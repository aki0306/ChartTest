//
//  StockChartView+Crosshair.swift
//  ChartTest
//
//  【View】StockChartView の表示オプションの反映と、十字線を動かす操作(タップ・ドラッグ)。
//  十字線・マーカー・4本値の枠の表示と、十字線の位置・薄くする処理は CrosshairOverlayView(crosshairView)が持つ。
//  ここでは「どこを触ったら、どの線を動かすか」を決めて、crosshairView に伝える。
//
//  4本値がオンのときの画面:
//
//   ┌──────────────────────────────┐
//   │移動平均 短期… 長期…            │
//   │          ┊         ┌─────────┐│
//   │          ┊         │ 4本値の枠 ││ ← 常に右上に置く
//   │          ┊         └─────────┘│
//   │   ＜60,660.98＞┈┈┈┈┈┈┈┼┈┈┈┈┈┈┈┈┈│◀ ← 横線・値のマーカー・Y軸側の矢印
//   │                      ┊         │
//   └──────────────────────────────┘
//                         /\           ← 日付のマーカー(文字なしの矢印)
//                        |  |
//
//  動き:
//  ・横線は指の高さ、縦線は指の位置に引く(足の中心には合わせない。線は黒い実線)。4本値は縦線に一番近い足の値
//  ・最初の位置(4本値をオンにしたとき・データや足種が変わったとき)は、メインチャートの描画領域の中央
//  ・動かす線は、触り始めた場所で決める(CrosshairArea / CrosshairMoveTarget)
//      | 触り始めた場所                                   | ドラッグ・タップで動かす線 |
//      | 十字線の交点から 15pt 以内(枠の内側でもよい)    | 縦線・横線の両方           |
//      | 枠の左右の外側(メインチャートの高さ)            | 横線だけ                   |
//      | 枠の上下の外側(日付ラベルの欄)・枠の下端 10pt | 縦線(日付・4本値)だけ    |
//      | 枠の内側(上以外)                               | 動かさない(スクロール)   |
//    動かせるのは、指がその線を動かせる場所にある間だけ(横線は枠の左右の外側でメインの高さ、縦線は枠の左右の幅の中)
//  ・値のない日時(値が空の足・1分足/日中足の値のない時間帯)を指したら、4本値は空欄にする
//  ・枠の内側は、4本値オン中もチャートのスクロール(1本指)・拡大(ピンチ)に使う。
//    交点・ラベルの欄からなぞったときは、十字線だけを動かしてスクロールはしない
//

import UIKit
import DGCharts

extension StockChartView {

    // MARK: - 表示オプションの反映

    /// 表示オプション(Y軸固定・4本値)を反映する。displayOptions が変わると呼ばれる
    func applyDisplayOptions() {
        // 4本値: オンのときだけ十字線のタップを受け付ける(チャートのスクロール・拡大はオン/オフに関係なく使える)。
        // ドラッグ(パン)は常に有効のまま、開始してよいかを gestureRecognizerShouldBegin で判定する
        for recognizer in self.crosshairRecognizers {
            guard recognizer is UITapGestureRecognizer else {
                continue
            }
            recognizer.isEnabled = self.displayOptions.showsOHLC
        }

        // オン/オフが切り替わったら、十字線は次回表示時に最初の位置から始める
        self.crosshairView.reset()
        // オンにしたときは元の濃さで表示し、一定時間後に薄くする
        self.crosshairView.wake()

        // Y軸固定: Y軸範囲を計算し直す(固定の場合は全期間、固定しない場合は表示範囲で計算される)
        if self.priceChartView.data != nil {
            if self.priceChartView.viewPortHandler.contentWidth > 0 {
                self.updateAxisRangesForVisibleCandles()
            } else {
                // レイアウト前は表示範囲が取れないので、初期表示範囲で計算する
                self.updateAxisRangesForInitialCandles()
            }
        }
        self.crosshairView.update()
    }

    // MARK: - ジェスチャー

    /// タップ: 外枠の外側をタップしたときだけ、十字線を動かす(枠の内側のタップでは動かさない)
    ///   ・右の価格ラベルの欄 → 横線だけを、タップした高さに移動する
    ///   ・下の日付ラベルの欄 → 縦線(日付・4本値)だけを、タップした位置の足に移動する
    @objc func chartTapped(_ recognizer: UITapGestureRecognizer) {
        guard let chart = recognizer.view else {
            return
        }
        let point = chart.convert(recognizer.location(in: chart), to: self)

        // 交点の近くのタップは、線は動かさずに元の濃さに戻すだけ
        if self.isNearCrosshairCross(point) {
            self.crosshairView.wake()
            return
        }
        switch self.crosshairArea(of: point) {
        case .priceLabels:
            self.crosshairView.move(to: point, target: .horizontalOnly)
        case .dateLabels:
            self.crosshairView.move(to: point, target: .verticalOnly)
        case .inside, .other:
            break  // 枠の内側(と左・上の外側)のタップでは動かさない
        }
    }

    /// 1本指ドラッグ: 十字線を指の位置に追従させる。動かす線は、なぞり始めた場所で決める
    ///   ・下の日付ラベルの欄からなぞる → 縦線(日付・4本値)だけ
    ///   ・右の価格ラベルの欄(メインチャートの高さ)からなぞる → 横線(価格)だけ
    ///   ・枠の内側などからなぞる → 動かさない
    @objc func chartPanned(_ recognizer: UIPanGestureRecognizer) {
        guard let chart = recognizer.view else {
            return
        }
        let point = chart.convert(recognizer.location(in: chart), to: self)

        switch recognizer.state {
        case .began:
            self.crosshairView.beginDrag(at: point, target: self.dragTarget(startingAt: point))
        case .changed:
            self.crosshairView.drag(to: point)
        default:
            // 指を離した・キャンセルされた
            self.crosshairView.endDrag()
        }
    }

    /// 指定した位置(このViewの座標)が、十字線の交点の近くか(4本値オンのときだけ)
    private func isNearCrosshairCross(_ point: CGPoint) -> Bool {
        guard self.displayOptions.showsOHLC else {
            return false
        }
        return self.crosshairView.isNearCross(point)
    }

    /// 指定した位置(このViewの座標)からなぞり始めたら、十字線を動かすか(4本値オンで、ラベルの欄のとき)
    func isCrosshairDragStart(at point: CGPoint) -> Bool {
        guard self.displayOptions.showsOHLC else {
            return false
        }
        return self.dragTarget(startingAt: point) != nil
    }

    /// なぞり始めた場所から、ドラッグで動かす線を決める(nil = 動かさない)
    private func dragTarget(startingAt point: CGPoint) -> CrosshairMoveTarget? {
        // 交点の近く(枠の内側でもよい)なら、縦線・横線の両方
        if self.isNearCrosshairCross(point) {
            return .both
        }
        switch self.crosshairArea(of: point) {
        case .priceLabels:
            return .horizontalOnly
        case .dateLabels:
            return .verticalOnly
        case .inside, .other:
            return nil  // 枠の内側(と左・上の外側)では動かさない
        }
    }

    /// メインチャートの描画領域の高さの範囲(このViewの座標)。外枠の上端〜区切り線(サブなしなら外枠の下端)
    var mainChartYRange: ClosedRange<CGFloat> {
        let frameRect = self.frameView.frame
        var bottom = frameRect.maxY
        if self.hasSubChart {
            bottom = self.dividerView.frame.minY
        }
        // レイアウト前などで区切り線が外枠の上端より上にあると、範囲の上下が逆になって落ちる(ClosedRange は下限 ≦ 上限が必要)。
        // その場合は、上端だけの範囲にする
        let upper = max(bottom, frameRect.minY)
        return frameRect.minY...upper
    }

    /// 縦線を動かせる、外枠の下端からの高さ(10pt。枠の内側でも縦線を動かす)
    private var dateTouchBandHeight: CGFloat {
        return 10
    }

    /// 指の位置が、外枠に対してどこにあるか
    private func crosshairArea(of point: CGPoint) -> CrosshairArea {
        let frameRect = self.frameView.frame
        let isWithinFrameWidth = (frameRect.minX...frameRect.maxX).contains(point.x)

        if frameRect.contains(point) {
            // 外枠の下端 10pt は、日付ラベルの欄と同じく縦線を動かす
            if point.y > frameRect.maxY - self.dateTouchBandHeight {
                return .dateLabels
            }
            return .inside
        }
        // 外枠の左右の外側(右の価格ラベルの欄など)で、メインチャートの高さ → 横線
        if !isWithinFrameWidth {
            if self.mainChartYRange.contains(point.y) {
                return .priceLabels
            }
            return .other
        }
        // 外枠の左右の幅の中で、外枠の上下の外側(下の日付ラベルの欄など) → 縦線
        return .dateLabels
    }
}

// MARK: - UIGestureRecognizerDelegate(十字線のドラッグ)

extension StockChartView: UIGestureRecognizerDelegate {

    /// 十字線を動かすドラッグは、4本値オンのときだけ開始する
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 自分で追加した十字線用のパンだけを判定する(それ以外は標準の動きのまま)
        guard gestureRecognizer is UIPanGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        guard self.crosshairRecognizers.contains(gestureRecognizer) else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        // 4本値オンで、ラベルの欄からなぞり始めたときだけ開始する
        // (枠の内側からなぞったときはチャートのスクロールに譲る)
        return self.isCrosshairDragStart(at: gestureRecognizer.location(in: self))
    }
}

// MARK: - 十字線を動かすときの種類

/// 十字線のどの線を動かすか
enum CrosshairMoveTarget {
    /// 縦線(日付・4本値)だけ(枠の上下の外側・枠の下端 10pt)
    case verticalOnly
    /// 横線(価格)だけ(枠の左右の外側)
    case horizontalOnly
    /// 縦線・横線の両方(交点から 15pt 以内)
    case both
}

/// 指の位置が、外枠に対してどこにあるか
enum CrosshairArea {
    /// 外枠の内側
    case inside
    /// 横線を動かす欄(枠の左右の外側で、メインチャートの高さ)
    case priceLabels
    /// 縦線を動かす欄(枠の上下の外側・枠の下端 10pt)
    case dateLabels
    /// それ以外(四隅など)
    case other
}

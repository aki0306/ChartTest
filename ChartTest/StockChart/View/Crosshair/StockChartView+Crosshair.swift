//
//  StockChartView+Crosshair.swift
//  ChartTest
//
//  【View】StockChartView の表示オプションの反映と、十字線・4本値の表示。
//
//  4本値がオンのときの画面:
//
//   ┌──────────────────────────────┐
//   │移動平均 短期… 長期…            │
//   │          ┊         ┌─────────┐│
//   │          ┊         │ 4本値の枠 ││ ← ohlcInfoView(常に右上に置く)
//   │          ┊         └─────────┘│
//   │   ＜60,660.98＞┈┈┈┈┈┈┈┼┈┈┈┈┈┈┈┈┈│◀ ← 横線・値のマーカー(valueMarker)・Y軸側の矢印(yAxisMarker)
//   │                      ┊         │
//   └──────────────────────────────┘
//                         /\           ← 日付のマーカー(dateMarker。文字なしの矢印)
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

        // オン/オフが切り替わったら、十字線は次回表示時に最新の足の位置から始める
        self.crosshairPoint = nil
        // オンにしたときは元の濃さで表示し、一定時間後に薄くする
        self.wakeCrosshair()

        // Y軸固定: Y軸範囲を計算し直す(固定の場合は全期間、固定しない場合は表示範囲で計算される)
        if self.priceChartView.data != nil {
            if self.priceChartView.viewPortHandler.contentWidth > 0 {
                self.updateAxisRangesForVisibleCandles()
            } else {
                // レイアウト前は表示範囲が取れないので、初期表示範囲で計算する
                self.updateAxisRangesForInitialCandles()
            }
        }
        self.updateCrosshair()
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
            self.wakeCrosshair()
            return
        }
        switch self.crosshairArea(of: point) {
        case .priceLabels:
            self.moveCrosshair(to: point, target: .horizontalOnly)
        case .dateLabels:
            self.moveCrosshair(to: point, target: .verticalOnly)
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
            self.crosshairDragTarget = self.dragTarget(startingAt: point)
            if let target = self.crosshairDragTarget {
                self.moveCrosshair(to: point, target: target)
            }
        case .changed:
            if let target = self.crosshairDragTarget {
                self.moveCrosshair(to: point, target: target)
            }
        default:
            // 指を離した・キャンセルされた(縦線は足の中心に合わせ直さない)
            self.crosshairDragTarget = nil
            // 指を離したところから、薄くするまでの時間を数え始める
            self.wakeCrosshair()
        }
    }

    /// 十字線の交点をつかめる距離(15pt)
    private var crosshairGrabRadius: CGFloat {
        return 15
    }

    /// 指定した位置(このViewの座標)が、十字線の交点から crosshairGrabRadius 以内か
    private func isNearCrosshairCross(_ point: CGPoint) -> Bool {
        guard self.displayOptions.showsOHLC else {
            return false
        }
        guard let cross = self.crosshairPoint else {
            return false
        }
        let distance = hypot(point.x - cross.x, point.y - cross.y)
        return distance <= self.crosshairGrabRadius
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
    private var mainChartYRange: ClosedRange<CGFloat> {
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

    /// 十字線を指定した位置(このViewの座標)に移動する。
    /// 指がその線を動かせる場所にある間だけ動かす(場所を外れたら、その線は止めておく)
    ///   ・縦線: 指が外枠の左右の幅の中にあるとき
    ///   ・横線: 交点をつかんでいるときはメインチャートの高さの中、横線だけのときは外枠の左右の外側でメインチャートの高さの中
    /// - Parameter target: 動かす線(縦線だけ・横線だけ・両方)。動かさない方の線は、今の位置のまま
    private func moveCrosshair(to point: CGPoint, target: CrosshairMoveTarget) {
        guard self.displayOptions.showsOHLC else {
            return
        }
        let frameRect = self.frameView.frame
        let isWithinFrameWidth = (frameRect.minX...frameRect.maxX).contains(point.x)
        let isWithinMainHeight = self.mainChartYRange.contains(point.y)

        // 今の十字線の位置(まだ置いていなければ、描画領域の中央)から、動かす線だけを変える
        var newPoint = self.initialCrosshairPoint()
        if let crosshairPoint {
            newPoint = crosshairPoint
        }
        switch target {
        case .verticalOnly:
            if isWithinFrameWidth {
                newPoint.x = point.x
            }
        case .horizontalOnly:
            if !isWithinFrameWidth {
                if isWithinMainHeight {
                    newPoint.y = point.y
                }
            }
        case .both:
            if isWithinFrameWidth {
                newPoint.x = point.x
            }
            if isWithinMainHeight {
                newPoint.y = point.y
            }
        }
        self.crosshairPoint = newPoint
        self.updateCrosshair()
        // 動かしたら元の濃さに戻す(ドラッグ中は薄くしない)
        self.wakeCrosshair()
    }

    // MARK: - 一定時間で薄くする

    /// 薄くする部品(十字線・値のマーカー・日付のマーカー・Y軸側のマーカー・4本値の枠)
    private var crosshairFadingViews: [UIView] {
        return [self.crosshairView, self.ohlcInfoView, self.valueMarker, self.dateMarker, self.yAxisMarker]
    }

    /// 4本値を元の濃さに戻し、一定時間後に薄くする予約をし直す。
    /// ドラッグ中(crosshairDragTarget あり)は予約しない(指を離したときに予約する)
    func wakeCrosshair() {
        self.crosshairFadeWorkItem?.cancel()
        self.crosshairFadeWorkItem = nil
        for view in self.crosshairFadingViews {
            view.layer.removeAllAnimations()
            view.alpha = 1
        }

        guard self.displayOptions.showsOHLC else {
            return
        }
        guard self.crosshairDragTarget == nil else {
            return
        }
        guard self.style.crosshairFadeDelay > 0 else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.fadeCrosshair()
        }
        self.crosshairFadeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + self.style.crosshairFadeDelay, execute: workItem)
    }

    /// 4本値を薄く表示する(アニメーションで少しずつ薄くする)
    private func fadeCrosshair() {
        self.crosshairFadeWorkItem = nil
        // 線は 30%、4本値の枠・値のマーカー・矢印は 50% の濃さにする
        let alpha = self.style.crosshairFadedAlpha
        let lineAlpha = self.style.crosshairFadedLineAlpha
        UIView.animate(withDuration: 0.3) {
            for view in self.crosshairFadingViews {
                if view === self.crosshairView {
                    view.alpha = lineAlpha
                } else {
                    view.alpha = alpha
                }
            }
        }
    }

    // MARK: - 十字線の配置

    /// 十字線・マーカー・4本値の枠を配置する(指の移動・スクロール・ズーム・サイズ変更のたびに呼ぶ)。
    /// 縦線は十字線の X に一番近い足に合わせ、4本値はその足の値を表示する
    func updateCrosshair() {
        let frameRect = self.frameView.frame  // 外枠(メイン + サブの描画領域全体)
        guard self.canShowCrosshair(in: frameRect) else {
            self.hideCrosshair()
            return
        }
        self.crosshairView.frame = self.bounds

        // 位置が未設定(4本値をオンにした直後・データ変更後)なら、メインチャートの描画領域の中央に置く
        if self.crosshairPoint == nil {
            self.crosshairPoint = self.initialCrosshairPoint()
        }
        guard let point = self.crosshairPoint else {
            return
        }

        // 縦線・横線は、指の位置のまま(足の中心には合わせない)。
        // 描画領域の大きさが変わった場合に備えて、外枠・メインチャートの範囲に収める
        let mainRange = self.mainChartYRange
        let lineX = min(max(point.x, frameRect.minX), frameRect.maxX)
        let lineY = min(max(point.y, mainRange.lowerBound), mainRange.upperBound)

        // 横線は、外枠の右の価格ラベルの欄を通って、右端の矢印のマーカーまで引く
        self.crosshairView.show(x: lineX, verticalRange: frameRect.minY...frameRect.maxY,
                                y: lineY, horizontalRange: frameRect.minX...self.bounds.maxX)
        self.showValueMarker(atY: lineY, frameRect: frameRect)
        self.showYAxisMarker(atY: lineY)
        self.showDateMarker(atX: lineX, frameRect: frameRect)

        // 4本値の枠は、十字線の位置に関係なく常に右上に置く。中身は縦線に一番近い日時のもの(値がなければ空欄)
        self.showOHLCInfo(for: self.crosshairSlot(atX: lineX), frameRect: frameRect)
    }

    /// 十字線を表示できる状態か
    private func canShowCrosshair(in frameRect: CGRect) -> Bool {
        // 4本値がオフ
        guard self.displayOptions.showsOHLC else {
            return false
        }
        // データがない
        guard !self.candles.isEmpty else {
            return false
        }
        // レイアウト前で、描画領域の大きさが決まっていない
        guard self.priceChartView.viewPortHandler.contentWidth > 0 else {
            return false
        }
        guard frameRect.width > 0 else {
            return false
        }
        return true
    }

    /// 十字線・マーカー・4本値の枠をすべて隠す
    private func hideCrosshair() {
        self.crosshairView.hide()
        for view in [self.ohlcInfoView, self.valueMarker, self.dateMarker, self.yAxisMarker] {
            view.isHidden = true
        }
    }

    /// 十字線の最初の位置(このViewの座標)。メインチャートの描画領域の中央
    private func initialCrosshairPoint() -> CGPoint {
        let priceArea = self.priceChartView.convert(self.priceChartView.viewPortHandler.contentRect, to: self)
        return CGPoint(x: priceArea.midX, y: priceArea.midY)
    }

    /// 指定した X(このViewの座標)に一番近い日時の、4本値の枠に出す内容。
    /// 値のない日時は空欄にする
    ///   ・値のある足                              → 日付と4本値
    ///   ・値が空の足(埋めた足)・値のない時間帯 → 日付だけ(4本値は空欄)
    ///   ・データの範囲の外                        → すべて空欄
    private func crosshairSlot(atX x: CGFloat) -> CrosshairSlot {
        // このViewの座標 → チャート上の座標 → X軸の値(何本目か。小数)→ 一番近い日時の番号
        let pointInChart = self.convert(CGPoint(x: x, y: 0), to: self.priceChartView)
        let xValue = self.priceChartView.valueForTouchPoint(point: pointInChart, axis: .right).x
        let index = Int(xValue.rounded())

        // 値のある足の範囲(0 〜 足の数 − 1)
        if (0..<self.candles.count).contains(index) {
            let candle = self.candles[index]
            if candle.isFilled {
                return CrosshairSlot(date: candle.date, candle: nil)
            }
            return CrosshairSlot(date: candle.date, candle: candle)
        }
        // 値のある最初の足より前の、日時だけの足(X軸の値はマイナス)
        let leadingIndex = self.leadingDates.count + index
        if index < 0 {
            if leadingIndex >= 0 {
                return CrosshairSlot(date: self.leadingDates[leadingIndex], candle: nil)
            }
            return CrosshairSlot(date: nil, candle: nil)
        }
        // 値のある最後の足より後ろの、日時だけの足
        let trailingIndex = index - self.candles.count
        if trailingIndex < self.trailingDates.count {
            return CrosshairSlot(date: self.trailingDates[trailingIndex], candle: nil)
        }
        return CrosshairSlot(date: nil, candle: nil)
    }

    // MARK: - マーカー

    /// 横線の値のマーカー: 外枠の左端寄りのグレーの六角形。
    /// 横線がメイン/サブのどちらにあるかで、その軸の値を表示する
    private func showValueMarker(atY y: CGFloat, frameRect: CGRect) {
        guard let text = self.crosshairValueText(atY: y) else {
            self.valueMarker.isHidden = true
            return
        }
        // 外枠の左端から 60pt 右の位置を中心にする(凡例の左端・外枠の線と重ならないように)
        let anchor = CGPoint(x: frameRect.minX + 60, y: y)
        self.valueMarker.show(text, anchor: anchor, within: frameRect)
    }

    /// Y軸側の赤い矢印: このViewの右端に、横線の高さで左向きに置く
    private func showYAxisMarker(atY y: CGFloat) {
        let anchor = CGPoint(x: self.bounds.maxX, y: y)
        self.yAxisMarker.show(nil, anchor: anchor, within: self.bounds, alignRight: true)
    }

    /// X軸の赤い矢印: 外枠のすぐ下(X軸ラベルの位置)に、縦線を指す上向きの矢印を置く(日付の文字は出さない)。
    /// 縦線がない(x = nil)場合は隠す
    private func showDateMarker(atX x: CGFloat?, frameRect: CGRect) {
        guard let x else {
            self.dateMarker.isHidden = true
            return
        }
        // 収める範囲: 横方向は外枠ではなくView全体(右端の足でも矢印が縦線からずれないように)。
        // 矢印の分だけX軸ラベル領域より少し背が高いので、縦方向は 8pt はみ出してもよいことにする
        let labelArea = CGRect(x: self.bounds.minX, y: frameRect.maxY,
                               width: self.bounds.width, height: self.style.xAxisLabelHeight + 8)
        let anchor = CGPoint(x: x, y: frameRect.maxY)  // 矢印の先端を外枠の下端に合わせる
        self.dateMarker.show(nil, anchor: anchor, within: labelArea)
    }

    /// 横線の高さ(このViewの座標)にあたる軸の値を、表示用の文字列にする。
    /// メインチャート上なら価格(小数2桁)、サブチャート上ならサブ指標の値(指標ごとの桁数・単位)。
    /// どちらの描画領域にもない場合は nil
    private func crosshairValueText(atY y: CGFloat) -> String? {
        // メインチャートの描画領域にあるか
        let priceArea = self.priceChartView.convert(self.priceChartView.viewPortHandler.contentRect, to: self)
        if (priceArea.minY...priceArea.maxY).contains(y) {
            let value = self.axisValue(of: self.priceChartView, atY: y, area: priceArea)
            return ChartNumberFormatter.price(value)
        }

        // サブチャートの描画領域にあるか
        if let sub = self.subContent {
            let subArea = self.subChartView.convert(self.subChartView.viewPortHandler.contentRect, to: self)
            if (subArea.minY...subArea.maxY).contains(y) {
                let value = self.axisValue(of: self.subChartView, atY: y, area: subArea)
                return ChartNumberFormatter.string(value, fractionDigits: sub.fractionDigits, suffix: sub.suffix)
            }
        }
        return nil
    }

    /// 指定した高さ(このViewの座標)にあたる、チャートのY軸の値
    private func axisValue(of chart: CombinedChartView, atY y: CGFloat, area: CGRect) -> Double {
        let pointInChart = self.convert(CGPoint(x: area.midX, y: y), to: chart)
        return chart.valueForTouchPoint(point: pointInChart, axis: .right).y
    }

    // MARK: - 4本値の枠

    /// 4本値の枠: 外枠の右上に置く。縦線を動かしても左右には移動しない
    ///
    ///   ┌────────────────────┐
    ///   │移動平均… │   ┌────┐│ ← 外枠の上端 + 5pt
    ///   │   │        │4本値││
    ///   │   │        └────┘│
    ///   │───┼──────────────│
    ///   │   │              │
    ///   └────────────────────┘
    ///                       ←5→
    ///
    /// ・大きさは中身(4本値のテキスト)から自動で決まる(systemLayoutSizeFitting)
    /// ・上端は外枠の上端から 5pt(凡例は左上にあるので、右上に置けば重ならない)
    /// ・右端は外枠の右端から 5pt
    private func showOHLCInfo(for slot: CrosshairSlot, frameRect: CGRect) {
        self.ohlcInfoView.update(date: slot.date, candle: slot.candle, dateFormat: self.style.ohlcDateFormat)
        self.ohlcInfoView.isHidden = false

        let size = self.ohlcInfoView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        // 外枠の右端・上端から 5pt
        let margin: CGFloat = 5
        let top = frameRect.minY + margin
        // 常に外枠の右上(縦線を動かしても左右に移動しない)
        let left = frameRect.maxX - margin - size.width
        self.ohlcInfoView.frame = CGRect(x: left, y: top, width: size.width, height: size.height)
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

/// 4本値の枠に出す内容(十字線が指している日時)
struct CrosshairSlot {
    /// 日時(データの範囲の外なら nil。日付も空欄にする)
    let date: Date?
    /// 値のある足(値のない日時なら nil。4本値を空欄にする)
    let candle: StockCandle?
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

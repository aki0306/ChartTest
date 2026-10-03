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
//  ・横線は指の高さ、縦線は指に一番近い足の中心に引く(線は黒い実線)
//  ・動かす線は、触った場所で決める(CrosshairArea / CrosshairMoveTarget)
//      | 触った場所                         | ドラッグ                 | タップ                       |
//      | 枠の内側                           | 動かさない               | 動かさない                   |
//      | 右の価格ラベルの欄(メインの高さ) | 横線だけ                 | 横線だけをその高さに移動     |
//      | 下の日付ラベルの欄                 | 縦線(日付・4本値)だけ  | 縦線だけをその位置の足に移動 |
//    横線は、メインチャートの高さの範囲だけで動かす(サブチャートの横の欄は触っても動かさない)
//    ドラッグで動かす線は、なぞり始めた場所で決める(途中で別の欄に指が移っても変えない)
//  ・枠の内側は、4本値オン中もチャートのスクロール(1本指)・拡大(ピンチ)に使う。
//    ラベルの欄からなぞったときは、十字線だけを動かしてスクロールはしない
//

import UIKit
import DGCharts

extension StockChartView {

    // MARK: - 表示オプションの反映

    /// 表示オプション(Y軸固定・4本値)を反映する。displayOptions が変わると呼ばれる
    func applyDisplayOptions() {
        // 4本値: オンのときだけ十字線のタップを受け付ける(チャートのスクロール・拡大はオン/オフに関係なく使える)。
        // ドラッグ(パン)は常に有効のまま、開始してよいかを gestureRecognizerShouldBegin で判定する
        for recognizer in crosshairRecognizers {
            guard recognizer is UITapGestureRecognizer else { continue }
            recognizer.isEnabled = displayOptions.showsOHLC
        }

        // オン/オフが切り替わったら、十字線は次回表示時に最新の足の位置から始める
        crosshairPoint = nil
        // オンにしたときは元の濃さで表示し、一定時間後に薄くする
        wakeCrosshair()

        // Y軸固定: Y軸範囲を計算し直す(固定の場合は全期間、固定しない場合は表示範囲で計算される)
        if priceChart.data != nil {
            if priceChart.viewPortHandler.contentWidth > 0 {
                updateAxisRangesForVisibleCandles()
            } else {
                // レイアウト前は表示範囲が取れないので、初期表示範囲で計算する
                updateAxisRangesForInitialCandles()
            }
        }
        updateCrosshair()
    }

    // MARK: - ジェスチャー

    /// タップ: 外枠の外側をタップしたときだけ、十字線を動かす(枠の内側のタップでは動かさない)
    ///   ・右の価格ラベルの欄 → 横線だけを、タップした高さに移動する
    ///   ・下の日付ラベルの欄 → 縦線(日付・4本値)だけを、タップした位置の足に移動する
    @objc func chartTapped(_ recognizer: UITapGestureRecognizer) {
        guard let chart = recognizer.view else { return }
        let point = chart.convert(recognizer.location(in: chart), to: self)

        switch crosshairArea(of: point) {
        case .priceLabels:
            moveCrosshair(to: point, target: .horizontalOnly)
        case .dateLabels:
            moveCrosshair(to: point, target: .verticalOnly)
        case .inside, .other:
            break  // 枠の内側(と左・上の外側)のタップでは動かさない
        }
    }

    /// 1本指ドラッグ: 十字線を指の位置に追従させる。動かす線は、なぞり始めた場所で決める
    ///   ・下の日付ラベルの欄からなぞる → 縦線(日付・4本値)だけ
    ///   ・右の価格ラベルの欄(メインチャートの高さ)からなぞる → 横線(価格)だけ
    ///   ・枠の内側などからなぞる → 動かさない
    @objc func chartPanned(_ recognizer: UIPanGestureRecognizer) {
        guard let chart = recognizer.view else { return }
        let point = chart.convert(recognizer.location(in: chart), to: self)

        switch recognizer.state {
        case .began:
            crosshairDragTarget = dragTarget(startingAt: point)
            if let target = crosshairDragTarget {
                moveCrosshair(to: point, target: target)
            }
        case .changed:
            if let target = crosshairDragTarget {
                moveCrosshair(to: point, target: target)
            }
        default:
            // 指を離した・キャンセルされた。縦線を動かしていた場合は、選んだ足の中心に合わせ直す
            let wasMovingVerticalLine = crosshairDragTarget == .verticalOnly
            crosshairDragTarget = nil
            if wasMovingVerticalLine {
                snapCrosshairToCandleCenter()
            }
            // 指を離したところから、薄くするまでの時間を数え始める
            wakeCrosshair()
        }
    }

    /// 縦線を、今選ばれている足(十字線の X に一番近い足)の中心に合わせる
    private func snapCrosshairToCandleCenter() {
        guard let point = crosshairPoint else { return }
        guard !candles.isEmpty else { return }
        let index = nearestCandleIndex(toX: point.x)
        if let centerX = candleCenterX(at: index, within: frameView.frame) {
            crosshairPoint = CGPoint(x: centerX, y: point.y)
        }
        updateCrosshair()
    }

    /// 指定した位置(このViewの座標)からなぞり始めたら、十字線を動かすか(4本値オンで、ラベルの欄のとき)
    func isCrosshairDragStart(at point: CGPoint) -> Bool {
        guard displayOptions.showsOHLC else { return false }
        return dragTarget(startingAt: point) != nil
    }

    /// なぞり始めた場所から、ドラッグで動かす線を決める(nil = 動かさない)
    private func dragTarget(startingAt point: CGPoint) -> CrosshairMoveTarget? {
        switch crosshairArea(of: point) {
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
        let frameRect = frameView.frame
        var bottom = frameRect.maxY
        if hasSubChart {
            bottom = dividerView.frame.minY
        }
        return frameRect.minY...max(bottom, frameRect.minY)
    }

    /// 指の位置が、外枠に対してどこにあるか
    private func crosshairArea(of point: CGPoint) -> CrosshairArea {
        let frameRect = frameView.frame
        if frameRect.contains(point) {
            return .inside
        }
        // 右の価格ラベルの欄(外枠の右側で、メインチャートの高さ。サブチャートの横は含めない)
        if point.x > frameRect.maxX {
            if mainChartYRange.contains(point.y) {
                return .priceLabels
            }
            return .other
        }
        // 下の日付ラベルの欄(外枠の下側で、外枠の左端〜右端の位置)
        if point.y > frameRect.maxY {
            if (frameRect.minX...frameRect.maxX).contains(point.x) {
                return .dateLabels
            }
            return .other
        }
        return .other
    }

    /// 十字線を指定した位置(このViewの座標)に移動する。外枠の外は外枠の端に寄せる
    /// - Parameter target: 動かす線(縦線だけ・横線だけ・両方)。動かさない方の線は、今の位置のまま
    private func moveCrosshair(to point: CGPoint, target: CrosshairMoveTarget) {
        guard displayOptions.showsOHLC else { return }
        let frameRect = frameView.frame
        let x = min(max(point.x, frameRect.minX), frameRect.maxX)  // 外枠の左端〜右端に収める
        // 横線はメインチャートの高さの範囲に収める(指がサブチャートの横まで移っても、メインの下端で止める)
        let mainRange = mainChartYRange
        let y = min(max(point.y, mainRange.lowerBound), mainRange.upperBound)

        // 今の十字線の位置(まだ置いていなければ、最新の足の位置)から、動かす線だけを変える
        var newPoint = latestCandlePoint()
        if let crosshairPoint {
            newPoint = crosshairPoint
        }
        switch target {
        case .verticalOnly:
            newPoint.x = x
        case .horizontalOnly:
            newPoint.y = y
        }
        crosshairPoint = newPoint
        updateCrosshair()
        // 動かしたら元の濃さに戻す(ドラッグ中は薄くしない)
        wakeCrosshair()
    }

    // MARK: - 一定時間で薄くする

    /// 薄くする部品(十字線・値のマーカー・日付のマーカー・Y軸側のマーカー・4本値の枠)
    private var crosshairFadingViews: [UIView] {
        return [crosshairView, ohlcInfoView, valueMarker, dateMarker, yAxisMarker]
    }

    /// 4本値を元の濃さに戻し、一定時間後に薄くする予約をし直す。
    /// ドラッグ中(crosshairDragTarget あり)は予約しない(指を離したときに予約する)
    func wakeCrosshair() {
        crosshairFadeWorkItem?.cancel()
        crosshairFadeWorkItem = nil
        for view in crosshairFadingViews {
            view.layer.removeAllAnimations()
            view.alpha = 1
        }

        guard displayOptions.showsOHLC else { return }
        guard crosshairDragTarget == nil else { return }
        guard style.crosshairFadeDelay > 0 else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.fadeCrosshair()
        }
        crosshairFadeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + style.crosshairFadeDelay, execute: workItem)
    }

    /// 4本値を薄く表示する(アニメーションで少しずつ薄くする)
    private func fadeCrosshair() {
        crosshairFadeWorkItem = nil
        let alpha = style.crosshairFadedAlpha
        UIView.animate(withDuration: 0.3) {
            for view in self.crosshairFadingViews {
                view.alpha = alpha
            }
        }
    }

    // MARK: - 十字線の配置

    /// 十字線・マーカー・4本値の枠を配置する(指の移動・スクロール・ズーム・サイズ変更のたびに呼ぶ)。
    /// 縦線は十字線の X に一番近い足に合わせ、4本値はその足の値を表示する
    func updateCrosshair() {
        let frameRect = frameView.frame  // 外枠(メイン + サブの描画領域全体)
        guard canShowCrosshair(in: frameRect) else {
            hideCrosshair()
            return
        }
        crosshairView.frame = bounds

        // 位置が未設定(4本値をオンにした直後・データ変更後)なら、表示範囲内の最新の足の終値の位置に置く
        if crosshairPoint == nil {
            crosshairPoint = latestCandlePoint()
        }
        guard let point = crosshairPoint else { return }

        // 指の位置に一番近い足
        let index = nearestCandleIndex(toX: point.x)
        let candle = candles[index]

        // 縦線の X。ふだんは足の中心(足が外枠の外なら nil で、縦線は描かない)。
        // 日付ラベルの欄からなぞっている間は、足ごとにカクカク跳ばないよう、指の位置にそのまま合わせる
        // (4本値・日付は指に一番近い足のものを出す。指を離したら足の中心に合わせ直す)
        var lineX = candleCenterX(at: index, within: frameRect)
        if crosshairDragTarget == .verticalOnly {
            lineX = point.x
        }
        // 横線の Y(指の高さ)
        let lineY = point.y

        // 横線は、外枠の右の価格ラベルの欄を通って、右端の矢印のマーカーまで引く
        crosshairView.show(x: lineX, verticalRange: frameRect.minY...frameRect.maxY,
                           y: lineY, horizontalRange: frameRect.minX...bounds.maxX)
        showValueMarker(atY: lineY, frameRect: frameRect)
        showYAxisMarker(atY: lineY)
        showDateMarker(atX: lineX, frameRect: frameRect)

        // 4本値の枠は、十字線の位置に関係なく常に右上に置く
        showOHLCInfo(for: candle, frameRect: frameRect)
    }

    /// 十字線を表示できる状態か
    private func canShowCrosshair(in frameRect: CGRect) -> Bool {
        // 4本値がオフ
        guard displayOptions.showsOHLC else { return false }
        // データがない
        guard !candles.isEmpty else { return false }
        // レイアウト前で、描画領域の大きさが決まっていない
        guard priceChart.viewPortHandler.contentWidth > 0 else { return false }
        guard frameRect.width > 0 else { return false }
        return true
    }

    /// 十字線・マーカー・4本値の枠をすべて隠す
    private func hideCrosshair() {
        crosshairView.hide()
        for view in [ohlcInfoView, valueMarker, dateMarker, yAxisMarker] {
            view.isHidden = true
        }
    }

    /// 表示範囲内の最新の足の、終値の位置(このViewの座標)
    private func latestCandlePoint() -> CGPoint {
        // 画面の右端に見えている足(データの範囲に収める)
        let rightEdgeIndex = Int(priceChart.highestVisibleX.rounded(.down))
        let latestIndex = min(max(rightEdgeIndex, 0), candles.count - 1)

        // チャートの値(X = 何本目か、Y = 終値)→ チャート上の座標 → このViewの座標
        let transformer = priceChart.getTransformer(forAxis: .right)
        let pointInChart = transformer.pixelForValues(x: Double(latestIndex), y: candles[latestIndex].close)
        return priceChart.convert(pointInChart, to: self)
    }

    /// 指定した X(このViewの座標)に一番近い足のインデックス(データの範囲外は端の足に寄せる)
    private func nearestCandleIndex(toX x: CGFloat) -> Int {
        // このViewの座標 → チャート上の座標 → X軸の値(何本目か。小数)
        let pointInChart = convert(CGPoint(x: x, y: 0), to: priceChart)
        let xValue = priceChart.valueForTouchPoint(point: pointInChart, axis: .right).x
        let index = Int(xValue.rounded())
        return min(max(index, 0), candles.count - 1)
    }

    /// 指定した足の中心の X(このViewの座標)。外枠の外にある場合は nil
    private func candleCenterX(at index: Int, within frameRect: CGRect) -> CGFloat? {
        // X軸の値(何本目か)→ チャート上の座標 → このViewの座標
        let transformer = priceChart.getTransformer(forAxis: .right)
        let pointInChart = transformer.pixelForValues(x: Double(index), y: 0)
        let x = priceChart.convert(pointInChart, to: self).x

        guard (frameRect.minX...frameRect.maxX).contains(x) else { return nil }
        return x
    }

    // MARK: - マーカー

    /// 横線の値のマーカー: 外枠の左端寄りのグレーの六角形。
    /// 横線がメイン/サブのどちらにあるかで、その軸の値を表示する
    private func showValueMarker(atY y: CGFloat, frameRect: CGRect) {
        guard let text = crosshairValueText(atY: y) else {
            valueMarker.isHidden = true
            return
        }
        // 外枠の左端から 60pt 右の位置を中心にする(凡例の左端・外枠の線と重ならないように)
        let anchor = CGPoint(x: frameRect.minX + 60, y: y)
        valueMarker.show(text, anchor: anchor, within: frameRect)
    }

    /// Y軸側の赤い矢印: このViewの右端に、横線の高さで左向きに置く
    private func showYAxisMarker(atY y: CGFloat) {
        let anchor = CGPoint(x: bounds.maxX, y: y)
        yAxisMarker.show(nil, anchor: anchor, within: bounds, alignRight: true)
    }

    /// X軸の赤い矢印: 外枠のすぐ下(X軸ラベルの位置)に、縦線を指す上向きの矢印を置く(日付の文字は出さない)。
    /// 縦線がない(x = nil)場合は隠す
    private func showDateMarker(atX x: CGFloat?, frameRect: CGRect) {
        guard let x else {
            dateMarker.isHidden = true
            return
        }
        // 収める範囲: 横方向は外枠ではなくView全体(右端の足でも矢印が縦線からずれないように)。
        // 矢印の分だけX軸ラベル領域より少し背が高いので、縦方向は 8pt はみ出してもよいことにする
        let labelArea = CGRect(x: bounds.minX, y: frameRect.maxY,
                               width: bounds.width, height: style.xAxisLabelHeight + 8)
        let anchor = CGPoint(x: x, y: frameRect.maxY)  // 矢印の先端を外枠の下端に合わせる
        dateMarker.show(nil, anchor: anchor, within: labelArea)
    }

    /// 横線の高さ(このViewの座標)にあたる軸の値を、表示用の文字列にする。
    /// メインチャート上なら価格(小数2桁)、サブチャート上ならサブ指標の値(指標ごとの桁数・単位)。
    /// どちらの描画領域にもない場合は nil
    private func crosshairValueText(atY y: CGFloat) -> String? {
        // メインチャートの描画領域にあるか
        let priceArea = priceChart.convert(priceChart.viewPortHandler.contentRect, to: self)
        if (priceArea.minY...priceArea.maxY).contains(y) {
            let value = axisValue(of: priceChart, atY: y, area: priceArea)
            let formatter = ChartNumberFormatter.make(fractionDigits: 2, minimumFractionDigits: 2)
            return formatter.string(from: NSNumber(value: value))
        }

        // サブチャートの描画領域にあるか
        if let sub = subContent {
            let subArea = subChart.convert(subChart.viewPortHandler.contentRect, to: self)
            if (subArea.minY...subArea.maxY).contains(y) {
                let value = axisValue(of: subChart, atY: y, area: subArea)
                let formatter = ChartNumberFormatter.make(fractionDigits: sub.fractionDigits, suffix: sub.suffix)
                return formatter.string(from: NSNumber(value: value))
            }
        }
        return nil
    }

    /// 指定した高さ(このViewの座標)にあたる、チャートのY軸の値
    private func axisValue(of chart: CombinedChartView, atY y: CGFloat, area: CGRect) -> Double {
        let pointInChart = convert(CGPoint(x: area.midX, y: y), to: chart)
        return chart.valueForTouchPoint(point: pointInChart, axis: .right).y
    }

    // MARK: - 4本値の枠

    /// 4本値の枠: 外枠の右上に置く。縦線を動かしても左右には移動しない
    ///
    ///   ┌────────────────────┐
    ///   │移動平均… │   ┌────┐│ ← 外枠の上端 + 4pt
    ///   │   │        │4本値││
    ///   │   │        └────┘│
    ///   │───┼──────────────│
    ///   │   │              │
    ///   └────────────────────┘
    ///                       ←8→
    ///
    /// ・大きさは中身(4本値のテキスト)から自動で決まる(systemLayoutSizeFitting)
    /// ・上端は外枠の上端から 4pt(凡例は左上にあるので、右上に置けば重ならない)
    /// ・右端は外枠の右端から 8pt
    private func showOHLCInfo(for candle: StockCandle, frameRect: CGRect) {
        ohlcInfoView.update(with: candle)
        ohlcInfoView.isHidden = false

        let size = ohlcInfoView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let margin: CGFloat = 8
        let top = frameRect.minY + 4
        // 常に外枠の右上(縦線を動かしても左右に移動しない)
        let left = frameRect.maxX - margin - size.width
        ohlcInfoView.frame = CGRect(x: left, y: top, width: size.width, height: size.height)
    }
}

// MARK: - UIGestureRecognizerDelegate(十字線のドラッグ)

extension StockChartView: UIGestureRecognizerDelegate {

    /// 十字線を動かすドラッグは、4本値オンのときだけ開始する
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 自分で追加した十字線用のパンか: 4本値オンで、ラベルの欄からなぞり始めたときだけ開始する
        // (枠の内側からなぞったときはチャートのスクロールに譲る)
        if gestureRecognizer is UIPanGestureRecognizer, crosshairRecognizers.contains(gestureRecognizer) {
            return isCrosshairDragStart(at: gestureRecognizer.location(in: self))
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

// MARK: - 十字線を動かすときの種類

/// 十字線のどの線を動かすか
enum CrosshairMoveTarget {
    /// 縦線(日付・4本値)だけ(下の日付ラベルの欄)
    case verticalOnly
    /// 横線(価格)だけ(右の価格ラベルの欄)
    case horizontalOnly
}

/// 指の位置が、外枠に対してどこにあるか
enum CrosshairArea {
    /// 外枠の内側
    case inside
    /// 右の価格ラベルの欄
    case priceLabels
    /// 下の日付ラベルの欄
    case dateLabels
    /// それ以外(左・上の外側、角)
    case other
}

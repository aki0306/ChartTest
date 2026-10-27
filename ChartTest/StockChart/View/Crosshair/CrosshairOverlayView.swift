//
//  CrosshairOverlayView.swift
//  ChartTest
//
//  【View】「4本値」の表示(十字線・マーカー・4本値の枠)と、その状態(十字線の位置・薄くする予約)をまとめて持つView。
//  4本値は横画面でしか使わないので、色・マーカーの画像・薄くするまでの秒数・薄くしたときの濃さは外から変えず、ここで決める。
//
//  ・十字線(縦線 + 横線)は、このView自身に描く
//  ・マーカーと4本値の枠は、チャートとの重なり順を合わせるため、親(StockChartView)に直接追加する(didMoveToSuperview)
//      dateMarker(日付の赤い矢印)                  … 一番奥。透明なチャートが描く日付ラベルが矢印の上に重なって見える
//      ohlcInfoView / valueMarker / yAxisMarker     … 一番手前。最高値・最安値の文字や凡例より手前
//    このViewは、親のほかの部品をすべて追加し終えてから追加する(StockChartView+Layout の addCrosshair)
//  ・位置の計算に使うチャート・外枠・足のデータは、親の StockChartView から読む
//
//  StockChartView(StockChartView+Crosshair)から呼ぶもの:
//  ・update()                    … 置き直す(スクロール・ズーム・サイズ変更・データ変更のたび)
//  ・reset()                     … 次に置くときは、最初の位置(メインチャートの描画領域の中央)から始める
//  ・wake()                      … 元の濃さに戻し、一定時間後に薄くする
//  ・move(to:target:)            … タップした位置に動かす
//  ・beginDrag / drag / endDrag  … ドラッグで動かす
//  ・isNearCross(_:)             … 十字線の交点の近くか(動かす線を決めるのに使う)
//

import UIKit
import DGCharts

/// 4本値(十字線・マーカー・4本値の枠)を表示するView。タッチは下のチャートに通す
final class CrosshairOverlayView: UIView {

    // MARK: - 見た目(横画面でしか使わないので、外からは変えない)

    /// 線の色(黒の実線)
    private let lineColor = UIColor(resource: .chartCrosshairLine)
    /// 動かしてから薄く表示するまでの秒数
    private let fadeDelay: TimeInterval = 3
    /// 薄く表示するときの、4本値の枠・値のマーカー・矢印の不透明度(50%)。また動かすと元の濃さに戻る
    private let fadedAlpha: CGFloat = 0.5
    /// 薄く表示するときの、十字線(縦線・横線)の不透明度(30%)
    private let fadedLineAlpha: CGFloat = 0.3
    /// 十字線の交点をつかめる距離(15pt)
    private let grabRadius: CGFloat = 15

    // MARK: - 部品

    /// 縦線
    private let verticalLine = CAShapeLayer()
    /// 横線
    private let horizontalLine = CAShapeLayer()
    /// 選択中の足の4本値の枠
    private let ohlcInfoView = OHLCInfoView()
    /// 横線の位置の値を表示するマーカー(外枠の左端寄り・グレーの六角形)。
    /// 文字の長さに合わせて、画像の左右の尖った部分(10pt)以外を伸ばす。文字は尖った部分に重ならないよう左右 12pt 空ける
    private let valueMarker = CrosshairMarkerLabel(
        backgroundImage: UIImage(resource: .chartValueMarker)
            .resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10), resizingMode: .stretch),
        padding: UIEdgeInsets(top: 3, left: 12, bottom: 3, right: 12))
    /// 縦線の位置を示すマーカー(X軸・赤い上向き矢印。文字なし)
    private let dateMarker = CrosshairMarkerLabel(backgroundImage: UIImage(resource: .chartDateMarker))
    /// 横線の位置を示すマーカー(Y軸側の右端・赤い左向き矢印。文字なし)
    private let yAxisMarker = CrosshairMarkerLabel(backgroundImage: UIImage(resource: .chartYAxisMarker))

    // MARK: - 状態

    /// 十字線の位置(親の座標)。指の位置に合わせて動く(縦線も足の中心には合わせない。4本値はこの X に一番近い足)。
    /// nil の場合は次に置くときに、メインチャートの描画領域の中央に置く
    private var crosshairPoint: CGPoint?
    /// ドラッグ中に動かす線(なぞり始めた場所で決める。nil = ドラッグしていない)
    private var dragTarget: CrosshairMoveTarget?
    /// 薄く表示する予約(一定時間動かさなかったら実行する。動かすと取り消して予約し直す)
    private var fadeWorkItem: DispatchWorkItem?

    /// 位置の計算に使うチャート(親)
    private var chartView: StockChartView? {
        return self.superview as? StockChartView
    }

    /// 親に直接追加する部品(マーカー・4本値の枠)
    private var parts: [UIView] {
        return [self.ohlcInfoView, self.valueMarker, self.dateMarker, self.yAxisMarker]
    }

    /// 薄くする部品(十字線・マーカー・4本値の枠)
    private var fadingViews: [UIView] {
        return [self] + self.parts
    }

    // MARK: - 初期化

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    private func setup() {
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
        for line in [self.verticalLine, self.horizontalLine] {
            line.strokeColor = self.lineColor.cgColor
            line.lineWidth = 1
            line.lineDashPattern = nil  // 破線にせず、実線で引く
            line.fillColor = nil
            self.layer.addSublayer(line)
        }
        self.hide()
    }

    /// マーカーと4本値の枠を、親に重なり順を合わせて追加する(日付の矢印は一番奥、それ以外は一番手前)
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let superview else {
            for part in self.parts {
                part.removeFromSuperview()
            }
            return
        }
        superview.insertSubview(self.dateMarker, at: 0)
        for part in [self.ohlcInfoView, self.valueMarker, self.yAxisMarker] {
            superview.addSubview(part)
        }
    }

    // MARK: - StockChartView から呼ぶもの

    /// 十字線・マーカー・4本値の枠を配置する(指の移動・スクロール・ズーム・サイズ変更のたびに呼ぶ)。
    /// 4本値は、縦線に一番近い足の値を表示する
    func update() {
        guard let chartView else {
            return
        }
        let frameRect = chartView.frameView.frame  // 外枠(メイン + サブの描画領域全体)
        guard self.canShow(in: frameRect, chartView: chartView) else {
            self.hide()
            return
        }
        self.frame = chartView.bounds

        // 位置が未設定(4本値をオンにした直後・データ変更後)なら、メインチャートの描画領域の中央に置く
        var point = self.initialPoint(in: chartView)
        if let crosshairPoint {
            point = crosshairPoint
        }
        self.crosshairPoint = point

        // 縦線・横線は、指の位置のまま(足の中心には合わせない)。
        // 描画領域の大きさが変わった場合に備えて、外枠・メインチャートの範囲に収める
        let mainRange = chartView.mainChartYRange
        let lineX = min(max(point.x, frameRect.minX), frameRect.maxX)
        let lineY = min(max(point.y, mainRange.lowerBound), mainRange.upperBound)

        // 横線は、外枠の右の価格ラベルの欄を通って、右端の矢印のマーカーまで引く
        self.showLines(x: lineX, verticalRange: frameRect.minY...frameRect.maxY,
                       y: lineY, horizontalRange: frameRect.minX...chartView.bounds.maxX)
        self.showValueMarker(atY: lineY, frameRect: frameRect, chartView: chartView)
        self.showYAxisMarker(atY: lineY, chartView: chartView)
        self.showDateMarker(atX: lineX, frameRect: frameRect, chartView: chartView)

        // 4本値の枠は、十字線の位置に関係なく常に右上に置く。中身は縦線に一番近い日時のもの(値がなければ空欄)
        let slot = self.slot(atX: lineX, chartView: chartView)
        self.showOHLCInfo(for: slot, frameRect: frameRect, chartView: chartView)
    }

    /// 次に置くときは、最初の位置(メインチャートの描画領域の中央)から始める
    /// (4本値のオン/オフ・データの件数・サイズが変わったとき)
    func reset() {
        self.crosshairPoint = nil
    }

    /// 指定した位置(親の座標)が、十字線の交点から grabRadius 以内か
    func isNearCross(_ point: CGPoint) -> Bool {
        guard let cross = self.crosshairPoint else {
            return false
        }
        let distance = hypot(point.x - cross.x, point.y - cross.y)
        return distance <= self.grabRadius
    }

    /// 十字線を指定した位置(親の座標)に移動する。
    /// 指がその線を動かせる場所にある間だけ動かす(場所を外れたら、その線は止めておく)
    ///   ・縦線: 指が外枠の左右の幅の中にあるとき
    ///   ・横線: 交点をつかんでいるときはメインチャートの高さの中、横線だけのときは外枠の左右の外側でメインチャートの高さの中
    /// - Parameter target: 動かす線(縦線だけ・横線だけ・両方)。動かさない方の線は、今の位置のまま
    func move(to point: CGPoint, target: CrosshairMoveTarget) {
        guard let chartView else {
            return
        }
        guard chartView.displayOptions.showsOHLC else {
            return
        }
        let frameRect = chartView.frameView.frame
        let isWithinFrameWidth = (frameRect.minX...frameRect.maxX).contains(point.x)
        let isWithinMainHeight = chartView.mainChartYRange.contains(point.y)

        // 今の十字線の位置(まだ置いていなければ、描画領域の中央)から、動かす線だけを変える
        var newPoint = self.initialPoint(in: chartView)
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
        self.update()
        // 動かしたら元の濃さに戻す(ドラッグ中は薄くしない)
        self.wake()
    }

    /// ドラッグを始める。target が nil なら、このドラッグでは十字線を動かさない
    func beginDrag(at point: CGPoint, target: CrosshairMoveTarget?) {
        self.dragTarget = target
        if let target {
            self.move(to: point, target: target)
        }
    }

    /// ドラッグ中の指の位置(親の座標)に、十字線を追従させる
    func drag(to point: CGPoint) {
        if let target = self.dragTarget {
            self.move(to: point, target: target)
        }
    }

    /// ドラッグを終える(指を離した・キャンセルされた。縦線は足の中心に合わせ直さない)
    func endDrag() {
        self.dragTarget = nil
        // 指を離したところから、薄くするまでの時間を数え始める
        self.wake()
    }

    // MARK: - 一定時間で薄くする

    /// 元の濃さに戻し、一定時間後に薄くする予約をし直す。
    /// ドラッグ中は予約しない(指を離したときに予約する)
    func wake() {
        self.fadeWorkItem?.cancel()
        self.fadeWorkItem = nil
        for view in self.fadingViews {
            view.layer.removeAllAnimations()
            view.alpha = 1
        }

        guard let chartView else {
            return
        }
        guard chartView.displayOptions.showsOHLC else {
            return
        }
        guard self.dragTarget == nil else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.fade()
        }
        self.fadeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + self.fadeDelay, execute: workItem)
    }

    /// 薄く表示する(アニメーションで少しずつ薄くする)
    private func fade() {
        self.fadeWorkItem = nil
        // 線は 30%、4本値の枠・値のマーカー・矢印は 50% の濃さにする
        UIView.animate(withDuration: 0.3) {
            self.alpha = self.fadedLineAlpha
            for part in self.parts {
                part.alpha = self.fadedAlpha
            }
        }
    }

    // MARK: - 配置

    /// 十字線を表示できる状態か
    private func canShow(in frameRect: CGRect, chartView: StockChartView) -> Bool {
        // 4本値がオフ
        guard chartView.displayOptions.showsOHLC else {
            return false
        }
        // データがない
        guard !chartView.candles.isEmpty else {
            return false
        }
        // レイアウト前で、描画領域の大きさが決まっていない
        guard chartView.priceChartView.viewPortHandler.contentWidth > 0 else {
            return false
        }
        guard frameRect.width > 0 else {
            return false
        }
        return true
    }

    /// 十字線・マーカー・4本値の枠をすべて隠す
    /// (十字線は線を描かないことで隠すので、このView自身は isHidden にしない)
    private func hide() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.verticalLine.path = nil
        self.horizontalLine.path = nil
        CATransaction.commit()
        for part in self.parts {
            part.isHidden = true
        }
    }

    /// 十字線の最初の位置(親の座標)。メインチャートの描画領域の中央
    private func initialPoint(in chartView: StockChartView) -> CGPoint {
        let priceChart = chartView.priceChartView
        let priceArea = priceChart.convert(priceChart.viewPortHandler.contentRect, to: chartView)
        return CGPoint(x: priceArea.midX, y: priceArea.midY)
    }

    /// 縦線・横線を引く(座標はこのViewの座標系)
    /// - Parameters:
    ///   - x: 縦線の X 座標
    ///   - verticalRange: 縦線を引く Y の範囲
    ///   - y: 横線の Y 座標
    ///   - horizontalRange: 横線を引く X の範囲
    private func showLines(x: CGFloat, verticalRange: ClosedRange<CGFloat>,
                           y: CGFloat, horizontalRange: ClosedRange<CGFloat>) {
        // 暗黙のアニメーションで線が遅れて動かないよう、アニメーションを無効にして更新する
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // 縦線: (x, 上端) から (x, 下端) まで
        let verticalPath = UIBezierPath()
        verticalPath.move(to: CGPoint(x: x, y: verticalRange.lowerBound))
        verticalPath.addLine(to: CGPoint(x: x, y: verticalRange.upperBound))
        self.verticalLine.path = verticalPath.cgPath

        // 横線: (左端, y) から (右端, y) まで
        let horizontalPath = UIBezierPath()
        horizontalPath.move(to: CGPoint(x: horizontalRange.lowerBound, y: y))
        horizontalPath.addLine(to: CGPoint(x: horizontalRange.upperBound, y: y))
        self.horizontalLine.path = horizontalPath.cgPath

        CATransaction.commit()
    }

    /// 指定した X(親の座標)に一番近い日時の、4本値の枠に出す内容。
    /// 値のない日時は空欄にする
    ///   ・値のある足                              → 日付と4本値
    ///   ・値が空の足(埋めた足)・値のない時間帯 → 日付だけ(4本値は空欄)
    ///   ・データの範囲の外                        → すべて空欄
    private func slot(atX x: CGFloat, chartView: StockChartView) -> CrosshairSlot {
        // 親の座標 → チャート上の座標 → X軸の値(何本目か。小数)→ 一番近い日時の番号
        let priceChart = chartView.priceChartView
        let pointInChart = chartView.convert(CGPoint(x: x, y: 0), to: priceChart)
        let xValue = priceChart.valueForTouchPoint(point: pointInChart, axis: .right).x
        let index = Int(xValue.rounded())
        let candles = chartView.candles

        // 値のある足の範囲(0 〜 足の数 − 1)
        if (0..<candles.count).contains(index) {
            let candle = candles[index]
            if candle.isFilled {
                return CrosshairSlot(date: candle.date, candle: nil)
            }
            return CrosshairSlot(date: candle.date, candle: candle)
        }
        // 値のある最初の足より前の、日時だけの足(X軸の値はマイナス)
        let leadingDates = chartView.leadingDates
        let leadingIndex = leadingDates.count + index
        if index < 0 {
            if leadingIndex >= 0 {
                return CrosshairSlot(date: leadingDates[leadingIndex], candle: nil)
            }
            return CrosshairSlot(date: nil, candle: nil)
        }
        // 値のある最後の足より後ろの、日時だけの足
        let trailingDates = chartView.trailingDates
        let trailingIndex = index - candles.count
        if trailingIndex < trailingDates.count {
            return CrosshairSlot(date: trailingDates[trailingIndex], candle: nil)
        }
        return CrosshairSlot(date: nil, candle: nil)
    }

    // MARK: - マーカー

    /// 横線の値のマーカー: 外枠の左端寄りのグレーの六角形。
    /// 横線がメイン/サブのどちらにあるかで、その軸の値を表示する
    private func showValueMarker(atY y: CGFloat, frameRect: CGRect, chartView: StockChartView) {
        guard let text = self.valueText(atY: y, chartView: chartView) else {
            self.valueMarker.isHidden = true
            return
        }
        // 外枠の左端から 60pt 右の位置を中心にする(凡例の左端・外枠の線と重ならないように)
        let anchor = CGPoint(x: frameRect.minX + 60, y: y)
        self.valueMarker.show(text, anchor: anchor, within: frameRect)
    }

    /// Y軸側の赤い矢印: 親の右端に、横線の高さで左向きに置く
    private func showYAxisMarker(atY y: CGFloat, chartView: StockChartView) {
        let anchor = CGPoint(x: chartView.bounds.maxX, y: y)
        self.yAxisMarker.show(nil, anchor: anchor, within: chartView.bounds, alignRight: true)
    }

    /// X軸の赤い矢印: 外枠のすぐ下(X軸ラベルの位置)に、縦線を指す上向きの矢印を置く(日付の文字は出さない)
    private func showDateMarker(atX x: CGFloat, frameRect: CGRect, chartView: StockChartView) {
        // 収める範囲: 横方向は外枠ではなく親全体(右端の足でも矢印が縦線からずれないように)。
        // 矢印の分だけX軸ラベル領域より少し背が高いので、縦方向は 8pt はみ出してもよいことにする
        let bounds = chartView.bounds
        let labelArea = CGRect(x: bounds.minX, y: frameRect.maxY,
                               width: bounds.width, height: chartView.style.xAxisLabelHeight + 8)
        let anchor = CGPoint(x: x, y: frameRect.maxY)  // 矢印の先端を外枠の下端に合わせる
        self.dateMarker.show(nil, anchor: anchor, within: labelArea, alignTop: true)
    }

    /// 横線の高さ(親の座標)にあたる軸の値を、表示用の文字列にする。
    /// メインチャート上なら価格(小数2桁)、サブチャート上ならサブ指標の値(指標ごとの桁数・単位)。
    /// どちらの描画領域にもない場合は nil
    private func valueText(atY y: CGFloat, chartView: StockChartView) -> String? {
        // メインチャートの描画領域にあるか
        let priceChart = chartView.priceChartView
        let priceArea = priceChart.convert(priceChart.viewPortHandler.contentRect, to: chartView)
        if (priceArea.minY...priceArea.maxY).contains(y) {
            let value = self.axisValue(of: priceChart, atY: y, area: priceArea, chartView: chartView)
            return ChartNumberFormatter.price(value)
        }

        // サブチャートの描画領域にあるか
        if let sub = chartView.subContent {
            let subChart = chartView.subChartView
            let subArea = subChart.convert(subChart.viewPortHandler.contentRect, to: chartView)
            if (subArea.minY...subArea.maxY).contains(y) {
                let value = self.axisValue(of: subChart, atY: y, area: subArea, chartView: chartView)
                return ChartNumberFormatter.string(value, fractionDigits: sub.fractionDigits, suffix: sub.suffix)
            }
        }
        return nil
    }

    /// 指定した高さ(親の座標)にあたる、チャートのY軸の値
    private func axisValue(of chart: CombinedChartView, atY y: CGFloat, area: CGRect,
                           chartView: StockChartView) -> Double {
        let pointInChart = chartView.convert(CGPoint(x: area.midX, y: y), to: chart)
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
    /// ・日付の書式は足種ごと(StockChartStyle.ohlcDateFormat。値は ChartPeriod.ohlcDateFormat)
    private func showOHLCInfo(for slot: CrosshairSlot, frameRect: CGRect, chartView: StockChartView) {
        self.ohlcInfoView.update(date: slot.date, candle: slot.candle, dateFormat: chartView.style.ohlcDateFormat)
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

/// 4本値の枠に出す内容(十字線が指している日時)
struct CrosshairSlot {
    /// 日時(データの範囲の外なら nil。日付も空欄にする)
    let date: Date?
    /// 値のある足(値のない日時なら nil。4本値を空欄にする)
    let candle: StockCandle?
}

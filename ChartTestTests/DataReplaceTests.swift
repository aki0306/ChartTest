//
//  DataReplaceTests.swift
//  ChartTestTests
//
//  データを大量に減らして(0件・数本を含む)渡し直したときのテスト。
//  落ちないこと・表示範囲がスクロールできる範囲に収まること・十字線や「データなし」の表示が正しいことを確かめる
//

import DGCharts
import Testing
import UIKit
@testable import ChartTest

@Suite(.serialized)
@MainActor
struct DataReplaceTests {

    /// チャートの大きさ(縦画面のチャートに近い大きさ)
    private let chartSize = CGSize(width: 390, height: 300)

    /// 最初に表示する多めのデータの本数
    private let largeCount = 1000

    init() {
        // 横画面のチャートは、選んだ状態を国内/海外ごとに覚えているので、毎回最初の状態から始める
        ChartStateStore.reset()
    }

    // MARK: - 本数を減らす

    /// 1000本 → 指定の本数に減らしても落ちず、表示範囲がスクロールできる範囲に収まる
    @Test(arguments: [500, 100, 30, 10, 5, 2, 1])
    func testShrink(count: Int) {
        let chartView = self.makeChartView(candles: SampleData.nikkeiLike(days: self.largeCount))

        chartView.setCandles(Array(SampleData.nikkeiLike(days: self.largeCount).suffix(count)))
        chartView.layoutIfNeeded()

        #expect(chartView.candles.count == count)
        #expect(!chartView.showsNoDataMessage)
        self.expectVisibleRangeWithinAxis(chartView)
    }

    /// 1000本 → 0件にすると「データなし」のメッセージになり、日付だけの足も並べない
    @Test
    func testShrinkToEmpty() {
        let chartView = self.makeChartView(candles: SampleData.nikkeiLike(days: self.largeCount))

        chartView.setCandles([])
        chartView.layoutIfNeeded()

        #expect(chartView.candles.isEmpty)
        #expect(chartView.showsNoDataMessage)
        #expect(chartView.leadingDates.isEmpty)
        #expect(chartView.trailingDates.isEmpty)
    }

    /// 1000本 → 0件 → 1000本 と戻しても、メッセージが消えて表示範囲が収まる
    @Test
    func testEmptyThenLarge() {
        let candles = SampleData.nikkeiLike(days: self.largeCount)
        let chartView = self.makeChartView(candles: candles)

        chartView.setCandles([])
        chartView.layoutIfNeeded()
        chartView.setCandles(candles)
        chartView.layoutIfNeeded()

        #expect(chartView.candles.count == self.largeCount)
        #expect(!chartView.showsNoDataMessage)
        self.expectVisibleRangeWithinAxis(chartView)
    }

    /// 本数を何度も増やしたり減らしたりしても、毎回表示範囲が収まる
    @Test
    func testRepeatedResize() {
        let candles = SampleData.nikkeiLike(days: self.largeCount)
        let chartView = self.makeChartView(candles: candles)

        for count in [1000, 3, 0, 800, 1, 1000, 60, 0, 0, 2, 999, 10] {
            chartView.setCandles(Array(candles.suffix(count)))
            chartView.layoutIfNeeded()
            #expect(chartView.candles.count == count)
            #expect(chartView.showsNoDataMessage == (count == 0))
            if count > 0 {
                self.expectVisibleRangeWithinAxis(chartView)
            }
        }
    }

    // MARK: - 表示範囲の引き継ぎ

    /// 右端を見ている状態で古い側を消すと、右端(最新の足)を見たままになる
    @Test
    func testRemoveOldestKeepsRightEdge() {
        let candles = SampleData.nikkeiLike(days: self.largeCount)
        let chartView = self.makeChartView(candles: candles)
        let widthBefore = self.visibleWidth(chartView)

        chartView.setCandles(Array(candles.suffix(200)))
        chartView.layoutIfNeeded()

        let priceChart = chartView.priceChartView
        #expect(abs(priceChart.highestVisibleX - chartView.xAxisMaximum) < 1)
        // 見えている本数(幅)も前と同じ
        #expect(abs(self.visibleWidth(chartView) - widthBefore) < 1)
    }

    /// 左端までスクロールした状態で減らしても、表示範囲がスクロールできる範囲に収まる
    @Test
    func testShrinkWhileScrolledToLeft() {
        let candles = SampleData.nikkeiLike(days: self.largeCount)
        let chartView = self.makeChartView(candles: candles)
        for chart in [chartView.priceChartView, chartView.subChartView] {
            chart.moveViewToX(chartView.xAxisMinimum)
        }

        chartView.setCandles(Array(candles.suffix(50)))
        chartView.layoutIfNeeded()

        self.expectVisibleRangeWithinAxis(chartView)
    }

    /// 最大まで縮小(全件表示)した状態で減らしても、表示範囲が収まる
    @Test
    func testShrinkWhileZoomedOut() {
        let candles = SampleData.nikkeiLike(days: self.largeCount)
        let chartView = self.makeChartView(candles: candles)
        for chart in [chartView.priceChartView, chartView.subChartView] {
            chart.fitScreen()
        }

        chartView.setCandles(Array(candles.suffix(5)))
        chartView.layoutIfNeeded()

        self.expectVisibleRangeWithinAxis(chartView)
    }

    // MARK: - 十字線(4本値)

    /// 十字線を右端の足に置いた状態で減らしても落ちず、十字線の位置はリセットされる
    @Test(arguments: [100, 1, 0])
    func testShrinkWithCrosshair(count: Int) {
        let candles = SampleData.nikkeiLike(days: self.largeCount)
        let chartView = self.makeChartView(candles: candles)
        chartView.displayOptions.showsOHLC = true
        chartView.layoutIfNeeded()
        // 右端近くに十字線を動かす
        let frameRect = chartView.frameView.frame
        let rightPoint = CGPoint(x: frameRect.maxX - 2, y: frameRect.midY)
        chartView.crosshairView.move(to: rightPoint, target: .both)
        #expect(chartView.crosshairView.isNearCross(rightPoint))

        chartView.setCandles(Array(candles.suffix(count)))
        chartView.layoutIfNeeded()
        chartView.crosshairView.update()

        // 本数が変わったので、十字線は最初の位置(中央)に戻っている
        #expect(!chartView.crosshairView.isNearCross(rightPoint))
    }

    // MARK: - 指標・チャートの種類

    /// どの指標の組み合わせでも、期間より少ない本数(0〜30本)に減らして落ちない
    @Test(arguments: [
        MainChartIndicator.movingAverage, .multipleMovingAverage, .bollingerBands, .ichimoku, .parabolic, .candleOnly,
    ])
    func testIndicatorsWithFewCandles(mainIndicator: MainChartIndicator) {
        let candles = SampleData.nikkeiLike(days: 300)
        let subIndicators: [SubChartIndicator] = [
            .volume, .movingAverageDeviation, .rsi, .psychological, .stochastics, .macd, .dmi, .hidden,
        ]
        for subIndicator in subIndicators {
            let chartView = self.makeChartView(candles: candles)
            chartView.mainIndicator = mainIndicator
            chartView.subIndicator = subIndicator
            chartView.setCandles(candles)
            chartView.layoutIfNeeded()
            for count in [30, 5, 2, 1, 0] {
                chartView.setCandles(Array(candles.suffix(count)))
                chartView.layoutIfNeeded()
                #expect(chartView.candles.count == count)
                if count > 0 {
                    self.expectVisibleRangeWithinAxis(chartView)
                }
            }
        }
    }

    /// どのチャートの種類でも、本数を減らして落ちない(VWAP は日中足のデータ)
    @Test(arguments: [ChartType.candlestick, .lineChart, .newPrice, .vwapLine, .vwapDots])
    func testChartTypesWithFewCandles(chartType: ChartType) {
        var period = ChartPeriod.daily
        var candles = SampleData.nikkeiLike(days: self.largeCount)
        switch chartType {
        case .vwapLine, .vwapDots:
            period = .intraday
            candles = SampleData.candles(for: .intraday).filter { candle in
                candle.hasValue
            }
        case .candlestick, .lineChart, .newPrice:
            break
        }
        let chartView = StockChartView(frame: CGRect(origin: .zero, size: self.chartSize))
        chartView.market = .japanIndex
        chartView.chartType = chartType
        chartView.setCandles(candles, period: period)
        chartView.layoutIfNeeded()

        for count in [50, 5, 1, 0] {
            chartView.setCandles(Array(candles.suffix(count)), period: period)
            chartView.layoutIfNeeded()
            let showsMessage = count < self.minimumDrawableCount(of: chartType)
            #expect(chartView.showsNoDataMessage == showsMessage, "count: \(count)")
            if !showsMessage {
                self.expectVisibleRangeWithinAxis(chartView)
            }
        }
    }

    /// 描くのに必要な、値のある足の本数。
    /// 線でつなぐチャート(折線チャート・新値足・VWAP：線)は2本以上、それ以外は1本以上
    /// (それより少ないと「データなし」のメッセージになる。ChartContentBuilder.requiringTwoValidCandles)
    private func minimumDrawableCount(of chartType: ChartType) -> Int {
        switch chartType {
        case .lineChart, .newPrice, .vwapLine:
            return 2
        case .candlestick, .vwapDots:
            return 1
        }
    }

    // MARK: - レスポンス(updateChartData:)

    /// 日足のレスポンスを 1000件 → 3件 → 0件 と減らして渡しても落ちない
    @Test
    func testUpdateChartDataShrink() {
        let chartView = StockChartView(frame: CGRect(origin: .zero, size: self.chartSize))
        chartView.period = .daily
        let response = self.response(from: SampleData.nikkeiLike(days: self.largeCount))

        chartView.updateChartData(response)
        chartView.layoutIfNeeded()
        #expect(chartView.candles.count == self.largeCount)

        chartView.updateChartData(Array(response.suffix(3)))
        chartView.layoutIfNeeded()
        #expect(chartView.candles.count == 3)
        self.expectVisibleRangeWithinAxis(chartView)

        chartView.updateChartData([])
        chartView.layoutIfNeeded()
        #expect(chartView.candles.isEmpty)
        #expect(chartView.showsNoDataMessage)
    }

    /// 値がすべて空のレスポンスに変わっても落ちない(値のある足がないので「データなし」)
    @Test
    func testUpdateChartDataAllEmptyValues() {
        let chartView = StockChartView(frame: CGRect(origin: .zero, size: self.chartSize))
        chartView.period = .daily
        chartView.updateChartData(self.response(from: SampleData.nikkeiLike(days: self.largeCount)))
        chartView.layoutIfNeeded()

        let emptyResponse = (1...20).map { day in
            [
                "kTimestamp": String(format: "2026/10/%02d", day),
                "kStart": "", "kHeight": "", "kLow": "", "kEnd": "", "kTurnover": "",
            ]
        }
        chartView.updateChartData(emptyResponse)
        chartView.layoutIfNeeded()

        #expect(chartView.candles.isEmpty)
        #expect(chartView.showsNoDataMessage)
    }

    /// 日中足: 値のある時間帯がなくなり、日時だけになっても落ちない
    @Test
    func testUpdateChartDataIntradayOnlyEmptyDates() {
        let chartView = StockChartView(frame: CGRect(origin: .zero, size: self.chartSize))
        chartView.period = .intraday
        let candles = SampleData.candles(for: .intraday)
        chartView.setCandles(candles, period: .intraday)
        chartView.layoutIfNeeded()

        let emptyResponse = candles.prefix(30).map { candle in
            [
                "kTimestamp": self.timestampText(candle.date),
                "kStart": "", "kHeight": "", "kLow": "", "kEnd": "", "kTurnover": "",
            ]
        }
        chartView.updateChartData(emptyResponse)
        chartView.layoutIfNeeded()

        #expect(chartView.candles.isEmpty)
        #expect(chartView.showsNoDataMessage)
        #expect(chartView.leadingDates.isEmpty)
        #expect(chartView.trailingDates.isEmpty)
    }

    /// 横画面: 1000件 → 2件 → 0件 → 1000件 と渡しても落ちない。
    /// 横画面は0件を渡すとチャートを消す(縦画面と違い「データなし」のメッセージは出さない。reloadChart)
    @Test
    func testLandscapeShrink() {
        let viewController = LandscapeChartViewController.instantiate()
        viewController.market = .japanIndex
        viewController.setCandles(SampleData.nikkeiLike(days: self.largeCount), period: .daily)
        viewController.view.frame = CGRect(x: 0, y: 0, width: 844, height: 390)
        viewController.view.layoutIfNeeded()
        let response = self.response(from: SampleData.nikkeiLike(days: self.largeCount))

        viewController.updateChartData(Array(response.suffix(2)))
        viewController.view.layoutIfNeeded()
        #expect(viewController.chartView.candles.count == 2)
        self.expectVisibleRangeWithinAxis(viewController.chartView)

        viewController.updateChartData([])
        viewController.view.layoutIfNeeded()
        #expect(viewController.chartView.candles.isEmpty)
        #expect(!viewController.chartView.showsNoDataMessage)

        viewController.updateChartData(response)
        viewController.view.layoutIfNeeded()
        #expect(viewController.chartView.candles.count == self.largeCount)
        self.expectVisibleRangeWithinAxis(viewController.chartView)
    }

    // MARK: - 部品

    /// 指定のデータを日足で表示したチャートを作る(大きさは chartSize)
    private func makeChartView(candles: [StockCandle]) -> StockChartView {
        let chartView = StockChartView(frame: CGRect(origin: .zero, size: self.chartSize))
        chartView.market = .japanIndex
        chartView.setCandles(candles, period: .daily)
        chartView.layoutIfNeeded()
        return chartView
    }

    /// 見えている X軸の範囲が、スクロールできる範囲(xAxisMinimum 〜 xAxisMaximum)に収まっているか
    private func expectVisibleRangeWithinAxis(_ chartView: StockChartView,
                                              sourceLocation: SourceLocation = #_sourceLocation) {
        let priceChart = chartView.priceChartView
        let tolerance = 0.01
        #expect(priceChart.lowestVisibleX >= chartView.xAxisMinimum - tolerance, sourceLocation: sourceLocation)
        #expect(priceChart.highestVisibleX <= chartView.xAxisMaximum + tolerance, sourceLocation: sourceLocation)
        #expect(priceChart.highestVisibleX > priceChart.lowestVisibleX, sourceLocation: sourceLocation)
    }

    /// 見えている X軸の幅(本数)
    private func visibleWidth(_ chartView: StockChartView) -> Double {
        return chartView.priceChartView.highestVisibleX - chartView.priceChartView.lowestVisibleX
    }

    /// ローソク足から、API と同じ形のレスポンス(辞書の配列)を作る
    private func response(from candles: [StockCandle]) -> [[String: Any]] {
        return candles.map { candle in
            [
                "kTimestamp": self.timestampText(candle.date),
                "kStart": String(candle.open),
                "kHeight": String(candle.high),
                "kLow": String(candle.low),
                "kEnd": String(candle.close),
                "kTurnover": String(candle.volume),
            ]
        }
    }

    /// レスポンスの日時の文字列(yyyy/MM/dd HH:mm)
    private func timestampText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

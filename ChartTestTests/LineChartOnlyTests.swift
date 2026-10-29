//
//  LineChartOnlyTests.swift
//  ChartTestTests
//
//  折線チャートだけで表示する銘柄(LineChartOnlyCodes)のテスト。
//  ・縦画面(StockChartView): 対象の銘柄は、chartType に関係なく折線チャートで描く
//  ・横画面(LandscapeChartViewController): 対象の銘柄は折線チャートだけを選べ、覚えておくチャートの種類は上書きしない
//
//  ChartStateStore・LineChartOnlyCodes はアプリ全体で1つなので、テストの中で毎回最初の状態にする
//  (init で行うと、ほかのテストが init と本体の間に動くことがあるため)
//

import Testing
import UIKit
@testable import ChartTest

@Suite(.serialized)
@MainActor
struct LineChartOnlyTests {

    /// 折線チャートだけで表示する銘柄コード(テスト用)
    private let lineOnlyCode = "TEST_LINE_ONLY"

    /// 対象ではない銘柄コード(テスト用)
    private let otherCode = "TEST_OTHER"

    /// 覚えている状態と、対象の銘柄コードを最初の状態にする
    private func reset() {
        ChartStateStore.reset()
        LineChartOnlyCodes.codes = [self.lineOnlyCode]
    }

    // MARK: - 縦画面

    /// 海外の対象の銘柄は、chartType がローソク足でも折線チャートで描く
    @Test
    func testPortraitOverseasLineOnlyCode() {
        self.reset()
        let chartView = StockChartView()
        chartView.market = .overseasDaily
        chartView.chartType = .candlestick
        chartView.qCode = self.lineOnlyCode
        #expect(chartView.isLineChartOnly)
        #expect(chartView.effectiveChartType == .lineChart)
        // chartType は変えない(ほかの銘柄にすると元の種類で描く)
        #expect(chartView.chartType == .candlestick)

        chartView.qCode = self.otherCode
        #expect(!chartView.isLineChartOnly)
        #expect(chartView.effectiveChartType == .candlestick)
    }

    /// 縦画面の対象の銘柄は、終値の折線 + 移動平均線だけを描く(サブチャート・現在値の破線なし)
    @Test
    func testPortraitLineOnlyContent() {
        self.reset()
        let chartView = StockChartView(frame: CGRect(x: 0, y: 0, width: 375, height: 400))
        chartView.market = .overseasDaily
        chartView.qCode = self.lineOnlyCode
        chartView.setCandles(SampleData.candles(for: .daily), period: .daily, market: .overseasDaily)

        #expect(chartView.mainContent.priceStyle == .hidden)
        #expect(chartView.mainContent.currentPrice == nil)
        #expect(chartView.mainContent.legendTitle == "移動平均")
        #expect(chartView.subContent == nil)
    }

    /// 国内は、一覧に入っている銘柄コードでも対象にしない
    @Test
    func testPortraitDomesticIsNotLineOnly() {
        self.reset()
        let chartView = StockChartView()
        chartView.market = .japanIndex
        chartView.qCode = self.lineOnlyCode
        #expect(chartView.effectiveChartType == .candlestick)
    }

    // MARK: - 横画面

    /// 海外の対象の銘柄は折線チャートになり、メニューも折線チャートだけになる。
    /// 対象から外れると、覚えているチャートの種類(ローソク足)に戻る
    @Test
    func testLandscapeOverseasLineOnlyCode() {
        self.reset()
        let viewController = LandscapeChartViewController.instantiate()
        viewController.market = .overseasDaily
        viewController.chartType = .candlestick
        viewController.setCandles(SampleData.candles(for: viewController.period), period: viewController.period)

        viewController.qCode = self.lineOnlyCode
        #expect(viewController.chartType == .lineChart)
        #expect(viewController.chartTypeChoices == [.lineChart])

        // コードからほかの種類にしても、折線チャートのまま
        viewController.chartType = .candlestick
        #expect(viewController.chartType == .lineChart)

        // 覚えておくチャートの種類は、折線チャートで上書きしない
        #expect(ChartStateStore.state(for: .overseasDaily).chartType == .candlestick)

        viewController.qCode = self.otherCode
        #expect(viewController.chartType == .candlestick)
        #expect(viewController.chartTypeChoices == ChartType.choices(for: .overseasDaily))
    }

    /// 対象の銘柄のまま国内に切り替えると、国内で覚えている種類に戻り、すべての種類を選べる
    @Test
    func testLandscapeSwitchToDomestic() {
        self.reset()
        let viewController = LandscapeChartViewController.instantiate()
        viewController.market = .overseasDaily
        viewController.qCode = self.lineOnlyCode
        #expect(viewController.chartType == .lineChart)

        viewController.market = .japanIndex
        #expect(viewController.chartType == .candlestick)
        #expect(viewController.chartTypeChoices == ChartType.choices(for: .japanIndex))
    }
}

//
//  UpdateChartDataTests.swift
//  ChartTestTests
//
//  updateChartData:(API のレスポンスを、表示中の足種のデータとして渡す)のテスト。
//  レスポンスは、サンプルの日中足(intraday.json。chartDataFromResponse:… の結果を JSON にしたもの)を使う
//

import Testing
import UIKit
@testable import ChartTest

@Suite(.serialized)
@MainActor
struct UpdateChartDataTests {

    /// サンプルの日中足のレスポンス(辞書の配列)
    private var intradayResponse: [[String: Any]] {
        guard let url = Bundle.main.url(forResource: "intraday", withExtension: "json") else {
            return []
        }
        guard let data = try? Data(contentsOf: url) else {
            return []
        }
        guard let response = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return response
    }

    /// 縦画面: 表示中の足種(period)のデータとして描く
    @Test
    func testPortrait() {
        let response = self.intradayResponse
        #expect(!response.isEmpty)
        let chartView = StockChartView()
        chartView.period = .intraday
        chartView.updateChartData(response)
        #expect(!chartView.candles.isEmpty)
        #expect(chartView.period == .intraday)
    }

    /// 横画面: VWAP：線・日中足を選んでから開き直すと、前回の状態のまま、日中足のデータとして描く
    @Test
    func testLandscapeKeepsPreviousChart() {
        ChartStateStore.reset()
        let response = self.intradayResponse

        // 1回目: VWAP：線・日中足にする
        let first = LandscapeChartViewController.instantiate()
        first.market = .japanIndex
        first.chartType = .vwapLine
        first.setCandles(SampleData.candles(for: .intraday), period: .intraday)

        // 2回目: 開き直すと、前回の状態になっている
        let second = LandscapeChartViewController.instantiate()
        second.market = .japanIndex
        #expect(second.chartType == .vwapLine)
        #expect(second.period == .intraday)

        second.updateChartData(response)
        #expect(second.period == .intraday)
        #expect(!second.chartView.candles.isEmpty)
    }
}

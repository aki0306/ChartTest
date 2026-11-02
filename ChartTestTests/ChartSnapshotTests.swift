//
//  ChartSnapshotTests.swift
//  ChartTestTests
//
//  チャートの見た目のスナップショットテスト(Swift Testing + swift-snapshot-testing)。
//  決まったデータ(SampleData。乱数のシードが固定なので毎回同じ形)でチャートを描き、
//  保存しておいた画像(__Snapshots__/ChartSnapshotTests/)と同じになるかを比べる。
//  指標の計算や描き方を直したときに、見た目が意図せず変わっていないかを確かめるのに使う。
//
//  ・指標・足種・チャートの種類は @Test(arguments:) で渡すので、1つずつ別のテストとして結果が出る
//  ・画像のファイル名は「テスト名.名前.png」(例: testSubIndicators.rsi.png)
//
//  【画像の作り方・作り直し】
//  ・画像がまだないテストは、1回目の実行で画像を作る(そのときテストは失敗になる。2回目から比べる)
//  ・見た目をわざと変えた場合は、下の @Suite の record を .all にしてテストを1回実行すると、画像が上書きされる。
//    確認したら .missing に戻し、作り直した画像もコミットする
//
//  【実行する環境】
//  画像は、シミュレータの機種・iOS のバージョン・Mac のタイムゾーン(X軸の日付)で少し変わる。
//  画像を作ったのと同じ環境(iPhone 17e・iOS 26.5・日本時間)で実行する。
//

import SnapshotTesting
import Testing
import UIKit
@testable import ChartTest

/// .serialized: 横画面のチャートは選んだ状態をアプリ全体で覚えている(ChartStateStore)ので、テストを1つずつ順に動かす
/// .snapshots(record:): 画像の記録の方法。.missing = 画像がないときだけ作る。.all = すべて作り直す(作り直したら .missing に戻す)
@Suite(.serialized, .snapshots(record: .missing))
@MainActor
struct ChartSnapshotTests {

    /// チャートの大きさ(縦画面のチャートに近い大きさ)
    private let chartSize = CGSize(width: 390, height: 300)

    /// 画像の比べ方。描画のわずかな違い(線のふちのぼかしなど)は許す
    private var imageStrategy: Snapshotting<UIView, UIImage> {
        return .image(precision: 1, perceptualPrecision: 0.98, traits: UITraitCollection(userInterfaceStyle: .light))
    }

    init() {
        // 横画面のチャートは、選んだ状態を国内/海外ごとに覚えているので、毎回最初の状態から始める
        ChartStateStore.reset()
    }

    // MARK: - メインチャートの指標

    /// メインチャートの指標ごとに、日足のローソク足 + 指標 + 出来高 を撮る
    @Test(arguments: [
        SnapshotCase("movingAverage", MainChartIndicator.movingAverage),
        SnapshotCase("multipleMovingAverage", .multipleMovingAverage),
        SnapshotCase("bollingerBands", .bollingerBands),
        SnapshotCase("ichimoku", .ichimoku),
        SnapshotCase("parabolic", .parabolic),
        SnapshotCase("candleOnly", .candleOnly),
    ])
    func testMainIndicators(_ item: SnapshotCase<MainChartIndicator>) {
        let chartView = self.makeChartView(mainIndicator: item.value)
        assertSnapshot(of: chartView, as: self.imageStrategy, named: item.name, testName: "testMainIndicators")
    }

    // MARK: - サブチャートの指標

    /// サブチャートの指標ごとに、日足のローソク足 + 移動平均線 + 指標 を撮る
    @Test(arguments: [
        SnapshotCase("volume", SubChartIndicator.volume),
        SnapshotCase("movingAverageDeviation", .movingAverageDeviation),
        SnapshotCase("rsi", .rsi),
        SnapshotCase("psychological", .psychological),
        SnapshotCase("stochastics", .stochastics),
        SnapshotCase("macd", .macd),
        SnapshotCase("dmi", .dmi),
        SnapshotCase("hidden", .hidden),
    ])
    func testSubIndicators(_ item: SnapshotCase<SubChartIndicator>) {
        let chartView = self.makeChartView(subIndicator: item.value)
        assertSnapshot(of: chartView, as: self.imageStrategy, named: item.name, testName: "testSubIndicators")
    }

    // MARK: - 足種

    /// 足種ごとに、ローソク足 + 移動平均線 + 出来高 を撮る
    @Test(arguments: [
        SnapshotCase("oneMinute", ChartPeriod.oneMinute),
        SnapshotCase("intraday", .intraday),
        SnapshotCase("daily", .daily),
        SnapshotCase("weekly", .weekly),
        SnapshotCase("monthly", .monthly),
    ])
    func testPeriods(_ item: SnapshotCase<ChartPeriod>) {
        let chartView = self.makeChartView(period: item.value)
        assertSnapshot(of: chartView, as: self.imageStrategy, named: item.name, testName: "testPeriods")
    }

    // MARK: - チャートの種類

    /// チャートの種類ごとに撮る(VWAP は日中足、それ以外は日足)
    @Test(arguments: [
        SnapshotCase("lineChart", ChartType.lineChart),
        SnapshotCase("newPrice", .newPrice),
        SnapshotCase("vwapLine", .vwapLine),
        SnapshotCase("vwapDots", .vwapDots),
    ])
    func testChartTypes(_ item: SnapshotCase<ChartType>) {
        // VWAP は日中足だけで描けるので、日中足のデータで撮る
        var period = ChartPeriod.daily
        switch item.value {
        case .vwapLine, .vwapDots:
            period = .intraday
        case .candlestick, .newPrice, .lineChart:
            break
        }
        let chartView = self.makeChartView(period: period, chartType: item.value)
        assertSnapshot(of: chartView, as: self.imageStrategy, named: item.name, testName: "testChartTypes")
    }

    // MARK: - 海外指数

    /// 海外指数(サブチャートなし)を、ローソク足と折線チャートで撮る
    @Test(arguments: [
        SnapshotCase("candlestick", ChartType.candlestick),
        SnapshotCase("lineChart", .lineChart),
    ])
    func testOverseasMarket(_ item: SnapshotCase<ChartType>) {
        let chartView = self.makeChartView(market: .overseasRealtime, chartType: item.value)
        assertSnapshot(of: chartView, as: self.imageStrategy, named: item.name, testName: "testOverseasMarket")
    }

    // MARK: - 横画面

    /// 横画面(テクニカル/設定タブ・下の帯付き)を、最初の状態(国内指数・日足)で撮る
    @Test
    func testLandscapeScreen() {
        let viewController = LandscapeChartViewController.instantiate()
        viewController.market = .japanIndex
        viewController.setCandles(SampleData.candles(for: .daily), period: .daily)
        viewController.updatePriceInfo(name: "日経平均", price: SampleData.latestPrice, date: SampleData.latestDate)
        assertSnapshot(of: viewController, as: .image(on: .iPhone13(.landscape)), named: "1", testName: "testLandscapeScreen")
    }

    // MARK: - 部品

    /// 決まったデータでチャートを作る(大きさは chartSize)
    private func makeChartView(period: ChartPeriod = .daily,
                               market: IndexMarket = .japanIndex,
                               chartType: ChartType = .candlestick,
                               mainIndicator: MainChartIndicator = .movingAverage,
                               subIndicator: SubChartIndicator = .volume) -> StockChartView {
        let chartView = StockChartView(frame: CGRect(origin: .zero, size: self.chartSize))
        // market を変えると chartType がその指数の種類の値に戻るので、market を先に設定する
        chartView.market = market
        chartView.chartType = chartType
        chartView.mainIndicator = mainIndicator
        chartView.subIndicator = subIndicator
        chartView.setCandles(SampleData.candles(for: period), period: period, market: market)
        chartView.layoutIfNeeded()
        return chartView
    }
}

/// テストに渡す1件(画像の名前と、指標・足種などの値)。
/// テスト結果には名前が表示される(CustomTestStringConvertible)
struct SnapshotCase<Value: Sendable>: Sendable, CustomTestStringConvertible {
    /// 画像の名前(ファイル名の「テスト名.名前.png」の部分)
    let name: String
    /// 指標・足種・チャートの種類など
    let value: Value

    init(_ name: String, _ value: Value) {
        self.name = name
        self.value = value
    }

    var testDescription: String {
        return self.name
    }
}

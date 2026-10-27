//
//  TechnicalMenuTests.swift
//  ChartTestTests
//
//  横画面の「テクニカル」タブ(指標の選択メニュー)のテスト。
//  ・タブ・背景のグレーでの開閉と、設定タブとの切り替え
//  ・指数の種類・足種・チャートの種類ごとに、メニューに並ぶ指標
//  ・指標を押したときのチャートへの反映と、選べなくなったときの切り替え
//  ・選んだ指標を国内/海外ごとに覚えること
//

import Testing
import UIKit
@testable import ChartTest

@Suite(.serialized)
@MainActor
struct TechnicalMenuTests {

    private typealias Support = LandscapeTestSupport

    init() {
        // 選んだ状態はアプリ全体で覚えているので、毎回最初の状態から始める
        ChartStateStore.reset()
    }

    // MARK: - 開閉

    /// タブを押すと開き、もう一度押すと閉じる(閉じたあとはメニューと背景のグレーが隠れる)
    @Test
    func testTabTogglesMenu() async throws {
        let viewController = Support.makeViewController()

        Support.tap(viewController.technicalTabButton)
        #expect(viewController.openPanel == .technical)
        #expect(!viewController.menuView.isHidden)
        #expect(!viewController.dimmingView.isHidden)
        #expect(viewController.tabTechnicalOpenedConstraint?.isActive == true)

        Support.tap(viewController.technicalTabButton)
        #expect(viewController.openPanel == nil)
        #expect(viewController.tabClosedConstraint?.isActive == true)
        try await Task.sleep(for: Support.animationWait)
        #expect(viewController.menuView.isHidden)
        #expect(viewController.dimmingView.isHidden)
    }

    /// 背景のグレーを押したときと同じ closePanels で閉じる
    @Test
    func testClosePanels() async throws {
        let viewController = Support.makeViewController()
        Support.tap(viewController.technicalTabButton)

        viewController.closePanels()

        #expect(viewController.openPanel == nil)
        try await Task.sleep(for: Support.animationWait)
        #expect(viewController.menuView.isHidden)
        #expect(viewController.dimmingView.isHidden)
    }

    /// テクニカルを開いたまま設定タブを押すと、設定画面に切り替わる(テクニカルは閉じる)
    @Test
    func testSwitchToSettings() async throws {
        let viewController = Support.makeViewController()
        Support.tap(viewController.technicalTabButton)

        Support.tap(viewController.settingsTabButton)

        #expect(viewController.openPanel == .settings)
        #expect(viewController.tabSettingsOpenedConstraint?.isActive == true)
        #expect(viewController.tabTechnicalOpenedConstraint?.isActive == false)
        try await Task.sleep(for: Support.animationWait)
        #expect(viewController.menuView.isHidden)
        #expect(!viewController.settingsView.isHidden)
        #expect(!viewController.dimmingView.isHidden)
    }

    /// 開いた・閉じたの知らせは1回ずつ。パネルを切り替えただけでは知らせない
    @Test
    func testPanelVisibilityCallback() async throws {
        let viewController = Support.makeViewController()
        var events: [Bool] = []
        viewController.onPanelVisibilityChange = { isOpen in
            events.append(isOpen)
        }

        Support.tap(viewController.technicalTabButton)
        #expect(events == [true])
        Support.tap(viewController.settingsTabButton)
        try await Task.sleep(for: Support.animationWait)
        #expect(events == [true])

        viewController.closePanels()
        try await Task.sleep(for: Support.animationWait)
        #expect(events == [true, false])
    }

    // MARK: - メニューに並ぶ指標

    /// 指数の種類・足種ごとに、選べる指標だけがメニューに並ぶ
    @Test(arguments: [IndexMarket.japanStock, .japanIndex, .overseasRealtime, .overseasDaily])
    func testMenuChoices(market: IndexMarket) {
        let viewController = Support.makeViewController(market: market)
        // 海外指数の既定は折線チャートではなくローソク足だが、念のためローソク足にする
        viewController.chartType = .candlestick

        for period in market.periods {
            viewController.setCandles(SampleData.candles(for: period), period: period)

            let expectedMain = MainChartIndicator.choices(for: market, period: period).map { indicator in indicator.title }
            let expectedSub = SubChartIndicator.choices(for: market, period: period).map { indicator in indicator.title }
            #expect(Support.mainMenuTitles(of: viewController) == expectedMain, "\(market) \(period)")
            #expect(Support.subMenuTitles(of: viewController) == expectedSub, "\(market) \(period)")
        }
    }

    /// 国内の日足は、メイン6種類・サブ8種類がすべて並ぶ
    @Test
    func testDomesticDailyShowsAllIndicators() {
        let viewController = Support.makeViewController()

        #expect(Support.mainMenuTitles(of: viewController) == MainChartIndicator.allCases.map { indicator in indicator.title })
        #expect(Support.subMenuTitles(of: viewController) == SubChartIndicator.allCases.map { indicator in indicator.title })
    }

    /// 指標を重ねられないチャートの種類(国内の VWAP・新値足・折線チャート)は、メイン・サブとも「なし」だけ。
    /// 押しても何も変わらない
    @Test(arguments: [ChartType.vwapLine, .vwapDots, .newPrice, .lineChart])
    func testOnlyNoneForChartTypeWithoutIndicators(chartType: ChartType) {
        let viewController = Support.makeViewController()

        viewController.chartType = chartType

        #expect(Support.mainMenuTitles(of: viewController) == ["なし"])
        #expect(Support.subMenuTitles(of: viewController) == ["なし"])
        #expect(viewController.mainIndicator == .candleOnly)
        #expect(viewController.subIndicator == .hidden)

        Support.tapMenu(MainChartIndicator.candleOnly, in: viewController)
        Support.tapMenu(SubChartIndicator.hidden, in: viewController)
        #expect(viewController.mainIndicator == .candleOnly)
        #expect(viewController.subIndicator == .hidden)
    }

    /// ローソク足に戻すと、すべての指標が並ぶ(指標は「なし」のまま。前に選んでいた指標には戻さない)
    @Test
    func testBackToCandlestick() {
        let viewController = Support.makeViewController()
        Support.tapMenu(MainChartIndicator.bollingerBands, in: viewController)
        viewController.chartType = .newPrice

        viewController.chartType = .candlestick

        #expect(Support.mainMenuTitles(of: viewController).count == MainChartIndicator.allCases.count)
        #expect(Support.subMenuTitles(of: viewController).count == SubChartIndicator.allCases.count)
        #expect(viewController.mainIndicator == .candleOnly)
        #expect(viewController.subIndicator == .hidden)
    }

    /// 海外指数の折線チャートは、指標を重ねられる(移動平均線・なし)
    @Test
    func testOverseasLineChartAllowsIndicators() {
        let viewController = Support.makeViewController(market: .overseasRealtime)

        viewController.chartType = .lineChart

        #expect(Support.mainMenuTitles(of: viewController) == ["移動平均線", "なし"])
        #expect(Support.subMenuTitles(of: viewController) == ["なし"])
        Support.tapMenu(MainChartIndicator.candleOnly, in: viewController)
        #expect(viewController.mainIndicator == .candleOnly)
    }

    // MARK: - 指標を押したとき

    /// メインの指標を押すと、その指標でチャートを描き直す(メニューは開いたまま・選んだ行が選択中になる)
    @Test(arguments: MainChartIndicator.allCases)
    func testSelectMainIndicator(indicator: MainChartIndicator) {
        let viewController = Support.makeViewController()
        Support.tap(viewController.technicalTabButton)

        Support.tapMenu(indicator, in: viewController)

        #expect(viewController.mainIndicator == indicator)
        #expect(viewController.menuView.selectedMainIndicator == indicator)
        #expect(viewController.openPanel == .technical)
        let builder = ChartContentBuilder(candles: SampleData.candles(for: .daily), parameters: viewController.parameters)
        let expected = builder.mainContent(for: indicator).series.map { series in series.label }
        #expect(Support.mainSeriesLabels(of: viewController) == expected)
        self.expectSelectedRow(column: "technicalMenu.main.", title: indicator.title, in: viewController)
    }

    /// サブの指標を押すと、その指標でチャートを描き直す(「なし」はサブチャートを隠す)
    @Test(arguments: SubChartIndicator.allCases)
    func testSelectSubIndicator(indicator: SubChartIndicator) {
        let viewController = Support.makeViewController()

        Support.tapMenu(indicator, in: viewController)

        #expect(viewController.subIndicator == indicator)
        #expect(viewController.menuView.selectedSubIndicator == indicator)
        let builder = ChartContentBuilder(candles: SampleData.candles(for: .daily), parameters: viewController.parameters)
        let expected = builder.subContent(for: indicator)?.series.map { series in series.label }
        #expect(Support.subSeriesLabels(of: viewController) == expected)
        if indicator == .hidden {
            #expect(!viewController.chartView.hasSubChart)
        } else {
            #expect(viewController.chartView.hasSubChart)
        }
        self.expectSelectedRow(column: "technicalMenu.sub.", title: indicator.title, in: viewController)
    }

    /// 同じ指標をもう一度押しても、何も変わらない
    @Test
    func testSelectSameIndicatorAgain() {
        let viewController = Support.makeViewController()
        Support.tapMenu(MainChartIndicator.ichimoku, in: viewController)
        let labels = Support.mainSeriesLabels(of: viewController)

        Support.tapMenu(MainChartIndicator.ichimoku, in: viewController)

        #expect(viewController.mainIndicator == .ichimoku)
        #expect(Support.mainSeriesLabels(of: viewController) == labels)
    }

    // MARK: - 選べなくなったとき

    /// 日足で 一目均衡表 + MACD を表示中に 1分足・日中足 にすると、移動平均線 + 出来高 になる
    @Test(arguments: [ChartPeriod.oneMinute, .intraday])
    func testFallbackWhenPeriodChanges(period: ChartPeriod) {
        let viewController = Support.makeViewController()
        Support.tapMenu(MainChartIndicator.ichimoku, in: viewController)
        Support.tapMenu(SubChartIndicator.macd, in: viewController)

        viewController.setCandles(SampleData.candles(for: period), period: period)

        #expect(viewController.mainIndicator == .movingAverage)
        #expect(viewController.subIndicator == .volume)
        #expect(viewController.menuView.selectedMainIndicator == .movingAverage)
        #expect(viewController.menuView.selectedSubIndicator == .volume)
    }

    /// 1分足・日中足でも選べる指標(なし + なし)は、そのまま
    @Test
    func testNoFallbackWhenStillAvailable() {
        let viewController = Support.makeViewController()
        Support.tapMenu(MainChartIndicator.candleOnly, in: viewController)
        Support.tapMenu(SubChartIndicator.hidden, in: viewController)

        viewController.setCandles(SampleData.candles(for: .intraday), period: .intraday)

        #expect(viewController.mainIndicator == .candleOnly)
        #expect(viewController.subIndicator == .hidden)
    }

    /// 1分足から日足に戻しても、自動で切り替えた指標(移動平均線 + 出来高)のまま
    @Test
    func testFallbackIsNotUndone() {
        let viewController = Support.makeViewController()
        Support.tapMenu(SubChartIndicator.rsi, in: viewController)
        viewController.setCandles(SampleData.candles(for: .oneMinute), period: .oneMinute)

        viewController.setCandles(SampleData.candles(for: .daily), period: .daily)

        #expect(viewController.subIndicator == .volume)
    }

    // MARK: - 覚えておく

    /// 選んだ指標は、画面を作り直しても残る
    @Test
    func testIndicatorsAreRemembered() {
        let first = Support.makeViewController()
        Support.tapMenu(MainChartIndicator.bollingerBands, in: first)
        Support.tapMenu(SubChartIndicator.stochastics, in: first)

        let second = Support.makeViewController()

        #expect(second.mainIndicator == .bollingerBands)
        #expect(second.subIndicator == .stochastics)
        self.expectSelectedRow(column: "technicalMenu.main.", title: "ボリンジャーバンド", in: second)
        self.expectSelectedRow(column: "technicalMenu.sub.", title: "ストキャス", in: second)
    }

    /// 国内と海外で別々に覚え、切り替えて戻すと前の指標に戻る
    @Test
    func testIndicatorsPerMarket() {
        let viewController = Support.makeViewController()
        Support.tapMenu(MainChartIndicator.parabolic, in: viewController)
        Support.tapMenu(SubChartIndicator.dmi, in: viewController)

        viewController.market = .overseasRealtime
        #expect(viewController.mainIndicator == .movingAverage)
        #expect(viewController.subIndicator == .hidden)
        Support.tapMenu(MainChartIndicator.candleOnly, in: viewController)

        viewController.market = .japanIndex
        #expect(viewController.mainIndicator == .parabolic)
        #expect(viewController.subIndicator == .dmi)

        viewController.market = .overseasDaily
        #expect(viewController.mainIndicator == .candleOnly)
    }

    /// 国内どうし(日本株 ⇔ 日本株価指数)の切り替えでは、指標はそのまま
    @Test
    func testIndicatorsKeptBetweenDomesticMarkets() {
        let viewController = Support.makeViewController(market: .japanStock)
        Support.tapMenu(SubChartIndicator.psychological, in: viewController)

        viewController.market = .japanIndex

        #expect(viewController.subIndicator == .psychological)
    }

    // MARK: - 部品

    /// 指定した列(column)で、指定した名称の行だけが選択中の見た目(グレー背景)か
    private func expectSelectedRow(column: String, title: String, in viewController: LandscapeChartViewController,
                                   sourceLocation: SourceLocation = #_sourceLocation) {
        let selectedColor = UIColor(resource: .chartMenuSelectedRow)
        let buttons = Support.buttons(identifierPrefix: column, in: viewController.menuView)
        #expect(!buttons.isEmpty, sourceLocation: sourceLocation)
        for button in buttons {
            let isSelected = button.configuration?.background.backgroundColor == selectedColor
            let isTarget = button.accessibilityIdentifier == column + title
            #expect(isSelected == isTarget, "\(button.accessibilityIdentifier ?? "")", sourceLocation: sourceLocation)
        }
    }
}

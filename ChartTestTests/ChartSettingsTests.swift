//
//  ChartSettingsTests.swift
//  ChartTestTests
//
//  横画面の「設定」タブ(設定画面)のテスト。
//  ・開いたときの状態(項目・足種のタブ・行)と、指数の種類ごとのリスト
//  ・表示オプションのトグル(すぐ反映する)
//  ・指標のパラメータ(−/+・スライダー・範囲の端・足種ごとの編集・「すべての足に反映」・「初期値に戻す」・「決定」)
//  ・決定せずに閉じたときに捨てること、国内/海外ごとに覚えること
//  ・すべての項目・パラメータを、範囲の端(最小・最大)にしても描けること
//

import Testing
import UIKit
@testable import ChartTest

@Suite(.serialized)
@MainActor
struct ChartSettingsTests {

    private typealias Support = LandscapeTestSupport

    init() {
        // 選んだ状態はアプリ全体で覚えているので、毎回最初の状態から始める
        ChartStateStore.reset()
    }

    // MARK: - 開いたとき

    /// 開いた直後は「オプション」が選ばれ、足種のタブと下のボタンは隠れ、トグルが並ぶ
    @Test(arguments: [IndexMarket.japanIndex, .overseasRealtime])
    func testOpenShowsOptions(market: IndexMarket) {
        let viewController = Support.makeViewController(market: market)

        Support.tap(viewController.settingsTabButton)

        #expect(viewController.openPanel == .settings)
        #expect(!viewController.settingsView.isHidden)
        #expect(viewController.selectedSettingsItem == .displayOptions)
        #expect(!viewController.settingsView.showsPeriodControls)
        let titles = Support.toggleRows(of: viewController).map { row in row.titleLabel.text ?? "" }
        #expect(titles == ChartDisplayOption.options(for: market).map { option in option.title })
        #expect(Support.stepperRows(of: viewController).isEmpty)
    }

    /// 左側リストの見出しと項目は、指数の種類で変わる(海外は オプション・移動平均線 だけ)
    @Test(arguments: [IndexMarket.japanStock, .japanIndex, .overseasRealtime, .overseasDaily])
    func testListSections(market: IndexMarket) {
        let viewController = Support.makeViewController(market: market)

        let sections = viewController.settingsView.sections
        let expected = ChartSettingsCatalog.sections(for: market)
        #expect(sections.map { section in section.title } == expected.map { section in section.title })
        #expect(sections.map { section in section.items } == expected.map { section in section.items.map { item in item.title } })
        #expect(viewController.settingsView.periods == market.periods)
    }

    /// 左側リストの各項目を選ぶと、その項目のパラメータの行が並び、足種のタブと下のボタンが出る
    @Test
    func testSelectEachItem() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)

        for section in ChartSettingsCatalog.sections(for: .japanIndex) {
            for item in section.items where item != .displayOptions {
                Support.selectSettingsItem(item, in: viewController)

                #expect(viewController.selectedSettingsItem == item)
                #expect(viewController.settingsView.showsPeriodControls, "\(item.title)")
                let fields = ChartSettingsCatalog.fields(for: item)
                let titles = Support.stepperRows(of: viewController).map { row in row.titleLabel.text ?? "" }
                #expect(titles == fields.map { field in field.title }, "\(item.title)")
                let values = Support.stepperRows(of: viewController).map { row in
                    Double(Support.slider(of: row)?.value ?? -1)
                }
                let daily = ChartPeriod.daily.indicatorParameters
                #expect(values == fields.map { field in field.value(in: daily) }, "\(item.title)")
            }
        }
    }

    /// 移動平均線はすべての足種を設定できる。それ以外の項目は 1分足・日中足 がグレーで押せない
    @Test
    func testDisabledPeriods() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)

        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        #expect(viewController.settingsView.disabledPeriods.isEmpty)
        #expect(Support.periodTabButtons(of: viewController).count == ChartPeriod.allCases.count)
        #expect(Support.periodTabButtons(of: viewController).allSatisfy { button in button.isEnabled })

        Support.selectSettingsItem(.sub(.rsi), in: viewController)
        #expect(viewController.settingsView.disabledPeriods == [.oneMinute, .intraday])
        for button in Support.periodTabButtons(of: viewController) {
            let isMinuteTab = [ChartPeriod.oneMinute.title, ChartPeriod.intraday.title].contains(button.title(for: .normal))
            #expect(button.isEnabled == !isMinuteTab, "\(button.title(for: .normal) ?? "")")
        }
    }

    /// 開いたときの足種のタブは、表示中の足種。週足なら週足の値が並ぶ
    @Test
    func testOpenUsesCurrentPeriod() {
        let viewController = Support.makeViewController(period: .weekly)
        Support.tap(viewController.settingsTabButton)

        Support.selectSettingsItem(.main(.movingAverage), in: viewController)

        #expect(viewController.settingsView.selectedPeriod == .weekly)
        #expect(self.sliderValues(of: viewController) == [13, 26])
    }

    /// 日中足を表示中に、日中足を設定できない項目を選ぶと、タブは日足になる
    @Test
    func testUnavailablePeriodSwitchesToDaily() {
        let viewController = Support.makeViewController(period: .intraday)
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        #expect(viewController.settingsView.selectedPeriod == .intraday)

        Support.selectSettingsItem(.sub(.macd), in: viewController)

        #expect(viewController.settingsPeriod == .daily)
        #expect(viewController.settingsView.selectedPeriod == .daily)
    }

    /// 開き直すと、足種のタブは表示中の足種に戻る(前に開いたときに選んだタブではない)
    @Test
    func testReopenResetsPeriodTab() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        Support.tapPeriodTab(.monthly, in: viewController)
        #expect(viewController.settingsPeriod == .monthly)

        Support.tap(viewController.settingsTabButton)
        Support.tap(viewController.settingsTabButton)

        #expect(viewController.settingsPeriod == .daily)
        #expect(viewController.settingsView.selectedPeriod == .daily)
    }

    /// 足種のタブで、選択中のタブを押し直しても何も起きない
    @Test
    func testTapSelectedPeriodTab() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        let rows = Support.stepperRows(of: viewController)
        #expect(rows.count == 2)

        Support.tapPeriodTab(.daily, in: viewController)

        // 行を作り直していない(同じ View のまま)
        #expect(Support.stepperRows(of: viewController) == rows)
    }

    // MARK: - 表示オプション

    /// トグルを切り替えると、決定を押さなくてもすぐチャートに反映する(閉じても残る)
    @Test(arguments: ChartDisplayOption.allCases)
    func testToggleOption(option: ChartDisplayOption) async throws {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        let options = ChartDisplayOption.options(for: .japanIndex)
        guard let index = options.firstIndex(of: option) else {
            Issue.record("国内指数に \(option) がない")
            return
        }

        Support.setToggle(Support.toggleRows(of: viewController)[index], isOn: true)

        #expect(viewController.displayOptions[keyPath: option.keyPath])
        #expect(viewController.chartView.displayOptions[keyPath: option.keyPath])
        // ほかのオプションは変わらない
        for other in options where other != option {
            #expect(!viewController.displayOptions[keyPath: other.keyPath])
        }

        viewController.closePanels()
        try await Task.sleep(for: Support.animationWait)
        #expect(viewController.displayOptions[keyPath: option.keyPath])
        #expect(ChartStateStore.state(for: .japanIndex).displayOptions[keyPath: option.keyPath])

        // オフに戻せる
        Support.tap(viewController.settingsTabButton)
        Support.setToggle(Support.toggleRows(of: viewController)[index], isOn: false)
        #expect(!viewController.displayOptions[keyPath: option.keyPath])
        #expect(!viewController.chartView.displayOptions[keyPath: option.keyPath])
    }

    /// 海外指数は トグルが2つ(Y軸(メイン)固定・4本値)。2つ目は4本値につながる
    @Test
    func testOverseasToggles() {
        let viewController = Support.makeViewController(market: .overseasRealtime)
        viewController.chartType = .candlestick
        Support.tap(viewController.settingsTabButton)
        let rows = Support.toggleRows(of: viewController)
        #expect(rows.count == 2)

        Support.setToggle(rows[1], isOn: true)

        #expect(viewController.displayOptions.showsOHLC)
        #expect(!viewController.displayOptions.isSubYAxisFixed)
        #expect(viewController.chartView.displayOptions.showsOHLC)
    }

    /// 4本値はローソク足のときだけ効く(設定の値は残り、ローソク足に戻すと効く)
    @Test
    func testOHLCOnlyForCandlestick() {
        let viewController = Support.makeViewController()
        viewController.showsOHLC = true

        viewController.chartType = .lineChart
        #expect(viewController.displayOptions.showsOHLC)
        #expect(!viewController.chartView.displayOptions.showsOHLC)

        viewController.chartType = .candlestick
        #expect(viewController.chartView.displayOptions.showsOHLC)
    }

    /// Y軸(サブ)固定は、海外指数ではオンにしていても効かない
    @Test
    func testSubYAxisFixedIgnoredOverseas() {
        let viewController = Support.makeViewController(market: .overseasRealtime)
        viewController.isSubYAxisFixed = true

        #expect(viewController.displayOptions.isSubYAxisFixed)
        #expect(!viewController.chartView.displayOptions.isSubYAxisFixed)
    }

    /// オプションを表示中に外から値を変えると、トグルの状態も合わせる
    @Test
    func testTogglesFollowExternalChange() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)

        viewController.isMainYAxisFixed = true

        let toggle = Support.subviews(of: UISwitch.self, in: Support.toggleRows(of: viewController)[0]).first
        #expect(toggle?.isOn == true)
    }

    // MARK: - −/+・スライダー

    /// + を押すと編集中の値だけが変わり、チャートは「決定」を押すまで変わらない
    @Test
    func testPlusChangesDraftOnly() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)

        Support.tap(Support.plusButton(of: Support.stepperRows(of: viewController)[0]))

        #expect(viewController.draftParametersByPeriod[.daily]?.shortMAPeriod == 6)
        #expect(viewController.parameters.shortMAPeriod == 5)
        #expect(Support.mainSeriesLabels(of: viewController).contains("短期移動平均(5)"))
    }

    /// − を押すと1つ減る
    @Test
    func testMinus() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)

        Support.tap(Support.minusButton(of: Support.stepperRows(of: viewController)[1]))

        #expect(viewController.draftParametersByPeriod[.daily]?.longMAPeriod == 24)
    }

    /// 範囲の下限では − が、上限では + が押せない。押しても範囲の外にはならない
    @Test
    func testRangeEdges() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        let row = Support.stepperRows(of: viewController)[0]

        Support.slide(row, to: 1)
        #expect(viewController.draftParametersByPeriod[.daily]?.shortMAPeriod == 1)
        #expect(Support.minusButton(of: row)?.isEnabled == false)
        #expect(Support.plusButton(of: row)?.isEnabled == true)
        Support.tap(Support.minusButton(of: row))
        #expect(viewController.draftParametersByPeriod[.daily]?.shortMAPeriod == 1)

        Support.slide(row, to: 99)
        #expect(viewController.draftParametersByPeriod[.daily]?.shortMAPeriod == 99)
        #expect(Support.plusButton(of: row)?.isEnabled == false)
        Support.tap(Support.plusButton(of: row))
        #expect(viewController.draftParametersByPeriod[.daily]?.shortMAPeriod == 99)
    }

    /// スライダーは刻み(1)に合わせて丸める
    @Test(arguments: [(25.4, 25), (25.5, 26), (1.2, 1), (98.6, 99)])
    func testSliderRounding(position: Double, expected: Int) {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        let row = Support.stepperRows(of: viewController)[1]

        Support.slide(row, to: position)

        #expect(viewController.draftParametersByPeriod[.daily]?.longMAPeriod == expected)
        #expect(Support.slider(of: row)?.value == Float(expected))
    }

    /// 移動平均乖離率の底値ラインは マイナスの範囲(−99〜1)
    @Test
    func testNegativeRange() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.sub(.movingAverageDeviation), in: viewController)
        let row = Support.stepperRows(of: viewController)[2]

        Support.slide(row, to: -99)
        #expect(viewController.draftParametersByPeriod[.daily]?.deviationLowerLine == -99)
        Support.slide(row, to: 1)
        #expect(viewController.draftParametersByPeriod[.daily]?.deviationLowerLine == 1)
    }

    // MARK: - 「決定」・閉じる

    /// 「決定」で編集中の値をチャートに反映し、設定画面を閉じる
    @Test
    func testConfirm() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        Support.tap(Support.plusButton(of: Support.stepperRows(of: viewController)[0]))

        Support.tapSettingsButton("settings.confirmButton", in: viewController)

        #expect(viewController.parameters.shortMAPeriod == 6)
        #expect(Support.mainSeriesLabels(of: viewController).contains("短期移動平均(6)"))
        #expect(viewController.openPanel == nil)
        #expect(ChartStateStore.state(for: .japanIndex).parametersByPeriod[.daily]?.shortMAPeriod == 6)
    }

    /// サブチャートの指標の値も、決定でチャートに反映する(表示中の指標の凡例が変わる)
    @Test
    func testConfirmSubIndicator() {
        let viewController = Support.makeViewController()
        Support.tapMenu(SubChartIndicator.rsi, in: viewController)
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.sub(.rsi), in: viewController)
        Support.slide(Support.stepperRows(of: viewController)[0], to: 9)

        Support.tapSettingsButton("settings.confirmButton", in: viewController)

        #expect(Support.subSeriesLabels(of: viewController)?.contains("期間(9)") == true)
    }

    /// 決定せずに閉じる(タブ・背景のグレー)と、変更は捨てる。開き直すと元の値が並ぶ
    @Test(arguments: [true, false])
    func testCloseWithoutConfirmDiscards(closesByTab: Bool) {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        Support.slide(Support.stepperRows(of: viewController)[0], to: 40)

        if closesByTab {
            Support.tap(viewController.settingsTabButton)
        } else {
            viewController.closePanels()
        }
        #expect(viewController.parameters.shortMAPeriod == 5)

        Support.tap(viewController.settingsTabButton)
        #expect(viewController.selectedSettingsItem == .main(.movingAverage))
        #expect(self.sliderValues(of: viewController) == [5, 25])
        #expect(viewController.draftParametersByPeriod[.daily]?.shortMAPeriod == 5)
    }

    /// テクニカルに切り替えて閉じた場合も、変更は捨てる
    @Test
    func testSwitchToTechnicalDiscards() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        Support.slide(Support.stepperRows(of: viewController)[0], to: 40)

        Support.tap(viewController.technicalTabButton)
        Support.tap(viewController.settingsTabButton)

        #expect(viewController.parameters.shortMAPeriod == 5)
        #expect(self.sliderValues(of: viewController) == [5, 25])
    }

    /// 何も変えずに決定しても、値は変わらない
    @Test
    func testConfirmWithoutChanges() {
        let viewController = Support.makeViewController()
        let before = viewController.parametersByPeriod
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)

        Support.tapSettingsButton("settings.confirmButton", in: viewController)

        #expect(viewController.parametersByPeriod == before)
    }

    // MARK: - 足種ごと

    /// 足種のタブを切り替えながら編集すると、足種ごとに別々の値になる(決定で全部反映する)
    @Test
    func testEditPerPeriod() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)

        Support.slide(Support.stepperRows(of: viewController)[0], to: 7)
        Support.tapPeriodTab(.weekly, in: viewController)
        #expect(self.sliderValues(of: viewController) == [13, 26])
        Support.slide(Support.stepperRows(of: viewController)[0], to: 14)
        Support.tapPeriodTab(.daily, in: viewController)
        #expect(self.sliderValues(of: viewController) == [7, 25])

        Support.tapSettingsButton("settings.confirmButton", in: viewController)

        #expect(viewController.parametersByPeriod[.daily]?.shortMAPeriod == 7)
        #expect(viewController.parametersByPeriod[.weekly]?.shortMAPeriod == 14)
        #expect(viewController.parametersByPeriod[.monthly]?.shortMAPeriod == 5)
        #expect(viewController.parametersByPeriod[.oneMinute]?.shortMAPeriod == 5)
    }

    /// 表示中でない足種の値を変えて決定すると、その足種のデータを渡したときに使われる
    @Test
    func testConfirmOtherPeriodUsedLater() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        Support.tapPeriodTab(.monthly, in: viewController)
        Support.slide(Support.stepperRows(of: viewController)[0], to: 3)
        Support.tapSettingsButton("settings.confirmButton", in: viewController)
        #expect(Support.mainSeriesLabels(of: viewController).contains("短期移動平均(5)"))

        viewController.setCandles(SampleData.candles(for: .monthly), period: .monthly)

        #expect(Support.mainSeriesLabels(of: viewController).contains("短期移動平均(3)"))
    }

    // MARK: - 「すべての足に反映」

    /// 移動平均線: 表示中の値を、すべての足種(1分足〜月足)にコピーする。長期の値もコピーする
    @Test
    func testApplyToAllPeriodsMovingAverage() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        Support.slide(Support.stepperRows(of: viewController)[0], to: 8)

        Support.tapSettingsButton("settings.applyToAllButton", in: viewController)
        Support.tapSettingsButton("settings.confirmButton", in: viewController)

        for period in ChartPeriod.allCases {
            #expect(viewController.parametersByPeriod[period]?.shortMAPeriod == 8, "\(period)")
            #expect(viewController.parametersByPeriod[period]?.longMAPeriod == 25, "\(period)")
        }
    }

    /// 移動平均線以外: 日足・週足・月足だけにコピーする(1分足・日中足は変えない)。ほかの項目の値は変えない
    @Test
    func testApplyToAllPeriodsRSI() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.sub(.rsi), in: viewController)
        Support.slide(Support.stepperRows(of: viewController)[0], to: 20)

        Support.tapSettingsButton("settings.applyToAllButton", in: viewController)
        Support.tapSettingsButton("settings.confirmButton", in: viewController)

        for period in [ChartPeriod.daily, .weekly, .monthly] {
            #expect(viewController.parametersByPeriod[period]?.rsiPeriod == 20, "\(period)")
            #expect(viewController.parametersByPeriod[period]?.shortMAPeriod == period.indicatorParameters.shortMAPeriod)
        }
        for period in [ChartPeriod.oneMinute, .intraday] {
            #expect(viewController.parametersByPeriod[period]?.rsiPeriod == 14, "\(period)")
        }
    }

    /// 海外指数の移動平均線: 1分足・日中足 は使わないので、日足・週足・月足だけにコピーする
    @Test
    func testApplyToAllPeriodsOverseas() {
        let viewController = Support.makeViewController(market: .overseasRealtime)
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        #expect(viewController.settingsView.periods == [.daily, .weekly, .monthly])
        Support.slide(Support.stepperRows(of: viewController)[0], to: 8)

        Support.tapSettingsButton("settings.applyToAllButton", in: viewController)
        Support.tapSettingsButton("settings.confirmButton", in: viewController)

        for period in [ChartPeriod.daily, .weekly, .monthly] {
            #expect(viewController.parametersByPeriod[period]?.shortMAPeriod == 8, "\(period)")
        }
        #expect(viewController.parametersByPeriod[.oneMinute]?.shortMAPeriod == 5)
    }

    /// 「すべての足に反映」だけでは、決定するまでチャートに反映しない(閉じれば捨てる)
    @Test
    func testApplyToAllWithoutConfirm() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        Support.slide(Support.stepperRows(of: viewController)[0], to: 8)

        Support.tapSettingsButton("settings.applyToAllButton", in: viewController)
        viewController.closePanels()

        for period in ChartPeriod.allCases {
            #expect(viewController.parametersByPeriod[period] == period.indicatorParameters, "\(period)")
        }
    }

    // MARK: - 「初期値に戻す」

    /// 表示中の足種の、選択中の項目だけを初期値に戻す(ほかの足種・ほかの項目の編集中の値は残す)
    @Test
    func testReset() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        // 週足の RSI と移動平均線、日足の移動平均線を変える
        Support.selectSettingsItem(.sub(.rsi), in: viewController)
        Support.tapPeriodTab(.weekly, in: viewController)
        Support.slide(Support.stepperRows(of: viewController)[0], to: 30)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        Support.slide(Support.stepperRows(of: viewController)[0], to: 3)
        Support.slide(Support.stepperRows(of: viewController)[1], to: 50)
        Support.tapPeriodTab(.daily, in: viewController)
        Support.slide(Support.stepperRows(of: viewController)[0], to: 9)
        Support.tapPeriodTab(.weekly, in: viewController)

        Support.tapSettingsButton("settings.resetButton", in: viewController)

        // 週足の初期値(13 / 26)が並ぶ
        #expect(self.sliderValues(of: viewController) == [13, 26])
        let draft = viewController.draftParametersByPeriod
        #expect(draft[.weekly]?.shortMAPeriod == 13)
        #expect(draft[.weekly]?.longMAPeriod == 26)
        #expect(draft[.weekly]?.rsiPeriod == 30)
        #expect(draft[.daily]?.shortMAPeriod == 9)
    }

    /// 決定済みの値も、「初期値に戻す」→「決定」で初期値に戻せる
    @Test
    func testResetConfirmedValue() {
        let viewController = Support.makeViewController()
        viewController.shortMAPeriod = 40
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        #expect(self.sliderValues(of: viewController) == [40, 25])

        Support.tapSettingsButton("settings.resetButton", in: viewController)
        Support.tapSettingsButton("settings.confirmButton", in: viewController)

        #expect(viewController.parameters.shortMAPeriod == 5)
    }

    // MARK: - 覚えておく

    /// 決定した値は、画面を作り直しても残る
    @Test
    func testParametersAreRemembered() {
        let first = Support.makeViewController()
        Support.tap(first.settingsTabButton)
        Support.selectSettingsItem(.sub(.macd), in: first)
        Support.slide(Support.stepperRows(of: first)[2], to: 12)
        Support.tapSettingsButton("settings.confirmButton", in: first)

        let second = Support.makeViewController()

        #expect(second.parameters.macdSignalPeriod == 12)
    }

    /// 国内と海外で別々に覚える
    @Test
    func testParametersPerMarket() {
        let viewController = Support.makeViewController()
        viewController.shortMAPeriod = 11

        viewController.market = .overseasRealtime
        #expect(viewController.parameters.shortMAPeriod == 5)
        viewController.shortMAPeriod = 22

        viewController.market = .japanIndex
        #expect(viewController.parameters.shortMAPeriod == 11)
        viewController.market = .overseasDaily
        #expect(viewController.parameters.shortMAPeriod == 22)
    }

    /// 表示オプションも国内と海外で別々に覚える
    @Test
    func testDisplayOptionsPerMarket() {
        let viewController = Support.makeViewController()
        viewController.showsOHLC = true

        viewController.market = .overseasRealtime
        #expect(!viewController.showsOHLC)

        viewController.market = .japanIndex
        #expect(viewController.showsOHLC)
    }

    // MARK: - 指数の種類を切り替えたとき

    /// 移動平均線を選んだまま海外に切り替えると、移動平均線の選択は残り、足種のタブは3つになる
    @Test
    func testMarketSwitchKeepsMovingAverage() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)

        viewController.market = .overseasRealtime

        #expect(viewController.selectedSettingsItem == .main(.movingAverage))
        #expect(viewController.selectedSettingsIndexPath == IndexPath(row: 0, section: 1))
        #expect(viewController.settingsView.periods == [.daily, .weekly, .monthly])
        #expect(Support.stepperRows(of: viewController).count == 2)
    }

    /// 1分足のタブで移動平均線を編集中に海外に切り替えると、タブは日足になる
    @Test
    func testMarketSwitchFromMinuteTab() {
        let viewController = Support.makeViewController(period: .oneMinute)
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        #expect(viewController.settingsPeriod == .oneMinute)

        viewController.market = .overseasRealtime

        #expect(viewController.settingsPeriod == .daily)
        #expect(viewController.settingsView.selectedPeriod == .daily)
    }

    /// オプションを選んだまま切り替えると、オプションのまま(トグルの数が変わる)
    @Test
    func testMarketSwitchKeepsOptions() {
        let viewController = Support.makeViewController()
        Support.tap(viewController.settingsTabButton)

        viewController.market = .overseasRealtime
        #expect(viewController.selectedSettingsItem == .displayOptions)
        #expect(Support.toggleRows(of: viewController).count == 2)

        viewController.market = .japanStock
        #expect(Support.toggleRows(of: viewController).count == 3)
    }

    /// 海外のリストにない項目(サブチャートの項目・移動平均線以外のメインの項目)を選んだまま海外に切り替えても落ちず、
    /// 「オプション」に戻る(設定画面を開いていても、閉じていても)
    @Test(arguments: [
        ChartSettingsItem.main(.multipleMovingAverage), .main(.bollingerBands), .main(.ichimoku),
        .sub(.movingAverageDeviation), .sub(.rsi), .sub(.psychological), .sub(.stochastics), .sub(.macd),
    ])
    func testMarketSwitchWithItemMissingOverseas(item: ChartSettingsItem) async throws {
        for isOpen in [true, false] {
            ChartStateStore.reset()
            let viewController = Support.makeViewController()
            Support.tap(viewController.settingsTabButton)
            Support.selectSettingsItem(item, in: viewController)
            #expect(viewController.selectedSettingsItem == item)
            if !isOpen {
                viewController.closePanels()
                try await Task.sleep(for: Support.animationWait)
            }

            viewController.market = .overseasRealtime

            #expect(viewController.selectedSettingsItem == .displayOptions, "\(item.title) 開いている: \(isOpen)")
            #expect(Support.toggleRows(of: viewController).count == 2)
            #expect(Support.stepperRows(of: viewController).isEmpty)

            // 国内に戻しても「オプション」のまま
            viewController.market = .japanIndex
            #expect(viewController.selectedSettingsItem == .displayOptions)
        }
    }

    /// 国内⇔海外を切り替えると、編集中の値は切り替えた先の設定値になる(切り替える前の値で上書きしない)
    @Test
    func testMarketSwitchResetsDraft() {
        let viewController = Support.makeViewController(market: .overseasRealtime)
        viewController.shortMAPeriod = 22
        viewController.market = .japanIndex
        viewController.shortMAPeriod = 11
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.main(.movingAverage), in: viewController)
        Support.slide(Support.stepperRows(of: viewController)[1], to: 40)

        viewController.market = .overseasRealtime

        #expect(self.sliderValues(of: viewController) == [22, 25])
        Support.tapSettingsButton("settings.confirmButton", in: viewController)
        #expect(viewController.parameters.shortMAPeriod == 22)
        #expect(viewController.parameters.longMAPeriod == 25)

        // 国内の設定値も変わっていない(編集していた 40 は決定していないので捨てる)
        viewController.market = .japanIndex
        #expect(viewController.parameters.shortMAPeriod == 11)
        #expect(viewController.parameters.longMAPeriod == 25)
    }

    /// 国内どうし(日本株 ⇔ 日本株価指数)の切り替えでは、編集中の値を残す
    @Test
    func testDomesticSwitchKeepsDraft() {
        let viewController = Support.makeViewController(market: .japanStock)
        Support.tap(viewController.settingsTabButton)
        Support.selectSettingsItem(.sub(.rsi), in: viewController)
        Support.slide(Support.stepperRows(of: viewController)[0], to: 30)

        viewController.market = .japanIndex

        #expect(viewController.selectedSettingsItem == .sub(.rsi))
        #expect(self.sliderValues(of: viewController).first == 30)
        Support.tapSettingsButton("settings.confirmButton", in: viewController)
        #expect(viewController.parameters.rsiPeriod == 30)
    }

    // MARK: - すべてのパラメータを範囲の端にする

    /// すべての項目・パラメータを、最小・最大にして決定しても、その指標を描ける(落ちない)
    @Test(arguments: [true, false])
    func testEveryFieldAtEdges(usesUpperBound: Bool) {
        let viewController = Support.makeViewController()

        for section in ChartSettingsCatalog.sections(for: .japanIndex) {
            for item in section.items where item != .displayOptions {
                // その項目の指標を表示しておく
                switch item {
                case .main(let indicator):
                    Support.tapMenu(indicator, in: viewController)
                case .sub(let indicator):
                    Support.tapMenu(indicator, in: viewController)
                case .displayOptions:
                    break
                }
                Support.tap(viewController.settingsTabButton)
                Support.selectSettingsItem(item, in: viewController)

                let fields = ChartSettingsCatalog.fields(for: item)
                for (index, field) in fields.enumerated() {
                    var bound = field.range.lowerBound
                    if usesUpperBound {
                        bound = field.range.upperBound
                    }
                    Support.slide(Support.stepperRows(of: viewController)[index], to: bound)
                }
                Support.tapSettingsButton("settings.confirmButton", in: viewController)
                viewController.view.layoutIfNeeded()

                for field in fields {
                    var bound = field.range.lowerBound
                    if usesUpperBound {
                        bound = field.range.upperBound
                    }
                    #expect(field.value(in: viewController.parameters) == bound, "\(item.title) \(field.title)")
                }
                #expect(!viewController.chartView.candles.isEmpty, "\(item.title)")
            }
        }
    }

    // MARK: - Model(ChartSettingsCatalog・IndicatorParameterField)

    /// どの足種の初期値も、設定画面で設定できる範囲に入っている
    @Test(arguments: ChartPeriod.allCases)
    func testDefaultsWithinRange(period: ChartPeriod) {
        let parameters = period.indicatorParameters
        for section in ChartSettingsCatalog.sections(for: .japanIndex) {
            for item in section.items {
                for field in ChartSettingsCatalog.fields(for: item) {
                    let value = field.value(in: parameters)
                    #expect(field.range.contains(value), "\(period) \(item.title) \(field.title) = \(value)")
                }
            }
        }
    }

    /// 1つの項目の中で、同じプロパティを2回並べていない
    @Test
    func testFieldsAreDistinct() {
        for section in ChartSettingsCatalog.sections(for: .japanIndex) {
            for item in section.items {
                let titles = ChartSettingsCatalog.fields(for: item).map { field in field.title }
                #expect(Set(titles).count == titles.count, "\(item.title)")
                // 1つずつ値を変えて、ほかのプロパティが変わらないことを確かめる
                let fields = ChartSettingsCatalog.fields(for: item)
                for (index, field) in fields.enumerated() {
                    var parameters = IndicatorParameters()
                    field.setValue(field.range.lowerBound, in: &parameters)
                    for (otherIndex, other) in fields.enumerated() where otherIndex != index {
                        #expect(other.value(in: parameters) == other.value(in: IndicatorParameters()),
                                "\(item.title) \(field.title) → \(other.title)")
                    }
                }
            }
        }
    }

    /// 値の書き込みは、範囲内に丸め、整数は四捨五入する
    @Test(arguments: [(5.4, 5), (5.5, 6), (0, 1), (-10, 1), (150, 99), (99.4, 99)])
    func testFieldSetValue(input: Double, expected: Int) {
        let field = ChartSettingsCatalog.fields(for: .main(.movingAverage))[0]
        var parameters = IndicatorParameters()

        field.setValue(input, in: &parameters)

        #expect(parameters.shortMAPeriod == expected)
    }

    /// 表示する小数点以下の桁数は、整数なら 0、小数は刻みの桁
    @Test
    func testFractionDigits() {
        let intField = IndicatorParameterField(title: "", target: .int(\.rsiPeriod), range: 1...99, step: 1)
        let doubleField = IndicatorParameterField(title: "", target: .double(\.parabolicStep), range: 0...1, step: 0.02)
        let tenthField = IndicatorParameterField(title: "", target: .double(\.parabolicMaximum), range: 0...1, step: 0.1)

        #expect(intField.fractionDigits == 0)
        #expect(doubleField.fractionDigits == 2)
        #expect(tenthField.fractionDigits == 1)
    }

    /// 多重移動平均線: 最短が最長より大きくても入れ替えて計算し、本数の範囲(2〜15)で期間が並ぶ
    @Test
    func testMultipleMovingAveragePeriods() {
        var parameters = IndicatorParameters()
        parameters.multipleMAShortestPeriod = 75
        parameters.multipleMALongestPeriod = 5
        #expect(parameters.multipleMAPeriods.first == 5)
        #expect(parameters.multipleMAPeriods.last == 75)

        parameters.multipleMAShortestPeriod = 1
        parameters.multipleMALongestPeriod = 1
        #expect(parameters.multipleMAPeriods == [1])

        for count in 2...15 {
            parameters.multipleMAShortestPeriod = 1
            parameters.multipleMALongestPeriod = 99
            parameters.multipleMACount = count
            let periods = parameters.multipleMAPeriods
            #expect(periods.first == 1, "本数 \(count)")
            #expect(periods.last == 99, "本数 \(count)")
            #expect(periods == periods.sorted(), "本数 \(count)")
        }
    }

    // MARK: - 部品

    /// 右側の数値の行の、スライダーの値(上から順)
    private func sliderValues(of viewController: LandscapeChartViewController) -> [Double] {
        return Support.stepperRows(of: viewController).map { row in
            Double(Support.slider(of: row)?.value ?? -1)
        }
    }
}

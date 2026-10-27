//
//  LandscapeTestSupport.swift
//  ChartTestTests
//
//  横画面(LandscapeChartViewController)のテクニカル/設定タブのテストで使う部品。
//  ボタン・スライダー・トグルは、実際に押したときと同じ処理(sendActions)を呼んで操作する
//

import UIKit
@testable import ChartTest

@MainActor
enum LandscapeTestSupport {

    /// 横画面の大きさ(iPhone の横向きに近い大きさ)
    static let screenSize = CGSize(width: 844, height: 390)

    /// パネルを開く・閉じるアニメーションが終わるまで待つ秒数(panelAnimationDuration より少し長く)
    static let animationWait: Duration = .milliseconds(500)

    /// 指定した指数の種類・足種のデータを表示した横画面を作る
    static func makeViewController(market: IndexMarket = .japanIndex,
                                   period: ChartPeriod = .daily) -> LandscapeChartViewController {
        let viewController = LandscapeChartViewController.instantiate()
        viewController.market = market
        viewController.setCandles(SampleData.candles(for: period), period: period)
        viewController.view.frame = CGRect(origin: .zero, size: self.screenSize)
        viewController.view.layoutIfNeeded()
        return viewController
    }

    // MARK: - 部品を探す

    /// 指定したView の中にある、指定した型の View をすべて返す(画面の並び順)
    static func subviews<View: UIView>(of type: View.Type, in view: UIView) -> [View] {
        var found: [View] = []
        for subview in view.subviews {
            if let match = subview as? View {
                found.append(match)
            }
            found += self.subviews(of: type, in: subview)
        }
        return found
    }

    /// accessibilityIdentifier が指定の文字で始まるボタン(画面の並び順)
    static func buttons(identifierPrefix prefix: String, in view: UIView) -> [UIButton] {
        return self.subviews(of: UIButton.self, in: view).filter { button in
            guard let identifier = button.accessibilityIdentifier else {
                return false
            }
            return identifier.hasPrefix(prefix)
        }
    }

    /// accessibilityIdentifier が一致するボタン
    static func button(identifier: String, in view: UIView) -> UIButton? {
        return self.subviews(of: UIButton.self, in: view).first { button in
            button.accessibilityIdentifier == identifier
        }
    }

    /// ボタンを押す(Touch Up Inside)
    static func tap(_ button: UIButton?) {
        button?.sendActions(for: .touchUpInside)
    }

    // MARK: - テクニカルのメニュー

    /// メニューのメインチャート列に並んでいる指標の名称(上から順)
    static func mainMenuTitles(of viewController: LandscapeChartViewController) -> [String] {
        let prefix = "technicalMenu.main."
        return self.buttons(identifierPrefix: prefix, in: viewController.menuView).map { button in
            String(button.accessibilityIdentifier?.dropFirst(prefix.count) ?? "")
        }
    }

    /// メニューのサブチャート列に並んでいる指標の名称(上から順)
    static func subMenuTitles(of viewController: LandscapeChartViewController) -> [String] {
        let prefix = "technicalMenu.sub."
        return self.buttons(identifierPrefix: prefix, in: viewController.menuView).map { button in
            String(button.accessibilityIdentifier?.dropFirst(prefix.count) ?? "")
        }
    }

    /// メニューのメインチャート列の指標を押す
    static func tapMenu(_ indicator: MainChartIndicator, in viewController: LandscapeChartViewController) {
        self.tap(self.button(identifier: "technicalMenu.main.\(indicator.title)", in: viewController.menuView))
    }

    /// メニューのサブチャート列の指標を押す
    static func tapMenu(_ indicator: SubChartIndicator, in viewController: LandscapeChartViewController) {
        self.tap(self.button(identifier: "technicalMenu.sub.\(indicator.title)", in: viewController.menuView))
    }

    // MARK: - 設定画面

    /// 設定画面の左側リストで、指定した項目を押す
    static func selectSettingsItem(_ item: ChartSettingsItem, in viewController: LandscapeChartViewController) {
        guard let indexPath = viewController.indexPathInSettingsList(of: item) else {
            return
        }
        let tables = self.subviews(of: UITableView.self, in: viewController.settingsView)
        guard let table = tables.first(where: { table in table.accessibilityIdentifier == "settings.list" }) else {
            return
        }
        table.delegate?.tableView?(table, didSelectRowAt: indexPath)
    }

    /// 設定画面の足種のタブ(左から順)
    static func periodTabButtons(of viewController: LandscapeChartViewController) -> [UIButton] {
        guard let tabView = self.subviews(of: ChartPeriodTabView.self, in: viewController.settingsView).first else {
            return []
        }
        return self.subviews(of: UIButton.self, in: tabView)
    }

    /// 設定画面の足種のタブを押す
    static func tapPeriodTab(_ period: ChartPeriod, in viewController: LandscapeChartViewController) {
        let button = self.periodTabButtons(of: viewController).first { button in
            button.title(for: .normal) == period.title
        }
        self.tap(button)
    }

    /// 設定画面の右側の、数値の行(上から順)
    static func stepperRows(of viewController: LandscapeChartViewController) -> [ChartSettingsStepperRow] {
        return self.subviews(of: ChartSettingsStepperRow.self, in: viewController.settingsView)
    }

    /// 設定画面の右側の、トグルの行(上から順)
    static func toggleRows(of viewController: LandscapeChartViewController) -> [ChartSettingsToggleRow] {
        return self.subviews(of: ChartSettingsToggleRow.self, in: viewController.settingsView)
    }

    /// 数値の行の − ボタン
    static func minusButton(of row: ChartSettingsStepperRow) -> UIButton? {
        return self.subviews(of: UIButton.self, in: row).first { button in
            button.title(for: .normal) == "−"
        }
    }

    /// 数値の行の + ボタン
    static func plusButton(of row: ChartSettingsStepperRow) -> UIButton? {
        return self.subviews(of: UIButton.self, in: row).first { button in
            button.title(for: .normal) == "+"
        }
    }

    /// 数値の行のスライダー
    static func slider(of row: ChartSettingsStepperRow) -> UISlider? {
        return self.subviews(of: UISlider.self, in: row).first
    }

    /// 数値の行のスライダーを、指定した位置まで動かす(Value Changed)
    static func slide(_ row: ChartSettingsStepperRow, to value: Double) {
        guard let slider = self.slider(of: row) else {
            return
        }
        slider.value = Float(value)
        slider.sendActions(for: .valueChanged)
    }

    /// トグルの行を、指定した状態に切り替える(Value Changed)
    static func setToggle(_ row: ChartSettingsToggleRow, isOn: Bool) {
        guard let toggle = self.subviews(of: UISwitch.self, in: row).first else {
            return
        }
        toggle.isOn = isOn
        toggle.sendActions(for: .valueChanged)
    }

    /// 設定画面の下のボタン(「すべての足に反映」「初期値に戻す」「決定」)を押す
    static func tapSettingsButton(_ identifier: String, in viewController: LandscapeChartViewController) {
        self.tap(self.button(identifier: identifier, in: viewController.settingsView))
    }

    // MARK: - チャート

    /// メインチャートに描いている線の凡例名
    static func mainSeriesLabels(of viewController: LandscapeChartViewController) -> [String?] {
        return viewController.chartView.mainContent.series.map { series in series.label }
    }

    /// サブチャートに描いている線の凡例名(サブチャートなしなら nil)
    static func subSeriesLabels(of viewController: LandscapeChartViewController) -> [String?]? {
        guard let sub = viewController.chartView.subContent else {
            return nil
        }
        return sub.series.map { series in series.label }
    }
}

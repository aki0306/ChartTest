//
//  LandscapeChartViewController+Settings.swift
//  ChartTest
//
//  【Controller】横画面のチャート画面(LandscapeChartViewController)のうち、設定画面(ChartSettingsView)との受け渡しを担当する部分。
//
//  ・Model → 設定画面: 左側リスト(指数の種類で変わる)・足種のタブ・右側の行(トグル/数値)を作って渡す
//  ・設定画面 → Model: 操作(ChartSettingsViewDelegate)を受け取り、状態を更新する
//  ・指標のパラメータは、設定画面を開くたびに編集用のコピー(draftParametersByPeriod)を作り、
//    「決定」を押したときだけチャートに反映する(決定せずに閉じた場合は捨てる)。表示オプションは、切り替えるとすぐ反映する
//

import UIKit

extension LandscapeChartViewController {

    // MARK: - 設定画面(Model → 設定画面)

    /// 設定画面を用意する(左側リストを作り、編集を始める)
    func configureSettingsView() {
        self.reloadSettingsList()
        self.beginSettingsEditing()
    }

    /// 設定画面の左側リストと足種のタブを、指数の種類に合わせて作る
    /// (海外指数は、左側リストの項目が少なく、足種のタブは 日足・週足・月足 だけ)
    func reloadSettingsList() {
        // 足種のタブ: 指数の種類で使う足種だけを並べる(海外指数は 1分足・日中足のタブを出さない)
        self.settingsView.periods = self.market.periods

        // 見出しごとに、項目の名称(「移動平均線」など)を並べる
        var sections: [ChartSettingsView.Section] = []
        for section in self.settingsSections {
            let itemTitles = section.items.map { item in item.title }
            sections.append(ChartSettingsView.Section(title: section.title, items: itemTitles))
        }
        self.settingsView.sections = sections
        self.settingsView.selectedIndexPath = self.selectedSettingsIndexPath
    }

    /// 設定画面での編集を始める(今のパラメータから編集用のコピーを作り、タブは表示中の足種にする)
    func beginSettingsEditing() {
        self.draftParametersByPeriod = self.parametersByPeriod
        self.settingsPeriod = self.period
        self.reloadSettingsRows()
    }

    /// 選択中の項目・足種に合わせて、設定画面の足種のタブと右側の行を作る
    func reloadSettingsRows() {
        switch self.selectedSettingsItem {
        case .displayOptions:
            // 表示オプション: トグル(足種ごとではないので、タブと下のボタンは隠す)
            self.settingsView.showsPeriodControls = false
            // 並べるオプションは指数の種類で変わる(海外指数は Y軸(サブ)固定を除く)
            self.settingsView.rows = ChartDisplayOption.options(for: self.market).map { option in
                .toggle(title: option.title, isOn: self.displayOptions[keyPath: option.keyPath])
            }
        case let item:
            // .displayOptions 以外のすべて(メイン・サブの指標)。default の代わりに、選択中の項目を item として受け取っている
            self.settingsView.showsPeriodControls = true

            // この項目を設定できない足種(移動平均線以外の1分足・日中足)はグレーにする。
            // 選択中の足種が設定できない足種なら、日足に切り替える
            let availablePeriods = self.settingsPeriods(for: item)
            if !availablePeriods.contains(self.settingsPeriod) {
                self.settingsPeriod = .daily
            }
            self.settingsView.disabledPeriods = Set(ChartPeriod.allCases.filter { period in
                !availablePeriods.contains(period)
            })
            self.settingsView.selectedPeriod = self.settingsPeriod

            // 指標: パラメータごとに 名称 + −/+ ボタン + スライダー(編集中の値を表示する)
            let draft = self.draftParameters(for: self.settingsPeriod)
            self.settingsView.rows = ChartSettingsCatalog.fields(for: item).map { field in
                .stepper(title: field.title, value: field.value(in: draft),
                         range: field.range, step: field.step, fractionDigits: field.fractionDigits)
            }
        }
    }

    /// 指定した項目を設定できる足種(項目ごとの足種のうち、この指数で使う足種だけ)。
    /// 海外指数では、どの項目も1分足・日中足は設定できない
    private func settingsPeriods(for item: ChartSettingsItem) -> [ChartPeriod] {
        return ChartSettingsCatalog.periods(for: item).filter { period in
            self.market.periods.contains(period)
        }
    }

    /// 編集中の、指定した足種のパラメータ
    private func draftParameters(for period: ChartPeriod) -> IndicatorParameters {
        if let parameters = self.draftParametersByPeriod[period] {
            return parameters
        }
        return self.parameters(for: period)
    }

    /// 選択中の項目のパラメータの値を、指定した値で上書きする(編集中のパラメータに対して)
    /// - Parameters:
    ///   - source: 値の取り出し元
    ///   - period: 上書きする足種
    private func copySelectedItemValues(from source: IndicatorParameters, to period: ChartPeriod) {
        var target = self.draftParameters(for: period)
        for field in ChartSettingsCatalog.fields(for: self.selectedSettingsItem) {
            field.setValue(field.value(in: source), in: &target)
        }
        self.draftParametersByPeriod[period] = target
    }

    // MARK: - 指数の種類を切り替えたとき

    /// 指定した指数の種類のリストで、指定した位置にある項目(範囲外なら nil)
    func settingsItem(at indexPath: IndexPath, in market: IndexMarket) -> ChartSettingsItem? {
        let sections = ChartSettingsCatalog.sections(for: market)
        guard sections.indices.contains(indexPath.section) else {
            return nil
        }
        let items = sections[indexPath.section].items
        guard items.indices.contains(indexPath.row) else {
            return nil
        }
        return items[indexPath.row]
    }

    /// 今の指数の種類のリストで、指定した項目がある位置(なければ nil)
    func indexPathInSettingsList(of item: ChartSettingsItem) -> IndexPath? {
        for (sectionIndex, section) in self.settingsSections.enumerated() {
            if let row = section.items.firstIndex(of: item) {
                return IndexPath(row: row, section: sectionIndex)
            }
        }
        return nil
    }
}

// MARK: - ChartSettingsViewDelegate(設定画面の操作を状態に反映する)

extension LandscapeChartViewController: ChartSettingsViewDelegate {

    /// 左側リストの項目が選ばれたら、右側をその項目の設定に切り替える
    func settingsView(_ settingsView: ChartSettingsView, didSelectItemAt indexPath: IndexPath) {
        self.selectedSettingsIndexPath = indexPath
        settingsView.selectedIndexPath = indexPath
        self.reloadSettingsRows()
    }

    /// トグル(表示オプション)が切り替えられたら、対応するオプションを更新する
    func settingsView(_ settingsView: ChartSettingsView, didToggleRowAt index: Int, isOn: Bool) {
        // 行の並びは reloadSettingsRows の .displayOptions と同じ(指数の種類で使えるオプションの順)
        let options = ChartDisplayOption.options(for: self.market)
        guard options.indices.contains(index) else {
            return
        }
        self.displayOptions[keyPath: options[index].keyPath] = isOn
    }

    /// 足種のタブが選ばれたら、その足種の設定に切り替える
    func settingsView(_ settingsView: ChartSettingsView, didSelectPeriod period: ChartPeriod) {
        self.settingsPeriod = period
        self.reloadSettingsRows()
    }

    /// 数値(指標パラメータ)が変更されたら、編集中のパラメータを更新する(チャートへの反映は「決定」のとき)
    func settingsView(_ settingsView: ChartSettingsView, didChangeValueAt index: Int, value: Double) {
        let fields = ChartSettingsCatalog.fields(for: self.selectedSettingsItem)
        guard fields.indices.contains(index) else {
            return
        }
        var draft = self.draftParameters(for: self.settingsPeriod)
        fields[index].setValue(value, in: &draft)
        self.draftParametersByPeriod[self.settingsPeriod] = draft
    }

    /// 「すべての足に反映」: 表示中の値を、この項目を設定できるすべての足種にコピーする(編集中のパラメータに対して)
    func settingsViewDidTapApplyToAllPeriods(_ settingsView: ChartSettingsView) {
        let source = self.draftParameters(for: self.settingsPeriod)
        for period in self.settingsPeriods(for: self.selectedSettingsItem) {
            self.copySelectedItemValues(from: source, to: period)
        }
    }

    /// 「初期値に戻す」: 表示中の足種の、この項目の値を初期値に戻す(編集中のパラメータに対して)
    func settingsViewDidTapReset(_ settingsView: ChartSettingsView) {
        self.copySelectedItemValues(from: self.settingsPeriod.indicatorParameters, to: self.settingsPeriod)
        self.reloadSettingsRows()
    }

    /// 「決定」: 編集中のパラメータをチャートに反映し、設定画面を閉じる
    func settingsViewDidTapConfirm(_ settingsView: ChartSettingsView) {
        self.parametersByPeriod = self.draftParametersByPeriod
        self.reloadChart(keepsViewport: true)
        self.setOpenPanel(nil, animated: true)
    }
}

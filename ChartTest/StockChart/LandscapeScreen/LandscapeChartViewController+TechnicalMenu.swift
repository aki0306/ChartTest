//
//  LandscapeChartViewController+TechnicalMenu.swift
//  ChartTest
//
//  【Controller】横画面のチャート画面(LandscapeChartViewController)のうち、テクニカルのメニュー(TechnicalMenuView)を担当する部分。
//  「テクニカル」を押したときの処理は、すべてこのファイルにある。
//
//  【流れ】
//   ① 左端の「テクニカル」タブを押す
//        → technicalTabTapped → togglePanel(+Panels)でメニューを開く(開いていれば閉じる)
//   ② メニューの中の指標(移動平均線・RSI など)を押す
//        → TechnicalMenuView が delegate で知らせる
//        → technicalMenuView(_:didSelectMainIndicator:) / (_:didSelectSubIndicator:) で mainIndicator / subIndicator を変える
//        → mainIndicator / subIndicator の didSet(LandscapeChartViewController.swift)でチャートを描き直す
//      指標を選んでもメニューは開いたまま。閉じるのは、もう一度タブを押したときか、背景のグレーを押したとき
//
//  ・メニューに並べる指標(選べるもの)は、指数の種類・足種・チャートの種類で変わる(applyIndicatorChoices)
//

import UIKit

extension LandscapeChartViewController {

    // MARK: - 「テクニカル」タブを押したとき(①)

    /// 「テクニカル」タブがタップされたら、指標の選択メニューを開閉する
    @objc func technicalTabTapped() {
        self.togglePanel(.technical)
    }

    // MARK: - メニューの中身

    /// メニューの初期状態を設定する(選択中の指標・選べる指標。配置は +Panels の setupPanels)
    func configureTechnicalMenu() {
        self.menuView.delegate = self
        self.menuView.selectedMainIndicator = self.mainIndicator
        self.menuView.selectedSubIndicator = self.subIndicator
        self.menuView.allowsOnlyNone = !self.chartType.usesTechnicalIndicators(in: self.market)
        self.menuView.availableMainIndicators = MainChartIndicator.choices(for: self.market, period: self.period)
        self.menuView.availableSubIndicators = SubChartIndicator.choices(for: self.market, period: self.period)
        self.menuView.accessibilityIdentifier = "chart.technicalMenu"  // UI テストで探すための名前
    }

    /// テクニカルのメニューに並べる指標を、指数の種類・足種に合わせる(MainChartIndicator / SubChartIndicator の choices)。
    /// 選べない指標を選んでいた場合は、選べるものに切り替える
    ///   ・メイン: 移動平均線(どの指数・足種でも選べる)
    ///   ・サブ  : 出来高(選べない場合 = 海外指数は なし)
    /// 例) 日足で 一目均衡表 + MACD を表示中に 1分足 にすると、移動平均線 + 出来高 になる
    func applyIndicatorChoices() {
        let mainChoices = MainChartIndicator.choices(for: self.market, period: self.period)
        let subChoices = SubChartIndicator.choices(for: self.market, period: self.period)
        self.menuView.availableMainIndicators = mainChoices
        self.menuView.availableSubIndicators = subChoices

        if !mainChoices.contains(self.mainIndicator) {
            self.mainIndicator = .movingAverage
        }
        if !subChoices.contains(self.subIndicator) {
            if subChoices.contains(.volume) {
                self.subIndicator = .volume
            } else {
                self.subIndicator = .hidden
            }
        }
    }
}

// MARK: - メニューの中の指標を押したとき(②)

extension LandscapeChartViewController: TechnicalMenuViewDelegate {

    /// メインチャートの指標が選ばれたら、表示する指標を変える(描き直しは mainIndicator の didSet)
    func technicalMenuView(_ menuView: TechnicalMenuView, didSelectMainIndicator indicator: MainChartIndicator) {
        self.mainIndicator = indicator
    }

    /// サブチャートの指標が選ばれたら、表示する指標を変える(描き直しは subIndicator の didSet)
    func technicalMenuView(_ menuView: TechnicalMenuView, didSelectSubIndicator indicator: SubChartIndicator) {
        self.subIndicator = indicator
    }
}

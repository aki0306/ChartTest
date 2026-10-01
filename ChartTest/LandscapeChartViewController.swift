//
//  LandscapeChartViewController.swift
//  ChartTest
//
//  【Controller】横画面のチャート画面(Landscape.storyboard)。
//
//  共通チャート部品(StockChartViewController)は storyboard のコンテナビューに埋め込んであり、
//  左端のテクニカル/設定タブで指標の切り替え・設定変更ができるようにする。
//  右下のボタン(chartTypeButton)で、チャートの種類(ローソク足・VWAP：線・VWAP：点・新値足・折線チャート)を切り替える。
//  ローソク足以外では、テクニカルのメニューは「なし」だけになり、4本値は表示しない(StockChartViewController.chartType)。
//
//  使い方(Swift):
//      let viewController = LandscapeChartViewController.instantiate()
//      viewController.chartViewController.mainIndicator = .bollingerBands   // 必要なら指標を変える
//      viewController.chartViewController.chartType = .newPrice             // 必要ならチャートの種類を変える
//      viewController.setCandles(candles)
//
//  使い方(Objective-C):
//      LandscapeChartViewController *viewController = [LandscapeChartViewController instantiate];
//      viewController.chartViewController.mainIndicator = MainChartIndicatorBollingerBands;
//      viewController.chartViewController.chartType = ChartTypeNewPrice;
//      [viewController setCandles:candles];
//

import UIKit

final class LandscapeChartViewController: UIViewController {

    /// Landscape.storyboard から生成する
    @objc static func instantiate() -> LandscapeChartViewController {
        UIStoryboard(name: "Landscape", bundle: nil).instantiateInitialViewController() as! LandscapeChartViewController
    }

    /// チャートの種類を切り替えるボタン(タップで種類のメニューを表示する)
    @IBOutlet private weak var chartTypeButton: UIButton!

    /// コンテナビューの embed で受け取った共通チャート部品(画面の読み込み時に設定される)
    private var embeddedChartViewController: StockChartViewController?

    /// 共通チャート部品(指標メニュー・設定画面付き)。
    /// 画面を読み込むまでは存在しないので、まだなら読み込んでから返す
    @objc var chartViewController: StockChartViewController {
        loadViewIfNeeded()
        return embeddedChartViewController!
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        chartViewController.isTechnicalMenuEnabled = true
        configureChartTypeButton()

        // 必要に応じて設定を変更できる(例)
        // chartViewController.mainIndicator = .bollingerBands     // メインチャートの指標
        // chartViewController.subIndicator = .macd                // サブチャートの指標
        // chartViewController.parameters.rsiPeriod = 9            // 指標のパラメータ(Model)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let chart = segue.destination as? StockChartViewController {
            embeddedChartViewController = chart
        }
    }

    // MARK: - チャートの種類

    /// チャートの種類のボタンを設定する(タップすると種類のメニューを表示する)
    private func configureChartTypeButton() {
        var configuration = UIButton.Configuration.bordered()
        configuration.baseBackgroundColor = .white
        configuration.baseForegroundColor = .systemBlue
        configuration.background.strokeColor = .systemGray4
        configuration.background.strokeWidth = 1
        configuration.image = UIImage(systemName: "arrowtriangle.down.fill",
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 12))
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 6
        chartTypeButton.configuration = configuration
        chartTypeButton.showsMenuAsPrimaryAction = true
        updateChartTypeButton()

        // 種類が変わったら(メニューからでも、コードから chartType を変えた場合でも)ボタンの表示を合わせる
        chartViewController.onChartTypeChange = { [weak self] _ in
            self?.updateChartTypeButton()
        }
    }

    /// ボタンの文字とメニュー(選択中の種類にチェック)を、選択中のチャートの種類に合わせる
    private func updateChartTypeButton() {
        let selectedType = chartViewController.chartType
        chartTypeButton.configuration?.title = selectedType.title

        var actions: [UIAction] = []
        for chartType in ChartType.allCases {
            let action = UIAction(title: chartType.title) { [weak self] _ in
                self?.selectChartType(chartType)
            }
            if chartType == selectedType {
                action.state = .on
            }
            actions.append(action)
        }
        chartTypeButton.menu = UIMenu(children: actions)
    }

    /// チャートの種類を切り替える(ボタンの表示は onChartTypeChange で更新される)
    private func selectChartType(_ chartType: ChartType) {
        chartViewController.chartType = chartType
    }

    // MARK: - データ

    /// ローソク足データを設定して描画する
    @objc func setCandles(_ candles: [StockCandle]) {
        chartViewController.setCandles(candles)
    }
}

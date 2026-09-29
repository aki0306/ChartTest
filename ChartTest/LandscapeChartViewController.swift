//
//  LandscapeChartViewController.swift
//  ChartTest
//
//  【Controller】横画面のチャート画面(Landscape.storyboard)。
//
//  共通チャート部品(StockChartViewController)は storyboard のコンテナビューに埋め込んであり、
//  左端のテクニカル/設定タブで指標の切り替え・設定変更ができるようにする。
//
//  使い方(Swift):
//      let viewController = LandscapeChartViewController.instantiate()
//      viewController.chartViewController.mainIndicator = .bollingerBands   // 必要なら指標を変える
//      viewController.setCandles(candles)
//
//  使い方(Objective-C):
//      LandscapeChartViewController *viewController = [LandscapeChartViewController instantiate];
//      viewController.chartViewController.mainIndicator = MainChartIndicatorBollingerBands;
//      [viewController setCandles:candles];
//

import UIKit

final class LandscapeChartViewController: UIViewController {

    /// Landscape.storyboard から生成する
    @objc static func instantiate() -> LandscapeChartViewController {
        UIStoryboard(name: "Landscape", bundle: nil).instantiateInitialViewController() as! LandscapeChartViewController
    }

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

    /// ローソク足データを設定して描画する
    @objc func setCandles(_ candles: [StockCandle]) {
        chartViewController.setCandles(candles)
    }
}

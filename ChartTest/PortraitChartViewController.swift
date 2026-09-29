//
//  PortraitChartViewController.swift
//  ChartTest
//
//  【Controller】縦画面のチャート画面(Portrait.storyboard)。
//
//   ┌─────┐┌─────┐┌─────┐┌─────┐┌─────┐
//   │1分足││日中足││日 足││週 足││月 足│   ← periodTabView(足種のタブ)
//   └─────┘└─────┘└─────┘└─────┘└─────┘
//   ┌────────────────────────────┐
//   │                            │
//   │       StockChartView       │   ← chartView(移動平均線 + 出来高)
//   │                            │
//   └────────────────────────────┘
//
//  ・タブで足種を選ぶと、その足種のデータを読み込み(candleLoader)、足種に合った設定で描き直す
//  ・選べる足種は指数の種類で変わる(国内: 5種類、海外: 日足・週足・月足)
//  ・チャートの View(StockChartView)は storyboard に直接配置してあり、StockChartViewController は経由しない
//
//  使い方(Swift):
//      let viewController = PortraitChartViewController.instantiate()
//      viewController.market = .domestic                                   // 国内指数(海外指数なら .overseas)
//      viewController.candleLoader = { period in SampleData.candles(for: period) }
//      viewController.reloadChart()                                        // 選択中の足種(最初は日足)を表示
//
//  使い方(Objective-C):
//      PortraitChartViewController *viewController = [PortraitChartViewController instantiate];
//      viewController.market = IndexMarketDomestic;
//      viewController.candleLoader = ^NSArray<StockCandle *> *(ChartPeriod period) {
//          return [SampleData candlesForPeriod:period];
//      };
//      [viewController reloadChart];
//

import UIKit

final class PortraitChartViewController: UIViewController {

    /// Portrait.storyboard から生成する
    @objc static func instantiate() -> PortraitChartViewController {
        UIStoryboard(name: "Portrait", bundle: nil).instantiateInitialViewController() as! PortraitChartViewController
    }

    // MARK: - 部品(storyboard に配置)

    /// 足種のタブ
    @IBOutlet private(set) weak var periodTabView: ChartPeriodTabView!
    /// チャート本体
    @IBOutlet private(set) weak var chartView: StockChartView!

    // MARK: - 設定(外から変更する)

    /// 指数の種類(国内/海外)。種類によってタブに並ぶ足種が変わる
    @objc var market: IndexMarket = .domestic {
        didSet {
            guard isViewLoaded else { return }  // viewDidLoad でタブを作るときに反映される
            configureTabs()
        }
    }

    /// 足種を指定してローソク足データを読み込む処理。タブが押されるたびに呼ばれる。
    /// (サンプルでは SampleData から返している。実際のアプリでは API から取得する処理に差し替える)
    /// Objective-C ではブロック `NSArray<StockCandle *> *(^)(ChartPeriod period)` として設定する
    @objc var candleLoader: ((ChartPeriod) -> [StockCandle])?

    // MARK: - 状態

    /// 選択中の足種(最初は日足)
    @objc private(set) var selectedPeriod: ChartPeriod = .daily

    // MARK: - ライフサイクル

    override func viewDidLoad() {
        super.viewDidLoad()

        // タブが押されたら、その足種で描き直す
        periodTabView.onSelect = { [weak self] period in
            self?.selectPeriod(period)
        }
        configureTabs()
    }

    // MARK: - 外から呼ぶ

    /// 選択中の足種のデータを読み込み直して描画する
    @objc func reloadChart() {
        loadViewIfNeeded()

        // データを読み込み、足種に合った設定で描画する
        // (X軸の書式・初期表示本数・移動平均の期間・出来高の凡例名が足種ごとに変わる)。
        // データが0件の場合は「現在、指定の条件で表示できる情報はありません。」と表示される
        var candles: [StockCandle] = []
        if let candleLoader {
            candles = candleLoader(selectedPeriod)
        }
        chartView.setCandles(candles, period: selectedPeriod)
    }

    // MARK: - タブ

    /// 指数の種類に合わせてタブを並べる
    private func configureTabs() {
        periodTabView.periods = market.periods

        // 選択中の足種がこの指数では選べない場合(海外指数の1分足など)は、日足にする
        if !market.periods.contains(selectedPeriod) {
            selectedPeriod = .daily
        }
        periodTabView.selectedPeriod = selectedPeriod
    }

    /// 足種を選んで描き直す
    private func selectPeriod(_ period: ChartPeriod) {
        selectedPeriod = period
        periodTabView.selectedPeriod = period
        reloadChart()
    }
}

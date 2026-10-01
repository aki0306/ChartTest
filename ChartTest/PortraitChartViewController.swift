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
//  ・チャートの大きさは storyboard(左端から 5pt・右端まで・高さ 208pt)、見た目は applyChartStyle で決めている
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
        applyChartStyle()
    }

    // MARK: - 見た目

    /// 縦画面のチャートの見た目を設定する
    ///
    ///   ←5→┌──────────────────────────┐←9→70,000    ┐
    ///      │移動平均 短期… 長期…(10pt)│   68,000    │ メイン 120pt
    ///      │                          │   ...       │
    ///      ├──────────────────────────┤4,000,000,000┤
    ///      │出来高 出来高移動平均      │      0      │ サブ 60pt
    ///      └──────────────────────────┘             ┘
    ///        7/21   7/31   8/13 ...(11pt)
    ///      |←───── 画面の幅 - 70 ─────→|←── 70 ──→|
    ///
    /// ・Y軸ラベルは Times 8pt。一番長いラベルの幅の中で中央揃えにし、下端の「0」は枠の内側に収める
    /// ・凡例は 10pt。背景を白にして、凡例の文字の後ろのグリッド線を隠す
    /// ・高さ 208pt = 上の余白 8pt + 外枠 180pt(メイン 120 : サブ 60)+ 日付ラベル 20pt
    private func applyChartStyle() {
        // style は代入するたびに描き直されるので、まとめて変更してから1回で代入する
        var style = chartView.style
        style.rightAxisWidth = 70
        style.yAxisFont = UIFont(name: "TimesNewRomanPSMT", size: 8) ?? .systemFont(ofSize: 8)
        style.yAxisLabelOffset = 9
        style.centersYAxisLabels = true
        style.keepsYAxisLabelsInside = true
        style.xAxisFont = .systemFont(ofSize: 11, weight: .medium)
        style.legendFont = .systemFont(ofSize: 10)
        style.legendTopInset = 5
        style.subLegendTopInset = 5
        style.legendBackgroundColor = .white
        chartView.style = style
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

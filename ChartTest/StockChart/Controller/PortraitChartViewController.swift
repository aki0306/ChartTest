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
//  ・タブで足種を選ぶと、その足種のデータを読み込み、足種に合った設定で描き直す。データの渡し方は2通り
//      A. onPeriodSelect(おすすめ。API から非同期で取得する場合)
//         タブが押されると onPeriodSelect が呼ばれる → データを取得 → 届いたら setCandles(_:period:) で渡す
//         (ChartResponseLoader の描画先にもできる。どのスレッドから渡してもよい)
//      B. candleLoader(データをその場で返せる場合。サンプルの SampleData など)
//         タブが押されると candleLoader が呼ばれ、返した配列をすぐに描く
//      両方を設定した場合は candleLoader を使う
//  ・選べる足種は指数の種類で変わる(国内: 5種類、海外: 日足・週足・月足)
//  ・チャートの View(StockChartView)は storyboard に直接配置してあり、StockChartViewController は経由しない
//  ・チャートの大きさは storyboard(左端から 5pt・右端まで・高さ 208pt)、見た目は applyChartStyle で決めている
//
//  使い方(Swift。A: 非同期):
//      let viewController = PortraitChartViewController.instantiate()
//      viewController.market = .domestic                                   // 国内指数(海外指数なら .overseas)
//      viewController.onPeriodSelect = { [weak viewController] period in
//          api.fetchCandles(period) { candles in                           // 既存アプリの通信処理(どのスレッドで終わってもよい)
//              viewController?.setCandles(candles, period: period)
//          }
//      }
//      viewController.reloadChart()                                        // 選択中の足種(最初は日足)を読み込む
//
//  使い方(Objective-C。A: 非同期):
//      PortraitChartViewController *viewController = [PortraitChartViewController instantiate];
//      viewController.market = IndexMarketDomestic;
//      __weak PortraitChartViewController *weakViewController = viewController;
//      viewController.onPeriodSelect = ^(ChartPeriod period) {
//          [api fetchCandlesWithPeriod:period completion:^(NSArray *responseArray) {
//              [ChartResponseLoader setResponse:responseArray period:period to:weakViewController];
//          }];
//      };
//      [viewController reloadChart];
//
//  使い方(B: その場で返す):
//      viewController.candleLoader = { period in SampleData.candles(for: period) }
//      viewController.reloadChart()
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

    /// 指数の種類(国内/海外)。種類によってタブに並ぶ足種と、チャートの描き方が変わる
    /// (海外指数: 日足・週足・月足だけ。ローソク足 + 移動平均線で、サブチャートなし)
    @objc var market: IndexMarket = .domestic {
        didSet {
            guard self.isViewLoaded else { return }  // viewDidLoad でタブを作るときに反映される
            self.configureTabs()
        }
    }

    /// 足種が選ばれたとき(タブが押されたとき・reloadChart)に呼ばれる処理(非同期でデータを取得する場合に使う)。
    /// その足種のデータを取得して、届いたら setCandles(_:period:) で渡す(どのスレッドから渡してもよい)。
    /// この画面がクロージャを持ち続けるので、中でこの画面や呼び出し元を使うときは [weak ...] で受ける(循環参照を防ぐ)
    @objc var onPeriodSelect: ((ChartPeriod) -> Void)?

    /// 足種を指定してローソク足データをその場で返す処理(データをすぐに用意できる場合に使う)。
    /// タブが押されるたびに呼ばれ、返した配列をすぐに描く。API から非同期で取得する場合は onPeriodSelect を使う。
    /// Objective-C ではブロック `NSArray<StockCandle *> *(^)(ChartPeriod period)` として設定する
    @objc var candleLoader: ((ChartPeriod) -> [StockCandle])?

    // MARK: - 状態

    /// 選択中の足種(最初は日足)
    @objc private(set) var selectedPeriod: ChartPeriod = .daily

    // MARK: - ライフサイクル

    override func viewDidLoad() {
        super.viewDidLoad()

        // タブが押されたら、その足種で描き直す
        self.periodTabView.onSelect = { [weak self] period in
            self?.selectPeriod(period)
        }
        self.configureTabs()
        self.applyChartStyle()
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
    ///        7/21   7/31   8/13 ...(8pt)
    ///      |←───── 画面の幅 - 70 ─────→|←── 70 ──→|
    ///
    /// ・Y軸ラベルは Times 8pt。一番長いラベルの幅の中で中央揃えにし、下端の「0」は枠の内側に収める
    /// ・日付ラベルは 8pt(既存アプリと同じ。1分足・日中足は 9:15 … 15:15 のように並ぶ)
    /// ・凡例は 10pt。背景を白にして、凡例の文字の後ろのグリッド線を隠す
    /// ・高さ 208pt = 上の余白 8pt + 外枠 180pt(メイン 120 : サブ 60)+ 日付ラベル 20pt
    private func applyChartStyle() {
        // style は代入するたびに描き直されるので、まとめて変更してから1回で代入する
        var style = self.chartView.style
        style.rightAxisWidth = 70
        style.yAxisFont = UIFont(name: "TimesNewRomanPSMT", size: 8) ?? .systemFont(ofSize: 8)
        style.yAxisLabelOffset = 9
        style.centersYAxisLabels = true
        style.keepsYAxisLabelsInside = true
        style.xAxisFont = .systemFont(ofSize: 8)
        style.legendFont = .systemFont(ofSize: 10)
        style.legendTopInset = 5
        style.subLegendTopInset = 5
        style.legendBackgroundColor = .white
        self.chartView.style = style
    }

    // MARK: - 外から呼ぶ

    /// 選択中の足種のデータを読み込み直して描画する
    ///   ・candleLoader がある: その場でデータを受け取って描く
    ///   ・onPeriodSelect がある: onPeriodSelect を呼ぶ(データは、届いたら setCandles(_:period:) で渡してもらう)
    ///   ・どちらもない: データなし(「現在、指定の条件で表示できる情報はありません。」)で描く
    @objc func reloadChart() {
        // メインスレッドでなければ、メインスレッドで呼び直す(通信の完了処理から直接呼ばれても安全にする。MainThread)
        guard MainThread.isCurrent(orRetry: { self.reloadChart() }) else { return }

        self.loadViewIfNeeded()
        let period = self.selectedPeriod

        if let candleLoader {
            self.setCandles(candleLoader(period), period: period)
            return
        }
        if let onPeriodSelect {
            onPeriodSelect(period)
            return
        }
        self.setCandles([], period: period)
    }

    /// 足種を指定してローソク足データを渡し、描画する(onPeriodSelect で取得したデータを渡すのに使う)。
    /// 足種・指数の種類に合った設定で描く(X軸の書式・初期表示本数・移動平均の期間・出来高の凡例名が足種ごとに変わる。
    /// 海外指数は、ローソク足 + 移動平均線で、サブチャート(出来高)なし)。タブの選択もこの足種に合わせる。
    /// どのスレッドから呼んでもよい。データが0件の場合は「現在、指定の条件で表示できる情報はありません。」と表示される
    /// - Parameters:
    ///   - candles: 日付の古い順に並んだローソク足データ(その足種のデータ)
    ///   - period: 足種
    @objc func setCandles(_ candles: [StockCandle], period: ChartPeriod) {
        // メインスレッドでなければ、メインスレッドで呼び直す(通信の完了処理から直接呼ばれても安全にする。MainThread)
        guard MainThread.isCurrent(orRetry: { self.setCandles(candles, period: period) }) else { return }

        self.loadViewIfNeeded()
        self.selectedPeriod = period
        self.periodTabView.selectedPeriod = period
        self.chartView.setCandles(candles, period: period, market: self.market)
    }

    // MARK: - タブ

    /// 指数の種類に合わせてタブを並べる
    private func configureTabs() {
        self.periodTabView.periods = self.market.periods

        // 選択中の足種がこの指数では選べない場合(海外指数の1分足など)は、日足にする
        if !self.market.periods.contains(self.selectedPeriod) {
            self.selectedPeriod = .daily
        }
        self.periodTabView.selectedPeriod = self.selectedPeriod
    }

    /// 足種を選んで描き直す
    private func selectPeriod(_ period: ChartPeriod) {
        self.selectedPeriod = period
        self.periodTabView.selectedPeriod = period
        self.reloadChart()
    }
}

// MARK: - API のレスポンスの描画先にする

/// ChartResponseLoader の描画先にできるようにする(setCandles(_:period:) は上で定義済み)
extension PortraitChartViewController: StockCandleReceiving {}

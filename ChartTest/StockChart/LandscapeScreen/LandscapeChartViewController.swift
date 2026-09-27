//
//  LandscapeChartViewController.swift
//  ChartTest
//
//  【Controller】横画面のチャート画面(Landscape.storyboard)。
//
//   ┌──┬──────────────────────────────────────────────────┐
//   │テ│                                                  │
//   │ク│            StockChartView(チャート本体)            │  ← 共通チャート部品(StockChartViewController)
//   │設│                                                  │
//   ├──┴──────────────────────────────────────────────────┤
//   │日経平均 68309.46 10/02 15:45  [ローソク足▼][月足▼][↻] │ [⤾] │  ← 下の帯(footerView)
//   └─────────────────────────────────────────────────────┘
//
//  ・共通チャート部品は storyboard のコンテナビューに埋め込んであり、
//    左端のテクニカル/設定タブで指標の切り替え・設定変更ができる
//  ・下の帯(Landscape.storyboard の Footer View。中身は ChartFooterView / ChartFooterView.xib)
//      左     : 指数名・現在値・日時(updatePriceInfo(name:price:date:) で設定する)
//      ローソク足▼: チャートの種類(ローソク足・VWAP：線・VWAP：点・新値足・折線チャート)を切り替える。
//                  ローソク足以外では、テクニカルのメニューは「なし」だけになり、4本値は表示しない
//      月足▼ : 足種を選ぶ。選ばれると onPeriodSelect が呼ばれるので、その足種のデータを取得して setCandles(_:period:) で渡す
//      ↻     : 更新。onReload が呼ばれるので、表示中の足種のデータを取得し直して渡す
//      ⤾     : 縦画面に戻す。onRotate が呼ばれるので、画面の向きを変える処理をする
//    データの取得・画面の回転は、呼び出し側(アプリ)の仕事にしている(API の取得は非同期のことが多いため)
//  ・チャート部品は画面いっぱいに置き、チャート本体だけを chartInsets で内側(帯の上)に置く。
//    テクニカル/設定を開いている間は、パネルが画面の上端〜セーフエリアの下端まで、背景のグレーが画面全体に広がる(configurePanelLayering)
//
//  使い方(Swift):
//      let viewController = LandscapeChartViewController.instantiate()
//      viewController.chartViewController.market = .overseasRealtime             // 海外指数(移動平均線・ローソク足/折線チャートだけ)
//      viewController.onPeriodSelect = { [weak viewController] period in /* その足種のデータを取得して viewController?.setCandles(_:period:) */ }
//      viewController.onReload = { [weak self] in /* 表示中の足種(chartViewController.period)のデータを取得し直す */ }
//      viewController.onRotate = { [weak self] in /* 縦画面に戻す */ }
//      viewController.setCandles(candles, period: .daily)
//      viewController.updatePriceInfo(name: "日経平均", price: 68309.46, date: date)
//
//  使い方(Objective-C):
//      LandscapeChartViewController *viewController = [LandscapeChartViewController instantiate];
//      __weak LandscapeChartViewController *weakViewController = viewController;   // ブロックの中では weak で使う
//      viewController.onPeriodSelect = ^(ChartPeriod period) { ... [weakViewController setCandles:candles period:period]; };
//      viewController.onReload = ^{ ... };
//      viewController.onRotate = ^{ ... };
//      [viewController setCandles:candles period:ChartPeriodDaily];
//      [viewController updatePriceInfoWithName:@"日経平均" price:68309.46 date:date];
//
//  API のレスポンス(足種ごと)を渡す場合(Objective-C):
//      [ChartResponseLoader setResponse:responseArray period:ChartPeriodDaily to:viewController];   // 辞書の配列(NSMutableArray のままでよい)
//      (ChartResponseLoader は縦画面の StockChartView にも使える)
//

import UIKit

final class LandscapeChartViewController: UIViewController {

    /// Landscape.storyboard から生成する
    @objc static func instantiate() -> LandscapeChartViewController {
        let storyboard = UIStoryboard(name: "Landscape", bundle: nil)
        guard let viewController = storyboard.instantiateInitialViewController() as? LandscapeChartViewController else {
            // storyboard の最初の画面のクラスが違う(設定ミス)。すぐ気付けるよう落とす
            fatalError("Landscape.storyboard の最初の画面が LandscapeChartViewController になっていません")
        }
        return viewController
    }

    // MARK: - 部品(storyboard に配置)

    /// 下の帯(ChartFooterView。見た目は ChartFooterView.xib)。
    /// テクニカル/設定のパネルを閉じている間は、チャート部品より手前に置く
    @IBOutlet private weak var footerView: ChartFooterView!

    // MARK: - 操作されたときの処理(外から設定する)

    /// 足種のメニューで足種が選ばれたときに呼ばれる処理(選ばれた足種が渡される)。
    /// その足種のデータを取得して setCandles(_:period:) で渡すと、チャートとボタンの表示が切り替わる。
    /// この画面がクロージャを持ち続けるので、中でこの画面や呼び出し元を使うときは [weak ...] で受ける(循環参照を防ぐ)
    @objc var onPeriodSelect: ((ChartPeriod) -> Void)?
    /// 更新ボタンが押されたときに呼ばれる処理。表示中の足種(chartViewController.period)のデータを取得し直して渡す
    @objc var onReload: (() -> Void)?
    /// 縦画面に戻すボタンが押されたときに呼ばれる処理
    @objc var onRotate: (() -> Void)?

    /// テクニカル/設定のパネルを開いた・閉じたときに呼ばれる処理(true = 開いた)。
    /// この画面の上に重ねたボタンなど(このアプリでは ViewController の 国内指数/海外指数 の切り替え)を、
    /// パネルを開いている間はパネルの奥に回す場合に使う。
    /// 閉じたときは、パネルを閉じるアニメーション(panelAnimationDuration 秒)が終わってから呼ばれる
    var onPanelVisibilityChange: ((Bool) -> Void)?

    /// パネルを開閉するアニメーションの秒数(StockChartViewController と同じ)
    static let panelAnimationDuration: TimeInterval = 0.25

    /// コンテナビューの embed で受け取った共通チャート部品(画面の読み込み時に設定される)
    private var embeddedChartViewController: StockChartViewController?

    /// 共通チャート部品(指標メニュー・設定画面付き)。
    /// 画面を読み込むまでは存在しないので、まだなら読み込んでから返す
    @objc var chartViewController: StockChartViewController {
        self.loadViewIfNeeded()
        guard let embeddedChartViewController else {
            // storyboard のコンテナビューの embed が外れている(設定ミス)。すぐ気付けるよう落とす
            fatalError("Landscape.storyboard のコンテナビューに StockChartViewController が埋め込まれていません")
        }
        return embeddedChartViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.chartViewController.isTechnicalMenuEnabled = true
        self.configureFooter()
        self.configurePanelLayering()

        // チャート部品は画面いっぱいに置き(パネルを画面の上端〜下端まで広げるため)、チャート本体だけを内側に置く。
        // 下は帯(セーフエリアの下端から 44pt。Landscape.storyboard)と、その上の間隔 4pt の分を空ける
        self.chartViewController.chartInsets = UIEdgeInsets(top: 8, left: 0, bottom: 44 + 4, right: 8)

        // 表示中の範囲の最高値・最安値を、ローソク足の上・下に表示する
        self.chartViewController.chartView.showsHighLowLabels = true

        // 必要に応じて設定を変更できる(例)
        // chartViewController.mainIndicator = .bollingerBands     // メインチャートの指標
        // chartViewController.subIndicator = .macd                // サブチャートの指標
        // chartViewController.parameters.rsiPeriod = 9            // 指標のパラメータ(Model)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let chart = segue.destination as? StockChartViewController {
            self.embeddedChartViewController = chart
        }
    }

    // MARK: - パネル(テクニカル/設定)を開いている間

    /// パネルの開閉に合わせて、チャート部品と下の帯の重なり順を切り替える。
    ///
    /// チャート部品(コンテナビュー)は画面いっぱいに置いてあり、パネルと背景のグレーは画面の上端〜下端まで広がる。
    /// ・開いている間: チャート部品を手前にする(下の帯にもグレーとパネルがかかり、帯のボタンは押せなくなる)
    /// ・閉じている間: 下の帯を手前にする(チャート部品は透明な部分もタップを受けるので、手前にあると帯のボタンが押せない)
    private func configurePanelLayering() {
        self.chartViewController.onPanelVisibilityChange = { [weak self] isOpen in
            guard let self else {
                return
            }
            guard let containerView = self.chartViewController.view.superview else {
                return
            }
            if isOpen {
                self.view.bringSubviewToFront(containerView)
                self.onPanelVisibilityChange?(true)
            } else {
                // 背景のグレーが消えるのを待ってから(パネルを閉じるアニメーションと同じ秒数)、ボタンを手前に戻す
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.panelAnimationDuration) {
                    // 待っている間にもう一度開いた場合は、チャート部品を手前のままにする
                    guard !self.chartViewController.isPanelOpen else {
                        return
                    }
                    self.view.bringSubviewToFront(self.footerView)
                    self.onPanelVisibilityChange?(false)
                }
            }
        }
    }

    // MARK: - 下の帯

    /// 下の帯のメニュー・ボタンを設定する。
    /// 見た目は帯(ChartFooterView)が決め、この画面はメニューの中身と、押されたときの処理だけを渡す
    private func configureFooter() {
        self.updateChartTypeMenu()
        self.updatePeriodMenu()
        self.footerView.onReload = { [weak self] in
            self?.onReload?()
        }
        self.footerView.onRotate = { [weak self] in
            self?.onRotate?()
        }

        // チャートの種類が変わったら(メニューからでも、コードから chartType を変えた場合でも)ボタンの表示を合わせ、
        // 表示中の足種がその種類では選べない場合(新値足の1分足)は、選べる足種に切り替える
        self.chartViewController.onChartTypeChange = { [weak self] _ in
            guard let self else {
                return
            }
            self.updateChartTypeMenu()
            self.switchPeriodIfUnavailable()
        }
    }

    // MARK: - チャートの種類

    /// 「チャートの種類」ボタンの文字とメニュー(選択中の種類にチェック)を、選択中のチャートの種類に合わせる。
    /// メニューの中身は開くたびに作るので、指数の種類(海外指数は ローソク足・折線チャート だけ)が後から変わっても反映される
    private func updateChartTypeMenu() {
        let items = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self else {
                completion([])
                return
            }
            let selectedType = self.chartViewController.chartType
            var actions: [UIAction] = []
            for chartType in ChartType.choices(for: self.chartViewController.market) {
                let action = UIAction(title: chartType.title) { [weak self] _ in
                    self?.chartViewController.chartType = chartType  // ボタンの表示は onChartTypeChange で更新される
                }
                if chartType == selectedType {
                    action.state = .on
                }
                actions.append(action)
            }
            completion(actions)
        }
        // ボタンの幅は、すべての種類の名前のうち一番長いもの(「折線チャート」など)が1行で入る幅にする
        let candidates = ChartType.allCases.map { chartType in chartType.title }
        self.footerView.setChartTypeMenu(title: self.chartViewController.chartType.title,
                                         candidates: candidates, menu: UIMenu(children: [items]))
    }

    // MARK: - 足種

    /// 「足種」ボタンの文字とメニュー(表示中の足種にチェック)を、表示中の足種に合わせる。
    /// メニューの中身は開くたびに作るので、指数の種類(海外指数は 日足・週足・月足 だけ)・
    /// チャートの種類(VWAP は 日中足 だけ、新値足・折線チャートは 1分足 を除く。ChartType.periods(in:))が後から変わっても反映される
    private func updatePeriodMenu() {
        let items = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self else {
                completion([])
                return
            }
            let selectedPeriod = self.chartViewController.period
            var actions: [UIAction] = []
            for period in self.availablePeriods {
                let action = UIAction(title: Self.shortTitle(of: period)) { [weak self] _ in
                    self?.onPeriodSelect?(period)
                }
                if period == selectedPeriod {
                    action.state = .on
                }
                actions.append(action)
            }
            completion(actions)
        }
        // ボタンの幅は、すべての足種の名前のうち一番長いもの(「1分足」「日中足」)が1行で入る幅にする
        let candidates = ChartPeriod.allCases.map { period in Self.shortTitle(of: period) }
        self.footerView.setPeriodMenu(title: Self.shortTitle(of: self.chartViewController.period),
                                      candidates: candidates, menu: UIMenu(children: [items]))
    }

    /// 今のチャートの種類・指数の種類で選べる足種(VWAP は 日中足 だけ、新値足・折線チャートは 1分足 を除く)
    private var availablePeriods: [ChartPeriod] {
        return self.chartViewController.chartType.periods(in: self.chartViewController.market)
    }

    /// 表示中の足種が今のチャートの種類では選べない場合(1分足のまま新値足・折線チャートにした・日足のまま VWAP にした など)、
    /// 選べる足種に切り替える。データの取得はアプリの仕事なので、足種のメニューで選んだときと同じく onPeriodSelect を呼ぶ
    /// (日中足を選べるなら 日中足 に切り替える。日中足も選べなければ、選べる足種の先頭)
    private func switchPeriodIfUnavailable() {
        let periods = self.availablePeriods
        if periods.contains(self.chartViewController.period) {
            return
        }
        var nextPeriod = periods.first
        if periods.contains(.intraday) {
            nextPeriod = .intraday
        }
        guard let nextPeriod else {
            return
        }
        self.onPeriodSelect?(nextPeriod)
    }

    /// ボタン・メニューに出す足種の名前。タブ用の名前(「月 足」)から空白を除く(「月足」)
    private static func shortTitle(of period: ChartPeriod) -> String {
        return period.title.replacingOccurrences(of: " ", with: "")
    }

    // MARK: - 指数名・現在値・日時

    /// 下の帯の左に、指数名・現在値・日時を表示する(例:「日経平均 68309.46 10/02 15:45」。書式は ChartFooterView)
    /// - Parameters:
    ///   - name: 指数名(「日経平均」など)
    ///   - price: 現在値。小数2桁で表示する(3桁区切りなし)
    ///   - date: 現在値の日時。「MM/dd HH:mm」で表示する
    @objc(updatePriceInfoWithName:price:date:)
    func updatePriceInfo(name: String, price: Double, date: Date) {
        // メインスレッドでなければ、メインスレッドで呼び直す(通信の完了処理から直接呼ばれても安全にする。MainThread)
        guard MainThread.isCurrent(orRetry: { self.updatePriceInfo(name: name, price: price, date: date) }) else {
            return
        }

        self.loadViewIfNeeded()
        self.footerView.updatePriceInfo(name: name, price: price, date: date)
    }

    // MARK: - データ

    /// ローソク足データを設定して描画する
    @objc func setCandles(_ candles: [StockCandle]) {
        // メインスレッドでなければ、メインスレッドで呼び直す(通信の完了処理から直接呼ばれても安全にする。MainThread)
        guard MainThread.isCurrent(orRetry: { self.setCandles(candles) }) else {
            return
        }

        self.chartViewController.setCandles(candles)
    }

    /// 足種を指定してローソク足データを設定し、描画する(足種ごとの指標パラメータ・日付の書式で表示する)。
    /// 足種のボタンの表示も、この足種に合わせる
    @objc func setCandles(_ candles: [StockCandle], period: ChartPeriod) {
        // メインスレッドでなければ、メインスレッドで呼び直す(通信の完了処理から直接呼ばれても安全にする。MainThread)
        guard MainThread.isCurrent(orRetry: { self.setCandles(candles, period: period) }) else {
            return
        }

        self.chartViewController.setCandles(candles, period: period)
        self.updatePeriodMenu()
    }
}

// MARK: - API のレスポンスの描画先にする

/// ChartResponseLoader の描画先にできるようにする(setCandles(_:period:) は上で定義済み)
extension LandscapeChartViewController: StockCandleReceiving {

    /// 指数の種類(共通チャート部品の market。設定は chartViewController.market で行う)
    var market: IndexMarket {
        return self.chartViewController.market
    }
}

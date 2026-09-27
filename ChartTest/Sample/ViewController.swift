//
//  ViewController.swift
//  ChartTest
//
//  Created by アキ on 2026/09/27.
//
//  【Controller】アプリ画面のサンプル。縦向き用のチャートと横画面用のチャート画面を置き、
//  画面の向きに合わせて表示を切り替える。
//
//  ・縦向き: StockChartView(チャートだけ。最初は日足を表示する)
//  ・横画面: LandscapeChartViewController(Landscape.storyboard。StockChartViewController で指標メニュー付き表示)
//  この画面は「どちらを表示するか」と「データを渡す」ことだけを担当する。
//  縦画面の左下の切り替えボタン(marketControl)で、日本株/国内指数/海外指数(リアルタイム・日次)を切り替えて表示を確かめられる
//  (横画面では下の帯と重なるので隠す。縦画面で切り替えてから横にする)。
//  チャートの上には縦向きのチャートの足種を切り替えるボタン(periodControl)を、下には横画面にするボタン(rotateButton)を置く
//  (どちらも縦画面だけに表示する。テスト用)。
//  横画面の下の帯(足種・更新・縦画面に戻す)が押されたときの処理も、ここで設定している(setupLandscapeFooter)。
//

import UIKit

class ViewController: UIViewController {

    // MARK: - Children

    /// 縦向きのチャート(チャートだけ。最初は日足を表示する)
    private let portraitChartView = StockChartView()
    /// 横画面のチャート(Landscape.storyboard)
    private let landscapeViewController = LandscapeChartViewController.instantiate()

    /// 現在の表示が横画面用か(nil = 未適用)
    private var isLandscapeLayout: Bool?

    // MARK: - 銘柄・指数の種類の切り替え

    /// 日本株/国内指数/海外指数を切り替えるボタン(左下。縦画面だけに表示する)
    private let marketControl = UISegmentedControl(items: ["日本株", "国内指数", "海外(R)", "海外(D)"])

    /// 切り替えボタンの並び順と同じ、銘柄・指数の種類
    private let marketChoices: [IndexMarket] = [.japanStock, .japanIndex, .overseasRealtime, .overseasDaily]

    /// 最初に表示する銘柄・指数の種類(国内指数)
    private let initialMarket = IndexMarket.japanIndex

    // MARK: - 縦向きのチャートの足種の切り替え(テスト用)

    /// 縦向きのチャートの足種を切り替えるボタン(チャートの上。縦画面だけに表示する)
    private let periodControl = UISegmentedControl()

    /// 切り替えボタンの並び順と同じ足種
    private let periodChoices: [ChartPeriod] = [.oneMinute, .intraday, .daily, .weekly, .monthly]

    /// 縦向きのチャートに表示している足種
    private var portraitPeriod = ChartPeriod.daily

    /// 表示している銘柄・指数の種類
    private var currentMarket = IndexMarket.japanIndex

    // MARK: - 横画面にするボタン(テスト用)

    /// 横画面にするボタン(チャートの下。縦画面だけに表示する)
    private let rotateButton = UIButton(configuration: .tinted())

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white

        // データを渡す前に埋め込んでおく(チャートが正しいサイズで初期表示位置を計算できるように)
        self.setupPortraitChartView()
        self.embed(self.landscapeViewController)
        self.applyLayout(isLandscape: self.view.bounds.width > self.view.bounds.height)

        // 横画面: 下の帯のボタンが押されたときの処理
        self.setupLandscapeFooter()

        // 縦向きのチャートの足種の切り替えボタンと、横画面にするボタン(テスト用)
        self.setupPeriodControl()
        self.setupRotateButton()

        // 日本株/国内指数/海外指数の切り替えボタン(最初は国内指数)
        self.setupMarketControl()
        self.showCharts(for: self.initialMarket)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 画面の縦横が変わったら表示を切り替える
        let isLandscape = self.view.bounds.width > self.view.bounds.height
        if isLandscape != self.isLandscapeLayout {
            self.applyLayout(isLandscape: isLandscape)
        }
    }

    // MARK: - Setup

    /// 縦向きのチャートを画面の上のほうに置く(高さを決めないと何も見えない)。
    /// 上端は、足種の切り替えボタンの下に合わせる(setupPeriodControl)
    private func setupPortraitChartView() {
        self.portraitChartView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.portraitChartView)
        NSLayoutConstraint.activate([
            self.portraitChartView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 8),
            self.portraitChartView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.portraitChartView.heightAnchor.constraint(equalToConstant: 260),
        ])
    }

    /// 子 ViewController を画面いっぱいに埋め込む
    private func embed(_ child: UIViewController) {
        self.addChild(child)
        let childView = child.view!
        childView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(childView)
        NSLayoutConstraint.activate([
            childView.topAnchor.constraint(equalTo: self.view.topAnchor),
            childView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            childView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            childView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
        ])
        child.didMove(toParent: self)
    }

    // MARK: - 縦向きのチャートの足種(テスト用)

    /// 足種の切り替えボタンを画面の上端(チャートの上)に置く
    private func setupPeriodControl() {
        for (index, period) in self.periodChoices.enumerated() {
            self.periodControl.insertSegment(withTitle: period.title, at: index, animated: false)
        }
        if let index = self.periodChoices.firstIndex(of: self.portraitPeriod) {
            self.periodControl.selectedSegmentIndex = index
        }
        self.periodControl.addTarget(self, action: #selector(self.periodControlChanged), for: .valueChanged)
        self.periodControl.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.periodControl)
        NSLayoutConstraint.activate([
            self.periodControl.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16),
            self.periodControl.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            self.periodControl.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            self.periodControl.heightAnchor.constraint(equalToConstant: 36),
            self.portraitChartView.topAnchor.constraint(equalTo: self.periodControl.bottomAnchor, constant: 16),
        ])
    }

    /// 足種の切り替えボタンが押されたら、縦向きのチャートをその足種のデータで描き直す
    @objc private func periodControlChanged() {
        let index = self.periodControl.selectedSegmentIndex
        guard self.periodChoices.indices.contains(index) else {
            return
        }
        self.portraitPeriod = self.periodChoices[index]
        self.showPortraitChart()
    }

    /// 足種の切り替えボタンを、指数の種類で選べる足種だけ押せるようにする。
    /// 表示中の足種が選べない場合(海外指数の1分足・日中足)は日足にする
    private func updatePeriodControl(for market: IndexMarket) {
        for (index, period) in self.periodChoices.enumerated() {
            self.periodControl.setEnabled(market.periods.contains(period), forSegmentAt: index)
        }
        if !market.periods.contains(self.portraitPeriod) {
            self.portraitPeriod = .daily
        }
        if let index = self.periodChoices.firstIndex(of: self.portraitPeriod) {
            self.periodControl.selectedSegmentIndex = index
        }
    }

    /// 縦向きのチャートを、表示中の足種・指数の種類のデータで描き直す
    private func showPortraitChart() {
        self.portraitChartView.setCandles(SampleData.candles(for: self.portraitPeriod), period: self.portraitPeriod,
                                          market: self.currentMarket)
    }

    // MARK: - 横画面にする(テスト用)

    /// 横画面にするボタンを、チャートの下に置く
    private func setupRotateButton() {
        self.rotateButton.configuration?.title = "横画面にする"
        self.rotateButton.configuration?.image = UIImage(systemName: "rectangle.landscape.rotate")
        self.rotateButton.configuration?.imagePadding = 6
        self.rotateButton.addTarget(self, action: #selector(self.rotateButtonTapped), for: .touchUpInside)
        self.rotateButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.rotateButton)
        NSLayoutConstraint.activate([
            self.rotateButton.topAnchor.constraint(equalTo: self.portraitChartView.bottomAnchor, constant: 16),
            self.rotateButton.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            self.rotateButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    /// 横画面にするボタンが押されたら、画面を横向きにする(横画面のチャートに切り替わる)
    @objc private func rotateButtonTapped() {
        self.view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
    }

    // MARK: - 日本株/国内指数/海外指数

    /// 切り替えボタンを左下に置く(チャート画面より手前)
    private func setupMarketControl() {
        // 最初に表示する種類のボタンを選んだ状態にする
        if let index = self.marketChoices.firstIndex(of: self.initialMarket) {
            self.marketControl.selectedSegmentIndex = index
        }
        self.marketControl.addTarget(self, action: #selector(self.marketControlChanged), for: .valueChanged)
        self.marketControl.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.marketControl)
        NSLayoutConstraint.activate([
            self.marketControl.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            self.marketControl.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            self.marketControl.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    /// 切り替えボタンが押されたら、選ばれた指数の種類で表示し直す
    @objc private func marketControlChanged() {
        let index = self.marketControl.selectedSegmentIndex
        guard self.marketChoices.indices.contains(index) else {
            return
        }
        self.showCharts(for: self.marketChoices[index])
    }

    /// 縦向き・横画面のチャートを、指定した指数の種類で表示し直す。
    /// 指数の種類は、データを渡す前に設定する(描き方・選べる足種や指標が変わるため)
    ///   ・国内指数: 縦向きは ローソク足 + 移動平均線 + 出来高
    ///   ・海外指数(R・D とも同じ): 縦向きは ローソク足 + 移動平均線(サブチャートなし)。
    ///              横画面は テクニカルが 移動平均線・なし、チャートの種類が ローソク足・折線チャート だけ
    /// (サンプルなので、海外指数でも同じダミーデータを使う)
    private func showCharts(for market: IndexMarket) {
        // 縦向き: 表示中の足種のデータを、指数の種類に合わせて描き直す(海外指数で選べない足種なら日足にする)
        self.currentMarket = market
        self.updatePeriodControl(for: market)
        self.showPortraitChart()

        // 横画面: market を変えると、国内/海外ごとに前回選んでいた足種(初めてなら日足)が period に入るので、
        // その足種のデータを渡す。下の帯の指数名・現在値も変える
        self.landscapeViewController.chartViewController.market = market
        let period = self.landscapeViewController.chartViewController.period
        self.landscapeViewController.setCandles(SampleData.candles(for: period), period: period)
        self.updateLandscapePriceInfo()
    }

    // MARK: - 横画面の下の帯

    /// 横画面の下の帯のボタンが押されたときの処理を設定する
    /// (サンプルなので SampleData から読み込む。実際のアプリでは API から取得して setCandles(_:period:) で渡す)
    private func setupLandscapeFooter() {
        // 足種が選ばれたら、その足種のデータを渡す(足種のボタンの表示も切り替わる)
        self.landscapeViewController.onPeriodSelect = { [weak self] period in
            self?.landscapeViewController.setCandles(SampleData.candles(for: period), period: period)
        }
        // 更新: 表示中の足種のデータを読み込み直し、現在値も更新する
        self.landscapeViewController.onReload = { [weak self] in
            guard let self else {
                return
            }
            let period = self.landscapeViewController.chartViewController.period
            self.landscapeViewController.setCandles(SampleData.candles(for: period), period: period)
            self.updateLandscapePriceInfo()
        }
        // 縦画面に戻す
        self.landscapeViewController.onRotate = { [weak self] in
            self?.view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }

    /// 横画面の下の帯に、指数名・現在値・日時を表示する
    /// (サンプルなので、当日の1分足の最後の足の終値・時刻を現在値として使う。どの足種を表示していても同じ値)
    private func updateLandscapePriceInfo() {
        var name = "日経平均"
        switch self.landscapeViewController.chartViewController.market {
        case .japanStock:
            name = "サンプル銘柄"
        case .japanIndex:
            break
        case .overseasRealtime:
            name = "NYダウ"
        case .overseasDaily:
            name = "NYダウ(日次)"
        }
        self.landscapeViewController.updatePriceInfo(name: name, price: SampleData.latestPrice, date: SampleData.latestDate)
    }

    // MARK: - Layout switching

    /// 縦向き/横画面のチャートを切り替える
    private func applyLayout(isLandscape: Bool) {
        self.isLandscapeLayout = isLandscape
        self.portraitChartView.isHidden = isLandscape
        self.landscapeViewController.view.isHidden = !isLandscape
        // 切り替えボタン・横画面にするボタンは縦画面だけ(横画面では下の帯の文字と重なるため)
        self.marketControl.isHidden = isLandscape
        self.periodControl.isHidden = isLandscape
        self.rotateButton.isHidden = isLandscape
    }
}

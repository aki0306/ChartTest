//
//  ViewController.swift
//  ChartTest
//
//  Created by アキ on 2026/09/27.
//
//  【Controller】アプリ画面のサンプル。縦向きのチャートを置き、ボタンで横画面のチャート画面を全画面で表示(present)する。
//
//  ・縦向き: StockChartView(チャートだけ。最初は日足を表示する)。この画面は縦向きだけで表示する(supportedInterfaceOrientations)
//  ・横画面: LandscapeChartViewController(LandscapeChartViewController.storyboard。指標メニュー・設定画面付き)。
//           チャートの下の「横画面にする」ボタン(rotateButton)で present すると横向きになり、
//           下の帯の「縦画面に戻す」ボタンで閉じる(dismiss)と縦向きに戻る。
//           端末を横に向けても開き(deviceOrientationDidChange)、縦に戻すと閉じる(LandscapeChartViewController が onRotate を呼ぶ)
//  この画面は「横画面を開く」ことと「データを渡す」ことだけを担当する。
//  左下の切り替えボタン(marketControl)で、日本株/国内指数/海外指数(リアルタイム・日次)を切り替えて表示を確かめられる
//  (横画面は、開いたときに選んでいる種類で表示する)。
//  チャートの上には縦向きのチャートの足種を切り替えるボタン(periodControl)を置く(テスト用)。
//  横画面の下の帯(足種・更新・縦画面に戻す)が押されたときの処理も、ここで設定している(presentLandscapeChart)。
//

import UIKit

class ViewController: UIViewController {

    // MARK: - Children

    /// 縦向きのチャート(チャートだけ。最初は日足を表示する)
    private let portraitChartView = StockChartView()

    // MARK: - 銘柄・指数の種類の切り替え

    /// 日本株/国内指数/海外指数を切り替えるボタン(左下)
    private let marketControl = UISegmentedControl(items: ["日本株", "国内指数", "海外(R)", "海外(D)"])

    /// 切り替えボタンの並び順と同じ、銘柄・指数の種類
    private let marketChoices: [IndexMarket] = [.japanStock, .japanIndex, .overseasRealtime, .overseasDaily]

    /// 最初に表示する銘柄・指数の種類(国内指数)
    private let initialMarket = IndexMarket.japanIndex

    // MARK: - 縦向きのチャートの足種の切り替え(テスト用)

    /// 縦向きのチャートの足種を切り替えるボタン(チャートの上)
    private let periodControl = UISegmentedControl()

    /// 切り替えボタンの並び順と同じ足種
    private let periodChoices: [ChartPeriod] = [.oneMinute, .intraday, .daily, .weekly, .monthly]

    /// 縦向きのチャートに表示している足種
    private var portraitPeriod = ChartPeriod.daily

    /// 表示している銘柄・指数の種類
    private var currentMarket = IndexMarket.japanIndex

    // MARK: - 横画面にするボタン

    /// 横画面のチャートを開くボタン(チャートの下)
    private let rotateButton = UIButton(configuration: .tinted())

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(resource: .sampleBackground)

        self.setupPortraitChartView()

        // 縦向きのチャートの足種の切り替えボタン(テスト用)と、横画面にするボタン
        self.setupPeriodControl()
        self.setupRotateButton()

        // 日本株/国内指数/海外指数の切り替えボタン(最初は国内指数)
        self.setupMarketControl()
        self.showPortraitChart(for: self.initialMarket)
    }

    // MARK: - 画面の向き

    /// この画面は縦向きだけで表示する(横画面のチャートは present で開く。LandscapeChartViewController は横向きだけ)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    /// 最後に分かった端末の向き(縦か横だけを覚える。机に置いたときなどの向きは無視する)
    private var lastDeviceOrientation = UIDeviceOrientation.unknown

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 端末を横に向けたら横画面のチャートを開けるよう、端末の向きの変化を受け取る
        // (横画面のチャートを開いている間は、viewWillDisappear で受け取るのをやめる)
        self.lastDeviceOrientation = UIDevice.current.orientation
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(self.deviceOrientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    /// 端末の向きが変わったとき。縦から横に変わったら、横画面のチャートを開く
    /// (横に持ったまま「縦画面に戻す」で閉じたときに、すぐ開き直さないよう、縦を経由したときだけにする)
    @objc private func deviceOrientationDidChange() {
        let orientation = UIDevice.current.orientation
        if orientation.isLandscape {
            let wasLandscape = self.lastDeviceOrientation.isLandscape
            self.lastDeviceOrientation = orientation
            guard !wasLandscape else {
                return
            }
            guard self.presentedViewController == nil else {
                return
            }
            self.presentLandscapeChart()
            return
        }
        if orientation == .portrait {
            self.lastDeviceOrientation = orientation
        }
    }

    // MARK: - Setup

    /// 縦向きのチャートを画面の上のほうに置く(高さを決めないと何も見えない)。
    /// 上端は、足種の切り替えボタンの下に合わせる(setupPeriodControl)
    private func setupPortraitChartView() {
        self.portraitChartView.translatesAutoresizingMaskIntoConstraints = false
        self.portraitChartView.accessibilityIdentifier = "portrait.chartView"  // UI テストで探すための名前
        self.view.addSubview(self.portraitChartView)
        NSLayoutConstraint.activate([
            // 左右は安全な領域に合わせる(カメラの穴やステータスバーが横にある画面で、チャートが隠れないように)
            self.portraitChartView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            self.portraitChartView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
            self.portraitChartView.heightAnchor.constraint(equalToConstant: 260),
        ])
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
        self.periodControl.accessibilityIdentifier = "portrait.periodControl"  // UI テストで探すための名前
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

    // MARK: - 横画面にする

    /// 横画面にするボタンを、チャートの下に置く
    private func setupRotateButton() {
        self.rotateButton.configuration?.title = "横画面にする"
        self.rotateButton.configuration?.image = UIImage(systemName: "rectangle.landscape.rotate")
        self.rotateButton.configuration?.imagePadding = 6
        self.rotateButton.addTarget(self, action: #selector(self.rotateButtonTapped), for: .touchUpInside)
        self.rotateButton.translatesAutoresizingMaskIntoConstraints = false
        self.rotateButton.accessibilityIdentifier = "portrait.rotateButton"  // UI テストで探すための名前
        self.view.addSubview(self.rotateButton)
        NSLayoutConstraint.activate([
            self.rotateButton.topAnchor.constraint(equalTo: self.portraitChartView.bottomAnchor, constant: 16),
            self.rotateButton.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            self.rotateButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    /// 横画面にするボタンが押されたら、横画面のチャートを全画面で表示する(横向きになる)
    @objc private func rotateButtonTapped() {
        self.presentLandscapeChart()
    }

    // MARK: - 日本株/国内指数/海外指数

    /// 切り替えボタンを左下に置く
    private func setupMarketControl() {
        // 最初に表示する種類のボタンを選んだ状態にする
        if let index = self.marketChoices.firstIndex(of: self.initialMarket) {
            self.marketControl.selectedSegmentIndex = index
        }
        self.marketControl.addTarget(self, action: #selector(self.marketControlChanged), for: .valueChanged)
        self.marketControl.translatesAutoresizingMaskIntoConstraints = false
        self.marketControl.accessibilityIdentifier = "portrait.marketControl"  // UI テストで探すための名前
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
        self.showPortraitChart(for: self.marketChoices[index])
    }

    /// 縦向きのチャートを、指定した指数の種類で表示し直す(海外指数で選べない足種なら日足にする)。
    ///   ・国内指数: ローソク足 + 移動平均線 + 出来高
    ///   ・海外指数(R・D とも同じ): ローソク足 + 移動平均線(サブチャートなし)
    /// 横画面のチャートは、開くときにこの種類で表示する(presentLandscapeChart)
    /// (サンプルなので、海外指数でも同じダミーデータを使う)
    private func showPortraitChart(for market: IndexMarket) {
        self.currentMarket = market
        self.updatePeriodControl(for: market)
        self.showPortraitChart()
    }

    // MARK: - 横画面のチャート

    /// 横画面のチャートを作り、データと下の帯のボタンの処理を設定して、全画面で表示する。
    /// 開くたびに作り直す(チャートの種類・指標・足種などは ChartStateStore が覚えているので、前回の状態で開く)。
    /// (サンプルなので SampleData から読み込む。実際のアプリでは API から取得して setCandles(_:period:) で渡す)
    private func presentLandscapeChart() {
        let landscapeViewController = LandscapeChartViewController.instantiate()

        // 指数の種類は、データを渡す前に設定する(描き方・選べる足種や指標が変わるため)。
        //   ・国内指数: テクニカル・チャートの種類はすべて選べる
        //   ・海外指数: テクニカルが 移動平均線・なし、チャートの種類が ローソク足・折線チャート だけ
        // market を設定すると、国内/海外ごとに前回選んでいた足種(初めてなら日足)が period に入るので、その足種のデータを渡す
        landscapeViewController.market = self.currentMarket
        let initialPeriod = landscapeViewController.period
        landscapeViewController.setCandles(SampleData.candles(for: initialPeriod), period: initialPeriod)
        self.updatePriceInfo(of: landscapeViewController)

        // 足種が選ばれたら、その足種のデータを渡す(足種のボタンの表示も切り替わる)
        landscapeViewController.onPeriodSelect = { [weak landscapeViewController] period in
            landscapeViewController?.setCandles(SampleData.candles(for: period), period: period)
        }
        // 更新: 表示中の足種のデータを読み込み直し、現在値も更新する
        landscapeViewController.onReload = { [weak self, weak landscapeViewController] in
            guard let self else {
                return
            }
            guard let landscapeViewController else {
                return
            }
            let period = landscapeViewController.period
            landscapeViewController.setCandles(SampleData.candles(for: period), period: period)
            self.updatePriceInfo(of: landscapeViewController)
        }
        // 縦画面に戻す: 閉じると、この画面の向き(縦)に戻る
        landscapeViewController.onRotate = { [weak landscapeViewController] in
            landscapeViewController?.dismiss(animated: true)
        }

        self.present(landscapeViewController, animated: true)
    }

    /// 横画面の下の帯に、指数名・現在値・日時を表示する
    /// (サンプルなので、当日の1分足の最後の足の終値・時刻を現在値として使う。どの足種を表示していても同じ値)
    private func updatePriceInfo(of landscapeViewController: LandscapeChartViewController) {
        var name = "日経平均"
        switch landscapeViewController.market {
        case .japanStock:
            name = "サンプル銘柄"
        case .japanIndex:
            break
        case .overseasRealtime:
            name = "NYダウ"
        case .overseasDaily:
            name = "NYダウ(日次)"
        }
        landscapeViewController.updatePriceInfo(name: name, price: SampleData.latestPrice, date: SampleData.latestDate)
    }
}

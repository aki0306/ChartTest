//
//  StockChartViewController.swift
//  ChartTest
//
//  【Controller】株価チャート部品の制御を担当する ViewController。
//
//  【責務】
//  ・状態の保持: ローソク足データ・足種・チャートの種類・選択中の指標・指標パラメータ(足種ごと)・表示オプション
//  ・Model(ChartContentBuilder)で描画内容を組み立て、View(StockChartView)に渡す
//  ・View(TechnicalMenuView / ChartSettingsView)からの操作を受け取り、状態を更新して再描画する
//  ・テクニカル/設定タブの表示/非表示と、各パネルの開閉
//
//  ┌──┬─────────────────────┐
//  │テ│                     │
//  │ク│                     │  ← isTechnicalMenuEnabled = true のとき左端にタブを表示する
//  │ニ│   StockChartView    │    ・テクニカル: 指標の選択メニュー(TechnicalMenuView)を開閉
//  │カ│                     │    ・設定: 表示オプション・指標パラメータの設定画面(ChartSettingsView)を開閉
//  │ル│                     │
//  ├──┤                     │
//  │設│                     │
//  │定│                     │
//  └──┴─────────────────────┘
//
//  使い方(子 ViewController として画面に埋め込む):
//      let chartViewController = StockChartViewController()
//      addChild(chartViewController)
//      view.addSubview(chartViewController.view)   // 制約はお好みで
//      chartViewController.didMove(toParent: self)
//      chartViewController.setCandles(candles)
//      chartViewController.isTechnicalMenuEnabled = true   // 横画面のときだけ true にする等
//

import UIKit

final class StockChartViewController: UIViewController {

    // MARK: - 状態(Model の状態)

    /// 表示中のローソク足データ(古い順)
    private var candles: [StockCandle] = []

    /// 表示中のデータの足種。使う指標パラメータ(足種ごと)と、設定画面を開いたときのタブを決める。
    /// setCandles(_:period:) で設定する(setCandles(_:) の場合は日足のまま)
    @objc private(set) var period: ChartPeriod = .daily

    /// 指数の種類(国内/海外)。種類によって、選べるもの・使えるものが変わる。
    ///
    ///   | 項目                     | 国内指数       | 海外指数                                      |
    ///   |--------------------------|----------------|-----------------------------------------------|
    ///   | テクニカル(メイン)       | すべて         | 移動平均線・なし                              |
    ///   | テクニカル(サブ)         | すべて         | なし(サブチャートは表示しない)              |
    ///   | 設定画面の項目           | すべて         | オプション・移動平均線                        |
    ///   | 設定画面のオプション     | すべて         | Y軸(メイン)固定・4本値(Y軸(サブ)固定はオンでも効かない) |
    ///   | 設定画面の足種のタブ     | 1分足〜月足    | 日足・週足・月足(1分足・日中足のタブは出さない)      |
    ///   | チャートの種類           | すべて         | ローソク足・折線チャート                      |
    ///
    /// 海外指数に変えたとき、選べない指標・チャートの種類を選んでいた場合は
    /// 移動平均線・サブなし・ローソク足 に切り替える
    @objc var market: IndexMarket = .domestic {
        didSet {
            guard market != oldValue else { return }
            applyMarket(previousMarket: oldValue)
        }
    }

    /// 足種ごとの指標の計算パラメータ。設定画面で足種ごとに変えられる。
    /// 初期値は足種に合わせたもの(週足の移動平均は 13/26 など。ChartPeriod.indicatorParameters)
    private var parametersByPeriod = StockChartViewController.defaultParametersByPeriod()

    /// 表示中の足種の指標パラメータ。変更すると再描画する
    var parameters: IndicatorParameters {
        get { parameters(for: period) }
        set {
            parametersByPeriod[period] = newValue
            reloadChart(keepsViewport: true)
        }
    }

    /// 表示オプション(Y軸固定・4本値)。変更すると即座にチャートへ反映する
    var displayOptions = ChartDisplayOptions() {
        didSet {
            applyDisplayOptionsToChart()
            // 設定画面でオプションを表示中なら、トグルの状態を合わせる
            if selectedSettingsItem == .displayOptions {
                reloadSettingsRows()
            }
        }
    }

    /// チャートの種類(ローソク足・VWAP・新値足・折線チャート)。
    /// ローソク足以外では、テクニカル指標とサブチャートは表示せず、テクニカルのメニューは「なし」だけにする。
    /// 4本値は、オンにしていてもローソク足のときだけ表示する
    @objc var chartType: ChartType = .candlestick {
        didSet {
            guard chartType != oldValue else { return }
            menuView.allowsOnlyNone = !chartType.usesTechnicalIndicators(in: market)
            applyDisplayOptionsToChart()
            reloadChart(keepsViewport: true)
            onChartTypeChange?(chartType)
        }
    }

    /// チャートの種類が変わったときに呼ばれる処理(種類を選ぶボタンの表示を合わせる場合など)
    var onChartTypeChange: ((ChartType) -> Void)?

    /// テクニカル/設定のパネルを開いた・閉じたときに呼ばれる処理(true = 開いた)。
    /// この画面の外(下のボタンなど)の背景もグレーにする場合に使う
    var onPanelVisibilityChange: ((Bool) -> Void)?

    /// パネルを開いているときに、後ろ(チャート)に重ねる色。半透明の黒で、背景をグレーに見せる
    static let dimmingColor = UIColor.black.withAlphaComponent(0.35)

    /// メインチャートに表示する指標。変更すると表示位置を保ったまま再描画する
    @objc var mainIndicator: MainChartIndicator = .movingAverage {
        didSet {
            guard mainIndicator != oldValue else { return }
            menuView.selectedMainIndicator = mainIndicator
            reloadChart(keepsViewport: true)
        }
    }

    /// サブチャートに表示する指標。.hidden にするとサブチャートを隠す
    @objc var subIndicator: SubChartIndicator = .volume {
        didSet {
            guard subIndicator != oldValue else { return }
            menuView.selectedSubIndicator = subIndicator
            reloadChart(keepsViewport: true)
        }
    }

    /// チャート(とテクニカル/設定タブ)を、この View のセーフエリアの端からどれだけ内側に置くか。
    /// テクニカル/設定のパネルと背景のグレーは、この余白に関係なく、この View の上端〜下端いっぱいに表示する。
    /// (例: この View を画面いっぱいに置き、下にボタンを並べる場合は bottom にボタンの分の余白を取る)
    @objc var chartInsets: UIEdgeInsets = .zero {
        didSet { applyChartInsets() }
    }

    /// テクニカル/設定のパネルの下端を、セーフエリアの下端からどれだけ上で止めるか(既定は 0 = セーフエリアの下端まで)。
    /// パネルの上端は、この View の上端(セーフエリアの外)から表示する
    @objc var panelBottomInset: CGFloat = 0 {
        didSet {
            for constraint in [menuBottomConstraint, settingsBottomConstraint] {
                constraint?.constant = -panelBottomInset
            }
        }
    }

    /// テクニカル/設定タブを使えるようにするか。
    /// false にするとタブとパネルを隠し、チャートを全幅で表示する(例: 横画面のときだけ true)
    @objc var isTechnicalMenuEnabled = false {
        didSet {
            guard isTechnicalMenuEnabled != oldValue else { return }
            updateMenuAvailability()
        }
    }

    // MARK: - 部品(View)

    /// チャート本体。見た目は chartView.style で変更できる
    @objc let chartView = StockChartView()
    /// パネルを開いているときにチャートの上に重ねる、半透明の黒(背景をグレーにする)。タップするとパネルを閉じる
    private let dimmingView = UIView()
    /// 指標の選択メニュー
    private let menuView = TechnicalMenuView()
    /// 設定画面
    private let settingsView = ChartSettingsView()
    /// テクニカルタブ(指標の選択メニューを開閉)
    private let technicalTabButton = UIButton(type: .custom)
    /// 設定タブ(設定画面を開閉)
    private let settingsTabButton = UIButton(type: .custom)
    /// 2つのタブを縦に並べるスタック
    private let tabStack = UIStackView()

    // MARK: - パネル(テクニカル/設定)の状態

    /// 開閉できるパネルの種類
    private enum Panel {
        /// 指標の選択メニュー
        case technical
        /// 設定画面
        case settings
    }

    /// 開いているパネル(nil = どちらも閉じている)
    private var openPanel: Panel?

    /// テクニカル/設定のパネルを開いているか
    var isPanelOpen: Bool {
        return openPanel != nil
    }

    /// 設定画面の左側リストで選択中の位置
    private var selectedSettingsIndexPath = IndexPath(row: 0, section: 0)

    /// 設定画面の左側リストに並べる見出しと項目(指数の種類で変わる)
    private var settingsSections: [ChartSettingsSection] {
        ChartSettingsCatalog.sections(for: market)
    }

    /// 設定画面で選択中の項目
    private var selectedSettingsItem: ChartSettingsItem {
        settingsSections[selectedSettingsIndexPath.section].items[selectedSettingsIndexPath.row]
    }

    /// 設定画面で選択中の足種(タブ)
    private var settingsPeriod: ChartPeriod = .daily

    /// 設定画面で編集中のパラメータ(足種ごと)。
    /// 設定画面を開くたびに今のパラメータから作り直し、「決定」を押すと parametersByPeriod に反映する
    /// (決定せずに閉じた場合は捨てる)
    private var draftParametersByPeriod: [ChartPeriod: IndicatorParameters] = [:]

    // MARK: - レイアウト

    /// タブの幅
    private let tabWidth: CGFloat = 30
    /// タブとチャートの間隔
    private let tabSpacing: CGFloat = 8

    /// チャートの左端(タブの有無・chartInsets で位置が変わる)
    private var chartLeadingConstraint: NSLayoutConstraint?
    /// チャートの上端・下端・右端(chartInsets で位置が変わる)
    private var chartTopConstraint: NSLayoutConstraint?
    private var chartBottomConstraint: NSLayoutConstraint?
    private var chartTrailingConstraint: NSLayoutConstraint?
    /// テクニカルのメニュー・設定画面の下端(panelBottomInset で位置が変わる)
    private var menuBottomConstraint: NSLayoutConstraint?
    private var settingsBottomConstraint: NSLayoutConstraint?
    /// タブの左端: パネルを閉じているとき(このViewの左端に付ける)
    private var tabClosedConstraint: NSLayoutConstraint?
    /// タブの左端: 指標の選択メニューを開いているとき(メニューの右端に付ける)
    private var tabTechnicalOpenedConstraint: NSLayoutConstraint?
    /// タブの左端: 設定画面を開いているとき(設定画面の右端に付ける)
    private var tabSettingsOpenedConstraint: NSLayoutConstraint?

    // MARK: - ライフサイクル

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        setupChartView()
        setupPanels()
        setupTabs()
        configureSettingsView()
        updateMenuAvailability()
    }

    // MARK: - 外から呼ぶ入口

    /// ローソク足データを設定して描画する。
    /// Objective-C からは `[chartViewController setCandles:candles]` で呼び出せる。
    /// - Parameter candles: 日付の古い順に並んだローソク足データ
    @objc func setCandles(_ candles: [StockCandle]) {
        self.candles = candles
        reloadChart(keepsViewport: false)
    }

    /// 足種を指定してローソク足データを設定し、描画する。
    /// 足種によって、使う指標パラメータ(足種ごと)と、X軸の日付の書式・初期表示本数が変わる。
    /// Objective-C からは `[chartViewController setCandles:candles period:ChartPeriodWeekly]` で呼び出せる。
    /// - Parameters:
    ///   - candles: 日付の古い順に並んだローソク足データ(その足種のデータ)
    ///   - period: 足種
    @objc func setCandles(_ candles: [StockCandle], period: ChartPeriod) {
        self.period = period

        // 足種に合わせて見た目を変える(style を変えると描き直されるので、まとめて1回で代入する)
        var newStyle = chartView.style
        newStyle.dateFormat = period.dateFormat
        newStyle.xAxisLabelCount = period.xAxisLabelCount
        newStyle.visibleCount = period.visibleCount
        chartView.style = newStyle

        setCandles(candles)
    }

    /// すべての足種の指標パラメータを変更して、描き直す(Swift からも使える)。
    /// 例: chartViewController.updateParametersForAllPeriods { $0.rsiPeriod = 9 }
    /// 表示中の足種だけを変える場合は parameters を、足種を指定する場合は setParameters(_:for:) を使う
    func updateParametersForAllPeriods(_ change: (inout IndicatorParameters) -> Void) {
        for period in ChartPeriod.allCases {
            var target = parameters(for: period)
            change(&target)
            parametersByPeriod[period] = target
        }
        reloadChart(keepsViewport: true)
    }

    /// 指定した足種の指標パラメータを変更して、描き直す
    func setParameters(_ parameters: IndicatorParameters, for period: ChartPeriod) {
        parametersByPeriod[period] = parameters
        reloadChart(keepsViewport: true)
    }

    /// 指定した足種の指標パラメータ
    func parameters(for period: ChartPeriod) -> IndicatorParameters {
        if let parameters = parametersByPeriod[period] {
            return parameters
        }
        return period.indicatorParameters
    }

    /// 足種ごとのパラメータの初期値(足種に合わせたもの)
    private static func defaultParametersByPeriod() -> [ChartPeriod: IndicatorParameters] {
        var result: [ChartPeriod: IndicatorParameters] = [:]
        for period in ChartPeriod.allCases {
            result[period] = period.indicatorParameters
        }
        return result
    }

    // MARK: - 描画(Model → View)

    /// 現在の状態から Model で描画内容を組み立て、View に表示させる
    /// - Parameter keepsViewport: true の場合、可能であれば現在の表示位置・拡大率を維持する
    private func reloadChart(keepsViewport: Bool) {
        guard !candles.isEmpty else {
            chartView.clear()
            return
        }
        let builder = ChartContentBuilder(candles: candles, parameters: parameters)
        let content = builder.content(for: chartType, mainIndicator: mainIndicator, subIndicator: subIndicator,
                                      market: market)
        chartView.display(candles: content.candles,
                          main: content.main,
                          sub: content.sub,
                          keepsViewport: keepsViewport)
    }

    /// 表示オプションをチャートに反映する。
    /// 4本値(十字線)はローソク足の4本値を表示するためのものなので、ローソク足以外(VWAP・新値足・折線チャート)では
    /// 設定がオンでも表示しない(海外指数の折線チャートも同じ。設定の値はそのまま残し、ローソク足に戻すと表示される)
    private func applyDisplayOptionsToChart() {
        var options = displayOptions
        if chartType != .candlestick {
            options.showsOHLC = false
        }
        // この指数で使えないオプション(海外指数の Y軸(サブ)固定)は、オンでも効かないようにする
        // (設定の値は残すので、国内指数に戻すと元の状態で表示される)
        let availableOptions = ChartDisplayOption.options(for: market)
        for option in ChartDisplayOption.allCases where !availableOptions.contains(option) {
            options[keyPath: option.keyPath] = false
        }
        chartView.displayOptions = options
    }

    // MARK: - 組み立て

    /// チャートを配置する(上下右はこのViewいっぱい、左端はタブの有無で変わる)
    private func setupChartView() {
        chartView.translatesAutoresizingMaskIntoConstraints = false
        applyDisplayOptionsToChart()
        view.addSubview(chartView)

        // チャートはセーフエリアの内側に、chartInsets の余白を空けて置く(余白の値は applyChartInsets で設定)
        let safeArea = view.safeAreaLayoutGuide
        let leading = chartView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor)
        let top = chartView.topAnchor.constraint(equalTo: safeArea.topAnchor)
        let bottom = chartView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        let trailing = chartView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor)
        NSLayoutConstraint.activate([leading, top, bottom, trailing])
        chartLeadingConstraint = leading
        chartTopConstraint = top
        chartBottomConstraint = bottom
        chartTrailingConstraint = trailing
        applyChartInsets()
    }

    /// chartInsets とタブの有無に合わせて、チャートの位置を決める
    private func applyChartInsets() {
        guard isViewLoaded else { return }  // viewDidLoad で改めて呼ばれる
        chartTopConstraint?.constant = chartInsets.top
        chartBottomConstraint?.constant = -chartInsets.bottom
        chartTrailingConstraint?.constant = -chartInsets.right

        // 左端: タブがあるときはタブの右側から表示する
        if isTechnicalMenuEnabled {
            chartLeadingConstraint?.constant = chartInsets.left + tabWidth + tabSpacing
        } else {
            chartLeadingConstraint?.constant = chartInsets.left
        }
        tabClosedConstraint?.constant = chartInsets.left
    }

    /// 指標の選択メニューと設定画面を配置する(どちらも初期状態は閉じている)
    private func setupPanels() {
        // 背景をグレーにする半透明の黒: チャートの上・パネルの下に、このViewいっぱいに重ねる(閉じているときは隠す)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.backgroundColor = Self.dimmingColor
        dimmingView.alpha = 0
        dimmingView.isHidden = true
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimmingViewTapped)))
        view.addSubview(dimmingView)
        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // パネルは、この View の上端(セーフエリアの外)から、セーフエリアの下端までに表示する。
        // 左右はセーフエリアの内側(横画面のノッチを避ける)
        let safeArea = view.safeAreaLayoutGuide

        // パネルの下端はセーフエリアの下端(ホームインジケーターの上)で止め、さらに panelBottomInset の分だけあける
        let menuBottom = menuView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -panelBottomInset)
        let settingsBottom = settingsView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -panelBottomInset)
        menuBottomConstraint = menuBottom
        settingsBottomConstraint = settingsBottom

        // 指標の選択メニュー: このViewの左側に幅 45% で表示
        menuView.translatesAutoresizingMaskIntoConstraints = false
        menuView.isHidden = true
        menuView.delegate = self
        menuView.selectedMainIndicator = mainIndicator
        menuView.selectedSubIndicator = subIndicator
        menuView.allowsOnlyNone = !chartType.usesTechnicalIndicators(in: market)
        menuView.availableMainIndicators = MainChartIndicator.choices(for: market)
        menuView.availableSubIndicators = SubChartIndicator.choices(for: market)
        view.addSubview(menuView)

        // 設定画面: このViewの左側に幅 75% で表示(左側リスト + 右側パネル)
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        settingsView.isHidden = true
        settingsView.delegate = self
        view.addSubview(settingsView)

        NSLayoutConstraint.activate([
            menuView.topAnchor.constraint(equalTo: view.topAnchor),
            menuBottom,
            menuView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            menuView.widthAnchor.constraint(equalTo: safeArea.widthAnchor, multiplier: 0.45),

            settingsView.topAnchor.constraint(equalTo: view.topAnchor),
            settingsBottom,
            settingsView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            settingsView.widthAnchor.constraint(equalTo: safeArea.widthAnchor, multiplier: 0.75),
        ])
    }

    /// テクニカル/設定タブを縦に並べて配置する
    private func setupTabs() {
        configureTabButton(technicalTabButton, title: "テクニカル", action: #selector(technicalTabTapped))
        configureTabButton(settingsTabButton, title: "設定", action: #selector(settingsTabTapped))

        tabStack.addArrangedSubview(technicalTabButton)
        tabStack.addArrangedSubview(settingsTabButton)
        tabStack.axis = .vertical
        tabStack.spacing = 4
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabStack)

        // タブの左端は、開いているパネルによって切り替える
        tabClosedConstraint = tabStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor)
        tabTechnicalOpenedConstraint = tabStack.leadingAnchor.constraint(equalTo: menuView.trailingAnchor)
        tabSettingsOpenedConstraint = tabStack.leadingAnchor.constraint(equalTo: settingsView.trailingAnchor)

        NSLayoutConstraint.activate([
            tabStack.topAnchor.constraint(equalTo: chartView.topAnchor),  // チャートの上端に揃える
            tabStack.widthAnchor.constraint(equalToConstant: tabWidth),
            technicalTabButton.heightAnchor.constraint(equalToConstant: 120),
            settingsTabButton.heightAnchor.constraint(equalToConstant: 72),
        ])
        tabClosedConstraint?.isActive = true
    }

    /// タブの見た目を設定する(縦書き・赤背景・右側の角だけ丸める)
    private func configureTabButton(_ button: UIButton, title: String, action: Selector) {
        // 1文字ずつ改行して縦書きにする
        button.setTitle(title.map(String.init).joined(separator: "\n"), for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        button.titleLabel?.textAlignment = .center
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.89, green: 0.05, blue: 0.27, alpha: 1)
        button.layer.cornerRadius = 6
        button.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    // MARK: - パネルの開閉

    /// isTechnicalMenuEnabled に合わせて、タブの表示とチャートの左端位置を切り替える
    private func updateMenuAvailability() {
        guard isViewLoaded else { return }  // viewDidLoad で改めて呼ばれる

        tabStack.isHidden = !isTechnicalMenuEnabled
        // タブがあるときはタブの右側から、ないときは左端からチャートを表示する
        applyChartInsets()
        if !isTechnicalMenuEnabled {
            // タブがないときは、開いているパネルを閉じる
            setOpenPanel(nil, animated: false)
        }
    }

    /// 「テクニカル」タブがタップされたら、指標の選択メニューを開閉する
    @objc private func technicalTabTapped() {
        togglePanel(.technical)
    }

    /// 「設定」タブがタップされたら、設定画面を開閉する
    @objc private func settingsTabTapped() {
        togglePanel(.settings)
    }

    /// 背景のグレーの部分がタップされたら、開いているパネルを閉じる
    @objc private func dimmingViewTapped() {
        closePanels()
    }

    /// 開いているパネル(テクニカル/設定)を閉じる。
    /// 設定画面で「決定」していない変更は捨てる
    @objc func closePanels() {
        setOpenPanel(nil, animated: true)
    }

    /// 指定したパネルが開いていれば閉じ、閉じていれば開く
    private func togglePanel(_ panel: Panel) {
        if openPanel == panel {
            setOpenPanel(nil, animated: true)
        } else {
            setOpenPanel(panel, animated: true)
        }
    }

    /// 指定したパネルを開く(もう一方は閉じる)。nil の場合は両方閉じる
    ///   1. 状態を変える(設定画面を開くときは、編集用のコピーを作り直す)
    ///   2. タブをパネルの右側(閉じたときは左端)に移す
    ///   3. 開くパネルと背景のグレーを、透明な状態で表示しておく
    ///   4. フェードで、開くパネルを不透明に・閉じるパネルを透明にする
    ///   5. 閉じたパネルを隠す(タッチを受けないように)
    private func setOpenPanel(_ panel: Panel?, animated: Bool) {
        // 設定画面を新しく開くときは、今のパラメータから編集用のコピーを作り直す
        if panel == .settings {
            if openPanel != .settings {
                beginSettingsEditing()
            }
        }

        // パネルを開く/閉じるが切り替わるときは、外の画面にも知らせる(背景をグレーにするため)
        let wasOpen = isPanelOpen
        openPanel = panel
        if wasOpen != isPanelOpen {
            onPanelVisibilityChange?(isPanelOpen)
        }

        updateTabPosition()
        showOpeningPanelTransparently()
        if animated {
            UIView.animate(withDuration: 0.25, animations: {
                self.applyPanelAlpha()
            }, completion: { _ in
                self.hideClosedPanels()
            })
        } else {
            applyPanelAlpha()
            hideClosedPanels()
        }
    }

    /// パネルの種類と、そのパネルの View の組
    private var panelViews: [(kind: Panel, view: UIView)] {
        return [(kind: .technical, view: menuView), (kind: .settings, view: settingsView)]
    }

    /// タブの位置を、開いているパネルに合わせる(先に全部無効にしてから、対応する制約だけを有効にする)
    private func updateTabPosition() {
        for constraint in [tabClosedConstraint, tabTechnicalOpenedConstraint, tabSettingsOpenedConstraint] {
            constraint?.isActive = false
        }
        switch openPanel {
        case .technical:
            tabTechnicalOpenedConstraint?.isActive = true
        case .settings:
            tabSettingsOpenedConstraint?.isActive = true
        case nil:
            tabClosedConstraint?.isActive = true
        }
    }

    /// 開くパネルと背景のグレーを、フェードインできるよう透明な状態で表示しておく
    private func showOpeningPanelTransparently() {
        if isPanelOpen {
            dimmingView.isHidden = false
        }
        for panel in panelViews {
            guard panel.kind == openPanel else { continue }  // 開くパネルだけが対象
            guard panel.view.isHidden else { continue }      // すでに表示中ならそのまま
            panel.view.isHidden = false
            panel.view.alpha = 0
        }
    }

    /// フェードの最後の状態にする: 開いているパネルは不透明・それ以外は透明。
    /// 背景のグレーは、どちらかのパネルを開いているときだけ表示する
    private func applyPanelAlpha() {
        for panel in panelViews {
            if panel.kind == openPanel {
                panel.view.alpha = 1
            } else {
                panel.view.alpha = 0
            }
        }
        if isPanelOpen {
            dimmingView.alpha = 1
        } else {
            dimmingView.alpha = 0
        }
        view.layoutIfNeeded()  // タブの移動もアニメーションさせる
    }

    /// 閉じ終わったパネル(と、パネルを閉じたときは背景のグレー)を隠して、タッチを受けないようにする
    private func hideClosedPanels() {
        for panel in panelViews where panel.kind != openPanel {
            panel.view.isHidden = true
        }
        if !isPanelOpen {
            dimmingView.isHidden = true
        }
    }

    // MARK: - 指数の種類

    /// 指数の種類に合わせて、選べる指標・チャートの種類・設定画面の項目を切り替え、描き直す
    /// - Parameter previousMarket: 変える前の指数の種類(設定画面で選んでいた項目を探すのに使う)
    private func applyMarket(previousMarket: IndexMarket) {
        // テクニカルのメニューに並べる指標(海外指数の折線チャートは指標を重ねられるので、「なし」だけにするかも変わる)
        menuView.allowsOnlyNone = !chartType.usesTechnicalIndicators(in: market)
        menuView.availableMainIndicators = MainChartIndicator.choices(for: market)
        menuView.availableSubIndicators = SubChartIndicator.choices(for: market)

        // 選べない指標・チャートの種類を選んでいた場合は、選べるものに切り替える
        // (それぞれの didSet でも描き直すが、最後にまとめて描き直す)
        if !MainChartIndicator.choices(for: market).contains(mainIndicator) {
            mainIndicator = .movingAverage
        }
        if !SubChartIndicator.choices(for: market).contains(subIndicator) {
            subIndicator = .hidden
        }
        if !ChartType.choices(for: market).contains(chartType) {
            chartType = .candlestick
        }

        applyDisplayOptionsToChart()
        reloadChart(keepsViewport: true)

        // 設定画面の左側リストを作り直す。編集中の内容(「決定」前の値)は残す。
        // 選んでいた項目が新しいリストにもあればその選択を残し、なければ先頭の「オプション」に戻す
        guard isViewLoaded else { return }  // viewDidLoad で作られる
        let previousItem = settingsItem(at: selectedSettingsIndexPath, in: previousMarket)
        selectedSettingsIndexPath = IndexPath(row: 0, section: 0)
        if let previousItem, let indexPath = indexPathInSettingsList(of: previousItem) {
            selectedSettingsIndexPath = indexPath
        }
        reloadSettingsList()
        reloadSettingsRows()
    }

    /// 指定した指数の種類のリストで、指定した位置にある項目(範囲外なら nil)
    private func settingsItem(at indexPath: IndexPath, in market: IndexMarket) -> ChartSettingsItem? {
        let sections = ChartSettingsCatalog.sections(for: market)
        guard sections.indices.contains(indexPath.section) else { return nil }
        let items = sections[indexPath.section].items
        guard items.indices.contains(indexPath.row) else { return nil }
        return items[indexPath.row]
    }

    /// 今の指数の種類のリストで、指定した項目がある位置(なければ nil)
    private func indexPathInSettingsList(of item: ChartSettingsItem) -> IndexPath? {
        for (sectionIndex, section) in settingsSections.enumerated() {
            if let row = section.items.firstIndex(of: item) {
                return IndexPath(row: row, section: sectionIndex)
            }
        }
        return nil
    }

    // MARK: - 設定画面(Model → 設定画面)

    /// 設定画面を用意する(左側リストを作り、編集を始める)
    private func configureSettingsView() {
        reloadSettingsList()
        beginSettingsEditing()
    }

    /// 設定画面の左側リストと足種のタブを、指数の種類に合わせて作る
    /// (海外指数は、左側リストの項目が少なく、足種のタブは 日足・週足・月足 だけ)
    private func reloadSettingsList() {
        // 足種のタブ: 指数の種類で使う足種だけを並べる(海外指数は 1分足・日中足のタブを出さない)
        settingsView.periods = market.periods

        // 見出しごとに、項目の名称(「移動平均線」など)を並べる
        var sections: [ChartSettingsView.Section] = []
        for section in settingsSections {
            let itemTitles = section.items.map { item in item.title }
            sections.append(ChartSettingsView.Section(title: section.title, items: itemTitles))
        }
        settingsView.sections = sections
        settingsView.selectedIndexPath = selectedSettingsIndexPath
    }

    /// 設定画面での編集を始める(今のパラメータから編集用のコピーを作り、タブは表示中の足種にする)
    private func beginSettingsEditing() {
        draftParametersByPeriod = parametersByPeriod
        settingsPeriod = period
        reloadSettingsRows()
    }

    /// 選択中の項目・足種に合わせて、設定画面の足種のタブと右側の行を作る
    private func reloadSettingsRows() {
        switch selectedSettingsItem {
        case .displayOptions:
            // 表示オプション: トグル(足種ごとではないので、タブと下のボタンは隠す)
            settingsView.showsPeriodControls = false
            // 並べるオプションは指数の種類で変わる(海外指数は Y軸(サブ)固定を除く)
            settingsView.rows = ChartDisplayOption.options(for: market).map { option in
                .toggle(title: option.title, isOn: displayOptions[keyPath: option.keyPath])
            }
        case let item:
            settingsView.showsPeriodControls = true

            // この項目を設定できない足種(移動平均線以外の1分足・日中足)はグレーにする。
            // 選択中の足種が設定できない足種なら、日足に切り替える
            let availablePeriods = settingsPeriods(for: item)
            if !availablePeriods.contains(settingsPeriod) {
                settingsPeriod = .daily
            }
            settingsView.disabledPeriods = Set(ChartPeriod.allCases.filter { period in
                !availablePeriods.contains(period)
            })
            settingsView.selectedPeriod = settingsPeriod

            // 指標: パラメータごとに 名称 + −/+ ボタン + スライダー(編集中の値を表示する)
            let draft = draftParameters(for: settingsPeriod)
            settingsView.rows = ChartSettingsCatalog.fields(for: item).map { field in
                .stepper(title: field.title, value: field.value(in: draft),
                         range: field.range, step: field.step, fractionDigits: field.fractionDigits)
            }
        }
    }

    /// 指定した項目を設定できる足種(項目ごとの足種のうち、この指数で使う足種だけ)。
    /// 海外指数では、どの項目も1分足・日中足は設定できない
    private func settingsPeriods(for item: ChartSettingsItem) -> [ChartPeriod] {
        return ChartSettingsCatalog.periods(for: item).filter { period in
            market.periods.contains(period)
        }
    }

    /// 編集中の、指定した足種のパラメータ
    private func draftParameters(for period: ChartPeriod) -> IndicatorParameters {
        if let parameters = draftParametersByPeriod[period] {
            return parameters
        }
        return parameters(for: period)
    }

    /// 選択中の項目のパラメータの値を、指定した値で上書きする(編集中のパラメータに対して)
    /// - Parameters:
    ///   - source: 値の取り出し元
    ///   - period: 上書きする足種
    private func copySelectedItemValues(from source: IndicatorParameters, to period: ChartPeriod) {
        var target = draftParameters(for: period)
        for field in ChartSettingsCatalog.fields(for: selectedSettingsItem) {
            field.setValue(field.value(in: source), in: &target)
        }
        draftParametersByPeriod[period] = target
    }
}

// MARK: - TechnicalMenuViewDelegate(指標の選択を状態に反映する)

extension StockChartViewController: TechnicalMenuViewDelegate {

    func technicalMenuView(_ menuView: TechnicalMenuView, didSelectMainIndicator indicator: MainChartIndicator) {
        mainIndicator = indicator
    }

    func technicalMenuView(_ menuView: TechnicalMenuView, didSelectSubIndicator indicator: SubChartIndicator) {
        subIndicator = indicator
    }
}

// MARK: - ChartSettingsViewDelegate(設定画面の操作を状態に反映する)

extension StockChartViewController: ChartSettingsViewDelegate {

    /// 左側リストの項目が選ばれたら、右側をその項目の設定に切り替える
    func settingsView(_ settingsView: ChartSettingsView, didSelectItemAt indexPath: IndexPath) {
        selectedSettingsIndexPath = indexPath
        settingsView.selectedIndexPath = indexPath
        reloadSettingsRows()
    }

    /// トグル(表示オプション)が切り替えられたら、対応するオプションを更新する
    func settingsView(_ settingsView: ChartSettingsView, didToggleRowAt index: Int, isOn: Bool) {
        // 行の並びは reloadSettingsRows の .displayOptions と同じ(指数の種類で使えるオプションの順)
        let options = ChartDisplayOption.options(for: market)
        guard options.indices.contains(index) else { return }
        displayOptions[keyPath: options[index].keyPath] = isOn
    }

    /// 足種のタブが選ばれたら、その足種の設定に切り替える
    func settingsView(_ settingsView: ChartSettingsView, didSelectPeriod period: ChartPeriod) {
        settingsPeriod = period
        reloadSettingsRows()
    }

    /// 数値(指標パラメータ)が変更されたら、編集中のパラメータを更新する(チャートへの反映は「決定」のとき)
    func settingsView(_ settingsView: ChartSettingsView, didChangeValueAt index: Int, value: Double) {
        let fields = ChartSettingsCatalog.fields(for: selectedSettingsItem)
        guard fields.indices.contains(index) else { return }
        var draft = draftParameters(for: settingsPeriod)
        fields[index].setValue(value, in: &draft)
        draftParametersByPeriod[settingsPeriod] = draft
    }

    /// 「すべての足に反映」: 表示中の値を、この項目を設定できるすべての足種にコピーする(編集中のパラメータに対して)
    func settingsViewDidTapApplyToAllPeriods(_ settingsView: ChartSettingsView) {
        let source = draftParameters(for: settingsPeriod)
        for period in settingsPeriods(for: selectedSettingsItem) {
            copySelectedItemValues(from: source, to: period)
        }
    }

    /// 「初期値に戻す」: 表示中の足種の、この項目の値を初期値に戻す(編集中のパラメータに対して)
    func settingsViewDidTapReset(_ settingsView: ChartSettingsView) {
        copySelectedItemValues(from: settingsPeriod.indicatorParameters, to: settingsPeriod)
        reloadSettingsRows()
    }

    /// 「決定」: 編集中のパラメータをチャートに反映し、設定画面を閉じる
    func settingsViewDidTapConfirm(_ settingsView: ChartSettingsView) {
        parametersByPeriod = draftParametersByPeriod
        reloadChart(keepsViewport: true)
        setOpenPanel(nil, animated: true)
    }
}

// MARK: - Objective-C 向けのパラメータ・オプション設定

/// IndicatorParameters / ChartDisplayOptions は struct のため Objective-C から直接扱えない。
/// よく変更するものだけを @objc プロパティとして公開する。
/// ・指標の期間: 読み出しは表示中の足種の値、設定は**すべての足種**に反映する(設定画面の「すべての足に反映」と同じ)
/// ・表示オプション: displayOptions を読み書きしているだけ
extension StockChartViewController {

    /// 短期移動平均の期間(本数)。設定するとすべての足種に反映する
    @objc var shortMAPeriod: Int {
        get { parameters.shortMAPeriod }
        set { updateParametersForAllPeriods { parameters in parameters.shortMAPeriod = newValue } }
    }

    /// 長期移動平均の期間(本数)。設定するとすべての足種に反映する
    @objc var longMAPeriod: Int {
        get { parameters.longMAPeriod }
        set { updateParametersForAllPeriods { parameters in parameters.longMAPeriod = newValue } }
    }

    /// 出来高移動平均の期間(本数)。設定するとすべての足種に反映する
    @objc var volumeMAPeriod: Int {
        get { parameters.volumeMAPeriod }
        set { updateParametersForAllPeriods { parameters in parameters.volumeMAPeriod = newValue } }
    }

    /// Y軸(メイン)固定
    @objc var isMainYAxisFixed: Bool {
        get { displayOptions.isMainYAxisFixed }
        set { displayOptions.isMainYAxisFixed = newValue }
    }

    /// Y軸(サブ)固定
    @objc var isSubYAxisFixed: Bool {
        get { displayOptions.isSubYAxisFixed }
        set { displayOptions.isSubYAxisFixed = newValue }
    }

    /// 4本値(十字線と、その足の日付・始値・高値・安値・終値を表示する)
    @objc var showsOHLC: Bool {
        get { displayOptions.showsOHLC }
        set { displayOptions.showsOHLC = newValue }
    }
}

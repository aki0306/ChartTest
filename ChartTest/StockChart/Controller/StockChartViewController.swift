//
//  StockChartViewController.swift
//  ChartTest
//
//  【Controller】株価チャート部品の制御を担当する ViewController。
//
//  【責務】
//  ・状態の保持: ローソク足データ・選択中の指標・指標パラメータ・表示オプション
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

    // MARK: - State(Model の状態)

    /// 表示中のローソク足データ(古い順)
    private var candles: [StockCandle] = []

    /// 指標の計算パラメータ。変更すると再描画する
    var parameters = IndicatorParameters() {
        didSet { reloadChart(keepsViewport: true) }
    }

    /// 表示オプション(Y軸固定・4本値)。変更すると即座にチャートへ反映する
    var displayOptions = ChartDisplayOptions() {
        didSet {
            chartView.displayOptions = displayOptions
            // 設定画面でオプションを表示中なら、トグルの状態を合わせる
            if selectedSettingsItem == .displayOptions {
                reloadSettingsRows()
            }
        }
    }

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

    /// テクニカル/設定タブを使えるようにするか。
    /// false にするとタブとパネルを隠し、チャートを全幅で表示する(例: 横画面のときだけ true)
    @objc var isTechnicalMenuEnabled = false {
        didSet {
            guard isTechnicalMenuEnabled != oldValue else { return }
            updateMenuAvailability()
        }
    }

    // MARK: - Views

    /// チャート本体。見た目は chartView.style で変更できる
    @objc let chartView = StockChartView()
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

    // MARK: - Panels

    /// 開閉できるパネルの種類
    private enum Panel {
        /// 指標の選択メニュー
        case technical
        /// 設定画面
        case settings
    }

    /// 開いているパネル(nil = どちらも閉じている)
    private var openPanel: Panel?

    /// 設定画面の左側リストで選択中の位置
    private var selectedSettingsIndexPath = IndexPath(row: 0, section: 0)

    /// 設定画面で選択中の項目
    private var selectedSettingsItem: ChartSettingsItem {
        ChartSettingsCatalog.sections[selectedSettingsIndexPath.section].items[selectedSettingsIndexPath.row]
    }

    // MARK: - Layout

    /// タブの幅
    private let tabWidth: CGFloat = 30
    /// タブとチャートの間隔
    private let tabSpacing: CGFloat = 8

    /// チャートの左端(タブの有無で位置が変わる)
    private var chartLeadingConstraint: NSLayoutConstraint?
    /// タブの左端: パネルを閉じているとき(このViewの左端に付ける)
    private var tabClosedConstraint: NSLayoutConstraint?
    /// タブの左端: 指標の選択メニューを開いているとき(メニューの右端に付ける)
    private var tabTechnicalOpenedConstraint: NSLayoutConstraint?
    /// タブの左端: 設定画面を開いているとき(設定画面の右端に付ける)
    private var tabSettingsOpenedConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        setupChartView()
        setupPanels()
        setupTabs()
        configureSettingsView()
        updateMenuAvailability()
    }

    // MARK: - Public

    /// ローソク足データを設定して描画する。
    /// Objective-C からは `[chartViewController setCandles:candles]` で呼び出せる。
    /// - Parameter candles: 日付の古い順に並んだローソク足データ
    @objc func setCandles(_ candles: [StockCandle]) {
        self.candles = candles
        reloadChart(keepsViewport: false)
    }

    // MARK: - Model → View

    /// 現在の状態から Model で描画内容を組み立て、View に表示させる
    /// - Parameter keepsViewport: true の場合、可能であれば現在の表示位置・拡大率を維持する
    private func reloadChart(keepsViewport: Bool) {
        guard !candles.isEmpty else {
            chartView.clear()
            return
        }
        let builder = ChartContentBuilder(candles: candles, parameters: parameters)
        chartView.display(candles: candles,
                          main: builder.mainContent(for: mainIndicator),
                          sub: builder.subContent(for: subIndicator),
                          keepsViewport: keepsViewport)
    }

    // MARK: - Setup

    /// チャートを配置する(上下右はこのViewいっぱい、左端はタブの有無で変わる)
    private func setupChartView() {
        chartView.translatesAutoresizingMaskIntoConstraints = false
        chartView.displayOptions = displayOptions
        view.addSubview(chartView)

        chartLeadingConstraint = chartView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        NSLayoutConstraint.activate([
            chartView.topAnchor.constraint(equalTo: view.topAnchor),
            chartView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            chartView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chartLeadingConstraint!,
        ])
    }

    /// 指標の選択メニューと設定画面を配置する(どちらも初期状態は閉じている)
    private func setupPanels() {
        // 指標の選択メニュー: このViewの左側に幅 45% で表示
        menuView.translatesAutoresizingMaskIntoConstraints = false
        menuView.isHidden = true
        menuView.delegate = self
        menuView.selectedMainIndicator = mainIndicator
        menuView.selectedSubIndicator = subIndicator
        view.addSubview(menuView)

        // 設定画面: このViewの左側に幅 75% で表示(左側リスト + 右側パネル)
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        settingsView.isHidden = true
        settingsView.delegate = self
        view.addSubview(settingsView)

        NSLayoutConstraint.activate([
            menuView.topAnchor.constraint(equalTo: view.topAnchor),
            menuView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            menuView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            menuView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.45),

            settingsView.topAnchor.constraint(equalTo: view.topAnchor),
            settingsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            settingsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.75),
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
        tabClosedConstraint = tabStack.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        tabTechnicalOpenedConstraint = tabStack.leadingAnchor.constraint(equalTo: menuView.trailingAnchor)
        tabSettingsOpenedConstraint = tabStack.leadingAnchor.constraint(equalTo: settingsView.trailingAnchor)

        NSLayoutConstraint.activate([
            tabStack.topAnchor.constraint(equalTo: view.topAnchor),
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

    // MARK: - Panels(開閉)

    /// isTechnicalMenuEnabled に合わせて、タブの表示とチャートの左端位置を切り替える
    private func updateMenuAvailability() {
        guard isViewLoaded else { return }  // viewDidLoad で改めて呼ばれる

        tabStack.isHidden = !isTechnicalMenuEnabled
        // タブがあるときはタブの右側からチャートを表示する
        chartLeadingConstraint?.constant = isTechnicalMenuEnabled ? tabWidth + tabSpacing : 0
        // タブが使えなくなったらパネルを閉じる
        if !isTechnicalMenuEnabled {
            setOpenPanel(nil, animated: false)
        }
    }

    /// 「テクニカル」タブがタップされたら、指標の選択メニューを開閉する
    @objc private func technicalTabTapped() {
        setOpenPanel(openPanel == .technical ? nil : .technical, animated: true)
    }

    /// 「設定」タブがタップされたら、設定画面を開閉する
    @objc private func settingsTabTapped() {
        setOpenPanel(openPanel == .settings ? nil : .settings, animated: true)
    }

    /// 指定したパネルを開く(もう一方は閉じる)。nil の場合は両方閉じる
    private func setOpenPanel(_ panel: Panel?, animated: Bool) {
        openPanel = panel

        // タブの位置: 先に全部無効化してから、開いているパネルに対応する制約を有効化する
        [tabClosedConstraint, tabTechnicalOpenedConstraint, tabSettingsOpenedConstraint].forEach { $0?.isActive = false }
        switch panel {
        case .technical: tabTechnicalOpenedConstraint?.isActive = true
        case .settings: tabSettingsOpenedConstraint?.isActive = true
        case nil: tabClosedConstraint?.isActive = true
        }

        // 開くパネルはフェードインのために一旦透明で表示する
        let panels: [(Panel, UIView)] = [(.technical, menuView), (.settings, settingsView)]
        for (kind, view) in panels where kind == panel && view.isHidden {
            view.isHidden = false
            view.alpha = 0
        }

        let changes = {
            for (kind, view) in panels {
                view.alpha = (kind == panel) ? 1 : 0
            }
            self.view.layoutIfNeeded()
        }
        let completion: (Bool) -> Void = { _ in
            // 閉じ終わったパネルは非表示にしてタッチを受けないようにする
            for (kind, view) in panels where kind != self.openPanel {
                view.isHidden = true
            }
        }
        if animated {
            UIView.animate(withDuration: 0.25, animations: changes, completion: completion)
        } else {
            changes()
            completion(true)
        }
    }

    // MARK: - Settings(Model → 設定画面)

    /// 設定画面の左側リストを Model(ChartSettingsCatalog)から作る
    private func configureSettingsView() {
        settingsView.sections = ChartSettingsCatalog.sections.map { section in
            ChartSettingsView.Section(title: section.title, items: section.items.map(\.title))
        }
        settingsView.selectedIndexPath = selectedSettingsIndexPath
        reloadSettingsRows()
    }

    /// 選択中の項目に合わせて、設定画面の右側の行を作る
    private func reloadSettingsRows() {
        switch selectedSettingsItem {
        case .displayOptions:
            // 表示オプション: トグル3つ
            settingsView.rows = [
                .toggle(title: "Y軸(メイン)固定", isOn: displayOptions.isMainYAxisFixed),
                .toggle(title: "Y軸(サブ)固定", isOn: displayOptions.isSubYAxisFixed),
                .toggle(title: "4本値", isOn: displayOptions.showsOHLC),
            ]
        case let item:
            // 指標: パラメータごとに 数値 + −/+ ボタン
            settingsView.rows = ChartSettingsCatalog.fields(for: item, parameters: parameters).map { field in
                .stepper(title: field.title, value: field.value(in: parameters),
                         range: field.range, step: field.step, fractionDigits: field.fractionDigits)
            }
        }
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
        // 行の並びは reloadSettingsRows の .displayOptions と同じ
        switch index {
        case 0: displayOptions.isMainYAxisFixed = isOn
        case 1: displayOptions.isSubYAxisFixed = isOn
        case 2: displayOptions.showsOHLC = isOn
        default: break
        }
    }

    /// 数値(指標パラメータ)が変更されたら、対応するパラメータを更新する(parameters の didSet で再描画される)
    func settingsView(_ settingsView: ChartSettingsView, didChangeValueAt index: Int, value: Double) {
        let fields = ChartSettingsCatalog.fields(for: selectedSettingsItem, parameters: parameters)
        guard fields.indices.contains(index) else { return }
        fields[index].setValue(value, in: &parameters)
    }
}

// MARK: - Objective-C 向けのパラメータ・オプション設定

/// IndicatorParameters / ChartDisplayOptions は struct のため Objective-C から直接扱えない。
/// よく変更するものだけを @objc プロパティとして公開する(中身は parameters / displayOptions を読み書きしているだけ)。
extension StockChartViewController {

    /// 短期移動平均の期間(本数)
    @objc var shortMAPeriod: Int {
        get { parameters.shortMAPeriod }
        set { parameters.shortMAPeriod = newValue }
    }

    /// 長期移動平均の期間(本数)
    @objc var longMAPeriod: Int {
        get { parameters.longMAPeriod }
        set { parameters.longMAPeriod = newValue }
    }

    /// 出来高移動平均の期間(本数)
    @objc var volumeMAPeriod: Int {
        get { parameters.volumeMAPeriod }
        set { parameters.volumeMAPeriod = newValue }
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

    /// 4本値(タップで十字線と4本値を表示)
    @objc var showsOHLC: Bool {
        get { displayOptions.showsOHLC }
        set { displayOptions.showsOHLC = newValue }
    }
}

//
//  StockChartViewController.swift
//  ChartTest
//
//  【Controller】株価チャート部品の制御を担当する ViewController。
//
//  【責務】
//  ・状態の保持: ローソク足データ・選択中の指標・指標パラメータ
//  ・Model(ChartContentBuilder)で描画内容を組み立て、View(StockChartView)に渡す
//  ・View(TechnicalMenuView)からの指標選択を受け取り、状態を更新して再描画する
//  ・指標メニュー(テクニカルタブ)の表示/非表示・開閉
//
//  ┌──┬─────────────────────┐
//  │テ│                     │
//  │ク│   StockChartView    │  ← isTechnicalMenuEnabled = true のとき左端にタブを表示し、
//  │ニ│                     │     タップで TechnicalMenuView を開閉する
//  │カ│                     │
//  │ル│                     │
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

    /// 指標メニュー(テクニカルタブ)を使えるようにするか。
    /// false にするとタブとメニューを隠し、チャートを全幅で表示する(例: 横画面のときだけ true)
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
    /// メニューを開閉するタブ
    private let technicalTabButton = UIButton(type: .custom)

    // MARK: - Layout

    /// タブの幅
    private let tabWidth: CGFloat = 30
    /// タブとチャートの間隔
    private let tabSpacing: CGFloat = 8

    /// チャートの左端(タブの有無で位置が変わる)
    private var chartLeadingConstraint: NSLayoutConstraint?
    /// タブの左端: メニューを閉じているとき(このViewの左端に付ける)
    private var tabClosedConstraint: NSLayoutConstraint?
    /// タブの左端: メニューを開いているとき(メニューの右端に付ける)
    private var tabOpenedConstraint: NSLayoutConstraint?

    /// メニューを開いているか
    private var isMenuOpen = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        setupChartView()
        setupMenu()
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
        view.addSubview(chartView)

        chartLeadingConstraint = chartView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        NSLayoutConstraint.activate([
            chartView.topAnchor.constraint(equalTo: view.topAnchor),
            chartView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            chartView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chartLeadingConstraint!,
        ])
    }

    /// 指標メニューと開閉タブを配置する
    private func setupMenu() {
        // メニュー: このViewの左側に幅 45% で表示。初期状態は閉じている
        menuView.translatesAutoresizingMaskIntoConstraints = false
        menuView.isHidden = true
        menuView.delegate = self
        menuView.selectedMainIndicator = mainIndicator
        menuView.selectedSubIndicator = subIndicator
        view.addSubview(menuView)

        // タブ: 縦書きの「テクニカル」。右側の角だけ丸める
        technicalTabButton.translatesAutoresizingMaskIntoConstraints = false
        technicalTabButton.setTitle("テ\nク\nニ\nカ\nル", for: .normal)
        technicalTabButton.titleLabel?.numberOfLines = 0
        technicalTabButton.titleLabel?.font = .boldSystemFont(ofSize: 14)
        technicalTabButton.titleLabel?.textAlignment = .center
        technicalTabButton.setTitleColor(.white, for: .normal)
        technicalTabButton.backgroundColor = UIColor(red: 0.89, green: 0.05, blue: 0.27, alpha: 1)
        technicalTabButton.layer.cornerRadius = 6
        technicalTabButton.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        technicalTabButton.addTarget(self, action: #selector(technicalTabTapped), for: .touchUpInside)
        view.addSubview(technicalTabButton)

        // タブの左端はメニューの開閉状態で切り替える
        tabClosedConstraint = technicalTabButton.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        tabOpenedConstraint = technicalTabButton.leadingAnchor.constraint(equalTo: menuView.trailingAnchor)

        NSLayoutConstraint.activate([
            menuView.topAnchor.constraint(equalTo: view.topAnchor),
            menuView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            menuView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            menuView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.45),

            technicalTabButton.topAnchor.constraint(equalTo: view.topAnchor),
            technicalTabButton.widthAnchor.constraint(equalToConstant: tabWidth),
            technicalTabButton.heightAnchor.constraint(equalToConstant: 120),
        ])
        tabClosedConstraint?.isActive = true
    }

    // MARK: - Menu

    /// isTechnicalMenuEnabled に合わせて、タブの表示とチャートの左端位置を切り替える
    private func updateMenuAvailability() {
        guard isViewLoaded else { return }  // viewDidLoad で改めて呼ばれる

        technicalTabButton.isHidden = !isTechnicalMenuEnabled
        // タブがあるときはタブの右側からチャートを表示する
        chartLeadingConstraint?.constant = isTechnicalMenuEnabled ? tabWidth + tabSpacing : 0
        // メニューが使えなくなったら閉じる
        if !isTechnicalMenuEnabled {
            setMenuOpen(false, animated: false)
        }
    }

    /// 「テクニカル」タブがタップされたら、メニューを開閉する
    @objc private func technicalTabTapped() {
        setMenuOpen(!isMenuOpen, animated: true)
    }

    /// メニューを開く/閉じる
    private func setMenuOpen(_ open: Bool, animated: Bool) {
        isMenuOpen = open

        // 先に無効化してから有効化する(同時に有効になると制約が衝突するため)
        (open ? tabClosedConstraint : tabOpenedConstraint)?.isActive = false
        (open ? tabOpenedConstraint : tabClosedConstraint)?.isActive = true
        if open {
            menuView.isHidden = false
            menuView.alpha = 0
        }

        let changes = {
            self.menuView.alpha = open ? 1 : 0
            self.view.layoutIfNeeded()
        }
        let completion: (Bool) -> Void = { _ in
            // 閉じ終わったら非表示にしてタッチを受けないようにする
            if !self.isMenuOpen { self.menuView.isHidden = true }
        }
        if animated {
            UIView.animate(withDuration: 0.25, animations: changes, completion: completion)
        } else {
            changes()
            completion(true)
        }
    }
}

// MARK: - TechnicalMenuViewDelegate(View からの指標選択を状態に反映する)

extension StockChartViewController: TechnicalMenuViewDelegate {

    func technicalMenuView(_ menuView: TechnicalMenuView, didSelectMainIndicator indicator: MainChartIndicator) {
        mainIndicator = indicator
    }

    func technicalMenuView(_ menuView: TechnicalMenuView, didSelectSubIndicator indicator: SubChartIndicator) {
        subIndicator = indicator
    }
}

// MARK: - Objective-C 向けのパラメータ設定

/// IndicatorParameters は struct のため Objective-C から直接扱えない。
/// よく変更するパラメータだけを @objc プロパティとして公開する(中身は parameters を読み書きしているだけ)。
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
}

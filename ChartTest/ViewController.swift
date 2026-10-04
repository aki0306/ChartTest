//
//  ViewController.swift
//  ChartTest
//
//  Created by アキ on 2026/09/27.
//
//  【Controller】アプリ画面のサンプル。縦画面用・横画面用のチャート画面を子として埋め込み、
//  画面の向きに合わせて表示を切り替える。
//
//  ・縦画面: PortraitChartViewController(Portrait.storyboard。足種のタブ + StockChartView)
//  ・横画面: LandscapeChartViewController(Landscape.storyboard。StockChartViewController で指標メニュー付き表示)
//  この画面は「どちらを表示するか」と「データを渡す」ことだけを担当する。
//  縦画面の左下の切り替えボタン(marketControl)で、国内指数/海外指数を切り替えて表示を確かめられる
//  (横画面では下の帯と重なるので隠す。縦画面で切り替えてから横にする)。
//  横画面の下の帯(足種・更新・縦画面に戻す)が押されたときの処理も、ここで設定している(setupLandscapeFooter)。
//

import UIKit

class ViewController: UIViewController {

    // MARK: - Children

    /// 縦画面のチャート(Portrait.storyboard)
    private let portraitViewController = PortraitChartViewController.instantiate()
    /// 横画面のチャート(Landscape.storyboard)
    private let landscapeViewController = LandscapeChartViewController.instantiate()

    /// 現在の表示が横画面用か(nil = 未適用)
    private var isLandscapeLayout: Bool?

    // MARK: - 国内指数/海外指数の切り替え

    /// 国内指数/海外指数を切り替えるボタン(左下。縦画面だけに表示する)
    private let marketControl = UISegmentedControl(items: ["国内指数", "海外指数"])

    /// 切り替えボタンの並び順と同じ、指数の種類
    private let marketChoices: [IndexMarket] = [.domestic, .overseas]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        // データを渡す前に埋め込んでおく(チャートが正しいサイズで初期表示位置を計算できるように)
        embed(portraitViewController)
        embed(landscapeViewController)
        applyLayout(isLandscape: view.bounds.width > view.bounds.height)

        // 縦画面: 足種のタブで切り替えるたびに、その足種のデータを読み込む
        portraitViewController.candleLoader = { period in
            return SampleData.candles(for: period)
        }

        // 横画面: 下の帯のボタンが押されたときの処理
        setupLandscapeFooter()

        // 国内指数/海外指数の切り替えボタン(最初は国内指数)
        setupMarketControl()
        showCharts(for: .domestic)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 画面の縦横が変わったら表示を切り替える
        let isLandscape = view.bounds.width > view.bounds.height
        if isLandscape != isLandscapeLayout {
            applyLayout(isLandscape: isLandscape)
        }
    }

    // MARK: - Setup

    /// 子 ViewController を画面いっぱいに埋め込む
    private func embed(_ child: UIViewController) {
        addChild(child)
        let childView = child.view!
        childView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(childView)
        NSLayoutConstraint.activate([
            childView.topAnchor.constraint(equalTo: view.topAnchor),
            childView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            childView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        child.didMove(toParent: self)
    }

    // MARK: - 国内指数/海外指数

    /// 切り替えボタンを左下に置く(チャート画面より手前)
    private func setupMarketControl() {
        marketControl.selectedSegmentIndex = 0
        marketControl.addTarget(self, action: #selector(marketControlChanged), for: .valueChanged)
        marketControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(marketControl)
        NSLayoutConstraint.activate([
            marketControl.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            marketControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            marketControl.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    /// 切り替えボタンが押されたら、選ばれた指数の種類で表示し直す
    @objc private func marketControlChanged() {
        let index = marketControl.selectedSegmentIndex
        guard marketChoices.indices.contains(index) else { return }
        showCharts(for: marketChoices[index])
    }

    /// 縦画面・横画面のチャートを、指定した指数の種類で表示し直す。
    /// 指数の種類は、データを渡す前に設定する(描き方・選べる足種や指標が変わるため)
    ///   ・国内指数: 縦画面は 1分足〜月足のタブ、ローソク足 + 移動平均線 + 出来高
    ///   ・海外指数: 縦画面は 日足・週足・月足のタブ、ローソク足 + 移動平均線(サブチャートなし)。
    ///              横画面は テクニカルが 移動平均線・なし、チャートの種類が ローソク足・折線チャート だけ
    /// (サンプルなので、海外指数でも同じダミーデータを使う)
    private func showCharts(for market: IndexMarket) {
        // 縦画面: タブに並ぶ足種が変わり、選択中の足種で描き直す
        portraitViewController.market = market
        portraitViewController.reloadChart()

        // 横画面: 日足のデータを渡すと描画される。下の帯の指数名・現在値も変える
        landscapeViewController.chartViewController.market = market
        landscapeViewController.setCandles(SampleData.candles(for: .daily), period: .daily)
        updateLandscapePriceInfo()
    }

    // MARK: - 横画面の下の帯

    /// 横画面の下の帯のボタンが押されたときの処理を設定する
    /// (サンプルなので SampleData から読み込む。実際のアプリでは API から取得して setCandles(_:period:) で渡す)
    private func setupLandscapeFooter() {
        // 足種が選ばれたら、その足種のデータを渡す(足種のボタンの表示も切り替わる)
        landscapeViewController.onPeriodSelect = { [weak self] period in
            self?.landscapeViewController.setCandles(SampleData.candles(for: period), period: period)
        }
        // 更新: 表示中の足種のデータを読み込み直し、現在値も更新する
        landscapeViewController.onReload = { [weak self] in
            guard let self else { return }
            let period = self.landscapeViewController.chartViewController.period
            self.landscapeViewController.setCandles(SampleData.candles(for: period), period: period)
            self.updateLandscapePriceInfo()
        }
        // 縦画面に戻す
        landscapeViewController.onRotate = { [weak self] in
            self?.view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }

    /// 横画面の下の帯に、指数名・現在値・日時を表示する
    /// (サンプルなので、当日の分足の最後の足の終値・時刻を現在値として使う)
    private func updateLandscapePriceInfo() {
        guard let latest = SampleData.candles(for: .oneMinute).last else { return }
        var name = "日経平均"
        if landscapeViewController.chartViewController.market == .overseas {
            name = "NYダウ"
        }
        landscapeViewController.updatePriceInfo(name: name, price: latest.close, date: latest.date)
    }

    // MARK: - Layout switching

    /// 縦画面/横画面のチャートを切り替える
    private func applyLayout(isLandscape: Bool) {
        isLandscapeLayout = isLandscape
        portraitViewController.view.isHidden = isLandscape
        landscapeViewController.view.isHidden = !isLandscape
        // 切り替えボタンは縦画面だけ(横画面では下の帯の文字と重なるため)
        marketControl.isHidden = isLandscape
    }
}

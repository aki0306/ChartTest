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
//  左下の切り替えボタン(marketControl)で、国内指数/海外指数を切り替えて表示を確かめられる。
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

    /// 国内指数/海外指数を切り替えるボタン(左下。縦画面・横画面のどちらでも表示する)
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

    /// 切り替えボタンを左下に置く(チャート画面より手前。横画面では右下に「チャートの種類」ボタンがあるので左に置く)
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

        // 横画面: 日足のデータを渡すと描画される
        landscapeViewController.chartViewController.market = market
        landscapeViewController.setCandles(SampleData.candles(for: .daily), period: .daily)
    }

    // MARK: - Layout switching

    /// 縦画面/横画面のチャートを切り替える
    private func applyLayout(isLandscape: Bool) {
        isLandscapeLayout = isLandscape
        portraitViewController.view.isHidden = isLandscape
        landscapeViewController.view.isHidden = !isLandscape
    }
}

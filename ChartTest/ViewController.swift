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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        // データを渡す前に埋め込んでおく(チャートが正しいサイズで初期表示位置を計算できるように)
        embed(portraitViewController)
        embed(landscapeViewController)
        applyLayout(isLandscape: view.bounds.width > view.bounds.height)

        // 縦画面: 国内指数として、足種(1分足〜月足)のタブで切り替えられるようにする。
        // 海外指数の場合は market = .overseas にする(タブは日足・週足・月足になる)
        portraitViewController.market = .domestic
        portraitViewController.candleLoader = { period in
            return SampleData.candles(for: period)
        }
        portraitViewController.reloadChart()

        // 横画面: 日足のデータを渡すと描画される
        landscapeViewController.setCandles(SampleData.candles(for: .daily))
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

    // MARK: - Layout switching

    /// 縦画面/横画面のチャートを切り替える
    private func applyLayout(isLandscape: Bool) {
        isLandscapeLayout = isLandscape
        portraitViewController.view.isHidden = isLandscape
        landscapeViewController.view.isHidden = !isLandscape
    }
}

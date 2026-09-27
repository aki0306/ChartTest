//
//  ViewController.swift
//  ChartTest
//
//  Created by アキ on 2026/09/27.
//
//  【Controller】アプリ画面のサンプル。共通チャート部品(StockChartViewController)を子として埋め込む。
//
//  ・縦画面: チャートを画面上部に固定の高さで表示する
//  ・横画面: チャートを画面いっぱいに表示し、指標メニュー(テクニカルタブ)を有効にする
//  チャート自体の制御(指標の切り替え・メニューの開閉など)は StockChartViewController に任せ、
//  この画面は「どこに・どの大きさで置くか」と「データを渡す」ことだけを担当する。
//

import UIKit

class ViewController: UIViewController {

    // MARK: - Child

    /// 共通チャート部品
    private let chartViewController = StockChartViewController()

    // MARK: - Layout

    /// 縦画面用の制約
    private var portraitConstraints: [NSLayoutConstraint] = []
    /// 横画面用の制約
    private var landscapeConstraints: [NSLayoutConstraint] = []
    /// 現在のレイアウトが横画面用か(nil = 未適用)
    private var isLandscapeLayout: Bool?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        embedChart()
        // データを渡す前に制約を有効にしておく(チャートが正しいサイズで初期表示位置を計算できるように)
        applyLayout(isLandscape: view.bounds.width > view.bounds.height)

        // 必要に応じて設定を変更できる(例)
        // chartViewController.mainIndicator = .bollingerBands     // メインチャートの指標
        // chartViewController.subIndicator = .macd                // サブチャートの指標
        // chartViewController.parameters.rsiPeriod = 9            // 指標のパラメータ(Model)
        // chartViewController.chartView.style.visibleCount = 40   // 見た目(View)

        // データを渡すと描画される
        chartViewController.setCandles(SampleData.nikkeiLike())
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 画面の縦横が変わったらレイアウトを切り替える
        let isLandscape = view.bounds.width > view.bounds.height
        if isLandscape != isLandscapeLayout {
            applyLayout(isLandscape: isLandscape)
        }
    }

    // MARK: - Setup

    /// チャート部品を子 ViewController として埋め込み、縦/横それぞれの制約を用意する
    private func embedChart() {
        addChild(chartViewController)
        let chart = chartViewController.view!
        chart.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chart)
        chartViewController.didMove(toParent: self)

        let safe = view.safeAreaLayoutGuide

        // 縦画面: 画面上部に高さ 360 で表示
        portraitConstraints = [
            chart.topAnchor.constraint(equalTo: safe.topAnchor, constant: 16),
            chart.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 8),
            chart.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -8),
            chart.heightAnchor.constraint(equalToConstant: 360),
        ]

        // 横画面: 画面いっぱいに表示(左端のタブは chartViewController 内に表示される)
        landscapeConstraints = [
            chart.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            chart.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8),
            chart.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            chart.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -8),
        ]
    }

    // MARK: - Layout switching

    /// 縦画面/横画面のレイアウトを適用する
    private func applyLayout(isLandscape: Bool) {
        isLandscapeLayout = isLandscape

        NSLayoutConstraint.deactivate(isLandscape ? portraitConstraints : landscapeConstraints)
        NSLayoutConstraint.activate(isLandscape ? landscapeConstraints : portraitConstraints)

        // 指標メニューは横画面のときだけ使えるようにする
        chartViewController.isTechnicalMenuEnabled = isLandscape
    }
}

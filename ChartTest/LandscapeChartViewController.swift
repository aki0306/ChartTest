//
//  LandscapeChartViewController.swift
//  ChartTest
//
//  【Controller】横画面のチャート画面(Landscape.storyboard)。
//
//  共通チャート部品(StockChartViewController)は storyboard のコンテナビューに埋め込んであり、
//  左端のテクニカル/設定タブで指標の切り替え・設定変更ができるようにする。
//  右下のボタン(chartTypeButton)で、チャートの種類(ローソク足・VWAP：線・VWAP：点・新値足・折線チャート)を切り替える。
//  ローソク足以外では、テクニカルのメニューは「なし」だけになり、4本値は表示しない(StockChartViewController.chartType)。
//  チャート部品は画面いっぱいに置き、チャート本体だけを chartInsets で内側に置く。
//  テクニカル/設定を開いている間は、パネルが画面の上端〜セーフエリアの下端まで、背景のグレーが画面全体に広がる(configurePanelLayering)。
//
//  使い方(Swift):
//      let viewController = LandscapeChartViewController.instantiate()
//      viewController.chartViewController.mainIndicator = .bollingerBands   // 必要なら指標を変える
//      viewController.chartViewController.chartType = .newPrice             // 必要ならチャートの種類を変える
//      viewController.chartViewController.market = .overseas               // 海外指数(移動平均線・ローソク足/折線チャートだけ)
//      viewController.setCandles(candles)
//
//  使い方(Objective-C):
//      LandscapeChartViewController *viewController = [LandscapeChartViewController instantiate];
//      viewController.chartViewController.mainIndicator = MainChartIndicatorBollingerBands;
//      viewController.chartViewController.chartType = ChartTypeNewPrice;
//      [viewController setCandles:candles];
//

import UIKit

final class LandscapeChartViewController: UIViewController {

    /// Landscape.storyboard から生成する
    @objc static func instantiate() -> LandscapeChartViewController {
        UIStoryboard(name: "Landscape", bundle: nil).instantiateInitialViewController() as! LandscapeChartViewController
    }

    /// チャートの種類を切り替えるボタン(タップで種類のメニューを表示する)
    @IBOutlet private weak var chartTypeButton: UIButton!

    /// コンテナビューの embed で受け取った共通チャート部品(画面の読み込み時に設定される)
    private var embeddedChartViewController: StockChartViewController?

    /// 共通チャート部品(指標メニュー・設定画面付き)。
    /// 画面を読み込むまでは存在しないので、まだなら読み込んでから返す
    @objc var chartViewController: StockChartViewController {
        loadViewIfNeeded()
        return embeddedChartViewController!
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        chartViewController.isTechnicalMenuEnabled = true
        configureChartTypeButton()
        configurePanelLayering()

        // チャート部品は画面いっぱいに置き(パネルを画面の上端〜下端まで広げるため)、チャート本体だけを内側に置く。
        // 下は「チャートの種類」ボタン(高さ 36)と上下の間隔 8 ずつの分を空ける
        chartViewController.chartInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8 + 36 + 8, right: 8)

        // 必要に応じて設定を変更できる(例)
        // chartViewController.mainIndicator = .bollingerBands     // メインチャートの指標
        // chartViewController.subIndicator = .macd                // サブチャートの指標
        // chartViewController.parameters.rsiPeriod = 9            // 指標のパラメータ(Model)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let chart = segue.destination as? StockChartViewController {
            embeddedChartViewController = chart
        }
    }

    // MARK: - パネル(テクニカル/設定)を開いている間

    /// パネルの開閉に合わせて、チャート部品と下のボタンの重なり順を切り替える。
    ///
    /// チャート部品(コンテナビュー)は画面いっぱいに置いてあり、パネルと背景のグレーは画面の上端〜下端まで広がる。
    /// ・開いている間: チャート部品を手前にする(下のボタンにもグレーとパネルがかかり、ボタンは押せなくなる)
    /// ・閉じている間: 下のボタンを手前にする(チャート部品は透明な部分もタップを受けるので、手前にあるとボタンが押せない)
    private func configurePanelLayering() {
        chartViewController.onPanelVisibilityChange = { [weak self] isOpen in
            guard let self else { return }
            guard let containerView = self.chartViewController.view.superview else { return }
            if isOpen {
                self.view.bringSubviewToFront(containerView)
            } else {
                // 背景のグレーが消えるのを待ってから(パネルを閉じるアニメーションと同じ 0.25 秒)、ボタンを手前に戻す
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    // 待っている間にもう一度開いた場合は、チャート部品を手前のままにする
                    guard !self.chartViewController.isPanelOpen else { return }
                    self.view.bringSubviewToFront(self.chartTypeButton)
                }
            }
        }
    }

    // MARK: - チャートの種類

    /// チャートの種類のボタンを設定する(タップすると種類のメニューを表示する)
    private func configureChartTypeButton() {
        var configuration = UIButton.Configuration.bordered()
        configuration.baseBackgroundColor = .white
        configuration.baseForegroundColor = .systemBlue
        configuration.background.strokeColor = .systemGray4
        configuration.background.strokeWidth = 1
        configuration.image = UIImage(systemName: "arrowtriangle.down.fill",
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 12))
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 6
        chartTypeButton.configuration = configuration
        chartTypeButton.showsMenuAsPrimaryAction = true
        updateChartTypeButton()

        // 種類が変わったら(メニューからでも、コードから chartType を変えた場合でも)ボタンの表示を合わせる
        chartViewController.onChartTypeChange = { [weak self] _ in
            self?.updateChartTypeButton()
        }
    }

    /// ボタンの文字とメニュー(選択中の種類にチェック)を、選択中のチャートの種類に合わせる。
    /// メニューの中身は開くたびに作るので、指数の種類(海外指数は ローソク足・折線チャート だけ)が後から変わっても反映される
    private func updateChartTypeButton() {
        chartTypeButton.configuration?.title = chartViewController.chartType.title

        let items = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self else {
                completion([])
                return
            }
            let selectedType = self.chartViewController.chartType
            var actions: [UIAction] = []
            for chartType in ChartType.choices(for: self.chartViewController.market) {
                let action = UIAction(title: chartType.title) { [weak self] _ in
                    self?.selectChartType(chartType)
                }
                if chartType == selectedType {
                    action.state = .on
                }
                actions.append(action)
            }
            completion(actions)
        }
        chartTypeButton.menu = UIMenu(children: [items])
    }

    /// チャートの種類を切り替える(ボタンの表示は onChartTypeChange で更新される)
    private func selectChartType(_ chartType: ChartType) {
        chartViewController.chartType = chartType
    }

    // MARK: - データ

    /// ローソク足データを設定して描画する
    @objc func setCandles(_ candles: [StockCandle]) {
        chartViewController.setCandles(candles)
    }

    /// 足種を指定してローソク足データを設定し、描画する(足種ごとの指標パラメータ・日付の書式で表示する)
    @objc func setCandles(_ candles: [StockCandle], period: ChartPeriod) {
        chartViewController.setCandles(candles, period: period)
    }
}

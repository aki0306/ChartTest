//
//  LandscapeChartViewController.swift
//  ChartTest
//
//  【Controller】横画面のチャート画面(Landscape.storyboard)。
//
//   ┌──┬──────────────────────────────────────────────────┐
//   │テ│                                                  │
//   │ク│            StockChartView(チャート本体)            │  ← 共通チャート部品(StockChartViewController)
//   │設│                                                  │
//   ├──┴──────────────────────────────────────────────────┤
//   │日経平均 68309.46 10/02 15:45  [ローソク足▼][月足▼][↻] │ [⤾] │  ← 下の帯(footerView)
//   └─────────────────────────────────────────────────────┘
//
//  ・共通チャート部品は storyboard のコンテナビューに埋め込んであり、
//    左端のテクニカル/設定タブで指標の切り替え・設定変更ができる
//  ・下の帯(Landscape.storyboard の Footer View)
//      左     : 指数名・現在値・日時(updatePriceInfo(name:price:date:) で設定する)
//      ローソク足▼: チャートの種類(ローソク足・VWAP：線・VWAP：点・新値足・折線チャート)を切り替える。
//                  ローソク足以外では、テクニカルのメニューは「なし」だけになり、4本値は表示しない
//      月足▼ : 足種を選ぶ。選ばれると onPeriodSelect が呼ばれるので、その足種のデータを取得して setCandles(_:period:) で渡す
//      ↻     : 更新。onReload が呼ばれるので、表示中の足種のデータを取得し直して渡す
//      ⤾     : 縦画面に戻す。onRotate が呼ばれるので、画面の向きを変える処理をする
//    データの取得・画面の回転は、呼び出し側(アプリ)の仕事にしている(API の取得は非同期のことが多いため)
//  ・チャート部品は画面いっぱいに置き、チャート本体だけを chartInsets で内側(帯の上)に置く。
//    テクニカル/設定を開いている間は、パネルが画面の上端〜セーフエリアの下端まで、背景のグレーが画面全体に広がる(configurePanelLayering)
//
//  使い方(Swift):
//      let viewController = LandscapeChartViewController.instantiate()
//      viewController.chartViewController.market = .overseas               // 海外指数(移動平均線・ローソク足/折線チャートだけ)
//      viewController.onPeriodSelect = { [weak viewController] period in /* その足種のデータを取得して viewController?.setCandles(_:period:) */ }
//      viewController.onReload = { [weak self] in /* 表示中の足種(chartViewController.period)のデータを取得し直す */ }
//      viewController.onRotate = { [weak self] in /* 縦画面に戻す */ }
//      viewController.setCandles(candles, period: .daily)
//      viewController.updatePriceInfo(name: "日経平均", price: 68309.46, date: date)
//
//  使い方(Objective-C):
//      LandscapeChartViewController *viewController = [LandscapeChartViewController instantiate];
//      __weak LandscapeChartViewController *weakViewController = viewController;   // ブロックの中では weak で使う
//      viewController.onPeriodSelect = ^(ChartPeriod period) { ... [weakViewController setCandles:candles period:period]; };
//      viewController.onReload = ^{ ... };
//      viewController.onRotate = ^{ ... };
//      [viewController setCandles:candles period:ChartPeriodDaily];
//      [viewController updatePriceInfoWithName:@"日経平均" price:68309.46 date:date];
//
//  API のレスポンス(足種ごと)を渡す場合(Objective-C):
//      [ChartResponseLoader setDailyResponse:responseArray to:viewController];   // 辞書の配列(NSMutableArray のままでよい)
//      (ChartResponseLoader は縦画面の StockChartView にも使える)
//

import UIKit

final class LandscapeChartViewController: UIViewController {

    /// Landscape.storyboard から生成する
    @objc static func instantiate() -> LandscapeChartViewController {
        UIStoryboard(name: "Landscape", bundle: nil).instantiateInitialViewController() as! LandscapeChartViewController
    }

    // MARK: - 部品(storyboard に配置)

    /// 下の帯(テクニカル/設定のパネルを閉じている間は、チャート部品より手前に置く)
    @IBOutlet private weak var footerView: UIView!
    /// 指数名・現在値・日時(例:「日経平均 68309.46 10/02 15:45」)
    @IBOutlet private weak var priceInfoLabel: UILabel!
    /// チャートの種類を切り替えるボタン(タップで種類のメニューを表示する)
    @IBOutlet private weak var chartTypeButton: UIButton!
    /// 足種を選ぶボタン(タップで足種のメニューを表示する)
    @IBOutlet private weak var periodButton: UIButton!
    /// 更新ボタン
    @IBOutlet private weak var reloadButton: UIButton!
    /// 縦画面に戻すボタン
    @IBOutlet private weak var rotateButton: UIButton!

    // MARK: - 操作されたときの処理(外から設定する)

    /// 足種のメニューで足種が選ばれたときに呼ばれる処理(選ばれた足種が渡される)。
    /// その足種のデータを取得して setCandles(_:period:) で渡すと、チャートとボタンの表示が切り替わる。
    /// この画面がクロージャを持ち続けるので、中でこの画面や呼び出し元を使うときは [weak ...] で受ける(循環参照を防ぐ)
    @objc var onPeriodSelect: ((ChartPeriod) -> Void)?
    /// 更新ボタンが押されたときに呼ばれる処理。表示中の足種(chartViewController.period)のデータを取得し直して渡す
    @objc var onReload: (() -> Void)?
    /// 縦画面に戻すボタンが押されたときに呼ばれる処理
    @objc var onRotate: (() -> Void)?

    /// テクニカル/設定のパネルを開いた・閉じたときに呼ばれる処理(true = 開いた)。
    /// この画面の上に重ねたボタンなど(このアプリでは ViewController の 国内指数/海外指数 の切り替え)を、
    /// パネルを開いている間はパネルの奥に回す場合に使う。
    /// 閉じたときは、パネルを閉じるアニメーション(panelAnimationDuration 秒)が終わってから呼ばれる
    var onPanelVisibilityChange: ((Bool) -> Void)?

    /// パネルを開閉するアニメーションの秒数(StockChartViewController と同じ)
    static let panelAnimationDuration: TimeInterval = 0.25

    /// コンテナビューの embed で受け取った共通チャート部品(画面の読み込み時に設定される)
    private var embeddedChartViewController: StockChartViewController?

    /// 共通チャート部品(指標メニュー・設定画面付き)。
    /// 画面を読み込むまでは存在しないので、まだなら読み込んでから返す
    @objc var chartViewController: StockChartViewController {
        self.loadViewIfNeeded()
        guard let embeddedChartViewController else {
            // storyboard のコンテナビューの embed が外れている(設定ミス)。すぐ気付けるよう落とす
            fatalError("Landscape.storyboard のコンテナビューに StockChartViewController が埋め込まれていません")
        }
        return embeddedChartViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.chartViewController.isTechnicalMenuEnabled = true
        self.configureChartTypeButton()
        self.configurePeriodButton()
        self.configureIconButtons()
        self.configurePanelLayering()
        self.priceInfoLabel.text = nil  // updatePriceInfo で設定されるまでは空にする

        // チャート部品は画面いっぱいに置き(パネルを画面の上端〜下端まで広げるため)、チャート本体だけを内側に置く。
        // 下は帯(セーフエリアの下端から 44pt。Landscape.storyboard)と、その上の間隔 4pt の分を空ける
        self.chartViewController.chartInsets = UIEdgeInsets(top: 8, left: 0, bottom: 44 + 4, right: 8)

        // 表示中の範囲の最高値・最安値を、ローソク足の上・下に表示する
        self.chartViewController.chartView.showsHighLowLabels = true
        // 日付ラベルは、12pt ずつ間隔を空けて、横幅に入るだけ並べる(縦画面より多く表示する)
        self.chartViewController.chartView.xAxisLabelSpacing = 12

        // 必要に応じて設定を変更できる(例)
        // chartViewController.mainIndicator = .bollingerBands     // メインチャートの指標
        // chartViewController.subIndicator = .macd                // サブチャートの指標
        // chartViewController.parameters.rsiPeriod = 9            // 指標のパラメータ(Model)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let chart = segue.destination as? StockChartViewController {
            self.embeddedChartViewController = chart
        }
    }

    // MARK: - パネル(テクニカル/設定)を開いている間

    /// パネルの開閉に合わせて、チャート部品と下の帯の重なり順を切り替える。
    ///
    /// チャート部品(コンテナビュー)は画面いっぱいに置いてあり、パネルと背景のグレーは画面の上端〜下端まで広がる。
    /// ・開いている間: チャート部品を手前にする(下の帯にもグレーとパネルがかかり、帯のボタンは押せなくなる)
    /// ・閉じている間: 下の帯を手前にする(チャート部品は透明な部分もタップを受けるので、手前にあると帯のボタンが押せない)
    private func configurePanelLayering() {
        self.chartViewController.onPanelVisibilityChange = { [weak self] isOpen in
            guard let self else { return }
            guard let containerView = self.chartViewController.view.superview else { return }
            if isOpen {
                self.view.bringSubviewToFront(containerView)
                self.onPanelVisibilityChange?(true)
            } else {
                // 背景のグレーが消えるのを待ってから(パネルを閉じるアニメーションと同じ秒数)、ボタンを手前に戻す
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.panelAnimationDuration) {
                    // 待っている間にもう一度開いた場合は、チャート部品を手前のままにする
                    guard !self.chartViewController.isPanelOpen else { return }
                    self.view.bringSubviewToFront(self.footerView)
                    self.onPanelVisibilityChange?(false)
                }
            }
        }
    }

    // MARK: - チャートの種類

    /// チャートの種類のボタンを設定する(タップすると種類のメニューを表示する)
    private func configureChartTypeButton() {
        self.chartTypeButton.configuration = Self.menuButtonConfiguration()
        self.chartTypeButton.showsMenuAsPrimaryAction = true
        self.updateChartTypeButton()

        // 種類が変わったら(メニューからでも、コードから chartType を変えた場合でも)ボタンの表示を合わせる
        self.chartViewController.onChartTypeChange = { [weak self] _ in
            self?.updateChartTypeButton()
        }
    }

    /// ボタンの文字とメニュー(選択中の種類にチェック)を、選択中のチャートの種類に合わせる。
    /// メニューの中身は開くたびに作るので、指数の種類(海外指数は ローソク足・折線チャート だけ)が後から変わっても反映される
    private func updateChartTypeButton() {
        self.chartTypeButton.configuration?.title = self.chartViewController.chartType.title

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
        self.chartTypeButton.menu = UIMenu(children: [items])
    }

    /// チャートの種類を切り替える(ボタンの表示は onChartTypeChange で更新される)
    private func selectChartType(_ chartType: ChartType) {
        self.chartViewController.chartType = chartType
    }

    // MARK: - 足種

    /// 足種のボタンを設定する(タップすると足種のメニューを表示する)
    private func configurePeriodButton() {
        self.periodButton.configuration = Self.menuButtonConfiguration()
        self.periodButton.showsMenuAsPrimaryAction = true
        self.updatePeriodButton()
    }

    /// ボタンの文字とメニュー(表示中の足種にチェック)を、表示中の足種に合わせる。
    /// メニューの中身は開くたびに作るので、指数の種類(海外指数は 日足・週足・月足 だけ)が後から変わっても反映される
    private func updatePeriodButton() {
        self.periodButton.configuration?.title = Self.shortTitle(of: self.chartViewController.period)

        let items = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self else {
                completion([])
                return
            }
            let selectedPeriod = self.chartViewController.period
            var actions: [UIAction] = []
            for period in self.chartViewController.market.periods {
                let action = UIAction(title: Self.shortTitle(of: period)) { [weak self] _ in
                    self?.onPeriodSelect?(period)
                }
                if period == selectedPeriod {
                    action.state = .on
                }
                actions.append(action)
            }
            completion(actions)
        }
        self.periodButton.menu = UIMenu(children: [items])
    }

    /// ボタン・メニューに出す足種の名前。タブ用の名前(「月 足」)から空白を除く(「月足」)
    private static func shortTitle(of period: ChartPeriod) -> String {
        return period.title.replacingOccurrences(of: " ", with: "")
    }

    // MARK: - 更新・縦画面に戻す

    /// 更新ボタン・縦画面に戻すボタン(アイコンだけのボタン)を設定する
    private func configureIconButtons() {
        self.reloadButton.configuration = Self.iconButtonConfiguration(systemName: "arrow.clockwise")
        self.reloadButton.addTarget(self, action: #selector(self.reloadTapped), for: .touchUpInside)
        self.rotateButton.configuration = Self.iconButtonConfiguration(systemName: "rectangle.portrait.rotate")
        self.rotateButton.addTarget(self, action: #selector(self.rotateTapped), for: .touchUpInside)
    }

    /// 更新ボタンが押されたとき
    @objc private func reloadTapped() {
        self.onReload?()
    }

    /// 縦画面に戻すボタンが押されたとき
    @objc private func rotateTapped() {
        self.onRotate?()
    }

    // MARK: - ボタンの見た目(下の帯で共通)

    /// メニューを開くボタンの見た目(白地・灰色の枠・青い文字 + 右に ▼)
    private static func menuButtonConfiguration() -> UIButton.Configuration {
        var configuration = self.baseButtonConfiguration()
        configuration.image = UIImage(systemName: "arrowtriangle.down.fill",
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 11))
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 6
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .boldSystemFont(ofSize: 15)
            return attributes
        }
        return configuration
    }

    /// アイコンだけのボタンの見た目(白地・灰色の枠・青いアイコン)
    private static func iconButtonConfiguration(systemName: String) -> UIButton.Configuration {
        var configuration = self.baseButtonConfiguration()
        configuration.image = UIImage(systemName: systemName,
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        return configuration
    }

    /// 下の帯のボタンの共通の見た目(白地・灰色の枠・青)
    private static func baseButtonConfiguration() -> UIButton.Configuration {
        var configuration = UIButton.Configuration.bordered()
        configuration.baseBackgroundColor = .white
        configuration.baseForegroundColor = .systemBlue
        configuration.background.strokeColor = .systemGray4
        configuration.background.strokeWidth = 1
        configuration.background.cornerRadius = 6
        return configuration
    }

    // MARK: - 指数名・現在値・日時

    /// 下の帯の左に、指数名・現在値・日時を表示する(例:「日経平均 68309.46 10/02 15:45」)
    /// - Parameters:
    ///   - name: 指数名(「日経平均」など)
    ///   - price: 現在値。小数2桁で表示する(3桁区切りなし)
    ///   - date: 現在値の日時。「MM/dd HH:mm」で表示する
    @objc(updatePriceInfoWithName:price:date:)
    func updatePriceInfo(name: String, price: Double, date: Date) {
        self.loadViewIfNeeded()
        let priceText = ChartNumberFormatter.plainPrice(price)
        let dateText = Self.priceDateFormatter.string(from: date)

        // 指数名・現在値は太字の大きい文字、日時は細い小さい文字
        let text = NSMutableAttributedString(string: "\(name) \(priceText) ",
                                             attributes: [.font: UIFont.boldSystemFont(ofSize: 20)])
        text.append(NSAttributedString(string: dateText, attributes: [.font: UIFont.systemFont(ofSize: 16)]))
        self.priceInfoLabel.attributedText = text
    }

    /// 日時の書式(例: 10/02 15:45)
    private static let priceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()

    // MARK: - データ

    /// ローソク足データを設定して描画する
    @objc func setCandles(_ candles: [StockCandle]) {
        self.chartViewController.setCandles(candles)
    }

    /// 足種を指定してローソク足データを設定し、描画する(足種ごとの指標パラメータ・日付の書式で表示する)。
    /// 足種のボタンの表示も、この足種に合わせる
    @objc func setCandles(_ candles: [StockCandle], period: ChartPeriod) {
        self.chartViewController.setCandles(candles, period: period)
        self.updatePeriodButton()
    }
}

// MARK: - API のレスポンスの描画先にする

/// ChartResponseLoader の描画先にできるようにする(setCandles(_:period:) は上で定義済み)
extension LandscapeChartViewController: StockCandleReceiving {}

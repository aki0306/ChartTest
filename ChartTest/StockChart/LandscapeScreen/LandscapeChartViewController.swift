//
//  LandscapeChartViewController.swift
//  ChartTest
//
//  【Controller】横画面のチャート画面(LandscapeChartViewController.storyboard)。
//
//   ┌──┬──────────────────────────────────────────────────┐
//   │テ│                                                  │
//   │ク│            StockChartView(チャート本体)            │
//   │設│                                                  │
//   ├──┴──────────────────────────────────────────────────┤
//   │日経平均 68309.46 10/02 15:45  [ローソク足▼][月足▼][↻] │ [⤾] │  ← 下の帯(footerView)
//   └─────────────────────────────────────────────────────┘
//
//  【責務】
//  ・状態の保持: ローソク足データ・足種・チャートの種類・選択中の指標・指標パラメータ(足種ごと)・表示オプション
//  ・Model(ChartContentBuilder)で描画内容を組み立て、View(StockChartView)に渡す
//  ・View(TechnicalMenuView / ChartSettingsView / ChartFooterView)からの操作を受け取り、状態を更新して再描画する
//  ・左端のテクニカル/設定タブと、各パネルの開閉
//
//  【ファイルの分け方】1つのクラスを、役割ごとのファイルに分けている
//  ・LandscapeChartViewController.swift            … 状態・画面の向き・ライフサイクル・データを渡す入口・描画(このファイル)
//  ・LandscapeChartViewController+Panels.swift        … チャート・パネル・タブの配置と、パネルを開く・閉じるしくみ
//  ・LandscapeChartViewController+TechnicalMenu.swift … 「テクニカル」タブ・メニューを押したとき(指標の切り替え)
//  ・LandscapeChartViewController+Settings.swift      … 「設定」タブを押したとき・設定画面との受け渡し
//  ・LandscapeChartViewController+Footer.swift        … 下の帯(指数名・現在値、チャートの種類・足種のメニュー)
//  (extension は別のファイルから private のものを使えないので、ファイルをまたいで使うものは private を付けていない)
//
//  ・下の帯(LandscapeChartViewController.storyboard の Footer View。中身は ChartFooterView / ChartFooterView.xib)
//      左     : 指数名・現在値・日時(updatePriceInfo(name:price:date:) で設定する)
//      ローソク足▼: チャートの種類(ローソク足・VWAP：線・VWAP：点・新値足・折線チャート)を切り替える。
//                  ローソク足以外では、テクニカルのメニューは「なし」だけになり、4本値は表示しない。
//                  選ばれると、ボタンがすぐその種類になってチャートが消え、onChartTypeSelect が呼ばれるので、
//                  表示中の足種のデータを取得して setCandles(_:period:) で渡す(onChartTypeSelect がなければ、今のデータのまま描き直す)
//      月足▼ : 足種を選ぶ。選ばれると、ボタンがすぐその足種になってチャートが消え、onPeriodSelect が呼ばれるので、
//              その足種のデータを取得して setCandles(_:period:) で渡す
//      ↻     : 更新。onReload が呼ばれるので、表示中の足種のデータを取得し直して渡す
//      ⤾     : 縦画面に戻す。onRotate が呼ばれるので、画面を閉じる(dismiss)
//    データの取得・画面を閉じる処理は、呼び出し側(アプリ)の仕事にしている(API の取得は非同期のことが多いため)
//  ・縦画面から present で全画面に表示する(instantiate で modalPresentationStyle を .fullScreen にしてある)。
//    開くとき: 縦向きのまま開き、開き終わったら requestGeometryUpdate で横向きに回す(requestEnterLandscape)。
//             回し終わるまでは、チャート・下の帯・タブを隠しておき、回し終わったらフェードで表示する
//             (縦向きのレイアウトのチャートが見えないように)。回し終わったあとは横向きだけに対応する(supportedInterfaceOrientations)
//    閉じるとき: 閉じると、元の画面の向きに戻る
//  ・端末を縦に向けたときも、縦画面に戻すボタンと同じく onRotate が呼ばれる(deviceOrientationDidChange)。
//    向きが変わってから 0.5 秒待って、まだ縦なら呼ぶ(傾けている途中の一瞬の縦では閉じない)。
//    この画面の上にアラートなどを表示している間は呼ばない
//  ・チャートは chartInsets で内側(帯の上)に置く。テクニカル/設定を開いている間は、パネルが画面の上端〜セーフエリアの下端まで、
//    背景のグレーが画面全体(下の帯の上にも)に広がる
//
//  使い方(Swift):
//      let viewController = LandscapeChartViewController.instantiate()
//      viewController.market = .overseasRealtime             // 海外指数(移動平均線・ローソク足/折線チャートだけ)
//      viewController.onPeriodSelect = { [weak viewController] period in /* その足種のデータを取得して viewController?.setCandles(_:period:) */ }
//      viewController.onChartTypeSelect = { [weak viewController] chartType in /* 表示中の足種(period)のデータを取得して viewController?.setCandles(_:period:) */ }
//      viewController.onReload = { [weak self] in /* 表示中の足種(period)のデータを取得し直す */ }
//      viewController.onRotate = { [weak viewController] in viewController?.dismiss(animated: true) }   // 閉じる
//      viewController.setCandles(candles, period: viewController.period)
//      viewController.updatePriceInfo(name: "日経平均", price: 68309.46, date: date)
//      present(viewController, animated: true)
//
//  使い方(Objective-C):
//      LandscapeChartViewController *viewController = [LandscapeChartViewController instantiate];
//      __weak LandscapeChartViewController *weakViewController = viewController;   // ブロックの中では weak で使う
//      viewController.onPeriodSelect = ^(ChartPeriod period) { ... [weakViewController setCandles:candles period:period]; };
//      viewController.onChartTypeSelect = ^(ChartType chartType) { ... [weakViewController setCandles:candles period:weakViewController.period]; };
//      viewController.onReload = ^{ ... };
//      viewController.onRotate = ^{ [weakViewController dismissViewControllerAnimated:YES completion:nil]; };
//      [viewController setCandles:candles period:viewController.period];
//      [viewController updatePriceInfoWithName:@"日経平均" price:68309.46 date:date];
//      [self presentViewController:viewController animated:YES completion:nil];
//
//  チャートの外(サーバーなど)で計算した指標の値を渡す場合(Objective-C):
//      ChartIndicatorPeriods *periods = viewController.indicatorPeriods;   // この期間で計算する(凡例の「期間(14)」などと合わせるため)
//      ChartIndicatorValues *values = [[ChartIndicatorValues alloc] init];
//      values.rsi = rsiValues;                                              // 値を入れた指標は、チャートでは計算しない
//      [viewController setCandles:candles period:ChartPeriodDaily indicatorValues:values];
//
//  API のレスポンス(足種ごと)を渡す場合(Objective-C):
//      [ChartResponseLoader setResponse:responseArray period:ChartPeriodDaily to:viewController];   // 辞書の配列(NSMutableArray のままでよい)
//      (ChartResponseLoader は縦画面の StockChartView にも使える)
//

import UIKit

final class LandscapeChartViewController: UIViewController {

    /// LandscapeChartViewController.storyboard から生成する
    @objc static func instantiate() -> LandscapeChartViewController {
        let storyboard = UIStoryboard(name: "LandscapeChartViewController", bundle: nil)
        guard let viewController = storyboard.instantiateInitialViewController() as? LandscapeChartViewController else {
            // storyboard の最初の画面のクラスが違う(設定ミス)。すぐ気付けるよう落とす
            fatalError("LandscapeChartViewController.storyboard の最初の画面が LandscapeChartViewController になっていません")
        }
        // present したときに全画面で表示する(全画面でないと、画面の向きが横に変わらない)
        viewController.modalPresentationStyle = .fullScreen
        return viewController
    }

    // MARK: - 画面の向き(present で表示したとき)

    /// 縦向きのまま開いて、まだ横向きに回していないか(開いた直後だけ true。requestEnterLandscape で false にする)
    private var isEnteringLandscape = true

    /// 端末を縦に向けたときに閉じる確かめを、向きが変わってから何秒待って行うか
    private static let portraitCheckDelay: TimeInterval = 0.5

    /// 最後に分かった端末の向き(縦か横だけを覚える。机に置いたときなどの向きは無視する)
    private var lastDeviceOrientation = UIDeviceOrientation.unknown

    /// 表示できる向き。開いた直後(横向きに回す前)は縦向き、回したあとは横向きだけ
    /// (アプリの対応する向き(Info.plist)に、Landscape Left / Right が入っている必要がある)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if self.isEnteringLandscape {
            return .portrait
        }
        return .landscape
    }

    /// 開いたときの向き。縦向きのまま開いて、開き終わってから横向きに回す(requestEnterLandscape)
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        if self.isEnteringLandscape {
            return .portrait
        }
        // 右に傾けているときに逆さまにならないよう、逆向きの横画面にする
        // (端末の向き UIDeviceOrientation.landscapeRight は、画面の向き UIInterfaceOrientation.landscapeLeft になる)
        if UIDevice.current.orientation == .landscapeRight {
            return .landscapeLeft
        }
        return .landscapeRight
    }

    // MARK: - 状態(Model の状態)

    /// 表示中のローソク足データ(古い順)
    private var candles: [StockCandle] = []

    /// チャートの外で計算した指標の値(setCandles(_:period:indicatorValues:) で渡されたもの)。
    /// 値が入っている指標は計算せずにこの値で描く。nil ならすべてチャートが計算する。
    /// 新しいデータを値なしで渡したとき・指標の期間が変わったとき(設定画面の「決定」など)は捨てる
    /// (古いデータや違う期間で計算した値のまま描くと、線や凡例の「期間(14)」と合わなくなるため)
    private var indicatorValues: ChartIndicatorValues?

    /// 表示中のデータの足種。使う指標パラメータ(足種ごと)と、設定画面を開いたときのタブを決める。
    /// setCandles(_:period:) で設定する(setCandles(_:) の場合は今の足種のまま)。
    /// 最初は、国内で前回選んでいた足種(初めてなら日足)。market を国内⇔海外で切り替えると、切り替えた先で前回選んでいた足種になる
    /// (ChartStateStore)。そのときは、この足種のデータを取得して setCandles(_:period:) で渡す
    @objc private(set) var period: ChartPeriod = LandscapeChartViewController.initialState.period

    /// 銘柄・指数の種類(日本株・日本株価指数・海外リアルタイム・海外日次。描き方は国内/海外の2通り)。種類によって、選べるもの・使えるものが変わる。
    /// データを渡す前に設定する。
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
    /// チャートの種類・指標・足種・設定値・表示オプションは国内/海外で別々に覚えておき、
    /// 国内⇔海外を切り替えると、切り替えた先で前回選んでいた状態に戻す(アプリの起動中だけ。ChartStateStore)。
    /// 最初は 国内: ローソク足・移動平均線 + 出来高・日足、海外: 折線チャート・移動平均線・日足。
    /// 選べない指標を選んでいた場合は 移動平均線・サブなし に切り替える
    @objc var market: IndexMarket = .japanIndex {
        didSet {
            guard self.market != oldValue else {
                return
            }
            self.loadViewIfNeeded()
            self.applyMarket(previousMarket: oldValue)
        }
    }

    /// 銘柄コード(Objective-C では NSString *。nil = 未設定)。
    /// 折線チャートだけで表示する銘柄(LineChartOnlyCodes)なら、折線チャートで描き、チャートの種類のメニューには折線チャートだけを出す。
    /// market と一緒に、データを渡す前に設定する
    @objc var qCode: String? {
        didSet {
            guard self.qCode != oldValue else {
                return
            }
            self.loadViewIfNeeded()
            self.applyLineChartOnly()
        }
    }

    /// 折線チャートだけで表示する銘柄を表示しているか(applyLineChartOnly で合わせる)。
    /// 対象の銘柄から外れたときに、覚えているチャートの種類に戻すのに使う
    private var isShowingLineChartOnly = false

    /// 折線チャートだけで表示する銘柄か(海外指数で、qCode が LineChartOnlyCodes に入っている)
    var isLineChartOnly: Bool {
        return LineChartOnlyCodes.contains(self.qCode, market: self.market)
    }

    /// 選べるチャートの種類(下の帯のメニューに並べる順)。折線チャートだけで表示する銘柄は、折線チャートだけ
    var chartTypeChoices: [ChartType] {
        if self.isLineChartOnly {
            return [.lineChart]
        }
        return ChartType.choices(for: self.market)
    }

    /// 画面を作ったときの状態(既定の market = 国内で、前回選んでいた状態。初めてなら初期の状態。ChartStateStore)
    private static var initialState: ChartViewState {
        return ChartStateStore.state(for: .japanIndex)
    }

    /// 覚えている状態に戻している最中か(戻している間は、途中で描き直したり、途中の状態を覚え直したりしない)
    private var isRestoringState = false

    /// 足種ごとの指標の計算パラメータ。設定画面で足種ごとに変えられる。
    /// 初期値は足種に合わせたもの(週足の移動平均は 13/26 など。ChartPeriod.indicatorParameters)
    var parametersByPeriod = LandscapeChartViewController.initialState.parametersByPeriod {
        didSet {
            // 期間が変わったら、チャートの外で計算した値は使わない(違う期間で計算した値なので)
            if self.parametersByPeriod != oldValue {
                self.indicatorValues = nil
            }
        }
    }

    /// 表示中の足種の指標パラメータ。変更すると再描画する
    var parameters: IndicatorParameters {
        get {
            self.parameters(for: self.period)
        }
        set {
            self.parametersByPeriod[self.period] = newValue
            self.reloadChart(keepsViewport: true)
        }
    }

    /// 表示オプション(Y軸固定・4本値)。変更すると即座にチャートへ反映する
    var displayOptions = LandscapeChartViewController.initialState.displayOptions {
        didSet {
            self.applyDisplayOptionsToChart()
            // 設定画面でオプションを表示中なら、トグルの状態を合わせる
            if self.selectedSettingsItem == .displayOptions {
                self.reloadSettingsRows()
            }
        }
    }

    /// チャートの種類(ローソク足・VWAP・新値足・折線チャート)。
    /// ローソク足以外では、テクニカル指標とサブチャートは表示せず、テクニカルのメニューは「なし」だけにする。
    /// 4本値は、オンにしていてもローソク足のときだけ表示する。
    /// コードから変える場合は、その種類で使える足種のデータを渡す(VWAP は日中足、新値足・折線チャートは1分足以外。
    /// 下の帯のメニューで選んだときは、使えない足種なら使える足種に切り替える。+Footer.swift の switchPeriodIfUnavailable)
    @objc var chartType: ChartType = LandscapeChartViewController.initialState.chartType {
        didSet {
            // 折線チャートだけで表示する銘柄は、ほかの種類にしない(didSet の中で代入しても、didSet はもう一度呼ばれない)
            if self.isLineChartOnly {
                self.chartType = .lineChart
            }
            guard self.chartType != oldValue else {
                return
            }
            self.menuView.allowsOnlyNone = !self.chartType.usesTechnicalIndicators(in: self.market)
            // 覚えている状態に戻している最中は、指標を「なし」にしたり描き直したりしない(指標も覚えている値に戻すため)
            if self.isRestoringState {
                self.chartTypeDidChange()
                return
            }
            // 指標を使わない種類(VWAP・新値足・国内の折線チャート)にしたら、メイン・サブとも「なし」にする。
            // ローソク足に戻しても「なし」のまま(前に選んでいた指標には戻さない)
            if !self.chartType.usesTechnicalIndicators(in: self.market) {
                self.mainIndicator = .candleOnly
                self.subIndicator = .hidden
            }
            self.applyDisplayOptionsToChart()
            self.reloadChart(keepsViewport: true)
            self.chartTypeDidChange()
        }
    }

    /// メインチャートに表示する指標。変更すると表示位置を保ったまま再描画する
    /// (テクニカルのメニューで選ばれたときも、ここを通る。+TechnicalMenu.swift)
    @objc var mainIndicator: MainChartIndicator = LandscapeChartViewController.initialState.mainIndicator {
        didSet {
            guard self.mainIndicator != oldValue else {
                return
            }
            self.menuView.selectedMainIndicator = self.mainIndicator
            guard !self.isRestoringState else {
                return
            }
            self.reloadChart(keepsViewport: true)
        }
    }

    /// サブチャートに表示する指標。.hidden にするとサブチャートを隠す
    /// (テクニカルのメニューで選ばれたときも、ここを通る。+TechnicalMenu.swift)
    @objc var subIndicator: SubChartIndicator = LandscapeChartViewController.initialState.subIndicator {
        didSet {
            guard self.subIndicator != oldValue else {
                return
            }
            self.menuView.selectedSubIndicator = self.subIndicator
            guard !self.isRestoringState else {
                return
            }
            self.reloadChart(keepsViewport: true)
        }
    }

    /// チャート(とテクニカル/設定タブ)を、この画面のセーフエリアの端からどれだけ内側に置くか。
    /// 下は帯(セーフエリアの下端から 44pt。LandscapeChartViewController.storyboard)と、その上の間隔 4pt の分を空ける。
    /// テクニカル/設定のパネルと背景のグレーは、この余白に関係なく、画面の上端〜下端いっぱいに表示する
    @objc var chartInsets = UIEdgeInsets(top: 8, left: 0, bottom: 44 + 4, right: 8) {
        didSet {
            self.applyChartInsets()
        }
    }

    // MARK: - 操作されたときの処理(外から設定する)

    /// 足種のメニューで足種が選ばれたときに呼ばれる処理(選ばれた足種が渡される。流れは +Footer.swift の先頭)。
    /// 呼ばれる前に、ボタンはその足種になり、チャートは消えている。その足種のデータを取得して setCandles(_:period:) で渡すと、チャートを描く。
    /// この画面がクロージャを持ち続けるので、中でこの画面や呼び出し元を使うときは [weak ...] で受ける(循環参照を防ぐ)
    @objc var onPeriodSelect: ((ChartPeriod) -> Void)?
    /// チャートの種類のメニューで種類が選ばれたときに呼ばれる処理(選ばれた種類が渡される。流れは +Footer.swift の先頭)。
    /// 呼ばれる前に、ボタンはその種類になり、チャートは消えている。表示中の足種(period)のデータを取得して setCandles(_:period:) で渡すと、チャートを描く。
    /// 設定しない場合は、チャートを消さずに、今のデータのままその種類で描き直す。
    /// 種類を変えたことで足種も変わったときは、これは呼ばれず onPeriodSelect が呼ばれる(データの取得を1回にするため)
    @objc var onChartTypeSelect: ((ChartType) -> Void)?
    /// 更新ボタンが押されたときに呼ばれる処理。表示中の足種(period)のデータを取得し直して渡す
    @objc var onReload: (() -> Void)?
    /// 縦画面に戻すボタンが押されたとき・端末を縦に向けたときに呼ばれる処理。present で表示した場合は、ここで dismiss する
    @objc var onRotate: (() -> Void)?

    /// テクニカル/設定のパネルを開いた・閉じたときに呼ばれる処理(true = 開いた)。
    /// 閉じたときは、パネルを閉じるアニメーション(panelAnimationDuration 秒)が終わってから呼ばれる
    var onPanelVisibilityChange: ((Bool) -> Void)?

    /// パネルを開閉するアニメーションの秒数
    static let panelAnimationDuration: TimeInterval = 0.25

    /// パネルを開いているときに、後ろ(チャートと下の帯)に重ねる色。半透明の黒で、背景をグレーに見せる
    static let dimmingColor = UIColor(resource: .chartDimming)

    // MARK: - 部品(View)

    /// 下の帯(ChartFooterView。見た目は ChartFooterView.xib)。storyboard に配置
    @IBOutlet weak var footerView: ChartFooterView!
    /// チャート本体。見た目は chartView.style で変更できる
    @objc let chartView = StockChartView()
    /// パネルを開いているときにチャートと下の帯の上に重ねる、半透明の黒(背景をグレーにする)。タップするとパネルを閉じる
    let dimmingView = UIView()
    /// 指標の選択メニュー
    let menuView = TechnicalMenuView()
    /// 設定画面
    let settingsView = ChartSettingsView()
    /// テクニカルタブ(指標の選択メニューを開閉)
    let technicalTabButton = UIButton(type: .custom)
    /// 設定タブ(設定画面を開閉)
    let settingsTabButton = UIButton(type: .custom)
    /// 2つのタブを縦に並べるスタック
    let tabStack = UIStackView()

    // MARK: - パネル(テクニカル/設定)の状態

    /// 開閉できるパネルの種類
    enum Panel {
        /// 指標の選択メニュー
        case technical
        /// 設定画面
        case settings
    }

    /// 開いているパネル(nil = どちらも閉じている)
    var openPanel: Panel?

    /// テクニカル/設定のパネルを開いているか
    var isPanelOpen: Bool {
        return self.openPanel != nil
    }

    /// 設定画面の左側リストで選択中の位置
    var selectedSettingsIndexPath = IndexPath(row: 0, section: 0)

    /// 設定画面の左側リストに並べる見出しと項目(指数の種類で変わる)
    var settingsSections: [ChartSettingsSection] {
        ChartSettingsCatalog.sections(for: self.market)
    }

    /// 設定画面で選択中の項目
    var selectedSettingsItem: ChartSettingsItem {
        let indexPath = self.selectedSettingsIndexPath
        let section = self.settingsSections[indexPath.section]
        return section.items[indexPath.row]
    }

    /// 設定画面で選択中の足種(タブ)
    var settingsPeriod: ChartPeriod = .daily

    /// 設定画面で編集中のパラメータ(足種ごと)。
    /// 設定画面を開くたびに今のパラメータから作り直し、「決定」を押すと parametersByPeriod に反映する
    /// (決定せずに閉じた場合は捨てる)
    var draftParametersByPeriod: [ChartPeriod: IndicatorParameters] = [:]

    // MARK: - レイアウト

    /// タブの幅
    let tabWidth: CGFloat = 30
    /// タブとチャートの間隔
    let tabSpacing: CGFloat = 8

    /// チャートの上端・下端・左端・右端(chartInsets で位置が変わる)
    var chartTopConstraint: NSLayoutConstraint?
    var chartBottomConstraint: NSLayoutConstraint?
    var chartLeadingConstraint: NSLayoutConstraint?
    var chartTrailingConstraint: NSLayoutConstraint?
    /// タブの左端: パネルを閉じているとき(画面の左端に付ける)
    var tabClosedConstraint: NSLayoutConstraint?
    /// タブの左端: 指標の選択メニューを開いているとき(メニューの右端に付ける)
    var tabTechnicalOpenedConstraint: NSLayoutConstraint?
    /// タブの左端: 設定画面を開いているとき(設定画面の右端に付ける)
    var tabSettingsOpenedConstraint: NSLayoutConstraint?

    // MARK: - ライフサイクル

    override func viewDidLoad() {
        super.viewDidLoad()

        // 重なり順(下から): チャート → 下の帯 → 背景のグレー → パネル → タブ(+Panels)
        self.setupChartView()
        self.setupPanels()
        self.setupTabs()
        self.configureSettingsView()
        self.configureFooter()

        // 表示中の範囲の最高値・最安値を、ローソク足の上・下に表示する
        self.chartView.showsHighLowLabels = true

        // 必要に応じて設定を変更できる(例)
        // self.mainIndicator = .bollingerBands     // メインチャートの指標
        // self.subIndicator = .macd                // サブチャートの指標
        // self.parameters.rsiPeriod = 9            // 指標のパラメータ(Model)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 開くとき: 横向きに回し終わるまで、チャート・下の帯・タブを隠しておく(縦向きのレイアウトのチャートが見えないように)
        guard self.isEnteringLandscape else {
            return
        }
        guard self.isBeingPresented else {
            return
        }
        self.setContentVisible(false, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 端末を縦に向けたら閉じられるよう、端末の向きの変化を受け取る
        self.lastDeviceOrientation = UIDevice.current.orientation
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(self.deviceOrientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)

        // 開き終わったら、横向きに回す
        if self.isEnteringLandscape {
            self.requestEnterLandscape()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // 横向きに回し終わったら、隠していたチャート・下の帯・タブを表示する
        coordinator.animate(alongsideTransition: nil) { context in
            guard !context.isCancelled else {
                return
            }
            guard size.width > size.height else {
                return
            }
            self.setContentVisible(true, animated: true)
        }
    }

    /// 横向きに回す(開き終わったときに1回だけ呼ぶ)。
    /// 横向きだけに対応するよう切り替えてから、シーンに横向きを頼む。
    /// すでに横向きのとき・回せなかったとき(iPad の画面分割中など)は、回さずにそのまま表示する
    private func requestEnterLandscape() {
        self.isEnteringLandscape = false
        self.setNeedsUpdateOfSupportedInterfaceOrientations()

        // present 以外で表示した場合(子として埋め込んだ場合など)は、向きは変えない
        guard self.presentingViewController != nil else {
            self.setContentVisible(true, animated: false)
            return
        }
        guard let windowScene = self.view.window?.windowScene else {
            self.setContentVisible(true, animated: false)
            return
        }
        if windowScene.effectiveGeometry.interfaceOrientation.isLandscape {
            self.setContentVisible(true, animated: false)
            return
        }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { [weak self] _ in
            DispatchQueue.main.async {
                self?.setContentVisible(true, animated: true)
            }
        }
    }

    /// チャート・下の帯・タブを表示する・隠す(パネルと背景のグレーは、閉じている間はもともと隠れている)
    private func setContentVisible(_ isVisible: Bool, animated: Bool) {
        var alpha: CGFloat = 0
        if isVisible {
            alpha = 1
        }
        let views: [UIView] = [self.chartView, self.footerView, self.tabStack]
        if animated {
            UIView.animate(withDuration: 0.2) {
                for view in views {
                    view.alpha = alpha
                }
            }
        } else {
            for view in views {
                view.alpha = alpha
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        // 頼んでいた縦向きの確かめは取り消す(閉じたあとに onRotate が呼ばれないように)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.checkPortraitAndClose), object: nil)
    }

    /// 端末の向きが変わったとき。横から縦に変わったら、0.5 秒待ってからもう一度確かめる(checkPortraitAndClose)
    /// (縦のままボタンで開いたあと、机に置いて持ち上げただけで閉じないよう、横を経由したときだけにする)
    @objc private func deviceOrientationDidChange() {
        let orientation = UIDevice.current.orientation
        if orientation == .portrait {
            let wasLandscape = self.lastDeviceOrientation.isLandscape
            self.lastDeviceOrientation = orientation
            guard wasLandscape else {
                return
            }
            // 傾けている途中の一瞬の縦では閉じないよう、少し待ってから確かめる(前に頼んだ確かめは取り消す)
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.checkPortraitAndClose), object: nil)
            self.perform(#selector(self.checkPortraitAndClose), with: nil, afterDelay: Self.portraitCheckDelay)
            return
        }
        if orientation.isLandscape {
            self.lastDeviceOrientation = orientation
        }
    }

    /// 端末がまだ縦向きなら、縦画面に戻すボタンと同じく onRotate を呼ぶ(閉じる処理は onRotate に任せる)。
    /// この画面の上にアラートなどを表示している間は呼ばない
    @objc private func checkPortraitAndClose() {
        guard UIDevice.current.orientation == .portrait else {
            return
        }
        guard self.presentedViewController == nil else {
            return
        }
        self.onRotate?()
    }

    // MARK: - 外から呼ぶ入口

    /// ローソク足データを設定して描画する。
    /// Objective-C からは `[viewController setCandles:candles]` で呼び出せる。
    /// - Parameter candles: 日付の古い順に並んだローソク足データ
    @objc func setCandles(_ candles: [StockCandle]) {
        // メインスレッドでなければ、メインスレッドで呼び直す(通信の完了処理から直接呼ばれても安全にする。MainThread)
        guard MainThread.isCurrent(orRetry: { self.setCandles(candles) }) else {
            return
        }

        self.loadViewIfNeeded()
        self.indicatorValues = nil
        self.candles = candles
        self.reloadChart(keepsViewport: false)
    }

    /// 足種を指定してローソク足データを設定し、描画する。
    /// 足種によって、使う指標パラメータ(足種ごと)と、X軸の日付の書式・初期表示本数が変わる。足種のボタンの表示も、この足種に合わせる。
    /// Objective-C からは `[viewController setCandles:candles period:ChartPeriodWeekly]` で呼び出せる。
    /// - Parameters:
    ///   - candles: 日付の古い順に並んだローソク足データ(その足種のデータ)
    ///   - period: 足種
    @objc func setCandles(_ candles: [StockCandle], period: ChartPeriod) {
        self.setCandles(candles, period: period, indicatorValues: nil)
    }

    /// 足種を指定してローソク足データと、チャートの外(サーバーなど)で計算した指標の値を渡し、描画する。
    /// 値が入っている指標は計算せずにその値で描き、入っていない指標はチャートが計算する(ChartIndicatorValues)。
    ///
    ///   指標の値は、indicatorPeriods の期間で計算しておく(凡例の「期間(14)」などと合わせるため)。
    ///   値は、メニューで指標を切り替えても使う(使う指標の分だけ入れておけばよい)。
    ///   設定画面などで期間が変わったときは捨てて、チャートが計算する(新しい期間の値は、次に setCandles で渡す)
    ///
    /// Objective-C からは `[viewController setCandles:candles period:ChartPeriodDaily indicatorValues:values]` で呼び出せる。
    /// - Parameters:
    ///   - candles: 日付の古い順に並んだローソク足データ(その足種のデータ)
    ///   - period: 足種
    ///   - indicatorValues: チャートの外で計算した指標の値(candles と同じ並び)。nil ならすべてチャートが計算する
    @objc func setCandles(_ candles: [StockCandle], period: ChartPeriod, indicatorValues: ChartIndicatorValues?) {
        // メインスレッドでなければ、メインスレッドで呼び直す(通信の完了処理から直接呼ばれても安全にする。MainThread)
        guard MainThread.isCurrent(orRetry: { self.setCandles(candles, period: period, indicatorValues: indicatorValues) }) else {
            return
        }

        self.loadViewIfNeeded()
        self.period = period

        // 足種に合わせて見た目を変える(style を変えると描き直されるので、まとめて1回で代入する)
        self.chartView.style = self.chartView.style.applying(period)

        // テクニカルで選べる指標を足種に合わせる(1分足・日中足は 移動平均線・出来高 などだけ)。
        // 選べない指標から切り替えたときに、新しい足種のデータで描き直されるよう、先にデータを持たせておく
        // 計算済みの値も、データと一緒に先に入れておく(指標の切り替えで途中で描き直すときに、古い値で描かないように)
        self.candles = candles
        self.indicatorValues = indicatorValues
        self.applyIndicatorChoices()

        self.reloadChart(keepsViewport: false)
        self.updatePeriodMenu()
    }

    /// 足種を切り替え、新しいデータが届くまでチャートを消す(足種のメニューで選ばれたとき。+Footer.swift)。
    /// 足種のボタンはすぐこの足種になり、この足種のデータは setCandles(_:period:) で渡されたときに描く
    func switchPeriodAndClearChart(to period: ChartPeriod) {
        self.loadViewIfNeeded()
        self.period = period
        self.chartView.style = self.chartView.style.applying(period)

        // 前の足種のデータは使わない(データがないので、reloadChart でチャートが消える)
        self.candles = []
        self.indicatorValues = nil
        self.applyIndicatorChoices()

        self.reloadChart(keepsViewport: false)
        self.updatePeriodMenu()
    }

    /// 新しいデータが届くまでチャートを消す(チャートの種類のメニューで選ばれたとき。+Footer.swift)。
    /// データは setCandles(_:period:) で渡されたときに描く
    func clearChartUntilNewCandles() {
        self.loadViewIfNeeded()
        self.candles = []
        self.indicatorValues = nil
        self.reloadChart(keepsViewport: false)
    }

    /// 指標の計算に使う期間など(表示中の足種の値)。チャートの外で指標を計算するときは、この値で計算する
    @objc var indicatorPeriods: ChartIndicatorPeriods {
        return ChartIndicatorPeriods(parameters: self.parameters)
    }

    /// すべての足種の指標パラメータを変更して、描き直す(Swift からも使える)。
    /// 例: viewController.updateParametersForAllPeriods { $0.rsiPeriod = 9 }
    /// 表示中の足種だけを変える場合は parameters を、足種を指定する場合は setParameters(_:for:) を使う
    func updateParametersForAllPeriods(_ change: (inout IndicatorParameters) -> Void) {
        for period in ChartPeriod.allCases {
            var target = self.parameters(for: period)
            change(&target)
            self.parametersByPeriod[period] = target
        }
        self.reloadChart(keepsViewport: true)
    }

    /// 指定した足種の指標パラメータを変更して、描き直す
    func setParameters(_ parameters: IndicatorParameters, for period: ChartPeriod) {
        self.parametersByPeriod[period] = parameters
        self.reloadChart(keepsViewport: true)
    }

    /// 指定した足種の指標パラメータ
    func parameters(for period: ChartPeriod) -> IndicatorParameters {
        if let parameters = self.parametersByPeriod[period] {
            return parameters
        }
        return period.indicatorParameters
    }

    // MARK: - 描画(Model → View)

    /// 現在の状態から Model で描画内容を組み立て、View に表示させる
    /// - Parameter keepsViewport: true の場合、可能であれば現在の表示位置・拡大率を維持する
    func reloadChart(keepsViewport: Bool) {
        // 指標・足種・設定値などが変わるとここを通るので、今の状態を国内/海外ごとに覚えておく
        self.saveState()
        guard !self.candles.isEmpty else {
            self.chartView.clear()
            return
        }
        // 日時だけの足(1分足・日中足の、値のない時間帯)は、先頭側・末尾側を X軸の日付だけに使う
        let slots = CandleSlots(self.candles)
        var builder = ChartContentBuilder(candles: slots.candles, parameters: self.parameters)
        builder.precomputed = self.indicatorValues
        let content = builder.content(for: self.chartType, mainIndicator: self.mainIndicator, subIndicator: self.subIndicator,
                                      market: self.market, period: self.period)
        // 足種・指数の種類・チャートの種類が前回と同じなら、データの更新として直前の表示範囲を引き継ぐ
        let rangeKey = VisibleRangeKey(period: self.period, market: self.market, chartType: self.chartType)
        self.chartView.display(candles: content.candles,
                               main: content.main,
                               sub: content.sub,
                               keepsViewport: keepsViewport,
                               leadingDates: StockChartView.leadingDates(of: slots, chartType: self.chartType),
                               trailingDates: StockChartView.trailingDates(of: slots, chartType: self.chartType),
                               rangeKey: rangeKey)
    }

    /// 表示オプションをチャートに反映する。
    /// どのオプションが効くか(ローソク足以外では4本値を出さない など)は Model の ChartDisplayOptions.effective が決める
    func applyDisplayOptionsToChart() {
        self.chartView.displayOptions = self.displayOptions.effective(for: self.chartType, market: self.market)
        self.saveState()
    }

    // MARK: - 状態を覚える(国内/海外ごと)

    /// 今の状態(チャートの種類・指標・足種・設定値・表示オプション)
    private var currentState: ChartViewState {
        return ChartViewState(chartType: self.chartType,
                              mainIndicator: self.mainIndicator,
                              subIndicator: self.subIndicator,
                              period: self.period,
                              parametersByPeriod: self.parametersByPeriod,
                              displayOptions: self.displayOptions)
    }

    /// 今の状態を、今の market の種類(国内/海外)として覚える。状態を戻している最中は覚えない。
    /// 折線チャートだけで表示する銘柄のときは、チャートの種類は覚えているものを残す
    /// (折線チャートで覚えると、ほかの海外の銘柄を開いたときも折線チャートになるため)
    private func saveState() {
        guard !self.isRestoringState else {
            return
        }
        var state = self.currentState
        if self.isLineChartOnly {
            state.chartType = ChartStateStore.state(for: self.market).chartType
        }
        ChartStateStore.save(state, for: self.market)
    }

    /// 指定した種類(国内/海外)で覚えている状態に戻す(描き直しは呼び出し側で行う)
    private func restoreState(for market: IndexMarket) {
        let state = ChartStateStore.state(for: market)
        self.isRestoringState = true
        self.chartType = state.chartType
        self.mainIndicator = state.mainIndicator
        self.subIndicator = state.subIndicator
        self.period = state.period
        self.parametersByPeriod = state.parametersByPeriod
        self.displayOptions = state.displayOptions
        self.isRestoringState = false
        // 足種に合わせて見た目を変える(データは、この足種のものを setCandles(_:period:) で渡してもらう)
        self.chartView.style = self.chartView.style.applying(self.period)
    }

    // MARK: - 指数の種類

    /// 指数の種類に合わせて、選べる指標・チャートの種類・設定画面の項目を切り替え、描き直す
    /// - Parameter previousMarket: 変える前の指数の種類(設定画面で選んでいた項目を探すのに使う)
    private func applyMarket(previousMarket: IndexMarket) {
        // 国内⇔海外を切り替えた場合は、切り替えた先で前回選んでいた状態(チャートの種類・指標・足種・設定値・表示オプション)に戻す。
        // 切り替える前の状態は、変更のたびに覚えている(saveState)。国内どうし・海外どうしの切り替えでは、状態はそのまま
        if previousMarket.isDomestic != self.market.isDomestic {
            self.restoreState(for: self.market)
        }

        // テクニカルのメニューに並べる指標(海外指数の折線チャートは指標を重ねられるので、「なし」だけにするかも変わる)
        self.menuView.allowsOnlyNone = !self.chartType.usesTechnicalIndicators(in: self.market)
        self.applyIndicatorChoices()

        // 折線チャートだけで表示する銘柄なら折線チャートにし、選べない種類だった場合は、その指数の既定の種類にする
        // (それぞれの didSet でも描き直すが、最後にまとめて描き直す)
        self.applyChartTypeChoices()

        self.applyDisplayOptionsToChart()
        self.reloadChart(keepsViewport: true)

        // 設定画面の左側リストを作り直す。編集中の内容(「決定」前の値)は残す。
        // 選んでいた項目が新しいリストにもあればその選択を残し、なければ先頭の「オプション」に戻す
        let previousItem = self.settingsItem(at: self.selectedSettingsIndexPath, in: previousMarket)
        self.selectedSettingsIndexPath = IndexPath(row: 0, section: 0)
        if let previousItem {
            if let indexPath = self.indexPathInSettingsList(of: previousItem) {
                self.selectedSettingsIndexPath = indexPath
            }
        }
        self.reloadSettingsList()
        self.reloadSettingsRows()

        // 下の帯のボタンの表示も合わせる(足種は、国内/海外ごとに前回選んでいた足種に変わっていることがある)
        self.updateChartTypeMenu()
        self.updatePeriodMenu()
    }
}

// MARK: - 折線チャートだけで表示する銘柄

extension LandscapeChartViewController {

    /// 銘柄コード(qCode)が変わったとき。折線チャートだけで表示する銘柄かどうかに合わせて、チャートの種類とメニューを切り替える
    func applyLineChartOnly() {
        self.applyChartTypeChoices()
        // チャートの種類が変わらなくても、メニューに並べる種類は変わる
        self.updateChartTypeMenu()
    }

    /// チャートの種類を、選べる種類(chartTypeChoices)に合わせる。
    ///   ・折線チャートだけで表示する銘柄: 折線チャートにする
    ///   ・対象の銘柄から外れたとき: 覚えているチャートの種類(ChartStateStore)に戻す
    ///   ・この指数で選べない種類だったとき: その指数の既定の種類にする
    func applyChartTypeChoices() {
        let isLineChartOnly = self.isLineChartOnly
        let wasLineChartOnly = self.isShowingLineChartOnly
        self.isShowingLineChartOnly = isLineChartOnly
        if isLineChartOnly {
            self.chartType = .lineChart
            return
        }
        if wasLineChartOnly {
            self.chartType = ChartStateStore.state(for: self.market).chartType
        }
        if !ChartType.choices(for: self.market).contains(self.chartType) {
            self.chartType = ChartType.defaultType(for: self.market)
        }
    }
}

// MARK: - API のレスポンスの描画先にする

/// ChartResponseLoader の描画先にできるようにする(market・setCandles(_:period:) は上で定義済み)
extension LandscapeChartViewController: StockCandleReceiving {}

// MARK: - Objective-C 向けのパラメータ・オプション設定

/// IndicatorParameters / ChartDisplayOptions は struct のため Objective-C から直接扱えない。
/// よく変更するものだけを @objc プロパティとして公開する。
/// ・指標の期間: 読み出しは表示中の足種の値、設定は**すべての足種**に反映する(設定画面の「すべての足に反映」と同じ)
/// ・表示オプション: displayOptions を読み書きしているだけ
extension LandscapeChartViewController {

    /// 短期移動平均の期間(本数)。設定するとすべての足種に反映する
    @objc var shortMAPeriod: Int {
        get {
            self.parameters.shortMAPeriod
        }
        set {
            self.updateParametersForAllPeriods { parameters in
                parameters.shortMAPeriod = newValue
            }
        }
    }

    /// 長期移動平均の期間(本数)。設定するとすべての足種に反映する
    @objc var longMAPeriod: Int {
        get {
            self.parameters.longMAPeriod
        }
        set {
            self.updateParametersForAllPeriods { parameters in
                parameters.longMAPeriod = newValue
            }
        }
    }

    /// 出来高移動平均の期間(本数)。設定するとすべての足種に反映する
    @objc var volumeMAPeriod: Int {
        get {
            self.parameters.volumeMAPeriod
        }
        set {
            self.updateParametersForAllPeriods { parameters in
                parameters.volumeMAPeriod = newValue
            }
        }
    }

    /// Y軸(メイン)固定
    @objc var isMainYAxisFixed: Bool {
        get {
            self.displayOptions.isMainYAxisFixed
        }
        set {
            self.displayOptions.isMainYAxisFixed = newValue
        }
    }

    /// Y軸(サブ)固定
    @objc var isSubYAxisFixed: Bool {
        get {
            self.displayOptions.isSubYAxisFixed
        }
        set {
            self.displayOptions.isSubYAxisFixed = newValue
        }
    }

    /// 4本値(十字線と、その足の日付・始値・高値・安値・終値を表示する)
    @objc var showsOHLC: Bool {
        get {
            self.displayOptions.showsOHLC
        }
        set {
            self.displayOptions.showsOHLC = newValue
        }
    }
}

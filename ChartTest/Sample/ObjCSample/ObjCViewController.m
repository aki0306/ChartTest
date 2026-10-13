//
//  ObjCViewController.m
//  ChartTest
//
//  【Controller】ViewController.swift を Objective-C で書いたもの。縦向きのチャートを置き、
//  ボタンで横画面のチャート画面を全画面で表示(present)する。
//
//  ・縦向き: StockChartView(チャートだけ。最初は日足を表示する)。この画面は縦向きだけで表示する(supportedInterfaceOrientations)
//  ・横画面: LandscapeChartViewController(LandscapeChartViewController.storyboard。StockChartViewController で指標メニュー付き表示)。
//           チャートの下の「横画面にする」ボタン(rotateButton)で present すると横向きになり、
//           下の帯の「縦画面に戻す」ボタンで閉じる(dismiss)と縦向きに戻る。
//           端末を横に向けても開き(deviceOrientationDidChange)、縦に戻すと閉じる(LandscapeChartViewController が onRotate を呼ぶ)
//  この画面は「横画面を開く」ことと「データを渡す」ことだけを担当する。
//  左下の切り替えボタン(marketControl)で、日本株/国内指数/海外指数(リアルタイム・日次)を切り替えて表示を確かめられる
//  (横画面は、開いたときに選んでいる種類で表示する)。
//  チャートの上には縦向きのチャートの足種を切り替えるボタン(periodControl)を置く(テスト用)。
//  横画面の下の帯(足種・更新・縦画面に戻す)が押されたときの処理も、ここで設定している(presentLandscapeChart)。
//
//  ChartPeriod.title・IndexMarket.periods は Swift の enum のプロパティで Objective-C からは呼べないため、
//  同じ内容をこのファイルに書いている(titleForPeriod: ・periodsForMarket:)。Swift 側を変えたら、こちらも合わせる。
//

#import "ObjCViewController.h"
// Swift のクラス(StockChartView / LandscapeChartViewController / SampleData など)を Objective-C から使うための自動生成ヘッダ
#import "ChartTest-Swift.h"

@interface ObjCViewController ()

// MARK: - Children

/// 縦向きのチャート(チャートだけ。最初は日足を表示する)
@property (nonatomic, strong) StockChartView *portraitChartView;

// MARK: - 銘柄・指数の種類の切り替え

/// 日本株/国内指数/海外指数を切り替えるボタン(左下)
@property (nonatomic, strong) UISegmentedControl *marketControl;

/// 切り替えボタンの並び順と同じ、銘柄・指数の種類(IndexMarket を NSNumber に包んだもの)
@property (nonatomic, copy) NSArray<NSNumber *> *marketChoices;

/// 最初に表示する銘柄・指数の種類(国内指数)
@property (nonatomic, assign) IndexMarket initialMarket;

// MARK: - 縦向きのチャートの足種の切り替え(テスト用)

/// 縦向きのチャートの足種を切り替えるボタン(チャートの上)
@property (nonatomic, strong) UISegmentedControl *periodControl;

/// 切り替えボタンの並び順と同じ足種(ChartPeriod を NSNumber に包んだもの)
@property (nonatomic, copy) NSArray<NSNumber *> *periodChoices;

/// 縦向きのチャートに表示している足種
@property (nonatomic, assign) ChartPeriod portraitPeriod;

/// 表示している銘柄・指数の種類
@property (nonatomic, assign) IndexMarket currentMarket;

// MARK: - 横画面にするボタン

/// 横画面のチャートを開くボタン(チャートの下)
@property (nonatomic, strong) UIButton *rotateButton;

// MARK: - 端末の向き

/// 最後に分かった端末の向き(縦か横だけを覚える。机に置いたときなどの向きは無視する)
@property (nonatomic, assign) UIDeviceOrientation lastDeviceOrientation;

@end

@implementation ObjCViewController

// MARK: - Init

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

/// プロパティの初期値を設定する(Swift 版でプロパティの宣言時に入れている値)
- (void)commonInit {
    self.portraitChartView = [[StockChartView alloc] init];

    self.marketControl = [[UISegmentedControl alloc] initWithItems:@[@"日本株", @"国内指数", @"海外(R)", @"海外(D)"]];
    self.marketChoices = @[@(IndexMarketJapanStock), @(IndexMarketJapanIndex), @(IndexMarketOverseasRealtime), @(IndexMarketOverseasDaily)];
    self.initialMarket = IndexMarketJapanIndex;

    self.periodControl = [[UISegmentedControl alloc] init];
    self.periodChoices = @[@(ChartPeriodOneMinute), @(ChartPeriodIntraday), @(ChartPeriodDaily), @(ChartPeriodWeekly), @(ChartPeriodMonthly)];
    self.portraitPeriod = ChartPeriodDaily;
    self.currentMarket = IndexMarketJapanIndex;

    self.rotateButton = [UIButton buttonWithConfiguration:[UIButtonConfiguration tintedButtonConfiguration] primaryAction:nil];
}

// MARK: - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorNamed:@"SampleBackground"];

    [self setupPortraitChartView];

    // 縦向きのチャートの足種の切り替えボタン(テスト用)と、横画面にするボタン
    [self setupPeriodControl];
    [self setupRotateButton];

    // 日本株/国内指数/海外指数の切り替えボタン(最初は国内指数)
    [self setupMarketControl];
    [self showPortraitChartForMarket:self.initialMarket];
}

// MARK: - 画面の向き

/// この画面は縦向きだけで表示する(横画面のチャートは present で開く。LandscapeChartViewController は横向きだけ)
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // 端末を横に向けたら横画面のチャートを開けるよう、端末の向きの変化を受け取る
    // (横画面のチャートを開いている間は、viewWillDisappear: で受け取るのをやめる)
    self.lastDeviceOrientation = UIDevice.currentDevice.orientation;
    [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(deviceOrientationDidChange)
                                               name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [NSNotificationCenter.defaultCenter removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    [UIDevice.currentDevice endGeneratingDeviceOrientationNotifications];
}

/// 端末の向きが変わったとき。縦から横に変わったら、横画面のチャートを開く
/// (横に持ったまま「縦画面に戻す」で閉じたときに、すぐ開き直さないよう、縦を経由したときだけにする)
- (void)deviceOrientationDidChange {
    UIDeviceOrientation orientation = UIDevice.currentDevice.orientation;
    if (UIDeviceOrientationIsLandscape(orientation)) {
        BOOL wasLandscape = UIDeviceOrientationIsLandscape(self.lastDeviceOrientation);
        self.lastDeviceOrientation = orientation;
        if (wasLandscape) {
            return;
        }
        if (self.presentedViewController != nil) {
            return;
        }
        [self presentLandscapeChart];
        return;
    }
    if (orientation == UIDeviceOrientationPortrait) {
        self.lastDeviceOrientation = orientation;
    }
}

// MARK: - Setup

/// 縦向きのチャートを画面の上のほうに置く(高さを決めないと何も見えない)。
/// 上端は、足種の切り替えボタンの下に合わせる(setupPeriodControl)
- (void)setupPortraitChartView {
    self.portraitChartView.translatesAutoresizingMaskIntoConstraints = NO;
    self.portraitChartView.accessibilityIdentifier = @"portrait.chartView";  // UI テストで探すための名前
    [self.view addSubview:self.portraitChartView];
    [NSLayoutConstraint activateConstraints:@[
        // 左右は安全な領域に合わせる(カメラの穴やステータスバーが横にある画面で、チャートが隠れないように)
        [self.portraitChartView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:8],
        [self.portraitChartView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.portraitChartView.heightAnchor constraintEqualToConstant:260],
    ]];
}

// MARK: - 縦向きのチャートの足種(テスト用)

/// 足種の切り替えボタンを画面の上端(チャートの上)に置く
- (void)setupPeriodControl {
    for (NSUInteger index = 0; index < self.periodChoices.count; index++) {
        ChartPeriod period = (ChartPeriod)self.periodChoices[index].integerValue;
        [self.periodControl insertSegmentWithTitle:[self titleForPeriod:period] atIndex:index animated:NO];
    }
    NSUInteger index = [self.periodChoices indexOfObject:@(self.portraitPeriod)];
    if (index != NSNotFound) {
        self.periodControl.selectedSegmentIndex = index;
    }
    [self.periodControl addTarget:self action:@selector(periodControlChanged) forControlEvents:UIControlEventValueChanged];
    self.periodControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.periodControl.accessibilityIdentifier = @"portrait.periodControl";  // UI テストで探すための名前
    [self.view addSubview:self.periodControl];
    [NSLayoutConstraint activateConstraints:@[
        [self.periodControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [self.periodControl.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.periodControl.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.periodControl.heightAnchor constraintEqualToConstant:36],
        [self.portraitChartView.topAnchor constraintEqualToAnchor:self.periodControl.bottomAnchor constant:16],
    ]];
}

/// 足種の切り替えボタンが押されたら、縦向きのチャートをその足種のデータで描き直す
- (void)periodControlChanged {
    NSInteger index = self.periodControl.selectedSegmentIndex;
    if (index < 0) {
        return;
    }
    if (index >= (NSInteger)self.periodChoices.count) {
        return;
    }
    self.portraitPeriod = (ChartPeriod)self.periodChoices[index].integerValue;
    [self showPortraitChart];
}

/// 足種の切り替えボタンを、指数の種類で選べる足種だけ押せるようにする。
/// 表示中の足種が選べない場合(海外指数の1分足・日中足)は日足にする
- (void)updatePeriodControlForMarket:(IndexMarket)market {
    NSArray<NSNumber *> *periods = [self periodsForMarket:market];
    for (NSUInteger index = 0; index < self.periodChoices.count; index++) {
        [self.periodControl setEnabled:[periods containsObject:self.periodChoices[index]] forSegmentAtIndex:index];
    }
    if (![periods containsObject:@(self.portraitPeriod)]) {
        self.portraitPeriod = ChartPeriodDaily;
    }
    NSUInteger index = [self.periodChoices indexOfObject:@(self.portraitPeriod)];
    if (index != NSNotFound) {
        self.periodControl.selectedSegmentIndex = index;
    }
}

/// 縦向きのチャートを、表示中の足種・指数の種類のデータで描き直す
- (void)showPortraitChart {
    [self.portraitChartView setCandles:[SampleData candlesForPeriod:self.portraitPeriod] period:self.portraitPeriod
                                market:self.currentMarket];
}

// MARK: - 横画面にする

/// 横画面にするボタンを、チャートの下に置く
- (void)setupRotateButton {
    UIButtonConfiguration *configuration = self.rotateButton.configuration;
    configuration.title = @"横画面にする";
    configuration.image = [UIImage systemImageNamed:@"rectangle.landscape.rotate"];
    configuration.imagePadding = 6;
    self.rotateButton.configuration = configuration;
    [self.rotateButton addTarget:self action:@selector(rotateButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.rotateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.rotateButton.accessibilityIdentifier = @"portrait.rotateButton";  // UI テストで探すための名前
    [self.view addSubview:self.rotateButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.rotateButton.topAnchor constraintEqualToAnchor:self.portraitChartView.bottomAnchor constant:16],
        [self.rotateButton.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.rotateButton.heightAnchor constraintEqualToConstant:40],
    ]];
}

/// 横画面にするボタンが押されたら、横画面のチャートを全画面で表示する(横向きになる)
- (void)rotateButtonTapped {
    [self presentLandscapeChart];
}

// MARK: - 日本株/国内指数/海外指数

/// 切り替えボタンを左下に置く
- (void)setupMarketControl {
    // 最初に表示する種類のボタンを選んだ状態にする
    NSUInteger index = [self.marketChoices indexOfObject:@(self.initialMarket)];
    if (index != NSNotFound) {
        self.marketControl.selectedSegmentIndex = index;
    }
    [self.marketControl addTarget:self action:@selector(marketControlChanged) forControlEvents:UIControlEventValueChanged];
    self.marketControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.marketControl.accessibilityIdentifier = @"portrait.marketControl";  // UI テストで探すための名前
    [self.view addSubview:self.marketControl];
    [NSLayoutConstraint activateConstraints:@[
        [self.marketControl.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.marketControl.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        [self.marketControl.heightAnchor constraintEqualToConstant:36],
    ]];
}

/// 切り替えボタンが押されたら、選ばれた指数の種類で表示し直す
- (void)marketControlChanged {
    NSInteger index = self.marketControl.selectedSegmentIndex;
    if (index < 0) {
        return;
    }
    if (index >= (NSInteger)self.marketChoices.count) {
        return;
    }
    [self showPortraitChartForMarket:(IndexMarket)self.marketChoices[index].integerValue];
}

/// 縦向きのチャートを、指定した指数の種類で表示し直す(海外指数で選べない足種なら日足にする)。
///   ・国内指数: ローソク足 + 移動平均線 + 出来高
///   ・海外指数(R・D とも同じ): ローソク足 + 移動平均線(サブチャートなし)
/// 横画面のチャートは、開くときにこの種類で表示する(presentLandscapeChart)
/// (サンプルなので、海外指数でも同じダミーデータを使う)
- (void)showPortraitChartForMarket:(IndexMarket)market {
    self.currentMarket = market;
    [self updatePeriodControlForMarket:market];
    [self showPortraitChart];
}

// MARK: - 横画面のチャート

/// 横画面のチャートを作り、データと下の帯のボタンの処理を設定して、全画面で表示する。
/// 開くたびに作り直す(チャートの種類・指標・足種などは ChartStateStore が覚えているので、前回の状態で開く)。
/// (サンプルなので SampleData から読み込む。実際のアプリでは API から取得して setCandles:period: で渡す)
- (void)presentLandscapeChart {
    LandscapeChartViewController *landscapeViewController = [LandscapeChartViewController instantiate];

    // 指数の種類は、データを渡す前に設定する(描き方・選べる足種や指標が変わるため)。
    //   ・国内指数: テクニカル・チャートの種類はすべて選べる
    //   ・海外指数: テクニカルが 移動平均線・なし、チャートの種類が ローソク足・折線チャート だけ
    // market を設定すると、国内/海外ごとに前回選んでいた足種(初めてなら日足)が period に入るので、その足種のデータを渡す
    landscapeViewController.chartViewController.market = self.currentMarket;
    ChartPeriod initialPeriod = landscapeViewController.chartViewController.period;
    [landscapeViewController setCandles:[SampleData candlesForPeriod:initialPeriod] period:initialPeriod];
    [self updatePriceInfoOfLandscapeViewController:landscapeViewController];

    // ブロックはこの画面・横画面が持ち続けるので、中では weak で使う(循環参照を防ぐ)
    __weak typeof(self) weakSelf = self;
    __weak LandscapeChartViewController *weakLandscapeViewController = landscapeViewController;
    // 足種が選ばれたら、その足種のデータを渡す(足種のボタンの表示も切り替わる)
    landscapeViewController.onPeriodSelect = ^(ChartPeriod period) {
        [weakLandscapeViewController setCandles:[SampleData candlesForPeriod:period] period:period];
    };
    // 更新: 表示中の足種のデータを読み込み直し、現在値も更新する
    landscapeViewController.onReload = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        LandscapeChartViewController *strongLandscapeViewController = weakLandscapeViewController;
        if (strongLandscapeViewController == nil) {
            return;
        }
        ChartPeriod period = strongLandscapeViewController.chartViewController.period;
        [strongLandscapeViewController setCandles:[SampleData candlesForPeriod:period] period:period];
        [strongSelf updatePriceInfoOfLandscapeViewController:strongLandscapeViewController];
    };
    // 縦画面に戻す: 閉じると、この画面の向き(縦)に戻る
    landscapeViewController.onRotate = ^{
        [weakLandscapeViewController dismissViewControllerAnimated:YES completion:nil];
    };

    [self presentViewController:landscapeViewController animated:YES completion:nil];
}

/// 横画面の下の帯に、指数名・現在値・日時を表示する
/// (サンプルなので、当日の1分足の最後の足の終値・時刻を現在値として使う。どの足種を表示していても同じ値)
- (void)updatePriceInfoOfLandscapeViewController:(LandscapeChartViewController *)landscapeViewController {
    NSString *name = @"日経平均";
    switch (landscapeViewController.chartViewController.market) {
        case IndexMarketJapanStock:
            name = @"サンプル銘柄";
            break;
        case IndexMarketJapanIndex:
            break;
        case IndexMarketOverseasRealtime:
            name = @"NYダウ";
            break;
        case IndexMarketOverseasDaily:
            name = @"NYダウ(日次)";
            break;
    }
    [landscapeViewController updatePriceInfoWithName:name price:SampleData.latestPrice date:SampleData.latestDate];
}

// MARK: - Swift の enum のプロパティの代わり

/// 足種の切り替えボタンに表示する名称(ChartPeriod.title と同じ)
- (NSString *)titleForPeriod:(ChartPeriod)period {
    switch (period) {
        case ChartPeriodOneMinute:
            return @"1分足";
        case ChartPeriodIntraday:
            return @"日中足";
        case ChartPeriodDaily:
            return @"日 足";
        case ChartPeriodWeekly:
            return @"週 足";
        case ChartPeriodMonthly:
            return @"月 足";
    }
    return @"";
}

/// 指数の種類で選べる足種(IndexMarket.periods と同じ。ChartPeriod を NSNumber に包んだもの)
- (NSArray<NSNumber *> *)periodsForMarket:(IndexMarket)market {
    switch (market) {
        case IndexMarketJapanStock:
        case IndexMarketJapanIndex:
            return @[@(ChartPeriodOneMinute), @(ChartPeriodIntraday), @(ChartPeriodDaily), @(ChartPeriodWeekly), @(ChartPeriodMonthly)];
        case IndexMarketOverseasRealtime:
        case IndexMarketOverseasDaily:
            return @[@(ChartPeriodDaily), @(ChartPeriodWeekly), @(ChartPeriodMonthly)];
    }
    return @[];
}

@end

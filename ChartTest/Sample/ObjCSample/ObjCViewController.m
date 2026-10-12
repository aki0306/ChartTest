//
//  ObjCViewController.m
//  ChartTest
//
//  【Controller】ViewController.swift を Objective-C で書いたもの。縦向き用のチャートと横画面用のチャート画面を置き、
//  画面の向きに合わせて表示を切り替える。
//
//  ・縦向き: StockChartView(チャートだけ。最初は日足を表示する)
//  ・横画面: LandscapeChartViewController(LandscapeChartViewController.storyboard。StockChartViewController で指標メニュー付き表示)
//  この画面は「どちらを表示するか」と「データを渡す」ことだけを担当する。
//  縦画面の左下の切り替えボタン(marketControl)で、日本株/国内指数/海外指数(リアルタイム・日次)を切り替えて表示を確かめられる
//  (横画面では下の帯と重なるので隠す。縦画面で切り替えてから横にする)。
//  チャートの上には縦向きのチャートの足種を切り替えるボタン(periodControl)を、下には横画面にするボタン(rotateButton)を置く
//  (どちらも縦画面だけに表示する。テスト用)。
//  横画面の下の帯(足種・更新・縦画面に戻す)が押されたときの処理も、ここで設定している(setupLandscapeFooter)。
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
/// 横画面のチャート(LandscapeChartViewController.storyboard)
@property (nonatomic, strong) LandscapeChartViewController *landscapeViewController;

// MARK: - 銘柄・指数の種類の切り替え

/// 日本株/国内指数/海外指数を切り替えるボタン(左下。縦画面だけに表示する)
@property (nonatomic, strong) UISegmentedControl *marketControl;

/// 切り替えボタンの並び順と同じ、銘柄・指数の種類(IndexMarket を NSNumber に包んだもの)
@property (nonatomic, copy) NSArray<NSNumber *> *marketChoices;

/// 最初に表示する銘柄・指数の種類(国内指数)
@property (nonatomic, assign) IndexMarket initialMarket;

// MARK: - 縦向きのチャートの足種の切り替え(テスト用)

/// 縦向きのチャートの足種を切り替えるボタン(チャートの上。縦画面だけに表示する)
@property (nonatomic, strong) UISegmentedControl *periodControl;

/// 切り替えボタンの並び順と同じ足種(ChartPeriod を NSNumber に包んだもの)
@property (nonatomic, copy) NSArray<NSNumber *> *periodChoices;

/// 縦向きのチャートに表示している足種
@property (nonatomic, assign) ChartPeriod portraitPeriod;

/// 表示している銘柄・指数の種類
@property (nonatomic, assign) IndexMarket currentMarket;

// MARK: - 横画面にするボタン(テスト用)

/// 横画面にするボタン(チャートの下。縦画面だけに表示する)
@property (nonatomic, strong) UIButton *rotateButton;

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
    self.landscapeViewController = [LandscapeChartViewController instantiate];

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

    // データを渡す前に埋め込んでおく(チャートが正しいサイズで初期表示位置を計算できるように)
    [self setupPortraitChartView];
    [self embedChildViewController:self.landscapeViewController];
    [self applyLayoutForLandscape:self.view.bounds.size.width > self.view.bounds.size.height];

    // 横画面: 下の帯のボタンが押されたときの処理
    [self setupLandscapeFooter];

    // 縦向きのチャートの足種の切り替えボタンと、横画面にするボタン(テスト用)
    [self setupPeriodControl];
    [self setupRotateButton];

    // 日本株/国内指数/海外指数の切り替えボタン(最初は国内指数)
    [self setupMarketControl];
    [self showChartsForMarket:self.initialMarket];
}

- (void)viewIsAppearing:(BOOL)animated {
    [super viewIsAppearing:animated];
    // viewDidLoad の時点では storyboard のサイズのままなので、実際の画面サイズでもう一度判定する
    [self applyLayoutForLandscape:self.view.bounds.size.width > self.view.bounds.size.height];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    // 画面の縦横が変わるときに表示を切り替える(回転のアニメーションに合わせる)
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self applyLayoutForLandscape:size.width > size.height];
    } completion:nil];
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

/// 子 ViewController を画面いっぱいに埋め込む
- (void)embedChildViewController:(UIViewController *)child {
    [self addChildViewController:child];
    UIView *childView = child.view;
    childView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:childView];
    [NSLayoutConstraint activateConstraints:@[
        [childView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [childView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [childView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [childView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
    [child didMoveToParentViewController:self];
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

// MARK: - 横画面にする(テスト用)

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

/// 横画面にするボタンが押されたら、画面を横向きにする(横画面のチャートに切り替わる)
- (void)rotateButtonTapped {
    [self requestInterfaceOrientations:UIInterfaceOrientationMaskLandscapeRight];
}

/// 画面を指定した向きにするよう、シーンに頼む
- (void)requestInterfaceOrientations:(UIInterfaceOrientationMask)orientations {
    UIWindowSceneGeometryPreferencesIOS *preferences =
        [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:orientations];
    [self.view.window.windowScene requestGeometryUpdateWithPreferences:preferences errorHandler:nil];
}

// MARK: - 日本株/国内指数/海外指数

/// 切り替えボタンを左下に置く(チャート画面より手前)
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
    [self showChartsForMarket:(IndexMarket)self.marketChoices[index].integerValue];
}

/// 縦向き・横画面のチャートを、指定した指数の種類で表示し直す。
/// 指数の種類は、データを渡す前に設定する(描き方・選べる足種や指標が変わるため)
///   ・国内指数: 縦向きは ローソク足 + 移動平均線 + 出来高
///   ・海外指数(R・D とも同じ): 縦向きは ローソク足 + 移動平均線(サブチャートなし)。
///              横画面は テクニカルが 移動平均線・なし、チャートの種類が ローソク足・折線チャート だけ
/// (サンプルなので、海外指数でも同じダミーデータを使う)
- (void)showChartsForMarket:(IndexMarket)market {
    // 縦向き: 表示中の足種のデータを、指数の種類に合わせて描き直す(海外指数で選べない足種なら日足にする)
    self.currentMarket = market;
    [self updatePeriodControlForMarket:market];
    [self showPortraitChart];

    // 横画面: market を変えると、国内/海外ごとに前回選んでいた足種(初めてなら日足)が period に入るので、
    // その足種のデータを渡す。下の帯の指数名・現在値も変える
    self.landscapeViewController.chartViewController.market = market;
    ChartPeriod period = self.landscapeViewController.chartViewController.period;
    [self.landscapeViewController setCandles:[SampleData candlesForPeriod:period] period:period];
    [self updateLandscapePriceInfo];
}

// MARK: - 横画面の下の帯

/// 横画面の下の帯のボタンが押されたときの処理を設定する
/// (サンプルなので SampleData から読み込む。実際のアプリでは API から取得して setCandles:period: で渡す)
- (void)setupLandscapeFooter {
    __weak typeof(self) weakSelf = self;
    // 足種が選ばれたら、その足種のデータを渡す(足種のボタンの表示も切り替わる)
    self.landscapeViewController.onPeriodSelect = ^(ChartPeriod period) {
        [weakSelf.landscapeViewController setCandles:[SampleData candlesForPeriod:period] period:period];
    };
    // 更新: 表示中の足種のデータを読み込み直し、現在値も更新する
    self.landscapeViewController.onReload = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        ChartPeriod period = strongSelf.landscapeViewController.chartViewController.period;
        [strongSelf.landscapeViewController setCandles:[SampleData candlesForPeriod:period] period:period];
        [strongSelf updateLandscapePriceInfo];
    };
    // 縦画面に戻す
    self.landscapeViewController.onRotate = ^{
        [weakSelf requestInterfaceOrientations:UIInterfaceOrientationMaskPortrait];
    };
}

/// 横画面の下の帯に、指数名・現在値・日時を表示する
/// (サンプルなので、当日の1分足の最後の足の終値・時刻を現在値として使う。どの足種を表示していても同じ値)
- (void)updateLandscapePriceInfo {
    NSString *name = @"日経平均";
    switch (self.landscapeViewController.chartViewController.market) {
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
    [self.landscapeViewController updatePriceInfoWithName:name price:SampleData.latestPrice date:SampleData.latestDate];
}

// MARK: - Layout switching

/// 縦向き/横画面のチャートを切り替える
- (void)applyLayoutForLandscape:(BOOL)isLandscape {
    self.portraitChartView.hidden = isLandscape;
    self.landscapeViewController.view.hidden = !isLandscape;
    // 切り替えボタン・横画面にするボタンは縦画面だけ(横画面では下の帯の文字と重なるため)
    self.marketControl.hidden = isLandscape;
    self.periodControl.hidden = isLandscape;
    self.rotateButton.hidden = isLandscape;
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

//
//  ObjCChartViewController.m
//  ChartTest
//
//  Objective-C から共通チャート部品(StockChartViewController)を子として埋め込むサンプル。
//

#import "ObjCChartViewController.h"
// Swift のクラス(StockChartViewController / StockChartView / StockCandle)を Objective-C から使うための自動生成ヘッダ。
// ファイル名は「<プロダクトモジュール名>-Swift.h」
#import "ChartTest-Swift.h"

@interface ObjCChartViewController ()
/// 共通チャート部品(Controller)
@property (nonatomic, strong) StockChartViewController *chartViewController;
@end

@implementation ObjCChartViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    // チャート部品を子 ViewController として埋め込み、画面上部に配置する
    self.chartViewController = [[StockChartViewController alloc] init];
    [self addChildViewController:self.chartViewController];
    UIView *chart = self.chartViewController.view;
    chart.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:chart];
    [NSLayoutConstraint activateConstraints:@[
        [chart.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [chart.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [chart.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [chart.heightAnchor constraintEqualToConstant:360],
    ]];
    [self.chartViewController didMoveToParentViewController:self];

    // 見た目の設定(View)。各設定のたびに再描画されるため、データ設定の前に行う
    self.chartViewController.chartView.visibleCount = 55;       // 初期表示本数(0 以下で全件)
    self.chartViewController.chartView.priceHeightRatio = 2.0;  // メイン:サブ = 2:1

    // 指標のパラメータ・選択(Controller が保持する状態)
    self.chartViewController.shortMAPeriod = 5;   // 短期移動平均の期間
    self.chartViewController.longMAPeriod = 25;   // 長期移動平均の期間
    self.chartViewController.mainIndicator = MainChartIndicatorMovingAverage;  // メインチャートの指標(移動平均線)
    self.chartViewController.subIndicator = SubChartIndicatorVolume;           // サブチャートの指標(出来高)
    self.chartViewController.isTechnicalMenuEnabled = NO;  // 指標メニュー(テクニカルタブ)を使うなら YES

    // データを渡すと描画される
    [self.chartViewController setCandles:[self makeSampleCandles]];
}

/// 動作確認用のダミーデータ(平日のみ・90本)を生成する
- (NSArray<StockCandle *> *)makeSampleCandles {
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *endComponents = [[NSDateComponents alloc] init];
    endComponents.year = 2026;
    endComponents.month = 9;
    endComponents.day = 25;
    NSDate *date = [calendar dateFromComponents:endComponents];
    
    // 終了日から遡って平日の日付を集める(古い順に並べるため先頭に挿入する)
    NSMutableArray<NSDate *> *dates = [NSMutableArray array];
    while (dates.count < 90) {
        if (![calendar isDateInWeekend:date]) {
            [dates insertObject:date atIndex:0];
        }
        date = [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:date options:0];
    }

    // 66,000 付近を上下するランダムな四本値・出来高を作る
    NSMutableArray<StockCandle *> *candles = [NSMutableArray array];
    double prevClose = 66000;
    for (NSDate *d in dates) {
        double revert = (66000 - prevClose) * 0.08;
        double open = prevClose + revert + [self randomFrom:-400 to:400];
        double close = open + [self randomFrom:-1200 to:1200];
        double high = MAX(open, close) + [self randomFrom:0 to:500];
        double low = MIN(open, close) - [self randomFrom:0 to:500];
        double volume = [self randomFrom:1.6e9 to:3.2e9];

        StockCandle *candle = [[StockCandle alloc] initWithDate:d
                                                           open:open
                                                           high:high
                                                            low:low
                                                          close:close
                                                         volume:volume];
        [candles addObject:candle];
        prevClose = close;
    }
    return candles;
}

/// min〜max の一様乱数を返す
- (double)randomFrom:(double)min to:(double)max {
    return min + (max - min) * ((double)arc4random() / UINT32_MAX);
}

@end

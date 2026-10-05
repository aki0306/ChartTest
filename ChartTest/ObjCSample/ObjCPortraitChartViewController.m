//
//  ObjCPortraitChartViewController.m
//  ChartTest
//
//  Objective-C から縦画面のチャート(足種のタブ付き・PortraitChartViewController)を子として埋め込むサンプル。
//
//  ・足種のタブ(1分足・日中足・日足・週足・月足)が押されるたびに candleLoader のブロックが呼ばれ、
//    その足種のデータを返すと、足種に合った設定で描き直される
//  ・海外指数の場合は market を IndexMarketOverseasRealtime(リアルタイム)/ IndexMarketOverseasDaily(日次)にする(タブは日足・週足・月足になる)
//

#import "ObjCPortraitChartViewController.h"
// Swift のクラス(PortraitChartViewController / SampleData など)を Objective-C から使うための自動生成ヘッダ。
// ファイル名は「<プロダクトモジュール名>-Swift.h」
#import "XxxChartEnum.h"      // ChartTest-Swift.h が使う既存アプリの enum(StockChartView+Xxx.swift)。ChartTest-Swift.h より前に読み込む
#import "ChartTest-Swift.h"

@interface ObjCPortraitChartViewController ()
/// 縦画面のチャート(足種のタブ + チャート)
@property (nonatomic, strong) PortraitChartViewController *chartViewController;
@end

@implementation ObjCPortraitChartViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;

    // Portrait.storyboard から生成し、子 ViewController として画面いっぱいに埋め込む
    self.chartViewController = [PortraitChartViewController instantiate];
    [self addChildViewController:self.chartViewController];
    UIView *chart = self.chartViewController.view;
    chart.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:chart];
    [NSLayoutConstraint activateConstraints:@[
        [chart.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [chart.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [chart.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [chart.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
    [self.chartViewController didMoveToParentViewController:self];

    // 指数の種類(国内指数: 1分足〜月足の5種類 / 海外指数: 日足・週足・月足)
    self.chartViewController.market = IndexMarketDomestic;

    // 足種を指定してデータを読み込む処理(タブが押されるたびに呼ばれる)。
    // 実際のアプリでは API から取得したデータを返す
    self.chartViewController.candleLoader = ^NSArray<StockCandle *> *(ChartPeriod period) {
        return [SampleData candlesForPeriod:period];
    };

    // 選択中の足種(最初は日足)を表示する
    [self.chartViewController reloadChart];
}

@end

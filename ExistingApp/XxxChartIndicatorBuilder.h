//
//  XxxChartIndicatorBuilder.h
//
//  【既存アプリ側に入れるファイル】既存アプリの XxxChartDataUtil でテクニカル指標を計算し、
//  チャート(StockChartView)に渡す。チャートは指標を計算せず、受け取った値で描くだけになる。
//
//  ※ XxxChartDataUtil(SciChart・AFNetworking などに依存)が必要なため、このサンプルプロジェクト(ChartTest)ではビルドしない。
//    既存アプリのターゲットに追加して使う(README の「既存アプリの計算でチャートを描く」)
//
//  使い方:
//      // dataArrayFromResponse:… の結果をそのまま渡す(qCodeType・chartData・mainChart・subChart などは先に設定しておく)
//      self.chartView.qCodeType = qCodeType;
//      self.chartView.chartData = chartData;
//      NSMutableArray *dataArray = [XxxChartDataUtil dataArrayFromResponse:response chartData:chartData qCode:qCode CodeType:qCodeType];
//      [XxxChartIndicatorBuilder setDataArray:dataArray toChartView:self.chartView];
//

#import <Foundation/Foundation.h>

@class StockChartView;
@class StockCandle;
@class ChartIndicatorValues;

NS_ASSUME_NONNULL_BEGIN

@interface XxxChartIndicatorBuilder : NSObject

/// dataArrayFromResponse:… の結果から、ローソク足と指標の値(XxxChartDataUtil で計算)を作り、チャートに渡して描く。
/// チャートのプロパティ(qCodeType・chartData・chartCategory・mainChart・subChart)は先に設定しておく。
/// メインスレッド以外から呼ばれた場合は、メインスレッドで呼び直す
/// @param dataArray dataArrayFromResponse:… の結果(kTimestamp は文字列でも NSDate でもよい)
/// @param chartView 描画先
+ (void)setDataArray:(NSArray<NSDictionary *> *)dataArray toChartView:(StockChartView *)chartView;

/// 指標の値だけを計算する(チャートが実際に描く指標の分だけ。StockChartView.effectiveMainIndicator など)
/// @param dataArray kTimestamp を NSDate にした配列(dataArrayWithDateTimestamps: の結果)
/// @param candles dataArray から作ったローソク足(値はこの並びにそろえる)
/// @param chartView 描画先(描く指標・期間・足種を読む)
+ (ChartIndicatorValues *)indicatorValuesWithDataArray:(NSArray<NSDictionary *> *)dataArray
                                               candles:(NSArray<StockCandle *> *)candles
                                             chartView:(StockChartView *)chartView;

/// kTimestamp を NSDate にした配列を返す(XxxChartDataUtil の指標の計算は、kTimestamp が NSDate である必要があるため)。
/// 日付は XxxChartDataUtil の dateFormatter(yyyy/MM/dd HH:mm)で読む。すでに NSDate ならそのまま
+ (NSMutableArray<NSMutableDictionary *> *)dataArrayWithDateTimestamps:(NSArray<NSDictionary *> *)dataArray;

@end

NS_ASSUME_NONNULL_END

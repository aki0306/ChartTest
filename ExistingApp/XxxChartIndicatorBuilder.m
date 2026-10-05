//
//  XxxChartIndicatorBuilder.m
//
//  【既存アプリ側に入れるファイル】XxxChartDataUtil で計算した指標(SciChart のデータ)を、
//  チャートの値(ChartIndicatorValues)に変換する。
//
//  ■ 変換のしかた
//    XxxChartDataUtil の結果は「日付(X) と 値(Y)」の並びで、線ごとに始まる位置が違う(移動平均は期間分あとから など)。
//    チャートは「何本目の足か」で描くので、日付でローソク足に合わせ直し、ローソク足と同じ長さの配列にする
//    (値がない足は NaN)。
//
//      ローソク足 :  5/24  5/27  5/28  …  6/20  6/21  …
//      RSI(日付)  :                          6/20  6/21  …   ← 期間分あとから
//      チャートの値:  NaN   NaN   NaN  …   52.1  48.3  …
//
//    一目均衡表の先行スパンだけは、データの右端より先の日付(未来)の値を、後ろに続けて入れる。
//
//  ※ 「既存アプリのモジュール名-Swift.h」の import を、既存アプリの名前に書き換えること
//

#import "XxxChartIndicatorBuilder.h"
#import "XxxChartDataUtil.h"
#import "XxxChartEnum.h"      // 「-Swift.h」より前に読み込む(-Swift.h の中で Xxx の enum を使っているため)
#import "MyApp-Swift.h"       // ← 既存アプリのモジュール名-Swift.h に書き換える

#pragma mark - SciChart のデータ → チャートの値

/// 値が NaN の配列(値なし)
static NSMutableArray<NSNumber *> *XxxNaNArray(NSUInteger count) {
    NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        [values addObject:@(NAN)];
    }
    return values;
}

/// SciChart の線を、ローソク足と同じ並び・長さの配列にする(ローソク足にない日付の値は捨てる)
static NSArray<NSNumber *> *XxxAlignedValues(SCIXyDataSeries *series,
                                             NSDictionary<NSDate *, NSNumber *> *indexByDate,
                                             NSUInteger count) {
    NSMutableArray<NSNumber *> *values = XxxNaNArray(count);
    for (NSInteger i = 0; i < series.count; i++) {
        NSDate *date = [[series.xValues valueAt:i] toDate];
        NSNumber *index = indexByDate[date];
        if (index == nil) {
            continue;
        }
        double value = [[series.yValues valueAt:i] toDouble];
        values[index.unsignedIntegerValue] = @(value);
    }
    return values;
}

/// 一目均衡表の先行スパン用。ローソク足の範囲の値に加えて、最後の足より先の日付の値を、後ろに順に続ける
static NSArray<NSNumber *> *XxxAlignedValuesWithFuture(SCIXyDataSeries *series,
                                                       NSDictionary<NSDate *, NSNumber *> *indexByDate,
                                                       NSUInteger count,
                                                       NSDate *lastDate) {
    NSMutableArray<NSNumber *> *values = XxxNaNArray(count);
    for (NSInteger i = 0; i < series.count; i++) {
        NSDate *date = [[series.xValues valueAt:i] toDate];
        double value = [[series.yValues valueAt:i] toDouble];
        NSNumber *index = indexByDate[date];
        if (index != nil) {
            values[index.unsignedIntegerValue] = @(value);
            continue;
        }
        // 最後の足より前で、ローソク足にない日付は捨てる
        if ([date compare:lastDate] != NSOrderedDescending) {
            continue;
        }
        // 最後の足より先(未来)の値は、後ろに続ける(日付の古い順に並んでいる)
        [values addObject:@(value)];
    }
    return values;
}

/// 新値足の SciChart のデータを、ローソク足(始値 = 線の始点、終値 = 線の終点)の配列にする(値のない仮の足は除く)
static NSArray<StockCandle *> *XxxNewPriceCandles(SCIOhlcDataSeries *series) {
    NSMutableArray<StockCandle *> *candles = [NSMutableArray array];
    for (NSInteger i = 0; i < series.count; i++) {
        double open = [[series.openValues valueAt:i] toDouble];
        double close = [[series.closeValues valueAt:i] toDouble];
        if (isnan(open)) {
            continue;
        }
        if (isnan(close)) {
            continue;
        }
        NSDate *date = [[series.xValues valueAt:i] toDate];
        StockCandle *candle = [[StockCandle alloc] initWithDate:date
                                                           open:open
                                                           high:MAX(open, close)
                                                            low:MIN(open, close)
                                                          close:close
                                                         volume:0];
        [candles addObject:candle];
    }
    return candles;
}

@implementation XxxChartIndicatorBuilder

#pragma mark - チャートに渡す

+ (void)setDataArray:(NSArray<NSDictionary *> *)dataArray toChartView:(StockChartView *)chartView {
    // チャートのプロパティを読むので、メインスレッドで行う
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setDataArray:dataArray toChartView:chartView];
        });
        return;
    }

    NSMutableArray<NSMutableDictionary *> *dateDataArray = [self dataArrayWithDateTimestamps:dataArray];
    // ローソク足はチャートの変換で作る(値がない件は直前の足で埋める。海外は終値だけを読む)
    NSArray<StockCandle *> *candles = [StockCandleResponseParser candlesFrom:dateDataArray market:chartView.market];
    ChartIndicatorValues *values = [self indicatorValuesWithDataArray:dateDataArray candles:candles chartView:chartView];
    [chartView setCandles:candles indicatorValues:values];
}

#pragma mark - 指標の計算

+ (ChartIndicatorValues *)indicatorValuesWithDataArray:(NSArray<NSDictionary *> *)dataArray
                                               candles:(NSArray<StockCandle *> *)candles
                                             chartView:(StockChartView *)chartView {
    ChartIndicatorValues *values = [[ChartIndicatorValues alloc] init];
    if (candles.count == 0) {
        return values;
    }

    // ローソク足の日付 → 何本目か
    NSMutableDictionary<NSDate *, NSNumber *> *indexByDate = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < candles.count; i++) {
        indexByDate[candles[i].date] = @(i);
    }

    // XxxChartDataUtil は NSMutableArray を受け取るので、コピーして渡す
    NSMutableArray *data = [dataArray mutableCopy];
    ChartIndicatorPeriods *periods = chartView.indicatorPeriods;

    switch (chartView.effectiveChartType) {
        case ChartTypeCandlestick:
        case ChartTypeLineChart:
            // メイン指標(折線チャートは海外指数のときだけ使う)・サブ指標
            [self setMainValuesTo:values
                        indicator:chartView.effectiveMainIndicator
                             data:data
                          periods:periods
                        chartData:chartView.chartData
                      indexByDate:indexByDate
                          candles:candles];
            [self setSubValuesTo:values
                       indicator:chartView.effectiveSubIndicator
                            data:data
                         periods:periods
                     indexByDate:indexByDate
                           count:candles.count];
            break;
        case ChartTypeNewPrice: {
            NSDictionary *result = [XxxChartDataUtil newPriceWithDataArray:data];
            values.newPriceCandles = XxxNewPriceCandles(result[XxxChartDataNewPriceDataSeries]);
            break;
        }
        case ChartTypeVwapLine:
        case ChartTypeVwapDots:
            // VWAP は API の値(kVWAP)。StockCandleResponseParser が StockCandle.vwap に入れている
            // (XxxChartDataUtil の vwapWithDataArray: と同じ値)
            break;
    }
    return values;
}

/// メインチャートの指標を計算して入れる
+ (void)setMainValuesTo:(ChartIndicatorValues *)values
              indicator:(MainChartIndicator)indicator
                   data:(NSMutableArray *)data
                periods:(ChartIndicatorPeriods *)periods
              chartData:(XxxChartData)chartData
            indexByDate:(NSDictionary<NSDate *, NSNumber *> *)indexByDate
                candles:(NSArray<StockCandle *> *)candles {
    NSUInteger count = candles.count;
    switch (indicator) {
        case MainChartIndicatorMovingAverage:
            values.movingAverageShort = XxxAlignedValues([XxxChartDataUtil movingAverageWithDataArray:data key:kEnd number:periods.shortMAPeriod],
                                                         indexByDate, count);
            values.movingAverageLong = XxxAlignedValues([XxxChartDataUtil movingAverageWithDataArray:data key:kEnd number:periods.longMAPeriod],
                                                        indexByDate, count);
            break;
        case MainChartIndicatorMultipleMovingAverage: {
            NSMutableArray<NSArray<NSNumber *> *> *lines = [NSMutableArray array];
            for (NSNumber *period in periods.multipleMAPeriods) {
                SCIXyDataSeries *series = [XxxChartDataUtil movingAverageWithDataArray:data key:kEnd number:period.integerValue];
                [lines addObject:XxxAlignedValues(series, indexByDate, count)];
            }
            values.multipleMovingAverages = lines;
            break;
        }
        case MainChartIndicatorBollingerBands: {
            // 既存の計算は σ の倍率ごとに1本ずつ(0 = 中心線、+n = 上限、−n = 下限)
            NSInteger period = periods.bollingerPeriod;
            values.bollingerMiddle = XxxAlignedValues([XxxChartDataUtil bollingerBandsWithDataArray:data number:period deviation:0],
                                                      indexByDate, count);
            NSMutableArray<NSArray<NSNumber *> *> *uppers = [NSMutableArray array];
            NSMutableArray<NSArray<NSNumber *> *> *lowers = [NSMutableArray array];
            for (NSNumber *sigma in periods.bollingerSigmas) {
                NSInteger deviation = sigma.integerValue;
                [uppers addObject:XxxAlignedValues([XxxChartDataUtil bollingerBandsWithDataArray:data number:period deviation:deviation],
                                                   indexByDate, count)];
                [lowers addObject:XxxAlignedValues([XxxChartDataUtil bollingerBandsWithDataArray:data number:period deviation:-deviation],
                                                   indexByDate, count)];
            }
            values.bollingerUppers = uppers;
            values.bollingerLowers = lowers;
            break;
        }
        case MainChartIndicatorIchimoku: {
            // 先行・遅行させる本数。チャートの設定(当日を1本目と数える)に合わせて「ichimokuShift − 1」本ずらす。
            // ※ 既存アプリで delay に渡している値と違う場合は、既存アプリに合わせて直す
            NSInteger delay = periods.ichimokuShift - 1;
            NSArray *rawDateArray = [XxxChartDataUtil allDateArrayWithDataArray:data];
            values.ichimokuTenkan = XxxAlignedValues([XxxChartDataUtil iChiMoKuBaseLineWithArray:data interVal:periods.ichimokuTenkanPeriod],
                                                     indexByDate, count);
            values.ichimokuKijun = XxxAlignedValues([XxxChartDataUtil iChiMoKuBaseLineWithArray:data interVal:periods.ichimokuKijunPeriod],
                                                    indexByDate, count);
            NSDictionary *beforeLines = [XxxChartDataUtil iChiMoKuBeforeLinesWithArray:data
                                                                          rawDateArray:rawDateArray
                                                                          baseInterval:periods.ichimokuKijunPeriod
                                                                     transformInterval:periods.ichimokuTenkanPeriod
                                                                         span2Interval:periods.ichimokuSpanBPeriod
                                                                              dateType:chartData
                                                                                 delay:delay];
            NSDate *lastDate = candles.lastObject.date;
            values.ichimokuSpanA = XxxAlignedValuesWithFuture(beforeLines[kIChiMokuBeforeLineSpan1], indexByDate, count, lastDate);
            values.ichimokuSpanB = XxxAlignedValuesWithFuture(beforeLines[kIChiMokuBeforeLineSpan2], indexByDate, count, lastDate);
            values.ichimokuChikou = XxxAlignedValues([XxxChartDataUtil iChiMoKuDelayLineWithArray:data
                                                                                      rawDateArray:rawDateArray
                                                                                          dateType:chartData
                                                                                             delay:delay],
                                                     indexByDate, count);
            break;
        }
        case MainChartIndicatorParabolic:
            // 既存アプリと同じく、移動平均線(短期・長期)も一緒に描く
            values.movingAverageShort = XxxAlignedValues([XxxChartDataUtil movingAverageWithDataArray:data key:kEnd number:periods.shortMAPeriod],
                                                         indexByDate, count);
            values.movingAverageLong = XxxAlignedValues([XxxChartDataUtil movingAverageWithDataArray:data key:kEnd number:periods.longMAPeriod],
                                                        indexByDate, count);
            values.parabolicSAR = XxxAlignedValues([XxxChartDataUtil parabolicSARDotWithArray:data], indexByDate, count);
            break;
        case MainChartIndicatorCandleOnly:
            break;
    }
}

/// サブチャートの指標を計算して入れる
+ (void)setSubValuesTo:(ChartIndicatorValues *)values
             indicator:(SubChartIndicator)indicator
                  data:(NSMutableArray *)data
               periods:(ChartIndicatorPeriods *)periods
           indexByDate:(NSDictionary<NSDate *, NSNumber *> *)indexByDate
                 count:(NSUInteger)count {
    switch (indicator) {
        case SubChartIndicatorVolume:
            // 出来高の棒はローソク足の出来高(kTurnover)。移動平均だけ計算する
            values.volumeAverage = XxxAlignedValues([XxxChartDataUtil movingAverageWithDataArray:data key:kTurnover number:periods.volumeMAPeriod],
                                                    indexByDate, count);
            break;
        case SubChartIndicatorMovingAverageDeviation:
            values.deviationShort = XxxAlignedValues([XxxChartDataUtil movingAverageBaisWithDataArray:data intervalDay:periods.deviationShortPeriod],
                                                     indexByDate, count);
            values.deviationLong = XxxAlignedValues([XxxChartDataUtil movingAverageBaisWithDataArray:data intervalDay:periods.deviationLongPeriod],
                                                    indexByDate, count);
            break;
        case SubChartIndicatorRsi:
            values.rsi = XxxAlignedValues([XxxChartDataUtil rsiWtihDataArray:data intervalDay:periods.rsiPeriod], indexByDate, count);
            break;
        case SubChartIndicatorPsychological:
            values.psychological = XxxAlignedValues([XxxChartDataUtil psychologicalWtihDataArray:data intervalDay:periods.psychologicalPeriod],
                                                    indexByDate, count);
            break;
        case SubChartIndicatorStochastics: {
            // 既存アプリと同じく、%D と Slow%D(%D の移動平均)
            SCIXyDataSeries *d = [XxxChartDataUtil stochasticsDPercentWithDataArray:data
                                                                          intervalK:periods.stochasticsKPeriod
                                                                           interval:periods.stochasticsDPeriod];
            SCIXyDataSeries *slowD = [XxxChartDataUtil stochasticsSlowDPercentWithPointDataSeries:d interval:periods.stochasticsDPeriod];
            values.stochasticsD = XxxAlignedValues(d, indexByDate, count);
            values.stochasticsSlowD = XxxAlignedValues(slowD, indexByDate, count);
            break;
        }
        case SubChartIndicatorMacd: {
            SCIXyDataSeries *macd = [XxxChartDataUtil macdLineWithDataArray:data
                                                              shortInterval:periods.macdShortPeriod
                                                               longInterval:periods.macdLongPeriod];
            SCIXyDataSeries *signal = [XxxChartDataUtil signalLineWithMACDPointDataSeries:macd interval:periods.macdSignalPeriod];
            values.macd = XxxAlignedValues(macd, indexByDate, count);
            values.macdSignal = XxxAlignedValues(signal, indexByDate, count);
            break;
        }
        case SubChartIndicatorDmi:
            // 既存アプリと同じく +DI・−DI だけ(ADX は描かない)
            values.dmiPlus = XxxAlignedValues([XxxChartDataUtil plusDIWtihDataArray:data interval:periods.dmiPeriod], indexByDate, count);
            values.dmiMinus = XxxAlignedValues([XxxChartDataUtil minusDIWtihDataArray:data interval:periods.dmiPeriod], indexByDate, count);
            break;
        case SubChartIndicatorHidden:
            break;
    }
}

#pragma mark - 日付の変換

+ (NSMutableArray<NSMutableDictionary *> *)dataArrayWithDateTimestamps:(NSArray<NSDictionary *> *)dataArray {
    NSMutableArray<NSMutableDictionary *> *result = [NSMutableArray arrayWithCapacity:dataArray.count];
    NSDateFormatter *formatter = [XxxChartDataUtil dateFormatter];
    for (NSDictionary *item in dataArray) {
        NSMutableDictionary *copied = [item mutableCopy];
        id timestamp = item[kTimestamp];
        if ([timestamp isKindOfClass:[NSString class]]) {
            NSDate *date = [formatter dateFromString:timestamp];
            if (date != nil) {
                copied[kTimestamp] = date;
            }
        }
        [result addObject:copied];
    }
    return result;
}

@end

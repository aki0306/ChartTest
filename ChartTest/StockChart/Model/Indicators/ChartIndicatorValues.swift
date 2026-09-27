//
//  ChartIndicatorValues.swift
//  ChartTest
//
//  【Model】チャートの外(Objective-C など)で計算したテクニカル指標の値と、
//  その計算に使う期間。
//
//  チャートは、ここに値が入っている指標は計算せずにその値で描く(ChartContentBuilder)。
//  値が入っていない指標は、今までどおりチャートが計算する(TechnicalIndicators)。
//  凡例・色・軸の範囲などの見た目は、どちらの場合も同じ(ChartContentBuilder が決める)。
//
//  ・値の配列は、渡すローソク足と同じ並び(日付の古い順・1本につき1つ)にする。値がない足は NaN
//    (配列がローソク足より短い場合、足りない分は値なしとして扱う)
//  ・一目均衡表の先行スパンだけは、データの右端より先の分を後ろに続けてよい(その分だけ右に伸ばして描く)
//  ・期間などは ChartIndicatorPeriods(StockChartView.indicatorPeriods)の値で計算する(凡例の「期間(14)」などと合わせるため)
//
//  使い方(Objective-C):
//      ChartIndicatorValues *values = [[ChartIndicatorValues alloc] init];
//      values.rsi = rsiValues;   // NSArray<NSNumber *> *(値がない足は @(NAN))
//      [chartView setCandles:candles indicatorValues:values];
//

import Foundation

/// チャートの外で計算したテクニカル指標の値。
/// Objective-C からも使えるよう NSObject を継承したクラスにしている
@objc final class ChartIndicatorValues: NSObject {

    // MARK: - メインチャート

    /// 移動平均線(短期)
    @objc var movingAverageShort: [NSNumber]?
    /// 移動平均線(長期)
    @objc var movingAverageLong: [NSNumber]?
    /// 多重移動平均線(ChartIndicatorPeriods.multipleMAPeriods の順)
    @objc var multipleMovingAverages: [[NSNumber]]?
    /// ボリンジャーバンドの中心線
    @objc var bollingerMiddle: [NSNumber]?
    /// ボリンジャーバンドの上限(ChartIndicatorPeriods.bollingerSigmas の順。例: +1σ, +2σ)
    @objc var bollingerUppers: [[NSNumber]]?
    /// ボリンジャーバンドの下限(ChartIndicatorPeriods.bollingerSigmas の順。例: −1σ, −2σ)
    @objc var bollingerLowers: [[NSNumber]]?
    /// 一目均衡表の転換線
    @objc var ichimokuTenkan: [NSNumber]?
    /// 一目均衡表の基準線
    @objc var ichimokuKijun: [NSNumber]?
    /// 一目均衡表の先行スパン1(データの右端より先の分を後ろに続けてよい)
    @objc var ichimokuSpanA: [NSNumber]?
    /// 一目均衡表の先行スパン2(データの右端より先の分を後ろに続けてよい)
    @objc var ichimokuSpanB: [NSNumber]?
    /// 一目均衡表の遅行スパン
    @objc var ichimokuChikou: [NSNumber]?
    /// パラボリック(SAR)。パラボリックと一緒に描く移動平均線は movingAverageShort / movingAverageLong に入れる
    @objc var parabolicSAR: [NSNumber]?
    /// 新値足の線(1本 = 始値が線の始点、終値が線の終点の足。古い順)
    @objc var newPriceCandles: [StockCandle]?

    // MARK: - サブチャート

    /// 出来高移動平均
    @objc var volumeAverage: [NSNumber]?
    /// 移動平均乖離率(短期)
    @objc var deviationShort: [NSNumber]?
    /// 移動平均乖離率(長期)
    @objc var deviationLong: [NSNumber]?
    /// RSI
    @objc var rsi: [NSNumber]?
    /// サイコロジカルライン
    @objc var psychological: [NSNumber]?
    /// ストキャスティクス %D
    @objc var stochasticsD: [NSNumber]?
    /// ストキャスティクス Slow%D(%D の移動平均)
    @objc var stochasticsSlowD: [NSNumber]?
    /// MACD
    @objc var macd: [NSNumber]?
    /// MACD のシグナル
    @objc var macdSignal: [NSNumber]?
    /// DMI の +DI
    @objc var dmiPlus: [NSNumber]?
    /// DMI の −DI
    @objc var dmiMinus: [NSNumber]?

    // MARK: - 値の変換

    /// NSNumber の配列を、チャートで使う値の配列(値なし = nil)にする
    /// - Parameters:
    ///   - values: 値の配列(NaN は値なし)
    ///   - count: 揃える長さ。短い場合は後ろを値なしで埋め、長い場合は切り詰める。nil ならそのままの長さ
    static func doubles(_ values: [NSNumber], count: Int?) -> [Double?] {
        var result: [Double?] = values.map { number in
            let value = number.doubleValue
            guard !value.isNaN else {
                return nil
            }
            return value
        }
        guard let count else {
            return result
        }
        if result.count < count {
            result += [Double?](repeating: nil, count: count - result.count)
        }
        return Array(result.prefix(count))
    }
}

/// チャートが指標の計算に使う期間など(IndicatorParameters を Objective-C から読めるようにしたもの)。
/// チャートの外で指標を計算するときは、この値で計算する(凡例の「期間(14)」などと合わせるため)。
/// 値は読み取り専用(期間を変えるときは ChartPeriod.indicatorParameters・IndicatorParameters を直す)
@objc final class ChartIndicatorPeriods: NSObject {

    /// 元のパラメータ
    let parameters: IndicatorParameters

    init(parameters: IndicatorParameters) {
        self.parameters = parameters
        super.init()
    }

    /// 移動平均線(短期)の期間
    @objc var shortMAPeriod: Int {
        return self.parameters.shortMAPeriod
    }

    /// 移動平均線(長期)の期間
    @objc var longMAPeriod: Int {
        return self.parameters.longMAPeriod
    }

    /// パラボリックに重ねる移動平均線(短期)の期間(移動平均線の設定とは別。5、週足は 13)
    @objc var parabolicShortMAPeriod: Int {
        return self.parameters.parabolicShortMAPeriod
    }

    /// パラボリックに重ねる移動平均線(長期)の期間(移動平均線の設定とは別。25、週足は 26)
    @objc var parabolicLongMAPeriod: Int {
        return self.parameters.parabolicLongMAPeriod
    }

    /// 出来高移動平均の期間
    @objc var volumeMAPeriod: Int {
        return self.parameters.volumeMAPeriod
    }

    /// 多重移動平均線の期間の一覧(短い順)
    @objc var multipleMAPeriods: [NSNumber] {
        return self.parameters.multipleMAPeriods.map { period in NSNumber(value: period) }
    }

    /// ボリンジャーバンドの期間
    @objc var bollingerPeriod: Int {
        return self.parameters.bollingerPeriod
    }

    /// ボリンジャーバンドの σ の倍率の一覧(例: 1, 2)
    @objc var bollingerSigmas: [NSNumber] {
        return self.parameters.bollingerSigmas.map { sigma in NSNumber(value: sigma) }
    }

    /// 一目均衡表の転換線の期間
    @objc var ichimokuTenkanPeriod: Int {
        return self.parameters.ichimokuTenkanPeriod
    }

    /// 一目均衡表の基準線の期間
    @objc var ichimokuKijunPeriod: Int {
        return self.parameters.ichimokuKijunPeriod
    }

    /// 一目均衡表の先行スパン2 の期間
    @objc var ichimokuSpanBPeriod: Int {
        return self.parameters.ichimokuSpanBPeriod
    }

    /// 一目均衡表の先行・遅行させる本数(当日を1本目と数える。実際のずらし幅は この値 − 1)
    @objc var ichimokuShift: Int {
        return self.parameters.ichimokuShift
    }

    /// 移動平均乖離率(短期)の期間
    @objc var deviationShortPeriod: Int {
        return self.parameters.deviationShortPeriod
    }

    /// 移動平均乖離率(長期)の期間
    @objc var deviationLongPeriod: Int {
        return self.parameters.deviationLongPeriod
    }

    /// RSI の期間
    @objc var rsiPeriod: Int {
        return self.parameters.rsiPeriod
    }

    /// サイコロジカルラインの期間
    @objc var psychologicalPeriod: Int {
        return self.parameters.psychologicalPeriod
    }

    /// ストキャスティクスの高安期間(%D の計算で、最高値・最安値を取る期間)
    @objc var stochasticsKPeriod: Int {
        return self.parameters.stochasticsKPeriod
    }

    /// ストキャスティクスの D期間(%D の合計を取る期間・Slow%D の移動平均の期間)
    @objc var stochasticsDPeriod: Int {
        return self.parameters.stochasticsDPeriod
    }

    /// MACD 短期EMA の期間
    @objc var macdShortPeriod: Int {
        return self.parameters.macdShortPeriod
    }

    /// MACD 長期EMA の期間
    @objc var macdLongPeriod: Int {
        return self.parameters.macdLongPeriod
    }

    /// MACD シグナルの期間
    @objc var macdSignalPeriod: Int {
        return self.parameters.macdSignalPeriod
    }

    /// DMI の期間
    @objc var dmiPeriod: Int {
        return self.parameters.dmiPeriod
    }
}

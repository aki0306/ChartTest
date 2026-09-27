//
//  IndicatorParameters.swift
//  ChartTest
//
//  【Model】テクニカル指標の計算パラメータ(期間・倍率など)。
//  見た目(色・フォント・レイアウト)は View 側の StockChartStyle が持つ。
//

import Foundation

struct IndicatorParameters {

    // MARK: 移動平均線 / 移動平均乖離率

    /// 短期移動平均の期間(本数)。移動平均乖離率の「短期」にも使う
    var shortMAPeriod = 5
    /// 長期移動平均の期間(本数)。移動平均乖離率の「長期」にも使う
    var longMAPeriod = 25
    /// 出来高移動平均の期間(本数)
    var volumeMAPeriod = 25

    // MARK: 多重移動平均線

    /// 多重移動平均線で表示する期間の一覧(本数)
    var multipleMAPeriods = [5, 25, 75]

    // MARK: ボリンジャーバンド

    /// ボリンジャーバンドの期間(本数)
    var bollingerPeriod = 20
    /// ボリンジャーバンドで表示する σ の倍率の一覧(例: [1, 2] なら ±1σ と ±2σ)
    var bollingerSigmas: [Double] = [1, 2]

    // MARK: 一目均衡表

    /// 転換線の期間(本数)
    var ichimokuTenkanPeriod = 9
    /// 基準線の期間(本数)
    var ichimokuKijunPeriod = 26
    /// 先行スパン2 の期間(本数)
    var ichimokuSpanBPeriod = 52
    /// 先行スパンを先に、遅行スパンを前にずらす本数(当日を1本目と数える)
    var ichimokuShift = 26

    // MARK: パラボリック

    /// 加速因子(AF)の初期値・増分
    var parabolicStep = 0.02
    /// 加速因子(AF)の上限
    var parabolicMaximum = 0.2

    // MARK: オシレーター

    /// RSI の期間(本数)
    var rsiPeriod = 14
    /// サイコロジカルラインの期間(本数)
    var psychologicalPeriod = 12
    /// ストキャスティクス %K の期間(本数)
    var stochasticsKPeriod = 9
    /// ストキャスティクス %D の期間(本数)
    var stochasticsDPeriod = 3
    /// MACD 短期EMA の期間(本数)
    var macdShortPeriod = 12
    /// MACD 長期EMA の期間(本数)
    var macdLongPeriod = 26
    /// MACD シグナルの期間(本数)
    var macdSignalPeriod = 9
    /// DMI の期間(本数)
    var dmiPeriod = 14
}

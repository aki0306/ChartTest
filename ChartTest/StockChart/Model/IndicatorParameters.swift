//
//  IndicatorParameters.swift
//  ChartTest
//
//  【Model】テクニカル指標の計算パラメータ(期間・倍率など)。
//  見た目(色・フォント・レイアウト)は View 側の StockChartStyle が持つ。
//

import Foundation

struct IndicatorParameters {

    // MARK: 移動平均線

    /// 短期移動平均の期間(本数)
    var shortMAPeriod = 5
    /// 長期移動平均の期間(本数)
    var longMAPeriod = 25
    /// 出来高移動平均の期間(本数)
    var volumeMAPeriod = 25
    /// 出来高の凡例に表示する名前(週足・月足では「出来高(平均)」にする。ChartPeriod を参照)
    var volumeLegendLabel = "出来高"

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

    /// 移動平均乖離率(短期)の移動平均の期間(本数)
    var deviationShortPeriod = 5
    /// 移動平均乖離率(長期)の移動平均の期間(本数)
    var deviationLongPeriod = 25
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

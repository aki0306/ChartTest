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

    /// 多重移動平均線の一番短い期間(本数)
    var multipleMAShortestPeriod = 5
    /// 多重移動平均線の一番長い期間(本数)
    var multipleMALongestPeriod = 75
    /// 多重移動平均線の本数(一番短い期間〜一番長い期間を、同じ間隔で分けて引く)
    var multipleMACount = 3

    /// 多重移動平均線で表示する期間の一覧(本数)。
    /// 例: 最短 5・最長 75・本数 15 なら 5, 10, 15, …, 75(5 刻み)。本数 3 なら 5, 40, 75
    var multipleMAPeriods: [Int] {
        let shortest = min(self.multipleMAShortestPeriod, self.multipleMALongestPeriod)
        let longest = max(self.multipleMAShortestPeriod, self.multipleMALongestPeriod)
        // 1本だけの場合は、最短の1本だけ
        guard self.multipleMACount > 1 else { return [shortest] }
        // 最短と最長が同じ場合も、最短の1本だけ
        guard shortest < longest else { return [shortest] }

        // 隣の線との期間の差(例: 5〜75 を3本なら (75 - 5) ÷ 2 = 35 → 5, 40, 75)
        let interval = Double(longest - shortest) / Double(self.multipleMACount - 1)
        var periods: [Int] = []
        for lineNumber in 0..<self.multipleMACount {
            let period = Int((Double(shortest) + interval * Double(lineNumber)).rounded())
            // 間隔が1本未満で同じ期間が続く場合は、重ねて引かない
            if periods.last != period {
                periods.append(period)
            }
        }
        return periods
    }

    // MARK: ボリンジャーバンド

    /// ボリンジャーバンドの期間(本数)
    var bollingerPeriod = 20
    /// ボリンジャーバンドで表示する σ の本数(例: 2 なら ±1σ と ±2σ、3 なら ±1σ〜±3σ)
    var bollingerSigmaCount = 2

    /// ボリンジャーバンドで表示する σ の倍率の一覧(例: [1, 2] なら ±1σ と ±2σ)
    var bollingerSigmas: [Double] {
        let count = max(self.bollingerSigmaCount, 1)
        return (1...count).map { sigma in Double(sigma) }
    }

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
    /// 移動平均乖離率の底値ライン(%)。この値に基準線を引く
    var deviationLowerLine = -10
    /// 移動平均乖離率の高値ライン(%)。この値に基準線を引く
    var deviationUpperLine = 10
    /// RSI の期間(本数)
    var rsiPeriod = 14
    /// RSI の底値ライン(%。売られすぎの目安)
    var rsiLowerLine = 30
    /// RSI の高値ライン(%。買われすぎの目安)
    var rsiUpperLine = 70
    /// サイコロジカルラインの期間(本数)
    var psychologicalPeriod = 12
    /// サイコロジカルラインの底値ライン(%)
    var psychologicalLowerLine = 25
    /// サイコロジカルラインの高値ライン(%)
    var psychologicalUpperLine = 75
    /// ストキャスティクス %K の期間(本数)
    var stochasticsKPeriod = 9
    /// ストキャスティクス %D の期間(本数)
    var stochasticsDPeriod = 3
    /// ストキャスティクスの底値ライン(%)
    var stochasticsLowerLine = 20
    /// ストキャスティクスの高値ライン(%)
    var stochasticsUpperLine = 80
    /// MACD 短期EMA の期間(本数)
    var macdShortPeriod = 12
    /// MACD 長期EMA の期間(本数)
    var macdLongPeriod = 26
    /// MACD シグナルの期間(本数)
    var macdSignalPeriod = 9
    /// DMI の期間(本数)
    var dmiPeriod = 14
}

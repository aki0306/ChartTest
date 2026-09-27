//
//  IndicatorParameters.swift
//  ChartTest
//
//  【Model】テクニカル指標の計算パラメータ(期間・倍率など)。
//  見た目(色・フォント・レイアウト)は View 側の StockChartStyle が持つ。
//
//  初期値は日足の値。週足・月足で違う値は ChartPeriod.indicatorParameters で上書きする。
//  (plist の1分足・日中足は空欄なので、日足と同じ値を使う)
//

import Foundation

struct IndicatorParameters {

    // MARK: 移動平均線

    /// 短期移動平均の期間(本数)
    var shortMAPeriod = 5
    /// 長期移動平均の期間(本数)
    var longMAPeriod = 25
    /// 出来高移動平均の期間(本数)
    var volumeMAPeriod = 5
    /// 出来高の凡例に表示する名前(週足・月足では「出来高(平均)」にする。ChartPeriod を参照)
    var volumeLegendLabel = "出来高"
    /// 期間の単位(凡例の「5日移動平均」などに使う。1分足・日中足は「分」、週足は「週」、月足は「月」。ChartPeriod を参照)
    var periodUnit = "日"

    // MARK: 多重移動平均線

    /// 多重移動平均線の一番短い期間(本数)
    var multipleMAShortestPeriod = 5
    /// 多重移動平均線の一番長い期間(本数)
    var multipleMALongestPeriod = 75
    /// 多重移動平均線の本数(一番短い期間〜一番長い期間を、同じ間隔で分けて引く)
    var multipleMACount = 15

    /// 多重移動平均線で表示する期間の一覧(本数)。
    ///
    ///   間隔 = (最長 − 最短) ÷ (本数 − 1)(小数点以下は切り捨て)
    ///   最短から間隔ずつ、「最長 − 間隔」以下の期間を並べ、最後に最長を足す
    ///
    ///   例) 最短 5・最長 75・本数 15 → 間隔 5 → 5, 10, 15, …, 70, 75(15本)
    ///       最短 13・最長 52・本数 15 → 間隔 2 → 13, 15, 17, …, 49, 52(20本。切り捨てのため本数より多くなる)
    ///       間隔が 0 になる場合(最短と最長が近い)は、最長の1本だけ
    var multipleMAPeriods: [Int] {
        let shortest = min(self.multipleMAShortestPeriod, self.multipleMALongestPeriod)
        let longest = max(self.multipleMAShortestPeriod, self.multipleMALongestPeriod)
        // 本数が1本以下の場合は間隔を決められないので、最長の1本だけ
        guard self.multipleMACount > 1 else {
            return [longest]
        }

        var periods: [Int] = []
        let step = (longest - shortest) / (self.multipleMACount - 1)
        if step > 0 {
            for period in stride(from: shortest, through: longest - step, by: step) {
                periods.append(period)
            }
        }
        periods.append(longest)
        return periods
    }

    // MARK: ボリンジャーバンド

    /// ボリンジャーバンドの期間(本数)
    var bollingerPeriod = 5
    /// ボリンジャーバンドで表示する σ の本数(例: 2 なら ±1σ と ±2σ、3 なら ±1σ〜±3σ)
    var bollingerSigmaCount = 3

    /// ボリンジャーバンドで表示する σ の倍率の一覧(例: [1, 2] なら ±1σ と ±2σ)
    var bollingerSigmas: [Double] {
        let count = max(self.bollingerSigmaCount, 1)
        return (1...count).map { sigma in Double(sigma) }
    }

    // MARK: 一目均衡表

    /// 転換線の期間(本数)
    var ichimokuTenkanPeriod = 3
    /// 基準線の期間(本数)
    var ichimokuKijunPeriod = 26
    /// 先行スパンを先に、遅行スパンを前にずらす本数(当日を1本目と数える。設定画面の「スパン期間」)
    var ichimokuShift = 26
    /// 先行スパン2 の期間(本数)。スパン期間の2倍(例: 26 → 52)
    var ichimokuSpanBPeriod: Int {
        return self.ichimokuShift * 2
    }

    // MARK: パラボリック

    /// 加速因子(AF)の初期値・増分
    var parabolicStep = 0.02
    /// 加速因子(AF)の上限
    var parabolicMaximum = 0.2
    /// パラボリックに重ねる移動平均線(短期)の期間。移動平均線の設定とは別に固定(週足は 13。ChartPeriod)
    var parabolicShortMAPeriod = 5
    /// パラボリックに重ねる移動平均線(長期)の期間。固定(週足は 26。ChartPeriod)
    var parabolicLongMAPeriod = 25

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
    var rsiLowerLine = 20
    /// RSI の高値ライン(%。買われすぎの目安)
    var rsiUpperLine = 80
    /// サイコロジカルラインの期間(本数)
    var psychologicalPeriod = 12
    /// サイコロジカルラインの底値ライン(%)
    var psychologicalLowerLine = 25
    /// サイコロジカルラインの高値ライン(%)
    var psychologicalUpperLine = 75
    /// ストキャスティクスの高安期間(%D の計算で最高値・最安値を取る期間。設定画面の「高安期間」)
    var stochasticsKPeriod = 14
    /// ストキャスティクス %D の期間(本数。設定画面の「D期間」)
    var stochasticsDPeriod = 3
    /// ストキャスティクスの底値ライン(%)
    var stochasticsLowerLine = 30
    /// ストキャスティクスの高値ライン(%)
    var stochasticsUpperLine = 70
    /// MACD 短期EMA の期間(本数)
    var macdShortPeriod = 5
    /// MACD 長期EMA の期間(本数)
    var macdLongPeriod = 25
    /// MACD シグナルの期間(本数)
    var macdSignalPeriod = 9
    /// DMI の期間(本数)。14 で固定(設定画面では変えられない)
    let dmiPeriod = 14
}

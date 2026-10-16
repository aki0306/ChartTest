//
//  Volume.swift
//  ChartTest
//
//  【Model】テクニカル指標「出来高」の、計算と描く内容。
//
//  サブチャートに、出来高の棒と出来高移動平均線を描く。
//    凡例:「出来高 出来高移動平均」
//  計算は TechnicalIndicators.sma(単純移動平均。TechnicalIndicators.swift)を使う
//
//  ・計算(TechnicalIndicators の extension): 値を計算する。描画や色の情報は持たない
//  ・描く内容(ChartContentBuilder の extension): 計算結果を、どの名前(凡例)・どの色の役割で描くかを決める
//    チャートの外で計算した値(ChartIndicatorValues)があれば、計算せずにその値を使う
//

import Foundation

// MARK: - 描く内容

extension ChartContentBuilder {

    /// 出来高: 出来高の棒 + 出来高移動平均線
    ///   凡例:「出来高 出来高移動平均」
    func volumeContent() -> SubChartContent {
        let volumes = self.candles.map { candle in candle.volume }
        var barValues: [Double?] = volumes.map { volume in volume }
        var averageValues = self.precomputedValues(\.volumeAverage)
            ?? TechnicalIndicators.sma(volumes, period: self.parameters.volumeMAPeriod)

        // 出来高がすべて 0 のデータ(指数の1分足・日中足など、出来高が配信されないもの)は、
        // 棒も移動平均線も描かない(凡例だけ表示する)
        let hasVolume = volumes.contains { volume in volume > 0 }
        if !hasVolume {
            barValues = volumes.map { _ in nil }
            averageValues = volumes.map { _ in nil }
        }

        let averageLine = ChartSeries(label: "出来高移動平均", values: averageValues, colorRole: .volumeAverage)
        let bars = ChartBars(label: self.parameters.volumeLegendLabel, labelColorRole: .volume,
                             values: barValues, colorRoles: volumes.map { _ in .volume })
        return SubChartContent(series: [averageLine], bars: bars, includesZero: true)
    }
}

//
//  MovingAverage.swift
//  ChartTest
//
//  【Model】テクニカル指標「移動平均線」の、計算と描く内容。
//
//  メインチャートに、短期(黄緑)・長期(オレンジ)の2本の移動平均線を引く。
//    凡例:「移動平均 短期移動平均(5) 長期移動平均(25)」
//  計算は TechnicalIndicators.sma(単純移動平均。TechnicalIndicators.swift)を使う
//
//  ・計算(TechnicalIndicators の extension): 値を計算する。描画や色の情報は持たない
//  ・描く内容(ChartContentBuilder の extension): 計算結果を、どの名前(凡例)・どの色の役割で描くかを決める
//    チャートの外で計算した値(ChartIndicatorValues)があれば、計算せずにその値を使う
//

import Foundation

// MARK: - 描く内容

extension ChartContentBuilder {

    /// 移動平均線: 短期(黄緑)・長期(オレンジ)の2本
    ///   凡例:「移動平均 短期移動平均(5) 長期移動平均(25)」
    func movingAverageContent() -> MainChartContent {
        return MainChartContent(legendTitle: "移動平均", series: self.movingAverageSeries())
    }

    /// 移動平均線(短期・長期)の2本の線
    private func movingAverageSeries() -> [ChartSeries] {
        let shortPeriod = self.parameters.shortMAPeriod
        let longPeriod = self.parameters.longMAPeriod
        // チャートの外で計算した値があればそれを使い、なければ計算する
        let shortValues = self.precomputedValues(\.movingAverageShort)
            ?? TechnicalIndicators.sma(self.closes, period: shortPeriod)
        let longValues = self.precomputedValues(\.movingAverageLong)
            ?? TechnicalIndicators.sma(self.closes, period: longPeriod)
        let shortLine = ChartSeries(label: "短期移動平均(\(shortPeriod))", values: shortValues, colorRole: .line(0))
        let longLine = ChartSeries(label: "長期移動平均(\(longPeriod))", values: longValues, colorRole: .line(1))
        return [shortLine, longLine]
    }
}

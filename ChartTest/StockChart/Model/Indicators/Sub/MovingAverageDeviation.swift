//
//  MovingAverageDeviation.swift
//  ChartTest
//
//  【Model】テクニカル指標「移動平均乖離率」の、計算と描く内容。
//
//  サブチャートに、短期(黄緑)・長期(オレンジ)の移動平均からの乖離率(%)を描く。
//    凡例:「乖離率 短期移動平均(5) 長期移動平均(25)」
//
//  ・計算(TechnicalIndicators の extension): 値を計算する。描画や色の情報は持たない
//  ・描く内容(ChartContentBuilder の extension): 計算結果を、どの名前(凡例)・どの色の役割で描くかを決める
//    チャートの外で計算した値(ChartIndicatorValues)があれば、計算せずにその値を使う
//

import Foundation

// MARK: - 計算

extension TechnicalIndicators {

    /// 移動平均乖離率(%) = (終値 − 移動平均) ÷ 移動平均 × 100
    static func movingAverageDeviation(closes: [Double], period: Int) -> [Double?] {
        let averages = self.sma(closes, period: period)
        return zip(closes, averages).map { close, average in
            guard let average else {
                return nil
            }
            // 0 で割れないので値なし
            guard average != 0 else {
                return nil
            }
            return (close - average) / average * 100
        }
    }
}

// MARK: - 描く内容

extension ChartContentBuilder {

    /// 移動平均乖離率: 短期(黄緑)・長期(オレンジ)の移動平均からの乖離率(%)。底値・高値ライン(既定 -10% / 10%)に基準線を引く
    ///   凡例:「乖離率 短期移動平均(5) 長期移動平均(25)」
    func movingAverageDeviationContent() -> SubChartContent {
        let shortPeriod = self.parameters.deviationShortPeriod
        let longPeriod = self.parameters.deviationLongPeriod
        // チャートの外で計算した値があればそれを使い、なければ計算する
        let shortValues = self.precomputedValues(\.deviationShort)
            ?? TechnicalIndicators.movingAverageDeviation(closes: self.closes, period: shortPeriod)
        let longValues = self.precomputedValues(\.deviationLong)
            ?? TechnicalIndicators.movingAverageDeviation(closes: self.closes, period: longPeriod)
        let shortLine = ChartSeries(label: "短期移動平均(\(shortPeriod))", values: shortValues, colorRole: .line(0))
        let longLine = ChartSeries(label: "長期移動平均(\(longPeriod))", values: longValues, colorRole: .line(1))
        let referenceLines = [Double(self.parameters.deviationLowerLine), Double(self.parameters.deviationUpperLine)]
        return SubChartContent(legendTitle: "乖離率", series: [shortLine, longLine],
                               referenceLines: referenceLines,
                               includesZero: true, fractionDigits: 1, suffix: "%")
    }
}

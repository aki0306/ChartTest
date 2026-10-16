//
//  MACD.swift
//  ChartTest
//
//  【Model】テクニカル指標「MACD」の、計算と描く内容。
//
//  サブチャートに、MACD(オレンジ)とシグナル(黄緑)の線を描く。
//    凡例:「ＭＡＣＤ ＭＡＣＤ(5,25) シグナル(9)」
//
//  ・計算(TechnicalIndicators の extension): 値を計算する。描画や色の情報は持たない
//  ・描く内容(ChartContentBuilder の extension): 計算結果を、どの名前(凡例)・どの色の役割で描くかを決める
//    チャートの外で計算した値(ChartIndicatorValues)があれば、計算せずにその値を使う
//

import Foundation

// MARK: - 計算

extension TechnicalIndicators {

    /// MACD。
    ///   MACD = 短期EMA − 長期EMA、シグナル = MACD の EMA
    static func macd(closes: [Double], shortPeriod: Int, longPeriod: Int, signalPeriod: Int)
        -> (macd: [Double?], signal: [Double?]) {

        // ema は nil を含む配列を受け取るので、[Double] を [Double?] に変換して渡す
        let optionalCloses: [Double?] = closes.map { close in close }
        let shortEMA = self.ema(optionalCloses, period: shortPeriod)
        let longEMA = self.ema(optionalCloses, period: longPeriod)

        // MACD = 短期EMA − 長期EMA(どちらかが計算できていない位置は nil)
        var macd = [Double?](repeating: nil, count: closes.count)
        for i in closes.indices {
            guard let shortValue = shortEMA[i] else {
                continue
            }
            guard let longValue = longEMA[i] else {
                continue
            }
            macd[i] = shortValue - longValue
        }

        // シグナル = MACD の EMA
        let signal = self.ema(macd, period: signalPeriod)
        return (macd, signal)
    }
}

// MARK: - 描く内容

extension ChartContentBuilder {

    /// MACD: MACD(オレンジ)・シグナル(黄緑)の線(ヒストグラム・0 の基準線は描かない)
    ///   凡例:「ＭＡＣＤ ＭＡＣＤ(5,25) シグナル(9)」
    func macdContent() -> SubChartContent {
        let result = TechnicalIndicators.macd(
            closes: self.closes, shortPeriod: self.parameters.macdShortPeriod,
            longPeriod: self.parameters.macdLongPeriod, signalPeriod: self.parameters.macdSignalPeriod)
        let macdValues = self.precomputedValues(\.macd) ?? result.macd
        let signalValues = self.precomputedValues(\.macdSignal) ?? result.signal

        let macdLine = ChartSeries(label: "ＭＡＣＤ(\(self.parameters.macdShortPeriod),\(self.parameters.macdLongPeriod))",
                                   values: macdValues, colorRole: .line(1))
        let signalLine = ChartSeries(label: "シグナル(\(self.parameters.macdSignalPeriod))",
                                     values: signalValues, colorRole: .line(0))
        return SubChartContent(legendTitle: "ＭＡＣＤ", series: [macdLine, signalLine], includesZero: true, fractionDigits: 2)
    }
}

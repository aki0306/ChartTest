//
//  DMI.swift
//  ChartTest
//
//  【Model】テクニカル指標「DMI」の、計算と描く内容。
//
//  サブチャートに、+DI(黄緑)と −DI(オレンジ)の線を描く。
//    凡例:「ＤＭＩ DI -DI」
//
//  ・計算(TechnicalIndicators の extension): 値を計算する。描画や色の情報は持たない
//  ・描く内容(ChartContentBuilder の extension): 計算結果を、どの名前(凡例)・どの色の役割で描くかを決める
//    チャートの外で計算した値(ChartIndicatorValues)があれば、計算せずにその値を使う
//

import Foundation

// MARK: - 計算

extension TechnicalIndicators {

    /// DMI。直近 period 本の単純合計で計算する。
    ///   +DM = 当日高値 − 前日高値(マイナス、または −DM より小さい場合は 0)
    ///   −DM = 前日安値 − 当日安値(マイナス、または +DM より大きい場合は 0)
    ///         ※ +DM と −DM が同じ値のときは、どちらも残す
    ///   TR  = max(高値 − 安値, 高値 − 前日終値, 前日終値 − 安値)
    ///   +DI = 直近 period 本の +DM の合計 ÷ 直近 period 本の TR の合計 × 100(−DI も同様。TR の合計が 0 なら 0)
    /// 前日との差を取るので、period + 1 本目から値が出る
    static func dmi(highs: [Double], lows: [Double], closes: [Double], period: Int)
        -> (plusDI: [Double?], minusDI: [Double?]) {

        let count = closes.count
        var plusDI = [Double?](repeating: nil, count: count)
        var minusDI = [Double?](repeating: nil, count: count)
        guard period > 0 else {
            return (plusDI, minusDI)
        }
        guard count > period else {
            return (plusDI, minusDI)
        }

        // 各足の +DM / −DM / TR(1本目は前日がないので 0)
        var plusDMs = [Double](repeating: 0, count: count)
        var minusDMs = [Double](repeating: 0, count: count)
        var trueRanges = [Double](repeating: 0, count: count)
        for i in 1..<count {
            let rawPlusDM = highs[i] - highs[i - 1]
            let rawMinusDM = lows[i - 1] - lows[i]

            var plusDM = rawPlusDM
            if rawPlusDM < 0 {
                plusDM = 0
            } else if rawPlusDM < rawMinusDM {
                plusDM = 0
            }
            var minusDM = rawMinusDM
            if rawMinusDM < 0 {
                minusDM = 0
            } else if rawPlusDM > rawMinusDM {
                minusDM = 0
            }

            plusDMs[i] = plusDM
            minusDMs[i] = minusDM
            trueRanges[i] = max(highs[i] - lows[i], highs[i] - closes[i - 1], closes[i - 1] - lows[i])
        }

        for i in period..<count {
            var sumPlusDM = 0.0
            var sumMinusDM = 0.0
            var sumTrueRange = 0.0
            for j in (i - period + 1)...i {
                sumPlusDM += plusDMs[j]
                sumMinusDM += minusDMs[j]
                sumTrueRange += trueRanges[j]
            }
            if sumTrueRange == 0 {
                plusDI[i] = 0
                minusDI[i] = 0
                continue
            }
            plusDI[i] = sumPlusDM / sumTrueRange * 100
            minusDI[i] = sumMinusDM / sumTrueRange * 100
        }
        return (plusDI, minusDI)
    }
}

// MARK: - 描く内容

extension ChartContentBuilder {

    /// DMI: +DI(黄緑)・−DI(オレンジ)。ADX は描かない
    ///   凡例:「ＤＭＩ DI -DI」
    func dmiContent() -> SubChartContent {
        let result = TechnicalIndicators.dmi(highs: self.highs, lows: self.lows, closes: self.closes, period: self.parameters.dmiPeriod)
        let plusDI = self.precomputedValues(\.dmiPlus) ?? result.plusDI
        let minusDI = self.precomputedValues(\.dmiMinus) ?? result.minusDI
        return SubChartContent(
            legendTitle: "ＤＭＩ",
            series: [
                ChartSeries(label: "DI", values: plusDI, colorRole: .line(0)),
                ChartSeries(label: "-DI", values: minusDI, colorRole: .line(1)),
            ],
            includesZero: true)
    }
}

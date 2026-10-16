//
//  Stochastics.swift
//  ChartTest
//
//  【Model】テクニカル指標「ストキャスティクス」の、計算と描く内容。
//
//  サブチャートに、%D(黄緑)と Slow%D(オレンジ)の線と、底値・高値ラインの基準線を描く。
//    凡例:「ストキャス %D(14,3) Slow%D」
//
//  ・計算(TechnicalIndicators の extension): 値を計算する。描画や色の情報は持たない
//  ・描く内容(ChartContentBuilder の extension): 計算結果を、どの名前(凡例)・どの色の役割で描くかを決める
//    チャートの外で計算した値(ChartIndicatorValues)があれば、計算せずにその値を使う
//

import Foundation

// MARK: - 計算

extension TechnicalIndicators {

    /// ストキャスティクスの %D(%)。Slow%D は、この値の dPeriod 本の移動平均(sma)。
    ///   %D = (終値 − 過去 kPeriod 本の最安値) の dPeriod 本合計 ÷ (最高値 − 最安値) の dPeriod 本合計 × 100
    /// - Parameters:
    ///   - kPeriod: 最高値・最安値を取る期間(設定画面の「高安期間」)
    ///   - dPeriod: 合計を取る期間(設定画面の「D期間」)
    static func stochasticsD(highs: [Double], lows: [Double], closes: [Double],
                             kPeriod: Int, dPeriod: Int) -> [Double?] {
        let count = closes.count
        var d = [Double?](repeating: nil, count: count)
        guard kPeriod > 0 else {
            return d
        }
        guard dPeriod > 0 else {
            return d
        }

        // 各位置の (終値 − 最安値) と (最高値 − 最安値)
        var numerators = [Double?](repeating: nil, count: count)
        var denominators = [Double?](repeating: nil, count: count)
        for i in 0..<count where i >= kPeriod - 1 {
            let range = (i - kPeriod + 1)...i  // i 本目までの直近 kPeriod 本
            guard let highest = highs[range].max() else {
                continue
            }
            guard let lowest = lows[range].min() else {
                continue
            }
            numerators[i] = closes[i] - lowest
            denominators[i] = highest - lowest
        }

        // (終値 − 最安値) は kPeriod 本目(インデックス kPeriod − 1)から出るので、
        // それを dPeriod 本合計できるのは、そこからさらに dPeriod − 1 本後から
        let firstIndex = (kPeriod - 1) + (dPeriod - 1)
        for i in 0..<count where i >= firstIndex {
            // 直近 dPeriod 本の (終値 − 最安値) と (最高値 − 最安値) をそれぞれ合計する
            var numerator = 0.0
            var denominator = 0.0
            for j in (i - dPeriod + 1)...i {
                numerator += numerators[j] ?? 0
                denominator += denominators[j] ?? 0
            }
            if denominator == 0 {
                // 値動きなしの場合は 0
                d[i] = 0
            } else {
                d[i] = numerator / denominator * 100
            }
        }
        return d
    }
}

// MARK: - 描く内容

extension ChartContentBuilder {

    /// ストキャスティクス: %D(黄緑)と Slow%D(オレンジ。%D の移動平均)。%K は描かない。
    /// 底値・高値ライン(既定 30% / 70%)に基準線を引く(Y軸は表示中の値で決める。oscillatorContent)
    ///   凡例:「ストキャス %D(14,3) Slow%D」
    func stochasticsContent() -> SubChartContent {
        let calculatedD = TechnicalIndicators.stochasticsD(
            highs: self.highs, lows: self.lows, closes: self.closes,
            kPeriod: self.parameters.stochasticsKPeriod, dPeriod: self.parameters.stochasticsDPeriod)
        let dValues = self.precomputedValues(\.stochasticsD) ?? calculatedD
        let slowDValues = self.precomputedValues(\.stochasticsSlowD)
            ?? TechnicalIndicators.sma(calculatedD, period: self.parameters.stochasticsDPeriod)
        let dLine = ChartSeries(label: "%D(\(self.parameters.stochasticsKPeriod),\(self.parameters.stochasticsDPeriod))",
                                values: dValues, colorRole: .line(0))
        let slowDLine = ChartSeries(label: "Slow%D", values: slowDValues, colorRole: .line(1))
        let referenceLines = [Double(self.parameters.stochasticsLowerLine), Double(self.parameters.stochasticsUpperLine)]
        return self.oscillatorContent(legendTitle: "ストキャス", series: [dLine, slowDLine], referenceLines: referenceLines)
    }
}

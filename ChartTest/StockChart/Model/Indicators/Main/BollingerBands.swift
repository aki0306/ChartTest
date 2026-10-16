//
//  BollingerBands.swift
//  ChartTest
//
//  【Model】テクニカル指標「ボリンジャーバンド」の、計算と描く内容。
//
//  メインチャートに、中心線(黄緑)と σ の倍率ごとの上限・下限(±1σ 水色、±2σ 濃い青、±3σ オレンジ)を引く。
//    凡例:「ボリンジャー 移動平均(5)」(中心線だけ)
//
//  ・計算(TechnicalIndicators の extension): 値を計算する。描画や色の情報は持たない
//  ・描く内容(ChartContentBuilder の extension): 計算結果を、どの名前(凡例)・どの色の役割で描くかを決める
//    チャートの外で計算した値(ChartIndicatorValues)があれば、計算せずにその値を使う
//

import Foundation

// MARK: - 計算

extension TechnicalIndicators {

    /// ボリンジャーバンド。
    /// 中心線 = period 本の SMA、バンド = 中心線 ± σ × 倍率
    /// σ は標本標準偏差(n − 1 で割る) = √((n × Σx² − (Σx)²) ÷ (n × (n − 1)))。n = 1 のときは 0
    /// - Returns: 中心線と、倍率ごとの (上限, 下限)
    static func bollingerBands(closes: [Double], period: Int, sigmas: [Double])
        -> (middle: [Double?], bands: [(sigma: Double, upper: [Double?], lower: [Double?])]) {

        let middle = self.sma(closes, period: period)

        // 各位置の標準偏差
        var deviations = [Double?](repeating: nil, count: closes.count)
        if period > 0 {
            for i in closes.indices where i >= period - 1 {
                let window = closes[(i - period + 1)...i]
                if period == 1 {
                    deviations[i] = 0
                    continue
                }
                // Σx²(2乗の合計)と Σx(合計)から、標本標準偏差を求める
                var sumOfSquares = 0.0
                var sum = 0.0
                for close in window {
                    sumOfSquares += close * close
                    sum += close
                }
                let n = Double(period)
                let variance = (n * sumOfSquares - sum * sum) / (n * (n - 1))
                // 計算の誤差でごくわずかにマイナスになった場合は 0 にする(平方根を取れないため)
                deviations[i] = max(variance, 0).squareRoot()
            }
        }

        // σ倍率ごとに、上限(中心線 + σ × 倍率)と下限(中心線 − σ × 倍率)を計算する
        var bands: [(sigma: Double, upper: [Double?], lower: [Double?])] = []
        for sigma in sigmas {
            var upper = [Double?](repeating: nil, count: closes.count)
            var lower = [Double?](repeating: nil, count: closes.count)
            for i in closes.indices {
                // 中心線・標準偏差のどちらかが計算できていない位置は nil のまま
                guard let center = middle[i] else {
                    continue
                }
                guard let deviation = deviations[i] else {
                    continue
                }
                upper[i] = center + deviation * sigma
                lower[i] = center - deviation * sigma
            }
            bands.append((sigma: sigma, upper: upper, lower: lower))
        }
        return (middle, bands)
    }
}

// MARK: - 描く内容

extension ChartContentBuilder {

    /// ボリンジャーバンド: 中心線(黄緑) + σ の倍率ごとの上限・下限(±1σ 水色、±2σ 濃い青、±3σ オレンジ)
    ///   凡例:「ボリンジャー 移動平均(5)」(中心線だけ)
    func bollingerBandsContent() -> MainChartContent {
        let result = TechnicalIndicators.bollingerBands(
            closes: self.closes, period: self.parameters.bollingerPeriod, sigmas: self.parameters.bollingerSigmas)

        let middle = self.precomputedValues(\.bollingerMiddle) ?? result.middle
        var series = [ChartSeries(label: "移動平均(\(self.parameters.bollingerPeriod))", values: middle, colorRole: .line(0))]
        for (bandNumber, band) in result.bands.enumerated() {
            let role = ChartColorRole.line(self.bollingerBandColorIndex(sigma: band.sigma))
            let upper = self.precomputedValues(\.bollingerUppers, at: bandNumber) ?? band.upper
            let lower = self.precomputedValues(\.bollingerLowers, at: bandNumber) ?? band.lower
            // 上限と下限は同じ色。凡例には出さない
            series.append(ChartSeries(label: nil, values: upper, colorRole: role))
            series.append(ChartSeries(label: nil, values: lower, colorRole: role))
        }
        return MainChartContent(legendTitle: "ボリンジャー", series: series)
    }

    /// ボリンジャーバンドの σ の倍率から、線の色の番号を決める(±1σ 水色、±2σ 濃い青、±3σ オレンジ)
    private func bollingerBandColorIndex(sigma: Double) -> Int {
        if sigma <= 1 {
            return 3
        }
        if sigma <= 2 {
            return 4
        }
        return 1
    }
}

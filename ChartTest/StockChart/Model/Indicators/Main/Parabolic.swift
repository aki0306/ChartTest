//
//  Parabolic.swift
//  ChartTest
//
//  【Model】テクニカル指標「パラボリック」の、計算と描く内容。
//
//  メインチャートに、移動平均線(短期・長期)と SAR の点(グレー)を描く。
//    凡例:「パラボリック 5日移動平均 25日移動平均」
//
//  ・計算(TechnicalIndicators の extension): 値を計算する。描画や色の情報は持たない
//  ・描く内容(ChartContentBuilder の extension): 計算結果を、どの名前(凡例)・どの色の役割で描くかを決める
//    チャートの外で計算した値(ChartIndicatorValues)があれば、計算せずにその値を使う
//

import Foundation

// MARK: - 計算

extension TechnicalIndicators {

    /// パラボリック SAR を計算する。
    /// (参照: http://exceltechnical.web.fc2.com/para.html)
    ///
    ///   SAR = 前の SAR + AF × (EP − 前の SAR)
    ///   trend: 上昇 1 / 下降 -1
    ///   EP   : 上昇中は最高値、下降中は最安値(極値)
    ///   AF   : 加速因子。step から始まり、同じトレンドのまま EP が変わるたびに step ずつ増える(maximum 未満のときだけ増やす)
    ///
    /// 手順(2本目から計算し、1本目には値を置かない):
    ///   ・2本目: 終値が1本目より高ければ上昇(EP = 高値、SAR = 安値)、それ以外は下降(EP = 安値、SAR = 高値)
    ///   ・3本目以降:
    ///       1. トレンド: 上昇中に前の SAR が安値より上なら下降へ、下降中に前の SAR が高値より下なら上昇へ
    ///       2. EP   : 上昇なら「前の SAR > 安値 で安値」「前の EP < 高値 で高値」、下降なら「前の SAR < 高値 で高値」「前の EP > 安値 で安値」
    ///                 (どちらにも当たらなければ前の EP のまま)
    ///       3. AF   : トレンドが変わったら step に戻す。同じトレンドで EP が変わり、AF が maximum 未満なら step を足す
    ///       4. SAR  : 同じトレンドなら 前の SAR + AF × (EP − 前の SAR)、トレンドが変わったら前の EP
    ///
    /// ※ 一般的な Wilder 方式にある「SAR を直近2本の安値(高値)の外側に置く」制限は入れていない
    ///
    /// - Returns: 各位置の SAR 値(1本目は nil)
    static func parabolicSAR(highs: [Double], lows: [Double], closes: [Double],
                             step: Double, maximum: Double) -> [Double?] {
        let count = closes.count
        var values = [Double?](repeating: nil, count: count)
        guard count >= 2 else {
            return values
        }

        // AF は 10進数で足す。
        // Double で 0.02 を足し続けると 0.19999… になり、上限 0.2 を超えて 0.22 まで増えてしまうため
        let stepValue = Self.decimal(step)
        let maximumValue = Self.decimal(maximum)
        var accelerationFactor = stepValue

        var trend = 1                // 今の足のトレンド(上昇 1 / 下降 -1)
        var previousTrend = 1        // 前の足のトレンド
        var extremePoint = 0.0       // 今の足の EP
        var previousExtremePoint = 0.0
        var sar = 0.0                // 計算の途中では前の足の SAR、計算後は今の足の SAR

        for i in 1..<count {
            let high = highs[i]
            let low = lows[i]

            if i == 1 {
                // 2本目: 1本目の終値と比べて、最初のトレンドを決める
                if closes[i] > closes[i - 1] {
                    trend = 1
                    extremePoint = high
                    sar = low
                } else {
                    trend = -1
                    extremePoint = low
                    sar = high
                }
            } else {
                // 1. トレンド: 前の SAR を価格が抜けたら転換する
                if previousTrend == 1 {
                    if sar > low {
                        trend = -1
                    }
                } else if previousTrend == -1 {
                    if sar < high {
                        trend = 1
                    }
                }

                // 2. EP
                if trend == 1 {
                    if sar > low {
                        extremePoint = low
                    }
                    if previousExtremePoint < high {
                        extremePoint = high
                    }
                }
                if trend == -1 {
                    if sar < high {
                        extremePoint = high
                    }
                    if previousExtremePoint > low {
                        extremePoint = low
                    }
                }

                // 3. AF
                if previousTrend != trend {
                    accelerationFactor = stepValue
                } else if accelerationFactor < maximumValue {
                    if extremePoint != previousExtremePoint {
                        accelerationFactor += stepValue
                    }
                }

                // 4. SAR
                if previousTrend == trend {
                    let factor = NSDecimalNumber(decimal: accelerationFactor).doubleValue
                    sar = sar + factor * (extremePoint - sar)
                } else {
                    sar = previousExtremePoint
                }
            }

            previousExtremePoint = extremePoint
            previousTrend = trend
            values[i] = sar
        }
        return values
    }

    /// Double を 10進数(Decimal)にする。0.02 のような値を、2進数の誤差なしで扱うため("0.02" として読む)
    private static func decimal(_ value: Double) -> Decimal {
        if let result = Decimal(string: "\(value)") {
            return result
        }
        return Decimal(value)
    }
}

// MARK: - 描く内容

extension ChartContentBuilder {

    /// パラボリック: 移動平均線(短期・長期) + SAR の点(グレー)
    ///   凡例:「パラボリック 5日移動平均 25日移動平均」(単位は足種ごと。分・日・週・月。週足は 13週・26週)
    func parabolicContent() -> MainChartContent {
        let sar = self.precomputedValues(\.parabolicSAR)
            ?? TechnicalIndicators.parabolicSAR(
                highs: self.highs, lows: self.lows, closes: self.closes,
                step: self.parameters.parabolicStep, maximum: self.parameters.parabolicMaximum)

        // 移動平均線は、移動平均線の設定とは別の固定の期間(5/25、週足は 13/26)
        let shortPeriod = self.parameters.parabolicShortMAPeriod
        let longPeriod = self.parameters.parabolicLongMAPeriod
        let shortValues = self.precomputedValues(\.movingAverageShort)
            ?? TechnicalIndicators.sma(self.closes, period: shortPeriod)
        let longValues = self.precomputedValues(\.movingAverageLong)
            ?? TechnicalIndicators.sma(self.closes, period: longPeriod)
        let unit = self.parameters.periodUnit
        var series = [
            ChartSeries(label: "\(shortPeriod)\(unit)移動平均", values: shortValues, colorRole: .line(0)),
            ChartSeries(label: "\(longPeriod)\(unit)移動平均", values: longValues, colorRole: .line(1)),
        ]
        series.append(ChartSeries(label: nil, values: sar, colorRole: .parabolic, style: .dots))
        return MainChartContent(legendTitle: "パラボリック", series: series)
    }
}

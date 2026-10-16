//
//  Ichimoku.swift
//  ChartTest
//
//  【Model】テクニカル指標「一目均衡表」の、計算と描く内容。
//
//  メインチャートに、転換線・基準線・先行スパン1/2・遅行スパンと、先行スパンの間の雲を描く。
//    凡例:「一目均衡 転換線(3) 基準線(26) 先行スパン2(52)」
//  雲の塗りつぶしは CloudCombinedRenderer(View/Chart/Renderers/)が描く
//
//  ・計算(TechnicalIndicators の extension): 値を計算する。描画や色の情報は持たない
//  ・描く内容(ChartContentBuilder の extension): 計算結果を、どの名前(凡例)・どの色の役割で描くかを決める
//    チャートの外で計算した値(ChartIndicatorValues)があれば、計算せずにその値を使う
//

import Foundation

// MARK: - 計算

extension TechnicalIndicators {

    /// 一目均衡表の各線
    struct Ichimoku {
        /// 転換線 = (過去 tenkan 本の最高値 + 最安値) ÷ 2
        let tenkan: [Double?]
        /// 基準線 = (過去 kijun 本の最高値 + 最安値) ÷ 2
        let kijun: [Double?]
        /// 先行スパン1 = (転換線 + 基準線) ÷ 2 を shift 本先にずらしたもの(配列はデータ数より長い)
        let spanA: [Double?]
        /// 先行スパン2 = (過去 spanB 本の最高値 + 最安値) ÷ 2 を shift 本先にずらしたもの(配列はデータ数より長い)
        let spanB: [Double?]
        /// 遅行スパン = 終値を shift 本前にずらしたもの
        let chikou: [Double?]
        /// 先行スパンがデータの右端より先に伸びる本数
        let futureCount: Int
    }

    /// 一目均衡表を計算する。
    /// - Parameter shift: 先行/遅行させる本数。当日を1本目と数えるのが一般的なため、実際のずらし幅は shift − 1
    static func ichimoku(highs: [Double], lows: [Double], closes: [Double],
                         tenkanPeriod: Int, kijunPeriod: Int, spanBPeriod: Int, shift: Int) -> Ichimoku {
        let count = closes.count
        let offset = max(shift - 1, 0)

        let tenkan = self.highLowMidpoint(highs: highs, lows: lows, period: tenkanPeriod)
        let kijun = self.highLowMidpoint(highs: highs, lows: lows, period: kijunPeriod)
        let spanBBase = self.highLowMidpoint(highs: highs, lows: lows, period: spanBPeriod)

        // 先行スパンは offset 本先に描くので、配列の長さを offset 本ぶん延ばす
        var spanA = [Double?](repeating: nil, count: count + offset)
        var spanB = [Double?](repeating: nil, count: count + offset)
        for i in 0..<count {
            // 先行スパン1 は、転換線・基準線の両方が計算できている位置だけ
            if let tenkanValue = tenkan[i] {
                if let kijunValue = kijun[i] {
                    spanA[i + offset] = (tenkanValue + kijunValue) / 2
                }
            }
            spanB[i + offset] = spanBBase[i]
        }

        // 遅行スパンは offset 本前に描く(i 本目の終値を i − offset 本目に置く)。
        // データが offset 本以下のときは範囲の上下が逆になって落ちるので、上限を offset 以上にする(その場合は1つも置かない)
        var chikou = [Double?](repeating: nil, count: count)
        let upperBound = max(count, offset)
        for i in offset..<upperBound {
            chikou[i - offset] = closes[i]
        }

        return Ichimoku(tenkan: tenkan, kijun: kijun, spanA: spanA, spanB: spanB,
                        chikou: chikou, futureCount: offset)
    }

    /// (過去 period 本の最高値 + 最安値) ÷ 2
    private static func highLowMidpoint(highs: [Double], lows: [Double], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: highs.count)
        guard period > 0 else {
            return result
        }
        for i in highs.indices where i >= period - 1 {
            let range = (i - period + 1)...i  // i 本目までの直近 period 本
            guard let highest = highs[range].max() else {
                continue
            }
            guard let lowest = lows[range].min() else {
                continue
            }
            result[i] = (highest + lowest) / 2
        }
        return result
    }
}

// MARK: - 描く内容

extension ChartContentBuilder {

    /// 一目均衡表: 転換線(青)・基準線(黄緑)・先行スパン1(黄緑)/2(オレンジ)・遅行スパン(グレー) + 雲
    ///   凡例:「一目均衡 転換線(3) 基準線(26) 先行スパン2(52)」
    ///   先行スパンは未来へずらして描くので、データの右端より先にも描く(futureCount)
    func ichimokuContent() -> MainChartContent {
        let result = TechnicalIndicators.ichimoku(
            highs: self.highs, lows: self.lows, closes: self.closes,
            tenkanPeriod: self.parameters.ichimokuTenkanPeriod, kijunPeriod: self.parameters.ichimokuKijunPeriod,
            spanBPeriod: self.parameters.ichimokuSpanBPeriod, shift: self.parameters.ichimokuShift)
        let tenkan = self.precomputedValues(\.ichimokuTenkan) ?? result.tenkan
        let kijun = self.precomputedValues(\.ichimokuKijun) ?? result.kijun
        let chikou = self.precomputedValues(\.ichimokuChikou) ?? result.chikou

        // 先行スパンは、データの右端より先の分も含めた長さ(ローソク足の本数 + futureCount)にそろえる
        var spanA = result.spanA
        var spanB = result.spanB
        var futureCount = result.futureCount
        if let precomputedSpanA = self.precomputed?.ichimokuSpanA {
            if let precomputedSpanB = self.precomputed?.ichimokuSpanB {
                let length = max(precomputedSpanA.count, precomputedSpanB.count, self.candles.count)
                spanA = ChartIndicatorValues.doubles(precomputedSpanA, count: length)
                spanB = ChartIndicatorValues.doubles(precomputedSpanB, count: length)
                futureCount = length - self.candles.count
            }
        }
        return MainChartContent(
            legendTitle: "一目均衡",
            series: [
                ChartSeries(label: "転換線(\(self.parameters.ichimokuTenkanPeriod))", values: tenkan, colorRole: .ichimokuTenkan),
                ChartSeries(label: "基準線(\(self.parameters.ichimokuKijunPeriod))", values: kijun, colorRole: .ichimokuKijun),
                ChartSeries(label: nil, values: spanA, colorRole: .ichimokuSpanA),
                ChartSeries(label: "先行スパン2(\(self.parameters.ichimokuSpanBPeriod))", values: spanB, colorRole: .ichimokuSpanB),
                ChartSeries(label: nil, values: chikou, colorRole: .ichimokuChikou),
            ],
            cloud: ChartCloud(spanA: spanA, spanB: spanB),
            futureCount: futureCount)
    }
}

//
//  NewPrice.swift
//  ChartTest
//
//  【Model】チャートの種類「新値足」の、計算と描く内容。
//
//  3本新値の新値足を、新値足の1本を1つの足として並べる(X軸は時間ではなく新値の本数。サブチャートなし)。
//    凡例:「新値足　■陰線　□陽線」(新値足の色)
//    現在値(最新の足の終値)の位置に破線を引く
//
//  ・計算(TechnicalIndicators の extension): 終値から新値足の線を作る。描画や色の情報は持たない
//  ・描く内容(ChartContentBuilder の extension): 線を足(StockCandle)に置き換えて、表示本数・スクロールできる本数を決める
//    チャートの外で計算した線(ChartIndicatorValues.newPriceCandles)があれば、計算せずにそれを使う
//

import Foundation

// MARK: - 計算

extension TechnicalIndicators {

    /// 新値足の1本(始点 → 終点)
    struct NewPriceLine {
        /// この線ができた足の日付
        let date: Date
        /// 線の始点(前の線の終点、または転換時は前の線の始点)
        let start: Double
        /// 線の終点(この線ができた足の終値)
        let end: Double

        /// 上昇の線(陽線)か
        var isUp: Bool {
            return self.end > self.start
        }

        /// 線の高いほうの値
        var high: Double {
            return max(self.start, self.end)
        }

        /// 線の低いほうの値
        var low: Double {
            return min(self.start, self.end)
        }
    }

    /// 新値足(N本新値)。
    /// 終値だけを使い、値が更新されたときだけ線を足す(時間の経過では線は増えない)。
    ///
    ///   ・1本目: 2本目の足で、1本目の終値 → 2本目の終値 の線を引く(値が同じでも引く)
    ///   ・以降 : 直近 N 本の線の最高値(始点・終点の大きいほう)を終値が上回ったら、直前の線の高いほうから終値まで上昇の線を引く
    ///            直近 N 本の線の最安値を終値が下回ったら、直前の線の低いほうから終値まで下降の線を引く
    ///            (線が N 本に満たない場合はあるだけで判定する。どちらでもなければ線は増えない)
    ///
    ///   例) N = 3、陽線 100→110、110→120、120→130 のあと
    ///       終値 125 → 線は増えない(3本の安値 100 を下回っていない)
    ///       終値 95  → 陰線 120→95 を引く(直前の線の低いほう = 始点 120 から)
    ///
    /// - Parameters:
    ///   - dates: 各足の日付
    ///   - closes: 各足の終値
    ///   - reversalCount: 判定に使う直近の線の本数(N)
    /// - Returns: 古い順の線
    static func newPriceLines(dates: [Date], closes: [Double], reversalCount: Int) -> [NewPriceLine] {
        guard closes.count >= 2 else {
            return []
        }
        var lines: [NewPriceLine] = []

        for i in 1..<closes.count {
            let price = closes[i]

            // 1本目: 1本目の足の終値から、この足の終値まで(値が同じでも引く)
            guard let last = lines.last else {
                lines.append(NewPriceLine(date: dates[i], start: closes[i - 1], end: price))
                continue
            }

            // 直近 N 本の線(N 本に満たない場合はあるだけ)の最高値・最安値。
            // N が 0 以下に設定されても、直前の線1本では判定できるよう、最低 1 本にする
            let recentCount = max(reversalCount, 1)
            let recentLines = lines.suffix(recentCount)
            var highestHigh = last.high
            var lowestLow = last.low
            for line in recentLines {
                highestHigh = max(highestHigh, line.high)
                lowestLow = min(lowestLow, line.low)
            }

            if price > highestHigh {
                // 上昇: 直前の線の高いほうから引く(陽線の続きなら終点から、陰線からの転換なら始点から)
                lines.append(NewPriceLine(date: dates[i], start: last.high, end: price))
            } else if price < lowestLow {
                // 下降: 直前の線の低いほうから引く(陰線の続きなら終点から、陽線からの転換なら始点から)
                lines.append(NewPriceLine(date: dates[i], start: last.low, end: price))
            }
        }
        return lines
    }
}

// MARK: - 描く内容

extension ChartContentBuilder {

    /// 新値足の転換に使う本数(3本新値)
    static let newPriceReversalCount = 3
    /// 新値足の表示本数(本数が少ないときは右寄せで表示する)
    static let newPriceVisibleCount = 50
    /// 新値足のスクロールできる本数(直近のこの本数だけを並べ、少ないときは左側を空けてこの本数分の幅にする)
    static let newPriceScrollCount = 250

    /// 新値足の内容(新値足の1本を1つの足として並べる。サブチャートなし)
    ///
    ///   凡例:「新値足　■陰線　□陽線」(新値足の色)
    ///   現在値(最新の足の終値)の位置に破線を引く
    func newPriceContent() -> ChartContent {
        // 新値足の1本 = ローソク足の「始値 = 始点、終値 = 終点」として並べる(ヒゲはないので高値・安値は線の両端)。
        // チャートの外で計算した線があれば、それを使う
        var lineCandles: [StockCandle] = []
        if let precomputedCandles = self.precomputed?.newPriceCandles {
            lineCandles = precomputedCandles
        } else {
            // 値が読めた足だけで作る(埋めた足は除く)
            let validCandles = self.candles.filter { candle in !candle.isFilled }
            let dates = validCandles.map { candle in candle.date }
            let closes = validCandles.map { candle in candle.close }
            let lines = TechnicalIndicators.newPriceLines(dates: dates, closes: closes,
                                                          reversalCount: Self.newPriceReversalCount)
            lineCandles = lines.map { line in
                StockCandle(date: line.date, open: line.start, high: line.high, low: line.low, close: line.end, volume: 0)
            }
        }
        // スクロールできるのは直近 newPriceScrollCount 本だけ
        lineCandles = Array(lineCandles.suffix(Self.newPriceScrollCount))
        let main = MainChartContent(
            priceStyle: .newPrice,
            // 全角スペースで区切った1つの文字列
            legendItems: [ChartLegendItem(text: "\(ChartType.newPrice.legendTitle)　■陰線　□陽線", colorRole: .newPrice)],
            currentPrice: self.candles.last?.close,
            fixedVisibleCount: Self.newPriceVisibleCount,
            minimumScrollCount: Self.newPriceScrollCount)
        return ChartContent(candles: lineCandles, main: main, sub: nil)
    }
}

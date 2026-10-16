//
//  TechnicalIndicators.swift
//  ChartTest
//
//  【Model】テクニカル指標の計算処理の入れ物(名前空間)と、いくつもの指標で使う共通の計算。
//  UIKit に依存しない純粋な計算のみを行う(描画や色の情報は持たない)。
//
//  各指標の計算は、指標ごとのファイルに extension で書いている(計算と描く内容を1つのファイルにまとめている)。
//    メインチャート: Indicators/Main/   (MovingAverage・MultipleMovingAverage・BollingerBands・Ichimoku・Parabolic)
//    サブチャート  : Indicators/Sub/    (Volume・MovingAverageDeviation・RSI・Psychological・Stochastics・MACD・DMI)
//  このファイルに残しているのは、いくつもの指標で使う移動平均(sma・ema)と、チャートの種類の新値足。
//
//  計算関数はすべて「入力と同じインデックスで値が並んだ配列」を返す。
//  計算に必要な本数に満たない部分は nil(= 線を描かない)になる。
//

import Foundation

// MARK: - 計算処理

/// テクニカル指標の計算処理をまとめた名前空間
enum TechnicalIndicators {

    // MARK: 移動平均(いくつもの指標で使う)

    /// 単純移動平均(SMA)
    static func sma(_ values: [Double], period: Int) -> [Double?] {
        values.simpleMovingAverage(period: period)
    }

    /// 値がない位置(nil)を含む配列の単純移動平均。直前 period 本の値がすべて揃っている位置だけ計算する
    /// (ストキャスティクスの Slow%D = %D の移動平均 など)
    static func sma(_ values: [Double?], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: values.count)
        guard period > 0 else {
            return result
        }
        for index in values.indices where index >= period - 1 {
            var sum = 0.0
            var isComplete = true
            for value in values[(index - period + 1)...index] {
                guard let value else {
                    isComplete = false
                    break
                }
                sum += value
            }
            if isComplete {
                result[index] = sum / Double(period)
            }
        }
        return result
    }

    /// 指数平滑移動平均(EMA)。
    /// 入力に nil を含む場合(MACD のシグナル計算など)は、連続して period 本の値が揃った位置から計算を始める。
    /// 最初の値は SMA で初期化し、以降は EMA = 前回EMA + α × (今回値 − 前回EMA)、α = 2 / (period + 1)。
    static func ema(_ values: [Double?], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: values.count)
        guard period > 0 else {
            return result
        }

        let alpha = 2.0 / Double(period + 1)
        var previous: Double?  // 前回の EMA
        var window: [Double] = []  // 初期値(SMA)計算用に直近の値を貯める

        for (i, value) in values.enumerated() {
            guard let value else {
                // 途中で値が途切れたら初期化からやり直す
                previous = nil
                window.removeAll()
                continue
            }
            if let previousEMA = previous {
                let current = previousEMA + alpha * (value - previousEMA)
                result[i] = current
                previous = current
            } else {
                window.append(value)
                if window.count == period {
                    let initial = window.reduce(0, +) / Double(period)
                    result[i] = initial
                    previous = initial
                }
            }
        }
        return result
    }

    // MARK: 新値足

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

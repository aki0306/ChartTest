//
//  TechnicalIndicators.swift
//  ChartTest
//
//  【Model】テクニカル指標の計算処理。
//  UIKit に依存しない純粋な計算のみを行う(描画や色の情報は持たない)。
//
//  計算関数はすべて「入力と同じインデックスで値が並んだ配列」を返す。
//  計算に必要な本数に満たない部分は nil(= 線を描かない)になる。
//

import Foundation

// MARK: - 計算処理

/// テクニカル指標の計算処理をまとめた名前空間
enum TechnicalIndicators {

    // MARK: 移動平均系

    /// 単純移動平均(SMA)
    static func sma(_ values: [Double], period: Int) -> [Double?] {
        values.simpleMovingAverage(period: period)
    }

    /// 指数平滑移動平均(EMA)。
    /// 入力に nil を含む場合(MACD のシグナル計算など)は、連続して period 本の値が揃った位置から計算を始める。
    /// 最初の値は SMA で初期化し、以降は EMA = 前回EMA + α × (今回値 − 前回EMA)、α = 2 / (period + 1)。
    static func ema(_ values: [Double?], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: values.count)
        guard period > 0 else { return result }

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

    /// 移動平均乖離率(%) = (終値 − 移動平均) ÷ 移動平均 × 100
    static func movingAverageDeviation(closes: [Double], period: Int) -> [Double?] {
        let averages = self.sma(closes, period: period)
        return zip(closes, averages).map { close, average in
            guard let average, average != 0 else { return nil }
            return (close - average) / average * 100
        }
    }

    // MARK: ボリンジャーバンド

    /// ボリンジャーバンド。
    /// 中心線 = period 本の SMA、バンド = 中心線 ± σ × 倍率(σ は母標準偏差)
    /// - Returns: 中心線と、倍率ごとの (上限, 下限)
    static func bollingerBands(closes: [Double], period: Int, sigmas: [Double])
        -> (middle: [Double?], bands: [(sigma: Double, upper: [Double?], lower: [Double?])]) {

        let middle = self.sma(closes, period: period)

        // 各位置の標準偏差
        var deviations = [Double?](repeating: nil, count: closes.count)
        if period > 0 {
            for i in closes.indices where i >= period - 1 {
                guard let mean = middle[i] else { continue }
                let window = closes[(i - period + 1)...i]
                // 分散 = (各値 − 平均)² の平均。標準偏差 = 分散の平方根
                var sumOfSquares = 0.0
                for close in window {
                    sumOfSquares += (close - mean) * (close - mean)
                }
                let variance = sumOfSquares / Double(period)
                deviations[i] = variance.squareRoot()
            }
        }

        // σ倍率ごとに、上限(中心線 + σ × 倍率)と下限(中心線 − σ × 倍率)を計算する
        var bands: [(sigma: Double, upper: [Double?], lower: [Double?])] = []
        for sigma in sigmas {
            var upper = [Double?](repeating: nil, count: closes.count)
            var lower = [Double?](repeating: nil, count: closes.count)
            for i in closes.indices {
                // 中心線・標準偏差のどちらかが計算できていない位置は nil のまま
                guard let center = middle[i], let deviation = deviations[i] else { continue }
                upper[i] = center + deviation * sigma
                lower[i] = center - deviation * sigma
            }
            bands.append((sigma: sigma, upper: upper, lower: lower))
        }
        return (middle, bands)
    }

    // MARK: 一目均衡表

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
            if let tenkanValue = tenkan[i], let kijunValue = kijun[i] {
                spanA[i + offset] = (tenkanValue + kijunValue) / 2
            }
            spanB[i + offset] = spanBBase[i]
        }

        // 遅行スパンは offset 本前に描く
        var chikou = [Double?](repeating: nil, count: count)
        for i in offset..<max(count, offset) {
            chikou[i - offset] = closes[i]
        }

        return Ichimoku(tenkan: tenkan, kijun: kijun, spanA: spanA, spanB: spanB,
                        chikou: chikou, futureCount: offset)
    }

    /// (過去 period 本の最高値 + 最安値) ÷ 2
    private static func highLowMidpoint(highs: [Double], lows: [Double], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: highs.count)
        guard period > 0 else { return result }
        for i in highs.indices where i >= period - 1 {
            let range = (i - period + 1)...i  // i 本目までの直近 period 本
            guard let highest = highs[range].max() else { continue }
            guard let lowest = lows[range].min() else { continue }
            result[i] = (highest + lowest) / 2
        }
        return result
    }

    // MARK: パラボリック

    /// パラボリック SAR(Wilder 方式)を計算する。
    ///
    /// SAR = 前回SAR + AF × (EP − 前回SAR)
    ///   EP: 上昇トレンド中の最高値 / 下降トレンド中の最安値
    ///   AF: 加速因子。step から始まり、EP 更新ごとに step ずつ増える(上限 maximum)
    /// 価格が SAR を割り込んだ(上抜けた)らトレンド転換し、SAR を直前の EP に置き換える。
    ///
    /// - Returns: 各位置の SAR 値と、その時点が上昇トレンドかどうか
    static func parabolicSAR(highs: [Double], lows: [Double], closes: [Double],
                             step: Double, maximum: Double) -> (values: [Double?], isUptrend: [Bool]) {
        let count = closes.count
        var values = [Double?](repeating: nil, count: count)
        var isUptrend = [Bool](repeating: true, count: count)
        guard count >= 2 else { return (values, isUptrend) }

        // 初期トレンドは最初の2本の終値で判定する
        var uptrend = closes[1] >= closes[0]
        // accelerationFactor(AF・加速因子): step から始まり、EP を更新するたびに step ずつ増える
        var accelerationFactor = step
        // extremePoint(EP・極値): 上昇トレンドなら最高値、下降トレンドなら最安値
        // SAR: 上昇トレンドなら最安値(足の下に置く)、下降トレンドなら最高値(足の上に置く)
        var extremePoint: Double
        var sar: Double
        if uptrend {
            extremePoint = max(highs[0], highs[1])
            sar = min(lows[0], lows[1])
        } else {
            extremePoint = min(lows[0], lows[1])
            sar = max(highs[0], highs[1])
        }
        values[1] = sar
        isUptrend[1] = uptrend

        for i in 2..<count {
            sar += accelerationFactor * (extremePoint - sar)

            if uptrend {
                // SAR は直近2本の安値より上にはならない
                sar = min(sar, lows[i - 1], lows[i - 2])
                if lows[i] < sar {
                    // 安値が SAR を割り込んだ → 下降トレンドへ転換
                    uptrend = false
                    sar = extremePoint
                    extremePoint = lows[i]
                    accelerationFactor = step
                } else if highs[i] > extremePoint {
                    // 最高値更新 → EP と AF を更新
                    extremePoint = highs[i]
                    accelerationFactor = min(accelerationFactor + step, maximum)
                }
            } else {
                // SAR は直近2本の高値より下にはならない
                sar = max(sar, highs[i - 1], highs[i - 2])
                if highs[i] > sar {
                    // 高値が SAR を上抜けた → 上昇トレンドへ転換
                    uptrend = true
                    sar = extremePoint
                    extremePoint = highs[i]
                    accelerationFactor = step
                } else if lows[i] < extremePoint {
                    // 最安値更新 → EP と AF を更新
                    extremePoint = lows[i]
                    accelerationFactor = min(accelerationFactor + step, maximum)
                }
            }
            values[i] = sar
            isUptrend[i] = uptrend
        }
        return (values, isUptrend)
    }

    // MARK: オシレーター系

    /// RSI(%)。国内で一般的な単純平均方式で計算する。
    /// RSI = 期間中の上昇幅合計 ÷ (上昇幅合計 + 下落幅合計) × 100
    static func rsi(closes: [Double], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: closes.count)
        guard period > 0 else { return result }

        for i in closes.indices where i >= period {
            var gain = 0.0
            var loss = 0.0
            for j in (i - period + 1)...i {
                let change = closes[j] - closes[j - 1]  // 前日からの値動き
                if change > 0 {
                    gain += change   // 上昇幅
                } else {
                    loss -= change   // 下落幅(マイナスなので引いてプラスにする)
                }
            }
            // 期間中まったく値動きがない場合は中立の 50 とする
            if gain + loss == 0 {
                result[i] = 50
            } else {
                result[i] = gain / (gain + loss) * 100
            }
        }
        return result
    }

    /// サイコロジカルライン(%) = 期間中の上昇日数 ÷ 期間 × 100
    static func psychological(closes: [Double], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: closes.count)
        guard period > 0 else { return result }

        for i in closes.indices where i >= period {
            // 期間中に前日より終値が上がった日数を数える
            var upDays = 0
            for j in (i - period + 1)...i {
                if closes[j] > closes[j - 1] {
                    upDays += 1
                }
            }
            result[i] = Double(upDays) / Double(period) * 100
        }
        return result
    }

    /// ストキャスティクス(%)。
    ///   %K = (終値 − 過去 kPeriod 本の最安値) ÷ (最高値 − 最安値) × 100
    ///   %D = (終値 − 最安値) の dPeriod 本合計 ÷ (最高値 − 最安値) の dPeriod 本合計 × 100
    static func stochastics(highs: [Double], lows: [Double], closes: [Double],
                            kPeriod: Int, dPeriod: Int) -> (k: [Double?], d: [Double?]) {
        let count = closes.count
        var k = [Double?](repeating: nil, count: count)
        var d = [Double?](repeating: nil, count: count)
        guard kPeriod > 0 else { return (k, d) }
        guard dPeriod > 0 else { return (k, d) }

        // 各位置の (終値 − 最安値) と (最高値 − 最安値)
        var numerators = [Double?](repeating: nil, count: count)
        var denominators = [Double?](repeating: nil, count: count)
        for i in 0..<count where i >= kPeriod - 1 {
            let range = (i - kPeriod + 1)...i  // i 本目までの直近 kPeriod 本
            guard let highest = highs[range].max() else { continue }
            guard let lowest = lows[range].min() else { continue }
            numerators[i] = closes[i] - lowest
            denominators[i] = highest - lowest
            if highest == lowest {
                // 期間中の高値と安値が同じ(値動きなし)場合は中立の 50 とする
                k[i] = 50
            } else {
                k[i] = (closes[i] - lowest) / (highest - lowest) * 100
            }
        }

        for i in 0..<count where i >= kPeriod - 1 + dPeriod - 1 {
            // 直近 dPeriod 本の (終値 − 最安値) と (最高値 − 最安値) をそれぞれ合計する
            var numerator = 0.0
            var denominator = 0.0
            for j in (i - dPeriod + 1)...i {
                numerator += numerators[j] ?? 0
                denominator += denominators[j] ?? 0
            }
            if denominator == 0 {
                // 値動きなしの場合は中立の 50 とする
                d[i] = 50
            } else {
                d[i] = numerator / denominator * 100
            }
        }
        return (k, d)
    }

    /// MACD。
    ///   MACD = 短期EMA − 長期EMA、シグナル = MACD の EMA、ヒストグラム = MACD − シグナル
    static func macd(closes: [Double], shortPeriod: Int, longPeriod: Int, signalPeriod: Int)
        -> (macd: [Double?], signal: [Double?], histogram: [Double?]) {

        // ema は nil を含む配列を受け取るので、[Double] を [Double?] に変換して渡す
        let optionalCloses: [Double?] = closes.map { close in close }
        let shortEMA = self.ema(optionalCloses, period: shortPeriod)
        let longEMA = self.ema(optionalCloses, period: longPeriod)

        // MACD = 短期EMA − 長期EMA(どちらかが計算できていない位置は nil)
        var macd = [Double?](repeating: nil, count: closes.count)
        for i in closes.indices {
            guard let shortValue = shortEMA[i], let longValue = longEMA[i] else { continue }
            macd[i] = shortValue - longValue
        }

        // シグナル = MACD の EMA
        let signal = self.ema(macd, period: signalPeriod)

        // ヒストグラム = MACD − シグナル
        var histogram = [Double?](repeating: nil, count: closes.count)
        for i in closes.indices {
            guard let macdValue = macd[i], let signalValue = signal[i] else { continue }
            histogram[i] = macdValue - signalValue
        }
        return (macd, signal, histogram)
    }

    /// DMI(Wilder 方式)。
    ///   +DM = 当日高値 − 前日高値(−DM より大きく、かつ正の場合のみ。それ以外は 0)
    ///   −DM = 前日安値 − 当日安値(+DM より大きく、かつ正の場合のみ。それ以外は 0)
    ///   TR  = max(高値 − 安値, |高値 − 前日終値|, |安値 − 前日終値|)
    ///   +DI = 平滑化した +DM ÷ 平滑化した TR × 100(−DI も同様)
    ///   ADX = DX(= |+DI − −DI| ÷ (+DI + −DI) × 100)の平滑化
    /// 平滑化は Wilder 方式(前回値 − 前回値 ÷ period + 今回値)
    static func dmi(highs: [Double], lows: [Double], closes: [Double], period: Int)
        -> (plusDI: [Double?], minusDI: [Double?], adx: [Double?]) {

        let count = closes.count
        var plusDI = [Double?](repeating: nil, count: count)
        var minusDI = [Double?](repeating: nil, count: count)
        var adx = [Double?](repeating: nil, count: count)
        guard period > 0 else { return (plusDI, minusDI, adx) }
        // 初期値を作るのに period + 1 本必要(前日との差を取るため)
        guard count > period else { return (plusDI, minusDI, adx) }

        var smoothedTR = 0.0
        var smoothedPlusDM = 0.0
        var smoothedMinusDM = 0.0
        var dxValues: [Double] = []  // ADX の初期値計算用
        var previousADX: Double?

        for i in 1..<count {
            // 当日の +DM / −DM / TR
            let upMove = highs[i] - highs[i - 1]
            let downMove = lows[i - 1] - lows[i]
            // +DM: 高値の上昇幅が安値の下落幅より大きく、かつ上昇している場合だけ採用する(それ以外は 0)
            var plusDM = 0.0
            if upMove > downMove, upMove > 0 {
                plusDM = upMove
            }
            // −DM: 安値の下落幅が高値の上昇幅より大きく、かつ下落している場合だけ採用する(それ以外は 0)
            var minusDM = 0.0
            if downMove > upMove, downMove > 0 {
                minusDM = downMove
            }
            let trueRange = max(highs[i] - lows[i], abs(highs[i] - closes[i - 1]), abs(lows[i] - closes[i - 1]))

            if i <= period {
                // 最初の period 本は単純合計で初期値を作る
                smoothedTR += trueRange
                smoothedPlusDM += plusDM
                smoothedMinusDM += minusDM
                // period 本たまるまでは DI を出さない
                if i < period {
                    continue
                }
            } else {
                // 以降は Wilder 方式で平滑化
                smoothedTR = smoothedTR - smoothedTR / Double(period) + trueRange
                smoothedPlusDM = smoothedPlusDM - smoothedPlusDM / Double(period) + plusDM
                smoothedMinusDM = smoothedMinusDM - smoothedMinusDM / Double(period) + minusDM
            }

            guard smoothedTR > 0 else { continue }
            let currentPlusDI = smoothedPlusDM / smoothedTR * 100
            let currentMinusDI = smoothedMinusDM / smoothedTR * 100
            plusDI[i] = currentPlusDI
            minusDI[i] = currentMinusDI

            // DX → ADX
            var dx = 0.0
            if currentPlusDI + currentMinusDI != 0 {
                dx = abs(currentPlusDI - currentMinusDI) / (currentPlusDI + currentMinusDI) * 100
            }
            if let previous = previousADX {
                // ADX = (前回ADX × (period − 1) + 今回DX) ÷ period
                let current = (previous * Double(period - 1) + dx) / Double(period)
                adx[i] = current
                previousADX = current
            } else {
                dxValues.append(dx)
                if dxValues.count == period {
                    let initial = dxValues.reduce(0, +) / Double(period)
                    adx[i] = initial
                    previousADX = initial
                }
            }
        }
        return (plusDI, minusDI, adx)
    }

    // MARK: VWAP

    /// VWAP(出来高加重平均価格)。
    /// 同じ日の足の「代表値 × 出来高」の累計 ÷ 出来高の累計。日付が変わると計算をやり直す。
    /// 代表値は (高値 + 安値 + 終値) ÷ 3(1本の中の約定価格の代わり)。
    ///   ・1分足・日中足: その日の寄り付きからの VWAP
    ///   ・日足・週足・月足: 1本ごとにやり直すので、その足の代表値になる
    /// その日の出来高の累計が 0 の間(出来高が配信されない指数など)は nil
    static func vwap(dates: [Date], highs: [Double], lows: [Double], closes: [Double], volumes: [Double]) -> [Double?] {
        var result = [Double?](repeating: nil, count: closes.count)
        let calendar = Calendar(identifier: .gregorian)
        var priceVolumeSum = 0.0  // その日の「代表値 × 出来高」の累計
        var volumeSum = 0.0       // その日の出来高の累計

        for i in closes.indices {
            // 日付が変わったら累計をやり直す(最初の足は前の足がないので比べない)
            if i > 0 {
                let isNewDay = !calendar.isDate(dates[i], inSameDayAs: dates[i - 1])
                if isNewDay {
                    priceVolumeSum = 0
                    volumeSum = 0
                }
            }
            let typicalPrice = (highs[i] + lows[i] + closes[i]) / 3
            priceVolumeSum += typicalPrice * volumes[i]
            volumeSum += volumes[i]

            guard volumeSum > 0 else { continue }
            result[i] = priceVolumeSum / volumeSum
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
        var isUp: Bool { self.end > self.start }
        /// 線の高いほうの値
        var high: Double { max(self.start, self.end) }
        /// 線の低いほうの値
        var low: Double { min(self.start, self.end) }
    }

    /// 新値足(N本新値)。終値だけを使い、値が更新されたときだけ線を足す(時間の経過では線は増えない)。
    ///
    ///   ・同じ向きに更新: 陽線なら直前の線の高値を、陰線なら安値を終値が更新したら、直前の線の終点から新しい線を引く
    ///   ・転換: 陽線のあと、直近 N 本の線の安値をすべて下回ったら陰線に転換する
    ///           (直前の線の始点から引く。陰線のあとの陽線への転換も同様)
    ///   ・どちらでもなければ線は増えない
    ///
    ///   例) N = 3、陽線 100→110、110→120、120→130 のあと
    ///       終値 125 → 線は増えない(3本の安値 100 を下回っていない)
    ///       終値 95  → 陰線 120→95 を引く(直前の線の始点 120 から)
    ///
    /// - Parameters:
    ///   - dates: 各足の日付
    ///   - closes: 各足の終値
    ///   - reversalCount: 転換の判定に使う本数(N)
    /// - Returns: 古い順の線。最初の足の終値を起点にして、そこから値が動いた足から線を作る
    static func newPriceLines(dates: [Date], closes: [Double], reversalCount: Int) -> [NewPriceLine] {
        guard let base = closes.first else { return [] }
        var lines: [NewPriceLine] = []

        for i in closes.indices.dropFirst() {
            let price = closes[i]

            // 1本目: 最初の足の終値から動いたら、その向きの線にする
            guard let last = lines.last else {
                if price != base {
                    lines.append(NewPriceLine(date: dates[i], start: base, end: price))
                }
                continue
            }

            // 転換の判定に使う直近 N 本(線が N 本に満たない場合はあるだけ)
            let recentLines = lines.suffix(max(reversalCount, 1))

            if last.isUp {
                if price > last.end {
                    // 高値を更新: 陽線を続ける
                    lines.append(NewPriceLine(date: dates[i], start: last.end, end: price))
                    continue
                }
                let lowestLow = recentLines.map { line in line.low }.min() ?? last.low
                if price < lowestLow {
                    // 直近 N 本の安値をすべて下回った: 陰線に転換
                    lines.append(NewPriceLine(date: dates[i], start: last.start, end: price))
                }
            } else {
                if price < last.end {
                    // 安値を更新: 陰線を続ける
                    lines.append(NewPriceLine(date: dates[i], start: last.end, end: price))
                    continue
                }
                let highestHigh = recentLines.map { line in line.high }.max() ?? last.high
                if price > highestHigh {
                    // 直近 N 本の高値をすべて上回った: 陽線に転換
                    lines.append(NewPriceLine(date: dates[i], start: last.start, end: price))
                }
            }
        }
        return lines
    }
}

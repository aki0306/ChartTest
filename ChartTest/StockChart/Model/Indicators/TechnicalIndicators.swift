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

    // MARK: ボリンジャーバンド

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

    // MARK: パラボリック

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

    // MARK: オシレーター系

    /// RSI(%)。単純平均方式。
    /// RSI = 期間中の上昇幅合計 ÷ (上昇幅合計 + 下落幅合計) × 100
    /// 期間中まったく値動きがない場合は、計算できない(0 で割る)ので値なし
    static func rsi(closes: [Double], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: closes.count)
        guard period > 0 else {
            return result
        }

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
            // 期間中まったく値動きがない場合は計算できないので、値なし(点を描かない)
            if gain + loss == 0 {
                continue
            }
            result[i] = gain / (gain + loss) * 100
        }
        return result
    }

    /// サイコロジカルライン(%) = 期間中の上昇日数 ÷ 期間 × 100
    static func psychological(closes: [Double], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: closes.count)
        guard period > 0 else {
            return result
        }

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

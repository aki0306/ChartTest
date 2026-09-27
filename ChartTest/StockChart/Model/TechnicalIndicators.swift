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
            if let prev = previous {
                let current = prev + alpha * (value - prev)
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
        let averages = sma(closes, period: period)
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

        let middle = sma(closes, period: period)

        // 各位置の標準偏差
        var deviations = [Double?](repeating: nil, count: closes.count)
        if period > 0 {
            for i in closes.indices where i >= period - 1 {
                guard let mean = middle[i] else { continue }
                let window = closes[(i - period + 1)...i]
                let variance = window.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(period)
                deviations[i] = variance.squareRoot()
            }
        }

        let bands = sigmas.map { sigma in
            (sigma: sigma,
             upper: zip(middle, deviations).map { m, d in m.flatMap { m in d.map { m + $0 * sigma } } },
             lower: zip(middle, deviations).map { m, d in m.flatMap { m in d.map { m - $0 * sigma } } })
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

        let tenkan = highLowMidpoint(highs: highs, lows: lows, period: tenkanPeriod)
        let kijun = highLowMidpoint(highs: highs, lows: lows, period: kijunPeriod)
        let spanBBase = highLowMidpoint(highs: highs, lows: lows, period: spanBPeriod)

        // 先行スパンは offset 本先に描くので、配列の長さを offset 本ぶん延ばす
        var spanA = [Double?](repeating: nil, count: count + offset)
        var spanB = [Double?](repeating: nil, count: count + offset)
        for i in 0..<count {
            if let t = tenkan[i], let k = kijun[i] { spanA[i + offset] = (t + k) / 2 }
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
            let range = (i - period + 1)...i
            let highest = highs[range].max()!
            let lowest = lows[range].min()!
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
        var af = step
        var ep = uptrend ? max(highs[0], highs[1]) : min(lows[0], lows[1])
        var sar = uptrend ? min(lows[0], lows[1]) : max(highs[0], highs[1])
        values[1] = sar
        isUptrend[1] = uptrend

        for i in 2..<count {
            sar += af * (ep - sar)

            if uptrend {
                // SAR は直近2本の安値より上にはならない
                sar = min(sar, lows[i - 1], lows[i - 2])
                if lows[i] < sar {
                    // 安値が SAR を割り込んだ → 下降トレンドへ転換
                    uptrend = false
                    sar = ep
                    ep = lows[i]
                    af = step
                } else if highs[i] > ep {
                    // 最高値更新 → EP と AF を更新
                    ep = highs[i]
                    af = min(af + step, maximum)
                }
            } else {
                // SAR は直近2本の高値より下にはならない
                sar = max(sar, highs[i - 1], highs[i - 2])
                if highs[i] > sar {
                    // 高値が SAR を上抜けた → 上昇トレンドへ転換
                    uptrend = true
                    sar = ep
                    ep = highs[i]
                    af = step
                } else if lows[i] < ep {
                    // 最安値更新 → EP と AF を更新
                    ep = lows[i]
                    af = min(af + step, maximum)
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
                let change = closes[j] - closes[j - 1]
                if change > 0 { gain += change } else { loss -= change }
            }
            // 期間中まったく値動きがない場合は中立の 50 とする
            result[i] = (gain + loss) == 0 ? 50 : gain / (gain + loss) * 100
        }
        return result
    }

    /// サイコロジカルライン(%) = 期間中の上昇日数 ÷ 期間 × 100
    static func psychological(closes: [Double], period: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: closes.count)
        guard period > 0 else { return result }

        for i in closes.indices where i >= period {
            let upDays = ((i - period + 1)...i).filter { closes[$0] > closes[$0 - 1] }.count
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
        guard kPeriod > 0, dPeriod > 0 else { return (k, d) }

        // 各位置の (終値 − 最安値) と (最高値 − 最安値)
        var numerators = [Double?](repeating: nil, count: count)
        var denominators = [Double?](repeating: nil, count: count)
        for i in 0..<count where i >= kPeriod - 1 {
            let range = (i - kPeriod + 1)...i
            let highest = highs[range].max()!
            let lowest = lows[range].min()!
            numerators[i] = closes[i] - lowest
            denominators[i] = highest - lowest
            k[i] = highest == lowest ? 50 : (closes[i] - lowest) / (highest - lowest) * 100
        }

        for i in 0..<count where i >= kPeriod - 1 + dPeriod - 1 {
            let range = (i - dPeriod + 1)...i
            let numerator = range.compactMap { numerators[$0] }.reduce(0, +)
            let denominator = range.compactMap { denominators[$0] }.reduce(0, +)
            d[i] = denominator == 0 ? 50 : numerator / denominator * 100
        }
        return (k, d)
    }

    /// MACD。
    ///   MACD = 短期EMA − 長期EMA、シグナル = MACD の EMA、ヒストグラム = MACD − シグナル
    static func macd(closes: [Double], shortPeriod: Int, longPeriod: Int, signalPeriod: Int)
        -> (macd: [Double?], signal: [Double?], histogram: [Double?]) {

        let shortEMA = ema(closes.map { $0 }, period: shortPeriod)
        let longEMA = ema(closes.map { $0 }, period: longPeriod)
        let macd: [Double?] = zip(shortEMA, longEMA).map { s, l in
            guard let s, let l else { return nil }
            return s - l
        }
        let signal = ema(macd, period: signalPeriod)
        let histogram: [Double?] = zip(macd, signal).map { m, s in
            guard let m, let s else { return nil }
            return m - s
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
        guard period > 0, count > period else { return (plusDI, minusDI, adx) }

        var smoothedTR = 0.0
        var smoothedPlusDM = 0.0
        var smoothedMinusDM = 0.0
        var dxValues: [Double] = []  // ADX の初期値計算用
        var previousADX: Double?

        for i in 1..<count {
            // 当日の +DM / −DM / TR
            let upMove = highs[i] - highs[i - 1]
            let downMove = lows[i - 1] - lows[i]
            let plusDM = (upMove > downMove && upMove > 0) ? upMove : 0
            let minusDM = (downMove > upMove && downMove > 0) ? downMove : 0
            let tr = max(highs[i] - lows[i], abs(highs[i] - closes[i - 1]), abs(lows[i] - closes[i - 1]))

            if i <= period {
                // 最初の period 本は単純合計で初期値を作る
                smoothedTR += tr
                smoothedPlusDM += plusDM
                smoothedMinusDM += minusDM
                if i < period { continue }
            } else {
                // 以降は Wilder 方式で平滑化
                smoothedTR = smoothedTR - smoothedTR / Double(period) + tr
                smoothedPlusDM = smoothedPlusDM - smoothedPlusDM / Double(period) + plusDM
                smoothedMinusDM = smoothedMinusDM - smoothedMinusDM / Double(period) + minusDM
            }

            guard smoothedTR > 0 else { continue }
            let pDI = smoothedPlusDM / smoothedTR * 100
            let mDI = smoothedMinusDM / smoothedTR * 100
            plusDI[i] = pDI
            minusDI[i] = mDI

            // DX → ADX
            let dx = (pDI + mDI) == 0 ? 0 : abs(pDI - mDI) / (pDI + mDI) * 100
            if let prev = previousADX {
                let current = (prev * Double(period - 1) + dx) / Double(period)
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
}

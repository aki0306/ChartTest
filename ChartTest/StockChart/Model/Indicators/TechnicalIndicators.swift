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
//  このファイルに残しているのは、いくつもの指標で使う移動平均(sma・ema)。
//  チャートの種類の新値足の計算は、Model/ChartTypes/NewPrice.swift にある。
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
}

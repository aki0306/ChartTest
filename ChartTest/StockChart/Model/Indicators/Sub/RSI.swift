//
//  RSI.swift
//  ChartTest
//
//  【Model】テクニカル指標「RSI」の、計算と描く内容。
//
//  サブチャートに、RSI(黄緑)の線と、底値・高値ラインの基準線を描く。
//    凡例:「ＲＳＩ 期間(14)」
//
//  ・計算(TechnicalIndicators の extension): 値を計算する。描画や色の情報は持たない
//  ・描く内容(ChartContentBuilder の extension): 計算結果を、どの名前(凡例)・どの色の役割で描くかを決める
//    チャートの外で計算した値(ChartIndicatorValues)があれば、計算せずにその値を使う
//

import Foundation

// MARK: - 計算

extension TechnicalIndicators {

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
}

// MARK: - 描く内容

extension ChartContentBuilder {

    /// RSI(黄緑): 底値・高値ライン(既定 20% / 80%)に基準線を引く(Y軸は表示中の値で決める。oscillatorContent)
    ///   凡例:「ＲＳＩ 期間(14)」
    func rsiContent() -> SubChartContent {
        let period = self.parameters.rsiPeriod
        // チャートの外で計算した値があればそれを使い、なければ計算する
        let values = self.precomputedValues(\.rsi)
            ?? TechnicalIndicators.rsi(closes: self.closes, period: period)
        let line = ChartSeries(label: "期間(\(period))", values: values, colorRole: .line(0))
        let referenceLines = [Double(self.parameters.rsiLowerLine), Double(self.parameters.rsiUpperLine)]
        return self.oscillatorContent(legendTitle: "ＲＳＩ", series: [line], referenceLines: referenceLines)
    }
}

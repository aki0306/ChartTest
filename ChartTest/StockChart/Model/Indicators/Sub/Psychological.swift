//
//  Psychological.swift
//  ChartTest
//
//  【Model】テクニカル指標「サイコロジカルライン」の、計算と描く内容。
//
//  サブチャートに、サイコロジカルライン(青)の線と、底値・高値ラインの基準線を描く。
//    凡例:「サイコロ 期間(12)」
//
//  ・計算(TechnicalIndicators の extension): 値を計算する。描画や色の情報は持たない
//  ・描く内容(ChartContentBuilder の extension): 計算結果を、どの名前(凡例)・どの色の役割で描くかを決める
//    チャートの外で計算した値(ChartIndicatorValues)があれば、計算せずにその値を使う
//

import Foundation

// MARK: - 計算

extension TechnicalIndicators {

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
}

// MARK: - 描く内容

extension ChartContentBuilder {

    /// サイコロジカルライン(青): 底値・高値ライン(既定 25% / 75%)に基準線を引く(Y軸は表示中の値で決める。oscillatorContent)
    ///   凡例:「サイコロ 期間(12)」
    func psychologicalContent() -> SubChartContent {
        let period = self.parameters.psychologicalPeriod
        // チャートの外で計算した値があればそれを使い、なければ計算する
        let values = self.precomputedValues(\.psychological)
            ?? TechnicalIndicators.psychological(closes: self.closes, period: period)
        let line = ChartSeries(label: "期間(\(period))", values: values, colorRole: .line(2))
        let referenceLines = [Double(self.parameters.psychologicalLowerLine), Double(self.parameters.psychologicalUpperLine)]
        return self.oscillatorContent(legendTitle: "サイコロ", series: [line], referenceLines: referenceLines)
    }
}

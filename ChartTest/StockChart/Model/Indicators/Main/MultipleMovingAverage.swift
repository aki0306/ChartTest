//
//  MultipleMovingAverage.swift
//  ChartTest
//
//  【Model】テクニカル指標「多重移動平均線」の、計算と描く内容。
//
//  メインチャートに、設定された期間の数だけ移動平均線を引く(すべてオレンジ)。
//    凡例:「多重平均 期間(5,75)」(最短・最長の期間)
//  計算は TechnicalIndicators.sma(単純移動平均。TechnicalIndicators.swift)を使う
//
//  ・計算(TechnicalIndicators の extension): 値を計算する。描画や色の情報は持たない
//  ・描く内容(ChartContentBuilder の extension): 計算結果を、どの名前(凡例)・どの色の役割で描くかを決める
//    チャートの外で計算した値(ChartIndicatorValues)があれば、計算せずにその値を使う
//

import Foundation

// MARK: - 描く内容

extension ChartContentBuilder {

    /// 多重移動平均線: 設定された期間の数だけ移動平均線を引く(すべてオレンジ)
    ///   凡例:「多重平均 期間(5,75)」(最短・最長の期間)
    func multipleMovingAverageContent() -> MainChartContent {
        var series: [ChartSeries] = []
        for (lineNumber, period) in self.parameters.multipleMAPeriods.enumerated() {
            // チャートの外で計算した値があればそれを使い、なければ計算する
            let values = self.precomputedValues(\.multipleMovingAverages, at: lineNumber)
                ?? TechnicalIndicators.sma(self.closes, period: period)
            // 線ごとの凡例は出さない(凡例は「期間(最短,最長)」だけ)
            let line = ChartSeries(label: nil, values: values, colorRole: .line(1))
            series.append(line)
        }
        let periodLabel = "期間(\(self.parameters.multipleMAShortestPeriod),\(self.parameters.multipleMALongestPeriod))"
        return MainChartContent(legendTitle: "多重平均", series: series,
                                legendItems: [ChartLegendItem(text: periodLabel, colorRole: .line(1))])
    }
}

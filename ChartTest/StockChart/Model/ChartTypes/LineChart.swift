//
//  LineChart.swift
//  ChartTest
//
//  【Model】チャートの種類「折線チャート」の描く内容。
//
//  ローソク足は描かず、終値を線で結ぶ(サブチャートなし)。現在値(最新の足の終値)の位置に破線を引く。
//    国内: 凡例「折線チャート」(線の色)。lineChartContent
//    海外: 終値の線にメインの指標を重ね、凡例は指標のもの。closeLineContent
//

import Foundation

extension ChartContentBuilder {

    /// 折線チャートに描く終値。値が読めなかった足(埋めた足)は nil にして、前後の足を線でつなぐ
    /// (指標の計算には埋めた値を使う)
    private var drawnCloses: [Double?] {
        self.candles.map { candle in
            if candle.isFilled {
                return nil
            }
            return candle.close
        }
    }

    /// 折線チャートの内容(ローソク足は描かず、終値を線で結ぶ。サブチャートなし)
    ///
    ///   凡例:「折線チャート」(線の色)
    ///   現在値(最新の足の終値)の位置に破線を引く
    func lineChartContent() -> ChartContent {
        let main = MainChartContent(
            series: [ChartSeries(label: ChartType.lineChart.legendTitle, values: self.drawnCloses, colorRole: .closeLine)],
            priceStyle: .hidden,
            currentPrice: self.candles.last?.close)
        return ChartContent(candles: self.candles, main: main, sub: nil)
    }

    // MARK: - 終値の折れ線 + 指標(海外指数の横画面の折線チャート)

    /// ローソク足の代わりに終値を折れ線で描き、指定した指標を重ねる内容を作る(サブチャートなし)。
    /// 海外指数の横画面の折線チャートで使う。
    /// 凡例は指標のもの(「移動平均 短期移動平均(5) 長期移動平均(25)」など)で、終値の線は凡例に出さない
    /// - Parameters:
    ///   - indicator: 重ねる指標
    ///   - showsCurrentPrice: 現在値(最新の終値)に破線を引くか(横画面の折線チャートでは引く)
    func closeLineContent(with indicator: MainChartIndicator, showsCurrentPrice: Bool = false) -> ChartContent {
        var main = self.mainContent(for: indicator)
        main.priceStyle = .hidden
        if showsCurrentPrice {
            main.currentPrice = self.candles.last?.close
        }
        // 終値の線は凡例に出さない(label: nil)。指標の線より下に描くよう先頭に入れる
        let closeLine = ChartSeries(label: nil, values: self.drawnCloses, colorRole: .closeLine)
        main.series.insert(closeLine, at: 0)
        return ChartContent(candles: self.candles, main: main, sub: nil)
    }
}

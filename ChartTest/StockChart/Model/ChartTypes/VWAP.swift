//
//  VWAP.swift
//  ChartTest
//
//  【Model】チャートの種類「VWAP：線」「VWAP：点」の描く内容。
//
//  ローソク足は描かず、VWAP の線または点だけを描く(サブチャートなし)。
//    凡例:「VWAP：線」「VWAP：点」(VWAP の色)
//
//  ・API が計算した VWAP(StockCandle.vwap。kVWAP)だけで描き、チャートでは計算しない
//

import Foundation

extension ChartContentBuilder {

    /// VWAP の内容(ローソク足は描かず、VWAP の線または点だけを描く。サブチャートなし)。
    /// API が計算した VWAP(StockCandle.vwap。kVWAP)だけで描き、チャートでは計算しない。
    /// 値が読めなかった足(埋めた足)は描かない(線は前後の足をつなぐ)。
    /// ※ kVWAP が空・0 の足は、0 として描くと線が 0 まで落ちてしまうので描かない(前後をつなぐ)
    /// - Parameters:
    ///   - title: 凡例に出す名前(「VWAP：線」「VWAP：点」。ChartType.legendTitle)
    ///   - style: 線で描くか、点で描くか
    func vwapContent(title: String, style: ChartSeries.Style) -> ChartContent {
        let values: [Double?] = self.candles.map { candle in
            if candle.isFilled {
                return nil
            }
            return candle.vwap
        }
        let main = MainChartContent(
            series: [ChartSeries(label: title, values: values, colorRole: .vwap, style: style)],
            priceStyle: .hidden)

        // API の VWAP が1件もないデータは描けないので、
        // 凡例だけ残して「表示できる情報はありません」と表示する
        let hasValue = values.contains { value in value != nil }
        guard hasValue else {
            return ChartContent(candles: [], main: main, sub: nil)
        }
        return ChartContent(candles: self.candles, main: main, sub: nil)
    }
}

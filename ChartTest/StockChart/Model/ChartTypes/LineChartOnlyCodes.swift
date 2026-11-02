//
//  LineChartOnlyCodes.swift
//  ChartTest
//
//  【Model】折線チャートだけで表示する海外の銘柄コードの一覧(終値しかない指数など)。
//
//  【使い方】
//   1. アプリの起動時に一度だけ、対象の銘柄コードを入れる
//        Swift:        LineChartOnlyCodes.codes = ["XXXX", "YYYY"]
//        Objective-C:  LineChartOnlyCodes.codes = @[@"XXXX", @"YYYY"];
//   2. チャートを表示するときは、データを渡す前に market(海外)と qCode(銘柄コード)を設定する
//        self.chartView.market = IndexMarketOverseasDaily;
//        self.chartView.qCode = qCode;
//
//  【どう表示されるか】(海外の銘柄で、qCode が一覧に入っているとき)
//    ・縦画面: 終値の折線 + 移動平均線(短期・長期)。サブチャート(出来高など)と、現在値の破線は描かない
//    ・横画面: 終値の折線 + 移動平均線。下の帯のチャートの種類のメニューには、折線チャートだけを出す
//  国内(日本株・日本株価指数)の銘柄コードは、一覧に入っていても対象にしない。
//
//  【しくみ】(chartType は書き換えない。描くときだけ折線チャートにする)
//    contains(_:market:) で対象か決める
//      → StockChartView.isLineChartOnly / LandscapeChartViewController.isLineChartOnly
//      → それぞれの effectiveChartType が .lineChart になり、描画(render / reloadChart)はこれを使う
//    縦画面の破線は、StockChartView.render が ChartContentBuilder.content の showsOverseasCurrentPrice で止める
//

import Foundation

@objc final class LineChartOnlyCodes: NSObject {

    /// 折線チャートだけで表示する銘柄コード
    @MainActor @objc static var codes: [String] = []

    /// 折線チャートだけで表示するか(海外指数で、銘柄コードが codes に入っている)
    /// - Parameters:
    ///   - qCode: 銘柄コード(nil = 未設定)
    ///   - market: 指数の種類
    @MainActor static func contains(_ qCode: String?, market: IndexMarket) -> Bool {
        guard !market.isDomestic else {
            return false
        }
        guard let qCode else {
            return false
        }
        return self.codes.contains(qCode)
    }
}

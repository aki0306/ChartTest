//
//  LineChartOnlyCodes.swift
//  ChartTest
//
//  【Model】折線チャートだけで表示する海外の銘柄コードの一覧(終値しかない指数など)。
//
//  アプリの起動時に、呼び出し側が一度だけ設定する。縦画面(StockChartView)・横画面(LandscapeChartViewController)の両方で使う。
//  一覧に入っている銘柄コード(qCode)を海外指数で表示すると:
//    ・縦画面: chartType の値に関係なく、折線チャートで描く(effectiveChartType)
//    ・横画面: 折線チャートで描き、下の帯のチャートの種類のメニューには折線チャートだけを出す
//  国内(日本株・日本株価指数)の銘柄コードは、一覧に入っていても対象にしない。
//
//    Swift:        LineChartOnlyCodes.codes = ["XXXX", "YYYY"]
//    Objective-C:  LineChartOnlyCodes.codes = @[@"XXXX", @"YYYY"];
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

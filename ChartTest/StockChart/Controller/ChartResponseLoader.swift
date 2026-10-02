//
//  ChartResponseLoader.swift
//  ChartTest
//
//  【Controller】API のレスポンス(足種ごと)を、チャートに渡して描画するためのユーティリティ。
//
//  縦画面・横画面に関係なく、どこからでも呼べるよう、画面のクラスから切り出している。
//  描画先には「足種を指定してローソク足を受け取れるもの」(StockCandleReceiving)を渡す。
//
//    | 描画先                         | 使う場面                                        |
//    |--------------------------------|-------------------------------------------------|
//    | StockChartView                 | 既存アプリの縦画面などに、チャートだけを置く場合 |
//    | StockChartViewController       | テクニカル・設定画面付きのチャートを埋め込む場合 |
//    | LandscapeChartViewController   | このアプリの横画面をそのまま使う場合             |
//
//  使い方(Objective-C):
//      NSMutableArray *responseArray = ...;   // 中身は NSDictionary(@{@"date": …, @"open": …, …})
//      [ChartResponseLoader setDailyResponse:responseArray to:landscapeViewController];   // 横画面
//      [ChartResponseLoader setDailyResponse:responseArray to:self.chartView];            // 縦画面(StockChartView)
//
//  使い方(Swift):
//      ChartResponseLoader.setDailyResponse(response, to: chartView)
//
//  ・辞書 → StockCandle の変換(キーの名前・値の型・日付の形式・並べ替え)は StockCandleResponseParser(Model)が行う
//  ・海外指数の場合は、描画先の market を先に .overseas にしておく
//  ・配列に辞書以外の要素が入っていると、受け取った時点でアプリが落ちる(Swift の [[String: Any]] に変換できないため)
//

import Foundation

/// 足種を指定してローソク足を受け取り、描画できるもの。
/// StockChartView・StockChartViewController が対応している。
/// ほかの画面(このアプリの LandscapeChartViewController など)も、setCandles(_:period:) を持っていれば対応させられる
@objc protocol StockCandleReceiving: AnyObject {
    /// 足種を指定してローソク足(日付の古い順)を渡し、描画する
    func setCandles(_ candles: [StockCandle], period: ChartPeriod)
}

extension StockChartView: StockCandleReceiving {}
extension StockChartViewController: StockCandleReceiving {}
// LandscapeChartViewController は StockChart フォルダの外(このアプリの画面)なので、そちらのファイルで対応させている

/// API のレスポンス(辞書の配列)を、足種ごとにチャートへ渡して描画する。
/// Objective-C からも使えるよう NSObject を継承したクラスにしている(インスタンスは作らない)
final class ChartResponseLoader: NSObject {

    /// インスタンスは作らない(static メソッドだけを使う)
    private override init() {
        super.init()
    }

    /// 1分足のレスポンスを渡して描画する(Objective-C: setOneMinuteResponse:to:)
    @objc static func setOneMinuteResponse(_ response: [[String: Any]], to target: StockCandleReceiving) {
        setResponse(response, period: .oneMinute, to: target)
    }

    /// 日中足のレスポンスを渡して描画する(Objective-C: setIntradayResponse:to:)
    @objc static func setIntradayResponse(_ response: [[String: Any]], to target: StockCandleReceiving) {
        setResponse(response, period: .intraday, to: target)
    }

    /// 日足のレスポンスを渡して描画する(Objective-C: setDailyResponse:to:)
    @objc static func setDailyResponse(_ response: [[String: Any]], to target: StockCandleReceiving) {
        setResponse(response, period: .daily, to: target)
    }

    /// 週足のレスポンスを渡して描画する(Objective-C: setWeeklyResponse:to:)
    @objc static func setWeeklyResponse(_ response: [[String: Any]], to target: StockCandleReceiving) {
        setResponse(response, period: .weekly, to: target)
    }

    /// 月足のレスポンスを渡して描画する(Objective-C: setMonthlyResponse:to:)
    @objc static func setMonthlyResponse(_ response: [[String: Any]], to target: StockCandleReceiving) {
        setResponse(response, period: .monthly, to: target)
    }

    /// 足種を指定してレスポンスを渡し、描画する(Objective-C: setResponse:period:to:)。
    /// 足種を引数で切り替えたい場合はこちらを使う
    @objc static func setResponse(_ response: [[String: Any]], period: ChartPeriod, to target: StockCandleReceiving) {
        // 辞書の配列を、日付の古い順のローソク足に変換してから描く(読めない件は飛ばす)
        let candles = StockCandleResponseParser.candles(from: response)
        target.setCandles(candles, period: period)
    }
}

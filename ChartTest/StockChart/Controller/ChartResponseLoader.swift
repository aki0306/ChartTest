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
//    | PortraitChartViewController    | このアプリの縦画面(足種のタブ付き)をそのまま使う場合 |
//
//  使い方(Objective-C):
//      NSMutableArray *responseArray = [XxxChartDataUtil dataArrayFromResponse:…];   // 中身は NSDictionary(@{kTimestamp: …, kStart: …, …})
//      [ChartResponseLoader setDailyResponse:responseArray to:landscapeViewController];   // 横画面
//      [ChartResponseLoader setDailyResponse:responseArray to:self.chartView];            // 縦画面(StockChartView)
//
//  使い方(Swift):
//      ChartResponseLoader.setDailyResponse(response, to: chartView)
//
//  ・辞書 → StockCandle の変換(キーの名前・値の型・日付の形式・並べ替え)は StockCandleResponseParser(Model)が行う
//  ・海外指数の場合は、描画先の market を先に .overseasRealtime / .overseasDaily にしておく
//    (レスポンスの読み方も market で変わる。海外は終値だけを読むので、.domestic のままだと0件になる)
//  ・配列に辞書以外の要素(NSNull など)が入っていても落ちない(その要素は飛ばす。StockCandleResponseParser)
//  ・どのスレッドから呼んでもよい(通信の完了処理から直接呼んでよい)。描画はメインスレッドで行う(MainThread)
//

import Foundation

/// 足種を指定してローソク足を受け取り、描画できるもの。
/// StockChartView・StockChartViewController が対応している。
/// ほかの画面(このアプリの LandscapeChartViewController など)も、market と setCandles(_:period:) を持っていれば対応させられる
@objc protocol StockCandleReceiving: AnyObject {
    /// 指数の種類。レスポンスの読み方(海外は終値だけを読む)を決めるのに使う
    var market: IndexMarket { get }
    /// 足種を指定してローソク足(日付の古い順)を渡し、描画する
    func setCandles(_ candles: [StockCandle], period: ChartPeriod)
}

extension StockChartView: StockCandleReceiving {}
extension StockChartViewController: StockCandleReceiving {}
// LandscapeChartViewController・PortraitChartViewController(このアプリの横画面・縦画面)は、それぞれのファイルで対応させている
// (横画面・縦画面を使わない場合に、その画面のファイルを削除しても、このファイルがビルドできるように)

/// API のレスポンス(辞書の配列)を、足種ごとにチャートへ渡して描画する。
/// Objective-C からも使えるよう NSObject を継承したクラスにしている(インスタンスは作らない)
final class ChartResponseLoader: NSObject {

    /// インスタンスは作らない(static メソッドだけを使う)
    private override init() {
        super.init()
    }

    /// 1分足のレスポンスを渡して描画する(Objective-C: setOneMinuteResponse:to:)
    @objc static func setOneMinuteResponse(_ response: [Any], to target: StockCandleReceiving) {
        self.setResponse(response, period: .oneMinute, to: target)
    }

    /// 日中足のレスポンスを渡して描画する(Objective-C: setIntradayResponse:to:)
    @objc static func setIntradayResponse(_ response: [Any], to target: StockCandleReceiving) {
        self.setResponse(response, period: .intraday, to: target)
    }

    /// 日足のレスポンスを渡して描画する(Objective-C: setDailyResponse:to:)
    @objc static func setDailyResponse(_ response: [Any], to target: StockCandleReceiving) {
        self.setResponse(response, period: .daily, to: target)
    }

    /// 週足のレスポンスを渡して描画する(Objective-C: setWeeklyResponse:to:)
    @objc static func setWeeklyResponse(_ response: [Any], to target: StockCandleReceiving) {
        self.setResponse(response, period: .weekly, to: target)
    }

    /// 月足のレスポンスを渡して描画する(Objective-C: setMonthlyResponse:to:)
    @objc static func setMonthlyResponse(_ response: [Any], to target: StockCandleReceiving) {
        self.setResponse(response, period: .monthly, to: target)
    }

    /// 値のない時間帯の日時を残すか(1分足・日中足だけ。日足・週足・月足は値のない日を並べない)
    private static func keepsEmptyDates(for period: ChartPeriod) -> Bool {
        switch period {
        case .oneMinute, .intraday:
            return true
        case .daily, .weekly, .monthly:
            return false
        }
    }

    /// 足種を指定してレスポンスを渡し、描画する(Objective-C: setResponse:period:to:)。
    /// 足種を引数で切り替えたい場合はこちらを使う
    @objc static func setResponse(_ response: [Any], period: ChartPeriod, to target: StockCandleReceiving) {
        // メインスレッドでなければ、メインスレッドで呼び直す(通信の完了処理から直接呼ばれても安全にする。MainThread)
        guard MainThread.isCurrent(orRetry: { self.setResponse(response, period: period, to: target) }) else { return }

        // 辞書の配列を、日付の古い順のローソク足に変換してから描く(値が読めない件は直前の足の値で埋める)。
        // 海外指数は終値だけが配信されるので、描画先の指数の種類に合わせて読み方を変える
        // 1分足・日中足は、値のない時間帯(寄り付き前・これから来る時間)も X軸に日付を並べるので、日時だけの件も残す
        let candles = StockCandleResponseParser.candles(from: response, market: target.market,
                                                        keepsEmptyDates: self.keepsEmptyDates(for: period))
        target.setCandles(candles, period: period)
    }
}

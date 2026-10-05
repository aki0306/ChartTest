//
//  StockCandleResponseParser.swift
//  ChartTest
//
//  【Model】API のレスポンス(辞書の配列)を、チャートに渡すローソク足(StockCandle)の配列に変換する。
//
//  レスポンスの1件(辞書)の例:
//      ["date": "2026/10/01", "open": "66,000", "high": 66500, "low": 65800, "close": "66300.5", "volume": 2.4e9]
//
//  ・キーの名前と日付の形式は、下の Key / dateFormats にまとめている(仮の値。既存アプリのレスポンスに合わせて直す)
//  ・値は 数値(NSNumber)・文字列("66,000" のようなカンマ付きも可)のどちらでも読める
//  ・日付は Date・文字列(dateFormats のどれかの形式)のどちらでも読める
//  ・日付が読めない件は飛ばす
//  ・値が読めない件は、直前の足の値で埋める(既存アプリの 値がない件の穴埋め処理 と同じ)。
//    ただし、直前の足がない先頭側の件と、値が読めた最後の足より後ろの件は飛ばす
//  ・国内(IndexMarket.domestic)と海外(.overseas)で、読む値が違う(既存アプリの 値のチェック処理(国内は4本値すべて・海外は終値だけ) と同じ)
//
//      | 指数     | 値が読めたとする条件          | 始値・高値・安値 | 出来高                 |
//      |----------|-------------------------------|------------------|------------------------|
//      | 国内     | 始値・高値・安値・終値がすべて | レスポンスの値   | レスポンスの値(なければ 0) |
//      | 海外     | 終値だけ                      | 終値と同じ値     | 0(既存アプリも使っていない) |
//
//  ・レスポンスの並び順に関係なく、日付の古い順に並べ替えて返す
//
//  使い方:
//      Swift       : let candles = StockCandleResponseParser.candles(from: response, market: .overseas)
//      Objective-C : NSArray<StockCandle *> *candles = [StockCandleResponseParser candlesFrom:response market:IndexMarketOverseas];
//      (market を省略した candles(from:) / candlesFrom: は国内として読む)
//

import Foundation

/// API のレスポンス(辞書の配列)を StockCandle の配列に変換する。
/// Objective-C からも使えるよう NSObject を継承したクラスにしている(インスタンスは作らない)
final class StockCandleResponseParser: NSObject {

    // MARK: - レスポンスの形(仮の値。既存アプリのレスポンスに合わせて直す)

    /// レスポンスの1件(辞書)のキー
    enum Key {
        /// 日付・時刻
        static let date = "date"
        /// 始値
        static let open = "open"
        /// 高値
        static let high = "high"
        /// 安値
        static let low = "low"
        /// 終値
        static let close = "close"
        /// 出来高
        static let volume = "volume"
    }

    /// 日付の文字列の形式。上から順に試し、最初に読めた形式を使う。
    /// 1分足・日中足は時刻付き、日足・週足・月足は日付だけの想定
    static let dateFormats = [
        "yyyy/MM/dd HH:mm:ss",
        "yyyy/MM/dd HH:mm",
        "yyyy/MM/dd",
        "yyyyMMddHHmmss",
        "yyyyMMddHHmm",
        "yyyyMMdd",
    ]

    /// インスタンスは作らない(static メソッドだけを使う)
    private override init() {
        super.init()
    }

    // MARK: - 変換

    /// レスポンスの配列を、国内指数として、日付の古い順に並べたローソク足の配列に変換する
    /// - Parameter response: レスポンス(辞書の配列。並び順は問わない)
    @objc(candlesFrom:)
    static func candles(from response: [[String: Any]]) -> [StockCandle] {
        return self.candles(from: response, market: .domestic)
    }

    /// レスポンスの配列を、日付の古い順に並べたローソク足の配列に変換する
    /// - Parameters:
    ///   - response: レスポンス(辞書の配列。並び順は問わない)
    ///   - market: 指数の種類。海外は終値だけを読む
    /// - Returns: 日付の古い順に並べたローソク足(値が読めない件は直前の足の値で埋める)
    @objc(candlesFrom:market:)
    static func candles(from response: [[String: Any]], market: IndexMarket) -> [StockCandle] {
        // 直前の足で埋めるには並び順が決まっている必要があるので、先に日付の古い順に並べ替える
        // (チャートも日付の古い順に並べる必要がある)
        var entries: [(date: Date, item: [String: Any])] = []
        for item in response {
            guard let date = self.date(item[Key.date]) else { continue }  // 日付が読めない件は飛ばす
            entries.append((date: date, item: item))
        }
        entries.sort { first, second in first.date < second.date }

        //   値:   ""    100   ""    105   ""
        //   結果: 飛ばす 100   100   105   飛ばす
        //         ↑ 直前の足がない          ↑ 値が読めた最後の足より後ろ
        var candles: [StockCandle] = []
        var validCount = 0  // 値が読めた最後の足までの本数
        for entry in entries {
            if let candle = self.candle(date: entry.date, item: entry.item, market: market) {
                candles.append(candle)
                validCount = candles.count
                continue
            }
            guard let previous = candles.last else { continue }  // 直前の足がない先頭側の件は飛ばす
            candles.append(self.filledCandle(date: entry.date, item: entry.item, market: market, previous: previous))
        }
        // 値が読めた最後の足より後ろの、埋めただけの足は取り除く
        return Array(candles.prefix(validCount))
    }

    /// レスポンスの1件をローソク足に変換する
    /// - Returns: 値が読めない場合は nil(国内は4本値のどれか、海外は終値)
    private static func candle(date: Date, item: [String: Any], market: IndexMarket) -> StockCandle? {
        guard let close = self.number(item[Key.close]) else { return nil }
        let volume = self.volume(of: item, market: market)

        switch market {
        case .domestic:
            guard let open = self.number(item[Key.open]) else { return nil }
            guard let high = self.number(item[Key.high]) else { return nil }
            guard let low = self.number(item[Key.low]) else { return nil }
            return StockCandle(date: date, open: open, high: high, low: low, close: close, volume: volume)
        case .overseas:
            // 海外は終値だけが配信される。始値・高値・安値も終値にしておく(4本値がそろっていないと足を作れないため)
            return StockCandle(date: date, open: close, high: close, low: close, close: close, volume: volume)
        }
    }

    /// 値が読めない件を、直前の足の4本値で埋めた足にする(日付・出来高はその件のもの)
    private static func filledCandle(date: Date, item: [String: Any], market: IndexMarket,
                                     previous: StockCandle) -> StockCandle {
        return StockCandle(date: date, open: previous.open, high: previous.high, low: previous.low,
                           close: previous.close, volume: self.volume(of: item, market: market))
    }

    /// 出来高。国内は配信されない場合(指数の1分足・日中足など)があるので、読めなければ 0 にする。
    /// 海外は既存アプリも使っていない(空にしている)ので 0 にする
    private static func volume(of item: [String: Any], market: IndexMarket) -> Double {
        switch market {
        case .domestic:
            guard let volume = self.number(item[Key.volume]) else { return 0 }
            return volume
        case .overseas:
            return 0
        }
    }

    // MARK: - 値の読み取り

    /// 数値(NSNumber)・文字列("66,000" などカンマ付きも可)を Double にする。読めない場合は nil
    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        guard let text = value as? String else { return nil }
        // 3桁区切りのカンマと前後の空白を取り除いてから読む("-" や空文字は読めないので nil)
        let cleaned = text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    /// Date・文字列(dateFormats のどれかの形式)を Date にする。読めない場合は nil
    private static func date(_ value: Any?) -> Date? {
        if let date = value as? Date {
            return date
        }
        guard let text = value as? String else { return nil }
        for formatter in self.dateFormatters {
            if let date = formatter.date(from: text) {
                return date
            }
        }
        return nil
    }

    /// dateFormats の形式ごとの DateFormatter(作るのに時間がかかるので、最初に1回だけ作って使い回す)
    private static let dateFormatters: [DateFormatter] = dateFormats.map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")  // 端末の設定(12時間表示など)に左右されないようにする
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format
        return formatter
    }
}

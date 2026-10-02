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
//  ・日付・始値・高値・安値・終値のどれかが読めない件(空・"-" など)は飛ばす。出来高がない件は 0 にする
//  ・レスポンスの並び順に関係なく、日付の古い順に並べ替えて返す
//
//  使い方:
//      Swift       : let candles = StockCandleResponseParser.candles(from: response)
//      Objective-C : NSArray<StockCandle *> *candles = [StockCandleResponseParser candlesFrom:response];
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

    /// レスポンスの配列を、日付の古い順に並べたローソク足の配列に変換する
    /// - Parameter response: レスポンス(辞書の配列。並び順は問わない)
    /// - Returns: 日付の古い順に並べたローソク足(読めない件は含まない)
    @objc(candlesFrom:)
    static func candles(from response: [[String: Any]]) -> [StockCandle] {
        var candles: [StockCandle] = []
        for item in response {
            guard let candle = candle(from: item) else { continue }  // 読めない件は飛ばす
            candles.append(candle)
        }
        // チャートは日付の古い順に並べる必要があるので、レスポンスの並び順に関係なく並べ替える
        return candles.sorted { first, second in first.date < second.date }
    }

    /// レスポンスの1件をローソク足に変換する
    /// - Returns: 日付・始値・高値・安値・終値のどれかが読めない場合は nil
    static func candle(from item: [String: Any]) -> StockCandle? {
        guard let date = date(item[Key.date]) else { return nil }
        guard let open = number(item[Key.open]) else { return nil }
        guard let high = number(item[Key.high]) else { return nil }
        guard let low = number(item[Key.low]) else { return nil }
        guard let close = number(item[Key.close]) else { return nil }

        // 出来高は配信されない場合(指数の1分足・日中足など)があるので、読めなければ 0 にする
        var volume = 0.0
        if let value = number(item[Key.volume]) {
            volume = value
        }
        return StockCandle(date: date, open: open, high: high, low: low, close: close, volume: volume)
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
        for formatter in dateFormatters {
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

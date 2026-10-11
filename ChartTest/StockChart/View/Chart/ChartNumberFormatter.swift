//
//  ChartNumberFormatter.swift
//  ChartTest
//
//  【View】価格・指標の値などの数値を文字にする書式。
//  軸ラベル(ChartAxisFormatters.swift)・凡例・4本値の枠・最高値と最安値・下の帯の現在値など、
//  チャートの部品で数値を文字にするときは、すべてここを使う。
//

import Foundation

/// チャートで使う数値の書式をまとめたもの。価格などを文字にするときは、ここのメソッドを使う
/// (画面ごとに書式を作ると、表示がそろわなくなるため)
///
///   | 用途                         | メソッド                            | 例(値 68309.456)    |
///   |------------------------------|-------------------------------------|----------------------|
///   | 価格(4本値の枠・十字線の値) | price(_:)                           | 68,309.46            |
///   | 最高値・最安値               | shortPrice(_:)                      | 68,309.46(60448.9 なら 60,448.9。末尾の 0 は省く) |
///   | 下の帯の現在値               | plainPrice(_:)                      | 68309.46(3桁区切りなし) |
///   | 4本値の枠                    | plainValue(_:)                      | 68309.46(3桁区切りなし・末尾の 0 は省く) |
///   | 指標の値(サブチャート)     | string(_:fractionDigits:suffix:)    | 12.5%                |
///
/// NumberFormatter は作るのに時間がかかるので、書式ごとに1回だけ作って使い回す
/// (十字線の値・最高値と最安値は、指でなぞる・スクロールするたびに文字にするため)。
/// 画面の部品からだけ使う(メインスレッド)
enum ChartNumberFormatter {

    // MARK: 用途ごとの書式

    /// 価格: 3桁区切り・小数2桁にそろえる(例: 68,309.46、66,000.00)
    @MainActor
    static func price(_ value: Double) -> String {
        return self.string(value, fractionDigits: 2, minimumFractionDigits: 2)
    }

    /// 価格(短い形): 3桁区切り・小数は最大2桁で、末尾の 0 は省く(例: 60,448.9、66,000)
    @MainActor
    static func shortPrice(_ value: Double) -> String {
        return self.string(value, fractionDigits: 2)
    }

    /// 価格(区切りなし): 3桁区切りなし・小数2桁にそろえる(例: 68309.46)
    @MainActor
    static func plainPrice(_ value: Double) -> String {
        return self.string(value, fractionDigits: 2, minimumFractionDigits: 2, usesGroupingSeparator: false)
    }

    /// 3桁区切りなし・小数は必要な桁だけ(最大2桁)の値(例: 6230 → 「6230」、5519.11 → 「5519.11」)。4本値の枠に使う
    static func plainValue(_ value: Double) -> String {
        return self.string(value, fractionDigits: 2, usesGroupingSeparator: false)
    }

    /// 指定した書式で数値を文字にする
    /// - Parameters:
    ///   - value: 文字にする値
    ///   - fractionDigits: 小数点以下の最大桁数(不要な 0 は表示しない)
    ///   - minimumFractionDigits: 小数点以下の最小桁数(桁をそろえる場合に指定)
    ///   - suffix: 末尾に付ける文字(「%」など)
    ///   - usesGroupingSeparator: 3桁区切りのカンマを付けるか
    @MainActor
    static func string(_ value: Double, fractionDigits: Int, minimumFractionDigits: Int = 0,
                       suffix: String = "", usesGroupingSeparator: Bool = true) -> String {
        let formatter = self.cachedFormatter(fractionDigits: fractionDigits,
                                             minimumFractionDigits: minimumFractionDigits,
                                             suffix: suffix, usesGroupingSeparator: usesGroupingSeparator)
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }

    // MARK: フォーマッタを作る

    /// 3桁カンマ区切りのフォーマッタを新しく作る(例: 60660.9 → 「60,660.9」)。
    /// 軸ラベル(ChartAxisValueFormatter)のように、フォーマッタを持ち続ける部品で使う
    /// - Parameters:
    ///   - fractionDigits: 小数点以下の最大桁数(不要な 0 は表示しない)
    ///   - suffix: 末尾に付ける文字(「%」など)
    ///   - minimumFractionDigits: 小数点以下の最小桁数(価格を「60,660.90」のように桁を揃えて表示する場合に指定)
    ///   - usesGroupingSeparator: 3桁区切りのカンマを付けるか
    static func make(fractionDigits: Int, suffix: String = "", minimumFractionDigits: Int = 0,
                     usesGroupingSeparator: Bool = true) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatter.positiveSuffix = suffix
        formatter.negativeSuffix = suffix
        formatter.usesGroupingSeparator = usesGroupingSeparator
        return formatter
    }

    // MARK: 使い回し

    /// 作ったフォーマッタ(書式ごと)。キーは書式の組み合わせを文字にしたもの
    @MainActor
    private static var formatterCache: [String: NumberFormatter] = [:]

    /// 指定した書式のフォーマッタを返す。まだなければ作って覚えておく
    @MainActor
    private static func cachedFormatter(fractionDigits: Int, minimumFractionDigits: Int,
                                        suffix: String, usesGroupingSeparator: Bool) -> NumberFormatter {
        let key = "\(fractionDigits)/\(minimumFractionDigits)/\(suffix)/\(usesGroupingSeparator)"
        if let formatter = self.formatterCache[key] {
            return formatter
        }
        let formatter = self.make(fractionDigits: fractionDigits, suffix: suffix,
                                  minimumFractionDigits: minimumFractionDigits,
                                  usesGroupingSeparator: usesGroupingSeparator)
        self.formatterCache[key] = formatter
        return formatter
    }
}

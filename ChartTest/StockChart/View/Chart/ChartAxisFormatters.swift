//
//  ChartAxisFormatters.swift
//  ChartTest
//
//  【View】チャートの軸ラベルや値の表示に使う書式。
//
//  ・DateAxisValueFormatter  … X軸: 何本目か(0, 1, 2, …)→ 日付の文字列(「7/14」など)
//  ・ChartAxisValueFormatter … Y軸: 数値 → 3桁カンマ区切りの文字列。重なるラベルは空文字にして隠す
//  ・ChartNumberFormatter    … 数値の書式(NumberFormatter)を作る
//
//  DGCharts は軸ラベルを描くとき、AxisValueFormatter の stringForValue を呼んで文字列を受け取る。
//

import Foundation
import DGCharts

// MARK: - X軸(インデックス → 日付)

/// X軸の値(データのインデックス)を日付文字列に変換するフォーマッタ
final class DateAxisValueFormatter: AxisValueFormatter {

    /// インデックスに対応する日付の配列
    private let dates: [Date]
    /// dates の先頭の日付のインデックス(値のある足より前に日付を並べる場合は負の値)
    private let firstIndex: Int
    /// 日付 → 文字列の変換に使うフォーマッタ
    private let formatter: DateFormatter

    /// - Parameters:
    ///   - dates: X軸に並ぶ日付(古い順)
    ///   - firstIndex: dates の先頭の日付のインデックス(例: 値のある足より前に2本並べる場合は -2)
    ///   - formatter: 日付 → 文字列の変換に使うフォーマッタ
    init(dates: [Date], firstIndex: Int = 0, formatter: DateFormatter) {
        self.dates = dates
        self.firstIndex = firstIndex
        self.formatter = formatter
    }

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let index = Int(value.rounded()) - self.firstIndex
        // 範囲外(前後の余白部分・一目均衡表の先行スパンの先)は空文字
        guard self.dates.indices.contains(index) else { return "" }
        return self.formatter.string(from: self.dates[index])
    }
}

// MARK: - Y軸(数値。端のラベルを隠す)

/// 数値を書式化し、軸の下端付近や指定値より上のラベルを空文字にするフォーマッタ。
///   ・下端付近: メインチャートの最下段ラベルが、区切り線を挟んでサブチャートの最上段ラベルと重なるのを防ぐ
///   ・指定値より上: RSI などで凡例用に 100 より上へ広げた部分のラベルを出さない
final class ChartAxisValueFormatter: AxisValueFormatter {

    /// 数値 → 文字列の変換に使うフォーマッタ
    private let formatter: NumberFormatter
    /// 軸の値幅に対して、下端からこの割合以内にあるラベルを隠す(0 なら隠さない)
    private let hiddenBottomRatio: Double
    /// この値より大きいラベルを隠す(nil なら隠さない)
    private let hiddenAbove: Double?

    init(formatter: NumberFormatter, hiddenBottomRatio: Double, hiddenAbove: Double?) {
        self.formatter = formatter
        self.hiddenBottomRatio = hiddenBottomRatio
        self.hiddenAbove = hiddenAbove
    }

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        if self.isNearBottom(value, axis: axis) {
            return ""
        }
        if self.isAboveHiddenLimit(value) {
            return ""
        }
        return self.formatter.string(from: NSNumber(value: value)) ?? ""
    }

    /// 軸の下端付近(下から hiddenBottomRatio の割合以内)の値か
    private func isNearBottom(_ value: Double, axis: AxisBase?) -> Bool {
        guard let axis else { return false }
        guard axis.axisRange > 0 else { return false }
        // 軸の下端を 0、上端を 1 としたときの位置
        let positionFromBottom = (value - axis.axisMinimum) / axis.axisRange
        return positionFromBottom < self.hiddenBottomRatio
    }

    /// hiddenAbove より大きい値か。
    /// 小数の誤差で 100 が 100.0000001 などになっても隠れないよう、少しだけ余裕を持たせて比べる
    private func isAboveHiddenLimit(_ value: Double) -> Bool {
        guard let hiddenAbove else { return false }
        return value > hiddenAbove + 1e-9
    }
}

// MARK: - 数値の書式

/// チャートで使う数値の書式をまとめたもの。価格などを文字にするときは、ここのメソッドを使う
/// (画面ごとに書式を作ると、表示がそろわなくなるため)
///
///   | 用途                         | メソッド                            | 例(値 68309.456)    |
///   |------------------------------|-------------------------------------|----------------------|
///   | 価格(4本値の枠・十字線の値) | price(_:)                           | 68,309.46            |
///   | 最高値・最安値               | shortPrice(_:)                      | 68,309.46(60448.9 なら 60,448.9。末尾の 0 は省く) |
///   | 下の帯の現在値               | plainPrice(_:)                      | 68309.46(3桁区切りなし) |
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

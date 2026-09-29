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
    /// 日付 → 文字列の変換に使うフォーマッタ
    private let formatter: DateFormatter

    init(dates: [Date], formatter: DateFormatter) {
        self.dates = dates
        self.formatter = formatter
    }

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let index = Int(value.rounded())
        // 範囲外(前後の余白部分・一目均衡表の先行スパンの先)は空文字
        guard dates.indices.contains(index) else { return "" }
        return formatter.string(from: dates[index])
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
        // 下端付近のラベルを隠す
        if let axis, axis.axisRange > 0 {
            // 軸の下端を 0、上端を 1 としたときの位置
            let positionFromBottom = (value - axis.axisMinimum) / axis.axisRange
            if positionFromBottom < hiddenBottomRatio {
                return ""
            }
        }

        // 指定値より上のラベルを隠す(小数の誤差で 100.0000001 などになっても隠れないよう、少しだけ余裕を持たせる)
        if let hiddenAbove, value > hiddenAbove + 1e-9 {
            return ""
        }

        return formatter.string(from: NSNumber(value: value)) ?? ""
    }
}

// MARK: - 数値の書式

/// 3桁カンマ区切りの数値の書式を作る
enum ChartNumberFormatter {

    /// 3桁カンマ区切りのフォーマッタを作る(例: 60660.9 → 「60,660.9」)
    /// - Parameters:
    ///   - fractionDigits: 小数点以下の最大桁数(不要な 0 は表示しない)
    ///   - suffix: 末尾に付ける文字(「%」など)
    ///   - minimumFractionDigits: 小数点以下の最小桁数(価格を「60,660.90」のように桁を揃えて表示する場合に指定)
    static func make(fractionDigits: Int, suffix: String = "", minimumFractionDigits: Int = 0) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatter.positiveSuffix = suffix
        formatter.negativeSuffix = suffix
        return formatter
    }
}

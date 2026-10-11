//
//  ChartAxisFormatters.swift
//  ChartTest
//
//  【View】チャートの軸ラベルに使う書式。
//
//  ・DateAxisValueFormatter  … X軸: 何本目か(0, 1, 2, …)→ 日付の文字列(「7/14」など)
//  ・ChartAxisValueFormatter … Y軸: 数値 → 3桁カンマ区切りの文字列。重なるラベルは空文字にして隠す
//
//  数値を文字にする書式そのもの(ChartNumberFormatter)は ChartNumberFormatter.swift。
//
//  DGCharts は軸ラベルを描くとき、AxisValueFormatter の stringForValue を呼んで文字列を受け取る。
//

import Foundation
import DGCharts

// MARK: - X軸(インデックス → 日付)

/// X軸の値(データのインデックス)を日付文字列に変換するフォーマッタ。
/// X軸の描画処理(LatestAlignedXAxisRenderer。アクター分離なし)から widestSampleText を読むので、
/// このプロジェクトの既定(MainActor)から外して nonisolated にしている
nonisolated final class DateAxisValueFormatter: AxisValueFormatter {

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

    /// 一番長い日付の例。「1970/10/10 10:10」をこの書式で表した文字
    /// (「10/10」「70/10/10」「1970/10」「10:10」。数字がすべて2桁なので、一番長くなる)
    var widestSampleText: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = self.formatter.timeZone
        let components = DateComponents(year: 1970, month: 10, day: 10, hour: 10, minute: 10)
        guard let date = calendar.date(from: components) else {
            return ""
        }
        return self.formatter.string(from: date)
    }

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let index = Int(value.rounded()) - self.firstIndex
        // 範囲外(前後の余白部分・一目均衡表の先行スパンの先)は空文字
        guard self.dates.indices.contains(index) else {
            return ""
        }
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
        guard let axis else {
            return false
        }
        guard axis.axisRange > 0 else {
            return false
        }
        // 軸の下端を 0、上端を 1 としたときの位置
        let positionFromBottom = (value - axis.axisMinimum) / axis.axisRange
        return positionFromBottom < self.hiddenBottomRatio
    }

    /// hiddenAbove より大きい値か。
    /// 小数の誤差で 100 が 100.0000001 などになっても隠れないよう、少しだけ余裕を持たせて比べる
    private func isAboveHiddenLimit(_ value: Double) -> Bool {
        guard let hiddenAbove else {
            return false
        }
        return value > hiddenAbove + 1e-9
    }
}

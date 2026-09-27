//
//  AlignedYAxisRenderer.swift
//  ChartTest
//
//  【View】Y軸ラベル(価格・指標の値)の並べ方を調整する描画処理。
//
//  DGCharts 標準では、右側のY軸ラベルはすべて左揃えで、グリッド線の高さに文字の中心を合わせて描かれる。
//  このクラスでは、次の2つを切り替えられるようにしている(StockChartStyle で指定)。
//
//  ・centersLabels(中央揃え): 一番長いラベルの幅の中で、各ラベルを中央に置く
//
//        4,000,000,000          4,000,000,000
//        3,000,000,000          3,000,000,000
//        0                ->          0
//        (左揃え)               (中央揃え)
//
//  ・keepsLabelsInside(枠内に収める): 描画領域の下端からはみ出すラベルを内側にずらして描き、上端からはみ出すラベルは描かない
//    (サブチャートの「0」が X軸ラベルの領域にはみ出さないようにする)
//
//  ※ 継承元の YAxisRenderer はアクター分離なしで宣言されているため、クラスを nonisolated にして
//    override できるようにしている(LatestAlignedXAxisRenderer と同じ)。描画は常にメインスレッドで行われる。
//

import UIKit
import DGCharts

nonisolated final class AlignedYAxisRenderer: YAxisRenderer {

    /// 一番長いラベルの幅の中で、各ラベルを中央揃えにするか(false なら DGCharts 標準の左揃え)。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var centersLabels = false
    /// 描画領域の上端・下端からはみ出すラベルを、内側にずらして描くか。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var keepsLabelsInside = false

    /// Y軸ラベルを描く。DGCharts が描画のたびに呼ぶ
    /// - Parameters:
    ///   - fixedPosition: ラベルの左端の X(描画領域の右端 + xOffset)
    ///   - positions: 各ラベルのグリッド線の位置
    ///   - offset: グリッド線の Y から、文字の上端までのずれ
    ///   - textAlign: 揃え方(右のY軸を外側に描く場合は左揃え)
    override func drawYLabels(context: CGContext, fixedPosition: CGFloat, positions: [CGPoint],
                              offset: CGFloat, textAlign: TextAlignment) {
        // どちらの調整もしない場合は、DGCharts 標準の描き方にする
        let needsAdjustment = self.centersLabels || self.keepsLabelsInside
        if !needsAdjustment {
            super.drawYLabels(context: context, fixedPosition: fixedPosition, positions: positions,
                              offset: offset, textAlign: textAlign)
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: self.axis.labelFont,
            .foregroundColor: self.axis.labelTextColor,
        ]

        // 描くラベルの範囲(DGCharts 標準と同じく、一番下・一番上のラベルを描かない設定に従う)
        var firstEntry = 0
        if !self.axis.isDrawBottomYLabelEntryEnabled {
            firstEntry = 1
        }
        var endEntry = self.axis.entryCount  // この番号の手前まで描く
        if !self.axis.isDrawTopYLabelEntryEnabled {
            endEntry = self.axis.entryCount - 1
        }
        guard firstEntry < endEntry else {
            return
        }
        let entries = Array(firstEntry..<endEntry)

        // 各ラベルの文字と幅(中央揃えでは、一番長いラベルの幅を基準にする)
        let texts = entries.map { entry in self.axis.getFormattedLabel(entry) }
        let widths = texts.map { text in (text as NSString).size(withAttributes: attributes).width }
        let maxWidth = widths.max() ?? 0
        let lineHeight = self.axis.labelFont.lineHeight

        for (labelNumber, entry) in entries.enumerated() {
            // 横位置: 中央揃えなら、一番長いラベルの幅の中で中央に置く
            var x = fixedPosition + self.axis.labelXOffset
            if self.centersLabels {
                x += (maxWidth - widths[labelNumber]) / 2
            }

            // 縦位置: 文字の上端。枠内に収める場合は、下端からはみ出すラベル(サブチャートの「0」など)を内側にずらす。
            // 上端からはみ出すラベルは描かない(内側にずらすと、すぐ下のラベルとの間隔が詰まって見えるため)
            //
            //   ずらした場合            描かない場合
            //   80,000 ← 上端に寄せる    (描かない)
            //   70,000 ← 間隔が狭い      70,000
            //   60,000                  60,000
            var y = positions[entry].y + offset
            if self.keepsLabelsInside {
                if y < self.viewPortHandler.contentTop {
                    continue
                }
                y = min(y, self.viewPortHandler.contentBottom - lineHeight)  // 下端からはみ出さない
            }

            context.drawText(texts[labelNumber], at: CGPoint(x: x, y: y), align: .left, attributes: attributes)
        }
    }

    // MARK: - 目盛りの値

    /// Y軸の目盛り(ラベル・グリッド線)の値を決める。DGCharts が表示範囲が変わるたびに呼ぶ。
    ///
    /// DGCharts の計算は、間隔をきりのいい値(10,000,000 など)にするときに浮動小数点の誤差で 1 小さくなることがある
    /// (pow(10, 6) を丸めた値が 999,999.99… になり、floor(10 × 999,999.99…) = 9,999,999 になる)。
    /// そのままだと、出来高の目盛りが 9,999,999・19,999,998・29,999,997 のような半端な値になるので、
    /// 間隔を有効数字2桁に丸め直し、目盛りをその倍数にそろえる
    ///
    ///   DGCharts の計算: 0  9,999,999  19,999,998  29,999,997
    ///   丸め直した後  : 0 10,000,000  20,000,000  30,000,000
    override func computeAxisValues(min: Double, max: Double) {
        super.computeAxisValues(min: min, max: max)
        self.roundAxisEntries()
    }

    /// 目盛りの値を、きりのいい間隔の倍数に丸め直す
    private func roundAxisEntries() {
        // ラベルの数を強制している場合(MACD など)は、目盛りが間隔の倍数ではない(下端から等間隔)ので、そのままにする
        if self.axis.isForceLabelsEnabled {
            return
        }
        let entries = self.axis.entries
        guard entries.count >= 2 else {
            return
        }

        let interval = Self.roundedToTwoSignificantDigits(entries[1] - entries[0])
        guard interval > 0 else {
            return
        }

        self.axis.entries = entries.map { entry in (entry / interval).rounded() * interval }
        if self.axis.centerAxisLabelsEnabled {
            self.axis.centeredEntries = self.axis.entries.map { entry in entry + interval / 2 }
        }
    }

    /// 値を有効数字2桁に丸める(例: 9,999,999 → 10,000,000、2,499,999 → 2,500,000、0.0999 → 0.1)
    private static func roundedToTwoSignificantDigits(_ value: Double) -> Double {
        guard value > 0 else {
            return value
        }
        let magnitude = pow(10.0, floor(log10(value)) - 1)
        return (value / magnitude).rounded() * magnitude
    }
}

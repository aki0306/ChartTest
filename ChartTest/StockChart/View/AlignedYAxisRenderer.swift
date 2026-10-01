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
//  ・keepsLabelsInside(枠内に収める): 描画領域の上端・下端からはみ出すラベルを、内側にずらして描く
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
        guard centersLabels || keepsLabelsInside else {
            super.drawYLabels(context: context, fixedPosition: fixedPosition, positions: positions,
                              offset: offset, textAlign: textAlign)
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: axis.labelFont,
            .foregroundColor: axis.labelTextColor,
        ]

        // 描くラベル(DGCharts 標準と同じく、上端・下端のラベルを描かない設定に従う)
        var from = 0
        if !axis.isDrawBottomYLabelEntryEnabled {
            from = 1
        }
        var to = axis.entryCount
        if !axis.isDrawTopYLabelEntryEnabled {
            to = axis.entryCount - 1
        }
        guard from < to else { return }

        let texts = (from..<to).map { index in axis.getFormattedLabel(index) }
        let widths = texts.map { text in (text as NSString).size(withAttributes: attributes).width }
        let maxWidth = widths.max() ?? 0
        let lineHeight = axis.labelFont.lineHeight

        for (i, index) in (from..<to).enumerated() {
            // 横位置: 中央揃えなら、一番長いラベルの幅の中で中央に置く
            var x = fixedPosition + axis.labelXOffset
            if centersLabels {
                x += (maxWidth - widths[i]) / 2
            }

            // 縦位置: 文字の上端。枠内に収める場合は、上端・下端からはみ出さないようにずらす
            var y = positions[index].y + offset
            if keepsLabelsInside {
                y = min(y, viewPortHandler.contentBottom - lineHeight)
                y = max(y, viewPortHandler.contentTop)
            }

            context.drawText(texts[i], at: CGPoint(x: x, y: y), align: .left, attributes: attributes)
        }
    }
}

//
//  CloudCombinedRenderer.swift
//  ChartTest
//
//  【View】一目均衡表の「雲」(先行スパン1 と 先行スパン2 の間)を塗りつぶすためのレンダラー。
//
//  DGCharts の線の塗りつぶし(fill)は「線と固定の高さの間」しか塗れず、
//  2本の線の間を塗ることができない。そのため CombinedChartRenderer を継承し、
//  通常の描画の前に雲の多角形を自前で塗っている。
//
//  ※ このプロジェクトは既定のアクター分離が MainActor だが、継承元の CombinedChartRenderer は
//    アクター分離なしで宣言されているため、クラスを nonisolated にして override できるようにしている。
//    描画は常にメインスレッドで行われるので、チャート(UIView)へのアクセスは MainActor.assumeIsolated で行う。
//

import UIKit
import DGCharts

nonisolated final class CloudCombinedRenderer: CombinedChartRenderer {

    /// 雲の描画に必要な情報
    struct Cloud {
        /// 先行スパン1(X軸のインデックスごとの値)
        let spanA: [Double?]
        /// 先行スパン2(X軸のインデックスごとの値)
        let spanB: [Double?]
        /// 先行スパン1 が上にあるとき(陽雲)の色
        let upColor: UIColor
        /// 先行スパン2 が上にあるとき(陰雲)の色
        let downColor: UIColor
    }

    /// 描画する雲。nil の場合は何も塗らない(一目均衡表以外)。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var cloud: Cloud?

    override func drawData(context: CGContext) {
        // 雲はローソク足や線の下に来るよう、通常の描画より先に塗る
        if let cloud, let chart {
            MainActor.assumeIsolated {
                drawCloud(cloud, chart: chart, context: context)
            }
        }
        super.drawData(context: context)
    }

    /// 隣り合う2本の間ごとに、先行スパン1/2 で囲まれた多角形を塗る
    @MainActor
    private func drawCloud(_ cloud: Cloud, chart: CombinedChartView, context: CGContext) {
        let transformer = chart.getTransformer(forAxis: .right)
        let count = min(cloud.spanA.count, cloud.spanB.count)
        guard count >= 2 else { return }

        // 描画は表示範囲(+前後1本)のみに絞る
        let from = max(0, Int(chart.lowestVisibleX.rounded(.down)) - 1)
        let to = min(count - 1, Int(chart.highestVisibleX.rounded(.up)) + 1)
        guard from < to else { return }

        context.saveGState()
        defer { context.restoreGState() }
        // 描画領域の外(軸ラベル部分など)にはみ出さないようにクリップする
        context.clip(to: viewPortHandler.contentRect)

        /// チャート座標の点列を画面座標に変換して塗りつぶす
        func fill(_ points: [(x: Double, y: Double)], color: UIColor) {
            let pixels = points.map { transformer.pixelForValues(x: $0.x, y: $0.y) }
            guard let first = pixels.first else { return }
            context.beginPath()
            context.move(to: first)
            pixels.dropFirst().forEach { context.addLine(to: $0) }
            context.closePath()
            context.setFillColor(color.cgColor)
            context.fillPath()
        }

        for i in from..<to {
            guard let a0 = cloud.spanA[i], let b0 = cloud.spanB[i],
                  let a1 = cloud.spanA[i + 1], let b1 = cloud.spanB[i + 1] else { continue }

            // 各位置での (先行スパン1 − 先行スパン2)。正なら陽雲、負なら陰雲
            let d0 = a0 - b0
            let d1 = a1 - b1
            let x0 = Double(i)
            let x1 = Double(i + 1)

            if d0 * d1 >= 0 {
                // 区間内で上下が入れ替わらない → 四角形1つで塗る
                let color = (d0 + d1) >= 0 ? cloud.upColor : cloud.downColor
                fill([(x0, a0), (x1, a1), (x1, b1), (x0, b0)], color: color)
            } else {
                // 区間内で線が交差する → 交点で分割し、三角形2つで塗る
                let t = d0 / (d0 - d1)  // 交点の位置(0〜1)
                let crossX = x0 + t
                let crossY = a0 + (a1 - a0) * t
                fill([(x0, a0), (crossX, crossY), (x0, b0)], color: d0 > 0 ? cloud.upColor : cloud.downColor)
                fill([(crossX, crossY), (x1, a1), (x1, b1)], color: d1 > 0 ? cloud.upColor : cloud.downColor)
            }
        }
    }
}

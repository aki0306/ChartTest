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
        if let cloud {
            if let chart {
                MainActor.assumeIsolated {
                    self.drawCloud(cloud, chart: chart, context: context)
                }
            }
        }
        super.drawData(context: context)
    }

    /// 隣り合う2本の間ごとに、先行スパン1/2 で囲まれた多角形を塗る
    @MainActor
    private func drawCloud(_ cloud: Cloud, chart: CombinedChartView, context: CGContext) {
        let transformer = chart.getTransformer(forAxis: .right)
        let count = min(cloud.spanA.count, cloud.spanB.count)
        guard count >= 2 else {
            return
        }

        // 描画は表示範囲(+前後1本)のみに絞る
        let from = max(0, Int(chart.lowestVisibleX.rounded(.down)) - 1)
        let to = min(count - 1, Int(chart.highestVisibleX.rounded(.up)) + 1)
        guard from < to else {
            return
        }

        context.saveGState()
        defer {
            context.restoreGState()
        }
        // 描画領域の外(軸ラベル部分など)にはみ出さないようにクリップする
        context.clip(to: self.viewPortHandler.contentRect)

        /// チャート座標の点列を画面座標に変換して塗りつぶす
        func fill(_ points: [(x: Double, y: Double)], color: UIColor) {
            // チャートの値(X = 何本目か、Y = 価格)→ 画面上の座標
            let pixels = points.map { point in transformer.pixelForValues(x: point.x, y: point.y) }
            guard let first = pixels.first else {
                return
            }
            context.beginPath()
            context.move(to: first)
            for pixel in pixels.dropFirst() {
                context.addLine(to: pixel)
            }
            context.closePath()
            context.setFillColor(color.cgColor)
            context.fillPath()
        }

        /// (先行スパン1 − 先行スパン2) の値から雲の色を決める。0 以上なら陽雲、負なら陰雲
        func color(forDifference difference: Double) -> UIColor {
            if difference >= 0 {
                return cloud.upColor
            } else {
                return cloud.downColor
            }
        }

        // i 本目と i+1 本目の間(区間)ごとに塗る
        //
        //   spanA ●───────●          ← 先行スパン1
        //         │ 雲    │
        //   spanB ●───────●          ← 先行スパン2
        //       i 本目   i+1 本目
        for i in from..<to {
            // 区間の左端(i 本目)と右端(i+1 本目)の、先行スパン1/2 の値。どれかが nil なら塗らない
            guard let spanALeft = cloud.spanA[i] else {
                continue
            }
            guard let spanBLeft = cloud.spanB[i] else {
                continue
            }
            guard let spanARight = cloud.spanA[i + 1] else {
                continue
            }
            guard let spanBRight = cloud.spanB[i + 1] else {
                continue
            }

            // 左端・右端での (先行スパン1 − 先行スパン2)。正なら陽雲、負なら陰雲
            let differenceLeft = spanALeft - spanBLeft
            let differenceRight = spanARight - spanBRight
            let xLeft = Double(i)
            let xRight = Double(i + 1)

            // 左端と右端で差の符号が同じ(積が 0 以上)なら、区間内で線は交差しない
            let crossesInside = differenceLeft * differenceRight < 0

            if !crossesInside {
                // 区間内で上下が入れ替わらない → 四角形1つで塗る。
                // 色は左右の差の和の符号で決める(左右は同じ符号か、どちらかが 0。
                // 片方だけ 0 のときも、もう片方の符号で陽雲・陰雲が決まるようにするため)
                let quad = [(xLeft, spanALeft), (xRight, spanARight), (xRight, spanBRight), (xLeft, spanBLeft)]
                fill(quad, color: color(forDifference: differenceLeft + differenceRight))
            } else {
                // 区間内で線が交差する → 交点で分割し、三角形2つで塗る
                //   交点は左端から区間幅の crossRatio(0〜1)の位置。差が直線的に変わるとして、差が 0 になる位置を求める
                let crossRatio = differenceLeft / (differenceLeft - differenceRight)
                let crossX = xLeft + crossRatio
                let crossY = spanALeft + (spanARight - spanALeft) * crossRatio

                // (交差する区間では左右の差は 0 にならず、必ず正負が逆になる)
                let leftTriangle = [(xLeft, spanALeft), (crossX, crossY), (xLeft, spanBLeft)]
                let rightTriangle = [(crossX, crossY), (xRight, spanARight), (xRight, spanBRight)]
                fill(leftTriangle, color: color(forDifference: differenceLeft))
                fill(rightTriangle, color: color(forDifference: differenceRight))
            }
        }
    }
}

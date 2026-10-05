//
//  StockChartView+HighLowLabels.swift
//  ChartTest
//
//  【View】表示中の範囲の最高値・最安値を、その足の上・下に表示する。
//
//                69,608.24          ← 最高値: 一番高い高値の足の、ヒゲの上端のすぐ上(足の中央に合わせる)
//                    │
//                   ┌┴┐
//                   └┬┘
//      ┌┐            │
//      ││
//      └┘
//      │
//   60,448.9                         ← 最安値: 一番安い安値の足の、ヒゲの下端のすぐ下
//
//  ・style.showsHighLowLabels が true で、ローソク足のときだけ表示する
//  ・スクロール・ズームで表示範囲が変わるたびに、値と位置を決め直す(updateAxisRanges から呼ばれる)
//  ・文字が足と重ならないよう、Y軸の上下に文字の高さ分の余白を空けている(updateMainAxisRange)
//  ・数値は3桁区切り・小数は最大2桁(末尾の 0 は省く。例: 60,448.9)
//

import UIKit
import DGCharts

extension StockChartView {

    /// 足と最高値・最安値の文字の間隔
    var highLowLabelGap: CGFloat { 2 }

    /// 最高値・最安値の文字を表示するか(設定がオンで、ローソク足を描いているとき)
    var drawsHighLowLabels: Bool {
        guard self.style.showsHighLowLabels else { return false }
        return self.mainContent.priceStyle == .candles
    }

    /// 指定した範囲の足の最高値・最安値を探して、その足の上・下に文字を置く
    /// - Parameters:
    ///   - from: 表示範囲の先頭インデックス
    ///   - to: 表示範囲の末尾インデックス
    func updateHighLowLabels(from: Int, to: Int) {
        guard let (highIndex, lowIndex) = self.highLowIndexes(from: from, to: to) else {
            self.highPriceLabel.isHidden = true
            self.lowPriceLabel.isHidden = true
            return
        }

        let high = self.candles[highIndex].high
        let low = self.candles[lowIndex].low
        self.placeLabel(self.highPriceLabel, text: ChartNumberFormatter.shortPrice(high), index: highIndex, value: high, isAbove: true)
        self.placeLabel(self.lowPriceLabel, text: ChartNumberFormatter.shortPrice(low), index: lowIndex, value: low, isAbove: false)
    }

    /// 指定した範囲で、高値が一番高い足と、安値が一番安い足のインデックス。表示しない場合は nil
    private func highLowIndexes(from: Int, to: Int) -> (high: Int, low: Int)? {
        guard self.drawsHighLowLabels else { return nil }
        guard !self.candles.isEmpty else { return nil }
        // レイアウト前は、足の画面上の位置が決まっていない
        guard self.priceChartView.viewPortHandler.contentWidth > 0 else { return nil }

        // 範囲をデータの中に収める(一目均衡表の先行スパンの先など、足のない部分は除く)
        let lower = max(min(from, to), 0)
        let upper = min(max(from, to), self.candles.count - 1)
        guard lower <= upper else { return nil }

        var highIndex = lower
        var lowIndex = lower
        for index in lower...upper {
            if self.candles[index].high > self.candles[highIndex].high {
                highIndex = index
            }
            if self.candles[index].low < self.candles[lowIndex].low {
                lowIndex = index
            }
        }
        return (highIndex, lowIndex)
    }

    /// 文字を、指定した足の上(isAbove = true)または下に置く。外枠の左右からはみ出さないよう、端では内側に寄せる
    private func placeLabel(_ label: UILabel, text: String, index: Int, value: Double, isAbove: Bool) {
        label.text = text
        label.font = self.style.highLowLabelFont
        label.textColor = self.style.textColor
        label.sizeToFit()

        // 足の位置(X = 足の中央、Y = 高値・安値)を、このViewの座標にする
        let transformer = self.priceChartView.getTransformer(forAxis: .right)
        let pointInChart = transformer.pixelForValues(x: Double(index), y: value)
        let point = self.priceChartView.convert(pointInChart, to: self)

        let size = label.bounds.size
        var x = point.x - size.width / 2
        // 外枠の左右からはみ出さないように寄せる
        let frameRect = self.frameView.frame
        x = max(x, frameRect.minX + self.highLowLabelGap)
        x = min(x, frameRect.maxX - self.highLowLabelGap - size.width)

        var y = point.y + self.highLowLabelGap         // 下: 安値のすぐ下
        if isAbove {
            y = point.y - self.highLowLabelGap - size.height  // 上: 高値のすぐ上
        }
        label.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
        label.isHidden = false
    }
}

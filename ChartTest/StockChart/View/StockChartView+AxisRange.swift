//
//  StockChartView+AxisRange.swift
//  ChartTest
//
//  【View】StockChartView のスクロール/ズームの同期と、Y軸範囲の調整。
//
//  ・メインとサブは別々のチャートなので、片方をスクロール/ズームしたら、もう片方を同じ位置に合わせる
//  ・Y軸の上限・下限は、今見えている範囲の値(高値・安値・指標の値)に合わせて毎回計算し直す
//    (スクロールすると、見えている範囲の値に合わせてY軸が伸び縮みする)
//

import UIKit
import DGCharts

// MARK: - スクロール/ズームの同期

extension StockChartView: ChartViewDelegate {

    /// ピンチでズームされたとき(DGCharts から呼ばれる)
    func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
        syncViewport(from: chartView)
    }

    /// ドラッグでスクロールされたとき(DGCharts から呼ばれる)
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        syncViewport(from: chartView)
    }

    /// 操作されたチャートの表示位置・倍率(変換行列)を、もう一方のチャートにコピーする。
    /// 両チャートは描画領域の左右位置と幅・X軸の範囲が同じなので、行列をそのままコピーすれば表示範囲が一致する
    private func syncViewport(from source: ChartViewBase) {
        let target: CombinedChartView
        if source === priceChart {
            target = subChart
        } else {
            target = priceChart
        }
        let matrix = source.viewPortHandler.touchMatrix
        target.viewPortHandler.refresh(newMatrix: matrix, chart: target, invalidate: true)

        // 表示範囲が変わったのでY軸を調整する
        updateAxisRangesForVisibleCandles()
    }
}

// MARK: - Y軸範囲の調整

extension StockChartView {

    /// 今画面に見えている足の範囲に合わせて、Y軸を調整する
    func updateAxisRangesForVisibleCandles() {
        let firstIndex = Int(priceChart.lowestVisibleX.rounded())
        let lastIndex = Int(priceChart.highestVisibleX.rounded())
        updateAxisRanges(from: firstIndex, to: lastIndex)
    }

    /// 初期表示の範囲(直近 visibleCount 本)に合わせて、Y軸を調整する。
    /// レイアウト前は DGCharts から表示範囲を取得できないため、インデックスから計算する
    func updateAxisRangesForInitialCandles() {
        var firstIndex = 0
        if let visibleCount = effectiveVisibleCount {
            firstIndex = max(0, totalCount - visibleCount)
        }
        updateAxisRanges(from: firstIndex, to: totalCount - 1)
    }

    /// 指定した範囲の値に合わせてメイン/サブのY軸範囲を調整する
    /// - Parameters:
    ///   - from: 表示範囲の先頭インデックス
    ///   - to: 表示範囲の末尾インデックス
    func updateAxisRanges(from: Int, to: Int) {
        let lower = min(from, to)
        let upper = max(from, to)

        // Y軸固定の場合は、表示範囲ではなくデータ全期間を対象にする(スクロールしても範囲が変わらない)
        var mainLower = lower
        var mainUpper = upper
        if displayOptions.isMainYAxisFixed {
            mainLower = 0
            mainUpper = totalCount - 1
        }
        var subLower = lower
        var subUpper = upper
        if displayOptions.isSubYAxisFixed {
            subLower = 0
            subUpper = totalCount - 1
        }

        updateMainAxisRange(from: mainLower, to: mainUpper)
        if hasSubChart {
            updateSubAxisRange(from: subLower, to: subUpper)
        }

        // Y軸範囲が変わると十字線の横線の位置も変わるので更新する
        // (スクロール・ズーム時もここを通るので、十字線が足に追従する)
        updateCrosshair()
    }

    /// メインチャートのY軸範囲を調整する
    ///
    /// 上側は凡例と重ならないよう「凡例の高さぶん」(最低でも値幅の 20%)、下側は値幅の 5% の余白を取る
    ///
    ///   axisMaximum   ┬ ─────────────────   ← 凡例(priceLegendLabel)はこの余白部分に重なる
    ///                 │ 余白(凡例の高さぶん。topPadding で計算)
    ///   表示中の最高値 ┼ ─────────────────
    ///                 │ ローソク足・指標の線
    ///   表示中の最安値 ┼ ─────────────────
    ///                 │ 余白(値幅の 5%)
    ///   axisMinimum   ┴ ─────────────────
    ///
    /// チャートの高さが低い(縦画面など)と、値幅の 20% では凡例の高さに足りないので、
    /// 画面上の高さ(pt)から必要な余白を計算して、線が一番高くても凡例の下に収まるようにしている
    private func updateMainAxisRange(from: Int, to: Int) {
        // 範囲の計算対象: 高値・安値(足を描く場合)・メイン指標の各線
        var valueArrays: [[Double?]] = []
        if mainContent.priceStyle != .hidden {
            valueArrays.append(candles.map { candle in candle.high })
            valueArrays.append(candles.map { candle in candle.low })
        }
        for series in mainContent.series {
            valueArrays.append(series.values)
        }

        guard var (low, high) = Self.valueRange(of: valueArrays, from: from, to: to) else { return }

        // 現在値の破線(新値足・折線チャート)も範囲に含める
        if let currentPrice = mainContent.currentPrice {
            low = min(low, currentPrice)
            high = max(high, currentPrice)
        }

        let range = Self.nonZeroRange(low: low, high: high)
        let bottomPadding = range * 0.05
        let topPadding = topPaddingForLegend(
            priceLegendLabel, legendTop: style.legendTopInset, chart: priceChart,
            valueRange: range + bottomPadding, minimumRatio: 0.2)
        priceChart.rightAxis.axisMaximum = high + topPadding
        priceChart.rightAxis.axisMinimum = low - bottomPadding
        priceChart.notifyDataSetChanged()
    }

    /// サブチャートのY軸範囲を調整する
    private func updateSubAxisRange(from: Int, to: Int) {
        guard let sub = subContent else { return }
        let axis = subChart.rightAxis
        axis.drawLabelsEnabled = true  // 値がない場合だけ、下で false にする

        if let fixedRange = sub.fixedRange {
            // 固定範囲(0〜100 など)。上側は凡例用に広げる(最低 25%。その部分のラベルは非表示)
            //   例) RSI: 0〜100 → 0〜125。100〜125 の部分に凡例(subLegendLabel)が重なる
            let width = fixedRange.upperBound - fixedRange.lowerBound
            axis.axisMinimum = fixedRange.lowerBound
            axis.axisMaximum = fixedRange.upperBound + topPaddingForSubLegend(valueRange: width, minimumRatio: 0.25)
        } else {
            // 範囲の計算対象: サブ指標の各線・棒
            var valueArrays: [[Double?]] = []
            for series in sub.series {
                valueArrays.append(series.values)
            }
            if let bars = sub.bars {
                valueArrays.append(bars.values)
            }

            if var (low, high) = Self.valueRange(of: valueArrays, from: from, to: to) {
                // 0 を必ず含める指標(出来高・MACD など)は、範囲を 0 まで広げる
                if sub.includesZero {
                    low = min(low, 0)
                    high = max(high, 0)
                }

                // 上側は凡例と重ならないよう凡例の高さぶん(最低でも値幅の 30%)、下側は 5% の余白を取る。
                // サブチャートはメインより背が低く、凡例の高さが占める割合が大きいので、メイン(20%)より多めに取る
                let range = Self.nonZeroRange(low: low, high: high)
                var bottomPadding = range * 0.05
                if sub.includesZero, low == 0 {
                    // 0 起点(出来高など): 下側の余白は取らず、0 を下端にする
                    bottomPadding = 0
                }
                axis.axisMinimum = low - bottomPadding
                axis.axisMaximum = high + topPaddingForSubLegend(valueRange: range + bottomPadding, minimumRatio: 0.3)

                // ラベルの数は、描画領域の高さに収まる数(ラベル1つにつき文字 1.3 行分の高さ)にする。
                // 縦画面などでサブチャートが低いと、5つ並べると文字同士が重なるため
                let labelHeight = style.yAxisFont.lineHeight * 1.3
                let fittingCount = Int(subChart.viewPortHandler.contentHeight / labelHeight)
                axis.setLabelCount(min(max(fittingCount, 2), 5), force: false)
            } else {
                // 値が1つもない(指数の1分足・日中足の出来高など): 棒も線もないので、Y軸のラベルも出さない。
                // 範囲は仮に 0〜1 にしておく(前に表示していた内容の範囲が残らないように)
                axis.axisMinimum = 0
                axis.axisMaximum = 1
                axis.drawLabelsEnabled = false
            }
        }
        subChart.notifyDataSetChanged()
    }

    // MARK: - 凡例の下の余白

    /// サブチャートの凡例が重ならないための、Y軸の上側の余白(値)
    /// - Parameters:
    ///   - valueRange: 余白を除いた表示範囲の値幅(下側の余白を含む)
    ///   - minimumRatio: 余白の最小値(valueRange に対する割合)
    private func topPaddingForSubLegend(valueRange: Double, minimumRatio: Double) -> Double {
        // サブの描画領域の上端は区切り線の中心なので、凡例の上端までには区切り線の太さの半分が加わる
        let legendTop = style.subLegendTopInset + style.borderWidth / 2
        return topPaddingForLegend(subLegendLabel, legendTop: legendTop, chart: subChart,
                                   valueRange: valueRange, minimumRatio: minimumRatio)
    }

    /// 凡例の下端より下に線・足が収まるための、Y軸の上側の余白(値)を求める
    ///
    ///   描画領域の上端 ┬──────────────┬ axisMaximum
    ///                 │ legendTop    │
    ///                 │ 凡例         │ reserved(pt) = legendTop + 凡例の高さ + legendBottomSpacing
    ///                 │ 間隔         │   → 値に直すと topPadding
    ///                 ├──────────────┼ 表示中の最高値
    ///                 │ 線・足       │ height - reserved(pt) = valueRange(値)
    ///   描画領域の下端 ┴──────────────┴ axisMinimum
    ///
    ///   「topPadding : valueRange = reserved : (height - reserved)」なので
    ///   topPadding = valueRange × reserved ÷ (height − reserved)
    ///
    /// - Parameters:
    ///   - legend: 凡例のラベル
    ///   - legendTop: 描画領域の上端から凡例の上端までの距離(pt)
    ///   - chart: 凡例が重なっているチャート
    ///   - valueRange: 余白を除いた表示範囲の値幅(下側の余白を含む)
    ///   - minimumRatio: 余白の最小値(valueRange に対する割合)。凡例がない・レイアウト前の場合はこの値になる
    private func topPaddingForLegend(_ legend: UILabel, legendTop: CGFloat, chart: CombinedChartView,
                                     valueRange: Double, minimumRatio: Double) -> Double {
        let minimumPadding = valueRange * minimumRatio

        // 凡例がない(「なし」の指標など)
        guard legend.attributedText != nil else { return minimumPadding }
        // レイアウト前で、描画領域の高さが決まっていない(サイズが決まったときに計算し直される)
        let height = chart.viewPortHandler.contentHeight
        guard height > 0 else { return minimumPadding }

        let reserved = legendTop + legend.intrinsicContentSize.height + style.legendBottomSpacing
        // 凡例だけで描画領域の高さの半分を超える場合は、線を描く場所がなくなるので半分で止める
        let limitedReserved = min(reserved, height / 2)
        let padding = valueRange * Double(limitedReserved / (height - limitedReserved))
        return max(padding, minimumPadding)
    }

    // MARK: - 計算の補助

    /// 複数の値の配列から、指定インデックス範囲内の最小値・最大値を求める(nil は無視)
    /// - Returns: 値が1つもない場合は nil
    static func valueRange(of arrays: [[Double?]], from: Int, to: Int) -> (low: Double, high: Double)? {
        var low = Double.infinity
        var high = -Double.infinity

        for values in arrays {
            // 配列の長さが足りない場合もあるので、範囲を配列の中に収める
            let lower = max(from, 0)
            let upper = min(to, values.count - 1)
            guard lower <= upper else { continue }

            for index in lower...upper {
                guard let value = values[index] else { continue }  // nil(値なし)は無視
                low = min(low, value)
                high = max(high, value)
            }
        }

        // 値が1つもなかった(すべて nil・範囲外)場合は low > high のまま
        guard low <= high else { return nil }
        return (low, high)
    }

    /// 値幅を返す。値幅 0 の場合に軸の範囲が潰れないよう、値の大きさに応じた幅を返す
    static func nonZeroRange(low: Double, high: Double) -> Double {
        let range = high - low
        if range > 0 {
            return range
        }
        // すべて同じ値の場合: 値そのものの大きさを幅にする(値が 0 なら 1)
        return max(abs(high), 1)
    }
}

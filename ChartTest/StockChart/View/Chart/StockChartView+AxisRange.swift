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
        self.syncViewport(from: chartView)
    }

    /// ドラッグでスクロールされたとき(DGCharts から呼ばれる)
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        self.syncViewport(from: chartView)
    }

    /// 操作されたチャートの表示位置・倍率(変換行列)を、もう一方のチャートにコピーする。
    /// 両チャートは描画領域の左右位置と幅・X軸の範囲が同じなので、行列をそのままコピーすれば表示範囲が一致する
    private func syncViewport(from source: ChartViewBase) {
        let target: CombinedChartView
        if source === self.priceChartView {
            target = self.subChartView
        } else {
            target = self.priceChartView
        }
        let matrix = source.viewPortHandler.touchMatrix
        target.viewPortHandler.refresh(newMatrix: matrix, chart: target, invalidate: true)

        // 表示範囲が変わったのでY軸を調整する
        self.updateAxisRangesForVisibleCandles()
    }
}

// MARK: - Y軸範囲の調整

extension StockChartView {

    /// 今画面に見えている足の範囲に合わせて、Y軸を調整する
    func updateAxisRangesForVisibleCandles() {
        let firstIndex = Int(self.priceChartView.lowestVisibleX.rounded())
        let lastIndex = Int(self.priceChartView.highestVisibleX.rounded())
        self.updateAxisRanges(from: firstIndex, to: lastIndex)
    }

    /// 初期表示の範囲(直近 visibleCount 本)に合わせて、Y軸を調整する。
    /// レイアウト前は DGCharts から表示範囲を取得できないため、インデックスから計算する
    func updateAxisRangesForInitialCandles() {
        var firstIndex = 0
        if let visibleCount = self.effectiveVisibleCount {
            firstIndex = max(0, self.totalCount - visibleCount)
        }
        self.updateAxisRanges(from: firstIndex, to: self.totalCount - 1)
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
        if self.displayOptions.isMainYAxisFixed {
            mainLower = 0
            mainUpper = self.totalCount - 1
        }
        var subLower = lower
        var subUpper = upper
        if self.displayOptions.isSubYAxisFixed {
            subLower = 0
            subUpper = self.totalCount - 1
        }

        self.updateMainAxisRange(from: mainLower, to: mainUpper)
        // 最高値・最安値の文字は、Y軸固定のときも「今見えている範囲」の値を出す
        self.updateHighLowLabels(from: lower, to: upper)
        if self.hasSubChart {
            self.updateSubAxisRange(from: subLower, to: subUpper)
        }

        // Y軸範囲が変わると十字線の横線の位置も変わるので更新する
        // (スクロール・ズーム時もここを通るので、十字線が足に追従する)
        self.updateCrosshair()
    }

    /// メインチャートのY軸範囲を調整する
    ///
    /// 上側は凡例と重ならないよう「凡例の高さぶん」(最低でも値幅の 20%)、下側は値幅の 20% の余白を取る(既存アプリと同じ)
    ///
    ///   axisMaximum   ┬ ─────────────────   ← 凡例(priceLegendLabel)はこの余白部分に重なる
    ///                 │ 余白(凡例の高さぶん。topPadding で計算)
    ///   表示中の最高値 ┼ ─────────────────
    ///                 │ ローソク足・指標の線
    ///   表示中の最安値 ┼ ─────────────────
    ///                 │ 余白(値幅の 20%)
    ///   axisMinimum   ┴ ─────────────────
    ///
    /// チャートの高さが低い(縦画面など)と、値幅の 20% では凡例の高さに足りないので、
    /// 画面上の高さ(pt)から必要な余白を計算して、線が一番高くても凡例の下に収まるようにしている
    private func updateMainAxisRange(from: Int, to: Int) {
        // 範囲の計算対象: 高値・安値(足を描く場合)・メイン指標の各線
        var valueArrays: [[Double?]] = []
        if self.mainContent.priceStyle != .hidden {
            valueArrays.append(self.candles.map { candle in candle.high })
            valueArrays.append(self.candles.map { candle in candle.low })
        }
        for series in self.mainContent.series {
            valueArrays.append(series.values)
        }

        guard var (low, high) = Self.valueRange(of: valueArrays, from: from, to: to) else { return }

        // 現在値の破線(新値足・折線チャート)も範囲に含める
        if let currentPrice = self.mainContent.currentPrice {
            low = min(low, currentPrice)
            high = max(high, currentPrice)
        }

        let range = Self.nonZeroRange(low: low, high: high)

        // 上側: 凡例の分。下側: なし(最低でも値幅の 20%)
        var topPoints: CGFloat = 0
        if self.priceLegendLabel.attributedText != nil {
            topPoints = self.style.legendTopInset + self.priceLegendLabel.intrinsicContentSize.height + self.style.legendBottomSpacing
        }
        var bottomPoints: CGFloat = 0
        // 最高値・最安値の文字を出す場合は、一番高い足の上・一番安い足の下に、文字の分の余白も空ける
        if self.drawsHighLowLabels {
            let labelSpace = self.style.highLowLabelFont.lineHeight + self.highLowLabelGap
            topPoints += labelSpace
            bottomPoints += labelSpace
        }
        let paddings = Self.axisPaddings(
            valueRange: range, topPoints: topPoints, bottomPoints: bottomPoints,
            height: self.priceChartView.viewPortHandler.contentHeight, minimumTopRatio: 0.2, minimumBottomRatio: 0.2)
        self.priceChartView.rightAxis.axisMaximum = high + paddings.top
        self.priceChartView.rightAxis.axisMinimum = low - paddings.bottom
        self.priceChartView.notifyDataSetChanged()
    }

    /// 上下に指定した高さ(pt)の余白を空けるための、Y軸の上側・下側の余白(値)を求める
    ///
    ///   描画領域の上端 ┬ topPoints(凡例・最高値の文字)    → 上側の余白(値)
    ///                 │ 線・足(valueRange)
    ///   描画領域の下端 ┴ bottomPoints(最安値の文字)       → 下側の余白(値)
    ///
    /// - Parameters:
    ///   - valueRange: 余白を除いた値幅
    ///   - topPoints: 上に空ける高さ(pt)
    ///   - bottomPoints: 下に空ける高さ(pt)
    ///   - height: 描画領域の高さ(pt)。0 ならレイアウト前なので、最小値だけを返す
    ///   - minimumTopRatio: 上側の余白の最小値(valueRange に対する割合)
    ///   - minimumBottomRatio: 下側の余白の最小値(valueRange に対する割合)
    static func axisPaddings(valueRange: Double, topPoints: CGFloat, bottomPoints: CGFloat, height: CGFloat,
                             minimumTopRatio: Double, minimumBottomRatio: Double) -> (top: Double, bottom: Double) {
        let minimumTop = valueRange * minimumTopRatio
        let minimumBottom = valueRange * minimumBottomRatio
        guard height > 0 else { return (minimumTop, minimumBottom) }

        // 線・足を描く部分の高さ。余白が大きすぎる場合でも、高さの半分は線・足のために残す
        let dataHeight = max(height - topPoints - bottomPoints, height / 2)
        let valuePerPoint = valueRange / Double(dataHeight)
        let top = max(Double(topPoints) * valuePerPoint, minimumTop)
        let bottom = max(Double(bottomPoints) * valuePerPoint, minimumBottom)
        return (top, bottom)
    }

    /// サブチャートのY軸範囲を調整する
    ///   ・固定範囲の指標(RSI など 0〜100): 範囲は変えず、上側に凡例の分だけ広げる
    ///   ・それ以外(出来高・MACD など): 見えている範囲の値に合わせて計算する
    private func updateSubAxisRange(from: Int, to: Int) {
        guard let sub = self.subContent else { return }
        self.subChartView.rightAxis.drawLabelsEnabled = true  // 値がない場合だけ、applyAutoSubAxisRange で false にする

        if let fixedRange = sub.fixedRange {
            self.applyFixedSubAxisRange(fixedRange)
        } else {
            self.applyAutoSubAxisRange(for: sub, from: from, to: to)
        }
        self.subChartView.notifyDataSetChanged()
    }

    /// 固定範囲(0〜100 など)のサブチャートのY軸。上側は凡例用に広げる(最低 25%。その部分のラベルは非表示)
    ///   例) RSI: 0〜100 → 0〜125。100〜125 の部分に凡例(subLegendLabel)が重なる
    private func applyFixedSubAxisRange(_ fixedRange: ClosedRange<Double>) {
        let axis = self.subChartView.rightAxis
        let width = fixedRange.upperBound - fixedRange.lowerBound
        axis.axisMinimum = fixedRange.lowerBound
        axis.axisMaximum = fixedRange.upperBound + self.topPaddingForSubLegend(valueRange: width, minimumRatio: 0.25)
    }

    /// 見えている範囲の値に合わせて、サブチャートのY軸を決める
    ///
    ///   axisMaximum ┬ 余白(凡例の高さぶん。最低でも値幅の 30%)
    ///   最大値      ┼ 線・棒
    ///   最小値      ┼ 余白(値幅の 5%。0 起点の出来高などは 0)
    ///   axisMinimum ┴
    private func applyAutoSubAxisRange(for sub: SubChartContent, from: Int, to: Int) {
        let axis = self.subChartView.rightAxis

        // 範囲の計算対象: サブ指標の各線・棒
        var valueArrays: [[Double?]] = []
        for series in sub.series {
            valueArrays.append(series.values)
        }
        if let bars = sub.bars {
            valueArrays.append(bars.values)
        }

        guard var (low, high) = Self.valueRange(of: valueArrays, from: from, to: to) else {
            // 値が1つもない(指数の1分足・日中足の出来高など): 棒も線もないので、Y軸のラベルも出さない。
            // 範囲は仮に 0〜1 にしておく(前に表示していた内容の範囲が残らないように)
            axis.axisMinimum = 0
            axis.axisMaximum = 1
            axis.drawLabelsEnabled = false
            return
        }

        // 0 を必ず含める指標(出来高・MACD など)は、範囲を 0 まで広げる
        if sub.includesZero {
            low = min(low, 0)
            high = max(high, 0)
        }
        // 基準線(移動平均乖離率の底値・高値ラインなど)も範囲に含め、線が見えなくならないようにする
        for level in sub.referenceLines {
            low = min(low, level)
            high = max(high, level)
        }

        // 上側は凡例と重ならないよう凡例の高さぶん(最低でも値幅の 30%)、下側は 5% の余白を取る。
        // サブチャートはメインより背が低く、凡例の高さが占める割合が大きいので、メイン(20%)より多めに取る
        let range = Self.nonZeroRange(low: low, high: high)
        let bottomPadding = self.subAxisBottomPadding(for: sub, low: low, range: range)
        axis.axisMinimum = low - bottomPadding
        axis.axisMaximum = high + self.topPaddingForSubLegend(valueRange: range + bottomPadding, minimumRatio: 0.3)

        axis.setLabelCount(self.subAxisLabelCount(), force: false)
    }

    /// サブチャートのY軸の下側の余白(値)。
    /// 0 起点の指標(出来高など)は、余白を取らずに 0 を下端にする。それ以外は値幅の 5%
    private func subAxisBottomPadding(for sub: SubChartContent, low: Double, range: Double) -> Double {
        if sub.includesZero {
            if low == 0 {
                return 0
            }
        }
        return range * 0.05
    }

    /// サブチャートのY軸ラベルの数。描画領域の高さに収まる数(ラベル1つにつき文字 1.3 行分の高さ)にする。
    /// 縦画面などでサブチャートが低いと、5つ並べると文字同士が重なるため(2〜5 個)
    private func subAxisLabelCount() -> Int {
        let labelHeight = self.style.yAxisFont.lineHeight * 1.3
        let fittingCount = Int(self.subChartView.viewPortHandler.contentHeight / labelHeight)
        let minimumCount = 2
        let maximumCount = 5
        return min(max(fittingCount, minimumCount), maximumCount)
    }

    // MARK: - 凡例の下の余白

    /// サブチャートの凡例が重ならないための、Y軸の上側の余白(値)
    /// - Parameters:
    ///   - valueRange: 余白を除いた表示範囲の値幅(下側の余白を含む)
    ///   - minimumRatio: 余白の最小値(valueRange に対する割合)
    private func topPaddingForSubLegend(valueRange: Double, minimumRatio: Double) -> Double {
        // サブの描画領域の上端は区切り線の中心なので、凡例の上端までには区切り線の太さの半分が加わる
        let legendTop = self.style.subLegendTopInset + self.style.borderWidth / 2
        return self.topPaddingForLegend(self.subLegendLabel, legendTop: legendTop, chart: self.subChartView,
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

        let reserved = legendTop + legend.intrinsicContentSize.height + self.style.legendBottomSpacing
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

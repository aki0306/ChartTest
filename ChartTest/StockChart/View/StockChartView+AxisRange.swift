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
        if let visibleCount = style.visibleCount {
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
    /// 上側は凡例と重ならないよう値幅の 20%、下側は 5% の余白を取る
    ///
    ///   axisMaximum   ┬ ─────────────────   ← 凡例(priceLegendLabel)はこの余白部分に重なる
    ///                 │ 余白(値幅の 20%)
    ///   表示中の最高値 ┼ ─────────────────
    ///                 │ ローソク足・指標の線
    ///   表示中の最安値 ┼ ─────────────────
    ///                 │ 余白(値幅の 5%)
    ///   axisMinimum   ┴ ─────────────────
    ///
    /// 凡例の位置は固定(外枠の上端から 6pt)なので、線が一番高くても凡例の下に収まるようにしている
    private func updateMainAxisRange(from: Int, to: Int) {
        // 範囲の計算対象: 高値・安値・メイン指標の各線
        let highs: [Double?] = candles.map { candle in candle.high }
        let lows: [Double?] = candles.map { candle in candle.low }
        var valueArrays: [[Double?]] = [highs, lows]
        for series in mainContent.series {
            valueArrays.append(series.values)
        }

        guard let (low, high) = Self.valueRange(of: valueArrays, from: from, to: to) else { return }

        let range = Self.nonZeroRange(low: low, high: high)
        priceChart.rightAxis.axisMaximum = high + range * 0.2
        priceChart.rightAxis.axisMinimum = low - range * 0.05
        priceChart.notifyDataSetChanged()
    }

    /// サブチャートのY軸範囲を調整する
    private func updateSubAxisRange(from: Int, to: Int) {
        guard let sub = subContent else { return }
        let axis = subChart.rightAxis
        axis.drawLabelsEnabled = true  // 値がない場合だけ、下で false にする

        if let fixedRange = sub.fixedRange {
            // 固定範囲(0〜100 など)。上側は凡例用に 25% 広げる(その部分のラベルは非表示)
            //   例) RSI: 0〜100 → 0〜125。100〜125 の部分に凡例(subLegendLabel)が重なる
            let width = fixedRange.upperBound - fixedRange.lowerBound
            axis.axisMinimum = fixedRange.lowerBound
            axis.axisMaximum = fixedRange.upperBound + width * 0.25
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

                // 上側は凡例と重ならないよう値幅の 30%、下側は 5% の余白を取る。
                // サブチャートはメインより背が低く、凡例の高さが占める割合が大きいので、メイン(20%)より多めに取る
                let range = Self.nonZeroRange(low: low, high: high)
                axis.axisMaximum = high + range * 0.3
                if sub.includesZero, low == 0 {
                    // 0 起点(出来高など): 下側の余白は取らず、0 を下端にする
                    axis.axisMinimum = 0
                } else {
                    axis.axisMinimum = low - range * 0.05
                }
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

//
//  StockChartView+Rendering.swift
//  ChartTest
//
//  【View】StockChartView の描画処理。
//  表示中の内容(candles / mainContent / subContent)を DGCharts のデータに変換してチャートに渡す。
//
//  【DGCharts のデータの形】
//   CombinedChartData(1つのチャートに重ねて描く全データ)
//     ├ candleData  … ローソク足
//     ├ barData     … 棒グラフ(出来高・MACD ヒストグラム)
//     ├ lineData    … 折れ線(移動平均線など。線1本 = LineChartDataSet 1つ)
//     └ scatterData … 点(パラボリック)
//   各データは「X = 何本目か、Y = 値」の点(ChartDataEntry)の並び。
//

import UIKit
import DGCharts

/// 凡例の1項目(表示する文字と、その色の役割)
private struct LegendItem {
    /// 表示する文字(例:「短期移動平均(5)」)
    let text: String
    /// 文字の色の役割(チャートの線と同じ色にする)
    let colorRole: ChartColorRole
}

extension StockChartView {

    // MARK: - 描画

    /// 表示中の内容をチャートに反映する
    /// - Parameter matrix: 適用する表示位置・拡大率。nil の場合は初期表示位置(直近 visibleCount 本)にする
    func render(keepingMatrix matrix: CGAffineTransform?) {
        // 凡例は、データが0件でも表示する(「現在、指定の条件で表示できる情報はありません。」の上に出す)
        updateLegends()
        noDataLabel.isHidden = !showsNoDataMessage

        // データが空ならチャートを消して終了
        guard !candles.isEmpty else {
            clearCharts()
            return
        }

        configureXAxisRange()
        renderMainChart()
        renderSubChart()
        applyViewport(matrix)

        // 表示範囲に合わせてY軸を調整する(AxisRange)。
        // 初期表示はレイアウト前で DGCharts から表示範囲が取れない場合があるため、インデックスから計算する
        if matrix != nil {
            updateAxisRangesForVisibleCandles()
        } else {
            updateAxisRangesForInitialCandles()
        }
    }

    /// チャートの表示を消す(凡例は updateLegends で別に設定する)
    private func clearCharts() {
        priceChart.data = nil
        subChart.data = nil
        priceRenderer.cloud = nil
    }

    /// X軸の範囲とラベルの書式を設定する(メイン/サブ共通)
    private func configureXAxisRange() {
        // X軸の値はデータのインデックス(0, 1, 2, ...)。
        // 日付をそのまま使うと土日・祝日が空白になるため、ラベルは「インデックス → 日付文字列」に変換して表示する
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = style.dateFormat
        let dates = candles.map { candle in candle.date }
        let xAxisFormatter = DateAxisValueFormatter(dates: dates, formatter: dateFormatter)

        // 両端のローソク足/バーが半分切れないよう、X軸の範囲を前後に 0.5 本ずつ広げる。
        // メインとサブで範囲を揃えておかないとスクロール同期がずれるので、両方に同じ値を設定する
        for chart in [priceChart, subChart] {
            chart.xAxis.valueFormatter = xAxisFormatter
            chart.xAxis.axisMinimum = -0.5
            chart.xAxis.axisMaximum = Double(totalCount) - 0.5
        }
    }

    /// メインチャート(ローソク足 + メイン指標・雲・凡例)を描く
    private func renderMainChart() {
        // 一目均衡表の雲(それ以外の指標では nil = 塗らない)
        if let cloud = mainContent.cloud {
            priceRenderer.cloud = CloudCombinedRenderer.Cloud(
                spanA: cloud.spanA,
                spanB: cloud.spanB,
                upColor: style.ichimokuSpanAColor.withAlphaComponent(style.cloudAlpha),
                downColor: style.ichimokuSpanBColor.withAlphaComponent(style.cloudAlpha))
        } else {
            priceRenderer.cloud = nil
        }

        priceChart.data = makePriceData()
    }

    /// サブチャート(サブ指標・Y軸)を描く。サブなしの場合は空にする
    private func renderSubChart() {
        guard let sub = subContent else {
            subChart.data = nil
            return
        }

        subChart.data = makeSubData(sub)
        configureSubAxis(sub)
    }

    /// 表示位置・拡大率を設定する
    /// - Parameter matrix: 維持する表示位置・拡大率。nil の場合は初期表示位置(直近 visibleCount 本・右端)にする
    private func applyViewport(_ matrix: CGAffineTransform?) {
        for chart in [priceChart, subChart] {
            if let matrix {
                // 指定された表示位置・拡大率(切り替え前の状態)をそのまま適用する
                chart.notifyDataSetChanged()
                chart.viewPortHandler.refresh(newMatrix: matrix, chart: chart, invalidate: true)
            } else {
                // 直近 visibleCount 本を表示し、右端(最新)にスクロールしておく。
                // (レイアウト前の場合、moveViewToX はサイズ確定後に DGCharts が自動で実行する)
                chart.fitScreen()
                if let visibleCount = style.visibleCount, visibleCount < totalCount {
                    chart.setVisibleXRangeMaximum(Double(visibleCount))
                    chart.moveViewToX(Double(totalCount))
                }
                chart.notifyDataSetChanged()
            }
        }
    }

    // MARK: - 凡例

    /// メイン・サブの凡例を、表示中の内容に合わせて設定する
    private func updateLegends() {
        // メインチャートの凡例: 「タイトル + 各線のラベル」を並べる
        //   例) 移動平均線       → 「移動平均 短期移動平均(5) 長期移動平均(25)」
        //       ボリンジャーバンド → 「ボリンジャーバンド(20) 中心線 ±1σ ±2σ」
        // ・タイトル(legendTitle)と各線のラベル(label)は Model(ChartContentBuilder)で決めている
        // ・label が nil の線は凡例に出さない(ボリンジャーバンドの下限線、パラボリックの点など)
        // ・「なし(ローソク足のみ)」はタイトルも線もないので、凡例は空(nil)になる
        let mainItems = legendItems(of: mainContent.series)
        priceLegendLabel.attributedText = makeLegend(title: mainContent.legendTitle, items: mainItems)

        // サブチャートの凡例: 「タイトル + 棒のラベル + 各線のラベル」の順に並べる
        //   例) 出来高 → 「出来高 出来高移動平均」(タイトルなし。棒のラベル「出来高」が先頭)
        //       RSI    → 「RSI(14)」(タイトルなし。線のラベルだけ)
        //       DMI    → 「DMI(14) +DI −DI ADX」
        guard let sub = subContent else {
            subLegendLabel.attributedText = nil
            return
        }
        var subItems: [LegendItem] = []
        if let bars = sub.bars, let barLabel = bars.label {
            subItems.append(LegendItem(text: barLabel, colorRole: bars.labelColorRole))
        }
        subItems += legendItems(of: sub.series)
        subLegendLabel.attributedText = makeLegend(title: sub.legendTitle, items: subItems)
    }

    /// 線のうち、凡例に出すもの(label があるもの)を凡例の項目にする
    private func legendItems(of series: [ChartSeries]) -> [LegendItem] {
        var items: [LegendItem] = []
        for line in series {
            guard let label = line.label else { continue }  // label が nil の線は凡例に出さない
            items.append(LegendItem(text: label, colorRole: line.colorRole))
        }
        return items
    }

    /// 凡例のテキストを作る(タイトルは文字色、各項目はその線の色)
    ///
    ///   「移動平均 短期移動平均(5) 長期移動平均(25)」
    ///     ~~~~~~~~ ~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~
    ///     textColor  line(0) の色   line(1) の色      ← 項目ごとに色を変えた1行の文字列
    ///
    /// ・項目の間は半角スペース1つで区切る
    /// ・フォントはすべて style.legendFont(12pt)。枠に収まらない場合は UILabel 側で縮小される(Layout)
    /// ・色の役割(ChartColorRole)は style.color(for:) で実際の色に変換するので、凡例の文字色とチャートの線の色は常に一致する
    /// - Parameters:
    ///   - title: 先頭に表示するタイトル(指標名など)。nil なら出さない
    ///   - items: 凡例に並べる項目。並び順のまま表示する
    /// - Returns: 表示する項目が1つもない場合は nil(凡例を空にする)
    private func makeLegend(title: String?, items: [LegendItem]) -> NSAttributedString? {
        // (文字, 色) の組を並べる
        var parts: [(text: String, color: UIColor)] = []
        if let title {
            parts.append((text: title, color: style.textColor))
        }
        for item in items {
            parts.append((text: item.text, color: style.color(for: item.colorRole)))
        }
        guard !parts.isEmpty else { return nil }

        // 色付きの文字列をつなげて1行にする
        let legend = NSMutableAttributedString()
        for (index, part) in parts.enumerated() {
            if index > 0 {
                legend.append(NSAttributedString(string: " "))  // 項目の間は半角スペース
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: part.color,
                .font: style.legendFont,
            ]
            legend.append(NSAttributedString(string: part.text, attributes: attributes))
        }
        return legend
    }

    // MARK: - DGCharts のデータを作る

    /// メインチャートのデータ(ローソク足 + メイン指標)を作る
    private func makePriceData() -> CombinedChartData {
        // ローソク足: X = 何本目か、Y = 4本値
        var candleEntries: [CandleChartDataEntry] = []
        for (index, candle) in candles.enumerated() {
            let entry = CandleChartDataEntry(x: Double(index),
                                             shadowH: candle.high,  // ヒゲの上端 = 高値
                                             shadowL: candle.low,   // ヒゲの下端 = 安値
                                             open: candle.open,
                                             close: candle.close)
            candleEntries.append(entry)
        }

        let candleSet = CandleChartDataSet(entries: candleEntries, label: "ローソク足")
        candleSet.axisDependency = .right               // 右のY軸を基準に描画する
        candleSet.drawValuesEnabled = false             // 各足の値ラベルは表示しない
        candleSet.highlightEnabled = false
        candleSet.increasingColor = style.increasingColor
        candleSet.increasingFilled = true               // 陽線も塗りつぶす(日本式)
        candleSet.decreasingColor = style.decreasingColor
        candleSet.decreasingFilled = true
        candleSet.neutralColor = style.textColor        // 始値 = 終値(同事線)の色
        candleSet.shadowColorSameAsCandle = true        // ヒゲを実体と同じ色にする
        candleSet.shadowWidth = 1
        candleSet.barSpace = 0.15                       // 足同士の隙間(1本分の幅に対する割合)

        let data = CombinedChartData()
        data.candleData = CandleChartData(dataSet: candleSet)
        addSeries(mainContent.series, to: data)
        return data
    }

    /// サブチャートのデータ(棒グラフ + 線)を作る
    private func makeSubData(_ content: SubChartContent) -> CombinedChartData {
        let data = CombinedChartData()

        if let bars = content.bars {
            data.barData = makeBarData(bars)
        }
        addSeries(content.series, to: data)

        // 点が1つもない場合(指数の1分足・日中足の出来高など)、DGCharts は軸(X軸の日付ラベル)も描かなくなる。
        // 日付ラベルはサブチャートに表示しているので、見えない線をX軸の両端に置いて、軸が描かれるようにする
        if data.entryCount == 0 {
            data.lineData = LineChartData(dataSet: makeInvisibleAnchorSet())
        }
        return data
    }

    /// 軸を描かせるためだけの、見えない線(X軸の左端と右端に1点ずつ)
    private func makeInvisibleAnchorSet() -> LineChartDataSet {
        let entries = [
            ChartDataEntry(x: 0, y: 0),
            ChartDataEntry(x: Double(totalCount - 1), y: 0),
        ]
        let set = LineChartDataSet(entries: entries, label: "")
        set.axisDependency = .right
        set.setColor(.clear)            // 透明なので画面には何も見えない
        set.drawCirclesEnabled = false
        set.drawValuesEnabled = false
        set.highlightEnabled = false
        return set
    }

    /// 棒グラフ(出来高・MACD ヒストグラム)のデータを作る
    private func makeBarData(_ bars: ChartBars) -> BarChartData {
        // nil の位置は棒を作らない。色は棒ごとに指定する(作った棒と同じ並びにする)
        var entries: [BarChartDataEntry] = []
        var colors: [UIColor] = []
        for (index, value) in bars.values.enumerated() {
            guard let value else { continue }
            entries.append(BarChartDataEntry(x: Double(index), y: value))
            colors.append(style.color(for: bars.colorRoles[index]))
        }

        let barSet = BarChartDataSet(entries: entries, label: bars.label ?? "")
        barSet.axisDependency = .right
        barSet.drawValuesEnabled = false
        barSet.highlightEnabled = false
        barSet.colors = colors

        let barData = BarChartData(dataSet: barSet)
        barData.barWidth = 0.7  // 棒の幅(1本分の幅に対する割合)
        return barData
    }

    /// 線・点の ChartSeries を DGCharts のデータ(lineData / scatterData)に変換して追加する
    private func addSeries(_ seriesList: [ChartSeries], to data: CombinedChartData) {
        var lineSets: [LineChartDataSet] = []
        var dotSets: [ScatterChartDataSet] = []
        for series in seriesList {
            switch series.style {
            case .line:
                lineSets.append(makeLineSet(series))
            case .dots:
                dotSets.append(makeScatterSet(series))
            }
        }

        if !lineSets.isEmpty {
            data.lineData = LineChartData(dataSets: lineSets)
        }
        if !dotSets.isEmpty {
            data.scatterData = ScatterChartData(dataSets: dotSets)
        }
    }

    /// 線(折れ線)用のデータセットを作る。nil の位置は線を描かない
    private func makeLineSet(_ series: ChartSeries) -> LineChartDataSet {
        let set = LineChartDataSet(entries: makeEntries(series.values), label: series.label ?? "")
        set.axisDependency = .right
        set.setColor(style.color(for: series.colorRole))
        set.lineWidth = 1.2
        set.drawCirclesEnabled = false  // データ点の丸は描かない
        set.drawValuesEnabled = false
        set.highlightEnabled = false
        set.mode = .linear              // 点と点を直線で結ぶ
        return set
    }

    /// 点(パラボリック)用のデータセットを作る
    private func makeScatterSet(_ series: ChartSeries) -> ScatterChartDataSet {
        let set = ScatterChartDataSet(entries: makeEntries(series.values), label: series.label ?? "")
        set.axisDependency = .right
        set.setScatterShape(.circle)
        set.scatterShapeSize = 3
        set.setColor(style.color(for: series.colorRole))
        set.drawValuesEnabled = false
        set.highlightEnabled = false
        return set
    }

    /// 「何本目の値か」が並んだ配列を、DGCharts の点(X = 何本目か、Y = 値)の配列に変換する。
    /// nil の位置は点を作らない(線はそこで途切れる)
    private func makeEntries(_ values: [Double?]) -> [ChartDataEntry] {
        var entries: [ChartDataEntry] = []
        for (index, value) in values.enumerated() {
            guard let value else { continue }
            entries.append(ChartDataEntry(x: Double(index), y: value))
        }
        return entries
    }

    // MARK: - サブチャートのY軸

    /// サブチャートのY軸(基準線・ラベル間隔・書式)を内容に合わせて設定する
    private func configureSubAxis(_ content: SubChartContent) {
        let axis = subChart.rightAxis

        // 基準線(RSI の 30/70 など)を破線で引く
        axis.removeAllLimitLines()
        for level in content.referenceLines {
            let line = ChartLimitLine(limit: level)
            line.lineColor = style.referenceLineColor
            line.lineWidth = 0.8
            line.lineDashLengths = [4, 3]  // 4pt 描いて 3pt 空ける破線
            line.drawLabelEnabled = false
            axis.addLimitLine(line)
        }

        // ラベルの間隔。固定範囲(0〜100)の場合は凡例用に広げた上端(125)まで含めて 25 刻みの 6 本にする。
        // それ以外は DGCharts に任せて 5 本程度
        if content.fixedRange != nil {
            axis.setLabelCount(6, force: true)
        } else {
            axis.setLabelCount(5, force: false)
        }

        // ラベルの書式。固定範囲の場合、凡例用に上へ広げた部分(100 超など)のラベルは表示しない
        axis.valueFormatter = ChartAxisValueFormatter(
            formatter: ChartNumberFormatter.make(fractionDigits: content.fractionDigits, suffix: content.suffix),
            hiddenBottomRatio: 0,
            hiddenAbove: content.fixedRange?.upperBound)
    }
}

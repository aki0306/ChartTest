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
//     ├ barData     … 棒グラフ(出来高)
//     ├ lineData    … 折れ線(移動平均線など。線1本 = LineChartDataSet 1つ)
//     └ scatterData … 点(パラボリック)
//   各データは「X = 何本目か、Y = 値」の点(ChartDataEntry)の並び。
//

import UIKit
import DGCharts

extension StockChartView {

    // MARK: - 描画

    /// 表示中の内容をチャートに反映する
    /// - Parameter matrix: 適用する表示位置・拡大率。nil の場合は初期表示位置(直近 visibleCount 本)にする
    func render(keepingMatrix matrix: CGAffineTransform?) {
        // 凡例は、データが0件でも表示する(「現在、指定の条件で表示できる情報はありません。」の上に出す)
        self.updateLegends()
        self.noDataLabel.isHidden = !self.showsNoDataMessage

        // データが空ならチャートを消して終了
        guard !self.candles.isEmpty else {
            self.clearCharts()
            return
        }

        self.configureXAxisRange()
        self.renderMainChart()
        self.renderSubChart()
        self.applyViewport(matrix)

        // 表示範囲に合わせてY軸を調整する(AxisRange)。
        // 初期表示はレイアウト前で DGCharts から表示範囲が取れない場合があるため、インデックスから計算する
        if matrix != nil {
            self.updateAxisRangesForVisibleCandles()
        } else {
            self.updateAxisRangesForInitialCandles()
        }
    }

    /// チャートの表示を消す(凡例は updateLegends で別に設定する)
    private func clearCharts() {
        self.priceChartView.data = nil
        self.subChartView.data = nil
        self.priceRenderer.cloud = nil
        // 前のデータの最高値・最安値の文字が残らないようにする
        self.highPriceLabel.isHidden = true
        self.lowPriceLabel.isHidden = true
    }

    /// X軸の範囲とラベルの書式を設定する(メイン/サブ共通)
    private func configureXAxisRange() {
        // X軸の値はデータのインデックス(0, 1, 2, ...)。
        // 日付をそのまま使うと土日・祝日が空白になるため、ラベルは「インデックス → 日付文字列」に変換して表示する
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = self.style.dateFormat
        // 日付だけを並べる時間帯(1分足・日中足の、値のない時間帯)は、値のある足の前後に並べる
        //   インデックス:  -2     -1     0      1    …  n-1    n      n+1
        //   日付        : 08:45  08:50  09:00  09:05 … 14:35  14:40  14:45
        //                 ↑ leadingDates            値のある足  ↑ trailingDates
        let dates = self.leadingDates + self.candles.map { candle in candle.date } + self.trailingDates
        let xAxisFormatter = DateAxisValueFormatter(dates: dates, firstIndex: -self.leadingDates.count, formatter: dateFormatter)

        // 両端のローソク足/バーが半分切れないよう、X軸の範囲を前後に 0.5 本ずつ広げる(xAxisMinimum)。
        // メインとサブで範囲を揃えておかないとスクロール同期がずれるので、両方に同じ値を設定する
        for chart in [self.priceChartView, self.subChartView] {
            chart.xAxis.valueFormatter = xAxisFormatter
            chart.xAxis.axisMinimum = self.xAxisMinimum  // 新値足で本数が少ない場合は、左側を空けて右寄せにする
            chart.xAxis.axisMaximum = Double(self.totalCount) - 0.5
        }

        // X軸ラベルは最新の足(データの右端)を基準に並べる。
        // (一目均衡表の先行スパン・日付だけを並べる時間帯で右に余白がある場合も、値のある最後の足を基準にする)
        self.priceXAxisRenderer.latestIndex = self.candles.count - 1
        self.subXAxisRenderer.latestIndex = self.candles.count - 1
    }

    /// メインチャート(ローソク足 + メイン指標・雲・凡例)を描く
    private func renderMainChart() {
        // 一目均衡表の雲(それ以外の指標では nil = 塗らない)
        if let cloud = self.mainContent.cloud {
            self.priceRenderer.cloud = CloudCombinedRenderer.Cloud(
                spanA: cloud.spanA,
                spanB: cloud.spanB,
                upColor: self.style.ichimokuSpanAColor.withAlphaComponent(self.style.cloudAlpha),
                downColor: self.style.ichimokuSpanBColor.withAlphaComponent(self.style.cloudAlpha))
        } else {
            self.priceRenderer.cloud = nil
        }

        self.updateCurrentPriceLine()
        self.priceChartView.data = self.makePriceData()
    }

    /// 現在値の破線(新値足・折線チャート)を引く。現在値がない内容では消す
    private func updateCurrentPriceLine() {
        let axis = self.priceChartView.rightAxis
        axis.removeAllLimitLines()
        guard let price = self.mainContent.currentPrice else { return }

        let line = ChartLimitLine(limit: price)
        line.lineColor = self.style.currentPriceLineColor
        line.lineWidth = 0.8
        line.lineDashLengths = [3, 2]  // 3pt 描いて 2pt 空ける破線
        line.drawLabelEnabled = false
        axis.addLimitLine(line)
    }

    /// サブチャート(サブ指標・Y軸)を描く。サブなしの場合は空にする
    private func renderSubChart() {
        guard let sub = self.subContent else {
            self.subChartView.data = nil
            return
        }

        self.subChartView.data = self.makeSubData(sub)
        self.configureSubAxis(sub)
    }

    /// 表示位置・拡大率を設定する
    /// - Parameter matrix: 維持する表示位置・拡大率。nil の場合は初期表示位置(直近 visibleCount 本・右端)にする
    private func applyViewport(_ matrix: CGAffineTransform?) {
        for chart in [self.priceChartView, self.subChartView] {
            if let matrix {
                // 指定された表示位置・拡大率(切り替え前の状態)をそのまま適用する
                chart.notifyDataSetChanged()
                self.applyZoomLimits(to: chart)
                chart.viewPortHandler.refresh(newMatrix: matrix, chart: chart, invalidate: true)
            } else {
                // 直近 visibleCount 本を表示し、右端(最新)にスクロールしておく。
                // (レイアウト前の場合、moveViewToX はサイズ確定後に DGCharts が自動で実行する)
                chart.fitScreen()
                // 表示本数の指定があり、全体の本数より少ない場合だけ、拡大して右端に寄せる(それ以外は全件表示)
                if let visibleCount = self.effectiveVisibleCount {
                    // X軸全体の本数(日付だけを並べる時間帯を含む)
                    let axisCount = self.totalCount + self.leadingDates.count
                    if visibleCount < axisCount {
                        // 縮小の限界を visibleCount 本にすると、その本数まで拡大された状態になる(初期表示の拡大率)
                        chart.setVisibleXRangeMaximum(Double(visibleCount))
                        chart.moveViewToX(Double(self.totalCount))
                    }
                }
                // 初期表示の拡大率を決めたあとで、ピンチで拡大・縮小できる範囲に設定し直す
                // (限界を変えても、今の拡大率はそのまま)
                self.applyZoomLimits(to: chart)
                chart.notifyDataSetChanged()
            }
        }
    }

    /// ピンチで拡大・縮小できる範囲(表示本数)を設定する
    ///
    ///   拡大の限界: style.minimumVisibleCount 本(縦画面の参考: 約20本)
    ///   縮小の限界: style.maximumVisibleCount 本。nil なら全件(データ全体が1画面に入るまで)
    ///
    /// ・どちらも、X軸全体の本数より多くはしない(全体より多く表示することはできないため)
    /// ・DGCharts は「表示本数」ではなく「拡大率(X軸全体 ÷ 表示本数)」で限界を持っている
    func applyZoomLimits(to chart: CombinedChartView) {
        let axisWidth = chart.xAxis.axisRange  // X軸全体の本数(前後の余白 0.5 本ずつを含む)
        guard axisWidth > 0 else { return }

        // 縮小の限界(最大の表示本数)
        var maximumCount = axisWidth
        if let maximumVisibleCount = self.style.maximumVisibleCount {
            maximumCount = min(Double(maximumVisibleCount), axisWidth)
        }
        chart.setVisibleXRangeMaximum(maximumCount)

        // 拡大の限界(最小の表示本数)
        if let minimumVisibleCount = self.style.minimumVisibleCount {
            let minimumCount = min(Double(minimumVisibleCount), axisWidth)
            chart.setVisibleXRangeMinimum(minimumCount)
        }
    }

    // MARK: - 凡例

    /// メイン・サブの凡例を、表示中の内容に合わせて設定する
    private func updateLegends() {
        // メインチャートの凡例: 「タイトル + 各線のラベル」を並べる
        //   例) 移動平均線       → 「移動平均 短期移動平均(5) 長期移動平均(25)」
        //       ボリンジャーバンド → 「ボリンジャー 移動平均(5)」(文字は既存アプリと同じ)
        // ・タイトル(legendTitle)と各線のラベル(label)は Model(ChartContentBuilder)で決めている
        // ・label が nil の線は凡例に出さない(ボリンジャーバンドの下限線、パラボリックの点など)
        // ・「なし(ローソク足のみ)」はタイトルも線もないので、凡例は空(nil)になる
        // ・線を持たない項目(新値足の「新値足　■陰線　□陽線」、多重移動平均の「期間(5,75)」など)は、各線のラベルのあとに並べる
        let mainItems = self.legendItems(of: self.mainContent.series) + self.mainContent.legendItems
        self.priceLegendLabel.attributedText = self.makeLegend(title: self.mainContent.legendTitle, items: mainItems)

        // サブチャートの凡例: 「タイトル + 棒のラベル + 各線のラベル」の順に並べる
        //   例) 出来高 → 「出来高 出来高移動平均」(タイトルなし。棒のラベル「出来高」が先頭)
        //       RSI    → 「ＲＳＩ 期間(14)」
        //       DMI    → 「ＤＭＩ DI -DI」
        guard let sub = self.subContent else {
            self.subLegendLabel.attributedText = nil
            return
        }
        var subItems: [ChartLegendItem] = []
        if let bars = sub.bars, let barLabel = bars.label {
            subItems.append(ChartLegendItem(text: barLabel, colorRole: bars.labelColorRole))
        }
        subItems += self.legendItems(of: sub.series)
        self.subLegendLabel.attributedText = self.makeLegend(title: sub.legendTitle, items: subItems)
    }

    /// 線のうち、凡例に出すもの(label があるもの)を凡例の項目にする
    private func legendItems(of series: [ChartSeries]) -> [ChartLegendItem] {
        var items: [ChartLegendItem] = []
        for line in series {
            guard let label = line.label else { continue }  // label が nil の線は凡例に出さない
            items.append(ChartLegendItem(text: label, colorRole: line.colorRole))
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
    private func makeLegend(title: String?, items: [ChartLegendItem]) -> NSAttributedString? {
        // (文字, 色) の組を並べる
        var parts: [(text: String, color: UIColor)] = []
        if let title {
            parts.append((text: title, color: self.style.textColor))
        }
        for item in items {
            parts.append((text: item.text, color: self.style.color(for: item.colorRole)))
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
                .font: self.style.legendFont,
            ]
            legend.append(NSAttributedString(string: part.text, attributes: attributes))
        }
        return legend
    }

    // MARK: - DGCharts のデータを作る

    /// メインチャートのデータ(ローソク足 + メイン指標)を作る
    private func makePriceData() -> CombinedChartData {
        let data = CombinedChartData()
        switch self.mainContent.priceStyle {
        case .candles:
            data.candleData = CandleChartData(dataSet: self.makeCandleSet())
        case .newPrice:
            data.candleData = CandleChartData(dataSet: self.makeNewPriceSet())
        case .hidden:
            break  // 足は描かない(VWAP など)
        }
        self.addSeries(self.mainContent.series, to: data)
        return data
    }

    /// 表示中の足を、DGCharts の足(X = 何本目か、Y = 4本値)に変換する
    private func makeCandleEntries() -> [CandleChartDataEntry] {
        var candleEntries: [CandleChartDataEntry] = []
        for (index, candle) in self.candles.enumerated() {
            let entry = CandleChartDataEntry(x: Double(index),
                                             shadowH: candle.high,  // ヒゲの上端 = 高値
                                             shadowL: candle.low,   // ヒゲの下端 = 安値
                                             open: candle.open,
                                             close: candle.close)
            candleEntries.append(entry)
        }
        return candleEntries
    }

    /// ローソク足のデータセットを作る
    private func makeCandleSet() -> CandleChartDataSet {
        let candleSet = CandleChartDataSet(entries: self.makeCandleEntries(), label: "ローソク足")
        candleSet.axisDependency = .right               // 右のY軸を基準に描画する
        candleSet.drawValuesEnabled = false             // 各足の値ラベルは表示しない
        candleSet.highlightEnabled = false
        candleSet.increasingColor = self.style.increasingColor
        candleSet.increasingFilled = true               // 陽線も塗りつぶす(日本式)
        candleSet.decreasingColor = self.style.decreasingColor
        candleSet.decreasingFilled = true
        candleSet.neutralColor = self.style.textColor        // 始値 = 終値(同事線)の色
        candleSet.shadowColorSameAsCandle = true        // ヒゲを実体と同じ色にする
        candleSet.shadowWidth = 1
        candleSet.barSpace = 0.15                       // 足同士の隙間(1本分の幅に対する割合)
        return candleSet
    }

    /// 新値足のデータセットを作る(新値足の1本をローソク足の実体として描く)
    ///
    ///   ・陽線は枠だけ、陰線は塗りつぶし(色はどちらも新値足の色)
    ///   ・ヒゲはなし(高値・安値は実体の両端と同じ。ヒゲの線は透明にする)
    ///   ・隣の足との隙間はなし(階段状につながって見える)
    private func makeNewPriceSet() -> CandleChartDataSet {
        let candleSet = CandleChartDataSet(entries: self.makeCandleEntries(), label: "新値足")
        candleSet.axisDependency = .right
        candleSet.drawValuesEnabled = false
        candleSet.highlightEnabled = false
        candleSet.increasingColor = self.style.newPriceColor
        candleSet.increasingFilled = false              // 陽線は枠だけ
        candleSet.decreasingColor = self.style.newPriceColor
        candleSet.decreasingFilled = true               // 陰線は塗りつぶし
        candleSet.neutralColor = self.style.newPriceColor
        candleSet.shadowColorSameAsCandle = false
        candleSet.shadowColor = .clear                  // ヒゲ(実体の中央の縦線)は描かない
        candleSet.shadowWidth = 1.5                     // 枠の線の太さ(DGCharts は枠もこの太さで描く)
        candleSet.barSpace = 0                          // 足同士の隙間なし
        return candleSet
    }

    /// サブチャートのデータ(棒グラフ + 線)を作る
    private func makeSubData(_ content: SubChartContent) -> CombinedChartData {
        let data = CombinedChartData()

        if let bars = content.bars {
            data.barData = self.makeBarData(bars)
        }
        self.addSeries(content.series, to: data)

        // 点が1つもない場合(指数の1分足・日中足の出来高など)、DGCharts は軸(X軸の日付ラベル)も描かなくなる。
        // 日付ラベルはサブチャートに表示しているので、見えない線をX軸の両端に置いて、軸が描かれるようにする
        if data.entryCount == 0 {
            data.lineData = LineChartData(dataSet: self.makeInvisibleAnchorSet())
        }
        return data
    }

    /// 軸を描かせるためだけの、見えない線(X軸の左端と右端に1点ずつ)
    private func makeInvisibleAnchorSet() -> LineChartDataSet {
        let entries = [
            ChartDataEntry(x: Double(-self.leadingBlankCount), y: 0),
            ChartDataEntry(x: Double(self.totalCount - 1), y: 0),
        ]
        let set = LineChartDataSet(entries: entries, label: "")
        set.axisDependency = .right
        set.setColor(.clear)            // 透明なので画面には何も見えない
        set.drawCirclesEnabled = false
        set.drawValuesEnabled = false
        set.highlightEnabled = false
        return set
    }

    /// 棒グラフ(出来高)のデータを作る
    private func makeBarData(_ bars: ChartBars) -> BarChartData {
        // nil の位置は棒を作らない。色は棒ごとに指定する(作った棒と同じ並びにする)
        var entries: [BarChartDataEntry] = []
        var colors: [UIColor] = []
        for (index, value) in bars.values.enumerated() {
            guard let value else { continue }
            entries.append(BarChartDataEntry(x: Double(index), y: value))
            colors.append(self.style.color(for: bars.colorRoles[index]))
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
                lineSets.append(self.makeLineSet(series))
            case .dots:
                dotSets.append(self.makeScatterSet(series))
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
        let set = LineChartDataSet(entries: self.makeEntries(series.values), label: series.label ?? "")
        set.axisDependency = .right
        set.setColor(self.style.color(for: series.colorRole))
        set.lineWidth = 1.2
        set.drawCirclesEnabled = false  // データ点の丸は描かない
        set.drawValuesEnabled = false
        set.highlightEnabled = false
        set.mode = .linear              // 点と点を直線で結ぶ
        return set
    }

    /// 点(パラボリック)用のデータセットを作る
    private func makeScatterSet(_ series: ChartSeries) -> ScatterChartDataSet {
        let set = ScatterChartDataSet(entries: self.makeEntries(series.values), label: series.label ?? "")
        set.axisDependency = .right
        set.setScatterShape(.circle)
        set.scatterShapeSize = 3
        set.setColor(self.style.color(for: series.colorRole))
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
        let axis = self.subChartView.rightAxis

        // 基準線(RSI の 20/80 など)を引く
        axis.removeAllLimitLines()
        for level in content.referenceLines {
            let line = ChartLimitLine(limit: level)
            line.lineColor = self.style.referenceLineColor
            line.lineWidth = 0.8
            // 既存アプリと同じく実線(破線にしない)
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

//
//  ChartContentBuilder.swift
//  ChartTest
//
//  【Model】ローソク足データ + 選択された指標 + パラメータ から、
//  チャートに描く内容(MainChartContent / SubChartContent)を組み立てる。
//
//  ・指標の計算そのものは TechnicalIndicators に任せ、ここでは
//    「どの計算結果を、どの名前・どの色の役割で描くか」を決める。
//  ・UIKit / DGCharts には依存しない。
//
//  【凡例のラベル】
//  ここで付けた legendTitle / label が、そのままチャート左上の凡例の文字列になる
//  (StockChartView の render → makeLegend で、半角スペース区切りの1行にまとめて表示される)。
//
//    MainChartContent(legendTitle: "移動平均", series: [
//        ChartSeries(label: "短期移動平均(5)",  …, colorRole: .line(0)),
//        ChartSeries(label: "長期移動平均(25)", …, colorRole: .line(1)),
//    ])
//      ↓
//    凡例:「移動平均 短期移動平均(5) 長期移動平均(25)」
//          ~~~~~~~~ ~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
//          文字色    line(0) の色     line(1) の色
//
//  ・legendTitle が nil ならタイトルなしで、各線のラベルだけを並べる(出来高・RSI など)
//  ・label が nil の線は描画するが凡例には出さない(ボリンジャーバンドの下限線など、同じ色の線が2本ある場合)
//  ・サブチャートの棒(ChartBars)にラベルがある場合は、線のラベルより前に並ぶ(出来高 → 出来高移動平均)
//  ・ラベルの表示位置(凡例の置き場所)は View(StockChartView)の責務で、ここでは決めない
//

import Foundation

struct ChartContentBuilder {

    /// 日付の古い順に並んだローソク足データ
    let candles: [StockCandle]
    /// 指標の計算パラメータ
    let parameters: IndicatorParameters

    // 計算によく使う列を先に取り出しておく
    private var closes: [Double] { self.candles.map { candle in candle.close } }
    private var highs: [Double] { self.candles.map { candle in candle.high } }
    private var lows: [Double] { self.candles.map { candle in candle.low } }

    // MARK: - チャート種類

    /// 新値足の転換に使う本数(3本新値)
    static let newPriceReversalCount = 3
    /// 新値足の表示本数(本数が少ないときは右寄せで表示する)
    static let newPriceVisibleCount = 50

    /// チャート種類に合わせて、表示する内容一式を作る
    /// - Parameters:
    ///   - chartType: チャートの種類
    ///   - mainIndicator: メインチャートの指標(ローソク足・海外指数の折線チャートのときだけ使う)
    ///   - subIndicator: サブチャートの指標(ローソク足のときだけ使う)
    ///   - market: 指数の種類(海外指数の折線チャートは、終値の線にメイン指標を重ね、現在値の破線を引く)
    func content(for chartType: ChartType, mainIndicator: MainChartIndicator,
                 subIndicator: SubChartIndicator, market: IndexMarket = .domestic) -> ChartContent {
        switch chartType {
        case .candlestick:
            return ChartContent(candles: self.candles,
                                main: self.mainContent(for: mainIndicator),
                                sub: self.subContent(for: subIndicator))
        case .vwapLine:
            return self.vwapContent(title: chartType.title, style: .line)
        case .vwapDots:
            return self.vwapContent(title: chartType.title, style: .dots)
        case .newPrice:
            return self.newPriceContent()
        case .lineChart:
            switch market {
            case .domestic:
                return self.lineChartContent()
            case .overseas:
                return self.closeLineContent(with: mainIndicator, showsCurrentPrice: true)
            }
        }
    }

    /// 折線チャートの内容(ローソク足は描かず、終値を線で結ぶ。サブチャートなし)
    ///
    ///   凡例:「折線チャート」(線の色)
    ///   現在値(最新の足の終値)の位置に破線を引く
    private func lineChartContent() -> ChartContent {
        let values: [Double?] = self.closes.map { close in close }
        let main = MainChartContent(
            series: [ChartSeries(label: ChartType.lineChart.title, values: values, colorRole: .closeLine)],
            priceStyle: .hidden,
            currentPrice: self.candles.last?.close)
        return ChartContent(candles: self.candles, main: main, sub: nil)
    }

    /// VWAP の内容(ローソク足は描かず、VWAP の線または点だけを描く。サブチャートなし)
    private func vwapContent(title: String, style: ChartSeries.Style) -> ChartContent {
        let values = TechnicalIndicators.vwap(
            dates: self.candles.map { candle in candle.date }, highs: self.highs, lows: self.lows, closes: self.closes,
            volumes: self.candles.map { candle in candle.volume })
        let main = MainChartContent(
            series: [ChartSeries(label: title, values: values, colorRole: .vwap, style: style)],
            priceStyle: .hidden)

        // 出来高がないデータ(指数の1分足・日中足など)は VWAP を計算できないので、
        // 凡例だけ残して「表示できる情報はありません」と表示する
        let hasValue = values.contains { value in value != nil }
        guard hasValue else {
            return ChartContent(candles: [], main: main, sub: nil)
        }
        return ChartContent(candles: self.candles, main: main, sub: nil)
    }

    /// 新値足の内容(新値足の1本を1つの足として並べる。サブチャートなし)
    ///
    ///   凡例:「新値足 ■陰線 □陽線」(すべて新値足の色)
    ///   現在値(最新の足の終値)の位置に破線を引く
    private func newPriceContent() -> ChartContent {
        let lines = TechnicalIndicators.newPriceLines(
            dates: self.candles.map { candle in candle.date }, closes: self.closes,
            reversalCount: Self.newPriceReversalCount)

        // 新値足の1本 = ローソク足の「始値 = 始点、終値 = 終点」として並べる(ヒゲはないので高値・安値は線の両端)
        let lineCandles = lines.map { line in
            StockCandle(date: line.date, open: line.start, high: line.high, low: line.low, close: line.end, volume: 0)
        }
        let main = MainChartContent(
            priceStyle: .newPrice,
            legendItems: [
                ChartLegendItem(text: ChartType.newPrice.title, colorRole: .newPrice),
                ChartLegendItem(text: "■陰線", colorRole: .newPrice),
                ChartLegendItem(text: "□陽線", colorRole: .newPrice),
            ],
            currentPrice: self.candles.last?.close,
            fixedVisibleCount: Self.newPriceVisibleCount)
        return ChartContent(candles: lineCandles, main: main, sub: nil)
    }

    // MARK: - 終値の折れ線 + 指標(海外指数の横画面の折線チャート)

    /// ローソク足の代わりに終値を折れ線で描き、指定した指標を重ねる内容を作る(サブチャートなし)。
    /// 海外指数の横画面の折線チャートで使う。
    /// 凡例は指標のもの(「移動平均 短期移動平均(5) 長期移動平均(25)」など)で、終値の線は凡例に出さない
    /// - Parameters:
    ///   - indicator: 重ねる指標
    ///   - showsCurrentPrice: 現在値(最新の終値)に破線を引くか(横画面の折線チャートでは引く)
    func closeLineContent(with indicator: MainChartIndicator, showsCurrentPrice: Bool = false) -> ChartContent {
        var main = self.mainContent(for: indicator)
        main.priceStyle = .hidden
        if showsCurrentPrice {
            main.currentPrice = self.candles.last?.close
        }
        // 終値の線は凡例に出さない(label: nil)。指標の線より下に描くよう先頭に入れる
        let closeLine = ChartSeries(label: nil, values: self.closes.map { close in close }, colorRole: .closeLine)
        main.series.insert(closeLine, at: 0)
        return ChartContent(candles: self.candles, main: main, sub: nil)
    }

    // MARK: - メインチャート

    /// メインチャート(ローソク足に重ねる部分)の描画内容を作る
    func mainContent(for indicator: MainChartIndicator) -> MainChartContent {
        switch indicator {
        case .movingAverage:
            return self.movingAverageContent()
        case .multipleMovingAverage:
            return self.multipleMovingAverageContent()
        case .bollingerBands:
            return self.bollingerBandsContent()
        case .ichimoku:
            return self.ichimokuContent()
        case .parabolic:
            return self.parabolicContent()
        case .candleOnly:
            // ローソク足のみ(凡例もなし)
            return MainChartContent()
        }
    }

    /// 移動平均線: 短期・長期の2本
    ///   凡例:「移動平均 短期移動平均(5) 長期移動平均(25)」
    private func movingAverageContent() -> MainChartContent {
        let shortLine = ChartSeries(label: "短期移動平均(\(parameters.shortMAPeriod))",
                                    values: TechnicalIndicators.sma(self.closes, period: self.parameters.shortMAPeriod),
                                    colorRole: .line(0))
        let longLine = ChartSeries(label: "長期移動平均(\(parameters.longMAPeriod))",
                                   values: TechnicalIndicators.sma(self.closes, period: self.parameters.longMAPeriod),
                                   colorRole: .line(1))
        return MainChartContent(legendTitle: "移動平均", series: [shortLine, longLine])
    }

    /// 多重移動平均線: 設定された期間の数だけ移動平均線を引く(色は 1本目、2本目、… の順)
    ///   凡例:「多重移動平均 5 40 75」
    private func multipleMovingAverageContent() -> MainChartContent {
        var series: [ChartSeries] = []
        for (lineNumber, period) in self.parameters.multipleMAPeriods.enumerated() {
            let line = ChartSeries(label: "\(period)",
                                   values: TechnicalIndicators.sma(self.closes, period: period),
                                   colorRole: .line(lineNumber))
            series.append(line)
        }
        return MainChartContent(legendTitle: "多重移動平均", series: series)
    }

    /// ボリンジャーバンド: 中心線 + σ の倍率ごとの上限・下限
    ///   凡例:「ボリンジャーバンド(20) 中心線 ±1σ ±2σ」
    ///   色: 中心線は 2本目の色。バンドは 1本目、3本目、4本目、… の色(中心線と同じ色を避ける)
    private func bollingerBandsContent() -> MainChartContent {
        let result = TechnicalIndicators.bollingerBands(
            closes: self.closes, period: self.parameters.bollingerPeriod, sigmas: self.parameters.bollingerSigmas)

        var series = [ChartSeries(label: "中心線", values: result.middle, colorRole: .line(1))]
        for (bandNumber, band) in result.bands.enumerated() {
            let role = ChartColorRole.line(self.bollingerBandColorIndex(bandNumber: bandNumber))
            let sigma = String(format: "%g", band.sigma)  // 1.0 → "1"
            // 上限と下限は同じ色。凡例は上限側だけに表示する
            series.append(ChartSeries(label: "±\(sigma)σ", values: band.upper, colorRole: role))
            series.append(ChartSeries(label: nil, values: band.lower, colorRole: role))
        }
        return MainChartContent(legendTitle: "ボリンジャーバンド(\(self.parameters.bollingerPeriod))", series: series)
    }

    /// ボリンジャーバンドの何組目かから、線の色の番号を決める。
    /// 中心線が 1 番の色を使うので、バンドは 1 番を飛ばす(0, 2, 3, 4, …)
    private func bollingerBandColorIndex(bandNumber: Int) -> Int {
        if bandNumber == 0 {
            return 0
        }
        return bandNumber + 1
    }

    /// 一目均衡表: 転換線・基準線・先行スパン1/2・遅行スパン + 雲
    ///   先行スパンは未来へずらして描くので、データの右端より先にも描く(futureCount)
    private func ichimokuContent() -> MainChartContent {
        let result = TechnicalIndicators.ichimoku(
            highs: self.highs, lows: self.lows, closes: self.closes,
            tenkanPeriod: self.parameters.ichimokuTenkanPeriod, kijunPeriod: self.parameters.ichimokuKijunPeriod,
            spanBPeriod: self.parameters.ichimokuSpanBPeriod, shift: self.parameters.ichimokuShift)
        return MainChartContent(
            legendTitle: "一目均衡表",
            series: [
                ChartSeries(label: "転換線", values: result.tenkan, colorRole: .ichimokuTenkan),
                ChartSeries(label: "基準線", values: result.kijun, colorRole: .ichimokuKijun),
                ChartSeries(label: "先行1", values: result.spanA, colorRole: .ichimokuSpanA),
                ChartSeries(label: "先行2", values: result.spanB, colorRole: .ichimokuSpanB),
                ChartSeries(label: "遅行", values: result.chikou, colorRole: .ichimokuChikou),
            ],
            cloud: ChartCloud(spanA: result.spanA, spanB: result.spanB),
            futureCount: result.futureCount)
    }

    /// パラボリック: SAR の点。上昇トレンド中と下降トレンド中で色を分ける
    private func parabolicContent() -> MainChartContent {
        let result = TechnicalIndicators.parabolicSAR(
            highs: self.highs, lows: self.lows, closes: self.closes,
            step: self.parameters.parabolicStep, maximum: self.parameters.parabolicMaximum)

        // 同じ長さの配列を2つ用意し、各足の SAR をトレンドに応じてどちらか一方にだけ入れる
        // (もう一方は nil = 点を描かない)
        var uptrendValues = [Double?](repeating: nil, count: result.values.count)
        var downtrendValues = [Double?](repeating: nil, count: result.values.count)
        for (index, value) in result.values.enumerated() {
            if result.isUptrend[index] {
                uptrendValues[index] = value
            } else {
                downtrendValues[index] = value
            }
        }
        return MainChartContent(
            legendTitle: String(format: "パラボリック(%g, %g)", self.parameters.parabolicStep, self.parameters.parabolicMaximum),
            series: [
                ChartSeries(label: nil, values: uptrendValues, colorRole: .increasing, style: .dots),
                ChartSeries(label: nil, values: downtrendValues, colorRole: .decreasing, style: .dots),
            ])
    }

    // MARK: - サブチャート

    /// サブチャートの描画内容を作る。サブなし(.hidden)の場合は nil
    func subContent(for indicator: SubChartIndicator) -> SubChartContent? {
        switch indicator {
        case .volume:
            return self.volumeContent()
        case .movingAverageDeviation:
            return self.movingAverageDeviationContent()
        case .rsi:
            return self.rsiContent()
        case .psychological:
            return self.psychologicalContent()
        case .stochastics:
            return self.stochasticsContent()
        case .macd:
            return self.macdContent()
        case .dmi:
            return self.dmiContent()
        case .hidden:
            return nil
        }
    }

    /// 出来高: 出来高の棒 + 出来高移動平均線
    ///   凡例:「出来高 出来高移動平均」
    private func volumeContent() -> SubChartContent {
        let volumes = self.candles.map { candle in candle.volume }
        var barValues: [Double?] = volumes.map { volume in volume }
        var averageValues = TechnicalIndicators.sma(volumes, period: self.parameters.volumeMAPeriod)

        // 出来高がすべて 0 のデータ(指数の1分足・日中足など、出来高が配信されないもの)は、
        // 棒も移動平均線も描かない(凡例だけ表示する)
        let hasVolume = volumes.contains { volume in volume > 0 }
        if !hasVolume {
            barValues = volumes.map { _ in nil }
            averageValues = volumes.map { _ in nil }
        }

        let averageLine = ChartSeries(label: "出来高移動平均", values: averageValues, colorRole: .volumeAverage)
        let bars = ChartBars(label: self.parameters.volumeLegendLabel, labelColorRole: .volume,
                             values: barValues, colorRoles: volumes.map { _ in .volume })
        return SubChartContent(series: [averageLine], bars: bars, includesZero: true)
    }

    /// 移動平均乖離率: 短期・長期の移動平均からの乖離率(%)。
    /// 0% と底値・高値ライン(既定 -10% / 10%)に基準線を引く
    private func movingAverageDeviationContent() -> SubChartContent {
        let shortPeriod = self.parameters.deviationShortPeriod
        let longPeriod = self.parameters.deviationLongPeriod
        let shortLine = ChartSeries(label: "短期(\(shortPeriod))",
                                    values: TechnicalIndicators.movingAverageDeviation(closes: self.closes, period: shortPeriod),
                                    colorRole: .line(0))
        let longLine = ChartSeries(label: "長期(\(longPeriod))",
                                   values: TechnicalIndicators.movingAverageDeviation(closes: self.closes, period: longPeriod),
                                   colorRole: .line(1))
        let referenceLines = [Double(self.parameters.deviationLowerLine), 0, Double(self.parameters.deviationUpperLine)]
        return SubChartContent(legendTitle: "移動平均乖離率", series: [shortLine, longLine],
                               referenceLines: referenceLines,
                               includesZero: true, fractionDigits: 1, suffix: "%")
    }

    /// RSI: 0〜100 の固定範囲。底値ライン(既定 30%・売られすぎ)と高値ライン(既定 70%・買われすぎ)に基準線を引く
    private func rsiContent() -> SubChartContent {
        let line = ChartSeries(label: "RSI(\(parameters.rsiPeriod))",
                               values: TechnicalIndicators.rsi(closes: self.closes, period: self.parameters.rsiPeriod),
                               colorRole: .line(2))
        let referenceLines = [Double(self.parameters.rsiLowerLine), Double(self.parameters.rsiUpperLine)]
        return SubChartContent(series: [line], referenceLines: referenceLines, fixedRange: 0...100)
    }

    /// サイコロジカルライン: 0〜100 の固定範囲。底値・高値ライン(既定 25% / 75%)に基準線を引く
    private func psychologicalContent() -> SubChartContent {
        let line = ChartSeries(label: "サイコロジカル(\(parameters.psychologicalPeriod))",
                               values: TechnicalIndicators.psychological(closes: self.closes, period: self.parameters.psychologicalPeriod),
                               colorRole: .line(3))
        let referenceLines = [Double(self.parameters.psychologicalLowerLine), Double(self.parameters.psychologicalUpperLine)]
        return SubChartContent(series: [line], referenceLines: referenceLines, fixedRange: 0...100)
    }

    /// ストキャスティクス: %K と %D。0〜100 の固定範囲。底値・高値ライン(既定 20% / 80%)に基準線を引く
    private func stochasticsContent() -> SubChartContent {
        let result = TechnicalIndicators.stochastics(
            highs: self.highs, lows: self.lows, closes: self.closes,
            kPeriod: self.parameters.stochasticsKPeriod, dPeriod: self.parameters.stochasticsDPeriod)
        let kLine = ChartSeries(label: "%K(\(parameters.stochasticsKPeriod))", values: result.k, colorRole: .line(0))
        let dLine = ChartSeries(label: "%D(\(parameters.stochasticsDPeriod))", values: result.d, colorRole: .line(1))
        let referenceLines = [Double(self.parameters.stochasticsLowerLine), Double(self.parameters.stochasticsUpperLine)]
        return SubChartContent(legendTitle: "ストキャス", series: [kLine, dLine],
                               referenceLines: referenceLines, fixedRange: 0...100)
    }

    /// MACD: MACD・シグナルの線 + ヒストグラム(正/負で色分け)。0 に基準線を引く
    private func macdContent() -> SubChartContent {
        let result = TechnicalIndicators.macd(
            closes: self.closes, shortPeriod: self.parameters.macdShortPeriod,
            longPeriod: self.parameters.macdLongPeriod, signalPeriod: self.parameters.macdSignalPeriod)

        let macdLine = ChartSeries(label: "MACD(\(parameters.macdShortPeriod),\(self.parameters.macdLongPeriod))",
                                   values: result.macd, colorRole: .line(3))
        let signalLine = ChartSeries(label: "シグナル(\(parameters.macdSignalPeriod))",
                                     values: result.signal, colorRole: .line(1))
        let histogramRoles = result.histogram.map { value in self.histogramColorRole(for: value) }
        let histogram = ChartBars(label: nil, labelColorRole: .histogramPositive,
                                  values: result.histogram, colorRoles: histogramRoles)
        return SubChartContent(series: [macdLine, signalLine], bars: histogram,
                               referenceLines: [0], includesZero: true, fractionDigits: 2)
    }

    /// MACD のヒストグラムの棒の色: 負の値は負の色、0 以上(値なしを含む)は正の色
    private func histogramColorRole(for value: Double?) -> ChartColorRole {
        guard let value else { return .histogramPositive }
        if value < 0 {
            return .histogramNegative
        }
        return .histogramPositive
    }

    /// DMI: +DI(上昇色)・−DI(下降色)・ADX
    private func dmiContent() -> SubChartContent {
        let result = TechnicalIndicators.dmi(highs: self.highs, lows: self.lows, closes: self.closes, period: self.parameters.dmiPeriod)
        return SubChartContent(
            legendTitle: "DMI(\(self.parameters.dmiPeriod))",
            series: [
                ChartSeries(label: "+DI", values: result.plusDI, colorRole: .increasing),
                ChartSeries(label: "−DI", values: result.minusDI, colorRole: .decreasing),
                ChartSeries(label: "ADX", values: result.adx, colorRole: .line(1)),
            ],
            includesZero: true)
    }
}

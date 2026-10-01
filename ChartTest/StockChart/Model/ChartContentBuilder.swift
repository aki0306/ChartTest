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
    private var closes: [Double] { candles.map { candle in candle.close } }
    private var highs: [Double] { candles.map { candle in candle.high } }
    private var lows: [Double] { candles.map { candle in candle.low } }

    // MARK: - チャート種類

    /// 新値足の転換に使う本数(3本新値)
    static let newPriceReversalCount = 3
    /// 新値足の表示本数(本数が少ないときは右寄せで表示する)
    static let newPriceVisibleCount = 50

    /// チャート種類に合わせて、表示する内容一式を作る
    /// - Parameters:
    ///   - chartType: チャートの種類
    ///   - mainIndicator: メインチャートの指標(ローソク足のときだけ使う)
    ///   - subIndicator: サブチャートの指標(ローソク足のときだけ使う)
    func content(for chartType: ChartType, mainIndicator: MainChartIndicator,
                 subIndicator: SubChartIndicator) -> ChartContent {
        switch chartType {
        case .candlestick:
            return ChartContent(candles: candles,
                                main: mainContent(for: mainIndicator),
                                sub: subContent(for: subIndicator))
        case .vwapLine:
            return vwapContent(title: chartType.title, style: .line)
        case .vwapDots:
            return vwapContent(title: chartType.title, style: .dots)
        case .newPrice:
            return newPriceContent()
        case .lineChart:
            return lineChartContent()
        }
    }

    /// 折線チャートの内容(ローソク足は描かず、終値を線で結ぶ。サブチャートなし)
    ///
    ///   凡例:「折線チャート」(線の色)
    ///   現在値(最新の足の終値)の位置に破線を引く
    private func lineChartContent() -> ChartContent {
        let values: [Double?] = closes.map { close in close }
        let main = MainChartContent(
            series: [ChartSeries(label: ChartType.lineChart.title, values: values, colorRole: .closeLine)],
            priceStyle: .hidden,
            currentPrice: candles.last?.close)
        return ChartContent(candles: candles, main: main, sub: nil)
    }

    /// VWAP の内容(ローソク足は描かず、VWAP の線または点だけを描く。サブチャートなし)
    private func vwapContent(title: String, style: ChartSeries.Style) -> ChartContent {
        let values = TechnicalIndicators.vwap(
            dates: candles.map { candle in candle.date }, highs: highs, lows: lows, closes: closes,
            volumes: candles.map { candle in candle.volume })
        let main = MainChartContent(
            series: [ChartSeries(label: title, values: values, colorRole: .vwap, style: style)],
            priceStyle: .hidden)

        // 出来高がないデータ(指数の1分足・日中足など)は VWAP を計算できないので、
        // 凡例だけ残して「表示できる情報はありません」と表示する
        let hasValue = values.contains { value in value != nil }
        guard hasValue else {
            return ChartContent(candles: [], main: main, sub: nil)
        }
        return ChartContent(candles: candles, main: main, sub: nil)
    }

    /// 新値足の内容(新値足の1本を1つの足として並べる。サブチャートなし)
    ///
    ///   凡例:「新値足 ■陰線 □陽線」(すべて新値足の色)
    ///   現在値(最新の足の終値)の位置に破線を引く
    private func newPriceContent() -> ChartContent {
        let lines = TechnicalIndicators.newPriceLines(
            dates: candles.map { candle in candle.date }, closes: closes,
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
            currentPrice: candles.last?.close,
            fixedVisibleCount: Self.newPriceVisibleCount)
        return ChartContent(candles: lineCandles, main: main, sub: nil)
    }

    // MARK: - メインチャート

    /// メインチャート(ローソク足に重ねる部分)の描画内容を作る
    func mainContent(for indicator: MainChartIndicator) -> MainChartContent {
        switch indicator {
        case .movingAverage:
            // 短期・長期の移動平均線
            return MainChartContent(legendTitle: "移動平均", series: [
                ChartSeries(label: "短期移動平均(\(parameters.shortMAPeriod))",
                            values: TechnicalIndicators.sma(closes, period: parameters.shortMAPeriod),
                            colorRole: .line(0)),
                ChartSeries(label: "長期移動平均(\(parameters.longMAPeriod))",
                            values: TechnicalIndicators.sma(closes, period: parameters.longMAPeriod),
                            colorRole: .line(1)),
            ])

        case .multipleMovingAverage:
            // 指定された期間の数だけ移動平均線を引く(色は 1本目、2本目、… の順)
            let series = parameters.multipleMAPeriods.enumerated().map { i, period in
                ChartSeries(label: "\(period)",
                            values: TechnicalIndicators.sma(closes, period: period),
                            colorRole: .line(i))
            }
            return MainChartContent(legendTitle: "多重移動平均", series: series)

        case .bollingerBands:
            // 中心線 + σ倍率ごとの上限/下限
            let result = TechnicalIndicators.bollingerBands(
                closes: closes, period: parameters.bollingerPeriod, sigmas: parameters.bollingerSigmas)
            // 中心線は 2本目の色。バンドは 1本目、3本目、4本目、… の色(中心線と同じ色を避ける)
            var series = [ChartSeries(label: "中心線", values: result.middle, colorRole: .line(1))]
            for (i, band) in result.bands.enumerated() {
                // 1組目は 1本目(0)の色、2組目以降は中心線の色(1)を飛ばして 3本目(2)、4本目(3)、… の色
                let colorIndex: Int
                if i == 0 {
                    colorIndex = 0
                } else {
                    colorIndex = i + 1
                }
                let role = ChartColorRole.line(colorIndex)
                let sigma = String(format: "%g", band.sigma)
                // 上限と下限は同じ色。凡例は上限側だけに表示する
                series.append(ChartSeries(label: "±\(sigma)σ", values: band.upper, colorRole: role))
                series.append(ChartSeries(label: nil, values: band.lower, colorRole: role))
            }
            return MainChartContent(legendTitle: "ボリンジャーバンド(\(parameters.bollingerPeriod))", series: series)

        case .ichimoku:
            let result = TechnicalIndicators.ichimoku(
                highs: highs, lows: lows, closes: closes,
                tenkanPeriod: parameters.ichimokuTenkanPeriod, kijunPeriod: parameters.ichimokuKijunPeriod,
                spanBPeriod: parameters.ichimokuSpanBPeriod, shift: parameters.ichimokuShift)
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

        case .parabolic:
            // 上昇トレンド中の SAR と下降トレンド中の SAR を別々の点列にして色分けする
            let result = TechnicalIndicators.parabolicSAR(
                highs: highs, lows: lows, closes: closes,
                step: parameters.parabolicStep, maximum: parameters.parabolicMaximum)
            // 同じ長さの配列を2つ用意し、各足の SAR をトレンドに応じてどちらか一方にだけ入れる(もう一方は nil = 点を描かない)
            var up = [Double?](repeating: nil, count: result.values.count)
            var down = [Double?](repeating: nil, count: result.values.count)
            for (i, value) in result.values.enumerated() {
                if result.isUptrend[i] {
                    up[i] = value
                } else {
                    down[i] = value
                }
            }
            return MainChartContent(
                legendTitle: String(format: "パラボリック(%g, %g)", parameters.parabolicStep, parameters.parabolicMaximum),
                series: [
                    ChartSeries(label: nil, values: up, colorRole: .increasing, style: .dots),
                    ChartSeries(label: nil, values: down, colorRole: .decreasing, style: .dots),
                ])

        case .candleOnly:
            // ローソク足のみ(凡例もなし)
            return MainChartContent()
        }
    }

    // MARK: - サブチャート

    /// サブチャートの描画内容を作る。サブなし(.hidden)の場合は nil
    func subContent(for indicator: SubChartIndicator) -> SubChartContent? {
        switch indicator {
        case .volume:
            // 出来高バー + 出来高移動平均線
            let volumes = candles.map { candle in candle.volume }
            var barValues: [Double?] = volumes.map { volume in volume }
            var averageValues = TechnicalIndicators.sma(volumes, period: parameters.volumeMAPeriod)

            // 出来高がすべて 0 のデータ(指数の1分足・日中足など、出来高が配信されないもの)は、
            // 棒も移動平均線も描かない(凡例だけ表示する)
            let hasVolume = volumes.contains { volume in volume > 0 }
            if !hasVolume {
                barValues = volumes.map { _ in nil }
                averageValues = volumes.map { _ in nil }
            }

            return SubChartContent(
                series: [ChartSeries(label: "出来高移動平均",
                                     values: averageValues,
                                     colorRole: .volumeAverage)],
                bars: ChartBars(label: parameters.volumeLegendLabel, labelColorRole: .volume,
                                values: barValues, colorRoles: volumes.map { _ in .volume }),
                includesZero: true)

        case .movingAverageDeviation:
            // 短期・長期の移動平均からの乖離率。0% と底値・高値ライン(既定 -10% / 10%)に基準線
            return SubChartContent(
                legendTitle: "移動平均乖離率",
                series: [
                    ChartSeries(label: "短期(\(parameters.deviationShortPeriod))",
                                values: TechnicalIndicators.movingAverageDeviation(closes: closes, period: parameters.deviationShortPeriod),
                                colorRole: .line(0)),
                    ChartSeries(label: "長期(\(parameters.deviationLongPeriod))",
                                values: TechnicalIndicators.movingAverageDeviation(closes: closes, period: parameters.deviationLongPeriod),
                                colorRole: .line(1)),
                ],
                referenceLines: [Double(parameters.deviationLowerLine), 0, Double(parameters.deviationUpperLine)],
                includesZero: true, fractionDigits: 1, suffix: "%")

        case .rsi:
            // 0〜100 の固定範囲。底値ライン(既定 30%・売られすぎ)/ 高値ライン(既定 70%・買われすぎ)に基準線
            return SubChartContent(
                series: [ChartSeries(label: "RSI(\(parameters.rsiPeriod))",
                                     values: TechnicalIndicators.rsi(closes: closes, period: parameters.rsiPeriod),
                                     colorRole: .line(2))],
                referenceLines: [Double(parameters.rsiLowerLine), Double(parameters.rsiUpperLine)],
                fixedRange: 0...100)

        case .psychological:
            // 0〜100 の固定範囲。底値・高値ライン(既定 25% / 75%)に基準線
            return SubChartContent(
                series: [ChartSeries(label: "サイコロジカル(\(parameters.psychologicalPeriod))",
                                     values: TechnicalIndicators.psychological(closes: closes, period: parameters.psychologicalPeriod),
                                     colorRole: .line(3))],
                referenceLines: [Double(parameters.psychologicalLowerLine), Double(parameters.psychologicalUpperLine)],
                fixedRange: 0...100)

        case .stochastics:
            // %K と %D。0〜100 の固定範囲。底値・高値ライン(既定 20% / 80%)に基準線
            let result = TechnicalIndicators.stochastics(
                highs: highs, lows: lows, closes: closes,
                kPeriod: parameters.stochasticsKPeriod, dPeriod: parameters.stochasticsDPeriod)
            return SubChartContent(
                legendTitle: "ストキャス",
                series: [
                    ChartSeries(label: "%K(\(parameters.stochasticsKPeriod))", values: result.k, colorRole: .line(0)),
                    ChartSeries(label: "%D(\(parameters.stochasticsDPeriod))", values: result.d, colorRole: .line(1)),
                ],
                referenceLines: [Double(parameters.stochasticsLowerLine), Double(parameters.stochasticsUpperLine)],
                fixedRange: 0...100)

        case .macd:
            // MACD・シグナルの線 + ヒストグラム(正/負で色分け)。0 に基準線
            let result = TechnicalIndicators.macd(
                closes: closes, shortPeriod: parameters.macdShortPeriod,
                longPeriod: parameters.macdLongPeriod, signalPeriod: parameters.macdSignalPeriod)
            // ヒストグラムの色: 0 以上(値なしを含む)は正の色、負の値は負の色
            let histogramRoles = result.histogram.map { value -> ChartColorRole in
                guard let value, value < 0 else { return .histogramPositive }
                return .histogramNegative
            }
            return SubChartContent(
                series: [
                    ChartSeries(label: "MACD(\(parameters.macdShortPeriod),\(parameters.macdLongPeriod))",
                                values: result.macd, colorRole: .line(3)),
                    ChartSeries(label: "シグナル(\(parameters.macdSignalPeriod))",
                                values: result.signal, colorRole: .line(1)),
                ],
                bars: ChartBars(label: nil, labelColorRole: .histogramPositive,
                                values: result.histogram, colorRoles: histogramRoles),
                referenceLines: [0], includesZero: true, fractionDigits: 2)

        case .dmi:
            // +DI(上昇色)・−DI(下降色)・ADX
            let result = TechnicalIndicators.dmi(highs: highs, lows: lows, closes: closes, period: parameters.dmiPeriod)
            return SubChartContent(
                legendTitle: "DMI(\(parameters.dmiPeriod))",
                series: [
                    ChartSeries(label: "+DI", values: result.plusDI, colorRole: .increasing),
                    ChartSeries(label: "−DI", values: result.minusDI, colorRole: .decreasing),
                    ChartSeries(label: "ADX", values: result.adx, colorRole: .line(1)),
                ],
                includesZero: true)

        case .hidden:
            return nil
        }
    }
}

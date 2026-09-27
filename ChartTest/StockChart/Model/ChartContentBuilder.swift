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

import Foundation

struct ChartContentBuilder {

    /// 日付の古い順に並んだローソク足データ
    let candles: [StockCandle]
    /// 指標の計算パラメータ
    let parameters: IndicatorParameters

    // 計算によく使う列を先に取り出しておく
    private var closes: [Double] { candles.map(\.close) }
    private var highs: [Double] { candles.map(\.high) }
    private var lows: [Double] { candles.map(\.low) }

    // MARK: - メインチャート

    /// メインチャート(ローソク足に重ねる部分)の描画内容を作る
    func mainContent(for indicator: MainChartIndicator) -> MainChartContent {
        let p = parameters

        switch indicator {
        case .movingAverage:
            // 短期・長期の移動平均線
            return MainChartContent(legendTitle: "移動平均", series: [
                ChartSeries(label: "短期移動平均(\(p.shortMAPeriod))",
                            values: TechnicalIndicators.sma(closes, period: p.shortMAPeriod),
                            colorRole: .line(0)),
                ChartSeries(label: "長期移動平均(\(p.longMAPeriod))",
                            values: TechnicalIndicators.sma(closes, period: p.longMAPeriod),
                            colorRole: .line(1)),
            ])

        case .multipleMovingAverage:
            // 指定された期間の数だけ移動平均線を引く(色は 1本目、2本目、… の順)
            let series = p.multipleMAPeriods.enumerated().map { i, period in
                ChartSeries(label: "\(period)",
                            values: TechnicalIndicators.sma(closes, period: period),
                            colorRole: .line(i))
            }
            return MainChartContent(legendTitle: "多重移動平均", series: series)

        case .bollingerBands:
            // 中心線 + σ倍率ごとの上限/下限
            let result = TechnicalIndicators.bollingerBands(
                closes: closes, period: p.bollingerPeriod, sigmas: p.bollingerSigmas)
            // 中心線は 2本目の色。バンドは 1本目、3本目、4本目、… の色(中心線と同じ色を避ける)
            var series = [ChartSeries(label: "中心線", values: result.middle, colorRole: .line(1))]
            for (i, band) in result.bands.enumerated() {
                let role = ChartColorRole.line(i == 0 ? 0 : i + 1)
                let sigma = String(format: "%g", band.sigma)
                // 上限と下限は同じ色。凡例は上限側だけに表示する
                series.append(ChartSeries(label: "±\(sigma)σ", values: band.upper, colorRole: role))
                series.append(ChartSeries(label: nil, values: band.lower, colorRole: role))
            }
            return MainChartContent(legendTitle: "ボリンジャーバンド(\(p.bollingerPeriod))", series: series)

        case .ichimoku:
            let result = TechnicalIndicators.ichimoku(
                highs: highs, lows: lows, closes: closes,
                tenkanPeriod: p.ichimokuTenkanPeriod, kijunPeriod: p.ichimokuKijunPeriod,
                spanBPeriod: p.ichimokuSpanBPeriod, shift: p.ichimokuShift)
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
                step: p.parabolicStep, maximum: p.parabolicMaximum)
            let up = zip(result.values, result.isUptrend).map { value, isUp in isUp ? value : nil }
            let down = zip(result.values, result.isUptrend).map { value, isUp in isUp ? nil : value }
            return MainChartContent(
                legendTitle: String(format: "パラボリック(%g, %g)", p.parabolicStep, p.parabolicMaximum),
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
        let p = parameters

        switch indicator {
        case .volume:
            // 出来高バー + 出来高移動平均線
            let volumes = candles.map(\.volume)
            return SubChartContent(
                series: [ChartSeries(label: "出来高移動平均",
                                     values: TechnicalIndicators.sma(volumes, period: p.volumeMAPeriod),
                                     colorRole: .volumeAverage)],
                bars: ChartBars(label: "出来高", labelColorRole: .volume,
                                values: volumes, colorRoles: volumes.map { _ in .volume }),
                includesZero: true)

        case .movingAverageDeviation:
            // 短期・長期の移動平均からの乖離率。0% に基準線
            return SubChartContent(
                legendTitle: "移動平均乖離率",
                series: [
                    ChartSeries(label: "短期(\(p.shortMAPeriod))",
                                values: TechnicalIndicators.movingAverageDeviation(closes: closes, period: p.shortMAPeriod),
                                colorRole: .line(0)),
                    ChartSeries(label: "長期(\(p.longMAPeriod))",
                                values: TechnicalIndicators.movingAverageDeviation(closes: closes, period: p.longMAPeriod),
                                colorRole: .line(1)),
                ],
                referenceLines: [0], includesZero: true, fractionDigits: 1, suffix: "%")

        case .rsi:
            // 0〜100 の固定範囲。30%(売られすぎ)/ 70%(買われすぎ)に基準線
            return SubChartContent(
                series: [ChartSeries(label: "RSI(\(p.rsiPeriod))",
                                     values: TechnicalIndicators.rsi(closes: closes, period: p.rsiPeriod),
                                     colorRole: .line(2))],
                referenceLines: [30, 70], fixedRange: 0...100)

        case .psychological:
            // 0〜100 の固定範囲。25% / 75% に基準線
            return SubChartContent(
                series: [ChartSeries(label: "サイコロジカル(\(p.psychologicalPeriod))",
                                     values: TechnicalIndicators.psychological(closes: closes, period: p.psychologicalPeriod),
                                     colorRole: .line(3))],
                referenceLines: [25, 75], fixedRange: 0...100)

        case .stochastics:
            // %K と %D。0〜100 の固定範囲。20% / 80% に基準線
            let result = TechnicalIndicators.stochastics(
                highs: highs, lows: lows, closes: closes,
                kPeriod: p.stochasticsKPeriod, dPeriod: p.stochasticsDPeriod)
            return SubChartContent(
                legendTitle: "ストキャス",
                series: [
                    ChartSeries(label: "%K(\(p.stochasticsKPeriod))", values: result.k, colorRole: .line(0)),
                    ChartSeries(label: "%D(\(p.stochasticsDPeriod))", values: result.d, colorRole: .line(1)),
                ],
                referenceLines: [20, 80], fixedRange: 0...100)

        case .macd:
            // MACD・シグナルの線 + ヒストグラム(正/負で色分け)。0 に基準線
            let result = TechnicalIndicators.macd(
                closes: closes, shortPeriod: p.macdShortPeriod,
                longPeriod: p.macdLongPeriod, signalPeriod: p.macdSignalPeriod)
            let histogramRoles = result.histogram.map { value -> ChartColorRole in
                (value ?? 0) >= 0 ? .histogramPositive : .histogramNegative
            }
            return SubChartContent(
                series: [
                    ChartSeries(label: "MACD(\(p.macdShortPeriod),\(p.macdLongPeriod))",
                                values: result.macd, colorRole: .line(3)),
                    ChartSeries(label: "シグナル(\(p.macdSignalPeriod))",
                                values: result.signal, colorRole: .line(1)),
                ],
                bars: ChartBars(label: nil, labelColorRole: .histogramPositive,
                                values: result.histogram, colorRoles: histogramRoles),
                referenceLines: [0], includesZero: true, fractionDigits: 2)

        case .dmi:
            // +DI(上昇色)・−DI(下降色)・ADX
            let result = TechnicalIndicators.dmi(highs: highs, lows: lows, closes: closes, period: p.dmiPeriod)
            return SubChartContent(
                legendTitle: "DMI(\(p.dmiPeriod))",
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

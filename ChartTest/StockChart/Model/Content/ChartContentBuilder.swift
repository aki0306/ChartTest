//
//  ChartContentBuilder.swift
//  ChartTest
//
//  【Model】ローソク足データ + 選択された指標 + パラメータ から、
//  チャートに描く内容(MainChartContent / SubChartContent)を組み立てる。
//
//  ・指標の計算そのものは TechnicalIndicators に任せ、ここでは
//    「どの計算結果を、どの名前・どの色の役割で描くか」を決める。
//  ・各指標の描く内容(movingAverageContent・rsiContent など)は、指標ごとのファイル
//    (Model/Indicators/Main/・Sub/)に extension で書いている。このファイルには、指標を選ぶ入口(mainContent・subContent)と、
//    チャートの種類(折線チャート・VWAP・新値足)と、指標のファイルで共通に使う部品(closes・precomputedValues・oscillatorContent など)を置いている。
//    (extension は別のファイルから private のものを使えないので、指標のファイルで使うものは private を付けていない)
//  ・チャートの外(Objective-C など)で計算した値(precomputed)がある指標は、計算せずにその値を使う
//    (凡例・色・軸の設定は同じ。ChartIndicatorValues)
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
    /// チャートの外で計算した指標の値。値がある指標は、計算せずにこの値を使う(nil ならすべて計算する)
    var precomputed: ChartIndicatorValues? = nil

    // 計算によく使う列(指標のファイルからも使う)。計算プロパティなので、参照するたびにローソク足から作り直す
    // (先に取り出して持っておくのではない。一目均衡表のように何度も参照すると、そのたびに作り直される)
    var closes: [Double] {
        return self.candles.map { candle in candle.close }
    }

    var highs: [Double] {
        return self.candles.map { candle in candle.high }
    }

    var lows: [Double] {
        return self.candles.map { candle in candle.low }
    }

    /// 折線チャートに描く終値。値が読めなかった足(埋めた足)は nil にして、前後の足を線でつなぐ
    /// (指標の計算には埋めた値を使う)
    private var drawnCloses: [Double?] {
        self.candles.map { candle in
            if candle.isFilled {
                return nil
            }
            return candle.close
        }
    }

    // MARK: - チャートの外で計算した値

    /// チャートの外で計算した値(ローソク足と同じ長さにそろえたもの)。ない場合は nil
    func precomputedValues(_ keyPath: KeyPath<ChartIndicatorValues, [NSNumber]?>) -> [Double?]? {
        guard let values = self.precomputed?[keyPath: keyPath] else {
            return nil
        }
        return ChartIndicatorValues.doubles(values, count: self.candles.count)
    }

    /// チャートの外で計算した値のうち、何本かの線をまとめたもの(多重移動平均線・ボリンジャーバンドの上限/下限)の index 番目。
    /// ない場合は nil
    func precomputedValues(_ keyPath: KeyPath<ChartIndicatorValues, [[NSNumber]]?>, at index: Int) -> [Double?]? {
        guard let lines = self.precomputed?[keyPath: keyPath] else {
            return nil
        }
        guard index < lines.count else {
            return nil
        }
        return ChartIndicatorValues.doubles(lines[index], count: self.candles.count)
    }

    // MARK: - チャート種類

    /// 新値足の転換に使う本数(3本新値)
    static let newPriceReversalCount = 3
    /// 新値足の表示本数(本数が少ないときは、ある本数だけで画面いっぱいに表示する)
    static let newPriceVisibleCount = 50
    /// 新値足のスクロールできる本数(直近のこの本数だけを並べ、少ないときは左側を空けてこの本数分の幅にする)
    static let newPriceScrollCount = 250

    /// チャート種類に合わせて、表示する内容一式を作る
    /// - Parameters:
    ///   - chartType: チャートの種類
    ///   - mainIndicator: メインチャートの指標(ローソク足・海外指数の折線チャートのときだけ使う)
    ///   - subIndicator: サブチャートの指標(ローソク足のときだけ使う)
    ///   - market: 指数の種類(海外指数の折線チャートは、終値の線にメイン指標を重ね、現在値の破線を引く)
    ///   - period: 足種(スクロールできる範囲の最小の本数を決めるのに使う。IndexMarket.minimumScrollCount)
    func content(for chartType: ChartType, mainIndicator: MainChartIndicator,
                 subIndicator: SubChartIndicator, market: IndexMarket, period: ChartPeriod) -> ChartContent {
        var content = self.content(for: chartType, mainIndicator: mainIndicator, subIndicator: subIndicator, market: market)
        // 新値足は newPriceContent で決めている
        if content.main.minimumScrollCount == nil {
            content.main.minimumScrollCount = market.minimumScrollCount(for: period)
        }
        return content
    }

    /// チャート種類に合わせて、表示する内容一式を作る(スクロールできる範囲の最小の本数は決めない)
    private func content(for chartType: ChartType, mainIndicator: MainChartIndicator,
                         subIndicator: SubChartIndicator, market: IndexMarket) -> ChartContent {
        switch chartType {
        case .candlestick:
            return ChartContent(candles: self.candles,
                                main: self.mainContent(for: mainIndicator),
                                sub: self.subContent(for: subIndicator))
        case .vwapLine:
            return self.requiringTwoValidCandles(self.vwapContent(title: chartType.legendTitle, style: .line))
        case .vwapDots:
            return self.vwapContent(title: chartType.legendTitle, style: .dots)
        case .newPrice:
            return self.requiringTwoValidCandles(self.newPriceContent())
        case .lineChart:
            switch market {
            case .japanStock, .japanIndex:
                return self.requiringTwoValidCandles(self.lineChartContent())
            case .overseasRealtime, .overseasDaily:
                return self.requiringTwoValidCandles(self.closeLineContent(with: mainIndicator, showsCurrentPrice: true))
            }
        }
    }

    /// 線でつなぐチャート(折線チャート・新値足・VWAP：線)は、値のある足が1本以下なら
    /// 凡例だけ残して「表示できる情報はありません」と表示する(線を引けないため)。
    /// ローソク足・VWAP：点は、値のある足が1本でもあれば描く
    private func requiringTwoValidCandles(_ content: ChartContent) -> ChartContent {
        let validCount = self.candles.filter { candle in !candle.isFilled }.count
        if validCount <= 1 {
            var emptyContent = content
            emptyContent.candles = []
            return emptyContent
        }
        return content
    }

    /// 折線チャートの内容(ローソク足は描かず、終値を線で結ぶ。サブチャートなし)
    ///
    ///   凡例:「折線チャート」(線の色)
    ///   現在値(最新の足の終値)の位置に破線を引く
    private func lineChartContent() -> ChartContent {
        let main = MainChartContent(
            series: [ChartSeries(label: ChartType.lineChart.legendTitle, values: self.drawnCloses, colorRole: .closeLine)],
            priceStyle: .hidden,
            currentPrice: self.candles.last?.close)
        return ChartContent(candles: self.candles, main: main, sub: nil)
    }

    /// VWAP の内容(ローソク足は描かず、VWAP の線または点だけを描く。サブチャートなし)。
    /// API が計算した VWAP(StockCandle.vwap。kVWAP)だけで描き、チャートでは計算しない。
    /// 値が読めなかった足(埋めた足)は描かない(線は前後の足をつなぐ)。
    /// ※ kVWAP が空・0 の足は、0 として描くと線が 0 まで落ちてしまうので描かない(前後をつなぐ)
    private func vwapContent(title: String, style: ChartSeries.Style) -> ChartContent {
        let values: [Double?] = self.candles.map { candle in
            if candle.isFilled {
                return nil
            }
            return candle.vwap
        }
        let main = MainChartContent(
            series: [ChartSeries(label: title, values: values, colorRole: .vwap, style: style)],
            priceStyle: .hidden)

        // API の VWAP が1件もないデータは描けないので、
        // 凡例だけ残して「表示できる情報はありません」と表示する
        let hasValue = values.contains { value in value != nil }
        guard hasValue else {
            return ChartContent(candles: [], main: main, sub: nil)
        }
        return ChartContent(candles: self.candles, main: main, sub: nil)
    }

    /// 新値足の内容(新値足の1本を1つの足として並べる。サブチャートなし)
    ///
    ///   凡例:「新値足　■陰線　□陽線」(新値足の色)
    ///   現在値(最新の足の終値)の位置に破線を引く
    private func newPriceContent() -> ChartContent {
        // 新値足の1本 = ローソク足の「始値 = 始点、終値 = 終点」として並べる(ヒゲはないので高値・安値は線の両端)。
        // チャートの外で計算した線があれば、それを使う
        var lineCandles: [StockCandle] = []
        if let precomputedCandles = self.precomputed?.newPriceCandles {
            lineCandles = precomputedCandles
        } else {
            // 値が読めた足だけで作る(埋めた足は除く)
            let validCandles = self.candles.filter { candle in !candle.isFilled }
            let dates = validCandles.map { candle in candle.date }
            let closes = validCandles.map { candle in candle.close }
            let lines = TechnicalIndicators.newPriceLines(dates: dates, closes: closes,
                                                          reversalCount: Self.newPriceReversalCount)
            lineCandles = lines.map { line in
                StockCandle(date: line.date, open: line.start, high: line.high, low: line.low, close: line.end, volume: 0)
            }
        }
        // スクロールできるのは直近 newPriceScrollCount 本だけ
        lineCandles = Array(lineCandles.suffix(Self.newPriceScrollCount))
        // 表示本数より少ない(日中足・月足など)ときは、日足と同じく画面いっぱいに並ぶよう、ある本数だけを表示する
        var visibleCount = Self.newPriceVisibleCount
        if !lineCandles.isEmpty {
            visibleCount = min(lineCandles.count, Self.newPriceVisibleCount)
        }
        let main = MainChartContent(
            priceStyle: .newPrice,
            // 全角スペースで区切った1つの文字列
            legendItems: [ChartLegendItem(text: "\(ChartType.newPrice.legendTitle)　■陰線　□陽線", colorRole: .newPrice)],
            currentPrice: self.candles.last?.close,
            fixedVisibleCount: visibleCount,
            minimumScrollCount: Self.newPriceScrollCount)
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
        let closeLine = ChartSeries(label: nil, values: self.drawnCloses, colorRole: .closeLine)
        main.series.insert(closeLine, at: 0)
        return ChartContent(candles: self.candles, main: main, sub: nil)
    }

    // MARK: - メインチャート

    /// メインチャート(ローソク足に重ねる部分)の描画内容を作る。
    /// 各指標の描く内容は、Model/Indicators/Main/ の指標ごとのファイルにある
    /// (凡例の線の色は StockChartStyle.lineColors の番号。0: 黄緑、1: オレンジ、2: 青、3: 水色、4: 濃い青)
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

    // MARK: - サブチャート

    /// サブチャートの描画内容を作る。サブなし(.hidden)の場合は nil。
    /// 各指標の描く内容は、Model/Indicators/Sub/ の指標ごとのファイルにある
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

    /// RSI・サイコロジカル・ストキャスのサブチャートの内容(3つの指標のファイルで共通に使う)。
    /// Y軸は 0〜100 に固定せず、表示中の値だけで決める(上に値幅の 20% の余白、下は余白なし)。
    /// 基準線(底値・高値ライン)は範囲に含めないので、値が届かない基準線は見えない
    func oscillatorContent(legendTitle: String, series: [ChartSeries], referenceLines: [Double]) -> SubChartContent {
        var content = SubChartContent(legendTitle: legendTitle, series: series, referenceLines: referenceLines)
        content.rangeIncludesReferenceLines = false
        content.autoRangePadding = (bottom: 0, top: 0.2)
        return content
    }
}

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
//    (Model/Indicators/Main/・Sub/)に extension で書いている。
//  ・ローソク足以外のチャートの種類の描く内容(vwapContent・newPriceContent・lineChartContent など)は、
//    種類ごとのファイル(Model/ChartTypes/)に extension で書いている。
//  ・このファイルには、チャートの種類を選ぶ入口(content(for:…))・指標を選ぶ入口(mainContent・subContent)と、
//    指標・種類のファイルで共通に使う部品(closes・precomputedValues・oscillatorContent など)を置いている。
//    (extension は別のファイルから private のものを使えないので、ほかのファイルで使うものは private を付けていない)
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

    /// チャート種類に合わせて、表示する内容一式を作る。
    /// ローソク足以外の種類の描く内容は、Model/ChartTypes/ の種類ごとのファイルにある
    /// - Parameters:
    ///   - chartType: チャートの種類
    ///   - mainIndicator: メインチャートの指標(ローソク足・海外指数の折線チャートのときだけ使う)
    ///   - subIndicator: サブチャートの指標(ローソク足のときだけ使う)
    ///   - market: 指数の種類(海外指数の折線チャートは、終値の線にメイン指標を重ね、現在値の破線を引く)
    ///   - period: 足種(スクロールできる範囲の最小の本数を決めるのに使う。IndexMarket.minimumScrollCount)
    func content(for chartType: ChartType, mainIndicator: MainChartIndicator,
                 subIndicator: SubChartIndicator, market: IndexMarket, period: ChartPeriod) -> ChartContent {
        var content = self.content(for: chartType, mainIndicator: mainIndicator, subIndicator: subIndicator, market: market)
        // 新値足は newPriceContent(NewPrice.swift)で決めている
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

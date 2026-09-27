//
//  ChartContent.swift
//  ChartTest
//
//  【Model】チャートに「何を描くか」を表すデータ構造。
//
//  ChartContentBuilder(Model)が指標の計算結果からこの構造を作り、
//  StockChartView(View)がこれを受け取って描画する。
//  描画ライブラリ(DGCharts)や具体的な色には依存せず、色は「役割(ChartColorRole)」で指定する。
//  役割 → 実際の色 の変換は View 側の StockChartStyle が行う。
//

import Foundation

/// 線・棒の色の役割。実際の色は StockChartStyle.color(for:) で決まる
enum ChartColorRole: Hashable {
    /// 汎用の線の色(0 = 1本目、1 = 2本目、…)
    case line(Int)
    /// 出来高バー
    case volume
    /// 出来高移動平均線
    case volumeAverage
    /// 一目均衡表: 転換線
    case ichimokuTenkan
    /// 一目均衡表: 基準線
    case ichimokuKijun
    /// 一目均衡表: 先行スパン1
    case ichimokuSpanA
    /// 一目均衡表: 先行スパン2
    case ichimokuSpanB
    /// 一目均衡表: 遅行スパン
    case ichimokuChikou
    /// パラボリック(SAR)の点
    case parabolic
    /// VWAP
    case vwap
    /// 新値足(陽線・陰線とも同じ色)
    case newPrice
    /// 折線チャートの線
    case closeLine
}

/// 凡例の1項目(表示する文字と、その色の役割)
struct ChartLegendItem {
    /// 表示する文字(例:「短期移動平均(5)」)
    var text: String
    /// 文字の色の役割(チャートの線と同じ色にする)
    var colorRole: ChartColorRole
}

/// 指標の1本の線(または点列)
struct ChartSeries {
    enum Style {
        /// 折れ線
        case line
        /// 点(パラボリック)
        case dots
    }

    /// 凡例に表示する名前。nil の場合は凡例に出さない
    var label: String?
    /// X軸のインデックスごとの値。nil の位置は描かない。配列はデータ数より長くても短くてもよい
    var values: [Double?]
    /// 色の役割
    var colorRole: ChartColorRole
    /// 描画スタイル
    var style: Style = .line
}

/// 棒グラフ(出来高)
struct ChartBars {
    /// 凡例に表示する名前。nil の場合は凡例に出さない
    var label: String?
    /// 凡例の文字色の役割
    var labelColorRole: ChartColorRole
    /// X軸のインデックスごとの値
    var values: [Double?]
    /// 値ごとの棒の色の役割(values と同じ並び)
    var colorRoles: [ChartColorRole]
}

/// 一目均衡表の雲(先行スパン1 と 先行スパン2 の間)
struct ChartCloud {
    /// 先行スパン1(X軸のインデックスごとの値)
    var spanA: [Double?]
    /// 先行スパン2(X軸のインデックスごとの値)
    var spanB: [Double?]
}

/// メインチャート(ローソク足に重ねる部分)の描画内容
struct MainChartContent {
    /// 足(candles)の描き方
    enum PriceStyle {
        /// ローソク足
        case candles
        /// 新値足(陽線は枠だけ・陰線は塗りつぶし。ヒゲなし・隙間なし)
        case newPrice
        /// 描かない(VWAP など、線・点だけを描く)
        case hidden
    }

    /// 凡例の先頭に表示するタイトル(指標名など)
    var legendTitle: String?
    /// ローソク足に重ねる線・点
    var series: [ChartSeries] = []
    /// 一目均衡表の雲
    var cloud: ChartCloud?
    /// データの右端より先に描く本数(一目均衡表の先行スパン。それ以外は 0)
    var futureCount = 0
    /// 足の描き方
    var priceStyle = PriceStyle.candles
    /// 線を持たない凡例の項目(新値足の「■陰線 □陽線」など)。各線のラベルのあとに並ぶ
    var legendItems: [ChartLegendItem] = []
    /// 横に破線を引く価格(新値足・折線チャートの現在値)。nil なら引かない
    var currentPrice: Double?
    /// 表示する本数を固定する場合の本数(新値足)。
    /// nil なら見た目の設定(StockChartStyle.visibleCount)に従う。
    /// データがこの本数より少ない場合は、左側を空けて右寄せで表示する
    var fixedVisibleCount: Int?
    /// スクロールできる範囲の最小の本数(nil = データの本数のまま)。
    /// データがこの本数より少ない場合は、左側を空けてこの本数分の幅にする(IndexMarket.minimumScrollCount)
    var minimumScrollCount: Int?
}

/// サブチャートの描画内容
struct SubChartContent {
    /// 凡例の先頭に表示するタイトル(指標名など)
    var legendTitle: String?
    /// 線
    var series: [ChartSeries] = []
    /// 棒グラフ
    var bars: ChartBars?
    /// 基準線を引く値(RSI の 20/80 など)
    var referenceLines: [Double] = []
    /// Y軸を固定範囲にする場合の範囲(nil なら表示中の値から自動算出)
    var fixedRange: ClosedRange<Double>?
    /// 自動算出の Y軸の範囲を、基準線(referenceLines)の値まで広げるか。
    /// false なら表示中の値だけで決める(基準線は範囲の外なら見えない)
    var rangeIncludesReferenceLines = true
    /// 自動算出の Y軸の上下の余白(値幅に対する割合)。
    /// nil なら、上は凡例の高さぶん(最低 30%)、下は 5%(0 起点の指標は 0)
    var autoRangePadding: (bottom: Double, top: Double)?
    /// Y軸範囲に 0 を必ず含めるか
    var includesZero = false
    /// Y軸ラベルの小数点以下の最大桁数
    var fractionDigits = 0
    /// Y軸ラベルの末尾に付ける文字(「%」など)
    var suffix = ""
}

/// チャートに表示する内容一式(チャート種類ごとに ChartContentBuilder が作る)
struct ChartContent {
    /// X軸に並べる足(古い順)。新値足では、新値足の1本を1つの足として並べる。
    /// 空の場合は「現在、指定の条件で表示できる情報はありません。」と表示される
    var candles: [StockCandle]
    /// メインチャートの内容
    var main: MainChartContent
    /// サブチャートの内容(nil = サブチャートなし)
    var sub: SubChartContent?
}

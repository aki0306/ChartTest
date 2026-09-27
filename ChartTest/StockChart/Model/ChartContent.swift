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
    /// 上昇(陽線・+DI・上昇トレンドの SAR など)
    case increasing
    /// 下降(陰線・−DI・下降トレンドの SAR など)
    case decreasing
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
    /// MACD ヒストグラム(正の値)
    case histogramPositive
    /// MACD ヒストグラム(負の値)
    case histogramNegative
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

/// 棒グラフ(出来高・MACD ヒストグラム)
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
    /// 凡例の先頭に表示するタイトル(指標名など)
    var legendTitle: String?
    /// ローソク足に重ねる線・点
    var series: [ChartSeries] = []
    /// 一目均衡表の雲
    var cloud: ChartCloud?
    /// データの右端より先に描く本数(一目均衡表の先行スパン。それ以外は 0)
    var futureCount = 0
}

/// サブチャートの描画内容
struct SubChartContent {
    /// 凡例の先頭に表示するタイトル(指標名など)
    var legendTitle: String?
    /// 線
    var series: [ChartSeries] = []
    /// 棒グラフ
    var bars: ChartBars?
    /// 基準線を引く値(RSI の 30/70 など)
    var referenceLines: [Double] = []
    /// Y軸を固定範囲にする場合の範囲(nil なら表示中の値から自動算出)
    var fixedRange: ClosedRange<Double>?
    /// Y軸範囲に 0 を必ず含めるか
    var includesZero = false
    /// Y軸ラベルの小数点以下の最大桁数
    var fractionDigits = 0
    /// Y軸ラベルの末尾に付ける文字(「%」など)
    var suffix = ""
}

//
//  StockChartStyle.swift
//  ChartTest
//
//  【View】チャートの見た目(色・フォント・レイアウト・初期表示範囲)の設定。
//  Model が指定した色の役割(ChartColorRole)を、実際の色に変換する役目も持つ。
//

import UIKit

struct StockChartStyle {

    // MARK: - 表示範囲

    /// 初期表示する本数。直近から数えてこの本数分を表示し、それより古いデータは右方向へのスワイプで表示する。
    /// nil の場合は全件を表示する
    var visibleCount: Int? = 55

    // MARK: - 色

    /// 陽線(終値 > 始値)などの上昇を表す色。日本式に合わせて赤
    var increasingColor = UIColor(red: 0.89, green: 0.05, blue: 0.27, alpha: 1)
    /// 陰線(終値 < 始値)などの下降を表す色。日本式に合わせて青
    var decreasingColor = UIColor(red: 0.07, green: 0.47, blue: 0.95, alpha: 1)
    /// 汎用の線の色(ChartColorRole.line(n) の n 番目。足りない場合は先頭から繰り返す)
    var lineColors: [UIColor] = [
        UIColor(red: 0.55, green: 0.80, blue: 0.10, alpha: 1),  // 0: 黄緑(短期移動平均など)
        UIColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1),  // 1: オレンジ(長期移動平均など)
        UIColor(red: 0.60, green: 0.30, blue: 0.85, alpha: 1),  // 2: 紫
        UIColor(red: 0.10, green: 0.60, blue: 0.85, alpha: 1),  // 3: 水色
        UIColor(red: 0.90, green: 0.30, blue: 0.55, alpha: 1),  // 4: ピンク
    ]
    /// 出来高バーの色(黄緑)
    var volumeColor = UIColor(red: 0.60, green: 0.80, blue: 0.10, alpha: 1)
    /// 出来高移動平均線の色(青)
    var volumeAverageColor = UIColor(red: 0.12, green: 0.50, blue: 0.95, alpha: 1)
    /// 一目均衡表: 転換線の色
    var ichimokuTenkanColor = UIColor(red: 0.90, green: 0.30, blue: 0.55, alpha: 1)
    /// 一目均衡表: 基準線の色
    var ichimokuKijunColor = UIColor(red: 0.10, green: 0.60, blue: 0.85, alpha: 1)
    /// 一目均衡表: 先行スパン1 の色(陽雲の色にも使う)
    var ichimokuSpanAColor = UIColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1)
    /// 一目均衡表: 先行スパン2 の色(陰雲の色にも使う)
    var ichimokuSpanBColor = UIColor(red: 0.60, green: 0.30, blue: 0.85, alpha: 1)
    /// 一目均衡表: 遅行スパンの色
    var ichimokuChikouColor = UIColor(red: 0.55, green: 0.80, blue: 0.10, alpha: 1)
    /// 雲の不透明度(先行スパンの色をこの不透明度で塗る)
    var cloudAlpha: CGFloat = 0.15
    /// MACD ヒストグラムの不透明度(上昇/下降の色をこの不透明度で塗る)
    var histogramAlpha: CGFloat = 0.5
    /// オシレーターの基準線(RSI の 30/70 など)の色
    var referenceLineColor = UIColor.systemGray2
    /// 横グリッド線の色
    var gridColor = UIColor.systemGray5
    /// 外枠の色
    var borderColor = UIColor.label
    /// メイン/サブの区切り線の色
    var dividerColor = UIColor.systemGray
    /// 軸ラベル・凡例タイトルの文字色
    var textColor = UIColor.label

    // MARK: - フォント

    /// 軸ラベルのフォント
    var axisFont = UIFont.systemFont(ofSize: 10)
    /// 凡例のフォント
    var legendFont = UIFont.systemFont(ofSize: 12)

    // MARK: - レイアウト

    /// メインチャートとサブチャートの描画領域の高さ比(メイン : サブ = priceHeightRatio : 1)
    var priceHeightRatio: CGFloat = 2.0
    /// 右側のY軸ラベル領域の幅
    var rightAxisWidth: CGFloat = 90
    /// 下側のX軸(日付)ラベル領域の高さ
    var xAxisLabelHeight: CGFloat = 20
    /// 外枠・区切り線の線幅
    var borderWidth: CGFloat = 1
    /// X軸ラベルの日付フォーマット
    var dateFormat = "M/d"

    // MARK: - 色の役割 → 実際の色

    /// Model が指定した色の役割を実際の色に変換する
    func color(for role: ChartColorRole) -> UIColor {
        switch role {
        case .line(let index): return lineColors.isEmpty ? textColor : lineColors[index % lineColors.count]
        case .increasing: return increasingColor
        case .decreasing: return decreasingColor
        case .volume: return volumeColor
        case .volumeAverage: return volumeAverageColor
        case .ichimokuTenkan: return ichimokuTenkanColor
        case .ichimokuKijun: return ichimokuKijunColor
        case .ichimokuSpanA: return ichimokuSpanAColor
        case .ichimokuSpanB: return ichimokuSpanBColor
        case .ichimokuChikou: return ichimokuChikouColor
        case .histogramPositive: return increasingColor.withAlphaComponent(histogramAlpha)
        case .histogramNegative: return decreasingColor.withAlphaComponent(histogramAlpha)
        }
    }
}

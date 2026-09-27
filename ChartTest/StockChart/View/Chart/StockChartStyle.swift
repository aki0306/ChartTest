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
    /// nil の場合は全件を表示する(足種ごとの値は ChartPeriod.visibleCount。既定は日足の 50 本)
    var visibleCount: Int? = 50
    /// 拡大の限界(ピンチで拡大したときに、最低でも表示する本数)。nil なら DGCharts の標準のまま
    var minimumVisibleCount: Int? = 20
    /// 縮小の限界(ピンチで縮小したときに、最大で表示する本数)。nil なら全件まで縮小できる
    /// (足種ごとの値は ChartPeriod.maximumVisibleCount。既定は日足の 250 本)
    var maximumVisibleCount: Int? = 250

    // MARK: - 色

    /// 陽線(終値 > 始値)などの上昇を表す色。日本式に合わせて赤
    var increasingColor = UIColor(hex: 0xe5003e)
    /// 陰線(終値 < 始値)などの下降を表す色。日本式に合わせて青
    var decreasingColor = UIColor(hex: 0x157efb)
    /// 汎用の線の色(ChartColorRole.line(n) の n 番目。足りない場合は先頭から繰り返す)
    var lineColors: [UIColor] = [
        UIColor(hex: 0x94cb10),  // 0: 黄緑(短期移動平均・ボリンジャーの中心線・RSI・%D・シグナル・+DI など)
        UIColor(hex: 0xff8a00),  // 1: オレンジ(長期移動平均・多重移動平均・±3σ・Slow%D・MACD・−DI など)
        UIColor(hex: 0x157efb),  // 2: 青(サイコロジカル)
        UIColor(hex: 0x00a2ff),  // 3: 水色(ボリンジャーの ±1σ)
        UIColor(hex: 0x006cff),  // 4: 濃い青(ボリンジャーの ±2σ)
    ]
    /// 出来高バーの色(黄緑)
    var volumeColor = UIColor(hex: 0x94cb10)
    /// 出来高移動平均線の色(青)
    var volumeAverageColor = UIColor(hex: 0x157efb)
    /// 一目均衡表: 転換線の色(青)
    var ichimokuTenkanColor = UIColor(hex: 0x005bd8)
    /// 一目均衡表: 基準線の色(黄緑)
    var ichimokuKijunColor = UIColor(hex: 0x94cb10)
    /// 一目均衡表: 先行スパン1 の色(陽雲の色にも使う。黄緑)
    var ichimokuSpanAColor = UIColor(hex: 0x94cb10)
    /// 一目均衡表: 先行スパン2 の色(陰雲の色にも使う。オレンジ)
    var ichimokuSpanBColor = UIColor(hex: 0xff8a00)
    /// 一目均衡表: 遅行スパンの色(グレー)
    var ichimokuChikouColor = UIColor(hex: 0x666666)
    /// パラボリック(SAR)の点の色(グレー)
    var parabolicColor = UIColor(hex: 0x666666)
    /// VWAP の線・点の色(赤)
    var vwapColor = UIColor(hex: 0xe5003e)
    /// 新値足の色(陽線・陰線とも同じ青。陽線は枠だけ、陰線は塗りつぶしで区別する)
    var newPriceColor = UIColor(hex: 0x157efb)
    /// 折線チャートの線の色(青)
    var lineChartColor = UIColor(hex: 0x157efb)
    /// 現在値の破線(新値足・折線チャート)の色
    var currentPriceLineColor = UIColor.darkGray
    /// 雲の不透明度(先行スパンの色をこの不透明度で塗る。約 25%)
    var cloudAlpha: CGFloat = 0.25
    /// オシレーターの基準線(RSI の 20/80 など)の色(赤)
    var referenceLineColor = UIColor(hex: 0xe5003e)
    /// 横グリッド線の色
    var gridColor = UIColor.systemGray5
    /// 外枠の色
    var borderColor = UIColor.black
    /// メイン/サブの区切り線の色(グレー)
    var dividerColor = UIColor(hex: 0xaaaaaa)
    /// 軸ラベル・凡例タイトルの文字色
    var textColor = UIColor.black

    // MARK: - フォント

    /// X軸ラベル(日付)のフォント。8pt
    var xAxisFont = UIFont.systemFont(ofSize: 8)
    /// Y軸ラベル(価格・指標の値)のフォント。8pt
    var yAxisFont = UIFont.systemFont(ofSize: 8)
    /// 凡例のフォント
    var legendFont = UIFont.systemFont(ofSize: 12)

    // MARK: - レイアウト(チャート全体)

    /// メインチャートとサブチャートの描画領域の高さ比(メイン : サブ = priceHeightRatio : 1)。60 : 40
    var priceHeightRatio: CGFloat = 1.5
    /// 右側のY軸ラベル領域の幅。65pt
    var rightAxisWidth: CGFloat = 65
    /// 下側のX軸(日付)ラベル領域の高さ
    var xAxisLabelHeight: CGFloat = 20
    /// 外枠・区切り線の線幅
    var borderWidth: CGFloat = 1

    // MARK: - X軸ラベル(日付)

    /// X軸ラベルの日付フォーマット(足種ごとの値は ChartPeriod.dateFormat)
    var dateFormat = "M/d"
    /// X軸ラベルを、時刻が何分ちょうどの足に置くか(nil = 日足・週足・月足の置き方)。
    /// 5 なら、5分ちょうどの足を左から順に、重ならない位置に置く(1分足・日中足。ChartPeriod.xAxisLabelMinuteMultiple)
    var xAxisLabelMinuteMultiple: Int?

    // MARK: - Y軸ラベル(価格・指標の値)

    /// Y軸ラベルの左端の位置(外枠の右端からの距離)
    var yAxisLabelOffset: CGFloat = 10
    /// Y軸ラベルを、一番長いラベルの幅の中で中央揃えにするか(false なら左揃え)
    var centersYAxisLabels = false
    /// Y軸ラベルを描画領域の内側に収めるか(下端の「0」などは上にずらし、上端からはみ出すラベルは描かない)
    var keepsYAxisLabelsInside = false

    // MARK: - 凡例

    /// 凡例の背景色(白にすると、凡例の文字の後ろのグリッド線が隠れる)
    var legendBackgroundColor = UIColor.clear
    /// メインチャートの凡例の上端の位置(外枠の上端からの距離)
    var legendTopInset: CGFloat = 3
    /// サブチャートの凡例の上端の位置(区切り線の下端からの距離)
    var subLegendTopInset: CGFloat = 2
    /// 凡例の左端の位置(外枠の左端からの距離。メイン・サブ共通)
    var legendLeadingInset: CGFloat = 8
    /// 凡例の下端と、チャートの一番高い線・足との最小の間隔。
    /// この間隔が空くよう、Y軸の上側の余白を自動で広げる(updateAxisRanges)
    var legendBottomSpacing: CGFloat = 4

    // MARK: - 最高値・最安値

    /// 表示中の範囲の最高値・最安値を、その足の上・下に表示するか(ローソク足のときだけ。StockChartView+HighLowLabels)
    var showsHighLowLabels = false
    /// 最高値・最安値の文字のフォント。12pt
    var highLowLabelFont = UIFont.systemFont(ofSize: 12)

    // MARK: - 4本値(十字線)

    /// 4本値の枠に表示する日付の書式(足種ごとの値は ChartPeriod.ohlcDateFormat)
    var ohlcDateFormat = "yyyy/MM/dd"
    /// 4本値(十字線・マーカー・4本値の枠)を動かしてから、薄く表示するまでの秒数(0 以下なら薄くしない)
    var crosshairFadeDelay: TimeInterval = 3
    /// 4本値を薄く表示するときの、4本値の枠・値のマーカー・矢印の不透明度(0 = 見えない 〜 1 = 元の濃さ)。
    /// また動かすと元の濃さに戻る。50%
    var crosshairFadedAlpha: CGFloat = 0.5
    /// 4本値を薄く表示するときの、十字線(縦線・横線)の不透明度。30%
    var crosshairFadedLineAlpha: CGFloat = 0.3
    /// 4本値の日付のマーカー(下の日付ラベルの欄の、縦線を指す赤い矢印)の画像。
    /// nil なら、increasingColor で上向き矢印の形を塗る。画像はそのままの大きさで表示する
    var dateMarkerImage: UIImage?
    /// 4本値の価格のマーカー(右の価格ラベルの欄の、横線の位置を指す赤い矢印)の画像。
    /// nil なら、increasingColor で左向き矢印の形を塗る。画像はそのままの大きさで表示する
    var yAxisMarkerImage: UIImage?

    // MARK: - 文言

    /// データが0件のときにメインチャートの凡例の下に表示するメッセージ
    var noDataMessage = "現在、指定の条件で表示できる情報はありません。"

    // MARK: - 足種に合わせる

    /// 足種に合わせた見た目にしたコピーを返す(日付の書式・日付ラベルの置き方・初期表示本数。値は ChartPeriod)。
    /// 縦画面(StockChartView.setCandles(_:period:))と横画面(StockChartViewController.setCandles(_:period:))の
    /// 両方がこれを使うので、足種ごとの見た目を変えるときはここ(と ChartPeriod)だけを直せばよい
    ///
    ///   例) 週足: 日付の書式「25/9/5」・日付ラベル 約5個・初期表示 50本・縮小の限界 250本
    func applying(_ period: ChartPeriod) -> StockChartStyle {
        var style = self
        style.dateFormat = period.dateFormat
        style.ohlcDateFormat = period.ohlcDateFormat
        style.xAxisLabelMinuteMultiple = period.xAxisLabelMinuteMultiple
        style.visibleCount = period.visibleCount
        style.maximumVisibleCount = period.maximumVisibleCount
        return style
    }

    // MARK: - 色の役割 → 実際の色

    /// Model が指定した色の役割を実際の色に変換する
    func color(for role: ChartColorRole) -> UIColor {
        switch role {
        case .line(let index):
            // 色が1つも設定されていなければ文字色で代用する
            guard !self.lineColors.isEmpty else {
                return self.textColor
            }
            return self.lineColors[index % self.lineColors.count]
        case .volume:
            return self.volumeColor
        case .volumeAverage:
            return self.volumeAverageColor
        case .ichimokuTenkan:
            return self.ichimokuTenkanColor
        case .ichimokuKijun:
            return self.ichimokuKijunColor
        case .ichimokuSpanA:
            return self.ichimokuSpanAColor
        case .ichimokuSpanB:
            return self.ichimokuSpanBColor
        case .ichimokuChikou:
            return self.ichimokuChikouColor
        case .parabolic:
            return self.parabolicColor
        case .vwap:
            return self.vwapColor
        case .newPrice:
            return self.newPriceColor
        case .closeLine:
            return self.lineChartColor
        }
    }
}

// MARK: - 色コードから色を作る

private extension UIColor {

    /// 0xRRGGBB の色コードから色を作る
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xff) / 255
        let green = CGFloat((hex >> 8) & 0xff) / 255
        let blue = CGFloat(hex & 0xff) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

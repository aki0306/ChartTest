//
//  StockChartView.swift
//  ChartTest
//
//  【View】株価チャートの描画を担当するカスタムView。
//
//  ┌───────────────────────────┐
//  │ 移動平均 短期(5) 長期(25)   │ 70,000  ← メインチャート(priceChart)
//  │   ローソク足 + メイン指標     │ 65,000     ローソク足 + MainChartContent
//  │                           │ 60,000
//  ├───────────────────────────┤ ← 区切り線(dividerView)
//  │ 出来高 出来高移動平均         │ 4,000,000,000 ← サブチャート(subChart)
//  │   サブ指標                  │ 0                SubChartContent
//  └───────────────────────────┘
//   7/14   7/27   8/6 ...          ← X軸ラベル(一番下のチャートにだけ表示)
//
//  【使い方】外から使うのは次のものだけ(Swift・Objective-C の両方から呼べる。書き方は README を参照)
//  ・setCandles(_:)          … データを渡すだけで描画する(移動平均線 + 出来高)
//  ・setCandles(_:period:)   … 足種に合った設定で描画する(X軸の書式・移動平均の期間などが足種ごとに変わる)
//  ・setCandles(_:mainIndicator:subIndicator:) … 指標を指定して描画する
//  ・display(candles:main:sub:keepsViewport:) … 描画内容を指定して描画する(StockChartViewController が使う)
//  ・clear()                 … 表示を消す
//  ・style                   … 見た目の設定(色・フォント・初期表示本数など。StockChartStyle)
//  ・displayOptions          … 表示オプション(Y軸固定・4本値。ChartDisplayOptions)
//  それ以外のプロパティ・メソッドはこのView の内部用。
//  (処理をファイルに分けているため private を付けられないものがあるが、外からは使わないこと)
//
//  【ファイルの構成】処理の役割ごとに、次のファイルに分けている
//  ・StockChartView.swift                … このファイル。プロパティ・外から呼ぶ入口・画面回転時の表示範囲の維持
//  ・StockChartView+Layout.swift         … 部品の配置(Auto Layout)と見た目の設定
//  ・StockChartView+Rendering.swift      … データを DGCharts の形に変換して描画する・凡例の文字列を作る
//  ・StockChartView+AxisRange.swift      … スクロール/ズームの同期と、表示範囲に合わせたY軸範囲の調整
//  ・StockChartView+HighLowLabels.swift  … 表示中の範囲の最高値・最安値の文字
//  ・StockChartView+Crosshair.swift      … 表示オプションの反映と、十字線・4本値の表示・操作
//  ・StockChartStyle.swift               … 見た目の設定(色・フォント・余白など)
//  部品(このView の中で使うもの)
//  ・ChartCrosshairViews.swift           … 十字線・4本値の枠・マーカーの部品
//  ・ChartAxisFormatters.swift           … 軸ラベルの書式(X軸の日付・Y軸の数値)
//  ・LatestAlignedXAxisRenderer.swift    … X軸ラベル(日付)をどの足の下に置くか
//  ・AlignedYAxisRenderer.swift          … Y軸ラベルの揃え方
//  ・CloudCombinedRenderer.swift         … 一目均衡表の雲の塗りつぶし
//  ・SafePinchCombinedChartView.swift    … ピンチ操作のクラッシュ対策をしたチャート
//  初めて読む場合は、このファイル → Layout → Rendering → AxisRange → Crosshair の順がおすすめ。
//
//  【描画の流れ】
//   display(...) で内容を受け取る
//     → render()               (Rendering) DGCharts のデータを作ってチャートに渡す
//     → updateAxisRanges(...)  (AxisRange) 見えている範囲の値に合わせてY軸の上限・下限を決める
//     → updateCrosshair()      (Crosshair) 4本値がオンなら十字線を置き直す
//   スクロール・ズームのたびに、updateAxisRanges → updateCrosshair が呼ばれる
//
//  【ラベルの種類と位置】
//  ・凡例(priceLegendLabel / subLegendLabel)
//      「移動平均 短期移動平均(5) 長期移動平均(25)」のような1行のテキスト。
//      DGCharts 標準の凡例は使わず、UILabel を外枠の内側・左上に重ねて表示している。
//        メイン: 外枠の上端から style.legendTopInset(3pt)下、左端から style.legendLeadingInset(8pt)右
//        サブ  : 区切り線の下端から style.subLegendTopInset(2pt)下、左端から 8pt 右
//      文字列は Model(ChartContentBuilder)が付けた legendTitle / label から作る(Rendering)。
//      凡例とチャートの線が重ならないよう、Y軸の上側に余白を取っている(AxisRange)。
//  ・Y軸ラベル(価格・指標の値)
//      外枠の右側、幅 style.rightAxisWidth(90pt)の領域に DGCharts が描く。
//      外枠の右端から style.yAxisLabelOffset(10pt)離して左揃え(style で中央揃えにもできる)で表示する。
//  ・X軸ラベル(日付)
//      外枠の下側、高さ style.xAxisLabelHeight(20pt)の領域に DGCharts が描く。
//      サブチャートがあるときはサブ、ないときはメインのチャートにだけ表示する。
//
//  【仕組み】
//  ・メイン/サブは別々の CombinedChartView(DGCharts のチャート)だが、外枠(frameView)と
//    区切り線(dividerView)を上から重ねて描くことで「1つの枠の中に2つのチャート」があるように見せている。
//  ・X軸の値は日付ではなく「データの何本目か(0, 1, 2, …)」。日付を使うと土日・祝日が空白になるため。
//  ・指標の計算や「どの指標を表示するか」の状態は持たない(Model / Controller の責務)。
//

import UIKit
import DGCharts

final class StockChartView: UIView {

    // MARK: - 設定(外から変更する)

    /// 見た目の設定。変更すると現在の内容を再描画する(表示位置は初期状態に戻る)
    var style = StockChartStyle() {
        didSet {
            self.applyStyle()
            self.render(keepingMatrix: nil)
        }
    }

    /// 指数の種類(国内/海外)。setCandles(_:period:) での描き方が変わる
    /// (国内: ローソク足 + 移動平均線・サブに出来高 / 海外: ローソク足 + 移動平均線・サブなし)。
    /// 変更しても描き直さないので、データを渡す前に設定する
    @objc var market: IndexMarket = .domestic

    /// 表示オプション(Y軸固定・4本値)。変更すると即座に反映する
    var displayOptions = ChartDisplayOptions() {
        didSet {
            guard self.displayOptions != oldValue else { return }
            self.applyDisplayOptions()
        }
    }

    // MARK: - 定数

    /// 各チャートの描画領域の上下に確保する余白。
    /// 描画領域の端ちょうどにあるY軸ラベルは文字の半分が領域外にはみ出すため、
    /// その部分がチャートViewの境界で切れないように余白を取っておく。
    /// (メインとサブはこの余白ぶん重ねて配置するので、見た目上の隙間にはならない)
    let labelOverflowInset: CGFloat = 8

    // MARK: - 部品(サブView)

    /// メインチャート(ローソク足 + メイン指標)
    let priceChart = SafePinchCombinedChartView()
    /// サブチャート(サブ指標)
    let subChart = SafePinchCombinedChartView()
    /// メインチャート用のレンダラー(描画処理)。一目均衡表の雲を塗るために DGCharts 標準のものから差し替えている
    lazy var priceRenderer = CloudCombinedRenderer(
        chart: self.priceChart, animator: self.priceChart.chartAnimator, viewPortHandler: self.priceChart.viewPortHandler)
    /// メインチャートの X軸ラベルの描画処理。最新の足を基準にラベルを並べるため、DGCharts 標準のものから差し替えている
    lazy var priceXAxisRenderer = LatestAlignedXAxisRenderer(
        viewPortHandler: self.priceChart.viewPortHandler, axis: self.priceChart.xAxis,
        transformer: self.priceChart.getTransformer(forAxis: .left))
    /// メインチャートの Y軸ラベルの描画処理。中央揃え・枠内に収める表示に切り替えられるよう、DGCharts 標準のものから差し替えている
    lazy var priceYAxisRenderer = AlignedYAxisRenderer(
        viewPortHandler: self.priceChart.viewPortHandler, axis: self.priceChart.rightAxis,
        transformer: self.priceChart.getTransformer(forAxis: .right))
    /// サブチャートの Y軸ラベルの描画処理(同上)
    lazy var subYAxisRenderer = AlignedYAxisRenderer(
        viewPortHandler: self.subChart.viewPortHandler, axis: self.subChart.rightAxis,
        transformer: self.subChart.getTransformer(forAxis: .right))
    /// サブチャートの X軸ラベルの描画処理(同上)
    lazy var subXAxisRenderer = LatestAlignedXAxisRenderer(
        viewPortHandler: self.subChart.viewPortHandler, axis: self.subChart.xAxis,
        transformer: self.subChart.getTransformer(forAxis: .left))
    /// メイン・サブ全体を囲む外枠(チャートの上に重ねて表示)
    let frameView = UIView()
    /// メインとサブの間の区切り線
    let dividerView = UIView()
    /// メインチャートの凡例(例:「移動平均 短期移動平均(5) 長期移動平均(25)」)。外枠の内側・左上に重ねて表示する
    let priceLegendLabel = UILabel()
    /// サブチャートの凡例(例:「出来高 出来高移動平均」)。区切り線のすぐ下・左端に重ねて表示する
    let subLegendLabel = UILabel()
    /// データが0件のときのメッセージ(「現在、指定の条件で表示できる情報はありません。」)。メインチャートの凡例の下に表示する
    let noDataLabel = UILabel()
    /// 表示中の範囲の最高値(その足の上に表示。style.showsHighLowLabels が true のとき)
    let highPriceLabel = UILabel()
    /// 表示中の範囲の最安値(その足の下に表示。style.showsHighLowLabels が true のとき)
    let lowPriceLabel = UILabel()

    // MARK: - 部品(4本値の表示用)

    /// 十字線(4本値がオンのときに表示)
    let crosshairView = CrosshairOverlayView()
    /// 選択中の足の4本値の枠
    let ohlcInfoView = OHLCInfoView()
    /// 十字線の横線の位置の値を表示するマーカー(外枠の左端寄り・グレーの六角形)
    let valueMarker = CrosshairMarkerLabel(shape: .hexagon)
    /// 十字線の縦線の位置を示すマーカー(X軸・赤い上向き矢印。文字なし)
    let dateMarker = CrosshairMarkerLabel(shape: .arrowUp)
    /// 十字線の横線の位置を示すマーカー(Y軸側の右端・赤い左向き矢印)
    let yAxisMarker = CrosshairMarkerLabel(shape: .arrowLeft)
    /// 十字線を動かすジェスチャー(タップ・1本指ドラッグ)。メイン・サブそれぞれに付ける
    var crosshairRecognizers: [UIGestureRecognizer] = []
    /// 十字線の位置(このViewの座標)。指の位置に合わせて動く。
    /// 縦線はこの X に一番近い足に合わせる。nil の場合は次回表示時に最新の足の位置に置く
    var crosshairPoint: CGPoint?
    /// ドラッグ中に動かす十字線の線(なぞり始めた場所で決める。nil = ドラッグしていない・動かさない)
    var crosshairDragTarget: CrosshairMoveTarget?
    /// 4本値を薄く表示する予約(一定時間動かさなかったら実行する。動かすと取り消して予約し直す)
    var crosshairFadeWorkItem: DispatchWorkItem?

    // MARK: - レイアウトの制約(スタイル・サブチャートの有無によって変わるもの)

    /// メインチャートの凡例の上端(style.legendTopInset)
    var priceLegendTopConstraint: NSLayoutConstraint?
    /// サブチャートの凡例の上端(style.subLegendTopInset)
    var subLegendTopConstraint: NSLayoutConstraint?
    /// 凡例の左端(style.legendLeadingInset。メイン・サブ・データなしのメッセージ)
    var legendLeadingConstraints: [NSLayoutConstraint] = []

    /// サブチャートを区切り線の位置まで重ねるための制約
    var subTopConstraint: NSLayoutConstraint?
    /// 外枠の右端(Y軸ラベル領域の左端)を決める制約
    var frameTrailingConstraint: NSLayoutConstraint?
    /// 区切り線の太さを決める制約
    var dividerHeightConstraint: NSLayoutConstraint?
    /// [サブあり] メインとサブの高さ比を決める制約
    var priceHeightConstraint: NSLayoutConstraint?
    /// [サブあり] 外枠の下端をサブチャートのX軸ラベル領域の上端に合わせる制約
    var frameBottomWithSubConstraint: NSLayoutConstraint?
    /// [サブなし] メインチャートの下端をこのViewの下端に合わせる制約
    var priceBottomConstraint: NSLayoutConstraint?
    /// [サブなし] 外枠の下端をメインチャートのX軸ラベル領域の上端に合わせる制約
    var frameBottomWithoutSubConstraint: NSLayoutConstraint?

    // MARK: - 表示中の内容

    /// 表示中のローソク足データ(古い順)
    var candles: [StockCandle] = []
    /// 表示中のメインチャートの内容
    var mainContent = MainChartContent()
    /// 表示中のサブチャートの内容(nil = サブチャートなし)
    var subContent: SubChartContent?

    /// データの右端より先に描く本数(一目均衡表の先行スパン用。それ以外は 0)
    var futureCount: Int {
        return self.mainContent.futureCount
    }

    /// X軸に並ぶ本数(先行スパンの先の部分を含む)
    var totalCount: Int {
        return self.candles.count + self.futureCount
    }

    /// 初期表示する本数(nil = 全件)。表示内容で本数が決まっている場合(新値足)はそちらを優先する
    var effectiveVisibleCount: Int? {
        if let fixedVisibleCount = self.mainContent.fixedVisibleCount {
            return fixedVisibleCount
        }
        return self.style.visibleCount
    }

    /// データの左端より前に空けておく本数(新値足の本数が表示本数より少ないとき、右寄せにするため)
    var leadingBlankCount: Int {
        guard let fixedVisibleCount = self.mainContent.fixedVisibleCount else { return 0 }
        return max(0, fixedVisibleCount - self.totalCount)
    }

    /// X軸の左端の値。両端の足が半分切れないよう、前に 0.5 本広げる(右寄せの場合は空ける本数も含める)
    var xAxisMinimum: Double {
        return -0.5 - Double(self.leadingBlankCount)
    }

    /// サブチャートを表示中か
    var hasSubChart: Bool {
        return self.subContent != nil
    }

    /// データが0件のときのメッセージを表示するか。
    /// display で空のデータを渡されたときだけ true(clear で消したときは何も表示しない)
    var showsNoDataMessage = false

    // MARK: - 初期化

    /// コードから生成された場合
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    /// Storyboard / XIB から生成された場合
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    // MARK: - 外から呼ぶ入口

    /// 描画内容を表示する。
    /// - Parameters:
    ///   - candles: 日付の古い順に並んだローソク足データ
    ///   - main: メインチャート(ローソク足に重ねる部分)の内容
    ///   - sub: サブチャートの内容。nil の場合はサブチャートを隠し、メインチャートを全高で表示する
    ///   - keepsViewport: true の場合、可能であれば現在の表示位置・拡大率を維持する(指標の切り替え時など)
    func display(candles: [StockCandle], main: MainChartContent, sub: SubChartContent?, keepsViewport: Bool = false) {
        // 維持する表示位置・拡大率(nil = 初期表示位置に戻す)。内容を差し替える前に取得しておく
        var keptMatrix: CGAffineTransform?
        if keepsViewport {
            keptMatrix = self.currentMatrixIfReusable(candleCount: candles.count, futureCount: main.futureCount,
                                                 fixedVisibleCount: main.fixedVisibleCount)
        }

        // サブチャートの表示/非表示が切り替わるか(今の表示状態と、新しい内容にサブがあるかを比べる)
        let willShowSub = sub != nil
        let subVisibilityChanged = willShowSub != self.hasSubChart

        // データ件数が変わったら(別のデータになったら)十字線の位置はリセットする
        if candles.count != self.candles.count {
            self.crosshairPoint = nil
        }

        self.candles = candles
        self.mainContent = main
        self.subContent = sub
        // データが0件なら、枠と凡例を残したままメッセージを表示する
        self.showsNoDataMessage = candles.isEmpty

        if subVisibilityChanged {
            self.updateSubChartVisibility()
        }
        self.render(keepingMatrix: keptMatrix)
    }

    /// 表示内容をすべて消す(Objective-C からは [chartView clear])
    @objc func clear() {
        self.candles = []
        self.mainContent = MainChartContent()
        self.subContent = nil
        self.crosshairPoint = nil
        self.showsNoDataMessage = false
        self.render(keepingMatrix: nil)
    }

    /// 現在の表示位置・拡大率(変換行列)を、新しい内容でもそのまま使えるなら返す。使えなければ nil
    ///
    /// DGCharts は「どこを・何倍で表示しているか」を変換行列(touchMatrix)で持っている。
    /// X軸の範囲が変わらなければ、同じ行列を使うと同じ位置が表示される。
    /// - Parameters:
    ///   - candleCount: 新しく表示するデータの件数
    ///   - futureCount: 新しく表示する内容の、データの右端より先に描く本数
    ///   - fixedVisibleCount: 新しく表示する内容の、表示本数の固定値(新値足)
    private func currentMatrixIfReusable(candleCount: Int, futureCount newFutureCount: Int,
                                         fixedVisibleCount: Int?) -> CGAffineTransform? {
        // まだ何も表示していない
        guard self.priceChart.data != nil else { return nil }
        // レイアウト前で、描画領域の幅が確定していない
        guard self.priceChart.viewPortHandler.contentWidth > 0 else { return nil }
        // データ件数が変わると X軸の範囲が変わるので、同じ行列では同じ位置にならない
        guard candleCount == self.candles.count else { return nil }
        // 先行スパンの本数(一目均衡表の有無)が変わっても X軸の範囲が変わる
        guard newFutureCount == self.futureCount else { return nil }
        // 表示本数の固定(新値足の右寄せ)が変わっても X軸の範囲が変わる
        guard fixedVisibleCount == self.mainContent.fixedVisibleCount else { return nil }

        return self.priceChart.viewPortHandler.touchMatrix
    }

    // MARK: - サイズ変更(画面回転など)

    override func layoutSubviews() {
        // DGCharts はスクロール位置をピクセル単位で保持しているため、画面回転などで幅が変わると
        // 表示範囲がずれてしまう。サイズ変更前の表示範囲(X軸の値)を覚えておき、変更後に復元する
        let oldWidth = self.priceChart.viewPortHandler.contentWidth
        let oldHeight = self.priceChart.viewPortHandler.contentHeight
        let oldRange = self.currentVisibleRange()

        super.layoutSubviews()  // ここでチャートのサイズが変わる

        let widthChanged = self.priceChart.viewPortHandler.contentWidth != oldWidth
        let heightChanged = self.priceChart.viewPortHandler.contentHeight != oldHeight

        if widthChanged, let oldRange {
            // 幅が変わった(画面の回転など): 変更前と同じ範囲(何本目〜何本目)が見えるように戻す。
            // Y軸範囲もこの中で計算し直す
            self.restoreVisibleRange(low: oldRange.low, high: oldRange.high)
        } else if heightChanged {
            // 高さが変わった(初めてサイズが決まったときを含む):
            // 凡例の下に空ける余白(Y軸の上側の余白)が変わるので、Y軸範囲を計算し直す
            self.updateAxisRangesAfterHeightChange(isFirstLayout: oldWidth == 0)
        }

        // 十字線の位置はこの View の座標で覚えているので、サイズが変わると(画面の回転など)外枠の外を指してしまう。
        // サイズが変わったら、最新の足の位置から置き直す(次の updateCrosshair で決め直される)
        let sizeChanged = widthChanged || heightChanged
        if sizeChanged {
            self.crosshairPoint = nil
        }
        self.updateCrosshair()
    }

    /// 今見えている X軸の範囲(何本目〜何本目)。まだ表示していない・レイアウト前なら nil
    private func currentVisibleRange() -> (low: Double, high: Double)? {
        guard self.priceChart.data != nil else { return nil }
        guard self.priceChart.viewPortHandler.contentWidth > 0 else { return nil }
        return (low: self.priceChart.lowestVisibleX, high: self.priceChart.highestVisibleX)
    }

    /// 高さが変わったあとに、Y軸範囲を計算し直す
    /// - Parameter isFirstLayout: 初めてサイズが決まったときか(このときはまだ表示範囲が取れないので、初期表示範囲で計算する)
    private func updateAxisRangesAfterHeightChange(isFirstLayout: Bool) {
        guard self.priceChart.data != nil else { return }
        if isFirstLayout {
            self.updateAxisRangesForInitialCandles()
        } else {
            self.updateAxisRangesForVisibleCandles()
        }
    }

    /// 指定した X軸の範囲(low〜high)が表示されるよう、両チャートの拡大率とスクロール位置を設定する
    private func restoreVisibleRange(low: Double, high: Double) {
        let visibleWidth = high - low
        guard visibleWidth > 0 else { return }

        // X軸全体の幅(axisMinimum = xAxisMinimum 〜 axisMaximum = totalCount - 0.5)
        let totalWidth = Double(self.totalCount) - 0.5 - self.xAxisMinimum

        for chart in [self.priceChart, self.subChart] {
            chart.fitScreen()  // 拡大率・スクロール位置をリセット
            chart.zoom(scaleX: CGFloat(totalWidth / visibleWidth), scaleY: 1, x: 0, y: 0)  // 表示本数に合わせて拡大
            chart.moveViewToX(low)  // 左端を元の位置に合わせる
        }
        self.updateAxisRanges(from: Int(low.rounded()), to: Int(high.rounded()))
    }
}

// MARK: - 直接呼び出し用(Controller を使わない場合)

/// 指標の切り替えメニューが不要な画面(縦画面など)で、StockChartView だけを置いて使うための入口。
/// 描画内容の組み立て(Model: ChartContentBuilder)もここで行う。
///
///   | やりたいこと               | Swift                                                   | Objective-C                                              |
///   |----------------------------|---------------------------------------------------------|----------------------------------------------------------|
///   | 移動平均線 + 出来高で表示  | setCandles(candles)                                     | [chartView setCandles:candles]                           |
///   | 足種に合わせて表示         | setCandles(candles, period: .weekly)                    | [chartView setCandles:candles period:ChartPeriodWeekly]  |
///   | 海外指数として表示         | setCandles(candles, period: .daily, market: .overseas)  | [chartView setCandles:candles period:… market:IndexMarketOverseas] |
///   | 指標を指定して表示         | setCandles(candles, mainIndicator: .macd, …)            | [chartView setCandles:candles mainIndicator:… subIndicator:…] |
///   | パラメータも指定(Swift のみ)| setCandles(candles, mainIndicator: …, subIndicator: …, parameters: …) | (IndicatorParameters は struct のため不可)     |
extension StockChartView {

    /// ローソク足データを渡して、移動平均線 + 出来高で描画する
    /// - Parameter candles: 日付の古い順に並んだローソク足データ
    @objc func setCandles(_ candles: [StockCandle]) {
        self.setCandles(candles, mainIndicator: .movingAverage, subIndicator: .volume)
    }

    /// ローソク足データを渡して、足種に合った設定で、移動平均線 + 出来高を描画する。
    /// 足種によって、X軸の日付の書式・ラベルの個数・初期表示本数・移動平均の期間・出来高の凡例名が変わる(ChartPeriod)
    /// - Parameters:
    ///   - candles: 日付の古い順に並んだローソク足データ(その足種のデータ)
    ///   - period: 足種
    @objc func setCandles(_ candles: [StockCandle], period: ChartPeriod) {
        // 指数の種類は market の値(既定は国内指数)
        self.setCandles(candles, period: period, market: self.market)
    }

    /// ローソク足データを渡して、足種・指数の種類に合った設定で描画する。
    ///   ・国内指数: ローソク足 + 移動平均線、サブチャートに出来高
    ///   ・海外指数: ローソク足 + 移動平均線(サブチャートなし。メインチャートを全高で表示)
    /// - Parameters:
    ///   - candles: 日付の古い順に並んだローソク足データ(その足種のデータ)
    ///   - period: 足種
    ///   - market: 指数の種類
    @objc func setCandles(_ candles: [StockCandle], period: ChartPeriod, market: IndexMarket) {
        self.market = market

        // 足種に合わせて見た目を変える(style を変えると描き直されるので、まとめて1回で代入する)
        var newStyle = self.style
        newStyle.dateFormat = period.dateFormat
        newStyle.xAxisLabelCount = period.xAxisLabelCount
        newStyle.visibleCount = period.visibleCount
        self.style = newStyle

        switch market {
        case .domestic:
            self.setCandles(candles, mainIndicator: .movingAverage, subIndicator: .volume,
                       parameters: period.indicatorParameters)
        case .overseas:
            // サブチャート(出来高)は出さない
            self.setCandles(candles, mainIndicator: .movingAverage, subIndicator: .hidden,
                       parameters: period.indicatorParameters)
        }
    }

    /// ローソク足データを渡して、指定した指標で描画する(パラメータは既定値)
    /// - Parameters:
    ///   - candles: 日付の古い順に並んだローソク足データ
    ///   - mainIndicator: メインチャートの指標
    ///   - subIndicator: サブチャートの指標(.hidden でサブチャートなし)
    @objc func setCandles(_ candles: [StockCandle], mainIndicator: MainChartIndicator, subIndicator: SubChartIndicator) {
        self.setCandles(candles, mainIndicator: mainIndicator, subIndicator: subIndicator,
                   parameters: IndicatorParameters())
    }

    /// ローソク足データを渡して、指定した指標・パラメータで描画する(Swift のみ)
    /// - Parameters:
    ///   - candles: 日付の古い順に並んだローソク足データ
    ///   - mainIndicator: メインチャートの指標
    ///   - subIndicator: サブチャートの指標(.hidden でサブチャートなし)
    ///   - parameters: 指標の計算パラメータ(期間など)
    func setCandles(_ candles: [StockCandle], mainIndicator: MainChartIndicator, subIndicator: SubChartIndicator,
                    parameters: IndicatorParameters) {
        // データが0件でも凡例は表示するので、描画内容は組み立てる(チャートの代わりにメッセージが表示される)
        let builder = ChartContentBuilder(candles: candles, parameters: parameters)
        self.display(candles: candles,
                main: builder.mainContent(for: mainIndicator),
                sub: builder.subContent(for: subIndicator))
    }
}

// MARK: - Objective-C 向けのスタイル設定

/// StockChartStyle は struct のため Objective-C から直接扱えない。
/// よく変更する設定だけを @objc プロパティとして公開する(中身は style を読み書きしているだけ)。
extension StockChartView {

    // MARK: チャート全体

    /// 初期表示する本数。0 以下を指定すると全件表示(Swift 側の visibleCount = nil に相当)
    @objc var visibleCount: Int {
        get {
            return self.style.visibleCount ?? 0
        }
        set {
            if newValue > 0 {
                self.style.visibleCount = newValue
            } else {
                self.style.visibleCount = nil
            }
        }
    }

    /// メインチャートとサブチャートの高さ比(メイン : サブ = priceHeightRatio : 1)
    @objc var priceHeightRatio: CGFloat {
        get { return self.style.priceHeightRatio }
        set { self.style.priceHeightRatio = newValue }
    }

    /// 陽線(上昇)の色
    @objc var increasingColor: UIColor {
        get { return self.style.increasingColor }
        set { self.style.increasingColor = newValue }
    }

    /// 陰線(下降)の色
    @objc var decreasingColor: UIColor {
        get { return self.style.decreasingColor }
        set { self.style.decreasingColor = newValue }
    }

    /// X軸ラベルの日付の書式(例: "M/d"、"HH:mm")
    @objc var dateFormat: String {
        get { return self.style.dateFormat }
        set { self.style.dateFormat = newValue }
    }

    /// データが0件のときに表示するメッセージ
    @objc var noDataMessage: String {
        get { return self.style.noDataMessage }
        set { self.style.noDataMessage = newValue }
    }

    // MARK: 文字・ラベル

    /// 凡例のフォント(「移動平均 短期移動平均(5) …」の文字)
    @objc var legendFont: UIFont {
        get { return self.style.legendFont }
        set { self.style.legendFont = newValue }
    }

    /// X軸ラベル(日付)のフォント
    @objc var xAxisFont: UIFont {
        get { return self.style.xAxisFont }
        set { self.style.xAxisFont = newValue }
    }

    /// Y軸ラベル(価格・指標の値)のフォント
    @objc var yAxisFont: UIFont {
        get { return self.style.yAxisFont }
        set { self.style.yAxisFont = newValue }
    }

    /// 表示中の範囲の最高値・最安値を、その足の上・下に表示するか(ローソク足のときだけ)
    @objc var showsHighLowLabels: Bool {
        get { return self.style.showsHighLowLabels }
        set { self.style.showsHighLowLabels = newValue }
    }

    /// X軸ラベル(日付)同士の最小の間隔。0 より大きいと、この間隔を空けて幅に入るだけ日付を並べる(0 なら約7個)
    @objc var xAxisLabelSpacing: CGFloat {
        get { return self.style.xAxisLabelSpacing }
        set { self.style.xAxisLabelSpacing = newValue }
    }

    /// メインチャートの凡例の上端の位置(外枠の上端からの距離)
    @objc var legendTopInset: CGFloat {
        get { return self.style.legendTopInset }
        set { self.style.legendTopInset = newValue }
    }

    // MARK: 4本値

    /// 4本値を動かしてから、薄く表示するまでの秒数(0 以下なら薄くしない)
    @objc var crosshairFadeDelay: TimeInterval {
        get { return self.style.crosshairFadeDelay }
        set { self.style.crosshairFadeDelay = newValue }
    }

    /// 4本値を薄く表示するときの不透明度(0 〜 1)
    @objc var crosshairFadedAlpha: CGFloat {
        get { return self.style.crosshairFadedAlpha }
        set { self.style.crosshairFadedAlpha = newValue }
    }

    /// 4本値の日付のマーカーの画像(nil なら赤い矢印の形を塗る。画像はそのままの大きさで表示する)
    @objc var dateMarkerImage: UIImage? {
        get { return self.style.dateMarkerImage }
        set { self.style.dateMarkerImage = newValue }
    }

    /// 4本値の価格のマーカーの画像(nil なら赤い矢印の形を塗る。画像はそのままの大きさで表示する)
    @objc var yAxisMarkerImage: UIImage? {
        get { return self.style.yAxisMarkerImage }
        set { self.style.yAxisMarkerImage = newValue }
    }
}

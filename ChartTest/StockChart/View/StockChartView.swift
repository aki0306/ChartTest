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
//  【責務】
//  ・渡された描画内容(MainChartContent / SubChartContent)を DGCharts で描画する
//  ・レイアウト(外枠・区切り線・凡例・サブチャートの表示/非表示)
//  ・スクロール/ピンチ操作のメイン・サブ間の同期、表示範囲に合わせたY軸範囲の調整
//  指標の計算や「どの指標を表示するか」の状態は持たない(Model / Controller の責務)。
//
//  【仕組み】
//  ・メイン/サブは別々の CombinedChartView だが、外枠(frameView)と区切り線(dividerView)を
//    上から重ねて描くことで「1つの枠の中に2つのチャート」があるように見せている。
//  ・各チャートの描画領域(viewport)は setViewPortOffsets で固定値にしているため、
//    外枠・区切り線の位置は Auto Layout の制約だけで描画領域とぴったり一致する。
//
//  使い方(通常は StockChartViewController 経由で使う):
//      chartView.display(candles: candles, main: mainContent, sub: subContent)
//

import UIKit
import DGCharts

final class StockChartView: UIView {

    // MARK: - Style

    /// 見た目の設定。変更すると現在の内容を再描画する(表示位置は初期状態に戻る)
    var style = StockChartStyle() {
        didSet {
            applyStyle()
            render(keepingMatrix: nil)
        }
    }

    // MARK: - Constants

    /// 各チャートの描画領域の上下に確保する余白。
    /// 描画領域の端ちょうどにあるY軸ラベルは文字の半分が領域外にはみ出すため、
    /// その部分がチャートViewの境界で切れないように余白を取っておく。
    /// (メインとサブはこの余白ぶん重ねて配置するので、見た目上の隙間にはならない)
    private let labelOverflowInset: CGFloat = 8

    // MARK: - Subviews

    /// メインチャート(ローソク足 + メイン指標)
    private let priceChart = CombinedChartView()
    /// サブチャート(サブ指標)
    private let subChart = CombinedChartView()
    /// メインチャート用のレンダラー。一目均衡表の雲を塗るために差し替えている
    private lazy var priceRenderer = CloudCombinedRenderer(
        chart: priceChart, animator: priceChart.chartAnimator, viewPortHandler: priceChart.viewPortHandler)
    /// メイン・サブ全体を囲む外枠(チャートの上に重ねて表示)
    private let frameView = UIView()
    /// メインとサブの間の区切り線
    private let dividerView = UIView()
    /// メインチャートの凡例
    private let priceLegendLabel = UILabel()
    /// サブチャートの凡例
    private let subLegendLabel = UILabel()

    // MARK: - Layout constraints(スタイル・サブチャート表示有無によって変わる制約)

    /// サブチャートを区切り線の位置まで重ねるための制約
    private var subTopConstraint: NSLayoutConstraint?
    /// 外枠の右端(Y軸ラベル領域の左端)を決める制約
    private var frameTrailingConstraint: NSLayoutConstraint?
    /// 区切り線の太さを決める制約
    private var dividerHeightConstraint: NSLayoutConstraint?
    /// [サブあり] メインとサブの高さ比を決める制約
    private var priceHeightConstraint: NSLayoutConstraint?
    /// [サブあり] 外枠の下端をサブチャートのX軸ラベル領域の上端に合わせる制約
    private var frameBottomWithSubConstraint: NSLayoutConstraint?
    /// [サブなし] メインチャートの下端をこのViewの下端に合わせる制約
    private var priceBottomConstraint: NSLayoutConstraint?
    /// [サブなし] 外枠の下端をメインチャートのX軸ラベル領域の上端に合わせる制約
    private var frameBottomWithoutSubConstraint: NSLayoutConstraint?

    // MARK: - 表示中の内容

    /// 表示中のローソク足データ(古い順)
    private var candles: [StockCandle] = []
    /// 表示中のメインチャートの内容
    private var mainContent = MainChartContent()
    /// 表示中のサブチャートの内容(nil = サブチャートなし)
    private var subContent: SubChartContent?

    /// データの右端より先に描く本数(一目均衡表の先行スパン用。それ以外は 0)
    private var futureCount: Int { mainContent.futureCount }
    /// X軸に並ぶ本数(先行スパンの先の部分を含む)
    private var totalCount: Int { candles.count + futureCount }
    /// サブチャートを表示中か
    private var hasSubChart: Bool { subContent != nil }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    /// Storyboard / XIB から生成された場合
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Public

    /// 描画内容を表示する。
    /// - Parameters:
    ///   - candles: 日付の古い順に並んだローソク足データ
    ///   - main: メインチャート(ローソク足に重ねる部分)の内容
    ///   - sub: サブチャートの内容。nil の場合はサブチャートを隠し、メインチャートを全高で表示する
    ///   - keepsViewport: true の場合、可能であれば現在の表示位置・拡大率を維持する(指標の切り替え時など)
    func display(candles: [StockCandle], main: MainChartContent, sub: SubChartContent?, keepsViewport: Bool = false) {
        // 表示位置を維持できるのは、レイアウト済み(描画領域の幅が確定済み)で、
        // X軸の範囲(データ件数・先行スパンの本数)が変わらない場合のみ
        let canKeepViewport = keepsViewport
            && priceChart.data != nil
            && priceChart.viewPortHandler.contentWidth > 0
            && candles.count == self.candles.count
            && main.futureCount == futureCount
        let savedMatrix = priceChart.viewPortHandler.touchMatrix
        let subVisibilityChanged = (sub != nil) != hasSubChart

        self.candles = candles
        self.mainContent = main
        self.subContent = sub

        if subVisibilityChanged {
            updateSubChartVisibility()
        }
        render(keepingMatrix: canKeepViewport ? savedMatrix : nil)
    }

    /// 表示内容をすべて消す
    func clear() {
        candles = []
        mainContent = MainChartContent()
        subContent = nil
        render(keepingMatrix: nil)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        // DGCharts はスクロール位置をピクセル単位で保持しているため、画面回転などで幅が変わると
        // 表示範囲がずれてしまう。サイズ変更前の表示範囲(X軸の値)を覚えておき、変更後に復元する
        let oldWidth = priceChart.viewPortHandler.contentWidth
        let oldRange = oldWidth > 0 && priceChart.data != nil
            ? (low: priceChart.lowestVisibleX, high: priceChart.highestVisibleX)
            : nil

        super.layoutSubviews()  // ここでチャートのサイズが変わる

        if let oldRange, priceChart.viewPortHandler.contentWidth != oldWidth {
            restoreVisibleRange(low: oldRange.low, high: oldRange.high)
        }
    }

    /// 指定した X軸の範囲(low〜high)が表示されるよう、両チャートの拡大率とスクロール位置を設定する
    private func restoreVisibleRange(low: Double, high: Double) {
        let visible = high - low
        guard visible > 0 else { return }
        // X軸全体の幅(axisMinimum = -0.5 〜 axisMaximum = totalCount - 0.5)
        let total = Double(totalCount)

        [priceChart, subChart].forEach { chart in
            chart.fitScreen()  // 拡大率・スクロール位置をリセット
            chart.zoom(scaleX: CGFloat(total / visible), scaleY: 1, x: 0, y: 0)  // 表示本数に合わせて拡大
            chart.moveViewToX(low)  // 左端を元の位置に合わせる
        }
        updateAxisRanges(from: Int(low.rounded()), to: Int(high.rounded()))
    }

    // MARK: - Setup

    /// サブViewの追加と、スタイルに依存しない制約の設定を行う(初期化時に1回だけ呼ばれる)
    private func setup() {
        // チャート本体。delegate でスクロール/ズームを受け取り、もう一方のチャートに同期する
        [priceChart, subChart].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.delegate = self
            $0.noDataText = ""  // データなしのときの文言は表示しない
            addSubview($0)
        }
        // 雲を描けるレンダラーに差し替える(drawOrder などの設定より前に行う)
        priceChart.renderer = priceRenderer

        // 外枠・区切り線・凡例はチャートの上に重ねる。
        // タッチはチャートに届くよう isUserInteractionEnabled を false にしておく
        [frameView, dividerView, priceLegendLabel, subLegendLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }
        frameView.backgroundColor = .clear

        // 凡例が長い場合(一目均衡表など)は枠内に収まるよう文字を縮小する
        [priceLegendLabel, subLegendLabel].forEach {
            $0.adjustsFontSizeToFitWidth = true
            $0.minimumScaleFactor = 0.6
        }

        NSLayoutConstraint.activate([
            // メインチャート: 上端と左右をこのViewに合わせる(下端/高さは applyLayoutConstraints で設定)
            priceChart.topAnchor.constraint(equalTo: topAnchor),
            priceChart.leadingAnchor.constraint(equalTo: leadingAnchor),
            priceChart.trailingAnchor.constraint(equalTo: trailingAnchor),

            // サブチャート: 左右と下端をこのViewに合わせる(上端は applyLayoutConstraints で設定)
            subChart.leadingAnchor.constraint(equalTo: leadingAnchor),
            subChart.trailingAnchor.constraint(equalTo: trailingAnchor),
            subChart.bottomAnchor.constraint(equalTo: bottomAnchor),

            // 外枠: 上端 = メインチャート描画領域の上端、左端 = このViewの左端
            //       (右端・下端は applyLayoutConstraints で設定)
            frameView.topAnchor.constraint(equalTo: priceChart.topAnchor, constant: labelOverflowInset),
            frameView.leadingAnchor.constraint(equalTo: leadingAnchor),

            // 区切り線: メインチャート描画領域の下端に、外枠と同じ幅で配置する
            dividerView.centerYAnchor.constraint(equalTo: priceChart.bottomAnchor, constant: -labelOverflowInset),
            dividerView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor),
            dividerView.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),

            // 凡例: 各チャート描画領域の左上(枠の内側)に表示する
            priceLegendLabel.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 6),
            priceLegendLabel.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 8),
            priceLegendLabel.trailingAnchor.constraint(lessThanOrEqualTo: frameView.trailingAnchor, constant: -8),
            subLegendLabel.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 4),
            subLegendLabel.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 8),
            subLegendLabel.trailingAnchor.constraint(lessThanOrEqualTo: frameView.trailingAnchor, constant: -8),
        ])

        observeColorAppearanceChanges()
        applyStyle()
    }

    /// スタイルに依存する見た目・制約・軸の設定を適用する
    private func applyStyle() {
        applyLayoutConstraints()

        // 外枠と区切り線の色・線幅
        frameView.layer.borderColor = style.borderColor.resolvedColor(with: traitCollection).cgColor
        frameView.layer.borderWidth = style.borderWidth
        dividerView.backgroundColor = style.dividerColor

        // --- メイン/サブ共通の設定 ---
        [priceChart, subChart].forEach { chart in
            chart.backgroundColor = .clear
            chart.chartDescription.enabled = false  // 右下の説明文は使わない
            chart.legend.enabled = false            // 凡例は独自の UILabel で表示する
            chart.drawBordersEnabled = false        // 枠線は frameView で描くのでチャート側では描かない
            chart.drawGridBackgroundEnabled = false

            // 操作: 横方向のスクロール・ピンチのみ許可。タップ時のハイライトは無効
            chart.dragEnabled = true
            chart.setScaleEnabled(true)
            chart.scaleYEnabled = false
            chart.pinchZoomEnabled = false
            chart.doubleTapToZoomEnabled = false
            chart.highlightPerTapEnabled = false
            chart.highlightPerDragEnabled = false

            // Y軸の範囲は表示中の値から自前で算出する(updateAxisRanges)。
            // DGCharts の autoScaleMinMax は CombinedChart でローソク足のヒゲや
            // 一目均衡表の先行スパン(データ範囲外)を考慮しきれないため使わない
            chart.autoScaleMinMaxEnabled = false

            // 描画順: 棒 → ローソク足 → 線 → 点(パラボリック)
            chart.drawOrder = [CombinedChartView.DrawOrder.bar.rawValue,
                               CombinedChartView.DrawOrder.candle.rawValue,
                               CombinedChartView.DrawOrder.line.rawValue,
                               CombinedChartView.DrawOrder.scatter.rawValue]

            // 左のY軸は使わず、右のY軸のみ表示する
            chart.leftAxis.enabled = false

            // 右のY軸: ラベルは描画領域の外側(右側)、軸線は外枠と重なるので描かない
            let right = chart.rightAxis
            right.labelFont = style.axisFont
            right.labelTextColor = style.textColor
            right.gridColor = style.gridColor
            right.drawAxisLineEnabled = false
            right.labelPosition = .outsideChart
            right.xOffset = 10
            right.drawLimitLinesBehindDataEnabled = true  // 基準線は指標の線より下に描く

            // X軸: 縦グリッド線と軸線は描かない。1本単位でラベルを配置する
            let x = chart.xAxis
            x.labelPosition = .bottom
            x.drawGridLinesEnabled = false
            x.drawAxisLineEnabled = false
            x.labelFont = style.axisFont
            x.labelTextColor = style.textColor
            x.granularity = 1
            x.granularityEnabled = true
            x.labelCount = 7                         // X軸ラベルは約7個
            x.avoidFirstLastClippingEnabled = true   // 両端のラベルが描画領域からはみ出さないようにする
        }

        // メインチャートのY軸: 区切り線付近のラベルがサブチャートの最上段ラベルと重ならないよう、
        // 下端付近のラベルは非表示にする
        priceChart.rightAxis.valueFormatter = ChartAxisValueFormatter(
            formatter: Self.numberFormatter(fractionDigits: 0, suffix: ""), hiddenBottomRatio: 0.06, hiddenAbove: nil)

        // サブチャートの Y軸(ラベル間隔・書式・基準線)はサブ指標ごとに設定する(configureSubAxis)

        updateSubChartVisibility()
    }

    /// スタイルに依存するレイアウト制約を作り直す
    private func applyLayoutConstraints() {
        let inset = labelOverflowInset

        // 既存の制約を無効化してから作り直す
        [subTopConstraint, frameTrailingConstraint, dividerHeightConstraint,
         priceHeightConstraint, frameBottomWithSubConstraint,
         priceBottomConstraint, frameBottomWithoutSubConstraint].forEach { $0?.isActive = false }

        // サブチャートの上端: メインチャートの描画領域下端(= 区切り線)から、さらに inset 分上に重ねる。
        // こうするとサブチャートの描画領域上端(View上端 + inset)が区切り線とちょうど一致する
        subTopConstraint = subChart.topAnchor.constraint(equalTo: priceChart.bottomAnchor, constant: -inset * 2)

        // 外枠の右端 = Y軸ラベル領域の左端
        frameTrailingConstraint = frameView.trailingAnchor.constraint(
            equalTo: trailingAnchor, constant: -style.rightAxisWidth)

        // 区切り線の太さは外枠と同じ
        dividerHeightConstraint = dividerView.heightAnchor.constraint(equalToConstant: style.borderWidth)

        // [サブあり] メイン/サブの「描画領域」の高さ比を ratio : 1 にする。
        //   メイン描画領域の高さ P' = P - inset * 2           (上下に inset)
        //   サブ描画領域の高さ   V' = V - inset - xLabelHeight (上に inset、下にX軸ラベル)
        //   P' = ratio * V'  を P について解くと
        //   P = ratio * V + (inset * 2 - ratio * (inset + xLabelHeight))
        let ratio = style.priceHeightRatio
        priceHeightConstraint = priceChart.heightAnchor.constraint(
            equalTo: subChart.heightAnchor,
            multiplier: ratio,
            constant: inset * 2 - ratio * (inset + style.xAxisLabelHeight))
        // [サブあり] 外枠の下端 = サブチャートのX軸ラベル領域の上端
        frameBottomWithSubConstraint = frameView.bottomAnchor.constraint(
            equalTo: subChart.bottomAnchor, constant: -style.xAxisLabelHeight)

        // [サブなし] メインチャートをこのViewの下端まで伸ばし、外枠の下端 = メインのX軸ラベル領域の上端
        priceBottomConstraint = priceChart.bottomAnchor.constraint(equalTo: bottomAnchor)
        frameBottomWithoutSubConstraint = frameView.bottomAnchor.constraint(
            equalTo: priceChart.bottomAnchor, constant: -style.xAxisLabelHeight)

        [subTopConstraint, frameTrailingConstraint, dividerHeightConstraint].forEach { $0?.isActive = true }
        // サブあり/なしで切り替わる制約は updateSubChartVisibility で有効化する
    }

    /// サブチャートの表示/非表示に合わせて、制約・描画領域・X軸ラベルの表示先を切り替える
    private func updateSubChartVisibility() {
        let inset = labelOverflowInset
        let showsSub = hasSubChart

        // 先に無効化してから有効化する(同時に有効になると制約が衝突するため)
        let withSub = [priceHeightConstraint, frameBottomWithSubConstraint]
        let withoutSub = [priceBottomConstraint, frameBottomWithoutSubConstraint]
        (showsSub ? withoutSub : withSub).forEach { $0?.isActive = false }
        (showsSub ? withSub : withoutSub).forEach { $0?.isActive = true }

        subChart.isHidden = !showsSub
        subLegendLabel.isHidden = !showsSub
        dividerView.isHidden = !showsSub

        // X軸ラベル(日付)は一番下のチャートにだけ表示する。
        // setViewPortOffsets を使うとラベルサイズからの自動計算が無効になり、
        // 描画領域が常に「Viewの境界 - 指定したオフセット」になる。
        // これにより外枠・区切り線を制約だけで描画領域に合わせられる。
        priceChart.xAxis.drawLabelsEnabled = !showsSub
        priceChart.setViewPortOffsets(left: 0, top: inset, right: style.rightAxisWidth,
                                      bottom: showsSub ? inset : style.xAxisLabelHeight)
        subChart.setViewPortOffsets(left: 0, top: inset, right: style.rightAxisWidth,
                                    bottom: style.xAxisLabelHeight)
    }

    /// ライト/ダークモード切り替え時に、CGColor で保持している外枠の色を更新する
    /// (layer.borderColor は UIColor の動的カラーに自動追従しないため)
    private func observeColorAppearanceChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.frameView.layer.borderColor =
                self.style.borderColor.resolvedColor(with: self.traitCollection).cgColor
        }
    }

    // MARK: - Rendering

    /// 保持している内容(candles / mainContent / subContent)をチャートに反映する
    /// - Parameter matrix: 適用する表示位置・拡大率。nil の場合は初期表示位置(直近 visibleCount 本)にする
    private func render(keepingMatrix matrix: CGAffineTransform?) {
        // データが空ならチャートをクリアして終了
        guard !candles.isEmpty else {
            priceChart.data = nil
            subChart.data = nil
            priceRenderer.cloud = nil
            priceLegendLabel.attributedText = nil
            subLegendLabel.attributedText = nil
            return
        }

        // X軸の値はデータのインデックス(0, 1, 2, ...)。
        // 日付をそのまま使うと土日・祝日が空白になるため、インデックス → 日付文字列に変換して表示する
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = style.dateFormat
        let xFormatter = DateAxisValueFormatter(dates: candles.map(\.date), formatter: dateFormatter)

        // 両端のローソク足/バーが半分切れないよう、X軸の範囲を前後に 0.5 本ずつ広げる。
        // メインとサブで範囲を揃えておかないとスクロール同期がずれるので、両方に同じ値を設定する
        [priceChart, subChart].forEach {
            $0.xAxis.valueFormatter = xFormatter
            $0.xAxis.axisMinimum = -0.5
            $0.xAxis.axisMaximum = Double(totalCount) - 0.5
        }

        // --- メインチャート ---
        priceRenderer.cloud = mainContent.cloud.map {
            CloudCombinedRenderer.Cloud(
                spanA: $0.spanA, spanB: $0.spanB,
                upColor: style.ichimokuSpanAColor.withAlphaComponent(style.cloudAlpha),
                downColor: style.ichimokuSpanBColor.withAlphaComponent(style.cloudAlpha))
        }
        priceChart.data = makePriceData()
        priceLegendLabel.attributedText = makeLegend(
            title: mainContent.legendTitle,
            items: mainContent.series.compactMap { s in s.label.map { ($0, s.colorRole) } })

        // --- サブチャート ---
        if let sub = subContent {
            subChart.data = makeSubData(sub)
            configureSubAxis(sub)
            var items: [(String, ChartColorRole)] = []
            if let bars = sub.bars, let label = bars.label { items.append((label, bars.labelColorRole)) }
            items += sub.series.compactMap { s in s.label.map { ($0, s.colorRole) } }
            subLegendLabel.attributedText = makeLegend(title: sub.legendTitle, items: items)
        } else {
            subChart.data = nil
            subLegendLabel.attributedText = nil
        }

        // --- 表示位置 ---
        [priceChart, subChart].forEach { chart in
            if let matrix {
                // 指定された表示位置・拡大率(切り替え前の状態)をそのまま適用する
                chart.notifyDataSetChanged()
                chart.viewPortHandler.refresh(newMatrix: matrix, chart: chart, invalidate: true)
            } else {
                // 直近 visibleCount 本を表示し、右端(最新)にスクロールしておく。
                // (レイアウト前の場合、moveViewToX はサイズ確定後に DGCharts が自動で実行する)
                chart.fitScreen()
                if let visible = style.visibleCount, visible < totalCount {
                    chart.setVisibleXRangeMaximum(Double(visible))
                    chart.moveViewToX(Double(totalCount))
                }
                chart.notifyDataSetChanged()
            }
        }

        // 表示範囲に合わせてY軸を調整する。
        // (初期表示はレイアウト前で lowestVisibleX が使えない場合があるため、インデックスから計算する)
        if matrix != nil {
            updateAxisRanges(from: Int(priceChart.lowestVisibleX.rounded()),
                             to: Int(priceChart.highestVisibleX.rounded()))
        } else {
            let firstIndex = style.visibleCount.map { max(0, totalCount - $0) } ?? 0
            updateAxisRanges(from: firstIndex, to: totalCount - 1)
        }
    }

    /// 凡例のテキストを作る(タイトルは文字色、各項目はその線の色)
    private func makeLegend(title: String?, items: [(String, ChartColorRole)]) -> NSAttributedString? {
        var all: [(String, UIColor)] = []
        if let title { all.append((title, style.textColor)) }
        all += items.map { ($0.0, style.color(for: $0.1)) }
        guard !all.isEmpty else { return nil }

        let text = NSMutableAttributedString()
        for (i, item) in all.enumerated() {
            if i > 0 { text.append(NSAttributedString(string: " ")) }
            text.append(NSAttributedString(string: item.0, attributes: [
                .foregroundColor: item.1,
                .font: style.legendFont,
            ]))
        }
        return text
    }

    /// メインチャートのデータ(ローソク足 + メイン指標)を作る
    private func makePriceData() -> CombinedChartData {
        // ローソク足
        let candleEntries = candles.enumerated().map { i, c in
            CandleChartDataEntry(x: Double(i), shadowH: c.high, shadowL: c.low, open: c.open, close: c.close)
        }
        let candleSet = CandleChartDataSet(entries: candleEntries, label: "ローソク足")
        candleSet.axisDependency = .right               // 右のY軸を基準に描画する
        candleSet.drawValuesEnabled = false             // 各足の値ラベルは表示しない
        candleSet.highlightEnabled = false
        candleSet.increasingColor = style.increasingColor
        candleSet.increasingFilled = true               // 陽線も塗りつぶす(日本式)
        candleSet.decreasingColor = style.decreasingColor
        candleSet.decreasingFilled = true
        candleSet.neutralColor = style.textColor        // 始値 = 終値(同事線)の色
        candleSet.shadowColorSameAsCandle = true        // ヒゲを実体と同じ色にする
        candleSet.shadowWidth = 1
        candleSet.barSpace = 0.15                       // 足同士の隙間(1本分の幅に対する割合)

        let data = CombinedChartData()
        data.candleData = CandleChartData(dataSet: candleSet)
        applySeries(mainContent.series, to: data)
        return data
    }

    /// サブチャートのデータ(棒グラフ + 線)を作る
    private func makeSubData(_ content: SubChartContent) -> CombinedChartData {
        let data = CombinedChartData()

        if let bars = content.bars {
            // nil の位置は棒を作らない。色は作った棒と同じ並びにする
            var entries: [BarChartDataEntry] = []
            var colors: [UIColor] = []
            for (i, value) in bars.values.enumerated() {
                guard let value else { continue }
                entries.append(BarChartDataEntry(x: Double(i), y: value))
                colors.append(style.color(for: bars.colorRoles[i]))
            }
            let barSet = BarChartDataSet(entries: entries, label: bars.label ?? "")
            barSet.axisDependency = .right
            barSet.drawValuesEnabled = false
            barSet.highlightEnabled = false
            barSet.colors = colors
            let barData = BarChartData(dataSet: barSet)
            barData.barWidth = 0.7  // バーの幅(1本分の幅に対する割合)
            data.barData = barData
        }

        applySeries(content.series, to: data)
        return data
    }

    /// 線・点の ChartSeries を DGCharts のデータ(lineData / scatterData)に変換して設定する
    private func applySeries(_ series: [ChartSeries], to data: CombinedChartData) {
        let lineSets = series.filter { $0.style == .line }.map(makeLineSet)
        let dotSets = series.filter { $0.style == .dots }.map(makeScatterSet)
        if !lineSets.isEmpty { data.lineData = LineChartData(dataSets: lineSets) }
        if !dotSets.isEmpty { data.scatterData = ScatterChartData(dataSets: dotSets) }
    }

    /// 線(折れ線)用のデータセットを作る。nil の位置は線を描かない
    private func makeLineSet(_ series: ChartSeries) -> LineChartDataSet {
        let set = LineChartDataSet(entries: makeEntries(series.values), label: series.label ?? "")
        set.axisDependency = .right
        set.setColor(style.color(for: series.colorRole))
        set.lineWidth = 1.2
        set.drawCirclesEnabled = false  // データ点の丸は描かない
        set.drawValuesEnabled = false
        set.highlightEnabled = false
        set.mode = .linear
        return set
    }

    /// 点(パラボリック)用のデータセットを作る
    private func makeScatterSet(_ series: ChartSeries) -> ScatterChartDataSet {
        let set = ScatterChartDataSet(entries: makeEntries(series.values), label: series.label ?? "")
        set.axisDependency = .right
        set.setScatterShape(.circle)
        set.scatterShapeSize = 3
        set.setColor(style.color(for: series.colorRole))
        set.drawValuesEnabled = false
        set.highlightEnabled = false
        return set
    }

    /// インデックスごとの値の配列を、nil を除いたエントリーの配列に変換する
    private func makeEntries(_ values: [Double?]) -> [ChartDataEntry] {
        values.enumerated().compactMap { i, v in v.map { ChartDataEntry(x: Double(i), y: $0) } }
    }

    /// サブチャートのY軸(ラベル間隔・書式・基準線)を内容に合わせて設定する
    private func configureSubAxis(_ content: SubChartContent) {
        let axis = subChart.rightAxis

        // 基準線(RSI の 30/70 など)を破線で引く
        axis.removeAllLimitLines()
        for level in content.referenceLines {
            let line = ChartLimitLine(limit: level)
            line.lineColor = style.referenceLineColor
            line.lineWidth = 0.8
            line.lineDashLengths = [4, 3]
            line.drawLabelEnabled = false
            axis.addLimitLine(line)
        }

        // ラベルの間隔。固定範囲(0〜100)の場合は凡例用に広げた上端(125)まで含めて 25 刻みの 6 本にする。
        // それ以外は DGCharts に任せて 5 本程度
        if content.fixedRange != nil {
            axis.setLabelCount(6, force: true)
        } else {
            axis.setLabelCount(5, force: false)
        }

        // ラベルの書式。固定範囲の場合、凡例用に上へ広げた部分(100 超など)のラベルは表示しない
        axis.valueFormatter = ChartAxisValueFormatter(
            formatter: Self.numberFormatter(fractionDigits: content.fractionDigits, suffix: content.suffix),
            hiddenBottomRatio: 0, hiddenAbove: content.fixedRange?.upperBound)
    }

    // MARK: - Y軸範囲の調整

    /// 表示範囲の値に合わせてメイン/サブのY軸範囲を調整する
    /// - Parameters:
    ///   - from: 表示範囲の先頭インデックス
    ///   - to: 表示範囲の末尾インデックス
    private func updateAxisRanges(from: Int, to: Int) {
        let lower = min(from, to)
        let upper = max(from, to)

        // --- メインチャート ---
        // 範囲の計算対象: 高値・安値・メイン指標の各線
        let mainValues = [candles.map { Optional($0.high) }, candles.map { Optional($0.low) }]
            + mainContent.series.map(\.values)
        // 上側は凡例と重ならないよう値幅の 20%、下側は 5% の余白を取る
        if let (low, high) = Self.valueRange(of: mainValues, from: lower, to: upper) {
            let range = Self.nonZeroRange(low: low, high: high)
            priceChart.rightAxis.axisMaximum = high + range * 0.2
            priceChart.rightAxis.axisMinimum = low - range * 0.05
            priceChart.notifyDataSetChanged()
        }

        // --- サブチャート ---
        guard let sub = subContent else { return }
        let axis = subChart.rightAxis
        if let fixed = sub.fixedRange {
            // 固定範囲(0〜100 など)。上側は凡例用に 25% 広げる(その部分のラベルは非表示)
            axis.axisMinimum = fixed.lowerBound
            axis.axisMaximum = fixed.upperBound + (fixed.upperBound - fixed.lowerBound) * 0.25
        } else {
            // 範囲の計算対象: サブ指標の各線・棒
            let subValues = sub.series.map(\.values) + (sub.bars.map { [$0.values] } ?? [])
            if var (low, high) = Self.valueRange(of: subValues, from: lower, to: upper) {
                if sub.includesZero {
                    low = min(low, 0)
                    high = max(high, 0)
                }
                // 上側は凡例と重ならないよう値幅の 30%、下側は 5% の余白を取る(0 起点の場合は 0 から)
                let range = Self.nonZeroRange(low: low, high: high)
                axis.axisMaximum = high + range * 0.3
                axis.axisMinimum = (sub.includesZero && low == 0) ? 0 : low - range * 0.05
            }
        }
        subChart.notifyDataSetChanged()
    }

    /// 複数の値の配列から、指定インデックス範囲内の最小値・最大値を求める(nil は無視)
    private static func valueRange(of arrays: [[Double?]], from: Int, to: Int) -> (low: Double, high: Double)? {
        var low = Double.infinity
        var high = -Double.infinity
        for values in arrays {
            let lower = max(from, 0)
            let upper = min(to, values.count - 1)
            guard lower <= upper else { continue }
            for case let value? in values[lower...upper] {
                low = min(low, value)
                high = max(high, value)
            }
        }
        return low <= high ? (low, high) : nil
    }

    /// 値幅を返す。値幅 0 の場合に軸の範囲が潰れないよう、値の大きさに応じた幅を返す
    private static func nonZeroRange(low: Double, high: Double) -> Double {
        let range = high - low
        return range > 0 ? range : max(abs(high), 1)
    }

    // MARK: - Formatter

    /// Y軸ラベル用の3桁カンマ区切りフォーマッタを作る
    /// - Parameters:
    ///   - fractionDigits: 小数点以下の最大桁数(不要な 0 は表示しない)
    ///   - suffix: 末尾に付ける文字(「%」など)
    private static func numberFormatter(fractionDigits: Int, suffix: String) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = fractionDigits
        f.positiveSuffix = suffix
        f.negativeSuffix = suffix
        return f
    }
}

// MARK: - Objective-C 向けのスタイル設定

/// StockChartStyle は struct のため Objective-C から直接扱えない。
/// よく変更する設定だけを @objc プロパティとして公開する(中身は style を読み書きしているだけ)。
extension StockChartView {

    /// 初期表示する本数。0 以下を指定すると全件表示(Swift 側の visibleCount = nil に相当)
    @objc var visibleCount: Int {
        get { style.visibleCount ?? 0 }
        set { style.visibleCount = newValue > 0 ? newValue : nil }
    }

    /// メインチャートとサブチャートの高さ比(メイン : サブ = priceHeightRatio : 1)
    @objc var priceHeightRatio: CGFloat {
        get { style.priceHeightRatio }
        set { style.priceHeightRatio = newValue }
    }

    /// 陽線(上昇)の色
    @objc var increasingColor: UIColor {
        get { style.increasingColor }
        set { style.increasingColor = newValue }
    }

    /// 陰線(下降)の色
    @objc var decreasingColor: UIColor {
        get { style.decreasingColor }
        set { style.decreasingColor = newValue }
    }
}

// MARK: - ChartViewDelegate(メイン/サブのスクロール・ズーム同期)

extension StockChartView: ChartViewDelegate {

    /// ピンチでズームされたとき
    func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
        syncViewPort(from: chartView)
    }

    /// ドラッグでスクロールされたとき
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        syncViewPort(from: chartView)
    }

    /// 操作されたチャートの表示位置・倍率(変換行列)を、もう一方のチャートにコピーする。
    /// 両チャートは描画領域の左右位置と幅・X軸の範囲が同じなので、行列をそのままコピーすれば表示範囲が一致する
    private func syncViewPort(from source: ChartViewBase) {
        let target: CombinedChartView = (source === priceChart) ? subChart : priceChart
        let matrix = source.viewPortHandler.touchMatrix
        target.viewPortHandler.refresh(newMatrix: matrix, chart: target, invalidate: true)

        // 表示範囲が変わったのでY軸を調整する
        updateAxisRanges(from: Int(priceChart.lowestVisibleX.rounded()),
                         to: Int(priceChart.highestVisibleX.rounded()))
    }
}

// MARK: - X軸フォーマッタ(インデックス → 日付)

/// X軸の値(データのインデックス)を日付文字列に変換するフォーマッタ
private final class DateAxisValueFormatter: AxisValueFormatter {
    /// インデックスに対応する日付の配列
    private let dates: [Date]
    /// 日付 → 文字列の変換に使うフォーマッタ
    private let formatter: DateFormatter

    init(dates: [Date], formatter: DateFormatter) {
        self.dates = dates
        self.formatter = formatter
    }

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let index = Int(value.rounded())
        // 範囲外(前後の余白部分・一目均衡表の先行スパンの先)は空文字
        guard dates.indices.contains(index) else { return "" }
        return formatter.string(from: dates[index])
    }
}

// MARK: - Y軸フォーマッタ(端のラベルを隠す)

/// 数値を書式化し、軸の下端付近や指定値より上のラベルを空文字にするフォーマッタ。
///   ・下端付近: メインチャートの最下段ラベルが、区切り線を挟んでサブチャートの最上段ラベルと重なるのを防ぐ
///   ・指定値より上: RSI などで凡例用に 100 より上へ広げた部分のラベルを出さない
private final class ChartAxisValueFormatter: AxisValueFormatter {
    /// 数値 → 文字列の変換に使うフォーマッタ
    private let formatter: NumberFormatter
    /// 軸の値幅に対して、下端からこの割合以内にあるラベルを隠す(0 なら隠さない)
    private let hiddenBottomRatio: Double
    /// この値より大きいラベルを隠す(nil なら隠さない)
    private let hiddenAbove: Double?

    init(formatter: NumberFormatter, hiddenBottomRatio: Double, hiddenAbove: Double?) {
        self.formatter = formatter
        self.hiddenBottomRatio = hiddenBottomRatio
        self.hiddenAbove = hiddenAbove
    }

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        if let axis, axis.axisRange > 0,
           (value - axis.axisMinimum) / axis.axisRange < hiddenBottomRatio {
            return ""
        }
        if let hiddenAbove, value > hiddenAbove + 1e-9 {
            return ""
        }
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }
}

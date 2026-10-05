//
//  StockChartView+Layout.swift
//  ChartTest
//
//  【View】StockChartView の部品の配置(Auto Layout)と見た目の設定。
//
//  ・setup()                    … 初期化時に1回だけ。部品を追加し、変わらない制約を張る
//  ・applyStyle()               … style が変わるたび。色・フォント・軸の設定と、スタイルに依存する制約
//  ・updateSubChartVisibility() … サブチャートの有無が変わるたび。制約と描画領域を切り替える
//
//  【部品の重なり順】(奥から手前へ。arrangeSubviewOrder で決める)
//   1. dateMarker(日付の赤い矢印)      … チャートより奥。透明なチャートが描く日付ラベルが矢印の上に重なって見える
//   2. priceChartView / subChartView(チャート本体)
//   3. crosshairView(十字線)
//   4. highPriceLabel / lowPriceLabel(最高値・最安値の文字)
//   5. frameView / dividerView(外枠・区切り線)、凡例、データなしのメッセージ
//   6. ohlcInfoView / valueMarker / yAxisMarker(4本値の枠・マーカー) … 一番手前
//  チャートより手前にある部品はタッチを受け取らない(isUserInteractionEnabled = false)ので、
//  スクロールやタップはすべて下のチャートに届く。
//

import UIKit
import DGCharts

extension StockChartView {

    // MARK: - 初期化時の設定

    /// 部品の追加と、スタイルに依存しない制約の設定を行う(初期化時に1回だけ呼ばれる)
    func setup() {
        self.addCharts()
        self.addCrosshairParts()
        self.addCrosshairGestures()
        self.addOverlays()
        self.arrangeSubviewOrder()
        self.activateFixedConstraints()
        self.applyStyle()
    }

    /// 部品の重なり順を整える(追加した順に手前に重なるので、追加後に一部だけ入れ替える)
    private func arrangeSubviewOrder() {
        // 4本値の枠・マーカーは、最高値・最安値の文字や凡例より手前に表示する
        for view in [self.ohlcInfoView, self.valueMarker, self.yAxisMarker] {
            self.bringSubviewToFront(view)
        }
        // 日付のマーカー(矢印)は、チャートより奥に置く。
        // チャートの背景は透明なので、矢印の上にチャートが描く日付ラベルの文字が重なって見える
        self.sendSubviewToBack(self.dateMarker)
    }

    /// チャート本体(メイン・サブ)を追加する
    private func addCharts() {
        for chart in [self.priceChartView, self.subChartView] {
            chart.translatesAutoresizingMaskIntoConstraints = false
            chart.delegate = self   // スクロール/ズームを受け取り、もう一方のチャートに同期する(AxisRange)
            chart.noDataText = ""   // データなしのときの文言は表示しない
            self.addSubview(chart)
        }
        // 雲を描けるレンダラーに差し替える(drawOrder などの設定より前に行う)
        self.priceChartView.renderer = self.priceRenderer
        // X軸ラベルを最新の足を基準に並べる描画処理に差し替える(LatestAlignedXAxisRenderer)
        self.priceChartView.xAxisRenderer = self.priceXAxisRenderer
        self.subChartView.xAxisRenderer = self.subXAxisRenderer
        // Y軸ラベルを中央揃え・枠内に収めて描けるよう、描画処理を差し替える(AlignedYAxisRenderer)
        self.priceChartView.rightYAxisRenderer = self.priceYAxisRenderer
        self.subChartView.rightYAxisRenderer = self.subYAxisRenderer
    }

    /// 4本値表示用の十字線・マーカー・枠を追加する(チャートの上に重ねる)。
    /// 位置は Auto Layout ではなく updateCrosshair で frame を直接設定する
    private func addCrosshairParts() {
        for view in [self.crosshairView, self.ohlcInfoView, self.valueMarker, self.dateMarker, self.yAxisMarker] {
            self.addSubview(view)
        }
        // マーカーと4本値の枠は、4本値がオンになるまで隠しておく
        // (十字線は線を描かないことで隠れるので、isHidden にはしない)
        for view in [self.ohlcInfoView, self.valueMarker, self.dateMarker, self.yAxisMarker] {
            view.isHidden = true
        }
    }

    /// 十字線を動かすジェスチャーを、メイン・サブそれぞれのチャートに付ける。
    /// 4本値がオンのときだけ有効にする(applyDisplayOptions)
    ///   タップ       : 価格・日付のラベルの欄をタップすると、その位置に十字線を移動
    ///   1本指ドラッグ: 価格・日付のラベルの欄からなぞると、十字線を指の位置に追従させる
    /// 枠の内側は、4本値がオンでもチャートのスクロール(1本指)・拡大(ピンチ)に使う。
    /// ラベルの欄からなぞったときは、十字線だけを動かしてスクロールはしない(canBeginScroll)
    private func addCrosshairGestures() {
        for chart in [self.priceChartView, self.subChartView] {
            // ラベルの欄(十字線を動かす欄)からなぞり始めたときは、チャートをスクロールしない
            chart.canBeginScroll = { [weak self, weak chart] pointInChart in
                guard let self, let chart else { return true }
                return !self.isCrosshairDragStart(at: chart.convert(pointInChart, to: self))
            }

            let tap = UITapGestureRecognizer(target: self, action: #selector(self.chartTapped(_:)))
            tap.isEnabled = false  // 4本値オンのときだけ有効にする(applyDisplayOptions)
            let pan = UIPanGestureRecognizer(target: self, action: #selector(self.chartPanned(_:)))
            pan.maximumNumberOfTouches = 1
            // 4本値オンで、ラベルの欄からなぞり始めたときだけ開始する(gestureRecognizerShouldBegin)。
            // 下でチャートのスクロールがこのパンの失敗を待つようにするので、常に有効にしておく
            // (無効にすると、スクロールが待ったままになることがあるため)
            pan.delegate = self

            for recognizer in [tap, pan] {
                chart.addGestureRecognizer(recognizer)
                self.crosshairRecognizers.append(recognizer)
            }

            // チャートのスクロール(DGCharts のパン)は、十字線のドラッグが始まらないと分かってから始める。
            // ラベルの欄からなぞったときは十字線だけが動き、チャートは一緒にスクロールしない
            // (スクロールすると、動かしていない方の線の日付・価格まで変わってしまうため)
            for recognizer in chart.gestureRecognizers ?? [] {
                guard recognizer is UIPanGestureRecognizer else { continue }
                guard recognizer.delegate === chart else { continue }  // DGCharts のスクロール用のパンだけ
                recognizer.require(toFail: pan)
            }
        }
    }

    /// 外枠・区切り線・凡例を追加する(チャートの上に重ねる)
    private func addOverlays() {
        // 最高値・最安値の文字: 位置は表示範囲に合わせて frame を直接設定する(StockChartView+HighLowLabels)
        for label in [self.highPriceLabel, self.lowPriceLabel] {
            label.isUserInteractionEnabled = false
            label.isHidden = true
            self.addSubview(label)
        }

        for view in [self.frameView, self.dividerView, self.priceLegendLabel, self.subLegendLabel, self.noDataLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.isUserInteractionEnabled = false  // タッチは下のチャートに届ける
            self.addSubview(view)
        }
        self.frameView.backgroundColor = .clear  // 外枠は線(layer.border)だけを描く

        // データが0件のときのメッセージ。表示するのは空のデータを渡されたときだけ(render で切り替える)
        self.noDataLabel.numberOfLines = 0  // 幅が足りないときは折り返す
        self.noDataLabel.isHidden = true

        // 凡例は1行で表示する(UILabel の numberOfLines は既定の 1 のまま)。
        // 長い場合(一目均衡表の「一目均衡表 転換線 基準線 先行1 先行2 遅行」など)は、
        // 右端の制約(外枠の右端 - 8pt)に収まるよう、元の 60% の大きさまで文字を縮小する。
        // 60% まで縮めても収まらない場合は末尾が「…」で省略される
        for label in [self.priceLegendLabel, self.subLegendLabel] {
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.6
        }
    }

    /// スタイルやサブチャートの有無で変わらない制約を有効にする
    private func activateFixedConstraints() {
        NSLayoutConstraint.activate([
            // メインチャート: 上端と左右をこのViewに合わせる(下端/高さは applyLayoutConstraints で設定)
            self.priceChartView.topAnchor.constraint(equalTo: self.topAnchor),
            self.priceChartView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.priceChartView.trailingAnchor.constraint(equalTo: self.trailingAnchor),

            // サブチャート: 左右と下端をこのViewに合わせる(上端は applyLayoutConstraints で設定)
            self.subChartView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.subChartView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.subChartView.bottomAnchor.constraint(equalTo: self.bottomAnchor),

            // 外枠: 上端 = メインチャート描画領域の上端、左端 = このViewの左端
            //       (右端・下端は applyLayoutConstraints で設定)
            self.frameView.topAnchor.constraint(equalTo: self.priceChartView.topAnchor, constant: self.labelOverflowInset),
            self.frameView.leadingAnchor.constraint(equalTo: self.leadingAnchor),

            // 区切り線: メインチャート描画領域の下端に、外枠と同じ幅で配置する
            self.dividerView.centerYAnchor.constraint(equalTo: self.priceChartView.bottomAnchor, constant: -self.labelOverflowInset),
            self.dividerView.leadingAnchor.constraint(equalTo: self.frameView.leadingAnchor),
            self.dividerView.trailingAnchor.constraint(equalTo: self.frameView.trailingAnchor),

            // 凡例: 各チャート描画領域の左上(枠の内側)に表示する
            //
            //   外枠 ┌──────────────────────────┐
            //        │↕3                        │
            //        │←8→移動平均 短期… 長期…  ←8→│ ← priceLegendLabel
            //        │                          │
            //  区切り線├──────────────────────────┤
            //        │↕2                        │
            //        │←8→出来高 出来高移動平均  ←8→│ ← subLegendLabel
            //        └──────────────────────────┘
            //
            // ・上端: メインは外枠の上端から style.legendTopInset(3pt)下、
            //         サブは区切り線の下端から style.subLegendTopInset(2pt)下(applyLayoutConstraints で設定)
            // ・左端: 外枠の左端から style.legendLeadingInset(8pt)右(applyLayoutConstraints で設定)
            // ・右端: 外枠の右端から 8pt 内側を超えない(lessThanOrEqual)。
            //         短い凡例は文字の長さぶんの幅になり、長い凡例はここで幅が制限されて文字が縮小される
            // ・高さ: 指定しない(フォントの大きさから自動で決まる。legendFont 12pt で約 15pt)
            // 凡例はチャートの描画領域の上に重なっているだけなので、チャートの線と重ならないよう
            // Y軸の上側に、凡例の高さぶんの余白を取っている(updateAxisRanges)
            self.priceLegendLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.frameView.trailingAnchor, constant: -8),
            self.subLegendLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.frameView.trailingAnchor, constant: -8),

            // データが0件のときのメッセージ: メインチャートの凡例のすぐ下(4pt 下)、凡例と同じ左端に表示する
            self.noDataLabel.topAnchor.constraint(equalTo: self.priceLegendLabel.bottomAnchor, constant: 4),
            self.noDataLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.frameView.trailingAnchor, constant: -8),
        ])

        // 凡例の上端・左端(値は style で変えられるので、applyLayoutConstraints で反映する)
        let priceLegendTop = self.priceLegendLabel.topAnchor.constraint(equalTo: self.frameView.topAnchor)
        let subLegendTop = self.subLegendLabel.topAnchor.constraint(equalTo: self.dividerView.bottomAnchor)
        let legendLeadings = [self.priceLegendLabel, self.subLegendLabel, self.noDataLabel].map { label in
            label.leadingAnchor.constraint(equalTo: self.frameView.leadingAnchor)
        }
        NSLayoutConstraint.activate([priceLegendTop, subLegendTop] + legendLeadings)
        self.priceLegendTopConstraint = priceLegendTop
        self.subLegendTopConstraint = subLegendTop
        self.legendLeadingConstraints = legendLeadings
    }

    // MARK: - スタイルの反映

    /// スタイルに依存する見た目・制約・軸の設定を適用する
    func applyStyle() {
        self.applyLayoutConstraints()
        self.applyColors()
        for chart in [self.priceChartView, self.subChartView] {
            self.configureChartBasics(chart)
            self.configureRightAxis(chart.rightAxis)
            self.configureXAxis(chart.xAxis)
        }
        for renderer in [self.priceYAxisRenderer, self.subYAxisRenderer] {
            renderer.centersLabels = self.style.centersYAxisLabels
            renderer.keepsLabelsInside = self.style.keepsYAxisLabelsInside
        }

        // メインチャートのY軸: 区切り線付近のラベルがサブチャートの最上段ラベルと重ならないよう、
        // 下端付近(値幅の下から 6% 以内)のラベルは表示しない
        self.priceChartView.rightAxis.valueFormatter = ChartAxisValueFormatter(
            formatter: ChartNumberFormatter.make(fractionDigits: 0),
            hiddenBottomRatio: 0.06,
            hiddenAbove: nil)

        // サブチャートの Y軸(ラベル間隔・書式・基準線)はサブ指標ごとに変わるので、描画時に設定する(configureSubAxis)

        self.updateSubChartVisibility()
    }

    /// 外枠・区切り線・十字線・マーカーの色と線幅を設定する
    private func applyColors() {
        self.frameView.layer.borderColor = self.style.borderColor.cgColor
        self.frameView.layer.borderWidth = self.style.borderWidth
        self.dividerView.backgroundColor = self.style.dividerColor
        self.priceLegendLabel.backgroundColor = self.style.legendBackgroundColor
        self.subLegendLabel.backgroundColor = self.style.legendBackgroundColor
        self.crosshairView.lineColor = self.style.textColor
        self.valueMarker.fillColor = UIColor.darkGray.withAlphaComponent(0.85)
        self.dateMarker.fillColor = self.style.increasingColor
        self.yAxisMarker.fillColor = self.style.increasingColor
        // 画像が設定されていれば、形を塗る代わりに画像を描く
        self.dateMarker.backgroundImage = self.style.dateMarkerImage
        self.yAxisMarker.backgroundImage = self.style.yAxisMarkerImage

        // データが0件のときのメッセージ(凡例と同じ文字の大きさ・色)
        self.noDataLabel.text = self.style.noDataMessage
        self.noDataLabel.font = self.style.legendFont
        self.noDataLabel.textColor = self.style.textColor
    }

    /// チャート全体の基本設定(メイン/サブ共通)
    private func configureChartBasics(_ chart: CombinedChartView) {
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

        // 描画順: 棒 → ローソク足 → 線 → 点(パラボリック)。後に描いたものが上に重なる
        chart.drawOrder = [
            CombinedChartView.DrawOrder.bar.rawValue,
            CombinedChartView.DrawOrder.candle.rawValue,
            CombinedChartView.DrawOrder.line.rawValue,
            CombinedChartView.DrawOrder.scatter.rawValue,
        ]

        // 左のY軸は使わず、右のY軸のみ表示する
        chart.leftAxis.enabled = false
    }

    /// 右のY軸の設定(メイン/サブ共通)。ラベルは描画領域の外側(右側)、軸線は外枠と重なるので描かない
    ///
    ///   外枠 ─┐
    ///         │←10→70,000     ← Y軸ラベル(左揃え。style.centersYAxisLabels で中央揃え)
    ///         │
    ///         │←10→65,000
    ///   ──────┘
    ///         |←── rightAxisWidth(90) ──→|
    ///
    /// ・ラベル領域の幅は setViewPortOffsets の right(= style.rightAxisWidth)で確保している
    /// ・ラベルは外枠の右端(描画領域の右端)から xOffset(style.yAxisLabelOffset)離した位置に描かれる
    /// ・縦位置は各グリッド線の高さに、文字の中心を合わせて描かれる
    ///   (描画領域の上下端のラベルは半分はみ出すので、labelOverflowInset で余白を取っている)
    private func configureRightAxis(_ axis: YAxis) {
        axis.labelFont = self.style.yAxisFont
        axis.labelTextColor = self.style.textColor
        axis.gridColor = self.style.gridColor
        axis.drawAxisLineEnabled = false
        axis.labelPosition = .outsideChart
        axis.xOffset = self.style.yAxisLabelOffset
        axis.drawLimitLinesBehindDataEnabled = true  // 基準線(RSI の 20/80 など)は指標の線より下に描く
    }

    /// X軸の設定(メイン/サブ共通)。縦グリッド線と軸線は描かない。1本単位でラベルを配置する
    /// ・ラベルは描画領域の下(setViewPortOffsets の bottom = style.xAxisLabelHeight で確保した領域)に描かれる
    /// ・横位置は各足の中心に、文字の中心を合わせて描かれる
    /// ・どの足にラベルを置くかは LatestAlignedXAxisRenderer が決める(最新の足から左へ同じ間隔で置く)
    /// ・表示するのは一番下のチャートだけ(updateSubChartVisibility で drawLabelsEnabled を切り替える)
    private func configureXAxis(_ axis: XAxis) {
        axis.labelPosition = .bottom
        axis.drawGridLinesEnabled = false
        axis.drawAxisLineEnabled = false
        axis.labelFont = self.style.xAxisFont
        axis.labelTextColor = self.style.textColor
        axis.granularity = 1                       // ラベルは1本単位(足と足の間には置かない)
        axis.granularityEnabled = true
        axis.labelCount = self.style.xAxisLabelCount    // X軸ラベルの個数(約7個。足種によって変える)
        // ラベル同士の間隔(0 より大きいと、幅に入るだけ並べる。LatestAlignedXAxisRenderer)
        self.priceXAxisRenderer.labelSpacing = self.style.xAxisLabelSpacing
        self.subXAxisRenderer.labelSpacing = self.style.xAxisLabelSpacing
        // ラベルを置く時刻の分の倍数(1分足は 5分の倍数の時刻だけ。LatestAlignedXAxisRenderer)
        self.priceXAxisRenderer.minuteMultiple = self.style.xAxisLabelMinuteMultiple
        self.subXAxisRenderer.minuteMultiple = self.style.xAxisLabelMinuteMultiple
        // 両端のラベルをずらす DGCharts の機能は使わない(ずらすと足の位置と合わず、隣のラベルと重なることがある)。
        // はみ出すラベルは LatestAlignedXAxisRenderer が表示しないようにしている
        axis.avoidFirstLastClippingEnabled = false
    }

    // MARK: - スタイルに依存する制約

    /// スタイルに依存するレイアウト制約を作り直す
    private func applyLayoutConstraints() {
        let inset = self.labelOverflowInset

        // 既存の制約を無効化してから作り直す
        let oldConstraints = [
            self.subTopConstraint, self.frameTrailingConstraint, self.dividerHeightConstraint,
            self.priceHeightConstraint, self.frameBottomWithSubConstraint,
            self.priceBottomConstraint, self.frameBottomWithoutSubConstraint,
        ]
        for constraint in oldConstraints {
            constraint?.isActive = false
        }

        // サブチャートの上端: メインチャートの描画領域下端(= 区切り線)から、さらに inset 分上に重ねる。
        // こうするとサブチャートの描画領域上端(View上端 + inset)が区切り線とちょうど一致する
        self.subTopConstraint = self.subChartView.topAnchor.constraint(equalTo: self.priceChartView.bottomAnchor, constant: -inset * 2)

        // 外枠の右端 = Y軸ラベル領域の左端
        self.frameTrailingConstraint = self.frameView.trailingAnchor.constraint(
            equalTo: self.trailingAnchor, constant: -self.style.rightAxisWidth)

        // 凡例の位置(上端・左端)
        self.priceLegendTopConstraint?.constant = self.style.legendTopInset
        self.subLegendTopConstraint?.constant = self.style.subLegendTopInset
        for constraint in self.legendLeadingConstraints {
            constraint.constant = self.style.legendLeadingInset
        }

        // 区切り線の太さは外枠と同じ
        self.dividerHeightConstraint = self.dividerView.heightAnchor.constraint(equalToConstant: self.style.borderWidth)

        // [サブあり] メイン/サブの「描画領域」の高さ比を ratio : 1 にする。
        //   メイン描画領域の高さ P' = P - inset * 2           (上下に inset)
        //   サブ描画領域の高さ   V' = V - inset - xLabelHeight (上に inset、下にX軸ラベル)
        //   P' = ratio * V'  を P について解くと
        //   P = ratio * V + (inset * 2 - ratio * (inset + xLabelHeight))
        let ratio = self.style.priceHeightRatio
        self.priceHeightConstraint = self.priceChartView.heightAnchor.constraint(
            equalTo: self.subChartView.heightAnchor,
            multiplier: ratio,
            constant: inset * 2 - ratio * (inset + self.style.xAxisLabelHeight))

        // [サブあり] 外枠の下端 = サブチャートのX軸ラベル領域の上端
        self.frameBottomWithSubConstraint = self.frameView.bottomAnchor.constraint(
            equalTo: self.subChartView.bottomAnchor, constant: -self.style.xAxisLabelHeight)

        // [サブなし] メインチャートをこのViewの下端まで伸ばし、外枠の下端 = メインのX軸ラベル領域の上端
        self.priceBottomConstraint = self.priceChartView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        self.frameBottomWithoutSubConstraint = self.frameView.bottomAnchor.constraint(
            equalTo: self.priceChartView.bottomAnchor, constant: -self.style.xAxisLabelHeight)

        // サブあり/なしに関係なく使う制約だけ、ここで有効にする。
        // サブあり/なしで切り替わる制約は updateSubChartVisibility で有効にする
        self.subTopConstraint?.isActive = true
        self.frameTrailingConstraint?.isActive = true
        self.dividerHeightConstraint?.isActive = true
    }

    // MARK: - サブチャートの表示/非表示

    /// サブチャートの表示/非表示に合わせて、制約・描画領域・X軸ラベルの表示先を切り替える
    func updateSubChartVisibility() {
        let inset = self.labelOverflowInset
        let showsSub = self.hasSubChart

        // 制約の切り替え。先に無効化してから有効化する(同時に有効になると制約が衝突するため)
        let constraintsWithSub = [self.priceHeightConstraint, self.frameBottomWithSubConstraint]
        let constraintsWithoutSub = [self.priceBottomConstraint, self.frameBottomWithoutSubConstraint]
        var constraintsToDeactivate = constraintsWithSub
        var constraintsToActivate = constraintsWithoutSub
        if showsSub {
            constraintsToDeactivate = constraintsWithoutSub
            constraintsToActivate = constraintsWithSub
        }
        for constraint in constraintsToDeactivate {
            constraint?.isActive = false
        }
        for constraint in constraintsToActivate {
            constraint?.isActive = true
        }

        self.subChartView.isHidden = !showsSub
        self.subLegendLabel.isHidden = !showsSub
        self.dividerView.isHidden = !showsSub

        // X軸ラベル(日付)は一番下のチャートにだけ表示する
        self.priceChartView.xAxis.drawLabelsEnabled = !showsSub

        // 描画領域(viewport)の余白を固定値で指定する。
        // setViewPortOffsets を使うと、DGCharts がラベルの大きさから余白を自動計算しなくなり、
        // 描画領域が常に「Viewの境界 - 指定した余白」になる。
        // これにより外枠・区切り線の位置を Auto Layout の制約だけで描画領域に合わせられる。
        //
        // メインチャートの下側の余白: サブありなら区切り線までの inset、サブなしなら X軸ラベルの高さ
        let priceBottomOffset: CGFloat
        if showsSub {
            priceBottomOffset = inset
        } else {
            priceBottomOffset = self.style.xAxisLabelHeight
        }
        self.priceChartView.setViewPortOffsets(left: 0, top: inset, right: self.style.rightAxisWidth,
                                      bottom: priceBottomOffset)
        self.subChartView.setViewPortOffsets(left: 0, top: inset, right: self.style.rightAxisWidth,
                                    bottom: self.style.xAxisLabelHeight)
    }
}

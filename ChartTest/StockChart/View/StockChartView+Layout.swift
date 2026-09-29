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
//  【部品の重なり順】(下から)
//   priceChart / subChart(チャート本体)
//   → crosshairView など(十字線・4本値)
//   → frameView / dividerView(外枠・区切り線)
//   → priceLegendLabel / subLegendLabel(凡例)
//  チャートより上にある部品はタッチを受け取らない(isUserInteractionEnabled = false)ので、
//  スクロールやタップはすべて下のチャートに届く。
//

import UIKit
import DGCharts

extension StockChartView {

    // MARK: - 初期化時の設定

    /// 部品の追加と、スタイルに依存しない制約の設定を行う(初期化時に1回だけ呼ばれる)
    func setup() {
        addCharts()
        addCrosshairParts()
        addCrosshairGestures()
        addOverlays()
        activateFixedConstraints()
        applyStyle()
    }

    /// チャート本体(メイン・サブ)を追加する
    private func addCharts() {
        for chart in [priceChart, subChart] {
            chart.translatesAutoresizingMaskIntoConstraints = false
            chart.delegate = self   // スクロール/ズームを受け取り、もう一方のチャートに同期する(AxisRange)
            chart.noDataText = ""   // データなしのときの文言は表示しない
            addSubview(chart)
        }
        // 雲を描けるレンダラーに差し替える(drawOrder などの設定より前に行う)
        priceChart.renderer = priceRenderer
        // X軸ラベルを最新の足を基準に並べる描画処理に差し替える(LatestAlignedXAxisRenderer)
        priceChart.xAxisRenderer = priceXAxisRenderer
        subChart.xAxisRenderer = subXAxisRenderer
    }

    /// 4本値表示用の十字線・マーカー・枠を追加する(チャートの上に重ねる)。
    /// 位置は Auto Layout ではなく updateCrosshair で frame を直接設定する
    private func addCrosshairParts() {
        for view in [crosshairView, ohlcInfoView, valueMarker, dateMarker, yAxisMarker] {
            addSubview(view)
        }
        // マーカーと4本値の枠は、4本値がオンになるまで隠しておく
        // (十字線は線を描かないことで隠れるので、isHidden にはしない)
        for view in [ohlcInfoView, valueMarker, dateMarker, yAxisMarker] {
            view.isHidden = true
        }
    }

    /// 十字線を動かすジェスチャーを、メイン・サブそれぞれのチャートに付ける。
    /// 4本値がオンのときだけ有効にする(applyDisplayOptions)
    ///   タップ       : タップした位置に十字線を移動
    ///   1本指ドラッグ: 十字線を指の位置に追従させる
    /// 4本値オン中はチャートのスクロールを2本指に切り替えるので(updateChartPanTouches)、1本指のドラッグと競合しない
    private func addCrosshairGestures() {
        for chart in [priceChart, subChart] {
            let tap = UITapGestureRecognizer(target: self, action: #selector(chartTapped(_:)))
            let pan = UIPanGestureRecognizer(target: self, action: #selector(chartPanned(_:)))
            pan.maximumNumberOfTouches = 1
            pan.delegate = self  // 4本値オンのときだけ開始する(gestureRecognizerShouldBegin)

            for recognizer in [tap, pan] {
                recognizer.isEnabled = false
                chart.addGestureRecognizer(recognizer)
                crosshairRecognizers.append(recognizer)
            }
        }
    }

    /// 外枠・区切り線・凡例を追加する(チャートの上に重ねる)
    private func addOverlays() {
        for view in [frameView, dividerView, priceLegendLabel, subLegendLabel, noDataLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.isUserInteractionEnabled = false  // タッチは下のチャートに届ける
            addSubview(view)
        }
        frameView.backgroundColor = .clear  // 外枠は線(layer.border)だけを描く

        // データが0件のときのメッセージ。表示するのは空のデータを渡されたときだけ(render で切り替える)
        noDataLabel.numberOfLines = 0  // 幅が足りないときは折り返す
        noDataLabel.isHidden = true

        // 凡例は1行で表示する(UILabel の numberOfLines は既定の 1 のまま)。
        // 長い場合(一目均衡表の「一目均衡表 転換線 基準線 先行1 先行2 遅行」など)は、
        // 右端の制約(外枠の右端 - 8pt)に収まるよう、元の 60% の大きさまで文字を縮小する。
        // 60% まで縮めても収まらない場合は末尾が「…」で省略される
        for label in [priceLegendLabel, subLegendLabel] {
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.6
        }
    }

    /// スタイルやサブチャートの有無で変わらない制約を有効にする
    private func activateFixedConstraints() {
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
            //
            //   外枠 ┌──────────────────────────┐
            //        │↕6                        │
            //        │←8→移動平均 短期… 長期…  ←8→│ ← priceLegendLabel
            //        │                          │
            //  区切り線├──────────────────────────┤
            //        │↕4                        │
            //        │←8→出来高 出来高移動平均  ←8→│ ← subLegendLabel
            //        └──────────────────────────┘
            //
            // ・上端: メインは外枠の上端から 6pt 下、サブは区切り線の下端から 4pt 下
            // ・左端: 外枠の左端から 8pt 右
            // ・右端: 外枠の右端から 8pt 内側を超えない(lessThanOrEqual)。
            //         短い凡例は文字の長さぶんの幅になり、長い凡例はここで幅が制限されて文字が縮小される
            // ・高さ: 指定しない(フォントの大きさから自動で決まる。legendFont 12pt で約 15pt)
            // 凡例はチャートの描画領域の上に重なっているだけなので、チャートの線と重ならないよう
            // Y軸の上側に余白を取っている(updateAxisRanges)
            priceLegendLabel.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 6),
            priceLegendLabel.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 8),
            priceLegendLabel.trailingAnchor.constraint(lessThanOrEqualTo: frameView.trailingAnchor, constant: -8),
            subLegendLabel.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 4),
            subLegendLabel.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 8),
            subLegendLabel.trailingAnchor.constraint(lessThanOrEqualTo: frameView.trailingAnchor, constant: -8),

            // データが0件のときのメッセージ: メインチャートの凡例のすぐ下(4pt 下)、凡例と同じ左端に表示する
            noDataLabel.topAnchor.constraint(equalTo: priceLegendLabel.bottomAnchor, constant: 4),
            noDataLabel.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 8),
            noDataLabel.trailingAnchor.constraint(lessThanOrEqualTo: frameView.trailingAnchor, constant: -8),
        ])
    }

    // MARK: - スタイルの反映

    /// スタイルに依存する見た目・制約・軸の設定を適用する
    func applyStyle() {
        applyLayoutConstraints()
        applyColors()
        for chart in [priceChart, subChart] {
            configureChartBasics(chart)
            configureRightAxis(chart.rightAxis)
            configureXAxis(chart.xAxis)
        }

        // メインチャートのY軸: 区切り線付近のラベルがサブチャートの最上段ラベルと重ならないよう、
        // 下端付近(値幅の下から 6% 以内)のラベルは表示しない
        priceChart.rightAxis.valueFormatter = ChartAxisValueFormatter(
            formatter: ChartNumberFormatter.make(fractionDigits: 0),
            hiddenBottomRatio: 0.06,
            hiddenAbove: nil)

        // サブチャートの Y軸(ラベル間隔・書式・基準線)はサブ指標ごとに変わるので、描画時に設定する(configureSubAxis)

        updateSubChartVisibility()
    }

    /// 外枠・区切り線・十字線・マーカーの色と線幅を設定する
    private func applyColors() {
        frameView.layer.borderColor = style.borderColor.cgColor
        frameView.layer.borderWidth = style.borderWidth
        dividerView.backgroundColor = style.dividerColor
        crosshairView.lineColor = style.textColor
        valueMarker.fillColor = UIColor.darkGray.withAlphaComponent(0.85)
        dateMarker.fillColor = style.increasingColor
        yAxisMarker.fillColor = style.increasingColor
        markerDateFormatter.dateFormat = style.dateFormat

        // データが0件のときのメッセージ(凡例と同じ文字の大きさ・色)
        noDataLabel.text = style.noDataMessage
        noDataLabel.font = style.legendFont
        noDataLabel.textColor = style.textColor
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
    ///         │←10→70,000     ← Y軸ラベル(左揃え)
    ///         │
    ///         │←10→65,000
    ///   ──────┘
    ///         |←── rightAxisWidth(90) ──→|
    ///
    /// ・ラベル領域の幅は setViewPortOffsets の right(= style.rightAxisWidth)で確保している
    /// ・ラベルは外枠の右端(描画領域の右端)から xOffset(10pt)離した位置に左揃えで描かれる
    /// ・縦位置は各グリッド線の高さに、文字の中心を合わせて描かれる
    ///   (描画領域の上下端のラベルは半分はみ出すので、labelOverflowInset で余白を取っている)
    private func configureRightAxis(_ axis: YAxis) {
        axis.labelFont = style.axisFont
        axis.labelTextColor = style.textColor
        axis.gridColor = style.gridColor
        axis.drawAxisLineEnabled = false
        axis.labelPosition = .outsideChart
        axis.xOffset = 10
        axis.drawLimitLinesBehindDataEnabled = true  // 基準線(RSI の 30/70 など)は指標の線より下に描く
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
        axis.labelFont = style.axisFont
        axis.labelTextColor = style.textColor
        axis.granularity = 1                       // ラベルは1本単位(足と足の間には置かない)
        axis.granularityEnabled = true
        axis.labelCount = style.xAxisLabelCount    // X軸ラベルの個数(約7個。足種によって変える)
        // 両端のラベルをずらす DGCharts の機能は使わない(ずらすと足の位置と合わず、隣のラベルと重なることがある)。
        // はみ出すラベルは LatestAlignedXAxisRenderer が表示しないようにしている
        axis.avoidFirstLastClippingEnabled = false
    }

    // MARK: - スタイルに依存する制約

    /// スタイルに依存するレイアウト制約を作り直す
    private func applyLayoutConstraints() {
        let inset = labelOverflowInset

        // 既存の制約を無効化してから作り直す
        let oldConstraints = [
            subTopConstraint, frameTrailingConstraint, dividerHeightConstraint,
            priceHeightConstraint, frameBottomWithSubConstraint,
            priceBottomConstraint, frameBottomWithoutSubConstraint,
        ]
        for constraint in oldConstraints {
            constraint?.isActive = false
        }

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

        // サブあり/なしに関係なく使う制約だけ、ここで有効にする。
        // サブあり/なしで切り替わる制約は updateSubChartVisibility で有効にする
        subTopConstraint?.isActive = true
        frameTrailingConstraint?.isActive = true
        dividerHeightConstraint?.isActive = true
    }

    // MARK: - サブチャートの表示/非表示

    /// サブチャートの表示/非表示に合わせて、制約・描画領域・X軸ラベルの表示先を切り替える
    func updateSubChartVisibility() {
        let inset = labelOverflowInset
        let showsSub = hasSubChart

        // 制約の切り替え。先に無効化してから有効化する(同時に有効になると制約が衝突するため)
        let constraintsWithSub = [priceHeightConstraint, frameBottomWithSubConstraint]
        let constraintsWithoutSub = [priceBottomConstraint, frameBottomWithoutSubConstraint]
        if showsSub {
            constraintsWithoutSub.forEach { $0?.isActive = false }
            constraintsWithSub.forEach { $0?.isActive = true }
        } else {
            constraintsWithSub.forEach { $0?.isActive = false }
            constraintsWithoutSub.forEach { $0?.isActive = true }
        }

        subChart.isHidden = !showsSub
        subLegendLabel.isHidden = !showsSub
        dividerView.isHidden = !showsSub

        // X軸ラベル(日付)は一番下のチャートにだけ表示する
        priceChart.xAxis.drawLabelsEnabled = !showsSub

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
            priceBottomOffset = style.xAxisLabelHeight
        }
        priceChart.setViewPortOffsets(left: 0, top: inset, right: style.rightAxisWidth,
                                      bottom: priceBottomOffset)
        subChart.setViewPortOffsets(left: 0, top: inset, right: style.rightAxisWidth,
                                    bottom: style.xAxisLabelHeight)
    }
}

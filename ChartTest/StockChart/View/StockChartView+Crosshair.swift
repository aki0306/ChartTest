//
//  StockChartView+Crosshair.swift
//  ChartTest
//
//  【View】StockChartView の表示オプションの反映と、十字線・4本値の表示。
//
//  4本値がオンのときの画面:
//
//   ┌──────────────────────────────┐
//   │移動平均 短期… 長期…            │
//   │┌─────────┐          ┊         │
//   ││ 4本値の枠 │          ┊         │ ← ohlcInfoView(十字線と反対側に置く)
//   │└─────────┘          ┊         │
//   │   ＜60,660.98＞┈┈┈┈┈┈┈┼┈┈┈┈┈┈┈┈┈│◀ ← 横線・値のマーカー(valueMarker)・Y軸側の矢印(yAxisMarker)
//   │                      ┊         │
//   └──────────────────────────────┘
//                         /\           ← 日付のマーカー(dateMarker)
//                        |8/19|
//
//  ・横線は指の高さ、縦線は指に一番近い足の中心に引く
//  ・4本値オン中は、1本指のドラッグで十字線を動かし、2本指でチャートをスクロールする
//

import UIKit
import DGCharts

extension StockChartView {

    // MARK: - 表示オプションの反映

    /// 表示オプション(Y軸固定・4本値)を反映する。displayOptions が変わると呼ばれる
    func applyDisplayOptions() {
        // 4本値: オンのときだけ十字線のジェスチャーを受け付け、チャートのスクロールを2本指に切り替える
        for recognizer in crosshairRecognizers {
            recognizer.isEnabled = displayOptions.showsOHLC
        }
        updateChartPanTouches()

        // オン/オフが切り替わったら、十字線は次回表示時に最新の足の位置から始める
        crosshairPoint = nil

        // Y軸固定: Y軸範囲を計算し直す(固定の場合は全期間、固定しない場合は表示範囲で計算される)
        if priceChart.data != nil {
            if priceChart.viewPortHandler.contentWidth > 0 {
                updateAxisRangesForVisibleCandles()
            } else {
                // レイアウト前は表示範囲が取れないので、初期表示範囲で計算する
                updateAxisRangesForInitialCandles()
            }
        }
        updateCrosshair()
    }

    /// DGCharts のスクロール(パン)に必要な指の本数を切り替える。
    /// 4本値オン中は1本指のドラッグを十字線の移動に使うため、スクロールは2本指にする
    private func updateChartPanTouches() {
        let touches: Int
        if displayOptions.showsOHLC {
            touches = 2
        } else {
            touches = 1
        }

        for chart in [priceChart, subChart] {
            for recognizer in chart.gestureRecognizers ?? [] {
                // パン(ドラッグ)以外は対象外
                guard let pan = recognizer as? UIPanGestureRecognizer else { continue }
                // 自分で追加した十字線用のパンは対象外(DGCharts が持つスクロール用のパンだけ変更する)
                guard !crosshairRecognizers.contains(pan) else { continue }
                pan.minimumNumberOfTouches = touches
            }
        }
    }

    // MARK: - ジェスチャー

    /// タップ: タップした位置に十字線を移動する
    @objc func chartTapped(_ recognizer: UITapGestureRecognizer) {
        guard let chart = recognizer.view else { return }
        let pointInChart = recognizer.location(in: chart)
        moveCrosshair(to: chart.convert(pointInChart, to: self))
    }

    /// 1本指ドラッグ: 十字線を指の位置に追従させる
    @objc func chartPanned(_ recognizer: UIPanGestureRecognizer) {
        guard let chart = recognizer.view else { return }
        switch recognizer.state {
        case .began, .changed:
            let pointInChart = recognizer.location(in: chart)
            moveCrosshair(to: chart.convert(pointInChart, to: self))
        default:
            break
        }
    }

    /// 十字線を指定した位置(このViewの座標)に移動する。外枠の外は外枠の端に寄せる
    private func moveCrosshair(to point: CGPoint) {
        guard displayOptions.showsOHLC else { return }
        let frameRect = frameView.frame
        let x = min(max(point.x, frameRect.minX), frameRect.maxX)  // 外枠の左端〜右端に収める
        let y = min(max(point.y, frameRect.minY), frameRect.maxY)  // 外枠の上端〜下端に収める
        crosshairPoint = CGPoint(x: x, y: y)
        updateCrosshair()
    }

    // MARK: - 十字線の配置

    /// 十字線・マーカー・4本値の枠を配置する(指の移動・スクロール・ズーム・サイズ変更のたびに呼ぶ)。
    /// 縦線は十字線の X に一番近い足に合わせ、4本値はその足の値を表示する
    func updateCrosshair() {
        let frameRect = frameView.frame  // 外枠(メイン + サブの描画領域全体)
        guard canShowCrosshair(in: frameRect) else {
            hideCrosshair()
            return
        }
        crosshairView.frame = bounds

        // 位置が未設定(4本値をオンにした直後・データ変更後)なら、表示範囲内の最新の足の終値の位置に置く
        if crosshairPoint == nil {
            crosshairPoint = latestCandlePoint()
        }
        guard let point = crosshairPoint else { return }

        // 指の位置に一番近い足
        let index = nearestCandleIndex(toX: point.x)
        let candle = candles[index]

        // 縦線の X(足の中心)。足が外枠の外(表示範囲外)なら nil で、縦線は描かない
        let lineX = candleCenterX(at: index, within: frameRect)
        // 横線の Y(指の高さ)
        let lineY = point.y

        crosshairView.show(x: lineX, verticalRange: frameRect.minY...frameRect.maxY,
                           y: lineY, horizontalRange: frameRect.minX...frameRect.maxX)
        showValueMarker(atY: lineY, frameRect: frameRect)
        showYAxisMarker(atY: lineY)
        showDateMarker(atX: lineX, date: candle.date, frameRect: frameRect)

        // 4本値の枠の左右は、縦線の位置(縦線がなければ指の位置)で決める
        let crosshairX = lineX ?? point.x
        showOHLCInfo(for: candle, crosshairX: crosshairX, frameRect: frameRect)
    }

    /// 十字線を表示できる状態か
    private func canShowCrosshair(in frameRect: CGRect) -> Bool {
        // 4本値がオフ
        guard displayOptions.showsOHLC else { return false }
        // データがない
        guard !candles.isEmpty else { return false }
        // レイアウト前で、描画領域の大きさが決まっていない
        guard priceChart.viewPortHandler.contentWidth > 0 else { return false }
        guard frameRect.width > 0 else { return false }
        return true
    }

    /// 十字線・マーカー・4本値の枠をすべて隠す
    private func hideCrosshair() {
        crosshairView.hide()
        for view in [ohlcInfoView, valueMarker, dateMarker, yAxisMarker] {
            view.isHidden = true
        }
    }

    /// 表示範囲内の最新の足の、終値の位置(このViewの座標)
    private func latestCandlePoint() -> CGPoint {
        // 画面の右端に見えている足(データの範囲に収める)
        let rightEdgeIndex = Int(priceChart.highestVisibleX.rounded(.down))
        let latestIndex = min(max(rightEdgeIndex, 0), candles.count - 1)

        // チャートの値(X = 何本目か、Y = 終値)→ チャート上の座標 → このViewの座標
        let transformer = priceChart.getTransformer(forAxis: .right)
        let pointInChart = transformer.pixelForValues(x: Double(latestIndex), y: candles[latestIndex].close)
        return priceChart.convert(pointInChart, to: self)
    }

    /// 指定した X(このViewの座標)に一番近い足のインデックス(データの範囲外は端の足に寄せる)
    private func nearestCandleIndex(toX x: CGFloat) -> Int {
        // このViewの座標 → チャート上の座標 → X軸の値(何本目か。小数)
        let pointInChart = convert(CGPoint(x: x, y: 0), to: priceChart)
        let xValue = priceChart.valueForTouchPoint(point: pointInChart, axis: .right).x
        let index = Int(xValue.rounded())
        return min(max(index, 0), candles.count - 1)
    }

    /// 指定した足の中心の X(このViewの座標)。外枠の外にある場合は nil
    private func candleCenterX(at index: Int, within frameRect: CGRect) -> CGFloat? {
        // X軸の値(何本目か)→ チャート上の座標 → このViewの座標
        let transformer = priceChart.getTransformer(forAxis: .right)
        let pointInChart = transformer.pixelForValues(x: Double(index), y: 0)
        let x = priceChart.convert(pointInChart, to: self).x

        guard (frameRect.minX...frameRect.maxX).contains(x) else { return nil }
        return x
    }

    // MARK: - マーカー

    /// 横線の値のマーカー: 外枠の左端寄りのグレーの六角形。
    /// 横線がメイン/サブのどちらにあるかで、その軸の値を表示する
    private func showValueMarker(atY y: CGFloat, frameRect: CGRect) {
        guard let text = crosshairValueText(atY: y) else {
            valueMarker.isHidden = true
            return
        }
        // 外枠の左端から 60pt 右の位置を中心にする(凡例の左端・外枠の線と重ならないように)
        let anchor = CGPoint(x: frameRect.minX + 60, y: y)
        valueMarker.show(text, anchor: anchor, within: frameRect)
    }

    /// Y軸側の赤い矢印: このViewの右端に、横線の高さで左向きに置く
    private func showYAxisMarker(atY y: CGFloat) {
        let anchor = CGPoint(x: bounds.maxX, y: y)
        yAxisMarker.show(nil, anchor: anchor, within: bounds, alignRight: true)
    }

    /// X軸の赤い矢印: 外枠のすぐ下(X軸ラベルの位置)に、縦線を指す上向きの矢印と日付を置く。
    /// 縦線がない(x = nil)場合は隠す
    private func showDateMarker(atX x: CGFloat?, date: Date, frameRect: CGRect) {
        guard let x else {
            dateMarker.isHidden = true
            return
        }
        // 収める範囲: 横方向は外枠ではなくView全体(右端の足でも矢印が縦線からずれないように)。
        // 矢印の分だけX軸ラベル領域より少し背が高いので、縦方向は 8pt はみ出してもよいことにする
        let labelArea = CGRect(x: bounds.minX, y: frameRect.maxY,
                               width: bounds.width, height: style.xAxisLabelHeight + 8)
        let anchor = CGPoint(x: x, y: frameRect.maxY)  // 矢印の先端を外枠の下端に合わせる
        dateMarker.show(markerDateFormatter.string(from: date), anchor: anchor, within: labelArea)
    }

    /// 横線の高さ(このViewの座標)にあたる軸の値を、表示用の文字列にする。
    /// メインチャート上なら価格(小数2桁)、サブチャート上ならサブ指標の値(指標ごとの桁数・単位)。
    /// どちらの描画領域にもない場合は nil
    private func crosshairValueText(atY y: CGFloat) -> String? {
        // メインチャートの描画領域にあるか
        let priceArea = priceChart.convert(priceChart.viewPortHandler.contentRect, to: self)
        if (priceArea.minY...priceArea.maxY).contains(y) {
            let value = axisValue(of: priceChart, atY: y, area: priceArea)
            let formatter = ChartNumberFormatter.make(fractionDigits: 2, minimumFractionDigits: 2)
            return formatter.string(from: NSNumber(value: value))
        }

        // サブチャートの描画領域にあるか
        if let sub = subContent {
            let subArea = subChart.convert(subChart.viewPortHandler.contentRect, to: self)
            if (subArea.minY...subArea.maxY).contains(y) {
                let value = axisValue(of: subChart, atY: y, area: subArea)
                let formatter = ChartNumberFormatter.make(fractionDigits: sub.fractionDigits, suffix: sub.suffix)
                return formatter.string(from: NSNumber(value: value))
            }
        }
        return nil
    }

    /// 指定した高さ(このViewの座標)にあたる、チャートのY軸の値
    private func axisValue(of chart: CombinedChartView, atY y: CGFloat, area: CGRect) -> Double {
        let pointInChart = convert(CGPoint(x: area.midX, y: y), to: chart)
        return chart.valueForTouchPoint(point: pointInChart, axis: .right).y
    }

    // MARK: - 4本値の枠

    /// 4本値の枠: 外枠の上部(凡例の下)に置く。十字線と重ならないよう、縦線が右半分なら左側、左半分なら右側に置く
    ///
    ///   縦線が右半分のとき               縦線が左半分のとき
    ///   ┌────────────────────┐         ┌────────────────────┐
    ///   │移動平均 短期… 長期… │         │移動平均 短期… 長期… │ ← 凡例(外枠の上端 + 6pt)
    ///   │┌────┐        │   │         │   │        ┌────┐│
    ///   ││4本値│        │   │         │   │        │4本値││ ← 外枠の上端 + 28pt
    ///   │└────┘        │   │         │   │        └────┘│
    ///   │──────────────┼───│         │───┼──────────────│
    ///   │              │   │         │   │              │
    ///   └────────────────────┘         └────────────────────┘
    ///    ←8→                                                 ←8→
    ///
    /// ・大きさは中身(4本値のテキスト)から自動で決まる(systemLayoutSizeFitting)
    /// ・上端 28pt は「凡例の上端 6pt + 凡例の高さ 約15pt + 隙間 約7pt」で、凡例と重ならない位置
    /// ・左右は外枠の端から 8pt(凡例の左端と揃う)
    private func showOHLCInfo(for candle: StockCandle, crosshairX: CGFloat, frameRect: CGRect) {
        ohlcInfoView.update(with: candle)
        ohlcInfoView.isHidden = false

        let size = ohlcInfoView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let margin: CGFloat = 8
        let top = frameRect.minY + 28

        let left: CGFloat
        if crosshairX > frameRect.midX {
            // 縦線が右半分 → 枠は左側
            left = frameRect.minX + margin
        } else {
            // 縦線が左半分 → 枠は右側
            left = frameRect.maxX - margin - size.width
        }
        ohlcInfoView.frame = CGRect(x: left, y: top, width: size.width, height: size.height)
    }
}

// MARK: - UIGestureRecognizerDelegate(十字線のドラッグ)

extension StockChartView: UIGestureRecognizerDelegate {

    /// 十字線を動かすドラッグは、4本値オンのときだけ開始する
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 自分で追加した十字線用のパンか
        if gestureRecognizer is UIPanGestureRecognizer, crosshairRecognizers.contains(gestureRecognizer) {
            return displayOptions.showsOHLC
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

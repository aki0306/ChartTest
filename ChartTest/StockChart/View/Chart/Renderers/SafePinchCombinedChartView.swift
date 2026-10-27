//
//  SafePinchCombinedChartView.swift
//  ChartTest
//
//  【View】ピンチ開始時のクラッシュを防ぎ、スクロールを始めてよい位置を選べる CombinedChartView。
//
//  DGCharts(5.1.0)の BarLineChartViewBase.pinchGestureRecognized は、pinchZoomEnabled が false のとき、
//  ピンチ開始(.began)の時点で 2 本目の指の位置を locationOfTouch(1, inView:) で取得する。
//  指が 2 本そろっていない状態でピンチが開始されると、次の例外でクラッシュする。
//    -[UIPinchGestureRecognizer locationOfTouch:inView:]: index (1) beyond bounds (0).
//  ・2 本の指がほぼ同時に離れたとき(指が 1 本しか残っていない)
//  ・トラックパッドのピンチ(iPad のトラックパッドなど。指で触れていないのでタッチの数が 0)
//  そこで、チャートの pinchZoomEnabled を true にして、2 本目の指の位置を読まないようにしている
//  (StockChartView+Layout.swift の configureChartBasics。scaleYEnabled が false なので、拡大・縮小は横方向だけのまま)。
//
//  Xcode 27 の Device Hub では、iPhone のシミュレータにトラックパッドのピンチも 2 本指のタッチも届かないので、
//  ピンチは実機で確かめる。
//

import UIKit
import DGCharts

final class SafePinchCombinedChartView: CombinedChartView {

    /// スクロール(DGCharts のパン)を、指を置いた位置(このチャートの座標)から始めてよいか。
    /// nil なら常に始める。4本値の十字線を動かす欄(価格・日付のラベルの欄)では始めないようにするのに使う
    var canBeginScroll: ((CGPoint) -> Bool)?

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // スクロール: 始めてよい位置かを確かめる。
        // このメソッドは、このチャートに付いているすべてのジェスチャーで呼ばれる(十字線のドラッグも含む)ので、
        // DGCharts のスクロール(delegate がこのチャートのパン)だけを対象にする
        if self.isScrollGesture(gestureRecognizer) {
            if let canBeginScroll {
                let location = gestureRecognizer.location(in: self)
                if !canBeginScroll(location) {
                    return false
                }
            }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    /// DGCharts のスクロール用のパンか(delegate がこのチャート。十字線のドラッグなど、外から付けたパンは含まない)
    private func isScrollGesture(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer is UIPanGestureRecognizer else {
            return false
        }
        return gestureRecognizer.delegate === self
    }
}

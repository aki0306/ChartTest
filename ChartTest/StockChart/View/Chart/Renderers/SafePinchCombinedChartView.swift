//
//  SafePinchCombinedChartView.swift
//  ChartTest
//
//  【View】ピンチ開始時のクラッシュを防いだ CombinedChartView。
//
//  DGCharts(5.1.0)の BarLineChartViewBase.pinchGestureRecognized は、pinchZoomEnabled が false のとき、
//  ピンチ開始(.began)の時点で 2 本目の指の位置を locationOfTouch(1, inView:) で取得する。
//  2 本の指がほぼ同時に離れたときなど、指が 1 本しか残っていない状態でピンチが開始されることがあり、
//  そのときは次の例外でクラッシュする。
//    -[UIPinchGestureRecognizer locationOfTouch:inView:]: index (1) beyond bounds (0).
//  そこで、指が 2 本そろっていないときはピンチを開始させないようにしている。
//

import UIKit
import DGCharts

final class SafePinchCombinedChartView: CombinedChartView {

    /// スクロール(DGCharts のパン)を、指を置いた位置(このチャートの座標)から始めてよいか。
    /// nil なら常に始める。4本値の十字線を動かす欄(価格・日付のラベルの欄)では始めないようにするのに使う
    var canBeginScroll: ((CGPoint) -> Bool)?

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // ピンチは指が 2 本そろっているときだけ開始する
        if gestureRecognizer is UIPinchGestureRecognizer {
            if gestureRecognizer.numberOfTouches < 2 {
                return false
            }
        }
        // スクロール: 始めてよい位置かを確かめる。
        // このメソッドは、このチャートに付いているすべてのジェスチャーで呼ばれる(十字線のドラッグも含む)ので、
        // DGCharts のスクロール(delegate がこのチャートのパン)だけを対象にする
        if self.isScrollGesture(gestureRecognizer), let canBeginScroll {
            if !canBeginScroll(gestureRecognizer.location(in: self)) {
                return false
            }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    /// DGCharts のスクロール用のパンか(delegate がこのチャート。十字線のドラッグなど、外から付けたパンは含まない)
    private func isScrollGesture(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer is UIPanGestureRecognizer else { return false }
        return gestureRecognizer.delegate === self
    }
}

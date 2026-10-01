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

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // ピンチは指が 2 本そろっているときだけ開始する
        if gestureRecognizer is UIPinchGestureRecognizer {
            if gestureRecognizer.numberOfTouches < 2 {
                return false
            }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

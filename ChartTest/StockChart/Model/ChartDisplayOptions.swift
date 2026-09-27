//
//  ChartDisplayOptions.swift
//  ChartTest
//
//  【Model】設定画面「表示 > オプション」で切り替える表示オプション。
//

import Foundation

struct ChartDisplayOptions: Equatable {
    /// Y軸(メイン)固定。
    /// true: スクロール/ズームしてもメインチャートのY軸範囲を変えない(データ全期間の範囲で固定)
    /// false: 表示中の範囲に合わせてY軸を自動調整する
    var isMainYAxisFixed = false
    /// Y軸(サブ)固定。サブチャートについて isMainYAxisFixed と同じ
    var isSubYAxisFixed = false
    /// 4本値。true の場合、チャートをタップすると十字線と、その日の日付・始値・高値・安値・終値を表示する
    var showsOHLC = false
}

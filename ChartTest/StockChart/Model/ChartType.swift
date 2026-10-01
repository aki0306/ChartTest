//
//  ChartType.swift
//  ChartTest
//
//  【Model】チャートの種類(ローソク足・VWAP・新値足・折線チャート)の定義。
//
//  | 種類       | メインチャートに描くもの                    | テクニカル(指標)・サブチャート |
//  |------------|---------------------------------------------|--------------------------------|
//  | ローソク足 | ローソク足 + メイン指標                     | 使える                         |
//  | VWAP：線   | VWAP の折れ線(ローソク足は描かない)       | 使えない(サブチャートもなし)  |
//  | VWAP：点   | VWAP の点(ローソク足は描かない)           | 使えない(サブチャートもなし)  |
//  | 新値足     | 3本新値の新値足(X軸は時間ではなく新値の本数) | 使えない(サブチャートもなし)  |
//  | 折線チャート | 終値の折れ線(ローソク足は描かない)       | 使えない(サブチャートもなし)  |
//
//  Objective-C からも使えるよう @objc enum(Int)にしている(Objective-C での名前は ChartTypeNewPrice など)。
//

import Foundation

@objc enum ChartType: Int, CaseIterable {
    /// ローソク足(テクニカル指標を重ねられる)
    case candlestick
    /// VWAP(出来高加重平均価格)を折れ線で描く
    case vwapLine
    /// VWAP(出来高加重平均価格)を点で描く
    case vwapDots
    /// 新値足(3本新値)
    case newPrice
    /// 折線チャート(終値を線で結ぶ)
    case lineChart

    /// メニュー・凡例に表示する名称
    var title: String {
        switch self {
        case .candlestick: return "ローソク足"
        case .vwapLine: return "VWAP：線"
        case .vwapDots: return "VWAP：点"
        case .newPrice: return "新値足"
        case .lineChart: return "折線チャート"
        }
    }

    /// テクニカル指標(メイン指標・サブチャート)と、その設定を使えるか
    var usesTechnicalIndicators: Bool {
        switch self {
        case .candlestick:
            return true
        case .vwapLine, .vwapDots, .newPrice, .lineChart:
            return false
        }
    }
}

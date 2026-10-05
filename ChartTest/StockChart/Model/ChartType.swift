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
//  | 折線チャート | 終値の折れ線(ローソク足は描かない)       | 国内: 使えない / 海外: 移動平均線を重ねられる(サブなし) |
//
//  Objective-C からも使えるよう @objc enum(Int)にしている(Objective-C での名前は ChartTypeNewPrice など)。
//  指数の種類によって、選べる種類が変わる(choices(for:)。海外指数は ローソク足・折線チャート だけ)。
//  チャートの種類によって、選べる足種が変わる(periods(in:)。VWAP は 日中足 だけ、新値足・折線チャートは 1分足 を選べない)。
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

    /// テクニカル指標(メイン指標・サブチャート)と、その設定を使えるか。
    /// 折線チャートは、海外指数のときだけ使える(終値の線に移動平均線を重ねる。国内指数では「なし」だけ)
    /// - Parameter market: 指数の種類
    func usesTechnicalIndicators(in market: IndexMarket) -> Bool {
        switch self {
        case .candlestick:
            return true
        case .lineChart:
            switch market {
            case .domestic:
                return false
            case .overseasRealtime, .overseasDaily:
                return true
            }
        case .vwapLine, .vwapDots, .newPrice:
            return false
        }
    }
}

// MARK: - チャートの種類ごとに選べる足種

extension ChartType {
    /// このチャートの種類で選べる足種(指数の種類で使う足種のうち、この種類に合うもの。並びは左から順)
    ///
    ///   | 種類                 | 国内指数                        | 海外指数              |
    ///   |----------------------|---------------------------------|-----------------------|
    ///   | VWAP：線 / VWAP：点  | 日中足                          | (選べない種類)      |
    ///   | 新値足・折線チャート | 日中足・日足・週足・月足        | 日足・週足・月足      |
    ///   | ローソク足           | 1分足・日中足・日足・週足・月足 | 日足・週足・月足      |
    ///
    /// ・VWAP は、その日の寄り付きからの平均価格なので、1日の中の動きを見る日中足だけで使う
    /// ・新値足・折線チャートは 1分足 では使わない(新値足は細かい値動きを除いて流れの転換を見るためのもの)
    /// - Parameter market: 指数の種類
    func periods(in market: IndexMarket) -> [ChartPeriod] {
        switch self {
        case .vwapLine, .vwapDots:
            return market.periods.filter { period in period == .intraday }
        case .newPrice, .lineChart:
            return market.periods.filter { period in period != .oneMinute }
        case .candlestick:
            return market.periods
        }
    }
}

// MARK: - 指数の種類ごとに選べるチャートの種類

extension ChartType {
    /// 指定した指数の種類で選べるチャートの種類(メニューに並べる順)
    static func choices(for market: IndexMarket) -> [ChartType] {
        switch market {
        case .domestic:
            return allCases
        case .overseasRealtime, .overseasDaily:
            return [.candlestick, .lineChart]
        }
    }

    /// 指数の種類ごとの既定のチャートの種類(既存アプリ XxxChartUtil と同じ。国内はローソク足、海外は折線チャート)
    static func defaultType(for market: IndexMarket) -> ChartType {
        switch market {
        case .domestic:
            return .candlestick
        case .overseasRealtime, .overseasDaily:
            return .lineChart
        }
    }
}

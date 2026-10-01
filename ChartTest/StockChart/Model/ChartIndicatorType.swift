//
//  ChartIndicatorType.swift
//  ChartTest
//
//  【Model】テクニカル指標の種類(メインチャート/サブチャート)の定義。
//  Objective-C からも使えるよう @objc enum(Int)にしている。
//
//  指数の種類によって、選べる指標が変わる(choices(for:))。
//    国内指数: すべて
//    海外指数: メインは 移動平均線・なし、サブは なし だけ(サブチャートは表示しない)
//

import Foundation

// MARK: - 指標の種類

/// メインチャート(ローソク足に重ねて表示)の指標
@objc enum MainChartIndicator: Int, CaseIterable {
    /// 移動平均線(短期・長期の2本)
    case movingAverage
    /// 多重移動平均線(期間の異なる3本以上)
    case multipleMovingAverage
    /// ボリンジャーバンド(中心線 ± nσ)
    case bollingerBands
    /// 一目均衡表(転換線・基準線・先行スパン1/2 + 雲・遅行スパン)
    case ichimoku
    /// パラボリック(SAR)
    case parabolic
    /// なし(ローソク足のみ)
    case candleOnly

    /// メニュー等に表示する名称
    var title: String {
        switch self {
        case .movingAverage: return "移動平均線"
        case .multipleMovingAverage: return "多重移動平均線"
        case .bollingerBands: return "ボリンジャーバンド"
        case .ichimoku: return "一目均衡表"
        case .parabolic: return "パラボリック"
        case .candleOnly: return "なし"
        }
    }
}

/// サブチャート(メインの下に別枠で表示)の指標
@objc enum SubChartIndicator: Int, CaseIterable {
    /// 出来高(+ 出来高移動平均)
    case volume
    /// 移動平均乖離率
    case movingAverageDeviation
    /// RSI
    case rsi
    /// サイコロジカルライン
    case psychological
    /// ストキャスティクス
    case stochastics
    /// MACD
    case macd
    /// DMI(+DI / -DI / ADX)
    case dmi
    /// なし(サブチャート自体を非表示にし、メインチャートを全高で表示)
    case hidden

    /// メニュー等に表示する名称
    var title: String {
        switch self {
        case .volume: return "出来高"
        case .movingAverageDeviation: return "移動平均乖離率"
        case .rsi: return "RSI"
        case .psychological: return "サイコロジカル"
        case .stochastics: return "ストキャス"
        case .macd: return "MACD"
        case .dmi: return "DMI"
        case .hidden: return "なし"
        }
    }
}

// MARK: - 指数の種類ごとに選べる指標

extension MainChartIndicator {
    /// 指定した指数の種類で選べるメインチャートの指標(メニューに並べる順)
    static func choices(for market: IndexMarket) -> [MainChartIndicator] {
        switch market {
        case .domestic:
            return allCases
        case .overseas:
            return [.movingAverage, .candleOnly]
        }
    }
}

extension SubChartIndicator {
    /// 指定した指数の種類で選べるサブチャートの指標(メニューに並べる順)。海外指数は「なし」だけ
    static func choices(for market: IndexMarket) -> [SubChartIndicator] {
        switch market {
        case .domestic:
            return allCases
        case .overseas:
            return [.hidden]
        }
    }
}

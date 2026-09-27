//
//  ChartDisplayOptions.swift
//  ChartTest
//
//  【Model】設定画面「表示 > オプション」で切り替える表示オプション。
//
//  指数の種類によって、使えるオプションが変わる(ChartDisplayOption.options(for:))。
//
//  | オプション       | 国内指数 | 海外指数 |
//  |------------------|----------|----------|
//  | Y軸(メイン)固定  | ○       | ○       |
//  | Y軸(サブ)固定    | ○       | ―       |
//  | 4本値            | ○       | ○       |
//

import Foundation

struct ChartDisplayOptions: Equatable {
    /// Y軸(メイン)固定。
    /// true: スクロール/ズームしてもメインチャートのY軸範囲を変えない(データ全期間の範囲で固定)
    /// false: 表示中の範囲に合わせてY軸を自動調整する
    var isMainYAxisFixed = false
    /// Y軸(サブ)固定。サブチャートについて isMainYAxisFixed と同じ
    var isSubYAxisFixed = false
    /// 4本値。true の場合、十字線と、その日の日付・始値・高値・安値・終値を表示する
    /// (十字線は指でなぞると動く。タップでは、右の価格ラベルの欄で横線だけ、下の日付ラベルの欄で縦線だけが動く)
    var showsOHLC = false
}

extension ChartDisplayOptions {

    /// チャートの種類・指数の種類に合わせて、実際に効く表示オプションを返す。
    /// 設定画面の値(self)は変えずに残すので、ローソク足・国内指数に戻すと、元の設定のまま表示される
    ///
    ///   | オプション        | オフにする場合                                         |
    ///   |-------------------|--------------------------------------------------------|
    ///   | 4本値             | ローソク足以外(4本値はローソク足の値を見るためのもの) |
    ///   | Y軸(サブ)固定     | 海外指数(サブチャートがない)                         |
    ///
    /// - Parameters:
    ///   - chartType: チャートの種類
    ///   - market: 指数の種類
    func effective(for chartType: ChartType, market: IndexMarket) -> ChartDisplayOptions {
        var options = self

        // 4本値はローソク足のときだけ
        if chartType != .candlestick {
            options.showsOHLC = false
        }

        // この指数で使えないオプションは、オンでも効かないようにする
        let availableOptions = ChartDisplayOption.options(for: market)
        for option in ChartDisplayOption.allCases {
            if availableOptions.contains(option) {
                continue
            }
            options[keyPath: option.keyPath] = false
        }
        return options
    }
}

/// 表示オプションの1項目(設定画面のトグル1つ分)
enum ChartDisplayOption: CaseIterable {
    /// Y軸(メイン)固定
    case mainYAxisFixed
    /// Y軸(サブ)固定
    case subYAxisFixed
    /// 4本値
    case ohlc

    /// 設定画面に表示する名称
    var title: String {
        switch self {
        case .mainYAxisFixed:
            return "Y軸(メイン)固定"
        case .subYAxisFixed:
            return "Y軸(サブ)固定"
        case .ohlc:
            return "4本値"
        }
    }

    /// 対応する ChartDisplayOptions のプロパティ
    var keyPath: WritableKeyPath<ChartDisplayOptions, Bool> {
        switch self {
        case .mainYAxisFixed:
            return \.isMainYAxisFixed
        case .subYAxisFixed:
            return \.isSubYAxisFixed
        case .ohlc:
            return \.showsOHLC
        }
    }

    /// 指定した指数の種類で使えるオプション(設定画面に並べる順)。
    /// 海外指数はサブチャートがないので、Y軸(サブ)固定を除く(Y軸(メイン)固定・4本値)
    static func options(for market: IndexMarket) -> [ChartDisplayOption] {
        switch market {
        case .japanStock, .japanIndex:
            return [.mainYAxisFixed, .subYAxisFixed, .ohlc]
        case .overseasRealtime, .overseasDaily:
            return [.mainYAxisFixed, .ohlc]
        }
    }
}

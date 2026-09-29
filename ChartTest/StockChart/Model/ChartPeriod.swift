//
//  ChartPeriod.swift
//  ChartTest
//
//  【Model】チャートの足種(1分足・日中足・日足・週足・月足)と、足種ごとの表示の違い。
//
//  足種によって変わるもの:
//
//  | 足種   | 移動平均(短期/長期) | X軸ラベル   | 初期表示       | 出来高の凡例    |
//  |--------|---------------------|-------------|----------------|-----------------|
//  | 1分足  | 5 / 25              | 09:15       | 全件           | 出来高          |
//  | 日中足 | 5 / 25              | 09:15       | 全件           | 出来高          |
//  | 日足   | 5 / 25              | 7/16        | 直近 55 本     | 出来高          |
//  | 週足   | 13 / 26             | 2025/9      | 直近 55 本     | 出来高(平均)    |
//  | 月足   | 5 / 25              | 2023/9      | 全件           | 出来高(平均)    |
//
//  指数の種類(国内/海外)によって、選べる足種が変わる(IndexMarket)。
//

import Foundation

/// チャートの足種(ローソク足1本が表す期間)。
/// Objective-C からも使えるよう @objc enum(Int)にしている(Objective-C での名前は ChartPeriodDaily など)
@objc enum ChartPeriod: Int, CaseIterable {
    /// 1分足(1本 = 1分)
    case oneMinute
    /// 日中足(1本 = 5分。当日の動き)
    case intraday
    /// 日足(1本 = 1日)
    case daily
    /// 週足(1本 = 1週間)
    case weekly
    /// 月足(1本 = 1か月)
    case monthly

    /// タブに表示する名称(2文字の足種は、3文字の足種と幅を揃えるため間に空白を入れる)
    var title: String {
        switch self {
        case .oneMinute: return "1分足"
        case .intraday: return "日中足"
        case .daily: return "日 足"
        case .weekly: return "週 足"
        case .monthly: return "月 足"
        }
    }

    /// 指標の計算パラメータ(移動平均の期間・出来高の凡例名)
    var indicatorParameters: IndicatorParameters {
        var parameters = IndicatorParameters()
        switch self {
        case .weekly:
            // 週足は 13週(約3か月)・26週(約半年)
            parameters.shortMAPeriod = 13
            parameters.longMAPeriod = 26
        case .oneMinute, .intraday, .daily, .monthly:
            parameters.shortMAPeriod = 5
            parameters.longMAPeriod = 25
        }

        switch self {
        case .weekly, .monthly:
            // 週足・月足の出来高は、期間中の1日あたりの平均
            parameters.volumeLegendLabel = "出来高(平均)"
        case .oneMinute, .intraday, .daily:
            parameters.volumeLegendLabel = "出来高"
        }
        return parameters
    }

    /// X軸ラベルの日付の書式
    var dateFormat: String {
        switch self {
        case .oneMinute, .intraday: return "HH:mm"
        case .daily: return "M/d"
        case .weekly, .monthly: return "yyyy/M"
        }
    }

    /// X軸ラベルのおおよその個数。
    /// 週足・月足は「2025/10」のように文字が長く、7個だと隣のラベルと重なるので減らす。
    /// (左端のラベルは画面からはみ出さないよう右にずらして描かれるため、間隔が狭いと2番目のラベルと重なる)
    var xAxisLabelCount: Int {
        switch self {
        case .oneMinute, .intraday, .daily:
            return 7
        case .weekly:
            return 3
        case .monthly:
            return 4
        }
    }

    /// 初期表示する本数(nil = 全件)
    var visibleCount: Int? {
        switch self {
        case .oneMinute, .intraday, .monthly:
            // 1日分・全期間をまとめて見られるよう、全件を表示する
            return nil
        case .daily, .weekly:
            return 55
        }
    }
}

/// 指数の種類。種類によって選べる足種が変わる。
/// Objective-C からも使えるよう @objc enum(Int)にしている(Objective-C での名前は IndexMarketDomestic など)
@objc enum IndexMarket: Int {
    /// 国内指数(日経平均など)
    case domestic
    /// 海外指数(NYダウなど)
    case overseas

    /// タブに並べる足種(左から順に)
    var periods: [ChartPeriod] {
        switch self {
        case .domestic:
            return [.oneMinute, .intraday, .daily, .weekly, .monthly]
        case .overseas:
            return [.daily, .weekly, .monthly]
        }
    }
}

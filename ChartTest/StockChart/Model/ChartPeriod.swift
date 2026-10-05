//
//  ChartPeriod.swift
//  ChartTest
//
//  【Model】チャートの足種(1分足・日中足・日足・週足・月足)と、足種ごとの表示の違い。
//
//  足種によって変わるもの:
//
//  | 足種   | 移動平均(短期/長期) | X軸ラベル   | 初期表示       | 縮小の限界 | 出来高の凡例    |
//  |--------|---------------------|-------------|----------------|------------|-----------------|
//  | 1分足  | 5 / 25              | 09:15       | 全件           | なし       | 出来高          |
//  | 日中足 | 5 / 25              | 09:15       | 全件           | なし       | 出来高          |
//  | 日足   | 5 / 25              | 7/16        | 直近 50 本     | 250 本     | 出来高          |
//  | 週足   | 13 / 26             | 25/9/5      | 直近 50 本     | 250 本     | 出来高(平均)    |
//  | 月足   | 5 / 25              | 2023/9      | 直近 50 本     | 250 本     | 出来高(平均)    |
//
//  (初期表示・縮小の限界・日付の書式は既存アプリ XxxChartView と同じ)
//
//  指標の期間は既存アプリ(初期値の設定ファイル)と同じ。日足の値が IndicatorParameters の初期値で、
//  週足・月足は次の値だけ違う(indicatorParameters)。
//
//  | 足種 | 移動平均 | 多重移動平均(最短〜最長) | ボリンジャー | 出来高移動平均 | 移動平均乖離率 |
//  |------|----------|--------------------------|--------------|----------------|----------------|
//  | 日足 | 5 / 25   | 5〜75                    | 5            | 5              | 5 / 25         |
//  | 週足 | 13 / 26  | 13〜52                   | 13           | 13             | 13 / 26        |
//  | 月足 | 5 / 25   | 5〜75                    | 25           | 5              | 5 / 25         |
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

    /// 指標の計算パラメータ(期間・出来高の凡例名)。
    /// 既存アプリ(初期値の設定ファイル)の足種ごとの値。日足の値は IndicatorParameters の初期値なので、違うものだけ上書きする
    var indicatorParameters: IndicatorParameters {
        var parameters = IndicatorParameters()
        switch self {
        case .weekly:
            // 週足は 13週(約3か月)・26週(約半年)など
            parameters.shortMAPeriod = 13
            parameters.longMAPeriod = 26
            parameters.multipleMAShortestPeriod = 13
            parameters.multipleMALongestPeriod = 52
            parameters.bollingerPeriod = 13
            parameters.volumeMAPeriod = 13
            parameters.deviationShortPeriod = 13
            parameters.deviationLongPeriod = 26
        case .monthly:
            parameters.bollingerPeriod = 25
        case .oneMinute, .intraday, .daily:
            break
        }

        // 凡例の「5日移動平均」などの単位(既存アプリと同じ)
        switch self {
        case .oneMinute, .intraday:
            parameters.periodUnit = "分"
        case .daily:
            parameters.periodUnit = "日"
        case .weekly:
            parameters.periodUnit = "週"
        case .monthly:
            parameters.periodUnit = "月"
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

    /// X軸ラベルを置く時刻の分の倍数(nil = 時刻にそろえない)。
    /// 1分足・日中足は、5分の倍数のきりのいい間隔(5・10・15・30・60分 …)で、毎時 15分を基準にした時刻に置く
    /// (例: 全体を表示すると 9:15・9:45 … 15:15。LatestAlignedXAxisRenderer)
    var xAxisLabelMinuteMultiple: Int? {
        switch self {
        case .oneMinute, .intraday:
            return 5
        case .daily, .weekly, .monthly:
            return nil
        }
    }

    /// X軸ラベルの日付の書式
    var dateFormat: String {
        switch self {
        case .oneMinute, .intraday: return "HH:mm"
        case .daily: return "M/d"
        case .weekly: return "yy/M/d"
        case .monthly: return "yyyy/M"
        }
    }

    /// 4本値(十字線)の枠に表示する日付の書式(既存アプリ XxxChartView と同じ)
    var ohlcDateFormat: String {
        switch self {
        case .oneMinute, .intraday: return "HH:mm"
        case .daily, .weekly: return "yyyy/MM/dd"
        case .monthly: return "yyyy/MM"
        }
    }

    /// X軸ラベルのおおよその個数。ラベルは最新の足から左へ同じ間隔で置かれる(LatestAlignedXAxisRenderer)。
    /// 週足・月足は「2025/10」のように文字が長いので、少なめにする。
    /// (月足は 48 本を5個で割ると 12 本 = 1年おきになり、「2023/9 2024/9 2025/9 2026/9」のように並ぶ)
    var xAxisLabelCount: Int {
        switch self {
        case .oneMinute, .intraday, .daily:
            return 7
        case .weekly, .monthly:
            return 5
        }
    }

    /// 初期表示する本数(nil = 全件)。既存アプリと同じく、日足・週足・月足は直近 50 本
    var visibleCount: Int? {
        switch self {
        case .oneMinute, .intraday:
            // 1日分をまとめて見られるよう、全件を表示する
            return nil
        case .daily, .weekly, .monthly:
            return 50
        }
    }

    /// 縮小の限界(ピンチで縮小したときに、最大で表示する本数。nil = 全件まで縮小できる)。
    /// 既存アプリと同じく、日足・週足・月足は 250 本まで
    var maximumVisibleCount: Int? {
        switch self {
        case .oneMinute, .intraday:
            return nil
        case .daily, .weekly, .monthly:
            return 250
        }
    }
}

/// 指数の種類。種類によって選べる足種・描き方が変わる。
/// 既存アプリの銘柄コードの種類(XxxCodeType)と同じく、海外株価指数はリアルタイム(R)と日次(D)の2つに分けている。
/// R と D の描き方は同じ(既存アプリでも、違うのは呼ぶ API だけ)
///
///   | IndexMarket       | Objective-C                  | 既存アプリ(XxxCodeType)                |
///   |-------------------|------------------------------|-----------------------------------------------|
///   | .domestic         | IndexMarketDomestic          | JapanStock(日本株)・JapanIndex(日本株価指数) |
///   | .overseasRealtime | IndexMarketOverseasRealtime  | OverseasRealtime(海外株価指数・リアルタイム)  |
///   | .overseasDaily    | IndexMarketOverseasDaily     | OverseasDaily(海外株価指数・日次)          |
///
/// Objective-C からも使えるよう @objc enum(Int)にしている
@objc enum IndexMarket: Int {
    /// 国内指数(日経平均など)
    case domestic
    /// 海外株価指数・リアルタイム(既存アプリの XxxCodeTypeOverseasRealtime)
    case overseasRealtime
    /// 海外株価指数・日次(既存アプリの XxxCodeTypeOverseasDaily)
    case overseasDaily

    /// タブに並べる足種(左から順に)
    var periods: [ChartPeriod] {
        switch self {
        case .domestic:
            return [.oneMinute, .intraday, .daily, .weekly, .monthly]
        case .overseasRealtime, .overseasDaily:
            return [.daily, .weekly, .monthly]
        }
    }
}

//
//  ChartStateStore.swift
//  ChartTest
//
//  【Model】横画面のチャート(StockChartViewController)で選んだ状態を、国内・海外ごとに覚えておく場所。
//  ・国内(日本株・日本株価指数)と海外(リアルタイム・日次)で別々に覚える
//  ・アプリを起動している間だけ覚える(画面を閉じて開き直しても残る。端末には保存しない)
//
//  覚えるもの: チャートの種類・メイン/サブの指標・足種・指標の設定値(足種ごと)・表示オプション(Y軸固定・4本値)
//
//    国内で MACD・1分足を表示 → 海外指数に切り替え → 国内に戻す → MACD・1分足に戻る
//

import Foundation

/// 横画面のチャートで選んだ状態
struct ChartViewState {
    /// チャートの種類
    var chartType: ChartType
    /// メインチャートの指標
    var mainIndicator: MainChartIndicator
    /// サブチャートの指標
    var subIndicator: SubChartIndicator
    /// 足種
    var period: ChartPeriod
    /// 指標の設定値(足種ごと)
    var parametersByPeriod: [ChartPeriod: IndicatorParameters]
    /// 表示オプション(Y軸固定・4本値)
    var displayOptions: ChartDisplayOptions

    /// まだ何も選んでいないときの状態
    ///   ・チャートの種類: 国内はローソク足、海外は折線チャート
    ///   ・指標: 移動平均線 + 出来高(海外はサブチャートなし)
    ///   ・足種: 日足
    static func initial(for market: IndexMarket) -> ChartViewState {
        var parametersByPeriod: [ChartPeriod: IndicatorParameters] = [:]
        for period in ChartPeriod.allCases {
            parametersByPeriod[period] = period.indicatorParameters
        }
        var subIndicator = SubChartIndicator.volume
        if !market.isDomestic {
            subIndicator = .hidden
        }
        return ChartViewState(chartType: ChartType.defaultType(for: market),
                              mainIndicator: .movingAverage,
                              subIndicator: subIndicator,
                              period: .daily,
                              parametersByPeriod: parametersByPeriod,
                              displayOptions: ChartDisplayOptions())
    }
}

/// 横画面のチャートで選んだ状態を、国内・海外ごとに覚えておく(アプリの起動中だけ)
@MainActor
enum ChartStateStore {

    /// 国内(日本株・日本株価指数)の状態。まだ覚えていなければ nil
    private static var domesticState: ChartViewState?
    /// 海外(リアルタイム・日次)の状態。まだ覚えていなければ nil
    private static var overseasState: ChartViewState?

    /// 指定した種類(国内/海外)で覚えている状態。まだ覚えていなければ初期の状態
    static func state(for market: IndexMarket) -> ChartViewState {
        if market.isDomestic {
            if let domesticState {
                return domesticState
            }
        } else {
            if let overseasState {
                return overseasState
            }
        }
        return ChartViewState.initial(for: market)
    }

    /// 指定した種類(国内/海外)の状態として覚える
    static func save(_ state: ChartViewState, for market: IndexMarket) {
        if market.isDomestic {
            self.domesticState = state
        } else {
            self.overseasState = state
        }
    }

    /// 覚えている状態をすべて消す(ログアウトしたときなど、最初の状態に戻したい場合に使う)
    static func reset() {
        self.domesticState = nil
        self.overseasState = nil
    }
}

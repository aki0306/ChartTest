//
//  StockChartView+Xxx.swift
//  ChartTest
//
//  【View】既存アプリの enum(XxxChartEnum.h)で、StockChartView の設定をするためのプロパティ。
//
//  既存アプリの Objective-C の enum を変換せずにそのまま設定できる。中では StockChartView のプロパティ
//  (period・market・chartType・mainIndicator・subIndicator)に置き換えて使う。
//
//    | プロパティ    | 既存アプリの enum   | StockChartView のプロパティ        |
//    |---------------|---------------------|------------------------------------|
//    | qCodeType     | XxxCodeType   | market(日本株・日本株価指数 → 国内 / 海外株価指数 R・D → 海外リアルタイム・日次) |
//    | chartData     | XxxChartData        | period(1分足〜月足)               |
//    | chartCategory | XxxChartCategory    | chartType(ローソク足・VWAP・新値足・折線) |
//    | mainChart     | XxxMainChart        | mainIndicator(None → ローソク足のみ) |
//    | subChart      | XxxSubChart         | subIndicator(None → サブチャートなし) |
//
//  使い方(Objective-C):
//      #import "XxxChartEnum.h"      // 「既存アプリのモジュール名-Swift.h」より前に読み込む
//      #import "MyApp-Swift.h"
//
//      self.chartView.qCodeType = XxxCodeTypeJapanIndex;
//      self.chartView.chartData = XxxChartDataWeek;
//      self.chartView.chartCategory = XxxChartCategoryCandle;
//      self.chartView.mainChart = XxxMainChartBollingerBands;
//      self.chartView.subChart = XxxSubChartMACD;
//      [self.chartView setCandles:candles];   // 上の設定で描く
//
//  ・Swift から XxxChartEnum.h を読むため、ブリッジングヘッダ(ChartTest-Bridging-Header.h)で読み込んでいる
//  ・Xxx の enum を使わないアプリに持っていく場合は、このファイルを削除すればよい(ほかのファイルは Xxx に依存しない)
//  ・Xxx の enum は C の enum なので、Swift の switch では網羅を確認できない(default を付けている)
//

import Foundation

extension StockChartView {

    /// 銘柄コードの種類。設定すると、指数の種類(market)も切り替わる。
    /// 変更しても描き直さないので、データを渡す前に設定する(海外株価指数は終値だけを読むため、ChartResponseLoader で渡す前にも必要)
    @objc var qCodeType: XxxCodeType {
        get {
            return XxxCodeType(rawValue: self.xxxCodeTypeRawValue)
        }
        set {
            self.xxxCodeTypeRawValue = newValue.rawValue
            self.market = Self.market(for: newValue)
        }
    }

    /// 足種(1分足〜月足)。設定すると、足種に合った見た目に切り替わる(period)
    @objc var chartData: XxxChartData {
        get {
            switch self.period {
            case .oneMinute: return XxxChartDataMin
            case .intraday: return XxxChartDataMidDay
            case .daily: return XxxChartDataDay
            case .weekly: return XxxChartDataWeek
            case .monthly: return XxxChartDataMonth
            }
        }
        set {
            self.period = Self.period(for: newValue)
        }
    }

    /// チャートの種類(ローソク足・VWAP・新値足・折線チャート)。変更しても描き直さないので、データを渡す前に設定する(chartType)
    @objc var chartCategory: XxxChartCategory {
        get {
            switch self.chartType {
            case .candlestick: return XxxChartCategoryCandle
            case .vwapLine: return XxxChartCategoryVWAPLine
            case .vwapDots: return XxxChartCategoryVWAPDot
            case .newPrice: return XxxChartCategoryRecordPrice
            case .lineChart: return XxxChartCategoryLine
            }
        }
        set {
            self.chartType = Self.chartType(for: newValue)
        }
    }

    /// メインチャートの指標。変更しても描き直さないので、データを渡す前に設定する(mainIndicator)
    @objc var mainChart: XxxMainChart {
        get {
            switch self.mainIndicator {
            case .movingAverage: return XxxMainChartMovingAverage
            case .multipleMovingAverage: return XxxMainChartMultipleMovingAverage
            case .bollingerBands: return XxxMainChartBollingerBands
            case .ichimoku: return XxxMainChartIChiMoKu
            case .parabolic: return XxxMainChartParabolic
            case .candleOnly: return XxxMainChartNone
            }
        }
        set {
            self.mainIndicator = Self.mainIndicator(for: newValue)
        }
    }

    /// サブチャートの指標。変更しても描き直さないので、データを渡す前に設定する(subIndicator)
    @objc var subChart: XxxSubChart {
        get {
            switch self.subIndicator {
            case .volume: return XxxSubChartTurnover
            case .movingAverageDeviation: return XxxSubChartDifferenceFromMovingAverage
            case .rsi: return XxxSubChartRSI
            case .psychological: return XxxSubChartPsychological
            case .stochastics: return XxxSubChartStochastics
            case .macd: return XxxSubChartMACD
            case .dmi: return XxxSubChartDMI
            case .hidden: return XxxSubChartNone
            }
        }
        set {
            self.subIndicator = Self.subIndicator(for: newValue)
        }
    }

    // MARK: - Xxx の enum → StockChartView の enum

    /// 銘柄コードの種類 → 指数の種類(日本株・日本株価指数は国内、海外株価指数はリアルタイム/日次)
    private static func market(for qCodeType: XxxCodeType) -> IndexMarket {
        switch qCodeType {
        case XxxCodeTypeOverseasRealtime:
            return .overseasRealtime
        case XxxCodeTypeOverseasDaily:
            return .overseasDaily
        default:
            // XxxCodeTypeJapanStock・XxxCodeTypeJapanIndex
            return .domestic
        }
    }

    /// XxxChartData → 足種
    private static func period(for chartData: XxxChartData) -> ChartPeriod {
        switch chartData {
        case XxxChartDataMin: return .oneMinute
        case XxxChartDataMidDay: return .intraday
        case XxxChartDataWeek: return .weekly
        case XxxChartDataMonth: return .monthly
        default:
            // XxxChartDataDay
            return .daily
        }
    }

    /// XxxChartCategory → チャートの種類
    private static func chartType(for category: XxxChartCategory) -> ChartType {
        switch category {
        case XxxChartCategoryVWAPLine: return .vwapLine
        case XxxChartCategoryVWAPDot: return .vwapDots
        case XxxChartCategoryRecordPrice: return .newPrice
        case XxxChartCategoryLine: return .lineChart
        default:
            // XxxChartCategoryCandle
            return .candlestick
        }
    }

    /// XxxMainChart → メインチャートの指標
    private static func mainIndicator(for mainChart: XxxMainChart) -> MainChartIndicator {
        switch mainChart {
        case XxxMainChartMultipleMovingAverage: return .multipleMovingAverage
        case XxxMainChartBollingerBands: return .bollingerBands
        case XxxMainChartIChiMoKu: return .ichimoku
        case XxxMainChartParabolic: return .parabolic
        case XxxMainChartNone: return .candleOnly
        default:
            // XxxMainChartMovingAverage
            return .movingAverage
        }
    }

    /// XxxSubChart → サブチャートの指標
    private static func subIndicator(for subChart: XxxSubChart) -> SubChartIndicator {
        switch subChart {
        case XxxSubChartDifferenceFromMovingAverage: return .movingAverageDeviation
        case XxxSubChartRSI: return .rsi
        case XxxSubChartPsychological: return .psychological
        case XxxSubChartStochastics: return .stochastics
        case XxxSubChartMACD: return .macd
        case XxxSubChartDMI: return .dmi
        case XxxSubChartNone: return .hidden
        default:
            // XxxSubChartTurnover
            return .volume
        }
    }
}

//
//  StockChartView+DGChartEnum.swift
//  ChartTest
//
//  【View】DGChartEnum.swift の enum で、StockChartView の設定をするためのプロパティ(Objective-C からも使える)。
//
//  DGChartEnum の enum を変換せずにそのまま設定できる。中では StockChartView のプロパティ
//  (period・market・chartType・mainIndicator・subIndicator)に置き換えて使う。
//
//    | プロパティ    | StockChartView のプロパティ        |
//    |---------------|------------------------------------|
//    | mainChart     | mainIndicator(None → ローソク足のみ) |
//    | subChart      | subIndicator(None → サブチャートなし) |
//    | chartCategory | chartType(ローソク足・VWAP・新値足・折線) |
//    | chartData     | period(1分足〜月足)               |
//    | qCodeType     | market(4つが1対1で対応。日本株 → .japanStock、日本株価指数 → .japanIndex、海外 R・D → .overseasRealtime・.overseasDaily) |
//
//  ・この enum を使わないアプリに持っていく場合は、このファイルと DGChartEnum.swift を削除すればよい
//    (ほかのファイルはこの enum に依存しない)
//  ・qCode(銘柄コード)は、ほかのプロパティと違って置き換え先がないので、このファイルの中で値を持つ
//    (extension にはプロパティの値を置けないため、Objective-C の関連オブジェクト(objc_setAssociatedObject)で持つ)
//

import Foundation

extension StockChartView {

    // 並び順は DGChartEnum.swift と同じ(メインチャート → サブチャート → チャート種別 → チャートデータ → 銘柄コード種別)

    /// メインチャートの指標。変更しても描き直さないので、データを渡す前に設定する(mainIndicator)
    @objc var mainChart: DGMainChart {
        get {
            switch self.mainIndicator {
            case .movingAverage:
                // 移動平均線
                return .movingAverage
            case .multipleMovingAverage:
                // 多重移動平均線
                return .multipleMovingAverage
            case .bollingerBands:
                // ボリンジャーバンド
                return .bollingerBands
            case .ichimoku:
                // 一目均衡表
                return .ichimoku
            case .parabolic:
                // パラボリック
                return .parabolic
            case .candleOnly:
                // テクニカル指標設定なし(ローソク足のみ)
                return .none
            }
        }
        set {
            self.mainIndicator = Self.mainIndicator(for: newValue)
        }
    }

    /// サブチャートの指標。変更しても描き直さないので、データを渡す前に設定する(subIndicator)
    @objc var subChart: DGSubChart {
        get {
            switch self.subIndicator {
            case .volume:
                // 出来高(+出来高移動平均)
                return .turnover
            case .movingAverageDeviation:
                // 移動平均乖離率
                return .differenceFromMovingAverage
            case .rsi:
                // ＲＳＩ
                return .rsi
            case .psychological:
                // サイコロジカル
                return .psychological
            case .stochastics:
                // ストキャス
                return .stochastics
            case .macd:
                // MACD
                return .macd
            case .dmi:
                // DMI
                return .dmi
            case .hidden:
                // テクニカル指標設定なし(サブチャートなし)
                return .none
            }
        }
        set {
            self.subIndicator = Self.subIndicator(for: newValue)
        }
    }

    /// チャートの種類(ローソク足・VWAP・新値足・折線チャート)。変更しても描き直さないので、データを渡す前に設定する(chartType)
    @objc var chartCategory: DGChartCategory {
        get {
            switch self.chartType {
            case .candlestick:
                // ローソク足
                return .candle
            case .vwapLine:
                // VWAP：線
                return .vwapLine
            case .vwapDots:
                // VWAP：点
                return .vwapDot
            case .newPrice:
                // 新値足
                return .recordPrice
            case .lineChart:
                // 折線チャート
                return .line
            }
        }
        set {
            self.chartType = Self.chartType(for: newValue)
        }
    }

    /// 足種(1分足〜月足)。設定すると、足種に合った見た目に切り替わる(period)
    @objc var chartData: DGChartData {
        get {
            switch self.period {
            case .oneMinute:
                // 1分足
                return .min
            case .intraday:
                // 日中足
                return .midDay
            case .daily:
                // 日足
                return .day
            case .weekly:
                // 週足
                return .week
            case .monthly:
                // 月足
                return .month
            }
        }
        set {
            self.period = Self.period(for: newValue)
        }
    }

    /// 銘柄コードの種類。設定すると、銘柄・指数の種類(market)も切り替わる(4つが1対1で対応する)。
    /// 変更しても描き直さないので、データを渡す前に設定する(海外株価指数はレスポンスの読み方が変わるため、ChartResponseLoader で渡す前にも必要)
    @objc var qCodeType: DGCodeType {
        get {
            switch self.market {
            case .japanStock:
                // 日本株
                return .japanStock
            case .japanIndex:
                // 日本株価指数
                return .japanIndex
            case .overseasRealtime:
                // 海外株価指数(リアルタイム)
                return .overseasRealtime
            case .overseasDaily:
                // 海外株価指数(日次)
                return .overseasDaily
            }
        }
        set {
            self.market = Self.market(for: newValue)
        }
    }

    /// 銘柄コード(Objective-C では NSString *。nil = 未設定)。チャートの描き方には使わず、持っておくだけ。
    /// 呼び出し側が、データを取得するときなどに使う
    ///
    ///   Objective-C:
    ///       self.chartView.qCode = qCode;
    ///       NSString *code = self.chartView.qCode;
    @objc var qCode: String? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.qCode) as? String
        }
        set {
            // 銘柄が変わったら、次にデータを渡したときは直前の表示範囲を引き継がずに初期表示にする
            if newValue != self.qCode {
                self.resetVisibleRange()
            }
            // NSString の copy プロパティと同じく、コピーして持つ
            objc_setAssociatedObject(self, &AssociatedKeys.qCode, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }

    // MARK: - DGChartEnum の enum → StockChartView の enum

    /// メインチャート → メインチャートの指標
    private static func mainIndicator(for mainChart: DGMainChart) -> MainChartIndicator {
        switch mainChart {
        case .movingAverage:
            // 移動平均線
            return .movingAverage
        case .multipleMovingAverage:
            // 多重移動平均線
            return .multipleMovingAverage
        case .bollingerBands:
            // ボリンジャーバンド
            return .bollingerBands
        case .ichimoku:
            // 一目均衡表
            return .ichimoku
        case .parabolic:
            // パラボリック
            return .parabolic
        case .none:
            // テクニカル指標設定なし(ローソク足のみ)
            return .candleOnly
        }
    }

    /// サブチャート → サブチャートの指標
    private static func subIndicator(for subChart: DGSubChart) -> SubChartIndicator {
        switch subChart {
        case .turnover:
            // 出来高(+出来高移動平均)
            return .volume
        case .differenceFromMovingAverage:
            // 移動平均乖離率
            return .movingAverageDeviation
        case .rsi:
            // ＲＳＩ
            return .rsi
        case .psychological:
            // サイコロジカル
            return .psychological
        case .stochastics:
            // ストキャス
            return .stochastics
        case .macd:
            // MACD
            return .macd
        case .dmi:
            // DMI
            return .dmi
        case .none:
            // テクニカル指標設定なし(サブチャートなし)
            return .hidden
        }
    }

    /// チャート種別 → チャートの種類
    private static func chartType(for category: DGChartCategory) -> ChartType {
        switch category {
        case .candle:
            // ローソク足
            return .candlestick
        case .vwapLine:
            // VWAP：線
            return .vwapLine
        case .vwapDot:
            // VWAP：点
            return .vwapDots
        case .recordPrice:
            // 新値足
            return .newPrice
        case .line:
            // 折線チャート
            return .lineChart
        }
    }

    /// チャートデータ → 足種
    private static func period(for chartData: DGChartData) -> ChartPeriod {
        switch chartData {
        case .min:
            // 1分足
            return .oneMinute
        case .midDay:
            // 日中足
            return .intraday
        case .day:
            // 日足
            return .daily
        case .week:
            // 週足
            return .weekly
        case .month:
            // 月足
            return .monthly
        }
    }

    /// 銘柄コードの種類 → 銘柄・指数の種類(1対1)
    private static func market(for qCodeType: DGCodeType) -> IndexMarket {
        switch qCodeType {
        case .japanStock:
            // 日本株
            return .japanStock
        case .japanIndex:
            // 日本株価指数
            return .japanIndex
        case .overseasRealtime:
            // 海外株価指数(リアルタイム)
            return .overseasRealtime
        case .overseasDaily:
            // 海外株価指数(日次)
            return .overseasDaily
        }
    }
}

// MARK: - 関連オブジェクトのキー

/// extension で値を持つための、関連オブジェクトのキー(変数のアドレスをキーに使う。値そのものは使わない)
private enum AssociatedKeys {
    /// qCode のキー
    nonisolated(unsafe) static var qCode: UInt8 = 0
}

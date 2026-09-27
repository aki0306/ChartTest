//
//  DGChartEnum.swift
//  ChartTest
//
//  【Model】チャートの設定に使う enum(Objective-C からも使える)。
//
//  StockChartView に設定するときは、StockChartView+DGChartEnum.swift のプロパティ
//  (mainChart・subChart・chartCategory・chartData・qCodeType)を使う。
//
//  Objective-C での名前は「型名 + ケース名(先頭は大文字)」になる(例: DGMainChartMovingAverage)。
//  RSI・MACD などの略語は、@objc(…) で Objective-C での名前を指定して大文字のままにしている。
//
//    Objective-C:
//        self.chartView.mainChart = DGMainChartBollingerBands;
//        self.chartView.subChart = DGSubChartRSI;
//

import Foundation

// MARK: - メインチャート

/// メインチャートに表示するテクニカル指標
@objc enum DGMainChart: Int {
    /// 移動平均線
    case movingAverage = 0
    /// 多重移動平均線
    case multipleMovingAverage
    /// ボリンジャーバンド
    case bollingerBands
    /// 一目均衡表
    @objc(DGMainChartIChiMoKu)
    case ichimoku
    /// パラボリック
    case parabolic
    /// テクニカル指標設定なし
    case none
}

// MARK: - サブチャート

/// サブチャートに表示するテクニカル指標
@objc enum DGSubChart: Int {
    /// 出来高(+出来高移動平均)
    case turnover = 0
    /// 移動平均乖離率
    case differenceFromMovingAverage
    /// ＲＳＩ
    @objc(DGSubChartRSI)
    case rsi
    /// サイコロジカル
    case psychological
    /// ストキャス
    case stochastics
    /// MACD
    @objc(DGSubChartMACD)
    case macd
    /// DMI
    @objc(DGSubChartDMI)
    case dmi
    /// テクニカル指標設定なし
    case none
}

// MARK: - チャート種別

/// 株価チャートの描画形式
@objc enum DGChartCategory: Int {
    /// ローソク足
    case candle = 0
    /// VWAP：線
    @objc(DGChartCategoryVWAPLine)
    case vwapLine
    /// VWAP：点
    @objc(DGChartCategoryVWAPDot)
    case vwapDot
    /// 新値足
    case recordPrice
    /// 折線チャート
    case line
}

// MARK: - チャートデータ

/// 株価データの時間軸
@objc enum DGChartData: Int {
    /// 1分足
    case min = 0
    /// 日中足
    case midDay
    /// 日足
    case day
    /// 週足
    case week
    /// 月足
    case month
}

// MARK: - チャートモード

/// チャートの表示モード
@objc enum DGChartMode: Int {
    /// 端末縦向き
    case normal = 0
    /// 端末横向き
    case profession
}

// MARK: - 銘柄コード種別

/// 銘柄コードの種類
@objc enum DGCodeType: Int {
    /// 日本株
    case japanStock = 0
    /// 日本株価指数
    case japanIndex
    /// 海外株価指数(リアルタイム)
    case overseasRealtime
    /// 海外株価指数(日次)
    case overseasDaily
}

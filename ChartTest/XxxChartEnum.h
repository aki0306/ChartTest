#pragma mark - メインチャート

/// メインチャートに表示するテクニカル指標
typedef enum {
    // 移動平均線
    XxxMainChartMovingAverage = 0,
    // 多重移動平均線
    XxxMainChartMultipleMovingAverage,
    // ボリンジャーバンド
    XxxMainChartBollingerBands,
    // 一目均衡表
    XxxMainChartIChiMoKu,
    // パラボリック
    XxxMainChartParabolic,
    // テクニカル指標設定なし
    XxxMainChartNone
} XxxMainChart;

#pragma mark - サブチャート

/// サブチャートに表示するテクニカル指標
typedef enum {
    // 出来高（+出来高移動平均）
    XxxSubChartTurnover = 0,
    // 移動平均乖離率
    XxxSubChartDifferenceFromMovingAverage,
    // ＲＳＩ
    XxxSubChartRSI,
    // サイコロジカル
    XxxSubChartPsychological,
    // ストキャス
    XxxSubChartStochastics,
    // MACD
    XxxSubChartMACD,
    // DMI
    XxxSubChartDMI,
    // テクニカル指標設定なし
    XxxSubChartNone
} XxxSubChart;

#pragma mark - チャート種別

/// 株価チャートの描画形式
typedef enum {
    // ローソク足
    XxxChartCategoryCandle = 0,
    // VWAP：線
    XxxChartCategoryVWAPLine,
    // VWAP：点
    XxxChartCategoryVWAPDot,
    // 新値足
    XxxChartCategoryRecordPrice,
    // 折線チャート
    XxxChartCategoryLine
} XxxChartCategory;

#pragma mark - チャートデータ

/// 株価データの時間軸
typedef enum {
    // 1分足
    XxxChartDataMin = 0,
    // 日中足
    XxxChartDataMidDay,
    // 日足
    XxxChartDataDay,
    // 週足
    XxxChartDataWeek,
    // 月足
    XxxChartDataMonth
} XxxChartData;

#pragma mark - チャートモード

/// チャートの表示モード
typedef enum {
    // 端末縦向き
    XxxChartModeNormal = 0,
    // 端末横向き
    XxxChartModeProfession
} XxxChartMode;

#pragma mark - 銘柄コード種別

/// 銘柄コードの種類
typedef enum{
    // 日本株
    XxxCodeTypeJapanStock = 0,
    // 日本株価指数
    XxxCodeTypeJapanIndex,
    // 海外株価指数（リアルタイム）
    XxxCodeTypeOverseasRealtime,
    // 海外株価指数（日次）
    XxxCodeTypeOverseasDaily
}XxxCodeType;

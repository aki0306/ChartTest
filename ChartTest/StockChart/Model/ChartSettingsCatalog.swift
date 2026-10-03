//
//  ChartSettingsCatalog.swift
//  ChartTest
//
//  【Model】設定画面に並べる項目と、各項目で編集できるパラメータの定義。
//
//  ・設定画面の左側のリスト(表示 / メインチャート / サブチャート の各項目)
//  ・項目ごとの編集対象(IndicatorParameters のどのプロパティを、どの範囲・刻みで変更できるか)
//  を決める。画面の見た目は View(ChartSettingsView)、値の反映は Controller が担当する。
//

import Foundation

/// 設定画面の左側リストの1項目
enum ChartSettingsItem: Equatable {
    /// 表示 > オプション(Y軸固定・4本値)
    case displayOptions
    /// メインチャート指標のパラメータ
    case main(MainChartIndicator)
    /// サブチャート指標のパラメータ
    case sub(SubChartIndicator)

    /// リストに表示する名称
    var title: String {
        switch self {
        case .displayOptions: return "オプション"
        case .main(let indicator): return indicator.title
        case .sub(let indicator): return indicator.title
        }
    }
}

/// 設定画面の左側リストの見出しごとのまとまり
struct ChartSettingsSection {
    /// 見出し(「表示」「メインチャート」「サブチャート」)
    let title: String
    /// 見出しの下に並ぶ項目
    let items: [ChartSettingsItem]
}

/// 編集できる1つのパラメータ(IndicatorParameters の1プロパティ)
struct IndicatorParameterField {
    /// 編集対象のプロパティ(整数 / 小数)
    enum Target {
        case int(WritableKeyPath<IndicatorParameters, Int>)
        case double(WritableKeyPath<IndicatorParameters, Double>)
    }

    /// 画面に表示する名称
    let title: String
    /// 編集対象のプロパティ
    let target: Target
    /// 設定できる範囲
    let range: ClosedRange<Double>
    /// +/− ボタン1回で変わる量
    let step: Double

    /// 表示に使う小数点以下の桁数(整数なら 0)
    var fractionDigits: Int {
        switch target {
        case .int:
            return 0
        case .double:
            // 刻みの桁に合わせる。log10 で「10 の何乗か」を求める
            //   0.1 刻み  → log10(0.1)  = -1 → 1 桁
            //   0.02 刻み → log10(0.02) = -1.69… → 切り上げて 2 桁
            let digits = Int((-log10(step)).rounded(.up))
            return max(0, digits)
        }
    }

    /// 現在の値を読み出す
    func value(in parameters: IndicatorParameters) -> Double {
        switch target {
        case .int(let keyPath): return Double(parameters[keyPath: keyPath])
        case .double(let keyPath): return parameters[keyPath: keyPath]
        }
    }

    /// 値を書き込む(範囲内に丸める。整数の場合は四捨五入する)
    func setValue(_ value: Double, in parameters: inout IndicatorParameters) {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        switch target {
        case .int(let keyPath): parameters[keyPath: keyPath] = Int(clamped.rounded())
        case .double(let keyPath): parameters[keyPath: keyPath] = clamped
        }
    }
}

/// 設定画面の項目・パラメータ定義
enum ChartSettingsCatalog {

    /// 指定した指数の種類で、左側リストに並べる見出しと項目。
    /// 海外指数は「表示 > オプション」と「メインチャート > 移動平均線」だけ(サブチャートの設定はない)
    static func sections(for market: IndexMarket) -> [ChartSettingsSection] {
        switch market {
        case .domestic:
            return sections
        case .overseas:
            return [
                ChartSettingsSection(title: "表示", items: [.displayOptions]),
                ChartSettingsSection(title: "メインチャート", items: [.main(.movingAverage)]),
            ]
        }
    }

    /// 左側リストに並べる見出しと項目(国内指数)
    static let sections: [ChartSettingsSection] = [
        ChartSettingsSection(title: "表示", items: [.displayOptions]),
        ChartSettingsSection(title: "メインチャート", items: [
            .main(.movingAverage),
            .main(.multipleMovingAverage),
            .main(.bollingerBands),
            .main(.ichimoku),
        ]),
        ChartSettingsSection(title: "サブチャート", items: [
            .sub(.movingAverageDeviation),
            .sub(.rsi),
            .sub(.psychological),
            .sub(.stochastics),
            .sub(.macd),
            .sub(.dmi),
        ]),
    ]

    /// 期間(本数)の一般的な設定範囲
    private static let periodRange: ClosedRange<Double> = 1...200
    /// 底値ライン・高値ライン(0〜100% の指標)の設定範囲
    private static let percentLineRange: ClosedRange<Double> = 0...100

    /// 指定した項目を設定できる足種。
    /// 1分足・日中足は移動平均線だけを設定できる(それ以外の項目では、設定画面のタブをグレーにして選べなくする)
    static func periods(for item: ChartSettingsItem) -> [ChartPeriod] {
        switch item {
        case .main(.movingAverage):
            return ChartPeriod.allCases
        case .displayOptions, .main, .sub:
            return [.daily, .weekly, .monthly]
        }
    }

    /// 指定した項目で編集できるパラメータの一覧(表示オプションの場合は空)
    ///
    ///   | 項目           | 並べるパラメータ                                     |
    ///   |----------------|------------------------------------------------------|
    ///   | 移動平均線     | 短期平均線・長期平均線                               |
    ///   | 多重移動平均線 | 最短期間・最長期間・本数                             |
    ///   | ボリンジャー   | 期間・乖離率(σ)                                    |
    ///   | 一目均衡表     | 基準線期間・転換線期間・スパン期間                   |
    ///   | 移動平均乖離率 | 短期平均線・長期平均線・底値ライン・高値ライン       |
    ///   | RSI            | 期間・底値ライン・高値ライン                         |
    ///   | サイコロジカル | 期間・底値ライン・高値ライン                         |
    ///   | ストキャス     | 高安期間・D期間・底値ライン・高値ライン              |
    ///   | MACD           | 短期EMA・長期EMA・シグナル期間                       |
    ///   | DMI            | 期間                                                 |
    static func fields(for item: ChartSettingsItem) -> [IndicatorParameterField] {
        switch item {
        case .displayOptions:
            return []

        case .main(let indicator):
            switch indicator {
            case .movingAverage:
                return [
                    period("短期平均線", \.shortMAPeriod),
                    period("長期平均線", \.longMAPeriod),
                ]
            case .multipleMovingAverage:
                return [
                    period("最短期間", \.multipleMAShortestPeriod),
                    period("最長期間", \.multipleMALongestPeriod),
                    IndicatorParameterField(title: "本数", target: .int(\.multipleMACount), range: 2...15, step: 1),
                ]
            case .bollingerBands:
                return [
                    period("期間", \.bollingerPeriod),
                    IndicatorParameterField(title: "乖離率(σ)", target: .int(\.bollingerSigmaCount), range: 1...3, step: 1),
                ]
            case .ichimoku:
                return [
                    period("基準線期間", \.ichimokuKijunPeriod),
                    period("転換線期間", \.ichimokuTenkanPeriod),
                    IndicatorParameterField(title: "スパン期間", target: .int(\.ichimokuShift), range: 1...100, step: 1),
                ]
            case .parabolic, .candleOnly:
                // 設定画面には並べない
                return []
            }

        case .sub(let indicator):
            switch indicator {
            case .movingAverageDeviation:
                return [
                    period("短期平均線", \.deviationShortPeriod),
                    period("長期平均線", \.deviationLongPeriod),
                    IndicatorParameterField(title: "底値ライン(%)", target: .int(\.deviationLowerLine), range: -50...0, step: 1),
                    IndicatorParameterField(title: "高値ライン(%)", target: .int(\.deviationUpperLine), range: 0...50, step: 1),
                ]
            case .rsi:
                return [period("期間", \.rsiPeriod)]
                    + percentLines(lower: \.rsiLowerLine, upper: \.rsiUpperLine)
            case .psychological:
                return [period("期間", \.psychologicalPeriod)]
                    + percentLines(lower: \.psychologicalLowerLine, upper: \.psychologicalUpperLine)
            case .stochastics:
                return [
                    period("高安期間", \.stochasticsKPeriod),
                    period("D期間", \.stochasticsDPeriod),
                ] + percentLines(lower: \.stochasticsLowerLine, upper: \.stochasticsUpperLine)
            case .macd:
                return [
                    period("短期EMA", \.macdShortPeriod),
                    period("長期EMA", \.macdLongPeriod),
                    period("シグナル期間", \.macdSignalPeriod),
                ]
            case .dmi:
                return [period("期間", \.dmiPeriod)]
            case .volume, .hidden:
                // 設定画面には並べない
                return []
            }
        }
    }

    /// 期間(整数・1〜200・1刻み)のパラメータ定義を作る
    private static func period(_ title: String, _ keyPath: WritableKeyPath<IndicatorParameters, Int>)
        -> IndicatorParameterField {
        IndicatorParameterField(title: title, target: .int(keyPath), range: periodRange, step: 1)
    }

    /// 底値ライン・高値ライン(0〜100% の指標)のパラメータ定義を作る
    private static func percentLines(lower: WritableKeyPath<IndicatorParameters, Int>,
                                     upper: WritableKeyPath<IndicatorParameters, Int>) -> [IndicatorParameterField] {
        [
            IndicatorParameterField(title: "底値ライン(%)", target: .int(lower), range: percentLineRange, step: 1),
            IndicatorParameterField(title: "高値ライン(%)", target: .int(upper), range: percentLineRange, step: 1),
        ]
    }
}

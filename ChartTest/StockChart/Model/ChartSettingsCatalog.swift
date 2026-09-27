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
        case .int: return 0
        // 刻みの桁に合わせる(0.1 刻みなら 1 桁、0.01 刻みなら 2 桁)
        case .double: return max(0, Int((-log10(step)).rounded(.up)))
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

    /// 左側リストに並べる見出しと項目
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

    /// 指定した項目で編集できるパラメータの一覧(表示オプションの場合は空)
    /// - Parameter parameters: 現在のパラメータ(配列の要素数に応じて項目を作るために使う)
    static func fields(for item: ChartSettingsItem, parameters: IndicatorParameters) -> [IndicatorParameterField] {
        switch item {
        case .displayOptions:
            return []

        case .main(let indicator):
            switch indicator {
            case .movingAverage:
                return [
                    period("短期", \.shortMAPeriod),
                    period("長期", \.longMAPeriod),
                ]
            case .multipleMovingAverage:
                // 期間の配列の要素ごとに「1本目」「2本目」… を並べる
                return parameters.multipleMAPeriods.indices.map { i in
                    period("\(i + 1)本目", \.multipleMAPeriods[i])
                }
            case .bollingerBands:
                return [period("期間", \.bollingerPeriod)]
                    + parameters.bollingerSigmas.indices.map { i in
                        IndicatorParameterField(title: "σ倍率\(i + 1)", target: .double(\.bollingerSigmas[i]),
                                                range: 0.1...5, step: 0.1)
                    }
            case .ichimoku:
                return [
                    period("転換線", \.ichimokuTenkanPeriod),
                    period("基準線", \.ichimokuKijunPeriod),
                    period("先行スパン2", \.ichimokuSpanBPeriod),
                    IndicatorParameterField(title: "先行/遅行", target: .int(\.ichimokuShift), range: 1...100, step: 1),
                ]
            case .parabolic, .candleOnly:
                // 設定画面には並べない
                return []
            }

        case .sub(let indicator):
            switch indicator {
            case .movingAverageDeviation:
                return [
                    period("短期", \.deviationShortPeriod),
                    period("長期", \.deviationLongPeriod),
                ]
            case .rsi:
                return [period("期間", \.rsiPeriod)]
            case .psychological:
                return [period("期間", \.psychologicalPeriod)]
            case .stochastics:
                return [
                    period("%K", \.stochasticsKPeriod),
                    period("%D", \.stochasticsDPeriod),
                ]
            case .macd:
                return [
                    period("短期EMA", \.macdShortPeriod),
                    period("長期EMA", \.macdLongPeriod),
                    period("シグナル", \.macdSignalPeriod),
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
}

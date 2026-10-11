//
//  IndexMarket.swift
//  ChartTest
//
//  【Model】銘柄・指数の種類(日本株・日本株価指数・海外リアルタイム・海外日次)と、種類ごとの違い。
//
//  | 種類             | 国内/海外 | 選べる足種                      | スクロールできる最小の本数 |
//  |------------------|-----------|---------------------------------|----------------------------|
//  | 日本株           | 国内      | 1分足・日中足・日足・週足・月足 | 日足〜月足 250 本          |
//  | 日本株価指数     | 国内      | 1分足・日中足・日足・週足・月足 | 日足〜月足 250 本          |
//  | 海外リアルタイム | 海外      | 日足・週足・月足                | 50 本                      |
//  | 海外日次         | 海外      | 日足・週足・月足                | 50 本                      |
//
//  足種そのもの(1分足〜月足)と足種ごとの違いは ChartPeriod.swift。
//

import Foundation

/// 銘柄・指数の種類。種類によって選べる足種・描き方が変わる。
/// Objective-C の銘柄コードの種類と同じ4つで、並び順(値)も同じにしている。
/// 描き方は国内(日本株・日本株価指数)と海外(リアルタイム・日次)の2通りで、同じグループの中では同じ
/// (同じグループの中で違うのは呼ぶ API だけ)
///
///   | IndexMarket       | Objective-C                  | 銘柄コードの種類                             | 描き方 |
///   |-------------------|------------------------------|----------------------------------------------|--------|
///   | .japanStock       | IndexMarketJapanStock        | JapanStock(日本株)                          | 国内   |
///   | .japanIndex       | IndexMarketJapanIndex        | JapanIndex(日本株価指数)                    | 国内   |
///   | .overseasRealtime | IndexMarketOverseasRealtime  | OverseasRealtime(海外株価指数・リアルタイム) | 海外   |
///   | .overseasDaily    | IndexMarketOverseasDaily     | OverseasDaily(海外株価指数・日次)           | 海外   |
///
/// Objective-C からも使えるよう @objc enum(Int)にしている
@objc enum IndexMarket: Int {
    /// 日本株
    case japanStock
    /// 日本株価指数(日経平均など)
    case japanIndex
    /// 海外株価指数・リアルタイム
    case overseasRealtime
    /// 海外株価指数・日次
    case overseasDaily

    /// タブに並べる足種(左から順に)
    var periods: [ChartPeriod] {
        switch self {
        case .japanStock, .japanIndex:
            return [.oneMinute, .intraday, .daily, .weekly, .monthly]
        case .overseasRealtime, .overseasDaily:
            return [.daily, .weekly, .monthly]
        }
    }

    /// 国内(日本株・日本株価指数)か。国内・海外で分ける設定(サブチャートの有無・覚えておく状態など)を決めるのに使う
    var isDomestic: Bool {
        switch self {
        case .japanStock, .japanIndex:
            return true
        case .overseasRealtime, .overseasDaily:
            return false
        }
    }

    /// スクロールできる範囲の最小の本数(nil = データの本数のまま)。
    /// データがこの本数より少なくても、左側を空けてこの本数分の幅をスクロール・縮小できるようにする
    ///
    ///   | 指数の種類 | 1分足・日中足 | 日足・週足・月足 |
    ///   |------------|---------------|------------------|
    ///   | 国内       | なし          | 250 本           |
    ///   | 海外       | (選べない)  | 50 本            |
    ///
    /// 新値足は足種によらず 250 本(ChartContentBuilder.newPriceScrollCount)
    func minimumScrollCount(for period: ChartPeriod) -> Int? {
        switch self {
        case .japanStock, .japanIndex:
            switch period {
            case .oneMinute, .intraday:
                return nil
            case .daily, .weekly, .monthly:
                return 250
            }
        case .overseasRealtime, .overseasDaily:
            return 50
        }
    }
}

//
//  SampleData.swift
//  ChartTest
//
//  動作確認用のダミーのローソク足データ(本来は API などから取得する想定)。
//

import Foundation

// MARK: - サンプルデータ

/// 動作確認用のダミーデータ
enum SampleData {

    /// 平日のみ・日経平均風のランダムウォークデータを生成する。
    /// シード固定の乱数を使っているので、毎回同じ形のチャートになる。
    /// (一目均衡表の先行スパン2 や多重移動平均線の 75 本など、長い期間の指標も描けるよう 200 本用意する)
    /// - Parameter days: 生成する営業日数
    /// - Returns: 日付の古い順に並んだローソク足データ
    static func nikkeiLike(days: Int = 200) -> [StockCandle] {
        var rng = SeededGenerator(seed: 20260925)
        let calendar = Calendar(identifier: .gregorian)
        let end = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25))!

        // 終了日から遡って平日(土日以外)を集める。祝日は考慮しない
        var dates: [Date] = []
        var date = end
        while dates.count < days {
            if !calendar.isDateInWeekend(date) { dates.insert(date, at: 0) }
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        }

        var candles: [StockCandle] = []
        var prevClose = 66_000.0
        for d in dates {
            // 66,000 付近に戻る力をかけて、値が大きく離れすぎないようにする
            let revert = (66_000 - prevClose) * 0.08
            // 始値は前日終値の近く、終値は始値から上下にランダム
            let open = prevClose + revert + Double.random(in: -400...400, using: &rng)
            let close = open + Double.random(in: -1_200...1_200, using: &rng)
            // 高値/安値は実体(始値〜終値)の外側にヒゲとして伸ばす
            let high = max(open, close) + Double.random(in: 0...500, using: &rng)
            let low = min(open, close) - Double.random(in: 0...500, using: &rng)
            // 出来高は 16億〜32億株
            let volume = Double.random(in: 1.6e9...3.2e9, using: &rng)
            candles.append(StockCandle(date: d, open: open, high: high, low: low, close: close, volume: volume))
            prevClose = close
        }
        return candles
    }

    /// シード指定可能な乱数ジェネレータ(SplitMix64)。
    /// SystemRandomNumberGenerator はシードを指定できないため、再現性のあるデータ生成用に用意している
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }
}

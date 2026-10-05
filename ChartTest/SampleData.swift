//
//  SampleData.swift
//  ChartTest
//
//  動作確認用のダミーのローソク足データ(本来は API などから取得する想定)。
//  1分足・日中足は、既存アプリの実際のレスポンス(SampleResponses/oneMinute.json・intraday.json。XxxChartDataUtil の
//  dataArrayFromResponse:… の結果を JSON にしたもの)を使う。
//

import Foundation

// MARK: - サンプルデータ

/// 動作確認用のダミーデータ。
/// Objective-C からも使えるよう NSObject を継承したクラスにしている(インスタンスは作らない)
///   Swift       : SampleData.candles(for: .daily)
///   Objective-C : [SampleData candlesForPeriod:ChartPeriodDaily]
final class SampleData: NSObject {

    /// インスタンスは作らない(static メソッドだけを使う)
    private override init() {
        super.init()
    }

    /// 平日のみ・日経平均風のランダムウォークデータを生成する。
    /// シード固定の乱数を使っているので、毎回同じ形のチャートになる。
    /// (一目均衡表の先行スパン2 や多重移動平均線の 75 本など、長い期間の指標も描けるよう 200 本用意する)
    /// - Parameter days: 生成する営業日数
    /// - Returns: 日付の古い順に並んだローソク足データ
    @objc static func nikkeiLike(days: Int = 200) -> [StockCandle] {
        var rng = SeededGenerator(seed: 20260925)
        let calendar = Calendar(identifier: .gregorian)
        let end = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25))!

        // 終了日から遡って平日(土日以外)を集める。祝日は考慮しない
        var dates: [Date] = []
        var date = end
        while dates.count < days {
            // 古い順に並べるため、先頭に入れる
            if !calendar.isDateInWeekend(date) {
                dates.insert(date, at: 0)
            }
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        }

        var candles: [StockCandle] = []
        var previousClose = 66_000.0
        for candleDate in dates {
            // 66,000 付近に戻る力をかけて、値が大きく離れすぎないようにする
            let revert = (66_000 - previousClose) * 0.08
            // 始値は前日終値の近く、終値は始値から上下にランダム
            let open = previousClose + revert + Double.random(in: -400...400, using: &rng)
            let close = open + Double.random(in: -1_200...1_200, using: &rng)
            // 高値/安値は実体(始値〜終値)の外側にヒゲとして伸ばす
            let high = max(open, close) + Double.random(in: 0...500, using: &rng)
            let low = min(open, close) - Double.random(in: 0...500, using: &rng)
            // 出来高は 1,200万〜3,500万(既存アプリの日経平均のレスポンス kTurnover と同じ桁。Y軸の欄 65pt に収まる)
            let volume = Double.random(in: 1.2e7...3.5e7, using: &rng)
            candles.append(StockCandle(date: candleDate, open: open, high: high, low: low, close: close, volume: volume))
            previousClose = close
        }
        return candles
    }

    // MARK: - 足種ごとのデータ

    /// 指定した足種のダミーデータを返す(本来は足種を指定して API から取得する想定)
    /// - Returns: 日付の古い順に並んだローソク足データ
    @objc(candlesForPeriod:)
    static func candles(for period: ChartPeriod) -> [StockCandle] {
        switch period {
        case .oneMinute:
            return self.responseCandles(fileName: "oneMinute")
        case .intraday:
            return self.responseCandles(fileName: "intraday")
        case .daily:
            return self.nikkeiLike()
        case .weekly:
            return self.weeklyCandles()
        case .monthly:
            return self.monthlyCandles()
        }
    }

    /// 既存アプリのレスポンス(SampleResponses の JSON)を、ChartResponseLoader と同じ読み方でローソク足にする。
    /// 1分足・日中足のレスポンスは 9:00〜15:30 の日時があり、値は 14:35 まで(それより後は値が空)なので、
    /// 値のない時間帯は日時だけの足になる(チャートは 14:35 で足が止まり、右側に 15:30 までの日付が並ぶ)。
    /// 日中足は、既存アプリが1分足を5分ごとにまとめた結果(出来高は 0。VWAP は API の値)
    /// - Parameter fileName: JSON のファイル名(拡張子なし)
    private static func responseCandles(fileName: String) -> [StockCandle] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else { return [] }
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let response = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return StockCandleResponseParser.candles(from: response, market: .domestic, keepsEmptyDates: true)
    }

    /// 週足(約2年半ぶん)。毎週金曜日の日付で、4万円台から6万円台へ上がっていく形
    private static func weeklyCandles() -> [StockCandle] {
        let calendar = Calendar(identifier: .gregorian)
        let lastFriday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25))!

        var dates: [Date] = []
        for weeksAgo in (0..<130).reversed() {
            dates.append(calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: lastFriday)!)
        }
        return self.trendCandles(dates: dates, startPrice: 38_000, endPrice: 65_500,
                            bodySize: 1_300, wickSize: 700,
                            volumeRange: 1.2e7...3.5e7, seed: 202609)
    }

    /// 月足(2022/10〜2026/9 の4年ぶん)。毎月1日の日付で、3万円台から6万円台へ上がっていく形
    private static func monthlyCandles() -> [StockCandle] {
        let calendar = Calendar(identifier: .gregorian)
        let lastMonth = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!

        var dates: [Date] = []
        for monthsAgo in (0..<48).reversed() {
            dates.append(calendar.date(byAdding: .month, value: -monthsAgo, to: lastMonth)!)
        }
        return self.trendCandles(dates: dates, startPrice: 32_000, endPrice: 65_500,
                            bodySize: 2_500, wickSize: 1_200,
                            volumeRange: 1.0e7...2.5e7, seed: 20269)
    }

    /// 開始値から終了値へ向かう、ランダムな値動きのローソク足を作る
    /// - Parameters:
    ///   - dates: 各足の日時(古い順)
    ///   - startPrice: 最初の足の値の目安
    ///   - endPrice: 最後の足の値の目安
    ///   - bodySize: 実体(始値〜終値)の大きさの目安
    ///   - wickSize: ヒゲの長さの目安
    ///   - volumeRange: 出来高の範囲
    ///   - seed: 乱数のシード(同じシードなら毎回同じ形になる)
    private static func trendCandles(dates: [Date], startPrice: Double, endPrice: Double,
                                     bodySize: Double, wickSize: Double,
                                     volumeRange: ClosedRange<Double>, seed: UInt64) -> [StockCandle] {
        var rng = SeededGenerator(seed: seed)
        var candles: [StockCandle] = []
        var previousClose = startPrice
        // 直線からのずれ(ゆっくり上下に波打つ)。前回の値を少し残しながら変えるので、上げ・下げの流れができる
        var wave = 0.0

        for (index, date) in dates.enumerated() {
            // 目標の値: 開始値から終了値へ直線的に動く線に、ゆっくりした波を足したもの
            var progress = 0.0
            if dates.count > 1 {
                progress = Double(index) / Double(dates.count - 1)
            }
            wave = wave * 0.95 + Double.random(in: -bodySize...bodySize, using: &rng)
            let target = startPrice + (endPrice - startPrice) * progress + wave

            // 始値は前の足の終値の近く。終値は目標の値に 3 割近づけ、少しランダムにずらす
            let open = previousClose + Double.random(in: -bodySize * 0.2...bodySize * 0.2, using: &rng)
            let close = open + (target - open) * 0.3 + Double.random(in: -bodySize * 0.6...bodySize * 0.6, using: &rng)
            // 高値/安値は実体(始値〜終値)の外側にヒゲとして伸ばす
            let high = max(open, close) + Double.random(in: 0...wickSize, using: &rng)
            let low = min(open, close) - Double.random(in: 0...wickSize, using: &rng)

            let volume = Double.random(in: volumeRange, using: &rng)

            candles.append(StockCandle(date: date, open: open, high: high, low: low, close: close, volume: volume))
            previousClose = close
        }
        return candles
    }

    // MARK: - 乱数

    /// シード指定可能な乱数ジェネレータ(SplitMix64)。
    /// SystemRandomNumberGenerator はシードを指定できないため、再現性のあるデータ生成用に用意している
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { self.state = seed }
        mutating func next() -> UInt64 {
            self.state &+= 0x9E3779B97F4A7C15
            var z = self.state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }
}

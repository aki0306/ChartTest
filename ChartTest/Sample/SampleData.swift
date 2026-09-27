//
//  SampleData.swift
//  ChartTest
//
//  動作確認用のダミーのローソク足データ(本来は API などから取得する想定)。
//  1分足・日中足は、実際のレスポンス(SampleResponses/oneMinute.json・intraday.json。
//  chartDataFromResponse:… の結果を JSON にしたもの)を使う。
//  日足・週足・月足は乱数で作り、最後の足の終値を1分足の最後の終値(現在値 latestPrice)にそろえる
//  (どの足種でも値の水準と、横画面の下の帯の現在値が同じになるように)。
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
            // 出来高は 1,200万〜3,500万(Y軸の欄 65pt に収まる桁)
            let volume = Double.random(in: 1.2e7...3.5e7, using: &rng)
            candles.append(StockCandle(date: candleDate, open: open, high: high, low: low, close: close, volume: volume))
            previousClose = close
        }
        return candles
    }

    // MARK: - 足種ごとのデータ

    /// 指定した足種のダミーデータを返す(本来は足種を指定して API から取得する想定)。
    /// 日足・週足・月足は、1分足(実際のレスポンス)と値の水準がそろうよう、最後の足の終値を現在値(latestPrice)に合わせる
    /// - Returns: 日付の古い順に並んだローソク足データ
    @objc(candlesForPeriod:)
    static func candles(for period: ChartPeriod) -> [StockCandle] {
        switch period {
        case .oneMinute:
            return self.responseCandles(fileName: "oneMinute")
        case .intraday:
            return self.responseCandles(fileName: "intraday")
        case .daily:
            return self.scaled(self.nikkeiLike(), lastClose: self.latestPrice)
        case .weekly:
            return self.scaled(self.weeklyCandles(), lastClose: self.latestPrice)
        case .monthly:
            return self.scaled(self.monthlyCandles(), lastClose: self.latestPrice)
        }
    }

    // MARK: - 現在値(すべての足種で共通)

    /// 当日の1分足のうち、値のある最後の足(14:35。それより後ろは日時だけの足)
    private static let latestOneMinuteCandle = SampleData.candles(for: .oneMinute).last { candle in candle.hasValue }

    /// 現在値。当日の1分足の最後の足の終値(日足・週足・月足の最後の足の終値も、この値にそろえている)
    static var latestPrice: Double {
        guard let candle = self.latestOneMinuteCandle else {
            return 0
        }
        return candle.close
    }

    /// 現在値の日時。日足の最後の日(2026/9/25)に、1分足の最後の足の時刻(14:35)を合わせたもの
    /// (1分足のレスポンスの日付は、時刻だけを使うための仮の日付「2000/01/01」なので、そのままでは使えない)
    static var latestDate: Date {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents(year: 2026, month: 9, day: 25)
        if let candle = self.latestOneMinuteCandle {
            components.hour = calendar.component(.hour, from: candle.date)
            components.minute = calendar.component(.minute, from: candle.date)
        }
        return calendar.date(from: components) ?? Date()
    }

    /// ローソク足の値(始値・高値・安値・終値)を一律に何倍かして、最後の足の終値を指定の値にする(出来高はそのまま)。
    /// 形は変えずに、値の水準だけを1分足(実際のレスポンス)に合わせるのに使う
    /// - Parameters:
    ///   - candles: 日付の古い順に並んだローソク足データ
    ///   - lastClose: 最後の足の終値にしたい値(0 以下の場合は何もしない)
    private static func scaled(_ candles: [StockCandle], lastClose: Double) -> [StockCandle] {
        guard let last = candles.last else {
            return candles
        }
        guard last.close > 0 else {
            return candles
        }
        guard lastClose > 0 else {
            return candles
        }

        let ratio = lastClose / last.close
        return candles.map { candle in
            StockCandle(date: candle.date, open: candle.open * ratio, high: candle.high * ratio,
                        low: candle.low * ratio, close: candle.close * ratio, volume: candle.volume)
        }
    }

    /// レスポンス(SampleResponses の JSON)を、ChartResponseLoader と同じ読み方でローソク足にする。
    /// 1分足・日中足のレスポンスは 9:00〜15:30 の日時があり、値は 14:35 まで(それより後は値が空)なので、
    /// 値のない時間帯は日時だけの足になる(チャートは 14:35 で足が止まり、右側に 15:30 までの日付が並ぶ)。
    /// 日中足は、1分足を5分ごとにまとめた結果(出来高は 0。VWAP は API の値)
    /// - Parameter fileName: JSON のファイル名(拡張子なし)
    private static func responseCandles(fileName: String) -> [StockCandle] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            return []
        }
        guard let data = try? Data(contentsOf: url) else {
            return []
        }
        guard let response = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return StockCandleResponseParser.candles(from: response, market: .japanIndex, keepsEmptyDates: true)
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
        init(seed: UInt64) {
            self.state = seed
        }
        mutating func next() -> UInt64 {
            self.state &+= 0x9E3779B97F4A7C15
            var z = self.state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }
}

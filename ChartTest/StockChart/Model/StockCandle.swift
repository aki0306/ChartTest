//
//  StockCandle.swift
//  ChartTest
//
//  【Model】ローソク足データと、移動平均の計算処理。
//

import Foundation

/// ローソク足1本分(1日分や1週分など)のデータ。
///
/// Objective-C からも生成できるよう、struct ではなく NSObject のサブクラスにしている。
///   Swift:        StockCandle(date: d, open: o, high: h, low: l, close: c, volume: v)
///   Objective-C:  [[StockCandle alloc] initWithDate:d open:o high:h low:l close:c volume:v]
///
/// 値がなく日時だけの足(StockCandle(emptyDate:)。hasValue = false)も作れる。
/// 1分足・日中足で、まだ値のない時間帯(寄り付き前・これから来る時間)の日時を X軸に並べるためのもの。
/// チャートは、先頭側・末尾側にある日時だけの足を描かずに、日付の軸の空きとして並べる(途中にあるものは無視する)。
@objc final class StockCandle: NSObject {
    /// 日付(X軸ラベルの表示に使う)
    @objc let date: Date
    /// 始値
    @objc let open: Double
    /// 高値
    @objc let high: Double
    /// 安値
    @objc let low: Double
    /// 終値
    @objc let close: Double
    /// 出来高
    @objc let volume: Double
    /// API が計算した VWAP(既存アプリのレスポンスの kVWAP。1分足・日中足だけ)。ない場合は nil。
    /// 値がある場合、VWAP のチャートはこの値で描く(ない場合は出来高から計算する。ChartContentBuilder)。
    /// Double? は Objective-C で扱えないので Swift からだけ使う(Objective-C で作った足は nil)
    let vwap: Double?
    /// 値がある足か。false は日時だけの足(4本値は NaN。チャートには描かず、X軸の日付だけに使う)
    @objc let hasValue: Bool

    /// - Parameter vwap: API が計算した VWAP(ない場合は nil)
    init(date: Date, open: Double, high: Double, low: Double, close: Double, volume: Double, vwap: Double?) {
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.vwap = vwap
        self.hasValue = true
        super.init()
    }

    /// 値がなく日時だけの足を作る(Objective-C: [[StockCandle alloc] initWithEmptyDate:d])
    @objc init(emptyDate date: Date) {
        self.date = date
        self.open = .nan
        self.high = .nan
        self.low = .nan
        self.close = .nan
        self.volume = 0
        self.vwap = nil
        self.hasValue = false
        super.init()
    }

    /// チャートに描ける足か(値があり、4本値がすべて NaN・無限大でない)。
    /// Objective-C で NAN を入れて作った足などは、描けないので日時だけの足と同じに扱う(CandleSlots)
    var isDrawable: Bool {
        guard self.hasValue else { return false }
        return self.open.isFinite && self.high.isFinite && self.low.isFinite && self.close.isFinite
    }

    /// VWAP なしで作る(Objective-C からはこちらを使う)
    @objc convenience init(date: Date, open: Double, high: Double, low: Double, close: Double, volume: Double) {
        self.init(date: date, open: open, high: high, low: low, close: close, volume: volume, vwap: nil)
    }

    /// 値なしでの生成は不可(Objective-C の [[StockCandle alloc] init] もコンパイルエラーになる)
    @available(*, unavailable)
    override init() {
        fatalError("init(date:open:high:low:close:volume:) を使用してください")
    }
}

extension Array where Element == Double {

    /// 単純移動平均(SMA)を計算する。
    ///
    /// 例: period = 3 の場合、index 2 の値は (self[0] + self[1] + self[2]) / 3。
    /// 合計値を1つずつずらしながら更新するので、要素数 n に対して O(n) で計算できる。
    ///
    /// - Parameter period: 平均を取る本数
    /// - Returns: 元の配列と同じ要素数の配列。期間に満たない先頭部分(index < period - 1)は nil
    func simpleMovingAverage(period: Int) -> [Double?] {
        // 期間が不正な場合は全て nil
        guard period > 0 else { return [Double?](repeating: nil, count: count) }

        var result = [Double?](repeating: nil, count: count)
        var sum = 0.0  // 直近 period 本の合計
        for (index, value) in enumerated() {
            // 新しい値を合計に加える
            sum += value
            // period 本より前の値は期間から外れたので、合計から引く
            if index >= period {
                sum -= self[index - period]
            }
            // period 本たまったら平均を出す(それまでは nil のまま)
            if index >= period - 1 {
                result[index] = sum / Double(period)
            }
        }
        return result
    }
}

// MARK: - 日時だけの足を分ける

/// ローソク足の配列を、先頭側の日時だけの足・値のある足・末尾側の日時だけの足に分けたもの。
/// チャートは値のある足だけで指標を計算して描き、日時だけの足は X軸の左右の空き(日付だけ)として並べる
///
///   全体   : 08:45(日時だけ) 08:50(日時だけ) 09:00 09:05 … 14:35 14:40(日時だけ) … 15:30(日時だけ)
///   分けた後: leadingDates = [08:45, 08:50]  candles = [09:00 … 14:35]  trailingDates = [14:40 … 15:30]
///
/// ・値のある足の間にある日時だけの足は、捨てる(パーサーは途中の値がない件を直前の足で埋めるので、通常はない)
/// ・値のある足が1本もない場合は、すべて空(チャートは「表示できる情報はありません」を表示する)
/// ・4本値に NaN・無限大が入った足(isDrawable = false)も、値のない足として扱う(軸の範囲・指標の計算が壊れないように)
struct CandleSlots {
    /// 値のある最初の足より前の日時(古い順)
    let leadingDates: [Date]
    /// 値のある足(古い順)
    let candles: [StockCandle]
    /// 値のある最後の足より後ろの日時(古い順)
    let trailingDates: [Date]

    init(_ allCandles: [StockCandle]) {
        guard let firstIndex = allCandles.firstIndex(where: { candle in candle.isDrawable }) else {
            self.leadingDates = []
            self.candles = []
            self.trailingDates = []
            return
        }
        guard let lastIndex = allCandles.lastIndex(where: { candle in candle.isDrawable }) else {
            self.leadingDates = []
            self.candles = []
            self.trailingDates = []
            return
        }
        self.leadingDates = allCandles[..<firstIndex].map { candle in candle.date }
        self.candles = allCandles[firstIndex...lastIndex].filter { candle in candle.isDrawable }
        self.trailingDates = allCandles[(lastIndex + 1)...].map { candle in candle.date }
    }
}

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

    /// - Parameter vwap: API が計算した VWAP(ない場合は nil)
    init(date: Date, open: Double, high: Double, low: Double, close: Double, volume: Double, vwap: Double?) {
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.vwap = vwap
        super.init()
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

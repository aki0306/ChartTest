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

    @objc init(date: Date, open: Double, high: Double, low: Double, close: Double, volume: Double) {
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        super.init()
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
        var sum = 0.0
        for (i, value) in enumerated() {
            sum += value                                // 新しい値を合計に加える
            if i >= period { sum -= self[i - period] }  // 期間から外れた古い値を合計から引く
            if i >= period - 1 { result[i] = sum / Double(period) }
        }
        return result
    }
}

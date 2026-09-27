//
//  MainThread.swift
//  ChartTest
//
//  【共通】画面を書き換える処理を、必ずメインスレッドで行うための部品。
//
//  API の通信(URLSession など)の完了処理は、裏のスレッドで呼ばれることが多い。
//  画面(UIKit)はメインスレッドからしか触れないので、データを受け取る入口(setCandles など)の先頭で
//  「今メインスレッドか」を確かめ、違えばメインスレッドで呼び直す。
//  これで、通信の完了処理から直接 setCandles を呼んでも、表示が崩れたり落ちたりしない。
//
//  使い方(入口のメソッドの先頭に書く):
//
//      @objc func setCandles(_ candles: [StockCandle], period: ChartPeriod) {
//          // メインスレッドでなければ、メインスレッドで同じメソッドを呼び直して、ここで終わる
//          guard MainThread.isCurrent(orRetry: { self.setCandles(candles, period: period) }) else {
//              return
//          }
//          …(ここから先は必ずメインスレッド)
//      }
//

import Foundation

enum MainThread {

    /// 今メインスレッドかを返す。メインスレッドでなければ、retry をメインスレッドで実行するよう予約して false を返す
    /// - Parameter retry: メインスレッドで呼び直す処理(ふつうは、同じメソッドを同じ引数で呼ぶ)
    /// - Returns: true = このまま続けてよい / false = 呼び直しを予約したので、呼び出し元はここで終わる
    static func isCurrent(orRetry retry: @escaping @MainActor () -> Void) -> Bool {
        if Thread.isMainThread {
            return true
        }
        DispatchQueue.main.async {
            retry()
        }
        return false
    }
}

//
//  LatestAlignedXAxisRenderer.swift
//  ChartTest
//
//  【View】X軸ラベル(日付)を、どの足の下に表示するかを決める描画処理。
//
//  ■ 何をしているか
//    DGCharts 標準では、ラベルは 0本目, 10本目, 20本目, … のような「きりのいい位置」に置かれるため、
//    一番右(最新)の足にラベルが来るとは限らない。
//    このクラスでは「最新の足」から左へ、同じ本数おきにラベルを置く。
//    そのため、右端までスクロールしている状態では、一番右のラベルが必ず最新の日付になる。
//
//       7/16   7/29   8/10   8/21   9/2   9/14   9/29
//                                               ↑ 最新の足
//       ←─ 何本おき ─→ ずつ左へ置いていく
//
//  ■ 何本おきに置くか(2通り。StockChartStyle の xAxisLabelSpacing で切り替える)
//    1. 間隔を指定しない(labelSpacing = 0。縦画面)
//       画面に axis.labelCount 個くらい並ぶ本数おき。
//       例) 画面に 55本、labelCount = 7 → 55 ÷ (7 - 1) = 9.1… → 10本おき
//    2. 間隔を指定する(labelSpacing > 0。横画面)
//       「日付の文字の幅 + 間隔」が空く、一番少ない本数おき(=横幅に入るだけ並べる)。
//       例) 足1本の幅 = 18pt、日付「9/25」の幅 = 26pt、間隔 = 12pt
//           → 必要な幅 26 + 12 = 38pt → 38 ÷ 18 = 2.1… → 3本おき
//
//  ■ そのほかの決まり
//    ・ラベルは足に固定されるので、スクロールしてもラベルが足からずれない
//      (何本おきかは足1本の幅・表示本数から決めるので、拡大・縮小したときだけ変わる)
//    ・足の中心に置くと画面からはみ出すラベルは、ずらさずに表示しない(ずらすと隣のラベルと重なるため)
//    ・最新の足より右に日付だけを並べる時間帯(1分足・日中足の、これから値が来る時間)がある場合は、右へも同じ間隔で置く
//    ・1分足・日中足(minuteMultiple = 5)は、最新の足を基準にせず、きりのいい間隔(5・10・15・30・60分 …)で、
//      毎時 15分を基準にした時刻に置く(例: 全体を表示すると 30分おきで 9:15・9:45 … 15:15。拡大したときだけ細かくする)
//
//  ※ このプロジェクトは既定のアクター分離が MainActor だが、継承元の XAxisRenderer は
//    アクター分離なしで宣言されているため、クラスを nonisolated にして override できるようにしている
//    (CloudCombinedRenderer と同じ)。描画は常にメインスレッドで行われる。
//

import UIKit
import DGCharts

nonisolated final class LatestAlignedXAxisRenderer: XAxisRenderer {

    // MARK: - 設定(StockChartView が設定する)

    /// 最新の足のインデックス(ここを基準に左へラベルを置く)。nil の場合は DGCharts 標準の置き方にする。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var latestIndex: Int?

    /// ラベル同士の最小の間隔(pt)。
    /// 0 より大きいと、この間隔を空けて横幅に入るだけラベルを並べる。0 なら axis.labelCount 個くらい並べる。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var labelSpacing: CGFloat = 0

    /// ラベルを置く時刻の分の倍数(nil = 時刻にそろえない)。
    /// 5 なら、5分の倍数のきりのいい間隔で、毎時 15分を基準にした時刻(9:15・9:45 … など)の足に置く(1分足・日中足)。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var minuteMultiple: Int?

    /// X軸に並ぶ日時(古い順。minuteMultiple を使うときに、足の時刻を調べる)。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var dates: [Date] = []

    /// dates の先頭の日時のインデックス(値のある足より前に日時を並べる場合は負の値)。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var firstIndex = 0

    // MARK: - ラベルの位置を決める

    /// X軸ラベルを置く位置(axis.entries = 何本目の足に置くか)を決める。DGCharts が描画のたびに呼ぶ
    /// - Parameters:
    ///   - visibleMin: 画面の左端の位置(何本目か。小数になることもある)
    ///   - visibleMax: 画面の右端の位置(何本目か。小数になることもある)
    override func computeAxisValues(min visibleMin: Double, max visibleMax: Double) {
        // 最新の足が決まっていない(データ設定前)なら、DGCharts 標準の置き方にする
        guard let latestIndex else {
            super.computeAxisValues(min: visibleMin, max: visibleMax)
            return
        }

        // 1分足・日中足(時刻にそろえる場合)は、きりのいい間隔で、毎時 15分を基準にした時刻に置く
        if let minuteMultiple = self.minuteMultiple {
            let indexes = self.minuteLabelIndexes(multiple: minuteMultiple, visibleMin: visibleMin, visibleMax: visibleMax)
            self.setLabelIndexes(indexes)
            return
        }

        // 1. 何本おきに置くかを決める
        guard let step = self.labelStep(visibleMin: visibleMin, visibleMax: visibleMax, latestIndex: latestIndex) else {
            self.setLabelIndexes([])
            return
        }

        // 2. 最新の足から左へ step 本おきに、画面に表示できる足を選ぶ
        let indexes = self.labelIndexes(from: latestIndex, step: step, visibleMin: visibleMin, visibleMax: visibleMax)

        // 3. 選んだ足をラベルの位置として DGCharts に渡す
        self.setLabelIndexes(indexes)
    }

    /// ラベルを置く足を、最新の足から左へ step 本おきに選ぶ
    /// - Returns: ラベルを置く足のインデックス(左から順)
    private func labelIndexes(from latestIndex: Int, step: Int,
                              visibleMin: Double, visibleMax: Double) -> [Double] {
        let leftmostIndex = Int(visibleMin.rounded(.down))  // 画面の左端の足

        var indexes: [Double] = []
        // stride: latestIndex, latestIndex - step, latestIndex - 2 × step, … と左端の足まで戻る
        for index in stride(from: latestIndex, through: leftmostIndex, by: -step) {
            let position = Double(index)
            // 画面の右端より右(スクロールで最新の足が画面外にある場合)は置かない
            if position > visibleMax {
                continue
            }
            // 文字が画面からはみ出す足には置かない
            if !self.labelFitsInChart(at: position) {
                continue
            }
            indexes.append(position)
        }
        // 右から順に集めたので、左から順に並べ直す
        indexes.reverse()

        // 最新の足より右(日付だけを並べる時間帯)にも、同じ間隔で置く(日付のない位置には置かない)
        let rightmostIndex = Int(visibleMax.rounded(.up))
        for index in stride(from: latestIndex + step, through: rightmostIndex, by: step) {
            let position = Double(index)
            if position > visibleMax {
                continue
            }
            if self.labelText(at: position).isEmpty {
                continue
            }
            if !self.labelFitsInChart(at: position) {
                continue
            }
            indexes.append(position)
        }
        return indexes
    }

    // MARK: - 時刻にそろえて置く(1分足・日中足)

    /// 1分足・日中足のラベル同士の最小の間隔(pt)。既存アプリ(XxxCustomChartDateLabelsView)と同じ 5pt
    static let minuteLabelGap: CGFloat = 5
    /// 1分足・日中足のラベルの時刻の基準(分)。間隔が 30分なら :15・:45、60分なら :15 に置く(全体を表示すると 9:15 … 15:15)
    static let minuteLabelAnchor = 15
    /// 画面にこの分数以上が入っているとき(全体表示など)は、ラベルの間隔を最低でも minuteLabelWideInterval にする
    static let minuteLabelWideSpan = 180
    /// 全体表示などのときの、ラベルの間隔の最小値(分)。既存アプリの1分足と同じく、必ず 9:15・9:45 … 15:15 になるようにする
    static let minuteLabelWideInterval = 30

    /// 1分足・日中足のラベルを置く足を選ぶ。
    ///
    ///   1. 間隔(分)を、multiple の倍数のきりのいい分数(5・10・15・30・60・120 …)のうち、
    ///      ラベル同士が重ならない(ラベルの幅 + minuteLabelGap 以上空く)一番短いものにする。
    ///      ただし、画面に 3時間(minuteLabelWideSpan)以上が入っているとき(全体表示など)は、最低でも 30分にする
    ///      (既存アプリの1分足と同じく、幅の広い横画面でも 9:15・9:45 … 15:15 になる。拡大したときだけ細かくする)
    ///   2. 時刻(0時からの分)が「基準(minuteLabelAnchor)+ 間隔の倍数」の足に置く
    ///      例) 間隔 30分: 9:15・9:45・10:15 … 15:15 / 間隔 60分: 9:15・10:15 … 15:15 / 間隔 10分: 9:05・9:15・9:25 …
    ///
    /// 足の本数ではなく時刻で選ぶので、画面の幅に関係なくきりのいい時刻に並び、スクロールしてもラベルの時刻は変わらない。
    /// 昼休みのように間に足がない時間があっても、ずれない
    /// - Returns: ラベルを置く足のインデックス(左から順)
    private func minuteLabelIndexes(multiple: Int, visibleMin: Double, visibleMax: Double) -> [Double] {
        guard multiple > 0 else { return [] }
        guard let transformer else { return [] }
        let leftmostIndex = Int(visibleMin.rounded(.up))
        let rightmostIndex = Int(visibleMax.rounded(.down))
        guard leftmostIndex <= rightmostIndex else { return [] }

        // 画面に出る足の、0時からの分
        var minutesByIndex: [(index: Int, minuteOfDay: Int)] = []
        for index in leftmostIndex...rightmostIndex {
            guard let minuteOfDay = self.minuteOfDay(at: index) else { continue }
            minutesByIndex.append((index: index, minuteOfDay: minuteOfDay))
        }

        // ラベルの幅(画面に出る、multiple の倍数の時刻のラベルの中で一番広いもの)
        var labelWidth: CGFloat = 0
        for item in minutesByIndex where item.minuteOfDay % multiple == 0 {
            labelWidth = max(labelWidth, self.labelWidth(at: Double(item.index)))
        }
        let visibleMinutes = Int((visibleMax - visibleMin) * Double(self.minutesPerCandle()))
        let interval = self.minuteLabelInterval(multiple: multiple, labelWidth: labelWidth, visibleMinutes: visibleMinutes)

        var indexes: [Double] = []
        var previousRight: CGFloat?
        for item in minutesByIndex {
            // 基準からの分が間隔で割り切れる時刻だけ(負の数でも割り切れるかを見るため、余りを 0〜間隔 にそろえる)
            let remainder = ((item.minuteOfDay - Self.minuteLabelAnchor) % interval + interval) % interval
            if remainder != 0 {
                continue
            }
            let position = Double(item.index)
            let centerX = transformer.pixelForValues(x: position, y: 0).x
            // 左端からはみ出すラベルは置かない
            if centerX - labelWidth / 2 < self.viewPortHandler.contentLeft {
                continue
            }
            // 念のため、前のラベルと重なる場合も置かない
            if let previousRight {
                if centerX - labelWidth / 2 <= previousRight + Self.minuteLabelGap {
                    continue
                }
            }
            if !self.labelFitsInChart(at: position) {
                continue
            }
            indexes.append(position)
            previousRight = centerX + labelWidth / 2
        }
        return indexes
    }

    /// ラベルを置く間隔(分)。multiple の倍数のきりのいい分数のうち、ラベル同士が重ならない一番短いもの
    /// (画面に minuteLabelWideSpan 分以上が入っているときは、minuteLabelWideInterval 分より短くしない)
    private func minuteLabelInterval(multiple: Int, labelWidth: CGFloat, visibleMinutes: Int) -> Int {
        var candidates = [1, 2, 3, 6, 12, 24, 36, 48, 72].map { factor in factor * multiple }
        if visibleMinutes >= Self.minuteLabelWideSpan {
            candidates = candidates.filter { candidate in candidate >= Self.minuteLabelWideInterval }
        }
        // 1分あたりの幅(pt) = 足1本の幅 ÷ 足1本の分数
        let pointsPerMinute = self.candleWidthInPoints() / CGFloat(self.minutesPerCandle())
        guard pointsPerMinute > 0 else { return candidates[candidates.count - 1] }
        let requiredWidth = labelWidth + Self.minuteLabelGap
        for candidate in candidates {
            if CGFloat(candidate) * pointsPerMinute > requiredWidth {
                return candidate
            }
        }
        return candidates[candidates.count - 1]
    }

    /// 足1本の分数(1分足は 1、日中足は 5)。隣り合う日時の差のうち一番小さいもの(分からない場合は 1)
    private func minutesPerCandle() -> Int {
        var smallest: Int?
        for index in self.dates.indices.dropFirst() {
            let seconds = self.dates[index].timeIntervalSince(self.dates[index - 1])
            let minutes = Int((seconds / 60).rounded())
            guard minutes > 0 else { continue }
            if let current = smallest {
                smallest = min(current, minutes)
            } else {
                smallest = minutes
            }
        }
        guard let smallest else { return 1 }
        return smallest
    }

    /// 指定した足の、0時からの分。日時がない位置は nil
    private func minuteOfDay(at index: Int) -> Int? {
        let dateIndex = index - self.firstIndex
        guard self.dates.indices.contains(dateIndex) else { return nil }
        let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: self.dates[dateIndex])
        guard let hour = components.hour else { return nil }
        guard let minute = components.minute else { return nil }
        return hour * 60 + minute
    }

    /// ラベルの位置を DGCharts に渡す(ラベルの大きさの計算もし直す)
    private func setLabelIndexes(_ indexes: [Double]) {
        self.axis.entries = indexes
        self.axis.centeredEntries = []
        self.axis.decimals = 0
        self.computeSize()
    }

    // MARK: - 何本おきに置くか

    /// ラベルを何本おきに置くか(1本おき以上)。ラベルを置けない場合は nil
    private func labelStep(visibleMin: Double, visibleMax: Double, latestIndex: Int) -> Int? {
        if self.labelSpacing > 0 {
            return self.labelStepBySpacing(visibleMin: visibleMin, latestIndex: latestIndex)
        }
        return self.labelStepByCount(visibleMin: visibleMin, visibleMax: visibleMax)
    }

    /// 間隔を指定しない場合: 画面に axis.labelCount 個くらい並ぶ本数おき
    /// 例) 画面に 55本、labelCount = 7 → 55 ÷ (7 - 1) = 9.1… → 10本おき
    private func labelStepByCount(visibleMin: Double, visibleMax: Double) -> Int? {
        let visibleCandleCount = visibleMax - visibleMin  // 画面に表示されている本数
        guard visibleCandleCount > 0 else { return nil }

        let labelCount = self.axis.labelCount
        guard labelCount >= 2 else { return nil }

        // ラベルが labelCount 個なら、ラベルとラベルの間は (labelCount - 1) か所
        let step = (visibleCandleCount / Double(labelCount - 1)).rounded(.up)
        return max(1, Int(step))
    }

    /// 間隔を指定した場合: 「日付の文字の幅 + 間隔」が空く、一番少ない本数おき
    /// 例) 足1本の幅 = 18pt、日付の幅 = 26pt、間隔 = 12pt → (26 + 12) ÷ 18 = 2.1… → 3本おき
    private func labelStepBySpacing(visibleMin: Double, latestIndex: Int) -> Int? {
        let candleWidth = self.candleWidthInPoints()
        guard candleWidth > 0 else { return nil }

        // 隣のラベルとの間に必要な幅 = 日付の文字の幅 + 間隔
        let requiredWidth = self.widestLabelWidth(visibleMin: visibleMin, latestIndex: latestIndex) + self.labelSpacing

        // 必要な幅を空けるには、足が何本分あればよいか(切り上げ)
        let step = (requiredWidth / candleWidth).rounded(.up)
        return max(1, Int(step))
    }

    /// 足1本分の幅(pt)。拡大すると広く、縮小すると狭くなる
    private func candleWidthInPoints() -> CGFloat {
        guard let transformer else { return 0 }
        let firstCandleX = transformer.pixelForValues(x: 0, y: 0).x
        let secondCandleX = transformer.pixelForValues(x: 1, y: 0).x
        return secondCandleX - firstCandleX
    }

    /// 画面に出る日付のうち、一番広い文字の幅(pt)。
    /// 日付によって文字の幅が変わる(「9/1」と「10/31」など)ので、画面の左端の足と最新の足を比べて広い方を使う
    private func widestLabelWidth(visibleMin: Double, latestIndex: Int) -> CGFloat {
        let leftmostIndex = max(visibleMin.rounded(.up), 0)
        let leftmostWidth = self.labelWidth(at: leftmostIndex)
        let latestWidth = self.labelWidth(at: Double(latestIndex))
        return max(leftmostWidth, latestWidth)
    }

    // MARK: - ラベルの文字

    /// 指定した足のラベルの文字の幅(pt)
    private func labelWidth(at index: Double) -> CGFloat {
        let text = self.labelText(at: index)
        return (text as NSString).size(withAttributes: [.font: self.axis.labelFont]).width
    }

    /// 指定した足のラベルの文字(日付)
    private func labelText(at index: Double) -> String {
        guard let formatter = self.axis.valueFormatter else { return "" }
        return formatter.stringForValue(index, axis: self.axis)
    }

    /// 指定した足の中心にラベルを描いたとき、チャートの範囲に収まるか。
    /// 左は描画領域の左端まで、右はチャート全体の右端まで(右側の価格ラベルの欄にははみ出してよい)
    private func labelFitsInChart(at index: Double) -> Bool {
        guard let transformer else { return false }

        let halfWidth = self.labelWidth(at: index) / 2
        let centerX = transformer.pixelForValues(x: index, y: 0).x  // 足の中心

        let labelLeft = centerX - halfWidth
        let labelRight = centerX + halfWidth
        if labelLeft < self.viewPortHandler.contentLeft {
            return false
        }
        if labelRight > self.viewPortHandler.chartWidth {
            return false
        }
        return true
    }
}

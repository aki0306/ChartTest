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

        // 1. 何本おきに置くかを決める
        guard let step = labelStep(visibleMin: visibleMin, visibleMax: visibleMax, latestIndex: latestIndex) else {
            setLabelIndexes([])
            return
        }

        // 2. 最新の足から左へ step 本おきに、画面に表示できる足を選ぶ
        let indexes = labelIndexes(from: latestIndex, step: step, visibleMin: visibleMin, visibleMax: visibleMax)

        // 3. 選んだ足をラベルの位置として DGCharts に渡す
        setLabelIndexes(indexes)
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
            if !labelFitsInChart(at: position) {
                continue
            }
            indexes.append(position)
        }
        // 右から順に集めたので、左から順に並べ直す
        return indexes.reversed()
    }

    /// ラベルの位置を DGCharts に渡す(ラベルの大きさの計算もし直す)
    private func setLabelIndexes(_ indexes: [Double]) {
        axis.entries = indexes
        axis.centeredEntries = []
        axis.decimals = 0
        computeSize()
    }

    // MARK: - 何本おきに置くか

    /// ラベルを何本おきに置くか(1本おき以上)。ラベルを置けない場合は nil
    private func labelStep(visibleMin: Double, visibleMax: Double, latestIndex: Int) -> Int? {
        if labelSpacing > 0 {
            return labelStepBySpacing(visibleMin: visibleMin, latestIndex: latestIndex)
        }
        return labelStepByCount(visibleMin: visibleMin, visibleMax: visibleMax)
    }

    /// 間隔を指定しない場合: 画面に axis.labelCount 個くらい並ぶ本数おき
    /// 例) 画面に 55本、labelCount = 7 → 55 ÷ (7 - 1) = 9.1… → 10本おき
    private func labelStepByCount(visibleMin: Double, visibleMax: Double) -> Int? {
        let visibleCandleCount = visibleMax - visibleMin  // 画面に表示されている本数
        guard visibleCandleCount > 0 else { return nil }

        let labelCount = axis.labelCount
        guard labelCount >= 2 else { return nil }

        // ラベルが labelCount 個なら、ラベルとラベルの間は (labelCount - 1) か所
        let step = (visibleCandleCount / Double(labelCount - 1)).rounded(.up)
        return max(1, Int(step))
    }

    /// 間隔を指定した場合: 「日付の文字の幅 + 間隔」が空く、一番少ない本数おき
    /// 例) 足1本の幅 = 18pt、日付の幅 = 26pt、間隔 = 12pt → (26 + 12) ÷ 18 = 2.1… → 3本おき
    private func labelStepBySpacing(visibleMin: Double, latestIndex: Int) -> Int? {
        let candleWidth = candleWidthInPoints()
        guard candleWidth > 0 else { return nil }

        // 隣のラベルとの間に必要な幅 = 日付の文字の幅 + 間隔
        let requiredWidth = widestLabelWidth(visibleMin: visibleMin, latestIndex: latestIndex) + labelSpacing

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
        let leftmostWidth = labelWidth(at: leftmostIndex)
        let latestWidth = labelWidth(at: Double(latestIndex))
        return max(leftmostWidth, latestWidth)
    }

    // MARK: - ラベルの文字

    /// 指定した足のラベルの文字の幅(pt)
    private func labelWidth(at index: Double) -> CGFloat {
        let text = labelText(at: index)
        return (text as NSString).size(withAttributes: [.font: axis.labelFont]).width
    }

    /// 指定した足のラベルの文字(日付)
    private func labelText(at index: Double) -> String {
        guard let formatter = axis.valueFormatter else { return "" }
        return formatter.stringForValue(index, axis: axis)
    }

    /// 指定した足の中心にラベルを描いたとき、チャートの範囲に収まるか。
    /// 左は描画領域の左端まで、右はチャート全体の右端まで(右側の価格ラベルの欄にははみ出してよい)
    private func labelFitsInChart(at index: Double) -> Bool {
        guard let transformer else { return false }

        let halfWidth = labelWidth(at: index) / 2
        let centerX = transformer.pixelForValues(x: index, y: 0).x  // 足の中心

        let labelLeft = centerX - halfWidth
        let labelRight = centerX + halfWidth
        if labelLeft < viewPortHandler.contentLeft {
            return false
        }
        if labelRight > viewPortHandler.chartWidth {
            return false
        }
        return true
    }
}

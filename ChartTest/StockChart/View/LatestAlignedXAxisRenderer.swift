//
//  LatestAlignedXAxisRenderer.swift
//  ChartTest
//
//  【View】X軸ラベル(日付)を「最新の足」を基準に並べる描画処理。
//
//  DGCharts 標準では、ラベルは 0, 10, 20, … のような「きりのいい位置」に置かれるため、
//  一番右(最新)の足にラベルが来るとは限らない。
//  このクラスでは、最新の足から左へ同じ間隔でラベルを置くので、右端までスクロールしている状態では
//  一番右のラベルが最新の日付になる。
//
//     7/16   7/29   8/10   8/21   9/2   9/14   9/29
//                                               ↑ 最新の足
//      ←── interval ──→ ずつ左へ置いていく
//
//  ・間隔(interval)の決め方は2通り
//      labelSpacing = 0 : 画面に axis.labelCount 個くらい並ぶ本数おき
//      labelSpacing > 0 : ラベルの文字の幅 + labelSpacing が空く、一番少ない本数おき(幅に入るだけ並べる)
//  ・ラベルは足に固定されるので、スクロールしてもラベルが足からずれない
//    (間隔は表示本数から決めるので、ズームしたときだけ変わる)
//  ・中心に置くと画面からはみ出すラベルは、ずらさずに表示しない(隣のラベルと重ならないように)
//
//  ※ このプロジェクトは既定のアクター分離が MainActor だが、継承元の XAxisRenderer は
//    アクター分離なしで宣言されているため、クラスを nonisolated にして override できるようにしている
//    (CloudCombinedRenderer と同じ)。描画は常にメインスレッドで行われる。
//

import UIKit
import DGCharts

nonisolated final class LatestAlignedXAxisRenderer: XAxisRenderer {

    /// 最新の足のインデックス(ここを基準に左へラベルを置く)。nil の場合は DGCharts 標準の置き方にする。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var latestIndex: Int?
    /// ラベル同士の最小の間隔(pt)。0 より大きいと、幅に入るだけラベルを並べる(0 なら axis.labelCount 個くらい)。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var labelSpacing: CGFloat = 0

    /// X軸ラベルを置く位置(axis.entries)を決める。DGCharts が描画のたびに呼ぶ
    /// - Parameters:
    ///   - visibleMin: 画面の左端の X軸の値(何本目か。小数)
    ///   - visibleMax: 画面の右端の X軸の値(何本目か。小数)
    override func computeAxisValues(min visibleMin: Double, max visibleMax: Double) {
        guard let latestIndex else {
            super.computeAxisValues(min: visibleMin, max: visibleMax)
            return
        }

        guard let interval = labelInterval(min: visibleMin, max: visibleMax, latestIndex: latestIndex) else {
            axis.entries = []
            axis.centeredEntries = []
            computeSize()
            return
        }

        // 最新の足から左へ interval ずつ戻りながら、画面内に収まるものだけをラベルにする
        var entries: [Double] = []
        var index = Double(latestIndex)
        while index >= visibleMin.rounded(.down) {
            let isVisible = index <= visibleMax
            if isVisible, labelFitsInChart(at: index) {
                entries.insert(index, at: 0)  // 左から順に並ぶよう、先頭に入れる
            }
            index -= interval
        }

        axis.entries = entries
        axis.centeredEntries = []
        axis.decimals = 0
        computeSize()
    }

    /// ラベルの間隔(何本おきか。1本未満にはしない)。ラベルを置けない場合は nil
    private func labelInterval(min visibleMin: Double, max visibleMax: Double, latestIndex: Int) -> Double? {
        let visibleWidth = visibleMax - visibleMin
        guard visibleWidth > 0 else { return nil }

        // 間隔の指定あり: 「ラベルの文字の幅 + 間隔」が空く本数おき
        if labelSpacing > 0 {
            guard let transformer else { return nil }
            // 足1本分の幅(pt)
            let candleWidth = transformer.pixelForValues(x: 1, y: 0).x - transformer.pixelForValues(x: 0, y: 0).x
            guard candleWidth > 0 else { return nil }
            // ラベルの文字の幅。日付によって幅が変わる(9/1 と 10/31 など)ので、画面の左端・右端の足の広い方を使う
            let leftWidth = labelWidth(at: max(visibleMin.rounded(.up), 0))
            let rightWidth = labelWidth(at: Double(latestIndex))
            let needed = max(leftWidth, rightWidth) + labelSpacing
            return max(1, (needed / candleWidth).rounded(.up))
        }

        // 間隔の指定なし: 画面の幅に labelCount 個くらい並ぶ本数おき
        let labelCount = axis.labelCount
        guard labelCount >= 2 else { return nil }
        return max(1, (visibleWidth / Double(labelCount - 1)).rounded(.up))
    }

    /// 指定した足のラベルの文字の幅
    private func labelWidth(at index: Double) -> CGFloat {
        let text = axis.valueFormatter?.stringForValue(index, axis: axis) ?? ""
        return (text as NSString).size(withAttributes: [.font: axis.labelFont]).width
    }

    /// 指定した足の位置を中心にラベルを描いたとき、チャートの範囲(左端〜Y軸ラベル領域の右端)に収まるか
    private func labelFitsInChart(at index: Double) -> Bool {
        guard let transformer else { return false }

        // ラベルの文字の幅
        let width = labelWidth(at: index)

        // ラベルの中心の X(足の中心)
        let centerX = transformer.pixelForValues(x: index, y: 0).x

        // 左は描画領域の左端、右はチャート全体の右端(右側の Y軸ラベル領域まではみ出してよい)
        let fitsLeft = centerX - width / 2 >= viewPortHandler.contentLeft
        let fitsRight = centerX + width / 2 <= viewPortHandler.chartWidth
        return fitsLeft && fitsRight
    }
}

//
//  LatestAlignedXAxisRenderer.swift
//  ChartTest
//
//  【View】X軸ラベル(日付)を、どの足の下に表示するかを決める描画処理。
//
//  ■ 日足・週足・月足(通常のモード)
//    1. 何本おきに置くか(skip)を、拡大・縮小したときだけ決め直す(スクロールでは変えない)
//         上限の個数 = 表示幅 ÷ 一番長い日付の幅 × 0.618
//         skip       = 表示している本数 ÷ 上限の個数(小数は切り捨て)
//       一番長い日付の幅は、「1970/10/10 10:10」を足種の書式で表した文字(「10/10」「70/10/10」「1970/10」)の幅
//    2. 基準の足(スクロールできる範囲の右端 = 最新の足。一目均衡表では先行スパンの右端)から skip 本おきの足に置く
//         例) 最新の足が 199 本目、skip = 3 → 199, 196, 193, … 本目
//       skip が 0(拡大して表示本数が上限の個数より少ない)のときは、基準の足にだけ置く
//    3. 左から順に、前のラベルと重なる(ラベルの中心の間が一番長い日付の幅以下)ラベルと、左端からはみ出すラベルは置かない
//
//       7/16   7/29   8/10   8/21   9/2   9/14   9/25
//                                                 ↑ 基準の足
//
//  ■ 1分足・日中足(5分のモード。minuteMultiple = 5)
//    時刻が 5分ちょうど(9:00・9:05 …)の足だけを候補にして、左から順に、
//    前のラベルとの間が「一番長い日付の幅 + 5pt」より空く足に置く(並ぶ時刻は画面の幅と表示範囲で変わる)
//
//  ■ そのほかの決まり
//    ・ラベルは足に固定されるので、スクロールしてもラベルが足からずれない
//    ・日付のない位置(前後の余白・一目均衡表の先行スパンの先)には置かない
//    ・右端は、はみ出してもよい(右の価格ラベルの欄にかかってもよい)
//
//  ※ このプロジェクトは既定のアクター分離が MainActor だが、継承元の XAxisRenderer は
//    アクター分離なしで宣言されているため、クラスを nonisolated にして override できるようにしている
//    (CloudCombinedRenderer と同じ)。描画は常にメインスレッドで行われる。
//

import UIKit
import DGCharts

nonisolated final class LatestAlignedXAxisRenderer: XAxisRenderer {

    // MARK: - 設定(StockChartView が設定する)

    /// ラベルを並べる基準の足のインデックス(スクロールできる範囲の右端)。nil の場合は DGCharts 標準の置き方にする。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var anchorIndex: Int?

    /// 5分のモードにするときの分の倍数(nil = 通常のモード)。1分足・日中足は 5。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var minuteMultiple: Int?

    /// X軸に並ぶ日時(古い順。5分のモードで、足の時刻を調べるのに使う)。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var dates: [Date] = []

    /// dates の先頭の日時のインデックス(値のある足より前に日時を並べる場合は負の値)。
    /// メインスレッドからのみ読み書きする
    nonisolated(unsafe) var firstIndex = 0

    // MARK: - 状態

    /// 何本おきにラベルを置くか(初期値は 5)。拡大・縮小したときだけ決め直す
    nonisolated(unsafe) private var skip = 5
    /// skip を決めたときの表示幅(本数)。これが変わったら(拡大・縮小したら)skip を決め直す
    nonisolated(unsafe) private var skipVisibleSpan: Double?

    /// 上限の個数を決めるときに掛ける割合(0.618)
    static let maxLabelRatio: CGFloat = 0.618
    /// 5分のモードで、ラベル同士の間に空ける幅(pt)。5pt
    static let minuteLabelGap: CGFloat = 5
    /// 拡大・縮小したとみなす表示幅の変化(本数)。0.01
    static let zoomThreshold = 0.01

    // MARK: - ラベルの位置を決める

    /// X軸ラベルを置く位置(axis.entries = 何本目の足に置くか)を決める。DGCharts が描画のたびに呼ぶ
    /// - Parameters:
    ///   - visibleMin: 画面の左端の位置(何本目か。小数になることもある)
    ///   - visibleMax: 画面の右端の位置(何本目か。小数になることもある)
    override func computeAxisValues(min visibleMin: Double, max visibleMax: Double) {
        // 基準の足が決まっていない(データ設定前)なら、DGCharts 標準の置き方にする
        guard let anchorIndex else {
            super.computeAxisValues(min: visibleMin, max: visibleMax)
            return
        }
        let maxLabelWidth = self.maxLabelWidth()
        let firstVisibleIndex = Int(visibleMin.rounded())
        let lastVisibleIndex = Int(visibleMax.rounded())
        guard maxLabelWidth > 0 else {
            self.setLabelIndexes([])
            return
        }
        guard firstVisibleIndex <= lastVisibleIndex else {
            self.setLabelIndexes([])
            return
        }

        if let minuteMultiple = self.minuteMultiple {
            let indexes = self.minuteLabelIndexes(multiple: minuteMultiple, from: firstVisibleIndex, to: lastVisibleIndex,
                                                  maxLabelWidth: maxLabelWidth)
            self.setLabelIndexes(indexes)
            return
        }

        self.updateSkip(visibleMin: visibleMin, visibleMax: visibleMax, maxLabelWidth: maxLabelWidth)
        let indexes = self.normalLabelIndexes(anchorIndex: anchorIndex, from: firstVisibleIndex, to: lastVisibleIndex,
                                              maxLabelWidth: maxLabelWidth)
        self.setLabelIndexes(indexes)
    }

    // MARK: - 通常のモード(日足・週足・月足)

    /// 拡大・縮小した(表示幅が変わった)ときだけ、何本おきに置くか(skip)を決め直す。スクロールでは変えない
    ///   上限の個数 = 表示幅 ÷ 一番長い日付の幅 × 0.618、skip = 表示している本数 ÷ 上限の個数(切り捨て)
    private func updateSkip(visibleMin: Double, visibleMax: Double, maxLabelWidth: CGFloat) {
        let span = visibleMax - visibleMin
        if let skipVisibleSpan {
            if abs(span - skipVisibleSpan) <= Self.zoomThreshold {
                return
            }
        }
        self.skipVisibleSpan = span

        let visibleCount = Int(visibleMax.rounded()) - Int(visibleMin.rounded()) + 1
        let maxLabelCount = Int(self.viewPortHandler.contentWidth / maxLabelWidth * Self.maxLabelRatio)
        // 上限の個数が 0 のときは 0 にする
        if maxLabelCount <= 0 {
            self.skip = 0
            return
        }
        self.skip = visibleCount / maxLabelCount
    }

    /// 通常のモードで、ラベルを置く足を選ぶ(左から順)
    private func normalLabelIndexes(anchorIndex: Int, from firstIndex: Int, to lastIndex: Int,
                                    maxLabelWidth: CGFloat) -> [Double] {
        guard let transformer else {
            return []
        }
        var indexes: [Double] = []
        var previousRight: CGFloat?
        for index in firstIndex...lastIndex {
            // 基準の足から skip 本おきの足だけ
            if !self.isOnSkip(index, anchorIndex: anchorIndex) {
                continue
            }
            let text = self.labelText(at: Double(index))
            // 日付のない位置(前後の余白など)には置かない
            if text.isEmpty {
                continue
            }
            let centerX = transformer.pixelForValues(x: Double(index), y: 0).x
            // 左端からはみ出すラベルは置かない(右端は、はみ出してもよい)
            if centerX - self.textWidth(text) / 2 < self.viewPortHandler.contentLeft {
                continue
            }
            // 前のラベルと重なる場合は置かない(ラベルの中心の間が一番長い日付の幅以下)
            if let previousRight {
                if centerX - maxLabelWidth / 2 <= previousRight {
                    continue
                }
            }
            indexes.append(Double(index))
            previousRight = centerX + maxLabelWidth / 2
        }
        return indexes
    }

    /// 指定した足が、基準の足から skip 本おきの足か(skip が 0 のときは基準の足だけ)
    private func isOnSkip(_ index: Int, anchorIndex: Int) -> Bool {
        if self.skip <= 0 {
            return index == anchorIndex
        }
        // 基準の足との差が skip で割り切れるか。
        // 基準の足より左の足は差がマイナスになるが、Swift の % は割り切れればマイナスでも 0 になる(例: -6 % 3 = 0)
        let remainder = (index - anchorIndex) % self.skip
        return remainder == 0
    }

    // MARK: - 5分のモード(1分足・日中足)

    /// 5分のモードで、ラベルを置く足を選ぶ(左から順)。
    /// 時刻が multiple 分ちょうどの足を、左から順に、前のラベルとの間が「一番長い日付の幅 + 5pt」より空く足に置く
    private func minuteLabelIndexes(multiple: Int, from firstIndex: Int, to lastIndex: Int,
                                    maxLabelWidth: CGFloat) -> [Double] {
        guard multiple > 0 else {
            return []
        }
        guard let transformer else {
            return []
        }
        var indexes: [Double] = []
        var previousRight: CGFloat?
        for index in firstIndex...lastIndex {
            // 日時のない位置には置かない
            guard let minute = self.minute(at: index) else {
                continue
            }
            if minute % multiple != 0 {
                continue
            }
            let text = self.labelText(at: Double(index))
            if text.isEmpty {
                continue
            }
            let centerX = transformer.pixelForValues(x: Double(index), y: 0).x
            if centerX - self.textWidth(text) / 2 < self.viewPortHandler.contentLeft {
                continue
            }
            if let previousRight {
                if centerX - maxLabelWidth / 2 <= previousRight + Self.minuteLabelGap {
                    continue
                }
            }
            indexes.append(Double(index))
            previousRight = centerX + maxLabelWidth / 2
        }
        return indexes
    }

    /// 指定した足の時刻の「分」(0〜59)。日時がない位置は nil
    private func minute(at index: Int) -> Int? {
        let dateIndex = index - self.firstIndex
        guard self.dates.indices.contains(dateIndex) else {
            return nil
        }
        return Calendar(identifier: .gregorian).component(.minute, from: self.dates[dateIndex])
    }

    // MARK: - ラベルの文字

    /// ラベルの位置を DGCharts に渡す(ラベルの大きさの計算もし直す)
    private func setLabelIndexes(_ indexes: [Double]) {
        self.axis.entries = indexes
        self.axis.centeredEntries = []
        self.axis.decimals = 0
        self.computeSize()
    }

    /// 一番長い日付の幅(pt)。「1970/10/10 10:10」を足種の書式で表した文字の幅
    private func maxLabelWidth() -> CGFloat {
        guard let formatter = self.axis.valueFormatter as? DateAxisValueFormatter else {
            return 0
        }
        return self.textWidth(formatter.widestSampleText)
    }

    /// 文字の幅(pt)
    private func textWidth(_ text: String) -> CGFloat {
        let size = (text as NSString).size(withAttributes: [.font: self.axis.labelFont])
        // 幅は小数になるので、切り上げて整数にする(文字が欠けない側に寄せる)
        return size.width.rounded(.up)
    }

    /// 指定した足のラベルの文字(日付)
    private func labelText(at index: Double) -> String {
        guard let formatter = self.axis.valueFormatter else {
            return ""
        }
        return formatter.stringForValue(index, axis: self.axis)
    }
}

//
//  OHLCInfoView.swift
//  ChartTest
//
//  【View】「4本値」表示用の部品のうち、選択中の足の日付・始値・高値・安値・終値を表示する枠。
//  十字線を動かしている間、チャートの右上に表示される。
//
//            ↓上 6pt
//    ┌──────────────────────────────┐
//    │          2026/04/06          │ ← dateLabel(日付。中央寄せ)
//    │ 始値：53413.68  高値：56924.11 │ ← upperLabel
//    │ 安値：53413.68  終値：56924.11 │ ← lowerLabel
//    └──────────────────────────────┘
//    ←→左右 10pt     ↑下 6pt         行と行の間は 2pt
//
//  ・大きさは中身の文字から自動で決まる(StockChartView+Crosshair の showOHLCInfo で測る)
//  ・置く位置も StockChartView+Crosshair が決める。ここでは渡された値を表示するだけ
//  ・色は StockChartColors.xcassets の ChartOHLCBackground(背景)・ChartOHLCText(文字)
//

import UIKit

/// 日付と4本値(始値・高値・安値・終値)を表示する半透明の枠
final class OHLCInfoView: UIView {

    // MARK: - 見た目

    /// 枠の内側の余白(上下 6pt・左右 10pt)
    private let padding = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
    /// 行と行の間隔
    private let lineSpacing: CGFloat = 2
    /// 枠の角の丸み
    private let cornerRadius: CGFloat = 6
    /// 日付の文字(13pt・やや太字)
    private let dateFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
    /// 4本値の文字(12pt)。数字の幅がそろう書体にして、値が変わっても文字の位置がずれないようにする
    private let valueFont = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)

    // MARK: - 部品

    /// 1行目: 日付
    private let dateLabel = UILabel()
    /// 2行目: 「始値：… 高値：…」
    private let upperLabel = UILabel()
    /// 3行目: 「安値：… 終値：…」
    private let lowerLabel = UILabel()

    /// 日付の書式(足種ごとに変わる。例: 日足 2026/04/06、月足 2026/04、1分足 09:15)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    // MARK: - 初期化

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    /// 枠の見た目を設定し、3行のラベルを縦に並べる
    private func setup() {
        // 表示するだけの枠なので、タッチは下のチャートに通す
        self.isUserInteractionEnabled = false
        self.backgroundColor = UIColor(resource: .chartOHLCBackground)
        self.layer.cornerRadius = self.cornerRadius

        self.dateLabel.font = self.dateFont
        self.dateLabel.textAlignment = .center
        self.upperLabel.font = self.valueFont
        self.lowerLabel.font = self.valueFont
        for label in [self.dateLabel, self.upperLabel, self.lowerLabel] {
            label.textColor = UIColor(resource: .chartOHLCText)
        }

        let stack = UIStackView(arrangedSubviews: [self.dateLabel, self.upperLabel, self.lowerLabel])
        stack.axis = .vertical
        stack.spacing = self.lineSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.topAnchor, constant: self.padding.top),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -self.padding.bottom),
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: self.padding.left),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -self.padding.right),
        ])
    }

    // MARK: - 表示する内容

    /// 表示する内容を変える。値のない日時は空欄にする。
    /// 価格は3桁区切りなし・小数は必要な桁だけ(最大2桁)。例: 6230・5519.11
    /// - Parameters:
    ///   - date: 日時(nil なら日付も空欄)
    ///   - candle: 値のある足(nil なら4本値を空欄にする)
    ///   - dateFormat: 日付の書式(StockChartStyle.ohlcDateFormat)
    func update(date: Date?, candle: StockCandle?, dateFormat: String) {
        self.dateFormatter.dateFormat = dateFormat
        var dateText = ""
        if let date {
            dateText = self.dateFormatter.string(from: date)
        }
        self.dateLabel.text = dateText

        let open = self.priceText(candle?.open)
        let high = self.priceText(candle?.high)
        let low = self.priceText(candle?.low)
        let close = self.priceText(candle?.close)
        self.upperLabel.text = "始値：\(open)  高値：\(high)"
        self.lowerLabel.text = "安値：\(low)  終値：\(close)"
    }

    /// 価格の文字(nil なら空欄)
    private func priceText(_ value: Double?) -> String {
        guard let value else {
            return ""
        }
        return ChartNumberFormatter.plainValue(value)
    }
}

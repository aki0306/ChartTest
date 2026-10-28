//
//  OHLCInfoView.swift
//  ChartTest
//
//  【View】「4本値」表示用の部品のうち、選択中の足の日付・始値・高値・安値・終値を表示する枠。
//  十字線を動かしている間、チャートの右上に表示される。
//  枠(角の丸い背景と、日付の下の白い線)は画像で、その上に文字を載せる。
//
//    ┌──────────────────────────────┐
//    │          2026/04/06          │ ← dateLabel(日付。上から 22pt の欄の中で上下・左右の中央)
//    │  ──────────────────────────  │ ← 白い線(画像。上から 22pt)
//    │ 始値：53413.68  高値：56924.11 │ ← openLabel・highLabel(白い線の 3pt 下から)
//    │ 安値：53413.68  終値：56924.11 │ ← lowLabel・closeLabel
//    └──────────────────────────────┘
//    ←→左右 10pt     ↑下 6pt         行と行の間は 2pt、左の列(始値・安値)と右の列(高値・終値)の間は 8pt
//
//  ・大きさは中身の文字から自動で決まる(CrosshairOverlayView の showOHLCInfo で測る)
//  ・置く位置も CrosshairOverlayView が決める。ここでは渡された値を表示するだけ
//
//  【レイアウト】OHLCInfoView.xib(Interface Builder で開いて編集する)
//  XIB の File's Owner をこのクラスにしてあり、XIB を読み込むと、中のラベルがこのクラスの @IBOutlet につながる。
//  読み込んだ Content View(枠全体)を、この View いっぱいに貼り付けている(ChartFooterView と同じ作り)。
//  ・背景は画像 ChartOHLCInfoBackground(StockChartColors.xcassets)。角と白い線の高さを崩さないよう、
//    上 30pt・下 10pt・左右 10pt を伸ばさない設定(Assets の Slicing)にしてあり、枠の大きさに合わせて真ん中だけ伸びる
//  ・日付の欄の高さ(22pt = 白い線の位置)・余白・行間・フォント・文字の色(ChartOHLCText)も XIB で決める。
//    画像を差し替えて白い線の位置が変わったら、XIB の日付の欄の高さを合わせる
//  ・下端・右端の余白の制約は、必須より少し弱く(999)してある。
//    この枠は最初は大きさ 0 のまま隠しておく(位置と大きさは表示するときに frame で決める)ので、
//    必須のままだと「大きさ 0」と「上下左右の余白」を両方は満たせず、制約の警告が出るため。
//    大きさを決めるとき(systemLayoutSizeFitting)は、この制約どおりの大きさになる
//

import UIKit

/// 日付と4本値(始値・高値・安値・終値)を表示する半透明の枠
final class OHLCInfoView: UIView {

    // MARK: - XIB の部品(XIB の File's Owner から接続)

    /// OHLCInfoView.xib(枠の配置が入っている)
    private static let nib = UINib(nibName: "OHLCInfoView", bundle: Bundle(for: OHLCInfoView.self))

    /// XIB の Content View(枠全体。この View いっぱいに貼り付ける)。
    /// XIB の一番外側の View は、読み込んだ直後はどこからも持たれていないので、解放されないよう strong で持つ
    @IBOutlet private var contentView: UIView!
    /// 1行目: 日付
    @IBOutlet private weak var dateLabel: UILabel!
    /// 2行目・左: 「始値：…」
    @IBOutlet private weak var openLabel: UILabel!
    /// 2行目・右: 「高値：…」
    @IBOutlet private weak var highLabel: UILabel!
    /// 3行目・左: 「安値：…」
    @IBOutlet private weak var lowLabel: UILabel!
    /// 3行目・右: 「終値：…」
    @IBOutlet private weak var closeLabel: UILabel!

    /// 日付の書式(足種ごとに変わる。例: 日足 2026/04/06、月足 2026/04、1分足 09:15)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    // MARK: - 初期化

    /// コードから生成された場合
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    /// Storyboard / XIB から生成された場合
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    /// XIB を読み込み、Content View を この View いっぱいに貼り付ける
    private func setup() {
        // 自分を File's Owner にして読み込むと、XIB の部品が @IBOutlet につながる
        _ = Self.nib.instantiate(withOwner: self)
        guard self.contentView != nil else {
            // XIB の File's Owner から Content View が接続されていない(設定ミス)。すぐ気付けるよう落とす
            fatalError("OHLCInfoView.xib の File's Owner に contentView が接続されていません")
        }

        // 表示するだけの枠なので、タッチは下のチャートに通す
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear  // 背景は XIB の画像で描く
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.contentView)
        NSLayoutConstraint.activate([
            self.contentView.topAnchor.constraint(equalTo: self.topAnchor),
            self.contentView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.contentView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.contentView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
        ])

        // 4本値の文字は、数字の幅がそろう書体にして、値が変わっても文字の位置がずれないようにする。
        // XIB では指定できないので、XIB の文字の大きさのままここで変える
        for label in [self.openLabel, self.highLabel, self.lowLabel, self.closeLabel] {
            guard let label else {
                continue
            }
            label.font = .monospacedDigitSystemFont(ofSize: label.font.pointSize, weight: .regular)
        }
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

        self.openLabel.text = "始値：\(self.priceText(candle?.open))"
        self.highLabel.text = "高値：\(self.priceText(candle?.high))"
        self.lowLabel.text = "安値：\(self.priceText(candle?.low))"
        self.closeLabel.text = "終値：\(self.priceText(candle?.close))"
    }

    /// 価格の文字(nil なら空欄)
    private func priceText(_ value: Double?) -> String {
        guard let value else {
            return ""
        }
        return ChartNumberFormatter.plainValue(value)
    }
}

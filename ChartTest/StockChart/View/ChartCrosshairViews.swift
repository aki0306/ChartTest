//
//  ChartCrosshairViews.swift
//  ChartTest
//
//  【View】「4本値」表示用の部品。
//
//  ・CrosshairOverlayView: 十字線(縦線 + 横線)を描く
//  ・OHLCInfoView: 選択中の足の日付・始値・高値・安値・終値を表示する枠
//  ・CrosshairMarkerLabel: 横線の値(グレーの六角形)・縦線と横線の位置を指す赤い矢印のマーカー
//
//    ┌──────────────────────────────┐
//    │          2026/04/06          │
//    │ 始値：53,413.68  高値：56,924.11 │
//    │ 安値：53,413.68  終値：56,924.11 │
//    └──────────────────────────────┘
//
//  位置の計算は StockChartView が行い、ここでは渡された座標・値を描くだけ。
//

import UIKit

// MARK: - 十字線

/// 十字線(縦線 + 横線)を描くView。タッチは下のチャートに通す
final class CrosshairOverlayView: UIView {

    /// 縦線
    private let verticalLine = CAShapeLayer()
    /// 横線
    private let horizontalLine = CAShapeLayer()

    /// 線の色
    var lineColor: UIColor = .black {
        didSet { self.applyLineStyle() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    private func setup() {
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
        for line in [self.verticalLine, self.horizontalLine] {
            self.layer.addSublayer(line)
        }
        self.applyLineStyle()
        self.hide()
    }

    /// 線の色・太さを設定する(実線)
    private func applyLineStyle() {
        for line in [self.verticalLine, self.horizontalLine] {
            line.strokeColor = self.lineColor.cgColor
            line.lineWidth = 1
            line.lineDashPattern = nil  // 破線にせず、実線で引く
            line.fillColor = nil
        }
    }

    /// 十字線を表示する(座標はこのViewの座標系)
    /// - Parameters:
    ///   - x: 縦線の X 座標。nil の場合は縦線を描かない
    ///   - verticalRange: 縦線を引く Y の範囲
    ///   - y: 横線の Y 座標。nil の場合は横線を描かない
    ///   - horizontalRange: 横線を引く X の範囲
    func show(x: CGFloat?, verticalRange: ClosedRange<CGFloat>,
              y: CGFloat?, horizontalRange: ClosedRange<CGFloat>) {
        // 暗黙のアニメーションで線が遅れて動かないよう、アニメーションを無効にして更新する
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // 縦線: (x, 上端) から (x, 下端) まで
        if let x {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: x, y: verticalRange.lowerBound))
            path.addLine(to: CGPoint(x: x, y: verticalRange.upperBound))
            self.verticalLine.path = path.cgPath
        } else {
            self.verticalLine.path = nil
        }

        // 横線: (左端, y) から (右端, y) まで
        if let y {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: horizontalRange.lowerBound, y: y))
            path.addLine(to: CGPoint(x: horizontalRange.upperBound, y: y))
            self.horizontalLine.path = path.cgPath
        } else {
            self.horizontalLine.path = nil
        }

        CATransaction.commit()
    }

    /// 十字線を消す
    func hide() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.verticalLine.path = nil
        self.horizontalLine.path = nil
        CATransaction.commit()
    }
}

// MARK: - 4本値の枠

/// 日付と4本値(始値・高値・安値・終値)を表示する半透明の枠
final class OHLCInfoView: UIView {

    /// 日付
    private let dateLabel = UILabel()
    /// 「始値：… 高値：…」
    private let upperLabel = UILabel()
    /// 「安値：… 終値：…」
    private let lowerLabel = UILabel()

    /// 日付の書式(例: 2026/04/06)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    /// 価格の書式(3桁カンマ区切り・小数2桁)
    private let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    /// 3行のラベルを縦に並べる
    private func setup() {
        self.isUserInteractionEnabled = false
        self.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        self.layer.cornerRadius = 6

        self.dateLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        self.dateLabel.textAlignment = .center
        for label in [self.upperLabel, self.lowerLabel] {
            // 数字の幅をそろえる(値が変わっても文字の位置がずれないように)
            label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        }
        for label in [self.dateLabel, self.upperLabel, self.lowerLabel] {
            label.textColor = .white
        }

        let stack = UIStackView(arrangedSubviews: [self.dateLabel, self.upperLabel, self.lowerLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -10),
        ])
    }

    /// 表示する足を設定する
    func update(with candle: StockCandle) {
        self.dateLabel.text = self.dateFormatter.string(from: candle.date)
        self.upperLabel.text = "始値：\(self.format(candle.open))  高値：\(self.format(candle.high))"
        self.lowerLabel.text = "安値：\(self.format(candle.low))  終値：\(self.format(candle.close))"
    }

    /// 価格を文字列にする
    private func format(_ value: Double) -> String {
        self.priceFormatter.string(from: NSNumber(value: value)) ?? ""
    }
}

// MARK: - 十字線のマーカー

/// 十字線に付けるマーカー(形付きの背景 + 文字)。
///
///   hexagon  : ＜ 60,660.98 ＞   横線の値(外枠の左端寄り)
///   arrowUp  :    /\             縦線の位置を示す、日付ラベルの欄の矢印(文字なし)
///               |  |
///   arrowLeft:  ◀■               横線の位置を示す、Y軸側の矢印(文字なし)
///
/// backgroundImage を設定すると、形を塗る代わりに画像を描く
final class CrosshairMarkerLabel: UILabel {

    /// マーカーの形
    enum Shape {
        /// 左右が尖った六角形
        case hexagon
        /// 上向きの矢印(五角形)
        case arrowUp
        /// 左向きの矢印(五角形)
        case arrowLeft
    }

    /// マーカーの形
    let shape: Shape
    /// 背景の塗り色
    var fillColor: UIColor = .darkGray {
        didSet { self.setNeedsDisplay() }
    }
    /// 背景の画像。設定すると、形を fillColor で塗る代わりにこの画像を描く(nil なら形を塗る)。
    /// 文字ありの場合は文字の大きさに合わせて伸ばすので、伸ばしたくない部分は
    /// resizableImage(withCapInsets:resizingMode:) で指定した画像を渡す
    var backgroundImage: UIImage? {
        didSet {
            self.invalidateIntrinsicContentSize()
            self.setNeedsDisplay()
        }
    }

    /// 矢印の尖った部分の長さ
    private let tipLength: CGFloat = 6

    /// 文字の周りの余白(形に合わせて尖った部分のぶんを空ける)
    private var padding: UIEdgeInsets {
        switch self.shape {
        case .hexagon: return UIEdgeInsets(top: 3, left: 12, bottom: 3, right: 12)
        case .arrowUp: return UIEdgeInsets(top: 1 + self.tipLength, left: 6, bottom: 1, right: 6)
        case .arrowLeft: return UIEdgeInsets(top: 3, left: 4 + self.tipLength, bottom: 3, right: 4)
        }
    }

    init(shape: Shape) {
        self.shape = shape
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear  // 背景は draw で形に沿って塗る
        self.textColor = .white
        self.textAlignment = .center
        self.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// マーカーの大きさ
    ///   ・文字なし・画像あり: 画像の大きさそのまま
    ///   ・それ以外: 中身(文字、または文字なしの固定サイズ)+ 余白。画像ありなら画像より小さくしない
    override var intrinsicContentSize: CGSize {
        let hasText = !(self.text ?? "").isEmpty
        if !hasText {
            if let backgroundImage {
                return backgroundImage.size
            }
        }

        // 中身の大きさ: 文字ありなら文字の大きさ、文字なしなら形ごとの固定サイズ
        var contentSize = super.intrinsicContentSize
        if !hasText {
            contentSize = self.noTextContentSize
        }
        var size = CGSize(width: contentSize.width + self.padding.left + self.padding.right,
                          height: contentSize.height + self.padding.top + self.padding.bottom)

        // 画像ありなら、画像より小さくはしない(文字が短くても画像の形が崩れないように)
        if let backgroundImage {
            size.width = max(size.width, backgroundImage.size.width)
            size.height = max(size.height, backgroundImage.size.height)
        }
        return size
    }

    /// 文字なしのときの中身の大きさ(余白を除く)
    private var noTextContentSize: CGSize {
        switch self.shape {
        case .arrowUp:
            // 日付の欄の矢印: 余白を含めて 24 x 20(日付ラベルの欄の高さに合わせる)
            return CGSize(width: 12, height: 12)
        case .hexagon, .arrowLeft:
            return CGSize(width: 10, height: 16)
        }
    }

    /// 背景(画像、または形に沿った塗り)を描き、その上に文字を描く
    override func draw(_ rect: CGRect) {
        if let backgroundImage {
            backgroundImage.draw(in: self.bounds)
        } else {
            self.fillColor.setFill()
            self.makeShapePath(in: self.bounds).fill()
        }
        super.draw(rect)  // drawText(in:) が呼ばれる
    }

    /// 余白の内側に文字を描く
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: self.padding))
    }

    /// マーカーの形のパスを作る
    private func makeShapePath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        switch self.shape {
        case .hexagon:
            let tip = rect.height / 2
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX + tip, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - tip, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - tip, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + tip, y: rect.maxY))
        case .arrowUp:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + self.tipLength))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + self.tipLength))
        case .arrowLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX + self.tipLength, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + self.tipLength, y: rect.maxY))
        }
        path.close()
        return path
    }

    /// 文字を設定し、指定した位置に配置する
    /// - Parameters:
    ///   - text: 表示する文字(nil なら文字なし)
    ///   - anchor: 配置の基準点(親Viewの座標)。hexagon / arrowLeft は縦方向の中心、arrowUp は矢印の先端
    ///   - bounds: はみ出さないように収める範囲(親Viewの座標)
    ///   - alignRight: true の場合、anchor.x にマーカーの右端を合わせる(false なら中心を合わせる)
    func show(_ text: String?, anchor: CGPoint, within bounds: CGRect, alignRight: Bool = false) {
        self.text = text
        let size = self.intrinsicContentSize
        var origin = CGPoint.zero

        // 横位置: alignRight なら anchor.x に右端を、そうでなければ中心を合わせる
        if alignRight {
            origin.x = anchor.x - size.width
        } else {
            origin.x = anchor.x - size.width / 2
        }

        // 縦位置: 上向き矢印は先端(上端)を anchor.y に、それ以外は縦方向の中心を合わせる
        switch self.shape {
        case .arrowUp:
            origin.y = anchor.y
        case .hexagon, .arrowLeft:
            origin.y = anchor.y - size.height / 2
        }

        // 範囲の端ではみ出さないよう内側に寄せる
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)
        self.frame = CGRect(origin: origin, size: size)
        self.isHidden = false
        self.setNeedsDisplay()
    }
}

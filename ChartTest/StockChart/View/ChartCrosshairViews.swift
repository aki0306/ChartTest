//
//  ChartCrosshairViews.swift
//  ChartTest
//
//  【View】「4本値」表示用の部品。
//
//  ・CrosshairOverlayView: 十字線(縦線 + 横線)を描く
//  ・OHLCInfoView: 選択中の足の日付・始値・高値・安値・終値を表示する枠
//  ・CrosshairMarkerLabel: 横線の値・縦線の日付・Y軸側の矢印などのマーカー
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
    var lineColor: UIColor = .label {
        didSet { applyLineStyle() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isUserInteractionEnabled = false
        backgroundColor = .clear
        [verticalLine, horizontalLine].forEach { layer.addSublayer($0) }
        applyLineStyle()
        hide()

        // ライト/ダークモード切り替え時に線の色(CGColor)を更新する
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.applyLineStyle()
        }
    }

    /// 線の色・太さ・破線を設定する
    private func applyLineStyle() {
        [verticalLine, horizontalLine].forEach {
            $0.strokeColor = lineColor.resolvedColor(with: traitCollection).cgColor
            $0.lineWidth = 0.8
            $0.lineDashPattern = [4, 3]
            $0.fillColor = nil
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
        verticalLine.path = x.map { x in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: x, y: verticalRange.lowerBound))
            path.addLine(to: CGPoint(x: x, y: verticalRange.upperBound))
            return path.cgPath
        }
        horizontalLine.path = y.map { y in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: horizontalRange.lowerBound, y: y))
            path.addLine(to: CGPoint(x: horizontalRange.upperBound, y: y))
            return path.cgPath
        }
        CATransaction.commit()
    }

    /// 十字線を消す
    func hide() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        verticalLine.path = nil
        horizontalLine.path = nil
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
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    /// 価格の書式(3桁カンマ区切り・小数2桁)
    private let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// 3行のラベルを縦に並べる
    private func setup() {
        isUserInteractionEnabled = false
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        layer.cornerRadius = 6

        dateLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        dateLabel.textAlignment = .center
        [upperLabel, lowerLabel].forEach { $0.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular) }
        [dateLabel, upperLabel, lowerLabel].forEach { $0.textColor = .white }

        let stack = UIStackView(arrangedSubviews: [dateLabel, upperLabel, lowerLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])
    }

    /// 表示する足を設定する
    func update(with candle: StockCandle) {
        dateLabel.text = dateFormatter.string(from: candle.date)
        upperLabel.text = "始値：\(format(candle.open))  高値：\(format(candle.high))"
        lowerLabel.text = "安値：\(format(candle.low))  終値：\(format(candle.close))"
    }

    /// 価格を文字列にする
    private func format(_ value: Double) -> String {
        priceFormatter.string(from: NSNumber(value: value)) ?? ""
    }
}

// MARK: - 十字線のマーカー

/// 十字線に付けるマーカー(形付きの背景 + 文字)。
///
///   hexagon  : ＜ 60,660.98 ＞   横線の値(外枠の左端)
///   arrowUp  :    /\             縦線の日付(X軸)。上向きの矢印の中に日付
///               | 8/19 |
///   arrowLeft:  ◀■               横線の位置を示すY軸側の矢印(文字なし)
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
        didSet { setNeedsDisplay() }
    }

    /// 矢印の尖った部分の長さ
    private let tipLength: CGFloat = 6

    /// 文字の周りの余白(形に合わせて尖った部分のぶんを空ける)
    private var padding: UIEdgeInsets {
        switch shape {
        case .hexagon: return UIEdgeInsets(top: 3, left: 12, bottom: 3, right: 12)
        case .arrowUp: return UIEdgeInsets(top: 1 + tipLength, left: 6, bottom: 1, right: 6)
        case .arrowLeft: return UIEdgeInsets(top: 3, left: 4 + tipLength, bottom: 3, right: 4)
        }
    }

    init(shape: Shape) {
        self.shape = shape
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear  // 背景は draw で形に沿って塗る
        textColor = .white
        textAlignment = .center
        // 日付の矢印はX軸ラベル領域に収まるよう少し小さい文字にする
        font = .monospacedDigitSystemFont(ofSize: shape == .arrowUp ? 11 : 12, weight: .semibold)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 余白を含めたサイズ(文字なしの矢印は固定サイズ)
    override var intrinsicContentSize: CGSize {
        let textSize = (text?.isEmpty ?? true) ? CGSize(width: 10, height: 16) : super.intrinsicContentSize
        return CGSize(width: textSize.width + padding.left + padding.right,
                      height: textSize.height + padding.top + padding.bottom)
    }

    /// 形に沿って背景を塗り、その上に文字を描く
    override func draw(_ rect: CGRect) {
        fillColor.setFill()
        makeShapePath(in: bounds).fill()
        super.draw(rect)  // drawText(in:) が呼ばれる
    }

    /// 余白の内側に文字を描く
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: padding))
    }

    /// マーカーの形のパスを作る
    private func makeShapePath(in r: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        switch shape {
        case .hexagon:
            let tip = r.height / 2
            path.move(to: CGPoint(x: r.minX, y: r.midY))
            path.addLine(to: CGPoint(x: r.minX + tip, y: r.minY))
            path.addLine(to: CGPoint(x: r.maxX - tip, y: r.minY))
            path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            path.addLine(to: CGPoint(x: r.maxX - tip, y: r.maxY))
            path.addLine(to: CGPoint(x: r.minX + tip, y: r.maxY))
        case .arrowUp:
            path.move(to: CGPoint(x: r.midX, y: r.minY))
            path.addLine(to: CGPoint(x: r.maxX, y: r.minY + tipLength))
            path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            path.addLine(to: CGPoint(x: r.minX, y: r.minY + tipLength))
        case .arrowLeft:
            path.move(to: CGPoint(x: r.minX, y: r.midY))
            path.addLine(to: CGPoint(x: r.minX + tipLength, y: r.minY))
            path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            path.addLine(to: CGPoint(x: r.minX + tipLength, y: r.maxY))
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
        let size = intrinsicContentSize
        var origin = CGPoint(x: alignRight ? anchor.x - size.width : anchor.x - size.width / 2,
                             y: shape == .arrowUp ? anchor.y : anchor.y - size.height / 2)
        // 範囲の端ではみ出さないよう内側に寄せる
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)
        frame = CGRect(origin: origin, size: size)
        isHidden = false
        setNeedsDisplay()
    }
}

//
//  CrosshairMarkerLabel.swift
//  ChartTest
//
//  【View】「4本値」表示用の部品のうち、横線の値・縦線と横線の位置を指すマーカー。背景は画像で描く。
//
//  十字線と、マーカーを置く位置・使う画像は CrosshairOverlayView.swift。ここでは渡された文字・位置に描くだけ。
//

import UIKit

/// 十字線に付けるマーカー(背景の画像 + 文字)。
///
///   ＜ 60,660.98 ＞   横線の値(外枠の左端寄り。文字の長さに合わせて画像を伸ばす)
///      /\             縦線の位置を示す、日付ラベルの欄の矢印(文字なし)
///     |  |
///    ◀■               横線の位置を示す、Y軸側の矢印(文字なし)
final class CrosshairMarkerLabel: UILabel {

    /// 背景の画像。文字ありの場合は文字の大きさに合わせて伸ばすので、伸ばしたくない部分は
    /// resizableImage(withCapInsets:resizingMode:) で指定した画像を渡す
    private let backgroundImage: UIImage
    /// 文字の周りの余白(文字なしなら使わない)
    private let padding: UIEdgeInsets

    /// - Parameters:
    ///   - backgroundImage: 背景の画像
    ///   - padding: 文字の周りの余白(画像の尖った部分などに文字が重ならないように空ける)
    init(backgroundImage: UIImage, padding: UIEdgeInsets = .zero) {
        self.backgroundImage = backgroundImage
        self.padding = padding
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear  // 背景は draw で画像を描く
        self.textColor = UIColor(resource: .chartMarkerText)
        self.textAlignment = .center
        self.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// マーカーの大きさ
    ///   ・文字なし: 画像の大きさそのまま
    ///   ・文字あり: 文字 + 余白。画像より小さくはしない(文字が短くても画像の形が崩れないように)
    override var intrinsicContentSize: CGSize {
        let hasText = !(self.text ?? "").isEmpty
        if !hasText {
            return self.backgroundImage.size
        }
        let textSize = super.intrinsicContentSize
        let width = textSize.width + self.padding.left + self.padding.right
        let height = textSize.height + self.padding.top + self.padding.bottom
        return CGSize(width: max(width, self.backgroundImage.size.width),
                      height: max(height, self.backgroundImage.size.height))
    }

    /// 背景の画像を描き、その上に文字を描く
    override func draw(_ rect: CGRect) {
        self.backgroundImage.draw(in: self.bounds)
        super.draw(rect)  // drawText(in:) が呼ばれる
    }

    /// 余白の内側に文字を描く
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: self.padding))
    }

    /// 文字を設定し、指定した位置に配置する
    /// - Parameters:
    ///   - text: 表示する文字(nil なら文字なし)
    ///   - anchor: 配置の基準点(親Viewの座標)
    ///   - bounds: はみ出さないように収める範囲(親Viewの座標)
    ///   - alignRight: true の場合、anchor.x にマーカーの右端を合わせる(false なら中心を合わせる)
    ///   - alignTop: true の場合、anchor.y にマーカーの上端を合わせる(false なら中心を合わせる)
    func show(_ text: String?, anchor: CGPoint, within bounds: CGRect,
              alignRight: Bool = false, alignTop: Bool = false) {
        self.text = text
        let size = self.intrinsicContentSize
        var origin = CGPoint.zero

        // 横位置: alignRight なら anchor.x に右端を、そうでなければ中心を合わせる
        if alignRight {
            origin.x = anchor.x - size.width
        } else {
            origin.x = anchor.x - size.width / 2
        }

        // 縦位置: alignTop なら anchor.y に上端を、そうでなければ中心を合わせる
        if alignTop {
            origin.y = anchor.y
        } else {
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

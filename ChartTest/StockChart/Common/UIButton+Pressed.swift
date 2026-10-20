//
//  UIButton+Pressed.swift
//  ChartTest
//
//  【共通】ボタンが押されている間の見た目を作るための部品。
//
//  ・isPressed … 押している間、またはメニューを表示している間に true
//  ・pressedImage / pressedColor … 押している間に使う、少し暗くした画像・色
//
//  使い方(configurationUpdateHandler の中で):
//
//      if button.isPressed {
//          configuration.background.image = UIButton.pressedImage(from: normalImage)
//      }
//

import UIKit

extension UIButton {

    /// 押している間に暗くする量(0 = そのまま、1 = 真っ黒)
    static let pressedDarkness: CGFloat = 0.2

    /// 押されているか(押している間、またはメニューを表示している間)
    /// メニューを開くボタン(showsMenuAsPrimaryAction)は、押すとすぐメニューが開くので isHighlighted が true にならない。
    /// メニューを表示している間(isHeld)も、押している間と同じに扱う
    var isPressed: Bool {
        if self.isHeld {
            return true
        }
        return self.isHighlighted
    }

    /// 押している間の画像(描かれている部分だけを暗くする。透明な部分はそのまま。伸ばす範囲も元の画像と同じにする)
    static func pressedImage(from image: UIImage, darkness: CGFloat = UIButton.pressedDarkness) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size, format: image.imageRendererFormat)
        let darkenedImage = renderer.image { context in
            image.draw(at: .zero)
            UIColor.black.withAlphaComponent(darkness).setFill()
            context.fill(CGRect(origin: .zero, size: image.size), blendMode: .sourceAtop)
        }
        return darkenedImage.resizableImage(withCapInsets: image.capInsets, resizingMode: image.resizingMode)
    }

    /// 押している間の色(ダークモードでも、そのときの色をもとに暗くする)
    static func pressedColor(from color: UIColor, darkness: CGFloat = UIButton.pressedDarkness) -> UIColor {
        let brightness = 1 - darkness
        return UIColor { traitCollection in
            let resolvedColor = color.resolvedColor(with: traitCollection)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            resolvedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return UIColor(red: red * brightness, green: green * brightness, blue: blue * brightness, alpha: alpha)
        }
    }
}

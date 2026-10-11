//
//  ChartSettingsRows.swift
//  ChartTest
//
//  【View】設定画面(ChartSettingsView)の右側に並べる1行の部品。
//
//  ・ChartSettingsToggleRow  … 「Y軸(メイン)固定  [トグル]」の1行。XIB の「Toggle Row」
//  ・ChartSettingsStepperRow … 「短期平均線  [−] ──●── [+]」の1行。XIB の「Stepper Row」
//
//  見た目(配置・文字の大きさ)は ChartSettingsView.xib で編集する。
//  ChartSettingsView が XIB から必要な数だけ作って並べ、名称・値・変わったときの処理を渡す。
//

import UIKit

// MARK: - 右側の行(トグル)。見た目は XIB の「Toggle Row」

/// 「Y軸(メイン)固定  [トグル]」の1行
final class ChartSettingsToggleRow: UIView {

    /// 名称(幅は ChartSettingsView が全行で揃える)
    @IBOutlet private(set) weak var titleLabel: UILabel!
    /// オン/オフ
    @IBOutlet private weak var toggle: UISwitch!

    /// 切り替えられたときの処理
    private var onChange: ((Bool) -> Void)?

    /// 名称・状態と、切り替えられたときの処理を設定する
    func configure(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        self.titleLabel.text = title
        self.toggle.isOn = isOn
        self.onChange = onChange
    }

    /// トグルが切り替えられたとき(XIB で Value Changed に接続)
    @IBAction private func toggleChanged(_ sender: UISwitch) {
        self.onChange?(sender.isOn)
    }
}

// MARK: - 右側の行(数値 + −/+ ボタン + スライダー)。見た目は XIB の「Stepper Row」

/// 「短期平均線  [−] ──●── [+]」の1行(値はスライダーの上に表示する)
final class ChartSettingsStepperRow: UIView {

    /// 名称(幅は ChartSettingsView が全行で揃える)
    @IBOutlet private(set) weak var titleLabel: UILabel!
    /// 値の表示(スライダーの上)
    @IBOutlet private weak var valueLabel: UILabel!
    /// スライダー
    @IBOutlet private weak var slider: UISlider!
    /// − ボタン
    @IBOutlet private weak var minusButton: UIButton!
    /// + ボタン
    @IBOutlet private weak var plusButton: UIButton!

    /// 現在の値
    private var value = 0.0
    /// 設定できる範囲
    private var range: ClosedRange<Double> = 0...0
    /// ボタン1回・スライダーの1目盛りで変わる量
    private var step = 1.0
    /// 表示する小数点以下の桁数
    private var fractionDigits = 0
    /// 値が変わったときの処理
    private var onChange: ((Double) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        // 枠線の色(Interface Builder の User Defined Runtime Attributes では CGColor を指定できないのでコードで指定)
        for button in [self.minusButton, self.plusButton] {
            button?.layer.borderColor = UIColor(resource: .chartSettingsButtonBorder).cgColor
        }
    }

    /// 名称・値・範囲と、値が変わったときの処理を設定する
    func configure(title: String, value: Double, range: ClosedRange<Double>, step: Double,
                   fractionDigits: Int, onChange: @escaping (Double) -> Void) {
        self.titleLabel.text = title
        self.value = value
        self.range = range
        self.step = step
        self.fractionDigits = fractionDigits
        self.onChange = onChange
        self.slider.minimumValue = Float(range.lowerBound)
        self.slider.maximumValue = Float(range.upperBound)
        self.updateDisplay()
    }

    /// − ボタン(XIB で Touch Up Inside に接続)
    @IBAction private func minusTapped(_ sender: UIButton) {
        self.setValue(self.value - self.step)
    }

    /// + ボタン(XIB で Touch Up Inside に接続)
    @IBAction private func plusTapped(_ sender: UIButton) {
        self.setValue(self.value + self.step)
    }

    /// スライダーが動かされたとき(XIB で Value Changed に接続)。刻み(step)に合わせて値を丸める
    ///   例) 範囲 1〜200・刻み 1 で、つまみが 25.4 の位置 → 下限から 24.4 刻み → 24 刻みに丸めて 25
    @IBAction private func sliderChanged(_ sender: UISlider) {
        let stepCount = ((Double(sender.value) - self.range.lowerBound) / self.step).rounded()  // 下限から何刻み目か
        self.setValue(self.range.lowerBound + stepCount * self.step)
    }

    /// 値を変え(範囲内に丸める)、表示を更新して通知する
    private func setValue(_ newValue: Double) {
        // 小数の誤差(0.1 + 0.2 など)が溜まらないよう、刻みの桁で丸める
        let scale = pow(10, Double(self.fractionDigits))
        let rounded = (newValue * scale).rounded() / scale
        let clamped = min(max(rounded, self.range.lowerBound), self.range.upperBound)
        guard clamped != self.value else {
            // 値は変わらないが、スライダーのつまみは刻みの位置に戻す
            self.updateDisplay()
            return
        }
        self.value = clamped
        self.updateDisplay()
        self.onChange?(self.value)
    }

    /// 値ラベル・スライダーの位置と、範囲の端でのボタンの有効/無効を更新する
    private func updateDisplay() {
        // 刻みの桁(fractionDigits)にそろえて表示する(例: 刻み 0.02 → 「0.20」、刻み 1 → 「5」)
        self.valueLabel.text = ChartNumberFormatter.string(self.value, fractionDigits: self.fractionDigits,
                                                           minimumFractionDigits: self.fractionDigits,
                                                           usesGroupingSeparator: false)
        self.slider.value = Float(self.value)
        self.minusButton.isEnabled = self.value > self.range.lowerBound
        self.plusButton.isEnabled = self.value < self.range.upperBound
    }
}

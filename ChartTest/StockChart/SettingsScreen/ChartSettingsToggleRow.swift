//
//  ChartSettingsToggleRow.swift
//  ChartTest
//
//  【View】設定画面(ChartSettingsView)の右側に並べる「Y軸(メイン)固定  [トグル]」の1行。
//
//  見た目(配置・文字の大きさ)は ChartSettingsToggleRow.xib で編集する。
//  ChartSettingsView が XIB から必要な数だけ作って並べ、名称・状態・切り替えられたときの処理を渡す。
//

import UIKit

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

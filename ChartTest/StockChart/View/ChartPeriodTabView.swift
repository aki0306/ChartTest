//
//  ChartPeriodTabView.swift
//  ChartTest
//
//  【View】足種(1分足・日中足・日足・週足・月足)を切り替えるタブ。
//
//   ┌─────┐┌─────┐┌─────┐┌─────┐┌─────┐
//   │1分足││日中足││日 足││週 足││▓月 足▓│   ← 選択中のタブは青く塗る
//   └─────┘└─────┘└─────┘└─────┘└─────┘
//
//  ・並べる足種は periods で指定する(国内指数は5種類、海外指数は3種類。IndexMarket.periods)
//  ・タブが押されると onSelect が呼ばれる。どの足種のデータを表示するかは呼び出し側(Controller)が決める
//  ・storyboard に置く場合は、View のクラスを ChartPeriodTabView にする
//

import UIKit

final class ChartPeriodTabView: UIView {

    // MARK: - 設定(外から変更する)

    /// 並べる足種(左から順に)。変更するとタブを作り直す
    var periods: [ChartPeriod] = [] {
        didSet { rebuildButtons() }
    }

    /// 選択中の足種。変更するとタブの見た目を更新する(onSelect は呼ばれない)
    var selectedPeriod: ChartPeriod? {
        didSet { updateButtonStyles() }
    }

    /// タブが押されたときに呼ばれる処理(押された足種が渡される)
    var onSelect: ((ChartPeriod) -> Void)?

    // MARK: - 見た目

    /// 選択中のタブの背景色(青)
    private let selectedColor = UIColor(red: 0.10, green: 0.47, blue: 0.95, alpha: 1)
    /// 選択していないタブの枠線・文字の色(灰色)
    private let normalColor = UIColor.gray
    /// タブ同士の間隔
    private let spacing: CGFloat = 6

    // MARK: - 部品

    /// タブ(ボタン)を横に並べるスタック
    private let stackView = UIStackView()
    /// タブ(ボタン)。periods と同じ並び
    private var buttons: [UIButton] = []

    // MARK: - 初期化

    /// コードから生成された場合
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    /// Storyboard / XIB から生成された場合
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// タブを並べるスタックを、このViewいっぱいに配置する
    private func setup() {
        backgroundColor = .clear

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually  // タブはすべて同じ幅にする
        stackView.spacing = spacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    // MARK: - タブの作成

    /// periods に合わせてタブ(ボタン)を作り直す
    private func rebuildButtons() {
        // 古いタブを取り除く
        for button in buttons {
            button.removeFromSuperview()
        }
        buttons = []

        // 足種ごとにタブを作って並べる
        for period in periods {
            let button = UIButton(type: .custom)
            button.setTitle(period.title, for: .normal)
            button.titleLabel?.adjustsFontSizeToFitWidth = true  // 幅が狭いときは文字を縮小する
            button.titleLabel?.minimumScaleFactor = 0.7
            button.layer.cornerRadius = 6
            button.layer.borderWidth = 1
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            buttons.append(button)
        }
        updateButtonStyles()
    }

    /// 選択中かどうかに合わせて、各タブの見た目を設定する
    private func updateButtonStyles() {
        for (index, button) in buttons.enumerated() {
            let isSelected = periods[index] == selectedPeriod
            if isSelected {
                // 選択中: 青で塗りつぶし、白の太字
                button.backgroundColor = selectedColor
                button.layer.borderColor = selectedColor.cgColor
                button.setTitleColor(.white, for: .normal)
                button.titleLabel?.font = .boldSystemFont(ofSize: 15)
            } else {
                // 選択していない: 白地に灰色の枠線と文字
                button.backgroundColor = .white
                button.layer.borderColor = normalColor.cgColor
                button.setTitleColor(normalColor, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 15)
            }
        }
    }

    // MARK: - 操作

    /// タブが押されたら、その足種を選択中にして onSelect を呼ぶ
    @objc private func buttonTapped(_ button: UIButton) {
        guard let index = buttons.firstIndex(of: button) else { return }
        let period = periods[index]

        // すでに選択中のタブを押した場合は何もしない
        guard period != selectedPeriod else { return }

        selectedPeriod = period
        onSelect?(period)
    }
}

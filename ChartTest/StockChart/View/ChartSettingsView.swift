//
//  ChartSettingsView.swift
//  ChartTest
//
//  【View】チャートの設定画面。
//
//  ┌─────────┬───────────────────────────┐
//  │   表示    │                           │
//  ├─────────┤                           │
//  │ オプション  │◀   Y軸(メイン)固定  [ ◯ ]   │ ← 左で選んだ項目の設定を右に表示
//  ├─────────┤    Y軸(サブ)固定   [ ◯ ]   │   ・トグル(オプション)
//  │メインチャート│    4本値          [ ◯ ]   │   ・数値 + −/+ ボタン(指標のパラメータ)
//  ├─────────┤                           │
//  │ 移動平均線  │                           │
//  │ ...     │                           │
//  └─────────┴───────────────────────────┘
//
//  【責務】渡された項目・行を表示し、操作を delegate で通知するのみ。
//  項目の内容や値の意味は知らず、表示する文字列・値は Controller が決めて渡す。
//

import UIKit

/// ChartSettingsView の操作を受け取るデリゲート
protocol ChartSettingsViewDelegate: AnyObject {
    /// 左側リストの項目が選ばれたとき
    func settingsView(_ settingsView: ChartSettingsView, didSelectItemAt indexPath: IndexPath)
    /// 右側のトグルが切り替えられたとき
    func settingsView(_ settingsView: ChartSettingsView, didToggleRowAt index: Int, isOn: Bool)
    /// 右側の数値が −/+ ボタンで変更されたとき
    func settingsView(_ settingsView: ChartSettingsView, didChangeValueAt index: Int, value: Double)
}

final class ChartSettingsView: UIView {

    // MARK: - Types

    /// 左側リストの見出しごとのまとまり(表示用)
    struct Section {
        /// 見出し
        let title: String
        /// 項目名の一覧
        let items: [String]
    }

    /// 右側に並べる1行(表示用)
    enum Row {
        /// トグル(オン/オフ)
        case toggle(title: String, isOn: Bool)
        /// 数値 + −/+ ボタン
        case stepper(title: String, value: Double, range: ClosedRange<Double>, step: Double, fractionDigits: Int)
    }

    // MARK: - Public

    /// 操作の通知先
    weak var delegate: ChartSettingsViewDelegate?

    /// 左側リストの内容
    var sections: [Section] = [] {
        didSet { tableView.reloadData(); updateListSelection() }
    }

    /// 左側リストで選択中の項目
    var selectedIndexPath: IndexPath? {
        didSet { updateListSelection() }
    }

    /// 右側に並べる行
    var rows: [Row] = [] {
        didSet { rebuildRows() }
    }

    // MARK: - Style

    /// 見出しの背景色
    private let headerColor = UIColor(red: 0.89, green: 0.05, blue: 0.27, alpha: 1)
    /// 選択中の項目の背景色
    private let selectedRowColor = UIColor(white: 0.40, alpha: 1)
    /// 右側パネルの外側の背景色
    private let panelBackgroundColor = UIColor.systemGray5
    /// 左側リストの1行の高さ
    private let listRowHeight: CGFloat = 52
    /// 左側リストの見出しの高さ
    private let listHeaderHeight: CGFloat = 36

    // MARK: - Subviews

    /// 左側のリスト
    private let tableView = UITableView(frame: .zero, style: .plain)
    /// 右側の白いパネル
    private let detailPanel = UIView()
    /// 右側パネル内で行を縦に並べるスタック(パネルの中央に配置)
    private let rowsStack = UIStackView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    /// Storyboard / XIB から生成された場合
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup

    /// 左側リストと右側パネルを配置する
    private func setup() {
        backgroundColor = panelBackgroundColor

        // 左側リスト: 幅は全体の 36%
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = listRowHeight
        tableView.sectionHeaderHeight = listHeaderHeight
        tableView.sectionHeaderTopPadding = 0
        tableView.separatorInset = .zero
        tableView.backgroundColor = .white
        addSubview(tableView)

        // 右側パネル: 白い角丸の板。中身の行は中央に縦並び
        detailPanel.translatesAutoresizingMaskIntoConstraints = false
        detailPanel.backgroundColor = .white
        detailPanel.layer.cornerRadius = 8
        addSubview(detailPanel)

        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.axis = .vertical
        rowsStack.spacing = 12
        rowsStack.alignment = .fill
        detailPanel.addSubview(rowsStack)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.36),

            detailPanel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            detailPanel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            detailPanel.leadingAnchor.constraint(equalTo: tableView.trailingAnchor, constant: 16),
            detailPanel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            rowsStack.centerXAnchor.constraint(equalTo: detailPanel.centerXAnchor),
            rowsStack.centerYAnchor.constraint(equalTo: detailPanel.centerYAnchor),
            rowsStack.leadingAnchor.constraint(greaterThanOrEqualTo: detailPanel.leadingAnchor, constant: 16),
            rowsStack.trailingAnchor.constraint(lessThanOrEqualTo: detailPanel.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Rows(右側)

    /// rows の内容で右側の行を作り直す
    private func rebuildRows() {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var titleLabels: [UILabel] = []
        for (index, row) in rows.enumerated() {
            let (rowView, titleLabel) = makeRowView(row, index: index)
            rowsStack.addArrangedSubview(rowView)
            titleLabels.append(titleLabel)
        }
        // 名称ラベルの幅を全行で「一番長い名称の幅」に揃え、操作部品の左端を縦に揃える
        let maxWidth = titleLabels.map { $0.intrinsicContentSize.width }.max() ?? 0
        titleLabels.forEach { $0.widthAnchor.constraint(equalToConstant: ceil(maxWidth)).isActive = true }
    }

    /// 1行分のView(名称ラベル + 操作部品)と、その名称ラベルを作る
    private func makeRowView(_ row: Row, index: Int) -> (UIView, UILabel) {
        let titleLabel = UILabel()
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.textAlignment = .right
        // 名称は省略・圧縮せずに表示する(狭い場合は操作部品側ではなく余白を詰める)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let control: UIView
        switch row {
        case let .toggle(title, isOn):
            titleLabel.text = title
            let toggle = UISwitch()
            toggle.isOn = isOn
            toggle.tag = index
            toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
            control = toggle

        case let .stepper(title, value, range, step, fractionDigits):
            titleLabel.text = title
            control = StepperControl(value: value, range: range, step: step, fractionDigits: fractionDigits) {
                [weak self] newValue in
                guard let self else { return }
                self.delegate?.settingsView(self, didChangeValueAt: index, value: newValue)
            }
        }

        // 名称は右寄せ、操作部品はその右に並べる(画像の「Y軸(メイン)固定 [トグル]」の形)
        let stack = UIStackView(arrangedSubviews: [titleLabel, control])
        stack.axis = .horizontal
        stack.spacing = 16
        stack.alignment = .center
        return (stack, titleLabel)
    }

    /// トグルが切り替えられたとき
    @objc private func toggleChanged(_ sender: UISwitch) {
        delegate?.settingsView(self, didToggleRowAt: sender.tag, isOn: sender.isOn)
    }

    // MARK: - List(左側)

    /// 選択中の項目の見た目を更新する
    private func updateListSelection() {
        for cell in tableView.visibleCells {
            guard let indexPath = tableView.indexPath(for: cell) else { continue }
            applyCellStyle(cell, isSelected: indexPath == selectedIndexPath,
                           text: sections[indexPath.section].items[indexPath.row])
        }
    }

    /// セルに項目名と、選択/非選択の見た目を適用する(選択中はグレー背景 + 白い太字)
    private func applyCellStyle(_ cell: UITableViewCell, isSelected: Bool, text: String?) {
        var content = cell.defaultContentConfiguration()
        content.text = text
        if isSelected {
            // 選択中: 太字・白文字(背景は selectedRowColor)
            content.textProperties.font = .boldSystemFont(ofSize: 16)
            content.textProperties.color = .white
        } else {
            content.textProperties.font = .systemFont(ofSize: 16)
            content.textProperties.color = .black
        }
        // 長い項目名(ボリンジャーバンドなど)は省略せず、文字を縮小して1行に収める
        content.textProperties.numberOfLines = 1
        content.textProperties.adjustsFontSizeToFitWidth = true
        content.textProperties.minimumScaleFactor = 0.6
        cell.contentConfiguration = content
        if isSelected {
            cell.backgroundColor = selectedRowColor
        } else {
            cell.backgroundColor = .white
        }
    }
}

// MARK: - UITableViewDataSource / UITableViewDelegate(左側リスト)

extension ChartSettingsView: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.selectionStyle = .none  // 選択の見た目は applyCellStyle で付ける
        applyCellStyle(cell, isSelected: indexPath == selectedIndexPath,
                       text: sections[indexPath.section].items[indexPath.row])
        return cell
    }

    /// 見出し(赤背景・白文字・中央寄せ)
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.text = sections[section].title
        label.textAlignment = .center
        label.textColor = .white
        label.font = .boldSystemFont(ofSize: 15)
        label.backgroundColor = headerColor
        return label
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.settingsView(self, didSelectItemAt: indexPath)
    }
}

// MARK: - StepperControl(数値 + −/+ ボタン)

/// 「−  25  +」の形で数値を増減する部品
private final class StepperControl: UIView {

    /// 現在の値
    private var value: Double
    /// 設定できる範囲
    private let range: ClosedRange<Double>
    /// ボタン1回で変わる量
    private let step: Double
    /// 表示する小数点以下の桁数
    private let fractionDigits: Int
    /// 値が変わったときの処理
    private let onChange: (Double) -> Void

    /// 値の表示
    private let valueLabel = UILabel()
    /// − ボタン
    private let minusButton = UIButton(type: .system)
    /// + ボタン
    private let plusButton = UIButton(type: .system)

    init(value: Double, range: ClosedRange<Double>, step: Double, fractionDigits: Int,
         onChange: @escaping (Double) -> Void) {
        self.value = value
        self.range = range
        self.step = step
        self.fractionDigits = fractionDigits
        self.onChange = onChange
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// ボタンと値ラベルを横に並べる
    private func setup() {
        [minusButton, plusButton].forEach {
            $0.titleLabel?.font = .boldSystemFont(ofSize: 22)
            $0.widthAnchor.constraint(equalToConstant: 40).isActive = true
            $0.heightAnchor.constraint(equalToConstant: 36).isActive = true
            $0.backgroundColor = .systemGray6
            $0.layer.cornerRadius = 6
        }
        minusButton.setTitle("−", for: .normal)
        plusButton.setTitle("+", for: .normal)
        minusButton.addTarget(self, action: #selector(minusTapped), for: .touchUpInside)
        plusButton.addTarget(self, action: #selector(plusTapped), for: .touchUpInside)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        valueLabel.textAlignment = .center
        valueLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true

        let stack = UIStackView(arrangedSubviews: [minusButton, valueLabel, plusButton])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        updateDisplay()
    }

    @objc private func minusTapped() { change(by: -step) }
    @objc private func plusTapped() { change(by: step) }

    /// 値を増減し(範囲内に丸める)、表示を更新して通知する
    private func change(by delta: Double) {
        // 小数の誤差(0.1 + 0.2 など)が溜まらないよう、刻みの桁で丸める
        let scale = pow(10, Double(fractionDigits))
        let newValue = min(max(((value + delta) * scale).rounded() / scale, range.lowerBound), range.upperBound)
        guard newValue != value else { return }
        value = newValue
        updateDisplay()
        onChange(value)
    }

    /// 値ラベルと、範囲の端でのボタンの有効/無効を更新する
    private func updateDisplay() {
        valueLabel.text = String(format: "%.\(fractionDigits)f", value)
        minusButton.isEnabled = value > range.lowerBound
        plusButton.isEnabled = value < range.upperBound
    }
}

//
//  TechnicalMenuView.swift
//  ChartTest
//
//  【View】メインチャート/サブチャートの指標を選ぶメニュー。
//
//  ┌────────────┬────────────┐
//  │ メインチャート │ サブチャート  │ ← 見出し(赤)
//  ├────────────┼────────────┤
//  │ 移動平均線    │ 出来高       │ ← 選択中の行はグレー背景 + 白文字
//  │ 多重移動平均線 │ 移動平均乖離率 │
//  │ ...        │ ...        │
//  └────────────┴────────────┘
//
//  【責務】選択肢の表示と、タップされた指標の通知のみ。
//  選択結果は delegate(Objective-C からも利用可)で Controller に通知し、
//  チャートへの反映は Controller(StockChartViewController)が行う。
//

import UIKit

/// TechnicalMenuView の選択結果を受け取るデリゲート
@objc protocol TechnicalMenuViewDelegate: AnyObject {
    /// メインチャートの指標が選ばれたとき
    func technicalMenuView(_ menuView: TechnicalMenuView, didSelectMainIndicator indicator: MainChartIndicator)
    /// サブチャートの指標が選ばれたとき
    func technicalMenuView(_ menuView: TechnicalMenuView, didSelectSubIndicator indicator: SubChartIndicator)
}

final class TechnicalMenuView: UIView {

    // MARK: - Public

    /// 選択結果の通知先
    @objc weak var delegate: TechnicalMenuViewDelegate?

    /// 選択中のメインチャート指標(行のハイライトに反映される)
    @objc var selectedMainIndicator: MainChartIndicator = .movingAverage {
        didSet { updateSelection() }
    }

    /// 選択中のサブチャート指標(行のハイライトに反映される)
    @objc var selectedSubIndicator: SubChartIndicator = .volume {
        didSet { updateSelection() }
    }

    // MARK: - Style

    /// 見出しの背景色
    private let headerColor = UIColor(red: 0.89, green: 0.05, blue: 0.27, alpha: 1)
    /// 選択中の行の背景色
    private let selectedRowColor = UIColor(white: 0.40, alpha: 1)
    /// 行の区切り線の色
    private let separatorColor = UIColor.systemGray4

    // MARK: - Subviews

    /// メインチャート列の各行のボタン(MainChartIndicator.allCases と同じ並び)
    private var mainButtons: [UIButton] = []
    /// サブチャート列の各行のボタン(SubChartIndicator.allCases と同じ並び)
    private var subButtons: [UIButton] = []

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

    /// 2列のメニューを組み立てる
    private func setup() {
        backgroundColor = separatorColor  // 列・行の隙間が区切り線に見えるよう背景を線の色にする

        mainButtons = MainChartIndicator.allCases.map { makeRowButton(title: $0.title, tag: $0.rawValue) }
        subButtons = SubChartIndicator.allCases.map { makeRowButton(title: $0.title, tag: $0.rawValue) }
        mainButtons.forEach { $0.addTarget(self, action: #selector(mainButtonTapped(_:)), for: .touchUpInside) }
        subButtons.forEach { $0.addTarget(self, action: #selector(subButtonTapped(_:)), for: .touchUpInside) }

        // 行の高さを両列で揃えるため、行数が少ない列は空の行で埋める
        let rowCount = max(mainButtons.count, subButtons.count)
        let mainColumn = makeColumn(title: "メインチャート", rows: mainButtons, rowCount: rowCount)
        let subColumn = makeColumn(title: "サブチャート", rows: subButtons, rowCount: rowCount)

        // 2列を横に等幅で並べる。spacing の隙間が列の区切り線になる
        let columns = UIStackView(arrangedSubviews: [mainColumn, subColumn])
        columns.axis = .horizontal
        columns.distribution = .fillEqually
        columns.spacing = 1
        columns.translatesAutoresizingMaskIntoConstraints = false
        addSubview(columns)
        NSLayoutConstraint.activate([
            columns.topAnchor.constraint(equalTo: topAnchor),
            columns.leadingAnchor.constraint(equalTo: leadingAnchor),
            columns.trailingAnchor.constraint(equalTo: trailingAnchor),
            columns.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        updateSelection()
    }

    /// 見出し + 行ボタンを縦に並べた1列を作る
    /// - Parameter rowCount: 列の行数。rows がこれより少ない場合は空の行で埋める
    private func makeColumn(title: String, rows: [UIButton], rowCount: Int) -> UIStackView {
        // 見出し
        let header = UILabel()
        header.text = title
        header.textAlignment = .center
        header.textColor = .white
        header.font = .boldSystemFont(ofSize: 15)
        header.backgroundColor = headerColor

        // 空の行(区切り線を出さないよう、行と同じ背景色にする)
        let fillers: [UIView] = (0..<max(rowCount - rows.count, 0)).map { _ in
            let view = UIView()
            view.backgroundColor = .white
            return view
        }

        // 見出し・行・空の行をすべて同じ高さで並べる。spacing の隙間が行の区切り線になる
        let column = UIStackView(arrangedSubviews: [header] + rows + fillers)
        column.axis = .vertical
        column.distribution = .fillEqually
        column.spacing = 0.5
        return column
    }

    /// 1行分のボタンを作る
    /// - Parameter tag: 指標の rawValue(タップ時にどの指標かを判別するのに使う)
    private func makeRowButton(title: String, tag: Int) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 8)
        config.background.cornerRadius = 0
        let button = UIButton(configuration: config)
        button.tag = tag
        button.contentHorizontalAlignment = .leading
        return button
    }

    // MARK: - Selection

    /// 選択中の行をグレー背景 + 白い太字、それ以外を通常表示にする
    private func updateSelection() {
        for button in mainButtons {
            applyRowStyle(button, isSelected: button.tag == selectedMainIndicator.rawValue)
        }
        for button in subButtons {
            applyRowStyle(button, isSelected: button.tag == selectedSubIndicator.rawValue)
        }
    }

    /// 行ボタンに選択/非選択の見た目を適用する
    private func applyRowStyle(_ button: UIButton, isSelected: Bool) {
        guard var config = button.configuration else { return }
        let font: UIFont
        if isSelected {
            // 選択中: 背景 selectedRowColor・白文字・太字
            config.background.backgroundColor = selectedRowColor
            config.baseForegroundColor = .white
            font = .boldSystemFont(ofSize: 15)
        } else {
            config.background.backgroundColor = .white
            config.baseForegroundColor = .black
            font = .systemFont(ofSize: 15)
        }
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font
            return attributes
        }
        button.configuration = config
    }

    // MARK: - Actions

    /// メインチャート列の行がタップされたとき
    @objc private func mainButtonTapped(_ sender: UIButton) {
        guard let indicator = MainChartIndicator(rawValue: sender.tag) else { return }
        selectedMainIndicator = indicator
        delegate?.technicalMenuView(self, didSelectMainIndicator: indicator)
    }

    /// サブチャート列の行がタップされたとき
    @objc private func subButtonTapped(_ sender: UIButton) {
        guard let indicator = SubChartIndicator(rawValue: sender.tag) else { return }
        selectedSubIndicator = indicator
        delegate?.technicalMenuView(self, didSelectSubIndicator: indicator)
    }
}

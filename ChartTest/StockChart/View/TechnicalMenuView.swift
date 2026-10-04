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
//  並べる指標は availableMainIndicators / availableSubIndicators で指定する(海外指数では絞り込む)。
//  allowsOnlyNone = true(ローソク足以外のチャート種類)のときは、メイン・サブとも「なし」だけを並べる。
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

    // MARK: - 設定(外から変更する)

    /// 選択結果の通知先
    @objc weak var delegate: TechnicalMenuViewDelegate?

    /// 選択中のメインチャート指標(行のハイライトに反映される)
    @objc var selectedMainIndicator: MainChartIndicator = .movingAverage {
        didSet { self.updateSelection() }
    }

    /// 選択中のサブチャート指標(行のハイライトに反映される)
    @objc var selectedSubIndicator: SubChartIndicator = .volume {
        didSet { self.updateSelection() }
    }

    /// true の場合、メイン・サブとも「なし」だけを選択肢にする(VWAP・新値足・折線チャートなど、指標を重ねられないチャート用)。
    /// 「なし」が選択中の表示になるが、selectedMainIndicator / selectedSubIndicator は変えない
    /// (false に戻すと、それまでの選択が表示される)
    @objc var allowsOnlyNone = false {
        didSet {
            guard self.allowsOnlyNone != oldValue else { return }
            self.rebuildColumns()
        }
    }

    /// メインチャート列に並べる指標(既定はすべて)。変更するとメニューを作り直す
    var availableMainIndicators = MainChartIndicator.allCases {
        didSet {
            guard self.availableMainIndicators != oldValue else { return }
            self.rebuildColumns()
        }
    }

    /// サブチャート列に並べる指標(既定はすべて)。変更するとメニューを作り直す
    var availableSubIndicators = SubChartIndicator.allCases {
        didSet {
            guard self.availableSubIndicators != oldValue else { return }
            self.rebuildColumns()
        }
    }

    // MARK: - 見た目

    /// 見出しの背景色
    private let headerColor = UIColor(red: 0.89, green: 0.05, blue: 0.27, alpha: 1)
    /// 選択中の行の背景色
    private let selectedRowColor = UIColor(white: 0.40, alpha: 1)
    /// 行の区切り線の色
    private let separatorColor = UIColor.systemGray4

    // MARK: - 部品

    /// メインチャート列の各行のボタン(mainChoices と同じ並び)
    private var mainButtons: [UIButton] = []
    /// サブチャート列の各行のボタン(subChoices と同じ並び)
    private var subButtons: [UIButton] = []
    /// メイン・サブの2列を横に並べたもの(選択肢が変わると作り直す)
    private var columns: UIStackView?

    /// メインチャート列に並べる指標
    private var mainChoices: [MainChartIndicator] {
        if self.allowsOnlyNone {
            return [.candleOnly]
        }
        return self.availableMainIndicators
    }

    /// サブチャート列に並べる指標
    private var subChoices: [SubChartIndicator] {
        if self.allowsOnlyNone {
            return [.hidden]
        }
        return self.availableSubIndicators
    }

    // MARK: - 初期化

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    /// Storyboard / XIB から生成された場合
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    // MARK: - メニューの組み立て

    /// 2列のメニューを組み立てる
    private func setup() {
        self.backgroundColor = self.separatorColor  // 列・行の隙間が区切り線に見えるよう背景を線の色にする
        self.rebuildColumns()
    }

    /// 選択肢(mainChoices / subChoices)に合わせて2列を作り直す
    private func rebuildColumns() {
        self.columns?.removeFromSuperview()

        // 指標ごとに1行のボタンを作る(タップされたら、tag に入れた rawValue でどの指標かを判別する)
        self.mainButtons = []
        for indicator in self.mainChoices {
            let button = self.makeRowButton(title: indicator.title, tag: indicator.rawValue)
            button.addTarget(self, action: #selector(self.mainButtonTapped(_:)), for: .touchUpInside)
            self.mainButtons.append(button)
        }
        self.subButtons = []
        for indicator in self.subChoices {
            let button = self.makeRowButton(title: indicator.title, tag: indicator.rawValue)
            button.addTarget(self, action: #selector(self.subButtonTapped(_:)), for: .touchUpInside)
            self.subButtons.append(button)
        }

        // 行の高さを両列で揃えるため、行数が少ない列は空の行で埋める。
        // 「なし」だけのときも行の高さが変わらないよう、全選択肢の行数に合わせる
        let rowCount = max(MainChartIndicator.allCases.count, SubChartIndicator.allCases.count)
        let mainColumn = self.makeColumn(title: "メインチャート", rows: self.mainButtons, rowCount: rowCount)
        let subColumn = self.makeColumn(title: "サブチャート", rows: self.subButtons, rowCount: rowCount)

        // 2列を横に等幅で並べる。spacing の隙間が列の区切り線になる
        let columns = UIStackView(arrangedSubviews: [mainColumn, subColumn])
        columns.axis = .horizontal
        columns.distribution = .fillEqually
        columns.spacing = 1
        columns.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(columns)
        self.columns = columns
        NSLayoutConstraint.activate([
            columns.topAnchor.constraint(equalTo: self.topAnchor),
            columns.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            columns.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            columns.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])

        self.updateSelection()
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
        header.backgroundColor = self.headerColor

        // 空の行(区切り線を出さないよう、行と同じ背景色にする)
        let fillerCount = max(rowCount - rows.count, 0)
        var fillers: [UIView] = []
        for _ in 0..<fillerCount {
            let filler = UIView()
            filler.backgroundColor = .white
            fillers.append(filler)
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

    // MARK: - 選択中の行の表示

    /// 選択中の行をグレー背景 + 白い太字、それ以外を通常表示にする
    private func updateSelection() {
        // 「なし」だけのときは、その「なし」を選択中として表示する
        var mainSelection = self.selectedMainIndicator
        var subSelection = self.selectedSubIndicator
        if self.allowsOnlyNone {
            mainSelection = .candleOnly
            subSelection = .hidden
        }
        for button in self.mainButtons {
            self.applyRowStyle(button, isSelected: button.tag == mainSelection.rawValue)
        }
        for button in self.subButtons {
            self.applyRowStyle(button, isSelected: button.tag == subSelection.rawValue)
        }
    }

    /// 行ボタンに選択/非選択の見た目を適用する
    private func applyRowStyle(_ button: UIButton, isSelected: Bool) {
        guard var config = button.configuration else { return }
        let font: UIFont
        if isSelected {
            // 選択中: 背景 selectedRowColor・白文字・太字
            config.background.backgroundColor = self.selectedRowColor
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

    // MARK: - 操作

    /// メインチャート列の行がタップされたとき
    @objc private func mainButtonTapped(_ sender: UIButton) {
        // 「なし」だけのときは選び直すものがないので、何もしない(選択中の指標を変えない)
        guard !self.allowsOnlyNone else { return }
        guard let indicator = MainChartIndicator(rawValue: sender.tag) else { return }
        self.selectedMainIndicator = indicator
        self.delegate?.technicalMenuView(self, didSelectMainIndicator: indicator)
    }

    /// サブチャート列の行がタップされたとき
    @objc private func subButtonTapped(_ sender: UIButton) {
        // 「なし」だけのときは選び直すものがないので、何もしない(選択中の指標を変えない)
        guard !self.allowsOnlyNone else { return }
        guard let indicator = SubChartIndicator(rawValue: sender.tag) else { return }
        self.selectedSubIndicator = indicator
        self.delegate?.technicalMenuView(self, didSelectSubIndicator: indicator)
    }
}

//
//  ChartSettingsView.swift
//  ChartTest
//
//  【View】チャートの設定画面。
//
//  ┌─────────┬──────────────────────────────────────────┐
//  │   表示    │  [1分足][日中足][▓日 足▓][週 足][月 足]     │ ← 足種のタブ(足種ごとに設定する)
//  ├─────────┤ ──────────────────────────────────────── │   設定できない足種はグレーにして選べなくする
//  │ オプション  │                  5                       │
//  ├─────────┤  短期平均線 [−] ──●────────────── [+]      │ ← 名称・−ボタン・スライダー(上に値)・+ボタン
//  │メインチャート│                  25                      │
//  ├─────────┤  長期平均線 [−] ─────●─────────── [+]      │
//  │ 移動平均線  │                                          │
//  │ ...     │ [すべての足に反映] [初期値に戻す] [ 決 定 ] │ ← 下のボタン
//  └─────────┴──────────────────────────────────────────┘
//
//  ・「オプション」(トグル)を選んだときは、足種のタブと下のボタンを隠し、トグルだけをパネルの中央に並べる
//
//  【レイアウト】ChartSettingsView.xib(Interface Builder で開いて編集する)
//  XIB には次の3つを並べて置いている。
//  ・Content View(ChartSettingsContentView) … 画面全体の配置(左のリスト・右の白いパネル)
//      右のパネルは上から「Period Header(足種のタブ)」「Rows Scroll View(行。入りきらないときはスクロール)」「Button Bar(下のボタン)」
//  ・Toggle Row(ChartSettingsToggleRow)     … 右側の「名称 + トグル」の1行の見本
//  ・Stepper Row(ChartSettingsStepperRow)   … 右側の「名称 + −/スライダー/+」の1行の見本
//  どれも「XIB を読み込んで、欲しい種類の View を取り出す」(loadFromNib)で作る。
//  右側の行は、選んだ項目によって数と種類が変わるので、見本の行を必要な数だけ作って並べる。
//  左リストの項目・見出しは文字と色だけなので、コードで作る(applyCellStyle / viewForHeaderInSection)。
//
//  【責務】渡された項目・行を表示し、操作を delegate で通知するのみ。
//  項目の内容や値の意味は知らず、表示する文字列・値は Controller が決めて渡す。
//

import UIKit

/// ChartSettingsView の操作を受け取るデリゲート
protocol ChartSettingsViewDelegate: AnyObject {
    /// 左側リストの項目が選ばれたとき
    func settingsView(_ settingsView: ChartSettingsView, didSelectItemAt indexPath: IndexPath)
    /// 足種のタブが選ばれたとき
    func settingsView(_ settingsView: ChartSettingsView, didSelectPeriod period: ChartPeriod)
    /// 右側のトグルが切り替えられたとき
    func settingsView(_ settingsView: ChartSettingsView, didToggleRowAt index: Int, isOn: Bool)
    /// 右側の数値が −/+ ボタン・スライダーで変更されたとき
    func settingsView(_ settingsView: ChartSettingsView, didChangeValueAt index: Int, value: Double)
    /// 「すべての足に反映」が押されたとき
    func settingsViewDidTapApplyToAllPeriods(_ settingsView: ChartSettingsView)
    /// 「初期値に戻す」が押されたとき
    func settingsViewDidTapReset(_ settingsView: ChartSettingsView)
    /// 「決定」が押されたとき
    func settingsViewDidTapConfirm(_ settingsView: ChartSettingsView)
}

final class ChartSettingsView: UIView {

    // MARK: - 表示用の型

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
        /// 数値 + −/+ ボタン + スライダー
        case stepper(title: String, value: Double, range: ClosedRange<Double>, step: Double, fractionDigits: Int)
    }

    // MARK: - 設定(外から変更する)

    /// 操作の通知先
    weak var delegate: ChartSettingsViewDelegate?

    /// 左側リストの内容
    var sections: [Section] = [] {
        didSet {
            self.tableView.reloadData()
            self.updateListSelection()
        }
    }

    /// 左側リストで選択中の項目
    var selectedIndexPath: IndexPath? {
        didSet {
            self.updateListSelection()
        }
    }

    /// 右側に並べる行
    var rows: [Row] = [] {
        didSet {
            self.rebuildRows()
        }
    }

    /// 足種のタブと下のボタンを表示するか(指標のパラメータのとき true、オプションのとき false)
    var showsPeriodControls = true {
        didSet {
            self.updatePeriodControlsVisibility()
        }
    }

    /// タブに並べる足種
    var periods: [ChartPeriod] {
        get {
            self.contentView.periodTabView.periods
        }
        set {
            self.contentView.periodTabView.periods = newValue
        }
    }

    /// 選べない足種(グレーにして押せなくする)
    var disabledPeriods: Set<ChartPeriod> {
        get {
            self.contentView.periodTabView.disabledPeriods
        }
        set {
            self.contentView.periodTabView.disabledPeriods = newValue
        }
    }

    /// 選択中の足種
    var selectedPeriod: ChartPeriod? {
        get {
            self.contentView.periodTabView.selectedPeriod
        }
        set {
            self.contentView.periodTabView.selectedPeriod = newValue
        }
    }

    // MARK: - 見た目(左リスト)

    /// 見出しの背景色
    private let headerColor = UIColor(red: 0.89, green: 0.05, blue: 0.27, alpha: 1)
    /// 選択中の項目の背景色
    private let selectedRowColor = UIColor(white: 0.40, alpha: 1)

    // MARK: - XIB の部品

    /// ChartSettingsView.xib(画面全体の配置と、行の見本が入っている)
    private static let nib = UINib(nibName: "ChartSettingsView", bundle: Bundle(for: ChartSettingsView.self))

    /// XIB の Content View(画面全体。このViewいっぱいに貼り付ける)
    private let contentView = ChartSettingsView.loadFromNib(ChartSettingsContentView.self)
    /// 左側のリスト
    private var tableView: UITableView {
        return self.contentView.tableView
    }

    /// 右側の白いパネルの中で、行を縦に並べるスタック
    private var rowsStack: UIStackView {
        return self.contentView.rowsStack
    }

    /// オプションのときに、行をパネル(スクロールビューの表示範囲)の縦の中央に置く制約
    private lazy var rowsCenterYConstraint = self.rowsStack.centerYAnchor.constraint(
        equalTo: self.contentView.rowsScrollView.frameLayoutGuide.centerYAnchor)

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

    // MARK: - 組み立て

    /// XIB の Content View を、このViewいっぱいに貼り付け、操作を受け取れるようにする
    private func setup() {
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.contentView)
        NSLayoutConstraint.activate([
            self.contentView.topAnchor.constraint(equalTo: self.topAnchor),
            self.contentView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.contentView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.contentView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
        ])

        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        // 見出しの上に iOS 15 以降で自動で付く余白をなくす(Interface Builder では設定できないのでコードで指定)
        self.tableView.sectionHeaderTopPadding = 0

        // 足種のタブ
        self.contentView.periodTabView.onSelect = { [weak self] period in
            guard let self else {
                return
            }
            self.delegate?.settingsView(self, didSelectPeriod: period)
        }

        // 下のボタン
        self.contentView.applyToAllButton.addTarget(self, action: #selector(self.applyToAllTapped), for: .touchUpInside)
        self.contentView.resetButton.addTarget(self, action: #selector(self.resetTapped), for: .touchUpInside)
        self.contentView.confirmButton.addTarget(self, action: #selector(self.confirmTapped), for: .touchUpInside)
    }

    // MARK: - 右側の行

    /// rows の内容で右側の行を作り直す
    private func rebuildRows() {
        // 前の行を取り除く
        for oldRow in self.rowsStack.arrangedSubviews {
            oldRow.removeFromSuperview()
        }

        // 行を作って並べる
        var titleLabels: [UILabel] = []
        for (index, row) in self.rows.enumerated() {
            let (rowView, titleLabel) = self.makeRowView(row, index: index)
            self.rowsStack.addArrangedSubview(rowView)
            titleLabels.append(titleLabel)
        }
        // 名称ラベルの幅を全行で「一番長い名称の幅」に揃え、操作部品の左端を縦に揃える
        let maxWidth = titleLabels.map { label in label.intrinsicContentSize.width }.max() ?? 0
        for label in titleLabels {
            label.widthAnchor.constraint(equalToConstant: ceil(maxWidth)).isActive = true
        }
    }

    /// 1行分のView(XIB の見本から作った行)と、その名称ラベルを作る
    private func makeRowView(_ row: Row, index: Int) -> (UIView, UILabel) {
        switch row {
        case let .toggle(title, isOn):
            let rowView = Self.loadFromNib(ChartSettingsToggleRow.self)
            rowView.configure(title: title, isOn: isOn) { [weak self] newValue in
                guard let self else {
                    return
                }
                self.delegate?.settingsView(self, didToggleRowAt: index, isOn: newValue)
            }
            return (rowView, rowView.titleLabel)

        case let .stepper(title, value, range, step, fractionDigits):
            let rowView = Self.loadFromNib(ChartSettingsStepperRow.self)
            rowView.configure(title: title, value: value, range: range, step: step,
                              fractionDigits: fractionDigits) { [weak self] newValue in
                guard let self else {
                    return
                }
                self.delegate?.settingsView(self, didChangeValueAt: index, value: newValue)
            }
            return (rowView, rowView.titleLabel)
        }
    }

    /// 足種のタブ・下のボタンの表示を切り替える。
    /// オプション(トグル)のときはタブとボタンを隠し、行をパネルの中央(上下左右)に並べる。
    /// 指標のパラメータのときは、行をパネルの幅いっぱいに、上から並べる
    private func updatePeriodControlsVisibility() {
        self.contentView.periodHeader.isHidden = !self.showsPeriodControls
        self.contentView.buttonBar.isHidden = !self.showsPeriodControls
        if self.showsPeriodControls {
            self.rowsStack.alignment = .fill
            self.rowsCenterYConstraint.isActive = false
            self.contentView.rowsTopConstraint.isActive = true
        } else {
            self.rowsStack.alignment = .center
            self.contentView.rowsTopConstraint.isActive = false
            self.rowsCenterYConstraint.isActive = true
        }
    }

    /// XIB を読み込んで、指定した種類の View(Content View・行の見本)を新しく1つ作る
    /// (XIB を読み込むと中の3つがすべて新しく作られるので、その中から欲しい種類だけを取り出して使う)
    private static func loadFromNib<PartView: UIView>(_ type: PartView.Type) -> PartView {
        let objects = self.nib.instantiate(withOwner: nil)
        let views = objects.compactMap { object in object as? PartView }
        guard let view = views.first else {
            // XIB にその種類の View がない(Custom Class の設定ミス)。すぐ気付けるよう落とす
            fatalError("ChartSettingsView.xib に \(String(describing: type)) がありません")
        }
        return view
    }

    // MARK: - 下のボタン

    /// 「すべての足に反映」
    @objc private func applyToAllTapped() {
        self.delegate?.settingsViewDidTapApplyToAllPeriods(self)
    }

    /// 「初期値に戻す」
    @objc private func resetTapped() {
        self.delegate?.settingsViewDidTapReset(self)
    }

    /// 「決定」
    @objc private func confirmTapped() {
        self.delegate?.settingsViewDidTapConfirm(self)
    }

    // MARK: - 左側のリスト

    /// 選択中の項目の見た目を更新する
    private func updateListSelection() {
        for cell in self.tableView.visibleCells {
            guard let indexPath = self.tableView.indexPath(for: cell) else {
                continue
            }
            self.applyCellStyle(cell, at: indexPath)
        }
    }

    /// 指定した位置のセルに、その項目名と、選択/非選択の見た目を適用する
    private func applyCellStyle(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let isSelected = indexPath == self.selectedIndexPath
        let section = self.sections[indexPath.section]
        let title = section.items[indexPath.row]
        self.applyCellStyle(cell, isSelected: isSelected, text: title)
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
            cell.backgroundColor = self.selectedRowColor
        } else {
            cell.backgroundColor = .white
        }
    }
}

// MARK: - UITableViewDataSource / UITableViewDelegate(左側リスト)

extension ChartSettingsView: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        self.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.sections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.selectionStyle = .none  // 選択の見た目は applyCellStyle で付ける
        self.applyCellStyle(cell, at: indexPath)
        return cell
    }

    /// 見出し(赤背景・白文字・中央寄せ)
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.text = self.sections[section].title
        label.textAlignment = .center
        label.textColor = .white
        label.font = .boldSystemFont(ofSize: 15)
        label.backgroundColor = self.headerColor
        return label
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.delegate?.settingsView(self, didSelectItemAt: indexPath)
    }
}

// MARK: - 画面全体。見た目は XIB の「Content View」

/// 設定画面の全体(左のリスト・右の白いパネル)
final class ChartSettingsContentView: UIView {

    /// 左側のリスト
    @IBOutlet private(set) weak var tableView: UITableView!
    /// 足種のタブと区切り線(オプションのときは隠す)
    @IBOutlet private(set) weak var periodHeader: UIView!
    /// 足種のタブ
    @IBOutlet private(set) weak var periodTabView: ChartPeriodTabView!
    /// 行を入れるスクロールビュー(行がパネルに入りきらないときはスクロールする)
    @IBOutlet private(set) weak var rowsScrollView: UIScrollView!
    /// 右側の白いパネルの中で、行を縦に並べるスタック
    @IBOutlet private(set) weak var rowsStack: UIStackView!
    /// 行をスクロールビューの上から並べる制約(オプションのときは外して、中央に置く)。
    /// 一時的に外すことがあるので、外しても解放されないよう strong で持つ
    @IBOutlet private(set) var rowsTopConstraint: NSLayoutConstraint!
    /// 下のボタンの帯(オプションのときは隠す)
    @IBOutlet private(set) weak var buttonBar: UIView!
    /// 「すべての足に反映」
    @IBOutlet private(set) weak var applyToAllButton: UIButton!
    /// 「初期値に戻す」
    @IBOutlet private(set) weak var resetButton: UIButton!
    /// 「決定」
    @IBOutlet private(set) weak var confirmButton: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        // 枠線の色(Interface Builder の User Defined Runtime Attributes では CGColor を指定できないのでコードで指定)
        for button in [self.applyToAllButton, self.resetButton] {
            button?.layer.borderColor = UIColor.systemGray3.cgColor
        }
        // 画面が狭いときは、文字を「…」で省略せずに縮小して収める
        for button in [self.applyToAllButton, self.resetButton, self.confirmButton] {
            button?.titleLabel?.adjustsFontSizeToFitWidth = true
            button?.titleLabel?.minimumScaleFactor = 0.6
            button?.titleLabel?.lineBreakMode = .byClipping
        }
    }
}

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
            button?.layer.borderColor = UIColor.systemGray3.cgColor
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

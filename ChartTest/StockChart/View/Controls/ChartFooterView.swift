//
//  ChartFooterView.swift
//  ChartTest
//
//  【View】チャートの下に置く帯(指数名・現在値と、チャートの種類・足種・更新・縦画面に戻すのボタン)。
//
//   ┌──────────────────────────────────────────────────────────────────┐
//   │日経平均 68309.46 10/02 15:45   [ローソク足 ▼] [日足 ▼] [↻] │ [⤾] │
//   └──────────────────────────────────────────────────────────────────┘
//     priceInfoLabel                  chartType    period   reload  rotate
//
//  ・指数名・現在値・日時は updatePriceInfo(name:price:date:) で表示する
//  ・「チャートの種類」「足種」のボタンは、押すとメニューを出す。メニューの中身(UIMenu)と、
//    ボタンに出す名前の候補は、使う側(Controller)が setChartTypeMenu / setPeriodMenu で渡す
//  ・ボタンの幅は、名前の候補のうち一番長いものが1行で入る幅にする(文字は縮小しない。
//    選んでいる名前に合わせると、選ぶたびに幅が変わってほかのボタンが動くため、一番長い名前に合わせて固定する)
//  ・更新・縦画面に戻すボタンが押されたら onReload / onRotate を呼ぶ(何をするかは使う側が決める)
//
//  【レイアウト】ChartFooterView.xib(Interface Builder で開いて編集する)
//  XIB の Content View(ChartFooterContentView)を、この View いっぱいに貼り付けている(ChartSettingsView と同じ作り)。
//  storyboard に置く場合は、View のクラスを ChartFooterView にする(Landscape.storyboard の Footer View)。
//

import UIKit

final class ChartFooterView: UIView {

    // MARK: - 操作されたときの処理(外から設定する)

    /// 更新ボタンが押されたときに呼ばれる処理
    var onReload: (() -> Void)?
    /// 縦画面に戻すボタンが押されたときに呼ばれる処理
    var onRotate: (() -> Void)?

    // MARK: - 部品

    /// ChartFooterView.xib(帯の配置が入っている)
    private static let nib = UINib(nibName: "ChartFooterView", bundle: Bundle(for: ChartFooterView.self))

    /// XIB の Content View(帯全体。この View いっぱいに貼り付ける)
    private let contentView = ChartFooterView.loadContentView()

    // MARK: - 初期化

    /// コードから生成された場合
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    /// Storyboard / XIB から生成された場合
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    /// XIB の Content View を、この View いっぱいに貼り付け、ボタンの見た目を設定する
    private func setup() {
        self.backgroundColor = .clear  // 背景の色は Content View(XIB)で決める
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.contentView)
        NSLayoutConstraint.activate([
            self.contentView.topAnchor.constraint(equalTo: self.topAnchor),
            self.contentView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.contentView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.contentView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
        ])

        // ボタンの見た目
        self.contentView.chartTypeButton.configuration = Self.menuButtonConfiguration()
        self.contentView.chartTypeButton.showsMenuAsPrimaryAction = true
        self.contentView.periodButton.configuration = Self.menuButtonConfiguration()
        self.contentView.periodButton.showsMenuAsPrimaryAction = true
        self.contentView.reloadButton.configuration = Self.iconButtonConfiguration(systemName: "arrow.clockwise")
        self.contentView.rotateButton.configuration = Self.iconButtonConfiguration(systemName: "rectangle.portrait.rotate")
        self.contentView.priceInfoLabel.text = nil  // updatePriceInfo で設定されるまでは空にする

        // ボタンが押されたら、外から設定された処理を呼ぶ
        self.contentView.onReload = { [weak self] in
            self?.onReload?()
        }
        self.contentView.onRotate = { [weak self] in
            self?.onRotate?()
        }
    }

    /// XIB を読み込んで、Content View を取り出す
    private static func loadContentView() -> ChartFooterContentView {
        let objects = self.nib.instantiate(withOwner: nil)
        let views = objects.compactMap { object in object as? ChartFooterContentView }
        guard let view = views.first else {
            // XIB に Content View がない(Custom Class の設定ミス)。すぐ気付けるよう落とす
            fatalError("ChartFooterView.xib に ChartFooterContentView がありません")
        }
        return view
    }

    // MARK: - メニューのボタン

    /// 「チャートの種類」ボタンの文字とメニューを設定する
    /// - Parameters:
    ///   - title: ボタンに出す名前(選んでいる種類。例:「ローソク足」)
    ///   - candidates: ボタンに出る可能性のある名前すべて(ボタンの幅を、一番長い名前が入る幅にする)
    ///   - menu: 押したときに出すメニュー
    func setChartTypeMenu(title: String, candidates: [String], menu: UIMenu) {
        self.setMenu(of: self.contentView.chartTypeButton, width: self.contentView.chartTypeButtonWidth,
                     title: title, candidates: candidates, menu: menu)
    }

    /// 「足種」ボタンの文字とメニューを設定する
    /// - Parameters:
    ///   - title: ボタンに出す名前(表示中の足種。例:「日足」)
    ///   - candidates: ボタンに出る可能性のある名前すべて(ボタンの幅を、一番長い名前が入る幅にする)
    ///   - menu: 押したときに出すメニュー
    func setPeriodMenu(title: String, candidates: [String], menu: UIMenu) {
        self.setMenu(of: self.contentView.periodButton, width: self.contentView.periodButtonWidth,
                     title: title, candidates: candidates, menu: menu)
    }

    /// メニューのボタンに、文字・幅・メニューを設定する
    private func setMenu(of button: UIButton, width: NSLayoutConstraint, title: String,
                         candidates: [String], menu: UIMenu) {
        width.constant = self.widthFittingLongestTitle(of: button, candidates: candidates + [title])
        button.configuration?.title = title
        button.menu = menu
    }

    /// 名前の候補のうち、一番長いものが1行で入るボタンの幅
    ///   = 文字の幅 + ▼ の幅 + 文字と ▼ の間 + 左右の余白(ボタンの見た目の設定から計算する)
    private func widthFittingLongestTitle(of button: UIButton, candidates: [String]) -> CGFloat {
        guard let configuration = button.configuration else { return 0 }

        // 文字の幅(一番長い名前)
        let font = Self.menuTitleFont
        var longestTitleWidth: CGFloat = 0
        for candidate in candidates {
            let width = (candidate as NSString).size(withAttributes: [.font: font]).width
            longestTitleWidth = max(longestTitleWidth, width)
        }

        // ▼ の幅と、左右の余白
        let imageWidth = configuration.image?.size.width ?? 0
        let insets = configuration.contentInsets
        let width = longestTitleWidth + imageWidth + configuration.imagePadding + insets.leading + insets.trailing
        return ceil(width) + Self.menuButtonExtraWidth
    }

    // MARK: - 指数名・現在値・日時

    /// 帯の左に、指数名・現在値・日時を表示する(例:「日経平均 68309.46 10/02 15:45」)
    /// - Parameters:
    ///   - name: 指数名(「日経平均」など)
    ///   - price: 現在値。小数2桁で表示する(3桁区切りなし。ChartNumberFormatter.plainPrice)
    ///   - date: 現在値の日時。「MM/dd HH:mm」で表示する
    func updatePriceInfo(name: String, price: Double, date: Date) {
        let priceText = ChartNumberFormatter.plainPrice(price)
        let dateText = Self.priceDateFormatter.string(from: date)

        // 指数名・現在値は太字の大きい文字、日時は細い小さい文字
        let text = NSMutableAttributedString(string: "\(name) \(priceText) ",
                                             attributes: [.font: UIFont.boldSystemFont(ofSize: 20)])
        text.append(NSAttributedString(string: dateText, attributes: [.font: UIFont.systemFont(ofSize: 16)]))
        self.contentView.priceInfoLabel.attributedText = text
    }

    /// 日時の書式(例: 10/02 15:45)
    private static let priceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()

    // MARK: - ボタンの見た目

    /// メニューのボタンの文字のフォント
    private static let menuTitleFont = UIFont.boldSystemFont(ofSize: 15)
    /// メニューのボタンの幅に足す余裕(枠線の太さ・計算の誤差で文字が折り返されないように)
    private static let menuButtonExtraWidth: CGFloat = 4

    /// メニューを開くボタンの見た目(白地・灰色の枠・青い文字 + 右に ▼)
    private static func menuButtonConfiguration() -> UIButton.Configuration {
        var configuration = self.baseButtonConfiguration()
        configuration.image = UIImage(systemName: "arrowtriangle.down.fill",
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 11))
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 6
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
        configuration.titleLineBreakMode = .byClipping  // 1行で表示する(幅は一番長い名前に合わせてある)
        let font = self.menuTitleFont
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font
            return attributes
        }
        return configuration
    }

    /// アイコンだけのボタンの見た目(白地・灰色の枠・青いアイコン)
    private static func iconButtonConfiguration(systemName: String) -> UIButton.Configuration {
        var configuration = self.baseButtonConfiguration()
        configuration.image = UIImage(systemName: systemName,
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        return configuration
    }

    /// 帯のボタンの共通の見た目(白地・灰色の枠・青)
    private static func baseButtonConfiguration() -> UIButton.Configuration {
        var configuration = UIButton.Configuration.bordered()
        configuration.baseBackgroundColor = .white
        configuration.baseForegroundColor = .systemBlue
        configuration.background.strokeColor = .systemGray4
        configuration.background.strokeWidth = 1
        configuration.background.cornerRadius = 6
        return configuration
    }
}

// MARK: - 帯の中身。見た目は XIB の「Content View」

/// 帯の中身(XIB で配置した部品)。ChartFooterView が外側に貼り付けて使う
final class ChartFooterContentView: UIView {

    /// 指数名・現在値・日時
    @IBOutlet private(set) weak var priceInfoLabel: UILabel!
    /// チャートの種類のボタン
    @IBOutlet private(set) weak var chartTypeButton: UIButton!
    /// チャートの種類のボタンの幅(一番長い名前が入る幅に、コードで変える)
    @IBOutlet private(set) weak var chartTypeButtonWidth: NSLayoutConstraint!
    /// 足種のボタン
    @IBOutlet private(set) weak var periodButton: UIButton!
    /// 足種のボタンの幅(一番長い名前が入る幅に、コードで変える)
    @IBOutlet private(set) weak var periodButtonWidth: NSLayoutConstraint!
    /// 更新ボタン
    @IBOutlet private(set) weak var reloadButton: UIButton!
    /// 縦画面に戻すボタン
    @IBOutlet private(set) weak var rotateButton: UIButton!

    /// 更新ボタンが押されたときの処理(ChartFooterView が設定する)
    var onReload: (() -> Void)?
    /// 縦画面に戻すボタンが押されたときの処理(ChartFooterView が設定する)
    var onRotate: (() -> Void)?

    /// 更新ボタンが押されたとき(XIB で Touch Up Inside に接続)
    @IBAction private func reloadTapped(_ sender: UIButton) {
        self.onReload?()
    }

    /// 縦画面に戻すボタンが押されたとき(XIB で Touch Up Inside に接続)
    @IBAction private func rotateTapped(_ sender: UIButton) {
        self.onRotate?()
    }
}

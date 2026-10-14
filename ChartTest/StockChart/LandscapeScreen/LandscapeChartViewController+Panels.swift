//
//  LandscapeChartViewController+Panels.swift
//  ChartTest
//
//  【Controller】横画面のチャート画面(LandscapeChartViewController)のうち、
//  チャート・パネル・タブの配置と、テクニカル/設定パネルの開閉を担当する部分。
//
//   ┌──┬──────────────────────┐        ┌──────────┬──┬─────────┐
//   │テ│                      │  開く   │          │テ│▒▒▒▒▒▒▒▒▒│
//   │ク│     チャート          │  ───→  │ パネル    │ク│▒ グレー ▒│ ← 背景のグレー(dimmingView)。
//   │設│                      │        │          │設│▒▒▒▒▒▒▒▒▒│   タップするとパネルを閉じる
//   ├──┴──────────────────────┤        ├──────────┴──┴─────────┤
//   │        下の帯           │        │▒▒▒▒▒▒ 下の帯にもグレー ▒▒▒▒▒│
//   └─────────────────────────┘        └───────────────────────┘
//
//  ・重なり順(下から): チャート → 下の帯 → 背景のグレー → パネル → タブ
//    背景のグレーは、パネルを閉じている間は隠す(下の帯のボタンを押せるように)
//  ・タブはパネルの右側に付いて動く(パネルを閉じているときは画面の左端)
//

import UIKit

extension LandscapeChartViewController {

    // MARK: - 組み立て

    /// チャートを配置する(下の帯より奥。位置は chartInsets で決める)
    func setupChartView() {
        self.chartView.translatesAutoresizingMaskIntoConstraints = false
        self.applyDisplayOptionsToChart()
        self.view.insertSubview(self.chartView, belowSubview: self.footerView)

        // チャートはセーフエリアの内側に、chartInsets の余白とタブの分を空けて置く(余白の値は applyChartInsets で設定)
        let safeArea = self.view.safeAreaLayoutGuide
        let leading = self.chartView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor)
        let top = self.chartView.topAnchor.constraint(equalTo: safeArea.topAnchor)
        let bottom = self.chartView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        let trailing = self.chartView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor)
        NSLayoutConstraint.activate([leading, top, bottom, trailing])
        self.chartLeadingConstraint = leading
        self.chartTopConstraint = top
        self.chartBottomConstraint = bottom
        self.chartTrailingConstraint = trailing
        self.applyChartInsets()
    }

    /// chartInsets に合わせて、チャートとタブの位置を決める(チャートの左端は、タブの右側から)
    func applyChartInsets() {
        // viewDidLoad で改めて呼ばれる
        guard self.isViewLoaded else {
            return
        }
        self.chartTopConstraint?.constant = self.chartInsets.top
        self.chartBottomConstraint?.constant = -self.chartInsets.bottom
        self.chartTrailingConstraint?.constant = -self.chartInsets.right
        self.chartLeadingConstraint?.constant = self.chartInsets.left + self.tabWidth + self.tabSpacing
        self.tabClosedConstraint?.constant = self.chartInsets.left
    }

    /// 背景のグレーと、指標の選択メニュー・設定画面を配置する(どれも初期状態は閉じている)
    func setupPanels() {
        // 背景をグレーにする半透明の黒: チャートと下の帯の上・パネルの下に、画面いっぱいに重ねる(閉じているときは隠す)
        self.dimmingView.translatesAutoresizingMaskIntoConstraints = false
        self.dimmingView.backgroundColor = Self.dimmingColor
        self.dimmingView.alpha = 0
        self.dimmingView.isHidden = true
        self.dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimmingViewTapped)))
        self.view.addSubview(self.dimmingView)
        NSLayoutConstraint.activate([
            self.dimmingView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.dimmingView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.dimmingView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.dimmingView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
        ])

        // パネルは、画面の上端(セーフエリアの外)から、セーフエリアの下端(ホームインジケーターの上)までに表示する。
        // 左右はセーフエリアの内側(横画面のノッチを避ける)
        let safeArea = self.view.safeAreaLayoutGuide

        // 指標の選択メニュー: 画面の左側に幅 45% で表示
        self.menuView.translatesAutoresizingMaskIntoConstraints = false
        self.menuView.isHidden = true
        self.menuView.delegate = self
        self.menuView.selectedMainIndicator = self.mainIndicator
        self.menuView.selectedSubIndicator = self.subIndicator
        self.menuView.allowsOnlyNone = !self.chartType.usesTechnicalIndicators(in: self.market)
        self.menuView.availableMainIndicators = MainChartIndicator.choices(for: self.market, period: self.period)
        self.menuView.availableSubIndicators = SubChartIndicator.choices(for: self.market, period: self.period)
        self.menuView.accessibilityIdentifier = "chart.technicalMenu"  // UI テストで探すための名前
        self.view.addSubview(self.menuView)

        // 設定画面: 画面の左側に幅 75% で表示(左側リスト + 右側パネル)
        self.settingsView.translatesAutoresizingMaskIntoConstraints = false
        self.settingsView.isHidden = true
        self.settingsView.delegate = self
        self.settingsView.accessibilityIdentifier = "chart.settingsView"  // UI テストで探すための名前
        self.view.addSubview(self.settingsView)

        NSLayoutConstraint.activate([
            self.menuView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.menuView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            self.menuView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            self.menuView.widthAnchor.constraint(equalTo: safeArea.widthAnchor, multiplier: 0.45),

            self.settingsView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.settingsView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            self.settingsView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            self.settingsView.widthAnchor.constraint(equalTo: safeArea.widthAnchor, multiplier: 0.75),
        ])
    }

    /// テクニカル/設定タブを縦に並べて配置する
    func setupTabs() {
        self.configureTabButton(self.technicalTabButton, title: "テクニカル", action: #selector(self.technicalTabTapped))
        self.configureTabButton(self.settingsTabButton, title: "設定", action: #selector(self.settingsTabTapped))
        // UI テストで探すための名前(タブの文字は縦書きで1文字ずつ改行しているので、文字では探しにくい)
        self.technicalTabButton.accessibilityIdentifier = "chart.technicalTab"
        self.settingsTabButton.accessibilityIdentifier = "chart.settingsTab"

        self.tabStack.addArrangedSubview(self.technicalTabButton)
        self.tabStack.addArrangedSubview(self.settingsTabButton)
        self.tabStack.axis = .vertical
        self.tabStack.spacing = 4
        self.tabStack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.tabStack)

        // タブの左端は、開いているパネルによって切り替える
        let closed = self.tabStack.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor,
                                                            constant: self.chartInsets.left)
        self.tabClosedConstraint = closed
        self.tabTechnicalOpenedConstraint = self.tabStack.leadingAnchor.constraint(equalTo: self.menuView.trailingAnchor)
        self.tabSettingsOpenedConstraint = self.tabStack.leadingAnchor.constraint(equalTo: self.settingsView.trailingAnchor)

        NSLayoutConstraint.activate([
            self.tabStack.topAnchor.constraint(equalTo: self.chartView.topAnchor),  // チャートの上端に揃える
            self.tabStack.widthAnchor.constraint(equalToConstant: self.tabWidth),
            self.technicalTabButton.heightAnchor.constraint(equalToConstant: 120),
            self.settingsTabButton.heightAnchor.constraint(equalToConstant: 72),
            closed,
        ])
    }

    /// タブの見た目を設定する(縦書き・赤背景・右側の角だけ丸める)
    private func configureTabButton(_ button: UIButton, title: String, action: Selector) {
        // 1文字ずつ改行して縦書きにする
        let characters = title.map { character in String(character) }
        let verticalTitle = characters.joined(separator: "\n")
        button.setTitle(verticalTitle, for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        button.titleLabel?.textAlignment = .center
        button.setTitleColor(UIColor(resource: .chartPanelTabText), for: .normal)
        button.backgroundColor = UIColor(resource: .chartPanelTab)
        button.layer.cornerRadius = 6
        button.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    // MARK: - パネルの開閉

    /// 「テクニカル」タブがタップされたら、指標の選択メニューを開閉する
    @objc private func technicalTabTapped() {
        self.togglePanel(.technical)
    }

    /// 「設定」タブがタップされたら、設定画面を開閉する
    @objc private func settingsTabTapped() {
        self.togglePanel(.settings)
    }

    /// 背景のグレーの部分がタップされたら、開いているパネルを閉じる
    @objc private func dimmingViewTapped() {
        self.closePanels()
    }

    /// 開いているパネル(テクニカル/設定)を閉じる。
    /// 設定画面で「決定」していない変更は捨てる
    @objc func closePanels() {
        self.setOpenPanel(nil, animated: true)
    }

    /// 指定したパネルが開いていれば閉じ、閉じていれば開く
    private func togglePanel(_ panel: Panel) {
        if self.openPanel == panel {
            self.setOpenPanel(nil, animated: true)
        } else {
            self.setOpenPanel(panel, animated: true)
        }
    }

    /// 指定したパネルを開く(もう一方は閉じる)。nil の場合は両方閉じる
    ///   1. 状態を変える(設定画面を開くときは、編集用のコピーを作り直す)
    ///   2. タブをパネルの右側(閉じたときは左端)に移す
    ///   3. 開くパネルと背景のグレーを、透明な状態で表示しておく
    ///   4. フェードで、開くパネルを不透明に・閉じるパネルを透明にする
    ///   5. 閉じたパネルを隠す(タッチを受けないように)
    func setOpenPanel(_ panel: Panel?, animated: Bool) {
        // 設定画面を新しく開くときは、今のパラメータから編集用のコピーを作り直す
        if panel == .settings {
            if self.openPanel != .settings {
                self.beginSettingsEditing()
            }
        }

        // パネルを開く/閉じるが切り替わるときは、外にも知らせる(開いたときはすぐ、閉じたときはアニメーションのあと)
        let wasOpen = self.isPanelOpen
        self.openPanel = panel
        let didOpen = !wasOpen && self.isPanelOpen
        let didClose = wasOpen && !self.isPanelOpen
        if didOpen {
            self.onPanelVisibilityChange?(true)
        }

        self.updateTabPosition()
        self.showOpeningPanelTransparently()
        if animated {
            UIView.animate(withDuration: Self.panelAnimationDuration, animations: {
                self.applyPanelAlpha()
            }, completion: { _ in
                self.hideClosedPanels()
                if didClose {
                    self.onPanelVisibilityChange?(false)
                }
            })
        } else {
            self.applyPanelAlpha()
            self.hideClosedPanels()
            if didClose {
                self.onPanelVisibilityChange?(false)
            }
        }
    }

    /// パネルの種類と、そのパネルの View の組
    private var panelViews: [(kind: Panel, view: UIView)] {
        return [(kind: .technical, view: self.menuView), (kind: .settings, view: self.settingsView)]
    }

    /// タブの位置を、開いているパネルに合わせる(先に全部無効にしてから、対応する制約だけを有効にする)
    private func updateTabPosition() {
        for constraint in [self.tabClosedConstraint, self.tabTechnicalOpenedConstraint, self.tabSettingsOpenedConstraint] {
            constraint?.isActive = false
        }
        switch self.openPanel {
        case .technical:
            self.tabTechnicalOpenedConstraint?.isActive = true
        case .settings:
            self.tabSettingsOpenedConstraint?.isActive = true
        case nil:
            self.tabClosedConstraint?.isActive = true
        }
    }

    /// 開くパネルと背景のグレーを、フェードインできるよう透明な状態で表示しておく
    private func showOpeningPanelTransparently() {
        if self.isPanelOpen {
            self.dimmingView.isHidden = false
        }
        for panel in self.panelViews {
            // 開くパネルだけが対象
            guard panel.kind == self.openPanel else {
                continue
            }
            // すでに表示中ならそのまま
            guard panel.view.isHidden else {
                continue
            }
            panel.view.isHidden = false
            panel.view.alpha = 0
        }
    }

    /// フェードの最後の状態にする: 開いているパネルは不透明・それ以外は透明。
    /// 背景のグレーは、どちらかのパネルを開いているときだけ表示する
    private func applyPanelAlpha() {
        for panel in self.panelViews {
            if panel.kind == self.openPanel {
                panel.view.alpha = 1
            } else {
                panel.view.alpha = 0
            }
        }
        if self.isPanelOpen {
            self.dimmingView.alpha = 1
        } else {
            self.dimmingView.alpha = 0
        }
        // タブの移動もアニメーションさせる。
        // 画面に表示される前は、レイアウトしない
        // (表示前にレイアウトすると、隠れている設定画面の表までレイアウトされて警告が出るため)
        if self.view.window != nil {
            self.view.layoutIfNeeded()
        }
    }

    /// 閉じ終わったパネル(と、パネルを閉じたときは背景のグレー)を隠して、タッチを受けないようにする
    private func hideClosedPanels() {
        for panel in self.panelViews where panel.kind != self.openPanel {
            panel.view.isHidden = true
        }
        if !self.isPanelOpen {
            self.dimmingView.isHidden = true
        }
    }
}

// MARK: - TechnicalMenuViewDelegate(指標の選択を状態に反映する)

extension LandscapeChartViewController: TechnicalMenuViewDelegate {

    func technicalMenuView(_ menuView: TechnicalMenuView, didSelectMainIndicator indicator: MainChartIndicator) {
        self.mainIndicator = indicator
    }

    func technicalMenuView(_ menuView: TechnicalMenuView, didSelectSubIndicator indicator: SubChartIndicator) {
        self.subIndicator = indicator
    }
}

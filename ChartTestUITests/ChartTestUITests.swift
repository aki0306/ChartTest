//
//  ChartTestUITests.swift
//  ChartTestUITests
//
//  サンプルアプリの画面を自動で操作する UI テスト。
//  各テストは、操作するたびにスクリーンショットを残す(テスト結果の Attachments で見られる)。
//
//  ・縦チャートの足種の切り替え(1分足〜月足)
//  ・日本株/国内指数/海外の切り替え(海外は 1分足・日中足 が押せない)
//  ・横画面の下の帯のメニュー(チャートの種類・足種。一番上が最初の項目になっているか)
//  ・横画面のテクニカル/設定パネル
//
//  ボタンは accessibilityIdentifier(「portrait.periodControl」など)で探す。
//  識別子は、アプリ側の各ファイルで「UI テストで探すための名前」として付けている。
//
//  実行: Xcode で ⌘U(スキーム ChartTest)、またはターミナルで
//      xcodebuild test -project ChartTest.xcodeproj -scheme ChartTest -destination 'platform=iOS Simulator,name=iPhone 17'
//

import XCTest

@MainActor
final class ChartTestUITests: XCTestCase {

    /// 画面に出るまで待つ時間(秒)
    private let timeout: TimeInterval = 10

    private var app: XCUIApplication!

    override func setUp() async throws {
        self.continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        self.app = XCUIApplication()
        self.app.launch()
    }

    override func tearDown() async throws {
        // 次のテストが縦画面から始まるように戻す
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - 縦チャート

    /// 縦チャートの足種を 1分足 → 月足 の順に切り替えて、選んだボタンが選択中になるか確かめる
    func testPortraitPeriodSwitching() {
        let periodControl = self.app.segmentedControls["portrait.periodControl"]
        XCTAssertTrue(periodControl.waitForExistence(timeout: self.timeout))

        // 縦チャートのボタンの文字(ChartPeriod.title。日足・週足・月足は間に空白が入る)
        let titles = ["1分足", "日中足", "日 足", "週 足", "月 足"]
        for title in titles {
            let segment = periodControl.buttons[title]
            segment.tap()
            XCTAssertTrue(segment.isSelected, "\(title) が選択中になっていない")
            self.attachScreenshot(named: "縦チャート_\(title)")
        }
    }

    /// 日本株/国内指数/海外を切り替えて、海外では 1分足・日中足 が押せなくなるか確かめる
    func testMarketSwitching() {
        let marketControl = self.app.segmentedControls["portrait.marketControl"]
        let periodControl = self.app.segmentedControls["portrait.periodControl"]
        XCTAssertTrue(marketControl.waitForExistence(timeout: self.timeout))

        // 切り替えボタンの文字と、1分足・日中足を押せるか(国内は押せる、海外は押せない)
        let markets: [(title: String, allowsIntraday: Bool)] = [
            ("日本株", true),
            ("国内指数", true),
            ("海外(R)", false),
            ("海外(D)", false),
        ]
        for market in markets {
            let segment = marketControl.buttons[market.title]
            segment.tap()
            XCTAssertTrue(segment.isSelected, "\(market.title) が選択中になっていない")
            XCTAssertEqual(periodControl.buttons["1分足"].isEnabled, market.allowsIntraday, "\(market.title) の 1分足")
            XCTAssertEqual(periodControl.buttons["日中足"].isEnabled, market.allowsIntraday, "\(market.title) の 日中足")
            self.attachScreenshot(named: "指数の種類_\(market.title)")
        }
    }

    // MARK: - 横画面の下の帯

    /// 下の帯のメニューが、最初の項目(ローソク足・日中足)を一番上にして並ぶか確かめ、選んだものに切り替わるか確かめる
    func testLandscapeFooterMenus() {
        self.rotateToLandscape()

        // チャートの種類: ローソク足が一番上、折線チャートが一番下
        let chartTypeButton = self.app.buttons["footer.chartTypeButton"]
        self.waitUntilHittable(chartTypeButton)
        chartTypeButton.tap()
        let candlestick = self.menuItem("ローソク足")
        let lineChart = self.menuItem("折線チャート")
        XCTAssertTrue(lineChart.waitForExistence(timeout: self.timeout))
        XCTAssertLessThan(candlestick.frame.minY, lineChart.frame.minY, "ローソク足が折線チャートより上にない")
        self.attachScreenshot(named: "横画面_チャートの種類のメニュー")

        lineChart.tap()
        XCTAssertEqual(chartTypeButton.label, "折線チャート")

        // 足種: 折線チャートでは 1分足 を選べないので、日中足が一番上、月足が一番下
        let periodButton = self.app.buttons["footer.periodButton"]
        periodButton.tap()
        let intraday = self.menuItem("日中足")
        let monthly = self.menuItem("月足")
        XCTAssertTrue(monthly.waitForExistence(timeout: self.timeout))
        XCTAssertFalse(self.menuItem("1分足").exists, "折線チャートで 1分足 が選べる")
        XCTAssertLessThan(intraday.frame.minY, monthly.frame.minY, "日中足が月足より上にない")
        self.attachScreenshot(named: "横画面_足種のメニュー")

        self.menuItem("週足").tap()
        XCTAssertEqual(periodButton.label, "週足")
        self.attachScreenshot(named: "横画面_折線チャート_週足")
    }

    // MARK: - 横画面のテクニカル/設定パネル

    /// テクニカルのメニューで指標を選び、設定画面を開いて「決定」で閉じる
    func testTechnicalAndSettingsPanels() {
        self.rotateToLandscape()

        // テクニカル: ボリンジャーバンド + ＲＳＩ を選ぶ(選んでもメニューは開いたまま)
        let technicalTab = self.app.buttons["chart.technicalTab"]
        self.waitUntilHittable(technicalTab)
        technicalTab.tap()
        let bollinger = self.app.buttons["technicalMenu.main.ボリンジャーバンド"]
        self.waitUntilHittable(bollinger)
        bollinger.tap()
        self.app.buttons["technicalMenu.sub.ＲＳＩ"].tap()
        self.attachScreenshot(named: "テクニカル_ボリンジャーバンド_RSI")

        // もう一度タブを押すと閉じる
        technicalTab.tap()
        self.waitUntilGone(bollinger)
        self.attachScreenshot(named: "テクニカル_閉じたあと")

        // 設定: 開いて「決定」で閉じる
        let settingsTab = self.app.buttons["chart.settingsTab"]
        settingsTab.tap()
        let confirmButton = self.app.buttons["settings.confirmButton"]
        self.waitUntilHittable(confirmButton)
        self.attachScreenshot(named: "設定画面")

        confirmButton.tap()
        self.waitUntilGone(confirmButton)
    }

    // MARK: - 共通の操作

    /// 横画面にして、下の帯が出るまで待つ
    private func rotateToLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        self.waitUntilHittable(self.app.buttons["footer.rotateButton"])
    }

    /// メニュー(UIMenu)の項目。下の帯のボタンも同じ文字なので、帯のボタン(識別子が footer. で始まる)を除いて探す
    private func menuItem(_ title: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label == %@ AND NOT (identifier BEGINSWITH 'footer.')", title)
        return self.app.buttons.matching(predicate).firstMatch
    }

    /// 要素が押せる状態になるまで待つ
    private func waitUntilHittable(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: self.timeout)
        XCTAssertEqual(result, .completed, "押せる状態にならない: \(element)", file: file, line: line)
    }

    /// 要素が画面から消えるまで待つ
    private func waitUntilGone(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: self.timeout)
        XCTAssertEqual(result, .completed, "消えない: \(element)", file: file, line: line)
    }

    /// 画面全体のスクリーンショットを、テスト結果に残す(テストが成功しても消さない)
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }
}

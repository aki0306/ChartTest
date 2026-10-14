//
//  LandscapeChartViewController+Footer.swift
//  ChartTest
//
//  【Controller】横画面のチャート画面(LandscapeChartViewController)のうち、下の帯(ChartFooterView)を担当する部分。
//
//   ┌─────────────────────────────────────────────────────────────────┐
//   │日経平均 68309.46 10/02 15:45   [ローソク足 ▼] [日足 ▼] [↻] │ [⤾] │
//   └─────────────────────────────────────────────────────────────────┘
//     updatePriceInfo                 チャートの種類  足種    更新   縦画面に戻す
//
//  ・見た目は帯(ChartFooterView)が決め、ここではメニューの中身と、押されたときの処理だけを渡す
//  ・足種・更新・縦画面に戻すは、データの取得や画面を閉じる処理が必要なので、onPeriodSelect・onReload・onRotate で呼び出し側に任せる
//

import UIKit

extension LandscapeChartViewController {

    // MARK: - 組み立て

    /// 下の帯のメニュー・ボタンを設定する
    func configureFooter() {
        self.updateChartTypeMenu()
        self.updatePeriodMenu()
        self.footerView.onReload = { [weak self] in
            self?.onReload?()
        }
        self.footerView.onRotate = { [weak self] in
            self?.onRotate?()
        }
    }

    // MARK: - チャートの種類

    /// チャートの種類が変わったとき(メニューからでも、コードから chartType を変えた場合でも)。
    /// ボタンの表示を合わせ、表示中の足種がその種類では選べない場合(新値足の1分足)は、選べる足種に切り替える
    func chartTypeDidChange() {
        // 画面を読み込む前は、帯がまだない(viewDidLoad の configureFooter で合わせる)
        guard self.isViewLoaded else {
            return
        }
        self.updateChartTypeMenu()
        self.switchPeriodIfUnavailable()
    }

    /// 「チャートの種類」ボタンの文字とメニュー(選択中の種類にチェック)を、選択中のチャートの種類に合わせる。
    /// メニューの中身は開くたびに作るので、指数の種類(海外指数は ローソク足・折線チャート だけ)が後から変わっても反映される
    func updateChartTypeMenu() {
        let items = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self else {
                completion([])
                return
            }
            let selectedType = self.chartType
            var actions: [UIAction] = []
            for chartType in ChartType.choices(for: self.market) {
                let action = UIAction(title: chartType.title) { [weak self] _ in
                    self?.chartType = chartType  // ボタンの表示は chartTypeDidChange で更新される
                }
                if chartType == selectedType {
                    action.state = .on
                }
                actions.append(action)
            }
            completion(actions)
        }
        // ボタンの幅は、すべての種類の名前のうち一番長いもの(「折線チャート」など)が1行で入る幅にする
        let candidates = ChartType.allCases.map { chartType in chartType.title }
        self.footerView.setChartTypeMenu(title: self.chartType.title, candidates: candidates, menu: UIMenu(children: [items]))
    }

    // MARK: - 足種

    /// 「足種」ボタンの文字とメニュー(表示中の足種にチェック)を、表示中の足種に合わせる。
    /// メニューの中身は開くたびに作るので、指数の種類(海外指数は 日足・週足・月足 だけ)・
    /// チャートの種類(VWAP は 日中足 だけ、新値足・折線チャートは 1分足 を除く。ChartType.periods(in:))が後から変わっても反映される
    func updatePeriodMenu() {
        // 画面を読み込む前は、帯がまだない(viewDidLoad の configureFooter で合わせる)
        guard self.isViewLoaded else {
            return
        }
        let items = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self else {
                completion([])
                return
            }
            let selectedPeriod = self.period
            var actions: [UIAction] = []
            for period in self.availablePeriods {
                let action = UIAction(title: Self.shortTitle(of: period)) { [weak self] _ in
                    self?.onPeriodSelect?(period)
                }
                if period == selectedPeriod {
                    action.state = .on
                }
                actions.append(action)
            }
            completion(actions)
        }
        // ボタンの幅は、すべての足種の名前のうち一番長いもの(「1分足」「日中足」)が1行で入る幅にする
        let candidates = ChartPeriod.allCases.map { period in Self.shortTitle(of: period) }
        self.footerView.setPeriodMenu(title: Self.shortTitle(of: self.period), candidates: candidates,
                                      menu: UIMenu(children: [items]))
    }

    /// 今のチャートの種類・指数の種類で選べる足種(VWAP は 日中足 だけ、新値足・折線チャートは 1分足 を除く)
    private var availablePeriods: [ChartPeriod] {
        return self.chartType.periods(in: self.market)
    }

    /// 表示中の足種が今のチャートの種類では選べない場合(1分足のまま新値足・折線チャートにした・日足のまま VWAP にした など)、
    /// 選べる足種に切り替える。データの取得はアプリの仕事なので、足種のメニューで選んだときと同じく onPeriodSelect を呼ぶ
    /// (日中足を選べるなら 日中足 に切り替える。日中足も選べなければ、選べる足種の先頭)
    private func switchPeriodIfUnavailable() {
        let periods = self.availablePeriods
        if periods.contains(self.period) {
            return
        }
        var nextPeriod = periods.first
        if periods.contains(.intraday) {
            nextPeriod = .intraday
        }
        guard let nextPeriod else {
            return
        }
        self.onPeriodSelect?(nextPeriod)
    }

    /// ボタン・メニューに出す足種の名前。タブ用の名前(「月 足」)から空白を除く(「月足」)
    private static func shortTitle(of period: ChartPeriod) -> String {
        return period.title.replacingOccurrences(of: " ", with: "")
    }

    // MARK: - 指数名・現在値・日時

    /// 下の帯の左に、指数名・現在値・日時を表示する(例:「日経平均 68309.46 10/02 15:45」。書式は ChartFooterView)
    /// - Parameters:
    ///   - name: 指数名(「日経平均」など)
    ///   - price: 現在値。小数2桁で表示する(3桁区切りなし)
    ///   - date: 現在値の日時。「MM/dd HH:mm」で表示する
    @objc(updatePriceInfoWithName:price:date:)
    func updatePriceInfo(name: String, price: Double, date: Date) {
        // メインスレッドでなければ、メインスレッドで呼び直す(通信の完了処理から直接呼ばれても安全にする。MainThread)
        guard MainThread.isCurrent(orRetry: { self.updatePriceInfo(name: name, price: price, date: date) }) else {
            return
        }

        self.loadViewIfNeeded()
        self.footerView.updatePriceInfo(name: name, price: price, date: date)
    }
}

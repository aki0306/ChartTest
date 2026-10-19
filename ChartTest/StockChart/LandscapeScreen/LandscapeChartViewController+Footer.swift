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
//  【足種を切り替えたときの流れ】
//   ① 「日足 ▼」でメニューを開き、「週足」を押す
//   ② periodMenuSelected → selectPeriod が、次の2つを順に行う
//      1. switchPeriodAndClearChart(LandscapeChartViewController.swift)で、足種のボタンを「週足」にし、チャートを消す
//      2. onPeriodSelect で、週足のデータの取得を頼む
//   ③ onPeriodSelect(Sample/ViewController.swift の presentLandscapeChart)が週足のデータを用意して、setCandles(_:period:) を呼ぶ
//   ④ setCandles(LandscapeChartViewController.swift)で、週足のデータでチャートを描く
//
//  【チャートの種類を切り替えたときの流れ】
//   ① 「ローソク足 ▼」でメニューを開き、「折線チャート」を押す
//   ② chartTypeMenuSelected が、次の2つを順に行う
//      1. chartType を変える(データはそのままなので、アプリには知らせない)
//         → chartType の didSet(LandscapeChartViewController.swift)でチャートを描き直し、ボタンの文字を合わせる
//      2. 表示中の足種がその種類で使えなければ(1分足のまま新値足・日足のまま VWAP など)、使える足種に切り替える
//         → 足種の切り替えと同じく selectPeriod で切り替える(このあとは【足種を切り替えたときの流れ】の ②・③・④)
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

    /// チャートの種類が変わったとき(メニューからでも、コードから chartType を変えた場合でも)。ボタンの文字を合わせる
    func chartTypeDidChange() {
        // 画面を読み込む前は、帯がまだない(viewDidLoad の configureFooter で合わせる)
        guard self.isViewLoaded else {
            return
        }
        self.updateChartTypeMenu()
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
                    self?.chartTypeMenuSelected(chartType)
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

    /// チャートの種類のメニューで種類が選ばれたとき(流れの②)
    private func chartTypeMenuSelected(_ chartType: ChartType) {
        // 1. 種類を変える(didSet でチャートを描き直し、ボタンの文字も合わせる)
        self.chartType = chartType
        // 2. 表示中の足種がこの種類で使えなければ、使える足種に切り替えるようアプリに頼む
        self.switchPeriodIfUnavailable()
    }

    // MARK: - 足種

    /// 足種のメニューで足種が選ばれたとき(流れの②)
    private func periodMenuSelected(_ period: ChartPeriod) {
        self.selectPeriod(period)
    }

    /// 足種を切り替える(足種のメニューで選んだとき・チャートの種類で使えない足種になったとき)。
    /// 足種のボタンをすぐこの足種にしてチャートを消し、onPeriodSelect でこの足種のデータを取得してもらう。
    /// データが setCandles(_:period:) で渡されると、チャートを描く
    private func selectPeriod(_ period: ChartPeriod) {
        self.switchPeriodAndClearChart(to: period)
        self.onPeriodSelect?(period)
    }

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
                    self?.periodMenuSelected(period)
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
    /// 選べる足種に切り替える(チャートの種類のメニューで選んだときの 2.)。
    /// 足種のメニューで選んだときと同じく selectPeriod で切り替える
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
        self.selectPeriod(nextPeriod)
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

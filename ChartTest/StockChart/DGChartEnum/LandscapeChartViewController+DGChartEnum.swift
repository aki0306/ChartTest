//
//  LandscapeChartViewController+DGChartEnum.swift
//  ChartTest
//
//  【Controller】横画面(LandscapeChartViewController)の足種を、DGChartEnum の enum で読むためのプロパティ(Objective-C からも使える)。
//
//    | プロパティ | LandscapeChartViewController のプロパティ |
//    |------------|-------------------------------------------|
//    | chartData  | period(1分足〜月足。読むだけ)           |
//
//  横画面の足種は、前回横画面で選んでいた足種(ChartStateStore)・足種のメニューで選んだ足種で決まるので、外からは変えない。
//  データを DGChartData で取得する場合は、market を設定したあとでこの値を読み、その足種のデータを渡す。
//
//    Objective-C:
//        landscapeViewController.market = IndexMarketJapanIndex;        // 先に設定する(前回選んでいた状態になる)
//        DGChartData chartData = landscapeViewController.chartData;      // VWAP を選んでいたら DGChartDataMidDay
//        // chartData の足種のデータを取得して…
//        [landscapeViewController updateChartData:responseArray];
//
//  ・この enum を使わない場合は、DGChartEnum フォルダごと削除してよい
//  ・横画面を使わない場合は、このファイルだけを削除する
//

import Foundation

extension LandscapeChartViewController {

    /// 表示中の足種(period)を DGChartData で返す(読むだけ)
    @objc var chartData: DGChartData {
        return DGChartData(period: self.period)
    }
}

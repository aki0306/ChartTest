# ChartTest

[DGCharts](https://github.com/ChartsOrg/Charts) を使って株価チャート(ローソク足 + テクニカル指標)を表示する iOS アプリのサンプルです。
チャート部分(`ChartTest/StockChart/`)は、ほかのアプリにもそのまま組み込める共通部品として作っています。

- UIKit / iOS 18 以上 / 常にライトモード
- Swift と Objective-C のどちらからでも呼び出せます(「使い方」に両方の書き方があります。Objective-C のサンプルは `ChartTest/ObjCSample/`)

## 画面

| 縦画面 | 横画面 |
|---|---|
| 上部のタブで足種(1分足・日中足・日足・週足・月足)を切り替える。チャートは移動平均線 + 出来高 | 左端の「テクニカル」「設定」タブで、指標の切り替えや設定の変更ができる。右下のボタンでチャートの種類を切り替える(日足) |
| `Portrait.storyboard` / `PortraitChartViewController` | `Landscape.storyboard` / `LandscapeChartViewController` |

`ViewController`(`Main.storyboard`)が縦画面用と横画面用の両方を読み込み、画面の向きに合わせて片方だけを表示します。

### 横画面のチャートの種類

右下のボタンで切り替えます(`ChartType`)。ローソク足以外では、テクニカル指標とサブチャートは表示しません。

- 「テクニカル」のメニューは、メインチャート・サブチャートとも「なし」だけになります(ローソク足に戻すと、それまでの選択に戻ります)
- 「設定」は使えますが、「4本値」はオンにしてもローソク足のときだけ表示されます

| 種類 | 表示 |
|---|---|
| ローソク足 | ローソク足 + テクニカル指標(メイン・サブ) |
| VWAP：線 / VWAP：点 | VWAP を線または点で表示(ローソク足は描かない)。同じ日の足で累計し、日付が変わると計算し直す。出来高が 0 のデータでは計算できないので、凡例と「現在、指定の条件で表示できる情報はありません。」を表示する |
| 折線チャート | 終値を線で結んだチャート(ローソク足は描かない)。現在値に破線を引く |
| 新値足 | 3本新値の新値足。陽線は枠だけ、陰線は塗りつぶしで、現在値に破線を引く。X軸は時間ではなく新値の本数で、50本分の幅で表示する(50本未満なら右寄せ) |

### 縦画面の足種

選べる足種は指数の種類で変わります(`IndexMarket`)。

| 指数 | タブ |
|---|---|
| 国内指数(`.domestic`) | 1分足・日中足・日足・週足・月足 |
| 海外指数(`.overseas`) | 日足・週足・月足 |

足種ごとに、次の表示が変わります(`ChartPeriod`)。

| 足種 | 移動平均(短期/長期) | X軸ラベル | 初期表示 | 出来高の凡例 |
|---|---|---|---|---|
| 1分足 | 5 / 25 | 09:15 | 全件 | 出来高 |
| 日中足(5分) | 5 / 25 | 09:15 | 全件 | 出来高 |
| 日足 | 5 / 25 | 7/16 | 直近 55 本 | 出来高 |
| 週足 | 13 / 26 | 2025/9 | 直近 55 本 | 出来高(平均) |
| 月足 | 5 / 25 | 2023/9 | 全件 | 出来高(平均) |

- 出来高がすべて 0 のデータ(指数の1分足・日中足など)は、出来高の棒と線を描かず、凡例だけを表示します
- データが0件のときは、枠と凡例を残したまま「現在、指定の条件で表示できる情報はありません。」と表示します

## 使い方(Swift / Objective-C)

チャートの部品は、Swift と Objective-C のどちらからでも呼び出せます。以下、それぞれの書き方を並べています。

### 準備(Objective-C のみ)

Swift のクラスは、Xcode が自動で作るヘッダ `<プロダクトモジュール名>-Swift.h`(このアプリでは `ChartTest-Swift.h`)を import すると使えます。

```objc
#import "ChartTest-Swift.h"
```

動くサンプル:

| ファイル | 内容 |
|---|---|
| [`ObjCSample/ObjCPortraitChartViewController.m`](ChartTest/ObjCSample/ObjCPortraitChartViewController.m) | 足種のタブ付きの縦画面(`PortraitChartViewController`)を使う |
| [`ObjCSample/ObjCChartViewController.m`](ChartTest/ObjCSample/ObjCChartViewController.m) | 指標メニュー付きのチャート(`StockChartViewController`)を使う |

### 1. データを作る

ローソク足1本を `StockCandle` で作り、**日付の古い順**に並べた配列を渡します。

```swift
// Swift
let candle = StockCandle(date: date, open: 66_000, high: 66_500, low: 65_800, close: 66_300, volume: 2.4e9)
let candles: [StockCandle] = [candle /* , … */]
```

```objc
// Objective-C
StockCandle *candle = [[StockCandle alloc] initWithDate:date
                                                   open:66000
                                                   high:66500
                                                    low:65800
                                                  close:66300
                                                 volume:2.4e9];
NSArray<StockCandle *> *candles = @[candle /* , … */];
```

#### `StockCandle` の各値

上の例の値は、次の意味です。

| 引数 | 意味 | 例の値 | 説明 |
|---|---|---|---|
| `date` | 足の日付・時刻 | `date` | X軸の日付ラベル・4本値の日付に使う。1分足・日中足は足の開始時刻(9:00, 9:05, …)、日足はその日、週足・月足は期間を代表する日(サンプルでは週足は金曜日、月足は1日) |
| `open` | 始値(その期間の最初の値段) | `66_000` | 66,000円 |
| `high` | 高値(その期間の一番高い値段) | `66_500` | 66,500円 |
| `low` | 安値(その期間の一番安い値段) | `65_800` | 65,800円 |
| `close` | 終値(その期間の最後の値段) | `66_300` | 66,300円。最新の足の終値が「現在値」になる |
| `volume` | 出来高(その期間に売買された株数) | `2.4e9` | 2,400,000,000株(24億株)。出来高が配信されない指数の1分足・日中足などは `0` を入れる |

- `66_000` の `_` は、Swift の数字の区切り(読みやすくするためだけのもの)で、`66000` と同じです。Objective-C では `66000` と書きます
- `2.4e9` は「2.4 × 10の9乗」= 2,400,000,000 です
- 値は `low ≦ open, close ≦ high` になるように入れてください(ローソク足のヒゲは安値〜高値、実体は始値〜終値で描かれます)
- 週足・月足の出来高に「期間中の1日あたりの平均」を入れる場合は、縦画面の凡例が「出来高(平均)」になります(`ChartPeriod`)

この1本はローソク足では次のように描かれます。終値(66,300)が始値(66,000)より高いので、陽線(赤)です。

```
  66,500 ─┬─  ← 高値(ヒゲの上端)
          │
  66,300 ┌┴┐ ← 終値(実体の上端)
         │ │    陽線(終値 > 始値)は赤、陰線(終値 < 始値)は青
  66,000 └┬┘ ← 始値(実体の下端)
          │
  65,800 ─┴─  ← 安値(ヒゲの下端)
```

#### チャート・指標ごとに使う値

どのチャート・指標も、`StockCandle` の配列だけから計算します。それぞれが使う値は次のとおりです。

| チャート・指標 | 使う値 | 描き方 | 上の例の1本の場合 |
|---|---|---|---|
| ローソク足 | 始値・高値・安値・終値 | 実体は始値〜終値、ヒゲは安値〜高値 | 65,800〜66,500 のヒゲ、66,000〜66,300 の赤い実体 |
| 折線チャート | 終値 | 各足の終値を線で結ぶ。最新の終値に現在値の破線 | 66,300 の点 |
| VWAP：線 / VWAP：点 | 高値・安値・終値・出来高・日付 | 同じ日の足の「(高値 + 安値 + 終値) ÷ 3 × 出来高」の合計 ÷ 出来高の合計。日付が変わると計算し直す | (66,500 + 65,800 + 66,300) ÷ 3 = 66,200 |
| 新値足 | 終値・日付 | 終値が直前の線を更新したときだけ線を足す(3本新値)。最新の終値に現在値の破線 | 1本だけでは線はできない(2本目以降の終値と比べて線を作る) |
| 4本値(十字線) | 日付・始値・高値・安値・終値 | 十字線の位置の足の値をそのまま表示 | 日付・66,000 / 66,500 / 65,800 / 66,300 |
| 移動平均線・多重移動平均線 | 終値 | 直近 n 本の終値の平均(短期 5本・長期 25本など) | ― |
| ボリンジャーバンド | 終値 | 直近 20本の終値の平均 ± 標準偏差 × σ | ― |
| 一目均衡表 | 高値・安値・終値 | 転換線・基準線・先行スパンは期間中の(最高値 + 最安値)÷ 2、遅行スパンは終値 | ― |
| パラボリック | 高値・安値・終値 | 高値・安値の更新に合わせて SAR を動かす | ― |
| 出来高 | 出来高 | 出来高の棒 + 直近 25本の平均線 | 2,400,000,000 の棒 |
| 移動平均乖離率・RSI・サイコロジカル・MACD | 終値 | 終値の変化から計算 | ― |
| ストキャス・DMI | 高値・安値・終値 | 期間中の高値・安値と終値から計算 | ― |

- 出来高が 0 のデータでは、出来高の棒と VWAP は描けません(凡例と「表示できる情報はありません」を表示します)
- 計算式の詳細は [`TechnicalIndicators.swift`](ChartTest/StockChart/Model/TechnicalIndicators.swift)、期間などの設定値は [`IndicatorParameters.swift`](ChartTest/StockChart/Model/IndicatorParameters.swift) にあります

動作確認用のダミーデータは `SampleData` で作れます。

```swift
let candles = SampleData.candles(for: .daily)              // Swift
```

```objc
NSArray<StockCandle *> *candles = [SampleData candlesForPeriod:ChartPeriodDaily];   // Objective-C
```

### 2. 足種のタブ付きの縦画面(PortraitChartViewController)

指数の種類と、「足種を指定してデータを読み込む処理」を渡します。タブが押されるたびにその処理が呼ばれ、足種に合った設定で描き直されます。

```swift
// Swift
let viewController = PortraitChartViewController.instantiate()   // Portrait.storyboard から生成
viewController.market = .domestic                                // 国内指数(海外指数なら .overseas)
viewController.candleLoader = { period in
    return SampleData.candles(for: period)                       // 実際のアプリでは API から取得する
}
viewController.reloadChart()                                     // 選択中の足種(最初は日足)を表示
```

```objc
// Objective-C
PortraitChartViewController *viewController = [PortraitChartViewController instantiate];
viewController.market = IndexMarketDomestic;                     // 国内指数(海外指数なら IndexMarketOverseas)
viewController.candleLoader = ^NSArray<StockCandle *> *(ChartPeriod period) {
    return [SampleData candlesForPeriod:period];                 // 実際のアプリでは API から取得する
};
[viewController reloadChart];                                    // 選択中の足種(最初は日足)を表示
```

作った `viewController` は、子 ViewController として画面に埋め込むか、そのまま表示します。
`candleLoader` は今はデータをその場で返す(同期)形です。API から非同期で取得する場合は、形を変える必要があります。

### 3. チャートだけを置く(StockChartView)

タブやメニューが不要な場合は、`StockChartView` を置いてデータを渡すだけです(storyboard に置く場合は、View のクラスを `StockChartView` にします)。

```swift
// Swift
let chartView = StockChartView()

chartView.setCandles(candles)                                            // 移動平均線 + 出来高
chartView.setCandles(candles, period: .weekly)                           // 足種に合った設定(週足: 移動平均 13/26 など)
chartView.setCandles(candles, mainIndicator: .bollingerBands, subIndicator: .macd)   // 指標を指定
```

```objc
// Objective-C
StockChartView *chartView = [[StockChartView alloc] initWithFrame:CGRectZero];

[chartView setCandles:candles];                                          // 移動平均線 + 出来高
[chartView setCandles:candles period:ChartPeriodWeekly];                 // 足種に合った設定
[chartView setCandles:candles
        mainIndicator:MainChartIndicatorBollingerBands
         subIndicator:SubChartIndicatorMacd];                            // 指標を指定
```

見た目の設定は、データを渡す前に行います(設定のたびに描き直されるため)。

```swift
// Swift(StockChartStyle のすべての項目を変更できる)
chartView.style.visibleCount = 55        // 初期表示本数(nil で全件)
chartView.style.priceHeightRatio = 2.0   // メイン:サブ = 2:1
```

```objc
// Objective-C(よく使う項目だけ)
chartView.visibleCount = 55;             // 初期表示本数(0 以下で全件)
chartView.priceHeightRatio = 2.0;        // メイン:サブ = 2:1
```

### 4. 指標メニュー・設定画面付きのチャート(StockChartViewController)

左端の「テクニカル」「設定」タブで、指標の切り替えや設定の変更ができます。子 ViewController として埋め込みます。

```swift
// Swift
let chartViewController = StockChartViewController()
addChild(chartViewController)
view.addSubview(chartViewController.view)          // 制約はお好みで
chartViewController.didMove(toParent: self)

chartViewController.mainIndicator = .bollingerBands
chartViewController.subIndicator = .macd
chartViewController.isTechnicalMenuEnabled = true  // テクニカル/設定タブを表示する
chartViewController.chartType = .candlestick       // チャートの種類(.vwapLine / .vwapDots / .newPrice / .lineChart)
chartViewController.setCandles(candles)
```

```objc
// Objective-C
StockChartViewController *chartViewController = [[StockChartViewController alloc] init];
[self addChildViewController:chartViewController];
[self.view addSubview:chartViewController.view];   // 制約はお好みで
[chartViewController didMoveToParentViewController:self];

chartViewController.mainIndicator = MainChartIndicatorBollingerBands;
chartViewController.subIndicator = SubChartIndicatorMacd;
chartViewController.isTechnicalMenuEnabled = YES;  // テクニカル/設定タブを表示する
chartViewController.chartType = ChartTypeCandlestick;  // チャートの種類
[chartViewController setCandles:candles];
```

このアプリの横画面(`LandscapeChartViewController`)は、これを `Landscape.storyboard` に埋め込んだものです。

```swift
let landscape = LandscapeChartViewController.instantiate()            // Swift
landscape.setCandles(candles)
```

```objc
LandscapeChartViewController *landscape = [LandscapeChartViewController instantiate];   // Objective-C
[landscape setCandles:candles];
```

### 5. 見た目を変える(色・文字の位置・フォントの大きさ)

チャートの見た目は、すべて `StockChartView` の `style`([`StockChart/View/StockChartStyle.swift`](ChartTest/StockChart/View/StockChartStyle.swift))で決まっています。
アプリ全体の既定値を変えるなら `StockChartStyle.swift` の初期値を書き換え、画面ごとに変えるならコードで `style` を設定します。

`style` は代入するたびに描き直されるので、まとめて変更してから1回で代入します。

```swift
// Swift
var style = chartView.style
style.legendFont = .systemFont(ofSize: 10)          // 凡例の文字を小さく
style.yAxisFont = .systemFont(ofSize: 9)            // 価格(Y軸)ラベルの文字を小さく
style.legendTopInset = 2                            // 凡例をさらに上へ
style.increasingColor = .systemRed                  // 陽線の色
style.lineColors[0] = .systemGreen                  // 短期移動平均の色
chartView.style = style
```

```objc
// Objective-C(よく使うものだけ。ほかの項目は Swift 側に @objc プロパティを追加してください)
chartView.legendFont = [UIFont systemFontOfSize:10];
chartView.yAxisFont = [UIFont systemFontOfSize:9];
chartView.legendTopInset = 2;
chartView.increasingColor = UIColor.systemRedColor;
```

このアプリの縦画面は、`PortraitChartViewController` の `applyChartStyle()` で見た目を設定しています(Y軸ラベルは Times 8pt・中央揃え、凡例は 10pt・白背景)。
チャートの大きさ(左端からの位置・高さ)は `Portrait.storyboard` の制約で決めています。

`chartView` は画面ごとに次のように取り出せます。

| 画面 | `chartView` の取り出し方 |
|---|---|
| 縦画面 | `portraitViewController.chartView`(`PortraitChartViewController`) |
| 横画面 | `landscapeViewController.chartViewController.chartView`(`LandscapeChartViewController`) |
| `StockChartViewController` | `chartViewController.chartView` |

#### 変えられる項目(`StockChartStyle`)

| 変えたいもの | 項目 | 既定値 |
|---|---|---|
| 陽線・陰線の色 | `increasingColor` / `decreasingColor` | 赤 / 青 |
| 指標の線の色(移動平均など) | `lineColors`(0 = 1本目、1 = 2本目、…) | 黄緑・オレンジ・紫・水色・ピンク |
| 出来高の棒・出来高移動平均の色 | `volumeColor` / `volumeAverageColor` | 黄緑 / 青 |
| 一目均衡表の線の色 | `ichimokuTenkanColor` など `ichimoku〜Color` | ― |
| VWAP・新値足・折線チャートの色 | `vwapColor` / `newPriceColor` / `lineChartColor` | 赤 / 青 / 青 |
| 現在値の破線の色(新値足・折線チャート) | `currentPriceLineColor` | 濃いグレー |
| 外枠・区切り線・横グリッド線の色 | `borderColor` / `dividerColor` / `gridColor` | 黒 / グレー / 薄いグレー |
| 軸ラベル・凡例タイトル(「移動平均」など)の文字色 | `textColor` | 黒 |
| 凡例のフォント(大きさ) | `legendFont` | 12pt |
| 日付(X軸)ラベルのフォント(大きさ) | `xAxisFont` | 10pt |
| 価格(Y軸)ラベルのフォント(大きさ) | `yAxisFont` | 10pt |
| 価格(Y軸)ラベルの位置(外枠の右端からの距離) | `yAxisLabelOffset` | 10pt |
| 価格(Y軸)ラベルの揃え方 | `centersYAxisLabels`(true で一番長いラベルの幅の中で中央揃え) | false(左揃え) |
| 価格(Y軸)ラベルを枠内に収める | `keepsYAxisLabelsInside`(true で下端の「0」などを上にずらす) | false |
| 凡例の背景色 | `legendBackgroundColor`(白にすると文字の後ろのグリッド線が隠れる) | 透明 |
| メインの凡例の位置(上端) | `legendTopInset`(外枠の上端からの距離) | 3pt |
| サブの凡例の位置(上端) | `subLegendTopInset`(区切り線からの距離) | 2pt |
| 凡例の位置(左端) | `legendLeadingInset`(外枠の左端からの距離) | 8pt |
| 凡例とチャートの線の間隔 | `legendBottomSpacing` | 4pt |
| 右側の価格ラベル欄の幅 | `rightAxisWidth` | 90pt |
| 下側の日付ラベル欄の高さ | `xAxisLabelHeight` | 20pt |
| メインとサブの高さの比 | `priceHeightRatio`(メイン : サブ = この値 : 1) | 2.0 |

- 凡例の文字の色は、線の色と同じになります(凡例だけの色はありません)。線の色を変えると、凡例の文字の色も変わります
- 凡例の位置やフォントを変えても、チャートの線が凡例と重ならないよう、Y軸の上側の余白は自動で調整されます

#### `style` 以外で決まっている見た目

| 部品 | ファイル | 項目 |
|---|---|---|
| 縦画面の足種タブ(色・文字の大きさ) | [`ChartPeriodTabView.swift`](ChartTest/StockChart/View/ChartPeriodTabView.swift) | `selectedColor`・`normalColor`、`updateSelection` 内のフォント |
| テクニカルのメニュー(見出しの色・文字の大きさ) | [`TechnicalMenuView.swift`](ChartTest/StockChart/View/TechnicalMenuView.swift) | `headerColor`・`selectedRowColor`、`makeColumn` / `applyRowStyle` 内のフォント |
| 「テクニカル」「設定」タブ | [`StockChartViewController.swift`](ChartTest/StockChart/Controller/StockChartViewController.swift) | `configureTabButton` |
| 4本値の枠(文字の大きさ・背景) | [`ChartCrosshairViews.swift`](ChartTest/StockChart/View/ChartCrosshairViews.swift) | `OHLCInfoView` |
| 凡例・Y軸の数値の書式(桁区切り・小数の桁数) | [`ChartAxisFormatters.swift`](ChartTest/StockChart/View/ChartAxisFormatters.swift) | `ChartNumberFormatter` |
| 凡例の文言(「短期移動平均(5)」など) | [`ChartContentBuilder.swift`](ChartTest/StockChart/Model/ChartContentBuilder.swift) | 各指標の `label` / `legendTitle` |

### Swift と Objective-C で使えるものの違い

ほとんどの機能は両方から使えます。Swift の struct(`StockChartStyle`・`IndicatorParameters` など)は Objective-C から直接扱えないため、次の違いがあります。

| 部品 | 両方から使える | Swift だけ |
|---|---|---|
| `StockCandle` | 作成(`init(date:open:high:low:close:volume:)`)、各値の読み取り | ― |
| `StockChartView` | `setCandles`(3種類)、`clear`、`visibleCount`、`priceHeightRatio`、`increasingColor`、`decreasingColor`、`dateFormat`、`noDataMessage`、`legendFont`、`xAxisFont`、`yAxisFont`、`legendTopInset` | `style`(すべての見た目)、`displayOptions`、`display(candles:main:sub:)`、パラメータを指定する `setCandles(_:mainIndicator:subIndicator:parameters:)` |
| `StockChartViewController` | `setCandles`、`chartType`、`mainIndicator`、`subIndicator`、`isTechnicalMenuEnabled`、`chartView`、`shortMAPeriod` / `longMAPeriod` / `volumeMAPeriod`、`isMainYAxisFixed` / `isSubYAxisFixed`、`showsOHLC` | `parameters`(すべての指標の期間など)、`displayOptions`、`onChartTypeChange` |
| `PortraitChartViewController` | `instantiate`、`market`、`candleLoader`、`reloadChart`、`selectedPeriod`、`chartView` | ― |
| `LandscapeChartViewController` | `instantiate`、`chartViewController`、`setCandles` | ― |
| `SampleData` | `candles(for:)`(Objective-C: `candlesForPeriod:`)、`nikkeiLike(days:)`(Objective-C: `nikkeiLikeWithDays:`) | ― |

Swift だけの設定を Objective-C から変えたい場合は、Swift 側に `@objc` プロパティを追加してください(`StockChartView.swift` と `StockChartViewController.swift` の末尾にある「Objective-C 向け」の extension が例です)。

### enum の名前の対応

Swift の enum は、Objective-C では「型名 + ケース名」になります。

| 足種(`ChartPeriod`) | 指数の種類(`IndexMarket`) |
|---|---|
| `.oneMinute` → `ChartPeriodOneMinute`(1分足) | `.domestic` → `IndexMarketDomestic`(国内) |
| `.intraday` → `ChartPeriodIntraday`(日中足) | `.overseas` → `IndexMarketOverseas`(海外) |
| `.daily` → `ChartPeriodDaily`(日足) | |
| `.weekly` → `ChartPeriodWeekly`(週足) | |
| `.monthly` → `ChartPeriodMonthly`(月足) | |

| メインチャート(`MainChartIndicator`) | サブチャート(`SubChartIndicator`) |
|---|---|
| `.movingAverage` → `MainChartIndicatorMovingAverage`(移動平均線) | `.volume` → `SubChartIndicatorVolume`(出来高) |
| `.multipleMovingAverage` → `MainChartIndicatorMultipleMovingAverage`(多重移動平均線) | `.movingAverageDeviation` → `SubChartIndicatorMovingAverageDeviation`(移動平均乖離率) |
| `.bollingerBands` → `MainChartIndicatorBollingerBands`(ボリンジャーバンド) | `.rsi` → `SubChartIndicatorRsi`(RSI) |
| `.ichimoku` → `MainChartIndicatorIchimoku`(一目均衡表) | `.psychological` → `SubChartIndicatorPsychological`(サイコロジカル) |
| `.parabolic` → `MainChartIndicatorParabolic`(パラボリック) | `.stochastics` → `SubChartIndicatorStochastics`(ストキャス) |
| `.candleOnly` → `MainChartIndicatorCandleOnly`(なし) | `.macd` → `SubChartIndicatorMacd`(MACD) |
| | `.dmi` → `SubChartIndicatorDmi`(DMI) |
| | `.hidden` → `SubChartIndicatorHidden`(サブチャートなし) |

| チャートの種類(`ChartType`) |
|---|
| `.candlestick` → `ChartTypeCandlestick`(ローソク足) |
| `.vwapLine` → `ChartTypeVwapLine`(VWAP：線) |
| `.vwapDots` → `ChartTypeVwapDots`(VWAP：点) |
| `.newPrice` → `ChartTypeNewPrice`(新値足) |
| `.lineChart` → `ChartTypeLineChart`(折線チャート) |

## フォルダ構成

```
ChartTest/
├─ ViewController.swift              … 縦/横の画面を切り替えるだけの画面
├─ PortraitChartViewController.swift … 縦画面(足種のタブ + StockChartView)
├─ LandscapeChartViewController.swift… 横画面(StockChartViewController を埋め込む)
├─ SampleData.swift                  … 動作確認用のダミーデータ(足種ごと)
└─ StockChart/                       … チャートの共通部品(MVC で役割を分けている)
   ├─ Model/       … 計算とデータ(UIKit・DGCharts に依存しない)
   ├─ View/        … 描画と画面部品
   └─ Controller/  … 状態の保持と、Model と View の橋渡し
```

### Model(`StockChart/Model/`)

| ファイル | 内容 |
|---|---|
| `StockCandle.swift` | ローソク足1本分のデータ(日付・始値・高値・安値・終値・出来高) |
| `TechnicalIndicators.swift` | 指標の計算(移動平均・ボリンジャーバンド・一目均衡表・RSI・MACD・VWAP・新値足 など) |
| `ChartType.swift` | チャートの種類(ローソク足・VWAP：線・VWAP：点・新値足・折線チャート) |
| `ChartIndicatorType.swift` | 指標の種類(メインチャート用 / サブチャート用) |
| `ChartPeriod.swift` | 足種(1分足〜月足)と足種ごとの表示の違い、指数の種類(国内/海外)ごとに選べる足種 |
| `IndicatorParameters.swift` | 指標の計算パラメータ(期間など) |
| `ChartContent.swift` | チャートに「何を描くか」を表すデータ(線・棒・雲・凡例の文字) |
| `ChartContentBuilder.swift` | ローソク足 + チャートの種類 + 指標 + パラメータ → `ChartContent` を組み立てる |
| `ChartDisplayOptions.swift` | 表示オプション(Y軸固定・4本値) |
| `ChartSettingsCatalog.swift` | 設定画面に並べる項目と、編集できるパラメータの定義 |

### View(`StockChart/View/`)

| ファイル | 内容 |
|---|---|
| `StockChartView.swift` | **チャート本体**。外から呼ぶ入口とプロパティ |
| `StockChartView+Layout.swift` | 部品の配置(Auto Layout)と見た目の設定 |
| `StockChartView+Rendering.swift` | `ChartContent` を DGCharts のデータに変換して描く・凡例を作る |
| `StockChartView+AxisRange.swift` | スクロール/ズームの同期と、Y軸の範囲の調整 |
| `StockChartView+Crosshair.swift` | 表示オプションの反映と、十字線・4本値の表示 |
| `ChartAxisFormatters.swift` | 軸ラベルの書式(X軸の日付・Y軸の数値) |
| `StockChartStyle.swift` | 見た目の設定(色・フォント・余白・初期表示本数) |
| `CloudCombinedRenderer.swift` | 一目均衡表の雲を塗るための描画処理 |
| `AlignedYAxisRenderer.swift` | 価格(Y軸)ラベルの中央揃え・枠内に収める描画処理 |
| `SafePinchCombinedChartView.swift` | ピンチ開始時のクラッシュ(DGCharts の不具合)を防いだチャート |
| `ChartCrosshairViews.swift` | 十字線・4本値の枠・マーカーの部品 |
| `ChartPeriodTabView.swift` | 足種のタブ(縦画面の上部) |
| `TechnicalMenuView.swift` | 指標の選択メニュー(テクニカルタブ) |
| `ChartSettingsView.swift` | 設定画面(設定タブ) |

### Controller(`StockChart/Controller/`)

| ファイル | 内容 |
|---|---|
| `StockChartViewController.swift` | チャートの種類・選択中の指標・パラメータ・表示オプションを持ち、メニューや設定画面の操作を受けてチャートを描き直す |

## データの流れ

```
StockCandle の配列(ローソク足データ)
   │
   ▼  ChartContentBuilder(Model)
   │    TechnicalIndicators で指標を計算し、
   │    「どの線を・どの名前で・どの色の役割で描くか」を決める
   ▼
MainChartContent / SubChartContent(何を描くか)
   │
   ▼  StockChartView.display(...)(View)
   │    DGCharts のデータに変換して描く。
   │    色の役割(ChartColorRole)は StockChartStyle で実際の色に変換する
   ▼
画面
```

横画面では、`StockChartViewController` がメニュー・設定画面の操作を受け取り、状態を変えて上の流れをもう一度実行します。

## 初めて読むときのおすすめの順番

1. `StockChart/Model/StockCandle.swift` と `ChartContent.swift` … 扱うデータの形
2. `StockChart/Model/ChartContentBuilder.swift` … 指標から「何を描くか」を作るところ
3. `StockChart/View/StockChartView.swift` … チャート本体の入口(冒頭のコメントに全体図があります)
4. `StockChartView+Layout.swift` → `+Rendering.swift` → `+AxisRange.swift` → `+Crosshair.swift`
5. `StockChart/Controller/StockChartViewController.swift` … 横画面のメニュー・設定の制御

指標の計算式を知りたいときは `TechnicalIndicators.swift` を見てください(各関数のコメントに式があります)。

## コードの書き方の約束

- 三項演算子(`a ? b : c`)や、`&&` を何行もつなげた条件式は使わない。`if` / `guard` / `switch` で1条件ずつ書く
- 1〜2文字の変数名は使わず、意味のわかる名前にする(ループの `i` / `j` を除く)

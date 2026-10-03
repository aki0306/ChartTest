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

### 横画面の設定画面

左端の「設定」タブで開きます。指標のパラメータは**足種ごと**に設定でき、上のタブで足種を切り替えます。

| 操作 | 動き |
|---|---|
| 足種のタブ | 編集する足種を切り替える。開いたときは表示中のチャートの足種。移動平均線以外の項目では、1分足・日中足はグレーで選べない |
| −/+ ボタン・スライダー | 値を変える(値はスライダーの上に表示) |
| すべての足に反映 | 表示中の値を、この項目を設定できるすべての足種にコピーする |
| 初期値に戻す | 表示中の足種の、この項目の値を初期値に戻す |
| 決定 | 変更をチャートに反映して閉じる(決定せずに閉じた場合、変更は捨てる) |

項目ごとに設定できる値は次のとおりです(`ChartSettingsCatalog`)。

| 項目 | 設定できる値 |
|---|---|
| 移動平均線 | 短期平均線・長期平均線 |
| 多重移動平均線 | 最短期間・最長期間・本数(最短〜最長を同じ間隔で分けて引く。例: 5・75・15本なら 5 刻み) |
| ボリンジャーバンド | 期間・乖離率(σ)(1〜3。3 なら ±1σ・±2σ・±3σ) |
| 一目均衡表 | 基準線期間・転換線期間・スパン期間(先行スパン・遅行スパンをずらす本数) |
| 移動平均乖離率 | 短期平均線・長期平均線・底値ライン(%)・高値ライン(%) |
| RSI・サイコロジカル | 期間・底値ライン(%)・高値ライン(%) |
| ストキャス | 高安期間・D期間・底値ライン(%)・高値ライン(%) |
| MACD | 短期EMA・長期EMA・シグナル期間 |
| DMI | 期間 |

オプション(Y軸固定・4本値)は足種ごとではないので、パネルの中央にトグルだけを並べ、切り替えるとすぐに反映されます。

指数の種類(`StockChartViewController.market`)が海外指数(`.overseas`)の場合は、次のようになります(詳しくは「使い方 > 海外指数の場合」)。

- 左のリストは「オプション」と「移動平均線」だけ
- オプションは「Y軸(メイン)固定」「4本値」を表示する(サブチャートがないので Y軸(サブ)固定は出さない。オンになっていても効かない)
- 4本値は、国内指数と同じくローソク足のときだけ表示する(折線チャートではオンでも表示しない)
- 足種のタブは 日足・週足・月足 だけを並べる(海外指数は日足・週足・月足だけを使うため)

テクニカル/設定を開いている間は、パネルを画面の上端〜セーフエリアの下端まで広げ、後ろの画面(チャート・下のボタン)をグレーにします。グレーの部分をタップするとパネルが閉じます(設定画面で「決定」していない変更は捨てます)。

自分の画面に組み込む場合は、`StockChartViewController` を画面いっぱいに置き、チャート本体の位置は `chartInsets`(セーフエリアの端からの余白)で決めます。
パネルは `StockChartViewController` の View の上端〜セーフエリアの下端(`panelBottomInset` でさらにあけられます)、背景のグレーは View いっぱいに表示されます。
`LandscapeChartViewController` は、下の「チャートの種類」ボタンの分を `chartInsets.bottom` で空け、パネルを開いている間だけチャート部品をボタンより手前に出しています(`onPanelVisibilityChange`)。

### 横画面のチャートの種類

右下のボタンで切り替えます(`ChartType`)。ローソク足以外では、テクニカル指標とサブチャートは表示しません。

- 「テクニカル」のメニューは、メインチャート・サブチャートとも「なし」だけになります(ローソク足に戻すと、それまでの選択に戻ります)
- 「設定」は使えますが、「4本値」はオンにしてもローソク足のときだけ表示されます

| 種類 | 表示 |
|---|---|
| ローソク足 | ローソク足 + テクニカル指標(メイン・サブ) |
| VWAP：線 / VWAP：点 | VWAP を線または点で表示(ローソク足は描かない)。同じ日の足で累計し、日付が変わると計算し直す。出来高が 0 のデータでは計算できないので、凡例と「現在、指定の条件で表示できる情報はありません。」を表示する |
| 折線チャート | 終値を線で結んだチャート(ローソク足は描かない)。現在値に破線を引く。海外指数では移動平均線を重ねられる |
| 新値足 | 3本新値の新値足。陽線は枠だけ、陰線は塗りつぶしで、現在値に破線を引く。X軸は時間ではなく新値の本数で、50本分の幅で表示する(50本未満なら右寄せ) |

### 縦画面の足種

選べる足種は指数の種類で変わります(`IndexMarket`)。

| 指数 | タブ |
|---|---|
| 国内指数(`.domestic`) | 1分足・日中足・日足・週足・月足 |
| 海外指数(`.overseas`) | 日足・週足・月足(チャートはローソク足 + 移動平均線で、サブチャート(出来高)なし) |

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

このヘッダは DGCharts の自動生成ヘッダ(`DGCharts-Swift.h`)も読み込みます。そこには説明が空の `\param` などがあり、ドキュメントコメントのチェックが有効だと、DGCharts のモジュールのビルド中に「Empty paragraph passed to '\param' command」などの警告が大量に出ます。
このアプリでは、ビルド設定の **Documentation Comments**(`CLANG_WARN_DOCUMENTATION_COMMENTS`)を `NO` にして、この警告を出さないようにしています。
(DGCharts のモジュールは `.m` ファイルとは別にビルドされるので、`.m` の `#pragma clang diagnostic` では止められません)

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
chartViewController.market = .domestic             // 指数の種類(海外指数なら .overseas)
chartViewController.setCandles(candles, period: .daily)   // 足種を指定すると、足種ごとの設定で描画する(省略時は日足)
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
chartViewController.market = IndexMarketDomestic;     // 指数の種類(海外指数なら IndexMarketOverseas)
[chartViewController setCandles:candles period:ChartPeriodDaily];  // 足種ごとの設定で描画する
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

#### 海外指数の場合

指数の種類(`market`)に `.overseas`(Objective-C は `IndexMarketOverseas`)を指定します。**データを渡す前に**指定してください(既定は国内指数 `.domestic`)。

```swift
// Swift: 縦画面(足種のタブが 日足・週足・月足 になり、チャートはローソク足 + 移動平均線・サブチャートなし)
let portrait = PortraitChartViewController.instantiate()
portrait.market = .overseas
portrait.candleLoader = { period in loadCandles(period) }   // 実際のデータの読み込み
portrait.reloadChart()

// Swift: 横画面(テクニカルは移動平均線・なし、チャートの種類はローソク足・折線チャートだけになる)
let landscape = LandscapeChartViewController.instantiate()
landscape.chartViewController.market = .overseas
landscape.setCandles(candles, period: .daily)

// Swift: StockChartViewController を直接使う場合
chartViewController.market = .overseas
chartViewController.setCandles(candles, period: .daily)
```

```objc
// Objective-C: 縦画面
PortraitChartViewController *portrait = [PortraitChartViewController instantiate];
portrait.market = IndexMarketOverseas;
portrait.candleLoader = ^NSArray<StockCandle *> *(ChartPeriod period) {
    return [self loadCandlesForPeriod:period];   // 実際のデータの読み込み
};
[portrait reloadChart];

// Objective-C: 横画面
LandscapeChartViewController *landscape = [LandscapeChartViewController instantiate];
landscape.chartViewController.market = IndexMarketOverseas;
[landscape setCandles:candles period:ChartPeriodDaily];

// Objective-C: StockChartViewController を直接使う場合
chartViewController.market = IndexMarketOverseas;
[chartViewController setCandles:candles period:ChartPeriodDaily];
```

海外指数にすると、次のように変わります。

| 画面 | 国内指数(`.domestic`) | 海外指数(`.overseas`) |
|---|---|---|
| 縦画面の足種のタブ | 1分足・日中足・日足・週足・月足 | 日足・週足・月足 |
| 縦画面のチャート | ローソク足 + 移動平均線、サブチャートに出来高 | ローソク足 + 移動平均線(サブチャートなし。メインチャートを全高で表示) |
| 横画面のテクニカル | メイン・サブとも全項目 | メインは 移動平均線・なし、サブは なし のみ(サブチャートは表示しない) |
| 横画面のチャートの種類 | ローソク足・VWAP：線・VWAP：点・新値足・折線チャート | ローソク足・折線チャート のみ |
| 横画面の折線チャート | 終値の折れ線だけ(テクニカルは「なし」のみ) | 終値の折れ線 + 移動平均線(テクニカルで 移動平均線・なし を選べる)、現在値の破線 |
| 設定画面の項目 | オプション・メインチャート・サブチャートの全項目 | オプション・メインチャートの移動平均線 のみ |
| 設定画面のオプション | Y軸(メイン)固定・Y軸(サブ)固定・4本値 | Y軸(メイン)固定・4本値(Y軸(サブ)固定はオンでも効かない。4本値はローソク足のときだけ表示) |
| 設定画面の足種のタブ | 1分足〜月足(移動平均線以外は 1分足・日中足がグレー) | 日足・週足・月足 の3つだけ |

海外指数に切り替えたとき、選べない指標・チャートの種類を選んでいた場合は、移動平均線・サブなし・ローソク足 に切り替わります。

国内・海外を切り替えるとき(同じ画面で別の指数を表示するとき)も、`market` を変えてからデータを渡し直します。

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
| 最高値・最安値の表示 | `showsHighLowLabels`(表示中の範囲の最高値・最安値を、その足の上・下に表示する。ローソク足のときだけ。Objective-C は `chartView.showsHighLowLabels`) | false(横画面では true) |
| 最高値・最安値の文字のフォント | `highLowLabelFont` | 14pt |
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
| 設定画面(配置・右側の行の見た目) | [`ChartSettingsView.xib`](ChartTest/StockChart/View/ChartSettingsView.xib) | Interface Builder で開いて編集する(Content View = 画面全体、Toggle Row / Stepper Row = 右側の行の見本) |
| 設定画面の左リスト(項目・見出しの色・文字の大きさ) | [`ChartSettingsView.swift`](ChartTest/StockChart/View/ChartSettingsView.swift) | `headerColor`・`selectedRowColor`、`applyCellStyle` / `viewForHeaderInSection` 内のフォント |
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
| `StockChartViewController` | `setCandles`(足種の指定あり/なし)、`period`、`market`、`chartType`、`mainIndicator`、`subIndicator`、`isTechnicalMenuEnabled`、`chartView`、`shortMAPeriod` / `longMAPeriod` / `volumeMAPeriod`、`isMainYAxisFixed` / `isSubYAxisFixed`、`showsOHLC` | `parameters`(表示中の足種の指標の期間など)、`setParameters(_:for:)`(足種を指定)、`updateParametersForAllPeriods`(すべての足種)、`displayOptions`、`onChartTypeChange` |
| `PortraitChartViewController` | `instantiate`、`market`、`candleLoader`、`reloadChart`、`selectedPeriod`、`chartView` | ― |
| `LandscapeChartViewController` | `instantiate`、`chartViewController`、`setCandles`(足種の指定あり/なし) | ― |
| `SampleData` | `candles(for:)`(Objective-C: `candlesForPeriod:`)、`nikkeiLike(days:)`(Objective-C: `nikkeiLikeWithDays:`) | ― |

`StockChartViewController` の `shortMAPeriod` / `longMAPeriod` / `volumeMAPeriod` は、設定すると**すべての足種**に反映されます(読み出すと表示中の足種の値)。足種ごとに変えたい場合は、設定画面か Swift の `setParameters(_:for:)` を使います。

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

## 既存アプリへの組み込み

チャート部分(`ChartTest/StockChart/`)は、ほかのアプリにそのまま組み込めるよう、ダミーデータ(`SampleData`)やサンプルの画面切り替え(`ViewController`)には依存しないように作っています。
`StockChart/Controller/` にある縦画面・横画面(`PortraitChartViewController` / `LandscapeChartViewController`)は、`ChartTest/` 直下の `Portrait.storyboard` / `Landscape.storyboard` から作る画面です。使う場合は storyboard もコピーします。

### 手順

1. **DGCharts を追加する**
   Swift Package Manager で `https://github.com/ChartsOrg/Charts.git`(5.1.0 以上)を追加し、アプリのターゲットにリンクします。

2. **`StockChart` フォルダをコピーする**
   Model / View / Controller の Swift ファイルと、設定画面の `ChartSettingsView.xib` をアプリのターゲットに追加します。
   XIB が **Copy Bundle Resources** に入っていることを確認してください(入っていないと、設定画面を開いたときに落ちます)。

3. **画面に置く**(どちらか)

   | 使いたいもの | 置くもの | 書き方 |
   |---|---|---|
   | チャートだけ | `StockChartView` | 「3. チャートだけを置く」 |
   | テクニカル・設定画面・チャートの種類も | `StockChartViewController`(子 ViewController として埋め込む) | 「4. 指標メニュー・設定画面付きのチャート」 |

   このアプリと同じ縦画面・横画面をそのまま使う場合は、`ChartTest/` 直下の `Portrait.storyboard` / `Landscape.storyboard` もコピーします(画面のクラス `PortraitChartViewController` / `LandscapeChartViewController` は `StockChart/Controller/` に入っています。中身は自由に変えて構いません)。

4. **データを渡す**
   API から取得した値で `StockCandle`(日付・4本値・出来高。「1. データを作る」を参照)を作り、**日付の古い順**の配列で渡します。
   海外指数の場合は、データを渡す前に `market = .overseas` を指定します(「海外指数の場合」を参照)。

### API のレスポンス(足種ごと)を渡す

既存アプリで足種ごとに取得したレスポンス(辞書の配列)は、[`ChartResponseLoader`](ChartTest/StockChart/Controller/ChartResponseLoader.swift) のメソッドでチャートに渡せます。
縦画面・横画面に関係なく、どこからでも呼べます。引数は Swift では `[[String: Any]]`、Objective-C では `NSArray<NSDictionary *> *` なので、`NSMutableArray` のまま渡せます(並び順は問いません。日付の古い順に並べ替えて描きます)。

| 足種 | Objective-C | Swift |
|---|---|---|
| 1分足 | `[ChartResponseLoader setOneMinuteResponse:array to:target]` | `ChartResponseLoader.setOneMinuteResponse(array, to: target)` |
| 日中足 | `[ChartResponseLoader setIntradayResponse:array to:target]` | `ChartResponseLoader.setIntradayResponse(array, to: target)` |
| 日足 | `[ChartResponseLoader setDailyResponse:array to:target]` | `ChartResponseLoader.setDailyResponse(array, to: target)` |
| 週足 | `[ChartResponseLoader setWeeklyResponse:array to:target]` | `ChartResponseLoader.setWeeklyResponse(array, to: target)` |
| 月足 | `[ChartResponseLoader setMonthlyResponse:array to:target]` | `ChartResponseLoader.setMonthlyResponse(array, to: target)` |
| 足種を引数で指定 | `[ChartResponseLoader setResponse:array period:ChartPeriodDaily to:target]` | `ChartResponseLoader.setResponse(array, period: .daily, to: target)` |

描画先(`target`)には、次のどれでも渡せます(`StockCandleReceiving` に対応しているもの)。

| 描画先 | 使う場面 |
|---|---|
| `StockChartView` | 既存アプリの縦画面などに、チャートだけを置く場合 |
| `StockChartViewController` | テクニカル・設定画面付きのチャートを埋め込む場合 |
| `LandscapeChartViewController` | このアプリの横画面をそのまま使う場合 |

```objc
// Objective-C: レスポンスの辞書を配列に入れて、そのまま渡す
NSMutableArray *responseArray = [NSMutableArray array];
[responseArray addObject:@{@"date": @"2026/10/01", @"open": @"66,000", @"high": @66500,
                           @"low": @65800, @"close": @"66300", @"volume": @2400000000}];
[ChartResponseLoader setDailyResponse:responseArray to:landscapeViewController];   // 横画面
[ChartResponseLoader setDailyResponse:responseArray to:self.chartView];            // 縦画面(StockChartView)
```

海外指数の場合は、描画先の `market` を先に `.overseas` にしておきます(`StockChartView` は `chartView.market`、横画面は `landscape.chartViewController.market`)。

辞書 → `StockCandle` の変換は [`StockCandleResponseParser`](ChartTest/StockChart/Model/StockCandleResponseParser.swift)(Model)が行います。

| 項目 | 内容 |
|---|---|
| キーの名前 | `StockCandleResponseParser.Key`(今は仮の名前 `date`・`open`・`high`・`low`・`close`・`volume`。既存アプリのレスポンスに合わせて直す) |
| 日付の形式 | `StockCandleResponseParser.dateFormats`(今は仮の形式 `yyyy/MM/dd HH:mm` など。上から順に試す) |
| 値の型 | 数値(`NSNumber`)・文字列(`"66,000"` のようなカンマ付きも可)のどちらでも読める |
| 読めない件 | 日付・始値・高値・安値・終値のどれかが読めない件(空・`"-"` など)は飛ばす。出来高がない件は 0 にする |
| 変換だけを使う | Swift: `StockCandleResponseParser.candles(from: array)` / Objective-C: `[StockCandleResponseParser candlesFrom:array]` |

※ 配列に辞書以外の要素が入っていると、受け取った時点でアプリが落ちます(Swift の `[[String: Any]]` に変換できないため)。

### 横画面のチャートだけを使う場合

縦画面は既存アプリの画面をそのまま使い、横画面のチャート(テクニカル・設定画面・チャートの種類のボタン付き)だけを組み込む場合です。

#### コピーするもの・しないもの

| ファイル | 必要か | 説明 |
|---|---|---|
| `StockChart/` フォルダ(`ChartSettingsView.xib` を含む) | 必要 | チャート本体・テクニカル・設定画面。`ChartPeriodTabView` も設定画面の足種のタブで使うので、フォルダごとコピーする |
| `Landscape.storyboard`(`ChartTest/` 直下) | 必要 | 横画面(チャートの種類のボタン付き)。画面のクラス `LandscapeChartViewController` は `StockChart/Controller/` に入っている。下のボタンが不要なら、`StockChartViewController` を直接使ってもよい |
| `Portrait.storyboard`、`StockChart/Controller/PortraitChartViewController.swift` | 不要 | このアプリの縦画面。フォルダごとコピーした場合、`PortraitChartViewController.swift` は削除してよい |
| `ViewController.swift` / `Main.storyboard` | 不要 | このアプリの、縦横を切り替えるサンプル画面 |
| `SampleData.swift` | 不要 | 動作確認用のダミーデータ |

#### 横画面を表示する

既存の縦画面から、横画面のチャートを表示します。表示の仕方は既存アプリに合わせて選んでください。

- **ボタンなどで全画面に表示する**(参考画面の右上の回転ボタンのような使い方)

```swift
// Swift(既存の縦画面の ViewController から)
let landscape = LandscapeChartViewController.instantiate()
landscape.chartViewController.market = .domestic          // 海外指数なら .overseas(データを渡す前に指定する)
landscape.setCandles(candles, period: .daily)             // 表示中の足種のデータ(古い順)
landscape.modalPresentationStyle = .fullScreen
present(landscape, animated: true)
```

```objc
// Objective-C(既存の縦画面の ViewController から)
LandscapeChartViewController *landscape = [LandscapeChartViewController instantiate];
landscape.chartViewController.market = IndexMarketDomestic;   // 海外指数なら IndexMarketOverseas
[landscape setCandles:candles period:ChartPeriodDaily];
landscape.modalPresentationStyle = UIModalPresentationFullScreen;
[self presentViewController:landscape animated:YES completion:nil];
```

  このとき、次の2点を既存アプリ側で追加してください(`LandscapeChartViewController` はコピーしたものを直接書き換えて構いません)。

  - 横向きで表示する: `LandscapeChartViewController` に次を追加する(アプリの対応する向きに「横」が含まれている必要があります)

    ```swift
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    ```

  - 閉じる操作: `LandscapeChartViewController` には閉じるボタンがないので、ボタンを追加して `dismiss(animated:)` を呼ぶ(参考画面の右下の回転ボタンなど)

- **端末を横にしたときに切り替える**

  このアプリの `ViewController.swift` と同じ方法です。既存の画面に `LandscapeChartViewController` を子 ViewController として画面いっぱいに埋め込んでおき、`viewDidLayoutSubviews` で縦横を判定して、横のときだけ表示します(`ViewController.swift` の `embed` / `applyLayout` を参照)。

#### 下のボタンを既存アプリのものにする場合

`Landscape.storyboard` の「チャートの種類」ボタンの代わりに既存アプリのボタン(足種・更新など)を使う場合は、`StockChartViewController` を直接埋め込み、ボタンの分の余白を `chartInsets` で空けます。チャートの種類は `chartType` で切り替えます(`LandscapeChartViewController.swift` が実装例です)。

```swift
chartViewController.chartInsets = UIEdgeInsets(top: 8, left: 0, bottom: 下のボタンの高さ + 余白, right: 8)
chartViewController.chartType = .lineChart               // 既存アプリのボタンで選ばれた種類
chartViewController.setCandles(candles, period: .weekly) // 既存アプリのボタンで選ばれた足種のデータ
```

テクニカル/設定を開いている間に既存アプリのボタンにもグレーをかけたい場合は、`onPanelVisibilityChange` でパネルの開閉を受け取り、`StockChartViewController` の View をボタンより手前に出します(`LandscapeChartViewController` の `configurePanelLayering` を参照)。

### 既存アプリ側で確認が必要なこと

| 項目 | このプロジェクトの設定 | 既存アプリで違う場合 |
|---|---|---|
| Objective-C から使う | `#import "ChartTest-Swift.h"` | ヘッダ名は `<既存アプリのモジュール名>-Swift.h` になる。Objective-C だけのアプリなら、Swift を使えるようにする設定(Bridging Header など)が必要 |
| Swift の並行処理の設定 | Default Actor Isolation = **MainActor**、Swift 5 | 設定が違うと、コンパイルエラーや警告が出ることがある。同じ設定にするか、出たエラーを直す |
| 対応 OS | iOS 18 以上で動作確認 | iOS 15 以降の API を使っているので、それより前の OS では使えない(iOS 18 未満は未確認) |
| ダークモード | ライトモード固定 | 色はライトモード前提(白背景・黒文字)。ダークモードに対応しているアプリでは、`StockChartStyle` で見た目を調整する |
| 型の名前 | `StockCandle`・`ChartType`・`ChartPeriod` など | 既存アプリに同じ名前の型があると衝突するので、名前を変える |
| DGCharts の警告 | Documentation Comments = NO | Objective-C から使うと、DGCharts のヘッダで「Empty paragraph passed to '\param' command」などの警告が大量に出ることがある(エラーではない。「準備(Objective-C のみ)」を参照) |

## フォルダ構成

```
ChartTest/
├─ ViewController.swift              … 縦/横の画面を切り替えるだけの画面
├─ Portrait.storyboard               … 縦画面のレイアウト(PortraitChartViewController)
├─ Landscape.storyboard              … 横画面のレイアウト(LandscapeChartViewController)
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
| `StockCandleResponseParser.swift` | API のレスポンス(辞書の配列)を `StockCandle` の配列に変換する(キーの名前・日付の形式はここで決める) |
| `TechnicalIndicators.swift` | 指標の計算(移動平均・ボリンジャーバンド・一目均衡表・RSI・MACD・VWAP・新値足 など) |
| `ChartType.swift` | チャートの種類(ローソク足・VWAP：線・VWAP：点・新値足・折線チャート) |
| `ChartIndicatorType.swift` | 指標の種類(メインチャート用 / サブチャート用) |
| `ChartPeriod.swift` | 足種(1分足〜月足)と足種ごとの表示の違い、指数の種類(国内/海外)ごとに選べる足種 |
| `IndicatorParameters.swift` | 指標の計算パラメータ(期間など) |
| `ChartContent.swift` | チャートに「何を描くか」を表すデータ(線・棒・雲・凡例の文字) |
| `ChartContentBuilder.swift` | ローソク足 + チャートの種類 + 指標 + パラメータ → `ChartContent` を組み立てる |
| `ChartDisplayOptions.swift` | 表示オプション(Y軸固定・4本値) |
| `ChartSettingsCatalog.swift` | 設定画面に並べる項目と、編集できるパラメータ・設定できる足種の定義 |

### View(`StockChart/View/`)

| ファイル | 内容 |
|---|---|
| `StockChartView.swift` | **チャート本体**。外から呼ぶ入口とプロパティ |
| `StockChartView+Layout.swift` | 部品の配置(Auto Layout)と見た目の設定 |
| `StockChartView+Rendering.swift` | `ChartContent` を DGCharts のデータに変換して描く・凡例を作る |
| `StockChartView+AxisRange.swift` | スクロール/ズームの同期と、Y軸の範囲の調整 |
| `StockChartView+Crosshair.swift` | 表示オプションの反映と、十字線・4本値の表示 |
| `StockChartView+HighLowLabels.swift` | 表示中の範囲の最高値・最安値を、その足の上・下に表示する |
| `ChartAxisFormatters.swift` | 軸ラベルの書式(X軸の日付・Y軸の数値) |
| `StockChartStyle.swift` | 見た目の設定(色・フォント・余白・初期表示本数) |
| `CloudCombinedRenderer.swift` | 一目均衡表の雲を塗るための描画処理 |
| `AlignedYAxisRenderer.swift` | 価格(Y軸)ラベルの中央揃え・枠内に収める描画処理 |
| `SafePinchCombinedChartView.swift` | ピンチ開始時のクラッシュ(DGCharts の不具合)を防いだチャート |
| `ChartCrosshairViews.swift` | 十字線・4本値の枠・マーカーの部品 |
| `ChartPeriodTabView.swift` | 足種のタブ(縦画面の上部) |
| `TechnicalMenuView.swift` | 指標の選択メニュー(テクニカルタブ) |
| `ChartSettingsView.swift` / `.xib` | 設定画面(設定タブ)。画面の配置(足種のタブ・行・下のボタン)と、右側の行の見本(トグル行・数値行)は XIB で編集する |

### Controller(`StockChart/Controller/`)

| ファイル | 内容 |
|---|---|
| `ChartResponseLoader.swift` | API のレスポンス(足種ごと)を、どこからでもチャートに渡して描画するユーティリティ(描画先は `StockCandleReceiving`) |
| `PortraitChartViewController.swift` | 縦画面(足種のタブ + StockChartView)。`Portrait.storyboard` から作る |
| `LandscapeChartViewController.swift` | 横画面(StockChartViewController を埋め込み、チャートの種類のボタンを付ける)。`Landscape.storyboard` から作る |
| `StockChartViewController.swift` | 足種・チャートの種類・選択中の指標・パラメータ(足種ごと)・表示オプションを持ち、メニューや設定画面の操作を受けてチャートを描き直す |

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

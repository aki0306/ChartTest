# ChartTest

[DGCharts](https://github.com/ChartsOrg/Charts) を使って株価チャート(ローソク足 + テクニカル指標)を表示する iOS アプリのサンプルです。
チャート部分(`ChartTest/StockChart/`)は、ほかのアプリにもそのまま組み込める共通部品として作っています。

- UIKit / iOS 18 以上 / 常にライトモード
- Swift と Objective-C のどちらからでも呼び出せます(「使い方」に両方の書き方があります。Objective-C のサンプルは `ChartTest/Sample/ObjCSample/`)

## 目次

| 知りたいこと | 読むところ |
|---|---|
| まず動かしたい・アプリに入れたい | [はじめての導入ガイド](#はじめての導入ガイド)(ステップごとに説明しています) |
| うまく動かない | [困ったとき](#困ったとき) |
| どんな画面・機能があるか | [画面](#画面) |
| 出来高・サブチャートの仕組み | [サブチャート(出来高など)](#サブチャート出来高など) |
| コードの書き方(Swift / Objective-C) | [使い方](#使い方swift--objective-c) |
| StockChartView・StockChartViewController・LandscapeChartViewController の違い | [どのクラスを使うか](#どのクラスを使うか) |
| 色・文字の大きさなどを変えたい | [見た目を変える](#4-見た目を変える色文字の位置フォントの大きさ) |
| API のレスポンスを渡したい | [API のレスポンス(足種ごと)を渡す](#api-のレスポンス足種ごとを渡す) |
| データを消したい・足種や銘柄を切り替えたい | [データを消す・入れ替えるとき](#データを消す入れ替えるとき) |
| ファイルの中身・仕組みを知りたい | [フォルダ構成](#フォルダ構成)・[データの流れ](#データの流れ) |

## はじめての導入ガイド

既存のアプリ(Swift でも Objective-C でも可)にチャートを入れるまでを、順番に説明します。
各ステップの最後にある **確認ポイント** のとおりになっていれば、次のステップに進んでください。うまくいかないときは [困ったとき](#困ったとき) を見てください。

### ステップ 0. 必要なもの

| もの | バージョン | 備考 |
|---|---|---|
| Xcode | 27 以上 | プロジェクトファイルが Xcode 27 の形式のため、Xcode 26 以前では開けません |
| iOS | 18 以上(動作確認済み) | iOS 15〜17 は未確認です |
| DGCharts | 5.1.0 以上 | チャートを描くライブラリ。ステップ 2 で追加します |
| Swift の言語モード | Swift 5 | Swift 6 の言語モードは未確認です |

### ステップ 1. まずこのサンプルを動かす

アプリに入れる前に、このプロジェクトで「どう動くか」を確かめます。

1. `ChartTest.xcodeproj` をダブルクリックして Xcode で開く
2. 初回は DGCharts の取得が自動で始まります。左下の進み具合の表示が消えるまで待つ
3. 画面上部の実行先で、iPhone のシミュレータ(例: iPhone 16 Pro)を選ぶ
4. **⌘R**(Product > Run)で実行する
5. シミュレータで **⌘ →**(Device > Rotate Right)を押して横向きにする

**確認ポイント**: 横向きにすると、左に「テクニカル」「設定」タブ・下に帯のあるチャートが表示される(下の「画面」の画像と同じ見た目)。

### ステップ 2. アプリに DGCharts を追加する

1. 組み込むアプリのプロジェクトを Xcode で開く
2. メニューの **File > Add Package Dependencies…** を選ぶ
3. 右上の検索欄に `https://github.com/ChartsOrg/Charts.git` を貼り付ける
4. **Dependency Rule** を「Up to Next Major Version」・`5.1.0` にして **Add Package** を押す
5. 次の画面で **DGCharts** の行の「Add to Target」に、組み込むアプリのターゲットを選んで **Add Package** を押す

**確認ポイント**: 左のファイル一覧の下の **Package Dependencies** に「Charts」が表示され、⌘B(ビルド)が成功する。

### ステップ 3. チャートの部品(`StockChart` フォルダ)をコピーする

1. Finder でこのプロジェクトの `ChartTest/StockChart/` フォルダを開く
2. フォルダごと、Xcode の左のファイル一覧(組み込むアプリのフォルダの中)にドラッグする
3. 出てきた画面で次のように選んで **Finish** を押す
   - **Action**(古い Xcode では **Copy items if needed**): 「Copy files to destination」(コピーする)を選ぶ。コピーせずに参照すると、元のフォルダを消したときに壊れるため
   - **Groups**: 「Create folders」(フォルダとして追加)のままでよい
   - **Targets**(古い Xcode では **Add to targets**): 組み込むアプリのターゲットにチェックを入れる
4. 使わないファイルは削除してかまいません

   | ファイル | 使わない場合は削除してよい |
   |---|---|
   | `LandscapeScreen/` フォルダ | 横画面(下の帯付き)を使わない |
   | `DGChartEnum/` フォルダ | `DGMainChart` などの enum(`mainChart`・`subChart` など)でチャートを設定しない |

   それ以外のフォルダは、すべて必要です。
5. ファイルがアプリのターゲットに入っているか確認する
   - **フォルダとして追加した場合**(Xcode 16 以降の既定。左の一覧で青いフォルダのアイコンになる): 中のファイルは自動でビルド・コピーされます。`StockChart` フォルダを選んで、右側の **File Inspector**(⌥⌘1)の **Target Membership** に組み込むアプリのターゲットのチェックが入っていれば OK です
   - **グループとして追加した場合**(黄色いフォルダのアイコン): ターゲットの **Build Phases** を開き、**Compile Sources** に `.swift` ファイルが、**Copy Bundle Resources** に `ChartSettingsView.xib`(と、使う場合は `ChartFooterView.xib`・`Landscape.storyboard`)が入っているか確認します。入っていないと、設定画面・横画面を開いたときにアプリが落ちます

**確認ポイント**: ⌘B(ビルド)が成功する。
(組み込むアプリに `StockCandle` や `ChartType` など同じ名前の型があるとエラーになります。[困ったとき](#困ったとき) を見てください)

### ステップ 4. Objective-C から使う準備(Objective-C のアプリだけ)

Swift のクラスを Objective-C から使うには、Xcode が自動で作るヘッダを import します。

```objc
#import "アプリのモジュール名-Swift.h"   // 例: アプリ名が MyApp なら "MyApp-Swift.h"
```

- モジュール名は、ターゲットの **Build Settings** で「Product Module Name」を検索すると確認できます(アプリ名に `-` や空白があると `_` に置き換わります)
- このヘッダは、Swift のファイルが1つでもターゲットに入っていれば、ビルドのときに自動で作られます(自分で作るファイルではありません)
- DGCharts のヘッダから「Empty paragraph passed to '\param' command」という警告が大量に出ることがあります。エラーではないので動作には影響しません。消したい場合は **Build Settings** の **Documentation Comments**(`CLANG_WARN_DOCUMENTATION_COMMENTS`)を **No** にします

Swift のアプリでは、この準備は不要です(同じターゲットの Swift のクラスはそのまま使えます)。

**確認ポイント**: `.m` ファイルで `#import` を書いて ⌘B が成功し、`StockChartView` と入力すると補完候補に出てくる。

### ステップ 5. いちばん簡単な表示を試す

画面にチャートを1つ置き、仮のデータを渡して表示します。新しい ViewController を作って、次のコードをそのまま貼り付けてください。

```swift
// Swift: MyChartViewController.swift
import UIKit

/// チャートを1つ表示するだけの画面(導入の動作確認用)
final class MyChartViewController: UIViewController {

    /// チャート本体
    private let chartView = StockChartView()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white

        // 1. チャートを画面の上のほうに置く(高さを必ず決める。高さが 0 だと何も見えない)
        self.chartView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.chartView)
        NSLayoutConstraint.activate([
            self.chartView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16),
            self.chartView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 8),
            self.chartView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.chartView.heightAnchor.constraint(equalToConstant: 260),
        ])

        // 2. データを渡す(日足として表示する)
        self.chartView.setCandles(self.makeTestCandles(), period: .daily)
    }

    /// 動作確認用の仮データ(60日分。日付の古い順)
    private func makeTestCandles() -> [StockCandle] {
        var candles: [StockCandle] = []
        var close = 66_000.0
        for daysAgo in (0..<60).reversed() {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
            let open = close
            close = open + Double.random(in: -800...800)
            let high = max(open, close) + Double.random(in: 0...300)
            let low = min(open, close) - Double.random(in: 0...300)
            candles.append(StockCandle(date: date, open: open, high: high, low: low, close: close, volume: 2.0e9))
        }
        return candles
    }
}
```

```objc
// Objective-C: MyObjCChartViewController.m(.h は UIViewController を継承するだけ)
#import "MyObjCChartViewController.h"
#import "MyApp-Swift.h"   // 「アプリのモジュール名-Swift.h」(ステップ 4)

@interface MyObjCChartViewController ()
/// チャート本体
@property (nonatomic, strong) StockChartView *chartView;
@end

@implementation MyObjCChartViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;

    // 1. チャートを画面の上のほうに置く(高さを必ず決める。高さが 0 だと何も見えない)
    self.chartView = [[StockChartView alloc] initWithFrame:CGRectZero];
    self.chartView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.chartView];
    [NSLayoutConstraint activateConstraints:@[
        [self.chartView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [self.chartView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.chartView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.chartView.heightAnchor constraintEqualToConstant:260],
    ]];

    // 2. データを渡す(日足として表示する)
    [self.chartView setCandles:[self makeTestCandles] period:ChartPeriodDaily];
}

/// 動作確認用の仮データ(60日分。日付の古い順)
- (NSArray<StockCandle *> *)makeTestCandles {
    NSMutableArray<StockCandle *> *candles = [NSMutableArray array];
    double close = 66000;
    for (NSInteger daysAgo = 59; daysAgo >= 0; daysAgo--) {
        NSDate *date = [NSDate dateWithTimeIntervalSinceNow:-daysAgo * 24 * 60 * 60];
        double open = close;
        close = open + (double)arc4random_uniform(1600) - 800;
        double high = MAX(open, close) + arc4random_uniform(300);
        double low = MIN(open, close) - arc4random_uniform(300);
        StockCandle *candle = [[StockCandle alloc] initWithDate:date open:open high:high low:low close:close volume:2.0e9];
        [candles addObject:candle];
    }
    return candles;
}

@end
```

この画面を表示する(既存の画面から `push` / `present` する、または一時的にアプリの最初の画面にする)と、チャートが表示されます。

**確認ポイント**: 次のように、ローソク足・移動平均線・出来高が表示される(値はランダムなので、形は毎回変わります)。

<img src="docs/images/minimal.png" width="300" alt="いちばん簡単な表示">

### ステップ 6. 本物のデータを渡す

仮データの代わりに、API から取得したデータを渡します。やり方は2つあります。

- **A. レスポンス(辞書の配列)をそのまま渡す**(おすすめ): [`ChartResponseLoader`](ChartTest/StockChart/Response/ChartResponseLoader.swift) に渡すと、`StockCandle` への変換・日付の並べ替えまでして描画します

  ```objc
  // Objective-C: 日足のレスポンス(NSMutableArray のままでよい)を、チャートに渡す
  [ChartResponseLoader setResponse:responseArray period:ChartPeriodDaily to:self.chartView];
  ```

  ```swift
  // Swift
  ChartResponseLoader.setResponse(responseArray, period: .daily, to: self.chartView)
  ```

  最初に、[`StockCandleResponseParser.swift`](ChartTest/StockChart/Response/StockCandleResponseParser.swift) の **キーの名前**(`Key`)と **日付の形式**(`dateFormats`)が、API のレスポンスと合っているか確認してください(キーは `kTimestamp`・`kStart` などです)。詳しくは「[API のレスポンス(足種ごと)を渡す](#api-のレスポンス足種ごとを渡す)」。

- **B. 自分で `StockCandle` を作って渡す**: 「[1. データを作る](#1-データを作る)」のとおり `StockCandle` の配列を作り、`setCandles(_:period:)` で渡します。**日付の古い順**に並べてください

**確認ポイント**: アプリのほかの画面と同じ値(最新の足の終値など)が、チャートに表示される。

### ステップ 7. 必要に応じて機能を足す

ここまでで「チャートだけを置く」(`StockChartView`)形の導入は完了です。必要に応じて、次の部品に置き換えます。

| やりたいこと | 使う部品 | 説明 |
|---|---|---|
| テクニカル(指標)の切り替え・設定画面を付けたい | `StockChartViewController` | [3. 指標メニュー・設定画面付きのチャート](#3-指標メニュー設定画面付きのチャートstockchartviewcontroller) |
| このアプリと同じ横画面(下の帯付き)を使いたい | `LandscapeChartViewController` | [横画面のチャートだけを使う場合](#横画面のチャートだけを使う場合) |
| 海外指数(NYダウなど)を表示したい | `market = .overseasRealtime`(日次は `.overseasDaily`) | [海外指数の場合](#海外指数の場合) |
| 色・文字の大きさを変えたい | `style` | [4. 見た目を変える](#4-見た目を変える色文字の位置フォントの大きさ) |

> **メモリリークに注意**: 横画面の `onPeriodSelect` などのクロージャ(ブロック)の中で、画面自身や `self` を使うときは、Swift は `[weak self]`、Objective-C は `__weak` を付けた変数を使ってください。詳しくは「[横画面の下の帯](#横画面の下の帯)」。

## 困ったとき

| 症状・エラーメッセージ | 原因 | 直し方 |
|---|---|---|
| `No such module 'DGCharts'` | DGCharts がターゲットに追加されていない | ステップ 2 をやり直す。ターゲットの **General > Frameworks, Libraries, and Embedded Content** に `DGCharts` があるか確認する |
| `'〇〇-Swift.h' file not found` | ヘッダの名前がモジュール名と違う | ステップ 4 のとおり、Product Module Name を確認して書き直す |
| Objective-C で `StockChartView` などが見つからない(`Unknown type name`) | `-Swift.h` を import していない、または Swift のファイルがターゲットに入っていない | `#import "〇〇-Swift.h"` を書く。Swift のファイルの **Target Membership** にチェックが入っているか確認する |
| `Invalid redeclaration of 'StockCandle'` など | 組み込むアプリに同じ名前の型がある | どちらかの名前を変える(Xcode で型名を右クリック > **Refactor > Rename** で、使っている箇所もまとめて変えられる) |
| プロジェクトが開けない(future Xcode project file format)、またはビルドで `nonisolated` に関するエラーが出る | Xcode が古い | Xcode 27 以上を使う(ステップ 0) |
| 「Empty paragraph passed to '\param' command」の警告が大量に出る | DGCharts のヘッダのコメントの書き方(動作には影響しない) | **Build Settings** の **Documentation Comments** を **No** にする |
| チャートが何も表示されない(真っ白) | チャートの高さ・幅が 0 | 高さの制約(例: 260)を付けているか確認する。storyboard に置いた場合は、View のクラスが `StockChartView` になっているか確認する |
| 「現在、指定の条件で表示できる情報はありません。」と表示される | 渡したデータが 0 件(レスポンスのキーや日付の形式が合っていない場合も、読めない件が飛ばされて 0 件になる。日付は読めても4本値が1件も読めなければ 0 件になる) | `StockCandleResponseParser` の `Key`・`dateFormats` がレスポンスと合っているか確認する |
| 出来高(サブチャート)の棒が表示されない(凡例だけ出る・段ごとない) | `volume` がすべて 0(レスポンスに `kTurnover` キーがない)、海外指数を指定している、または横画面でローソク足以外のチャートを選んでいる | レスポンスのキーを `StockCandleResponseParser` の `Key.volume`(`kTurnover`)に合わせる。指数の種類・チャートの種類を確認する([サブチャート(出来高など)](#サブチャート出来高など)) |
| ローソク足の並びがおかしい・日付ラベルがおかしい | データが日付の古い順になっていない | `StockCandle` の配列を日付の古い順に並べる(`ChartResponseLoader` を使うと自動で並べ替える) |
| 設定タブを押す・横画面を開くとアプリが落ちる(`Could not load NIB`) | `ChartSettingsView.xib`・`ChartFooterView.xib` がアプリに入っていない | ステップ 3 の 6. のとおり、XIB の **Target Membership** にチェックを入れる(グループの場合は **Copy Bundle Resources** に入れる) |
| 横画面を開くとアプリが落ちる(`Could not find a storyboard named`) | storyboard がアプリに入っていない | `Landscape.storyboard` の **Target Membership** にチェックを入れる(グループの場合は **Copy Bundle Resources** に入れる) |
| 横向きにならない | アプリが横向きに対応していない | ターゲットの **General > Deployment Info** で **Landscape Left / Right** にチェックを入れる |
| 横画面を閉じたあとも、メモリが解放されない | クロージャ(ブロック)の中で、画面を強く参照している | `[weak self]` / `__weak` を使う(ステップ 7 の注意) |
| 配列を渡したらアプリが落ちた | 配列に辞書以外(文字列など)が入っている | `ChartResponseLoader` には辞書(`NSDictionary`)だけを入れた配列を渡す |


## 画面

| 横画面(`Landscape.storyboard` / `LandscapeChartViewController`) |
|---|
| 左端の「テクニカル」「設定」タブで、指標の切り替えや設定の変更ができる。下の帯で、チャートの種類・足種の切り替え、更新、縦画面に戻す操作ができる |
| <img src="docs/images/landscape.png" width="520" alt="横画面"> |

`ViewController`(`Main.storyboard`)は、縦向きでは `StockChartView`(チャートだけ・日足)を、横向きでは横画面を表示します。

### 横画面のテクニカル

左端の「テクニカル」タブで、メインチャート・サブチャートの指標を選びます。選べる指標は、チャートの種類・指数の種類・足種で変わります(`MainChartIndicator.choices(for:period:)` / `SubChartIndicator.choices(for:period:)`)。

| 条件 | メインチャート | サブチャート |
|---|---|---|
| 国内指数・ローソク足・日足/週足/月足 | 移動平均線・多重移動平均線・ボリンジャーバンド・一目均衡表・パラボリック・なし | 出来高・移動平均乖離率・RSI・サイコロジカル・ストキャス・MACD・DMI・なし |
| 国内指数・ローソク足・1分足/日中足 | 移動平均線・なし | 出来高・なし |
| 国内指数・VWAP/新値足/折線チャート | なし | なし |
| 海外指数・ローソク足/折線チャート | 移動平均線・なし | なし |

選べない指標を選んでいた場合(日足で一目均衡表・MACD を表示中に 1分足 にした場合など)は、メインは移動平均線、サブは出来高(海外指数は なし)に切り替えます。足種を戻しても、元の指標には戻りません。

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
| ボリンジャーバンド | 期間・乖離率（σ）(1〜3。3 なら ±1σ・±2σ・±3σ) |
| 一目均衡表 | 基準線期間・転換線期間・スパン期間(先行スパン・遅行スパンをずらす本数) |
| 移動平均乖離率 | 短期平均線・長期平均線・底値ライン(%)・高値ライン(%) |
| RSI・サイコロジカル | 期間・底値ライン(%)・高値ライン(%) |
| ストキャス | 高安期間・D期間・底値ライン(%)・高値ライン(%) |
| MACD | 短期EMA・長期EMA・シグナル期間 |
| DMI | (設定なし。期間 14 で固定) |

オプション(Y軸固定・4本値)は足種ごとではないので、パネルの中央にトグルだけを並べ、切り替えるとすぐに反映されます。

4本値をオンにすると、十字線(黒い実線)と、その足の日付・始値・高値・安値・終値を表示します(ローソク足のときだけ)。日付の書式は足種ごと(日足・週足 `yyyy/MM/dd`、月足 `yyyy/MM`、1分足・日中足 `HH:mm`)、値は 3桁区切りなしです。
十字線は、最初は(4本値をオンにしたとき・データや足種が変わったとき)メインチャートの描画領域の中央に出ます。動かし方は、触り始めた場所で変わります。

| 触り始めた場所 | 指でなぞる(ドラッグ)・タップ |
|---|---|
| 十字線の交点から 15pt 以内(枠の内側でもよい) | 縦線・横線の両方が動く(タップでは動かない) |
| 枠の左右の外側(右の価格ラベルの欄など。メインチャートの高さ) | 横線(価格)だけが動く |
| 枠の上下の外側(下の日付ラベルの欄など)・枠の下端 10pt | 縦線(日付・4本値)だけが動く |
| 枠の内側(上以外) | 動かない(チャートのスクロール・拡大) |

線は、指がその線を動かせる場所にある間だけ動きます(横線はメインチャートの高さ、縦線は枠の左右の幅の中。外れたところで止まります)。
縦線は指の位置のまま止まり、足の中心には合わせません。4本値・日付は、縦線に一番近い足のものです。
値のない日時(値が空の足、1分足・日中足の値のない時間帯)を指したときは、4本値を空欄にします(データの範囲の外では日付も空欄)。
十字線を動かさないまま 3 秒経つと薄くなります(4本値の枠・値のマーカー・矢印は 50%、線は 30%。もう一度動かすと元の濃さに戻ります。秒数と濃さは `style` の `crosshairFadeDelay`・`crosshairFadedAlpha`・`crosshairFadedLineAlpha` で変えられます)。

枠の内側は、4本値がオンの間もチャートのスクロール(1本指)・拡大(ピンチ)に使えます(交点・ラベルの欄からなぞったときは、十字線だけが動き、チャートはスクロールしません)。

指数の種類(`StockChartViewController.market`)が海外指数(`.overseasRealtime`・`.overseasDaily`)の場合は、次のようになります(詳しくは「使い方 > 海外指数の場合」)。

- 左のリストは「オプション」と「移動平均線」だけ
- オプションは「Y軸(メイン)固定」「4本値」を表示する(サブチャートがないので Y軸(サブ)固定は出さない。オンになっていても効かない)
- 4本値は、国内指数と同じくローソク足のときだけ表示する(折線チャートではオンでも表示しない)
- 足種のタブは 日足・週足・月足 だけを並べる(海外指数は日足・週足・月足だけを使うため)

テクニカル/設定を開いている間は、パネルを画面の上端〜セーフエリアの下端まで広げ、後ろの画面(チャート・下のボタン)をグレーにします。グレーの部分をタップするとパネルが閉じます(設定画面で「決定」していない変更は捨てます)。

自分の画面に組み込む場合は、`StockChartViewController` を画面いっぱいに置き、チャート本体の位置は `chartInsets`(セーフエリアの端からの余白)で決めます。
パネルは `StockChartViewController` の View の上端〜セーフエリアの下端(`panelBottomInset` でさらにあけられます)、背景のグレーは View いっぱいに表示されます。
`LandscapeChartViewController` は、下の帯の分を `chartInsets.bottom` で空け、パネルを開いている間だけチャート部品を帯より手前に出しています(`onPanelVisibilityChange`)。

### 横画面の下の帯

```
日経平均 68309.46 10/02 15:45            [ローソク足 ▼] [月足 ▼] [↻] | [⤾]
```

帯は [`ChartFooterView`](ChartTest/StockChart/LandscapeScreen/ChartFooterView.swift)(View)で、`Landscape.storyboard` の Footer View に置いています。配置は [`ChartFooterView.xib`](ChartTest/StockChart/LandscapeScreen/ChartFooterView.xib) を Interface Builder で開いて編集します。
帯は見た目(ボタンの色・幅・現在値の文字)だけを担当し、メニューの中身と「押されたら何をするか」は `LandscapeChartViewController` が渡します。データの取得や画面の回転はアプリによって違うので、ボタンが押されたら `LandscapeChartViewController` の処理(クロージャ / ブロック)を呼ぶだけにしています。
「チャートの種類」「足種」のボタンの幅は、メニューの中で一番長い名前(「折線チャート」など)が1行で入る幅に固定しています(文字は縮小しません。選ぶたびに幅が変わらないようにするため)。

| 部品 | 動き | 使うもの |
|---|---|---|
| 指数名・現在値・日時 | 「日経平均 68309.46 10/02 15:45」のように表示する(現在値は小数2桁・3桁区切りなし、日時は MM/dd HH:mm) | `updatePriceInfo(name:price:date:)`(Objective-C は `updatePriceInfoWithName:price:date:`) |
| ローソク足 ▼ | チャートの種類のメニュー(下の「横画面のチャートの種類」) | `chartViewController.chartType` |
| 月足 ▼ | 足種のメニュー(国内指数は 1分足〜月足、海外指数は 日足・週足・月足。VWAP のときは 日中足 だけ、新値足・折線チャートのときは 1分足 を除く。`ChartType.periods(in:)`)。選ばれると `onPeriodSelect` が呼ばれるので、その足種のデータを取得して `setCandles(_:period:)` で渡す。ボタンの文字は、渡した足種に変わる | `onPeriodSelect` |
| ↻(更新) | `onReload` が呼ばれるので、表示中の足種(`chartViewController.period`)のデータと現在値を取得し直して渡す | `onReload` |
| ⤾(縦画面に戻す) | `onRotate` が呼ばれるので、縦画面に戻す処理をする(全画面で表示している場合は `dismiss` など) | `onRotate` |

```swift
// Swift
landscape.onPeriodSelect = { [weak landscape] period in
    // その足種のデータを API から取得して渡す(ChartResponseLoader で渡してもよい)
    landscape?.setCandles(candles, period: period)
}
landscape.onReload = { [weak self] in /* 表示中の足種のデータを取得し直して setCandles(_:period:)・updatePriceInfo を呼ぶ */ }
landscape.onRotate = { [weak self] in /* 縦画面に戻す */ }
landscape.updatePriceInfo(name: "日経平均", price: 68309.46, date: date)
```

```objc
// Objective-C
__weak LandscapeChartViewController *weakLandscape = landscape;
landscape.onPeriodSelect = ^(ChartPeriod period) {
    [ChartResponseLoader setResponse:responseArray period:period to:weakLandscape];
};
landscape.onReload = ^{ /* 取得し直す */ };
landscape.onRotate = ^{ /* 縦画面に戻す */ };
[landscape updatePriceInfoWithName:@"日経平均" price:68309.46 date:date];
```

> **メモリリークに注意**: `onPeriodSelect` などのクロージャ(ブロック)は `LandscapeChartViewController` が持ち続けます。
> 中で `landscape` 自身や、`landscape` を持っている画面(`self`)を使う場合は、Swift は `[weak landscape]` / `[weak self]`、
> Objective-C は `__weak` を付けた変数を使ってください(そのまま使うと、お互いを持ち合って解放されなくなります)。

このアプリの `ViewController.swift`(`setupLandscapeFooter`)では、SampleData のデータで動かしています。
縦画面の左下にある「日本株・国内指数・海外(R)・海外(D)」の切り替えボタンはサンプル用で、横画面では帯と重なるので表示しません。

### 横画面のチャートの種類

下の帯の「ローソク足 ▼」ボタンで切り替えます(`ChartType`)。ローソク足以外では、テクニカル指標とサブチャートは表示しません。

- 「テクニカル」のメニューは、メインチャート・サブチャートとも「なし」だけになります(メイン・サブとも「なし」になり、ローソク足に戻しても「なし」のままです)
- 「設定」は使えますが、「4本値」はオンにしてもローソク足のときだけ表示されます

| 種類 | 表示 |
|---|---|
| ローソク足 | ローソク足 + テクニカル指標(メイン・サブ) |
| VWAP：線 / VWAP：点 | VWAP を線または点で表示(ローソク足は描かない)。API が計算した VWAP(`kVWAP`)で描く。`kVWAP` が1件もないデータでは、凡例と「現在、指定の条件で表示できる情報はありません。」を表示する。足種は **日中足** だけを選べる(ほかの足種のまま VWAP にすると、日中足に切り替える) |
| 折線チャート | 終値を線で結んだチャート(ローソク足は描かない)。現在値に破線を引く。海外指数では移動平均線を重ねられる。足種は **日中足・日足・週足・月足** だけを選べる(1分足のまま折線チャートにすると、日中足に切り替える) |
| 新値足 | 3本新値の新値足。陽線は枠だけ、陰線は塗りつぶしで、現在値に破線を引く。X軸は時間ではなく新値の本数で、50本分の幅で表示する(50本未満なら右寄せ)。表示中の足種の終値から作る。足種は **日中足・日足・週足・月足** だけを選べる(1分足は選べない。1分足のまま新値足にすると、日中足に切り替える) |

### サブチャート(出来高など)

サブチャートは、メインチャート(ローソク足)の下にある小さい段です。**出来高は、サブチャートに出せる指標の1つ**です。

```
┌──────────────────────────────┐
│ 移動平均 短期… 長期…          │ ← メインチャート(ローソク足 + 移動平均線など)
│   ローソク足                  │
├──────────────────────────────┤
│ 出来高 出来高移動平均          │ ← サブチャート(出来高・RSI・MACD などのうち1つ)
│ ▮▮ ▮▮▮ ▮ ▮▮                  │
└──────────────────────────────┘
```

サブチャートに出せるのは `SubChartIndicator` の次の8種類で、同時に出せるのは**1つだけ**です。

出来高(`.volume`)・移動平均乖離率・RSI・サイコロジカル・ストキャス・MACD・DMI・なし(`.hidden`。サブチャートの段を消す)

#### いつ何が出るか

| 画面 | サブチャート |
|---|---|
| チャートだけ(`StockChartView`)・国内指数 | `subIndicator` で指定する。**既定は出来高** |
| チャートだけ・海外指数 | なし |
| 横画面(`StockChartViewController`) | 「テクニカル」タブで選ぶ。**最初は出来高**。選べるものは足種・チャートの種類で絞られる(上の「横画面のテクニカル」の表) |

#### 出来高のデータ

サブチャート用のデータを別に渡す必要はありません。**`StockCandle` の `volume`** をそのまま使います。
API のレスポンスを `ChartResponseLoader` で渡す場合は、`kTurnover` キー(`chartDataFromResponse:…` が出来高を入れるキー)の値が入ります(キーがない場合は `0`。`StockCandleResponseParser`)。
レスポンスでは、1分足・日中足・日足はその足の出来高、週足・月足は「1日あたり平均出来高」です。日中足は、1分足の出来高を5分ごとに合計した値です。
海外指数は、`kTurnover` があっても常に 0 として読みます(`chartDataFromResponse:…` も海外指数の出来高は空にしている)。

#### 出来高のサブチャートに描くもの

| 描くもの | 値 | 色(`StockChartStyle`) |
|---|---|---|
| 棒(出来高) | 各足の `volume` をそのまま | `volumeColor`(黄緑) |
| 線(出来高移動平均) | 直近 5本(週足は 13本)の `volume` の平均(`IndicatorParameters.volumeMAPeriod`。足種ごとの値は `ChartPeriod.indicatorParameters`) | `volumeAverageColor`(青) |

- Y軸の上限は、スクロール・拡大のたびに、見えている範囲の出来高に合わせて決め直します。下限は必ず 0 です
- 凡例は、1分足・日中足・日足は「出来高 出来高移動平均」、週足・月足は「出来高(平均) 出来高移動平均」です(`ChartPeriod.indicatorParameters`)。
  チャート側では平均を計算しないので、週足・月足は API から「期間中の1日あたりの平均」の値を渡す前提です
- 出来高がすべて 0 のデータ(出来高が配信されない指数の1分足・日中足など)は、棒も線も描かず、凡例だけを表示します

`volume` を使うのは、出来高のサブチャートと VWAP だけです。ほかのサブチャートの指標は、RSI・MACD・移動平均乖離率・サイコロジカルが終値、ストキャス・DMI が高値・安値・終値から計算します(「使い方 > チャート・指標ごとに使う値」)。

#### サブチャートの処理の場所

```
StockCandle の配列
   │
   ▼ ChartContentBuilder.subContent(for:)       … 選ばれた指標の中身を作る(出来高は volumeContent)
   │    計算は TechnicalIndicators(RSI・MACD など)
   ▼
SubChartContent                                 … 線(series)・棒(bars)・基準線(referenceLines)・Y軸の範囲・書式
   │
   ▼ StockChartView+Rendering.renderSubChart    … DGCharts のデータに変換して描く
   │  StockChartView+AxisRange.updateSubAxisRange … 見えている範囲に合わせて Y軸の範囲を決める
   ▼
画面
```

| 変えたいこと | 見るところ |
|---|---|
| 出来高移動平均の本数(5・週足 13) | `Model/Indicators/IndicatorParameters.swift` の `volumeMAPeriod` |
| 凡例の文言 | `Model/Content/ChartContentBuilder.swift` の `volumeContent`、足種ごとの「出来高(平均)」は `Model/Display/ChartPeriod.swift` |
| 棒・線の色 | `StockChartStyle` の `volumeColor` / `volumeAverageColor` |
| `StockChartView` のサブチャートを出来高以外にする | `subIndicator` を設定する(「[2. チャートだけを置く](#2-チャートだけを置くstockchartview)」) |
| 横画面で選べる指標 | `Model/Indicators/ChartIndicatorType.swift` の `SubChartIndicator.choices(for:period:)` |

## 使い方(Swift / Objective-C)

チャートの部品は、Swift と Objective-C のどちらからでも呼び出せます。以下、それぞれの書き方を並べています。

### どのクラスを使うか

画面に置くクラスは3つあり、入れ子になっています。外側のクラスは、内側のクラスを中に持っています。

```
LandscapeChartViewController(横画面)
├─ StockChartViewController(チャート + テクニカル/設定タブ)   ← chartViewController で取り出せる
│   └─ StockChartView(チャート本体)                           ← chartView で取り出せる
└─ 下の帯(ChartFooterView): 指数名・現在値、チャートの種類▼、足種▼、更新、縦画面に戻す
```

| | `StockChartView` | `StockChartViewController` | `LandscapeChartViewController` |
|---|---|---|---|
| 種類 | View | ViewController | ViewController |
| 中身 | チャートだけ | `StockChartView` + 左端のテクニカル/設定タブ(`isTechnicalMenuEnabled = true` のとき) | `StockChartViewController` + 下の帯 |
| 作り方 | `StockChartView()` | `StockChartViewController()` | `LandscapeChartViewController.instantiate()`(`Landscape.storyboard` から作る。`LandscapeChartViewController()` では下の帯が出ない) |
| 画面への置き方 | `addSubview` | 子 ViewController として埋め込む | 子 ViewController として埋め込む |
| 指標・パラメータ | コードで設定する | テクニカル/設定タブで切り替えられる(コードでも設定できる) | 中の `chartViewController` で設定する |
| チャートの種類・足種 | `chartType`・`period` をコードで設定する | ボタンはない。チャートの種類は `chartType`、足種は `setCandles(_:period:)` でデータと一緒に設定する | 下の帯のメニューで切り替えられる |
| データの渡し方 | `setCandles(_:period:)` などで渡す | `setCandles(_:period:)` などで渡す | 足種・更新・縦画面に戻すが押されると `onPeriodSelect`・`onReload`・`onRotate` が呼ばれるので、アプリ側でデータを取得して `setCandles(_:period:)` で渡す |
| 指数名・現在値の表示 | なし | なし | `updatePriceInfo(name:price:date:)` |
| フォルダ | `StockChart/View/Chart/` | `StockChart/Controller/` | `StockChart/LandscapeScreen/`(使わなければフォルダごと削除してよい) |

使い分けの目安:

| やりたいこと | 使うクラス | 説明 |
|---|---|---|
| 縦画面でチャートだけ見せる | `StockChartView` | [2. チャートだけを置く](#2-チャートだけを置くstockchartview) |
| 指標メニュー・設定画面付きのチャートを、アプリ側のボタンと組み合わせて使う | `StockChartViewController` | [3. 指標メニュー・設定画面付きのチャート](#3-指標メニュー設定画面付きのチャートstockchartviewcontroller)。ボタンの分の余白は `chartInsets` で空ける |
| 下の帯付きの横画面をそのまま使う | `LandscapeChartViewController` | [横画面を表示する](#横画面を表示する) |

縦画面は `StockChartView`、横画面は `LandscapeChartViewController` と分けて使う場合、2つはつながっていないので、データはそれぞれに渡します(このアプリの `Sample/ViewController.swift` が例です)。

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
| [`Sample/ObjCSample/ObjCChartViewController.m`](ChartTest/Sample/ObjCSample/ObjCChartViewController.m) | 指標メニュー付きのチャート(`StockChartViewController`)を使う |

### 1. データを作る

ローソク足1本を `StockCandle` で作り、**日付の古い順**に並べた配列を渡します。

```swift
// Swift
let candle = StockCandle(date: date, open: 66_000, high: 66_500, low: 65_800, close: 66_300, volume: 2.4e7)
let candles: [StockCandle] = [candle /* , … */]
```

```objc
// Objective-C
StockCandle *candle = [[StockCandle alloc] initWithDate:date
                                                   open:66000
                                                   high:66500
                                                    low:65800
                                                  close:66300
                                                 volume:2.4e7];
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
| `volume` | 出来高(その期間に売買された株数) | `2.4e7` | 24,000,000株(2,400万株。日経平均のレスポンスと同じ桁)。出来高が配信されない指数の1分足・日中足などは `0` を入れる。Y軸の欄は 65pt なので、13桁以上(10億以上)の値はラベルが切れる |
| `hasValue` | 値がある足か(`initWithEmptyDate:` で作った日時だけの足は NO) | YES | 1分足・日中足で、値のない時間帯の日時だけを X軸に並べたい場合は `[[StockCandle alloc] initWithEmptyDate:date]` を先頭側・末尾側に入れる(チャートは描かずに日付だけ並べる) |
| `vwap` | API が計算した VWAP(省略可・Swift のみ) | なし | 1分足・日中足で API が VWAP を配信している場合に入れる(`StockCandle(date:open:high:low:close:volume:vwap:)`)。VWAP のチャートはこの値だけで描く(チャートでは計算しない。入っていなければ VWAP は描かない)。レスポンスを `StockCandleResponseParser` で変換する場合は、`kVWAP` から自動で入る |

- `66_000` の `_` は、Swift の数字の区切り(読みやすくするためだけのもの)で、`66000` と同じです。Objective-C では `66000` と書きます
- `2.4e7` は「2.4 × 10の7乗」= 24,000,000 です
- 値は `low ≦ open, close ≦ high` になるように入れてください(ローソク足のヒゲは安値〜高値、実体は始値〜終値で描かれます)
- 週足・月足の出来高に「期間中の1日あたりの平均」を入れる場合は、出来高の凡例が「出来高(平均)」になります(`ChartPeriod`)

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
| VWAP：線 / VWAP：点 | `vwap`(API が計算した VWAP) | API の値をそのまま線・点で描く(チャートでは計算しない) | ― |
| 新値足 | 終値・日付 | 終値が直前の線を更新したときだけ線を足す(3本新値)。最新の終値に現在値の破線 | 1本だけでは線はできない(2本目以降の終値と比べて線を作る) |
| 4本値(十字線) | 日付・始値・高値・安値・終値 | 十字線の位置の足の値をそのまま表示(3桁区切りなし。日付の書式は足種ごと) | 2026/10/01・66000 / 66500 / 65800 / 66300 |
| 移動平均線・多重移動平均線 | 終値 | 直近 n 本の終値の平均(短期 5本・長期 25本など) | ― |
| ボリンジャーバンド | 終値 | 直近 5本(週足 13・月足 25)の終値の平均 ± 標準偏差 × σ | ― |
| 一目均衡表 | 高値・安値・終値 | 転換線・基準線・先行スパンは期間中の(最高値 + 最安値)÷ 2、遅行スパンは終値 | ― |
| パラボリック | 高値・安値・終値 | 高値・安値の更新に合わせて SAR を動かす | ― |
| 出来高 | 出来高 | 出来高の棒 + 直近 5本(週足 13)の平均線 | 24,000,000 の棒 |
| 移動平均乖離率・RSI・サイコロジカル・MACD | 終値 | 終値の変化から計算 | ― |
| ストキャス・DMI | 高値・安値・終値 | 期間中の高値・安値と終値から計算 | ― |

- 出来高が 0 のデータでは、出来高の棒は描けません(凡例だけを表示します)。`vwap` がないデータでは、VWAP は描けません(凡例と「表示できる情報はありません」を表示します)
- 計算式の詳細は [`TechnicalIndicators.swift`](ChartTest/StockChart/Model/Indicators/TechnicalIndicators.swift)、期間などの設定値は [`IndicatorParameters.swift`](ChartTest/StockChart/Model/Indicators/IndicatorParameters.swift) にあります

動作確認用のダミーデータは `SampleData` で作れます。

```swift
let candles = SampleData.candles(for: .daily)              // Swift
```

```objc
NSArray<StockCandle *> *candles = [SampleData candlesForPeriod:ChartPeriodDaily];   // Objective-C
```

### 2. チャートだけを置く(StockChartView)

タブやメニューが不要な場合は、`StockChartView` を置いてデータを渡すだけです(storyboard に置く場合は、View のクラスを `StockChartView` にします)。

```swift
// Swift
let chartView = StockChartView()

chartView.setCandles(candles)                                            // 移動平均線 + 出来高(period・market の設定で描く。既定は日足・国内指数)
chartView.setCandles(candles, period: .weekly)                           // 足種に合った設定(週足: 移動平均 13/26 など)
chartView.setCandles(candles, mainIndicator: .bollingerBands, subIndicator: .macd)   // 指標を指定
```

```objc
// Objective-C
StockChartView *chartView = [[StockChartView alloc] initWithFrame:CGRectZero];

[chartView setCandles:candles];                                          // 移動平均線 + 出来高(period・market の設定で描く。既定は日足・国内指数)
[chartView setCandles:candles period:ChartPeriodWeekly];                 // 足種に合った設定
[chartView setCandles:candles
        mainIndicator:MainChartIndicatorBollingerBands
         subIndicator:SubChartIndicatorMacd];                            // 指標を指定
```

足種・指数の種類は、プロパティで先に設定しておくこともできます。
`period` を設定すると、その足種の見た目(日付の書式・日付ラベルの数・初期表示本数)に切り替わり、`setCandles:` はその足種の設定(移動平均の期間・出来高の凡例名)で描きます。

```objc
// Objective-C
chartView.market = IndexMarketJapanIndex;   // 銘柄・指数の種類(海外指数なら IndexMarketOverseasRealtime / IndexMarketOverseasDaily。サブチャートなしになる)
chartView.period = ChartPeriodWeekly;       // 足種(ChartPeriodOneMinute / Intraday / Daily / Weekly / Monthly)
chartView.visibleCount = 30;                // 足種ごとの値を変えたい場合は、period を設定したあとで変える
chartView.chartType = ChartTypeCandlestick;                 // チャートの種類(既定はローソク足)
chartView.mainIndicator = MainChartIndicatorBollingerBands; // メインチャートの指標(既定は移動平均線)
chartView.subIndicator = SubChartIndicatorMacd;             // サブチャートの指標(既定は出来高)
[chartView setCandles:candles];             // 上の設定で描く(週足・初期表示は 30本)
```

| 足種(`period`) | 移動平均(短期/長期) | X軸の日付 | 日付ラベルの数 | 初期表示 | 縮小の限界 | 出来高の凡例 |
|---|---|---|---|---|---|---|
| `ChartPeriodOneMinute` | 5 / 25 | `HH:mm`(5分ちょうどの時刻) | 横幅に入るだけ(左から重ならない位置) | 全件 | なし | 出来高 |
| `ChartPeriodIntraday` | 5 / 25 | `HH:mm`(5分ちょうどの時刻) | 横幅に入るだけ(左から重ならない位置) | 全件 | なし | 出来高 |
| `ChartPeriodDaily`(既定) | 5 / 25 | `M/d` | 幅から決まる(下の注) | 直近50本 | 250本 | 出来高 |
| `ChartPeriodWeekly` | 13 / 26 | `yy/M/d` | 幅から決まる | 直近50本 | 250本 | 出来高(平均) |
| `ChartPeriodMonthly` | 5 / 25 | `yyyy/M` | 幅から決まる | 直近50本 | 250本 | 出来高(平均) |

日付ラベルの並べ方は `LatestAlignedXAxisRenderer` で決めています(「[データの扱い・表示の仕様](#データの扱い表示の仕様)」の「日付ラベルの並べ方」)。

- 日足・週足・月足: 上限の個数を「表示幅 ÷ 一番長い日付(「1970/10/10 10:10」を書式で表した文字)の幅 × 0.618」とし、表示本数をその個数で割った本数おきに、スクロールできる範囲の右端(最新の足。一目均衡表では先行スパンの右端)から置きます。何本おきかは拡大・縮小したときだけ決め直します。表示本数が上限の個数より少ないほど拡大したときは、右端の足にだけ置きます
- 1分足・日中足: 5分ちょうどの足を、左から順に、前のラベルとの間が「一番長い日付の幅 + 5pt」より空く足に置きます(並ぶ時刻は画面の幅と表示範囲で変わります)
- どちらも、重なるラベル・左端からはみ出すラベルは置きません(右端は、はみ出しても置きます)

- 足種の値そのものを変えたい場合は、`Model/Display/ChartPeriod.swift` を書き換えます
- 同じ足種を設定し直しても(`setCandles:period:` で同じ足種を渡した場合も)、見た目は上書きしません。別の足種に変えたときだけ、その足種の値に戻ります

見た目の設定は、データを渡す前に行います(設定のたびに描き直されるため)。

```swift
// Swift(StockChartStyle のすべての項目を変更できる)
chartView.style.visibleCount = 50        // 初期表示本数(nil で全件)
chartView.style.minimumVisibleCount = 20 // 拡大の限界: 最低でも表示する本数(nil で制限なし)
chartView.style.maximumVisibleCount = 250 // 縮小の限界: 最大で表示する本数(nil で全件まで縮小できる)
chartView.style.priceHeightRatio = 1.5   // メイン:サブ = 60:40
```

```objc
// Objective-C(よく使う項目だけ)
chartView.visibleCount = 50;             // 初期表示本数(0 以下で全件)
chartView.minimumVisibleCount = 20;      // 拡大の限界(0 以下で制限なし)
chartView.maximumVisibleCount = 250;     // 縮小の限界(0 以下で全件まで縮小できる)
chartView.priceHeightRatio = 1.5;        // メイン:サブ = 60:40
```

### 3. 指標メニュー・設定画面付きのチャート(StockChartViewController)

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
chartViewController.market = .japanIndex           // 銘柄・指数の種類(日本株は .japanStock、海外は .overseasRealtime / .overseasDaily)
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
chartViewController.market = IndexMarketJapanIndex;   // 銘柄・指数の種類(日本株は IndexMarketJapanStock、海外は IndexMarketOverseasRealtime / IndexMarketOverseasDaily)
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

指数の種類(`market`)に、次のどちらかを指定します。**データを渡す前に**指定してください(既定は日本株価指数 `.japanIndex`)。

| 指数の種類 | Swift | Objective-C |
|---|---|---|
| 海外株価指数(リアルタイム) | `.overseasRealtime` | `IndexMarketOverseasRealtime` |
| 海外株価指数(日次) | `.overseasDaily` | `IndexMarketOverseasDaily` |

どちらも描き方は同じです(違うのは呼ぶ API だけ)。以下の例はリアルタイムで書いています。日次の場合は `.overseasDaily` / `IndexMarketOverseasDaily` に読み替えてください。

```swift
// Swift: チャートだけ(StockChartView。サブチャートなし。折線チャートにする場合は chartType = .lineChart)
chartView.market = .overseasRealtime
chartView.setCandles(candles, period: .daily)

// Swift: 横画面(テクニカルは移動平均線・なし、チャートの種類はローソク足・折線チャートだけになる)
let landscape = LandscapeChartViewController.instantiate()
landscape.chartViewController.market = .overseasRealtime
landscape.setCandles(candles, period: .daily)

// Swift: StockChartViewController を直接使う場合
chartViewController.market = .overseasRealtime
chartViewController.setCandles(candles, period: .daily)
```

```objc
// Objective-C: チャートだけ(StockChartView)
chartView.market = IndexMarketOverseasRealtime;
[chartView setCandles:candles period:ChartPeriodDaily];

// Objective-C: 横画面
LandscapeChartViewController *landscape = [LandscapeChartViewController instantiate];
landscape.chartViewController.market = IndexMarketOverseasRealtime;
[landscape setCandles:candles period:ChartPeriodDaily];

// Objective-C: StockChartViewController を直接使う場合
chartViewController.market = IndexMarketOverseasRealtime;
[chartViewController setCandles:candles period:ChartPeriodDaily];
```

海外指数にすると、次のように変わります。

| 画面 | 国内(`.japanStock`・`.japanIndex`) | 海外指数(`.overseasRealtime`・`.overseasDaily`) |
|---|---|---|
| チャートだけ(`StockChartView`) | `chartType`・`mainIndicator`・`subIndicator` のとおり(既定はローソク足 + 移動平均線、サブチャートに出来高) | ローソク足(国内と同じ。`chartType` で折線チャートにもできる)+ 移動平均線・なし だけ、サブチャートなし(メインチャートを全高で表示)。VWAP・新値足はローソク足で描く |
| 横画面のテクニカル | メイン・サブとも全項目 | メインは 移動平均線・なし、サブは なし のみ(サブチャートは表示しない) |
| 横画面のチャートの種類 | ローソク足・VWAP：線・VWAP：点・新値足・折線チャート | ローソク足・折線チャート のみ |
| 横画面の折線チャート | 終値の折れ線だけ(テクニカルは「なし」のみ) | 終値の折れ線 + 移動平均線(テクニカルで 移動平均線・なし を選べる)、現在値の破線 |
| 設定画面の項目 | オプション・メインチャート・サブチャートの全項目 | オプション・メインチャートの移動平均線 のみ |
| 設定画面のオプション | Y軸(メイン)固定・Y軸(サブ)固定・4本値 | Y軸(メイン)固定・4本値(Y軸(サブ)固定はオンでも効かない。4本値はローソク足のときだけ表示) |
| 設定画面の足種のタブ | 1分足〜月足(移動平均線以外は 1分足・日中足がグレー) | 日足・週足・月足 の3つだけ |

海外指数に切り替えたとき、選べない指標を選んでいた場合は、メインは移動平均線、サブは なし に切り替わります。
横画面のチャート(`StockChartViewController`)は、チャートの種類・メイン/サブの指標・足種・設定値・表示オプション(Y軸固定・4本値)を**国内(日本株・日本株価指数)と海外(リアルタイム・日次)で別々に**覚えていて、国内⇔海外を切り替えると、切り替えた先で前回選んでいた状態に戻ります(最初は 国内: ローソク足・移動平均線 + 出来高・日足、海外: 折線チャート・移動平均線・日足)。
覚えておくのはアプリを起動している間だけで、画面を閉じて開き直しても残ります(端末には保存しません。`ChartStateStore`。最初の状態に戻すときは `ChartStateStore.reset()`)。
足種も戻るので、`market` を変えたあとは `chartViewController.period` の足種のデータを取得して `setCandles(_:period:)` で渡してください。

海外指数のデータも、国内と同じく**始値・高値・安値・終値**を読みます(ローソク足で描くため)。出来高は 0 になります(レスポンスに `kTurnover` が入っていても使いません)。
値があるかどうかは終値だけで決め、始値・高値・安値のどれかがない件(終値だけの当日の値など)は、3つとも終値にします(その足は横線だけになります)。

国内・海外を切り替えるとき(同じ画面で別の指数を表示するとき)も、`market` を変えてからデータを渡し直します。

### 4. 見た目を変える(色・文字の位置・フォントの大きさ)

チャートの見た目は、すべて `StockChartView` の `style`([`StockChart/View/Chart/StockChartStyle.swift`](ChartTest/StockChart/View/Chart/StockChartStyle.swift))で決まっています。
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

`chartView` は画面ごとに次のように取り出せます。

| 画面 | `chartView` の取り出し方 |
|---|---|
| 横画面 | `landscapeViewController.chartViewController.chartView`(`LandscapeChartViewController`) |
| `StockChartViewController` | `chartViewController.chartView` |

#### 変えられる項目(`StockChartStyle`)

| 変えたいもの | 項目 | 既定値 |
|---|---|---|
| 陽線・陰線の色 | `increasingColor` / `decreasingColor` | 赤 `e5003e` / 青 `157efb` |
| 指標の線の色(移動平均など) | `lineColors`(0 = 1本目、1 = 2本目、…) | 黄緑 `94cb10`・オレンジ `ff8a00`・青 `157efb`・水色 `00a2ff`・濃い青 `006cff` |
| 出来高の棒・出来高移動平均の色 | `volumeColor` / `volumeAverageColor` | 黄緑 / 青 |
| 一目均衡表の線の色 | `ichimokuTenkanColor` など `ichimoku〜Color` | 転換線 `005bd8`・基準線 / 先行1 黄緑・先行2 オレンジ・遅行 `666666` |
| パラボリック(SAR)の点の色 | `parabolicColor` | グレー `666666` |
| 一目均衡表の雲の不透明度 | `cloudAlpha` | 0.25 |
| オシレーターの基準線(RSI の 20/80 など)の色 | `referenceLineColor` | 赤 `e5003e`(実線) |
| VWAP・新値足・折線チャートの色 | `vwapColor` / `newPriceColor` / `lineChartColor` | 赤 / 青 / 青 |
| 現在値の破線の色(新値足・折線チャート) | `currentPriceLineColor` | 濃いグレー |
| 外枠・区切り線・横グリッド線の色 | `borderColor` / `dividerColor` / `gridColor` | 黒 / グレー `aaaaaa` / 薄いグレー |
| 軸ラベル・凡例タイトル(「移動平均」など)の文字色 | `textColor` | 黒 |
| 凡例のフォント(大きさ) | `legendFont` | 12pt |
| 日付(X軸)ラベルのフォント(大きさ) | `xAxisFont` | 8pt |
| 価格(Y軸)ラベルのフォント(大きさ) | `yAxisFont` | 8pt |
| 価格(Y軸)ラベルの位置(外枠の右端からの距離) | `yAxisLabelOffset` | 10pt |
| 価格(Y軸)ラベルの揃え方 | `centersYAxisLabels`(true で一番長いラベルの幅の中で中央揃え) | false(左揃え) |
| 価格(Y軸)ラベルを枠内に収める | `keepsYAxisLabelsInside`(true で下端の「0」などを上にずらし、上端からはみ出すラベルは描かない) | false |
| 凡例の背景色 | `legendBackgroundColor`(白にすると文字の後ろのグリッド線が隠れる) | 透明 |
| 最高値・最安値の表示 | `showsHighLowLabels`(表示中の範囲の最高値・最安値を、その足の上・下に表示する。ローソク足のときだけ。Objective-C は `chartView.showsHighLowLabels`) | false(横画面では true) |
| 最高値・最安値の文字のフォント | `highLowLabelFont` | 12pt |
| 4本値の枠の日付の書式 | `ohlcDateFormat`(足種に合わせて `ChartPeriod.ohlcDateFormat` が入る) | 日足・週足 `yyyy/MM/dd`、月足 `yyyy/MM`、1分足・日中足 `HH:mm` |
| 4本値を薄くするまでの秒数 | `crosshairFadeDelay`(十字線を動かしてからこの秒数が経つと、十字線・マーカー・4本値の枠を薄くする。また動かすと元の濃さに戻る。0 以下なら薄くしない) | 3秒 |
| 4本値を薄くしたときの濃さ(4本値の枠・マーカー・矢印) | `crosshairFadedAlpha`(0 = 見えない 〜 1 = 元の濃さ) | 0.5 |
| 4本値を薄くしたときの濃さ(十字線) | `crosshairFadedLineAlpha` | 0.3 |
| 4本値の日付のマーカーの画像 | `dateMarkerImage`(下の日付ラベルの欄の、縦線を指す赤い矢印の代わりに描く画像。そのままの大きさで、矢印の先を外枠の下端に合わせる) | nil(`increasingColor` で矢印の形を塗る) |
| 4本値の価格のマーカーの画像 | `yAxisMarkerImage`(右端の赤い矢印の代わりに描く画像。そのままの大きさで、横線の高さに中心を合わせる) | nil(`increasingColor` で矢印の形を塗る) |
| メインの凡例の位置(上端) | `legendTopInset`(外枠の上端からの距離) | 3pt |
| サブの凡例の位置(上端) | `subLegendTopInset`(区切り線からの距離) | 2pt |
| 凡例の位置(左端) | `legendLeadingInset`(外枠の左端からの距離) | 8pt |
| 凡例とチャートの線の間隔 | `legendBottomSpacing` | 4pt |
| 右側の価格ラベル欄の幅 | `rightAxisWidth` | 65pt |
| 下側の日付ラベル欄の高さ | `xAxisLabelHeight` | 20pt |
| 日付ラベルを置く時刻(分の倍数) | `xAxisLabelMinuteMultiple`(5 なら、5分ちょうどの足を左から順に重ならない位置に置く。足種ごとの値は `ChartPeriod.xAxisLabelMinuteMultiple`) | 1分足・日中足は 5、それ以外は nil |
| メインとサブの高さの比 | `priceHeightRatio`(メイン : サブ = この値 : 1) | 1.5(= 60 : 40) |
| 初期表示の本数 | `visibleCount`(nil で全件。足種ごとの値は `ChartPeriod.visibleCount`) | 55 |
| 拡大の限界 | `minimumVisibleCount`(ピンチで拡大したときに、最低でも表示する本数。nil で制限なし) | 20 |
| 縮小の限界 | `maximumVisibleCount`(ピンチで縮小したときに、最大で表示する本数。nil で全件まで。足種に合わせて `ChartPeriod.maximumVisibleCount` が入る) | 日足・週足・月足 250本、1分足・日中足 nil(全件) |

- 凡例の文字の色は、線の色と同じになります(凡例だけの色はありません)。線の色を変えると、凡例の文字の色も変わります
- 凡例の位置やフォントを変えても、チャートの線が凡例と重ならないよう、Y軸の上側の余白は自動で調整されます
- 4本値のマーカーを画像にする場合は、Assets に画像を追加して次のように設定します(Objective-C も同じプロパティ名で、`chartView` から設定できます)。

  ```swift
  let chartView = landscapeViewController.chartViewController.chartView
  chartView.dateMarkerImage = UIImage(named: "dateMarker")
  chartView.yAxisMarkerImage = UIImage(named: "priceMarker")
  ```

  ```objc
  StockChartView *chartView = landscapeViewController.chartViewController.chartView;
  chartView.dateMarkerImage = [UIImage imageNamed:@"dateMarker"];
  chartView.yAxisMarkerImage = [UIImage imageNamed:@"priceMarker"];
  ```

#### `style` 以外で決まっている見た目

| 部品 | ファイル | 項目 |
|---|---|---|
| 設定画面の足種タブ(色・文字の大きさ) | [`ChartPeriodTabView.swift`](ChartTest/StockChart/SettingsScreen/ChartPeriodTabView.swift) | `selectedColor`・`normalColor`、`updateSelection` 内のフォント |
| 設定画面(配置・右側の行の見た目) | [`ChartSettingsView.xib`](ChartTest/StockChart/SettingsScreen/ChartSettingsView.xib) | Interface Builder で開いて編集する(Content View = 画面全体、Toggle Row / Stepper Row = 右側の行の見本) |
| 横画面の下の帯(配置) | [`ChartFooterView.xib`](ChartTest/StockChart/LandscapeScreen/ChartFooterView.xib) | Interface Builder で開いて編集する(Content View = 帯全体) |
| 横画面の下の帯(ボタンの色・文字の大きさ・現在値の書式) | [`ChartFooterView.swift`](ChartTest/StockChart/LandscapeScreen/ChartFooterView.swift) | `baseButtonConfiguration`・`menuTitleFont`・`updatePriceInfo` |
| 設定画面の左リスト(項目・見出しの色・文字の大きさ) | [`ChartSettingsView.swift`](ChartTest/StockChart/SettingsScreen/ChartSettingsView.swift) | `headerColor`・`selectedRowColor`、`applyCellStyle` / `viewForHeaderInSection` 内のフォント |
| テクニカルのメニュー(見出しの色・文字の大きさ) | [`TechnicalMenuView.swift`](ChartTest/StockChart/TechnicalMenu/TechnicalMenuView.swift) | `headerColor`・`selectedRowColor`、`makeColumn` / `applyRowStyle` 内のフォント |
| 「テクニカル」「設定」タブ | [`StockChartViewController.swift`](ChartTest/StockChart/Controller/StockChartViewController.swift) | `configureTabButton` |
| 4本値の枠(文字の大きさ・背景) | [`ChartCrosshairViews.swift`](ChartTest/StockChart/View/Crosshair/ChartCrosshairViews.swift) | `OHLCInfoView` |
| 凡例・Y軸の数値の書式(桁区切り・小数の桁数) | [`ChartAxisFormatters.swift`](ChartTest/StockChart/View/Chart/ChartAxisFormatters.swift) | `ChartNumberFormatter` |
| 凡例の文言(「短期移動平均(5)」など) | [`ChartContentBuilder.swift`](ChartTest/StockChart/Model/Content/ChartContentBuilder.swift) | 各指標の `label` / `legendTitle` |

### Swift と Objective-C で使えるものの違い

ほとんどの機能は両方から使えます。Swift の struct(`StockChartStyle`・`IndicatorParameters` など)は Objective-C から直接扱えないため、次の違いがあります。

| 部品 | 両方から使える | Swift だけ |
|---|---|---|
| `StockCandle` | 作成(`init(date:open:high:low:close:volume:)`)、各値の読み取り | ― |
| `StockChartView` | `setCandles`(3種類)、`setCandles:indicatorValues:`、`indicatorPeriods`、`effectiveChartType`・`effectiveMainIndicator`・`effectiveSubIndicator`、`clear`、`period`、`market`、`chartType`、`mainIndicator`、`subIndicator`、`visibleCount`、`minimumVisibleCount`、`maximumVisibleCount`、`priceHeightRatio`、`increasingColor`、`decreasingColor`、`dateFormat`、`noDataMessage`、`legendFont`、`xAxisFont`、`yAxisFont`、`legendTopInset`、`showsHighLowLabels`、`crosshairFadeDelay`、`crosshairFadedAlpha`、`dateMarkerImage`、`yAxisMarkerImage` | `style`(すべての見た目)、`displayOptions`、`display(candles:main:sub:)`、パラメータを指定する `setCandles(_:mainIndicator:subIndicator:parameters:)` |
| `StockChartViewController` | `setCandles`(足種の指定あり/なし)、`period`、`market`、`chartType`、`mainIndicator`、`subIndicator`、`isTechnicalMenuEnabled`、`chartView`、`shortMAPeriod` / `longMAPeriod` / `volumeMAPeriod`、`isMainYAxisFixed` / `isSubYAxisFixed`、`showsOHLC` | `parameters`(表示中の足種の指標の期間など)、`setParameters(_:for:)`(足種を指定)、`updateParametersForAllPeriods`(すべての足種)、`displayOptions`、`onChartTypeChange` |
| `LandscapeChartViewController` | `instantiate`、`chartViewController`、`setCandles`(足種の指定あり/なし)、`updatePriceInfo`、`onPeriodSelect`、`onReload`、`onRotate` | `onPanelVisibilityChange` |
| `SampleData` | `candles(for:)`(Objective-C: `candlesForPeriod:`)、`nikkeiLike(days:)`(Objective-C: `nikkeiLikeWithDays:`) | ― |

`StockChartViewController` の `shortMAPeriod` / `longMAPeriod` / `volumeMAPeriod` は、設定すると**すべての足種**に反映されます(読み出すと表示中の足種の値)。足種ごとに変えたい場合は、設定画面か Swift の `setParameters(_:for:)` を使います。

Swift だけの設定を Objective-C から変えたい場合は、Swift 側に `@objc` プロパティを追加してください(`StockChartView.swift` と `StockChartViewController.swift` の末尾にある「Objective-C 向け」の extension が例です)。

### enum の名前の対応

Swift の enum は、Objective-C では「型名 + ケース名」になります。

| 足種(`ChartPeriod`) | 指数の種類(`IndexMarket`) |
|---|---|
| `.oneMinute` → `ChartPeriodOneMinute`(1分足) | `.japanStock` → `IndexMarketJapanStock`(日本株) |
| `.intraday` → `ChartPeriodIntraday`(日中足) | `.japanIndex` → `IndexMarketJapanIndex`(日本株価指数) |
| `.daily` → `ChartPeriodDaily`(日足) | `.overseasRealtime` → `IndexMarketOverseasRealtime`(海外・リアルタイム) |
| `.weekly` → `ChartPeriodWeekly`(週足) | `.overseasDaily` → `IndexMarketOverseasDaily`(海外・日次) |
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

## アプリへの組み込み

チャート部分(`ChartTest/StockChart/`)は、ほかのアプリにそのまま組み込めるよう、ダミーデータ(`SampleData`)やサンプルの画面切り替え(`ViewController`)には依存しないように作っています。
`StockChart/LandscapeScreen/` にある横画面(`LandscapeChartViewController`)は、同じフォルダにある `Landscape.storyboard` から作る画面です。`StockChart/` フォルダごとコピーすれば storyboard も入ります。

### 手順

手順は「[はじめての導入ガイド](#はじめての導入ガイド)」にステップごとにまとめています。ここでは、組み込むときに使う機能を説明します。

### API のレスポンス(足種ごと)を渡す

足種ごとに取得したレスポンス(辞書の配列)は、[`ChartResponseLoader`](ChartTest/StockChart/Response/ChartResponseLoader.swift) の `setResponse(_:period:to:)` に、そのレスポンスの足種を指定してチャートに渡せます。
どの画面からでも呼べます。**どのスレッドから呼んでもかまいません**(通信の完了処理から直接呼べます。描画は自動でメインスレッドに切り替えて行います)。引数は Swift では `[[String: Any]]`、Objective-C では `NSArray<NSDictionary *> *` なので、`NSMutableArray` のまま渡せます(並び順は問いません。日付の古い順に並べ替えて描きます)。

| 言語 | 書き方(日足の例) |
|---|---|
| Objective-C | `[ChartResponseLoader setResponse:array period:ChartPeriodDaily to:target]` |
| Swift | `ChartResponseLoader.setResponse(array, period: .daily, to: target)` |

足種(`period`)は、1分足 `ChartPeriodOneMinute`(`.oneMinute`)・日中足 `ChartPeriodIntraday`(`.intraday`)・日足 `ChartPeriodDaily`(`.daily`)・週足 `ChartPeriodWeekly`(`.weekly`)・月足 `ChartPeriodMonthly`(`.monthly`)から、渡すレスポンスに合わせて指定します。

描画先(`target`)には、次のどれでも渡せます(`StockCandleReceiving` に対応しているもの)。

| 描画先 | 使う場面 |
|---|---|
| `StockChartView` | 縦画面などに、チャートだけを置く場合 |
| `StockChartViewController` | テクニカル・設定画面付きのチャートを埋め込む場合 |
| `LandscapeChartViewController` | このアプリの横画面をそのまま使う場合 |

```objc
// Objective-C: レスポンスの辞書を配列に入れて、そのまま渡す
NSMutableArray *responseArray = [NSMutableArray array];
[responseArray addObject:@{kTimestamp: @"2026/10/01 00:00", kStart: @"66000", kHeight: @"66500",
                           kLow: @"65800", kEnd: @"66300", kTurnover: @"2400000000"}];
// chartDataFromResponse:… の結果も、そのまま渡せばよい
[ChartResponseLoader setResponse:responseArray period:ChartPeriodDaily to:landscapeViewController];   // 横画面
[ChartResponseLoader setResponse:responseArray period:ChartPeriodDaily to:self.chartView];            // チャートだけ(StockChartView)
```

海外指数の場合は、描画先の `market` を先に `.overseasRealtime` / `.overseasDaily` にしておきます(`StockChartView` は `chartView.market`、横画面は `landscape.chartViewController.market`)。海外指数は終値だけの件も足にするので、国内(`.japanIndex` など)のままだと、その件が値なしになります。

辞書 → `StockCandle` の変換は [`StockCandleResponseParser`](ChartTest/StockChart/Response/StockCandleResponseParser.swift)が行います。

| 項目 | 内容 |
|---|---|
| キーの名前 | `StockCandleResponseParser.Key`。`kTimestamp`・`kStart`・`kHeight`・`kLow`・`kEnd`・`kTurnover`・`kVWAP`(`kVWAP` は 1分足・日中足だけ。空・0 は値なし) |
| 日付の形式 | `StockCandleResponseParser.dateFormats`(`yyyy/MM/dd HH:mm` など。上から順に試す)。`Date`(`NSDate`)もそのまま読める |
| 値の型 | 数値(`NSNumber`)・文字列(`"66,000"` のようなカンマ付きも可)のどちらでも読める |
| 読めない件 | 日付が読めない件は飛ばす。値が読めない件は、直前の足の値で埋める(埋めた足は `StockCandle.isFilled` が true で、ローソク足は描かず空白になる)。ただし、直前の足がない先頭側の件と、値が読めた最後の足より後ろの件は飛ばす(1分足・日中足は飛ばさずに日時だけの足にする。下の「値のない時間帯」) |
| 国内・海外 | 国内は始値・高値・安値・終値がすべて読めた件を有効とし、出来高がなければ 0 にする。海外は終値が読めた件を有効とし、始値・高値・安値はレスポンスの値(どれかがなければ3つとも終値)、出来高は 0 にする |
| 変換だけを使う | Swift: `StockCandleResponseParser.candles(from: array, market: .overseasRealtime)` / Objective-C: `[StockCandleResponseParser candlesFrom:array market:IndexMarketOverseasRealtime]`(`market` を省略すると国内として読む) |

※ 配列に辞書以外の要素が入っていると、受け取った時点でアプリが落ちます(Swift の `[[String: Any]]` に変換できないため)。

### データの扱い・表示の仕様

| 項目 | 内容 |
|---|---|
| 日付 | `chartDataFromResponse:…` の結果(文字列 `"2026/10/02 00:00"`・`"2000/01/01 09:00"`)のままでも、呼び出し側で `NSDate` に変換したあとの配列でも読める。タイムゾーンは端末のタイムゾーン(`systemTimeZone`) |
| 値がない件 | 指標の計算には直前の足の値で埋めた値を使う。ローソク足はその足を描かずに空白にし、折線チャート・VWAP は前後の足を線でつなぐ。新値足は値のある足だけで作る |
| 海外指数 | ローソク足で描くため、国内と同じく4本値を読む。始値・高値・安値のどれかがない件は、3つとも終値にする |
| 日中足 | `chartDataFromResponse:…` が5分ごとにまとめた結果を、そのまま日中足として描く |
| VWAP | API の値(`kVWAP`)だけで描く(指数の日中足のように出来高が 0 でも描ける)。`kVWAP` が空・0 の足は、描かずに前後をつなぐ(0 として描くと線が 0 まで落ちるため) |
| 指標の期間・基準線 | 初期値は、例: ボリンジャー 5(週足 13・月足 25)・±3σ、一目均衡表 転換線 3・基準線 26・スパン 26、出来高移動平均 5(週足 13)、RSI 14(20% / 80%)、ストキャス 高安期間 14・D期間 3(30% / 70%)、MACD 5 / 25 / 9。足種ごとの値は `ChartPeriod.indicatorParameters` |
| 描く線 | ストキャスは %D・Slow%D、パラボリックは移動平均線 2本 + SAR の点、多重移動平均線は 1色(5〜75 を 15本)、MACD はヒストグラムなし、DMI は ADX なし、移動平均乖離率・MACD に 0 の線は引かない |
| ボリンジャーバンドの計算 | 標準偏差は n − 1 で割る(標本標準偏差) |
| DMI の計算 | 直近 n 本の +DM・−DM・TR の単純合計で割る(Wilder 方式の平滑化はしない)。+DM と −DM が同じ値のときは両方残す |
| RSI・ストキャスの値動きなし | 期間中まったく値動きがないとき、RSI は値なし(点を描かない)、ストキャスは 0 |
| 新値足の計算 | 直近3本の線の最高値を上回ったら直前の線の高いほうから、最安値を下回ったら低いほうから線を引く。最初の線は、2本目の終値が1本目と同じでも引く |
| 日付ラベルの並べ方 | 日足・週足・月足は「表示幅 ÷ 一番長い日付の幅 × 0.618」個を上限に本数おき(拡大・縮小のときだけ決め直す)、1分足・日中足は 5分ちょうどの足を左から重ならない位置に置く。右端ははみ出しても置く |
| 海外指数のチャートの種類 | ローソク足・折線チャートから選べる(横画面は最初は折線チャート、チャートだけ(`StockChartView`)は最初からローソク足)。海外指数も4本値を読むので、国内と同じローソク足になる |
| チャートの種類を変えたときの指標 | VWAP・新値足・国内の折線チャートにすると、メイン・サブとも「なし」になる。ローソク足に戻しても「なし」のまま |
| RSI・サイコロジカル・ストキャスの Y軸 | 0〜100 に固定せず表示中の値で決める(上に値幅の 20% の余白、下は余白なし)。底値・高値ラインは範囲に含めないので、値が届かないラインは見えない |
| DMI の期間 | 14 で固定(設定画面には並べない) |
| パラボリックの移動平均線 | 移動平均線の設定とは別に 5・25(週足は 13・26)で固定 |
| パラボリックの計算 | AF は 0.02 から始まり上限 0.2(10進数で足すので誤差で上限を超えない)、2本目から点を置く。一般的な Wilder 方式にある「SAR を直近2本の安値(高値)の外側に置く」制限は入れていない |
| 凡例・色 | 文字の例:「多重平均 期間(5,75)」「ボリンジャー 移動平均(5)」「一目均衡 転換線(3) 基準線(26) 先行スパン2(52)」「パラボリック 5日移動平均 25日移動平均」「ＲＳＩ 期間(14)」「ストキャス %D(14,3) Slow%D」。基準線は赤の実線 |
| 表示範囲・見た目 | 初期表示は日足・週足・月足とも直近 50 本(1分足・日中足は全件)、縮小は 250 本まで、スクロールできる範囲は国内の日足・週足・月足と新値足が最低 250 本・海外が最低 50 本(足りない分は左側を空ける。新値足は直近 250 本まで)、データを更新したとき(足種・指数の種類・チャートの種類・`qCode` が同じ)は直前の表示範囲を引き継ぐ(銘柄の切り替えを `qCode` を使わずに伝える場合は `resetVisibleRange()`)、メイン : サブ = 60 : 40、Y軸ラベルの欄 65pt・文字 8pt、週足の日付 `yy/M/d`、ローソク足の幅 0.6・出来高の棒 0.55、メインのY軸の下の余白 20%、区切り線 `aaaaaa` |
| 海外指数の既定 | 横画面は、海外指数の最初のチャートの種類は折線チャート(国内はローソク足)。チャートだけ(`StockChartView`)は、海外指数も国内と同じくローソク足から始まる |
| 状態の覚え方 | 横画面のチャートの種類・指標・足種・設定値・表示オプションを国内/海外で別々に、アプリの起動中だけ覚える(`ChartStateStore`) |
| 設定画面の値の範囲 | 期間は 1〜99、多重移動平均線の本数は 2〜15、ボリンジャーの σ は 1〜3、移動平均乖離率の底値ラインは −99〜1・高値ラインは 1〜99、RSI・サイコロジカル・ストキャスの底値・高値ラインは 1〜99 |
| 名前の表記 | テクニカルのメニュー・設定画面の指標名は ＲＳＩ・ＭＡＣＤ・ＤＭＩ(全角)、チャートの種類のメニューは ＶＷＡＰ：線・ＶＷＡＰ：点(全角)、設定の項目名は 乖離率（σ）。凡例は「ＲＳＩ 期間(14)」「VWAP：線」(VWAP は半角。`ChartType.legendTitle`) |
| ローソク足・出来高の棒の幅 | 1本の幅を「描画領域の幅 ÷ 20」までにする(足が少ないときに太くなりすぎない) |
| 最高値・最安値 | 横画面・ローソク足のときに、12pt で表示する(国内・海外とも) |
| 4本値の枠 | 日付は足種ごとの書式(日足・週足 `yyyy/MM/dd`、月足 `yyyy/MM`、1分足・日中足 `HH:mm`)、値は 3桁区切りなし(小数は必要な桁だけ。例: 6230・5519.11)。十字線は、最初は描画領域の中央に出し、交点から 15pt 以内をつかむか、ラベルの欄で動かす(足の中心には合わせない)。値のない日時は空欄にする。枠の余白は右・上 5pt。矢印は画像ではなく形を描いている(画像は `style` で差し替えられる) |
| 足が1本だけのとき | 寄り付き直後の1分足・日中足や、過去分がない新規上場の銘柄などで起きる。ローソク足・出来高は1本だけ描かれる。移動平均などの指標は期間に足りないので線が出ない(凡例だけ出る)。折線チャート・新値足・VWAP：線は、値のある足が1本以下なら「表示できる情報はありません」になる(凡例は残す) |
| 値のない時間帯(1分足・日中足) | 寄り付き前やこれから来る時間帯のように、日時だけで値がない件も、X軸に日付を並べる(チャートは値のある時間から途中まで描き、残りは空白で日付だけ出す)。例: 13:00 まで値があり 15:30 まで日時がある日中足は、13:00 で足が止まり、右側に 15:30 までの日付が並ぶ。値のない件が途中にある場合は、上の「値がない件」と同じ(ローソク足は空白、指標は直前の足の値で計算)。値のある件が1件もない場合は「表示できる情報はありません」 |

### データを消す・入れ替えるとき

#### 表示を消す(`clear()`)

`StockChartView` の `clear()` で、表示中のチャートを消して空にできます(凡例・「表示できる情報はありません」のメッセージも出ません)。

| 言語 | 書き方 |
|---|---|
| Swift | `chartView.clear()` |
| Objective-C | `[chartView clear];` |

消えるものは、データ・メインチャートとサブチャートの描画内容・前後に並べる日付・十字線と4本値です。
次の場合は、チャートが自動で `clear()` を呼びます。

- `StockChartViewController`(横画面を含む)に、0件のデータを渡したとき

#### 足種などを切り替えたとき(`setCandles`)

`setCandles` でデータを渡し直すと、`clear()` を呼ばなくても、前の表示は新しい内容に置き換わります。

| 前の表示 | 切り替えたときの処理 |
|---|---|
| ローソク足・指標の線(メインチャート) | 新しく作って入れ替える |
| サブチャート | 新しく作って入れ替える(サブなしなら消す) |
| 一目均衡表の雲 | 入れ替える(雲なしなら消す) |
| 現在値の破線(新値足・折線チャート) | 消してから引き直す |
| 凡例 | 作り直す |
| 最高値・最安値の文字 | 表示範囲から計算し直す(0件なら隠す) |
| 十字線・4本値 | データの件数が変わったときだけ消す。件数が同じなら、同じ位置に出したままにする |
| 表示範囲(スクロール位置・拡大率) | 足種・指数の種類・チャートの種類が変わったら、初期表示(直近 `visibleCount` 本・右端)に戻す。同じなら、データの更新とみなして直前の表示範囲を引き継ぐ |

注意: 十字線・4本値は件数だけで判断しているので、足種を切り替えても件数がたまたま同じなら、前の足種で出していた位置に残ります。
足種を切り替えるときに十字線も消したい場合は、`setCandles` の前に `clear()` を呼びます。

#### 銘柄を切り替えたとき

足種・指数の種類・チャートの種類が同じまま銘柄だけを切り替えると、データの更新とみなされて、前の銘柄の表示範囲が引き継がれます。
初期表示に戻したい場合は、データを渡す前に `resetVisibleRange()` を呼びます(`qCode` を使っている場合は、`qCode` を変えるだけで初期表示に戻ります)。

| やりたいこと | 書き方(Swift) |
|---|---|
| 表示を消すだけ(通信中・エラーのときなど) | `chartView.clear()` |
| 足種を切り替える | `chartView.setCandles(candles, period: .weekly)` |
| 足種を切り替えて、十字線も消す | `chartView.clear()` のあとに `chartView.setCandles(candles, period: .weekly)` |
| 銘柄を切り替えて、表示範囲を初期表示に戻す | `chartView.resetVisibleRange()` のあとに `chartView.setCandles(candles)` |

### 横画面のチャートだけを使う場合

縦画面はアプリの今の画面をそのまま使い、横画面のチャート(テクニカル・設定画面・下の帯付き)だけを組み込む場合です。

#### コピーするもの・しないもの

| ファイル | 必要か | 説明 |
|---|---|---|
| `StockChart/` フォルダ(`ChartSettingsView.xib`・`ChartFooterView.xib` を含む) | 必要 | チャート本体・テクニカル・設定画面・下の帯。`ChartPeriodTabView` も設定画面の足種のタブで使うので、フォルダごとコピーする |
| `StockChart/LandscapeScreen/Landscape.storyboard` | 必要 | 横画面(下の帯付き)。画面のクラス `LandscapeChartViewController` も同じ `StockChart/LandscapeScreen/` に入っている。下の帯が不要なら、`StockChartViewController` を直接使ってもよい |
| `Sample/` フォルダ・`App/Base.lproj/Main.storyboard` | 不要 | このアプリの、縦横を切り替えるサンプル画面 |
| `Sample/SampleData.swift` | 不要 | 動作確認用のダミーデータ(`Sample/` フォルダに含まれる) |

#### 横画面を表示する

既存の縦画面から、横画面のチャートを表示します。表示の仕方はアプリに合わせて選んでください。

- **ボタンなどで全画面に表示する**(参考画面の右上の回転ボタンのような使い方)

```swift
// Swift(既存の縦画面の ViewController から)
let landscape = LandscapeChartViewController.instantiate()
landscape.chartViewController.market = .japanIndex        // 日本株は .japanStock、海外指数は .overseasRealtime / .overseasDaily(データを渡す前に指定する)
landscape.setCandles(candles, period: .daily)             // 表示中の足種のデータ(古い順)
landscape.modalPresentationStyle = .fullScreen
present(landscape, animated: true)
```

```objc
// Objective-C(既存の縦画面の ViewController から)
LandscapeChartViewController *landscape = [LandscapeChartViewController instantiate];
landscape.chartViewController.market = IndexMarketJapanIndex;   // 日本株は IndexMarketJapanStock、海外指数は IndexMarketOverseasRealtime / IndexMarketOverseasDaily
[landscape setCandles:candles period:ChartPeriodDaily];
landscape.modalPresentationStyle = UIModalPresentationFullScreen;
[self presentViewController:landscape animated:YES completion:nil];
```

  このとき、次の2点をアプリ側で追加してください(`LandscapeChartViewController` はコピーしたものを直接書き換えて構いません)。

  - 横向きで表示する: `LandscapeChartViewController` に次を追加する(アプリの対応する向きに「横」が含まれている必要があります)

    ```swift
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    ```

  - 閉じる操作: 下の帯の「縦画面に戻す」ボタンが押されたら呼ばれる `onRotate` で、`dismiss(animated:)` を呼ぶ

    ```swift
    landscape.onRotate = { [weak landscape] in landscape?.dismiss(animated: true) }
    ```

- **端末を横にしたときに切り替える**

  このアプリの `ViewController.swift` と同じ方法です。既存の画面に `LandscapeChartViewController` を子 ViewController として画面いっぱいに埋め込んでおき、`viewDidLayoutSubviews` で縦横を判定して、横のときだけ表示します(`ViewController.swift` の `embed` / `applyLayout` を参照)。

#### 下の帯をアプリ側のものにする場合

`Landscape.storyboard` の下の帯の代わりにアプリ側のボタン(足種・更新など)を使う場合は、`StockChartViewController` を直接埋め込み、ボタンの分の余白を `chartInsets` で空けます。チャートの種類は `chartType` で切り替えます(`LandscapeChartViewController.swift` が実装例です)。

```swift
chartViewController.chartInsets = UIEdgeInsets(top: 8, left: 0, bottom: 下のボタンの高さ + 余白, right: 8)
chartViewController.chartType = .lineChart               // アプリ側のボタンで選ばれた種類
chartViewController.setCandles(candles, period: .weekly) // アプリ側のボタンで選ばれた足種のデータ
```

テクニカル/設定を開いている間にアプリ側のボタンにもグレーをかけたい場合は、`onPanelVisibilityChange` でパネルの開閉を受け取り、`StockChartViewController` の View をボタンより手前に出します(`LandscapeChartViewController` の `configurePanelLayering` を参照)。

### 組み込むアプリ側で確認が必要なこと

| 項目 | このプロジェクトの設定 | 組み込むアプリで違う場合 |
|---|---|---|
| Objective-C から使う | `#import "ChartTest-Swift.h"` | ヘッダ名は `<アプリのモジュール名>-Swift.h` になる。Objective-C だけのアプリなら、Swift を使えるようにする設定(Bridging Header など)が必要 |
| Swift の並行処理の設定 | Default Actor Isolation = **MainActor**、Swift 5 | 組み込むアプリで Default Actor Isolation を指定していない(nonisolated)場合も、エラー・警告なくビルドできることを確認済み。設定を変える必要はない |
| Xcode | Xcode 27 で作成 | Xcode 27 以上が必要(プロジェクトファイルが Xcode 27 の形式のため) |
| 対応 OS | iOS 18 以上で動作確認 | iOS 15 以降の API を使っているので、それより前の OS では使えない(iOS 18 未満は未確認) |
| ダークモード | ライトモード固定 | 色はライトモード前提(白背景・黒文字)。ダークモードに対応しているアプリでは、`StockChartStyle` で見た目を調整する |
| 型の名前 | `StockCandle`・`ChartType`・`ChartPeriod` など | 組み込むアプリに同じ名前の型があると衝突するので、名前を変える |
| DGCharts の警告 | Documentation Comments = NO | Objective-C から使うと、DGCharts のヘッダで「Empty paragraph passed to '\param' command」などの警告が大量に出ることがある(エラーではない。「準備(Objective-C のみ)」を参照) |

## フォルダ構成

`StockChart/` が、ほかのアプリにも組み込めるチャートの部品です。それ以外は、このサンプルアプリだけで使うものです。
`StockChart/` の中は、役割ごとに **Model**(計算とデータ)・**View**(画面の部品)・**Controller**(状態を持ち、Model と View をつなぐ)に分けています。1つの画面・機能だけで使うものは、`SettingsScreen/`・`TechnicalMenu/`・`LandscapeScreen/`・`Response/`・`DGChartEnum/` にまとめています。

```
ChartTest/
├─ App/                                 アプリ本体(起動・画面の土台)
│   ├─ AppDelegate.swift / SceneDelegate.swift
│   ├─ Info.plist
│   ├─ Assets.xcassets
│   └─ Base.lproj/                          Main.storyboard・LaunchScreen.storyboard
│
├─ Sample/                              サンプル(動作確認用。ほかのアプリには不要)
│   ├─ ViewController.swift                 縦向きは StockChartView、横向きは横画面を表示する画面
│   ├─ SampleData.swift                     動作確認用のダミーデータ
│   ├─ SampleResponses/oneMinute.json       1分足のデータ(実際のレスポンス。14:35 まで値があり、15:30 まで日時がある)
│   ├─ SampleResponses/intraday.json        日中足のデータ(実際のレスポンス。14:35 まで値があり、15:30 まで日時がある)
│   └─ ObjCSample/                          Objective-C から使う例
│
└─ StockChart/                          ★ チャートの部品(ほかのアプリにはこのフォルダごとコピーする)
   │
   ├─ Model/                            計算とデータ(画面の部品には依存しない)
   │   ├─ Data/                             元になるデータ
   │   │   └─ StockCandle.swift                 ローソク足1本分のデータ
   │   ├─ Display/                          チャートの種類・足種・表示の設定
   │   │   ├─ ChartPeriod.swift                 足種(1分足〜月足)・指数の種類(国内/海外)
   │   │   ├─ ChartType.swift                   チャートの種類(ローソク足・折線チャート など)
   │   │   ├─ ChartDisplayOptions.swift         表示オプション(Y軸固定・4本値)
   │   │   └─ ChartStateStore.swift             横画面で選んだ状態を国内/海外ごとに覚える
   │   ├─ Indicators/                       テクニカル指標
   │   │   ├─ ChartIndicatorType.swift          指標の種類(移動平均線・RSI など)
   │   │   ├─ ChartIndicatorValues.swift        チャートの外で計算した指標の値・計算に使う期間
   │   │   ├─ IndicatorParameters.swift         指標のパラメータ(期間など)
   │   │   └─ TechnicalIndicators.swift         指標の計算式
   │   └─ Content/                          「何を描くか」
   │       ├─ ChartContent.swift                「何を描くか」を表すデータ
   │       └─ ChartContentBuilder.swift         データ + 指標 → 「何を描くか」を組み立てる
   │
   ├─ View/                             画面の部品
   │   ├─ Chart/                            チャート本体
   │   │   ├─ StockChartView.swift              ★ チャート本体の入口
   │   │   ├─ StockChartView+Layout.swift       部品の配置
   │   │   ├─ StockChartView+Rendering.swift    描画・凡例
   │   │   ├─ StockChartView+AxisRange.swift    スクロール/ズームと、Y軸の範囲
   │   │   ├─ StockChartView+HighLowLabels.swift 最高値・最安値の文字
   │   │   ├─ StockChartStyle.swift             ★ 見た目の設定(色・フォント・余白など)
   │   │   ├─ ChartAxisFormatters.swift         軸ラベル・価格などの書式
   │   │   └─ Renderers/                        DGCharts の描き方を変える部品(ふだんは触らない)
   │   │       ├─ CloudCombinedRenderer.swift       一目均衡表の雲
   │   │       ├─ LatestAlignedXAxisRenderer.swift  日付ラベルの並べ方
   │   │       ├─ AlignedYAxisRenderer.swift        価格ラベルの揃え方
   │   │       └─ SafePinchCombinedChartView.swift  ピンチのクラッシュ対策
   │   └─ Crosshair/                        4本値(十字線)
   │       ├─ StockChartView+Crosshair.swift    十字線の操作・配置
   │       └─ ChartCrosshairViews.swift         十字線・4本値の枠・マーカーの部品
   │
   ├─ TechnicalMenu/                    テクニカルのメニュー(テクニカルタブ)だけで使うもの
   │   └─ TechnicalMenuView.swift           指標の選択メニュー
   │
   ├─ SettingsScreen/                   設定画面(設定タブ)だけで使うもの
   │   ├─ ChartSettingsView.swift / .xib    設定画面
   │   ├─ ChartPeriodTabView.swift          足種のタブ(設定画面の上)
   │   └─ ChartSettingsCatalog.swift        設定画面に並べる項目
   │
   ├─ LandscapeScreen/                  横画面だけで使うもの(横画面を使わなければフォルダごと削除してよい)
   │   ├─ LandscapeChartViewController.swift 横画面(+ Landscape.storyboard)
   │   └─ ChartFooterView.swift / .xib      横画面の下の帯
   │
   ├─ Response/                         API のレスポンスをチャートに渡す
   │   ├─ ChartResponseLoader.swift         レスポンスをチャートに渡す入口
   │   └─ StockCandleResponseParser.swift   API のレスポンス → StockCandle の配列(キーの名前・日付の形式)
   │
   ├─ DGChartEnum/                      DGMainChart などの enum で設定するための部品(使わなければフォルダごと削除してよい)
   │   ├─ DGChartEnum.swift                 チャートの設定に使う enum(Objective-C からも使える)
   │   └─ StockChartView+DGChartEnum.swift  DGChartEnum の enum で設定するプロパティ
   │
   ├─ Controller/                       状態を持ち、Model と View をつなぐ
   │   └─ StockChartViewController.swift    ★ テクニカル・設定画面付きのチャート
   │
   └─ Common/                           Model・View・Controller の共通部品
       └─ MainThread.swift                  データを受け取る入口を、必ずメインスレッドで動かす

docs/images/                            README の画像
```

★ は、使うとき・見た目を変えるときに、最初に見るファイルです。

### やりたいことから探す

| やりたいこと | 見るファイル |
|---|---|
| 色・フォント・余白を変えたい | `View/Chart/StockChartStyle.swift` |
| 足種ごとの移動平均の期間・初期表示本数を変えたい | `Model/Display/ChartPeriod.swift` |
| 指標の計算式を確かめたい | `Model/Indicators/TechnicalIndicators.swift` |
| サブチャート(出来高など)の中身・凡例を変えたい | `Model/Content/ChartContentBuilder.swift`(`subContent(for:)`)。詳しくは [サブチャート(出来高など)](#サブチャート出来高など) |
| 凡例の文言(「短期移動平均(5)」など)を変えたい | `Model/Content/ChartContentBuilder.swift` |
| API のレスポンスのキーの名前・日付の形式を合わせたい | `Response/StockCandleResponseParser.swift` |
| 設定画面に並べる項目・値の範囲を変えたい | `SettingsScreen/ChartSettingsCatalog.swift` |
| 設定画面・下の帯の配置を変えたい | `SettingsScreen/ChartSettingsView.xib`・`LandscapeScreen/ChartFooterView.xib`(Interface Builder で開く) |
| 4本値(十字線)の動きを変えたい | `View/Crosshair/StockChartView+Crosshair.swift` |
| テクニカル/設定パネルの開き方を変えたい | `Controller/StockChartViewController.swift` |
| 横画面の下の帯のボタンの動きを変えたい | `LandscapeScreen/LandscapeChartViewController.swift` |

### Model(`StockChart/Model/`)

| ファイル | 内容 |
|---|---|
| `StockCandle.swift` | ローソク足1本分のデータ(日付・始値・高値・安値・終値・出来高) |
| `TechnicalIndicators.swift` | 指標の計算(移動平均・ボリンジャーバンド・一目均衡表・RSI・MACD・VWAP・新値足 など) |
| `ChartType.swift` | チャートの種類(ローソク足・VWAP：線・VWAP：点・新値足・折線チャート) |
| `ChartIndicatorType.swift` | 指標の種類(メインチャート用 / サブチャート用) |
| `ChartIndicatorValues.swift` | チャートの外(Objective-C など)で計算した指標の値(`ChartIndicatorValues`)と、計算に使う期間(`ChartIndicatorPeriods`)。値がある指標はチャートが計算しない |
| `ChartPeriod.swift` | 足種(1分足〜月足)と足種ごとの表示の違い、指数の種類(国内/海外)ごとに選べる足種 |
| `IndicatorParameters.swift` | 指標の計算パラメータ(期間など) |
| `ChartContent.swift` | チャートに「何を描くか」を表すデータ(線・棒・雲・凡例の文字) |
| `ChartContentBuilder.swift` | ローソク足 + チャートの種類 + 指標 + パラメータ → `ChartContent` を組み立てる |
| `ChartDisplayOptions.swift` | 表示オプション(Y軸固定・4本値) |
| `ChartStateStore.swift` | 横画面のチャートで選んだ状態(チャートの種類・指標・足種・設定値・表示オプション)を、国内/海外ごとにアプリの起動中だけ覚える |

### View(`StockChart/View/`)

| フォルダ | ファイル | 内容 |
|---|---|---|
| `Chart/` | `StockChartView.swift` | **チャート本体**。外から呼ぶ入口とプロパティ |
| | `StockChartView+Layout.swift` | 部品の配置(Auto Layout)と見た目の設定 |
| | `StockChartView+Rendering.swift` | `ChartContent` を DGCharts のデータに変換して描く・凡例を作る |
| | `StockChartView+AxisRange.swift` | スクロール/ズームの同期と、Y軸の範囲の調整 |
| | `StockChartView+HighLowLabels.swift` | 表示中の範囲の最高値・最安値を、その足の上・下に表示する |
| | `StockChartStyle.swift` | 見た目の設定(色・フォント・余白・初期表示本数・拡大縮小の限界) |
| | `ChartAxisFormatters.swift` | 軸ラベルの書式(X軸の日付・Y軸の数値)と、価格などの数値の書式(`ChartNumberFormatter`) |
| `Chart/Renderers/` | `CloudCombinedRenderer.swift` | 一目均衡表の雲を塗るための描画処理 |
| | `LatestAlignedXAxisRenderer.swift` | 日付(X軸)ラベルを並べる描画処理 |
| | `AlignedYAxisRenderer.swift` | 価格(Y軸)ラベルの中央揃え・枠内に収める描画処理 |
| | `SafePinchCombinedChartView.swift` | ピンチ開始時のクラッシュ(DGCharts の不具合)を防いだチャート |
| `Crosshair/` | `StockChartView+Crosshair.swift` | 表示オプションの反映と、十字線・4本値の表示・操作 |
| | `ChartCrosshairViews.swift` | 十字線・4本値の枠・マーカーの部品 |

### 設定画面(`StockChart/SettingsScreen/`)

設定画面(設定タブ)だけで使うものを、Model・View の区別なくまとめています。設定画面を変えるときは、このフォルダだけ見れば足ります。

| ファイル | 内容 |
|---|---|
| `ChartSettingsView.swift` / `.xib` | 設定画面(View)。画面の配置(足種のタブ・行・下のボタン)と、右側の行の見本(トグル行・数値行)は XIB で編集する |
| `ChartPeriodTabView.swift` | 足種のタブ(View。設定画面の上部) |
| `ChartSettingsCatalog.swift` | 設定画面に並べる項目と、編集できるパラメータ・設定できる足種の定義(Model) |

### テクニカルのメニュー(`StockChart/TechnicalMenu/`)

| ファイル | 内容 |
|---|---|
| `TechnicalMenuView.swift` | 指標の選択メニュー(テクニカルタブ) |

### 横画面(`StockChart/LandscapeScreen/`)

横画面だけで使うものをまとめています。横画面を使わない場合は、フォルダごと削除してかまいません。

| ファイル | 内容 |
|---|---|
| `LandscapeChartViewController.swift` | 横画面(StockChartViewController を埋め込み、下の帯(指数名・現在値、チャートの種類・足種・更新・縦画面に戻す)を付ける)。`Landscape.storyboard` から作る |
| `Landscape.storyboard` | 横画面のレイアウト(Interface Builder で開いて編集する) |
| `ChartFooterView.swift` / `.xib` | 横画面の下の帯(指数名・現在値、チャートの種類・足種・更新・縦画面に戻すのボタン)。配置は XIB で編集する |

### API のレスポンス(`StockChart/Response/`)

| ファイル | 内容 |
|---|---|
| `ChartResponseLoader.swift` | API のレスポンス(足種ごと)を、どこからでもチャートに渡して描画するユーティリティ(描画先は `StockCandleReceiving`) |
| `StockCandleResponseParser.swift` | API のレスポンス(辞書の配列)を `StockCandle` の配列に変換する(キーの名前・日付の形式はここで決める) |

### DGChartEnum(`StockChart/DGChartEnum/`)

`DGMainChart` などの enum でチャートを設定するための部品です。使わない場合は、フォルダごと削除してかまいません。

| ファイル | 内容 |
|---|---|
| `DGChartEnum.swift` | チャートの設定に使う enum(`DGMainChart`・`DGSubChart`・`DGChartCategory`・`DGChartData`・`DGChartMode`・`DGCodeType`)。Objective-C からも使える |
| `StockChartView+DGChartEnum.swift` | `DGChartEnum` の enum で設定するプロパティ(`mainChart`・`subChart`・`chartCategory`・`chartData`・`qCodeType`)と銘柄コード `qCode` |

### Controller(`StockChart/Controller/`)

| ファイル | 内容 |
|---|---|
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

1. `StockChart/Model/Data/StockCandle.swift` と `ChartContent.swift` … 扱うデータの形
2. `StockChart/Model/Content/ChartContentBuilder.swift` … 指標から「何を描くか」を作るところ
3. `StockChart/View/Chart/StockChartView.swift` … チャート本体の入口(冒頭のコメントに全体図があります)
4. 同じフォルダの `StockChartView+Layout.swift` → `+Rendering.swift` → `+AxisRange.swift` → `View/Crosshair/StockChartView+Crosshair.swift`
5. `StockChart/Controller/StockChartViewController.swift` … 横画面のメニュー・設定の制御

指標の計算式を知りたいときは `TechnicalIndicators.swift` を見てください(各関数のコメントに式があります)。

## コードの書き方の約束

- 三項演算子(`a ? b : c`)や、`&&` を何行もつなげた条件式は使わない。`if` / `guard` / `switch` で1条件ずつ書く
- 1〜2文字の変数名は使わず、意味のわかる名前にする(ループの `i` / `j` を除く)
- 自分のプロパティ・メソッドには `self.` を付ける(UIKit から引き継いだ `view` / `bounds` / `addSubview` なども含む)。
  ローカル変数・引数と区別しやすくするため。`if let x {` のような省略形は、そのまま使ってよい。
  まとめて付ける場合は SwiftFormat を使う: `swiftformat ChartTest --rules redundantSelf --self insert --swiftversion 5.0`
  (SwiftFormat は、別ファイル・別の extension で宣言したメンバーや、`if let` / `guard let` の右側には付けないので、残りは手で付ける)

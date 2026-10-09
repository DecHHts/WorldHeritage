<p align="center"><img src="docs/design/appicon.png" width="120" alt="icon"></p>
<h1 align="center">世界遺産さんぽ（世遗漫游）</h1>
<p align="center">[简体中文](README.md) · [English](README.en.md) · **日本語** · [한국어](README.ko.md)</p>
<p align="center">ユネスコ世界遺産リストをもとにした、旅先選びのための iOS アプリ。世界ヒートマップ、国別マップ、行き先ルーレット、デバイス上の AI による提案、旅程づくりを備えています。</p>
<p align="center">
<img src="https://img.shields.io/badge/platform-iOS%2016%2B-blue" alt="platform">
<img src="https://img.shields.io/badge/Swift-5-orange" alt="swift">
<img src="https://img.shields.io/badge/UI-SwiftUI-informational" alt="swiftui">
<img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-lightgrey" alt="license">
</p>

<table>
<tr><td align="center"><img src="docs/screenshots/explore.png" width="190" alt="世界ヒートマップとタイムライン"><br><sub>世界ヒートマップとタイムライン</sub></td><td align="center"><img src="docs/screenshots/wheel.png" width="190" alt="行き先ルーレット"><br><sub>行き先ルーレット</sub></td><td align="center"><img src="docs/screenshots/assistant.png" width="190" alt="AI に行き先を選んでもらう"><br><sub>AI に行き先を選んでもらう</sub></td><td align="center"><img src="docs/screenshots/footprint.png" width="190" alt="わたしの足あと"><br><sub>わたしの足あと</sub></td></tr>
<tr><td align="center"><img src="docs/screenshots/badges.png" width="190" alt="バッジ"><br><sub>バッジ</sub></td><td align="center"><img src="docs/screenshots/themes.png" width="190" alt="カラーテーマ"><br><sub>カラーテーマ</sub></td><td align="center"><img src="docs/screenshots/detail.png" width="190" alt="遺産の詳細と訪問記録"><br><sub>遺産の詳細と訪問記録</sub></td></tr>
</table>

## 概要

世界遺産さんぽは、ユネスコ世界遺産リストの全 1,273 件を、拡大・縮小できる 1 枚の世界地図に載せたアプリです。まず世界全体のヒートマップを眺め、気になる国をタップするとその国の遺産が表示されます。各遺産には登録年、登録基準、歴史や文化の概要があります。行き先に迷ったときは、ルーレットに任せるか、ひとことで希望を伝えてください。

すべて SwiftUI と MapKit で書かれており、サードパーティのライブラリも独自サーバーも使っていません。リストのデータはアプリに同梱され、AI の提案はデバイス上で動きます。

## 機能

### 無料

- **世界ヒートマップ**：独自に描画するカーネル密度のヒートレイヤー。拡大するとクラスタ表示のピンに切り替わります。すべて・文化・自然・複合・危機遺産で切り替えできます。
- **国別マップ**：国をタップすると、その国の遺産の分布とカード一覧を表示します。
- **遺産の詳細**：登録年、種別、登録基準、概要、ミニマップ。マップアプリやユネスコ公式ページも開けます。
- **行き先ルーレット**：地域・種別・「行きたい」リストからランダムに選びます。候補数は 5〜30 で調整できます。
- **リスト**：全 1,273 件を検索・絞り込み・並べ替えできます。
- **近くの遺産**：現在地からの直線距離の近い順に表示します。
- **行きたい / 訪問済み**：訪問ごとに日付、ひとことメモ、写真を残せます。
- **行き先の提案**：日数・種別・地域・距離から、まとめて回りやすい遺産の組み合わせを提案します。
- **5 つの言語**：簡体字中国語、繁体字中国語、英語、日本語、韓国語。遺産名と概要もすべてローカライズされています。システムの言語に従うほか、個別にも設定できます。
- **今日の遺産**：毎日の通知とホーム画面ウィジェット。

### Pro（サブスクリプション）

- **AI 旅行アシスタント**：旅の希望をひとことで入力すると、デバイス上の Apple Intelligence（Foundation Models）が条件に変換し、おすすめの理由を書きます。モデルが担当するのは理解と説明だけで、遺産そのものは必ずアプリがリストから選ぶため、存在しない場所が出てくることはありません。
- **旅程プランニング**：複数の遺産をルートにまとめ、回りやすい順に並べ替え、日数と距離を見積もります。カレンダーファイルの書き出しや、マップアプリでの表示もできます。
- **条件付きルーレット**：距離・季節・訪問済みかどうかで絞り込み、複数のルーレットを保存できます。
- **到着通知と自動チェックイン**：遺産の近くに来ると通知し、自動で訪問済みに記録します。
- **カスタムレイヤーとタイムライン**：行きたい場所や未訪問だけを表示、1978 年からのリストの移り変わりを再生、衛星写真への切り替え。
- **振り返りとバッジ**：年間の振り返り、地域・種別・達成数のバッジ、共有できる足あとポスター。
- **音声ガイド**、**オフライン写真パック**、**カラーテーマ**（青磁・藍・桜・墨金・松）、**足あとウィジェット**、**無制限の保存と iCloud 同期**。

## バッジのデザイン

<p align="center"><img src="docs/design/badge_asia.svg" width="68" alt="asia"><img src="docs/design/badge_europe.svg" width="68" alt="europe"><img src="docs/design/badge_africa.svg" width="68" alt="africa"><img src="docs/design/badge_arab.svg" width="68" alt="arab"><img src="docs/design/badge_latin.svg" width="68" alt="latin"><img src="docs/design/badge_cultural.svg" width="68" alt="cultural"><img src="docs/design/badge_natural.svg" width="68" alt="natural"><img src="docs/design/badge_mixed.svg" width="68" alt="mixed"><img src="docs/design/badge_bronze.svg" width="68" alt="bronze"><img src="docs/design/badge_silver.svg" width="68" alt="silver"><img src="docs/design/badge_gold.svg" width="68" alt="gold"></p>

バッジとアプリアイコンのベクター原稿は [`docs/design`](docs/design) にあります。

## 技術メモ

| 項目 | 実装 |
|---|---|
| UI | SwiftUI、iOS 16 以降 |
| 地図 | MapKit（`MKMapView` のラッパー）。独自の `MKOverlayRenderer` がタイルごとにガウスカーネル密度のヒートマップを描画 |
| 国の判定 | Natural Earth 1:50m の国境ポリゴンを同梱し、点の内外判定を実施 |
| AI | Foundation Models フレームワーク（iOS 26 以降）の構造化出力。利用できない場合は条件による絞り込みに切り替え |
| 課金 | StoreKit 2。テスト用の StoreKit 構成ファイル付き |
| ウィジェット | WidgetKit。App Group を通じてアプリと少量の状態を共有 |
| ローカライズ | 軽量な独自の文字列テーブル。再起動なしで言語を切り替え |
| データ | リストはアプリに同梱され、オフラインで利用可能 |

## ビルドと実行

1. Xcode 26 以降が必要です（開発は Xcode 27 で行っています）。
2. `WorldHeritage.xcodeproj` を開き、iOS 16 以降のシミュレータを選んで実行します。
3. デバッグビルドでは「マイ → サブスクリプション」に「デバッグ：登録済みとして動作」のスイッチがあり、Pro の機能をすべて試せます。
4. AI アシスタントには、iOS 26 以降と Apple Intelligence が有効なデバイスが必要です。
5. 実機で動かす場合は、Signing & Capabilities でご自身のチームを選び、Bundle ID と App Group をご自身のものに変更してください。

## ディレクトリ構成

```
WorldHeritage/            アプリ本体
  Models/                 データモデル、ローカライズ、お気に入り、位置情報、テーマ
  Map/                    ヒートレイヤーと地図のラッパー
  Views/                  探索、ルーレット、リスト、マイページ
  Features/               AI アシスタント、旅程、振り返りとバッジ
  Pro/                    課金とペイウォール
  Resources/              リストと国境のデータ
HeritageWidget/           ホーム画面ウィジェット
docs/                     スクリーンショットとデザイン原稿
```

## データの出典

- リスト、登録年、登録基準、概要は [UNESCO World Heritage Centre](https://whc.unesco.org) の公開データに基づきます。公式の中国語訳がない項目の中国語、およびすべての日本語・韓国語は本プロジェクトによる編訳で、誤りを含む可能性があります。ご指摘を歓迎します。
- 国境データは [Natural Earth](https://www.naturalearthdata.com) によるものです。タップ判定のためだけに使用しており、いかなる立場も示すものではありません。
- 本プロジェクトはユネスコと提携・協力関係にありません。

## ライセンス

ソースコードは [PolyForm Noncommercial License 1.0.0](LICENSE.md) で公開しています。学習、改変、個人利用などの非商用目的で自由にお使いいただけますが、**商用利用はできません**。App Store での配信を含む商用利用の権利は作者が保持します。アプリに同梱している第三者のデータはこのライセンスの対象外です。詳しくは [NOTICE](NOTICE) をご覧ください。

## Star の推移

[![Star History Chart](https://api.star-history.com/svg?repos=DecHHts/WorldHeritage&type=Date)](https://star-history.com/#DecHHts/WorldHeritage&Date)

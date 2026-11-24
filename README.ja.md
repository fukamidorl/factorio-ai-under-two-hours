# AIにファクトリオを1時間40分以内にクリアしてもらう方法

[English](README.md) · **日本語** · [简体中文](README.zh-Hans.md)

**公開候補 v0.2.0-rc.1**では、Factorio 2.1.25の固定シードを専用Lua MODで走らせ、ゲーム内 **1:34:05.300** にロケットの上昇を完了し、**1:34:14.783** にスペースサイエンスパック1,000個が着荷しました。 [公開候補の日本語手順](replay-kit/README.md)

## 初回公開版 v0.1.0

以下は初回公開時のルート、手順、実測値です。

Factorio **2.1.25** の基本ゲームで、シード **4263722700** の新規フリープレイから衛星を打ち上げます。同じマップを生成する設定、施工と配給を行う Lua MOD、画面あり・なしのランチャーを収録しています。

設計、実装、試走、検証、文書化まで、**ChatGPTがほぼすべての仕事を行いました。** ユーザーは目標を設定し、参考RTAの提供と改善案の提案、最終打ち上げの確認に参加しました。公開名義は **Factory Launch Project** です。

## 見る・再現する

Windows、Factorio 2.1.25、Python 3.11 以降を用意し、このフォルダで PowerShell を開きます。Pythonの追加パッケージは不要です。Steamが「カスタム引数を指定してゲームを起動」を表示したら、今回の試走フォルダを指す引数を確認し、「続行」を選ぶとゲームが開きます。

~~~powershell
py -3 -X utf8 .\run_route.py check
py -3 -X utf8 .\run_route.py visible watch-01
py -3 -X utf8 .\run_route.py report watch-01
~~~

画面なしで発射と着荷まで検証する場合は、`visible watch-01` の代わりに `headless verify-01` を実行します。再実行時は毎回新しい試走名を使います。Steamの標準の場所と異なる場合は `check` と実行コマンドに `--factorio "D:\Games\Factorio\bin\x64\factorio.exe"` を追加します。`py -3` は利用できる Python の実行パスに置き換えられます。

ランチャーはインストール済みのFactorioで開始セーブを試走用フォルダに生成し、同梱の専用MOD **`first-rocket-route-check` 0.1.0** を有効にして開きます。Factorioをすでに起動している場合は、画面付き試走の前に必要なセーブを保存して閉じます。 [Factorioの起動・観戦・終了手順](docs/ja/METHOD_AND_TOOLS.md)

## 実測記録

| 試走 | 操作開始から発射まで | 最後に確認した状態 |
| --- | ---: | --- |
| 配布版、画面なし | **1:50:18** | 1:50:27に宇宙サイエンス1,000個が着荷 |
| 同じ工程の先行画面付き試走 | **1:52:59** | 勝利画面には導入を含めて1:53:21と表示 |
| 統合版の先行検証、2回 | **1:49:38** | 65分でローカルサーバーへ継ぎ、1:49:47に着荷。173件のイベント時刻が2回とも一致 |

表はゲーム内時間です。先行版の画面付き通し試走では発射と勝利画面を確認し、その後の画面あり再検証では蒸気発電後のカメラ切り替えまでを確認しました。 [配布版の検証](reference/package_verification.json) · [先行試走](reference/confirmed_runs.json)

プレイヤー作成前のマップから始めます。Luaが移動、施工、研究キュー、設備間のアイテム・流体の集配を操作し、Factorio本体が採掘、製造、発電、研究、発射を進めます。Codexと組んだ工程を実行するMOD自動運転として計時しています。

## 試走環境

| 項目 | 構成 |
| --- | --- |
| PC | Intel Core i5-12450H（8コア・12スレッド）、メモリ16 GB、NVMe SSD 約512 GB |
| 画面描画 | GeForce RTX 3050 Ti Laptop GPU（専用VRAM 約4 GB、Direct3D 11）。Intel UHD Graphicsも搭載 |
| OS | Windows 11 Home 64ビット（ビルド26200） |
| Factorio | Steam版 2.1.25（ビルド88022）、基本ゲーム、Space Age無効。公開版の初期セーブは2.1.25でローカル生成 |
| 自動運転 | `first-rocket-route-check` 0.1.0、ランチャーはPython 3.12.16で確認 |

開発では **ChatGPT CodexのGPT-6.2 Sol** を使用しました。利用者の説明では、試走の調整中は推論設定の**超高（`xhigh`）とMax（`max`）**を行き来し、最終段階は **Max** です。Codexが工程設計・実装・試走分析を担当し、再現時のゲーム操作はローカルのLua MODが進めます。

画面ありは最大12倍に設定し、発射は等速です。ローカル生成したマップでの画面なし検証は、上記PCでFactorioのテスト起動から完了まで現実時間で **約7分7秒**。先行の検証とも発射と着荷のティックが一致しました。 [試走環境](reference/run_environment.json) · [配布版の検証と再点検](reference/package_verification.json)

## 資料

- [開発の時系列](docs/ja/DEVELOPMENT_HISTORY.md) · 初期の試走、人力RTAから採った手法、ユーザーの指摘、増産と待機短縮の結果を追えます。
- [AI操作手順](docs/ja/AI_OPERATIONS.md) · 依頼の読み方、実行・監視、詰まりの切り分け、成功判定をまとめています。
- [使用ツールと開発時の週間利用枠](docs/ja/METHOD_AND_TOOLS.md#開発検証で使ったもの) · 専用MOD、Computer Use、初期のFactorio LLM Useの役割と、Pro 100での残量表示の概算を確認できます。
- [取得候補の実績](docs/ja/METHOD_AND_TOOLS.md#取得候補の実績) · 打ち上げ、時間制限、設備制限などの条件と、Steamで取得する場合の設定です。
- [公開準備](docs/ja/PUBLISHING.md) · 配布するファイルと実測の表記、ライセンスと開始セーブの扱いを確認できます。

## ライセンスと再配布

このプロジェクトで作成したコード、文書、設計データにはMITライセンスを適用します。再配布する場合は著作権表示と許諾文を残してください。Factorioのゲーム本体と素材の権利はWube Software Ltd.に帰属します。 [MITライセンス](LICENSE) · [Factorioの利用規約](https://www.factorio.com/terms-of-service#intellectual-property-rights-and-sharing)

**再配布・改良版を公開する際は、記録の更新をお願いします。** タイムを計測した場合は、発射までのゲーム内時間、Factorioのバージョン、シード、実行モード、主な変更点を添えてください。1時間50分18秒を縮めた結果も歓迎します。

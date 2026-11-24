# GitHub公開準備

[人間向けREADME](../../README.ja.md) · [AI操作手順](AI_OPERATIONS.md) · [English](../en/PUBLISHING.md) · [简体中文](../zh-Hans/PUBLISHING.md)

## 公開設定

| 項目 | 内容 |
| --- | --- |
| 題名 | AIにファクトリオを2時間以内にクリアしてもらう方法 |
| 公開名義 | Factory Launch Project |
| GitHubリポジトリ名 | `factorio-ai-under-two-hours` |
| ライセンス | [MIT](../../LICENSE)（自作コード、文書、設計データ） |

## GitHubの概要欄

> Factorio 2.1.25の基本ゲームで、ゲーム内1時間50分18秒で衛星を打ち上げる自動化ルート。ChatGPTがほぼすべての仕事を行いました。

## リリースの紹介文

> 固定シード4263722700の新規マップから衛星を打ち上げる、Factorio 2.1.25のLua MODとWindows用の再現手順です。ChatGPTがほぼすべての仕事を行い、ユーザーが目標設定、RTA資料の提供、改善案の提案と最終確認に参加しました。画面なしの通し試走はゲーム内1時間50分18秒で発射し、宇宙サイエンス1,000個の着荷まで確認しました。再配布・改良版を公開する際は、記録の更新をお願いします。

## リポジトリに含めるもの

| 対象 | 内容 |
| --- | --- |
| `README*.md`、`AGENTS.md`、`docs/` | 人間とAIの入口、開発経緯、公開の準備。日本語・英語・簡体字中国語のどれからも手順と根拠をたどれるようにする。 |
| `run_route.py`、`mod/`、`manifest.json` | 検証済みのランチャー、自作Lua、配置と研究順、実行条件とSHA-256。WindowsでGitが読み書きしても検証対象のバイト列を維持する設定を含む。 |
| `world/` | マップ生成設定。Factorio 2.1.25がこの設定からプレイヤー作成前のフリープレイセーブを試走用フォルダに生成する。 |
| `reference/` | 公開用に抜き出したイベントと検証条件。先行試走、配布版の通し、配布版の画面起動試験の範囲が分かる。 |

公開用ZIPには整理済みのソースと資料を収録する。Factorio本体とシナリオの素材は利用者のインストール済み環境から読み込む。実行で作る `runs/`、生ログ、個別のゲーム設定とセーブはローカルに保存する。参照したRTAには開発史からリンクする。 [Factorioの利用規約](https://www.factorio.com/terms-of-service#intellectual-property-rights-and-sharing)

## 公開名義とメールの扱い

リポジトリのURLには所有者のユーザー名または組織名が表示される。GitHubで公開する場合は、公に表示してよい名義の名前空間を使う。公開用ZIPは履歴を持たないソースアーカイブ。公開コミットにはGitHubが発行する `noreply` アドレスをリポジトリ単位で設定し、作成者・コミッター双方のメールを確認する。アカウントのメール非公開設定と、個人メールアドレスを露出するプッシュのブロックも使える。 [コミット用メールの設定](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address) · [個人メールを含むプッシュのブロック](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/blocking-command-line-pushes-that-expose-your-personal-email-address)

## 再配布と記録の更新

MITで再配布する場合は、著作権表示と許諾文を残す。改良版の公開時には、記録の更新を協力事項としてお願いする。タイムを測ったらゲーム内の発射時間、Factorioの版、シード、実行モード、主な変更点を添える。公開時の比較基準は画面なしの `1:50:18`。先行の画面あり実演は `1:52:59`。 [ライセンス](../../LICENSE) · [実測記録](../../reference/package_verification.json)

リリース用ZIPは新しいフォルダに展開して `check` を実行し、ゲーム版と配布ファイルのハッシュを照合する。リリースごとに検証に使ったタグかコミットを記録する。不具合報告には版・モード、`check` と `report` の結果、症状が始まった工程・ティック、個人情報を除いたログの抜粋があれば再検証しやすい。 [GitHub Releasesの案内](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)

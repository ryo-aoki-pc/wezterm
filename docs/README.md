# WezTerm 文書案内

[リポジトリの概要](../README.md) / [機能早見表](../README.md#機能早見表)

## 初めて使う

1. WezTerm 本体の nightly と Git を入れる。AlmaLinux 10 / Windows 11 の本体導入は setup-notes の [WezTerm Nightly](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/wezterm-nightly.md)を参照する
1. [設定の導入手順](install.md)で、このリポジトリの設定とシェル統合を導入する
1. [操作ガイド](usage.md)でキー・マウス・起動メニューを調べる

## 操作と保守

| 目的 | 文書 |
| --- | --- |
| タブ・ペイン・ワークスペースを操作する | [キーとマウス](usage.md#キーバインド)、[機能の詳細](usage.md#機能の詳細) |
| 出力をコピーする・長いコマンドの終了を知る | [出力とスクロールバック](usage.md#出力とスクロールバック)、[完了通知](usage.md#長いコマンドの完了通知) |
| シェル・WSL・ssh 接続先を選んで開く | [シェルと起動メニュー](usage.md#シェルと起動メニュー) |
| WSL / ssh 先でもシェル統合を使う | 導入手順の [WSL](install.md#wsl-でもシェル統合を使う任意) / [ssh](install.md#ssh-先でもシェル統合を使う任意)の任意節 |
| 設定を更新する・導入前へ戻す | 導入手順の [更新](install.md#更新) / [ロールバック](install.md#ロールバック) |
| 設定が読まれない・通知やコピーが動かない | [動作確認と対処](troubleshooting.md) |
| 見た目・キー・設定値を変える | [カスタマイズの勘所](reference/configuration.md#カスタマイズの勘所)、[ファイル構成](reference/configuration.md#ファイル構成) |

## 仕様・理由・検証

| 目的 | 文書 |
| --- | --- |
| OSC とシェルごとの対応・公式統合との共存を調べる | [シェル統合の仕様](reference/shell-integration.md) |
| 配置先と読み込み順の理由を調べる | [導入の参照情報](reference/install.md) |
| nightly が必要な機能・見送った設定を調べる | [設定参照](reference/configuration.md) |
| 実施環境・対象版・結果・未確認事項を調べる | [導入と動作の検証記録](verification/install.md)、[旧 README の検証記録](verification/readme.md) |
| Starship / SSH の検証を再実行する | [検証用スクリプトの案内](../tests/starship/README.md) |
| 文書・コードを変更するときの決まりを調べる | [CLAUDE.md](../CLAUDE.md) |

操作と必要な前提は手順書・操作ガイドに、仕組みと選定理由は `reference/` に、実施済みの結果は `verification/` に置きます。設定の導入コマンドは [install.md](install.md) を使用してください。

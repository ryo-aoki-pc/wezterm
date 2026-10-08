# wezterm

[WezTerm](https://wezterm.org/) の個人設定です。Tokyo Night 系の配色に、ピル型タブ・
ステータスバー・シェル選択ランチャーを組み合わせ、シェル統合でカレントディレクトリ・
プロンプト・コマンド出力の位置を WezTerm に伝えて操作を便利にしています。

Windows 11（既定シェルは Git Bash）を主に、Linux（GNOME Wayland）と macOS でも同じ設定が
動くように書いてあります。

## 必須要件

| | |
| --- | --- |
| WezTerm | **nightly 必須**（stable では未知オプションで設定エラーになります） |
| フォント | [HackGen Console NF](https://github.com/yuru7/HackGen)（日本語 + Nerd Font + Powerline） |

フォントが未導入でも `wezterm.font_with_fallback` により
`Symbols Nerd Font Mono` / `Noto Sans Mono CJK JP` へフォールバックしますが、
見た目を揃えるには HackGen Console NF の導入を推奨します。

導入の手順（前提の入れ方を含む）は [docs/install.md](docs/install.md) にあります。

## 配置と初回セットアップ

| OS | 配置先 |
| --- | --- |
| Linux / macOS | `~/.config/wezterm` |
| Windows | `%USERPROFILE%\.config\wezterm` |

導入は [docs/install.md](docs/install.md) の手順で行います（setup-notes と同じ書式の手順書）。
AlmaLinux 10 と Windows 11 の Git Bash に同じコマンドを貼り、次のことをします。

- 既にある設定（`~/.wezterm.lua`・`~/.config/wezterm`）を `.bak` に退避する
- このリポジトリを `~/.config/wezterm` に clone する
- bash のシェル統合を読み込む（→ [シェル統合](docs/reference/shell-integration.md#シェル統合)。共通の bash 設定を入れたホストでは追記不要。PowerShell は自動で読み込まれる）
- 任意で、WSL と ssh 先でもシェル統合を使えるようにする

設定ファイルは保存すると自動で再読み込みされます（手動なら `Ctrl+Shift+R`）。
ただしウィンドウ装飾（`window_decorations`）の変更だけは WezTerm の再起動が必要です。

導入の後に、必要ならやること:

- **SSH 接続先**: `~/.ssh/config` に `Host` を書いておくと、起動メニューに
  「ssh ホスト名」が並ぶ（→ [SSH ホスト](docs/usage.md#ssh-ホスト)）
- **通知の許可**: 完了通知を使うなら、OS の通知設定で WezTerm を許可しておく

## 機能早見表

| 分類 | 機能 | 操作 | 詳細 |
| --- | --- | --- | --- |
| 外観 | Tokyo Night 配色・半透明・IME 変換中のカーソル色・低コントラスト補正 | 自動 | [外観](docs/usage.md#外観) |
| タブ | ピル型タブ（番号・実行中のプログラムのアイコン・ズーム・進捗・未読） | 自動 | [タブバー](docs/usage.md#タブバー) |
| タブ | タブ名を今のディレクトリ名 / ssh の接続先にする | 自動 | [タブ名の決まり方](docs/usage.md#タブ名の決まり方) |
| タブ | タブ名を手で付ける | `Ctrl+Shift+Alt+T` | [タブバー](docs/usage.md#タブバー) |
| ステータス | モード表示（リサイズ / コピー / 検索）・一時メッセージ・日時・電池 | 自動 | [ステータスバー](docs/usage.md#ステータスバー) |
| ペイン | 分割・シェルを選んで分割・移動・ラベルで選択・入れ替え・回転・リサイズ | `Ctrl+Shift+D/E` ほか | [ペイン操作](docs/usage.md#ペイン操作) |
| ペイン | ペインを新しいタブ / ウィンドウへ移す | コマンドパレット | [ペイン操作](docs/usage.md#ペイン操作) |
| ワークスペース | 作成・切替・前後移動・名前変更 | `Ctrl+Shift+Alt+N/W/H/L` | [ワークスペース](docs/usage.md#ワークスペース) |
| 出力 | 前後のプロンプトへジャンプ | `Ctrl+Shift+Alt+↑/↓` | [出力とスクロールバック](docs/usage.md#出力とスクロールバック) |
| 出力 | 直前のコマンドの出力をコピー | `Ctrl+Shift+Alt+C` | [直前の出力をコピー](docs/usage.md#直前の出力をコピー) |
| 出力 | スクロールバックをエディタで開く | `Ctrl+Shift+Alt+O` | [スクロールバックをエディタで開く](docs/usage.md#スクロールバックをエディタで開く) |
| 出力 | 長いコマンドが終わったら通知 | 自動 | [長いコマンドの完了通知](docs/usage.md#長いコマンドの完了通知) |
| 選択 | 画面上のハッシュ・パス・URL をキーで選んでコピー / 貼り付け | `Ctrl+Shift+Space` | [QuickSelect とリンク](docs/usage.md#quickselect-とリンク) |
| 選択 | 画面上の URL をキーで選んで開く | `Ctrl+Shift+O` | [URL を開く](docs/usage.md#url-を開く) |
| 入力 | 手元の OS のクリップボードから貼り付け（SSH 先の Neovim 内でも） | 右クリック | [マウス](docs/usage.md#マウス) |
| 起動 | シェル・WSL・SSH 接続先の起動メニュー | `Ctrl+Shift+M` | [シェルと起動メニュー](docs/usage.md#シェルと起動メニュー) |
| その他 | 独自操作を名前で探して実行 | `Ctrl+Shift+P` | [コマンドパレット](docs/usage.md#コマンドパレット) |
| その他 | Ctrl+ホイールで文字の拡大 / 縮小 | マウス | [外観](docs/usage.md#外観) |

## 文書索引

文書を目的から探す場合は [docs/README.md](docs/README.md) を参照してください。

| 文書 | 内容 |
| --- | --- |
| [設定を導入する](docs/install.md) | 導入・WSL / ssh の任意設定・更新・ロールバック |
| [操作ガイド](docs/usage.md) | キーとマウス・タブ・ペイン・ワークスペース・通知・起動メニュー |
| [動作確認と対処](docs/troubleshooting.md) | 設定の読み込みと構文の確認・症状別の確認先 |
| [シェル統合の仕様](docs/reference/shell-integration.md) | OSC・シェルごとの対応・Starship と公式統合との共存 |
| [設定参照](docs/reference/configuration.md) | カスタマイズ・ファイル構成・nightly 限定機能・見送った設定 |
| [導入の参照情報](docs/reference/install.md) | 配置・読み込み順・導入方針の理由 |
| [導入と動作の検証記録](docs/verification/install.md) | 実施した環境・対象版・結果・未確認事項 |
| [旧 README の検証記録](docs/verification/readme.md) | 旧 README から移した実機の記録 |

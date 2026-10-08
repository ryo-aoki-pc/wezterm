# WezTerm の設定参照

[文書案内](../README.md) / [操作ガイド](../usage.md) / [動作確認と対処](../troubleshooting.md)

## 目次

- [カスタマイズの勘所](#カスタマイズの勘所)
- [ファイル構成](#ファイル構成)
- [使用している nightly 限定機能](#使用している-nightly-限定機能)
- [検討して見送った設定](#検討して見送った設定)

## カスタマイズの勘所

よく変えそうな値と場所です。

| 変えたいもの | ファイル | 設定 |
| --- | --- | --- |
| フォントの候補 | `lua/ui.lua` | `font_family` |
| 文字の大きさ | `lua/general.lua` / `lua/tabs.lua` | `font_size`（本文）/ `window_frame.font_size`（タブバー） |
| 配色 | `lua/colors.lua` | `palette` |
| 透明度・ぼかし | `lua/window.lua` | `window_background_opacity` / `win32_system_backdrop` / `macos_window_background_blur` |
| 余白 | `lua/window.lua` | `window_padding` |
| カーソルの形 | `lua/window.lua` | `default_cursor_style` |
| スクロールバックの行数 | `lua/general.lua` | `scrollback_lines` |
| タブ名の最大文字数 | `lua/tabs.lua` | `wezterm.truncate_right(title, 24)` |
| プログラムのアイコン | `lua/tabs.lua` | `PROCESS_ICONS` |
| ステータスバーの項目 | `lua/statusbar.lua` | `render()` |
| 一時メッセージの表示秒数 | `lua/statusbar.lua` | `FLASH_SECONDS` |
| QuickSelect の追加パターン | `lua/general.lua` | `quick_select_patterns` |
| 「URL を開く」のパターン | `lua/actions.lua` | `URL_PATTERN` |
| 完了通知のしきい値 | 環境変数 | `WEZTERM_NOTIFY_AFTER`（[完了通知](../usage.md#長いコマンドの完了通知)） |
| 完了通知の文面・条件 | `lua/notify.lua` | `user-var-changed` ハンドラ |
| 起動メニューのシェル | `lua/shells.lua` | `discover()` の `candidates` |
| SSH の一覧から外すホスト | `lua/shells.lua` | `SSH_SKIP_HOSTS` |
| ssh 中とみなすプログラム | `lua/procs.lua` | `REMOTE` |
| コマンド行で読み飛ばす前置き（`sudo` など） | `lua/procs.lua` | `PREFIXES` |
| キー / マウス | `lua/bindings.lua` | `config.keys` / `config.mouse_bindings` |
| コマンドパレットの独自項目 | `lua/palette.lua` | `ENTRIES` |

キーを足すときは WezTerm の既定の割り当てと重ならないか `wezterm show-keys` で確かめてください
（[動作確認](../troubleshooting.md#動作確認)）。

## ファイル構成

`wezterm.lua` が `lua/` 配下の各モジュールの `apply(config)` を順に呼び出します。

| ファイル | 役割 |
| --- | --- |
| `wezterm.lua` | エントリポイント。`package.path` を通して各モジュールを適用 |
| `lua/general.lua` | フォント・スクロールバック・視覚ベル・QuickSelect など全般 |
| `lua/colors.lua` | パレット定義と `config.colors`・コマンドパレットの配色（他モジュールからも参照） |
| `lua/window.lua` | ウィンドウ装飾・余白・半透明 / Acrylic・カーソル |
| `lua/tabs.lua` | ファンシータブバーとピル型タブ（アイコン・タブ名・進捗・未読） |
| `lua/statusbar.lua` | 右上のステータス（一時メッセージ・モード・ワークスペース・日時・電池）。`flash()` を公開 |
| `lua/shells.lua` | シェル・SSH ホストの探索と `launch_menu` / `default_prog` / WSL ドメイン |
| `lua/bindings.lua` | キーバインドとマウスバインド |
| `lua/actions.lua` | キーとコマンドパレットの両方から使う操作（出力コピー・URL を開く など）。`apply` は持たない |
| `lua/palette.lua` | コマンドパレットの独自項目 |
| `lua/notify.lua` | 長いコマンドの完了通知 |
| `lua/ui.lua` | 共有定数（パワーライン区切り・フォント候補）。`apply` は持たない |
| `lua/procs.lua` | 実行中のプログラムの判定（ssh 中か・タブのアイコン。`WEZTERM_PROG` も使う）。`apply` は持たない |
| `shell/wezterm.sh` | シェル統合（bash / zsh）。OSC 7 / OSC 133 / 完了通知 / 実行中のコマンド（`WEZTERM_PROG`）/ 迷子のマウス報告よけ |
| `shell/wezterm.ps1` | シェル統合（PowerShell）。OSC 7 / OSC 133 / 完了通知 |
| `docs/install.md` | 導入の手順書（操作・前提・期待結果） |
| `docs/README.md` | 目的別の文書索引 |
| `docs/usage.md` | 機能とキー・マウス操作 |
| `docs/troubleshooting.md` | 動作確認と症状別の対処 |
| `docs/reference/shell-integration.md` | シェル統合の仕様と対応範囲 |
| `docs/reference/configuration.md` | カスタマイズ・ファイル構成・nightly 限定機能・見送った設定 |
| `docs/verification/install.md` | 導入・GUI・シェル統合の検証記録 |
| `docs/verification/readme.md` | 旧 README から移した実機の記録 |
| `docs/reference/install.md` | 導入の選定理由と技術的説明 |
| `CLAUDE.md` | Claude Code 向けの、このリポジトリの構成と書き方の決まり |

## 使用している nightly 限定機能

stable ではこれらが未知オプションとして設定エラーになります。

| 機能 | 使用箇所 |
| --- | --- |
| `text_min_contrast_ratio` | `lua/general.lua` — 低コントラストな文字色を自動補正 |
| `quick_select_remove_styling` | `lua/general.lua` — QuickSelect 中の装飾を外す |
| `window_content_alignment` | `lua/window.lua` — 端数余白を上下左右へ均等配分 |
| `show_close_tab_button_in_tabs` | `lua/tabs.lua` — タブ内の × ボタンを非表示 |
| `PaneInformation.progress` | `lua/tabs.lua` — OSC 9;4 の進捗をタブに表示 |
| `input_selector_label_*` / `launcher_label_*` | `lua/colors.lua` — 選択 UI のラベル配色 |
| `PromptInputLine` の `prompt` / `initial_value` | `lua/actions.lua` — タブ名・ワークスペース名の入力 |

## 検討して見送った設定

過去に提案され、理由があって入れていないものです。同じ案を検討するときの参考に残します。

| 案 | 理由 |
| --- | --- |
| タブを閉じたら直前のタブへ戻る（`switch_to_last_active_tab_when_closing_tab`） | 見送り（標準の「左隣へ移る」のまま） |
| 背景の透過 ⇔ 不透明の切替 | 見送り |
| 検索を大文字小文字を区別しない / スマートケースにする | 見送り。検索中に `Ctrl+R` で切り替えられる |
| `Alt+1`〜`9` でタブ切替 | readline の `Alt+数字`（数引数）や tmux でよく使う `M-1`〜`9` を横取りしてしまう。標準の `Ctrl+Shift+1`〜`9` がある |
| `http://` の無い `localhost:3000` をリンクにする | 開発サーバの多くは `http://` 付きで表示するため出番が少ない。QuickSelect では既に拾える |
| QuickSelect に `IP:ポート`・`localhost:ポート` を追加 | 既存の `ファイル:行` のパターンが既に拾う |
| QuickSelect に semver・UNC パス、`owner/repo` のリンク化 | 出番が少なく、誤検出が増える |
| `check_for_updates = false` | nightly は stable より新しい版として扱われ、更新通知が出ないため効果がない |
| 直前のタブに ↩ の目印 | タブの情報量が既に多く、タイトルの幅を削る |
| `Ctrl+Shift+Alt+←/→` でタブ移動 | 標準の `Ctrl+Shift+PageUp` / `PageDown` と重複し、標準のペイン幅調整を潰す |
| 描画を OpenGL に固定・`use_ime = false` | 原因だった IME 切替時のクラッシュは nightly で修正済み |
| 東アジアの曖昧幅の文字を全角扱い | 多くの TUI の桁揃えが崩れる |
| プロジェクトのディレクトリからワークスペースを作る（zoxide 連携） | 外部ツールへの依存を増やさないため見送り |
| セッションの保存・復元（resurrect.wezterm） | プラグインへの依存を増やさないため見送り |
| アクティブなタブの名前を太字・斜体にする | ファンシータブバーはタブバー全体を 1 つのフォントで描き、太字・斜体の指定を無視する |
| マウスを乗せたタブに面を付ける | `format-tab-title` に渡る `hover` はレトロタブバーの桁で判定されていて、ファンシータブバーのタブの位置とずれる（WezTerm の `tabbar.rs`）。ピクセル単位で判定される `inactive_tab_hover` の面はタブの箱（上だけ角丸）の形になり、ピルと揃わない。文字を明るくするだけにした |
| ステータスの知らせを面で塗ったピルにする | ステータスは帯の高さいっぱい（1.75 行）で描かれるので、面が上下いっぱいに広がり、端の半円も縦長になってタブのピルと揃わない |
| 閉じるボタンのホバーを配色の赤にする | WezTerm が純色の赤に固定していて変えられない |
| 検索のほかの一致を控えめな色にする | 今の一致は WezTerm が選択範囲にするので、選択範囲の色（紺）で描かれる。ほかの一致を控えめにすると、今の一致の方が目立たなくなる |

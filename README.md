# wezterm

[WezTerm](https://wezterm.org/) の個人設定。Tokyo Night 系の配色に、ピル型タブ・
ステータスバー・シェル選択ランチャーを組み合わせた構成です。

## 必須要件

| | |
| --- | --- |
| WezTerm | **nightly 必須**（stable では未知オプションで設定エラーになります） |
| フォント | [HackGen Console NF](https://github.com/yuru7/HackGen)（日本語 + Nerd Font + Powerline） |

フォントが未導入でも `wezterm.font_with_fallback` により
`Symbols Nerd Font Mono` / `Noto Sans Mono CJK JP` へフォールバックしますが、
見た目を揃えるには HackGen Console NF の導入を推奨します。

## 配置

| OS | 配置先 |
| --- | --- |
| Linux / macOS | `~/.config/wezterm` |
| Windows | `%USERPROFILE%\.config\wezterm` |

```sh
git clone <this-repo> ~/.config/wezterm
```

## ファイル構成

`wezterm.lua` が `lua/` 配下の各モジュールの `apply(config)` を順に呼び出します。

| ファイル | 役割 |
| --- | --- |
| `wezterm.lua` | エントリポイント。`package.path` を通して各モジュールを適用 |
| `lua/general.lua` | フォント・スクロールバック・視覚ベルなど全般 |
| `lua/colors.lua` | パレット定義と `config.colors`（他モジュールからも参照） |
| `lua/window.lua` | ウィンドウ装飾・余白・半透明 / Acrylic・カーソル |
| `lua/tabs.lua` | ファンシータブバーとピル型タブ（プロセスアイコン・進捗表示） |
| `lua/statusbar.lua` | 右下ステータス（ワークスペース・日付・時刻・バッテリー） |
| `lua/shells.lua` | シェル探索と `launch_menu` / `default_prog` / WSL ドメイン |
| `lua/bindings.lua` | キーバインドとマウスバインド |
| `lua/ui.lua` | 共有定数（パワーライン区切り・フォント候補）。`apply` は持たない |

## キーバインド

### カスタム

| キー | 動作 |
| --- | --- |
| `Ctrl+Shift+D` / `E` | ペインを左右 / 上下に分割 |
| `Ctrl+Shift+Alt+D` / `E` | シェルを選んで左右 / 上下に分割 |
| `Ctrl+Shift+H/J/K/L` | ペイン移動（左/下/上/右, vim 風） |
| `Ctrl+Shift+Q` | ペインを閉じる（確認あり） |
| `Ctrl+Shift+M` | 起動メニュー（Git Bash / PowerShell / MSYS2 / WSL / ワークスペース） |
| `Ctrl+Shift+Alt+T` | タブ名を変更（空欄で確定するとデフォルト名に戻る） |
| `Ctrl+Shift+Alt+W` | ワークスペースを選んで切替 |
| `Ctrl+Shift+Alt+N` | ワークスペースを作成 / 既存へ移動 |
| `Ctrl+Shift+Alt+H` / `L` | 前 / 次のワークスペースへ |
| `Ctrl+Shift+S` | リサイズモード（`h/j/k/l` または矢印で調整、`Esc`/`Enter` で終了、2 秒で自動終了） |
| 右クリック | クリップボードから貼り付け |

### 主要デフォルト（WezTerm 標準。この設定でも有効）

| キー | 動作 |
| --- | --- |
| `Ctrl+Shift+C` / `V` | コピー / 貼り付け |
| `Ctrl+Shift+F` | 検索 |
| `Ctrl+Shift+X` | コピーモード（vim 風カーソル選択） |
| `Ctrl+Shift+Z` | ペインのズーム切替（タブの虫眼鏡アイコンがこの状態を示す） |
| `Ctrl+Shift+矢印` | ペイン移動（`Ctrl+Shift+H/J/K/L` と同じ） |
| `Ctrl+Shift+Space` | QuickSelect（URL 等を素早く選択） |
| `Ctrl+Shift+P` | コマンドパレット |
| `Ctrl+Shift+U` | 文字（絵文字）選択 |
| `Ctrl+Shift+R` | 設定リロード |
| `Ctrl+Shift+N` / `T` / `W` | 新しいウィンドウ / 新しいタブ / タブを閉じる |
| `Ctrl+Shift+1`〜`9` | 指定番号のタブへ切替 |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | 次 / 前のタブ |
| `Ctrl+Shift+PageUp` / `PageDown` | タブを左 / 右へ移動 |
| `Ctrl` + `+` / `-` / `0` | フォント拡大 / 縮小 / リセット |
| `Alt+Enter` | フルスクリーン切替 |
| 左クリック | 選択をコピー（リンク上なら URL を開く） |

標準の `Ctrl+Shift+K`(ClearScrollback) / `Ctrl+Shift+L`(ShowDebugOverlay) は
上記のペイン移動へ再割当のため無効です。

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
| `PromptInputLine` の `prompt` / `initial_value` | `lua/bindings.lua` — タブ名・ワークスペース名の入力 |

## 動作確認

設定を反映せずに読み込みだけ検証できます。

```sh
# キー割り当てのダンプ（設定エラーがあればここで出る）
wezterm --config-file "$PWD/wezterm.lua" show-keys

# フォントがどのファイルで解決されるか確認
wezterm --config-file "$PWD/wezterm.lua" ls-fonts --text 'あ'
```

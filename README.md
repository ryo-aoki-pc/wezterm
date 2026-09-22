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

## ウィンドウのタイトルバー

タイトルバーは出さず、`window_decorations = "INTEGRATED_BUTTONS|RESIZE"` で
タブバーの右端に 最小化 / 最大化 / 閉じる を並べます（Windows と Linux の Wayland）。
端末の表示領域が縦に一段広がり、マウス操作は残ります。

- 移動: タブバーの空き（タブや ＋ の無い帯）を左ドラッグ ※Wayland を除く
- リサイズ: ウィンドウの縁をドラッグ ※Wayland を除く
- 最大化/元に戻す: タブバーの空き帯をダブルクリック

macOS と Linux の X11 はネイティブのタイトルバーが問題なく出るため
`"TITLE|RESIZE"` のままです。

ボタンはファンシータブバーの一部として描かれるので、`use_fancy_tab_bar = true` と
`hide_tab_bar_if_only_one_tab = false`（どちらも `lua/tabs.lua`）を変えないでください。
タブバーを消すとボタンとドラッグ用の帯ごと消えます。

### Wayland の事情

GNOME (mutter) は xdg-decoration に対応しておらず、WezTerm はサーバー側装飾が無いと
フレームを描きません。タブバーのドラッグ移動も Wayland では未実装のため、
マウス操作の取っかかりが無くなります。WezTerm 自前のタイトルバー（`"TITLE"`）は
最大化・タイル時に本文をモニタ全面と同じ大きさにしたうえでフレームを外側に足すため、
ウィンドウが画面より一回り大きくなり**下端と右端が見切れる**ので使いません。

移動は `Win`+左ドラッグ、リサイズは `Win`+中ドラッグ（GNOME 標準。キーボードなら
`Alt+F7` / `Alt+F8`）。

素のドラッグでは移動できません。WezTerm の Wayland バックエンドには
`start_window_drag` の実装が無く（`window/src/os/wayland/window.rs` の `WindowOps`）、
`StartWindowDrag` を好きなマウスバインドに割り当てても無効だからです。既定の
`Win`+ドラッグ / `Ctrl+Shift`+ドラッグも Wayland では効きません。

GNOME 純正のタイトルバーでドラッグ移動したい場合は `enable_wayland = false`（XWayland）
にしてください。最大化サイズも正しくなりますが、X11 描画になるため分数スケールの
ディスプレイでは文字がにじみます。

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
| `shell/wezterm.sh` | シェル統合（bash / zsh）。OSC 7 / OSC 133 を送る / 迷子のマウス報告よけ |
| `shell/wezterm.ps1` | シェル統合（PowerShell）。同上 |

## キーバインド

### カスタム

| キー | 動作 |
| --- | --- |
| `Ctrl+Shift+D` / `E` | ペインを左右 / 上下に分割 |
| `Ctrl+Shift+Alt+D` / `E` | シェルを選んで左右 / 上下に分割 |
| `Ctrl+Shift+H/J/K/L` | ペイン移動（左/下/上/右, vim 風） |
| `Ctrl+Shift+Q` | ペインを閉じる（確認あり） |
| `Ctrl+Shift+Alt+P` | ペインをラベルで選んで移動（3 ペイン以上で便利） |
| `Ctrl+Shift+Alt+S` | ペインをラベルで選んで現在のペインと入れ替え |
| `Ctrl+Shift+Alt+R` | ペインの中身を時計回りに回す（レイアウトは変えない） |
| `Ctrl+Shift+Alt+B` | 直前に見ていたタブへ戻る |
| `Ctrl+Shift+Alt+K` | スクロールバックと画面を消去 |
| `Ctrl+Shift+Alt+↑` / `↓` | 前 / 次のプロンプトへスクロール（[シェル統合](#シェル統合)が必要） |
| `Ctrl+Shift+M` | 起動メニュー（Git Bash / PowerShell / コマンドプロンプト / MSYS2 / WSL / ワークスペース） |
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
上記のペイン移動へ再割当のため無効です。ClearScrollback は `Ctrl+Shift+Alt+K` で
使えます。ShowDebugOverlay はコマンドパレット（`Ctrl+Shift+P`）から開けます。

## シェル統合

`shell/wezterm.sh` / `shell/wezterm.ps1` がシェルから端末へ次の 2 つを通知します。

| 通知 | 得られる動作 |
| --- | --- |
| OSC 7（カレントディレクトリ） | 新しいタブ・分割ペインが「今いるディレクトリ」で開く / タブ名がディレクトリ名になる |
| OSC 133（プロンプト位置） | `Ctrl+Shift+Alt+↑` / `↓` で前後のプロンプトへジャンプできる |

WezTerm 以外の端末で読み込まれた場合、この 2 つは何もしません（`$TERM_PROGRAM` で判定）。
次の「迷子のマウス報告よけ」だけは判定より手前にあり、端末を問わず働きます。

Linux 版 WezTerm のパッケージは公式のシェル統合を `/etc/profile.d/wezterm.sh` に置きます。
それが読み込まれている環境では OSC 7 / OSC 133 は公式側に任せ、`shell/wezterm.sh` は
マウス報告よけだけを残して抜けます（同名の `__wezterm_osc7` を上書きして公式側のフックを
壊さないため）。

### 迷子のマウス報告よけ

lazygit や yazi のような TUI は起動時にマウス報告（DECSET 1003 = 移動も含む全イベント /
1006 = SGR 形式）を有効にし、終了時に解除します。ところが解除が端末へ届く前に端末が
出してしまった報告は行き場を失い、戻ってきたシェルにこう現れます。

```
[almalinux@abiko-pi setup-notes]$ lazygit
^[[<35;33;72M[almalinux@abiko-pi setup-notes]$
```

届くタイミングで見え方が変わります。プロンプト表示前なら端末がそのまま echo するだけ
（表示が汚れる）ですが、readline の起動後に届くと `35: command not found` のように
コマンド行が壊れます。WezTerm 固有の問題ではなく、tmux や ssh を挟んでも起きます。

`shell/wezterm.sh` は対策を 2 つ入れています。

- プロンプトごとにマウス報告を解除する（解除され損ねて残っている場合の回復）
- readline に `\e[<` を食わせ、終端の `M` / `m` まで読み捨てる（コマンド行への混入防止）

ただしプロンプト表示前に届いた分の echo までは消せません。lazygit については
`~/.config/lazygit/config.yml` に次を書き、発生源ごと止めるのが確実です
（代わりに lazygit 内でマウスが使えなくなります）。

```yaml
gui:
  mouseEvents: false
```

手で復旧したいときは `printf '\033[?1003l\033[?1006l'` を実行します。

### PowerShell

追加の設定は不要です。`lua/shells.lua` が起動引数で自動的に読み込みます
（`-Command` はプロファイルを抑止しないため、既存のプロファイルはそのまま動きます）。

`shell/wezterm.ps1` は **UTF-8 BOM 付き**で保存してください。Windows PowerShell 5.1 は
BOM の無い `.ps1` を ANSI として読むため、日本語コメントが化けて構文エラーになります。

PowerShell 7 は公式インストーラ（MSI）・scoop・Microsoft Store 版のいずれでも検出します。
Store 版は実体パス（`C:\Program Files\WindowsApps\Microsoft.PowerShell_<版>_...`）に
バージョン番号が入り、親フォルダも列挙できないため、アプリ実行エイリアス
`%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe` を使います。これは 0 バイトの
再解析ポイントで `io.open` では開けないので、`lua/shells.lua` の `exists()` は
`os.rename` による追加判定を持っています。

### コマンドプロンプト（cmd）

`Command Prompt` と `Developer Command Prompt` には**シェル統合がありません**
（cmd 向けの OSC 7 / OSC 133 スクリプトを用意していないため）。次の 2 つは効きません。

- `Ctrl+Shift+Alt+↑` / `↓` による前後のプロンプトへのジャンプ
- 新しいタブ・分割ペインが「今いるディレクトリ」で開く動作

`Developer Command Prompt` は Visual Studio の `VsDevCmd.bat` を読み込んだ状態で開くので、
`cl.exe` などのビルドツールがそのまま使えます（`Developer PowerShell` の cmd 版）。

### bash（Git Bash / MSYS2 / QMK MSYS）

`lua/shells.lua` が環境変数 `WEZTERM_SHELL_INTEGRATION` にパスを渡すので、
`~/.bashrc` に次の 1 行を追記します。

```sh
[ -r "${WEZTERM_SHELL_INTEGRATION:=$HOME/.config/wezterm/shell/wezterm.sh}" ] && . "$WEZTERM_SHELL_INTEGRATION"
```

環境変数が無いときのフォールバックを付けてあるのは、tmux や ssh を挟むとこの変数が
届かないためです（tmux サーバは起動時の環境を子プロセスへ配るので、WezTerm が渡した
変数は後から作ったペインに入りません）。パスは「[配置](#配置)」の表どおり全 OS で
`$HOME/.config/wezterm` なので、フォールバックだけでも読み込めます。

ログインシェル（`bash -i -l`）では `--rcfile` が無視されるため、この 1 行だけは
手で入れる必要があります。ホームディレクトリはシェルごとに異なる点に注意してください。

| シェル | `~/.bashrc` の場所 |
| --- | --- |
| Git Bash | `%USERPROFILE%\.bashrc` |
| MSYS2 | `C:\msys64\home\<ユーザー名>\.bashrc` |
| QMK MSYS | `C:\QMK_MSYS\home\<ユーザー名>\.bashrc` |

既存の `PS1` は置き換えず前後に印を足すだけなので、Git Bash の
`git-prompt.sh` によるブランチ表示はそのまま残ります。

### WSL

WSL ドメインは起動引数を渡せないため、WSL 側の `~/.bashrc` に直接書きます。

```sh
. /mnt/c/Users/<ユーザー名>/.config/wezterm/shell/wezterm.sh
```

### 導入しない場合

統合を入れなくても設定は問題なく動きます。タブ名は従来どおりプロセス名になり、
`Ctrl+Shift+Alt+↑` / `↓` が効かないだけです。

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
# 設定エラーの検出。エラー行が出なければ読み込めている
# （ついでにフォントがどのファイルで解決されるかも分かる）
wezterm --config-file "$PWD/wezterm.lua" ls-fonts --text 'あ'

# キー割り当てのダンプ
wezterm --config-file "$PWD/wezterm.lua" show-keys
```

**注意**: `show-keys` は設定の読み込みに失敗しても何も言わずデフォルト設定の
一覧を表示し、終了コードも 0 のままです。設定エラーの有無は上の `ls-fonts` で
確認してください（こちらは `ERROR ... runtime error:` を stderr に出します）。
`show-keys` の出力を見る場合は、自分で定義したキー（`PaneSelect` など）が
実際に載っているかどうかで読み込み成否を判断します。

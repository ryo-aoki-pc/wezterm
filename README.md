# wezterm

[WezTerm](https://wezterm.org/) の個人設定です。Tokyo Night 系の配色に、ピル型タブ・
ステータスバー・シェル選択ランチャーを組み合わせ、シェル統合でカレントディレクトリ・
プロンプト・コマンド出力の位置を WezTerm に伝えて操作を便利にしています。

Windows 11（既定シェルは Git Bash）を主に、Linux（GNOME Wayland）と macOS でも同じ設定が
動くように書いてあります。

## 目次

- [必須要件](#必須要件)
- [配置と初回セットアップ](#配置と初回セットアップ)
- [機能早見表](#機能早見表)
- [キーバインド](#キーバインド)
- [機能の詳細](#機能の詳細)
  - [外観](#外観)
  - [ウィンドウのタイトルバー](#ウィンドウのタイトルバー)
  - [タブバー](#タブバー)
  - [ステータスバー](#ステータスバー)
  - [ペイン操作](#ペイン操作)
  - [ワークスペース](#ワークスペース)
  - [出力とスクロールバック](#出力とスクロールバック)
  - [QuickSelect とリンク](#quickselect-とリンク)
  - [長いコマンドの完了通知](#長いコマンドの完了通知)
  - [シェルと起動メニュー](#シェルと起動メニュー)
  - [コマンドパレット](#コマンドパレット)
- [シェル統合](#シェル統合)
- [カスタマイズの勘所](#カスタマイズの勘所)
- [ファイル構成](#ファイル構成)
- [使用している nightly 限定機能](#使用している-nightly-限定機能)
- [動作確認](#動作確認)
- [トラブルシューティング](#トラブルシューティング)
- [検討して見送った設定](#検討して見送った設定)

## 必須要件

| | |
| --- | --- |
| WezTerm | **nightly 必須**（stable では未知オプションで設定エラーになります） |
| フォント | [HackGen Console NF](https://github.com/yuru7/HackGen)（日本語 + Nerd Font + Powerline） |

フォントが未導入でも `wezterm.font_with_fallback` により
`Symbols Nerd Font Mono` / `Noto Sans Mono CJK JP` へフォールバックしますが、
見た目を揃えるには HackGen Console NF の導入を推奨します。

## 配置と初回セットアップ

| OS | 配置先 |
| --- | --- |
| Linux / macOS | `~/.config/wezterm` |
| Windows | `%USERPROFILE%\.config\wezterm` |

```sh
git clone <this-repo> ~/.config/wezterm
```

設定ファイルは保存すると自動で再読み込みされます（手動なら `Ctrl+Shift+R`）。
ただしウィンドウ装飾（`window_decorations`）の変更だけは WezTerm の再起動が必要です。

初回にやること:

1. **フォント**: HackGen Console NF を入れる（無くても動くが、アイコンや丸いタブの端の見た目が変わる）
2. **bash / zsh のシェル統合**: `~/.bashrc`（zsh は `~/.zshrc`）に 1 行追記する。
   カレントディレクトリでの分割・タブ名・プロンプトジャンプ・出力コピー・完了通知に必要
   （→ [シェル統合](#シェル統合)）。PowerShell は自動で読み込まれるので不要
3. **SSH 接続先（任意）**: `~/.ssh/config` に `Host` を書いておくと、起動メニューに
   「ssh ホスト名」が並ぶ（→ [SSH ホスト](#ssh-ホスト)）
4. **通知の許可（任意）**: 完了通知を使うなら、OS の通知設定で WezTerm を許可しておく

## 機能早見表

| 分類 | 機能 | 操作 | 詳細 |
| --- | --- | --- | --- |
| 外観 | Tokyo Night 配色・半透明・IME 変換中のカーソル色・低コントラスト補正 | 自動 | [外観](#外観) |
| タブ | ピル型タブ（番号・実行中のプログラムのアイコン・ズーム・進捗・未読） | 自動 | [タブバー](#タブバー) |
| タブ | タブ名を今のディレクトリ名 / ssh の接続先にする | 自動 | [タブ名の決まり方](#タブ名の決まり方) |
| タブ | タブ名を手で付ける | `Ctrl+Shift+Alt+T` | [タブバー](#タブバー) |
| ステータス | モード表示（リサイズ / コピー / 検索）・一時メッセージ・日時・電池 | 自動 | [ステータスバー](#ステータスバー) |
| ペイン | 分割・シェルを選んで分割・移動・ラベルで選択・入れ替え・回転・リサイズ | `Ctrl+Shift+D/E` ほか | [ペイン操作](#ペイン操作) |
| ペイン | ペインを新しいタブ / ウィンドウへ移す | コマンドパレット | [ペイン操作](#ペイン操作) |
| ワークスペース | 作成・切替・前後移動・名前変更 | `Ctrl+Shift+Alt+N/W/H/L` | [ワークスペース](#ワークスペース) |
| 出力 | 前後のプロンプトへジャンプ | `Ctrl+Shift+Alt+↑/↓` | [出力とスクロールバック](#出力とスクロールバック) |
| 出力 | 直前のコマンドの出力をコピー | `Ctrl+Shift+Alt+C` | [直前の出力をコピー](#直前の出力をコピー) |
| 出力 | スクロールバックをエディタで開く | `Ctrl+Shift+Alt+O` | [スクロールバックをエディタで開く](#スクロールバックをエディタで開く) |
| 出力 | 長いコマンドが終わったら通知 | 自動 | [長いコマンドの完了通知](#長いコマンドの完了通知) |
| 選択 | 画面上のハッシュ・パス・URL をキーで選んでコピー / 貼り付け | `Ctrl+Shift+Space` | [QuickSelect とリンク](#quickselect-とリンク) |
| 選択 | 画面上の URL をキーで選んで開く | `Ctrl+Shift+O` | [URL を開く](#url-を開く) |
| 起動 | シェル・WSL・SSH 接続先の起動メニュー | `Ctrl+Shift+M` | [シェルと起動メニュー](#シェルと起動メニュー) |
| その他 | 独自操作を名前で探して実行 | `Ctrl+Shift+P` | [コマンドパレット](#コマンドパレット) |
| その他 | アイドル状態の Git Bash を確認なしで閉じる | `Ctrl+Shift+W/Q` | [閉じるときの確認](#閉じるときの確認) |
| その他 | Ctrl+ホイールで文字の拡大 / 縮小 | マウス | [外観](#外観) |

## キーバインド

「標準」は WezTerm の既定の割り当て（この設定でも有効）、それ以外はこの設定で追加したものです。
定義は `lua/bindings.lua`（冒頭のコメントにも同じ一覧があります）。

### ペイン

| キー | 動作 | |
| --- | --- | --- |
| `Ctrl+Shift+D` / `E` | 左右 / 上下に分割（今と同じシェル・同じディレクトリ） | |
| `Ctrl+Shift+Alt+D` / `E` | シェルを一覧から選んで左右 / 上下に分割 | |
| `Ctrl+Shift+H/J/K/L` | 左 / 下 / 上 / 右のペインへ移動（vim 風） | |
| `Ctrl+Shift+矢印` | 同上 | 標準 |
| `Ctrl+Shift+Alt+P` | ペインにラベルを出し、打ったラベルのペインへ移動 | |
| `Ctrl+Shift+Alt+S` | 選んだペインと今のペインを入れ替え | |
| `Ctrl+Shift+Alt+R` | ペインの中身を時計回りに回す（レイアウトは変えない） | |
| `Ctrl+Shift+Z` | 今のペインをタブいっぱいに広げる / 戻す（ズーム） | 標準 |
| `Ctrl+Shift+S` | リサイズモード（`h/j/k/l` か矢印で 2 セルずつ、`Esc`/`Enter` で終了、2 秒で自動終了） | |
| `Ctrl+Shift+Alt+←/→` | ペインの幅を 1 セルずつ調整 | 標準 |
| `Ctrl+Shift+Q` | ペインを閉じる（プログラム実行中は確認あり） | |

### タブ

| キー | 動作 | |
| --- | --- | --- |
| `Ctrl+Shift+T` / `W` | 新しいタブ / タブを閉じる（プログラム実行中は確認あり） | 標準 |
| `Ctrl+Shift+1`〜`9` | 指定番号のタブへ（`9` は最後のタブ） | 標準 |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | 次 / 前のタブ | 標準 |
| `Ctrl+PageUp` / `PageDown` | 前 / 次のタブ | 標準 |
| `Ctrl+Shift+PageUp` / `PageDown` | タブを左 / 右へ移動 | 標準 |
| `Ctrl+Shift+Alt+B` | 直前に見ていたタブへ戻る（2 枚のタブの行き来に） | |
| `Ctrl+Shift+Alt+T` | タブ名を変更（今の名前を編集。空欄で確定すると自動の名前に戻る） | |

### ワークスペースの切り替え

| キー | 動作 |
| --- | --- |
| `Ctrl+Shift+Alt+W` | 一覧から選んで切替 |
| `Ctrl+Shift+Alt+N` | 名前を入力して作成（既存の名前ならそこへ移動） |
| `Ctrl+Shift+Alt+H` / `L` | 前 / 次のワークスペースへ |

名前の変更はコマンドパレットから行います（[ワークスペース](#ワークスペース)）。

### 出力とスクロール

| キー | 動作 | |
| --- | --- | --- |
| `Ctrl+Shift+Alt+↑` / `↓` | 前 / 次のプロンプトへスクロール（要シェル統合） | |
| `Ctrl+Shift+Alt+C` | 直前のコマンドの出力だけをコピー（要シェル統合） | |
| `Ctrl+Shift+Alt+O` | スクロールバック全体を OS 既定のテキストエディタで開く | |
| `Ctrl+Shift+Alt+K` | スクロールバックと画面を消去 | |
| `Shift+PageUp` / `PageDown` | 1 ページスクロール | 標準 |
| `Ctrl+Shift+F` | 検索（選択中の文字列があれば、それを検索語に入れて開く） | 標準 |
| `Ctrl+Shift+X` | コピーモード（キーボードで範囲選択） | 標準 |

### 選択・コピー・リンク

| キー | 動作 | |
| --- | --- | --- |
| `Ctrl+Shift+C` / `V` | コピー / 貼り付け | 標準 |
| `Ctrl+Shift+Space` | QuickSelect: ハッシュ・パス・URL 等にラベルを出し、打つとコピー（大文字で打つとコピー + 貼り付け） | 標準 |
| `Ctrl+Shift+O` | 画面上の URL にラベルを出し、選んだものをブラウザで開く | |
| `Ctrl+Shift+U` | 文字（絵文字）を名前で探して入力 | 標準 |

### 起動・その他

| キー | 動作 | |
| --- | --- | --- |
| `Ctrl+Shift+M` | 起動メニュー（シェル / WSL / ssh 接続先 / 開いているタブ / ワークスペース） | |
| `Ctrl+Shift+P` | コマンドパレット（この設定の独自操作も並ぶ） | 標準 |
| `Ctrl+Shift+N` | 新しいウィンドウ | 標準 |
| `Ctrl+Shift+R` | 設定の再読み込み | 標準 |
| `Ctrl` + `+` / `-` / `0` | 文字の拡大 / 縮小 / 元に戻す | 標準 |
| `Alt+Enter` | フルスクリーン切替 | 標準 |

### マウス

| 操作 | 動作 | |
| --- | --- | --- |
| 左ドラッグ / ダブル / トリプルクリック | 文字 / 単語 / 行を選択。離すとコピー | 標準 |
| 左クリック（リンク上） | URL を開く | 標準 |
| `Alt` + 左ドラッグ | 矩形選択 | 標準 |
| 右クリック | クリップボードから貼り付け | |
| 中クリック | 選択中の文字列（PRIMARY）を貼り付け | 標準 |
| `Ctrl` + ホイール | 文字の拡大 / 縮小（ウィンドウの大きさは変えず、行数・桁数が変わる） | |
| タブバーの空き帯を左ドラッグ / ダブルクリック | ウィンドウの移動 / 最大化（Wayland では移動不可） | 標準 |

### 無効にした標準キー

`Ctrl+Shift+K`（スクロールバック消去）と `Ctrl+Shift+L`（デバッグ表示）は、vim 風の
ペイン移動に使ったため元の動作はしません。スクロールバック消去は `Ctrl+Shift+Alt+K` で、
デバッグ表示はコマンドパレット（`Ctrl+Shift+P`）で `debug` と打つと出る項目から使えます。

### コマンドパレットの独自項目

`Ctrl+Shift+P` で開くコマンドパレットに次の項目を足しています（定義は `lua/palette.lua`）。
名前は「日本語 (English)」形式なので、IME を切り替えずに英語（例: `copy`, `rename`）でも絞り込めます。

| 項目 | キー |
| --- | --- |
| 直前のコマンドの出力をコピー (Copy last output) | `Ctrl+Shift+Alt+C` |
| スクロールバックをエディタで開く (Open scrollback in editor) | `Ctrl+Shift+Alt+O` |
| URL を選んで開く (Open URL) | `Ctrl+Shift+O` |
| タブ名を変更 (Rename tab) | `Ctrl+Shift+Alt+T` |
| ペインを新しいタブへ移動 (Move pane to new tab) | — |
| ペインを新しいウィンドウへ移動 (Move pane to new window) | — |
| ワークスペースを作成 / 移動 (New workspace) | `Ctrl+Shift+Alt+N` |
| ワークスペース名を変更 (Rename workspace) | — |
| 設定フォルダを開く (Open config folder) | — |

## 機能の詳細

### 外観

#### 配色

`lua/colors.lua` の `palette` が全体の色を決めます。他のモジュール（タブ・ステータスバー）も
ここを参照するので、色を変えるときはこの表だけ直せば揃います。

| 名前 | 色 | 使いどころ |
| --- | --- | --- |
| `bg` | `#1a1b26` | 背景 / 明るいピル（アクティブタブ・バッジ）の上の文字 |
| `fg` | `#c0caf5` | 文字 / ステータスバーの文字 / コマンドパレットの文字 |
| `accent` | `#7aa2f7` | アクティブなタブ / カーソル / ペインの境界線 / 日付・時刻のアイコン / コピーモードのバッジ |
| `accent2` | `#bb9af7` | マウスを乗せたタブ / ワークスペース名 / 検索モードのバッジ / 終わりの見えない進捗 |
| `tab_bg` | `#24283b` | 非アクティブなタブ / スクロールバー / 選択 UI のラベル / コマンドパレット・文字選択の背景 |
| `tab_bar_bg` | `#15161e` | タブバーとステータスバーの背景 |
| `selection_bg` | `#283457` | 選択範囲 |
| `dim` | `#565f89` | 非アクティブなタブの文字 / 新しいタブ（＋）ボタン |
| `warn` | `#e0af68` | IME 変換中のカーソル / リサイズのバッジ / 未読ドット / 注意メッセージ / 電池残量 15% 以下 |
| `ok` | `#9ece6a` | 進捗 / 電池 / 成功メッセージ |

ANSI 16 色（`ansi` / `brights`）も同じファイルにあります。

#### 文字と描画

- **フォント**: `lua/ui.lua` の候補を先頭から使う（HackGen Console NF → HackGen35 Console NF →
  Symbols Nerd Font Mono → Noto Sans Mono CJK JP → Noto Sans CJK JP）。本文 12pt、タブバー 11pt。
  リガチャ（`calt` / `clig` / `liga`）有効。コマンドパレットと文字選択にも同じフォントを使う
  （既定の Roboto だと日本語とアイコンが豆腐になるため）
- **文字の拡大 / 縮小**（`Ctrl` + `+`/`-` か `Ctrl`+ホイール）ではウィンドウの大きさを変えない
  （`adjust_window_size_when_changing_font_size = false`）。代わりに行数・桁数が変わる
- **低コントラストの自動補正**: 背景とのコントラスト比が 4.5:1 未満の文字色を自動で明るくする
  （`text_min_contrast_ratio`。例: 黒背景に濃紺の `ls` のディレクトリ名）。タブバーとステータスバーは対象外
- **IME 変換中のカーソル色**: 日本語入力の未確定中はカーソルが黄色（`warn`）になり、確定すると青に戻る
- **非アクティブなペイン**は彩度 85%・明るさ 75% に落として、どのペインにいるか分かるようにする
- **カーソル**: 点滅する下線（500ms 間隔、フェードなし）
- **ベル**: 音は鳴らさず、カーソル色を一瞬フェードさせる
- **スクロールバック** 100,000 行。右端にスクロールバーを出す（右の余白 16px の中に描くので本文は狭くならない）
- **描画**: 最大 120fps、アニメーション 60fps

#### ウィンドウ

- 背景は 90% の不透明度。Windows 11 はアクリル（すりガラス）、macOS はぼかし 24
- 文字のセルとタブバーは不透明のまま（半透明にすると文字とボタンが背景に沈んで読みにくい）
- 余白は 左右 16px・上 12px・下 10px。ウィンドウの大きさがセルの整数倍でないときの端数は
  上下左右に均等に配る（`window_content_alignment`）

### ウィンドウのタイトルバー

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

#### Wayland の事情

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

### タブバー

タブは丸い端のピル型で、左から次の順に並びます（`lua/tabs.lua` の `format-tab-title`）。

```
 1 <アイコン>  タイトル <🔍> <進捗 / ●>
```

| 要素 | 内容 |
| --- | --- |
| 番号 | タブの番号（`Ctrl+Shift+1`〜`9` の番号と同じ） |
| アイコン | ペインで今動いているプログラムのアイコン（下の表） |
| タイトル | [タブ名の決まり方](#タブ名の決まり方) を参照。24 文字を超えると切り詰める |
| 🔍 | ペインをズーム中（`Ctrl+Shift+Z`） |
| 進捗 | プログラムが OSC 9;4 で進捗を報告しているとき（winget / pacman / yazi など）。緑の円グラフ + %、赤 = エラー、紫 = 終わりの見えない処理 |
| ● | 見ていない間に出力があったタブ（非アクティブなタブだけ）。切り替えると消える |

アクティブなタブは青、マウスを乗せたタブは紫。タブ内の × ボタンは出さない
（閉じるのは `Ctrl+Shift+W`）。右端の ＋ で新しいタブ。

進捗表示は次で試せます（最後の行で消える）。

```sh
printf '\e]9;4;1;50\e\\'   # 50%
printf '\e]9;4;2;50\e\\'   # エラー
printf '\e]9;4;3;0\e\\'    # 終わりの見えない処理
printf '\e]9;4;0;0\e\\'    # 消す
```

#### タブ名の決まり方

上から順に、最初に当てはまったものを使います。

1. `Ctrl+Shift+Alt+T` で**手で付けた名前**
2. ssh 先のシェルが OSC 7 でディレクトリを送っているとき → **`ホスト名:ディレクトリ名`**
   （例: `myhost:setup-notes`）。送られてきたホスト名が自分のホスト名・`localhost` 以外なら ssh 先とみなす
3. **ssh の実行中** → ペインのタイトル。多くの Linux の既定の bashrc は `user@host:dir` を
   タイトルに設定するので、`user@` を省いて `myhost:~/setup-notes` のように出る。
   このときディレクトリの情報は接続前のローカルのもののまま残っているので使わない
4. **今いるディレクトリ名**（[シェル統合](#シェル統合)がある場合）。ホームは `~`
5. ペインのタイトル（シェル統合が無いシェルでは、ほぼプログラム名）

#### アイコンの対応

| 分類 | プログラム |
| --- | --- |
| シェル | `pwsh` `powershell` `cmd` `bash` `sh` `zsh` `fish` `nu` |
| WSL | `wsl` `wslhost` |
| エディタ | `nvim` `vim` |
| 開発ツール | `node` `python` `python3` `git` `lazygit` `gh` `cargo` `rustc` `go` `docker` `kubectl` `ssh` |
| モニタ | `top` `htop` `btop` |

それ以外は汎用の端末アイコンです。WSL のペインではプログラム名が取れないことが多く、
その場合も汎用アイコンになります。

### ステータスバー

タブバーの右端（ウィンドウボタンの左）に、左から次の順で出ます（`lua/statusbar.lua`、1 秒ごとに更新）。

| 表示 | 出る条件 |
| --- | --- |
| 一時メッセージ（緑 = 成功 / 黄 = 注意） | 「直前の出力をコピー」などの結果。約 3 秒で消える |
| モードのバッジ（黄「リサイズ」/ 青「コピー」/ 紫「検索」） | リサイズモード（`Ctrl+Shift+S`）・コピーモード（`Ctrl+Shift+X`）・検索（`Ctrl+Shift+F`）の間 |
| ワークスペース名 | `default` 以外のワークスペースにいるとき |
| 日付（曜日は日本語）・時刻 | 常に |
| 電池残量 | 電池のある機種だけ。充電中は充電アイコン、15% 以下は黄色 |

タブ名はディレクトリ名を優先するため、WezTerm 標準の「Copy mode: …」というタブ表示は出ません。
モードに入ったかどうかはバッジで確認してください。

### ペイン操作

- **分割**（`Ctrl+Shift+D` / `E`）: 今のペインと同じシェルで、同じディレクトリから開く
  （ディレクトリの引き継ぎには[シェル統合](#シェル統合)が必要）
- **シェルを選んで分割**（`Ctrl+Shift+Alt+D` / `E`）: 起動メニューと同じ一覧（Git Bash / PowerShell /
  WSL / ssh 接続先 …）から選び、そのシェルで分割する。文字を打つと絞り込める。`Esc` で中止
- **ラベルで選ぶ**（`Ctrl+Shift+Alt+P`）: 各ペインに `a` `s` `d` `f` … のラベルが出るので、打つとそこへ移動。
  3 枚以上のペインで方向キーより速い。`Ctrl+Shift+Alt+S` は同じ方法で選んだペインと今のペインを入れ替える
- **回転**（`Ctrl+Shift+Alt+R`）: ペインの配置はそのまま、中身だけを時計回りに回す
- **リサイズモード**（`Ctrl+Shift+S`）: `h/j/k/l` か矢印を押すたびに境界が 2 セル動く。
  `Esc` / `Enter` で終了し、2 秒何も押さなければ自動で終わる。モード中はステータスバーに「リサイズ」
- **ペインを新しいタブ / ウィンドウへ移動**（コマンドパレット）: 分割していたペインを独立したタブ
  （またはウィンドウ）にする。移したタブへ切り替わる

### ワークスペース

ワークスペースは「タブの組」を名前で切り替える仕組みです。作業ごと（例: `blog`, `infra`）に
タブを分けておき、丸ごと切り替えられます。起動直後は `default` にいます。

- **作成 / 移動**（`Ctrl+Shift+Alt+N`）: 名前を入力。無ければ作って移動、あればそこへ移動
- **一覧から切替**（`Ctrl+Shift+Alt+W`）: 文字を打つと絞り込める。起動メニュー（`Ctrl+Shift+M`）にも並ぶ
- **前後へ**（`Ctrl+Shift+Alt+H` / `L`）
- **名前の変更**（コマンドパレット「ワークスペース名を変更」）: 今の名前を編集する。
  既にある名前にすると 2 つのワークスペースが 1 つに混ざってしまうので、その場合は変更せず注意を出す
- `default` 以外にいる間はステータスバーに名前が出る

### 出力とスクロールバック

以下のうちプロンプトジャンプと出力コピーは、[シェル統合](#シェル統合)がプロンプトと出力の位置を
WezTerm に知らせていることが前提です。

- **プロンプトジャンプ**（`Ctrl+Shift+Alt+↑` / `↓`）: 前 / 次のプロンプト行まで一気にスクロール。
  長い出力をさかのぼって、どのコマンドの結果かを探すときに使う

#### 直前の出力をコピー

`Ctrl+Shift+Alt+C` で、最後に実行したコマンドの**出力だけ**をクリップボードへコピーします
（プロンプトとコマンド行は含まない）。ドラッグで範囲を選ぶ手間が無く、スクロールが必要な長い出力も丸ごと取れます。

- 結果はステータスバーに「出力 N 行をコピー」と数秒出る
- 対象は「最後に Enter で実行したコマンド」の出力。プロンプトで入力途中の文字は数えない
- 出力が無いコマンド（`cd` など）の直後は「直前の出力は空です」（それより前のコマンドの出力は取らない）
- 実行中のコマンドでは、その時点までの出力をコピーする（まだ何も出ていなければ「空です」）
- シェル統合が無いシェル（コマンドプロンプト / 統合を読み込んでいない bash）では
  「コピーできる出力がありません（要シェル統合）」
- **ssh 中**は、ssh 先のシェルでも統合が動いていればそのコマンド単位でコピーできる
  （→ [ssh 先でもシェル統合を使う](#ssh-先でもシェル統合を使う)）。動いていないと
  ssh を始めてからの画面全体が 1 つの出力になってしまうため、コピーせず
  「ssh 先の出力は区切れません（ssh 先でシェル統合が必要）」と出す
- 出力の後ろの空行や、`clear` の後に残る画面の余白は含めない

#### スクロールバックをエディタで開く

`Ctrl+Shift+Alt+O` で、スクロールバック全体（最大 100,000 行）をテキストファイルに書き出し、
OS の既定のアプリで開きます。長いログを検索・保存したいときに使います。

- 書き出し先: 一時ディレクトリの `wezterm-scrollback.txt`（Windows は `%TEMP%`、
  Linux / macOS は `$TMPDIR` か `/tmp`）。毎回上書きするのでファイルは増えない。
  残したい内容はエディタで別名保存する
- 画面の幅で折り返された行は 1 行に戻して書き出す
- 開くアプリは `.txt` の関連付けで決まる（Windows の既定はメモ帳）。VS Code などで開きたい場合は
  OS の設定で `.txt` の既定のアプリを変える

#### そのほか

- **消去**（`Ctrl+Shift+Alt+K`）: スクロールバックと画面を消す
- **検索**（`Ctrl+Shift+F`、標準）: 文字を選択してから押すと、それが検索語に入る。検索中は
  `Enter` / `↑` / `Ctrl+P` = 前の一致、`↓` / `Ctrl+N` = 次の一致、`PageUp` / `PageDown` = ページ単位、
  `Ctrl+R` = 一致方法の切替（大文字小文字を区別 → 区別しない → 正規表現）、`Ctrl+U` = 検索語を消す、`Esc` = 閉じる
- **コピーモード**（`Ctrl+Shift+X`、標準）: キーボードで範囲選択する vim 風のモード。
  `h/j/k/l` 移動、`w/b/e` 単語、`0` / `$` 行頭 / 行末、`g` / `G` 先頭 / 末尾、
  `v` / `V` / `Ctrl+V` で文字 / 行 / 矩形の選択開始、`y` でコピーして終了、`Esc` / `q` で終了

### QuickSelect とリンク

#### QuickSelect

`Ctrl+Shift+Space`（標準）で、画面に見えている「コピーしたくなりそうな文字列」にラベルが付きます。
ラベルを打つとその文字列をコピーして終わります。**ラベルを大文字で打つとコピーしたうえで
今のカーソル位置に貼り付けます**（コミットハッシュやパスをそのままコマンド行に入れたいときに便利）。

- ラベルは `a` `s` `d` `f` `g` `h` `j` `k` `l`（ホームポジション。ペインのラベル選択と同じ）
- QuickSelect 中は画面の色付けを外して、ラベルを見やすくする
- 標準で拾うもの: URL、パスの断片、git のハッシュ、IP アドレス、数字 など
- この設定で足したもの（`lua/general.lua` の `quick_select_patterns`）:

  | パターン | 例 |
  | --- | --- |
  | git のコミットハッシュ（7〜40 桁） | `d1fc9b1` |
  | Windows の絶対パス | `C:\Users\foo\a.txt`、`D:/work/x` |
  | `ファイル:行` / `ファイル:行:桁` | `src/main.rs:42:7`、`localhost:3000` |

#### URL を開く

`Ctrl+Shift+O` で、画面上の `http://` / `https://` の URL にだけラベルが付き、選んだものを
既定のブラウザで開きます。`gh pr create` や開発サーバが表示した URL を、マウスを使わずに開けます。

URL の末尾の `.` `,` `:` `;` `?` `!`、閉じ括弧・引用符、続く日本語は URL に含めません
（例: 「詳細は https://example.com/docs/ を参照」「(https://example.com/a)」）。
そのため括弧を含む URL（Wikipedia の一部など）は括弧の手前で切れます。その場合はマウスでクリックしてください。

#### マウスでリンクを開く

URL の上で左クリックすると開きます（標準）。ドラッグで選択したときは開かずにコピーだけします。

### 長いコマンドの完了通知

**10 秒以上**かかったコマンドが終わったとき、**そのペインを見ていなければ** OS の通知を出します。
ビルドやテストを流して別のタブ・別のアプリで作業している間に、終わったことが分かります。

```
✔ 完了                       ✘ 失敗 (終了コード 2)
make build (1分23秒)          cargo test (12秒)
```

- 「見ている」とは、WezTerm のウィンドウが前面にあり、かつそのペインがアクティブなこと。
  別のタブ・別のペイン・別のアプリを見ていれば通知する。ブラウザを見ている間も通知される
- 見ていたペインでは通知しないので、`vim` や `ssh` を終了したときに出ることはない
- 通知文のコマンドは先頭 60 文字まで
- しきい値は環境変数 `WEZTERM_NOTIFY_AFTER`（秒）で変えられる。例:
  - bash / zsh: `~/.bashrc` に `export WEZTERM_NOTIFY_AFTER=30`
  - PowerShell: プロファイルに `$env:WEZTERM_NOTIFY_AFTER = 30`
  - 全シェル共通: `lua/shells.lua` の `config.set_environment_variables` に `WEZTERM_NOTIFY_AFTER = "30"` を足す
- 通知の見た目や条件は `lua/notify.lua` で変えられる

仕組み: シェル統合がコマンドの開始時刻を覚えておき、次のプロンプトで経過時間を計算します。
しきい値を超えていれば「終了コード・経過秒・コマンド」を WezTerm のユーザー変数
（`wezterm_cmd_done`）として送り、`lua/notify.lua` が見ているかどうかを判断して通知します。

制約:

- bash / zsh / PowerShell のみ（[シェル統合](#シェル統合)が必要）。コマンドプロンプトは対象外
- **表示していないワークスペース**のペインでは通知されない（WezTerm がそのペインの変化を
  表示中のウィンドウに伝えないため）
- tmux の中では動かない（シェル統合がそこでは無効になるため）
- ssh 先で動かしたコマンドは、[ssh 先でもシェル統合を使う](#ssh-先でもシェル統合を使う)の設定をすれば
  通知される（ssh 先の統合が送った通知が、ssh を通って手元の WezTerm に届く）
- Windows で通知が出ないときは「設定 → システム → 通知」で WezTerm が許可されているか、
  集中モード（応答不可）になっていないかを確認

### シェルと起動メニュー

`Ctrl+Shift+M` の起動メニューには、この設定が見つけたシェル・WSL・ssh 接続先に加えて、
開いているタブとワークスペースが並びます。文字を打つと絞り込めます。
シェルの一覧は `Ctrl+Shift+Alt+D` / `E`（シェルを選んで分割）とも共通です（`lua/shells.lua`）。

#### Windows で探すシェル

見つかったものだけが並びます。上から順に探し、最初に見つかったパスを使います。

| 表示名 | 探す場所 | シェル統合 |
| --- | --- | --- |
| Git Bash | `C:\Program Files\Git\bin\bash.exe` / `%USERPROFILE%\AppData\Local\Programs\Git\bin\bash.exe` / `%USERPROFILE%\scoop\apps\git\current\bin\bash.exe` | `~/.bashrc` に 1 行 |
| PowerShell 7 | `C:\Program Files\PowerShell\7\pwsh.exe` / scoop / Microsoft Store 版 | 自動 |
| Windows PowerShell | `powershell.exe`（常にある） | 自動 |
| Command Prompt | `cmd.exe`（常にある） | なし |
| Developer PowerShell (年) | Visual Studio 2026 / 2022 / 2019 の `Common7\Tools\Launch-VsDevShell.ps1` | 自動 |
| Developer Command Prompt (年) | 同じ場所の `VsDevCmd.bat` | なし |
| MSYS2 UCRT64 / MSYS2 MSYS | `C:\msys64\msys2_shell.cmd` | `~/.bashrc` に 1 行 |
| QMK MSYS | `C:\QMK_MSYS\usr\bin\bash.exe` | `~/.bashrc` に 1 行 |
| WSL の各ディストリビューション | `wsl.exe` に登録されているもの | WSL 側の `~/.bashrc` に 1 行 |
| ssh ホスト名 | `~/.ssh/config` | — |

新しいタブ・ウィンドウの既定のシェル（`default_prog`）は、Git Bash が見つかれば Git Bash、
無ければ WezTerm の既定です。

- Developer PowerShell / Developer Command Prompt は Visual Studio の開発環境（`cl.exe` や MSBuild に
  PATH が通った状態）で開く。VS はバージョン × エディション（Community / Professional /
  Enterprise / Preview / BuildTools）を新しい順に探す
- PowerShell 7 の Microsoft Store 版は実体のパス（`C:\Program Files\WindowsApps\Microsoft.PowerShell_<版>_...`）に
  バージョン番号が入り、親フォルダも列挙できないため、アプリ実行エイリアス
  `%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe` を使う。これは 0 バイトの再解析ポイントで
  `io.open` では開けないので、`lua/shells.lua` の `exists()` は `os.rename` による追加判定を持っている

#### Linux / macOS で探すシェル

`bash` / `zsh` / `fish` / `nu` を代表的な場所（`/bin`、`/usr/bin`、`/usr/local/bin`、`/opt/homebrew/bin`）から
探し、ログインシェルとして起動します。既定のシェルはログインシェル（`$SHELL`）のままです。

#### SSH ホスト

`~/.ssh/config`（Windows は `%USERPROFILE%\.ssh\config`）の `Host` が「ssh ホスト名」として
起動メニューと分割の一覧に並びます（名前順）。`ssh` と打てば絞り込めます。

```
Host myhost
  HostName 192.168.1.20
  User foo
```

- 接続には OpenSSH の `ssh` コマンドを使う（WezTerm 内蔵の SSH クライアントではない）ので、
  ssh-agent・ProxyJump などの設定がそのまま効く。Windows は標準の OpenSSH クライアントを使う
- `Host *` や `Host 192.168.1.*` のようなワイルドカードの行は並ばない
- `github.com` / `gitlab.com` / `bitbucket.org` はシェルに入れない（挨拶を出して切れる）ので並べない。
  除外するホストは `lua/shells.lua` の `SSH_SKIP_HOSTS` で変えられる
- WSL のペインから分割しても、WSL の中ではなく Windows 側の `ssh` で接続する
- 接続中のタブ名は接続先になる（[タブ名の決まり方](#タブ名の決まり方)）
- ssh 先でもシェル統合を動かすと、ディレクトリ名入りのタブ名・プロンプトジャンプ・出力のコピー・
  完了通知が ssh 先でも使える（→ [ssh 先でもシェル統合を使う](#ssh-先でもシェル統合を使う)）
- `~/.ssh/config` を編集したら `Ctrl+Shift+R` で反映

#### 閉じるときの確認

`Ctrl+Shift+W`（タブ）/ `Ctrl+Shift+Q`（ペイン）で閉じるとき、WezTerm は中で動いているプログラムを調べ、
**シェルがプロンプトで待っているだけなら確認なしで閉じ**、それ以外（vim・ssh・ビルド中など）なら確認します。

WezTerm の既定の「確認不要なプログラム」の一覧は `bash` のように拡張子なしで書かれていますが、
Windows のプログラム名は `bash.exe` なので一致せず、Git Bash や MSYS2 はアイドル状態でも毎回確認が出ていました。
この設定では `bash.exe` `sh.exe` `zsh.exe` `fish.exe` `nu.exe` を足しています
（`lua/shells.lua` の `skip_close_confirmation_for_processes_named`）。

`ssh.exe` と `wsl.exe` は足していません。その先で何が動いているかを WezTerm から見られないためです。

#### コマンドプロンプト（cmd）

`Command Prompt` と `Developer Command Prompt` には**シェル統合がありません**
（cmd 向けの OSC 7 / OSC 133 スクリプトを用意していないため）。次は効きません。

- 前後のプロンプトへのジャンプ・直前の出力のコピー・完了通知
- 新しいタブ・分割ペインが「今いるディレクトリ」で開く動作

### コマンドパレット

`Ctrl+Shift+P`（標準）で WezTerm のすべての操作を名前で探して実行できます。この設定では
独自の操作を[独自項目](#コマンドパレットの独自項目)として足しています。キーを覚えていない操作や、
キーを割り当てていない操作（ペインを新しいタブへ、ワークスペース名の変更、設定フォルダを開く）はここから使います。
パレットの配色はタブと同じ色に揃えています（既定は灰色）。

## シェル統合

`shell/wezterm.sh`（bash / zsh）と `shell/wezterm.ps1`（PowerShell）が、シェルから WezTerm へ
次の情報を送ります。WezTerm はこれを見て、ディレクトリやプロンプト・出力の位置を知ります。

| 送る情報 | いつ | 得られる動作 |
| --- | --- | --- |
| OSC 7（今のディレクトリ） | プロンプトごと | 新しいタブ・分割ペインが同じディレクトリで開く / タブ名がディレクトリ名になる |
| OSC 133 A / B（プロンプトの開始 / 入力の開始） | プロンプトごと | 前後のプロンプトへのジャンプ |
| OSC 133 C（出力の開始） | Enter を押してコマンドが動く直前 | 直前の出力のコピー |
| OSC 133 D（終了コード） | コマンドが終わったとき | 出力の範囲の終わり |
| ユーザー変数 `wezterm_cmd_done` | 長いコマンドが終わったとき | [完了通知](#長いコマンドの完了通知) |

シェルごとの対応:

| 機能 | bash / zsh | PowerShell | cmd |
| --- | --- | --- | --- |
| ディレクトリの引き継ぎ・タブ名 | ○ | ○ | × |
| プロンプトジャンプ | ○ | ○ | × |
| 直前の出力をコピー | ○ | ○（PSReadLine が必要。通常は入っている） | × |
| 完了通知 | ○（`base64` コマンドが必要。Git Bash には入っている） | ○ | × |
| 迷子のマウス報告よけ | ○ | — | — |

WezTerm 以外の端末で読み込まれた場合、「迷子のマウス報告よけ」以外は何もしません
（`$TERM_PROGRAM` で判定）。既存のプロンプト（`PS1` や `prompt` 関数、oh-my-posh など）は
置き換えず、前後に印を足すだけです。

### PowerShell

追加の設定は不要です。`lua/shells.lua` が起動引数で自動的に読み込みます
（`-Command` はプロファイルを抑止しないため、既存のプロファイルはそのまま動きます）。

- 出力の開始（OSC 133 C）は、PSReadLine が定義する入力読み取り関数 `PSConsoleHostReadLine` を
  包んで、Enter の直後に送ります（VS Code のシェル統合と同じ方法）。PSReadLine を読み込んでいない場合は送らない
- `shell/wezterm.ps1` は **UTF-8 BOM 付き**で保存してください。Windows PowerShell 5.1 は
  BOM の無い `.ps1` を ANSI として読むため、日本語コメントが化けて構文エラーになります

### bash（Git Bash / MSYS2 / QMK MSYS / Linux）と zsh

`lua/shells.lua` が環境変数 `WEZTERM_SHELL_INTEGRATION` にパスを渡すので、
`~/.bashrc`（zsh は `~/.zshrc`）に次の 1 行を追記します。

```sh
[ -r "${WEZTERM_SHELL_INTEGRATION:=$HOME/.config/wezterm/shell/wezterm.sh}" ] && . "$WEZTERM_SHELL_INTEGRATION"
```

環境変数が無いときのフォールバックを付けてあるのは、tmux や ssh を挟むとこの変数が
届かないためです（tmux サーバは起動時の環境を子プロセスへ配るので、WezTerm が渡した
変数は後から作ったペインに入りません）。パスは「[配置と初回セットアップ](#配置と初回セットアップ)」の表どおり全 OS で
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

Linux 版 WezTerm のパッケージは公式のシェル統合を `/etc/profile.d/wezterm.sh` に置きます。
それが読み込まれている環境では OSC 7 / OSC 133 は公式側に任せ、`shell/wezterm.sh` は
マウス報告よけだけを残して抜けます（同名の `__wezterm_osc7` を上書きして公式側のフックを
壊さないため）。この場合、完了通知は動きません。

### WSL

WSL ドメインは起動引数を渡せないため、WSL 側の `~/.bashrc` に直接書きます。

```sh
. /mnt/c/Users/<ユーザー名>/.config/wezterm/shell/wezterm.sh
```

### tmux の中

tmux の中では `$TERM_PROGRAM` が `tmux` になるため、シェル統合は（マウス報告よけ以外）無効になります。

### ssh 先でもシェル統合を使う

シェル統合は `$TERM_PROGRAM` が `WezTerm` のときだけ動きます。ssh はこの環境変数を既定では
接続先へ渡さないので、ssh 先のシェルでは統合が動きません。その場合でもタブ名は接続先になりますが
（ペインのタイトルから取る）、ssh 先のコマンドについてはプロンプトジャンプ・出力のコピー・完了通知が使えません。

次の 3 つを設定すると、ssh 先でも手元と同じように使えます（myhost のような自分で管理しているホスト向け）。

1. **手元の `~/.ssh/config`**（Windows は `%USERPROFILE%\.ssh\config`）で `TERM_PROGRAM` を送る。
   WezTerm から ssh したときだけ `WezTerm` が入るので、他の端末から接続したときは統合は動かない

   ```
   Host myhost 192.168.1.10
     SendEnv TERM_PROGRAM
   ```

2. **ssh 先の sshd** で受け取りを許可する（root で 1 回）

   ```sh
   echo 'AcceptEnv TERM_PROGRAM' | sudo tee /etc/ssh/sshd_config.d/50-wezterm.conf
   sudo systemctl reload sshd
   ```

3. **ssh 先の `~/.bashrc`** に、手元と同じ[シェル統合の 1 行](#bashgit-bash--msys2--qmk-msys--linuxと-zsh)を書き、
   この設定を ssh 先の `~/.config/wezterm` にも置く（Syncthing などで同期していればそのまま）

設定後に ssh すると、タブ名が `myhost:setup-notes` のように ssh 先のディレクトリ名になり、
ssh 先でも `Ctrl+Shift+Alt+↑/↓`・`Ctrl+Shift+Alt+C`・完了通知が効きます。
確かめるには、ssh 先で `echo $TERM_PROGRAM` が `WezTerm` になるかを見ます。
ssh 先で tmux を使っている場合、tmux の中では無効です（[tmux の中](#tmux-の中)）。

### 迷子のマウス報告よけ

lazygit や yazi のような TUI は起動時にマウス報告（DECSET 1003 = 移動も含む全イベント /
1006 = SGR 形式）を有効にし、終了時に解除します。ところが解除が端末へ届く前に端末が
出してしまった報告は行き場を失い、戻ってきたシェルにこう現れます。

```
[foo@myhost setup-notes]$ lazygit
^[[<35;33;72M[foo@myhost setup-notes]$
```

届くタイミングで見え方が変わります。プロンプト表示前なら端末がそのまま echo するだけ
（表示が汚れる）ですが、readline の起動後に届くと `35: command not found` のように
コマンド行が壊れます。WezTerm 固有の問題ではなく、tmux や ssh を挟んでも起きます。

`shell/wezterm.sh` は対策を 2 つ入れています（この部分は WezTerm 以外・tmux の中でも働きます）。

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

### 導入しない場合

統合を入れなくても設定は問題なく動きます。タブ名は従来どおりプロセス名になり、
プロンプトジャンプ・出力のコピー・完了通知が効かないだけです。

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
| 完了通知のしきい値 | 環境変数 | `WEZTERM_NOTIFY_AFTER`（[完了通知](#長いコマンドの完了通知)） |
| 完了通知の文面・条件 | `lua/notify.lua` | `user-var-changed` ハンドラ |
| 起動メニューのシェル | `lua/shells.lua` | `discover()` の `candidates` |
| SSH の一覧から外すホスト | `lua/shells.lua` | `SSH_SKIP_HOSTS` |
| 確認なしで閉じるプログラム | `lua/shells.lua` | `skip_close_confirmation_for_processes_named` |
| キー / マウス | `lua/bindings.lua` | `config.keys` / `config.mouse_bindings` |
| コマンドパレットの独自項目 | `lua/palette.lua` | `ENTRIES` |

キーを足すときは WezTerm の既定の割り当てと重ならないか `wezterm show-keys` で確かめてください
（[動作確認](#動作確認)）。

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
| `lua/shells.lua` | シェル・SSH ホストの探索と `launch_menu` / `default_prog` / WSL ドメイン / 閉じる確認 |
| `lua/bindings.lua` | キーバインドとマウスバインド |
| `lua/actions.lua` | キーとコマンドパレットの両方から使う操作（出力コピー・URL を開く など）。`apply` は持たない |
| `lua/palette.lua` | コマンドパレットの独自項目 |
| `lua/notify.lua` | 長いコマンドの完了通知 |
| `lua/ui.lua` | 共有定数（パワーライン区切り・フォント候補）。`apply` は持たない |
| `shell/wezterm.sh` | シェル統合（bash / zsh）。OSC 7 / OSC 133 / 完了通知 / 迷子のマウス報告よけ |
| `shell/wezterm.ps1` | シェル統合（PowerShell）。OSC 7 / OSC 133 / 完了通知 |

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

シェル統合の構文確認:

```sh
bash -n shell/wezterm.sh && zsh -n shell/wezterm.sh
```

## トラブルシューティング

| 症状 | 確認すること |
| --- | --- |
| アイコンやタブの丸い端が □ になる | HackGen Console NF（または Symbols Nerd Font Mono）が入っているか。`ls-fonts` でどのフォントが使われているか見る |
| 設定を変えたのに反映されない / 見た目が素の WezTerm になった | 設定エラー。画面上部のエラー表示か、`ls-fonts` の `ERROR` 行を見る。stable 版で起動していないか（nightly 必須） |
| 新しいタブが今のディレクトリで開かない / タブ名がディレクトリ名にならない | [シェル統合](#シェル統合)が読み込まれているか。bash は `~/.bashrc` の 1 行、WSL は WSL 側の `~/.bashrc` |
| 「コピーできる出力がありません」と出る | 同上。コマンドプロンプトは非対応。tmux の中も非対応 |
| 「ssh 先の出力は区切れません」と出る | ssh 先でシェル統合が動いていない。[ssh 先でもシェル統合を使う](#ssh-先でもシェル統合を使う) |
| 完了通知が出ない | 10 秒以上かかったか（`WEZTERM_NOTIFY_AFTER`）、そのペインを見ていなかったか、OS の通知で WezTerm が許可されているか、表示中のワークスペースか。`sleep 11` を実行してすぐ別のタブに切り替えると試せる |
| Git Bash を閉じるときにまだ確認が出る | シェルの中でプログラム（`ssh`、バックグラウンドのジョブなど）が動いていないか |
| ssh 中のタブ名がローカルのタイトルのまま | ssh 先のシェルがタイトルを設定していない。ssh 先の `PS1` / `PROMPT_COMMAND` でタイトル（`\e]0;...\a`）を送るようにする |
| ssh の一覧にホストが出ない | `~/.ssh/config` に `Host` があるか（ワイルドカードは出ない）。編集後は `Ctrl+Shift+R` |
| lazygit の終了後に `^[[<35;...M` が出る | [迷子のマウス報告よけ](#迷子のマウス報告よけ) |
| Wayland でウィンドウをドラッグできない | 仕様（[Wayland の事情](#wayland-の事情)）。`Win`+ドラッグで移動 |

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

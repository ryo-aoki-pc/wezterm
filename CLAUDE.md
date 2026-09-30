# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## このリポジトリは何か

[WezTerm](https://wezterm.org/) の nightly 向けの個人設定。Windows 11（既定のシェルは Git Bash）が主で、Linux（GNOME Wayland）と macOS でも同じ設定が動くように書いてある。`~/.config/wezterm`（Windows は `%USERPROFILE%\.config\wezterm`）に clone して使う。

- 機能・キー操作・シェル統合の仕組みの説明は `README.md`（参照用）
- 導入の手順は `docs/install.md`（手順書。[setup-notes](https://github.com/ryo-aoki-pc/setup-notes) と同じ書式。下の「docs/install.md の書き方」）

ビルド・テストフレームワークは無い。ドキュメント・コードのコメント・コミットメッセージは日本語で書く。検証していないことを「動く」と書かない。

## よく使うコマンド

```bash
# 設定の読み込みの確認。`ERROR  wezterm_gui >` の行が出なければ読めている（終了コードは誤りがあっても 0）
wezterm --config-file "$PWD/wezterm.lua" ls-fonts --text 'aあ'

# キー割り当ての一覧。設定を読めなくても黙って既定の一覧を出すので、読み込みの確認には使わない
wezterm --config-file "$PWD/wezterm.lua" show-keys

# シェル統合の構文の確認
bash -n shell/wezterm.sh && zsh -n shell/wezterm.sh
```

- 画面の無い環境でシェル統合を試すときは、`wezterm-mux-server --daemonize` を起動し、`wezterm cli spawn` / `send-text --no-paste` / `get-text` / `list` を使う（`docs/install.md` の付録と同じ方法。設定の `set_environment_variables` が効き、シェルはログインシェルで起動する）
- AlmaLinux 10 のコンテナで WezTerm を入れるときは、setup-notes の `docs/wezterm-nightly.md` の手順（COPR の `rhel-9-<arch>` を明示）

## 構成

- `wezterm.lua` — エントリポイント。`package.path` に `wezterm.config_dir .. "/lua/?.lua"` を足し、`lua/` の各モジュールの `apply(config)` を順に呼ぶ
- `lua/*.lua` — 1 モジュール 1 関心。`apply(config)` を持つのが基本で、`actions.lua`（キーとコマンドパレットで共有する操作）・`ui.lua`（共有定数・フォントの候補）・`procs.lua`（実行中のプログラムと ssh 中かの判定）は持たない
  - `colors.lua` の `palette` を、タブ・ステータスバーも参照する。色は `palette` だけを直す
  - `statusbar.lua` は、一時メッセージを出す `flash()` を公開している
  - `shells.lua` はシェル・WSL・SSH ホストを探して `launch_menu` / `default_prog` を組み立て、bash 系に環境変数 `WEZTERM_SHELL_INTEGRATION`（`shell/wezterm.sh` のパス）を渡し、PowerShell には `-NoExit -Command` で `shell/wezterm.ps1` を読ませる
- `shell/wezterm.sh` — bash / zsh のシェル統合（OSC 7・OSC 133・完了通知のユーザー変数・実行中のコマンドのユーザー変数 `WEZTERM_PROG`・迷子のマウス報告よけ）。`~/.bashrc` の 1 行で読む
- `shell/wezterm.ps1` — PowerShell のシェル統合。**UTF-8 の BOM 付き**で保存する（Windows PowerShell 5.1 は BOM の無い `.ps1` を ANSI として読み、日本語のコメントで構文エラーになる）
- `docs/install.md` — 導入の手順書

## 変えたら合わせて直すもの

- キー・マウスの割り当て（`lua/bindings.lua`）→ README の「機能早見表」「キーバインド」の表と、`lua/bindings.lua` の冒頭のコメントの一覧
- コマンドパレットの項目（`lua/palette.lua` の `ENTRIES`）→ README の「コマンドパレットの独自項目」
- nightly だけの設定を使ったとき → README の「使用している nightly 限定機能」の表
- よく変える値の場所を動かしたとき → README の「カスタマイズの勘所」、ファイルを足したとき → README の「ファイル構成」
- 導入のしかたが変わる変更（配置先、シェル統合の読み込み方・環境変数、`lua/shells.lua` の `set_environment_variables`）→ `docs/install.md` の手順と、補足の「状態」行・注意点
  - 例: AlmaLinux 10 の COPR 版は `/etc/profile.d/wezterm.sh`（公式の統合）が先に読まれ、`shell/wezterm.sh` はマウス報告よけだけになる。`WEZTERM_SHELL_SKIP_ALL=1` を渡すように変えたら、`docs/install.md` の手順 9 と注意点を書き直す

## コードの注意

- 設定の評価中に `wezterm.glob` / `wezterm.read_dir` を呼ばない（非同期で、`attempt to yield from outside a coroutine` で設定ごと落ちる）
- ファイルの有無は `lua/shells.lua` の `exists()` を使う（Microsoft Store 版の PowerShell 7 のアプリ実行エイリアスは `io.open` で開けないので、`os.rename` で補っている）
- Windows だけの探索（`USERPROFILE`・`C:/` 配下）は `is_windows` の分岐の中に置く（Linux / macOS で `nil` の連結で落ちたことがある）
- ファンシータブバー（タブ・ステータス）は WezTerm の描き方に合わせる
  - タブバー全体が 1 つのフォントで描かれ、`Intensity`（太字）・斜体は効かない
  - `format-tab-title` の `hover` はレトロタブバーの桁で判定されていて、位置がずれるので使わない。非アクティブなタブは色を付けず、`colors.tab_bar.inactive_tab` / `inactive_tab_hover` に任せる（最初のセルの背景がタブの箱の色になり、無ければこの 2 つが使われる）
  - ステータスは 1.75 行の高さで描かれるので、面で塗ったピルにしない（端の半円が縦長になる）
- `shell/wezterm.sh` は、既存の `PS1` / `PROMPT_COMMAND` を置き換えず前後に足すだけにする（Git Bash の `git-prompt.sh` のブランチ表示を残すため）。公式の統合があれば、マウス報告よけの後で抜ける
- Git Bash（MSYS2）から起動したプログラム（`vim`・`ssh` など）は、Windows 上で親プロセスが消えるので WezTerm から見えない（フォアグラウンドは常に `bash.exe`）。プロセス名に頼る判定は Git Bash では効かないので、シェル統合の印（OSC 133 の範囲・`WEZTERM_PROG`）を使う。`skip_close_confirmation_for_processes_named` に `bash.exe` を足さない（vim の編集中でも確認なしで閉じる）
- Git Bash では `$(…)` のサブシェル 1 回に約 10ms、外部コマンド（`cygpath`・`base64` など）1 回に 40〜55ms かかる。プロンプトごと・コマンドごとに動く処理では避ける（bash 5.3 の `${ …; }`、結果の使い回し）

## docs/install.md の書き方

setup-notes の手順書と同じ骨格にする。要点:

- タイトルの直後に `## 実施手順` を置き、手順は**番号付きリスト 1 つ**（マーカーはすべて `1.`、本文は 3 スペース字下げ）
  - リードの `> [!IMPORTANT]` に実行する場所・前提・対話や切り替えのある手順、続けて読み方の箇条書き、検証範囲の `> [!WARNING]`
  - 変数は置かない（URL と置き場所は固定）。変える必要の無い値はコマンドに直接書く
- 各手順は「1 行の説明（「〜する。」）→ コマンドのブロック → 箇条書き（確認・分岐・注意）→ 折り畳み 1 つ（`<details>` / `<summary>補足: 〜</summary>`、前後に空行）」
  - 箇条書きは 1 項目 1 事実で、末尾に「。」を付けない。理由・実測・出力例は折り畳みへ
  - 条件付きの手順は 1 行の説明に条件を書き、判定する手順の箇条書きに「〜なら、手順 N は飛ばす」、代わりに行う手順は「（手順 N の代わりに）」
  - コマンドの無い操作（WezTerm を起動し直す、`~/.ssh/config` をエディタで直す、別のタブで ssh する）も独立した手順にし、次にコマンドを貼る手順の直前に「**次の手順は、〜してから貼る**」を置く
  - `sudo` の後ろに行が続くブロックは `{` と `}` の行で囲む。`sudo` のパスワードを聞かれうる手順は「**次の手順は、`sudo` のパスワードを聞かれたら答えてから貼る**」で終える
  - `<...>` を含むコマンドはブロックに置かず、箇条書きのインラインコードにする。出力例の値は `<USER>` / `<HOST>` などのプレースホルダで書く
- 手順の後ろに任意の節（WSL・ssh 先）・`## 更新`・`## ロールバック`（リード → 番号付きリスト → `---`。節ごとに 1 から数える）、最後に `## 補足`（対象と検証環境・実施前の状態・選択した方針・完了時点の状態・注意点・参照・付録）
- 手順の参照は、`## 実施手順` の中では「手順 N」、ほかの節からは `[手順 N](#実施手順)`、その節の中は「この節の手順 N」。手順を分けたりまとめたりしたら番号を付け替える（README の `docs/install.md#実施手順` へのリンクの番号も）
- アラートは本文の最上位にだけ置き（リストや `<details>` の中では描画されない）、1 文書に 5 つまで。取り戻せない削除のある節は `> [!CAUTION]` で手順を名指しし、その手順の説明に「（取り戻せない）」
- 閉じの `**` を約物に接して閉じない（`**…（…）**を` は太字にならない）
- 補足の「状態」行は、何を通したか・確認したこと・確認していないことの入れ子の箇条書き。**検証範囲が変わったら、状態行・リードの `> [!WARNING]`・付録を合わせて直す**。付録（検証記録）は書き直さない（手順番号の付け替えだけ）
- コマンドは実際に実行したものを載せる。手順書のブロックを変えたら、コンテナなどで抜き出して流し直してから「検証済み」と書く
- パスワード・鍵・トークンは書かない

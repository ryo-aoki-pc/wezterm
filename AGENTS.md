# AGENTS.md

このリポジトリで作業するコーディングエージェント（Claude Code・Codex・Grok Build・Antigravity CLI）への指示。Claude Code は CLAUDE.md の `@AGENTS.md` で、Codex・Grok Build・Antigravity CLI はこのファイルを直接読む。

## 導入手順の正本

導入・設定・更新の手順は、setup-notes の [shell-terminal.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md) の「WezTerm」とその子の項（AlmaLinux 10）、「Windows 11 で WezTerm を入れる」「Git Bash と WezTerm の設定」とその子の項（Windows 11）にある。このリポジトリには置かない。共通 bash 設定が読むツールの初期化を、手順書で `~/.bashrc` に直接追記させない。

## このリポジトリは何か

[WezTerm](https://wezterm.org/) の nightly 向けの個人設定。Windows 11（既定のシェルは Git Bash）が主で、Linux（GNOME Wayland）と macOS でも同じ設定が動くように書いてある。`~/.config/wezterm`（Windows は `%USERPROFILE%\.config\wezterm`）に clone して使う。

- README は、冒頭の「導入」の表（正本の項への案内）と、機能・キー操作・シェル統合の仕組みの説明（参照用）
- MSYS2・QMK MSYS・zsh でシェル統合を読む 1 行は、README の「bash（Git Bash / MSYS2 / QMK MSYS / Linux）と zsh」にある

ビルド・テストフレームワークは無い（`tests/` は手で動かす検証の道具）。ドキュメント・コードのコメント・コミットメッセージは日本語で書く。検証していないことを「動く」と書かない。

## よく使うコマンド

設定の読み込み（`ls-fonts`）・キー割り当て（`show-keys`）・シェル統合の構文（`bash -n` / `zsh -n`）の確かめ方は、README の「動作確認」にある。`show-keys` は設定を読めなくても黙って既定の一覧を出すので、読み込みの確認には `ls-fonts` を使う。

- 画面の無い環境でシェル統合を試すときは、`wezterm-mux-server --daemonize` を起動し、`wezterm cli spawn` / `send-text --no-paste` / `get-text` / `list` を使う（非公開側の検証記録の `install.md` のコンテナ記録と同じ方法。設定の `set_environment_variables` が効き、シェルはログインシェルで起動する）
- AlmaLinux 10 のコンテナで WezTerm を入れるときは、setup-notes のシェルと端末のセットアップ（`docs/shell-terminal.md`）の「WezTerm」の手順 1〜4（COPR の `rhel-9-<arch>` を明示）

## 構成

- `wezterm.lua` — エントリポイント。`package.path` に `wezterm.config_dir .. "/lua/?.lua"` を足し、`lua/` の各モジュールの `apply(config)` を順に呼ぶ
- `lua/*.lua` — 1 モジュール 1 関心。`apply(config)` を持つのが基本で、`actions.lua`（キーとコマンドパレットで共有する操作）・`ui.lua`（共有定数・フォントの候補）・`procs.lua`（実行中のプログラムと ssh 中かの判定）は持たない
  - `colors.lua` の `palette` を、タブ・ステータスバーも参照する。色は `palette` だけを直す
  - `statusbar.lua` は、一時メッセージを出す `flash()` を公開している
  - `shells.lua` はシェル・WSL・SSH ホストを探して `launch_menu` / `default_prog` を組み立て、bash 系に環境変数 `WEZTERM_SHELL_INTEGRATION`（`shell/wezterm.sh` のパス）を渡し、PowerShell には `-NoExit -Command` で `shell/wezterm.ps1` を読ませる
- `shell/wezterm.sh` — bash / zsh のシェル統合（OSC 7・OSC 133・完了通知のユーザー変数・実行中のコマンドのユーザー変数 `WEZTERM_PROG`・迷子のマウス報告よけ）。`~/.bashrc` の 1 行で読む
- `shell/wezterm.ps1` — PowerShell のシェル統合。**UTF-8 の BOM 付き**で保存する（Windows PowerShell 5.1 は BOM の無い `.ps1` を ANSI として読み、日本語のコメントで構文エラーになる）
- `docs/extra/install.md` — 設定の注意点。`docs/reference/install.md` — 正本の手順の背景と選定理由、Windows の SSH 先への貼り付けの実装
- 非公開側の検証記録 — `install.md` は導入とシェル統合、`readme.md` は実機の記録、`starship/` は Starship との共存の報告書
- `tests/` — 手で動かす検証の道具（`paste/` は貼り付け、`starship/` は Starship との共存。`starship/verification-summary.json` は公開用の集計）

## 変えたら合わせて直すもの

- キー・マウスの割り当て（`lua/bindings.lua`）→ README の「機能早見表」「キーバインド」の表と、`lua/bindings.lua` の冒頭のコメントの一覧
- コマンドパレットの項目（`lua/palette.lua` の `ENTRIES`）→ README の「コマンドパレットの独自項目」
- nightly だけの設定を使ったとき → README の「使用している nightly 限定機能」の表
- よく変える値の場所を動かしたとき → README の「カスタマイズの勘所」、ファイルを足したとき → README の「ファイル構成」
- 導入のしかたが変わる変更（配置先、シェル統合の読み込み方・環境変数、`lua/shells.lua` の `set_environment_variables`）→ 正本の手順・README の「導入」の表・`docs/extra/install.md` の注意点。検証を行ったら非公開側の検証記録の `install.md` に対象版と結果を追加する
  - AlmaLinux 10 の COPR 版は `/etc/profile.d/wezterm.sh`（公式の統合）が先に読まれる。Bash では公式の cwd・ユーザー変数・bash-preexec を保ち、semantic の 2 callback だけを独自処理へ移して完了通知を補う。`WEZTERM_SHELL_SKIP_ALL=1` は渡さない。公式との担当や確かめ用の関数が変わったら、正本の「WezTerm の設定を導入する」の手順 6 と `docs/extra/install.md` の注意点を合わせる
  - シェル統合を読む 1 行や置き場所を変えたら、自分用の bash の設定（`ryo-aoki-pc/bash`）の `bashrc` も直す。その設定は、starship → この統合 → zoxide の順に読む（`PROMPT_COMMAND`・`PS0` の扱いを変えたら、bash リポジトリの検証記録にある「読む順番」の実測を取り直す）

## コードの注意

- 設定の評価中に `wezterm.glob` / `wezterm.read_dir` を呼ばない（非同期で、`attempt to yield from outside a coroutine` で設定ごと落ちる）
- ファイルの有無は `lua/shells.lua` の `exists()` を使う（Microsoft Store 版の PowerShell 7 のアプリ実行エイリアスは `io.open` で開けないので、`os.rename` で補っている）
- Windows だけの探索（`USERPROFILE`・`C:/` 配下）は `is_windows` の分岐の中に置く（Linux / macOS で `nil` の連結で落ちたことがある）
- ファンシータブバー（タブ・ステータス）は WezTerm の描き方に合わせる
  - タブバー全体が 1 つのフォントで描かれ、`Intensity`（太字）・斜体は効かない
  - `format-tab-title` の `hover` はレトロタブバーの桁で判定されていて、位置がずれるので使わない。非アクティブなタブは色を付けず、`colors.tab_bar.inactive_tab` / `inactive_tab_hover` に任せる（最初のセルの背景がタブの箱の色になり、無ければこの 2 つが使われる）
  - ステータスは 1.75 行の高さで描かれるので、面で塗ったピルにしない（端の半円が縦長になる）
- `shell/wezterm.sh` は、既存の `PS1` / `PROMPT_COMMAND` とユーザーのフックを保ち、前後に必要な印・処理だけ足す（Git Bash の `git-prompt.sh` のブランチ表示も残す）
  - 公式 Bash 統合では `__wezterm_semantic_precmd` / `__wezterm_semantic_preexec` の登録だけを外して独自の OSC 133 と完了通知へ移す。公式関数・cwd・ユーザー変数・bash-preexec dispatcher は温存し、Starship とユーザーの callback の順序を保つ
  - 既に有効な公式 Bash 統合は `TERM_PROGRAM` 未受信の SSH でも補完する。公式なしの経路は `TERM_PROGRAM=WezTerm` の条件を保つ。zsh・ble.sh・tmux、semantic を明示的に無効化した環境は公式へ任せる
  - 独自 OSC 7 は `__wz_osc7` の名前で定義し、公式の `__wezterm_osc7` は上書きしない。公式経路では公式の OSC 7 を使い、二重に送らない
  - bash-preexec dispatcher と Starship の後、`__bp_interactive_mode` の前にマウス解除と独自プロンプト処理を置く。初回 install 前は先頭要素の末尾、稼働中は mode 直前の独立した配列要素へ登録し、ユーザーの途中要素も保つ。再読込時は自分のフックだけを外して足し直す
  - 何度読まれてもよいように、フック・印は無いときだけ足す（フラグで早く抜けると、`.bashrc` を読み直して `PS1` / `PROMPT_COMMAND` が作り直されたときに統合が消える）
  - `set -u`（zsh は `setopt nounset`）でも動くよう、未設定かもしれない変数は `${変数-}` で参照する
  - `PS0`・`PS1` に足す印は BEL（`\007`）で終える。`ESC \`（`\033\\`）で終えると、bash が `\\` を `\` にしてから展開するので、後ろに続く元の `PS0`（starship の `${STARSHIP_START_TIME:…}` など）の先頭の `$` がエスケープされ、`${…}` が文字のまま画面に出る。`PS1` も、行編集が無いとき（`bash --noediting`・`set +o emacs +o vi`）は `\]` が消えて同じことが起きる
- OSC 7 のパスは WezTerm が URL として読む。`#` と `?` から後ろは捨てられ、`\` は `/` になるので、`%`・空白と合わせてパーセントエンコードする。PowerShell は ASCII 以外もエンコードする（`[Console]::Write` がコンソールのコード ページで書き出し、932 に無い文字が化ける）
- PowerShell の `prompt` をラップするときは、元の `prompt` を呼ぶ前に `$?` を戻す（oh-my-posh などは `$?` で失敗を表示する）
- `lua/shells.lua` の Windows のシェルには `domain = "DefaultDomain"` を付ける（既定の `CurrentPaneDomain` だと、WSL のペインから選んだとき WSL の中で起動しようとして閉じる）
- Git Bash（MSYS2）から起動したプログラム（`vim`・`ssh` など）は、Windows 上で親プロセスが消えるので WezTerm から見えない（フォアグラウンドは常に `bash.exe`）。プロセス名に頼る判定は Git Bash では効かないので、シェル統合の印（OSC 133 の範囲・`WEZTERM_PROG`）を使う。`skip_close_confirmation_for_processes_named` に `bash.exe` を足さない（vim の編集中でも確認なしで閉じる）
- Git Bash では `$(…)` のサブシェル 1 回に約 10ms、外部コマンド（`cygpath`・`base64` など）1 回に 40〜55ms かかる。プロンプトごと・コマンドごとに動く処理では避ける（bash 5.3 の `${ …; }`、結果の使い回し）

## 文書の置き場所

- 導入・利用・更新の手順は正本に置き、README の「導入」の表から正本の項へ直接リンクする（手順書の先頭やカテゴリの見出しへはリンクしない）。執筆規則は setup-notes の `docs/dev/writing-rules.md`
- `docs/extra/` は注意点。ロールバック（取り消し）の手順は書かない。`docs/reference/` は背景。検証記録（環境・日付・対象コミット・実出力・未確認事項）は、非公開の `ryo-aoki-pc/setup-notes-verification` の `repos/wezterm/docs/verification/` に置く。検証の報告書も非公開側の検証記録に置き、`tests/` には道具だけを置く
- 検証記録を書く・直すときは、`setup-notes-verification` を clone し、そちらへ Pull Request を作る
- 文書を移す・分ける・まとめるときは、移した経緯と、旧ファイル名・旧見出しとの対応を文書に書かない（経緯は git の履歴と Pull Request の本文に残す）。リンクを今の場所へ直す。中身が新しい場所への案内だけになったファイルは消す
- 残す検証記録の実施日・対象版・環境・出力・成功と失敗・未実施の範囲・記録したときの手順番号は書き換えない。再検証せずに検証範囲を広げない。記録の手順番号が今の手順と違い、本文を読むのに要るときだけ「記録の手順 | 今の手順」の表で結ぶ
- 操作を変えたら、正本・README の「導入」の表・参考資料を合わせて直す

# AGENTS.md

このリポジトリで作業するコーディングエージェント（Claude Code・Codex・Grok Build）への指示。Claude Code は CLAUDE.md の `@AGENTS.md` で、Codex と Grok Build はこのファイルを直接読む。

利用者への回答・質問・報告は、常に日本語で書く（コードのコメントなどの言語は、このファイルのほかの決まりに従う）。

## このリポジトリは何か

[WezTerm](https://wezterm.org/) の nightly 向けの個人設定。Windows 11（既定のシェルは Git Bash）が主で、Linux（GNOME Wayland）と macOS でも同じ設定が動くように書いてある。`~/.config/wezterm`（Windows は `%USERPROFILE%\.config\wezterm`）に clone して使う。

- 機能・キー操作・シェル統合の仕組みの説明は `README.md`（参照用）
- 導入の手順は `docs/install.md`（下の「docs/install.md の書き方」）
- 過去の検証環境・実施日・対象コミット・実出力・結果・未確認事項は `docs/verification/install.md`、選定理由と技術的説明は `docs/reference/install.md`

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

- 画面の無い環境でシェル統合を試すときは、`wezterm-mux-server --daemonize` を起動し、`wezterm cli spawn` / `send-text --no-paste` / `get-text` / `list` を使う（`docs/verification/install.md` のコンテナ記録と同じ方法。設定の `set_environment_variables` が効き、シェルはログインシェルで起動する）
- AlmaLinux 10 のコンテナで WezTerm を入れるときは、setup-notes の `docs/almalinux-setup.md` の「WezTerm」の手順 1〜4（COPR の `rhel-9-<arch>` を明示。もとは `docs/wezterm-nightly.md`）

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
- 導入のしかたが変わる変更（配置先、シェル統合の読み込み方・環境変数、`lua/shells.lua` の `set_environment_variables`）→ `docs/install.md` の手順と `docs/reference/install.md` の注意点。検証を行ったら `docs/verification/install.md` に対象版と結果を追加する
  - AlmaLinux 10 の COPR 版は `/etc/profile.d/wezterm.sh`（公式の統合）が先に読まれる。Bash では公式の cwd・ユーザー変数・bash-preexec を保ち、semantic の 2 callback だけを独自処理へ移して完了通知を補う。`WEZTERM_SHELL_SKIP_ALL=1` は渡さない。公式との担当や確かめ用の関数が変わったら、`docs/install.md` の手順 9 と `docs/reference/install.md` の注意点を合わせる
  - シェル統合を読む 1 行や置き場所を変えたら、自分用の bash の設定（`ryo-aoki-pc/bash`）の `bashrc`・`migrate/old-lines.txt` も直す。その設定は、starship → この統合 → zoxide の順に読む（`PROMPT_COMMAND`・`PS0` の扱いを変えたら、bash リポジトリの検証記録にある「読む順番」の実測を取り直す）

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
  - 既に有効な公式 Bash 統合は `TERM_PROGRAM` 未受信の SSH でも補完する。公式なしの経路は `TERM_PROGRAM=WezTerm` の条件を保つ。zsh・ble.sh・tmux、semantic を明示的に無効化した環境は従来どおり公式へ任せる
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

## docs/install.md の書き方

- タイトルの下に検証記録と参照情報へのリンクを置き、`## 実施手順`、任意の WSL・ssh、更新、ロールバックの順に並べる。手順書には手順と実行に必要な前提・分岐・注意・期待結果だけを載せる。
- 過去の検証環境・日付・コミット・実測・失敗・未確認事項は `docs/verification/install.md` に置く。検証記録の既存本文は実施時点のまま保持し、番号やリンクの追従で範囲を広げない。再検証したら対象版と範囲を明記して追加する。
- 選定理由・仕様・技術的な説明は `docs/reference/install.md` に置く。手順書へ背景説明の折り畳み・補足・検証付録は追加しない。
- 各節はリード → 番号付きリスト → `---` の順。マーカーはすべて `1.`、本文は 3 スペース字下げ。各手順は「1 行の説明（〜する。）→ bash のブロック → 確認・分岐・注意の箇条書き」にする。
- リードの `[!IMPORTANT]` に実行する場所・ユーザー・前提・対話や切り替えのある手順を示す。URL と置き場所は固定で、変える必要の無い変数は作らない。
- 条件付きの手順は説明に条件を書く。判定側に飛ばす手順を示し、代わりの手順は「（手順 N の代わりに）」と書く。コマンドの無いウィンドウ・エディタ・タブの操作も独立した手順にする。
- 待機や場所の切り替えがある手順の末尾は「**次の手順は、〜してから貼る**」。sudo の後ろに行が続くブロックは `{` と `}` で囲み、パスワード応答が要る手順は応答してから次を貼ることを書く。
- 箇条書きは 1 項目 1 事実、末尾に「。」を付けない。`<...>` を含むコマンドはブロックに置かずインラインコードにする。出力の期待値は `<USER>` / `<HOST>` などのプレースホルダで書く。
- 手順の参照は実施手順内では「手順 N」、他の節からは `[手順 N](docs/install.md#実施手順)`、同じ節では「この節の手順 N」。手順を変えたら README・参照情報・検証記録の番号とリンクを追従する。
- アラートは最上位にだけ置き、1 文書に 5 つまで。取り戻せない削除は節の `[!CAUTION]` と手順の説明で示す。閉じの `**` は約物に接して閉じない。
- 手順のコマンドを変更したら該当する分岐を実行して記録する。実行していないものを「検証済み」と書かない。パスワード・鍵・トークンは記載しない。

## 共同作業の規則

このリポジトリでは、Claude Code・Codex・Grok Build が同じ規則で作業する。分担と `main` への取り込みは人が決める。

- 起動された worktree（作業ディレクトリ）の中だけでファイルを変える。ほかの worktree のファイルは変えない
- 今のブランチにだけコミットする。`main` にはコミットも push もしない
- 頼まれた範囲のファイルだけを変える。範囲の外を変えるときは、変える前に理由を書いて確かめる
- 終わったら、テストとリンターを通してから、目的ごとにコミットする。通らなければコミットせずに、結果を報告する
- コミットしたら、今のブランチを push し、`main` への Pull Request を作る（既にあれば足す）。`main` への取り込み（マージ）とブランチの削除は人が行う。今のブランチに `main` を取り込むのは、頼まれたときと、Pull Request が競合したときだけ
- 秘密情報（`.env`・鍵・トークン・パスワード）を読まない・書かない・出力しない
- レビューを頼まれたら、ファイルを変えずに、指摘を「重大度・場所（ファイル:行）・理由・直し方」で挙げる
- ほかの担当の変更は、`git diff main...agent/codex` のように git で読む（ほかの worktree へ移らない）

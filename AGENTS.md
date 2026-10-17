# AGENTS.md

このリポジトリで作業するコーディングエージェント（Claude Code・Codex・Grok Build・Antigravity CLI）への指示。Claude Code は CLAUDE.md の `@AGENTS.md` で、Codex・Grok Build・Antigravity CLI はこのファイルを直接読む。

利用者への回答・質問・報告は、常に日本語で書く（コードのコメントなどの言語は、このファイルのほかの決まりに従う）。

## 導入手順の正本

導入・設定・更新の手順は、setup-notes の [shell-terminal.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md) の「WezTerm」とその子の項（AlmaLinux 10）、「Windows 11 で WezTerm を入れる」「Git Bash と WezTerm の設定」とその子の項（Windows 11）にある。SSH 先の PowerShell は、windows-setup.md の [SSH で管理者・非管理者の PowerShell を使う](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-setup.md#ssh-で管理者非管理者の-powershell-を使う)にある。このリポジトリには置かない。共通 bash 設定が読むツールの初期化を、手順書で `~/.bashrc` に直接追記させない。

## このリポジトリは何か

[WezTerm](https://wezterm.org/) の nightly 向けの個人設定。Windows 11（既定のシェルは Git Bash）が主で、Linux（GNOME Wayland）と macOS でも同じ設定が動くように書いてある。`~/.config/wezterm`（Windows は `%USERPROFILE%\.config\wezterm`）に clone して使う。

- README は、冒頭の「導入」の表（正本の項への案内）と、機能・キー操作・シェル統合の仕組みの説明（参照用）
- MSYS2・QMK MSYS・zsh でシェル統合を読む 1 行は、README の「bash（Git Bash / MSYS2 / QMK MSYS / Linux）と zsh」にある

ビルド・テストフレームワークは無い（`tests/` は手で動かす検証の道具）。ドキュメント・コードのコメント・コミットメッセージは日本語で書く。検証していないことを「動く」と書かない。

## よく使うコマンド

設定の読み込み（`ls-fonts`）・キー割り当て（`show-keys`）・シェル統合の構文（`bash -n` / `zsh -n`）の確かめ方は、README の「動作確認」にある。`show-keys` は設定を読めなくても黙って既定の一覧を出すので、読み込みの確認には `ls-fonts` を使う。

- 画面の無い環境でシェル統合を試すときは、`wezterm-mux-server --daemonize` を起動し、`wezterm cli spawn` / `send-text --no-paste` / `get-text` / `list` を使う（`docs/verification/install.md` のコンテナ記録と同じ方法。設定の `set_environment_variables` が効き、シェルはログインシェルで起動する）
- AlmaLinux 10 のコンテナで WezTerm を入れるときは、setup-notes のシェルと端末のセットアップ（`docs/shell-terminal.md`）の「WezTerm」の手順 1〜4（COPR の `rhel-9-<arch>` を明示）

## 構成

- `wezterm.lua` — エントリポイント。`package.path` に `wezterm.config_dir .. "/lua/?.lua"` を足し、`lua/` の各モジュールの `apply(config)` を順に呼ぶ
- `lua/*.lua` — 1 モジュール 1 関心。`apply(config)` を持つのが基本で、`actions.lua`（キーとコマンドパレットで共有する操作）・`ui.lua`（共有定数・フォントの候補）・`procs.lua`（実行中のプログラムと ssh 中かの判定）は持たない
  - `colors.lua` の `palette` を、タブ・ステータスバーも参照する。色は `palette` だけを直す
  - `statusbar.lua` は、一時メッセージを出す `flash()` を公開している
  - `shells.lua` はシェル・WSL・SSH ホストを探して `launch_menu` / `default_prog` を組み立て、bash 系に環境変数 `WEZTERM_SHELL_INTEGRATION`（`shell/wezterm.sh` のパス）を渡し、PowerShell には `-NoExit -Command` で `shell/wezterm.ps1` を読ませる
- `shell/wezterm.sh` — bash / zsh のシェル統合（OSC 7・OSC 133・完了通知のユーザー変数・実行中のコマンドのユーザー変数 `WEZTERM_PROG`・迷子のマウス報告よけ）。`~/.bashrc` の 1 行で読む
- `shell/wezterm.ps1` — PowerShell のシェル統合。**UTF-8 の BOM 付き**で保存する（Windows PowerShell 5.1 は BOM の無い `.ps1` を ANSI として読み、日本語のコメントで構文エラーになる）
- `docs/extra/install.md` — 設定のロールバックと注意点。`docs/reference/install.md` — 正本の手順の背景と選定理由、Windows の SSH 先への貼り付けの実装
- `docs/verification/` — 検証記録（`install.md` は導入とシェル統合、`readme.md` は実機の記録、`starship/` は Starship との共存の報告書）
- `tests/` — 手で動かす検証の道具（`paste/` は貼り付け、`starship/` は Starship との共存。`starship/verification-summary.json` は公開用の集計）

## 変えたら合わせて直すもの

- キー・マウスの割り当て（`lua/bindings.lua`）→ README の「機能早見表」「キーバインド」の表と、`lua/bindings.lua` の冒頭のコメントの一覧
- コマンドパレットの項目（`lua/palette.lua` の `ENTRIES`）→ README の「コマンドパレットの独自項目」
- nightly だけの設定を使ったとき → README の「使用している nightly 限定機能」の表
- よく変える値の場所を動かしたとき → README の「カスタマイズの勘所」、ファイルを足したとき → README の「ファイル構成」
- 導入のしかたが変わる変更（配置先、シェル統合の読み込み方・環境変数、`lua/shells.lua` の `set_environment_variables`）→ 正本の手順・README の「導入」の表・`docs/extra/install.md` の注意点。検証を行ったら `docs/verification/install.md` に対象版と結果を追加する
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
- `docs/extra/` はロールバックと注意点、`docs/reference/` は背景、`docs/verification/` は検証記録（環境・日付・対象コミット・実出力・未確認事項）。検証の報告書も `docs/verification/` に置き、`tests/` には道具だけを置く
- 文書を移す・分ける・まとめるときは、移した経緯と、旧ファイル名・旧見出しとの対応を文書に書かない（経緯は git の履歴と Pull Request の本文に残す）。リンクを今の場所へ直す。中身が新しい場所への案内だけになったファイルは消す
- 残す検証記録の実施日・対象版・環境・出力・成功と失敗・未実施の範囲・記録したときの手順番号は書き換えない。再検証せずに検証範囲を広げない。記録の手順番号が今の手順と違い、本文を読むのに要るときだけ「記録の手順 | 今の手順」の表で結ぶ
- 操作を変えたら、正本・README の「導入」の表・参考資料を合わせて直す

## 共同作業の規則

このリポジトリでは、Claude Code・Codex・Grok Build・Antigravity CLI が同じ規則で作業する。分担は人が決める。

- 起動された worktree（作業ディレクトリ）の中だけでファイルを変える。ほかの worktree のファイルは変えない
- 今のブランチにだけコミットする。`main` にはコミットも push もしない
- 頼まれた範囲のファイルだけを変える。範囲の外を変えるときは、変える前に理由を書いて確かめる
- 終わったら、テストとリンターを通してから、目的ごとにコミットする。通らなければコミットせずに、結果を報告する
- コミットしたら、今のブランチを push し、`main` への Pull Request を作る（既にあれば足す）。今のブランチに `main` を取り込むのは、頼まれたときと、Pull Request が競合したときだけ
- `main` への取り込み（マージ）は、エージェントが行ってよい。テストとリンターが通り、Pull Request が競合していなければ、`gh pr merge --squash` で Pull Request を取り込む（手元の `main` にはコミットも push もしない）。利用者が取り込まないよう頼んだときは取り込まず、そのことを報告する。取り込んだブランチには、その後コミットも push もせず、次の作業は新しいブランチで始める
  - リモートのブランチ: 取り込んだ Pull Request のブランチは、GitHub が自動で消す（リポジトリの Automatically delete head branches）。取り込む前に `gh api 'repos/{owner}/{repo}' --jq .delete_branch_on_merge` で確かめ、`false` なら `gh api -X PATCH 'repos/{owner}/{repo}' -F delete_branch_on_merge=true` で有効にする（`{owner}/{repo}` は gh が今のリポジトリで埋めるので、そのまま打つ）。取り込んだ後もリモートに残った自分のブランチは、`git push origin --delete <ブランチ>` で消す
  - 手元のブランチ: 自分が作ったブランチは、Pull Request が取り込まれたこと（`gh pr view <番号> --json state` が `MERGED`）と、どの worktree でも使っていないこと（`git worktree list`）を確かめてから、`git branch -D <ブランチ>` で消す（squash で取り込むので `git branch -d` は通らない）。今いるブランチは、新しいブランチへ移ってから消す。ほかの担当のブランチは消さない
  - Claude Code の worktree とブランチ: セッションの worktree は、Pull Request が閉じるとアプリがセッションをアーカイブして消す（Claude Code の設定の Auto-archive sessions when their pull request closes を有効にしておく。消えることはアプリの設定の説明による。コミットしていない変更がある worktree は残る）。残った `claude/` のブランチは、ほかの担当のブランチを消さない決まりの例外とする。Claude Code は、ほかのセッションが作ったものも、Pull Request が取り込まれたこと（`gh pr list --head <ブランチ> --state merged` に出る）と、どの worktree でも使っていないこと（`git worktree list`）を確かめてから、手元は `git branch -D <ブランチ>`、リモートに残っていれば `git push origin --delete <ブランチ>` で消す
- 秘密情報（`.env`・鍵・トークン・パスワード）を読まない・書かない・出力しない
- レビューを頼まれたら、ファイルを変えずに、指摘を「重大度・場所（ファイル:行）・理由・直し方」で挙げる
- ほかの担当の変更は、`git diff main...agent/codex` のように git で読む（ほかの worktree へ移らない）

## 既定の分担

利用者が Claude Code に、分担を指定せずにファイルを変える作業を頼んだときは、Claude Code が取りまとめて次の 4 つで分担する。「共同作業の規則」の「分担は人が決める」で、人が分担を決めていないときの既定にする。利用者がほかのエージェントに直接頼んだときは、この節は使わず「共同作業の規則」に従う。

- Claude Code だけで行うもの: 利用者の質問への答え、ファイルを変えない調べもの、1 つのファイルの数行で振る舞いを変えない直し（誤字・リンク・値の直しなど）
- Claude Code: 計画・実機での確かめ・ほかの 3 つへの依頼・指摘の確かめ・統合・コミットと Pull Request・取り込み
- Codex: 実装と下書き。Claude Code が用意した別の clone か worktree の中だけで書く。この分担で頼まれたときは、「共同作業の規則」のコミット・push・Pull Request・取り込みを行わず、変更を残して報告する（Claude Code が確かめ、自分の worktree に移してからコミットする）
- Grok Build: 差分の読み取り専用のレビュー。ファイルを変えない（Windows 11 では、Claude Code は `--always-approve` を付けずに頼む）
- Antigravity CLI: 差分の読み取り専用のレビューと、その作業のための調べもの。ファイルを変えない（Claude Code は、入力を写した使い捨てのフォルダーで 1 回だけ実行し、`--dangerously-skip-permissions`・`--mode` を付けない）
- Claude Code から頼まれたエージェントは、上の自分の役割の範囲で作業する
- レビューの指摘は、実物で確かめてから採る。採らなかった指摘は、理由を付けて報告する
- 使えないエージェント（入っていない・ログインが切れた）は飛ばし、そのことを報告する
- 頼み方は、[setup-notes](https://github.com/ryo-aoki-pc/setup-notes) の `docs/ai-agents.md` の「コーディングエージェントの共同作業: Windows 11 で既定で分担する」と、`docs/reference/coding-agents.md` の「既定の分担」

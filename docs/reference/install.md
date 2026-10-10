# WezTerm 設定導入の参照情報

[手順書](../install.md) / [検証記録](../verification/install.md) / [機能とキー操作](../../README.md)

## 手順の背景と実装の説明

### 実施手順 — 手順 1: 2 つの置き場所

- WezTerm は `~/.wezterm.lua` を `~/.config/wezterm/wezterm.lua` より先に探し、見つけた 1 つだけを読む（setup-notes の [wezterm-nightly.md の「設定ファイルの探索順序（実測）」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/verification/wezterm-nightly.md#設定ファイルの探索順序実測)）
- `~/.wezterm.lua` が残っていると、この設定は読まれない

### 実施手順 — 手順 3: `~/.config/wezterm` に置く理由

- `wezterm.lua` は、`lua/` のモジュールを `wezterm.config_dir`（`wezterm.lua` のあるディレクトリ）から読む。シェル統合のスクリプトも、同じディレクトリの `shell/` を指す。1 ファイルの `~/.wezterm.lua` には置けない
- 手順 6 の 1 行は、`$HOME/.config/wezterm` を既定の置き場所として書いてある。別の場所に置くなら、その 1 行も書き換える

### 実施手順 — 手順 5: starship の行より後ろ、zoxide の行より前に置く理由

- starship は、直前の終了コードとパイプ各要素の終了コード（`PIPESTATUS`）を先に保存し、`PS1` を毎回作り直す。統合は `PROMPT_COMMAND` の後ろにフックを足し、starship が保存した終了コードを OSC 133 の `D` と完了通知に使う
- 統合は `PS1` の OSC 133 の印（`A` / `B`）をプロンプトごとに付け直す。starship のプロンプトとパイプ個別ステータス表示を保ちながら、WezTerm にプロンプト・入力・出力の範囲を伝える
- zoxide はいちばん最後に初期化する（共通の bash 設定が starship → WezTerm → zoxide の順に読む。setup-notes の [AlmaLinux 10 の初期設定の注意点](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/extra/almalinux-setup.md#注意点)）
- 前の版のこの文書（2026-09-30 まで）は、この 1 行を starship の行の前に差し込んでいた。そのホストは、当時の setup-notes の starship.md の手順 3〜6 で starship の行を前へ移した（今は [AlmaLinux 10 の初期設定](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md)にまとめ、順番は共通の bash 設定が持つ）

### 実施手順 — 手順 6: 1 行の中身

- `WEZTERM_SHELL_INTEGRATION` は、この設定の WezTerm が起動するシェルに渡す環境変数で、`shell/wezterm.sh` のパスが入る（`lua/shells.lua` の `set_environment_variables`）
- 変数が無いとき（tmux や ssh を挟むと届かない）は、`$HOME/.config/wezterm/shell/wezterm.sh` を読む
- WezTerm は bash をログインシェル（`-l`）で起動するので、`--rcfile` では読ませられない。そのため `~/.bashrc` に書く
- PowerShell は、`lua/shells.lua` が起動引数（`-Command`）で `shell/wezterm.ps1` を読ませるので、プロファイルに足すものは無い
- 公式統合が無い場合、WezTerm 以外の端末では迷子のマウス報告よけ（README）だけを動かす。既に有効な公式 Bash 統合がある場合は、それを補完する

### ssh 先でもシェル統合を使う（任意） — 手順 2: AlmaLinux 10 の sshd の既定と、検証コンテナでの出力

- AlmaLinux 10.2 の既定の sshd は、`AcceptEnv` を 1 つも持たない（`sshd -T` に `acceptenv` の行が出ない）
- `/etc/ssh/sshd_config` の `Include /etc/ssh/sshd_config.d/*.conf` が、このファイルを読む。`AcceptEnv` は、ほかの行やファイルにあっても足し合わされる

## 全体の参照情報


### 対象と検証環境

- **目的**: この設定（[ryo-aoki-pc/wezterm](https://github.com/ryo-aoki-pc/wezterm)）を `~/.config/wezterm` に置き、bash のシェル統合を読ませる。AlmaLinux 10 と Windows 11 の Git Bash で、同じコマンドにする
- **進め方**: git で clone し、`~/.bashrc` に 1 行を足す。**読者が書き換える変数は無い**（リポジトリの URL と置き場所は固定）
### 選択した方針

- **`~/.config/wezterm` に git で clone する**
  - `lua/` と `shell/` を `wezterm.config_dir` から読むので、ディレクトリごと置く
  - 更新は `git pull` で、手元で変えたところは `git diff` で見られる
  - Windows の WezTerm も `%USERPROFILE%\.config\wezterm\wezterm.lua` を読む。設定はディレクトリごと置く
- **シェル統合は `~/.bashrc` の 1 行**
  - PowerShell には起動引数で読ませられるが、bash はログインシェルで起動するので `--rcfile` を使えない
  - tmux・ssh を挟むと環境変数が届かないので、既定の置き場所をフォールバックにした
- **既にある設定は、消さずに `.bak` に退避する**
  - `~/.wezterm.lua` が残るとこの設定が読まれないので、`~/.config/wezterm` と合わせて退避する
  - [ロールバック](../install.md#ロールバック)の手順 4 で戻せる
- **AlmaLinux 10 の公式のシェル統合は止めない**
  - 公式 Bash 統合の cwd・ユーザー変数・bash-preexec を保ち、semantic の 2 フックだけを独自処理へ移す。`WEZTERM_SHELL_SKIP_ALL=1` を渡す設定は加えない（[注意点](#注意点)）
- **Windows は、Git Bash に同じ bash のブロックを貼る**（setup-notes の git.md と同じ）

### 完了時点の状態

| 場所 | 中身 |
|---|---|
| `~/.config/wezterm` | このリポジトリの clone（`main`） |
| `~/.bashrc` | 末尾（zoxide の行があればその上）に、シェル統合の 1 行 |
| `~/.wezterm.lua.bak` / `~/.config/wezterm.bak` | 手順 2 で退避したときだけ |
| （ssh 先）`/etc/ssh/sshd_config.d/50-wezterm.conf` | `AcceptEnv TERM_PROGRAM` の 1 行 |

- WezTerm が起動したシェルは、[手順 9](../install.md#実施手順) で確かめる

### 注意点

- **AlmaLinux 10（COPR の WezTerm）の公式 Bash 統合と共存する**
  - `wezterm-common` の `/etc/profile.d/wezterm.sh` は、`TERM_PROGRAM` を見ずに、すべての対話シェルで読まれる（ログインシェルは `/etc/profile`、そうでないシェルは `/etc/bashrc` から）
  - `shell/wezterm.sh` は、公式の semantic の 2 フック（`__wezterm_semantic_precmd` / `__wezterm_semantic_preexec`）だけを独自処理へ移す。公式の cwd・ユーザー変数・bash-preexec と、Starship / ユーザーのフックは保つ
  - 今のディレクトリ（OSC 7）は公式側が送り、プロンプト・入力・出力の印（OSC 133）と長いコマンドの完了通知は独自処理が送る。独自 OSC 7 は `__wz_osc7` とし、公式の `__wezterm_osc7` を上書きしない
  - 既に有効な公式 Bash 統合があれば、SSH 先で `TERM_PROGRAM` が未設定でも補完する。zsh・ble.sh・tmux、semantic を明示的に無効化した環境は従来どおり公式へ任せる
  - 公式の統合は `WEZTERM_SHELL_SKIP_ALL=1` で止まる。この設定の `lua/shells.lua` は、この値を渡していない
- **WezTerm は nightly が要る**
  - stable では、nightly だけの設定（README の「使用している nightly 限定機能」）が `ERROR  wezterm_gui >` になり、組み込みの既定の設定で開く見込み
- **`~/.wezterm.lua` があると、`~/.config/wezterm` は読まれない**
  - Windows では、`wezterm.exe` と同じフォルダーの `wezterm.lua` も探される（公式の [Configuration Files](https://wezterm.org/config/files.html)）
- **starship と一緒に使うとき**: シェル統合の行は、starship の行より後ろに置く
  - starship が終了コードと `PIPESTATUS` を保存してから、統合のフックを動かす。OSC 133 の `D` と完了通知にはその終了コードを使い、`PS1` の `A` / `B` は毎回付け直す
  - 公式 Bash 統合では、bash-preexec が終了コードとパイプ状態を保存し、Starship がプロンプトを作り直した後に独自処理を呼ぶ。公式 semantic フックは外して OSC 133 の二重送信を防ぐ
  - 公式の bash-preexec 経路で starship だけを直接再初期化する場合は、この統合も続けて読み直す。再初期化だけで重なる登録を各 1 個へ戻す。通常の個人 Bash 設定は starship の再初期化をガードしている
  - 前の版でシェル統合を starship より先に読んでいるホストは、[手順 5](../install.md#実施手順)に従って並びを直し、新しいタブを開く
- **Git Bash の `~/.bash_profile`**
  - WezTerm は Git Bash をログインシェル（`-l`）で起動するので、`~/.bashrc` は `~/.bash_profile` から読まれる必要がある
  - Git for Windows は、`~/.bashrc` があって `~/.bash_profile` などが無いと、`~/.bashrc` を読む `~/.bash_profile` を作り、`WARNING: Found ~/.bashrc but no ~/.bash_profile` と表示する
- **MSYS2・QMK MSYS は、ホームが別**
  - `C:\msys64\home\<WIN_USER>\.bashrc` と `C:\QMK_MSYS\home\<WIN_USER>\.bashrc` にも、手順 6 の 1 行を足す（README の「bash（Git Bash / MSYS2 / QMK MSYS / Linux）と zsh」）
- **完了通知は、OS の通知の設定にも従う**
  - Windows は「設定 → システム → 通知」で WezTerm が許されているか、集中モードになっていないかを見る（README の「長いコマンドの完了通知」）

### 参照

- [README](../../README.md) — この設定の機能・キー操作・シェル統合の仕組み
- setup-notes の [wezterm-nightly.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/wezterm-nightly.md) — WezTerm nightly の導入と、設定ファイルの探索順序の実測
- setup-notes の [git.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/git.md)・[hackgen.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/hackgen.md)・[almalinux-setup.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md)（starship・zoxide。もとは starship.md・zoxide.md）
- [Configuration Files — WezTerm](https://wezterm.org/config/files.html) — 設定ファイルの置き場所
- [Shell Integration — WezTerm](https://wezterm.org/shell-integration.html) — 公式のシェル統合と `WEZTERM_SHELL_SKIP_ALL`
- `man sshd_config`（`AcceptEnv`）・`man ssh_config`（`SendEnv`）

---

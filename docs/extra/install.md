# WezTerm の設定の注意点

setup-notes の[WezTerm の設定を導入する](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#wezterm-の設定を導入する)・[Windows 11 で WezTerm の設定を導入する](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#windows-11-で-wezterm-の設定を導入する)などで入れるときの注意点。背景は[参考資料](../reference/install.md)、検証は[検証記録](https://github.com/ryo-aoki-pc/setup-notes-verification/blob/main/repos/wezterm/docs/verification/install.md#修正後の状態2026-10-06)。リンクの付いた「手順 N」は正本の項の手順を指す。

## 注意点

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
- **Git Bash の `~/.bash_profile`**
  - WezTerm は Git Bash をログインシェル（`-l`）で起動するので、`~/.bashrc` は `~/.bash_profile` から読まれる必要がある
  - Git for Windows は、`~/.bashrc` があって `~/.bash_profile` などが無いと、`~/.bashrc` を読む `~/.bash_profile` を作り、`WARNING: Found ~/.bashrc but no ~/.bash_profile` と表示する
- **MSYS2・QMK MSYS は、ホームが別**
  - `C:\msys64\home\<WIN_USER>\.bashrc` と `C:\QMK_MSYS\home\<WIN_USER>\.bashrc` に、シェル統合を読む 1 行を足す（README の「[bash（Git Bash / MSYS2 / QMK MSYS / Linux）と zsh](../../README.md#bashgit-bash--msys2--qmk-msys--linuxと-zsh)」）
- **完了通知は、OS の通知の設定にも従う**
  - Windows は「設定 → システム → 通知」で WezTerm が許されているか、集中モードになっていないかを見る（README の「長いコマンドの完了通知」）

---

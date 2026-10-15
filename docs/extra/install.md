# WezTerm の設定のロールバックと注意点

setup-notes の[WezTerm の設定を導入する](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#wezterm-の設定を導入する)・[Windows 11 で WezTerm の設定を導入する](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#windows-11-で-wezterm-の設定を導入する)などで入れたものを戻す。背景は[参考資料](../reference/install.md)、検証は[検証記録](../verification/install.md#修正後の状態2026-10-06)。「この節の手順 N」はこの文書の手順、リンクの付いた「手順 N」は正本の項の手順を指す。

## ロールバック

- この文書で足したものを外す。WezTerm 本体は消さない（消すなら setup-notes の [AlmaLinux 10 の初期設定のロールバックの「端末とエディタを消す」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/extra/almalinux-setup.md#端末とエディタを消す)。Windows 11 は[「OpenSSH・Git for Windows・Firefox・WezTerm を外す」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/extra/windows-setup.md#opensshgit-for-windowsfirefoxwezterm-を外す)）

> [!IMPORTANT]
> - **自分のユーザーの bash で行う**。`sudo -i`・`su -` で開いた root のシェルには貼らない
> - 手順 1〜3 はこの PC で行い、Windows 11 は **Git Bash** に貼る
> - **手順 4 は WSL のシェルだけ**に貼る。WSL に手順 1〜3 は貼らない
> - **手順 5 は ssh 先のシェルだけ**に貼る。手元の PC には貼らない
> - 手順 5 の前に、ssh 先の端末で `sudo -v` を手で入力し、認証を終えてプロンプトに戻るまで待つ。認証できなければ中断する
> - **パスワード入力中は後続の行を貼らない**。入力を終え、プロンプトに戻ってから進む

> [!CAUTION]
> **この節の手順 2 は、`~/.config/wezterm` を消す**。手元で変えて commit・push していないものは取り戻せない。この節の手順 1 で確かめてから貼る。

1. 設定のリポジトリに、手元だけの変更が無いか確かめる。

   ```bash
   git -C ~/.config/wezterm status --short --branch
   ```

   - `## main...origin/main` の 1 行だけなら、手元だけの変更は無い
   - ほかの行や `[ahead 1]` などが出たら、要るものを別の場所へ写してから、この節の手順 2 へ進む

1. 設定を消す（取り戻せない）。

   ```bash
   rm -rf ~/.config/wezterm
   ls -ld ~/.config/wezterm
   ```

   - `No such file or directory` と出る
   - WezTerm は、次に起動したときから組み込みの既定の設定で開く（この節の手順 3 で戻したときは、戻した設定）

1. [手順 2](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#wezterm-の設定を導入する)（Windows 11 は[手順 3](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#windows-11-で-wezterm-の設定を導入する)）で退避したときだけ、元の設定を戻す。

   ```bash
   for f in ~/.wezterm.lua ~/.config/wezterm; do
     if [ -e "$f" ]; then echo "中断: $f が既にある" >&2
     elif [ -e "$f.bak" ]; then mv -v "$f.bak" "$f"
     fi
   done
   ```

   - 戻したものだけ、`renamed '/home/<USER>/.config/wezterm.bak' -> '/home/<USER>/.config/wezterm'` のように出る

1. [WezTerm のシェル統合を WSL で使う](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#wezterm-のシェル統合を-wsl-で使う)を通したときだけ、WSL のシェルで、WSL の `~/.bashrc` の行を消す。

   ```bash
   sed -i '\#/.config/wezterm/shell/wezterm.sh#d' ~/.bashrc
   grep -c '/.config/wezterm/shell/wezterm.sh' ~/.bashrc
   ```

   - `0` と出ればよい

1. [WezTerm のシェル統合を SSH 先で使う](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#wezterm-のシェル統合を-ssh-先で使う)を通したときだけ、ssh 先で、sshd の設定を消す。

   ```bash
   {
     sudo rm -v /etc/ssh/sshd_config.d/50-wezterm.conf
     sudo sshd -t && sudo systemctl reload sshd
   }
   ```

   - `removed '/etc/ssh/sshd_config.d/50-wezterm.conf'` と出る
   - ssh 先の `~/.config/wezterm` は、ssh 先でこの節の手順 1・2 を貼って消す
   - 手元の `~/.ssh/config` に足した `SendEnv TERM_PROGRAM` の行は、エディタで消す

---

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

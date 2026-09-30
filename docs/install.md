# WezTerm の設定の導入手順（AlmaLinux 10 / Windows 11 の Git Bash）

## 実施手順

> [!IMPORTANT]
> - **自分のユーザーのシェルで貼る**。`sudo -i` した root のシェルでは貼らない（設定と `~/.bashrc` が root のホームに置かれるため）
> - **Windows 11 では、Git for Windows の Git Bash に同じブロックを貼る**。PowerShell や cmd には貼らない（bash の構文のため）
> - **前提**: WezTerm の nightly と git が入っていること
>   - AlmaLinux 10: setup-notes の [wezterm-nightly.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/wezterm-nightly.md) と [git.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/git.md)
>   - Windows 11: WezTerm の [nightly のリリース](https://github.com/wezterm/wezterm/releases/tag/nightly)のインストーラと、[Git for Windows](https://gitforwindows.org/)
> - **手順 8 は、WezTerm を閉じて起動し直す操作**。手順 9 は、起動し直した WezTerm のタブで貼る

- 上から順にコードブロックを貼る
- フォントの HackGen Console NF は任意（無くてもほかのフォントで動く）。AlmaLinux 10 は setup-notes の [hackgen.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/hackgen.md) で入れる
- 各手順の末尾の「補足」（折り畳み）と後半の[補足](#補足)は、実行するだけなら読まなくてよい。折り畳みの中のブロックも貼らなくてよい
- 手順の後: WSL や ssh 先でも使うなら[WSL でもシェル統合を使う（任意）](#wsl-でもシェル統合を使う任意)・[ssh 先でもシェル統合を使う（任意）](#ssh-先でもシェル統合を使う任意)。以後は[更新](#更新)・[ロールバック](#ロールバック)
- 機能とキー操作は [README](../README.md) にある

> [!WARNING]
> **AlmaLinux 10 は x86_64 のコンテナでのみ検証した**（WezTerm の画面は出さず、mux サーバーで開いたシェルで確かめた）。**実機・Windows 11・WSL では試していない**。詳しくは[対象と検証環境](#対象と検証環境)。

1. 既存の WezTerm の設定があるか確かめる。

   ```bash
   ls -ld ~/.wezterm.lua ~/.config/wezterm
   ```

   - どちらかが出たら、手順 2 で退避する
   - 2 行とも `No such file or directory` なら、設定は無い。手順 2 は飛ばす

   <details>
   <summary>補足: 2 つの置き場所</summary>

   - WezTerm は `~/.wezterm.lua` を `~/.config/wezterm/wezterm.lua` より先に探し、見つけた 1 つだけを読む（setup-notes の [wezterm-nightly.md の「設定ファイルの探索順序（実測）」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/wezterm-nightly.md#設定ファイルの探索順序実測)）
   - `~/.wezterm.lua` が残っていると、この設定は読まれない
   - Windows でも、WezTerm は `%USERPROFILE%\.wezterm.lua` と `%USERPROFILE%\.config\wezterm\wezterm.lua` を探す。Git Bash の `~` は `%USERPROFILE%` なので、同じコマンドで見られるはず（試していない）

   </details>

1. 既存の設定があるときだけ、名前の後ろに `.bak` を付けて退避する。

   ```bash
   for f in ~/.wezterm.lua ~/.config/wezterm; do
     if [ -e "$f.bak" ]; then echo "中断: $f.bak が既にある" >&2
     elif [ -e "$f" ]; then mv -v "$f" "$f.bak"
     fi
   done
   ls -ld ~/.wezterm.lua ~/.config/wezterm
   ```

   - あったものだけ、`renamed '/home/<USER>/.config/wezterm' -> '/home/<USER>/.config/wezterm.bak'` のように出る
   - 最後の `ls` が 2 行とも `No such file or directory` ならよい
   - `中断:` と出たら、前に作った `.bak` を片付けて（要らなければ消して）から貼り直す
   - 退避したものは、[ロールバック](#ロールバック)の手順 4 で戻せる

1. この設定を `~/.config/wezterm` に clone する。

   ```bash
   git clone https://github.com/ryo-aoki-pc/wezterm.git ~/.config/wezterm
   git -C ~/.config/wezterm log -1 --oneline
   ```

   - `Cloning into '/home/<USER>/.config/wezterm'...` の後に、最新のコミットが 1 行出る
   - `fatal: destination path '/home/<USER>/.config/wezterm' already exists and is not an empty directory.` と出たら、手順 1 から見直す

   <details>
   <summary>補足: <code>~/.config/wezterm</code> に置く理由</summary>

   - `wezterm.lua` は、`lua/` のモジュールを `wezterm.config_dir`（`wezterm.lua` のあるディレクトリ）から読む。シェル統合のスクリプトも、同じディレクトリの `shell/` を指す。1 ファイルの `~/.wezterm.lua` には置けない
   - 手順 6 の 1 行は、`$HOME/.config/wezterm` を既定の置き場所として書いてある。別の場所に置くなら、その 1 行も書き換える
   - Git Bash のホームは `/c/Users/<WIN_USER>`（setup-notes の [windows-openssh-server.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-openssh-server.md) の実測）なので、Windows では `C:\Users\<WIN_USER>\.config\wezterm` に置かれるはず（試していない）

   </details>

1. WezTerm がこの設定を読めるか確かめる。

   ```bash
   wezterm ls-fonts --text 'aあ'
   ```

   - `ERROR  wezterm_gui >` で始まる行が無ければ、設定を読めている
   - HackGen Console NF が入っていれば、2 文字とも `wezterm.font("HackGen Console NF", ...)` の行が出る
   - 入っていなければ、`Unable to load a font specified by your font=wezterm.font('HackGen Console NF', ...)` と出て、ほかのフォントで描く（設定の誤りではない）
   - そのとき画面の無いシェル（ssh など）では、`ERROR  wezterm_toast_notification::dbus` も出ることがある。フォントの警告を通知に出せなかっただけで、設定の誤りではない
   - Windows で `wezterm: command not found` と出たら、`"/c/Program Files/WezTerm/wezterm.exe" ls-fonts --text 'aあ'` のようにインストール先から呼ぶ（試していない）

   <details>
   <summary>補足: 出力の例と、設定の誤りの出方</summary>

   **HackGen Console NF があるとき**（検証コンテナの 2 回目。警告も `ERROR` も出ない。長い空白は詰めた）:

   ```
   LeftToRight
    0 a    \u{61}       x_adv=8  cells=1  glyph=uni0061#0#0#0#0  ,68    wezterm.font("HackGen Console NF", {weight="Regular", stretch="Normal", style="Normal"})
                                         /home/<USER>/.local/share/fonts/HackGenConsoleNF-Regular.ttf, FontConfig
    1 あ    \u{3042}     x_adv=17 cells=2  glyph=cid01454#1       ,14050 wezterm.font("HackGen Console NF", {weight="Regular", stretch="Normal", style="Normal"})
                                         /home/<USER>/.local/share/fonts/HackGenConsoleNF-Regular.ttf, FontConfig
   ```

   **HackGen Console NF が無いとき**（1 回目。日本語のフォントも無いコンテナなので、`あ` は `.notdef` になった）:

   ```
   Unable to load a font specified by your font=wezterm.font('HackGen Console NF', {weight="Regular", stretch='Normal', style=Normal}) configuration. Fallback(s) are being used instead, and the terminal may not render as intended. See https://wezterm.org/config/fonts.html for more information
   <TIME>  WARN   wezterm_font > No fonts contain glyphs for these codepoints: \u{3042}.
   （中略）
   <TIME>  ERROR  wezterm_toast_notification::dbus > while showing notification: I/O error: No such file or directory (os error 2)
   LeftToRight
    0 a    \u{61}       x_adv=10 cells=1  glyph=a        ,189  wezterm.font("JetBrains Mono", {weight="Regular", stretch="Normal", style="Normal"})
                                         <built-in>, BuiltIn
    1 あ    \u{3042}     x_adv=16 cells=2  glyph=.notdef  ,0    wezterm.font("Symbols Nerd Font Mono", {weight="Regular", stretch="Normal", style="Normal"})
                                         <built-in>, BuiltIn
   ```

   **設定に誤りがあるとき**は、`ERROR  wezterm_gui >` の行が出る。検証コンテナで、この設定を複製して壊し、`--config-file` で読ませた:

   - 存在しない設定名（`config.no_such_option = 1`）を足したとき。stable の WezTerm で、nightly だけの設定を読んだときもこの形になる見込み（stable では試していない）

   ```
   <TIME>  ERROR  wezterm_gui > error converting Lua table to Config (Config::from_dynamic: `no_such_option` is not a valid Config field.  There are too many alternatives to list here; consult the documentation!)
   ```

   - `lua/palette.lua` に文法エラーがあるとき

   ```
   <TIME>  ERROR  wezterm_gui > runtime error: searcher:8: error loading module 'palette' from file '/tmp/bad/lua/palette.lua':
   	/tmp/bad/lua/palette.lua:2: unexpected symbol near <eof>
   ```

   - どちらも終了コードは 0 のままなので、出力の `ERROR` の行で判断する
   - `wezterm show-keys` は、設定を読めなくても何も言わずに既定のキーの一覧を出す（README の「動作確認」）ので、この確かめには使わない
   - `| head` で切ると、パイプが閉じて終了コードが 101 になる（setup-notes の [wezterm-nightly.md 手順 4](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/wezterm-nightly.md#実施手順) の補足）ので、付けていない

   </details>

1. `~/.bashrc` に、シェル統合の行と starship の行があるか確かめる。

   ```bash
   grep -n -e 'WEZTERM_SHELL_INTEGRATION' -e 'starship init' ~/.bashrc
   ```

   - 何も出なければ、手順 7 は飛ばす
   - `WEZTERM_SHELL_INTEGRATION` を含む行が出たら、もう足してある。手順 6・7 は飛ばす
   - `starship init` を含む行だけが出たら、手順 6 は飛ばす
   - Git Bash で `~/.bashrc` がまだ無ければ、`No such file or directory` と出る。手順 7 は飛ばす（手順 6 で作られる）
   - 自分用の bash の設定（`ryo-aoki-pc/bash`）を入れたホストでは、手順 6・7 は飛ばす（その設定が、starship・zoxide と合わせた順番でシェル統合を読む）

   <details>
   <summary>補足: starship の行より前に置く理由</summary>

   - setup-notes の [starship.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/starship.md) は、starship の初期化を zoxide と WezTerm のシェル統合より後ろに置く
   - starship は、既にある `PROMPT_COMMAND` を `STARSHIP_PROMPT_COMMAND` に退避して、自分の中から呼ぶ。シェル統合が先に足した関数は呼ばれ続ける
   - 検証コンテナで、公式の統合を止めて（[注意点](#注意点)）、この 1 行 → starship の順に読んだシェルでは:
     - `PS1` の OSC 133 の印（`A` / `B`）は無くなった。starship が `PS1` を毎回作り直すため
     - `PS0` の `133;C` は残り、`STARSHIP_PROMPT_COMMAND` の先頭は `__wezterm_prompt_command` だった
     - 画面でのプロンプトへのジャンプや、出力のコピーへの影響は確かめていない

   </details>

1. `~/.bashrc` に starship の行が無いときは、最後にシェル統合の 1 行を足す。

   ```bash
   echo '[ -r "${WEZTERM_SHELL_INTEGRATION:=$HOME/.config/wezterm/shell/wezterm.sh}" ] && . "$WEZTERM_SHELL_INTEGRATION"' >> ~/.bashrc
   tail -1 ~/.bashrc
   ```

   - 足した 1 行が、そのまま出る
   - zsh を使うなら、同じ行を `~/.zshrc` にも足す（試していない）

   <details>
   <summary>補足: 1 行の中身</summary>

   - `WEZTERM_SHELL_INTEGRATION` は、この設定の WezTerm が起動するシェルに渡す環境変数で、`shell/wezterm.sh` のパスが入る（`lua/shells.lua` の `set_environment_variables`）
   - 変数が無いとき（tmux や ssh を挟むと届かない）は、`$HOME/.config/wezterm/shell/wezterm.sh` を読む
   - WezTerm は bash をログインシェル（`-l`）で起動するので、`--rcfile` では読ませられない。そのため `~/.bashrc` に書く
   - PowerShell は、`lua/shells.lua` が起動引数（`-Command`）で `shell/wezterm.ps1` を読ませるので、プロファイルに足すものは無い
   - WezTerm 以外の端末で読まれても、迷子のマウス報告よけ（README）のほかは何もしない

   </details>

1. `~/.bashrc` に starship の行があるときだけ（手順 6 の代わりに）、その行の前に 1 行を差し込む。

   ```bash
   sed -i '/starship init bash/i [ -r "${WEZTERM_SHELL_INTEGRATION:=$HOME/.config/wezterm/shell/wezterm.sh}" ] && . "$WEZTERM_SHELL_INTEGRATION"' ~/.bashrc
   grep -n -e 'WEZTERM_SHELL_INTEGRATION' -e 'starship init' ~/.bashrc
   ```

   - シェル統合の行が、`starship init` の行のすぐ上に出る
   - `starship init bash` を含む行が 2 つ以上あると、それぞれの上に入る。余分な行はエディタで消す

1. WezTerm のウィンドウをすべて閉じてから、起動し直す。

   - WezTerm を開いていなければ、起動するだけでよい
   - AlmaLinux 10 はアプリ一覧の「WezTerm」から、Windows 11 はスタートメニューの「WezTerm」から起動する
   - 設定のファイルは保存すると読み直されるが、シェル統合はシェルの起動時に読むので、開いていたタブには効かない。ウィンドウの装飾（`window_decorations`）も、起動し直すまで変わらない
   - **次の手順は、起動し直した WezTerm のタブで貼る**（開いていたタブで貼ると、手順 9 の確かめが外れる）

1. 起動し直した WezTerm のタブで、シェル統合が読まれたか確かめる。

   ```bash
   echo "$TERM_PROGRAM"
   echo "$WEZTERM_SHELL_INTEGRATION"
   declare -F __wezterm_set_user_var __wezterm_notify_done __wz_mouse_off
   ```

   - 1 行目は `WezTerm`、2 行目は `.config/wezterm/shell/wezterm.sh` で終わるパス
   - 3 つ目は、WezTerm のパッケージの公式のシェル統合があるかどうかで変わる
     - AlmaLinux 10（COPR の WezTerm）: `__wezterm_set_user_var` と `__wz_mouse_off` の 2 行。公式の統合が先に読まれ、この設定の統合はマウス報告よけだけを残して抜ける（長いコマンドの完了通知は動かない。[注意点](#注意点)）
     - 公式の統合が無いとき（Windows の Git Bash など）: `__wezterm_notify_done` と `__wz_mouse_off` の 2 行
   - 1 行目が空なら、WezTerm の外で貼っている。2 行目が空なら、手順 8 の前から開いていたタブで貼っている
   - `__wz_mouse_off` が出なければ、`~/.bashrc` の行が読まれていない。手順 5 から見直す

   <details>
   <summary>補足: 検証コンテナでの出力</summary>

   1 回目の出力。WezTerm の画面の代わりに、`wezterm-mux-server` を起動し直して開いたペインに打ち込み、`wezterm cli get-text` で画面の文字を読んだ:

   ```
   [<USER>@<HOST> ~]$ echo "$TERM_PROGRAM"
   WezTerm
   [<USER>@<HOST> ~]$ echo "$WEZTERM_SHELL_INTEGRATION"
   /home/<USER>/.config/wezterm/shell/wezterm.sh
   [<USER>@<HOST> ~]$ declare -F __wezterm_set_user_var __wezterm_notify_done __wz_mouse_off
   __wezterm_set_user_var
   __wz_mouse_off
   ```

   - `declare -F` は、定義されている関数の名前だけを出す
   - 手順 6 の 1 行を足す前は、`__wezterm_set_user_var`（と公式の `__wezterm_osc7`）だけだった。シェルはログインシェルで起動していた
   - 公式の統合を止めた（`WEZTERM_SHELL_SKIP_ALL=1` を付けて起動した）シェルでは、`__wezterm_notify_done` と `__wz_mouse_off` が出た。公式の統合が無い Windows の Git Bash も、この形になるはず（試していない）

   </details>

---

## WSL でもシェル統合を使う（任意）

- WezTerm は WSL のシェルに起動引数を渡せないので、WSL の `~/.bashrc` に、Windows 側に置いたシェル統合を読む行を直接書く
- Windows で[実施手順](#実施手順)の手順 1〜7 を通してから、WSL のシェルで貼る
- **この節は試していない**

1. WSL のシェルで、Windows のホームを調べ、シェル統合のスクリプトが見えるか確かめる。

   ```bash
   WIN_HOME=$(wslpath "$(cd /mnt/c && cmd.exe /c 'echo %USERPROFILE%' | tr -d '\r')")
   ls -l "$WIN_HOME/.config/wezterm/shell/wezterm.sh"
   ```

   - `/mnt/c/Users/<WIN_USER>/.config/wezterm/shell/wezterm.sh` の 1 行が出ればよい
   - `No such file or directory` なら、Windows で[手順 3](#実施手順) を先に通す

1. この節の手順 1 と同じシェルで、WSL の `~/.bashrc` に読み込む行を足す。

   ```bash
   echo "[ -r '$WIN_HOME/.config/wezterm/shell/wezterm.sh' ] && . '$WIN_HOME/.config/wezterm/shell/wezterm.sh'" >> ~/.bashrc
   tail -1 ~/.bashrc
   ```

   - `/mnt/c/Users/<WIN_USER>/.config/wezterm/shell/wezterm.sh` を 2 回含む 1 行が出る
   - WSL の `$HOME` は Linux 側なので、[手順 6](#実施手順) の 1 行（`$HOME/.config/wezterm` を読む）では届かない

1. WezTerm の起動メニューから、WSL のタブを開き直す。

   - `Ctrl+Shift+M` の起動メニューで、WSL のディストリビューションを選ぶ
   - **次の手順は、開き直した WSL のタブで貼る**

1. 開き直した WSL のタブで、シェル統合が読まれたか確かめる。

   ```bash
   echo "$TERM_PROGRAM"
   declare -F __wezterm_set_user_var __wezterm_notify_done __wz_mouse_off
   ```

   - 見方は[手順 9](#実施手順) と同じ（WSL のディストリビューションに WezTerm のパッケージが入っていなければ、公式の統合は無い）

---

## ssh 先でもシェル統合を使う（任意）

- ssh は `TERM_PROGRAM` を既定では送らないので、ssh 先のシェルではシェル統合が動かない（タブ名は接続先になる）
- 手元の `~/.ssh/config` で送り、ssh 先の sshd で受け取り、ssh 先にもこの設定を置く。自分で管理している AlmaLinux 10 のホストを想定している
- 動けば、タブ名が `<HOST>:<ディレクトリ名>` になり、ssh 先でもプロンプトへのジャンプ・出力のコピー・完了通知が使える（README の「ssh 先でもシェル統合を使う」）

1. 手元の `~/.ssh/config` で、使う `Host` に `SendEnv TERM_PROGRAM` を足す。

   - エディタで `~/.ssh/config` を開く（Windows は `%USERPROFILE%\.ssh\config`。Git Bash では `~/.ssh/config`）
   - 使う `Host <HOST>` の行の下に、字下げして `SendEnv TERM_PROGRAM` の行を足す
   - WezTerm から ssh したときだけ、`WezTerm` が送られる。ほかの端末から ssh したときはその端末の値が送られ、シェル統合は動かない

1. ssh 先で、sshd が `TERM_PROGRAM` を受け取るようにする。

   ```bash
   {
     echo 'AcceptEnv TERM_PROGRAM' | sudo tee /etc/ssh/sshd_config.d/50-wezterm.conf
     sudo sshd -t && sudo systemctl reload sshd
     sudo sshd -T | grep -i '^acceptenv'
   }
   ```

   - 最後に `acceptenv TERM_PROGRAM` と出ればよい
   - `sshd -t` が設定の誤りを出したら、`reload` はされない
   - **次の手順は、`sudo` のパスワードを聞かれたら答えてから貼る**（続けて貼ると答えとして食われる）

   <details>
   <summary>補足: AlmaLinux 10 の sshd の既定と、検証コンテナでの出力</summary>

   - AlmaLinux 10.2 の既定の sshd は、`AcceptEnv` を 1 つも持たない（`sshd -T` に `acceptenv` の行が出ない）
   - `/etc/ssh/sshd_config` の `Include /etc/ssh/sshd_config.d/*.conf` が、このファイルを読む。`AcceptEnv` は、ほかの行やファイルにあっても足し合わされる
   - 検証コンテナ（systemd が PID 1）での出力は、次の 2 行だった。journal には `Received SIGHUP; restarting.` と `Reloaded sshd.service - OpenSSH server daemon.` が出た

   ```
   AcceptEnv TERM_PROGRAM
   acceptenv TERM_PROGRAM
   ```

   </details>

1. ssh 先で、[実施手順](#実施手順)の手順 1〜7 を通す。

   - ssh 先に WezTerm が入っていなければ、[手順 4](#実施手順) は飛ばす（`wezterm` コマンドが無い。シェル統合には要らない）
   - Syncthing などで `~/.config/wezterm` を同期しているなら、[手順 5〜7](#実施手順) だけでよい
   - [手順 8・9](#実施手順) の代わりに、この節の手順 4・5 を行う

1. 手元の WezTerm の新しいタブから、ssh し直す。

   - `ssh <HOST>` を打つか、起動メニュー（`Ctrl+Shift+M`）の「ssh <HOST>」を選ぶ
   - **次の手順は、ssh 先のシェルで貼る**

1. ssh 先のシェルで、`TERM_PROGRAM` が届き、シェル統合が読まれたか確かめる。

   ```bash
   echo "$TERM_PROGRAM"
   declare -F __wezterm_set_user_var __wezterm_notify_done __wz_mouse_off
   ```

   - 1 行目が `WezTerm` ならよい。空なら、この節の手順 1・2 を見直す
   - 2 つ目の見方は[手順 9](#実施手順) と同じ（ssh 先に COPR の WezTerm が入っていれば、公式の統合が読まれる）
   - tmux の中では `TERM_PROGRAM` が `tmux` になり、マウス報告よけのほかは動かない

---

## 更新

- この設定を新しくするだけ。WezTerm 本体の更新は、setup-notes の [wezterm-nightly.md の更新](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/wezterm-nightly.md#更新)

1. 設定のリポジトリを pull する。

   ```bash
   git -C ~/.config/wezterm pull
   git -C ~/.config/wezterm log -1 --oneline
   ```

   - 新しいコミットが無ければ、`Already up to date.` と出る
   - 起動中の WezTerm は、ファイルが変わると設定を読み直す（効かなければ `Ctrl+Shift+R`）
   - シェル統合（`shell/`）とウィンドウの装飾の変更は、[手順 8](#実施手順) と同じく起動し直すまで効かない
   - 手元で変えたファイルがあって pull が止まったら、`git -C ~/.config/wezterm status` で見る

---

## ロールバック

- この文書で足したものを外す。WezTerm 本体は消さない（消すなら setup-notes の [wezterm-nightly.md のロールバック](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/wezterm-nightly.md#ロールバック)）

> [!CAUTION]
> **この節の手順 3 は、`~/.config/wezterm` を消す**。手元で変えて commit・push していないものは取り戻せない。この節の手順 2 で確かめてから貼る。

1. `~/.bashrc` から、シェル統合の行を消す。

   ```bash
   sed -i '/WEZTERM_SHELL_INTEGRATION/d' ~/.bashrc
   grep -c 'WEZTERM_SHELL_INTEGRATION' ~/.bashrc
   ```

   - `0` と出ればよい

1. 設定のリポジトリに、手元だけの変更が無いか確かめる。

   ```bash
   git -C ~/.config/wezterm status --short --branch
   ```

   - `## main...origin/main` の 1 行だけなら、手元だけの変更は無い
   - ほかの行や `[ahead 1]` などが出たら、要るものを別の場所へ写してから、この節の手順 3 へ進む

1. 設定を消す（取り戻せない）。

   ```bash
   rm -rf ~/.config/wezterm
   ls -ld ~/.config/wezterm
   ```

   - `No such file or directory` と出る
   - WezTerm は、次に起動したときから組み込みの既定の設定で開く（この節の手順 4 で戻したときは、戻した設定）

1. [手順 2](#実施手順) で退避したときだけ、元の設定を戻す。

   ```bash
   for f in ~/.wezterm.lua ~/.config/wezterm; do
     if [ -e "$f" ]; then echo "中断: $f が既にある" >&2
     elif [ -e "$f.bak" ]; then mv -v "$f.bak" "$f"
     fi
   done
   ```

   - 戻したものだけ、`renamed '/home/<USER>/.config/wezterm.bak' -> '/home/<USER>/.config/wezterm'` のように出る

1. [WSL でもシェル統合を使う（任意）](#wsl-でもシェル統合を使う任意)を通したときだけ、WSL のシェルで、WSL の `~/.bashrc` の行を消す。

   ```bash
   sed -i '\#/.config/wezterm/shell/wezterm.sh#d' ~/.bashrc
   grep -c '/.config/wezterm/shell/wezterm.sh' ~/.bashrc
   ```

   - `0` と出ればよい

1. [ssh 先でもシェル統合を使う（任意）](#ssh-先でもシェル統合を使う任意)を通したときだけ、ssh 先で、sshd の設定を消す。

   ```bash
   {
     sudo rm -v /etc/ssh/sshd_config.d/50-wezterm.conf
     sudo sshd -t && sudo systemctl reload sshd
   }
   ```

   - `removed '/etc/ssh/sshd_config.d/50-wezterm.conf'` と出る
   - ssh 先の `~/.bashrc` の行と `~/.config/wezterm` は、ssh 先でこの節の手順 1〜3 を貼って消す
   - 手元の `~/.ssh/config` に足した `SendEnv TERM_PROGRAM` の行は、エディタで消す

---

## 補足

### 対象と検証環境

- **目的**: この設定（[ryo-aoki-pc/wezterm](https://github.com/ryo-aoki-pc/wezterm)）を `~/.config/wezterm` に置き、bash のシェル統合を読ませる。AlmaLinux 10 と Windows 11 の Git Bash で、同じコマンドにする
- **進め方**: git で clone し、`~/.bashrc` に 1 行を足す。**読者が書き換える変数は無い**（リポジトリの URL と置き場所は固定）
- **状態**: **x86_64 のコンテナでのみ検証済み（2026-09-30）。実機・Windows 11・WSL では本実行していない**
  - 下表の検証コンテナで、**この文書の bash のコードブロックを抜き出したもの**を、一般ユーザーの `bash -s` に手順ごとに流した（[付録](#付録-コンテナでの検証記録2026-09-30)）
  - 手順 8・9 は、WezTerm の画面の代わりに、そのユーザーの `wezterm-mux-server` を起動し直し、開いたペインに手順 9 のブロックを打ち込んで、画面の文字を `wezterm cli get-text` で読んだ
  - 確認したこと: 既存の設定の退避と戻し、clone、`wezterm ls-fonts` での読み込み（HackGen Console NF の有無の両方）、`~/.bashrc` の 1 行（starship の行の前への差し込みも）、WezTerm が起動したシェルに `TERM_PROGRAM` と `WEZTERM_SHELL_INTEGRATION` が入ること、公式のシェル統合との関係、ssh 先の節（`systemctl reload sshd` と、mux のペインから ssh した先での確かめ）、更新、ロールバック
  - **確認していないこと**: WezTerm の画面（見た目・タブ名・キー操作・プロンプトへのジャンプ・出力のコピー・完了通知の表示）、Windows 11 の Git Bash、WSL の節、zsh、aarch64、macOS

| 項目 | 検証コンテナ |
|---|---|
| 実施日 | 2026-09-30 |
| OS | AlmaLinux 10.2 (Lavender Lion) / x86_64（`quay.io/almalinuxorg/10-init:10.2`、Docker 29.3.1、`--privileged`。systemd が PID 1） |
| WezTerm | `wezterm-20260929_043349_cab25161-0.x86_64`（COPR の `rhel-9-x86_64`。setup-notes の wezterm-nightly.md の手順で導入） |
| git / bash | `git-2.52.0-1.el10` / `bash-5.2.26-6.el10` |
| この設定 | `main` の `e06db70` |
| sshd | `openssh-server-9.9p1-27.el10_2.alma.1` |
| 2 回目だけ | HackGen Console NF v2.10.0（`~/.local/share/fonts`）、starship 1.26.0（`~/.local/bin`） |

> [!NOTE]
> 出力例の値は `<USER>` / `<WIN_USER>` / `<HOST>` / `<TIME>` などのプレースホルダで書いてある。WezTerm の版（`20260929_043349_cab25161`）とこの設定のコミット（`e06db70`）は、実行日によって変わる。

手順書全体に関わる理由・実測・落とし穴と検証記録（手順ごとのものは各手順の末尾の「補足」にある）。手順を実行するだけなら読まなくてよい。

### 実施前の状態

| 項目 | 1 回目 | 2 回目 |
|---|---|---|
| WezTerm | COPR の nightly（`/etc/profile.d/wezterm.sh` がある） | 同じ |
| `~/.wezterm.lua` | 無し | あり（wezterm-nightly.md の最小の例） |
| `~/.config/wezterm` | 無し | あり（同じ最小の例の `wezterm.lua` だけ） |
| `~/.bashrc` | `/etc/skel` のまま | `/etc/skel` の末尾に `eval "$(starship init bash)"` |
| HackGen Console NF | 無し（日本語のフォントも無い） | `~/.local/share/fonts` に 4 ファイル |

### 選択した方針

- **`~/.config/wezterm` に git で clone する**
  - `lua/` と `shell/` を `wezterm.config_dir` から読むので、ディレクトリごと置く（手順 3 の補足）
  - 更新は `git pull` で、手元で変えたところは `git diff` で見られる
  - Windows の WezTerm も `%USERPROFILE%\.config\wezterm\wezterm.lua` を読むので、Git Bash から同じコマンドで置ける（試していない）
- **シェル統合は `~/.bashrc` の 1 行**
  - PowerShell には起動引数で読ませられるが、bash はログインシェルで起動するので `--rcfile` を使えない（手順 6 の補足）
  - tmux・ssh を挟むと環境変数が届かないので、既定の置き場所をフォールバックにした
- **既にある設定は、消さずに `.bak` に退避する**
  - `~/.wezterm.lua` が残るとこの設定が読まれないので、`~/.config/wezterm` と合わせて退避する
  - [ロールバック](#ロールバック)の手順 4 で戻せる
- **AlmaLinux 10 の公式のシェル統合は止めない**
  - 止めるには、WezTerm が起動するシェルに `WEZTERM_SHELL_SKIP_ALL=1` を渡す設定が要る。この設定はまだ渡していない（[注意点](#注意点)）
- **Windows は、Git Bash に同じ bash のブロックを貼る**（setup-notes の git.md と同じ）

### 完了時点の状態

| 場所 | 中身 |
|---|---|
| `~/.config/wezterm` | このリポジトリの clone（`main`） |
| `~/.bashrc` | 末尾（starship の行があればその上）に、シェル統合の 1 行 |
| `~/.wezterm.lua.bak` / `~/.config/wezterm.bak` | 手順 2 で退避したときだけ |
| （ssh 先）`/etc/ssh/sshd_config.d/50-wezterm.conf` | `AcceptEnv TERM_PROGRAM` の 1 行 |

- WezTerm が起動したシェルでの確かめ（手順 9）の出力は、手順 9 の補足にある

### 注意点

- **AlmaLinux 10（COPR の WezTerm）では、この設定のシェル統合の大半が働かない**
  - `wezterm-common` の `/etc/profile.d/wezterm.sh` は、`TERM_PROGRAM` を見ずに、すべての対話シェルで読まれる（ログインシェルは `/etc/profile`、そうでないシェルは `/etc/bashrc` から）
  - `shell/wezterm.sh` は、公式の統合の関数（`__wezterm_set_user_var`）を見つけると、マウス報告よけだけを残して抜ける（同じ名前の `__wezterm_osc7` を上書きして、公式のフックを壊さないため）
  - 今のディレクトリ（OSC 7）とプロンプトの位置（OSC 133）は、公式の統合が送る。長いコマンドの完了通知（`__wezterm_notify_done`）は動かない
  - 公式の統合は `WEZTERM_SHELL_SKIP_ALL=1` で止まる。検証コンテナで、この値を付けて起動したシェル（`wezterm cli spawn -- env WEZTERM_SHELL_SKIP_ALL=1 bash -l`）では、この設定の統合がすべて読まれた。この設定の `lua/shells.lua` は、まだこの値を渡していない
- **WezTerm は nightly が要る**
  - stable では、nightly だけの設定（README の「使用している nightly 限定機能」）が `ERROR  wezterm_gui >` になり、組み込みの既定の設定で開く見込み（stable では試していない。存在しない設定名を足したときの出方は、手順 4 の補足）
- **`~/.wezterm.lua` があると、`~/.config/wezterm` は読まれない**（手順 1 の補足）
  - Windows では、`wezterm.exe` と同じフォルダーの `wezterm.lua` も探される（公式の [Configuration Files](https://wezterm.org/config/files.html)。試していない）
- **starship と一緒に使うとき**: starship を後ろに置くと、`PS1` の OSC 133 の印は消える（手順 5 の補足の実測）。画面でのプロンプトへのジャンプへの影響は確かめていない
  - 手順 7 の並び（この 1 行 → starship）では、コマンドの終了コード（OSC 133 の `D`）がいつも 0 で送られる。starship → この 1 行 → zoxide の並びなら正しく送られる（自分用の bash の設定 `ryo-aoki-pc/bash` の検証コンテナでの実測。手順 7 はまだこの並びに直していない）
- **Git Bash の `~/.bash_profile`**（試していない）
  - WezTerm は Git Bash をログインシェル（`-l`）で起動するので、`~/.bashrc` は `~/.bash_profile` から読まれる必要がある
  - Git for Windows は、`~/.bashrc` があって `~/.bash_profile` などが無いと、`~/.bashrc` を読む `~/.bash_profile` を作り、`WARNING: Found ~/.bashrc but no ~/.bash_profile` と表示する
- **MSYS2・QMK MSYS は、ホームが別**
  - `C:\msys64\home\<WIN_USER>\.bashrc` と `C:\QMK_MSYS\home\<WIN_USER>\.bashrc` にも、手順 6 の 1 行を足す（README の「bash（Git Bash / MSYS2 / QMK MSYS / Linux）と zsh」。試していない）
- **完了通知は、OS の通知の設定にも従う**
  - Windows は「設定 → システム → 通知」で WezTerm が許されているか、集中モードになっていないかを見る（README の「長いコマンドの完了通知」）

### 参照

- [README](../README.md) — この設定の機能・キー操作・シェル統合の仕組み
- setup-notes の [wezterm-nightly.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/wezterm-nightly.md) — WezTerm nightly の導入と、設定ファイルの探索順序の実測
- setup-notes の [git.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/git.md)・[hackgen.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/hackgen.md)・[starship.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/starship.md)
- [Configuration Files — WezTerm](https://wezterm.org/config/files.html) — 設定ファイルの置き場所
- [Shell Integration — WezTerm](https://wezterm.org/shell-integration.html) — 公式のシェル統合と `WEZTERM_SHELL_SKIP_ALL`
- `man sshd_config`（`AcceptEnv`）・`man ssh_config`（`SendEnv`）

---

### 付録: コンテナでの検証記録（2026-09-30）

x86_64 のクラウドホストで `dockerd` を動かし、`docker run -d --privileged --network host quay.io/almalinuxorg/10-init:10.2` で、systemd が PID 1 の使い捨てのコンテナを立てた。実機には何も加えていない。

- 検証環境だけの変更: dnf と git がホストのプロキシを通るように、`/etc/dnf/dnf.conf` に `proxy=` を足し、AlmaLinux のリポジトリを `mirrorlist` から `baseurl` に変え、プロキシの CA を取り込んだ。git には `https_proxy` を渡した
- WezTerm は、setup-notes の wezterm-nightly.md の手順 1・3 と同じ `dnf copr enable wezfurlong/wezterm-nightly rhel-9-x86_64` と `dnf install wezterm` を、`-y` を付けて root で流して入れた
- ユーザーごとに NOPASSWD の sudo を付け、**この文書の bash のコードブロックを機械的に抜き出したもの**を、手順ごとにそのユーザーの `bash -s` に流した（折り畳みの中のブロックは除いた）
- 手順 8・9: そのユーザーの `wezterm-mux-server --daemonize` を起動し直し（手順 8 の代わり）、最初のペインに `wezterm cli send-text --no-paste` で手順 9 のブロックを打ち込み、`wezterm cli get-text` で画面の文字を読んだ
- ssh 先の節: 検証環境だけの `/etc/ssh/sshd_config.d/10-verify-port.conf`（`Port 2222`）で sshd を 2222 番で待たせ、ssh 先を同じコンテナの別のユーザー（r1）にした
  - この節の手順 1 は、手元のユーザー（u1）の `~/.ssh/config` に `Host wzr`（`HostName 127.0.0.1`・`Port 2222`・`User r1`・`SendEnv TERM_PROGRAM`）を書いて代えた
  - この節の手順 4・5 は、u1 の mux のペインに `ssh wzr` と手順 5 のブロックを打ち込んだ
- 2 回目の HackGen Console NF は、リリースの zip（`HackGen_NF_v2.10.0.zip`）の 4 ファイルを `~/.local/share/fonts` に置いた（Homebrew の cask が置く場所。setup-notes の hackgen.md）。starship は、リリースの musl 版の 1 ファイルを `~/.local/bin` に置いた

| 実行 | ユーザー | 流した手順 | 結果 |
|---|---|---|---|
| 1 | u1（設定無し） | 手順 1・3〜6・8（mux）・9、[更新](#更新)の手順 1、[ロールバック](#ロールバック)の手順 1〜3 | 手順 1 は 2 行とも `No such file or directory`。手順 4 は HackGen が無い警告と `ERROR  wezterm_toast_notification::dbus` で、`ERROR  wezterm_gui` は無し。手順 5 は何も出さなかった。手順 9 は `WezTerm`・`/home/<USER>/.config/wezterm/shell/wezterm.sh`・`__wezterm_set_user_var`・`__wz_mouse_off`。更新は `Already up to date.`。ロールバックは `0`・`## main...origin/main`・`No such file or directory` |
| 1 | r1（ssh 先） | 手順 1・3〜6、[ssh 先の節](#ssh-先でもシェル統合を使う任意)の手順 2（r1）と手順 4・5（u1 の mux のペインから）、ロールバックの手順 6・1〜3 | ssh 先の節の手順 2 は、手順 2 の補足の 2 行。手順 5 は `WezTerm`・`__wezterm_set_user_var`・`__wz_mouse_off`（ssh 先にも COPR の WezTerm があるため）。`wezterm cli list` のペインの CWD は `file://<HOST>/home/r1/`。ロールバックの手順 6 は `removed '/etc/ssh/sshd_config.d/50-wezterm.conf'` で、reload の後の `sshd -T` に `acceptenv` の行は無かった |
| 2 | u2（既存の設定・starship・HackGen） | 手順 1〜5・7・8（mux）・9、更新の手順 1、ロールバックの手順 1〜4 | 手順 1 は 2 行とも出た。手順 2 は `renamed` が 2 行。手順 4 は 2 文字とも HackGen Console NF で、警告も `ERROR` も無し。手順 5 は `26:eval "$(starship init bash)"`。手順 7 の後は、26 行目がシェル統合で 27 行目が starship。手順 9 は実行 1 と同じ（プロンプトは starship のもの）。ロールバックの手順 4 で 2 つとも戻り、`wezterm ls-fonts` は元の最小の例のフォント（`Noto Sans Mono`）を読んだ |

個別に確かめたこと（systemd の無い AlmaLinux 10.2 のコンテナに同じ版の WezTerm を入れたものも使った）:

| 確かめたこと | 結果 |
|---|---|
| `.bak` が既にあるときの手順 2 | `中断: /home/<USER>/.config/wezterm.bak が既にある`。元のディレクトリはそのまま残った |
| clone 先に中身があるときの手順 3 | `fatal: destination path '/home/<USER>/.config/wezterm' already exists and is not an empty directory.`。空のディレクトリなら、そのまま clone された |
| 手元だけの変更があるときのロールバックの手順 2 | `## main...origin/main [ahead 1]` と ` M lua/ui.lua` |
| 戻す先があるときのロールバックの手順 4 | `中断: /home/<USER>/.config/wezterm が既にある` |
| ロールバックの手順 5 の `sed`（WSL の行を模した 3 行のファイル） | その行だけが消え、`grep -c` は `0` |
| 手順 6 の 1 行が無いときに、WezTerm が起動したシェル | 関数は公式の統合の `__wezterm_set_user_var` と `__wezterm_osc7` だけ。ログインシェルだった（`shopt -q login_shell` が真） |
| `WEZTERM_SHELL_SKIP_ALL=1` を付けて起動したシェル（1 行あり） | `__wezterm_osc7`・`__wezterm_notify_done`・`__wz_mouse_off` があり、`__wezterm_integration_loaded=1`。`cd /usr/share` の後、`wezterm cli list` の CWD が `file://<HOST>/usr/share` になった |
| 上のシェルに、starship を後ろに読ませたとき | 手順 5 の補足のとおり |
| `SendEnv TERM_PROGRAM` で送られる値 | 送った側の値がそのまま届いた（`WezTerm`・`gnome`。無ければ空） |
| 設定の誤り（存在しない設定名・文法エラー） | 手順 4 の補足のとおり。どちらも終了コードは 0 |

#### 未確認事項

- WezTerm の画面での確かめ（見た目・タブ名・プロンプトへのジャンプ・直前の出力のコピー・完了通知の表示）
- Windows 11 の Git Bash での実行（`~` の場所、`wezterm` が `PATH` にあるか、`~/.bash_profile` の生成、公式の統合が無いときの手順 9 の出力）
- WSL の節、MSYS2・QMK MSYS
- zsh（`~/.zshrc` に足す場合）
- 実機（AlmaLinux 10）と aarch64
- 更新で新しいコミットが入るところ（`Already up to date.` の状態でだけ流した）
- stable の WezTerm で開いたときの出方

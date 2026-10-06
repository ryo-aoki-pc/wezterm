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
> **導入・更新・ロールバックの全分岐は AlmaLinux 10 の x86_64 コンテナで検証した**。新規 x86_64 VM では、共通 bash 設定を使う分岐の導入、実 GUI、日本語入力、公式シェル統合、更新・ロールバックを確認した（2026-10-06。[新規 VM の記録](#付録-現行版の新規-vm-での再検証2026-10-06)）。Windows 11 の実ホストの画面・分割・OS 通知と、外部 SSH の統合の制限は以前の検証記録にある。aarch64 の Linux GUI、物理キー・マウス、この VM での WSL・SSH 任意節は未実施。各環境の範囲は[対象と検証環境](#対象と検証環境)を参照。

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

1. `~/.bashrc` に、シェル統合の行と starship・zoxide の行があるか確かめる。

   ```bash
   grep -n -e 'WEZTERM_SHELL_INTEGRATION' -e 'starship init' -e 'zoxide init' ~/.bashrc
   ```

   - シェル統合の行は、starship の行より後ろ、zoxide の行より前に置く（この手順の補足）
   - 何も出なければ、手順 7 は飛ばす
   - `WEZTERM_SHELL_INTEGRATION` を含む行が出たら、もう足してある。手順 6・7 は飛ばす
   - `zoxide init` を含む行が出たら（`WEZTERM_SHELL_INTEGRATION` の行が無いとき）、手順 6 は飛ばす
   - `starship init` を含む行だけが出たら、手順 7 は飛ばす
   - `starship init` の行が、`WEZTERM_SHELL_INTEGRATION` か `zoxide init` の行より後ろに出たら（前の版のこの文書や setup-notes の starship.md の並び）、setup-notes の [starship.md 手順 3〜6](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/starship.md#実施手順) で starship の行を前へ移す（シェル統合の行は動かさなくてよい）
   - Git Bash で `~/.bashrc` がまだ無ければ、`No such file or directory` と出る。手順 7 は飛ばす（手順 6 で作られる）
   - 自分用の bash の設定（`ryo-aoki-pc/bash`）を入れたホストでは、手順 6・7 は飛ばす（その設定が、starship・zoxide と合わせた順番でシェル統合を読む）

   <details>
   <summary>補足: starship の行より後ろ、zoxide の行より前に置く理由</summary>

   - starship は、既にある `PROMPT_COMMAND` を `STARSHIP_PROMPT_COMMAND` に退避して、自分の中から呼ぶ。シェル統合が starship より前にあると、統合の関数がその退避先に入り、呼ばれるときの `$?` がいつも 0 になる
   - starship より後ろなら、統合は `$?` を保つ関数を `starship_precmd` の前に足すので、OSC 133 の `D` に正しい終了コードが入る
   - zoxide は `~/.bashrc` のいちばん最後に置く（setup-notes の [zoxide.md 手順 6](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/zoxide.md#実施手順)）。統合が zoxide より後ろにあっても、結果は同じだった（統合は `PROMPT_COMMAND` の先頭に足すため）
   - 自分用の bash の設定（`ryo-aoki-pc/bash`）の検証コンテナで、公式の統合の無い形で、擬似端末の生の出力を見た（2026-09-30）:
     - starship → この 1 行 → zoxide（と starship → zoxide → この 1 行）: `false` の後は `D;1`。`zoxide: detected a possible configuration issue.` は出なかった
     - この 1 行 → starship（前の版のこの文書の手順 7 の並び）: `D` はいつも `D;0`
     - 当時の統合では、どの並びでも、starship がいると `PS1` の OSC 133 の印（`A` / `B`）は無くなった。2026-10-06 に、既存のプロンプト処理の後で印を付け直すよう修正し、Windows の Git Bash で A / B と出力コピーの復帰を確認した
     - 2026-09-30 の時点では、画面でのプロンプトへのジャンプや、出力のコピーへの影響は確かめていなかった。2026-10-06 の実 GUI の結果は[ホストでの検証記録](#付録-windows-11-のホストでの動作検証2026-10-06)
   - 前の版のこの文書（2026-09-30 まで）は、この 1 行を starship の行の前に差し込んでいた。そのホストは、setup-notes の starship.md の手順 3〜6 で starship の行を前へ移す（この 1 行は動かさなくてよい）

   </details>

1. `~/.bashrc` に zoxide の行が無いときは、最後にシェル統合の 1 行を足す。

   ```bash
   echo '[ -r "${WEZTERM_SHELL_INTEGRATION:=$HOME/.config/wezterm/shell/wezterm.sh}" ] && . "$WEZTERM_SHELL_INTEGRATION"' >> ~/.bashrc
   tail -1 ~/.bashrc
   ```

   - 足した 1 行が、そのまま出る
   - starship の行があれば、その後ろに入る
   - zsh を使うなら、同じ行を `~/.zshrc` にも足す（試していない）

   <details>
   <summary>補足: 1 行の中身</summary>

   - `WEZTERM_SHELL_INTEGRATION` は、この設定の WezTerm が起動するシェルに渡す環境変数で、`shell/wezterm.sh` のパスが入る（`lua/shells.lua` の `set_environment_variables`）
   - 変数が無いとき（tmux や ssh を挟むと届かない）は、`$HOME/.config/wezterm/shell/wezterm.sh` を読む
   - WezTerm は bash をログインシェル（`-l`）で起動するので、`--rcfile` では読ませられない。そのため `~/.bashrc` に書く
   - PowerShell は、`lua/shells.lua` が起動引数（`-Command`）で `shell/wezterm.ps1` を読ませるので、プロファイルに足すものは無い
   - WezTerm 以外の端末で読まれても、迷子のマウス報告よけ（README）のほかは何もしない

   </details>

1. `~/.bashrc` に zoxide の行があるときだけ（手順 6 の代わりに）、その行の前に 1 行を差し込む。

   ```bash
   sed -i '/zoxide init/i [ -r "${WEZTERM_SHELL_INTEGRATION:=$HOME/.config/wezterm/shell/wezterm.sh}" ] && . "$WEZTERM_SHELL_INTEGRATION"' ~/.bashrc
   grep -n -e 'WEZTERM_SHELL_INTEGRATION' -e 'starship init' -e 'zoxide init' ~/.bashrc
   ```

   - シェル統合の行が、`zoxide init` の行のすぐ上に出る
   - `zoxide init` を含む行が 2 つ以上あると、それぞれの上に入る。余分な行はエディタで消す（最初の `zoxide init` の行の上の 1 つを残す）

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
   - 公式の統合を止めた（`WEZTERM_SHELL_SKIP_ALL=1` を付けて起動した）シェルでは、`__wezterm_notify_done` と `__wz_mouse_off` が出た。公式の統合が無い Windows の Git Bash も、この形になることを 2026-10-06 に確認した

   </details>

---

## WSL でもシェル統合を使う（任意）

- WezTerm は WSL のシェルに起動引数を渡せないので、WSL の `~/.bashrc` に、Windows 側に置いたシェル統合を読む行を直接書く
- Windows で[実施手順](#実施手順)の手順 1〜7 を通してから、WSL のシェルで貼る
- **この節のコードブロックは流していない**。Windows の実ホストの WSL 2 環境は、Linux 側の既定パスに統合を置く方法で検証した（[ホストでの検証記録](#付録-windows-11-のホストでの動作検証2026-10-06)）

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

- ssh は `TERM_PROGRAM` を既定では送らないので、ssh 先のシェルではこの設定の統合が動かない（パッケージ付属の公式統合は働くことがある）
- 手元の `~/.ssh/config` で送り、ssh 先の sshd で受け取り、ssh 先にもこの設定を置く。自分で管理している AlmaLinux 10 のホストを想定している
- この設定の統合が動けば、タブ名が `<HOST>:<ディレクトリ名>` になり、ssh 先でもプロンプトへのジャンプ・出力のコピー・完了通知が使える。公式統合が先に読まれる場合は完了通知が動かず、Starship との併用では出力の区切りも失われることがある（[追加検証](#付録-os-通知と外部-ssh-の追加検証2026-10-06)）

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
- **状態**: **導入手順全体は x86_64 のコンテナで検証済み（2026-09-30）。新規 AlmaLinux 10.2 / x86_64 VM の共通 bash 分岐と実 GUI、更新・ロールバックも確認した（2026-10-06）。既存設定の動作は Windows 11 の実ホストでも検証した（2026-10-06）**
  - 新規 VM では nightly `20261005_054844_37254829` とこの設定 `4bdfbf1` を使い、既存設定の退避、clone、フォント解決、実 GUI の起動、実タブの公式シェル統合、Anthy の確定、更新と設定の復帰を確認した。共通 bash を使うため手順 6・7 は条件外。全キー操作と WSL / SSH 任意節はこの VM では実施していない（[付録](#付録-現行版の新規-vm-での再検証2026-10-06)）
  - 下表の検証コンテナで、**この文書の bash のコードブロックを抜き出したもの**を、一般ユーザーの `bash -s` に手順ごとに流した（[付録](#付録-コンテナでの検証記録2026-09-30)）
  - 手順 8・9 は、WezTerm の画面の代わりに、そのユーザーの `wezterm-mux-server` を起動し直し、開いたペインに手順 9 のブロックを打ち込んで、画面の文字を `wezterm cli get-text` で読んだ
  - 並びを直した手順 5〜7（starship の行より後ろ、zoxide の行より前）は、2026-09-30 に別の AlmaLinux 10.2 のコンテナで、6 つの `~/.bashrc` に流し直した（手順 7 の `sed` の探す文字列を直した後の 2 つを含む）。WezTerm は入れず、この設定の `shell/wezterm.sh` を読んだ対話のシェルを `script` の擬似端末で動かして、OSC 133 を生の出力で見た（[付録](#付録-並びを直した版の検証2026-09-30)）
  - 確認したこと: 既存の設定の退避と戻し、clone、`wezterm ls-fonts` での読み込み（HackGen Console NF の有無の両方）、`~/.bashrc` の 1 行（今の手順 7 の、zoxide の行の前への差し込みは、並びを直した版の検証で）、WezTerm が起動したシェルに `TERM_PROGRAM` と `WEZTERM_SHELL_INTEGRATION` が入ること、公式のシェル統合との関係、ssh 先の節（`systemctl reload sshd` と、mux のペインから ssh した先での確かめ）、更新、ロールバック
  - Windows 11 では、nightly の実 GUI でフォント・日本語・タブ・ランチャー・パレット・分割・OSC 7 / 133・出力コピー・プロンプトジャンプ・完了通知データを確認した。WSL と修正内容の詳細は[ホストでの検証記録](#付録-windows-11-のホストでの動作検証2026-10-06)
  - 追加検証では、Windows の成功・失敗の通知バナーを実画像で確認し、外部の AlmaLinux 10.2 / aarch64 の SSH 2 台で既存の公式統合と一時的なこの設定の統合を比較した。正常な範囲と既存設定の制限は[追加検証の記録](#付録-os-通知と外部-ssh-の追加検証2026-10-06)
  - **確認していないこと**: Windows での導入・更新・ロールバックの全ブロック、物理キーとマウスの入力、Windows の IME の未確定表示、OS の通知センターを開いた状態の表示、MSYS2・QMK MSYS・zsh・macOS、aarch64 の Linux GUI。今回の Linux VM では全キー操作・OS 通知・プロンプトジャンプ・出力コピー・SSH / WSL 任意節も実施していない

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
  - Windows の WezTerm も `%USERPROFILE%\.config\wezterm\wezterm.lua` を読む。2026-10-06 に、既存配置の設定読み込みと新規 GUI の起動を確認した（clone・退避・ロールバックの全手順は未実施）
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
| `~/.bashrc` | 末尾（zoxide の行があればその上）に、シェル統合の 1 行 |
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
- **starship と一緒に使うとき**: シェル統合の行は、starship の行より後ろに置く（手順 5 の補足）
  - starship より前に置くと（前の版のこの文書の手順 7 の並び）、公式の統合が無いとき（この設定の統合が働く Windows の Git Bash など）は、コマンドの終了コード（OSC 133 の `D`）がいつも 0 で送られる
  - AlmaLinux 10（COPR の WezTerm）では `D` は公式の統合が送るので、どちらの並びでも失敗したコマンドは `D;1` になる（上流の `wezterm.sh` を読ませた模擬での実測）
  - 2026-09-30 の検証では、どの並びでも Starship が PS1 の OSC 133 A / B を消した。この設定の統合を使う場合は 2026-10-06 の修正で印が戻る。公式統合が先に読まれる環境の制限は[追加検証](#付録-os-通知と外部-ssh-の追加検証2026-10-06)
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
| 2 | u2（既存の設定・starship・HackGen） | 手順 1〜5・7（当時の、starship の行の前に差し込む版）・8（mux）・9、更新の手順 1、ロールバックの手順 1〜4 | 手順 1 は 2 行とも出た。手順 2 は `renamed` が 2 行。手順 4 は 2 文字とも HackGen Console NF で、警告も `ERROR` も無し。手順 5 は `26:eval "$(starship init bash)"`。手順 7 の後は、26 行目がシェル統合で 27 行目が starship。手順 9 は実行 1 と同じ（プロンプトは starship のもの）。ロールバックの手順 4 で 2 つとも戻り、`wezterm ls-fonts` は元の最小の例のフォント（`Noto Sans Mono`）を読んだ |

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
| 上のシェルに、starship を後ろに読ませたとき | `PS1` の OSC 133 の印（`A` / `B`）は無くなった。`PS0` の `133;C` は残り、`STARSHIP_PROMPT_COMMAND` の先頭は `__wezterm_prompt_command` だった（2026-09-30 に手順 5 の補足を書き直す前の、その補足の記録） |
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

### 付録: 並びを直した版の検証（2026-09-30）

手順 5〜7 を「starship の行より後ろ、zoxide の行より前」に直した版を、x86_64 のクラウドホストの Docker で立てた `almalinux:10`（AlmaLinux 10.2、bash 5.2.26）で流した。WezTerm と COPR の公式の統合は入れず、Homebrew で starship 1.26.0 と zoxide 0.10.0 を入れ、各ユーザーの `~/.config/wezterm` にこの設定を clone した（`shell/wezterm.sh` は、印を BEL で終える直しの入ったもの）。**この文書の手順 5〜7 のブロックを抜き出したもの**を、そのユーザーの `bash -s` に流した。OSC 133 は、`TERM_PROGRAM=WezTerm` で `script` の擬似端末の `bash -il` を開き、`false` などを打ち込んで、生の出力から読んだ（自分用の bash の設定 `ryo-aoki-pc/bash` の検証と同じ方法）。

| ユーザー（実施前の `~/.bashrc` の末尾） | 流した手順 | 結果 |
|---|---|---|
| wz1（`brew shellenv` → starship → `zoxide init bash --cmd z`） | 手順 5・7（当時の、`zoxide init bash` で探す版） | 手順 5 は starship と zoxide の 2 行。手順 7 の後は starship（27 行目）→ シェル統合（28 行目）→ zoxide（29 行目）。`false` の後は `D;1`、`zoxide: detected a possible configuration issue.` は出ない |
| wz2（`brew shellenv` → starship） | 手順 5・6 | 手順 5 は starship の 1 行。手順 6 の後は starship（27 行目）→ シェル統合（28 行目）。`false` の後は `D;1` |
| wz3（`/etc/skel` のまま） | 手順 5・6 | 手順 5 は何も出さず、手順 6 で末尾に 1 行 |
| wz4（前の版の手順書の並び: zoxide → シェル統合 → starship） | 手順 5、setup-notes の starship.md の手順 5（当時の、`brew shellenv` の行を動かさない版） | 手順 5 は 3 行とも出た（starship が zoxide より後ろ）。starship.md の手順 5 の後は starship（27 行目）→ zoxide → シェル統合。`false` の後は `D;1`、警告は出ない |

- 上の 3 つの `false` の後の `D;1` は、`PROMPT_COMMAND` が配列（AlmaLinux の `/etc/bashrc`）のとき。starship → zoxide → シェル統合の並びは、文字列の `PROMPT_COMMAND`（Git Bash と同じ）でも `D;1` で、警告は出なかった（setup-notes の starship.md の付録）
- 前の版の並び（シェル統合 → starship）は、同じ方法で `D` がいつも `D;0` だった（公式の統合が無いとき）。上流の公式の `wezterm.sh` を `/etc/profile.d` に置いた模擬では、`D;1` だった

手順 7 の `sed` を `zoxide init` で探す形に、setup-notes の starship.md の手順 5 を `brew shellenv` の行も動かす形に直した後、同じコンテナで、抜き出し直したブロックを流した（2026-09-30 の夜）。

| ユーザー（実施前の `~/.bashrc` の末尾） | 流した手順 | 結果 |
|---|---|---|
| wa（`brew shellenv` → starship → `zoxide init --cmd cd bash`） | 手順 5・7 | 手順 5 は starship と zoxide の 2 行。手順 7 の後は starship（27 行目）→ シェル統合（28 行目）→ zoxide（29 行目）。`false` の後は `D;1`、警告は出ない |
| wb（`brew shellenv` → シェル統合 → starship） | 手順 5、starship.md の手順 5 | 手順 5 はシェル統合と starship の 2 行（starship が後ろ）。starship.md の手順 5 の後は `brew shellenv`（26 行目）→ starship → シェル統合。`false` の後は `D;1` |

- wa と wb も、`script` の擬似端末で開き直した `bash -il` を上と同じ方法で見た。`false` の後だけ `D;1` で、zoxide の警告は出なかった。`z` の無い 2 つ（wa は `--cmd cd`、wb は zoxide の行が無い）では `z share` が `command not found` で、その後は `D;127` だった
- 手順の後に `su -` で開いた新しいログインシェルは、どちらも何も出さなかった

### 付録: Windows 11 のホストでの動作検証（2026-10-06）

既にこの設定を使っている Windows ホストで、設定の読み込みとシェルの実動作を調べた。
導入・更新・ロールバックの全ブロックを貼る検証とは別の記録で、上の 2026-09-30 の記録は当時の結果のまま残している。

| 項目 | 検証環境 |
|---|---|
| OS | Windows 11 Pro / x86_64、ビルド 26300 |
| WezTerm | `20260905-153129-092dcf70`（nightly） |
| フォント・DPI | HackGen Console NF、168 DPI（175%） |
| シェル | Git Bash 5.3.15、Store 版 PowerShell 7.6.6、別の独立検証に PowerShell 7.6.5、Windows PowerShell 5.1 |
| プロンプト | starship 1.26.0 → この統合 → zoxide 0.9.9（自分用の bash 設定） |
| 開発者シェル | Visual Studio 2026 / 18 BuildTools、x64 |
| WSL | AlmaLinux-10（bash 5.2.26）、podman-machine-default（bash 5.3.9） |
| 設定の基点 | `fb52eeb` と、この検証で加えた修正 |

GUI は検証専用のプロセスで起動し、`wezterm cli` でペインの起動・入力・状態取得を行った。
キーに割り当てた操作は、検証用コピーにだけ加えた Lua イベントから実際の
`window:perform_action` を呼び、ペイン・区切り・クリップボード・画像で結果を確認した。
画像はウィンドウの実ピクセルサイズで取得し、DPI による画像側の切れを避けた。
物理キーボード、マウス、IME の入力は自動操作していない。

| 確かめたこと | 結果 |
|---|---|
| 設定読み込み・フォント | `ls-fonts` に設定エラー無し。英字・日本語・Nerd Font アイコンを HackGen Console NF で解決 |
| 表示 | 本文の日本語・ANSI 色・タブの丸キャップ・日本語タブ名・非アクティブなペイン・ステータス・ウィンドウ操作ボタンを画像で確認。起動メニューと日本語の独自項目を含むパレットも表示 |
| Windows の起動メニュー | Git Bash、PowerShell 7、Windows PowerShell、cmd、Developer PowerShell、Developer Command Prompt の 6 項目を独立プロセスで実際の引数から起動。空白・`#`・`%`・`&`・単一引用符・日本語を含む cwd を保持。Developer の x64 環境も確認 |
| bash の既存フックとの共存 | 本物の bashrc と starship / zoxide を独立 PTY と GUI で実行。失敗コード、再読み込み、既存 PS0 / PS1、配列の PROMPT_COMMAND、nounset、履歴抑止、Unicode のユーザー変数を確認 |
| PowerShell の統合 | 7 と 5.1 の独立 PTY で OSC 7 / 133、成功・失敗・native exit 37 / 23、StrictMode、10 回読み込み、prompt / ReadLine の個別再定義、PSReadLine の後読み込みを確認。UTF-8 BOM を保持 |
| 通常分割 | GUI で PowerShell 7 → PowerShell 7、Git Bash → Git Bash、Vim 実行中の Git Bash → Git Bash を確認。実行中のコマンドを再実行せず cwd を保持 |
| 出力コピー | GUI の bash で日本語を含む 3 行の出力を実行し、コピー結果がその 3 行だけと完全一致することを確認。元のクリップボードのテキストは復元 |
| プロンプトジャンプ・モード | 修正後の Prompt / Input / Output の区切り、割り当てたプロンプトジャンプの実行、`resize_pane` の開始を確認 |
| 長いコマンド | 実行中の `WEZTERM_PROG` と、終了後の消去を確認。3 秒のコマンドに対し `0<TAB>3<TAB>コマンド` の完了通知データを GUI で受信 |
| マウス割り当て | `show-keys` で右クリック貼り付けと Ctrl+ホイールの拡縮が通常時・マウス報告中・alternate screen に対応することを確認 |
| WSL の統合 | 両ユーザーにスクリプトと bashrc の読み込み行を配置。独立 PTY で OSC 7 / 133・`false` 後の D;1・再読み込みの重複無し、実 GUI の新しい WSL ペインで正しい Linux cwd と Prompt / Input / Output の区切りを確認。AlmaLinux の出力コピーが日本語を含む 2 行と完全一致し、通常分割も WSL のまま起動 |

検証で見つけて修正したこと:

- Starship が PS1 を毎回生成して OSC 133 A / B を消していた。既存のプロンプト処理の後で印を付け直すフックを追加した
- PowerShell の初回ロード判定が StrictMode の未定義変数エラーになった。未定義でも安全な判定にし、prompt / ReadLine が作り直された後の再読み込みにも対応した
- 通常分割は現在のシェルではなくドメインの既定を開いていた。ローカルでは既知の起動元シェルの定義を選び、WSL などはドメインを維持するよう変更した
- Ctrl+ホイールの設定がマウス報告中には一致しなかった。その状態にも上下の割り当てを追加した
- WSL の 2 環境には統合が未導入だった。各ユーザーの bashrc をバックアップし、既定パスの統合を読む 1 行を追加した。Podman の既存 systemd のフックも保持した

Windows の通常設定への反映前のファイルは `%USERPROFILE%/.local/state/wezterm/backups/` に退避した。
WSL の退避先は各ユーザーの `~/.local/state/wezterm/backups/host-test-20261006.*`。
検証用の Lua イベントは通常設定へ含めていない。

未確認: 物理キーの配列や OS のショートカット競合、実際の右クリック・ホイール入力、
IME の未確定カーソル、OS の通知センターでの完了通知表示、外部 SSH 接続先、
未導入の MSYS2 / QMK MSYS、zsh、macOS、Linux の画面。
Lua のロジック検証 47 ケース、bash 構文、PowerShell パーサーと `git diff --check` も通した。

### 付録: OS 通知と外部 SSH の追加検証（2026-10-06）

上のホスト検証の後、同じ Windows ホストで通知の実表示と、既存の SSH 設定にある
`abiko-pi`・`kawasaki-pi` を追加検証した。上の記録の未確認事項は、その時点の結果のまま残した。

入力操作ツールは、WezTerm が操作対象一覧に現れず、明示的な起動も
`product policy blocks this app` として拒否した。
そのため、物理キー・右クリック・ホイールの入力経路、IME 変換中の未確定文字・候補窓は未確認。
Lua アクションの実行や `send-text` の成功を、これらの入力検証の代わりにはしていない。

| 確かめたこと | 条件と結果 |
|---|---|
| Windows の成功通知 | 検証専用 GUI の Git Bash で `WEZTERM_NOTIFY_AFTER=1; sleep 3` を実行し、別ペインをアクティブにした。`0<TAB>3<TAB>コマンド` を受信し、OS バナーに「完了」・コマンド・「3秒」が表示された実画像を確認 |
| Windows の失敗通知 | 同じシェルの `sleep 2; false` で `1<TAB>2<TAB>コマンド` を受信し、OS バナーに「失敗 (終了コード 1)」・コマンド・「2秒」が表示された実画像を確認 |
| Windows の通知許可 | `org.wezfurlong.wezterm` の ToastNotifier は Enabled、通知サービスは起動中、Focus セッションは無効。OS 設定は変更していない。通知センターを開いた状態や通知のクリックは未確認 |
| 外部 SSH の環境・接続 | 2 台とも AlmaLinux 10.2 / aarch64、bash 5.2.26。既存の鍵で BatchMode / StrictHostKeyChecking を有効にして接続成功。ホスト鍵を追加・更新せず、遠隔の設定ファイルも変更していない |
| SSH の既存条件 | 2 台ともパッケージ付属の公式統合が先に読まれ、この設定の通知フックは不在。通常ログインの PTY で OSC 7 / 133、`false` 後の D;1 を確認したが、`kawasaki-pi` は Starship の PS1 から B が消えた。既存の接続設定に SendEnv は無く、試験接続で SendEnv を足しても TERM_PROGRAM は空だった |
| SSH の実 GUI・既存条件 | `env HISTFILE=/dev/null bash -il` の専用 SSH ペインで、2 台とも `/usr/share` のリモート cwd とホスト名を受信。日本語の printf 出力は Output ゾーンに分離されず、`abiko-pi` は Input、`kawasaki-pi` は Prompt に含まれた。生の OSC 列があるだけでは、出力コピーが正常とは判定していない |
| SSH の一時的なこの設定の統合 | 遠隔コマンドで `env TERM_PROGRAM=WezTerm WEZTERM_SHELL_SKIP_ALL=1 HISTFILE=/dev/null bash -il` を起動。2 台とも A / B / C と `false` 後の D;1 を独立 PTY で確認。GUI でも Prompt / Input / Output が分離し、日本語 2 行だけの出力コピーが完全一致。元のクリップボードのテキストは復元 |
| SSH の完了通知・再読込 | 一時セッションの 2 台とも既定閾値の `sleep 11` で `0<TAB>11<TAB>sleep 11` を自然送信。GUI の `kawasaki-pi` でも閾値を 1 秒にしたコマンドの完了バナーを Windows で確認。統合を 2 回読み直しても WezTerm のフック・PS0 の C は重複しない。`abiko-pi` の既存 zoxide フックは bashrc 自体の再読込で増えた |

SSH の一時セッションの成功は、通常接続の設定が完了していることを意味しない。
通常接続でこの設定の統合を使うには、`TERM_PROGRAM` の送受信と、公式統合が先に読まれる条件を
接続先で整える必要がある。今回、sshd・SSH 設定・既存の bashrc は変更していない。
検証専用のペインと GUI は終了し、テスト用コードや接続ログはリポジトリへ含めていない。

PR 前の独立レビューでも Lua 47 ケース、実設定の読み込み、bash 構文とプロンプトの回帰、
PowerShell 5.1 / 7 の StrictMode・10 回読み込み・prompt / ReadLine の個別再定義・後読み込みが通った。

---

### 付録: 現行版の新規 VM での再検証（2026-10-06）

**環境**: 別のクリーンな AlmaLinux 10.2 Workstation / x86_64 の VM。GNOME 49.4 のヘッドレスセッションと `1920x1080` 仮想モニター、SELinux Enforcing、firewalld 稼働、US 配列。WezTerm は COPR の `20261005_054844_37254829-0`、この設定は `4bdfbf1`、HackGen Console NF は 2.10.0。一般ユーザーの SSH シェルで配置・clone・確認を実行し、実 GUI のシェル統合は WezTerm のタブに確認ブロックを送って読んだ。GUI の文字列と操作後の PNG を確認した。既存の実機や利用者の資格情報は使っていない。

- 実施手順 1〜5 の操作を確認した。先に作った最小設定を `.bak` に退避し、指定のリポジトリを `~/.config/wezterm` に clone した。`ls-fonts --text 'aあ'` は両方 HackGen Console NF を解決し、設定の `ERROR` は無かった。配布済みの共通 bash 設定を使うため手順 6・7 は条件外だった
- 手順 8・9 は実際の GNOME Wayland ウィンドウで確認した。`TERM_PROGRAM=WezTerm`、`WEZTERM_SHELL_INTEGRATION` はこの設定の `shell/wezterm.sh`、関数は公式統合の `__wezterm_set_user_var` とこの設定の `__wz_mouse_off` が存在した。COPR の `/etc/profile.d/wezterm.sh` が先に読まれる条件なので、この設定の完了通知フックが無いことは本文どおりである。公式統合を無効にする設定は追加していない
- Anthy の日本語変換は、Mutter の evdev キー押下・解放を使う別の検証プローブで実行した。実際の WezTerm に「日本語」が確定し、保存したファイルも同じ内容だった。LazyVim の日本語検索結果と picker の Nerd Font / Powerline の表示も確認した。Neovim への RPC など、OS の IME を迂回する入力はこの判定に使っていない
- 更新は `git pull` が変更なし、`git log` は `4bdfbf1`。ロールバック 1〜4 も本文のブロックを実行した。共通 bash 分岐には挿入行が無いため grep の件数は `0`、作業ツリーは clean、clone を削除した後の `ls` は期待どおり存在なし、退避した最小設定が元の場所へ戻った。grep の終了 1 と削除後の ls の終了 2 は期待結果として扱った

**今回の未実施範囲**: 手順 6・7 の独立 bashrc 分岐、Starship / zsh、プロンプトジャンプ・出力コピー・完了通知、タブ・分割・ランチャーなど全キー操作、マウスの貼り付け、物理キーボード、Windows / macOS / aarch64 の GUI、WSL と SSH の任意節。この新規 VM の結果で以前の Windows / SSH の検証を置き換えていない。検証後は nightly と HackGen もそれぞれの手順で撤去し、VM を正常停止した。

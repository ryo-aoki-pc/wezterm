# WezTerm の設定の導入手順（AlmaLinux 10 / Windows 11 の Git Bash）

関連文書: [検証記録](verification/install.md) / [参照情報](reference/install.md)

## 実施手順

> [!IMPORTANT]
> - **自分のユーザーのシェルで貼る**。`sudo -i` した root のシェルでは貼らない（設定と `~/.bashrc` が root のホームに置かれるため）
> - **Windows 11 では、Git for Windows の Git Bash に同じブロックを貼る**。PowerShell や cmd には貼らない（bash の構文のため）
> - **前提**: WezTerm の nightly と git が入っていること
>   - AlmaLinux 10: setup-notes の [AlmaLinux 10 の初期設定の「WezTerm」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md#wezterm)の手順 1〜4 と[「Git」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md#git)（この文書は、同書の「WezTerm」の手順 5 から通す）
>   - Windows 11: WezTerm の [nightly のリリース](https://github.com/wezterm/wezterm/releases/tag/nightly)のインストーラと、[Git for Windows](https://gitforwindows.org/)（setup-notes の [Windows 11 の初期設定の「WezTerm」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-setup.md#wezterm)・[「Git for Windows」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-setup.md#git-for-windows)。この文書は、同書の「Git Bash と WezTerm の設定」の手順 5 から通す）
> - **手順 8 は、WezTerm を閉じて起動し直す操作**。手順 9 は、起動し直した WezTerm のタブで貼る

- 上から順にコードブロックを貼る
- フォントの HackGen Console NF は任意（無くてもほかのフォントで動く）。setup-notes の [AlmaLinux 10 の初期設定の「HackGen Console NF」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md#hackgen-console-nf)・[Windows 11 の初期設定の「HackGen Console NF」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-setup.md#hackgen-console-nf)で入れる
- 手順の後: WSL や ssh 先でも使うなら[WSL でもシェル統合を使う（任意）](#wsl-でもシェル統合を使う任意)・[ssh 先でもシェル統合を使う（任意）](#ssh-先でもシェル統合を使う任意)。[Windows の SSH 先で PowerShell に貼り付ける（任意）](#windows-の-ssh-先で-powershell-に貼り付ける任意)も参照。以後は[更新](#更新)・[ロールバック](#ロールバック)
- 機能とキー操作は [README](../README.md) にある


1. 既存の WezTerm の設定があるか確かめる。

   ```bash
   ls -ld ~/.wezterm.lua ~/.config/wezterm
   ```

   - どちらかが出たら、手順 2 で退避する
   - 2 行とも `No such file or directory` なら、設定は無い。手順 2 は飛ばす
   - `~/.wezterm.lua` が残っていると、この設定は読まれない


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
   - この後のシェル統合も `$HOME/.config/wezterm` を使う。別の配置先にするなら、手順 6・7 の 1 行も書き換える
   - `fatal: destination path '/home/<USER>/.config/wezterm' already exists and is not an empty directory.` と出たら、手順 1 から見直す


1. WezTerm がこの設定を読めるか確かめる。

   ```bash
   wezterm ls-fonts --text 'aあ'
   ```

   - `ERROR  wezterm_gui >` で始まる行が無ければ、設定を読めている
   - 設定の誤りがあっても終了コードは 0 なので、出力の `ERROR` で判定する
   - `wezterm show-keys` は設定を読めなくても既定の一覧を出すので、この確認には使わない
   - `| head` は付けずに出力を読む (パイプが閉じると終了 101 になる)
   - HackGen Console NF が入っていれば、2 文字とも `wezterm.font("HackGen Console NF", ...)` の行が出る
   - 入っていなければ、`Unable to load a font specified by your font=wezterm.font('HackGen Console NF', ...)` と出て、ほかのフォントで描く（設定の誤りではない）
   - そのとき画面の無いシェル（ssh など）では、`ERROR  wezterm_toast_notification::dbus` も出ることがある。フォントの警告を通知に出せなかっただけで、設定の誤りではない
   - Windows で `wezterm: command not found` と出たら、`"/c/Program Files/WezTerm/wezterm.exe" ls-fonts --text 'aあ'` のようにインストール先から呼ぶ


1. `~/.bashrc` に、シェル統合の行と starship・zoxide の行があるか確かめる。

   ```bash
   grep -n -e 'WEZTERM_SHELL_INTEGRATION' -e 'starship init' -e 'zoxide init' ~/.bashrc
   ```

   - シェル統合の行は、starship の行より後ろ、zoxide の行より前に置く
   - 何も出なければ、手順 7 は飛ばす
   - `WEZTERM_SHELL_INTEGRATION` を含む行が出たら、もう足してある。手順 6・7 は飛ばす
   - `zoxide init` を含む行が出たら（`WEZTERM_SHELL_INTEGRATION` の行が無いとき）、手順 6 は飛ばす
   - `starship init` を含む行だけが出たら、手順 7 は飛ばす
   - `starship init` の行が、`WEZTERM_SHELL_INTEGRATION` か `zoxide init` の行より後ろに出たら（前の版のこの文書や setup-notes の starship.md の並び）、setup-notes の [AlmaLinux 10 の初期設定の「共通の bash 設定」の手順 1・2](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md#共通の-bash-設定)で共通の bash 設定を入れる（既知の追記は控えを取って移され、starship → WezTerm → zoxide の順番はその設定が持つ。starship の行を前へ移していた setup-notes の starship.md は、この初期設定にまとめた）
   - Git Bash で `~/.bashrc` がまだ無ければ、`No such file or directory` と出る。手順 7 は飛ばす（手順 6 で作られる）
   - 自分用の bash の設定（`ryo-aoki-pc/bash`）を入れたホストでは、手順 6・7 は飛ばす（その設定が、starship・zoxide と合わせた順番でシェル統合を読む）


1. `~/.bashrc` に zoxide の行が無いときは、最後にシェル統合の 1 行を足す。

   ```bash
   echo '[ -r "${WEZTERM_SHELL_INTEGRATION:=$HOME/.config/wezterm/shell/wezterm.sh}" ] && . "$WEZTERM_SHELL_INTEGRATION"' >> ~/.bashrc
   tail -1 ~/.bashrc
   ```

   - 足した 1 行が、そのまま出る
   - starship の行があれば、その後ろに入る
   - zsh を使うなら、同じ行を `~/.zshrc` にも足す
   - Git Bash はログインシェルで起動するため、`~/.bash_profile` から `~/.bashrc` が読まれることを確かめる
   - MSYS2 / QMK MSYS では各シェルのホームにある `~/.bashrc` にも同じ行を足す
   - PowerShell のプロファイルに足す行は無い


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
     - AlmaLinux 10（COPR の WezTerm）の公式 Bash 統合: `__wezterm_set_user_var`・`__wezterm_notify_done`・`__wz_mouse_off` の 3 行。公式の cwd・ユーザー変数・bash-preexec を保ち、独自のプロンプト区切りと完了通知を補う（[注意点](#注意点)）
     - 公式の統合が無いとき（Windows の Git Bash など）: `__wezterm_notify_done` と `__wz_mouse_off` の 2 行
   - 1 行目が空なら、WezTerm の外で貼っている。2 行目が空なら、手順 8 の前から開いていたタブで貼っている
   - `__wz_mouse_off` が出なければ、`~/.bashrc` の行が読まれていない。手順 5 から見直す


---

## WSL でもシェル統合を使う（任意）

- WezTerm は WSL のシェルに起動引数を渡せないので、WSL の `~/.bashrc` に、Windows 側に置いたシェル統合を読む行を直接書く
- Windows で[実施手順](#実施手順)の手順 1〜7 を通してから、WSL のシェルで貼る

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

- ssh は `TERM_PROGRAM` を既定では送らない。公式統合が無い接続先では、この設定の独自統合を使うために `WezTerm` の受信が要る。既に有効な公式 Bash 統合がある場合は、変数が未設定でもこの設定で補完する
- 手元の `~/.ssh/config` で送り、ssh 先の sshd で受け取り、ssh 先にもこの設定を置く。自分で管理している AlmaLinux 10 のホストを想定している
- この設定の統合が動けば、タブ名が `<HOST>:<ディレクトリ名>` になり、ssh 先でもプロンプトへのジャンプ・出力のコピー・完了通知が使える。公式 Bash 統合が先に読まれる場合も、修正版は Starship 後に入力範囲の印と独自完了通知を補う

1. 手元の `~/.ssh/config` で、使う `Host` に `SendEnv TERM_PROGRAM` を足す。

   - エディタで `~/.ssh/config` を開く（Windows は `%USERPROFILE%\.ssh\config`。Git Bash では `~/.ssh/config`）
   - 使う `Host <HOST>` の行の下に、字下げして `SendEnv TERM_PROGRAM` の行を足す
   - WezTerm から ssh したときだけ、`WezTerm` が送られる。公式統合が無い場合、この値が `WezTerm` のときだけ独自統合が動く

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

   - 1 行目が `WezTerm` ならよい。公式 Bash 統合が有効なら、空でも補完処理は動く。公式統合が無ければ、この節の手順 1・2 を見直す
   - 2 つ目の見方は[手順 9](#実施手順) と同じ（ssh 先に COPR の WezTerm が入っていれば、公式の統合が読まれる）
   - tmux の中では `TERM_PROGRAM` が `tmux` になり、マウス報告よけのほかは動かない

---

## Windows の SSH 先で PowerShell に貼り付ける（任意）

> [!IMPORTANT]
> 接続元は Linux または Windows の WezTerm、接続先は Windows OpenSSH と Git Bash。接続元と接続先の両方に、この版の設定を配置する。SSH のログイン後に Git Bash から PowerShell を開き、終了すると Git Bash へ戻る。

PSReadLine の入力欄へ複数行を貼る。管理者・同じユーザーの非管理者 PowerShell の切り替えは、setup-notes の [SSH 操作手順](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-setup.md#ssh-で管理者非管理者の-powershell-を使う任意)を使う。

1. 接続元と Windows 接続先の設定を、[更新](#更新)の手順 1 で更新する。

   - 接続先は Git Bash で実行する
   - 接続元は `Ctrl+Shift+R` で設定を読み直す
   - 通常の PowerShell プロファイルには追記しない

1. Linux の接続元では、セッションに対応するクリップボード取得コマンドがあるか確かめる。

   ```bash
   if [ -n "${WAYLAND_DISPLAY-}" ]; then
     command -v wl-paste
   elif [ -n "${DISPLAY-}" ]; then
     command -v xclip
   else
     echo 'GUI セッションから WezTerm を起動してください'
   fi
   ```

   - Wayland は `wl-clipboard` の `wl-paste`、X11 は `xclip` が要る。無ければ接続元の OS のパッケージ管理で導入する
   - Windows 接続元ではこの手順を飛ばす。標準の Windows PowerShell を `-NoProfile` で使う

1. 接続元の WezTerm の新しいペインで Windows に接続する。

   ```bash
   ssh surface
   ```

   - `surface` はこの環境の SSH エイリアス。別の接続先では自分のホスト名を使う
   - Windows OpenSSH の既定シェルは Git Bash とする
   - **次の手順は、接続先の Git Bash のプロンプトが出てから貼る**

1. 接続先の Git Bash で統合を読み、Windows PowerShell 5.1 を起動する。

   ```bash
   export TERM_PROGRAM=WezTerm
   . ~/.config/wezterm/shell/wezterm.sh
   powershell.exe -NoLogo -NoExit -Command '. "$env:USERPROFILE\.config\wezterm\shell\wezterm.ps1"'
   ```

   - PowerShell 7 を使う場合は、最後の行の `powershell.exe` を `pwsh.exe` に替える
   - **次の手順は、PowerShell のプロンプトが出てから貼る**

1. 接続先 PowerShell で、専用受信キーが登録されたか確かめる。

   ```powershell
   Get-Module PSReadLine | Select-Object Name, Version; Get-PSReadLineKeyHandler -Bound | Where-Object Function -eq WezTermSshPaste
   ```

   - `Ctrl+Shift+F12` の `WezTermSshPaste` が出ればよい。このキーは配送用で、手動では押さない
   - キーが無ければ PSReadLine を読み込み、統合を読み直してから確認する

1. 接続元で無害な複数行をコピーし、右クリックまたは `Ctrl+Shift+V` で貼る。

   ```powershell
   & {
     '一行目'

     '二行目'
   }
   ```

   - このブロックは入力欄に残り、Enter を押すまで実行しない
   - 空行・日本語・末尾改行を保持する。PSReadLine の Paste と同じく CR を除き、タブを空白 4 個にする
   - 準備応答・取得・検証が失敗すると通知し、本文を挿入しない。自動で通常貼り付けに切り替えない
   - 本文は UTF-8 で 64 KiB まで。途中で `Ctrl+C` を押すと終端まで受信して捨てる。配送が止まった場合は受信待機が続くため、本文を追加で貼らず、接続元でその SSH ペインを閉じて接続し直す

1. 入力欄を確認し、Enter を押して実行する。

   - `一行目`・`二行目` が一度ずつ出ればよい
   - **次の手順は、PowerShell のプロンプトが戻ってから行う**

1. PowerShell を終了し、Git Bash から SSH を終了する。

   ```powershell
   exit
   ```

   - **次の手順は、Git Bash のプロンプトに戻ってから貼る**

1. 接続先の Git Bash で接続を閉じる。

   ```bash
   exit
   ```

   - 接続元のプロンプトに戻ればよい

---

## 更新

- この設定を新しくするだけ。WezTerm 本体の更新は、setup-notes の [AlmaLinux 10 の初期設定の更新](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md#更新)（Windows 11 は[「Git for Windows・Firefox・WezTerm を上げる」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-setup.md#git-for-windowsfirefoxwezterm-を上げる)）

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

- この文書で足したものを外す。WezTerm 本体は消さない（消すなら setup-notes の [AlmaLinux 10 の初期設定のロールバックの「端末とエディタを消す」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/extra/almalinux-setup.md#端末とエディタを消す)。Windows 11 は[「OpenSSH・Git for Windows・Firefox・WezTerm を外す」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/extra/windows-setup.md#opensshgit-for-windowsfirefoxwezterm-を外す)）

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


## 注意点

- AlmaLinux 10（COPR の WezTerm）の公式 Bash 統合は止めない。`WEZTERM_SHELL_SKIP_ALL=1` を渡す設定は加えない
- 公式の bash-preexec 経路で starship だけを直接再初期化する場合は、この統合も続けて読み直す。再初期化だけで重なる登録を各 1 個へ戻す。通常の個人 Bash 設定は starship の再初期化をガードしている
- 前の版でシェル統合を starship より先に読んでいるホストは、[手順 5](#実施手順)に従って並びを直し、新しいタブを開く
- 完了通知が表示されなければ、Windows の「設定 → システム → 通知」で WezTerm が許されているか、集中モードになっていないかを見る

実装の説明と環境ごとの注意は[参照情報](reference/install.md#注意点)、実施済みの範囲と結果は[検証記録](verification/install.md#修正後の状態2026-10-06)にある。

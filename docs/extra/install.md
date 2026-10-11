# WezTerm 設定を戻す

## ロールバック

- この文書で足したものを外す。WezTerm 本体は消さない（消すなら setup-notes の [AlmaLinux 10 の初期設定のロールバックの「端末とエディタを消す」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/extra/almalinux-setup.md#端末とエディタを消す)。Windows 11 は[「OpenSSH・Git for Windows・Firefox・WezTerm を外す」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/extra/windows-setup.md#opensshgit-for-windowsfirefoxwezterm-を外す)）

> [!IMPORTANT]
> - **自分のユーザーの bash で行う**。`sudo -i`・`su -` で開いた root のシェルには貼らない
> - 手順 1〜4 はこの PC で行い、Windows 11 は **Git Bash** に貼る
> - **手順 5 は WSL のシェルだけ**に貼る。WSL に手順 1〜4 は貼らない
> - **手順 6 は ssh 先のシェルだけ**に貼る。手元の PC には貼らない
> - 手順 6 の前に、ssh 先の端末で `sudo -v` を手で入力し、認証を終えてプロンプトに戻るまで待つ。認証できなければ中断する
> - **パスワード入力中は後続の行を貼らない**。入力を終え、プロンプトに戻ってから進む

> [!CAUTION]
> **この節の手順 3 は、`~/.config/wezterm` を消す**。手元で変えて commit・push していないものは取り戻せない。この節の手順 2 で確かめてから貼る。

1. 以前の手順で直接追記していた場合だけ、`~/.bashrc` からシェル統合の行を消す。

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

1. [手順 2](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md#wezterm-の設定を導入する) で退避したときだけ、元の設定を戻す。

   ```bash
   for f in ~/.wezterm.lua ~/.config/wezterm; do
     if [ -e "$f" ]; then echo "中断: $f が既にある" >&2
     elif [ -e "$f.bak" ]; then mv -v "$f.bak" "$f"
     fi
   done
   ```

   - 戻したものだけ、`renamed '/home/<USER>/.config/wezterm.bak' -> '/home/<USER>/.config/wezterm'` のように出る

1. [WSL でもシェル統合を使う（任意）](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-setup.md#wezterm-のシェル統合を-wsl-で使う任意)を通したときだけ、WSL のシェルで、WSL の `~/.bashrc` の行を消す。

   ```bash
   sed -i '\#/.config/wezterm/shell/wezterm.sh#d' ~/.bashrc
   grep -c '/.config/wezterm/shell/wezterm.sh' ~/.bashrc
   ```

   - `0` と出ればよい

1. [ssh 先でもシェル統合を使う（任意）](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md#wezterm-のシェル統合を-ssh-先で使う任意)を通したときだけ、ssh 先で、sshd の設定を消す。

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
- 前の版でシェル統合を starship より先に読んでいるホストは、[共通の bash 設定](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md#共通の-bash-設定)を導入し、新しいタブを開く
- 完了通知が表示されなければ、Windows の「設定 → システム → 通知」で WezTerm が許されているか、集中モードになっていないかを見る

実装の説明と環境ごとの注意は[参照情報](../reference/install.md#注意点)、実施済みの範囲と結果は[検証記録](../verification/install.md#修正後の状態2026-10-06)にある。

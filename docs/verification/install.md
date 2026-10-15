# WezTerm 設定導入の検証記録

[手順書](../install.md) に記載していた検証結果を移動した記録。各記録の実施時点・対象版・未確認事項を保持し、この文書の移動による再検証は行っていない。

以下の既存記録は公式 Bash 統合との共存修正前の説明を含む。2026-10-06 の追加検証と修正後の範囲は[修正後の状態](#修正後の状態2026-10-06)を参照。

### 対象と検証環境

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


## 手順本文にあった検証記録

### 実施手順 — 手順 1: 2 つの置き場所

- WezTerm は `~/.wezterm.lua` を `~/.config/wezterm/wezterm.lua` より先に探し、見つけた 1 つだけを読む（setup-notes-verification（非公開）の [wezterm-nightly.md の「設定ファイルの探索順序（実測）」](https://github.com/ryo-aoki-pc/setup-notes-verification/blob/main/docs/verification/shell-terminal.md#wezterm-設定ファイルの探索順序実測)）
- `~/.wezterm.lua` が残っていると、この設定は読まれない
- Windows でも、WezTerm は `%USERPROFILE%\.wezterm.lua` と `%USERPROFILE%\.config\wezterm\wezterm.lua` を探す。Git Bash の `~` は `%USERPROFILE%` なので、同じコマンドで見られるはず（試していない）

### 実施手順 — 手順 3: `~/.config/wezterm` に置く理由

- `wezterm.lua` は、`lua/` のモジュールを `wezterm.config_dir`（`wezterm.lua` のあるディレクトリ）から読む。シェル統合のスクリプトも、同じディレクトリの `shell/` を指す。1 ファイルの `~/.wezterm.lua` には置けない
- 手順 6 の 1 行は、`$HOME/.config/wezterm` を既定の置き場所として書いてある。別の場所に置くなら、その 1 行も書き換える
- Git Bash のホームは `/c/Users/<WIN_USER>`（setup-notes の [windows-openssh-server.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-setup.md#openssh-サーバー) の実測）なので、Windows では `C:\Users\<WIN_USER>\.config\wezterm` に置かれるはず（試していない）

### 実施手順 — 手順 4: 出力の例と、設定の誤りの出方

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
- `| head` で切ると、パイプが閉じて終了コードが 101 になる（setup-notes の [wezterm-nightly.md 手順 4](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#wezterm) の補足）ので、付けていない

### 実施手順 — 手順 5: starship の行より後ろ、zoxide の行より前に置く理由

- starship は、既にある `PROMPT_COMMAND` を `STARSHIP_PROMPT_COMMAND` に退避して、自分の中から呼ぶ。シェル統合が starship より前にあると、統合の関数がその退避先に入り、呼ばれるときの `$?` がいつも 0 になる
- starship より後ろなら、統合は `$?` を保つ関数を `starship_precmd` の前に足すので、OSC 133 の `D` に正しい終了コードが入る
- zoxide は `~/.bashrc` のいちばん最後に置く（当時の setup-notes の zoxide.md 手順 6。今は [AlmaLinux 10 の初期設定](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md)）。統合が zoxide より後ろにあっても、結果は同じだった（統合は `PROMPT_COMMAND` の先頭に足すため）
- 自分用の bash の設定（`ryo-aoki-pc/bash`）の検証コンテナで、公式の統合の無い形で、擬似端末の生の出力を見た（2026-09-30）:
  - starship → この 1 行 → zoxide（と starship → zoxide → この 1 行）: `false` の後は `D;1`。`zoxide: detected a possible configuration issue.` は出なかった
  - この 1 行 → starship（前の版のこの文書の手順 7 の並び）: `D` はいつも `D;0`
  - 当時の統合では、どの並びでも、starship がいると `PS1` の OSC 133 の印（`A` / `B`）は無くなった。2026-10-06 に、既存のプロンプト処理の後で印を付け直すよう修正し、Windows の Git Bash で A / B と出力コピーの復帰を確認した
  - 2026-09-30 の時点では、画面でのプロンプトへのジャンプや、出力のコピーへの影響は確かめていなかった。2026-10-06 の実 GUI の結果は[ホストでの検証記録](#付録-windows-11-のホストでの動作検証2026-10-06)
- 前の版のこの文書（2026-09-30 まで）は、この 1 行を starship の行の前に差し込んでいた。そのホストは、setup-notes の starship.md の手順 3〜6 で starship の行を前へ移す（この 1 行は動かさなくてよい）

### 実施手順 — 手順 9: 検証コンテナでの出力

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

### ssh 先でもシェル統合を使う（任意） — 手順 2: AlmaLinux 10 の sshd の既定と、検証コンテナでの出力

- AlmaLinux 10.2 の既定の sshd は、`AcceptEnv` を 1 つも持たない（`sshd -T` に `acceptenv` の行が出ない）
- `/etc/ssh/sshd_config` の `Include /etc/ssh/sshd_config.d/*.conf` が、このファイルを読む。`AcceptEnv` は、ほかの行やファイルにあっても足し合わされる
- 検証コンテナ（systemd が PID 1）での出力は、次の 2 行だった。journal には `Received SIGHUP; restarting.` と `Reloaded sshd.service - OpenSSH server daemon.` が出た

```
AcceptEnv TERM_PROGRAM
acceptenv TERM_PROGRAM
```

### 実施手順 — 手順 0 の記載

> **導入・更新・ロールバックの全分岐は AlmaLinux 10 の x86_64 コンテナで検証した**。新規 x86_64 VM では、共通 bash 設定を使う分岐の導入、実 GUI、日本語入力、公式シェル統合、更新・ロールバックを確認した（2026-10-06。[新規 VM の記録](#付録-現行版の新規-vm-での再検証2026-10-06)）。Windows 11 の実ホストの画面・分割・OS 通知と、外部 SSH の統合の制限は以前の検証記録にある。aarch64 の Linux GUI、物理キー・マウス、この VM での WSL・SSH 任意節は未実施。各環境の範囲は[対象と検証環境](#対象と検証環境)を参照。

### 実施手順 — 手順 4 の記載

- Windows で `wezterm: command not found` と出たら、`"/c/Program Files/WezTerm/wezterm.exe" ls-fonts --text 'aあ'` のようにインストール先から呼ぶ（試していない）

### 実施手順 — 手順 6 の記載

- zsh を使うなら、同じ行を `~/.zshrc` にも足す（試していない）

### WSL でもシェル統合を使う（任意） — 手順 0 の記載

- **この節のコードブロックは流していない**。Windows の実ホストの WSL 2 環境は、Linux 側の既定パスに統合を置く方法で検証した（[ホストでの検証記録](#付録-windows-11-のホストでの動作検証2026-10-06)）

### ssh 先でもシェル統合を使う（任意）の適用範囲

- この設定の統合が動けば、タブ名が `<HOST>:<ディレクトリ名>` になり、ssh 先でもプロンプトへのジャンプ・出力のコピー・完了通知が使える。公式統合が先に読まれる場合は完了通知が動かず、Starship との併用では出力の区切りも失われることがある（[追加検証](#付録-os-通知と外部-ssh-の追加検証2026-10-06)）

## 補足にあった検証記録

  - Windows の WezTerm も `%USERPROFILE%\.config\wezterm\wezterm.lua` を読む。2026-10-06 に、既存配置の設定読み込みと新規 GUI の起動を確認した（clone・退避・ロールバックの全手順は未実施）
  - 公式の統合は `WEZTERM_SHELL_SKIP_ALL=1` で止まる。検証コンテナで、この値を付けて起動したシェル（`wezterm cli spawn -- env WEZTERM_SHELL_SKIP_ALL=1 bash -l`）では、この設定の統合がすべて読まれた。この設定の `lua/shells.lua` は、まだこの値を渡していない
  - stable では、nightly だけの設定（README の「使用している nightly 限定機能」）が `ERROR  wezterm_gui >` になり、組み込みの既定の設定で開く見込み（stable では試していない。存在しない設定名を足したときの出方は、手順 4 の補足）
  - Windows では、`wezterm.exe` と同じフォルダーの `wezterm.lua` も探される（公式の [Configuration Files](https://wezterm.org/config/files.html)。試していない）
  - AlmaLinux 10（COPR の WezTerm）では `D` は公式の統合が送るので、どちらの並びでも失敗したコマンドは `D;1` になる（上流の `wezterm.sh` を読ませた模擬での実測）
  - 2026-09-30 の検証では、どの並びでも Starship が PS1 の OSC 133 A / B を消した。この設定の統合を使う場合は 2026-10-06 の修正で印が戻る。公式統合が先に読まれる環境の制限は[追加検証](#付録-os-通知と外部-ssh-の追加検証2026-10-06)
- **Git Bash の `~/.bash_profile`**（試していない）
  - `C:\msys64\home\<WIN_USER>\.bashrc` と `C:\QMK_MSYS\home\<WIN_USER>\.bashrc` にも、手順 6 の 1 行を足す（README の「bash（Git Bash / MSYS2 / QMK MSYS / Linux）と zsh」。試していない）
- setup-notes の [wezterm-nightly.md](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#wezterm) — WezTerm nightly の導入と、設定ファイルの探索順序の実測

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
| 1 | u1（設定無し） | 手順 1・3〜6・8（mux）・9、[更新](https://github.com/ryo-aoki-pc/wezterm/blob/f7fe6b33b36e806e99148d9551f16f0ee01e4949/docs/install.md#更新)の手順 1、[ロールバック](https://github.com/ryo-aoki-pc/wezterm/blob/f7fe6b33b36e806e99148d9551f16f0ee01e4949/docs/install.md#ロールバック)の手順 1〜3 | 手順 1 は 2 行とも `No such file or directory`。手順 4 は HackGen が無い警告と `ERROR  wezterm_toast_notification::dbus` で、`ERROR  wezterm_gui` は無し。手順 5 は何も出さなかった。手順 9 は `WezTerm`・`/home/<USER>/.config/wezterm/shell/wezterm.sh`・`__wezterm_set_user_var`・`__wz_mouse_off`。更新は `Already up to date.`。ロールバックは `0`・`## main...origin/main`・`No such file or directory` |
| 1 | r1（ssh 先） | 手順 1・3〜6、[ssh 先の節](https://github.com/ryo-aoki-pc/wezterm/blob/f7fe6b33b36e806e99148d9551f16f0ee01e4949/docs/install.md#ssh-先でもシェル統合を使う任意)の手順 2（r1）と手順 4・5（u1 の mux のペインから）、ロールバックの手順 6・1〜3 | ssh 先の節の手順 2 は、手順 2 の補足の 2 行。手順 5 は `WezTerm`・`__wezterm_set_user_var`・`__wz_mouse_off`（ssh 先にも COPR の WezTerm があるため）。`wezterm cli list` のペインの CWD は `file://<HOST>/home/r1/`。ロールバックの手順 6 は `removed '/etc/ssh/sshd_config.d/50-wezterm.conf'` で、reload の後の `sshd -T` に `acceptenv` の行は無かった |
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

## 2026-10-06 の Starship 共存修正に伴う追加記録

以下は upstream `6474a968ad06844d078828468f762272f751a4b0` の導入文書から移した原記録。この文書分離の作業では実行していない。修正前の付録も当時の結果として保持する。

### 修正後の状態（2026-10-06）

- **状態**: **導入手順全体は x86_64 のコンテナで検証済み（2026-09-30）。新規 AlmaLinux 10.2 / x86_64 VM の共通 bash 分岐と実 GUI、更新・ロールバックも確認した（2026-10-06）。既存設定の動作は Windows 11 の実ホストでも検証した（2026-10-06）。同日に Git Bash + Starship / SSH 先の公式 Bash 統合との共存を修正し、配置後の通常 SSH のコピー・パイプ状態・独自通知を確認済み**
  - 新規 VM では nightly `20261005_054844_37254829` とこの設定 `4bdfbf1` を使い、既存設定の退避、clone、フォント解決、実 GUI の起動、実タブの公式シェル統合、Anthy の確定、更新と設定の復帰を確認した。共通 bash を使うため手順 6・7 は条件外。全キー操作と WSL / SSH 任意節はこの VM では実施していない（[付録](#付録-現行版の新規-vm-での再検証2026-10-06)）
  - 下表の検証コンテナで、**この文書の bash のコードブロックを抜き出したもの**を、一般ユーザーの `bash -s` に手順ごとに流した（[付録](#付録-コンテナでの検証記録2026-09-30)）
  - 手順 8・9 は、WezTerm の画面の代わりに、そのユーザーの `wezterm-mux-server` を起動し直し、開いたペインに手順 9 のブロックを打ち込んで、画面の文字を `wezterm cli get-text` で読んだ
  - 並びを直した手順 5〜7（starship の行より後ろ、zoxide の行より前）は、2026-09-30 に別の AlmaLinux 10.2 のコンテナで、6 つの `~/.bashrc` に流し直した（手順 7 の `sed` の探す文字列を直した後の 2 つを含む）。WezTerm は入れず、この設定の `shell/wezterm.sh` を読んだ対話のシェルを `script` の擬似端末で動かして、OSC 133 を生の出力で見た（[付録](#付録-並びを直した版の検証2026-09-30)）
  - 確認したこと: 既存の設定の退避と戻し、clone、`wezterm ls-fonts` での読み込み（HackGen Console NF の有無の両方）、`~/.bashrc` の 1 行（今の手順 7 の、zoxide の行の前への差し込みは、並びを直した版の検証で）、WezTerm が起動したシェルに `TERM_PROGRAM` と `WEZTERM_SHELL_INTEGRATION` が入ること、公式のシェル統合との関係、ssh 先の節（`systemctl reload sshd` と、mux のペインから ssh した先での確かめ）、更新、ロールバック
  - Windows 11 では、nightly の実 GUI でフォント・日本語・タブ・ランチャー・パレット・分割・OSC 7 / 133・出力コピー・プロンプトジャンプ・完了通知データを確認した。WSL と修正内容の詳細は[ホストでの検証記録](#付録-windows-11-のホストでの動作検証2026-10-06)
  - 追加検証では、Windows の成功・失敗の通知バナーを実画像で確認し、外部の AlmaLinux 10.2 / aarch64 の SSH 2 台で既存の公式統合と一時的なこの設定の統合を比較した。正常な範囲と既存設定の制限は[追加検証の記録](#付録-os-通知と外部-ssh-の追加検証2026-10-06)
  - 2026-10-06 に、この作業ツリーの `shell/wezterm.sh` を使い、Windows の Git Bash + Starship を別途検証した。20 条件の必須確認 367 件（helper 14 件を含む）がすべて成立した。実 WezTerm の隔離ペインでも出力コピーと Prompt / Input / Output の範囲生成を確認した（[付録](#付録-git-bash-と-starship-の修正後の検証2026-10-06)）
  - 2026-10-06 の修正前の検証で、既存の AlmaLinux 10.2 / aarch64 ホストへ Windows の WezTerm から SSH 接続し、Starship と公式統合の実ペイン動作を確認した。入力開始の印が欠け、直前出力の代わりにログイン時の出力をコピーする不具合が再現した。既存設定の変更や、この文書の導入手順の再実行は行っていない（[付録](#付録-ssh-先の-starship-の検証2026-10-06)）
  - 同日に公式 Bash 統合との共存を修正した。SSH 22 条件の必須 438 件、Git Bash の回帰確認 367 件、実 WezTerm の比較確認 84 件が成立した。配置前の控えと SHA を照合して Windows / `kawasaki-pi` の `shell/wezterm.sh` だけへ反映し、パス上書きの無い通常 SSH の 37 件も成立した（[付録](#付録-ssh-の公式-bash-統合と-starship-の共存修正後の検証2026-10-06)）
  - **確認していないこと**: Windows での導入・更新・ロールバックの全ブロック、物理キーとマウスの入力、Windows の IME の未確定表示、OS の通知センターを開いた状態の表示、MSYS2・QMK MSYS・zsh・macOS、aarch64 の Linux GUI。今回の Linux VM では全キー操作・OS 通知・プロンプトジャンプ・出力コピー・SSH / WSL 任意節も実施していない。Starship 共存修正後の追加検証は通知データまでを対象とし、OS 通知表示は再確認していない


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


### 実施手順にあった検証範囲の追記（2026-10-06）

> [!WARNING]
> **導入・更新・ロールバックの全分岐は AlmaLinux 10 の x86_64 コンテナで検証した**。新規 x86_64 VM では、共通 bash 設定を使う分岐の導入、実 GUI、日本語入力、公式シェル統合、更新・ロールバックを確認した（2026-10-06。[新規 VM の記録](#付録-現行版の新規-vm-での再検証2026-10-06)）。Windows 11 の実ホストの画面・分割・OS 通知と、外部 SSH の統合の制限は以前の検証記録にある。同日に Git Bash + Starship と SSH 先の公式 Bash 統合との共存を修正し、配置後の通常 SSH でコピー・パイプ状態・独自通知を確認した。aarch64 の Linux GUI、物理キー・マウス、この VM での WSL・SSH 任意節は未実施。各環境の範囲は[対象と検証環境](#修正後の状態2026-10-06)を参照。

- 2026-09-30 の検証は修正前の統合を使った記録なので、当時の結果は[付録](#付録-並びを直した版の検証2026-09-30)に残している
- 2026-10-06 の実 GUI の結果は[ホストでの検証記録](#付録-windows-11-のホストでの動作検証2026-10-06)と、[Git Bash の追加検証](#付録-git-bash-と-starship-の修正後の検証2026-10-06)に分けている

### 手順 9 の補足にあった修正前の出力の説明

以下は公式との共存を修正する前の検証記録。WezTerm の画面の代わりに、`wezterm-mux-server` を起動し直して開いたペインに打ち込み、`wezterm cli get-text` で画面の文字を読んだ:

### SSH 節にあった修正前後の案内

- この設定の統合が動けば、タブ名が `<HOST>:<ディレクトリ名>` になり、ssh 先でもプロンプトへのジャンプ・出力のコピー・完了通知が使える。公式 Bash 統合が先に読まれる場合も、修正版は Starship 後に入力範囲の印と独自完了通知を補う。修正前の制限は[追加検証](#付録-os-通知と外部-ssh-の追加検証2026-10-06)、修正後の結果は[共存修正後の検証](#付録-ssh-の公式-bash-統合と-starship-の共存修正後の検証2026-10-06)に分けている

### 付録: Git Bash と Starship の修正後の検証（2026-10-06）

Windows の Git Bash `5.3.15(2)-release`、Starship `1.26.0`、WezTerm `20260905-153129-092dcf70` で、この作業ツリーの `shell/wezterm.sh` の修正後の動作を確かめた。専用の rc と Starship 設定、隔離した WezTerm のペインを使ったシェル統合の検証。ユーザーのプロファイル・Starship 設定・本番の WezTerm 設定は変更していない。

- `tests/starship/bash-compat-check.py` の 20 条件で、必須確認 367 件がすべて成立した（helper 14 件を含む）
- 推奨の starship → 統合 → zoxide、starship → zoxide → 統合で、OSC 133 A / B / C / D、終了コード、パイプ個別ステータス、完了通知データ、統合の再読込、starship 再初期化を確認した。統合を追加読込しない starship 再初期化単独の補助確認も 10 件すべて成立した
- `set -u`、行編集あり・なし、scalar / array の既存フック、旧版のフックを含む配列、配列の export 属性、既存 PS0、履歴設定、cwd、`BASH_REMATCH`、日本語・絵文字を含むユーザー変数の境界も確認した
- 実 WezTerm の隔離ペインでは、23 snapshots の 19 件の確認がすべて成立した。Starship 起動時と後付け後のどちらも Prompt / Input / Output の範囲が生成され、直前の出力だけをコピーできた。プロンプトジャンプ後の可視範囲、cwd の分割先への引継ぎ、リサイズ・コピーモード・ズーム、Bash の失敗通知データ、PowerShell 2 種の回帰確認 8 件を含む
- 統合 → starship の推奨外の並びでは、統合をもう一度読むまで A / B の一部が欠ける。追加読込後の復旧は確認したが、導入時は[手順 5](https://github.com/ryo-aoki-pc/wezterm/blob/f7fe6b33b36e806e99148d9551f16f0ee01e4949/docs/install.md#実施手順)の並びに直して新しいタブを開く

詳しい修正内容、再実行方法、生の出力と未検証範囲は [Git Bash の修正後の検証記録](../../tests/starship/FIX-REPORT.md)に保存した。修正前の結果は [Starship 適用時の検証記録](../../tests/starship/REPORT.md)と上の 2026-09-30 の付録をそのまま残している。

### 付録: SSH 先の Starship の検証（2026-10-06）

Windows の WezTerm `20260905-153129-092dcf70` から、既存の AlmaLinux 10.2 / aarch64 ホストへ OpenSSH で接続した。Starship `1.26.0` が導入済みの `kawasaki-pi` で、通常のログインと隔離した対話 Bash `5.2.26(1)-release` を比較した。

- 既存 SSH 設定と、一時的な `SendEnv=TERM_PROGRAM` の両方で、接続先の `TERM_PROGRAM` は未設定だった。`abiko-pi` も同じ結果だったが、Starship は導入されていなかった
- `kawasaki-pi` は `/etc/profile.d/wezterm.sh` の公式統合 → Starship → この設定の統合 → zoxide の順で読まれた。公式統合は `TERM_PROGRAM` を条件にせず動き、この設定の独自統合はマウス報告よけの後で終了した
- 実 WezTerm の通常ログインでは、Starship が作り直すプロンプトから入力開始の OSC 133 B が消えた。出力コピーは直前の試験出力を選ばず、ログイン時の出力を選び続けた。独自の完了通知データも送られなかった
- SSH の実 PTY では 12 条件の必須 220 評価のうち 210 件が成立し、10 件は不成立だった。公式統合を外した修正版の 7 条件は 129 件すべて成立した。公式経路の入力開始の印・一部コマンドの実行開始の印、修正版を公式経路で読み直した際のマウス解除の重複、公式を外して配置済み旧版だけ読む比較条件のパイプ状態が不成立だった
- 実ペインの通常ログインでは `false | true` の Starship / bash-preexec の保存値は `1 0` を保った。公式統合を外した修正版の隔離ペインでもパイプ状態を保持し、試験出力だけのコピーと失敗の独自完了通知データを確認した
- 実 WezTerm では 53 snapshots を記録し、成立する機能 46 件と既知不具合の再現 10 件を分けて確認した。公式を外した修正版は Git Bash 経由 / Windows OpenSSH 直接の両方で各 11 件が成立。公式経路の cwd・タブのホスト表示・プロンプトジャンプは正常だったが、入力範囲・出力コピー・独自通知には問題があった
- 本番 Lua 関数をモデル化した確認では、SSH 判定・コピー・タブ・通知の必須 36 件が成立し、エイリアスと短縮ホスト名衝突の制限 3 件も確認した。実際の通信や OSC 解釈の結果とは分けて記録した
- この検証では本番のシェル統合、プロファイル、Starship 設定、SSH / sshd の設定を変更していない。履歴は `HISTFILE=/dev/null` または `unset HISTFILE` で保存を避けた
- 試験用 GUI / ペインを終了し、リモートの専用一時ディレクトリも削除後の不存在を確認した。既存のユーザーの WezTerm プロセスは維持した

隔離した修正版の条件別集計、実ペインの証拠、再実行方法と制限は [SSH 先の Starship 検証記録](../../tests/starship/SSH-REPORT.md)に保存した。過去の付録と導入コマンドは変更していない。

### 付録: SSH の公式 Bash 統合と Starship の共存修正後の検証（2026-10-06）

公式統合の cwd・ユーザー変数・bash-preexec を残し、semantic の 2 フックだけを独自処理へ移す修正を行った。独自のプロンプト区切りと完了通知を、Starship のプロンプト更新後に送る。公式のない Git Bash 経路も保ち、初期化の 1 行・配置先・SSH / sshd の設定・読む順番は変更していない。

- 最終ソースの SHA-256 は `40bbe213610c39019a1b394ae6a02dcc8b7dba64f2a87bdb7fbaca2a99532595`。実 SSH 22 条件の必須 438 / 438、Git Bash 20 条件の必須 367 / 367 が成立した
- 実 WezTerm の比較は 76 snapshots の機能 84 / 84 と、旧版の不具合比較 2 / 2。複数行、サブシェルの終了コード 7、再読込、Starship 再初期化後の復旧、入力範囲、コピーと独自通知を確認した
- 公式へ委譲する条件は 5 条件の限定モデルで 90 / 90。実 tmux / ble.sh の起動は未実施、zsh は手元と両 SSH ホストにコマンドが無く、構文・実行は未確認
- 配置前の内容 `8ed8a09c...` を控えへ保存し、SHA を照合して Windows と `kawasaki-pi` の `shell/wezterm.sh` だけへ反映した。配置後の通常 SSH は、パス上書きなし・Git Bash 経由 / Windows OpenSSH 直接で、28 snapshots の機能 37 / 37 が成立した
- 比較・補助で残る制限を分けた。公式経路で starship だけを直接再初期化したときの登録重複は、統合の再読込で単独化する。通常の個人 Bash 設定では再初期化をガードしている
- 個人 Bash README の「読む順番」に今回の実測を追記した。初期化の 1 行・配置先は不変なので、個人 Bash の `bashrc` / `migrate` は変更していない
- 試験用 GUI / ペインとリモートの専用一時ディレクトリを終了・除去し、既存のユーザーの WezTerm プロセスを維持した

条件別の集計、ソースハッシュ、配置前の控えと反映後の確認、制限は [SSH の修正後の検証記録](../../tests/starship/SSH-FIX-REPORT.md)に保存した。修正前の記録は上の付録と [SSH-REPORT.md](../../tests/starship/SSH-REPORT.md)にそのまま残している。


## 2026-10-11 の PowerShell 貼り付け修正に伴う追加記録

対象は `9cb9f771df782199c79f5cf13fb4ded930759b21` を基にした
`codex/fix-powershell-paste` の変更。右クリックと Ctrl+Shift+V を共有操作へ移し、
Windows のローカル PowerShell が PSReadLine で入力を待っている間だけ `Paste` を呼ぶ。
元からある空行を保持し、貼り付け後に Enter を押して実行する。

検証環境は Windows 11、WezTerm `20260905-153129-092dcf70`、Windows PowerShell
`5.1.26100.9444` / PSReadLine `2.0.0`、PowerShell `7.6.5` / PSReadLine `2.4.5`。
ユーザープロファイルと通常の WezTerm 設定は変更していない。

通常プロファイルの関連する設定は、両 PowerShell とも Emacs 編集モードと
`Ctrl+Enter → AddLine`。この割り当てを専用ペインに再現すると、旧 `PasteFrom` で
4 行のスクリプトブロックを貼った入力バッファが、両版・LF/CRLF とも 7 行になり、
各行の境界に空行が増えた。
画面の描画だけでなく、PSReadLine の `GetBufferState` で余分な LF を確認した。
同じ文字列を修正後の操作で貼ると 4 行のまま保持し、Enter 前は実行回数 0、Enter 後は 1 だった。
`Ctrl+Enter → AddLine` を設定しない最小構成では、この空行増加は再現しなかった。

コピー元は利用者の申告では GitHub の Markdown コードブロックのコピーボタン。
試験には生成した無害なコードを使い、元のクリップボードや通常ペインの履歴は採取していない。

内部の経路は、Windows 既定の [CRLF 正規化](https://wezterm.org/config/lua/config/canonicalize_pasted_newlines.html)、
[ConPTY の CR とほかの制御文字のキー変換](https://github.com/microsoft/terminal/blob/7d06b26f73ef4bcb78b56647c395251eeee4c2bc/src/terminal/parser/InputStateMachineEngine.cpp#L150-L211)、
PSReadLine 2.0.0 の [未完入力での AcceptLine](https://github.com/PowerShell/PSReadLine/blob/v2.0.0/PSReadLine/BasicEditing.cs#L215-L222) と
[AddLine](https://github.com/PowerShell/PSReadLine/blob/v2.0.0/PSReadLine/BasicEditing.cs#L464-L467)
の実装と整合する。この Windows で `VkKeyScanW` を読み取り専用で比較すると、CR は
`0x000D`、LF は `0x0A0D`（両方 Enter、LF は Ctrl 修飾も含む）だった。
CR の Enter と LF の Ctrl+Enter がそれぞれ LF を挿入するという説明は、公式ソースと
API 比較に基づく推定であり、入力バッファの 4 行 → 7 行は実測で確認した結果である。

- 設定を `ls-fonts` で読み込み、`ERROR` が無いことを確認した。`show-keys` でも右クリックの
  2 経路と Ctrl+Shift+V が同じ共有操作を参照することを確認した
- `tests/paste/lua-behavior.lua` は 24/24 通過。入力待機、実行中、統合なし、古いマーカー、
  SSH・WSL・TUI・別ドメイン・alternate screen・キーテーブル・Linux/macOS の分岐を模擬した
- `tests/paste/check-powershell.ps1` は両 PowerShell で各 21/21 通過。実 PSReadLine の
  Emacs モードへのキー登録、EditMode 再設定と再読み込み、登録失敗、元入力関数の例外、
  待機マーカーの解除、C 印と戻り値の保持、StrictMode、UTF-8 BOM と構文を確認した
- `tests/paste/live-run.py --shared-clipboard` の修正後の 96/96 ケースが通過した。
  6 種類のコード（通常の 2 行・block・元からある空行・日本語・here-string・末尾改行）×
  LF/CRLF × 4 経路（共有操作・右クリック 2 設定・Ctrl+Shift+V）×両 PowerShell の組み合わせで、
  入力バッファの完全一致、Enter 前の実行回数 0、Enter 後の 1 回実行と期待値、空バッファを確認した
- 同じ試験に含めた旧 `PasteFrom` の比較 24 件は、いずれも「入力保持かつ Enter 前に未実行」
  の条件を満たさなかった。block では実空行が増え、通常の 2 行では先頭行が貼り付け中に実行された
- 入力待機中のマーカー `1`、コマンド実行中の解除、再待機の復帰を両版で確認した。
  統合を読み直した後も、Windows PowerShell の右クリックと PowerShell 7 の Ctrl+Shift+V の
  block 貼り付けが各 1/1 通過した
- 実ペインの effective config は `allow_win32_input_mode=true`、
  `canonicalize_pasted_newlines=platform-default`。この 2 設定は変更していない。
  最終全件結果は `tests/paste/results/20261011-200508/summary.json` に保存した
- 二重 CR を意図的に作った補足試験も、両版の修正後の 8/8 ケースが通過した。
  旧 block は 7 行、修正後は 4 行であり、二重 CR は元症状の再現に必須ではない。
  結果は `tests/paste/results/20261011-200804/summary.json` に保存した
- 既存の `tests/starship/lua-behavior.lua` は 49/49 通過。PowerShell の既存検証は
  74 プロセスケース、34 callback チェック、標準チェック 494/494 が通過し、予期しない失敗は 0。
  既知失敗として分類する 4 件（各版の `integration-first` と `threshold-large`）は今回の変更で扱わない
- Lua の読み込み、両 PowerShell の構文解析、Python の構文解析、`git diff --check` を通した。
  詳細結果は `tests/paste/results/` に保存し、Git の管理対象には含めない

再実行の方法と実ペイン比較用の試験コードは
[PowerShell の貼り付け検証](../../tests/paste/README.md)にある。
実ペインの試験では設定の各 action を `window:perform_action` で呼び出した。
SSH・WSL・Neovim・PSReadLine なしなどの切り替えは Lua の模擬 API で確認し、実セッションへは接続していない。
クリップボードは無害な試験コードで置換し、元の内容を読まないため復元せず、試験後もコードが残る。

## 共存修正前の説明

以下は元の固定コミット `92f799a6ee6f45d1648db622760ffeea2ed5ad98` の説明。現行の実装は[参照情報](../reference/install.md)を参照。

### 実施手順 — 手順 5: starship の行より後ろ、zoxide の行より前に置く理由

- starship は、既にある `PROMPT_COMMAND` を `STARSHIP_PROMPT_COMMAND` に退避して、自分の中から呼ぶ。シェル統合が starship より前にあると、統合の関数がその退避先に入り、呼ばれるときの `$?` がいつも 0 になる
- starship より後ろなら、統合は `$?` を保つ関数を `starship_precmd` の前に足すので、OSC 133 の `D` に正しい終了コードが入る
- zoxide は `~/.bashrc` のいちばん最後に置く（当時の setup-notes の zoxide.md 手順 6。今は [AlmaLinux 10 の初期設定](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md)）。統合は `PROMPT_COMMAND` の先頭に足す
- 前の版のこの文書は、この 1 行を starship の行の前に差し込んでいた。そのホストは、setup-notes の starship.md の手順 3〜6 で starship の行を前へ移す（この 1 行は動かさなくてよい）


### 注意点

- **AlmaLinux 10（COPR の WezTerm）では、この設定のシェル統合の大半が働かない**
  - `wezterm-common` の `/etc/profile.d/wezterm.sh` は、`TERM_PROGRAM` を見ずに、すべての対話シェルで読まれる（ログインシェルは `/etc/profile`、そうでないシェルは `/etc/bashrc` から）
  - `shell/wezterm.sh` は、公式の統合の関数（`__wezterm_set_user_var`）を見つけると、マウス報告よけだけを残して抜ける（同じ名前の `__wezterm_osc7` を上書きして、公式のフックを壊さないため）
  - 今のディレクトリ（OSC 7）とプロンプトの位置（OSC 133）は、公式の統合が送る。長いコマンドの完了通知（`__wezterm_notify_done`）は動かない
  - 公式の統合は `WEZTERM_SHELL_SKIP_ALL=1` で止まる。この設定の `lua/shells.lua` は、まだこの値を渡していない
- **WezTerm は nightly が要る**
  - stable では、nightly だけの設定（README の「使用している nightly 限定機能」）が `ERROR  wezterm_gui >` になり、組み込みの既定の設定で開く見込み
- **`~/.wezterm.lua` があると、`~/.config/wezterm` は読まれない**
  - Windows では、`wezterm.exe` と同じフォルダーの `wezterm.lua` も探される（公式の [Configuration Files](https://wezterm.org/config/files.html)）
- **starship と一緒に使うとき**: シェル統合の行は、starship の行より後ろに置く
  - starship より前に置くと（前の版のこの文書の手順 7 の並び）、公式の統合が無いとき（この設定の統合が働く Windows の Git Bash など）は、コマンドの終了コード（OSC 133 の `D`）がいつも 0 で送られる
  - AlmaLinux 10（COPR の WezTerm）では `D` は公式の統合が送るので、どちらの並びでも失敗したコマンドは `D;1` になる
- **Git Bash の `~/.bash_profile`**
  - WezTerm は Git Bash をログインシェル（`-l`）で起動するので、`~/.bashrc` は `~/.bash_profile` から読まれる必要がある
  - Git for Windows は、`~/.bashrc` があって `~/.bash_profile` などが無いと、`~/.bashrc` を読む `~/.bash_profile` を作り、`WARNING: Found ~/.bashrc but no ~/.bash_profile` と表示する
- **MSYS2・QMK MSYS は、ホームが別**
  - `C:\msys64\home\<WIN_USER>\.bashrc` と `C:\QMK_MSYS\home\<WIN_USER>\.bashrc` にも、手順 6 の 1 行を足す（README の「bash（Git Bash / MSYS2 / QMK MSYS / Linux）と zsh」）
- **完了通知は、OS の通知の設定にも従う**
  - Windows は「設定 → システム → 通知」で WezTerm が許されているか、集中モードになっていないかを見る（README の「長いコマンドの完了通知」）


### 付録: Windows の SSH 先の PowerShell へ貼り付ける修正（2026-10-12、V1 の記録）

[PR #39](https://github.com/ryo-aoki-pc/wezterm/pull/39) のローカル Windows 用経路を保ち、SSH 先の PSReadLine 入力待機中に専用キーで受信を始める経路を追加した。接続元で取得したテキストを改行なしの Base64 フレームで配送し、受信側の公開 `Insert` / `Replace` API でバッファへ挿入する。Enter は送らない。

接続元は AlmaLinux 10.2 / aarch64、WezTerm `20261010_083911_e2a98e1b`、専用 headless Mutter と Wayland clipboard。接続先は Windows 11 の `surface`、既定シェル Git Bash、WezTerm `20260917-114457-b09b56c2`、Windows PowerShell `5.1.26100.9444` / PSReadLine `2.0.0` と PowerShell `7.6.6` / PSReadLine `2.4.5`。SSH で起動した親は管理者だった。同じユーザーの非管理者子は SHA-256 を確認した busybox-w32 `FRP-6075-g169694ebd` の `drop --` で開いた。

| 検証 | 結果 | 実施範囲 |
| --- | --- | --- |
| Linux の実 WezTerm → SSH → Windows | 最終 12/12、起動診断付き追加 3/3 | 5.1 / 7 × 管理者 / 非管理者、共有操作・右クリック・Ctrl+Shift+V。入力バッファ一致、Enter 前の未実行、Enter 後の一度だけの実行 |
| Windows の実 WezTerm → ローカル ConPTY に SSH 環境を再現 | 期限確認追加前の 48/48 と 6/6 | 実クリップボードと共有操作の 3 経路。`real_ssh=false`、Windows からの実 SSH 接続とは区別 |
| Linux の実 SSH / ConPTY で受信を直接検証 | 最終 76/76 | 5.1 / 7 × 管理者 / 非管理者、正常・不正・取消・無応答・再読み込み・親 PowerShell / Git Bash へ戻る経路 |
| 64 KiB の上限付近 | 74/74 | `unavailable` の追加前の受信処理で 65,536 バイトを保持し、65,537 バイトを拒否。両 PowerShell と両権限 |
| Lua の API stub による状態検証 | 78/78 | 取得失敗・不正・大きさ・無応答・古い / 偽 / 重複 READY・ペイン切替・状態失効・`unavailable`・既存経路 |
| SSH の入力関数・マーカーの単体検証 | 各版 16/16 | 解除・戻り値・例外・再読み込み・EditMode の再設定・キー登録失敗・StrictMode・PSReadLine 無効化 |
| 既存ローカル PowerShell の単体検証 | 各版 21/21 | PR #39 のキー登録・待機マーカー・失敗経路を維持 |
| 既存 PowerShell / Starship の標準回帰 | 74 プロセスケース、34 callback、494/494 | 既知失敗 4 件（両版の `integration-first` / `threshold-large`）、予期しない失敗 0 |
| Git Bash / Starship の回帰検証 | control 26/26、nounset 34/34、array-before 35/35、最終単独 37/37 | 終了コード・プロンプト・フック・通知と新しいマーカー解除の共存 |

UI の処理が止まり、期限の timer より古い READY が先に処理される競合を見つけた。Lua の待機状態に開始時刻と 3 秒の期限を保存し、READY 処理でも期限の到達・超過・時計の後戻りを確認するように修正した。timer 未処理の期限境界・5.5 秒遅延・時計の後戻りを拒否し、期限直前の正常応答は一度だけ送る回帰を追加した。実 WezTerm の時刻 API は Linux / Windows で検証し、Lua は両環境で 78/78 が成功した。 修正後の Lua SHA-256 は `613b50588dd3bfd43a346b130a6892cf6e366b22bc8790bebac0b7245e3f9e44`。Linux の実 SSH GUI は修正後も 12/12 が成功した。

正常入力は LF / CRLF、空行、日本語・絵文字、here-string、タブ、末尾改行と選択範囲を含めた。CR を取り除き、タブを 4 空白にする PSReadLine の既存 `Paste` と同じ結果を比較した。不正入力は nonce、長さ、Base64、UTF-8、NUL、終端直前 LF を送り、元のバッファが変わらないことを確認した。受信途中の Ctrl+C は終端まで読み捨て、本文を挿入しなかった。本文の無応答は受信側で約 5 秒後に解除した。

通常プロファイルの子シェルを起動した試験でも、非管理者では同じユーザー、`IsInRole(Administrator)=False`、Medium、管理者 SID が拒否専用だった。取消後に子を終了すると、管理者の親のバッファは空、実行カウンターは増えず、子の READY / RESULT / 待機マーカーが消えた。親 PowerShell を終了して Git Bash へ戻る試験でも 3 マーカーと `READLINE_LINE` が空だった。専用 TEMP の統合を起動コマンドから読み、通常プロファイルには追記していない。

最終の PowerShell ソース SHA-256 は `5f4b84bc493adb9a948983c0ffebe8f0719ef01b6ee7e5cfd2649e98c0858f07`、Bash は `13eb17a4a95ce98700c6c0f1b28c26aae84b394d433409f7196b6f584665f7d9`。上限付近の 74/74 は PowerShell `48e0d22f04aaa31fd9b195f97f22564f016ed8b57d56c9162c72708a9af99e7e` を試した。最終版との差は、SSH のキー準備に失敗した場合に `unavailable` を通知する処理で、配送・復号処理は同じ。

結果は Git 管理外の `tests/paste/results/` に保存した。最終受信は `ssh-20261012-024201-1d6123d1/summary.json`、上限付近は `ssh-20261012-023414-600be936/summary.json`、Linux GUI は期限確認追加後の `linux-gui-ssh-20261012-025903-69ea2a7c/summary.json` と、追加前の診断 `linux-gui-ssh-20261012-024149-502b8789/summary.json`、Windows は `windows-gui-local-final/summary.json` と `windows-gui-local-latest/summary.json`。再実行するコードと条件は [貼り付け検証](../../tests/paste/README.md)にある。

試験途中には、当初の 1 MiB が数分以内に完了せず中断したため、上限を UTF-8 64 KiB に下げた。64 KiB の READY から RESULT まで約 40〜55 秒だった。Linux GUI の初回では PowerShell 7 の非管理者の待機マーカーが空のまま時間切れになったが、同条件の 12/12 と最終の 12/12、起動診断付き 3/3 では再現しなかった。初回原因は未特定。Bash の同時実行ではタイムアウトや短い通知閾値の不成立が出たが、main の比較と最終版の単独実行は 37/37 だった。 PowerShell / Starship の初回 PS5 集計では、既存 checker が BOM なしの callback JSON を ANSI として読み集計が崩れた。採取済み JSON を既存の PS7 checker で読み直し、34 callback を含む 494/494 を確定した。結果は `starship-20261012-025404-937ae999/regression-summary.json` に保存した。

期限確認追加後の Windows GUI は、既存の Python が WindowsApps のエイリアスで起動を拒否され、再実行できなかった。Windows の実 API を含む Lua 78/78 と、追加前の GUI 48/48 と 6/6 を区別する。追加インストールは行っていない。

Windows からの実 SSH は未検証。一時的な `ssh -A surface` の agent 転送は許可を受けて試したが、Windows 側で転送 agent を利用できず、実 SSH 認証まで進めなかった。鍵ファイル・SSH 設定・通常プロファイルは作成・変更していない。Linux の実 GUI → SSH → PowerShell 7 から起動した Neovim の alternate screen と `Read-Host` 待機を追加で確認し、2/2 が成功した。3 マーカーが空の Neovim へ右クリックで通常貼り付けし、日本語・絵文字・空行を含む UTF-8 27 バイトを専用 TEMP に保存して完全一致を確認した。PowerShell に戻ると待機マーカーも復帰した。初回は GUI 内の clipboard 更新直後の貼り付けが空になったため、専用 Wayland の `wl-copy` で既知データを提供して再検証した。結果は `routing-gui-20261012-025707/summary.json`。入れ子 SSH と tmux の実セッションも未検証。Lua の alternate screen / キーテーブルなどの送り分け確認は API stub の結果であり、実機の結果とは分けて扱う。

Bash と zsh の構文、両 PowerShell の構文と UTF-8 BOM、Python の構文、文書リンクと手順順序、`git diff --check` を確認した。zsh は公式 AlmaLinux RPM を専用 TEMP に展開し、システムへインストールせず構文だけを検証した。WezTerm の実設定読み込みは終了コードだけでなく stderr の `ERROR` が無いことを確認した。 ShellCheck 0.11.0 は main と今回の Bash ソースに同じ 16 診断を出した。行番号以外の診断内容・該当ソースを比較して追加診断が無いことを確認し、既存の `SC1007` / `SC2178` / `SC2128` / `SC1003` / `SC2016` を除外したチェックは成功した。Lua / Markdown の専用リンターと PSScriptAnalyzer は未導入で、構文・実設定・手順とリンクの確認で補った。クリップボードは既知の無害な試験コードだけを使い、元の内容を読まないため復元していない。試験の専用 GUI / TEMP / 接続は終了時に片付けた。


### 付録: Grok Build レビュー後の V2 初回追試（2026-10-12）

上の V1 記録を採取後、Grok Build（`grok-4.7`）が差分をレビューした。受信側が早期の `~` やヘッダー前の Ctrl+C で終了すると、遅れて届いた本文が管理者親の入力欄へ残り得ること、通常文字で無期限待機に入ること、ペイン切替で待機を破棄した後に同じ epoch の専用キーを再送できることを指摘した。

V2 は最初の READY の後に `WZP2:<nonce>:` ヘッダーだけを送り、受信側が完全なヘッダーを読んで BODYREADY を返した場合だけ Base64 本文を送る。ヘッダー前の余分な文字・早期終端・Ctrl+C では絶対 5 秒の期限を延ばさない。本文前のクライアント取消は本文を破棄して終端だけを送り、RESULT やマーカー解除後には追加送信しない。同じ epoch で再発火させず、新しい入力待機の通知を待つ。本文の受信開始後は、遅延した残りが親の入力へ漏れないよう、取消後も終端まで読み捨てる。

対象の SHA-256 は PowerShell `334beaa83d8f87f816c8446bc9aed6ee5304f3125b16e758fb14a1f06e672787`、Lua `8de4a8e5a4f43da4b47d33aab036ec53171e05a65354c8f41a423285a543a225`。Bash は V1 試験時から変更していない。

| 検証 | 結果 | 実施範囲 |
| --- | --- | --- |
| Linux の実 WezTerm → SSH → Windows | 12/12 | 5.1 / 7 × 管理者 / 非管理者、共有操作・右クリック・Ctrl+Shift+V。バッファ一致、Enter 前の未実行、Enter 後一度だけの実行 |
| Linux の実 SSH / ConPTY で受信を直接検証 | 108/108 | 5.1 / 7 × 管理者 / 非管理者の各 26 ケース、通常プロファイルの子から管理者親へ復帰 2 件、PowerShell から専用 Git Bash へ復帰 2 件 |
| SSH マーカーと既存ローカル貼り付けの単体検証 | 各版 16/16 と 21/21 | PS5 / PS7 の専用 NoProfile プロセス。パーサーのエラーも両版 0 |
| Lua の状態検証 | Linux / Windows 各 100/100 | 実 WezTerm の時刻 API と stub。二段 READY、古い / 偽 / 重複 BODYREADY、準備期限・時計の後戻り、取消、同じ epoch の再送抑止、RESULT 後の終端非送信、旧版混在、既存経路 |

Linux GUI の結果は `tests/paste/results/linux-gui-ssh-20261012-032011-ce8e32e7/summary.json`、Windows Lua は当初 `tests/paste/results/windows-lua-v2/lua.json` に採取した。このファイルは後の 102 件の追試で上書きされ、最終結果を別のファイルへ退避した。Windows の実 SSH GUI は未検証で、V1 のローカル ConPTY 48/48 と 6/6 は V2 の GUI 試験とは区別する。

実 SSH の結果は `tests/paste/results/ssh-20261012-032034-430fdfbf/summary.json`。追加 8 回帰を全 4 条件で試し、元の入力バッファが空で Enter 前の実行も無かった。ヘッダー前の取消・部分ヘッダー・連続不正文字は約 5.03 秒で終了し、BODYREADY を発行しなかった。完全なヘッダー後は 5 秒を超えても終端まで待ち、本文前に取消した後の管理者親と Git Bash には本文が残らなかった。SSH 状態・ローカル単体の結果は `/tmp/codex-ssh-v2-state-00efd734c29b4fb89a2bf3ed0fedb8b8/` に採取した。すべて専用接続と TEMP を片付けた。


### 付録: V2 の送信失敗・入出力例外の追試（2026-10-12、nonce 終端追加前）

Grok Build（`grok-4.7`）の V2 再レビューで、送信完了の記録が `send_text` より前だったため、送信例外で終端取消を送れないことと、受信の Console 入出力例外が終端の読み捨てを中断することを指摘された。送信成功後にだけ完了を記録するよう直し、受信側は `IOException` / `InvalidOperationException` を不正として終端まで読む。持続した入力故障でも本文の受信後に入力欄へ戻さず、接続元からペインを閉じて復旧する。

「ヘッダー前の期限到達時に未読本文が残る」という別の指摘は採用しなかった。V2 の接続元は BODYREADY 前に本文を保持し、受信側は `started=true` にしてから BODYREADY を発行する。`started=true` ではヘッダー期限は適用しないため、ヘッダー期限で戻る時点にこの接続元が送った本文は存在しない。前節の実機回帰と、Lua の二段待機を照合する試験で確認した。

最終ソースの SHA-256 は PowerShell `b79886ec05c756f5c6ef01acde5ac996170f107351d030c862c19d43f0d4dfa4`、Lua `e08ef96636a3d1eab0c6371e49ed3995550612f272a8765086aebc2d626144ac`。

| 検証 | 結果 | 実施範囲 |
| --- | --- | --- |
| Lua の状態検証 | Linux / Windows 各 102/102 | 100 件に完全送信失敗・部分送信失敗を追加。終端だけで取消し、本文再送と同じ epoch の再発火をしない |
| Linux の実 WezTerm → SSH → Windows | 代表 3/3 | 最終両ソースの PowerShell 7 管理者で共有操作・右クリック・Ctrl+Shift+V。バッファ一致、Enter 前未実行、Enter 後一度だけの実行 |

結果は `tests/paste/results/windows-lua-v2-body-failure/lua.json` と `linux-gui-ssh-20261012-033356-d523a110/summary.json`。初回 V2 の上限・型キャッシュ追加試験は `ssh-20261012-032350-f7469421/summary.json` の 112/112。PowerShell `334beaa…` で 65,536 バイトを保持し、65,537 バイトは両版・両権限で拒否した。正常受信は PS5 管理者 34.287 秒・非管理者 53.101 秒、PS7 管理者 37.009 秒・非管理者 56.204 秒。旧 V1 型を試験用プロセスに先に作ってから V2 の初回読み込みと再読み込みも確認した。同名 V2 型を更新する試験ではなく、更新時には新しいプロセスを使う。

専用 tmux `next-3.4` サーバーを `-L` と空の設定で起動し、PowerShell 7 管理者・右クリックの 1 条件を試した。既定 `allow-passthrough=off` は outer pane の alternate screen が有効、SSH の 3 マーカーは空、専用受信呼び出し 0 で通常 `PasteFrom` になり、LF・日本語・絵文字・末尾 LF の一致、Enter 前 0 回・後 1 回が成功した。追加の `allow-passthrough=on` と TEMP 統合だけの DCS ラップでも同じ通常経路だった。専用配送や DCS 通過の成功とは扱わない。結果は `tmux-gui-20261012-032930-default/summary.json` と `tmux-gui-20261012-032822-wrapped/summary.json`。通常設定を変えず専用サーバー・GUI・TEMP を片付けた。


### 付録: nonce 付き終端の追試（2026-10-12）

本文の受信確認後、手入力の `~` が先に届くと、入力欄へ復帰した後に遅延した本文が残ることを専用 PTY で再現した。PowerShell `b79886ec…` の試験で入力欄に既知の `8:a25vd24=~` が残り、実行は 0 回だった。結果は `tests/paste/results/early-body-terminator-20261012-033544-ac43ae59/summary.json`。通常のデータと配送の終端を区別するため、完全な `~WZE2:<nonce>~` だけを終端として認めるよう変更した。手入力の `~`、偽の nonce、部分終端では復帰せず、本物の終端まで読み捨てる。本文前の取消も同じ識別子付き終端を送る。


nonce 終端版の PowerShell SHA-256 は `2ee03930cbe59d08c244b124b4c07dab8f16963fe921d17cc609697cefe46a7b`。Console shim の両版 21/21 は通常受信、`KeyAvailable` / `ReadKey` / ACK 書き込みの 2 種の例外、持続障害、Ctrl+C 設定復元、早い `~`、偽 nonce、部分終端、本文なし取消を含む。SSH 状態は両版 16/16、ローカル貼り付けは両版 21/21、パーサーはエラー 0。結果は `/tmp/codex-ssh-v2-state-376f34ffb0bc42f3b0d49935a84af0f3/` に採取し、専用 TEMP を削除した。

実証と同じ早い `~` の試験は、修正後に入力バッファが空・実行 0 で成功した。`tests/paste/results/early-body-terminator-fixed-20261012-034019-f1fb633e/summary.json` に保存した。最終 PowerShell の既存 Starship 標準回帰も 74 プロセスケース・34 callback・494/494、既知 4 件・予期しない失敗 0。結果は `starship-20261012-034025-2196716b/regression-summary.json`。


最終 Lua の SHA-256 は `b1c701930fe2f00caf509d541f69f54bc17e86b8d92993d87b87552804916e4b`。Linux / Windows は各 103/103（実時刻 API 1 件と状態の stub 102 件）成功し、正常送信と本文前取消の終端が READY の nonce を使うことも確認した。Windows の結果は `tests/paste/results/windows-lua-v2-nonce/lua.json`。

最終両ソースの fresh Linux GUI → SSH は 5.1 / 7 × 管理者 / 非管理者の 4 条件で共有操作・右クリック・Ctrl+Shift+V の 12/12。入力バッファ一致、Enter 前未実行、Enter 後一度だけの実行が成功した。`linux-gui-ssh-20261012-034501-0cdaaeb6/summary.json` に保存し、専用 GUI・接続・TEMP を片付けた。Windows の実 SSH と最終版の Windows GUI は未検証のまま。

Grok Build（`grok-4.7`）へ最終の PowerShell / Lua ソースと検証結果を渡して再レビューした。正常・取消の同じ nonce 終端、完全終端の照合、偽 / 部分終端と入出力例外後の読み捨てについて、追加指摘なしだった。過去の指摘と採用・不採用の根拠は各追試に記載した。


nonce 終端版の実 SSH は `tests/paste/results/ssh-20261012-034151-07712eee/summary.json` の 128/128。5.1 / 7 × 管理者 / 非管理者が各 31 件、子から管理者親への復帰 2 件、PowerShell から Git Bash への復帰 2 件。64 KiB の入力一致、Enter 前未実行・後一度だけの実行、65,537 バイトの拒否、旧 V1 型から V2 の読み込みと再読み込み、準備期限、早い / 偽 / 部分終端と正常終端の分割、取消後の親の空バッファが成功した。65,536 バイトの受信は PS5 管理者 51.102 秒・非管理者 67.589 秒、PS7 管理者 55.017 秒・非管理者 70.672 秒だった。

終端の途中の 2 種の入出力例外も追加で注入し、照合位置を保って終端まで読み捨てることを確認した。受信の shim は最終の両版 23/23。結果は `/tmp/codex-ssh-v2-state-c4680a62b7f84d119750faf9be318ac2/`。この追試では製品ソースを変えていない。両版の構文エラー 0、専用 TEMP の削除も確認した。

最終 SSH 試験の `cleanup.json` で専用 TEMP が無く、試験用 PowerShell の残留プロセスが 0 件であることを確認した。nonce 付き終端版の構文・UTF-8 BOM・実 WezTerm 設定・文書リンク・`git diff --check` も成功した。Bash / zsh と ShellCheck の対象ソースは前の試験から変えていない。

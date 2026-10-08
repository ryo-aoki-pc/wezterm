# シェル統合の仕様

[文書案内](../README.md) / [設定の導入](../install.md) / [操作ガイド](../usage.md) / [検証記録](../verification/install.md)

## 目次

- [シェル統合](#シェル統合)
  - [PowerShell](#powershell)
  - [bash と zsh](#bashgit-bash--msys2--qmk-msys--linuxと-zsh)
  - [WSL](#wsl)
  - [tmux の中](#tmux-の中)
  - [ssh 先でもシェル統合を使う](#ssh-先でもシェル統合を使う)
  - [迷子のマウス報告よけ](#迷子のマウス報告よけ)
  - [導入しない場合](#導入しない場合)

## シェル統合

`shell/wezterm.sh`（bash / zsh）と `shell/wezterm.ps1`（PowerShell）が、シェルから WezTerm へ
次の情報を送ります。WezTerm はこれを見て、ディレクトリやプロンプト・出力の位置を知ります。

| 送る情報 | いつ | 得られる動作 |
| --- | --- | --- |
| OSC 7（今のディレクトリ） | プロンプトごと | 新しいタブ・分割ペインが同じディレクトリで開く / タブ名がディレクトリ名になる |
| OSC 133 A / B（プロンプトの開始 / 入力の開始） | プロンプトごと | 前後のプロンプトへのジャンプ |
| OSC 133 C（出力の開始） | Enter を押してコマンドが動く直前 | 直前の出力のコピー |
| OSC 133 D（終了コード） | コマンドが終わったとき | 出力の範囲の終わり |
| ユーザー変数 `wezterm_cmd_done` | 長いコマンドが終わったとき | [完了通知](../usage.md#長いコマンドの完了通知) |
| ユーザー変数 `WEZTERM_PROG`（実行中のコマンド行） | コマンドが動く直前（プロンプトで空に戻す）。Git Bash・MSYS2・WSL の bash / zsh だけ | WezTerm から見えないプログラムのアイコン・ssh 中のタブ名（[タブ名の決まり方](../usage.md#タブ名の決まり方)） |

シェルごとの対応:

| 機能 | bash / zsh | PowerShell | cmd |
| --- | --- | --- | --- |
| ディレクトリの引き継ぎ・タブ名 | ○ | ○ | × |
| プロンプトジャンプ | ○ | ○ | × |
| 直前の出力をコピー | ○ | ○（PSReadLine が必要。通常は入っている） | × |
| 完了通知 | ○（zsh は `base64` コマンドが必要） | ○ | × |
| 実行中のコマンドを送る（`WEZTERM_PROG`） | ○（Git Bash・MSYS2・WSL のみ） | 不要（WezTerm がプロセスを見られる） | × |
| 迷子のマウス報告よけ | ○ | — | — |

公式統合が無い環境では、`$TERM_PROGRAM` が `WezTerm` のときだけ統合を有効にし、ほかの端末では
「迷子のマウス報告よけ」だけを動かします。既に有効な公式 Bash 統合がある場合は、それを補完します。
既存のプロンプト（`PS1` や `prompt` 関数、oh-my-posh など）は保ち、前後に印を足します。

### PowerShell

追加の設定は不要です。`lua/shells.lua` が起動引数で自動的に読み込みます
（`-Command` はプロファイルを抑止しないため、既存のプロファイルはそのまま動きます）。

- 出力の開始（OSC 133 C）は、PSReadLine が定義する入力読み取り関数 `PSConsoleHostReadLine` を
  包んで、Enter の直後に送ります（VS Code のシェル統合と同じ方法）。PSReadLine を読み込んでいない場合は送らない
- 終了コード（OSC 133 D と完了通知）は Windows Terminal のシェル統合と同じ考え方で決めます。
  `$?` は成否しか持たず、`$LASTEXITCODE` はネイティブコマンドが動いたときしか更新されない（コマンドレットが
  失敗しても前の値が残る）ため、その行で新しく記録されたエラー（前のプロンプトのときと `$Error[0]` が
  入れ替わったか）で見分けます。成功は 0、コマンドレットのエラー・`throw` は 1、ネイティブコマンドは
  その終了コード（Windows PowerShell で `2>&1` を付けて stderr を受けた場合も、終了コード 0 なら成功）
- 元の `prompt` 関数からは、直前のコマンドの成否（`$?`）がそのまま見えます
  （`$?` で失敗を表示するテーマのため）
- プロファイルで `Set-StrictMode` を有効にしていても、プロンプトの中では切るので壊れません
- `shell/wezterm.ps1` は **UTF-8 BOM 付き**で保存してください。Windows PowerShell 5.1 は
  BOM の無い `.ps1` を ANSI として読むため、日本語コメントが化けて構文エラーになります

### bash（Git Bash / MSYS2 / QMK MSYS / Linux）と zsh

`lua/shells.lua` が環境変数 `WEZTERM_SHELL_INTEGRATION` にパスを渡すので、
`~/.bashrc`（zsh は `~/.zshrc`）に、このパスのスクリプトを読み込む 1 行を足します。
足し方は [docs/install.md の手順 5〜7](../install.md#実施手順) にあります
（starship の初期化より後ろ、zoxide の初期化より前に置きます）。
自分用の bash の設定（`ryo-aoki-pc/bash`）を入れたホストでは、この 1 行は要りません
（その設定が、starship・zoxide と合わせた順番でこのスクリプトを読みます）。

環境変数が無いときのフォールバックを付けてあるのは、tmux や ssh を挟むとこの変数が
届かないためです（tmux サーバは起動時の環境を子プロセスへ配るので、WezTerm が渡した
変数は後から作ったペインに入りません）。パスは「[配置と初回セットアップ](../../README.md#配置と初回セットアップ)」の表どおり全 OS で
`$HOME/.config/wezterm` なので、フォールバックだけでも読み込めます。

ログインシェル（`bash -i -l`）では `--rcfile` が無視されるため、この 1 行だけは
手で入れる必要があります。ホームディレクトリはシェルごとに異なる点に注意してください。

| シェル | `~/.bashrc` の場所 |
| --- | --- |
| Git Bash | `%USERPROFILE%\.bashrc` |
| MSYS2 | `C:\msys64\home\<ユーザー名>\.bashrc` |
| QMK MSYS | `C:\QMK_MSYS\home\<ユーザー名>\.bashrc` |

既存の `PS1` は置き換えず前後に印を足すだけなので、Git Bash の
`git-prompt.sh` によるブランチ表示はそのまま残ります。

- bash はプロンプトを表示する前に `PS1` の OSC 133 A / B を毎回付け直します。Starship が
  プロンプトを作り直しても、プロンプトと入力の範囲を WezTerm に伝えられます
- Starship がある bash では、Starship が先に終了コードと `PIPESTATUS` を保存し、その後にこの統合を
  動かします。OSC 133 D と完了通知は Starship が保存した終了コードを使うので、Starship の
  パイプ個別ステータス表示も保ちます。初期化順は上記のままです
- zsh は入力の開始（OSC 133 B）の印をプロンプトの末尾に付けます。プロンプトを毎回作り直すテーマでも
  プロンプトごとに付け直しますが、テーマのフックがこの統合より後に動く場合は付かず、直前の出力をコピーできません
- bash の OSC 133 の印（`PS1` の A / B と `PS0` の C）は BEL で終えます。`ESC \` で終えると、後ろに続く
  ほかの `PS0`（starship など）や元の `PS1` の先頭の `$` がその `\` でエスケープされ、`${…}` が文字のまま画面に出ます
  （`PS1` は行編集が無いときだけ）
- Git Bash・MSYS2・WSL では、実行を始めたコマンドを `WEZTERM_PROG` で送ります（[シェル統合](#シェル統合)）。
  bash 5.3 以降（Git Bash の現行版）はサブシェルを作らずに送るので、コマンドごとの待ち時間はほぼありません
  （古い bash はサブシェルを 1〜2 回作る）。Linux / macOS では WezTerm が自分でプロセスを調べられるので送りません

Git Bash + Starship の修正後の検証範囲と結果は [tests/starship/FIX-REPORT.md](../../tests/starship/FIX-REPORT.md) にあります。

Linux 版 WezTerm のパッケージは公式のシェル統合を `/etc/profile.d/wezterm.sh` に置きます。
公式の Bash 統合が有効なら、`shell/wezterm.sh` は公式の OSC 7・ユーザー変数・`bash-preexec` を
保ち、OSC 133 のプロンプト・入力・出力の印と独自完了通知を補います。公式の semantic フック 2 個だけを
独自処理へ移し、Starship やユーザーのフックは保ちます。公式の関数を上書きせず、独自の cwd 処理は
`__wz_osc7` として定義します。

`bash-preexec` が終了コードとパイプ状態を保存し、Starship がプロンプトを作り直した後に印を付けるため、
公式の印と独自の印を二重に送らない構成です。zsh・ble.sh・tmux、semantic の明示的な無効化では、
従来どおり公式へ任せます。初期化の 1 行、Starship → 統合 → zoxide の読む順番、環境変数の設定は変更しません
（[docs/install.md の注意点](../install.md#注意点)）。

公式の bash-preexec 経路で Starship だけを直接再初期化した場合は、この統合も続けて読み直します。
Starship が重ねた登録を各 1 個へ戻します。通常の個人 Bash 設定は Starship の再初期化をガードしています。

### WSL

WSL ドメインは起動引数を渡せないため、WSL 側の `~/.bashrc` に、Windows 側の
`/mnt/c/Users/<ユーザー名>/.config/wezterm/shell/wezterm.sh` を読み込む行を直接書きます。
足し方は [docs/install.md の「WSL でもシェル統合を使う（任意）」](../install.md#wsl-でもシェル統合を使う任意) にあります。

WezTerm が WSL の中へ渡す環境変数は `TERM`・`COLORTERM`・`TERM_PROGRAM`・`TERM_PROGRAM_VERSION` だけです
（`WSLENV`）。`TERM_PROGRAM` は届くので統合は動きますが、`WEZTERM_SHELL_INTEGRATION` や
`set_environment_variables` に足した値（`WEZTERM_NOTIFY_AFTER` など）は届きません。

### tmux の中

tmux の中では `$TERM_PROGRAM` が `tmux` になるため、シェル統合は（マウス報告よけ以外）無効になります。

### ssh 先でもシェル統合を使う

ssh は `$TERM_PROGRAM` を既定では接続先へ渡しません。公式統合が無い接続先では、この設定の独自統合を
動かすために `TERM_PROGRAM=WezTerm` の受信が必要です。この統合が動かない場合でもタブ名は接続先になりますが
（ペインのタイトルから取る）、この設定の完了通知は使えません。
プロンプトジャンプ・出力のコピーは、接続先の別の統合が OSC 133 の区切りを正しく送る場合に限り使えます。

公式統合が無い ssh 先では、次の 3 つを設定します（myhost のような自分で管理しているホスト向け）。
手順は [docs/install.md の「ssh 先でもシェル統合を使う（任意）」](../install.md#ssh-先でもシェル統合を使う任意) にあります。

- **手元の `~/.ssh/config`**（Windows は `%USERPROFILE%\.ssh\config`）の `Host` に `SendEnv TERM_PROGRAM` を足し、
  `TERM_PROGRAM` を送る。公式統合が無い場合、この値が `WezTerm` のときだけ独自統合を動かす
- **ssh 先の sshd** で、`AcceptEnv TERM_PROGRAM` のドロップインを置いて受け取りを許可する
- **ssh 先**にもこの設定を置き、ssh 先の `~/.bashrc` に手元と同じ[シェル統合の 1 行](#bashgit-bash--msys2--qmk-msys--linuxと-zsh)を足す
  （Syncthing などで `~/.config/wezterm` を同期していれば、1 行だけでよい）

独自統合が動くと、タブ名が `myhost:setup-notes` のように ssh 先のディレクトリ名になり、
ssh 先でも `Ctrl+Shift+Alt+↑/↓`・`Ctrl+Shift+Alt+C`・完了通知が効きます。
確かめるには、ssh 先で `echo $TERM_PROGRAM` が `WezTerm` になるかを見ます。
ssh 先で tmux を使っている場合、tmux の中では無効です（[tmux の中](#tmux-の中)）。

AlmaLinux の COPR 版など、接続先で公式 Bash 統合が既に有効な場合は、`TERM_PROGRAM` が届かなくても
この設定が公式統合を補完します。接続先の `~/.bashrc` が修正版の `shell/wezterm.sh` を読む必要があります。
公式の cwd・ユーザー変数を残し、Starship 後に入力範囲の印を付け直す構成です。

[SSH 共存修正前後の検証記録](../verification/readme.md#ssh-共存修正前後の検証2026-10-06)を参照してください。

### 迷子のマウス報告よけ

lazygit や yazi のような TUI は起動時にマウス報告（DECSET 1003 = 移動も含む全イベント /
1006 = SGR 形式）を有効にし、終了時に解除します。ところが解除が端末へ届く前に端末が
出してしまった報告は行き場を失い、戻ってきたシェルにこう現れます。

```
[foo@myhost setup-notes]$ lazygit
^[[<35;33;72M[foo@myhost setup-notes]$
```

届くタイミングで見え方が変わります。プロンプト表示前なら端末がそのまま echo するだけ
（表示が汚れる）ですが、入力の受付（bash の readline・zsh の ZLE）が始まった後に届くと
`35: command not found` のようにコマンド行が壊れます。WezTerm 固有の問題ではなく、tmux や ssh を挟んでも起きます。

`shell/wezterm.sh` は対策を 2 つ入れています（この部分は WezTerm 以外・tmux の中でも働きます）。

- プロンプトごとにマウス報告を解除する（解除され損ねて残っている場合の回復）
- readline（zsh は ZLE）に `\e[<` を食わせ、終端の `M` / `m` まで読み捨てる（コマンド行への混入防止）

ただしプロンプト表示前に届いた分の echo までは消せません。lazygit については
`~/.config/lazygit/config.yml` に次を書き、発生源ごと止めるのが確実です
（代わりに lazygit 内でマウスが使えなくなります）。

```yaml
gui:
  mouseEvents: false
```

手で復旧したいときは `printf '\033[?1003l\033[?1006l'` を実行します。

### 導入しない場合

統合を入れなくても設定は問題なく動きます。タブ名は従来どおりプロセス名になり、
プロンプトジャンプ・出力のコピー・完了通知と、Git Bash・WSL での ssh 中の判定（タブ名・アイコン）が効かないだけです。

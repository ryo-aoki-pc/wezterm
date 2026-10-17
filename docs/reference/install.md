# WezTerm 設定導入の参照情報

手順は setup-notes の[WezTerm の設定を導入する](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#wezterm-の設定を導入する)（AlmaLinux 10）と[Windows 11 で WezTerm の設定を導入する](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#windows-11-で-wezterm-の設定を導入する)にある。見出しの手順番号は AlmaLinux 10 の項の番号で、Windows 11 の項は窓を開く手順が先頭にあるので 1 つ後ろになる。ロールバックと注意点は [extra](../extra/install.md)、検証は[検証記録](https://github.com/ryo-aoki-pc/setup-notes-verification/blob/main/repos/wezterm/docs/verification/install.md)、機能とキー操作は [README](../../README.md)。

## 手順の背景と実装の説明

### WezTerm の設定を導入する / 手順 1: 補足: 2 つの置き場所

- WezTerm は `~/.wezterm.lua` を `~/.config/wezterm/wezterm.lua` より先に探し、見つけた 1 つだけを読む（setup-notes-verification（非公開）の [WezTerm の記録の「設定ファイルの探索順序（実測）」](https://github.com/ryo-aoki-pc/setup-notes-verification/blob/main/docs/verification/shell-terminal.md#wezterm-設定ファイルの探索順序実測)）
- `~/.wezterm.lua` が残っていると、この設定は読まれない

### WezTerm の設定を導入する / 手順 3: 補足: `~/.config/wezterm` に置く理由

- `wezterm.lua` は、`lua/` のモジュールを `wezterm.config_dir`（`wezterm.lua` のあるディレクトリ）から読む。シェル統合のスクリプトも、同じディレクトリの `shell/` を指す。1 ファイルの `~/.wezterm.lua` には置けない
- 共通の bash 設定は、`WEZTERM_SHELL_INTEGRATION` が無いとき（tmux や ssh を挟むと届かない）に `$HOME/.config/wezterm/shell/wezterm.sh` を読む。別の場所に置くと、そのときに読めない

### WezTerm の設定を導入する / 補足: starship の後、zoxide の前に読む理由

- starship は、直前の終了コードとパイプ各要素の終了コード（`PIPESTATUS`）を先に保存し、`PS1` を毎回作り直す。統合は `PROMPT_COMMAND` の後ろにフックを足し、starship が保存した終了コードを OSC 133 の `D` と完了通知に使う
- 統合は `PS1` の OSC 133 の印（`A` / `B`）をプロンプトごとに付け直す。starship のプロンプトとパイプ個別ステータス表示を保ちながら、WezTerm にプロンプト・入力・出力の範囲を伝える
- zoxide はいちばん最後に初期化する（共通の bash 設定が starship → WezTerm → zoxide の順に読む。setup-notes の [シェルと端末のセットアップの注意点](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/extra/shell-terminal.md#注意点)）

### WezTerm の設定を導入する / 手順 6: 補足: シェル統合を読む仕組み

- `WEZTERM_SHELL_INTEGRATION` は、この設定の WezTerm が起動するシェルに渡す環境変数で、`shell/wezterm.sh` のパスが入る（`lua/shells.lua` の `set_environment_variables`）
- 変数が無いとき（tmux や ssh を挟むと届かない）は、`$HOME/.config/wezterm/shell/wezterm.sh` を読む
- WezTerm は bash をログインシェル（`-l`）で起動するので、`--rcfile` では読ませられない。そのため `~/.bashrc` から読む（今は共通の bash 設定が読む。この手順で確かめる）
- PowerShell は、`lua/shells.lua` が起動引数（`-Command`）で `shell/wezterm.ps1` を読ませるので、プロファイルに足すものは無い
- 公式統合が無い場合、WezTerm 以外の端末では迷子のマウス報告よけ（README）だけを動かす。既に有効な公式 Bash 統合がある場合は、それを補完する

### WezTerm のシェル統合を SSH 先で使う / 手順 2: 補足: AlmaLinux 10 の sshd の既定と、検証コンテナでの出力

- AlmaLinux 10.2 の既定の sshd は、`AcceptEnv` を 1 つも持たない（`sshd -T` に `acceptenv` の行が出ない）
- `/etc/ssh/sshd_config` の `Include /etc/ssh/sshd_config.d/*.conf` が、このファイルを読む。`AcceptEnv` は、ほかの行やファイルにあっても足し合わされる

## 全体の参照情報

### 対象と検証環境

- **目的**: この設定（[ryo-aoki-pc/wezterm](https://github.com/ryo-aoki-pc/wezterm)）を `~/.config/wezterm` に置き、bash のシェル統合を読ませる。AlmaLinux 10 と Windows 11 の Git Bash で、同じコマンドにする
- **進め方**: git で clone する。シェル統合は共通の bash 設定が読む。**読者が書き換える変数は無い**（リポジトリの URL と置き場所は固定）

### 選択した方針

- **`~/.config/wezterm` に git で clone する**
  - `lua/` と `shell/` を `wezterm.config_dir` から読むので、ディレクトリごと置く
  - 更新は `git pull` で、手元で変えたところは `git diff` で見られる
  - Windows の WezTerm も `%USERPROFILE%\.config\wezterm\wezterm.lua` を読む。設定はディレクトリごと置く
- **シェル統合は `~/.bashrc` から読む**（今は共通の bash 設定が読む）
  - PowerShell には起動引数で読ませられるが、bash はログインシェルで起動するので `--rcfile` を使えない
  - tmux・ssh を挟むと環境変数が届かないので、既定の置き場所をフォールバックにした
- **既にある設定は、消さずに `.bak` に退避する**
  - `~/.wezterm.lua` が残るとこの設定が読まれないので、`~/.config/wezterm` と合わせて退避する
  - [ロールバック](../extra/install.md#ロールバック)の手順 3 で戻せる
- **AlmaLinux 10 の公式のシェル統合は止めない**
  - 公式 Bash 統合の cwd・ユーザー変数・bash-preexec を保ち、semantic の 2 フックだけを独自処理へ移す。`WEZTERM_SHELL_SKIP_ALL=1` を渡す設定は加えない（[注意点](../extra/install.md#注意点)）
- **Windows は、Git Bash に同じ bash のブロックを貼る**（setup-notes の初期設定の「Git」と同じ）

### 完了時点の状態

| 場所 | 中身 |
|---|---|
| `~/.config/wezterm` | このリポジトリの clone（`main`） |
| `~/.bashrc` | 変えない（シェル統合は共通の bash 設定が読む） |
| `~/.wezterm.lua.bak` / `~/.config/wezterm.bak` | 手順 2（Windows 11 は手順 3）で退避したときだけ |
| （ssh 先）`/etc/ssh/sshd_config.d/50-wezterm.conf` | `AcceptEnv TERM_PROGRAM` の 1 行 |

- WezTerm が起動したシェルは、正本の設定導入（[AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#wezterm-の設定を導入する) / [Windows 11](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#windows-11-で-wezterm-の設定を導入する)）の最後で確かめる

### 参照

- [README](../../README.md) — この設定の機能・キー操作・シェル統合の仕組み
- setup-notes の [シェルと端末のセットアップの「WezTerm」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#wezterm)・[シェルと端末のセットアップの「Windows 11 で WezTerm を入れる」](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#windows-11-で-wezterm-を入れる) — WezTerm nightly の導入（設定ファイルの探索順序の実測は、その検証記録の「WezTerm の記録」）
- setup-notes の [AlmaLinux 10 の初期設定](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md)の「Git」と、[シェルと端末のセットアップ](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md)の「HackGen Console NF」と starship・zoxide
- [Configuration Files — WezTerm](https://wezterm.org/config/files.html) — 設定ファイルの置き場所
- [Shell Integration — WezTerm](https://wezterm.org/shell-integration.html) — 公式のシェル統合と `WEZTERM_SHELL_SKIP_ALL`
- `man sshd_config`（`AcceptEnv`）・`man ssh_config`（`SendEnv`）

---

## Windows SSH の PowerShell 貼り付け

- 操作は [AlmaLinux 10 の接続元](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/shell-terminal.md#wezterm-windows-の-ssh-先で-powershell-に貼り付ける) / [Windows 11 の接続元](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-setup.md#ssh-で管理者非管理者の-powershell-を使う)を参照する。SSH 先の PSReadLine `Paste` は接続先のクリップボードを読むため、接続元のクリップボードを使う専用経路が必要になる
- 接続元 Windows は標準 PowerShell の `-NoProfile -NonInteractive -STA` で `Get-Clipboard -Raw` を読み、UTF-8 の Base64 として取得する。接続元 Linux は Wayland の `wl-paste --no-newline --type text` または X11 の `xclip -selection clipboard -out -target UTF8_STRING` を使う。本文をコマンド引数・ファイル・ログへ書かない
- 受信は SSH 用キーのハンドラー内で `Console.ReadKey` を呼ぶ。初回だけメモリー内の C# 補助型を `Add-Type` で読み、文字ごとの PowerShell 解釈を避ける。受信本文は補助型にもコマンドとして渡さない
- PSReadLine 入力中の epoch、準備応答の nonce、ペイン、待機状態、取得前の応答を照合する。無応答・古い応答・識別子不一致では本文を送らない。クリップボード取得を先に済ませ、専用キーの受信開始後に準備応答を待ってヘッダーだけを送る。受信側がヘッダーを読み終えた確認を返してから Base64 本文を送る。版番号は `2`、ヘッダーは `WZP2:<nonce>:`、本文は `<Base64長>:<Base64>~WZE2:<nonce>~`。旧版との混在では通知して停止する
- 本文は最大 64 KiB。厳密な UTF-8 と Base64・長さ・nonce を検証し、NUL を拒否する。CR 除去・タブの空白 4 個への変換は [PSReadLine Paste の実装](https://github.com/PowerShell/PSReadLine/blob/v2.0.0/PSReadLine/KillYank.cs)に合わせる。選択範囲があれば `Replace`、なければ `Insert` を使い、Enter は送らない
- 取消後は本文を終端まで読み捨てる。本文の受信が始まった後にタイムアウトで親シェルへ戻すと、遅れて届いたデータが管理者の入力に残るため、ヘッダー未着の待機だけを 5 秒で終了する。完全なヘッダーを読む前の余分な文字や終端 `~` は不正として扱い、本文待機を始めない。Lua の各準備待機は 3 秒で終了する。ヘッダー後・本文前の失効では本文を捨てて同じ nonce の終端 `~WZE2:<nonce>~` だけを送り、受信待機を解除する。配送停止時は接続元で SSH ペインを閉じる
- 同じ入力待機の epoch では、取消や時間切れの後も専用キーを再送しない。受信終了時に新しい epoch が通知されてから次を受け付ける。RESULT や待機マーカーの解除後には追加の終端を送らない
- 本文の受信開始後は、手入力の `~` や偽・部分終端では入力欄へ戻らず、不正として同じ nonce の完全な終端まで読み捨てる
- 本文の送信完了を記録するのは `send_text` が成功した後。完全・部分送信の例外では、本文を再送せず、同じ epoch を確認して同じ nonce の終端だけを送る。受信側の Console 入出力例外も不正データとして扱い、ヘッダー前は期限で終了し、ヘッダー後は終端まで読み捨てる
- C# の型は PowerShell のプロセス内に残り、同じ型名を再定義できない。統合ファイルを更新した後は、新しい SSH / PowerShell プロセスを起動する。同じ版の再読み込みでは既存の型を使う
- OSC の識別子は古い配送や別ペインの応答を区別する。SSH 先が出力する OSC 自体を信頼する端末統合であり、接続先の悪意あるプログラムを認証する仕組みではない
- Git Bash の既定シェルでは、対話 SSH の後に PowerShell を起動する。[Windows OpenSSH の PTY 起動実装](https://github.com/PowerShell/openssh-portable/blob/latestw_all/contrib/win32/win32compat/w32-doexec.c)が `bash -c` のコマンド引数を組み立てるため、`ssh -tt <ホスト名> 'powershell.exe ...'` の形では引数の引用が失われることがある
- ローカル Windows は `Ctrl+V` と PSReadLine `Paste` を使う。専用経路は Windows の SSH セッションで PSReadLine 入力待機の能力が通知された場合に使う。Neovim の alternate screen・実行中のコマンド・統合なしは通常の端末貼り付けを使う。tmux の既定設定では、PowerShell 7 管理者・右クリックの 1 条件で通常貼り付けを確認した。tmux の専用配送と入れ子 SSH の実セッションは未検証

# PowerShell の貼り付け検証

`lua-behavior.lua` と `check-powershell.ps1` は共有 action とシェル統合を単体で検証する。
`live-run.py` は Windows 上の新規 desktop に専用クラスの WezTerm GUI を起動し、利用者の画面へ表示せず、実際の ConPTY と PSReadLine で貼り付けを比較する。利用者のプロファイルは読まず、既存の GUI は操作しない。

リポジトリのルートで結果の保存先を作り、Lua・Windows PowerShell 5.1・PowerShell 7 の非対話チェックを順に実行する。

```powershell
New-Item -ItemType Directory -Force tests/paste/results | Out-Null
wezterm --config-file tests/paste/lua-behavior.lua ls-fonts --text a
Get-Content tests/paste/results/lua.json -Raw | ConvertFrom-Json
& "$env:WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -ExecutionPolicy Bypass -File tests/paste/check-powershell.ps1 -ResultPath "$PWD/tests/paste/results/ps5.json"
pwsh -NoProfile -File tests/paste/check-powershell.ps1 -ResultPath "$PWD/tests/paste/results/ps7.json"
```

Lua は設定エラーでも終了コードが 0 になり得るため、`lua.json` の `passed` と各チェック結果を確認する。PowerShell は失敗したチェックがあれば終了コード 1 を返す。

実ペイン検証の `WEZTERM` は検証機のインストール先に合わせる。PowerShell 7 は PATH の `pwsh` を使い、別の実行ファイルは `--pwsh <パス>` で渡す。Windows PowerShell 5.1 は PSReadLine 2.0.0、PowerShell 7 はインストール済みの PSReadLine を Emacs モードで読み込む。通常プロファイルで確認された `Ctrl+Enter = AddLine` を専用スクリプト内で再現し、元のプロファイルは読み込まない。

Emacs の既定割り当てだけの初期比較では block の余分な空行を再現しなかったため、`Ctrl+Enter = AddLine` も再現条件に含める。端末の `allow_win32_input_mode` と `canonicalize_pasted_newlines` は上書きせず Windows の既定を使い、各 action の結果に effective config を記録する。実際にアプリが要求した Win32 input の内部状態までは採取しない。

実ペイン検証は標準クリップボードを無害な試験コードで置換する。元データを読み取らないため復元せず、終了後も最後の試験コードが残る。この動作を選ぶ `--shared-clipboard` が必須で、指定しないと実行せずに終了する。基本 CRLF の `--quick`、全件、追加の CRCRLF を順に実行する。

```powershell
python tests/paste/live-run.py --shared-clipboard --quick
python tests/paste/live-run.py --shared-clipboard
python tests/paste/live-run.py --shared-clipboard --double-cr
```

通常の 2 行・全体を囲む block・意図的な空行・日本語・here-string・末尾改行の各 LF/CRLF を、旧 `PasteFrom`、共有 action、右クリックの 2 設定、Ctrl+Shift+V の設定で比較する。操作は本物の `window:perform_action` を呼ぶ。F11 の専用 handler で Enter 前後の入力 buffer と試験コードの実行カウンターを取り、Enter 前には実行しないこと、Enter 後に 1 回だけ実行すること、待機中だけ入力マーカーが立つことを確かめる。block と quick の通常 2 行では Enter 前の画面テキストも保存する。両シェルで統合を読み直してから 1 回ずつ block を貼り、貼り付けが保たれることも確認する。旧動作の結果は比較資料として記録する。

`--double-cr` はコピー元に二重 CR がある場合を制御した block で比較する追加試験で、利用者がコピーした実データではない。試験ペインの履歴と採取結果は git 管理から除外した `results/<日時>/` に保存する。`summary.json` に環境・対象ソースの SHA-256・各ケースの入力と Enter 前後の結果・クリップボードの扱いを記録する。非表示 desktop は終了時に閉じる。

Linux から Windows の SSH 受信側だけを検証するときは `ssh-live.py` を使い、`--host` に SSH の接続名を渡す。SSH ホストの既定シェルは Git Bash とし、Windows PowerShell 5.1 と PowerShell 7 が PATH から起動できることを前提にする。統合と `ssh-probe.ps1` を SSH 先の `%TEMP%` の専用ディレクトリへ SCP し、終了時にそのディレクトリだけを削除する。通常の設定・プロファイル・履歴・接続元のクリップボードは変更しない。

```bash
python3 tests/paste/ssh-live.py --host <接続名>
python3 tests/paste/ssh-live.py --host <接続名> --include-drop
python3 tests/paste/ssh-live.py --host <接続名> --include-drop --large-size 65536 --large
python3 tests/paste/ssh-live.py --host <接続名> --drop-return --bash-return
```

`--include-drop` は手順書の固定版 busybox が `%LOCALAPPDATA%\setup-notes\bin\busybox.exe` に配置済みのときだけ使う。起動前に SHA-256 を照合し、`drop --` で同じユーザーの非管理者子シェルも試す。`--large-size` は正常入力の文字数、`--large` は復号後 64 KiB を超える不正入力の試験を追加する。PowerShell の公開 API によるバッファ採取を F11、選択範囲を残した採取を F10 の専用 handler で行う。

`--drop-return` は管理者の親から手順と同形の `-NoLogo -NoExit -Command` で子を開き、通常プロファイルの起動、取消、子からの `exit`、管理者親への復帰を確認する。`--bash-return` は通常プロファイルを読まない専用 Git Bash から通常プロファイルの PowerShell を開き、取消と `exit` の後に Bash へ戻り、マーカーが消えて入力バッファが空であることを確認する。どちらも統合は専用 TEMP の試験版を読む。通常プロファイルは編集しない。

LF/CRLF、空行、日本語・絵文字、here-string、タブ、末尾改行、選択範囲、大入力、nonce・長さ・Base64・UTF-8・NUL・終端直前 LF の不正、受信途中の Ctrl+C、ヘッダーなしの timeout、再読み込みを試す。V2 の追加回帰は早期 `~`・通常文字・ヘッダー前 Ctrl+C・部分ヘッダー・連続した不正文字・ヘッダーだけの待機・本文前の取消・本文前の早い `~` と遅延本文・偽の nonce 終端・部分終端・正常終端の分割を含む。完全なヘッダーの受信確認を待ってから本文を送り、ヘッダー前の不正文字で 5 秒の期限が延びないこと、本文前に取消した後も管理者親の入力欄が空であることを確認する。各正常入力は Enter 前の未実行と Enter 後の一度だけの実行も確認する。結果は `results/ssh-<日時>/summary.json` に保存し、対象ソースの SHA-256・PowerShell / PSReadLine の版・実効権限・ケースごとの成否を記録する。同じディレクトリの試験用ソースを SCP するため、試験中に作業ファイルが変わっても対象版を追える。

PTY は Win32 input mode のキー通知と改行を含まない ASCII フレームを送り分ける。V2 は初期 READY の後にヘッダーだけを送り、ヘッダー受信の BODYREADY を照合してから Base64 本文と nonce 付き終端 `~WZE2:<nonce>~` を送る。Windows OpenSSH が Git Bash に渡す PTY コマンドの引用を補うため、起動コマンド自身を二重引用符で囲む。この試験は実 ConPTY / PSReadLine の受信を確認するが、WezTerm GUI の共有 action と接続元クリップボード取得は試さない。GUI の検証結果とは分けて記録する。

SSH 用 wrapper の待機マーカー・解除・再読み込み・キー登録失敗・PSReadLine 無効化を、専用の非対話プロセスで確認する。実入力関数だけを制御した関数に置き換え、クリップボードと通常プロファイルは使わない。

```powershell
& "$env:WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -ExecutionPolicy Bypass -File tests/paste/check-ssh-state.ps1 -IntegrationPath "$PWD/shell/wezterm.ps1" -ResultPath "$PWD/tests/paste/results/ssh-state-ps5.json"
pwsh -NoProfile -File tests/paste/check-ssh-state.ps1 -IntegrationPath "$PWD/shell/wezterm.ps1" -ResultPath "$PWD/tests/paste/results/ssh-state-ps7.json"
```

受信中の入出力例外は `check-ssh-reader.ps1` で確認する。製品の C# Reader のソースを読み、Console の呼び出しだけを制御用 shim に置き換える。`KeyAvailable`・`ReadKey`・ヘッダー受信確認の書き込みに `IOException` / `InvalidOperationException` を注入し、ヘッダー前は絶対期限で戻り、ヘッダー後は期限を超えても終端まで読み捨てることを比較する。手入力の `~`・偽の nonce・部分終端で復帰せず、正しい nonce の終端を消費することも確認する。実際の入力と clipboard は使わない。

```powershell
& "$env:WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -ExecutionPolicy Bypass -File tests/paste/check-ssh-reader.ps1 -IntegrationPath "$PWD/shell/wezterm.ps1" -ResultPath "$PWD/tests/paste/results/ssh-reader-ps5.json"
pwsh -NoProfile -File tests/paste/check-ssh-reader.ps1 -IntegrationPath "$PWD/shell/wezterm.ps1" -ResultPath "$PWD/tests/paste/results/ssh-reader-ps7.json"
```

接続元の実クリップボードと共有操作を合わせて試すときは `ssh-gui-run.py` を使う。Linux は `--host` に SSH の接続名を渡す。利用者の画面から隔離した Wayland / X11 セッションを用意し、`wl-paste` / `xclip` と clipboard の書き込み用コマンドがあることを確認してから実行する。headless Mutter に入力デバイスが無い場合は、専用の `/tmp/codex-ssh-paste-*` runtime 内で仮想入力を用意し、その試験用 D-Bus アドレスを `CODEX_TEST_MUTTER_DBUS` に指定する。

```bash
python3 tests/paste/ssh-gui-run.py --host <接続名> --include-drop --quick
python3 tests/paste/ssh-gui-run.py --host <接続名> --include-drop
```

Windows は専用 desktop でローカル ConPTY に SSH 環境だけを再現する。次の指定が必須で、`--host` は要らない。Windows からの実 SSH 接続は試さない。

```powershell
python tests/paste/ssh-gui-run.py --local-ssh-receiver --include-drop
```

通常の LF、CRLF と空行と日本語・絵文字、here-string、タブと末尾改行を、共有操作・右クリック・Ctrl+Shift+V の 3 経路で送る。`--quick` は複合 CRLF の 1 入力だけを試す。F11 で入力バッファと実行回数を読み、Enter 前の未実行と Enter 後の一度だけの実行を確認する。各 action は本物の `window:perform_action` を呼ぶ。物理キー・マウスは操作しない。結果の `real_ssh` と `transport` で接続条件を区別し、ソース SHA と起動診断も保存する。

この GUI 試験ではクリップボードを既知の無害なコードで置き換える。元の内容は読まないため復元せず、終了後も最後の試験コードが残る。Linux の専用 GUI / SSH ペインと Windows の専用 desktop は終了時に閉じ、SSH 先の専用 TEMP も削除する。結果は `results/` に保存し、Git 管理には含めない。

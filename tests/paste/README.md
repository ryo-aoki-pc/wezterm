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

実ペイン検証の `WEZTERM`・`PS7` を検証機のインストール先に合わせる。Windows PowerShell 5.1 は PSReadLine 2.0.0、PowerShell 7 はインストール済みの PSReadLine を Emacs モードで読み込む。通常プロファイルで確認された `Ctrl+Enter = AddLine` を専用スクリプト内で再現し、元のプロファイルは読み込まない。

Emacs の既定割り当てだけの初期比較では block の余分な空行を再現しなかったため、`Ctrl+Enter = AddLine` も再現条件に含める。端末の `allow_win32_input_mode` と `canonicalize_pasted_newlines` は上書きせず Windows の既定を使い、各 action の結果に effective config を記録する。実際にアプリが要求した Win32 input の内部状態までは採取しない。

実ペイン検証は標準クリップボードを無害な試験コードで置換する。元データを読み取らないため復元せず、終了後も最後の試験コードが残る。この動作を選ぶ `--shared-clipboard` が必須で、指定しないと実行せずに終了する。基本 CRLF の `--quick`、全件、追加の CRCRLF を順に実行する。

```powershell
python tests/paste/live-run.py --shared-clipboard --quick
python tests/paste/live-run.py --shared-clipboard
python tests/paste/live-run.py --shared-clipboard --double-cr
```

通常の 2 行・全体を囲む block・意図的な空行・日本語・here-string・末尾改行の各 LF/CRLF を、旧 `PasteFrom`、共有 action、右クリックの 2 設定、Ctrl+Shift+V の設定で比較する。操作は本物の `window:perform_action` を呼ぶ。F11 の専用 handler で Enter 前後の入力 buffer と試験コードの実行カウンターを取り、Enter 前には実行しないこと、Enter 後に 1 回だけ実行すること、待機中だけ入力マーカーが立つことを確かめる。block と quick の通常 2 行では Enter 前の画面テキストも保存する。両シェルで統合を読み直してから 1 回ずつ block を貼り、貼り付けが保たれることも確認する。旧動作の結果は比較資料として記録する。

`--double-cr` はコピー元に二重 CR がある場合を制御した block で比較する追加試験で、利用者がコピーした実データではない。試験ペインの履歴と採取結果は git 管理から除外した `results/<日時>/` に保存する。`summary.json` に環境・対象ソースの SHA-256・各ケースの入力と Enter 前後の結果・クリップボードの扱いを記録する。非表示 desktop は終了時に閉じる。

# Git Bash / Starship 統合の実測（2026-10-06）

この記録は Git Bash 修正前の調査結果。最終修正後の回帰確認は [SSH-FIX-REPORT.md](SSH-FIX-REPORT.md) を参照する。

公開用の集計は [verification-summary.json](verification-summary.json) にまとめた。生出力、実ペイン本文、環境の状態、cache、準備ファイルと配置前の控えはローカル保存の生成物で、Git の管理対象には含めない。再実行の前提は [README.md](README.md) を参照する。

Git Bash 5.3.15(2)-release（`OSTYPE=cygwin`）とインストール済み Starship 1.26.0 を使った。`bash --noprofile --rcfile <テスト専用ファイル> -i` の標準入力へコマンドを送り、stdout と stderr の生バイトを一緒に保存した。18 種類の条件を比較した。本番の `.bashrc`、Starship 設定、WezTerm 設定は変更していない。

この記録の Bash 実行には端末が付かないため、画面・Readline の折り返し・キー操作・トーストはこの記録だけでは確認できない。実 WezTerm / ConPTY の結果は親の検証記録に含まれる。

## 主な結果

| 初期化の順番 | Starship の終了状態 | OSC 133 D / 完了通知 | OSC 133 A / B | Starship のパイプ個別状態 |
| --- | --- | --- | --- | --- |
| Starship → 統合 → zoxide（推奨） | `false=1`、`exit 7=7` と正しい | 正しい | 送出されない | 単一状態に潰れる |
| Starship → zoxide → 統合 | 正しい | 正しい | 送出されない | 単一状態に潰れる |
| 統合 → Starship → zoxide | 正しい | 再読み込み前は失敗でも `0` | 送出されない | `1 0` のまま保たれる |

- 推奨順の代表記録では、42 個のコマンドに対して C は 42 回、A と B は各 0 回だった。Starship が毎回 `PS1` を作り直すため、統合を後からもう一度読んでも次のプロンプトで A / B が消える。
- `PS0` の C と Starship の開始時刻の式は共存する。通常の行編集・`--noediting` とも、`${STARSHIP_START_TIME:...}` が画面に文字として漏れず、2.15 秒のコマンドは Starship に約 2.2 秒と出た。
- 推奨順で `sleep 2.15; false` の通知は `1<TAB>2〜3<TAB>sleep 2.15; false`。逆順の最初の同じコマンドは `0<TAB>2<TAB>sleep 2.15; false` で誤成功だった。
- Starship の初期化後に統合を読み直すと、逆順で退避済みの統合フックに加えて前段にもフックが入る。OSC D が重複する場合があるため、起動順の誤りを単なる追加の `source` で直すことは推奨できない。

## パイプ状態の可視差

`bash-pipeline.toml` で Starship の `[status] pipestatus = true` を有効にした。

| コマンド | Starship のみ | Starship → 統合 |
| --- | --- | --- |
| `false \| true` | `PIPE=S=1 \|S=0 -> S=0 OK>` | `OK>` |
| `set -o pipefail; false \| true` | `PIPE=S=1 \|S=0 -> S=1 ERR>` | `S=1 ERR>` |

推奨順では統合とマウス解除のフックが Starship より先に動き、`PIPESTATUS` を `[0]` または `[1]` に変えてしまう。全体の `$?` は保たれるが、パイプの途中で失敗したコマンドを Starship が表示できない。既定の Starship は `pipestatus=false` のため、その状態ではこの表示差は表面に出ない。

## 確認できた動作

- OSC 7: Windows 形式の `C:/...` を送出し、空白、`#`、`%` を符号化する。日本語を含む実ディレクトリでも送出した。独立テストでは `?` と `\` の符号化も確認した（Windows で作れないパスなので `cygpath` のテスト用関数を使用）。ディレクトリが変わらないと `cygpath` は再実行されない。
- `WEZTERM_PROG`: 履歴に残るコマンドは実行前に base64 で送られ、次のプロンプトで空に戻る。コマンドが履歴に残らない条件では前のコマンド名を誤送出しない。
- 完了通知: 成功と失敗、`HISTCONTROL=ignorespace` の先頭空白、`HISTIGNORE`、履歴無効、`ignoredups` の同一コマンドを確認した。履歴に残らないコマンドでは通知のコマンド欄が空になり、同一コマンドの重複では正しいコマンド名が残った。
- 空 Enter: C や新たな完了通知を送らない。
- 統合だけを二度読み直しても、通常の scalar / array `PROMPT_COMMAND`、PS0 の C は重ならない。Starship の再初期化自体は Starship の PS0 式をもう一つ足すが、統合の C は一つのままだった。
- `set -u`、`--noediting`、既存の PS0 と併用しても unbound variable / bad substitution は発生しなかった。`BASH_REMATCH` の `a` も次のコマンドまで保たれた。
- 普通の array `PROMPT_COMMAND` の既存フックは残った。ただし、統合フックが配列の第 2 要素に既にある条件を作ると、第 1 要素にもう一度足されて OSC D が二重になった（既存の有無を第 1 要素だけで判定している）。
- 公式統合がある印の関数を用意すると、独自の OSC 7 / 133 / 通知は追加されず、マウス解除だけが残った。これは機能の分岐の確認であり、公式統合そのものの実行テストではない。
- 純 Bash の base64 は、空、1〜4 バイト、UTF-8 の日本語と絵文字、NUL を除く全 255 バイトで Python の base64 と一致した。

## 周辺の境界問題

Starship 固有ではないが、Git Bash の `${2:0:200}` は絵文字を 2 単位として数える。199 個の ASCII 文字の直後に `😀` を置くと、その途中で切れて不正な UTF-8 が送られた。198 個なら絵文字全体が残り、BMP の日本語は 200 文字で正常に切れる。`bash-helpers.py` はこの 199 文字の境界だけで assertion が失敗する（12 項目中 11 項目が正常）。

## 再実行と記録

この環境では PowerShell から以下を実行した。テスト用 cache と zoxide のデータはテスト用ディレクトリへ置く。本番のプロファイルは読まない。

```powershell
python tests/starship/bash-run.py
python tests/starship/bash-focused.py
python tests/starship/bash-pipeline.py
python tests/starship/bash-helpers.py
python tests/starship/bash-summarize.py
```

[修正前の公開集計](verification-summary.json)に、条件別の確認件数と成立・不成立をまとめた。`bash-results.json`、代表的な生の OSC と読みやすい表示、パイプ状態の可視差、helper の詳細はローカル生成物として保持した。

このテストの外にある zsh、WSL、Linux / macOS は未検証。root の Starship 設定を読まない最小の表示設定で試した。Starship のモジュール全体や外部サービスは対象にしていない。

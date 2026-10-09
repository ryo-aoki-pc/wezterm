# Git Bash と Starship の修正後の検証

この記録は Git Bash 修正直後の中間結果。続く SSH 対応を含む最終コードと配置後の確認は [SSH-FIX-REPORT.md](SSH-FIX-REPORT.md) を参照する。

公開用の集計は [verification-summary.json](verification-summary.json) にまとめた。生出力、実ペイン本文、環境の状態、cache、準備ファイルと配置前の控えはローカル保存の生成物で、Git の管理対象には含めない。再実行の前提は [README.md](README.md) を参照する。

検証日: 2026-10-06（Asia/Tokyo）

修正対象: `shell/wezterm.sh`

検証時の SHA-256: `5e1a4386f11e802fb8b5a8e184b84367d97a879a36339a91fed73a8e78c1437c`

## 結果

**推奨の初期化順で、Git Bash + Starship の出力コピー、プロンプトジャンプ、終了コード、パイプ個別ステータス、通知データが正常に動作した。Bash の必須確認 367 件と、実 WezTerm の確認 19 件がすべて成立した。**

この作業ツリーのシェル統合を修正した。テストは専用の rc・Starship 設定と隔離した WezTerm プロセスを使った。ユーザーのプロファイル、Starship 設定、本番の `~/.config/wezterm` は変更していない。テスト用 GUI とペインは検証後に終了した。

修正前の結果と再現証拠は [REPORT.md](REPORT.md) に残した。今回の結果は `fix-results/` に保存し、修正前の生出力と分けた。

## 修正内容

1. Starship がある Bash では、`starship_precmd` が終了コードと `PIPESTATUS` を先に保存する順序を保ち、独自統合とマウス解除のフックをその後に追加する。OSC 133 D と完了通知には `STARSHIP_CMD_STATUS` の保存済み終了コードを使う。
1. Starship が毎回作り直す `PS1` に、プロンプトを表す OSC 133 A と入力開始の B を毎回付け直す。元のプロンプトと `PS0` の実行開始 C は保つ。
1. `PROMPT_COMMAND` が配列の場合は全要素を調べ、フックの重複を防ぐ。ユーザーのフック・順序・配列の export 属性・コメントを保ち、旧版の先頭フックを移す。統合の再読込と Starship の再初期化も検査した。
1. Git Bash の絵文字が UTF-16 の 2 単位として数えられる境界では、ユーザー変数を絵文字の途中で切らないようにした。通知や `WEZTERM_PROG` の値を不正な UTF-8 にしない。

読み込む 1 行、配置先、環境変数は変更していない。推奨順は **Starship → シェル統合 → zoxide** のまま。Starship → zoxide → シェル統合でも今回の検査は成立した。

## 確認した動作

| 対象 | 結果・証拠 |
| --- | --- |
| Starship 適用済みペインの出力コピー | Prompt / Input / Output の範囲が生成され、`STAR_OUTPUT` だけをコピーした |
| 既存ペインに Starship を後付けし、統合を再読込 | `AFTER_THEME_OUTPUT` だけをコピーした。以前の誤コピーに含まれたプロンプトとコマンドは混入しない |
| Starship なしのコピー | `BASE_OUTPUT` だけをコピーし、従来の動作を保つ |
| プロンプトジャンプ | Starship あり・なしの両方で `ScrollToPrompt(-1)` 後の可視範囲を観測し、期待する絶対行の文字列と一致した |
| パイプ途中の失敗 | `false \| true` の `PIPESTATUS=1 0` を Starship に渡し、`pipestatus=true` の表示を保つ。`pipefail` の有無を確認 |
| 終了コード | `false=1`、サブシェルの `(exit 7)=7` が Starship と OSC 133 D の両方に入る |
| 完了通知データ | 実ペインの `sleep 2.2; false` は `1<TAB>3<TAB>sleep 2.2; false`。履歴設定・重複抑止・空 Enter も別途確認 |
| cwd と分割時の引継ぎ | 日本語・空白・`#`・`%` を含む実ディレクトリが分割先へ引き継がれた |
| リサイズ・コピーモード・ズーム | 実ペインで action を実行し、モード名とズーム状態を確認 |
| 再読込・再初期化 | 推奨順で統合を複数回読んでも各プロンプトの印とマウス解除は重ならない。Starship の再初期化単独でも、統合を続けて再読込する場合でも正常 |
| 既存設定との共存 | scalar / array のフック、既存 PS0、旧フックを含む配列、export 属性、コメントを保持 |
| シェルと文字の境界 | 行編集あり・なし、`set -u`、履歴設定、`BASH_REMATCH`、日本語・絵文字の切断位置、base64、OSC 7 のパス変換キャッシュを確認 |

実コピーは本番の `copy_last_output` を使い、OS クリップボードへの書込みだけを捕捉した。プロンプトジャンプは実 WezTerm のスクロール後に CopyMode で文字列を採取した。実測した `MoveToViewportTop` の 5 行の余白は、現在の [WezTerm の公式実装](https://raw.githubusercontent.com/wezterm/wezterm/main/wezterm-gui/src/overlay/copy.rs) の `move_to_viewport_top` / `dimensions` とも一致する。この余白を考慮して、選択行と期待する絶対行を比較した。

## 検証の規模と記録

| 項目 | 実測 |
| --- | --- |
| OS | Windows |
| Git Bash | `5.3.15(2)-release`、`OSTYPE=cygwin` |
| Starship | `1.26.0`（インストール済みの実 init と prompt） |
| WezTerm | `20260905-153129-092dcf70` |
| Bash | 20 条件。全 393 評価のうち、必須 367 / 367 成立（helper 14 件を含む） |
| Starship 再初期化単独の補助確認 | 統合の追加読込なしの実プロンプトで、10 / 10 確認成立 |
| 実 WezTerm / ConPTY | 23 snapshots、19 / 19 確認成立 |
| PowerShell の回帰確認 | 上の実ペイン確認に、PowerShell 7 と Windows PowerShell の出力コピー・native 失敗・空 Enter・通知データの計 8 件を含む |
| 構文・差分確認 | `bash -n`、Python 8 ファイルの構文確認、`git diff --check` が成立 |

Bash の全 393 評価には、推奨外の逆順を比較する 26 評価が含まれる。そのうち 9 評価では、統合を再読込する前の A / B と出力境界の欠落を記録した。これらは正常として数えていない。再読込後の復旧は必須確認に含め、成立した。

実ペイン検証の GUI stderr には、CLI 接続終了時の `PDU write` / `os10054` が 4 件記録された。各 CLI は成功し、19 件の確認が成立した。Lua 設定の読込エラーはなかった。

[Git Bash 修正直後の公開集計](verification-summary.json)に、条件別の確認件数、推奨外の制限、検証時のソースハッシュをまとめた。再初期化単独の補助確認は 10 / 10、実ペインの確認は 19 / 19 成立した。専用 rc、生出力、読みやすい出力、cache、zoxide のデータと実ペインの詳細は、`fix-results/` のローカル生成物として保持した。

この環境で再実行するときは、PowerShell から以下を実行する。Git Bash、Starship、zoxide、WezTerm が導入された環境を使う。`--fix` は結果を `fix-results/live/` に保存する。

```powershell
python -X utf8 tests/starship/bash-compat-check.py
python -X utf8 tests/starship/live-run.py --fix
python -X utf8 tests/starship/live-check.py --fix
```

## 制限と未検証範囲

- 統合 → Starship の推奨外の初期化順では、統合をもう一度読むまで A / B が欠ける。通常の導入では [docs/install.md の手順 5](../../docs/install.md#実施手順)に従って並びを直し、新しいタブを開く。
- OS 通知センターへのトースト表示と、物理キーを押しての操作は未確認。実ペインでは WezTerm の action と通知データを確認した。
- WSL、Linux / macOS、MSYS2 / QMK MSYS、zsh、古い Bash の実行は今回の修正後テストの対象外。Starship の表示は専用の短い TOML を使い、全モジュールや外部サービスは検証していない。
- PowerShell の統合は今回変更していない。前回記録した Starship 再初期化後の問題は今回の Git Bash 修正の対象外。
- 本番の配置先への反映は未実施。検証したファイルはこの作業ツリーの `shell/wezterm.sh`。

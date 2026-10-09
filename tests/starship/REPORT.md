# Starship 適用時の WezTerm カスタマイズ検証

この記録は修正前の調査結果であり、本文の失敗や行番号は当時のコードに対するもの。最終修正と配置後の確認は [SSH-FIX-REPORT.md](SSH-FIX-REPORT.md) を参照する。

公開用の集計は [verification-summary.json](verification-summary.json) にまとめた。生出力、実ペイン本文、環境の状態、cache、準備ファイルと配置前の控えはローカル保存の生成物で、Git の管理対象には含めない。再実行の前提は [README.md](README.md) を参照する。

検証日: 2026-10-06（Asia/Tokyo）

対象コミット: `fb52eeb643c1bf866c44b2716bb8376151797cd4`

この記録は修正前の検証結果です。Git Bash 対応の修正直後の結果は
[修正後の検証記録](FIX-REPORT.md)にあります。

## 結果

**完全な互換性はない。Windows の Git Bash + Starship では、直前の出力コピーに不具合を再現した。PowerShell は標準の起動順で主要機能が動作するが、Starship の再初期化で統合が外れる。**

本番の Lua・シェル統合、ユーザーのプロファイル、Starship 設定は変更していない。専用の WezTerm プロセスとテスト用設定を使い、作成したペインを終了した。テストと結果をこのディレクトリに保存した。

| 機能 | Git Bash + Starship（推奨順） | PowerShell 7 / Windows PowerShell + Starship（標準順） | 確認方法 |
| --- | --- | --- | --- |
| WezTerm 設定読込・日本語フォント | 正常 | 共通の設定で正常 | 実 WezTerm の `ls-fonts`。設定エラーなし、`a` と `あ` は HackGen Console NF、ピル端は WezTerm が描画 |
| cwd の通知と分割時の引継ぎ | 正常 | OSC 7 正常 | Bash は日本語・空白・`#`・`%` の実ディレクトリを分割へ引継ぎ。PS はパス符号化と FileSystem/provider 分岐も確認 |
| 直前の出力コピー | **不具合** | 正常 | 実 ConPTY の semantic zones と本番 `copy_last_output` を使用。OS クリップボード書込だけ捕捉 |
| プロンプトジャンプ | **必要な Prompt 範囲が生成されない** | Prompt 範囲は正常 | `ScrollToPrompt(-1)` を実行。画面のスクロール位置そのものは直接観測していない |
| 全体の終了コード | 正常 | 正常 | `false`、native exit 7、cmdlet エラー、stderr、古い LASTEXITCODE 等 |
| 長いコマンドの通知データ | 正常 | 正常 | 実ペインの `wezterm_cmd_done`、閾値境界、重複抑止。OS 通知センターへの表示は未確認 |
| リサイズ・コピーモード・ズーム | 正常 | 共通の設定 | Bash の実ペインで action を実行しモード名・ズーム状態を取得 |
| タブの cwd・プログラムアイコン・進捗・未読印 | Lua の処理は正常 | 共通の設定 | 実モジュールと API stub。画面上の見た目を目視確認した結果ではない |
| Starship のパイプ個別ステータス | **失われる** | この Bash 固有ケースは対象外 | `pipestatus=true` の表示を Starship 単体と比較 |
| 統合のみの再読込 | 通常は重複なし。A/B は復旧しない | 通常は重複なし | 推奨順・配列フック・再初期化を比較 |
| 起動後の Starship 再初期化 | A/B 消失が継続 | **prompt の統合が消失し、統合の再読込でも復旧しない** | 実 Starship init をもう一度実行 |

## 環境とテストの規模

| 項目 | 実測 |
| --- | --- |
| OS | Windows |
| WezTerm | `20260905-153129-092dcf70` |
| Starship | `1.26.0` |
| Git Bash | `5.3.15(2)-release`、`OSTYPE=cygwin` |
| PowerShell 7 / PSReadLine | `7.6.5` / `2.4.5` |
| Windows PowerShell / PSReadLine | `5.1.26100.9444` / `2.0.0`（子プロセスの比較テスト） |

- Bash は初期化順・scalar/array フック・履歴・再読込・nounset・noediting 等の **18 条件**を比較。別途 helper **12 項目中 11 項目が正常、1 項目で文字切断の不具合**。
- PowerShell は **74 個の独立プロセスケース**と **34 個の callback 確認**。通常動作に関する 494 assertions は成立し、逆順・再初期化・巨大閾値の 6 ケースで問題を再現。
- Lua は本番モジュールを WezTerm 内蔵 Lua で実行し、API を stub にした **49 assertions**が成立。内訳は procs 12、copy 16、tabs 10、notify 7、statusbar 3、bindings 1。
- 実 WezTerm/ConPTY は **23 snapshots**を採取。保存結果の **17 確認が成立**（正常機能 14、不具合再現 3）。

assertion の成立には「現状の不具合が期待どおり再現する」という確認も含む。カスタマイズ全体が正常という意味ではない。テスト表示は短い専用 Starship TOML を使用し、インストール済み Starship の実 init と prompt を実行した。

## 再現した互換性の問題

### 1. Bash: プロンプトと入力の区切りが消える

推奨の `Starship → shell/wezterm.sh → zoxide` でも、Starship がプロンプトごとに `PS1` を作り直し、`shell/wezterm.sh:356` が一度だけ足した OSC 133 A/B が消える。代表的な生出力では C は 42 回、A/B は各 0 回だった。C/D が存在しても、コピー処理が必要とする Input 範囲は生成されない。

実ペインの比較:

| 操作 | 実 WezTerm の範囲 | コピー結果 |
| --- | --- | --- |
| Starship なしで `printf 'BASE_OUTPUT\n'` | Prompt / Input / Output | `BASE_OUTPUT` |
| Starship ありで `printf 'STAR_OUTPUT\n'` | Output のみ | `コピーできません（要シェル統合）` |
| Starship なしで開始し、同じペインに Starship を適用後 `printf 'AFTER_THEME_OUTPUT\n'` | 過去の Input が残り、後続部分が Output | 下のようにプロンプト・新しいコマンドまで混入 |

```text
wezterm DURATION=0s OK>  printf 'AFTER_THEME_OUTPUT\n'
AFTER_THEME_OUTPUT
wezterm DURATION=0s OK>
```

`lua/actions.lua:103` は最後の確定済み Input を基準に出力を探すため、新しい Input が消えた場合に過去の入力を参照する。新規ペインでの使用不可に加え、後付け時の誤コピーも実測した。`Ctrl+Shift+Alt+↑/↓` に必要な Prompt 範囲も生成されない。公式の [semantic zones の説明](https://wezterm.org/config/lua/pane/get_semantic_zones.html) と照らして、範囲データの欠落を確認した。

証拠: `live-results/summary.json` の `baseline-output`、`starship-output`、`baseline-then-starship`。`live-results/verification.json` はそれぞれを機械的に確認する。

### 2. Bash: パイプ途中の失敗が Starship から見えなくなる

推奨順では `__wezterm_prompt_command` と `__wz_mouse_off` が Starship より先に実行され、`$?` は返すが `PIPESTATUS` の各要素を保持しない。

Starship の `[status] pipestatus=true` を有効にして比較した:

| コマンド | Starship 単体 | Starship → 統合 |
| --- | --- | --- |
| `false \| true` | `PIPE=S=1 \|S=0 -> S=0 OK>` | `OK>` |
| `set -o pipefail; false \| true` | `PIPE=S=1 \|S=0 -> S=1 ERR>` | `S=1 ERR>` |

全体の終了コードは正しいが、途中の失敗情報が失われる。既定の `pipestatus=false` ではこの表示差は表面に出ない。

証拠: `bash-pipeline-visible-baseline.txt`、`bash-pipeline-visible-recommended.txt`、`bash-results.json`。

### 3. Bash: 読み込み順を逆にすると失敗が成功として通知される

`統合 → Starship → zoxide` では、統合が Starship の退避フックへ入り、呼ばれる時の状態が 0 になる。Starship の表示自体は失敗を示していても、OSC 133 D と完了通知は 0 になった。

```text
推奨順: sleep 2.15; false → 通知 1<TAB>2〜3<TAB>sleep 2.15; false
逆順:   sleep 2.15; false → 通知 0<TAB>2<TAB>sleep 2.15; false
```

単なる統合の追加 `source` では、退避済みの古いフックと新しいフックが重なる場合もある。起動順を直したうえで新しいシェルを起動する必要がある。ただし、正しい順番でも問題 1 と 2 は残る。

### 4. PowerShell: Starship の再初期化後に統合を再読込しても戻らない

通常の `Starship → shell/wezterm.ps1` は正常だった。プロファイルで Starship を初期化し、`lua/shells.lua` の起動引数で統合を読む設計と整合する。

一方、次のどちらも両 PowerShell で再現した:

1. `統合 → Starship` の逆順。
2. `Starship → 統合 → Starship 再初期化 → 統合の再読込`。

Starship が `prompt` を上書きし、`shell/wezterm.ps1:20` のロード済みガードで再ラップが行われない。OSC 7、133 A/B/D、完了通知が消え、PSReadLine ラッパーの C だけが残る。

証拠: `powershell/results-final/summary.json` の `Mode=integration-first` / `reinitialize`。標準起動時には実ペインで `PS_OUTPUT` のコピーと `0<TAB>2<TAB>Start-Sleep -Seconds 2` の通知データも確認した。

## その他の境界問題と表示差

互換性の中心問題とは区別するが、詳細テストで次も確認した。

- **Git Bash の文字切断**: 199 個の ASCII の直後に絵文字 `😀` を置くと、`shell/wezterm.sh:252` の `${2:0:200}` が絵文字の途中を切り、ユーザー変数へ不正 UTF-8 を送る。198 個なら絵文字全体が残る。`bash-helpers.json` の `emoji-boundary-199` は失敗。
- **PROMPT_COMMAND 配列の重複**: 統合フックが既に配列の第 2 要素にある変則条件では、先頭にも追加されて D が二重になった。通常の配列・二重 source は正常。
- **PowerShell の巨大通知閾値**: `WEZTERM_NOTIFY_AFTER=999999999999999999999999` は `shell/wezterm.ps1:91` の int 変換でエラーを残し、既定 10 秒に戻って通知する。通常値・不正文字列・負数・ゼロ・境界はテストした。
- **Starship 側の PowerShell 表示**: native exit 7 の後に `Write-Error` を実行すると、Starship は古い `STATUS=7` を示すことがある。Starship 単体でも同じ挙動で、統合の OSC D は 1 と正しい。Windows PowerShell の native stderr を `2>&1` で受けるケースも Starship 単体と同じ表示の制限がある。統合による退行とは判断しない。

## 正常動作の証拠と限界

- Bash の `PS0` と Starship の開始時刻式が共存し、通常編集と `--noediting` で式の文字漏れがない。
- `set -u`、既存 PS0、BASH_REMATCH、通常の scalar/array フック、履歴の ignorespace/HISTIGNORE/ignoredups/無効化、空 Enter を確認した。
- Bash の `WEZTERM_PROG` は実行時に送られ、プロンプトで空に戻る。実通知データは `1<TAB>2<TAB>sleep 2.2; false` を WezTerm で復号して取得した。
- PowerShell の native/cmdlet エラー、古い LASTEXITCODE、StrictMode、PSReadLine なし、空 Enter、閾値境界、Unicode cwd、FileSystem 以外の provider を比較した。非対話ケースの時間・履歴は Add-History で再現し、実ペインの Start-Sleep と出力コピーでも補った。
- Lua のタブ・通知・ステータス処理は本番モジュールで確認した。前面アクティブペインの通知抑制、非アクティブ/非フォーカスの通知要求、失敗コード、空コマンドの表示も stub で確認した。
- **未検証**: Linux/macOS/WSL/zsh、実 SSH 接続、tmux/TUI の実マウス報告、IME、物理キー/マウス操作、アクリルや色の目視、実クリップボード、通知センター、全 Starship モジュール、ユーザーのプロファイル全体、transient prompt の実再描画。
- 公式統合の存在分岐はテスト関数で再現した。公式統合そのものを起動した結果ではない。
- Windows PowerShell の非対話ハーネスでは追加 Job adapter の自動読込を止めた。Starship の job 数の機能は対象外。
- `ScrollToPrompt` は action の呼出と範囲の有無まで確認した。`physical_top` は非スクロール画面の位置であり、ジャンプ後の可視スクロール位置を示す測定としては使っていない。
- GUI の stderr に CLI 接続切断の `os error 10054` が記録されたが、保存した 23 計測と action は完了した。設定読み込みエラーとは区別している。

## 再実行

リポジトリのルートで PowerShell から実行する。インストール済み WezTerm/Git Bash/Starship/Python/PowerShell を使う。この環境向けの実行ファイルパスを含むため、別の環境ではテスト内のパスを合わせる。

```powershell
python tests/starship/bash-run.py
python tests/starship/bash-focused.py
python tests/starship/bash-pipeline.py
python tests/starship/bash-helpers.py
& tests/starship/powershell/run-powershell.ps1
& 'C:\Program Files\WezTerm\wezterm.exe' --config-file "$PWD/tests/starship/lua-behavior.lua" ls-fonts --text 'a'
python tests/starship/live-run.py
python tests/starship/live-check.py
```

`bash-helpers.py` は現状の絵文字境界問題で終了コード 1 を返す。Lua や PowerShell の成功件数には不具合再現の確認も含むので、件数だけで互換性を判定しない。

Codex の filesystem sandbox 内では WezTerm が HOME 解決に失敗したため、WezTerm 実行は承認済みの sandbox 外プロセスで行った。HOME/USERPROFILE やユーザープロファイルを変更する回避策は不要。

公開記録:

- [修正前の確認集計と検証環境](verification-summary.json)
- [Bash の調査詳細](bash-report.md)

元の条件集計、helper 結果、PowerShell 計測、実ペイン本文、バージョンと対象ファイルの詳細記録は、ローカル生成物として保持した。

調査時点のコードでは、Bash は Starship の後で統合を読む必要があったが、出力コピーとプロンプトの区切りは別途修正が必要だった。PowerShell はプロファイルで Starship を初期化してから統合を読み、起動後に Starship を再初期化した場合は新しいペインを起動するのが確認済みの復旧方法である。

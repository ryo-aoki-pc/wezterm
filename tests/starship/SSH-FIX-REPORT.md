# SSH 先の Starship と公式 Bash 統合の修正後の検証

公開用の集計は [verification-summary.json](verification-summary.json) にまとめた。生出力、実ペイン本文、環境の状態、cache、準備ファイルと配置前の控えはローカル保存の生成物で、Git の管理対象には含めない。再実行の前提は [README.md](README.md) を参照する。

検証日: 2026-10-06（Asia/Tokyo）

検証・反映した `shell/wezterm.sh` の SHA-256: `40bbe213610c39019a1b394ae6a02dcc8b7dba64f2a87bdb7fbaca2a99532595`

## 結果

**SSH 先の公式 Bash 統合と Starship が共存するように修正し、Windows と `kawasaki-pi` の配置先へ反映した。反映後の通常 SSH でも、出力コピー・プロンプトジャンプ・パイプ状態・独自完了通知が正常だった。**

実 SSH の 22 条件で必須 438 件、Git Bash の回帰確認 367 件、実 WezTerm の比較確認 84 件と反映後の通常接続 37 件がすべて成立した。公式へ委譲する条件の限定モデルも 90 件すべて成立した。

既存の配置ファイルは SHA-256 を照合して控えを保存し、`shell/wezterm.sh` の 1 ファイルを Windows と `kawasaki-pi` で更新した。プロファイル・SSH / sshd の設定・公式スクリプト・Lua 設定は変更していない。既存のユーザーの WezTerm プロセスは維持し、試験で起動した GUI とペインは終了した。

修正前に観測した SSH の出力コピー失敗、独自通知の未送信、再読込時のマウス解除の重複は [SSH-REPORT.md](SSH-REPORT.md)に残した。このファイルは修正後の記録として分ける。

## 修正内容

1. 公式 Bash 統合が先に読まれる経路では、公式の cwd・ユーザー変数・bash-preexec dispatcher を保ち、semantic の precmd / preexec の登録 2 個だけを外す。Starship とユーザーのフックは残す。
1. bash-preexec dispatcher と Starship の後、`__bp_interactive_mode` の前に独自処理を置き、OSC 133 A / B / C / D と完了通知を補う。初回 install 前は先頭要素の末尾、稼働中は mode 直前の独立した配列要素へ登録する。ユーザーの途中要素を保ち、何度読んでも自分のフックを重ねないよう整理する。
1. 既に有効な公式 Bash 統合がある場合は、SSH で `TERM_PROGRAM` が受信されなくても補完する。公式のない経路は `TERM_PROGRAM=WezTerm` の条件を保つ。
1. 独自 cwd の関数を `__wz_osc7` へ改名し、公式の `__wezterm_osc7` を上書きしない。公式経路では既存の cwd 通知を使う。
1. zsh・ble.sh・tmux、semantic を明示的に無効化した環境は、従来どおり公式に任せる。

初期化の 1 行、配置先、Starship → 統合 → zoxide の順序、SSH / sshd の設定は変更しない。公式統合全体を止める `WEZTERM_SHELL_SKIP_ALL=1` は追加しない。

## 環境と検証の規模

| 対象 | 実測 |
| --- | --- |
| 手元 | Windows、Git Bash `5.3.15(2)-release`、Starship `1.26.0`、WezTerm `20260905-153129-092dcf70` |
| SSH 先 | `kawasaki-pi`、AlmaLinux 10.2 / aarch64、Bash `5.2.26(1)-release`、Homebrew の Starship `1.26.0` |
| 実 SSH / PTY | 22 条件、全 508 評価。必須 **438 / 438** 成立 |
| Git Bash の回帰確認 | 20 条件、全 393 評価。必須 **367 / 367** 成立 |
| 実 WezTerm の比較 | 76 snapshots、機能 **84 / 84** 成立。配置済み旧版の不具合比較 **2 / 2** を再現 |
| 配置後の通常 SSH | 28 snapshots、機能 **37 / 37** 成立。Git Bash 経由と Windows OpenSSH 直接の両方 |
| 公式へ委譲するガード | 5 条件の限定モデル、**90 / 90** 成立 |
| ソースの整合 | 実 SSH・Git Bash・ガード検査・後片付け・配置後の SHA-256 が上記の修正版と一致 |

実 SSH の必須確認は、通常の公式 → Starship → 統合 → zoxide、`TERM_PROGRAM` 未設定 / 実受信値、行編集なし、初期化前からの `set -u`、Starship 前後に登録したユーザーフック、旧版を先に読んだ状態、稼働中の移行を含む。`PROMPT_COMMAND` の途中のユーザープロンプト更新、dispatcher を外した後の古い保存値の無視、Starship の無い公式 Bash も確認した。

必須の成立数には、旧版比較のうちセッションの正常終了・環境情報などの基本確認を含む。旧版自体の互換性が直ったことを意味しない。全 508 評価中、比較・補助の 70 評価では 28 件が不成立だった。内訳は旧版のパイプ状態 3、公式のみ / 旧版共存時の B / C 欠落 4、推奨外の逆順の再読込前の A / B / コピー境界 3、公式経路で Starship だけを直接再初期化した際のフック重複 18。これらは必須確認と分けて記録した。

## 実ペインと配置後の確認

| 動作 | 結果 |
| --- | --- |
| 直前出力のコピー | Git Bash 経由と Windows OpenSSH 直接の通常接続で、リモートの試験出力だけをコピーした。以前の `Last login: …` の誤コピーは解消 |
| Prompt / Input / Output | Starship 後にも入力範囲が生成された。公式 semantic は外し、印を二重に送らない |
| パイプ状態 | `false | true` の `PIPESTATUS=1 0` と、`pipefail` 時の失敗を保持 |
| 終了コード | `false=1`、サブシェルの `(exit 7)=7` を Starship と OSC 133 D に保持 |
| 独自通知 | リモートの `sleep 2.2; false` の失敗コードと経過時間・コマンドが届いた |
| 複数行入力 | 継続プロンプトでも入力・出力の範囲を保ち、出力だけをコピーした |
| 再読込・再初期化からの復旧 | 統合の再読込で印とフックが重ならず、Starship 再初期化後も統合を読み直して単独化した |
| cwd・タブ・ジャンプ | リモートホスト付き cwd とタブ表示、`ScrollToPrompt(-1)` の可視行を確認 |
| 空 Enter・SSH 終了 | 空 Enter 後も直前出力を保持し、Git Bash 経由の SSH 終了後は手元の出力コピーへ復帰 |
| 本配置での初期化 | パスの上書きやリモートコマンド指定を使わない通常 SSH で確認。`TERM_PROGRAM` が未受信でも、既存の公式 Bash 統合を補完した |

コピーは本番の `copy_last_output` を使い、OS クリップボードへの書込みだけを捕捉した。ジャンプは実 WezTerm のスクロール後に選択行を採取した。通知は端末へ届くデータを確認しており、OS 通知センターの表示は対象外。

## 配置と控え

反映前の Windows と `kawasaki-pi` の配置ファイルは、どちらも `8ed8a09c46edd310d22369310dc44fc8d929cf93d9550ae5958062da87d12363` だった。内容を照合し、ローカルの配置前の控えへ保存してから更新した。

- Windows: `$env:USERPROFILE/.config/wezterm/shell/wezterm.sh`
- `kawasaki-pi`: `$HOME/.config/wezterm/shell/wezterm.sh`

更新後は両方が検証済みの SHA-256 と一致した。反映後の通常 SSH を専用 GUI で確認し、37 件すべて成立した。戻す場合は、この控えが対象の配置前ファイルであることと現在の内容を照合し、`shell/wezterm.sh` だけを戻す。配置と控えの詳細記録はローカル生成物として保持した。公開用の検証件数と対象ソースハッシュは [verification-summary.json](verification-summary.json) にある。

## 読む順番の記録

`CLAUDE.md` と個人 Bash 設定の `CLAUDE.md` は、`PROMPT_COMMAND` / `PS0` の変更時に、個人 Bash README の「読む順番」の実測を取り直すよう定めている。今回の公式 → Starship → 統合 → zoxide の新規起動・再読込・保存済み状態を記録した。初回 install 前は先頭要素の末尾、稼働中は dispatcher とユーザー処理の後、`__bp_interactive_mode` の前に独自フックを置く。個人 Bash README へ今回の実測を追記し、過去の記録と既存の差分は保持した。読み込む 1 行と配置先は変えないので、個人 Bash の `bashrc` / `migrate/old-lines.txt` は変更していない。既存内容のバイト一致と前後のハッシュはローカルの README 更新記録に残した。

## 記録と再実行

[修正後の公開集計](verification-summary.json)に、実 SSH、Git Bash 回帰、実 WezTerm 比較、配置後の通常接続、委譲ガードの確認件数・条件・成立状況とソースハッシュをまとめた。`ssh-fix-results/` の生出力、専用 rc、実ペイン本文と状態、配置・README 更新・後片付けの記録はローカル生成物として保持した。

リモートの試験ディレクトリは除去し、別 SSH の `test ! -e` と `TEMP_REMOVED` で確認した。再準備の補助確認では、リモート内で現在配置を比較用に複製し、SHA 一致・22 rc の参照先・試験ディレクトリの除去を確認した。

この環境での再実行例。SSH は既存 alias と鍵認証を使い、準備した専用 rc を実 PTY / WezTerm で読む。`--fix` は修正後の記録へ分け、準備時点のリモート配置ファイルをリモート内で `temp/production.sh` へ複製して比較用にする。比較用 snapshot の SHA と由来は manifest に記録する。以下の検証コマンドは本配置を書き換えない。

今回の旧版対照 2 件と旧版のパイプ・B / C 欠落は、反映前に採取した保存済み記録による。配置後の再準備では修正版の現在配置を使うため、その対照結果は配置前の旧版対照と条件が異なる。配置前の控えはロールバック用の証拠として保持している。

```powershell
python -X utf8 tests/starship/ssh-check.py kawasaki-pi --fix --prepare-only
python -X utf8 tests/starship/ssh-check.py kawasaki-pi --fix --reuse --keep-temp
$sshFixPreviousResults = $env:WEZTERM_STARSHIP_TEST_RESULTS
try {
  $env:WEZTERM_STARSHIP_TEST_RESULTS = 'tests/starship/ssh-fix-results/git-bash'
  python -X utf8 tests/starship/bash-compat-check.py
} finally {
  $env:WEZTERM_STARSHIP_TEST_RESULTS = $sshFixPreviousResults
}
python -X utf8 tests/starship/ssh-guard-check.py
python -X utf8 tests/starship/ssh-live-run.py --fix
python -X utf8 tests/starship/ssh-fix-live-check.py
python -X utf8 tests/starship/ssh-live-run.py --deployed
python -X utf8 tests/starship/ssh-fix-live-check.py --deployed
python -X utf8 tests/starship/ssh-check.py kawasaki-pi --fix --cleanup
```

## 制限と検証対象

- 公式の bash-preexec 経路では、Starship だけを直接再初期化すると `precmd_functions` / `preexec_functions` へ登録が重なる。続けて統合を読み直せば各 1 個へ復旧することを必須確認で検証した。通常の個人 Bash 設定は Starship の再初期化をガードしている。
- 統合 → Starship の推奨外の順序では、統合を読み直すまで A / B とコピー境界が欠ける。導入時は Starship → 統合 → zoxide の順を保ち、新しいシェルを開く。
- tmux / ble.sh / semantic 無効化の委譲は、公式スクリプトと修正版を実 Git Bash で読む限定モデルで確認した。実 tmux / ble.sh プロセスの起動は未実施。zsh は手元と両 SSH ホストにコマンドが無く、構文・実行は未確認。
- ユーザーの既存の Starship 設定と専用 TOML を使ったが、全モジュールや外部サービス、別の Starship 版は対象外。
- 物理キー操作や OS 通知センターのトースト表示は未確認。もう一方の調査ホストには Starship が無いため、今回の Starship 修正の反映対象は `kawasaki-pi`。

- 今回確認した Bash は 5.3.15 と 5.2.26。古い Bash は未検証で、Bash 5.0 以下における公式 bash-preexec dispatcher の再読込は検証対象外。

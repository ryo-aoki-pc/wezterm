# SSH 先の Starship と WezTerm の検証

この記録は SSH 不具合の調査結果で、最終修正前に採取したもの。修正と配置後の確認は [SSH-FIX-REPORT.md](SSH-FIX-REPORT.md) を参照する。

公開用の集計は [verification-summary.json](../../../tests/starship/verification-summary.json) にまとめた。生出力、実ペイン本文、環境の状態、cache、準備ファイルと配置前の控えはローカル保存の生成物で、Git の管理対象には含めない。再実行の前提は [README.md](../../../tests/starship/README.md) を参照する。

検証日: 2026-10-06（Asia/Tokyo）

作業ツリーの `shell/wezterm.sh` の SHA-256: `5e1a4386f11e802fb8b5a8e184b84367d97a879a36339a91fed73a8e78c1437c`

## 結果

**SSH 先の既存設定では、公式 WezTerm 統合と Starship の組合せに出力コピーの不具合が再現した。Git Bash 用に修正した独自統合を、接続先へ反映するだけではこの経路を置き換えられない。**

`kawasaki-pi` の通常 SSH ログインでは、公式統合が Starship より先に読み込まれる。公式統合は `bash-preexec` を使い、`TERM_PROGRAM` が無くても OSC を送る。Starship がプロンプトを作り直すと入力開始の OSC 133 B が消え、実 WezTerm の出力コピーは直前のコマンド出力ではなくログイン時の出力をコピーし続けた。この設定の独自統合は公式統合を検出するとマウス報告よけの後で終了するため、独自の完了通知も送られない。

**公式統合を外した隔離環境では、作業ツリーの修正版と Starship の組合せは正常だった。** 7 条件の必須確認 129 件がすべて成立した。実 WezTerm の SSH ペインでも、Git Bash から接続する場合と Windows の OpenSSH を直接起動する場合の両方で、出力コピー、プロンプトジャンプ、パイプ状態、独自通知など各 11 機能が成立した。通常ログインの公式経路でも `PIPESTATUS=1 0` は保持されたため、出力コピーの不具合とパイプ状態の不具合は区別する。

今回はチェックを行った。本番のシェルコードや接続先の設定は修正していない。通常ログインと、専用 rc・作業ツリーの修正版を使う隔離したシェルを分けて確認した。

## 環境と読み込み順

| 項目 | 実測 |
| --- | --- |
| 手元 | Windows、WezTerm `20260905-153129-092dcf70`、OpenSSH |
| SSH 接続先 | 既存の SSH alias 2 件、鍵認証 |
| 接続先 OS | AlmaLinux 10.2 (Lavender Lion)、aarch64 |
| 接続先 Bash | `5.2.26(1)-release` |
| `kawasaki-pi` の Starship | Homebrew 版 `1.26.0` |
| もう一方のホストの Starship | コマンドが存在しないため Starship の動作確認対象外 |
| 配置済み個人統合の SHA-256 | 両ホストとも `8ed8a09c46edd310d22369310dc44fc8d929cf93d9550ae5958062da87d12363`。Git Bash 修正前の版 |
| 公式統合 | 両ホストに `/etc/profile.d/wezterm.sh` が存在 |
| 環境変数の受信 | 両ホストとも既存設定 / 一時 `SendEnv=TERM_PROGRAM` で `TERM_PROGRAM=unset` |

`kawasaki-pi` の通常ログインは、`/etc/profile.d/wezterm.sh` → ユーザーの Bash 設定 → Starship → 個人の `shell/wezterm.sh` → zoxide の順だった。公式統合が先に `bash-preexec` を用意するため、Starship は `PROMPT_COMMAND` に直接登録する経路ではなく、`precmd_functions` / `preexec_functions` に登録する。

読み取りプローブの最初のプロンプト前では、`precmd_functions` は `__wezterm_semantic_precmd`、`__wezterm_user_vars_precmd`、`__wezterm_osc7`、`starship_precmd`。個人統合の `__wezterm_prompt_command` は登録されず、マウス解除の `__wz_mouse_off` が `PROMPT_COMMAND` の先頭に付いていた。`bash-preexec` は最初のプロンプトでフックを組み直すため、稼働後の判定には実 PTY と実 WezTerm の結果を用いた。

## 接続条件と試験の分離

- 読み取りプローブでは既存 SSH alias、`BatchMode=yes`、`StrictHostKeyChecking=yes`、`ConnectTimeout=8` を使った。秘密鍵、履歴ファイルの中身、トークンは読んでいない。
- SSH の環境変数転送は、手元のプロセスだけで `TERM_PROGRAM=WezTerm` を設定して確認した。既存設定と一時的な CLI の `SendEnv=TERM_PROGRAM` を、両ホストで比較した。受信結果は 4 条件すべて `unset`。
- 通常 SSH ログインと、リモートコマンドで `TERM_PROGRAM=WezTerm` を一時指定したログインシェルを別のケースとして扱った。環境変数を指定したケースは SSHd の受信設定を変更していない。
- 履歴は `HISTFILE=/dev/null` または `unset HISTFILE` で保存を避けた。`HISTFILE=/dev/null bash -l` はユーザーの初期化後も `/dev/null` のまま保持されることを確認した。
- 専用 rc、Starship 設定、作業ツリーの修正版と接続先の配置済み旧版を使う隔離したシェルは、既存プロファイルの経路と分けた。公式統合の有無、行編集、`set -u`、環境変数の欠落、初期化順を比較した。

## 本番 Lua 関数のモデル試験

`ssh-lua-behavior.lua` は本番の `procs`、出力コピー、タブ、通知の関数を読み込み、Pane / Window の API 応答をモデル化して呼び出した。**必須 36 件がすべて成立し、既知制限 3 件を含む 39 評価すべてが期待した挙動と一致した。** 実 SSH 通信・端末の OSC 解釈・描画の検査とは分けている。

Git Bash 経由と OpenSSH 直接の SSH 判定、リモートから `WEZTERM_PROG` が変更された場合、入力中 / 実行中のコピー抑止、SSH 終了後の復帰、ホスト付き cwd とタイトルの優先順、通知の文面と前面ペインでの抑止、不正な通知データを扱う動作を確認した。

既知制限 3 件は次のとおり。成立数は制限が解消されたことを意味しない。

- Git Bash の `alias s='ssh host'` のようなエイリアスは展開できず、実行中のコマンド文字列だけでは SSH と認識できない。
- 上のエイリアス経由で、接続先にも入力範囲の統合が無い場合、SSH 全体を出力とみなすことの防止には制限がある。
- 接続先と手元の短縮ホスト名が同じ場合、タブの cwd 判定ではローカルとして扱われる。

これらはモデル試験で確認した制限であり、今回の 2 ホストで実際にエイリアスやホスト名衝突を作った試験ではない。

## 記録

[SSH 調査時の公開集計](../../../tests/starship/verification-summary.json)に、実 PTY の必須 220 評価、失敗した 10 評価、実 WezTerm の機能確認 46 件と不具合再現 10 件、Lua モデルの確認件数をまとめた。環境・読み込み順・履歴設定・転送条件のプローブ、準備 manifest、生出力、実ペイン本文、後片付け記録は、`ssh-results/` のローカル生成物として保持した。

bash-preexec の単独補助プローブは、状態保存より前にフックを呼ぶ最小 stub の診断。公式の `__bp_install` と DEBUG trap を再現していないため、通常 SSH のパイプ状態の判定根拠には用いていない。

この環境での再実行例。`ssh-check.py` は既存 SSH alias に接続できること、Starship と Bash が接続先にあることを前提とする。`--keep-temp` は実 WezTerm の試験で使う専用 rc を残し、最後の `--cleanup` は manifest に記録した専用の一時ディレクトリだけを除去する。

```powershell
python -X utf8 tests/starship/ssh-probe.py
python -X utf8 tests/starship/ssh-history-probe.py
python -X utf8 tests/starship/ssh-check.py kawasaki-pi --prepare-only
python -X utf8 tests/starship/ssh-check.py kawasaki-pi --reuse --keep-temp
python -X utf8 tests/starship/ssh-live-run.py
python -X utf8 tests/starship/ssh-live-check.py
& 'C:\Program Files\WezTerm\wezterm.exe' --config-file tests/starship/ssh-lua-behavior.lua ls-fonts --text a
python -X utf8 tests/starship/ssh-check.py kawasaki-pi --cleanup
```

`ssh-check.py` は既知の不成立を含む全条件を比較するため、今回の集計では終了コード 1 を返した。保存した結果の 10 失敗と補助確認を読み、全条件成功として扱わない。

Python 6 ファイルと Bash 補助スクリプトの構文、`git diff --check` も成立した。

## 制限と未検証範囲

- SSH / sshd の `SendEnv` / `AcceptEnv` を本番設定に追記する操作、導入手順全体の再実行、修正版の本番配置は行っていない。
- `tmux` の実プロセス内での動作、zsh / fish、別の Starship 版、他ホストの異なる初期化設定は対象外。`TERM_PROGRAM=tmux` の隔離条件は、実 tmux の検証を意味しない。
- 実コピーでは本番の `copy_last_output` を使い、OS クリップボードへの書込みだけを捕捉した。物理キー操作や OS 通知センターのトースト表示は確認していない。
- タブ名・cwd とプロンプトジャンプ・出力コピー・独自通知は別の経路を使う。公式の OSC 7 が届いて cwd が分かることだけでは、入力範囲や独自通知の成立を保証しない。

# Starship と WezTerm の検証

Git Bash と SSH 先の Starship が、このリポジトリのシェル統合・出力コピー・完了通知と共存するかを確かめる手動検証用の harness。最終修正と配置後の確認は [SSH-FIX-REPORT.md](SSH-FIX-REPORT.md)、公開用の集計は [verification-summary.json](verification-summary.json) にある。

修正前の調査は [REPORT.md](REPORT.md)・[bash-report.md](bash-report.md)・[SSH-REPORT.md](SSH-REPORT.md)、Git Bash 修正直後の中間結果は [FIX-REPORT.md](FIX-REPORT.md) に残している。過去の不成立を現在の結果として扱わないこと。

## 前提

- Windows、PowerShell、Python 3、Git Bash、Starship、zoxide、WezTerm が必要。PowerShell の比較試験には PowerShell 7 と Windows PowerShell 5.1 も使う。
- 実測した手元の主要バージョンは Git Bash 5.3.15、Starship 1.26.0、WezTerm `20260905-153129-092dcf70`。SSH 先は Bash 5.2.26、Starship 1.26.0 を使った。別の版や古い Bash は未検証。
- SSH 試験は既存の SSH alias と鍵認証を使う。対象ホストには Bash、Starship、zoxide、公式 WezTerm Bash 統合が必要。ユーザーの SSH / sshd 設定やプロファイルを、この harness のために変更する必要はない。
- スクリプトには、この検証環境での実行ファイルパス、SSH alias、リモートの配置パスや期待するホスト名を含む。再実行前に、各 script の定数・manifest の参照先・checker の期待値を自分の環境に合わせる。特に SSH 用の runner と checker は同じ対象ホストを指定する。
- `ssh-guard-check.py` は `tests/starship/cache/official-wezterm.sh` を入力に使う。検証対象ホストの `/etc/profile.d/wezterm.sh` を読み取り専用で取得し、その場所へ保存してから実行する。これは配布用 fixture ではなく、対象環境の公式スクリプトを使うためのローカル入力である。

## 実行

リポジトリのルートで PowerShell から実行する。インストール済みの Python を `python` で呼べる環境を使う。

```powershell
python -X utf8 tests/starship/bash-compat-check.py
python -X utf8 tests/starship/live-run.py --fix
python -X utf8 tests/starship/live-check.py --fix
```

SSH の準備・実 PTY・実 WezTerm・後片付けを含む順序は [SSH-FIX-REPORT.md の再実行例](SSH-FIX-REPORT.md#記録と再実行) にある。`ssh-check.py` の準備を先に行うと、リモートに一時ディレクトリと専用 rc を作り、手元へ `prepared.json` を生成する。実 WezTerm 用の runner はこの manifest を読む。試験終了時は `ssh-check.py` の cleanup を実行する。

`live-check.py`・`ssh-live-check.py`・`ssh-fix-live-check.py` は対応する runner の記録を入力にするため、runner を先に実行する。Lua 単独の SSH モデルを実行するときも、結果を書き出す `ssh-results/` を準備する。

実 WezTerm 用の runner は専用 GUI と試験ペインを起動し、終了時に後片付けする。既存のユーザーの WezTerm GUI を再起動しない。通知の判定は端末に届くデータ、コピーの判定は本番関数が取得する文字列を対象にしている。OS 通知センターの表示や物理キー操作の結果は、この試験からは断定できない。

## 記録

`fix-results/`、`live-results/`、`ssh-results/`、`ssh-fix-results/`、PowerShell の結果ディレクトリと root の詳細 JSON・raw・txt は、各 runner がローカルに生成する。cache、zoxide のデータ、GUI の PID・request・ログ、生成した rc も Git の管理対象に含めない。

公開用の [verification-summary.json](verification-summary.json) は、検証件数・条件・test 名・成立状況・ソースハッシュを残した採取済みの集計。実ペイン本文、個人のパス、環境の状態、配置前のファイルは含めない。再実行して得た詳細結果はローカルに保存し、この公開集計の日時やソースハッシュと区別する。

PR 向けに整理する前の報告書の原本は、`local-records/reports-before-pr/` にバイト一致の控えを保存した。生ログや配置前の控えとともにローカルで保持し、公開しない。

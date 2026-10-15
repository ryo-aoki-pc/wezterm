# WezTerm README の検証記録

実施日・対象版: 不明（「SSH のシェル統合の検証」を除く）。機能の説明は [README](../../README.md)を参照。

## 閉じるときの確認

WezTerm からは `bash.exe` しか見えず、vim の編集中でも確認なしで閉じてしまいます（実機で確認済み）。

## PowerShell の prompt

[PowerShell の統合](../../README.md#powershell)の未確認事項。

- 元の `prompt` 関数からは、直前のコマンドの成否（`$?`）がそのまま見えます
  （`$?` で失敗を表示するテーマのため。oh-my-posh・starship そのものでは試していない）

Linux / ssh の説明の対象版: [92f799a6ee6f45d1648db622760ffeea2ed5ad98](https://github.com/ryo-aoki-pc/wezterm/blob/92f799a6ee6f45d1648db622760ffeea2ed5ad98/README.md)。現在の動作は [README](../../README.md#シェル統合)を参照。

## SSH のシェル統合の検証（2026-10-06）

記録を確認した版: [6474a968ad06844d078828468f762272f751a4b0](https://github.com/ryo-aoki-pc/wezterm/blob/6474a968ad06844d078828468f762272f751a4b0/README.md)。

外部の AlmaLinux 10 / aarch64 の 2 台で通常接続と、公式統合を止めた一時セッションを比較した修正前の結果は
[追加検証の記録](install.md#付録-os-通知と外部-ssh-の追加検証2026-10-06)に残しています。
修正前の SSH 実機検証では、公式統合 → Starship の並びで入力開始の印が消え、出力コピーがログイン時の
出力を選び続ける問題と独自通知の未送信を確認しました。当時の記録は [SSH 検証記録](starship/SSH-REPORT.md)に残しています。
公式 Bash 統合との共存を修正し、Windows と `kawasaki-pi` の配置先へ反映しました。通常 SSH の両接続経路で
出力コピーと独自通知の成立を確認しています。修正内容と追加検証は [SSH 修正後の検証記録](starship/SSH-FIX-REPORT.md)にあります。

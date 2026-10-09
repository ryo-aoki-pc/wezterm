# WezTerm README の検証記録

[README](../../README.md#閉じるときの確認) の「閉じるときの確認」にあった記録。実施日・対象版は元の記載に無い。

## 閉じるときの確認

WezTerm からは `bash.exe` しか見えず、vim の編集中でも確認なしで閉じてしまいます（実機で確認済み）。

## PowerShell の prompt

[README の PowerShell](../../README.md#powershell) にあった未確認事項。

- 元の `prompt` 関数からは、直前のコマンドの成否（`$?`）がそのまま見えます
  （`$?` で失敗を表示するテーマのため。oh-my-posh・starship そのものでは試していない）

以下の Linux / ssh の既存説明は、元の固定コミット `92f799a6ee6f45d1648db622760ffeea2ed5ad98` にあった共存修正前の記録。現在の動作は [README](../../README.md#シェル統合)を参照。

## Linux の公式シェル統合

[README の bash と zsh](../../README.md#bashgit-bash--msys2--qmk-msys--linuxと-zsh) にあった説明とコンテナでの確認記録。実施日・対象版は元の記載に無い。

Linux 版 WezTerm のパッケージは公式のシェル統合を `/etc/profile.d/wezterm.sh` に置きます。
それが読み込まれている環境では OSC 7 / OSC 133 は公式側に任せ、`shell/wezterm.sh` は
マウス報告よけだけを残して抜けます（同名の `__wezterm_osc7` を上書きして公式側のフックを
壊さないため）。この場合、完了通知は動きません。AlmaLinux 10 の COPR 版では、公式側が
すべての対話シェルで先に読まれ、この形になることをコンテナで確かめました
（[docs/install.md の注意点](../reference/install.md#注意点)）。

## ssh 先の公式シェル統合

[README の ssh 先でもシェル統合を使う](../../README.md#ssh-先でもシェル統合を使う) にあった注意と追加検証への案内。

ssh 先でパッケージ付属の公式統合が先に読まれる場合は、上の 3 条件だけでは完了通知は使えません。
この設定の統合はマウス報告よけだけになり、Starship との併用では出力の区切りも失われることがあります。
外部の AlmaLinux 10 / aarch64 の 2 台で通常接続と、公式統合を止めた一時セッションを比較した結果は
[追加検証の記録](install.md#付録-os-通知と外部-ssh-の追加検証2026-10-06)にあります。

## SSH 共存修正前後の検証（2026-10-06）

以下は upstream `6474a968ad06844d078828468f762272f751a4b0` の README から移した記録。この文書分離の作業による再検証ではない。

外部の AlmaLinux 10 / aarch64 の 2 台で通常接続と、公式統合を止めた一時セッションを比較した修正前の結果は
[追加検証の記録](install.md#付録-os-通知と外部-ssh-の追加検証2026-10-06)に残しています。
修正前の SSH 実機検証では、公式統合 → Starship の並びで入力開始の印が消え、出力コピーがログイン時の
出力を選び続ける問題と独自通知の未送信を確認しました。当時の記録は [SSH 検証記録](../../tests/starship/SSH-REPORT.md)に残しています。
公式 Bash 統合との共存を修正し、Windows と `kawasaki-pi` の配置先へ反映しました。通常 SSH の両接続経路で
出力コピーと独自通知の成立を確認しています。修正内容と追加検証は [SSH 修正後の検証記録](../../tests/starship/SSH-FIX-REPORT.md)にあります。

# WezTerm の動作確認と対処

[文書案内](README.md) / [設定の導入](install.md) / [操作ガイド](usage.md)

以下のコマンドは、clone したリポジトリの直下で実行します。過去に実施した検証結果は [検証記録](verification/install.md) を参照してください。

## 目次

- [動作確認](#動作確認)
- [トラブルシューティング](#トラブルシューティング)

## 動作確認

設定を反映せずに読み込みだけ検証できます。

```sh
# 設定エラーの検出。エラー行が出なければ読み込めている
# （ついでにフォントがどのファイルで解決されるかも分かる）
wezterm --config-file "$PWD/wezterm.lua" ls-fonts --text 'あ'

# キー割り当てのダンプ
wezterm --config-file "$PWD/wezterm.lua" show-keys
```

**注意**: `show-keys` は設定の読み込みに失敗しても何も言わずデフォルト設定の
一覧を表示し、終了コードも 0 のままです。設定エラーの有無は上の `ls-fonts` で
確認してください（こちらは `ERROR ... runtime error:` を stderr に出します）。
`show-keys` の出力を見る場合は、自分で定義したキー（`PaneSelect` など）が
実際に載っているかどうかで読み込み成否を判断します。

シェル統合の構文確認:

```sh
bash -n shell/wezterm.sh && zsh -n shell/wezterm.sh
```

実施した環境・対象版・結果・未確認事項は [導入と動作の検証記録](verification/install.md)、旧 README にあった実機の記録は [旧 README の検証記録](verification/readme.md) を参照してください。

## トラブルシューティング

| 症状 | 確認すること |
| --- | --- |
| アイコンやタブの丸い端が □ になる | HackGen Console NF（または Symbols Nerd Font Mono）が入っているか。`ls-fonts` でどのフォントが使われているか見る |
| 設定を変えたのに反映されない / 見た目が素の WezTerm になった | 設定エラー。画面上部のエラー表示か、`ls-fonts` の `ERROR` 行を見る。stable 版で起動していないか（nightly 必須） |
| 新しいタブが今のディレクトリで開かない / タブ名がディレクトリ名にならない | [シェル統合](reference/shell-integration.md#シェル統合)が読み込まれているか。bash は `~/.bashrc` の 1 行、WSL は WSL 側の `~/.bashrc`（[docs/install.md の手順 9](install.md#実施手順) で確かめられる） |
| 「コピーできません（要シェル統合）」と出る | 同上。コマンドプロンプトは非対応。tmux の中も非対応 |
| 「コピーできる出力がありません」と出る | 画面に実行したコマンドが無い（開いた直後・`clear`・`Ctrl+Shift+Alt+K` の後）。zsh では、テーマがプロンプトを作り直して入力の開始の印が消えていないか（[bash と zsh](reference/shell-integration.md#bashgit-bash--msys2--qmk-msys--linuxと-zsh)） |
| 「ssh 先の出力は区切れません」と出る | ssh 先でシェル統合が動いていない。[ssh 先でもシェル統合を使う](reference/shell-integration.md#ssh-先でもシェル統合を使う) |
| 完了通知が出ない | 10 秒以上かかったか（`WEZTERM_NOTIFY_AFTER`）、そのペインを見ていなかったか、OS の通知で WezTerm が許可されているか、表示中のワークスペースか。`sleep 11` を実行してすぐ別のタブに切り替えると試せる |
| 完了通知にコマンド名が出ない | bash で履歴に残らないコマンド（`HISTCONTROL=ignorespace` での先頭の空白など）。[完了通知](usage.md#長いコマンドの完了通知) |
| Git Bash を閉じるたびに確認が出る | 仕様（[閉じるときの確認](usage.md#閉じるときの確認)） |
| ssh 中のタブ名がローカルのタイトルのまま | ssh 先のシェルがタイトルを設定していない。ssh 先の `PS1` / `PROMPT_COMMAND` でタイトル（`\e]0;...\a`）を送るようにする。Git Bash・WSL からの ssh なら、手元のシェル統合が読み込まれているか。Git Bash・WSL ではエイリアス経由（`alias s='ssh host'`）の ssh は判定できない |
| ssh の一覧にホストが出ない | `~/.ssh/config` に `Host` があるか（ワイルドカードは出ない）。編集後は `Ctrl+Shift+R` |
| lazygit の終了後に `^[[<35;...M` が出る | [迷子のマウス報告よけ](reference/shell-integration.md#迷子のマウス報告よけ) |
| Wayland でウィンドウをドラッグできない | 仕様（[Wayland の事情](usage.md#wayland-の事情)）。`Win`+ドラッグで移動 |

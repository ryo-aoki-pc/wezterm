# WezTerm の設定の導入手順（AlmaLinux 10 / Windows 11 の Git Bash）

Windows 11・AlmaLinux 10 の導入・利用・更新手順は setup-notes の2冊に集約した。

## 実施手順

[AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md#wezterm-の設定を導入する) / [Windows 11](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-setup.md#wezterm-の設定を導入する)

## WSL でもシェル統合を使う（任意）

[Windows 11](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-setup.md#wezterm-のシェル統合を-wsl-で使う任意)

## ssh 先でもシェル統合を使う（任意）

[AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md#wezterm-のシェル統合を-ssh-先で使う任意)

## 更新

[AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md#wezterm-の設定を更新する) / [Windows 11](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-setup.md#wezterm-の設定を更新する)

## ロールバック

[元に戻す手順](extra/install.md#ロールバック)

## 注意点

[運用上の注意](extra/install.md#注意点)

## AlmaLinux 10・Git Bash 以外のシェル

MSYS2・QMK MSYS・zsh は、各シェルのホームの `~/.bashrc`（zsh は `~/.zshrc`）で統合を読む。starship の後、zoxide の前に置く。

1. エディタで該当する rc ファイルを開き、次の 1 行を追記する。

   ```bash
   [ -r "${WEZTERM_SHELL_INTEGRATION:=$HOME/.config/wezterm/shell/wezterm.sh}" ] && . "$WEZTERM_SHELL_INTEGRATION"
   ```

   - 保存して新しい WezTerm のタブを開くと、rc ファイルから読み込む

PowerShell は追加設定不要。起動引数で自動的に読む。

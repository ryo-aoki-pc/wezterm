# wezterm

個人用の WezTerm 設定（Windows 11 想定 / Tokyo Night 配色）。

## トラブルシューティング

### 操作中（ペイン分割・リサイズ等）に無言でウィンドウが消える

Windows 11 では既定の GPU バックエンド **WebGpu** が、分割/リサイズ時のスワップチェーン
再生成でクラッシュする報告が多い（wezterm
[#4279](https://github.com/wezterm/wezterm/issues/4279) /
[#3229](https://github.com/wezterm/wezterm/issues/3229) /
[#2881](https://github.com/wezterm/wezterm/issues/2881)）。エラー表示も残さず無言で
落ちるのが特徴。本設定では `lua/general.lua` で `config.front_end = "OpenGL"` に
固定して回避している。

それでも落ちる場合は次の順で切り分ける:

1. **半透明 / Acrylic を無効化**: `lua/window.lua` の `enable_acrylic = true` を `false` に。
   Acrylic + 半透明 + RESIZE 装飾は不安定要因になり得る（wezterm
   [#6111](https://github.com/wezterm/wezterm/issues/6111) /
   [#5348](https://github.com/wezterm/wezterm/issues/5348)）。
2. **`max_fps` を下げる**: `lua/general.lua` の `config.max_fps = 120` を `60` に。
3. **バックトレースを採取**: 既存の PowerShell から環境変数付きで起動し stderr を直接見る。

   ```powershell
   $env:RUST_BACKTRACE = "full"
   $env:WEZTERM_LOG    = "wgpu_core=warn,wezterm_gui=info"
   & "C:\Program Files\WezTerm\wezterm-gui.exe"
   ```

   この状態で分割/リサイズを繰り返して再現させ、コンソールの wgpu / panic 出力を確認する。

### アプリ内ログ（Debug Overlay）の開き方

コマンドパレット **`Ctrl+Shift+P` →「Show Debug Overlay」** で開く。
※ 標準の `Ctrl+Shift+L`（ShowDebugOverlay）は本設定でペイン移動に再割当済みのため使えない。

# wezterm

個人用の WezTerm 設定（Windows 11 想定 / Tokyo Night 配色）。

## トラブルシューティング

### Ctrl+Space や 半角/全角 で IME を切り替えた瞬間に落ちる【最有力】

WezTerm 本体の既知バグ。Windows で IME を切り替えると（**特にペイン分割の後**）、
ウィンドウイベント処理の RefCell 二重借用で `RefCell already borrowed` パニックが
発生し、無言でウィンドウが消える（wezterm
[#7632](https://github.com/wezterm/wezterm/issues/7632) /
修正 PR [#7529](https://github.com/wezterm/wezterm/pull/7529)）。
「分割・リサイズ操作の後に落ちる」ように見える症状もこれが原因のことが多い。

**本設定では既定で `config.use_ime = false`**（`lua/general.lua`）にしてこのクラッシュを回避している。
そのぶん **WezTerm 内では IME による日本語入力ができない**ため、必要なときだけ下記で一時的に有効化する。

- **一時的に日本語入力したいとき**: `Ctrl+Shift+I` を押すと、`use_ime=true` を付けた専用ウィンドウが
  別プロセスで開く（`lua/bindings.lua`）。メインのウィンドウは `use_ime=false` のままなので安全。
  日本語入力が済んだらその専用ウィンドウを閉じるだけ。
  - 注意: この専用ウィンドウは `use_ime=true` のため、**安定版では IME 切替時に #7632 でまだ
    落ちる可能性が残る**（落ちてもメインのウィンドウは無事）。完全解消は下記の nightly 更新。
  - `wezterm-gui(.exe)` が PATH に無いと開けない。その場合は `bindings.lua` のパスをフルパスに。
- **恒久対策（推奨）**: 修正 PR [#7529](https://github.com/wezterm/wezterm/pull/7529) は
  **2026-06-07 に upstream へマージ済み**。安定版 20240203 には未収録のため、
  **2026-06-08 以降の nightly ビルドへ更新**すれば IME を常用しても落ちなくなる:
  - <https://github.com/wezterm/wezterm/releases/tag/nightly> から `WezTerm-*-setup.exe` を入れる
  - scoop 利用なら: `scoop bucket add versions` → `scoop install versions/wezterm-nightly`

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

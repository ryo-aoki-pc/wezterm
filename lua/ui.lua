-- 見た目まわりの共有定数（apply は持たないデータモジュール）。
-- tabs.lua / statusbar.lua / general.lua から直接 require する。
local M = {}

-- 丸型のパワーライン区切り（ピル状タブ・バッジ）
-- U+E0B6 = 左半円, U+E0B4 = 右半円（Nerd Font / Powerline Extra）
-- もし端が □（豆腐）で表示される場合はハード区切りに変更:
--   local wezterm = require("wezterm")
--   M.LEFT_CAP  = wezterm.nerdfonts.pl_left_hard_divider
--   M.RIGHT_CAP = wezterm.nerdfonts.pl_right_hard_divider
M.LEFT_CAP = utf8.char(0xe0b6)
M.RIGHT_CAP = utf8.char(0xe0b4)

-- フォント候補（先頭から順に解決される）。
-- HackGen Console NF は日本語 + Nerd Font + Powerline をすべて含むが、
-- 未インストール環境でピルの丸キャップやアイコンが一斉に豆腐化しないよう
-- シンボル用・日本語用のフォールバックを並べておく
M.font_family = {
	"HackGen Console NF",
	"HackGen35 Console NF",
	"Symbols Nerd Font Mono",
	"Noto Sans Mono CJK JP",
	"Noto Sans CJK JP",
}

return M

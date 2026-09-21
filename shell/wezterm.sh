# WezTerm シェル統合 (bash / zsh)
#
#   OSC 7   カレントディレクトリを端末に通知する。
#           → 新しいタブ・分割ペインが「今いるディレクトリ」で開く
#           → タブ名がディレクトリ名になる (lua/tabs.lua の cwd_label)
#   OSC 133 プロンプトの位置を端末に通知する。
#           → Ctrl+Shift+Alt+↑/↓ で前後のプロンプトへジャンプできる
#
# 読み込み方（~/.bashrc に次の 1 行を追記する）:
#
#   [ -n "$WEZTERM_SHELL_INTEGRATION" ] && . "$WEZTERM_SHELL_INTEGRATION"
#
# WEZTERM_SHELL_INTEGRATION はこのファイルへのパスで、lua/shells.lua が
# bash 系シェルを起動するときに環境変数として渡す。

# WezTerm 以外の端末で読み込まれても無害なように何もせず抜ける
[ "$TERM_PROGRAM" = "WezTerm" ] || return 0

# 二重ロード防止（.bashrc が複数回読まれても副作用を重ねない）
[ -n "$__wezterm_integration_loaded" ] && return 0
__wezterm_integration_loaded=1

# OSC 7 でカレントディレクトリを送る。
# Git Bash / MSYS2 の $PWD は "/c/Users/..." 形式で Windows 側から解決できないため、
# cygpath があれば "C:/Users/..." に変換する（WSL / Linux / macOS では変換しない）。
__wezterm_osc7() {
	local __wz_dir=$PWD
	if command -v cygpath >/dev/null 2>&1; then
		__wz_dir=$(cygpath -m "$PWD" 2>/dev/null) || __wz_dir=$PWD
	fi
	# file:// URL に載せるため最低限のパーセントエンコードを行う
	# （% を先に処理しないと後続の置換結果まで壊れる）
	__wz_dir=${__wz_dir//%/%25}
	__wz_dir=${__wz_dir// /%20}
	# "C:/..." には先頭の / が無いので補う（file://host/C:/... が Windows の標準形）
	case $__wz_dir in
	/*) ;;
	*) __wz_dir=/$__wz_dir ;;
	esac
	printf '\033]7;file://%s%s\033\\' "${HOSTNAME:-localhost}" "$__wz_dir"
}

if [ -n "$ZSH_VERSION" ]; then
	# zsh: precmd（プロンプト直前）と preexec（コマンド実行直前）のフックを使う
	__wezterm_precmd() {
		local __wz_status=$?
		printf '\033]133;D;%s\033\\' "$__wz_status"
		__wezterm_osc7
		printf '\033]133;A\033\\'
	}
	__wezterm_preexec() {
		printf '\033]133;C\033\\'
	}
	autoload -Uz add-zsh-hook
	add-zsh-hook precmd __wezterm_precmd
	add-zsh-hook preexec __wezterm_preexec
	return 0
fi

# bash: 直前のコマンドの終了ステータス (D) と cwd (OSC 7) をプロンプトごとに送る。
# PROMPT_COMMAND は PS1 の表示直前に実行されるので、ここが D の送出位置になる。
__wezterm_prompt_command() {
	local __wz_status=$?
	printf '\033]133;D;%s\033\\' "$__wz_status"
	__wezterm_osc7
}

case "$PROMPT_COMMAND" in
*__wezterm_prompt_command*) ;;
"") PROMPT_COMMAND="__wezterm_prompt_command" ;;
*) PROMPT_COMMAND="__wezterm_prompt_command;$PROMPT_COMMAND" ;;
esac

# PS0 はコマンドを読み取ってから実行する直前に展開される = 出力の開始位置 (C)
# ※ PS1 と違い \[ \] で囲まない。あれは readline の幅計算用マーカーで、
#    PS0 ではそのまま制御文字として出力されてしまう
PS0='\033]133;C\033\\'"$PS0"

# PS1 は置き換えず前後に印だけ足す。
# Git Bash の /etc/profile.d/git-prompt.sh が組み立てたブランチ表示付き
# プロンプトをそのまま活かすため、この形を崩さないこと。
# \[ \] で囲むのは「幅ゼロ」と bash に伝えるため（折り返し位置がずれるのを防ぐ）
PS1='\[\033]133;A\033\\\]'"$PS1"'\[\033]133;B\033\\\]'

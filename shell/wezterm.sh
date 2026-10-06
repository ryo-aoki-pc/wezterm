# WezTerm シェル統合 (bash / zsh)
#
#   OSC 7   カレントディレクトリを端末に通知する。
#           → 新しいタブ・分割ペインが「今いるディレクトリ」で開く
#           → タブ名がディレクトリ名になる (lua/tabs.lua の cwd_label)
#   OSC 133 プロンプトと出力の位置を端末に通知する。
#           → Ctrl+Shift+Alt+↑/↓ で前後のプロンプトへジャンプできる
#           → Ctrl+Shift+Alt+C で直前のコマンドの出力をコピーできる
#   OSC 1337 SetUserVar
#           長いコマンドが終わったことを端末に通知する (wezterm_cmd_done)。
#           → 見ていないペインなら完了をトースト通知 (lua/notify.lua)
#           Git Bash / MSYS2 / WSL では、実行を始めたコマンドも通知する (WEZTERM_PROG)。
#           → WezTerm から見えないプログラムでも、タブのアイコン・ssh 中のタブ名・
#             出力コピーの ssh 判定が効く (lua/procs.lua)
#
# あわせて、TUI の終了時に取りこぼされたマウス報告がシェルへ漏れるのを防ぐ
# （下の「迷子のマウス報告よけ」。こちらは WezTerm 以外でも働く）
#
# 読み込み方（~/.bashrc に次の 1 行を追記する）:
#
#   [ -r "${WEZTERM_SHELL_INTEGRATION:=$HOME/.config/wezterm/shell/wezterm.sh}" ] && . "$WEZTERM_SHELL_INTEGRATION"
#
# WEZTERM_SHELL_INTEGRATION はこのファイルへのパスで、lua/shells.lua が
# bash 系シェルを起動するときに環境変数として渡す。tmux や ssh を挟むと変数が
# 届かないので、既定の配置先へのフォールバックを付けてある。
#
# ※ set -u（zsh は setopt nounset）のシェルでも読めるよう、未設定かもしれない変数は
#   ${変数-} の形で参照する

# --- 迷子のマウス報告よけ ---------------------------------------------------
# TUI (lazygit など) は起動時にマウス報告を有効化し (DECSET 1003 = 移動も含む全
# イベント / 1006 = SGR 形式)、終了時に解除する。ところが解除が端末へ届く前に
# 端末が出してしまった報告は行き場を失い、戻ってきたシェルに
# ^[[<35;33;72M のような文字列として現れる。
#   - プロンプト表示前に届くと端末がそのまま echo する（表示が汚れるだけ）
#   - readline 起動後に届くと "35: command not found" のようにコマンド行を壊す
# ※ WezTerm 固有の話ではなく tmux / ssh 越しでも起きる。tmux 配下では
#   TERM_PROGRAM が "tmux" になり下の判定で抜けてしまうため、判定より前に置く
# ※ このファイルは何度読まれてもよい（関数は定義し直し、フックは無いときだけ足す）。
#   .bashrc を読み直して PROMPT_COMMAND や PS1 が作り直されても、そこで足し直される

# プロンプトに戻った時点でマウス報告を欲しがるものは居ないので毎回送ってよい。
# 解除され損ねてトラッキングが残っている場合の回復もこれが担う。
# ※ 直前のコマンドの終了ステータスは後続フック（OSC 133 の D）のために保つ
__wz_mouse_off() {
	local __wz_st=$?
	printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?1015l'
	return $__wz_st
}

if [ -n "${BASH_VERSION-}" ]; then
	# 公式統合などが用意した bash-preexec は、dispatcher の先頭で終了コードと
	# BP_PIPESTATUS を保存する。その前に自分のフックを入れない。
	__wz_bash_preexec_active() {
		[ -n "${bash_preexec_imported-}${__bp_imported-}" ] &&
			declare -F __bp_precmd_invoke_cmd >/dev/null || return 1
		local __wz_pc
		for __wz_pc in "${PROMPT_COMMAND[@]-}"; do
			case $__wz_pc in *'__bp_precmd_invoke_cmd'* | *'__bp_install'*) return 0 ;; esac
		done
		return 1
	}

	# Starship は precmd の最初に $? と PIPESTATUS を保存する。先にこちらの
	# 関数を呼ぶとパイプの各終了コードが消えるため、フックはその後ろに置く。
	__wz_starship_active() {
		[ "${STARSHIP_SHELL-}" = bash ] || return 1
		declare -F starship_precmd >/dev/null || return 1
		local __wz_pc
		for __wz_pc in "${PROMPT_COMMAND[@]-}"; do
			case $__wz_pc in *starship_precmd*) return 0 ;; esac
		done
		if __wz_bash_preexec_active; then
			for __wz_pc in "${precmd_functions[@]-}"; do
				[ "$__wz_pc" = starship_precmd ] && return 0
			done
		fi
		return 1
	}

	# 前の版が先頭に付けた自分のフックだけを外す。ユーザーのコードを
	# セミコロンで分割したり、文字列の途中を置換したりしない。
	__wz_strip_prompt_prefixes() {
		__wz_prompt_code=$1
		local __wz_dispatcher=
		while :; do
			case $__wz_prompt_code in
			__wezterm_prompt_command | __wz_mouse_off) __wz_prompt_code=; break ;;
			__wezterm_prompt_command\;*) __wz_prompt_code=${__wz_prompt_code#__wezterm_prompt_command;} ;;
			__wz_mouse_off\;*) __wz_prompt_code=${__wz_prompt_code#__wz_mouse_off;} ;;
			__wezterm_prompt_command$'\n'*) __wz_prompt_code=${__wz_prompt_code#__wezterm_prompt_command$'\n'} ;;
			__wz_mouse_off$'\n'*) __wz_prompt_code=${__wz_prompt_code#__wz_mouse_off$'\n'} ;;
			__bp_precmd_invoke_cmd$'\n'*)
				# 初回の __bp_install が旧版の先頭フックを dispatcher の後ろへ移す。
				# この既知の形だけ扱い、任意のユーザーコードは分割しない。
				[ -z "$__wz_dispatcher" ] || break
				__wz_dispatcher=$'__bp_precmd_invoke_cmd\n'
				__wz_prompt_code=${__wz_prompt_code#$'__bp_precmd_invoke_cmd\n'}
				;;
			*) break ;;
			esac
		done
		while :; do
			case $__wz_prompt_code in
			*$'\n'__wezterm_prompt_command) __wz_prompt_code=${__wz_prompt_code%$'\n'__wezterm_prompt_command} ;;
			*$'\n'__wz_mouse_off) __wz_prompt_code=${__wz_prompt_code%$'\n'__wz_mouse_off} ;;
			*) break ;;
			esac
		done
		__wz_prompt_code=$__wz_dispatcher$__wz_prompt_code
	}
	if __wz_starship_active || __wz_bash_preexec_active; then
		__wz_prompt_commands=()
		for __wz_pc_code in "${PROMPT_COMMAND[@]-}"; do
			__wz_strip_prompt_prefixes "$__wz_pc_code"
			[ -n "$__wz_prompt_code" ] && __wz_prompt_commands+=("$__wz_prompt_code")
		done
		# 自分の単独フックを除いた空要素は残さない。先頭が空だと Starship の
		# 再初期化が「未登録」と判断し、starship_precmd をもう一つ足してしまう。
		# スカラーのコードも 1 要素として保持する（末尾コメント等を壊さない）。
		PROMPT_COMMAND=("${__wz_prompt_commands[@]}")
		# 統合を先に読んだ古い .bashrc からの復旧。Starship が退避した
		# 自分のフックを外してから、以下で PROMPT_COMMAND の後ろに付け直す。
		if [ -n "${STARSHIP_PROMPT_COMMAND-}" ]; then
			__wz_strip_prompt_prefixes "$STARSHIP_PROMPT_COMMAND"
			STARSHIP_PROMPT_COMMAND=$__wz_prompt_code
		fi
		unset __wz_pc_code __wz_prompt_code __wz_prompt_commands
	fi
	if __wz_bash_preexec_active && __wz_starship_active; then
		# Starship の bash-preexec 経路は再 init のたびに同じ関数を append する。
		# 統合を読み直したときは最初の登録だけ残し、他の関数の順序を保つ。
		__wz_prompt_commands=() __wz_starship_seen=
		for __wz_pc_code in "${precmd_functions[@]-}"; do
			if [ "$__wz_pc_code" = starship_precmd ]; then
				[ -z "$__wz_starship_seen" ] || continue
				__wz_starship_seen=1
			fi
			__wz_prompt_commands+=("$__wz_pc_code")
		done
		precmd_functions=("${__wz_prompt_commands[@]}")
		__wz_prompt_commands=() __wz_starship_seen=
		for __wz_pc_code in "${preexec_functions[@]-}"; do
			if [ "$__wz_pc_code" = starship_preexec_all ]; then
				[ -z "$__wz_starship_seen" ] || continue
				__wz_starship_seen=1
			fi
			__wz_prompt_commands+=("$__wz_pc_code")
		done
		preexec_functions=("${__wz_prompt_commands[@]}")
		unset __wz_pc_code __wz_prompt_commands __wz_starship_seen
	fi

	# 配列なら全要素を調べ、既存フックを重ねない。既存のコードと配列の
	# 順番は保ち、Starship があるときは末尾、ないときは先頭に加える。
	__wz_add_prompt_hook() {
		local __wz_hook=$1 __wz_pc __wz_decl
		for __wz_pc in "${PROMPT_COMMAND[@]-}"; do
			case ";${__wz_pc//$'\n'/;};" in *";$__wz_hook;"*) return 0 ;; esac
		done
		__wz_decl=$(declare -p PROMPT_COMMAND 2>/dev/null) || __wz_decl=
		if __wz_bash_preexec_active; then
			local __wz_has_mode= __wz_hooks=()
			for __wz_pc in "${PROMPT_COMMAND[@]-}"; do
				if [ "$__wz_pc" = __bp_interactive_mode ] && [ -z "$__wz_has_mode" ]; then
					__wz_hooks+=("$__wz_hook")
					__wz_has_mode=1
				fi
				__wz_hooks+=("$__wz_pc")
			done
			if [ -n "$__wz_has_mode" ]; then
				# interactive_mode の直前に入れ、途中の既存 PC 要素も温存する。
				# その後に置くと DEBUG trap が mode を消し、次の preexec が動かない。
				PROMPT_COMMAND=("${__wz_hooks[@]}")
			else
				# 初回 install 前は scalar の末尾へ足す。__bp_install 自身が
				# dispatcher の後、interactive_mode の前へ移してくれる。
				# 改行で足し、既存コードの末尾コメントを壊さない。
				PROMPT_COMMAND[0]="${PROMPT_COMMAND[0]-}${PROMPT_COMMAND[0]:+$'\n'}$__wz_hook"
			fi
		elif __wz_starship_active; then
			case $__wz_decl in
			'declare -a'*) PROMPT_COMMAND+=("$__wz_hook") ;;
			*) PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}$__wz_hook" ;;
			esac
		else
			case $__wz_decl in
			'declare -a'*) PROMPT_COMMAND=("$__wz_hook" "${PROMPT_COMMAND[@]}") ;;
			*) PROMPT_COMMAND="$__wz_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
			esac
		fi
	}
	case $- in
	*i*)
		# readline に \e[< を食わせ、終端の M / m まで読み捨てる。
		# 終端が来なくても -t で抜けるのでハングしない
		__wz_eat_mouse_report() {
			local c
			while IFS= read -rsn1 -t 0.05 c 2>/dev/null; do
				case $c in [Mm]) break ;; esac
			done
		}
		bind -x '"\e[<": __wz_eat_mouse_report' 2>/dev/null
		;;
	esac

	__wz_add_prompt_hook __wz_mouse_off
elif [ -n "${ZSH_VERSION-}" ]; then
	case $- in
	*i*)
		# zsh も同じく、ZLE に \e[< を食わせて終端の M / m まで読み捨てる（read -k は
		# ウィジェットの中では端末から読む）。後から vi モードに切り替えても効くよう、
		# 主なキーマップすべてに割り当てる
		__wz_eat_mouse_report() {
			local c
			while read -rs -k 1 -t 0.05 c 2>/dev/null; do
				case $c in [Mm]) break ;; esac
			done
		}
		zle -N __wz_eat_mouse_report
		bindkey -M emacs '\e[<' __wz_eat_mouse_report
		bindkey -M viins '\e[<' __wz_eat_mouse_report
		bindkey -M vicmd '\e[<' __wz_eat_mouse_report
		;;
	esac

	autoload -Uz add-zsh-hook
	add-zsh-hook precmd __wz_mouse_off
fi

# 公式の bash 統合は Starship より先に PS1 を包み、後で入力開始の印が消える。
# bash-preexec の状態保存・cwd・ユーザー変数は温存し、semantic の担当だけ
# 下の独自処理へ移す。公式関数の定義は上書きしない。
__wz_official_bash=
if command -v __wezterm_set_user_var >/dev/null 2>&1; then
	if [ -n "${BASH_VERSION-}" ] && __wz_bash_preexec_active &&
		[ -z "${BLE_VERSION-}${TMUX-}${WEZTERM_SHELL_SKIP_SEMANTIC_ZONES-}" ] &&
		[ "${TERM_PROGRAM-}" != tmux ]; then
		__wz_official_bash=1
		__wz_functions=()
		for __wz_fn in "${precmd_functions[@]-}"; do
			[ "$__wz_fn" = __wezterm_semantic_precmd ] || __wz_functions+=("$__wz_fn")
		done
		precmd_functions=("${__wz_functions[@]}")
		__wz_functions=()
		for __wz_fn in "${preexec_functions[@]-}"; do
			[ "$__wz_fn" = __wezterm_semantic_preexec ] || __wz_functions+=("$__wz_fn")
		done
		preexec_functions=("${__wz_functions[@]}")
		unset __wz_functions __wz_fn
		# 稼働中の公式プロンプトから移行する場合だけ、保存された元の値へ戻す。
		if [ -n "${__wezterm_save_ps1+set}" ] && [ "${PS1-}" = "${__wezterm_check_ps1-}" ]; then
			PS1=$__wezterm_save_ps1
			PS2=${__wezterm_save_ps2-}
		fi
		# 公式 user-vars はこの変数を未設定のまま参照するので nounset を補う。
		: "${WEZTERM_HOSTNAME:=}"
	else
		# zsh / ble.sh / tmux と semantic を明示的に無効化した環境は公式へ任せる。
		return 0
	fi
fi

# SSH では TERM_PROGRAM が届かなくても、既に有効な公式 bash 統合を補完する。
[ "${TERM_PROGRAM-}" = "WezTerm" ] || [ -n "$__wz_official_bash" ] || return 0

# 読み込んだ印（確かめる用。何度読まれてもフックや印は重ならないので、ここでは抜けない）
__wezterm_integration_loaded=1

# 実行中のコマンドをユーザー変数 WEZTERM_PROG で送るか。WezTerm がシェルの子プロセスを
# 見られない環境だけ送る（lua/procs.lua がタブのアイコン・名前と ssh の判定に使う）:
#   Git Bash / MSYS2 / Cygwin  起動したプログラムは Windows 上で親プロセスが消えるので、
#                              vim でも ssh でも WezTerm からは bash.exe に見える
#                              （Git Bash 5.3 の $OSTYPE は msys ではなく cygwin）
#   WSL                        中のプロセスは Windows 側の WezTerm から見えない
# ほかの OS は WezTerm が自分で調べられるので送らない（コマンドごとの手間を省き、
# ssh 先でこの統合が動いているときに、そこから届く値で手元の値を上書きしないため）
__wz_send_prog=
case $OSTYPE in
msys* | cygwin*) __wz_send_prog=1 ;;
*) [ -n "${WSL_DISTRO_NAME-}" ] && __wz_send_prog=1 ;;
esac

# OSC 7 でカレントディレクトリを送る。
# Git Bash / MSYS2 の $PWD は "/c/Users/..." 形式で Windows 側から解決できないため、
# cygpath があれば "C:/Users/..." に変換する（WSL / Linux / macOS では変換しない）。
# 変換とエンコードはディレクトリが変わったときだけ行い、結果（__wz_osc7_path）を使い回す
# （Git Bash では cygpath の起動に 1 回 40ms ほどかかり、プロンプトごとだと待たされる）
__wz_osc7() {
	if [ "$PWD" != "${__wz_osc7_pwd-}" ]; then
		__wz_osc7_pwd=$PWD
		local __wz_dir=$PWD
		if command -v cygpath >/dev/null 2>&1; then
			__wz_dir=$(cygpath -m "$PWD" 2>/dev/null) || __wz_dir=$PWD
		fi
		# file:// URL に載せるため、URL で意味を持つ文字をパーセントエンコードする
		# （% を先に処理しないと後続の置換結果まで壊れる）。WezTerm は URL として読むので、
		# # と ? をそのまま送るとそこから後ろを捨て、\ は / とみなす（パスが変わり、タブ名が
		# ずれて、新しいタブがホームで開く）。ASCII 以外の文字はそのまま送ってよい
		# ※ パターンの % # ? \ は \ で文字として扱う。zsh では先頭の % が「末尾に一致」、
		#   bash では先頭の # が「先頭に一致」の意味になり、? はどの 1 文字にも一致する
		__wz_dir=${__wz_dir//\%/%25}
		__wz_dir=${__wz_dir// /%20}
		__wz_dir=${__wz_dir//\#/%23}
		__wz_dir=${__wz_dir//\?/%3F}
		__wz_dir=${__wz_dir//\\/%5C}
		# "C:/..." には先頭の / が無いので補う（file://host/C:/... が Windows の標準形）
		case $__wz_dir in
		/*) ;;
		*) __wz_dir=/$__wz_dir ;;
		esac
		__wz_osc7_path=$__wz_dir
	fi
	# ホスト名は bash が $HOSTNAME、zsh が $HOST に持つ（lua/tabs.lua が自分のホスト名と
	# 比べて、違えば ssh 先とみなす）
	printf '\033]7;file://%s%s\033\\' "${HOSTNAME:-${HOST:-localhost}}" "$__wz_osc7_path"
}

# 経過秒 $1 が完了通知のしきい値（WEZTERM_NOTIFY_AFTER 秒。既定 10）以上か
__wezterm_long() {
	[ "$1" -ge "${WEZTERM_NOTIFY_AFTER:-10}" ] 2>/dev/null
}

# 長いコマンドの完了通知。「終了コード<TAB>経過秒<TAB>コマンド」をユーザー変数
# wezterm_cmd_done で端末へ送る（しきい値の判定は呼び出し側の __wezterm_long）。
# 通知を出すかどうか（見ていないペインのときだけ出す）は lua/notify.lua が決める。
# コマンドが分からないときは空で送る（通知は経過時間だけになる）
# 引数: $1 = 終了コード, $2 = 経過秒, $3 = コマンド
__wezterm_notify_done() {
	__wezterm_uservar wezterm_cmd_done "$1"$'\t'"$2"$'\t'"$3"
}

if [ -n "${ZSH_VERSION-}" ]; then
	# zsh: precmd（プロンプト直前）と preexec（コマンド実行直前）のフックを使う
	# ※ このブロックは bash にも解析されるので、bash でも通る書き方にしておく

	# ユーザー変数を送る（OSC 1337 SetUserVar。値は base64 で送る決まりで、WezTerm 側で
	# 復号される）。値は先頭 200 文字まで。空の値（WEZTERM_PROG を消すとき）は base64 を呼ばない
	# 引数: $1 = 名前, $2 = 値
	__wezterm_uservar() {
		local __wz_v=
		if [ -n "$2" ]; then
			command -v base64 >/dev/null 2>&1 || return 0
			__wz_v=$(printf '%s' "${2:0:200}" | base64 | tr -d '\r\n')
		fi
		printf '\033]1337;SetUserVar=%s=%s\033\\' "$1" "$__wz_v"
	}

	# 入力の開始 (OSC 133 B) の印。プロンプトの末尾に付ける。%{ %} は「幅ゼロ」と zsh に
	# 伝える（折り返し位置がずれるのを防ぐ）。終端は BEL（プロンプト展開で \ を扱わずに済む）
	__wz_mark_b=$'%{\e]133;B\a%}'

	__wezterm_precmd() {
		local __wz_status=$?
		printf '\033]133;D;%s\033\\' "$__wz_status"
		if [ -n "${__wz_cmd_start-}" ]; then
			# 実行中のコマンドの知らせ (WEZTERM_PROG) を消す
			[ -n "$__wz_send_prog" ] && __wezterm_uservar WEZTERM_PROG ""
			# typeset -F SECONDS で小数になっていても整数秒にそろえる
			local -i __wz_elapsed=$((SECONDS - __wz_cmd_start))
			__wezterm_long "$__wz_elapsed" &&
				__wezterm_notify_done "$__wz_status" "$__wz_elapsed" "$__wz_cmd"
			unset __wz_cmd_start __wz_cmd
		fi
		__wz_osc7
		printf '\033]133;A\033\\'
		# 入力の開始 (B) が無ければ付ける。テーマがプロンプトを毎回作り直しても付け直せるよう、
		# プロンプトごとに確かめる（B が無いと入力の範囲ができず、直前の出力をコピーできない）
		[[ $PS1 == *"$__wz_mark_b"* ]] || PS1=$PS1$__wz_mark_b
		return $__wz_status
	}
	__wezterm_preexec() {
		# 完了通知用に開始時刻とコマンド文字列を覚える（空行では preexec は呼ばれない）。
		# $1 は履歴に残さないコマンド（HIST_IGNORE_SPACE など）でも入力どおりに渡される
		__wz_cmd_start=$SECONDS
		__wz_cmd=$1
		[ -n "$__wz_send_prog" ] && __wezterm_uservar WEZTERM_PROG "$1"
		printf '\033]133;C\033\\'
	}
	autoload -Uz add-zsh-hook
	add-zsh-hook precmd __wezterm_precmd
	add-zsh-hook preexec __wezterm_preexec
	return 0
fi

# ---- ここから bash（zsh は上の return で抜けるので、ここより下は実行しない） ----

# SetUserVar の値（base64）を bash だけで作り、__wz_b64 に入れる。Git Bash では外部の
# base64 を呼ぶと 1 回 50ms ほどかかり、コマンドごとに送る WEZTERM_PROG では待たされるため。
# LC_ALL=C で 1 バイトずつ数値にし、3 バイト → 4 文字に変換する（printf %d "'c" は
# 0x80 以上を負の値にすることがあるので & 255 でそろえる）
# ※ 部分文字列の位置は $i のように $ を付けて書く（zsh -n でこのファイルを検査したとき、
#   ${s:i:1} の :i が zsh の修飾子と解釈されるのを避ける）
__wezterm_b64() {
	local LC_ALL=C
	local s=$1 t=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/
	local i n=${#s} a b c v
	__wz_b64=
	for ((i = 0; i < n; i += 3)); do
		printf -v a %d "'${s:$i:1}"
		b=0 c=0
		((i + 1 < n)) && printf -v b %d "'${s:$((i + 1)):1}"
		((i + 2 < n)) && printf -v c %d "'${s:$((i + 2)):1}"
		((v = (a & 255) << 16 | (b & 255) << 8 | (c & 255)))
		__wz_b64+=${t:$((v >> 18 & 63)):1}${t:$((v >> 12 & 63)):1}
		if ((i + 1 < n)); then __wz_b64+=${t:$((v >> 6 & 63)):1}; else __wz_b64+='='; fi
		if ((i + 2 < n)); then __wz_b64+=${t:$((v & 63)):1}; else __wz_b64+='='; fi
	done
}

# ユーザー変数を送る（OSC 1337 SetUserVar）。値は先頭 200 文字まで（貼り付けた長い
# コマンドでも変換の手間と送る量を抑える）。Git Bash は絵文字を UTF-16 の
# 2 単位として数えるので、境界で切れた上位サロゲートは落としてから送る。
# 引数: $1 = 名前, $2 = 値
__wezterm_uservar() {
	local __wz_value=${2:0:200} __wz_tail
	if ((${#2} > 200)); then
		printf -v __wz_tail %d "'${__wz_value: -1}"
		if ((__wz_tail >= 0xD800 && __wz_tail <= 0xDBFF)); then
			__wz_value=${__wz_value:0:199}
		fi
	fi
	__wezterm_b64 "$__wz_value"
	printf '\033]1337;SetUserVar=%s=%s\033\\' "$1" "$__wz_b64"
}

# 履歴の最後の 1 件を __wz_h に入れる。bash 5.3 以降は ${ …; }（今のシェルのまま出力を
# 受け取る）で fork を避ける（Git Bash では $(…) が 1 回約 10ms かかる）。古い bash には
# 見せたくない構文なので、文字列にして eval で定義する。PS0 から WEZTERM_PROG を送る
# 呼び方も同じ理由で分ける
if ((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] >= 503)); then
	eval '__wezterm_hist1() { __wz_h=${ HISTTIMEFORMAT= builtin history 1; }; }'
	__wz_ps0_prog='${ __wezterm_ps0; }'
else
	__wezterm_hist1() { __wz_h=$(HISTTIMEFORMAT= builtin history 1); }
	__wz_ps0_prog='$(__wezterm_ps0)'
fi

# 実行した（実行を始める）コマンドを履歴の最後の 1 件から取り、__wz_last に入れる。
# "  123  sleep 20" の番号と、その後ろの 2 文字（空白 2 つ。編集した履歴なら "* "）を外す。
# ※ fc -ln -1 は使えない: PROMPT_COMMAND から呼ぶと「最後の履歴は fc 自身」とみなして
#   1 件飛ばすため、1 つ前のコマンドが返る
# ※ [[ =~ ]] は使わない: PS0 からも呼ぶので、ユーザーの BASH_REMATCH を毎回上書きしてしまう
__wezterm_last_cmd() {
	local __wz_h
	__wezterm_hist1
	__wz_h=${__wz_h#"${__wz_h%%[![:space:]]*}"}
	__wz_h=${__wz_h#"${__wz_h%%[!0-9]*}"}
	__wz_last=${__wz_h:2}
}

# 履歴の最後の 1 件が「今のコマンド」か。
# HISTCMD（次の履歴番号）が前のプロンプトのときより進んでいれば、今のコマンドが履歴に入った。
# 進んでいないのは (1) 同じコマンドの繰り返し（ignoredups / erasedups。最後の 1 件は今の
# コマンドと同じ）か、(2) 履歴に残さないコマンド（ignorespace / ignoreboth での先頭の空白・
# HISTIGNORE・set +o history。最後の 1 件は前のコマンド）。(2) の設定が無ければ (1) なので
# 使ってよい。あれば見分けられないので使わない（1 つ前のコマンド名を出すより、出さないほうがよい）
__wezterm_hist_ok() {
	((HISTCMD > ${__wz_hist_prompt:-0})) && return 0
	[[ -o history && -z ${HISTIGNORE-} && ${HISTCONTROL-} != *ignorespace* && ${HISTCONTROL-} != *ignoreboth* ]]
}

# PS0（コマンドの実行直前）から呼ぶ: 実行を始めるコマンドをユーザー変数 WEZTERM_PROG で送る。
# 名前は WezTerm 公式のシェル統合と同じ（向こうが読み込まれた環境でも Lua 側はそのまま動く）
__wezterm_ps0() {
	__wezterm_hist_ok || return 0
	__wezterm_last_cmd
	__wezterm_uservar WEZTERM_PROG "$__wz_last"
}

# bash: 直前のコマンドの終了ステータス (D) と cwd (OSC 7) をプロンプトごとに送る。
# PROMPT_COMMAND は PS1 の表示直前に実行されるので、ここが D の送出位置になる。
# 最後に $? を元の値で返す（後ろに並ぶ __wz_mouse_off・zoxide などのフックのため）
__wezterm_prompt_command() {
	local __wz_status=$?
	# Starship が先に動く構成では、後続フックの $? ではなく保存済みの値を使う。
	# 検出を毎回行い、Starship を使わなくなったシェルの古い値は参照しない。
	if __wz_bash_preexec_active; then
		__wz_status=${__bp_last_ret_value:-$__wz_status}
	elif __wz_starship_active; then
		__wz_status=${STARSHIP_CMD_STATUS:-$__wz_status}
	fi
	printf '\033]133;D;%s\033\\' "$__wz_status"
	# __wz_cmd_start は下の PS0 がコマンド実行直前に入れる。空 Enter では PS0 が
	# 展開されないので未設定のまま = コマンドは走っていない
	if [ -n "${__wz_cmd_start-}" ]; then
		# 実行中のコマンドの知らせ (WEZTERM_PROG) を消す
		[ -n "$__wz_send_prog" ] && __wezterm_uservar WEZTERM_PROG ""
		local __wz_elapsed=$((SECONDS - __wz_cmd_start))
		# コマンド名は通知するときだけ履歴から読む（コマンドごとにサブシェルを作らない）
		if __wezterm_long "$__wz_elapsed"; then
			__wz_last=
			__wezterm_hist_ok && __wezterm_last_cmd
			__wezterm_notify_done "$__wz_status" "$__wz_elapsed" "$__wz_last"
		fi
		unset __wz_cmd_start
	fi
	# 次のコマンドが履歴に入ったかを見分ける基準（__wezterm_hist_ok）
	__wz_hist_prompt=$HISTCMD
	[ -n "$__wz_official_bash" ] || __wz_osc7
	# Starship が毎回 PS1 を作り直した後に、プロンプト・入力の印を付け直す。
	__wezterm_mark_prompt
	return "$__wz_status"
}

__wz_add_prompt_hook __wezterm_prompt_command

# PS0 はコマンドを読み取ってから実行する直前に展開される = 出力の開始位置 (C)
# ※ PS1 と違い \[ \] で囲まない。あれは readline の幅計算用マーカーで、
#    PS0 ではそのまま制御文字として出力されてしまう
# 先頭の ${PS1:0:$((…,0))} は完了通知用に開始時刻を __wz_cmd_start へ入れる。
# 算術展開はこのシェル自身で評価されるので代入が残り、「PS1 の先頭 0 文字」= 空文字に
# 展開されるので画面には何も出ない（$(...) はサブシェルになるため代入が残らず使えない）
# 続く __wz_ps0_prog は WEZTERM_PROG の送出（__wz_send_prog のときだけ）。bash 5.3 の
# ${ …; } は今のシェルで動くが、$? / $_ / PIPESTATUS は bash が元に戻すので、
# これから実行するコマンドには影響しない
# 印は BEL（\007）で終える。ESC \ で終えると、後ろに続く元の PS0 の先頭の $ が
# その \ でエスケープされ、starship の ${STARSHIP_START_TIME:…} などが文字のまま画面に出る
# （bash は PS0 の \\ を \ にしてから $ の展開をする。PS1 も、行編集が無いとき
#   （bash --noediting・set +o emacs +o vi）は \] が消え、元の PS1 の先頭の $ で同じことが起きる）
# PS0・PS1 とも、印が既にあれば足さない（何度読まれても重ねない）
case ${PS0-} in
*'133;C'*) ;;
*) PS0='${PS1:0:$((__wz_cmd_start=SECONDS,0))}'"${__wz_send_prog:+$__wz_ps0_prog}"'\033]133;C\007'"${PS0-}" ;;
esac
unset __wz_ps0_prog

# PS1 は置き換えず前後に印だけ足す。プロンプトごとに呼び、テーマが PS1 を
# 作り直した場合も復帰する。既にある印は重ねない。
# Git Bash の /etc/profile.d/git-prompt.sh が組み立てたブランチ表示付き
# プロンプトをそのまま活かすため、この形を崩さないこと。
# \[ \] で囲むのは「幅ゼロ」と bash に伝えるため（折り返し位置がずれるのを防ぐ）
__wezterm_mark_prompt() {
	case ${PS1-} in
	*'133;A'*) ;;
	*) PS1='\[\033]133;A\007\]'"${PS1-}" ;;
	esac
	case ${PS1-} in
	*'133;B'*) ;;
	*) PS1=${PS1-}'\[\033]133;B\007\]' ;;
	esac
	if [ -n "$__wz_official_bash" ]; then
		# 公式から引き継いだ複数行入力の継続プロンプトも区切る。
		case ${PS2-} in
		*'133;P;k=s'*) ;;
		*) PS2='\[\033]133;P;k=s\007\]'"${PS2-}" ;;
		esac
		case ${PS2-} in
		*'133;B'*) ;;
		*) PS2=${PS2-}'\[\033]133;B\007\]' ;;
		esac
	fi
}
__wezterm_mark_prompt

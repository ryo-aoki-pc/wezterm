# 状態保存より前にフックを置いた場合の影響を、最小の bash-preexec 風 stub で診断する。
# Starship は実体を使うが、公式 bash-preexec の __bp_install・DEBUG trap・初回の
# PROMPT_COMMAND 再構成は再現しない。SSH 通信も行わない。実機の障害再現ではない。
# 実機 kawasaki-pi の公式統合は初回 __bp_install が既存フックを状態保存の後ろへ移す。
# その通常ログインでは STARSHIP_PIPE_STATUS / BP_PIPESTATUS が 1 0 を保持していた。
export PATH="/usr/bin:/bin:$PATH"
export TERM_PROGRAM=WezTerm TERM=xterm-256color COLUMNS=80
export STARSHIP_CONFIG="$PWD/tests/starship/bash-pipeline.toml"
STARSHIP_CACHE="$PWD/tests/starship/ssh-results/preexec-cache"
export STARSHIP_CACHE

bash_preexec_imported=defined
precmd_functions=()
preexec_functions=()
__wezterm_set_user_var() { :; }
__bp_set_ret_value() { return "$1"; }
__bp_precmd_invoke_cmd() {
	__bp_last_ret_value=$? BP_PIPESTATUS=("${PIPESTATUS[@]}")
	local callback
	for callback in "${precmd_functions[@]}"; do
		__bp_set_ret_value "$__bp_last_ret_value"
		"$callback"
	done
	__bp_set_ret_value "$__bp_last_ret_value"
}
PROMPT_COMMAND=__bp_precmd_invoke_cmd
eval "$(starship init bash)"

# 追加統合が無い場合、Starship は保存済みのパイプの全要素を使う。
false | true
__bp_precmd_invoke_cmd
printf 'BASELINE_PIPE=%s\n' "${STARSHIP_PIPE_STATUS[*]}"

. "$PWD/shell/wezterm.sh"
printf 'PROMPT_COMMAND=%s\n' "${PROMPT_COMMAND[*]}"
printf 'PRECMD_FUNCTIONS=%s\n' "${precmd_functions[*]}"

# stub の PROMPT_COMMAND を対話シェルに任せ、外側 eval による PIPESTATUS 破壊を避ける。
# 入力は runner から与える。

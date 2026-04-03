# Auto-source project env when entering a repo that has scripts/dev/env.sh.

_quinlan_auto_env() {
    # Re-entrancy guard: env.sh may cd, which triggers chpwd, which calls us again.
    [[ -n "${_QUINLAN_AUTO_ENV_RUNNING:-}" ]] && return
    _QUINLAN_AUTO_ENV_RUNNING=1

    local dir="$PWD"

    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/scripts/dev/env.sh" ]]; then
            if [[ "${_QUINLAN_ENV_ROOT:-}" != "$dir" ]]; then
                # shellcheck source=/dev/null
                source "$dir/scripts/dev/env.sh"
            fi
            unset _QUINLAN_AUTO_ENV_RUNNING
            return
        fi
        dir="$(dirname "$dir")"
    done

    unset _QUINLAN_AUTO_ENV_RUNNING
}

# Tell the terminal the shell's real CWD via OSC 7. On Windows (WezTerm),
# this prevents tab titles showing child-process CWDs like dist/. On macOS
# (Ghostty), this enables Cmd+T to open new tabs in the current directory.
_quinlan_osc7_cwd() {
    local uri
    case "$OSTYPE" in
        msys*|cygwin*)
            # cygpath converts POSIX paths to Windows mixed-mode for WezTerm.
            command -v cygpath >/dev/null 2>&1 || return
            uri="file:///$(cygpath -m "$PWD")"
            ;;
        *)
            # macOS / Linux: standard file URI with hostname.
            uri="file://$(hostname)$PWD"
            ;;
    esac

    printf '\e]7;%s\e\\' "$uri"

    # Inside tmux, the above is intercepted for #{pane_current_path} and not
    # forwarded to the outer terminal. Send again via DCS passthrough so
    # Ghostty receives it — needed for Cmd+T new-tab CWD inheritance.
    [[ -n "${TMUX:-}" ]] && printf '\ePtmux;\e\e]7;%s\e\e\\\e\\' "$uri"
}

# Disable focus reporting (CSI ?1004) to prevent bell storms.
# Claude Code enables focus reporting via ANSI sequences but doesn't always
# clean up on exit (#17010). WezTerm then sends focus-in/out events that some
# programs interpret as input, causing spurious BEL characters.
_quinlan_reset_focus_reporting() {
    printf '\e[?1004l'
}

if [[ -n "${ZSH_VERSION:-}" ]]; then
    autoload -Uz add-zsh-hook 2>/dev/null || true
    if [[ -z "${_QUINLAN_AUTO_ENV_ZSH_REGISTERED:-}" ]]; then
        # chpwd makes repo entry immediate; precmd is the safety net that matches
        # bash's prompt-driven refresh if the working tree changes underneath us.
        add-zsh-hook chpwd _quinlan_auto_env
        add-zsh-hook precmd _quinlan_reset_focus_reporting
        add-zsh-hook precmd _quinlan_osc7_cwd
        add-zsh-hook precmd _quinlan_auto_env
        _QUINLAN_AUTO_ENV_ZSH_REGISTERED=1
    fi
elif [[ "${PROMPT_COMMAND:-}" != *"_quinlan_auto_env"* ]]; then
    PROMPT_COMMAND="_quinlan_reset_focus_reporting;_quinlan_osc7_cwd;_quinlan_auto_env${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

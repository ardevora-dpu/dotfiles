# Claude Code entrypoint used by both Timon and Jeremy.
#
# Prompt file convention: .claude-init-prompt at the git root is read
# as a positional prompt arg (`claude "prompt"`) which starts an
# interactive session with that message pre-sent. File is deleted
# after reading. Used by /start-session.

_quinlan_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

_quinlan_repo_runtime_script() {
    local root="$1"
    printf '%s/scripts/dev/shell-runtime.sh' "$root"
}

_quinlan_load_repo_runtime() {
    local root="$1" script

    if [[ -z "$root" ]]; then
        return 1
    fi

    script="$(_quinlan_repo_runtime_script "$root")"
    if [[ ! -f "$script" ]]; then
        return 1
    fi

    # shellcheck disable=SC1090
    source "$script"
}

_quinlan_cc_fallback() {
    local root="$1"
    shift 1

    if [[ -n "$root" && "$PWD" != "$root" ]]; then
        claude --add-dir "$root" -- "$@"
    else
        claude "$@"
    fi
}

cc() {
    local root prompt

    root="$(_quinlan_repo_root)" || root=""

    if _quinlan_load_repo_runtime "$root" && declare -F _quinlan_runtime_cc >/dev/null 2>&1; then
        _quinlan_runtime_cc "$@"
        return
    fi

    if [[ -n "$root" && -f "$root/.claude-init-prompt" ]]; then
        prompt="$(cat "$root/.claude-init-prompt")"
        rm -f "$root/.claude-init-prompt"
        _quinlan_cc_fallback "$root" "$prompt" "$@"
        return
    fi

    _quinlan_cc_fallback "$root" "$@"
}

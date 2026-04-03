# Timon-only Codex launch commands for Windows-native Codex.
#
# The canonical implementation lives in the active repo at
# scripts/dev/shell-runtime.sh. This module only resolves the active repo
# and hands off to that runtime.

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

_quinlan_repo_runtime_dispatch() {
    local command="$1"
    shift

    local root
    root="$(_quinlan_repo_root)" || root=""

    if _quinlan_load_repo_runtime "$root" && command -v "_quinlan_runtime_${command}" >/dev/null 2>&1; then
        "_quinlan_runtime_${command}" "$@"
        return
    fi

    echo "[codex] Quinlan runtime not available here." >&2
    echo "[codex] Open a quinlan worktree with scripts/dev/shell-runtime.sh for c/dev." >&2
    return 1
}

c() {
    _quinlan_repo_runtime_dispatch c "$@"
}

dev() {
    _quinlan_repo_runtime_dispatch dev "$@"
}

# Codex and dev-layout launchers.
#
# Inside a Quinlan worktree the canonical implementation in
# scripts/dev/shell-runtime.sh is sourced and used.  Outside Quinlan,
# `c` loads project secrets and applies standard flags, but skips
# workspace cd and O-Drive env vars.

_quinlan_codex_ensure_env() {
    # Already loaded this session (by auto-env or a previous call).
    [[ -n "${_QUINLAN_ENV_ROOT:-}" ]] && return 0

    # Locate the repo via the persistent pointer.
    local repo_root=""
    if [[ -f "$HOME/.quinlan-repo" ]]; then
        repo_root="$(tr -d '\r\n' < "$HOME/.quinlan-repo")"
    fi
    [[ -n "$repo_root" && -f "$repo_root/scripts/dev/env.sh" ]] || return 1

    # shellcheck disable=SC1091
    source "$repo_root/scripts/dev/env.sh"
}

c() {
    local root
    root="$(_quinlan_repo_root)" || root=""

    if _quinlan_load_repo_runtime "$root" && command -v _quinlan_runtime_c >/dev/null 2>&1; then
        _quinlan_runtime_c "$@"
        return
    fi

    # Outside Quinlan: load secrets and apply standard flags.
    _quinlan_codex_ensure_env 2>/dev/null || true
    codex -a never -s danger-full-access "$@"
}

dev() {
    local root
    root="$(_quinlan_repo_root)" || root=""

    if _quinlan_load_repo_runtime "$root" && command -v _quinlan_runtime_dev >/dev/null 2>&1; then
        _quinlan_runtime_dev "$@"
        return
    fi

    echo "[dev] Requires a Quinlan worktree (creates a Claude + Codex layout)." >&2
    return 1
}

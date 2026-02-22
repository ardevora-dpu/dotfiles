# Timon override for Claude Code entrypoint.
# Shares one task list across sessions in the same worktree.

_quinlan_cc_task_list_id() {
    local root worktree

    root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$root" ]]; then
        worktree="$(basename "$root")"
    else
        worktree="$(basename "$PWD")"
    fi

    if [[ -z "$worktree" ]]; then
        return 1
    fi

    worktree="${worktree,,}"
    worktree="${worktree//[^a-z0-9._-]/-}"

    if [[ "$worktree" == quinlan* ]]; then
        printf '%s' "$worktree"
    else
        printf 'quinlan-%s' "$worktree"
    fi
}

cc() {
    local task_list_id

    task_list_id="$(_quinlan_cc_task_list_id)" || {
        unset CLAUDE_CODE_TASK_LIST_ID
        _quinlan_run_claude "$@"
        return
    }

    CLAUDE_CODE_TASK_LIST_ID="$task_list_id" _quinlan_run_claude "$@"
}

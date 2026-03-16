# Claude Code entrypoint used by both Timon and Jeremy.
# Base behaviour is isolated task lists per session.
#
# Prompt file convention: if .claude-init-prompt exists in the git
# worktree root, cc reads it as the initial prompt and deletes the
# file. Used by /start-session to prime new sessions without
# WezTerm text injection.

_quinlan_run_claude() {
    # Propagate project-level .claude/settings.json to the CWD so Claude
    # Code picks up the shared permission policy even when launched from a
    # workspace subdirectory.  The root file is the single source of truth;
    # workspace copies are gitignored.
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [[ -n "$root" && -f "$root/.claude/settings.json" && "$PWD" != "$root" ]]; then
        mkdir -p "$PWD/.claude"
        cp "$root/.claude/settings.json" "$PWD/.claude/settings.json"
    fi
    claude "$@"
}

cc() {
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null)"

    if [[ -n "$root" ]]; then
        local init_prompt_file="$root/.claude-init-prompt"
        if [[ -f "$init_prompt_file" ]]; then
            local init_prompt
            init_prompt="$(cat "$init_prompt_file")"
            rm -f "$init_prompt_file"
            _quinlan_run_claude "$init_prompt" "$@"
            return
        fi
    fi

    _quinlan_run_claude "$@"
}

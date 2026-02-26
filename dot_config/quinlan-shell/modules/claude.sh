# Claude Code entrypoint used by both Timon and Jeremy.
# Base behaviour is isolated task lists per session.
#
# Prompt file convention: if .claude-init-prompt exists in the git
# worktree root, cc reads it as the initial prompt and deletes the
# file. Used by /start-session to prime new sessions without
# WezTerm text injection.

_quinlan_run_claude() {
    claude --dangerously-skip-permissions "$@"
}

cc() {
    local init_prompt_file
    init_prompt_file="$(git rev-parse --show-toplevel 2>/dev/null)/.claude-init-prompt"

    if [[ -f "$init_prompt_file" ]]; then
        local init_prompt
        init_prompt="$(cat "$init_prompt_file")"
        rm -f "$init_prompt_file"
        _quinlan_run_claude "$init_prompt" "$@"
    else
        _quinlan_run_claude "$@"
    fi
}

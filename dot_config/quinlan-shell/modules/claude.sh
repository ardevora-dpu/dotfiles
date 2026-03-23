# Claude Code entrypoint used by both Timon and Jeremy.
#
# Prompt file convention: .claude-init-prompt at the git root is read
# as a positional prompt arg (`claude "prompt"`) which starts an
# interactive session with that message pre-sent. File is deleted
# after reading. Used by /start-session.

_quinlan_run_claude() {
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null)"
    # Propagate settings to CWD so Claude picks up permissions + MCP approval.
    if [[ -n "$root" && "$PWD" != "$root" ]]; then
        mkdir -p "$PWD/.claude"
        [[ -f "$root/.claude/settings.json" ]] && \
            cp "$root/.claude/settings.json" "$PWD/.claude/settings.json"
        [[ -f "$root/.claude/settings.local.json" ]] && \
            cp "$root/.claude/settings.local.json" "$PWD/.claude/settings.local.json"
    fi
    if [[ -n "$root" && "$PWD" != "$root" ]]; then
        claude --add-dir "$root" -- "$@"
    else
        claude "$@"
    fi
}

cc() {
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null)"

    if [[ -n "$root" && -f "$root/.claude-init-prompt" ]]; then
        local prompt
        prompt="$(cat "$root/.claude-init-prompt")"
        rm -f "$root/.claude-init-prompt"
        _quinlan_run_claude "$prompt" "$@"
    else
        _quinlan_run_claude "$@"
    fi
}

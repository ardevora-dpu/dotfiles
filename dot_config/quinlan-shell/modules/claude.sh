# Claude Code entrypoint used by both Timon and Jeremy.
# Base behaviour is isolated task lists per session.

_quinlan_run_claude() {
    claude --dangerously-skip-permissions "$@"
}

cc() {
    _quinlan_run_claude "$@"
}

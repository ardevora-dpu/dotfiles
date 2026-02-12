# Timon-only Codex launch commands for Windows -> WSL worktree parity.

_quinlan_require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[codex-wsl] Missing command: $cmd" >&2
        return 1
    fi
}

_quinlan_wsl_user() {
    if [[ -n "${_QUINLAN_WSL_USER:-}" ]]; then
        printf '%s' "$_QUINLAN_WSL_USER"
        return 0
    fi

    _quinlan_require_command wsl.exe || return 1

    _QUINLAN_WSL_USER="$(wsl.exe -d Ubuntu -e whoami 2>/dev/null | tr -d '\r[:space:]')"
    if [[ -z "$_QUINLAN_WSL_USER" ]]; then
        echo "[codex-wsl] Could not resolve WSL username from Ubuntu distro." >&2
        return 1
    fi

    printf '%s' "$_QUINLAN_WSL_USER"
}

_quinlan_current_worktree_name() {
    local win_dir
    win_dir="$(basename "$PWD")"

    if [[ ! "$win_dir" == quinlan* ]]; then
        echo "[codex-wsl] Current directory is not a quinlan worktree: $win_dir" >&2
        return 1
    fi

    printf '%s' "$win_dir"
}

_quinlan_wsl_worktree_path() {
    local win_dir="$1"
    local wsl_user

    wsl_user="$(_quinlan_wsl_user)" || return 1
    printf '/home/%s/projects/%s' "$wsl_user" "$win_dir"
}

_ensure_codex_snowflake_timeout() {
    local config="$HOME/.codex/config.toml"
    local timeout="${1:-45.0}"

    [[ -f "$config" ]] || return 0
    grep -q '^\[mcp_servers\.snowflake\]$' "$config" || return 0

    local tmp
    tmp="$(mktemp)" || return 0

    awk -v timeout="$timeout" '
    BEGIN { in_sf=0; set=0 }
    /^\[mcp_servers\.snowflake\]$/ {
        in_sf=1
        set=0
        print
        next
    }
    /^\[/ {
        if (in_sf && !set) {
            print "startup_timeout_sec = " timeout
        }
        in_sf=0
    }
    {
        if (in_sf && $0 ~ /^[[:space:]]*startup_timeout_sec[[:space:]]*=/) {
            if (!set) {
                print "startup_timeout_sec = " timeout
                set=1
            }
            next
        }
        print
    }
    END {
        if (in_sf && !set) {
            print "startup_timeout_sec = " timeout
        }
    }
    ' "$config" > "$tmp" && mv "$tmp" "$config"
}

_quinlan_require_wsl_worktree() {
    local wsl_path="$1"
    local expected_branch="$2"
    local wsl_branch

    _quinlan_require_command wsl || return 1

    if ! wsl -d Ubuntu -e bash -lc "[ -d '$wsl_path/.git' ]"; then
        echo "[codex-wsl] Missing WSL worktree at: $wsl_path" >&2
        echo "[codex-wsl] Create it with:" >&2
        echo "  wsl -d Ubuntu -e bash -lc \"cd ~/projects/quinlan && git worktree add '$wsl_path' '$expected_branch'\"" >&2
        return 1
    fi

    wsl_branch="$(wsl -d Ubuntu -e bash -lc "cd '$wsl_path' && git branch --show-current" | tr -d '\r[:space:]')"
    if [[ "$wsl_branch" != "$expected_branch" ]]; then
        echo "[codex-wsl] Branch mismatch for $wsl_path (expected '$expected_branch', got '${wsl_branch:-detached}')." >&2
        echo "[codex-wsl] Align it with:" >&2
        echo "  wsl -d Ubuntu -e bash -lc \"cd '$wsl_path' && git fetch origin && git checkout '$expected_branch' && git pull --ff-only\"" >&2
        return 1
    fi
}

c() {
    _quinlan_require_command git || return 1
    _quinlan_require_command wsl || return 1

    local win_dir branch wsl_path args
    win_dir="$(_quinlan_current_worktree_name)" || return 1
    branch="$(git branch --show-current 2>/dev/null)"

    if [[ -z "$branch" ]]; then
        echo "[codex-wsl] Could not determine current branch for $PWD" >&2
        return 1
    fi

    wsl_path="$(_quinlan_wsl_worktree_path "$win_dir")" || return 1
    _quinlan_require_wsl_worktree "$wsl_path" "$branch" || return 1
    _ensure_codex_snowflake_timeout

    args=""
    if (( $# > 0 )); then
        printf -v args ' %q' "$@"
    fi

    echo "Starting Codex in WSL: $wsl_path"
    wsl -- bash -lc "source ~/.nvm/nvm.sh 2>/dev/null; cd '$wsl_path' && source scripts/dev/env.sh && codex --dangerously-bypass-approvals-and-sandbox${args}"
}

dev() {
    local panes=4
    if [[ "${1:-}" == "2" ]]; then
        panes=2
        shift
    fi
    if (( $# > 0 )); then
        echo "Usage: dev [2]" >&2
        return 1
    fi

    _quinlan_require_command git || return 1
    _quinlan_require_command jq || return 1
    _quinlan_require_command wezterm || return 1
    _quinlan_require_command wsl || return 1

    local branch win_dir wsl_path left_pane
    branch="$(git branch --show-current 2>/dev/null)"
    if [[ -z "$branch" ]]; then
        echo "[codex-wsl] Could not determine current branch for $PWD" >&2
        return 1
    fi

    win_dir="$(_quinlan_current_worktree_name)" || return 1
    wsl_path="$(_quinlan_wsl_worktree_path "$win_dir")" || return 1
    _quinlan_require_wsl_worktree "$wsl_path" "$branch" || return 1
    _ensure_codex_snowflake_timeout

    left_pane="${WEZTERM_PANE:-$(wezterm cli list --format json | jq -r 'first(.[] | select(.is_active)) | .pane_id')}"
    if [[ -z "$left_pane" || "$left_pane" == "null" ]]; then
        echo "[codex-wsl] Could not resolve an active WezTerm pane." >&2
        return 1
    fi

    if [[ "$panes" == "2" ]]; then
        local right_pane
        right_pane="$(wezterm cli split-pane --right --percent 50 --pane-id "$left_pane" -- wsl.exe -d Ubuntu --cd "~")"

        sleep 0.3
        wezterm cli send-text --pane-id "$left_pane" $'cc\n'

        sleep 2
        wezterm cli send-text --no-paste --pane-id "$right_pane" -- "cd $wsl_path && source scripts/dev/env.sh && source ~/.nvm/nvm.sh && codex --dangerously-bypass-approvals-and-sandbox
"

        echo "Dev layout '$win_dir' ready: Claude Code (left) | Codex (right)"
        return 0
    fi

    local top_right bottom_left bottom_right
    top_right="$(wezterm cli split-pane --right --percent 50 --pane-id "$left_pane" --cwd "$PWD")"
    bottom_left="$(wezterm cli split-pane --bottom --percent 50 --pane-id "$left_pane" -- wsl.exe -d Ubuntu --cd "~")"
    bottom_right="$(wezterm cli split-pane --bottom --percent 50 --pane-id "$top_right" -- wsl.exe -d Ubuntu --cd "~")"

    sleep 0.3
    wezterm cli send-text --pane-id "$left_pane" $'cc\n'
    wezterm cli send-text --pane-id "$top_right" $'cc\n'

    sleep 2
    wezterm cli send-text --no-paste --pane-id "$bottom_left" -- "cd $wsl_path && source scripts/dev/env.sh && source ~/.nvm/nvm.sh && codex --dangerously-bypass-approvals-and-sandbox
"
    wezterm cli send-text --no-paste --pane-id "$bottom_right" -- "cd $wsl_path && source scripts/dev/env.sh && source ~/.nvm/nvm.sh && codex --dangerously-bypass-approvals-and-sandbox
"

    echo "Dev layout '$win_dir' ready: 2x Claude Code (top) | 2x Codex (bottom)"
}

# Timon-only Codex launch commands for Windows -> WSL worktree parity.

_quinlan_require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[codex-wsl] Missing command: $cmd" >&2
        return 1
    fi
}

_quinlan_wsl_bash() {
    local script="$1"
    wsl -d Ubuntu -e bash -c "$script"
}

_quinlan_wsl_login_bash() {
    local script="$1"
    wsl -d Ubuntu -e bash -lc "$script"
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
    local repo_root win_dir
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "$repo_root" ]]; then
        echo "[codex-wsl] Could not resolve git worktree root from: $PWD" >&2
        return 1
    fi

    win_dir="$(basename "$repo_root")"

    if [[ ! "$win_dir" == quinlan* ]]; then
        echo "[codex-wsl] Git worktree root is not a quinlan worktree: $win_dir" >&2
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

_quinlan_wsl_context_path() {
    local wsl_path="$1"
    printf '%s/workspaces/timon' "$wsl_path"
}

# shellcheck disable=SC2120 # Default parameter is intentional — callers use the default
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

_ensure_wsl_codex_dbt_mcp_env() {
    local wsl_path="$1"
    local wsl_user config expected_dbt expected_project

    wsl_user="$(_quinlan_wsl_user)" || return 0
    config="/home/$wsl_user/.codex/config.toml"
    expected_dbt="$wsl_path/.venv/bin/dbt"
    expected_project="$wsl_path/warehouse"

    _quinlan_wsl_bash "[ -f '$config' ]" || return 0
    _quinlan_wsl_bash "grep -q '^\\[mcp_servers\\.dbt-mcp\\]$' '$config'" || return 0

    _quinlan_wsl_login_bash "WSL_CODEX_CONFIG='$config' WSL_DBT_PATH='$expected_dbt' WSL_DBT_PROJECT_DIR='$expected_project' python3 - <<'PY'
import os
from pathlib import Path

config = Path(os.environ['WSL_CODEX_CONFIG'])
dbt_path = os.environ['WSL_DBT_PATH']
dbt_project_dir = os.environ['WSL_DBT_PROJECT_DIR']
text = config.read_text()
if '[mcp_servers.dbt-mcp]' not in text:
    raise SystemExit(0)

lines = text.splitlines()
had_trailing_newline = text.endswith('\n')
out = []
in_env = False
saw_env = False
wrote_path = False
wrote_project = False

def emit_missing():
    global wrote_path, wrote_project
    if not wrote_path:
        out.append(f'DBT_PATH = \"{dbt_path}\"')
        wrote_path = True
    if not wrote_project:
        out.append(f'DBT_PROJECT_DIR = \"{dbt_project_dir}\"')
        wrote_project = True

for line in lines:
    if line == '[mcp_servers.dbt-mcp.env]':
        in_env = True
        saw_env = True
        wrote_path = False
        wrote_project = False
        out.append(line)
        continue

    if in_env and line.startswith('['):
        emit_missing()
        in_env = False

    if in_env and line.lstrip().startswith('DBT_PATH'):
        if not wrote_path:
            out.append(f'DBT_PATH = \"{dbt_path}\"')
            wrote_path = True
        continue

    if in_env and line.lstrip().startswith('DBT_PROJECT_DIR'):
        if not wrote_project:
            out.append(f'DBT_PROJECT_DIR = \"{dbt_project_dir}\"')
            wrote_project = True
        continue

    out.append(line)

if in_env:
    emit_missing()

if not saw_env:
    if out and out[-1] != '':
        out.append('')
    out.append('[mcp_servers.dbt-mcp.env]')
    out.append(f'DBT_PATH = \"{dbt_path}\"')
    out.append(f'DBT_PROJECT_DIR = \"{dbt_project_dir}\"')

updated = '\n'.join(out)
if had_trailing_newline:
    updated += '\n'

if updated != text:
    config.write_text(updated)
PY"
}

_ensure_wsl_codex_project_doc_fallback() {
    local wsl_user config

    wsl_user="$(_quinlan_wsl_user)" || return 0
    config="/home/$wsl_user/.codex/config.toml"

    _quinlan_wsl_bash "[ -f '$config' ]" || return 0

    _quinlan_wsl_login_bash "WSL_CODEX_CONFIG='$config' python3 - <<'PY'
import os
from pathlib import Path

config = Path(os.environ['WSL_CODEX_CONFIG'])
text = config.read_text()
line = 'project_doc_fallback_filenames = [\"CLAUDE.md\"]'

lines = text.splitlines()
replaced = False
for idx, value in enumerate(lines):
    if value.lstrip().startswith('project_doc_fallback_filenames'):
        if lines[idx] != line:
            lines[idx] = line
        replaced = True
        break

if not replaced:
    insert_at = None
    for idx, value in enumerate(lines):
        if value.lstrip().startswith('personality'):
            insert_at = idx + 1
            break
    if insert_at is None:
        insert_at = 0
    lines.insert(insert_at, line)

updated = '\\n'.join(lines)
if text.endswith('\\n'):
    updated += '\\n'

if updated != text:
    config.write_text(updated)
PY"
}

_ensure_codex_no_user_agents() {
    local local_agents="$HOME/.codex/AGENTS.md"
    local wsl_user wsl_agents

    if [[ -f "$local_agents" ]]; then
        rm -f "$local_agents"
    fi

    wsl_user="$(_quinlan_wsl_user)" || return 0
    wsl_agents="/home/$wsl_user/.codex/AGENTS.md"
    _quinlan_wsl_bash "rm -f '$wsl_agents'" >/dev/null 2>&1 || true
}

_quinlan_create_wsl_worktree() {
    local wsl_path="$1"
    local branch="$2"
    local wsl_main="$3"

    echo "[codex-wsl] Creating WSL worktree: $wsl_path (branch: $branch)"

    _quinlan_wsl_bash "[ -d '$wsl_path' ] && rm -rf '$wsl_path' || true"
    _quinlan_wsl_bash "cd '$wsl_main' && git worktree prune"

    if ! _quinlan_wsl_bash "cd '$wsl_main' && git fetch origin '+refs/heads/$branch:refs/remotes/origin/$branch'"; then
        echo "[codex-wsl] Failed to fetch branch '$branch' in WSL main repo." >&2
        return 1
    fi

    if ! _quinlan_wsl_bash "cd '$wsl_main' && git worktree add '$wsl_path' 'origin/$branch'"; then
        echo "[codex-wsl] Failed to create WSL worktree for '$branch'." >&2
        return 1
    fi
}

_quinlan_ensure_wsl_worktree() {
    local wsl_path="$1"
    local branch="$2"
    local main_repo="$3"
    local wsl_user wsl_main wsl_branch

    _quinlan_require_command wsl || return 1
    _quinlan_require_command git || return 1

    if [[ -z "$branch" ]]; then
        echo "[codex-wsl] Missing branch for WSL worktree sync." >&2
        return 1
    fi

    if [[ -z "$main_repo" ]]; then
        echo "[codex-wsl] Missing main repo path for WSL worktree sync." >&2
        return 1
    fi

    wsl_user="$(_quinlan_wsl_user)" || return 1
    wsl_main="/home/$wsl_user/projects/quinlan"

    if ! _quinlan_wsl_bash "[ -d '$wsl_main/.git' ] || [ -f '$wsl_main/.git' ]"; then
        echo "[codex-wsl] Missing WSL main repo: $wsl_main" >&2
        echo "[codex-wsl] Clone quinlan in WSL before using c/dev." >&2
        return 1
    fi

    if ! git -C "$main_repo" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
        echo "[codex-wsl] Pushing branch '$branch' to origin for WSL sync..."
        git -C "$main_repo" push -u origin "$branch" || return 1
    fi

    if ! _quinlan_wsl_bash "[ -d '$wsl_path/.git' ] || [ -f '$wsl_path/.git' ]"; then
        _quinlan_create_wsl_worktree "$wsl_path" "$branch" "$wsl_main" || return 1
    fi

    wsl_branch="$(_quinlan_wsl_bash "cd '$wsl_path' && git branch --show-current" 2>/dev/null | tr -d '\r[:space:]')"
    if [[ -z "$wsl_branch" || "$wsl_branch" != "$branch" ]]; then
        echo "[codex-wsl] Aligning WSL worktree branch: $wsl_path -> $branch"
        # Stash dirty state so checkout succeeds, then pop to preserve Codex work.
        # Only pop if we actually created a stash entry (avoid popping older unrelated stashes).
        local pre_stash_count
        pre_stash_count="$(_quinlan_wsl_bash "cd '$wsl_path' && git stash list | wc -l" 2>/dev/null | tr -d '\r[:space:]')"
        _quinlan_wsl_bash "cd '$wsl_path' && git stash --include-untracked -q" 2>/dev/null || true
        _quinlan_wsl_bash "cd '$wsl_path' && git fetch origin && git checkout '$branch' && git pull --ff-only" || return 1
        local post_stash_count
        post_stash_count="$(_quinlan_wsl_bash "cd '$wsl_path' && git stash list | wc -l" 2>/dev/null | tr -d '\r[:space:]')"
        if [[ "$post_stash_count" -gt "$pre_stash_count" ]]; then
            _quinlan_wsl_bash "cd '$wsl_path' && git stash pop -q" 2>/dev/null || true
        fi
    fi

    _quinlan_wsl_bash "cd '$wsl_path' && git config core.autocrlf input" >/dev/null 2>&1 || true
}

c() {
    _quinlan_require_command git || return 1
    _quinlan_require_command wsl || return 1

    local win_dir branch wsl_path wsl_context_path args main_repo
    win_dir="$(_quinlan_current_worktree_name)" || return 1
    branch="$(git branch --show-current 2>/dev/null)"
    main_repo="$(git rev-parse --show-toplevel 2>/dev/null)"

    if [[ -z "$branch" ]]; then
        echo "[codex-wsl] Could not determine current branch for $PWD" >&2
        return 1
    fi

    wsl_path="$(_quinlan_wsl_worktree_path "$win_dir")" || return 1
    _quinlan_ensure_wsl_worktree "$wsl_path" "$branch" "$main_repo" || return 1
    wsl_context_path="$(_quinlan_wsl_context_path "$wsl_path")"
    if ! _quinlan_wsl_bash "[ -d '$wsl_context_path' ]"; then
        echo "[codex-wsl] Missing Timon workspace in WSL worktree: $wsl_context_path" >&2
        return 1
    fi
    _ensure_codex_snowflake_timeout
    _ensure_wsl_codex_dbt_mcp_env "$wsl_path"
    _ensure_wsl_codex_project_doc_fallback
    _ensure_codex_no_user_agents

    args=""
    if (( $# > 0 )); then
        printf -v args ' %q' "$@"
    fi

    echo "Starting Codex in WSL: $wsl_context_path"
    wsl -- bash -lc "source ~/.nvm/nvm.sh 2>/dev/null; cd '$wsl_path' && source scripts/dev/env.sh && cd 'workspaces/timon' && codex --dangerously-bypass-approvals-and-sandbox${args}"
}

dev() {
    _quinlan_require_command git || return 1
    _quinlan_require_command jq || return 1
    _quinlan_require_command wezterm || return 1
    _quinlan_require_command wsl || return 1

    local branch win_dir wsl_path wsl_context_path left_pane main_repo claude_workspace
    branch="$(git branch --show-current 2>/dev/null)"
    main_repo="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [[ -z "$branch" ]]; then
        echo "[codex-wsl] Could not determine current branch for $PWD" >&2
        return 1
    fi

    win_dir="$(_quinlan_current_worktree_name)" || return 1
    wsl_path="$(_quinlan_wsl_worktree_path "$win_dir")" || return 1
    _quinlan_ensure_wsl_worktree "$wsl_path" "$branch" "$main_repo" || return 1
    wsl_context_path="$(_quinlan_wsl_context_path "$wsl_path")"
    if ! _quinlan_wsl_bash "[ -d '$wsl_context_path' ]"; then
        echo "[codex-wsl] Missing Timon workspace in WSL worktree: $wsl_context_path" >&2
        return 1
    fi
    claude_workspace="$main_repo/workspaces/timon"
    if [[ ! -d "$claude_workspace" ]]; then
        echo "[codex-wsl] Missing Timon workspace in Windows worktree: $claude_workspace" >&2
        return 1
    fi
    _ensure_codex_snowflake_timeout
    _ensure_wsl_codex_dbt_mcp_env "$wsl_path"
    _ensure_wsl_codex_project_doc_fallback
    _ensure_codex_no_user_agents

    # Copy Codex init prompt from Windows worktree to WSL if present.
    # /start-session writes both prompt files to the Windows worktree root;
    # dev handles the cross-boundary copy so callers don't need WSL paths.
    local win_codex_prompt="$main_repo/.codex-init-prompt"
    if [[ -f "$win_codex_prompt" ]]; then
        _quinlan_wsl_bash "cat > '$wsl_path/.codex-init-prompt'" < "$win_codex_prompt"
        rm -f "$win_codex_prompt"
    fi

    left_pane="${WEZTERM_PANE:-$(wezterm cli list --format json | jq -r 'first(.[] | select(.is_active)) | .pane_id')}"
    if [[ -z "$left_pane" || "$left_pane" == "null" ]]; then
        echo "[codex-wsl] Could not resolve an active WezTerm pane." >&2
        return 1
    fi

    # Codex launch command: checks for .codex-init-prompt and passes it
    # as the initial prompt if found. Escaping is for the WSL bash shell
    # that receives this text via send-text.
    local codex_cmd
    codex_cmd="cd '$wsl_path' && source scripts/dev/env.sh && cd workspaces/timon && source ~/.nvm/nvm.sh && _qf='$wsl_path/.codex-init-prompt'; if [ -f \"\$_qf\" ]; then _qp=\"\$(cat \"\$_qf\")\"; rm -f \"\$_qf\"; codex --dangerously-bypass-approvals-and-sandbox \"\$_qp\"; else codex --dangerously-bypass-approvals-and-sandbox; fi"

    local right_pane
    right_pane="$(wezterm cli split-pane --right --percent 50 --pane-id "$left_pane" -- wsl.exe -d Ubuntu --cd "~")"

    sleep 0.3
    wezterm cli send-text --no-paste --pane-id "$left_pane" -- "cd '$claude_workspace' && cc
"

    sleep 2
    wezterm cli send-text --no-paste --pane-id "$right_pane" -- "$codex_cmd
"

    echo "Dev layout '$win_dir' ready: Claude Code (left) | Codex (right)"
}

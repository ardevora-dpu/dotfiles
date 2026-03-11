# Timon-only Codex launch commands for Windows -> WSL worktree/clone parity.

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

_codex_wsl_repo_root() {
    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "$repo_root" ]]; then
        echo "[codex-wsl] Could not resolve git worktree root from: $PWD" >&2
        return 1
    fi

    printf '%s' "$repo_root"
}

_codex_wsl_repo_name() {
    local repo_root="${1:-}"
    if [[ -z "$repo_root" ]]; then
        repo_root="$(_codex_wsl_repo_root)" || return 1
    fi

    printf '%s' "${repo_root##*/}"
}

_codex_wsl_is_quinlan_repo() {
    local repo_name="${1:-}"
    if [[ -z "$repo_name" ]]; then
        repo_name="$(_codex_wsl_repo_name)" || return 1
    fi

    [[ "$repo_name" == quinlan* ]]
}

_quinlan_current_worktree_name() {
    local repo_root win_dir
    repo_root="$(_codex_wsl_repo_root)" || return 1
    win_dir="$(_codex_wsl_repo_name "$repo_root")"

    if ! _codex_wsl_is_quinlan_repo "$win_dir"; then
        echo "[codex-wsl] Git worktree root is not a quinlan worktree: $win_dir" >&2
        return 1
    fi

    printf '%s' "$win_dir"
}

_codex_wsl_projects_root() {
    local wsl_user
    wsl_user="$(_quinlan_wsl_user)" || return 1
    printf '/home/%s/projects' "$wsl_user"
}

_codex_wsl_clone_path() {
    local repo_name="$1"
    local wsl_root
    wsl_root="$(_codex_wsl_projects_root)" || return 1
    printf '%s/%s' "$wsl_root" "$repo_name"
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

_quinlan_tab_label_from_worktree() {
    local win_dir="$1"
    if [[ "$win_dir" == "quinlan" ]]; then
        printf 'main'
        return 0
    fi

    if [[ "$win_dir" == quinlan-* ]]; then
        printf '%s' "${win_dir#quinlan-}"
        return 0
    fi

    printf '%s' "$win_dir"
}

_quinlan_dotfiles_state_local() {
    local repo="$1"
    local head origin dirty

    git -C "$repo" fetch origin >/dev/null 2>&1 || return 1
    head="$(git -C "$repo" rev-parse HEAD 2>/dev/null)" || return 1
    origin="$(git -C "$repo" rev-parse origin/main 2>/dev/null)" || return 1
    dirty="$(git -C "$repo" status --porcelain | wc -l | tr -d '[:space:]')" || return 1

    printf '%s|%s|%s' "$head" "$origin" "$dirty"
}

_quinlan_dotfiles_state_wsl() {
    local repo="$1"
    local state

    state="$(_quinlan_wsl_bash "git -C '$repo' fetch origin >/dev/null 2>&1 && \
        h=\$(git -C '$repo' rev-parse HEAD) && \
        o=\$(git -C '$repo' rev-parse origin/main) && \
        d=\$(git -C '$repo' status --porcelain | wc -l | tr -d '[:space:]') && \
        printf '%s|%s|%s' \"\$h\" \"\$o\" \"\$d\"" 2>/dev/null)" || return 1
    [[ -n "$state" ]] || return 1

    printf '%s' "$state"
}

_quinlan_sync_dotfiles_if_needed() {
    local local_repo="$HOME/.local/share/chezmoi"
    local wsl_user wsl_repo
    local local_state wsl_state
    local local_head local_origin local_dirty
    local wsl_head wsl_origin wsl_dirty
    local needs_sync=0

    _quinlan_require_command chezmoi || return 1
    _quinlan_require_command git || return 1

    if [[ ! -d "$local_repo/.git" ]]; then
        echo "[codex-wsl] Missing Windows chezmoi repo: $local_repo" >&2
        return 1
    fi

    wsl_user="$(_quinlan_wsl_user)" || return 1
    wsl_repo="/home/$wsl_user/.local/share/chezmoi"
    if ! _quinlan_wsl_bash "[ -d '$wsl_repo/.git' ]"; then
        echo "[codex-wsl] Missing WSL chezmoi repo: $wsl_repo" >&2
        return 1
    fi

    local_state="$(_quinlan_dotfiles_state_local "$local_repo")" || {
        echo "[codex-wsl] Failed to read Windows dotfiles state." >&2
        return 1
    }
    IFS='|' read -r local_head local_origin local_dirty <<< "$local_state"

    wsl_state="$(_quinlan_dotfiles_state_wsl "$wsl_repo")" || {
        echo "[codex-wsl] Failed to read WSL dotfiles state." >&2
        return 1
    }
    IFS='|' read -r wsl_head wsl_origin wsl_dirty <<< "$wsl_state"

    if [[ "$local_dirty" != "0" || "$wsl_dirty" != "0" ]]; then
        if [[ "${_QUINLAN_DOTFILES_DIRTY_WARNED:-0}" != "1" ]]; then
            echo "[codex-wsl] Dotfiles repos have local changes; skipping auto-sync."
            echo "[codex-wsl] Commit/stash dotfiles changes when you want strict sync checks again."
            _QUINLAN_DOTFILES_DIRTY_WARNED=1
            export _QUINLAN_DOTFILES_DIRTY_WARNED
        fi
        return 0
    fi

    if [[ "$local_head" != "$local_origin" || "$wsl_head" != "$wsl_origin" ]]; then
        needs_sync=1
    fi

    if (( needs_sync == 0 )); then
        return 0
    fi

    echo "[codex-wsl] Dotfiles drift detected; syncing Windows and WSL..."
    chezmoi update --force || {
        echo "[codex-wsl] Windows chezmoi update failed. Use 'dev --no-sync' to bypass once." >&2
        return 1
    }
    chezmoi apply --force || {
        echo "[codex-wsl] Windows chezmoi apply failed. Use 'dev --no-sync' to bypass once." >&2
        return 1
    }
    _quinlan_wsl_login_bash "chezmoi update --force && chezmoi apply --force" || {
        echo "[codex-wsl] WSL chezmoi sync failed. Use 'dev --no-sync' to bypass once." >&2
        return 1
    }
}

_codex_wsl_ensure_branch_on_origin() {
    local repo_root="$1"
    local branch="$2"

    if git -C "$repo_root" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
        return 0
    fi

    echo "[codex-wsl] Pushing '$branch' to origin so the WSL clone can check it out..." >&2
    git -C "$repo_root" push -u origin "$branch" || {
        echo "[codex-wsl] Failed to push '$branch' to origin." >&2
        return 1
    }
}

_codex_wsl_ensure_clone() {
    local repo_root="$1"
    local repo_name="$2"
    local branch="$3"
    local origin_url wsl_root wsl_path clone_exists wsl_branch wsl_dirty

    origin_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null)" || {
        echo "[codex-wsl] No 'origin' remote configured for $repo_root." >&2
        return 1
    }
    wsl_root="$(_codex_wsl_projects_root)" || return 1
    wsl_path="$(_codex_wsl_clone_path "$repo_name")" || return 1

    _codex_wsl_ensure_branch_on_origin "$repo_root" "$branch" || return 1

    clone_exists="$(_quinlan_wsl_bash "if [ -d '$wsl_path/.git' ] || [ -f '$wsl_path/.git' ]; then echo yes; else echo no; fi" 2>/dev/null)"
    if [[ "$clone_exists" != "yes" ]]; then
        echo "[codex-wsl] Cloning '$repo_name' into WSL: $wsl_path" >&2
        _quinlan_wsl_bash "mkdir -p '$wsl_root' && git clone '$origin_url' '$wsl_path' && cd '$wsl_path' && git config core.autocrlf input" || {
            echo "[codex-wsl] Failed to clone '$repo_name' into WSL." >&2
            return 1
        }
    fi

    wsl_branch="$(_quinlan_wsl_bash "cd '$wsl_path' && git branch --show-current" 2>/dev/null | tr -d '\r[:space:]')"
    wsl_dirty="$(_quinlan_wsl_bash "cd '$wsl_path' && git status --porcelain | wc -l" 2>/dev/null | tr -d '\r[:space:]')"
    if [[ "${wsl_dirty:-0}" != "0" && -n "$wsl_branch" && "$wsl_branch" != "$branch" ]]; then
        echo "[codex-wsl] Refusing to realign dirty WSL clone: $wsl_path (${wsl_branch} -> $branch)" >&2
        echo "[codex-wsl] Commit, stash, or clean the WSL checkout yourself before rerunning dev/c." >&2
        return 1
    fi

    _quinlan_wsl_bash "cd '$wsl_path' && git fetch origin >/dev/null" || return 1
    if [[ -z "$wsl_branch" || "$wsl_branch" != "$branch" ]]; then
        echo "[codex-wsl] Aligning WSL clone branch: $wsl_path -> $branch" >&2
        _quinlan_wsl_bash "cd '$wsl_path' && (git checkout '$branch' >/dev/null 2>&1 || git checkout -b '$branch' 'origin/$branch' >/dev/null 2>&1)" || return 1
        wsl_branch="$branch"
    fi

    if [[ "${wsl_dirty:-0}" == "0" ]]; then
        _quinlan_wsl_bash "cd '$wsl_path' && git pull --ff-only >/dev/null" || return 1
    elif [[ "$wsl_branch" == "$branch" ]]; then
        echo "[codex-wsl] WSL clone has local changes on '$branch'; skipping auto-pull." >&2
    fi

    _quinlan_wsl_bash "cd '$wsl_path' && git config core.autocrlf input" >/dev/null 2>&1 || true
    printf '%s' "$wsl_path"
}

# shellcheck disable=SC2120 # Default parameters are intentional — callers use defaults
_ensure_codex_mcp_setting() {
    local config="$1"
    local server="$2"
    local key="$3"
    local value="$4"

    [[ -f "$config" ]] || return 0
    grep -q "^\[mcp_servers\\.${server}\]$" "$config" || return 0

    local tmp
    tmp="$(mktemp)" || return 0

    awk -v section="[mcp_servers.${server}]" -v key="$key" -v value="$value" '
    BEGIN { in_target=0; set=0 }
    $0 == section {
        in_target=1
        set=0
        print
        next
    }
    /^\[/ {
        if (in_target && !set) {
            print key " = " value
        }
        in_target=0
    }
    {
        if (in_target && $0 ~ ("^[[:space:]]*" key "[[:space:]]*=")) {
            if (!set) {
                print key " = " value
                set=1
            }
            next
        }
        print
    }
    END {
        if (in_target && !set) {
            print key " = " value
        }
    }
    ' "$config" > "$tmp" && mv "$tmp" "$config"
}

# shellcheck disable=SC2120 # Default parameters are intentional — callers use defaults
_ensure_codex_mcp_timeouts() {
    local config="$HOME/.codex/config.toml"
    local snowflake_startup="${1:-45.0}"
    local neon_startup="${2:-60.0}"
    local neon_tool="${3:-300.0}"

    _ensure_codex_mcp_setting "$config" "snowflake" "startup_timeout_sec" "$snowflake_startup"
    _ensure_codex_mcp_setting "$config" "neon" "startup_timeout_sec" "$neon_startup"
    _ensure_codex_mcp_setting "$config" "neon" "tool_timeout_sec" "$neon_tool"
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

_codex_wsl_launch_flags() {
    # WSL shells do not have a reliable desktop keyring session, so
    # keep MCP OAuth tokens in Codex's file-backed store for WSL launches.
    printf "%s" "--dangerously-bypass-approvals-and-sandbox -c 'mcp_oauth_credentials_store=\"file\"'"
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
    local wsl_user wsl_main wsl_branch wsl_dirty

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
        wsl_dirty="$(_quinlan_wsl_bash "cd '$wsl_path' && git status --porcelain | wc -l" 2>/dev/null | tr -d '\r[:space:]')"
        if [[ "${wsl_dirty:-0}" != "0" ]]; then
            echo "[codex-wsl] Refusing to realign dirty WSL worktree: $wsl_path (${wsl_branch:-detached} -> $branch)" >&2
            echo "[codex-wsl] Commit, stash, or clean the WSL checkout yourself before rerunning dev/c." >&2
            return 1
        fi

        echo "[codex-wsl] Aligning WSL worktree branch: $wsl_path -> $branch"
        _quinlan_wsl_bash "cd '$wsl_path' && git fetch origin && git checkout '$branch' && git pull --ff-only" || return 1
    fi

    _quinlan_wsl_bash "cd '$wsl_path' && git config core.autocrlf input" >/dev/null 2>&1 || true
}

c() {
    _quinlan_require_command git || return 1
    _quinlan_require_command wsl || return 1

    local repo_root repo_name win_dir branch wsl_path wsl_context_path args codex_flags main_repo
    repo_root="$(_codex_wsl_repo_root)" || return 1
    repo_name="$(_codex_wsl_repo_name "$repo_root")" || return 1
    branch="$(git branch --show-current 2>/dev/null)"
    main_repo="$repo_root"
    codex_flags="$(_codex_wsl_launch_flags)"

    if [[ -z "$branch" ]]; then
        echo "[codex-wsl] Could not determine current branch for $PWD" >&2
        return 1
    fi

    if _codex_wsl_is_quinlan_repo "$repo_name"; then
        win_dir="$(_quinlan_current_worktree_name)" || return 1
        wsl_path="$(_quinlan_wsl_worktree_path "$win_dir")" || return 1
        _quinlan_ensure_wsl_worktree "$wsl_path" "$branch" "$main_repo" || return 1
        wsl_context_path="$(_quinlan_wsl_context_path "$wsl_path")"
        if ! _quinlan_wsl_bash "[ -d '$wsl_context_path' ]"; then
            echo "[codex-wsl] Missing Timon workspace in WSL worktree: $wsl_context_path" >&2
            return 1
        fi
        _ensure_codex_mcp_timeouts
        _ensure_wsl_codex_dbt_mcp_env "$wsl_path"
        _ensure_wsl_codex_project_doc_fallback
        _ensure_codex_no_user_agents
    else
        wsl_path="$(_codex_wsl_ensure_clone "$repo_root" "$repo_name" "$branch")" || return 1
        wsl_context_path="$wsl_path"
    fi

    args=""
    if (( $# > 0 )); then
        printf -v args ' %q' "$@"
    fi

    echo "Starting Codex in WSL: $wsl_context_path"
    if _codex_wsl_is_quinlan_repo "$repo_name"; then
        wsl -- bash -lc "source ~/.nvm/nvm.sh 2>/dev/null; cd '$wsl_path' && source scripts/dev/env.sh && cd 'workspaces/timon' && codex $codex_flags${args}"
    else
        wsl -- bash -lc "source ~/.nvm/nvm.sh 2>/dev/null; cd '$wsl_path' && codex $codex_flags${args}"
    fi
}

dev() {
    _quinlan_require_command git || return 1
    _quinlan_require_command jq || return 1
    _quinlan_require_command wezterm || return 1
    _quinlan_require_command wsl || return 1

    local skip_sync=0
    if (( $# > 0 )) && [[ "$1" == "--no-sync" ]]; then
        skip_sync=1
        shift
    fi
    if (( $# > 0 )) && [[ "$1" == "2" ]]; then
        echo "[codex-wsl] 'dev 2' is obsolete; use 'dev' for the two-pane Claude Code | Codex layout." >&2
        return 1
    fi
    if (( $# > 0 )); then
        echo "[codex-wsl] Usage: dev [--no-sync]" >&2
        return 1
    fi

    local branch repo_root repo_name win_dir wsl_path wsl_context_path left_pane main_repo claude_workspace codex_flags
    if (( skip_sync == 0 )); then
        _quinlan_sync_dotfiles_if_needed || return 1
    fi

    repo_root="$(_codex_wsl_repo_root)" || return 1
    repo_name="$(_codex_wsl_repo_name "$repo_root")" || return 1
    branch="$(git branch --show-current 2>/dev/null)"
    main_repo="$repo_root"
    codex_flags="$(_codex_wsl_launch_flags)"
    if [[ -z "$branch" ]]; then
        echo "[codex-wsl] Could not determine current branch for $PWD" >&2
        return 1
    fi

    if _codex_wsl_is_quinlan_repo "$repo_name"; then
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
        _ensure_codex_mcp_timeouts
        _ensure_wsl_codex_dbt_mcp_env "$wsl_path"
        _ensure_wsl_codex_project_doc_fallback
        _ensure_codex_no_user_agents

        # Copy Codex init prompt from Windows worktree to WSL if present.
        # /start-session writes both prompt files to the Windows worktree root;
        # dev handles the cross-boundary copy so callers don't need WSL paths.
        local win_codex_prompt="$main_repo/.codex-init-prompt"
        if [[ -f "$win_codex_prompt" ]]; then
            if _quinlan_wsl_bash "cat > '$wsl_path/.codex-init-prompt'" < "$win_codex_prompt"; then
                rm -f "$win_codex_prompt"
            else
                echo "[codex-wsl] Failed to copy Codex prompt to WSL; keeping $win_codex_prompt" >&2
            fi
        fi
    else
        win_dir="$repo_name"
        wsl_path="$(_codex_wsl_ensure_clone "$repo_root" "$repo_name" "$branch")" || return 1
        wsl_context_path="$wsl_path"
        claude_workspace="$main_repo"
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
    if _codex_wsl_is_quinlan_repo "$repo_name"; then
        codex_cmd="cd '$wsl_path' && source scripts/dev/env.sh && cd workspaces/timon && source ~/.nvm/nvm.sh && _qf='$wsl_path/.codex-init-prompt'; if [ -f \"\$_qf\" ]; then _qp=\"\$(cat \"\$_qf\")\"; rm -f \"\$_qf\"; codex $codex_flags \"\$_qp\"; else codex $codex_flags; fi"
    else
        codex_cmd="cd '$wsl_path' && source ~/.nvm/nvm.sh 2>/dev/null && codex $codex_flags"
    fi

    local right_pane
    # MSYS_NO_PATHCONV prevents Git Bash from mangling the Linux path
    # (e.g. /home/chimern/... → C:/Program Files/Git/home/chimern/...).
    right_pane="$(MSYS_NO_PATHCONV=1 wezterm cli split-pane --right --percent 50 --pane-id "$left_pane" -- wsl.exe -d Ubuntu --cd "$wsl_context_path")"
    local tab_label
    if _codex_wsl_is_quinlan_repo "$repo_name"; then
        tab_label="$(_quinlan_tab_label_from_worktree "$win_dir")"
    else
        tab_label="$win_dir"
    fi
    wezterm cli set-tab-title --pane-id "$left_pane" "$tab_label" >/dev/null 2>&1 || true

    sleep 0.3
    wezterm cli send-text --no-paste --pane-id "$left_pane" -- "cd '$claude_workspace' && cc
"

    sleep 2
    wezterm cli send-text --no-paste --pane-id "$right_pane" -- "$codex_cmd
"

    echo "Dev layout '$win_dir' ready: Claude Code (left) | Codex (right)"
}

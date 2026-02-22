# Project picker for workspaces under WORKSPACE_ROOT.

_quinlan_workspace_root() {
    if [[ -n "${WORKSPACE_ROOT:-}" ]] && [[ -d "$WORKSPACE_ROOT" ]]; then
        printf '%s' "$WORKSPACE_ROOT"
        return 0
    fi

    if [[ -f "$HOME/.quinlan-repo" ]]; then
        local repo_root
        repo_root="$(tr -d '\r\n' < "$HOME/.quinlan-repo")"
        if [[ -n "$repo_root" ]]; then
            local parent
            parent="$(dirname "$repo_root")"
            if [[ -d "$parent" ]]; then
                printf '%s' "$parent"
                return 0
            fi
        fi
    fi

    if [[ -d "/e/projects/main_workspace" ]]; then
        printf '%s' "/e/projects/main_workspace"
        return 0
    fi

    printf '%s' "$HOME/projects"
}

_quinlan_workspace_context_dir() {
    local user_name=""

    if [[ -f "$HOME/.quinlan-user" ]]; then
        user_name="$(tr -d '\r\n' < "$HOME/.quinlan-user" | tr '[:upper:]' '[:lower:]')"
    fi

    if [[ -z "$user_name" ]]; then
        user_name="${USER,,}"
    fi

    case "$user_name" in
        timon|chimern)
            printf '%s' "workspaces/timon"
            ;;
        jeremy|jeremylang)
            printf '%s' "workspaces/jeremy"
            ;;
        *)
            return 1
            ;;
    esac
}

p() {
    if ! command -v fzf >/dev/null 2>&1; then
        echo "[project] Missing dependency: fzf" >&2
        return 1
    fi

    local workspace selected target context_dir
    workspace="$(_quinlan_workspace_root)"

    if [[ ! -d "$workspace" ]]; then
        echo "[project] Workspace root does not exist: $workspace" >&2
        return 1
    fi

    selected="$(find "$workspace" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sed "s|$workspace/||" | sort | fzf --height 40% --reverse --prompt="project> ")"
    [[ -z "$selected" ]] && return 0

    target="$workspace/$selected"
    context_dir="$(_quinlan_workspace_context_dir 2>/dev/null || true)"

    if [[ -n "$context_dir" ]] && [[ -d "$target/$context_dir" ]]; then
        target="$target/$context_dir"
    fi

    cd "$target" || return 1
}

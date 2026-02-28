# Shared shell path setup for Quinlan sessions (Windows Git Bash + WSL/Linux).

_quinlan_uname="$(uname -s 2>/dev/null || true)"
case "$_quinlan_uname" in
    MINGW*|MSYS*|CYGWIN*)
        _quinlan_is_windows_shell=1
        ;;
    *)
        _quinlan_is_windows_shell=0
        ;;
esac

_quinlan_path_prepend_if_dir() {
    local candidate="$1"

    if [[ ! -d "$candidate" ]]; then
        return
    fi

    case ":$PATH:" in
        *":$candidate:"*) ;;
        *) PATH="$candidate:$PATH" ;;
    esac
}

_quinlan_path_remove_entry() {
    local target="$1"
    local filtered=""
    local entry=""
    local old_ifs="$IFS"

    IFS=':'
    for entry in $PATH; do
        if [[ -z "$entry" ]] || [[ "$entry" == "$target" ]]; then
            continue
        fi

        case ":$filtered:" in
            *":$entry:"*) ;;
            *) filtered="${filtered:+$filtered:}$entry" ;;
        esac
    done
    IFS="$old_ifs"

    PATH="$filtered"
}

if (( _quinlan_is_windows_shell )); then
    if [[ "$PATH" == *";"* ]] && [[ -x /usr/bin/cygpath ]]; then
        PATH="$(/usr/bin/cygpath -u -p "$PATH")"
    fi
else
    # Drop Git Bash residue in WSL/Linux shells.
    _quinlan_path_remove_entry "/mingw64/bin"
fi

_quinlan_path_prepend_if_dir "/usr/bin"
_quinlan_path_prepend_if_dir "$HOME/.local/bin"

if (( _quinlan_is_windows_shell )); then
    _win_path() {
        local value="$1"

        if command -v cygpath >/dev/null 2>&1; then
            cygpath -u "$value"
            return
        fi

        if [ -x /usr/bin/cygpath ]; then
            /usr/bin/cygpath -u "$value"
            return
        fi

        printf '%s' "${value//\\//}"
    }

    _quinlan_path_prepend_if_dir "/mingw64/bin"

    if [[ -n "${LOCALAPPDATA:-}" ]]; then
        win_links="$(_win_path "$LOCALAPPDATA")/Microsoft/WinGet/Links"
        _quinlan_path_prepend_if_dir "$win_links"

        uv_bin="$(_win_path "$LOCALAPPDATA")/uv/bin"
        _quinlan_path_prepend_if_dir "$uv_bin"
    fi

    if [[ -n "${APPDATA:-}" ]]; then
        npm_bin="$(_win_path "$APPDATA")/npm"
        _quinlan_path_prepend_if_dir "$npm_bin"
    fi

    if command -v mise >/dev/null 2>&1 && [[ -n "${LOCALAPPDATA:-}" ]]; then
        mise_shims="$(_win_path "$LOCALAPPDATA")/mise/shims"
        _quinlan_path_prepend_if_dir "$mise_shims"
    fi
fi

if [[ -z "${WORKSPACE_ROOT:-}" && -f "$HOME/.quinlan-repo" ]]; then
    repo_root="$(tr -d '\r\n' < "$HOME/.quinlan-repo")"
    if [[ -n "$repo_root" ]]; then
        WORKSPACE_ROOT="$(dirname "$repo_root")"
        export WORKSPACE_ROOT
    fi
fi

export PATH

unset -f _quinlan_path_prepend_if_dir
unset -f _quinlan_path_remove_entry
unset -f _win_path 2>/dev/null
unset _quinlan_is_windows_shell
unset _quinlan_uname
unset repo_root

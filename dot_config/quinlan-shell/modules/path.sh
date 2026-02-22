# Shared shell path setup for Quinlan Git Bash sessions.

if [[ "$PATH" == *";"* ]] && [[ -x /usr/bin/cygpath ]]; then
    PATH="$(/usr/bin/cygpath -u -p "$PATH")"
fi

if [ -d /usr/bin ]; then
    case ":$PATH:" in
        *":/usr/bin:"*) ;;
        *) export PATH="/usr/bin:$PATH" ;;
    esac
fi

if [ -d /mingw64/bin ]; then
    case ":$PATH:" in
        *":/mingw64/bin:"*) ;;
        *) export PATH="/mingw64/bin:$PATH" ;;
    esac
fi

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

if [ -n "$LOCALAPPDATA" ]; then
    win_links="$(_win_path "$LOCALAPPDATA")/Microsoft/WinGet/Links"
    if [ -d "$win_links" ]; then
        export PATH="$win_links:$PATH"
    fi
fi

if [ -d "$HOME/.local/bin" ]; then
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
fi

if [ -n "$APPDATA" ]; then
    npm_bin="$(_win_path "$APPDATA")/npm"
    if [ -d "$npm_bin" ]; then
        case ":$PATH:" in
            *":$npm_bin:"*) ;;
            *) export PATH="$npm_bin:$PATH" ;;
        esac
    fi
fi

if [ -n "$LOCALAPPDATA" ]; then
    uv_bin="$(_win_path "$LOCALAPPDATA")/uv/bin"
    if [ -d "$uv_bin" ]; then
        case ":$PATH:" in
            *":$uv_bin:"*) ;;
            *) export PATH="$uv_bin:$PATH" ;;
        esac
    fi
fi

if command -v mise >/dev/null 2>&1 && [ -n "$LOCALAPPDATA" ]; then
    mise_shims="$(_win_path "$LOCALAPPDATA")/mise/shims"
    if [ -d "$mise_shims" ]; then
        case ":$PATH:" in
            *":$mise_shims:"*) ;;
            *) export PATH="$mise_shims:$PATH" ;;
        esac
    fi
fi

if [[ -z "${WORKSPACE_ROOT:-}" && -f "$HOME/.quinlan-repo" ]]; then
    repo_root="$(tr -d '\r\n' < "$HOME/.quinlan-repo")"
    if [[ -n "$repo_root" ]]; then
        WORKSPACE_ROOT="$(dirname "$repo_root")"
        export WORKSPACE_ROOT
    fi
fi

unset -f _win_path
unset repo_root

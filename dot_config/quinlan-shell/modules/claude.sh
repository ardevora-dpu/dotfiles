# Claude Code entrypoint used by both Timon and Jeremy.
#
# Prompt file convention: .claude-init-prompt at the git root is read
# as a positional prompt arg (`claude "prompt"`) which starts an
# interactive session with that message pre-sent. File is deleted
# after reading. Used by /start-session.

_quinlan_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

_quinlan_repo_runtime_script() {
    local root="$1"
    printf '%s/scripts/dev/shell-runtime.sh' "$root"
}

_quinlan_load_repo_runtime() {
    local root="$1" script

    if [[ -z "$root" ]]; then
        return 1
    fi

    script="$(_quinlan_repo_runtime_script "$root")"
    if [[ ! -f "$script" ]]; then
        return 1
    fi

    # shellcheck disable=SC1090
    source "$script"
}

# --- Lightweight slot selection (works anywhere, no repo dependency) ---
# Full provisioning/repair lives in shell-runtime.sh; this only resolves
# an existing slot directory and sets CLAUDE_CONFIG_DIR.

_quinlan_slot_has_credentials() {
    local slot_dir="$1"
    # .credentials.json is the cross-platform credential file.
    [[ -f "$slot_dir/.credentials.json" ]] && return 0
    # macOS stores tokens in Keychain; presence of oauthAccount in
    # .claude.json is sufficient.
    [[ -f "$slot_dir/.claude.json" ]] || return 1
    command -v python3 >/dev/null 2>&1 || return 1
    python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if isinstance(d.get('oauthAccount'), dict) and d['oauthAccount'] else 1)
" "$slot_dir/.claude.json" 2>/dev/null
}

_quinlan_slot_resolve() {
    # Resolve slot path for CLAUDE_CONFIG_DIR.
    # Priority: $1 (explicit) → last-used (with creds) → first slot with creds.
    local account="${1:-}"
    local slots_dir="$HOME/.claude/slots"
    local last_used="$slots_dir/.last_used"

    # Fall back to last-used account (only if it has credentials).
    if [[ -z "$account" && -f "$last_used" ]]; then
        local candidate
        candidate="$(tr -d '[:space:]' < "$last_used")"
        if [[ -n "$candidate" ]] && _quinlan_slot_has_credentials "$slots_dir/$candidate"; then
            account="$candidate"
        fi
    fi

    # Fall back to first slot with credentials.
    if [[ -z "$account" && -d "$slots_dir" ]]; then
        local slot
        for slot in "$slots_dir"/*/; do
            if _quinlan_slot_has_credentials "$slot"; then
                account="$(basename "$slot")"
                break
            fi
        done
    fi

    [[ -n "$account" && -d "$slots_dir/$account" ]] || return 1

    # Remember this as last-used.
    printf '%s' "$account" > "$last_used" 2>/dev/null || true

    printf '%s' "$slots_dir/$account"
}

_quinlan_slot_parse_account() {
    # Parse optional account name from the first positional arg.
    # `cc quant2` → sets _QUINLAN_PARSED_ACCOUNT=quant2, _QUINLAN_PARSED_SHIFT=1.
    # `cc "fix the bug"` → leaves both empty/zero (passthrough).
    # Caller is responsible for shifting.
    _QUINLAN_PARSED_ACCOUNT=""
    _QUINLAN_PARSED_SHIFT=0

    [[ $# -gt 0 ]] || return 0

    local first="$1"
    [[ "${first:0:2}" != "--" ]] || return 0
    [[ "$first" =~ ^[a-z0-9][a-z0-9-]*$ ]] || return 0

    if [[ -d "$HOME/.claude/slots/$first" ]]; then
        _QUINLAN_PARSED_ACCOUNT="$first"
        _QUINLAN_PARSED_SHIFT=1
    elif [[ ${#first} -le 12 ]]; then
        echo "[cc] Unknown account '$first'. Available: $(ls -1 "$HOME/.claude/slots/" 2>/dev/null | tr '\n' ' ')" >&2
        echo "[cc] If this is a prompt, use: cc -- $first" >&2
        return 1
    fi
}

_quinlan_cc_fallback() {
    local root="$1"
    shift 1

    # Slot isolation: set CLAUDE_CONFIG_DIR if a slot resolves.
    local -a slot_env=()
    local slot_dir
    if slot_dir="$(_quinlan_slot_resolve "${_QUINLAN_PARSED_ACCOUNT:-}")"; then
        slot_env=(env "CLAUDE_CONFIG_DIR=$slot_dir")
    fi

    if [[ -n "$root" && "$PWD" != "$root" ]]; then
        # Propagate project settings to CWD (Claude Code settings are CWD-scoped).
        if [[ -f "$root/.claude/settings.json" ]]; then
            mkdir -p "$PWD/.claude"
            cp "$root/.claude/settings.json" "$PWD/.claude/settings.json"
        fi
        "${slot_env[@]}" claude --add-dir "$root" "$@"
    else
        "${slot_env[@]}" claude "$@"
    fi
}

cc() {
    local root prompt

    root="$(_quinlan_repo_root)" || root=""

    if _quinlan_load_repo_runtime "$root" && command -v _quinlan_runtime_cc >/dev/null 2>&1; then
        _quinlan_runtime_cc "$@"
        return
    fi

    # Outside Quinlan: parse account name and resolve slot ourselves.
    _quinlan_slot_parse_account "$@" || return 1
    shift "$_QUINLAN_PARSED_SHIFT"

    if [[ -n "$root" && -f "$root/.claude-init-prompt" ]]; then
        prompt="$(cat "$root/.claude-init-prompt")"
        rm -f "$root/.claude-init-prompt"
        # -- separates flags from the positional prompt arg
        _quinlan_cc_fallback "$root" -- "$prompt" "$@"
        return
    fi

    # No --, so flags like --resume pass through correctly
    _quinlan_cc_fallback "$root" "$@"
}

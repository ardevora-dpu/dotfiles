#!/usr/bin/env bash
# Claude Code status line — managed by chezmoi.
# ARD-451: declarative deployment replaces doctor-side provisioning.

input=$(cat)

cwd=$(echo "$input"       | jq -r '.cwd // empty')
model=$(echo "$input"     | jq -r '.model.display_name // empty')
cost=$(echo "$input"      | jq -r '.cost.total_cost_usd // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
added=$(echo "$input"     | jq -r '.cost.total_lines_added // empty')
removed=$(echo "$input"   | jq -r '.cost.total_lines_removed // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')

# ANSI colours — grouped by purpose
RESET='\033[0m'
DIM='\033[90m'
CYAN='\033[36m'
BOLD_MAGENTA='\033[1;35m'
YELLOW='\033[33m'
GREEN='\033[32m'
RED='\033[31m'
BLUE='\033[94m'

# 0. Active account from slot directory name
account_part=""
if [[ -n "$CLAUDE_CONFIG_DIR" ]]; then
    account=$(basename "$CLAUDE_CONFIG_DIR")
    account_part="${CYAN}@${account}${RESET}"
fi

# 0a. Research session ticker (keyed by session_id)
ticker=""
if [[ -n "$session_id" && -f "$HOME/.claude/research-sessions/${session_id}.ticker" ]]; then
    ticker=$(cat "$HOME/.claude/research-sessions/${session_id}.ticker")
fi

ticker_part=""
if [[ -n "$ticker" ]]; then
    ticker_part="${BOLD_MAGENTA}${ticker}${RESET}"
fi

# 1. Session context: conversation title + git safety indicator
branch=""
session_label=""
git_prefix=""

# Detect main branch as a safety signal (applies to all users)
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || true)
    if [[ "$branch" == "main" || "$branch" == "master" ]]; then
        git_prefix="${YELLOW}[main]${RESET} "
    fi
fi

# Claude Code conversation title from terminal pane (preferred over branch).
# Cached to /tmp to avoid IPC on every status line update (10s TTL).
# Claude Code titles have a single-char non-ASCII spinner prefix + space
# (e.g. "✳ Scaffold Astro project"). Shell/program titles don't match
# this pattern ("bash", "vim file", "quinlan-ard-731").
_sl_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-${TEMP:-/tmp}}}/claude-statusline-$(id -u 2>/dev/null || echo "$USER")"

if [[ -n "$WEZTERM_PANE" ]]; then
    _sl_cache="${_sl_dir}/${WEZTERM_PANE}"
    _sl_refresh=true
    if [[ -f "$_sl_cache" ]]; then
        # Portable mtime check: GNU stat uses -c %Y, BSD/macOS uses -f %m
        _sl_mtime=$(stat -c %Y "$_sl_cache" 2>/dev/null || stat -f %m "$_sl_cache" 2>/dev/null || echo 0)
        _sl_age=$(( $(date +%s) - _sl_mtime ))
        (( _sl_age < 10 )) && _sl_refresh=false
    fi
    if $_sl_refresh; then
        mkdir -p "$_sl_dir" 2>/dev/null
        wezterm cli list --format json 2>/dev/null \
          | jq -r --arg pid "$WEZTERM_PANE" \
            '.[] | select(.pane_id == ($pid | tonumber)) | .title // empty' \
          > "$_sl_cache" 2>/dev/null || true
    fi
    raw_title=$(cat "$_sl_cache" 2>/dev/null)
    if [[ -n "$raw_title" ]]; then
        prefix="${raw_title%% *}"
        if [[ ${#prefix} -eq 1 && "$prefix" != "$raw_title" ]]; then
            stripped="${raw_title#* }"
            [[ ${#stripped} -gt 3 ]] && session_label="$stripped"
        fi
    fi
elif [[ -n "$TMUX" ]]; then
    # tmux path: read pane title set by Claude Code via OSC 0/2.
    _sl_cache="${_sl_dir}/tmux-${TMUX_PANE:-default}"
    _sl_refresh=true
    if [[ -f "$_sl_cache" ]]; then
        _sl_mtime=$(stat -c %Y "$_sl_cache" 2>/dev/null || stat -f %m "$_sl_cache" 2>/dev/null || echo 0)
        _sl_age=$(( $(date +%s) - _sl_mtime ))
        (( _sl_age < 10 )) && _sl_refresh=false
    fi
    if $_sl_refresh; then
        mkdir -p "$_sl_dir" 2>/dev/null
        tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_title}' > "$_sl_cache" 2>/dev/null || true
    fi
    raw_title=$(cat "$_sl_cache" 2>/dev/null)
    if [[ -n "$raw_title" ]]; then
        prefix="${raw_title%% *}"
        if [[ ${#prefix} -eq 1 && "$prefix" != "$raw_title" ]]; then
            stripped="${raw_title#* }"
            [[ ${#stripped} -gt 3 ]] && session_label="$stripped"
        fi
    fi
fi

# Fallback to git branch when no conversation title is available
if [[ -z "$session_label" && -n "$branch" ]]; then
    session_label="($branch)"
fi

branch_part=""
if [[ -n "$session_label" ]]; then
    branch_part="${git_prefix}${CYAN}${session_label}${RESET}"
fi

# 2. Model in dim (stable info, doesn't need to shout)
model_part=""
if [[ -n "$model" ]]; then
    model_part="${DIM}${model}${RESET}"
fi

# 3. Cost in yellow (money = gold)
cost_part=""
if [[ -n "$cost" ]]; then
    cost_fmt=$(printf '%.2f' "$cost" 2>/dev/null)
    cost_part="${YELLOW}\$${cost_fmt}${RESET}"
fi

# 4. Remaining context with traffic-light colouring
ctx_part=""
if [[ -n "$remaining" ]]; then
    ctx_int=${remaining%.*}
    if (( ctx_int > 30 )); then
        ctx_color="$BLUE"
    elif (( ctx_int > 10 )); then
        ctx_color="$YELLOW"
    else
        ctx_color="$RED"
    fi
    ctx_part="${ctx_color}${ctx_int}% remaining${RESET}"
fi

# 5. Lines changed in green/red (compact +N/-N)
lines_part=""
if [[ -n "$added" || -n "$removed" ]]; then
    chunks=()
    [[ -n "$added" && "$added" != "0" ]] && chunks+=("${GREEN}+${added}${RESET}")
    [[ -n "$removed" && "$removed" != "0" ]] && chunks+=("${RED}-${removed}${RESET}")
    if [[ ${#chunks[@]} -gt 0 ]]; then
        lines_part=$(IFS=/; echo "${chunks[*]}")
    fi
fi

# Assemble — join non-empty parts with separator (ticker first for visibility)
parts=()
[[ -n "$account_part" ]] && parts+=("$account_part")
[[ -n "$ticker_part" ]] && parts+=("$ticker_part")
[[ -n "$branch_part" ]] && parts+=("$branch_part")
[[ -n "$model_part"  ]] && parts+=("$model_part")
[[ -n "$cost_part"   ]] && parts+=("$cost_part")
[[ -n "$lines_part"  ]] && parts+=("$lines_part")
[[ -n "$ctx_part"    ]] && parts+=("$ctx_part")

sep=" ${DIM}|${RESET} "
line=""
for part in "${parts[@]}"; do
    if [[ -z "$line" ]]; then
        line="$part"
    else
        line="${line}${sep}${part}"
    fi
done

printf '%b' "$line"

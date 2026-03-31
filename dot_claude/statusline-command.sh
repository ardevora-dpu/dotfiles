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

# 1. Git branch (dim — stable context)
branch=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || true)
fi

branch_part=""
if [[ -n "$branch" ]]; then
    branch_part="${CYAN}(${branch})${RESET}"
fi

# 2. Model in dim (stable info, doesn't need to shout)
model_part=""
if [[ -n "$model" ]]; then
    model_part="\033[37m${model}${RESET}"
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

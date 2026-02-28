# Auto-source project env when entering a repo that has scripts/dev/env.sh.

_quinlan_auto_env() {
    local dir="$PWD"

    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/scripts/dev/env.sh" ]]; then
            if [[ "${_QUINLAN_ENV_ROOT:-}" != "$dir" ]]; then
                # shellcheck source=/dev/null
                source "$dir/scripts/dev/env.sh"
            fi
            return
        fi
        dir="$(dirname "$dir")"
    done
}

# Tell WezTerm the shell's real CWD via OSC 7. Without this, WezTerm
# walks the process tree and may find pyright's node.exe (CWD dist/dist/),
# causing tab titles to show "dist" and new tabs to open in the wrong dir.
_quinlan_osc7_cwd() {
    printf '\e]7;file://%s%s\e\\' "$HOSTNAME" "$PWD"
}

if [[ "${PROMPT_COMMAND:-}" != *"_quinlan_auto_env"* ]]; then
    PROMPT_COMMAND="_quinlan_osc7_cwd;_quinlan_auto_env${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

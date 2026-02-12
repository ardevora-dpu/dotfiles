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

if [[ "${PROMPT_COMMAND:-}" != *"_quinlan_auto_env"* ]]; then
    PROMPT_COMMAND="_quinlan_auto_env${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

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
    # cygpath -m converts POSIX paths (/e/projects/...) to Windows mixed-mode
    # (E:/projects/...) so WezTerm can parse the drive letter correctly.
    # Without this, WezTerm sees /e/... which isn't a valid Windows path,
    # causing new tabs to fall back to ~ or produce doubled paths (/c/c/...).
    printf '\e]7;file:///%s\e\\' "$(cygpath -m "$PWD")"
}

if [[ "${PROMPT_COMMAND:-}" != *"_quinlan_auto_env"* ]]; then
    PROMPT_COMMAND="_quinlan_osc7_cwd;_quinlan_auto_env${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

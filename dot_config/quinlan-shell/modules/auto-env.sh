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
    # Guard: cygpath only exists in MSYS2/Git Bash, not WSL.
    command -v cygpath >/dev/null 2>&1 || return
    printf '\e]7;file:///%s\e\\' "$(cygpath -m "$PWD")"
}

# Disable focus reporting (CSI ?1004) to prevent bell storms.
# Claude Code enables focus reporting via ANSI sequences but doesn't always
# clean up on exit (#17010). WezTerm then sends focus-in/out events that some
# programs interpret as input, causing spurious BEL characters.
_quinlan_reset_focus_reporting() {
    printf '\e[?1004l'
}

if [[ "${PROMPT_COMMAND:-}" != *"_quinlan_auto_env"* ]]; then
    PROMPT_COMMAND="_quinlan_reset_focus_reporting;_quinlan_osc7_cwd;_quinlan_auto_env${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

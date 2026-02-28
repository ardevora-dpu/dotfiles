#!/usr/bin/bash
# Workaround for Claude Code #15128. Remove when upstream fixes snapshot PATH.
#
# Problem: Claude Code's shell snapshot applies AFTER BASH_ENV, overwriting
# PATH with Windows format (C:\...;C:\...). A one-shot fix here gets undone.
#
# Solution: DEBUG trap fires before each command — after the snapshot has run.
# Fixes PATH on first command, then removes itself.
#
# BASH_ENV is injected by Claude Code settings.json env block.
_quinlan_fix_path() {
    if [[ "$PATH" == *";"* ]]; then
        if [[ -n "${ORIGINAL_PATH:-}" ]]; then
            PATH="$ORIGINAL_PATH"
        elif [[ -x /usr/bin/cygpath ]]; then
            PATH="$(/usr/bin/cygpath -u -p "$PATH")"
        fi
        export PATH
    fi
    trap - DEBUG
}
trap '_quinlan_fix_path' DEBUG

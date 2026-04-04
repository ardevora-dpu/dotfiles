#!/bin/bash
# Ghostty tmux auto-start: every new tab lands inside tmux.
# Names the session after the CWD for easy identification in choose-tree.
# Named sessions (quinlan, quinlan-ard-*) are created by the dev launcher.

base="$(basename "$PWD")"
[[ "$PWD" == "$HOME" ]] && base="home"

# Deduplicate: if "timon" exists, try "timon-2", "timon-3", ...
session="$base"
n=2
while /opt/homebrew/bin/tmux has-session -t "=$session" 2>/dev/null; do
    session="${base}-${n}"
    ((n++))
done

exec /opt/homebrew/bin/tmux new-session -s "$session"

# Personal, machine-local overrides (never committed).
if [[ -f "$HOME/.bashrc.local" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.bashrc.local"
fi

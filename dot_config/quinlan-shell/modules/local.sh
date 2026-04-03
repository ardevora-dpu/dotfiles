# Personal, machine-local overrides (never committed).
# Keep durable launcher or workflow behaviour in managed shell modules instead
# of redefining core functions such as c/dev here.
if [[ -n "${ZSH_VERSION:-}" ]]; then
    if [[ -f "$HOME/.zshrc.local" ]]; then
        # shellcheck source=/dev/null
        source "$HOME/.zshrc.local"
    fi
elif [[ -f "$HOME/.bashrc.local" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.bashrc.local"
fi

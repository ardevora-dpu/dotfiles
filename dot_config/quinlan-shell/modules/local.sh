# Personal, machine-local overrides (never committed).
# Keep durable launcher or workflow behaviour in managed shell modules instead
# of redefining core functions such as c/dev here.
if [[ -f "$HOME/.bashrc.local" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.bashrc.local"
fi

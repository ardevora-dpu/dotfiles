# Timon User Context (Codex)

This file is the user-level context for Timon's Codex sessions.

## Runtime

- Use WSL for Codex.
- `c` launches Codex for the matching WSL worktree of the current Windows worktree.
- `dev` launches the dual-agent pane layout.

## Context Model

- User-level guidance lives in `~/.codex/AGENTS.md` (this file).
- Project-level guidance comes from each repository's committed `AGENTS.md`.
- Durable project rules belong in the repo, not here.

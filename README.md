# Dotfiles

Shell and terminal configuration managed by [chezmoi](https://chezmoi.io).

## Source of Truth

This repository is the source of truth for home-directory shell/runtime config.

- Edit files here.
- Apply with `chezmoi apply --force`.
- Do not edit `~/.bashrc` or `~/.wezterm.lua` directly.

## Deployed Files

| Source | Target | Purpose |
|---|---|---|
| `dot_bash_profile` | `~/.bash_profile` | Login shell bootstrap |
| `dot_bashrc` | `~/.bashrc` | Module loader + role routing |
| `dot_config/quinlan-shell/modules/*.sh` | `~/.config/quinlan-shell/modules/*.sh` | Explicit shell modules |
| `dot_wezterm.lua` | `~/.wezterm.lua` | WezTerm config |
| `dot_claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Timon user-level Claude context (Timon only) |
| `dot_codex/AGENTS.md` | `~/.codex/AGENTS.md` | Timon user-level Codex context (Timon only) |
| `dot_claude/skills/*` | `~/.claude/skills/*` | Timon user-level skills (Timon only) |
| `run_once_compile-helpers.ps1` | one-time run | Build helper executables on Windows |
| `scripts/clip2png.cs` | `~/scripts/clip2png.cs` | Clipboard image helper source |

## Role Model

Shell role routing is explicit and driven by `~/.quinlan-user`.

- Valid values: `timon` or `jeremy`
- No fallback role inference
- `/update` is expected to set this file

Role behaviour:

- `jeremy`: base modules + `cc`
- `timon`: base modules + Codex/WSL module (`c`, `dev`)

## Timon-Only Gating

`dot_claude/CLAUDE.md`, `dot_codex/AGENTS.md`, and `dot_claude/skills/**` are gated by username in `.chezmoiignore.tmpl`.

## Quick Start

```bash
chezmoi apply --force
```

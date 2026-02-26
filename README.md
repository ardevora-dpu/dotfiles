# Dotfiles

Shell and terminal configuration managed by [chezmoi](https://chezmoi.io).

## Source Of Truth

This repository is the source of truth for home-directory shell/runtime config.

- Edit files here.
- Apply with `chezmoi apply --force`.
- Do not edit `~/.bashrc` or `~/.wezterm.lua` directly.

## Deployed Files

| Source | Target | Purpose |
|---|---|---|
| `dot_bash_profile` | `~/.bash_profile` | Login shell bootstrap |
| `dot_bashrc` | `~/.bashrc` | Module loader |
| `dot_config/quinlan-shell/modules/path.sh` | `~/.config/quinlan-shell/modules/path.sh` | PATH and workspace root setup |
| `dot_config/quinlan-shell/modules/auto-env.sh` | `~/.config/quinlan-shell/modules/auto-env.sh` | Auto-source `scripts/dev/env.sh` |
| `dot_config/quinlan-shell/modules/claude.sh` | `~/.config/quinlan-shell/modules/claude.sh` | Base `cc` launcher |
| `dot_config/quinlan-shell/modules/project.sh` | `~/.config/quinlan-shell/modules/project.sh` | `p` project picker |
| `dot_config/quinlan-shell/modules/codex-wsl.sh` | `~/.config/quinlan-shell/modules/codex-wsl.sh` | Timon-only WSL/Codex commands (`c`, `dev`) |
| `dot_config/quinlan-shell/modules/local.sh` | `~/.config/quinlan-shell/modules/local.sh` | Optional machine-local override loader |
| `dot_wezterm.lua.tmpl` | `~/.wezterm.lua` | WezTerm config |
| `dot_claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Timon user-level Claude context (Timon only) |
| `run_once_compile-helpers.ps1` | one-time run | Build helper executables on Windows |
| `scripts/clip2png.cs` | `~/scripts/clip2png.cs` | Clipboard image helper source |

## Behaviour Model

Deployment-time gating controls user-specific payload; no runtime role file is used in `.bashrc`.

- Shared modules (all users): `path`, `auto-env`, `claude`, `project`
- Timon-only modules: `codex-wsl`
- Jeremy receives only shared modules

`cc` behaviour: isolated task list per session (default for all users).

## Context Model

Canonical project context for Timon is:

- `quinlan/CLAUDE.md` (global shared context)
- `quinlan/workspaces/timon/CLAUDE.md` (Timon-specific context)

Codex and Claude should be launched from `workspaces/timon` when working in Quinlan.

## Quick Start

```bash
chezmoi apply --force
```

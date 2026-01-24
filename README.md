# Dotfiles

Shared shell and terminal configuration, managed by [chezmoi](https://chezmoi.io).

## What's Included

| File | Target | Purpose |
|------|--------|---------|
| `dot_wezterm.lua` | `~/.wezterm.lua` | WezTerm terminal config (GPU, 240fps, Git Bash) |
| `dot_bashrc` | `~/.bashrc` | Shell aliases, PATH, auto-env loading |
| `dot_bash_profile` | `~/.bash_profile` | Login shell setup |
| `scripts/clip2png.cs` | `~/scripts/clip2png.cs` | Clipboard image helper (source) |

## Quick Start

```bash
# First time on a new machine: run /update to configure chezmoi
# After that, from any worktree:
chezmoi apply
```

This copies dotfiles to your home directory, overwriting any existing versions.

**Note:** `/update` creates `~/.config/chezmoi/chezmoi.toml` once per machine, pointing to the repo's dotfiles. After first-time setup, `chezmoi apply` works from any worktree.

## Compile clip2png (One-Time)

The WezTerm config uses a clipboard helper to paste screenshots. Compile it once:

```bash
# Find the .NET compiler
CSC="/c/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe"

# Compile
mkdir -p ~/.local/bin
"$CSC" /optimize /target:exe /out:~/.local/bin/clip2png.exe ~/scripts/clip2png.cs
```

After this, Ctrl+V in WezTerm will:
- Paste image path if clipboard contains an image
- Normal paste otherwise

## Updating Dotfiles

**Source of truth:** Edit files in `setup/dotfiles/`, not `~/`.

```bash
# 1. Edit the repo version
vim setup/dotfiles/dot_wezterm.lua

# 2. Apply to home
chezmoi apply

# 3. Commit
git add setup/dotfiles/
git commit -m "chore(dotfiles): update wezterm config"
```

## Default Paths

The wezterm config uses dynamic paths:
- `default_cwd` → `~/projects/quinlan` (uses `$USERPROFILE`)

If your repo is elsewhere, the `/update` skill will detect this and fix it.

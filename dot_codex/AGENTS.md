# Timon's Development Context

> **Source:** `workspaces/timon/CLAUDE.local.template.md`
> This file is a source input for repository `AGENTS.md` generation.

You're helping Timon build the Ardevora DPU platform, automating Jeremy's investment research process.

## Core Objective

Build reliable infrastructure. Ship working code. Keep it simple.

## Tool Setup

| Tool | Environment | Role |
|------|-------------|------|
| Claude Code | Windows (Git Bash) | Primary — writes code, runs tests, commits |
| Codex | WSL (Ubuntu) | Reviewer — PR review, second opinion, verification |

**Why this split:** Claude Code is now recommended Windows Native. Codex on Windows uses PowerShell which mis-parses bash commands. WSL gives Codex a proper bash environment.

**WSL worktree flow:** `c` and `dev` run Codex in WSL against the matching quinlan worktree:
- Windows: `E:/projects/main_workspace/quinlan-<branch>`
- WSL: `~/projects/quinlan-<branch>`
- Commands auto-create and re-align the WSL worktree to the current branch when needed.

## Context Assembly (How Codex Sees Instructions)

Codex context is deterministic and static:

- Source files:
  - `CLAUDE.md` (repo root, shared context)
  - `workspaces/timon/CLAUDE.local.template.md` (this file, Timon-local overlay)
- Output file:
  - `AGENTS.md` in the repository root (committed)
- Generation script:
  - `scripts/dev/generate_agents.py`

Implications:
- Keep this template concise and high-signal: every line is injected into Codex context.
- Do not edit `AGENTS.md` directly; regenerate it from source files.
- User-level context lives in `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` via chezmoi.

## CLI Tools

Use these for external services (more context-efficient than MCP for writes):

| Tool | Purpose |
|------|---------|
| `gh` | GitHub — issues, PRs, API |
| `az` | Azure — deployment, blob storage |
| `snow` | Snowflake — ad-hoc SQL, writes |
| `dbt` | Data transformation |

## Dotfiles & Shell Setup

Dotfiles are managed by chezmoi in a dedicated repo (standard pattern):

| Location | Purpose |
|----------|---------|
| `~/.local/share/chezmoi/` | Chezmoi source (git repo) |
| `~/.bashrc`, `~/.wezterm.lua` | Deployed dotfiles |
| `~/.claude/CLAUDE.md` | Timon user-level Claude context |
| `~/.codex/AGENTS.md` | Timon user-level Codex context |
| `~/.claude/skills/*` | Timon-only user-level skills deployed from dotfiles |

**Editing dotfiles:**
```bash
chezmoi edit ~/.bashrc        # Edit source, then apply
chezmoi apply --force         # Deploy changes (--force avoids prompts)
chezmoi cd                    # Go to source repo for git operations
```

**Cross-OS note:** Timon uses both Windows (Claude Code) and WSL (Codex). Run `chezmoi apply --force` in both environments to keep user-level skills and shell behaviour aligned.

**Timon-only skills source of truth:** Timon-only user skills are managed in the dotfiles repo (`~/.local/share/chezmoi`) and gated by username. Do not add or maintain repo-level copies under `.claude/skills/`.

**Launcher behaviour:** Timon's `cc` shares a task list per worktree (`CLAUDE_CODE_TASK_LIST_ID`), so restarting a session in the same worktree keeps task continuity.

## Development Workflow

### Before starting work

```bash
git branch --show-current  # verify not on main
```

If on main, create a feature branch or use a worktree.

**For Linear-tracked work** (preferred — enables auto-linking):
```bash
# 1. Create Linear issue first (via /ticket or Linear UI)
# 2. Use the issue's gitBranchName (e.g., tvanrensburg/ard-168-feature-name)
git worktree add ../quinlan-ard-168 -b tvanrensburg/ard-168-feature-name
```

This enables:
- PR auto-links to Linear issue on creation
- Issue auto-closes to Done when PR merges

**For ad-hoc work** (no Linear issue):
```bash
git worktree add ../quinlan-<task> -b feat/<task>
```

**If you forgot to use Linear's branch name:** Add `Closes ARD-###` to PR description.

### Testing

```bash
uv run pytest                                    # all tests
uv run pytest packages/research/tests -k test_x  # single test
uv run ruff check .                              # lint
uv run lint-imports                              # architecture boundaries
```

### Before committing

1. Run relevant tests
2. Check lint: `uv run ruff check .`
3. Verify imports: `uv run lint-imports`

### PR workflow

1. Push branch, create PR via `gh pr create`
2. Wait for Gemini/Claude automated review
3. Address review comments
4. Merge after approval

### Worktree merge workflow

**Use `/merge` for all PR merges.** It handles worktree checkout, captures changelog entries for `/update`, and cleans up.

```bash
/merge 235          # Merge PR #235 with changelog capture
/merge              # Merge PR for current branch
```

For trivial PRs (docs, typos) where changelog isn't needed:
```bash
git checkout main && git pull origin main
gh pr merge <PR> --squash --delete-branch
```

**Worktree layout:**
```
C:/Projects/quinlan/              ← main clone (main branch)
C:/Projects/quinlan-<feature>/    ← worktrees for feature branches
```

**Cleanup commands:**
```bash
git worktree list                 # See all worktrees
git worktree remove ../quinlan-x  # Remove worktree (deletes folder if clean)
git worktree prune                # Clean up stale git references
```

**Gotcha — orphaned folders:** `git worktree remove` refuses to delete folders with uncommitted changes, and `git worktree prune` only cleans git's internal tracking. This leaves orphaned folders that `git worktree list` doesn't show but still exist on disk.

**Full cleanup after merge:**
```bash
git worktree remove ../quinlan-x        # Try git's removal first
rm -rf ../quinlan-x                     # Force delete if folder remains
git branch -d feat/x                    # Delete the local branch
```

**Periodic housekeeping:** Compare `git worktree list` against `ls ../quinlan-*` to find orphans.

**After merge:** The worktree now has `main` checked out — ready for your next feature, or remove it if done.

## dbt Workflow

```bash
dbt run --select model_name    # build to QUINLAN_DEV (safe)
dbt test                       # run tests
dbt run --target prod          # production (use sparingly)
```

**Guardrails:**
- Prefer `uv run dbt ...` to ensure the right env.
- Avoid `+` selectors on prod unless explicitly requested.
- Keep prod runs minimal and targeted (`--select model_a model_b`).

Use `snowdev` / `snowdrop` to manage dev clones.

## Guardrails

- **Always use `/merge` when merging PRs** — this captures changelog entries for `/update`. Skip only for trivial PRs (docs, typos).
- **Prefer PRs for main** — but direct push is allowed for trivial changes (docs, typos, config)
- Don't deploy to production without explicit approval
- Don't modify canonical views without testing downstream impact
- Keep PRs focused — one logical change per PR

## Interaction Preferences

- **Always use AskUserQuestion tool** when Timon asks to be questioned, interrogated, or wants clarifying questions. Don't just list questions in prose — use the structured tool for better UX.

---
name: start-session
description: >
  Bootstrap dev sessions from Linear tickets. Creates worktree,
  opens WezTerm tab with Claude + Codex layout, primes agents
  with ticket context. Use when starting work on one or more tickets.
argument-hint: "ARD-383 or 383 or ARD-215 ARD-383"
---

# Start Session

Bootstrap a full development session from Linear ticket references. Creates a git worktree, opens a WezTerm tab with the `dev` layout (Claude Code + Codex), primes agents with ticket context, and moves the ticket to In Progress.

**For Timon only.** Platform: Windows native (Git Bash + WezTerm).

## Arguments

```
/start-session ARD-383
/start-session 383
/start-session ARD-215 ARD-383
/start-session 215 383
```

Flexible input: full identifiers (`ARD-383`), bare numbers (`383`), or mixed. Space-separated for multiple tickets. Each ticket gets its own worktree and WezTerm tab.

## Prerequisites

- WezTerm running with at least one window open
- Linear MCP available (for ticket resolution and status updates)
- Git access to quinlan repo (current session must be in a quinlan worktree)
- `dev` function available in shell (from quinlan-shell modules — launches Claude Code + Codex layout)
- Run this skill from **Windows Git Bash** in a Windows worktree path (`E:/...`), not from WSL or `/mnt/...`

## Workflow

Process each ticket through all phases before moving to the next.

### Phase 0: Platform + Path Preflight (hard guard)

Before resolving tickets, validate the runtime context:

```bash
UNAME_S="$(uname -s)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
```

Fail fast and stop if either is true:

- Not Windows Git Bash (`$UNAME_S` is not `MINGW*` or `MSYS*`)
- Repo root is a Linux path (`/home/...` or `/mnt/...`)

When this guard fails, print a clear instruction and do not continue:

```text
start-session must run from Windows Git Bash in a Windows worktree path (for example E:/projects/main_workspace/quinlan-ard-483).
Do not run start-session from WSL or /mnt paths.
```

### Phase 1: Parse and Resolve Tickets

1. **Normalise input** — Convert all references to `ARD-{N}` format:
   - `383` → `ARD-383`
   - `ard-383` → `ARD-383`
   - `ARD-383` → already normalised

2. **Fetch from Linear** — For each normalised identifier:
   - `mcp__linear__get_issue` with the identifier, `includeRelations: true`
   - Extract: `id` (UUID), `identifier`, `title`, `gitBranchName`, current `state`
   - If not found: warn and skip that ticket
   - If state is Done or Cancelled: warn and ask before proceeding

3. **Derive worktree directory name** — `quinlan-ard-{N}` (lowercase number only, e.g. `quinlan-ard-383`)

### Phase 2: Worktree Setup

Resolve the main repo root via `git rev-parse --show-toplevel`. Worktrees are sibling directories to the main repo.

**Critical: always use absolute paths for worktree creation.** Relative paths resolve from cwd, which may be a subdirectory — this creates the worktree inside the repo instead of beside it.

Compute the absolute worktree path:
```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKTREE_PATH="$(dirname "$REPO_ROOT")/quinlan-ard-{N}"
```

1. **Check existing worktrees** — `git worktree list`
   - If a worktree already exists at `$WORKTREE_PATH`:
     - Check its branch matches `gitBranchName` from Linear
     - **Match:** reuse it, report "Reusing existing worktree"
     - **Mismatch:** warn user with current vs expected branch, ask whether to proceed or recreate

2. **Create new worktree** (if it doesn't exist):

   Try in order until one succeeds:

   ```bash
   # Branch doesn't exist yet — create it
   git worktree add "$WORKTREE_PATH" -b {gitBranchName}

   # Branch already exists locally — check it out
   git worktree add "$WORKTREE_PATH" {gitBranchName}

   # Branch exists on remote only — fetch and create local tracking branch
   git fetch origin {gitBranchName}
   git worktree add "$WORKTREE_PATH" -b {gitBranchName} origin/{gitBranchName}
   ```

3. **No `gitBranchName` from Linear** — If the field is empty or null, derive one:
   `tvanrensburg/ard-{N}-{slugified-title}` (lowercase, hyphens, max ~60 chars)

### Phase 3: Write Prompt Files + Launch

Both Claude Code and Codex support initial prompts via file convention. Write both prompt files to the **Windows worktree root** — `dev` handles copying the Codex prompt to WSL internally.

1. **Write `.claude-init-prompt`** to the worktree root (Claude template below)
2. **Write `.codex-init-prompt`** to the worktree root (Codex template below)
3. **Spawn a new WezTerm tab** in the worktree's Timon workspace (so `dev` resolves git context correctly):

   ```bash
   pane_id=$(wezterm cli spawn --cwd "$WORKTREE_PATH/workspaces/timon")
   ```

4. **Wait for shell init, then launch dev layout.** The shell runs `auto-env.sh` on entry which may trigger `uv sync`, and `dev` now performs a dotfiles sync gate unless you pass `--no-sync` — this can take several seconds. Wait long enough for the prompt to be ready:

   ```bash
   sleep 5
   wezterm cli send-text --no-paste --pane-id "$pane_id" -- $'dev\n'
   ```

   `dev` handles the full layout: splits into 2 panes (Claude Code | Codex), copies `.codex-init-prompt` from Windows to WSL, mirrors the WSL worktree, and starts both tools. `cc` picks up `.claude-init-prompt`; the codex launch command picks up `.codex-init-prompt`. Both launch directly into the priming task.

#### Claude Priming Prompt Template

Substitute `{IDENTIFIER}` and `{TITLE}` from the resolved Linear ticket:

```
You are starting work on Linear ticket {IDENTIFIER} ("{TITLE}"). This is a fresh session — orient yourself before writing code.

1. Fetch the full ticket: use mcp__linear__get_issue for {IDENTIFIER}, then mcp__linear__list_comments to read all discussion
2. Understand the scope: what is being asked, what has been discussed, decisions already made
3. Scan the relevant codebase — let the ticket description and comments guide which files and packages matter
4. Present a brief summary: what the ticket asks for, what you found, and your proposed approach

Do not start implementation until you have presented your understanding and I have confirmed.
```

#### Codex Priming Prompt Template

Codex doesn't have Linear MCP, so the prompt focuses on codebase orientation:

```
You are starting work on Linear ticket {IDENTIFIER} ("{TITLE}"). Orient yourself before writing code.

1. Read CLAUDE.md and workspaces/timon/CLAUDE.md for project context
2. Scan the relevant codebase — the ticket title should guide which files and packages matter
3. Present a brief summary of what you found and wait for instructions

Do not start implementation until you receive explicit direction.
```

### Phase 5: Update Linear Status

For each ticket, update state based on the current state:

| Current state | Action |
|---------------|--------|
| `Todo` or `Backlog` | `mcp__linear__save_issue(id: "<uuid>", state: "In Progress")` |
| `In Progress` or `In Review` | Skip — already active |
| `Done` or `Cancelled` | Already warned in Phase 1 |

### Phase 6: Report

Present a summary table after all tickets are processed:

```
Session setup complete:

| Ticket  | Branch                          | Worktree        | Status        | Primed |
|---------|---------------------------------|-----------------|---------------|--------|
| ARD-383 | tvanrensburg/ard-383-feature    | quinlan-ard-383 | → In Progress | Yes    |
| ARD-215 | tvanrensburg/ard-215-fix        | quinlan-ard-215 | Already active| Yes    |
```

Include any warnings or errors encountered during processing.

## Edge Cases

| Situation | Handling |
|-----------|----------|
| Worktree exists, different branch | Warn with current vs expected branch. Ask: reuse, delete and recreate, or skip |
| WezTerm not running | Detect spawn failure, suggest opening WezTerm first |
| Linear MCP unavailable | Fall back to manual input — ask Timon for branch name and ticket title |
| Ticket already Done | Warn and ask "This ticket is marked Done. Start a session anyway?" |
| No `gitBranchName` from Linear | Derive branch name: `tvanrensburg/ard-{N}-{slugified-title}` |
| Multiple tickets | Process sequentially. Each gets its own worktree and tab. Report all at end |
| Branch exists but no worktree | Use `git worktree add` without `-b` flag |
| Session started from WSL or `/mnt/...` path | Hard-stop in Phase 0 and instruct rerun from Windows Git Bash with `E:/...` repo path |
| Spawn succeeds but `dev` fails | Prompt files remain; next manual `cc`/`dev` in that worktree picks them up |

## What This Skill Does NOT Do

- **Run inside the spawned session** — it orchestrates from the current (main) session
- **Replace `dev 2`** — it delegates to `dev 2` for the actual layout and tool startup
- **Manage WSL worktrees** — `dev 2` handles WSL mirroring internally
- **Close or clean up sessions** — use `git worktree remove` when done

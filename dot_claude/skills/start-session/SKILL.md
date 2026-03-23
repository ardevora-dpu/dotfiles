---
name: start-session
description: >
  Bootstrap dev sessions from Linear tickets. Creates worktrees, primes agents
  with full ticket context and a critical thinking gate, launches WezTerm tabs
  with Claude Code + Codex. Use when starting work on one or more tickets.
argument-hint: "ARD-383 or 383 or ARD-215 ARD-383"
---

# Start Session

Bootstrap development sessions from Linear tickets. Each ticket gets an isolated git worktree, a WezTerm tab with the `dev` layout (Claude Code + Codex), and a dynamically crafted priming prompt that injects full ticket context and forces independent verification before implementation.

**For Timon only.** Platform: Windows native (Git Bash + WezTerm).

## Arguments

```
/start-session ARD-383
/start-session 383
/start-session ARD-215 ARD-383
/start-session 215 383
```

Flexible: full identifiers, bare numbers, or mixed. Space-separated for multiple.

## Workflow

### Phase 0: Preflight

Validate before doing anything:

```bash
UNAME_S="$(uname -s)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
```

**Hard stop** if not Windows Git Bash (`MINGW*`/`MSYS*`) or repo root is a Linux path. Print:

```
start-session must run from Windows Git Bash in a Windows worktree path.
```

Then **update main** to ensure worktrees branch from the latest code:

```bash
git fetch origin && git checkout main && git pull origin main
```

### Phase 1: Parse and Resolve

Normalise all inputs to `ARD-{N}` format, then fetch each ticket from Linear with `mcp__linear__get_issue` (includeRelations: true) and `mcp__linear__list_comments`.

Extract per ticket: identifier, title, description, labels, priority, gitBranchName, status, createdBy, relations (blockers, related), all comments.

If a ticket is Done or Cancelled, warn and ask before proceeding.

### Phase 2: Parallel Setup (Agent Team)

**Spawn one named Agent per ticket, all in a single message.** Each agent handles everything for its ticket independently. Name agents by ticket number (e.g., `ard-510`).

Each agent receives a prompt containing:
- The full ticket data (from Phase 1)
- Instructions for the setup steps below

#### What each agent does:

**2a. Create worktree**

Worktrees are siblings to the main repo at `$(dirname "$REPO_ROOT")/quinlan-ard-{N}`.

- Check `git worktree list` — reuse if it exists with the matching branch
- Otherwise create: try `-b {branch}` first, then bare `{branch}`, then `fetch origin + tracking branch`
- If no `gitBranchName` from Linear, derive: `tvanrensburg/ard-{N}-{slugified-title}`

**2b. Propagate settings**

Copy both settings files from the git root to `$WORKTREE_PATH/workspaces/timon/.claude/`:

```bash
cp "$REPO_ROOT/.claude/settings.json" "$WORKTREE_PATH/workspaces/timon/.claude/settings.json"
cp "$REPO_ROOT/.claude/settings.local.json" "$WORKTREE_PATH/workspaces/timon/.claude/settings.local.json"
```

This prevents the MCP server approval popup in new worktrees.

**2c. Craft the priming prompt**

Build a dynamic prompt from the ticket data. See the **Priming Prompt** section below — this is the most important part of the skill.

**2d. Write prompt files + launch tab**

The `dev` function natively reads init prompt files from the worktree root and passes them to each tool at launch. Write the **same prompt** to both files:

```bash
# Delete any stale prompt files from prior runs first
rm -f "$WORKTREE_PATH/.claude-init-prompt" "$WORKTREE_PATH/.codex-init-prompt"

# Write the crafted prompt to BOTH files (same content, model-agnostic)
# .claude-init-prompt → picked up by cc (Claude Code)
# .codex-init-prompt  → picked up by dev's codex launcher
```

Then spawn a WezTerm tab, wait for shell init, and launch `dev`:

```bash
pane_id=$(wezterm cli spawn --cwd "$WORKTREE_PATH/workspaces/timon")
sleep 5
wezterm cli send-text --no-paste --pane-id "$pane_id" -- $'dev\n'
```

`dev` handles the rest: reads the prompt files, passes them to each tool, and deletes the files after reading. No `send-text` prompt delivery needed — the file convention is the primary mechanism.

**2f. Update Linear status**

Move `Todo` or `Backlog` tickets to `In Progress`. Skip if already active.

**2g. Report back**

Return: ticket ID, branch, worktree path, status change, any warnings.

### Phase 3: Collect and Report

After all agents complete, present a summary table:

```
| Ticket  | Branch               | Worktree        | Status         | Primed |
|---------|--------------------- |-----------------|----------------|--------|
| ARD-510 | timon/ard-510-...    | quinlan-ard-510 | Already active | Yes    |
| ARD-551 | timon/ard-551-...    | quinlan-ard-551 | → In Progress  | Yes    |
```

Include any warnings (blockers, Done tickets, missing branches).

---

## Priming Prompt

The orchestrating Claude crafts this dynamically from real ticket data. Both Claude Code and Codex in the worktree receive the **same prompt** — it must be model-agnostic (no MCP-specific instructions).

### Structure

The prompt has four sections. Adapt the tone and emphasis based on what you find in the ticket.

#### 1. Context Injection

Embed the full ticket content so the agent starts fully informed:

- **Ticket ID, title, priority, due date** (if set)
- **Full description** — the complete text, not a summary
- **Labels** — these signal ticket type (Bug, research-harness, Improvement, etc.)
- **Related tickets** — with titles, so the agent understands the neighbourhood
- **Blockers** — with current status (is the blocker resolved?)
- **All comments** — discussion often contains decisions not in the description
- **Branch name** — so the agent knows where it is
- **Created by** — signals whether this is Timon's own ticket or from Jeremy/Jack

#### 2. Critical Thinking Gate

This section prevents the agent from treating the ticket as gospel.

The core instruction: **"This ticket was written by an AI agent in a previous session. Treat the problem statement and any proposed approach as a hypothesis, not a confirmed diagnosis."**

Adapt the framing based on ticket type:

- **Bug tickets** (labels: Bug, data-quality): "Show evidence you can reproduce or locate the failure. What alternative root causes exist? Could the problem be upstream or downstream of where the ticket points?"
- **Research/evaluation tickets** (labels: research-harness, Improvement, or description contains 'evaluate', 'assess', 'audit'): "Survey the landscape beyond this ticket. What does the broader ecosystem look like? Use web search and codebase exploration to understand the taxonomy of the problem."
- **Implementation tickets** (clear specs, no ambiguity): "Show you understand the current state and blast radius. Is this the simplest approach that works?"
- **All tickets**: "Take a holistic view. What hasn't been considered?"

#### 3. Origin Trace (conditional)

Include this section **only when the ticket content signals external origins:**

- Description references a meeting, call, or specific date in a "Context" section
- Description says "discussed", "agreed", "decided" without full inline context
- Ticket was created by someone other than the assignee (e.g., Jack or Jeremy created it for Timon)

When triggered: "This ticket references external discussion that may not be fully captured. Search for the original source — Otter transcripts, email threads, Teams messages — to ensure you have the complete picture."

When NOT triggered: omit this section entirely.

#### 4. Verification Gate

The final instruction, always present:

"Present your independent assessment before proposing any approach. Show what you verified, what evidence you found, and whether you agree with the ticket's framing. Do not start implementation until you have presented your understanding and it has been confirmed."

### Example (what a crafted prompt looks like)

For ARD-558 ("Tech stack audit: updated service list for forecast"):

```
## Linear Ticket ARD-558: Tech stack audit: updated service list for forecast

**Priority:** Unset | **Due:** 2026-03-16 (overdue) | **Labels:** none
**Branch:** timon/ard-558-tech-stack-audit-updated-service-list-for-forecast
**Created by:** Jack Algeo (j.algeo@ardevora.com)

### Description
[full description text here]

### Blockers
- ARD-604: "Grant Timon read-only Xero access for central spend tracking" — Status: [current status]

### Related tickets
[none]

### Comments
[all comments]

---

## Your task

This ticket was written based on a team meeting. Treat the scope and approach as a starting hypothesis.

This ticket references a meeting (3 Mar 2026) and was created by Jack, not the assignee. Search for the original meeting context — check Otter transcripts and email threads around that date to understand what was actually discussed and agreed.

Before proposing an approach:
- Check whether the blocker (ARD-604, Xero access) has been resolved
- Survey what services and costs are already documented anywhere in the codebase or prior audit outputs
- Consider whether the scope described matches what was actually agreed in the meeting

Present your independent assessment. Do not start work until your understanding has been confirmed.
```

---

## Edge Cases

| Situation | Handling |
|-----------|----------|
| Worktree exists, wrong branch | Warn with current vs expected. Ask: reuse, recreate, or skip |
| WezTerm not running | Detect spawn failure, suggest opening WezTerm |
| Linear MCP unavailable | Ask Timon for branch name and title manually |
| Ticket is Done/Cancelled | Warn and ask before proceeding |
| No `gitBranchName` from Linear | Derive: `tvanrensburg/ard-{N}-{slugified-title}` |
| `settings.local.json` missing at root | Skip propagation, warn (MCP approval will prompt) |
| Agent team member fails | Report the failure, continue with remaining tickets |
| `dev` fails to launch | Prompt files remain; next manual `dev` in that worktree picks them up |

## What This Skill Does NOT Do

- Run inside the spawned sessions — it orchestrates from the current session
- Manage WSL worktrees — `dev` handles WSL mirroring
- Close or clean up sessions — use `git worktree remove` when done
- Prescribe which tools the primed agents should use — agents choose based on the problem

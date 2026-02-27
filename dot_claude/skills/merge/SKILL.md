---
name: merge
description: Merge PRs with changelog capture. Timon-only — consolidates the merge workflow and captures changelog entries for /update.
---

# Merge Skill

Merge PRs while capturing structured changelog entries for `/update`.

**For Timon only.** This skill consolidates the manual merge workflow and ensures changelog entries are captured.

**Platform:** Windows native (Git Bash)

## Why This Skill Exists

When PRs merge, `/update` needs to know what changed so Jeremy sees a good report.
Previously, `/update` ran a slow sub-agent to infer changes from diffs.
Now, **you draft the changelog at merge time** — faster, more accurate, human-curated.

## Arguments

```
/merge <PR_NUMBER>
/merge              # Defaults to PR for current branch
```

## Workflow

```
1. Identify PR → get number, verify it exists
2. Analyze PR → read diff, Linear issue, PR description
3. Draft changelog → propose Highlights + Technical bullets
4. Refine → Timon edits/approves the draft
5. Execute → commit changelog, merge PR, notify Jeremy (optional), cleanup
```

---

## Phase 1: Identify PR

If PR number provided, use it. Otherwise, find PR for current branch:

```bash
# Get current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Find PR for this branch
gh pr list --head "$BRANCH" --json number,title,state --jq '.[0]'
```

**Verify PR exists and is open.** If no PR found, tell user:

> "No open PR found for branch `{branch}`. Create one with `gh pr create` first."

---

## Phase 2: Analyze PR

Gather context to draft a good changelog entry:

### 2.1 Get PR details

```bash
gh pr view $PR_NUMBER --json title,body,files,commits,labels
```

### 2.2 Get the diff

```bash
gh pr diff $PR_NUMBER
```

### 2.2a Large PRs — don't miss anything

For large PRs where you can't confidently capture all changes from a single pass, spawn parallel Explore agents to review different parts of the diff. Look at the actual files changed and decide how to split — by package, by theme, by layer, whatever makes sense for that specific PR. Each agent should return a summary + bullet list of changes + whether anything is user-facing.

**The goal:** Never miss a refactor, schema change, or workflow impact that matters to Jeremy's research. A missed changelog bullet is better than a missed breaking change — use agents when the diff is too large to hold in your head comfortably.

### 2.3 Check for Linear issue

Extract issue ID from branch name (e.g., `tvanrensburg/ard-173-...` → `ARD-173`):

```bash
echo "$BRANCH" | grep -oE 'ard-[0-9]+' | head -1 | tr '[:lower:]' '[:upper:]'
```

If found, use Linear MCP to get issue details:
- Title and description
- Priority (helps classify as highlight vs technical)

### 2.4 Categorize the changes

Based on files changed, classify into:

| Category | File patterns | Goes in |
|----------|---------------|---------|
| **highlight** | `.claude/skills/**`, `warehouse/models/**`, `workspaces/jeremy/scripts/**`, user-facing fixes | Highlights section |
| **technical** | `packages/**`, `setup/**`, `.github/**`, `scripts/dev/**`, infra | Also shipped section |

---

## Phase 3: Draft Changelog

Using the analysis, draft a changelog entry. Present it to Timon for review:

```
Looking at PR #235: feat(update): add state tracking for reliable changelog

Here's what I'd add to the changelog:

┌─────────────────────────────────────────────────────────────────┐
│ HIGHLIGHTS                                                       │
│                                                                  │
│ **Reliable changelog with smart first-run detection**           │
│                                                                  │
│ Before: /update could miss commits depending on which branch    │
│ you ran it from, or show nothing on first run.                  │
│ After: State tracking compares against origin/main with         │
│ intelligent first-run bootstrap using merge-base.               │
│ Why: You always see what's new in the platform, regardless of   │
│ which branch you're on.                                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ ALSO SHIPPED (technical)                                         │
│                                                                  │
│ - Added ~/.quinlan-update-state.json for tracking last-seen ref │
│ - Refactored Phase 4 to read from CHANGELOG.json                │
└─────────────────────────────────────────────────────────────────┘

Edit this, or say "go" to merge.
```

### Writing Guidelines

**For Highlights:**
- Use **Before → After → Why** format
- Write for Jeremy (what does this mean for his research workflow?)
- One highlight per significant user-facing change
- Skip if the PR is purely technical

**For Technical bullets:**
- One-liner per change
- No explanation needed — just a receipt
- Include all non-highlight changes

**If PR is purely technical (no highlights):**

```
This looks like a technical/infrastructure PR with no user-facing changes.

┌─────────────────────────────────────────────────────────────────┐
│ ALSO SHIPPED (technical)                                         │
│                                                                  │
│ - Refactored scanner package to use new API                     │
│ - Updated Python to 3.11.13                                     │
└─────────────────────────────────────────────────────────────────┘

Edit this, or say "go" to merge.
```

---

## Phase 4: Refine

Wait for Timon's response. Handle:

| Response | Action |
|----------|--------|
| "go" / "yes" / "looks good" | Proceed to Phase 5 |
| Edits or corrections | Update the draft and re-present |
| "skip changelog" | Proceed to merge without changelog entry |
| Questions | Answer, then re-present draft |

**This is a conversation, not a form.** Iterate until Timon is happy.

---

## Phase 5: Execute

### 5.1 Write changelog fragment

Write the entry as an individual fragment file at `changelog/{PR_NUMBER}.json`.

**Entry structure:**

```json
{
  "pr": 235,
  "merged_at": "2026-02-04T14:30:00Z",
  "commit": "abc123def",
  "branch": "tvanrensburg/ard-173-changelog",
  "category": "highlight",
  "headline": "Reliable changelog with smart first-run detection",
  "highlight": {
    "title": "Reliable changelog with smart first-run detection",
    "before": "/update could miss commits depending on branch",
    "after": "State tracking compares against origin/main",
    "why": "You always see what's new in the platform"
  },
  "technical_bullets": [
    "Added ~/.quinlan-update-state.json for tracking",
    "Refactored Phase 4 to read from CHANGELOG.json"
  ],
  "author": "timon"
}
```

For technical-only PRs (no highlight):

```json
{
  "pr": 230,
  "merged_at": "2026-02-04T10:00:00Z",
  "commit": "def456abc",
  "branch": "feat/infra-cleanup",
  "category": "technical",
  "headline": "Infrastructure cleanup. 1 PR.",
  "highlight": null,
  "technical_bullets": [
    "Removed unused packages/signals/",
    "Updated Python to 3.11.13"
  ],
  "author": "timon"
}
```

### 5.2 Commit the changelog

```bash
git add changelog/$PR_NUMBER.json
git commit -m "changelog: PR #$PR_NUMBER - $HEADLINE"
git push origin HEAD
```

### 5.3 Merge the PR

```bash
gh pr merge $PR_NUMBER --squash --admin
```

**Why no `--delete-branch`:** GitHub auto-deletes remote head branches on merge (repo setting). The `--delete-branch` flag also tries to `git checkout main` locally, which fails in worktrees because main is already checked out in the primary clone.

**Why `--admin`:** By the time `/merge` runs, Timon has already reviewed agent feedback and approved. The changelog commit (5.2) hasn't been CI-reviewed yet, which triggers branch protection. `--admin` bypasses this safely since the substantive code was already approved.

### 5.4 Notify Jeremy

After a successful merge, **always** draft a notification and present it for review.

**Step 1 — Draft the message:**

Compose a short Linear comment based on the changelog entry. Format:

> @j.lang Shipped in PR #235 — **{headline}**
>
> {Before → After → Why summary, if highlight exists. Otherwise 1-2 technical bullets.}
>
> Available on your next `/update`.

**Step 2 — Present and ask:**

Present the draft to Timon via `AskUserQuestion`:
- "Send this to Jeremy on {ARD-XXX}?"
- Options: **"Send"** / **"Edit (I'll rewrite)"** / **"Skip"**

If "Edit" — Timon provides replacement text, re-present for confirmation.
If "Send" — post the comment on the linked Linear issue using `mcp__linear__create_comment`, @mentioning `@j.lang`.
If "Skip" — move on.

**If no linked Linear issue:** Still draft the message and ask. If Timon wants to send it, ask which Linear issue or channel to use.

### 5.5 Report success

```
✓ Changelog committed
✓ PR #235 merged (squash)
✓ Remote branch auto-deleted by GitHub
✓ Jeremy notified on ARD-173        ← only if sent

Next /update will show:
  Highlights: "Reliable changelog with smart first-run detection"
  Technical: 2 items
```

---

## If Merge Fails

If `gh pr merge` fails (e.g., checks not passing, conflicts):

> "PR merge failed: {error}. The changelog entry has been committed but not merged.
> Fix the issue and run `gh pr merge $PR_NUMBER --squash --admin` manually."

Don't roll back the changelog commit — it's harmless if the merge happens later.

---

## Skipping Changelog

If Timon says "skip changelog" or the PR is trivial:

```bash
# Skip straight to merge
gh pr merge $PR_NUMBER --squash --admin
```

> "Merged without changelog entry. Note: /update won't show this PR."

This is fine for docs fixes, typos, etc.

---

## Examples

### Example 1: Feature PR with highlight

```
Timon: /merge 235

Claude: Looking at PR #235: feat(update): add state tracking...

        [Draft with Highlights + Technical]

Timon: The headline should mention "for Jeremy" — make it clearer who benefits

Claude: Updated:

        **Reliable changelog so Jeremy always sees what's new**

        [Rest of draft]

Timon: go

Claude: ✓ Changelog committed
        ✓ PR #235 merged
        ✓ Remote branch auto-deleted by GitHub

        Notify Jeremy about this merge?  [Yes, draft a message] [Skip]

Timon: Yes

Claude: Here's the draft for ARD-173:

        @j.lang Shipped in PR #235 — **Reliable changelog so Jeremy
        always sees what's new**

        Before: /update could miss commits depending on branch.
        After: State tracking compares against origin/main.

        Available on your next /update.

        Send this to Jeremy on ARD-173?  [Send] [Edit] [Skip]

Timon: Send

Claude: ✓ Jeremy notified on ARD-173
```

### Example 2: Technical-only PR

```
Timon: /merge 230

Claude: Looking at PR #230: chore: remove unused packages...

        This looks purely technical with no user-facing changes.

        ┌───────────────────────────────────────────────┐
        │ ALSO SHIPPED                                  │
        │ - Removed packages/signals/ (now in dbt)     │
        │ - Updated ruff to 0.8.0                      │
        └───────────────────────────────────────────────┘

Timon: go

Claude: ✓ Changelog committed
        ✓ PR #230 merged
```

### Example 3: Skipping changelog

```
Timon: /merge 228

Claude: Looking at PR #228: docs: fix typo in README...

        This is a trivial docs change. Skip changelog?

Timon: yes skip

Claude: ✓ PR #228 merged (no changelog entry)
```

---

## What This Skill Does NOT Do

- **Create PRs** — use `gh pr create` for that
- **Run tests** — assume PR checks have passed
- **Handle conflicts** — if merge conflicts exist, the PR should be updated first
- **Work for Jeremy** — this skill is Timon-only

## Visibility

This skill is in `.claude/skills/merge/` and visible in the skill list. However:
- The description says "Timon-only"
- Jeremy's context doesn't include merge workflows
- If Jeremy accidentally invokes it, politely redirect: "This skill is for platform maintenance. Is there something else I can help with?"

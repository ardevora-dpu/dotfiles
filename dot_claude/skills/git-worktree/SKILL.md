---
name: git-worktree
description: >
  Git workflow safety and isolation patterns. Use for any git operations,
  branch management, or parallel development. Includes session isolation,
  git safety automation, and worktree management.
---

# Git Workflow & Isolation

This skill covers git safety patterns for AI agents and worktree management for parallel development.

## Session Isolation (Multi-Agent Awareness)

Multiple Claude/Codex sessions can run in parallel. Without isolation:
- Sessions on the same checkout contaminate each other
- Changes intended for one branch land on another
- Context bleeds between unrelated tasks

### Before starting significant work:

1. **Check current branch**: `git branch --show-current`
2. **If on main/master** and the task involves code changes:
   - Offer: "Create a worktree for isolated work, or create a branch here?"
3. **If on a feature branch**: Verify it's the *right* branch for this task

### Before reviewing a PR:

1. **Check if current branch matches PR branch**
2. **If mismatch**: Offer worktree for isolated review
3. **If match**: Proceed directly

## Git Command Safety (Automation Pattern)

Claude Code / Codex is automation, not a human terminal session. Apply CI/CD patterns:

### Always verify branch before mutations:

```bash
# Pattern: checkout && operation (checkout is idempotent if already there)
git checkout <branch> && git add <files> && git commit -m "..."
git checkout <branch> && git push
```

### Why:

- Bash state can drift between tool calls (known behaviour)
- Every CI/CD pipeline does explicit checkout before git operations
- Explicit checkout documents intent and prevents cross-branch contamination
- Cost: ~0.1s latency. Benefit: guarantees correct target.

### Don't:

```bash
# Separate calls - state may drift
git checkout feat/x      # Call 1
git add . && git commit   # Call 2 - might be on wrong branch!
```

### Force-push safety

When amending or rebasing, always use `--force-with-lease` instead of `--force`:

```bash
# Safe: fails if remote has changed since your last fetch
git push --force-with-lease

# Unsafe: blindly overwrites remote, can lose others' work
git push --force  # AVOID
```

**Why this matters for agents:**
- Multiple sessions can run in parallel on the same branch
- `--force` silently overwrites; `--force-with-lease` fails safely if the remote changed
- The failure is cheap (just fetch and retry); the alternative is lost work

**When raw `--force` is acceptable:**
- Intentionally discarding remote state (rare, requires explicit user request)
- The branch is exclusively yours and you're certain no other session touched it

### After merging a PR:

`gh pr merge --delete-branch` only removes the **remote** branch. Clean up locally:

```bash
git checkout main && git pull && git branch -d <branch>
```

Or prune all stale local branches at once:

```bash
git fetch --prune && git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -d
```

## Worktree Management

Worktrees provide physical isolation — each session has its own directory.

### Directory Pattern

Worktrees are created as **sibling directories** to your main repo:

```
~/projects/
├── quinlan/                    # Main repo
├── quinlan-feat-auth/          # Worktree for feat/auth branch
└── quinlan-fix-bug/            # Worktree for fix/bug branch
```

**Why siblings?**
- Clean separation — worktrees aren't mixed with repo content
- No gitignore needed
- Standard pattern used by most developers

### Creating a Worktree

```bash
# From main repo
git worktree add ../quinlan-<branch> -b <branch>

# Examples
git worktree add ../quinlan-feat-auth -b feat/auth
git worktree add ../quinlan-pr-123 -b pr-123-review
```

### Listing Worktrees

```bash
git worktree list
```

### Cleaning Up

```bash
# Remove worktree (from main repo, not from within the worktree)
git worktree remove ../quinlan-<branch>

# Also delete the branch if done with it
git branch -d <branch>
```

### Workflow Example: Isolated PR Review

```bash
# From main repo, create worktree for review
git fetch origin
git worktree add ../quinlan-pr-review origin/feat/some-feature

# Switch to it
cd ../quinlan-pr-review

# Do your review work...

# When done, return to main and cleanup
cd ../quinlan
git worktree remove ../quinlan-pr-review
```

## Technical Notes

- Worktrees are lightweight (file system links + checkout)
- No repository duplication — shared git objects
- All worktrees share git history with main repo
- Can push from any worktree
- Much faster than cloning

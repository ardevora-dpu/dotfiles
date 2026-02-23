---
name: compare-impl
description: Compare a parallel implementation (typically Codex) against your plan. Use when both agents have implemented and you want to audit gaps, divergences, and risks.
---

# Compare Implementation

Audit a parallel implementation against the plan in your current context. Designed for the two-model workflow where Claude and Codex independently implement the same ticket, then Claude reviews Codex's work.

**For Timon only.** Platform: Windows native (Git Bash).

## The Two-Model Pattern

The power here is **independent reasoning**: two models read the same ticket, form independent plans, implement independently, then one reviews the other's work against its own plan. Divergences are the interesting signal — they reveal gaps neither model would catch alone.

Typical flow:
1. Both agents read the Linear ticket and agree on outcomes
2. Both create independent plans
3. Both implement (Claude on Windows, Codex in WSL, shared worktree)
4. Timon invokes `/compare-impl` in a **fresh Claude context** with just the plan
5. Claude pulls Codex's changes from remote, audits against the plan

## Invocation

```
/compare-impl
/compare-impl <codex-output-pasted-below>
```

No arguments needed — the skill infers everything from context:
- **Plan:** Already in the current conversation (provided before invoking)
- **Branch:** Current worktree branch (should match the Linear ticket)
- **Codex changes:** Pulled from the same remote branch

If Timon pastes Codex's output/summary alongside the command, use that as additional context for what Codex intended.

## Workflow

### Step 1: Gather Context

1. **Read the plan** from the current conversation context. Identify:
   - Each discrete change/touch point
   - Expected files and locations
   - Stated out-of-scope items
   - Verification criteria

2. **Find Codex's changes.** The branch is shared — pull from remote:
   ```bash
   git fetch origin
   git log --oneline HEAD..origin/<current-branch>
   ```
   If there are new commits, pull them. Read the diffs to understand what Codex changed.

3. **Read the Linear ticket** (if ARD-xxx is in the branch name) for the original requirements. Use `mcp__linear__get_issue` with the ticket identifier.

### Step 2: Audit

For each touch point in the plan:

1. **Check if addressed** — Did Codex make the change? Read the relevant file.
2. **Check correctness** — Does the change achieve the stated outcome?
3. **Check for side effects** — Did Codex change something outside the plan scope?
4. **Note divergences** — If Codex took a different approach, assess whether it's:
   - Equivalent alternative (fine)
   - Improvement over the plan (note it)
   - Gap or omission (flag it)
   - Risk or regression (flag urgently)

Also check:
- **Unstated work** — Did Codex add changes not in the plan? Are they helpful or scope creep?
- **Test coverage** — If the plan requires tests, did Codex add them? Do they cover the right cases?
- **Verification criteria** — Can the stated verification steps still pass?

### Step 3: Discuss

Use `AskUserQuestion` to walk through findings interactively. Don't dump a wall of text — present the most interesting divergences as structured choices so Timon can decide which need action.

Good questions to surface:
- "Codex did X differently from the plan. Here's why it might be fine / might be a problem. Which interpretation do you want to go with?"
- "The plan called for Y but Codex skipped it. Is this still needed?"
- "Codex added Z which wasn't in the plan. Keep, modify, or remove?"

### Step 4: Report

After discussion, produce a concise summary:
- What was implemented correctly
- What diverged (and whether accepted after discussion)
- What's missing and needs follow-up
- Any new risks discovered

## When to Use a Team

For large changes (many files, multiple packages, or cross-cutting concerns), suggest using `TeamCreate` to parallelise the audit — e.g., one agent reviews code changes while another reviews docs/tests. The lead agent synthesises findings.

## Guiding Principles

- **Codex is allowed to diverge.** Different is not wrong. Only flag divergences that create risk or miss requirements.
- **The plan is the contract, not a script.** Judge outcomes, not exact steps.
- **Be specific.** Reference file paths and line numbers when flagging issues.
- **Don't over-report.** If everything looks good, say so briefly. The value is in catching gaps, not narrating the obvious.
- **Fresh eyes matter.** You're in a clean context for a reason — approach the code without the sunk-cost bias of having written the plan.

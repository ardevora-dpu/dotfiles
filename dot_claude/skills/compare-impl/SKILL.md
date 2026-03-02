---
name: compare-impl
description: Compare two parallel implementations of the same ticket. Works from either agent. Outputs a handoff prompt the other agent can execute directly.
---

# Compare Implementation

Audit a parallel implementation against the plan in your current context. Designed for the two-model workflow where two agents independently implement the same ticket, then one reviews the other's work.

## The Two-Model Pattern

The power here is **independent reasoning**: two agents read the same ticket, form independent plans, implement independently, then one reviews the other's work against its own plan. Divergences are the interesting signal — they reveal gaps neither agent would catch alone.

This is essentially N-version programming: independent implementations from the same spec. When both agents make the same choice, it's strong evidence. When they diverge, that's where the real design decisions live. Be aware that agents sharing training data can make correlated mistakes — so agreements on edge cases or domain-specific logic still deserve a skeptical eye.

Typical flow:
1. Both agents read the Linear ticket and agree on outcomes
2. Both create independent plans
3. Both implement (on the same branch, shared via remote)
4. Timon invokes `/compare-impl` in the **reviewing agent** with just the plan
5. The reviewing agent pulls the other agent's changes from remote and audits against the plan

## Invocation

```
/compare-impl
/compare-impl <other-agent-output-pasted-below>
```

No arguments needed — the skill infers everything from context:
- **Plan:** Already in the current conversation (provided before invoking)
- **Branch:** Current worktree branch (should match the Linear ticket)
- **Other agent's changes:** Pulled from the same remote branch

If Timon pastes the other agent's output/summary alongside the command, use that as additional context for what it intended.

## Workflow

### Step 1: Gather Context

1. **Read the plan** from the current conversation context. Identify:
   - Each discrete change/touch point
   - Expected files and locations
   - Stated out-of-scope items
   - Verification criteria

2. **Find the other agent's changes.** The branch is shared — pull from remote:
   ```bash
   git fetch origin
   git log --oneline HEAD..origin/<current-branch>
   ```
   If there are new commits, pull them. Read the diffs to understand what the other agent changed.

3. **Read the Linear ticket** (if ARD-xxx is in the branch name) for the original requirements. Use `mcp__linear__get_issue` with the ticket identifier.

### Step 2: Audit

For each touch point in the plan:

1. **Check if addressed** — Did the other agent make the change? Read the relevant file.
2. **Check correctness** — Does the change achieve the stated outcome?
3. **Check for side effects** — Did the other agent change something outside the plan scope?
4. **Note divergences** — If the other agent took a different approach, assess whether it's:
   - Equivalent alternative (fine)
   - Improvement over the plan (note it)
   - Gap or omission (flag it)
   - Risk or regression (flag urgently)

Also check:
- **Unstated work** — Changes not in the plan? Helpful or scope creep? Track what kind of additions each agent makes — patterns reveal biases (over-engineering vs under-engineering).
- **Test strategy** — Not just "were tests added" but what do they actually assert? Watch for tests that pass but don't meaningfully validate behaviour — this is a common agent failure mode.
- **Error handling divergence** — One of the strongest quality signals. If one agent adds boundary validation the other doesn't, that's a design assumption worth surfacing.
- **Silent risks** — Code that appears correct but strips safety checks, removes defensive logic, or produces plausible-looking output without real validation. These are harder to catch than crashes and more dangerous.
- **Verification criteria** — Can the stated verification steps still pass?

### Step 3: Simplify

Before discussing divergences, look for surface area reduction across **both** implementations:
- Duplicated logic that could be consolidated
- Over-engineered abstractions where simpler code would do
- Unnecessary compatibility shims or defensive code
- Code that exists in both implementations but isn't needed by either

If running in Claude Code and `/simplify` is available, invoke it on the combined changeset. Otherwise, analyse directly and include simplification opportunities in the next step.

### Step 4: Feature Selection

Use `AskUserQuestion` to walk through findings interactively. The goal is **cherry-picking the best from both implementations**, not just flagging problems.

For each meaningful divergence, present the trade-off:
- "Your agent did X, the other agent did Y. Here's why each approach works / has risk. Which do you want to keep?"
- "The plan called for Z but the other agent skipped it. Still needed?"
- "The other agent added W which wasn't in the plan. Keep, modify, or remove?"
- "Both implementations have duplicated logic here. Simplify to one approach?"

Let Timon make each call. Track decisions as you go — they feed directly into the handoff prompt.

### Step 5: Handoff Prompt

After feature selection, produce a **self-contained imperative prompt** that the other agent can execute without ambiguity. This is the deliverable — not a report.

Structure the prompt as:

```
## Context
<One-paragraph summary: ticket, branch, what both agents implemented, key decisions Timon made>

## Keep
<Things from the other agent's implementation to preserve as-is. Be specific: file paths, function names, approach.>

## Change
<Things from the other agent's implementation that need modification. State the current state and the desired state.>

## Add
<Things from your implementation (or new requirements) that the other agent didn't include. Provide enough detail to implement without guessing.>

## Remove
<Things from the other agent's implementation to delete. Explain why — prevents the agent from re-adding them.>

## Simplify
<Consolidation opportunities across both implementations. Describe the target state, not just "simplify this".>
```

Present the prompt to Timon for review before he pastes it to the other agent. Omit any section that has no items.

## When to Use a Team

For large changes (many files, multiple packages, or cross-cutting concerns), suggest using `TeamCreate` to parallelise the audit — e.g., one agent reviews code changes while another reviews docs/tests. The lead agent synthesises findings.

## Guiding Principles

- **The other agent is allowed to diverge.** Different is not wrong. Only flag divergences that create risk or miss requirements.
- **The plan is the contract, not a script.** Judge outcomes, not exact steps.
- **Review structurally, not line-by-line.** Focus on architectural choices, scope assumptions, and edge case coverage. Leave style to linters.
- **Be specific.** Reference file paths and line numbers when flagging issues.
- **Don't over-report.** If everything looks good, say so briefly. The value is in catching gaps, not narrating the obvious.
- **Fresh eyes matter.** You're in a clean context for a reason — approach the code without the sunk-cost bias of having written the plan.
- **Skeptical agreement.** When both implementations make the same choice, that's probably right — but probe agreements on edge cases and domain logic, where correlated training-data biases can mislead both agents.
- **Output is a prompt, not a report.** The deliverable is an actionable handoff the other agent can execute, not a summary for humans to interpret.

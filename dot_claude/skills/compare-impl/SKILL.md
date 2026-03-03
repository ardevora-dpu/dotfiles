---
name: compare-impl
description: Peer-review a parallel implementation against your plan. Produces a debate-style handoff prompt for the other agent with evidence-backed feedback.
---

# Compare Implementation

Peer-review a parallel implementation against the plan in your current context. Designed for the two-model workflow where two agents independently implement the same ticket, then one reviews the other's work.

## The Two-Model Pattern

The power is **independent reasoning**: two agents read the same ticket, form independent plans, implement independently, then one reviews the other's work.

**Divergences are the most valuable output.** When two agents independently solve the same problem and arrive at different answers, that's where the real design insight lives — one agent saw a constraint the other missed, or found a better path the plan didn't consider. Spend most of your thinking time here. Agreements are quick to validate; divergences are where the review earns its keep.

This is N-version programming from the same spec. Be aware that agents sharing training data can make correlated mistakes — so even agreements on edge cases and domain-specific logic deserve a skeptical eye.

Typical flow:
1. Both agents read the Linear ticket and agree on outcomes
2. Both create independent plans
3. Both implement (on the same branch, shared via remote)
4. Timon invokes `/compare-impl` in the **reviewing agent**
5. The reviewing agent pulls the other's changes, reviews, and produces a debate-style handoff

## Invocation

```
/compare-impl
/compare-impl <other-agent-output-pasted-below>
```

No arguments needed — the skill infers everything from context:
- **Plan:** Already in the current conversation
- **Branch:** Current worktree branch (should match the Linear ticket)
- **Other agent's changes:** Pulled from the same remote branch

If Timon pastes the other agent's output/summary alongside the command, use that as additional context for what it intended.

## Workflow

### Step 1: Gather Context

1. **Read the plan** from the current conversation context. Identify each discrete touch point, expected files, out-of-scope items, and verification criteria.

2. **Find the other agent's changes.** The branch is shared — pull from remote, read the diffs.

3. **Read the Linear ticket** (if ARD-xxx is in the branch name) for the original requirements.

### Step 2: Audit

Map each plan touch point to what the other agent did:

1. **Addressed?** — Did the other agent make the change?
2. **Correct?** — Does it achieve the stated outcome?
3. **Side effects?** — Changes outside plan scope?
4. **Divergences** — Different approach? Classify as equivalent, improvement, gap, or risk.

Also check:
- **Unstated work** — Changes not in the plan. Helpful or scope creep?
- **Test strategy** — What do tests actually assert? Watch for tests that pass but don't meaningfully validate.
- **Error handling divergence** — One of the strongest quality signals.
- **Silent risks** — Code that appears correct but strips safety checks or produces plausible output without real validation.

### Step 3: Verify with Evidence

**This is critical.** Don't just reason about divergences — test them. Run code, check live state, verify claims. Evidence-backed opinions are the foundation of the handoff.

For each significant divergence:
- **Run the code** if possible (scripts, tests, linters, template rendering)
- **Check live state** (does the file exist? does the config match? does the env var resolve?)
- **Test both approaches** when feasible — the plan's approach and the other agent's approach
- **Record results** — what passed, what failed, what surprised you

If you can't test something (requires the other machine, production access, etc.), note that explicitly as a verification gap.

### Step 4: Form Opinions

Divergences are where you should spend the most time. For each one, take a position — you are a peer reviewer, not a neutral reporter:

- **Agree** — The other agent's approach is better than the plan. Say why, with evidence. This is not a consolation prize — genuinely good divergences are the whole point of independent reasoning.
- **Disagree** — The plan's approach is better. Say why, with evidence. Frame as "I'd recommend X because [evidence], but here's the counterargument."
- **Suggest alternative** — Neither approach is ideal. Propose something better.

Back every opinion with evidence from Step 3 where possible. Theoretical reasoning is fine for architectural choices, but always prefer "I tested this and found..." over "I think this might...".

Matched items (plan and implementation agree) need only brief confirmation. Don't spend equal time on agreements and divergences — the divergences are the interesting signal.

### Step 5: Surface Key Decisions

Use `AskUserQuestion` to confirm the **biggest divergences only** — the ones that change architecture, scope, or risk profile. Aim for one round, 2-4 questions max.

For each, present:
- What the other agent did vs what the plan said
- Your recommendation and why
- Frame as a recommendation to confirm, not a blank choice

Do not walk through every divergence interactively. Most should be handled by your own judgement in Step 4. Only escalate decisions where:
- Both approaches have real trade-offs and you're genuinely uncertain
- The choice has safety or irreversibility implications
- The scope change is large enough that Timon should explicitly opt in

### Step 6: Draft Handoff

Produce a **debate-style handoff prompt** for the other agent. This is the deliverable — peer feedback that invites the other agent to respond, verify, and make final decisions.

**Tone:** You are a peer, not a boss. Frame feedback as "I'd recommend..." and "consider whether...", not "do this" and "change that." The other agent made independent decisions for reasons — engage with those reasons.

Structure:

```
## Context
<One-paragraph summary: ticket, branch, what both agents implemented, what Timon confirmed>

## Agreements
<Divergences where you agree with the other agent's approach over the plan.
For each: what they did, why it's good, evidence if you tested it.
Validates good independent decisions — this matters for the collaborative dynamic.>

## Feedback
<The substantive divergences where you'd recommend a different approach.
For each:
- What you did (plan) vs what they did
- Evidence you gathered (test results, live state checks)
- Your recommendation and reasoning
- The counterargument — why their approach might be right
- Specific verification request: "please check X" or "I couldn't test Y"
Order by significance, most important first.>

## Suggestions
<Non-controversial items: omissions, minor fixes, small improvements.
Still framed as suggestions, not commands.
"I'd suggest adding X because Y.">

## Open Questions
<Things you couldn't verify or aren't sure about.
"I couldn't test whether Z works on Jeremy's machine — worth checking."
"The plan assumed A but neither of us verified it — can you confirm?">
```

Present the handoff to Timon for a final review before he sends it to the other agent. Omit any section that has no items.

### Step 7: Simplify (optional)

If both implementations together create consolidation opportunities, include them in the Suggestions section:
- Duplicated logic across both implementations
- Over-engineered abstractions where simpler code would do
- Code that exists in both but isn't needed by either

## Guiding Principles

- **The other agent is a peer.** They made independent decisions for reasons. Engage with those reasons rather than overriding them.
- **Evidence over theory.** Run the code. Check live state. Test both approaches. "I ran X and it failed" beats "I think X might not work."
- **Divergence is the signal.** Where both agents agree, it's probably right (but probe edge cases). Where they diverge, that's where the design insight lives.
- **The plan is a starting point, not a contract.** The other agent may have discovered things during implementation that the plan missed. Be open to that.
- **Explicit agreement matters.** When the other agent made a good call that diverges from your plan, say so. This builds trust in the collaborative workflow.
- **Nothing is stated as fact.** Frame everything as your assessment. The other agent should verify, not just comply.
- **Verification requests are first-class.** Every feedback point should end with what the other agent should check. You might have missed something.
- **Fresh eyes matter.** You're in a clean context for a reason — approach the code without sunk-cost bias.
- **Don't over-report.** If everything looks good, say so briefly. The value is in the debate points, not narrating agreement.

---
name: late-binding-guardrails
description: Review designs and PRs for late-binding primitives (immutable ledgers, explicit scope, run envelopes, versioned projections, explicit judgements). Use when adding durable state, agent tools, retrieval features, or permissioned views.
---

# Late Binding Guardrails

**Prime directive:** Store irreducible facts immutably; defer interpretation to versioned projections.

This skill reviews for *durability* — ensuring work compounds and history is preserved. For *capability parity* (can agents do what users do?), see `agent-native-architecture`.

---

## The Core 5 (Non-Negotiable)

These primitives keep you from blocking yourself as the system evolves:

### 1. Immutable Ledger + Stable IDs

Durable state is **append-only events**, not mutable records. Changes are new events (retire, supersede, correct), not overwrites.

**Minimum:** `event_id`, `event_type`, `occurred_at`, `subject_ref`, `payload`

**Recommended:** Add `scope` (actor, workspace) for auditability. See `references/event-schema-guide.md` for full spec.

### 2. Scope as First-Class Input

Every meaningful operation accepts explicit **Scope** — no ambient globals like `current_ticker`.

**Minimum:** `workspace_id`, `actor`, `as_of` (PIT timestamp)

### 3. Run Envelope + Artefacts

Every retrieval/tool/model call produces a **durable run record** with inputs, outputs, artefact paths, and linkage.

**Minimum:** `run_id`, `run_type`, `inputs`, `outputs`, `artefacts` (paths under `data/debug/`)

### 4. Projection Boundary

"Current state" is derived via **versioned projections** from events — not stored as the only truth.

**Why:** You can evolve semantics (what "confirmed" means) by shipping new projection versions, not migrating history.

### 5. Judgements + Evals as Events

Human and automated decisions are **explicit events** (confirm, reject, stamp, eval_passed), not implicit booleans.

**Why:** Without recorded judgements, you can't measure quality, train policies, or automate safely.

---

## Intake

What would you like to do?

1. **Review a PR / code change** for late-binding compliance
2. **Design a new feature** with late-binding primitives (before coding)
3. **Add a new event type / ledger** schema
4. **Run the static checker** script

Use AskUserQuestion to capture the choice before proceeding.

---

## Routing

| Response | Action |
|----------|--------|
| 1, "pr", "review", "code" | Read `references/pr-review-checklist.md` |
| 2, "design", "feature", "new" | Read `references/feature-design-checklist.md` |
| 3, "event", "schema", "ledger" | Read `references/event-schema-guide.md` |
| 4, "check", "static", "script" | Run: `uv run python .claude/skills/late-binding-guardrails/scripts/lb_check.py` |

---

## Quick Checks (From Memory)

Before any PR that writes durable state, verify:

- [ ] **Append-only?** — No `open(..., 'w')` on ledgers; no in-place mutations
- [ ] **Scope explicit?** — No `current_ticker` globals; scope threaded through
- [ ] **Run produces artefacts?** — `data/debug/{feature}/{run_id}/` with manifest
- [ ] **Judgements recorded?** — Decisions are events, not implicit booleans
- [ ] **Current state derived?** — If there's a "view", can it be recomputed from events?

**Severity:**
- **P1 (blocking):** Immutability breaches — ledger overwrites, missing audit trail for decisions
- **P2 (warning):** Scope/artefact/projection gaps — recoverable but should be fixed

---

## Relationship to Other Skills

| Skill | Concern | Question It Answers |
|-------|---------|---------------------|
| `agent-native-architecture` | Capability parity | Can agents do what users do? |
| `late-binding-guardrails` | Durability semantics | Will work compound? Is history preserved? |
| `snowflake-sql-review` | Query patterns | Is this SQL performant and safe? |

---

## Static Checker

Quick automated check for catastrophic mistakes:

```bash
uv run python .claude/skills/late-binding-guardrails/scripts/lb_check.py
```

Catches: ledger overwrites, implicit context smells. Returns exit code 1 on P1 findings.

---

## Reference Index

- `references/pr-review-checklist.md` — Full PR review checklist with examples
- `references/feature-design-checklist.md` — Pre-coding design template
- `references/event-schema-guide.md` — When introducing new ledgers
- `references/advanced-tracing.md` — Aspirational: W3C Trace Context, OTel patterns

---

## When This Skill Isn't Needed

Skip this review for:

- Fast Mode scripts (`workspaces/<user>/scripts/`) — disposable by design
- Pure read-only queries — nothing durable at stake
- UI-only changes — no state written

Apply this review for:

- Any new ledger or event type
- Any retrieval/search feature (should produce run records)
- Any agent tool that mutates state
- Any "current state" view or projection

# Feature Design Checklist

Use this checklist **before coding** to ensure a new feature follows late-binding primitives. Output a "Primitive Map" that documents your design decisions.

---

## When to Use This

- Adding a new ledger or event type
- Building a retrieval/search feature
- Creating an agent tool that writes state
- Adding a "current state" view or dashboard

---

## The Primitive Map (One-Page Template)

Before coding, fill in this template:

```markdown
# Primitive Map: [Feature Name]

## A. System-of-Record Events

What events will this feature produce?

| Event Type | Subject | Payload Fields | Example |
|------------|---------|----------------|---------|
| | | | |

**Subject types:** (evidence, claim, annotation, run, etc.)

**Event lifecycle:** How does state evolve? (created → linked → judged → retired?)

## B. Scope Contract

What scope fields does this feature require?

| Field | Required? | Purpose |
|-------|-----------|---------|
| workspace_id | | |
| actor | | |
| actor_type | | |
| as_of | | |
| capabilities | | |

**PIT semantics:** Does this feature need point-in-time queries? If so, what does `as_of` mean here?

## C. Runs and Artefacts

What retrieval/tool/model calls will this feature make?

| Run Type | Inputs | Outputs | Artefacts |
|----------|--------|---------|-----------|
| | | | |

**Artefact location:** `data/debug/{feature_name}/{run_id}/`

**Run manifest:** What goes in `run_manifest.json`?

## D. Projections

What "current state" views will this feature expose?

| Projection | Source Events | Versioned? | Role-Safe? |
|------------|---------------|------------|------------|
| | | | |

**Recomputation:** Can each projection be rebuilt from events?

## E. Judgements / Evals

What decisions does this feature capture?

| Decision Type | Actor Type | Recorded As |
|---------------|------------|-------------|
| | human/ai/system | |

**Eval harness:** Will automated checks run? What events do they produce?
```

---

## Step-by-Step Process

### Step 1: Identify the Durable Objects

Ask: "What state does this feature create or modify?"

- New ledger? → Define events in Section A
- New view? → Define projection in Section D
- New search/retrieval? → Define runs in Section C

If the answer is "none" (read-only feature), this checklist doesn't apply.

### Step 2: Define Events First

Before thinking about storage or API, define the **events**:

```
What happens? → Event type
To what? → Subject
By whom? → Actor (in scope)
With what data? → Payload
```

**Good event names:** `evidence_created`, `annotation_linked`, `claim_retired`, `run_completed`

**Bad event names:** `update`, `change`, `set` (too generic)

### Step 3: Thread Scope Through

For each operation that produces events:

- Where does `actor` come from? (parameter, auth context, CLI flag)
- Where does `as_of` come from? (parameter, system time, external source)
- Is the workspace/tenant explicit?

**Common mistake:** Forgetting `actor` on internal operations. Even system jobs need an actor like `"system:scheduler"`.

### Step 4: Design Run Envelopes

For any retrieval, tool call, or model call:

- What are the inputs? (query, parameters, context)
- What are the outputs? (results, metrics, errors)
- What artefacts should be persisted? (raw results, intermediate data, debug info)

**Rule of thumb:** If you'd want to debug this later, it needs a run envelope.

### Step 5: Separate Record from View

Ask: "How will this data be consumed?"

- API response? → Projection
- Dashboard? → Projection
- Audit log? → Read events directly

For each consumption pattern, define whether it's:
- **Direct read** (audit, history) → Read events
- **Derived view** (current state, aggregates) → Projection

### Step 6: Make Judgements Explicit

Identify any decisions:

- Human review? → `judged` event
- Automated validation? → `eval_completed` event
- Promotion/staging? → `stage_changed` event

Each decision should answer: who, when, what, why.

---

## Design Review Questions

Before finalising, verify:

### Immutability

> "If I need to change a past record, how do I do it?"

Answer should be: "Append a correction/supersession event."

Not: "Update the row" or "Rewrite the file."

### Replay

> "Can I rebuild current state from events?"

Answer should be: "Yes, by replaying events through projection X."

Not: "No, current state is the only truth."

### Debugging

> "If something goes wrong, what artefacts exist?"

Answer should be: "Run manifest + debug outputs in `data/debug/`."

Not: "Chat logs" or "We'd have to re-run it."

### Audit

> "Who made this decision and when?"

Answer should be: "The judgement event has actor, timestamp, and reason."

Not: "It's a boolean flag" or "Check git blame."

---

## Example: Transcript Annotation Feature

```markdown
# Primitive Map: Transcript Annotation

## A. System-of-Record Events

| Event Type | Subject | Payload Fields | Example |
|------------|---------|----------------|---------|
| annotation_created | annotation | span_locator, tag, note | Tag CFO margin comment |
| annotation_linked | annotation | linked_to (evidence_id) | Link to thesis evidence |
| annotation_judged | annotation | judgement, reason | Confirm as relevant |
| annotation_retired | annotation | reason | Superseded by better tag |

## B. Scope Contract

| Field | Required? | Purpose |
|-------|-----------|---------|
| workspace_id | Yes | Isolate per-user annotations |
| actor | Yes | Who created/judged |
| actor_type | Yes | human/ai distinction |
| as_of | No | Not PIT-critical for this feature |

## C. Runs and Artefacts

| Run Type | Inputs | Outputs | Artefacts |
|----------|--------|---------|-----------|
| transcript_search | query, ticker | result_ids, scores | results.json |
| span_extraction | transcript_id, query | spans, confidence | extracted_spans.json |

## D. Projections

| Projection | Source Events | Versioned? | Role-Safe? |
|------------|---------------|------------|------------|
| current_annotations | annotation_* events | No (simple) | No (all visible) |
| annotation_timeline | all events | No | No |

## E. Judgements / Evals

| Decision Type | Actor Type | Recorded As |
|---------------|------------|-------------|
| Relevance confirmation | human | annotation_judged |
| Auto-tag suggestion | ai | annotation_created (actor_type=ai) |
```

---

## Anti-Patterns to Avoid

### The "Status Column" Trap

❌ **Bad:** `annotations` table with `status` column that gets `UPDATE`d

✅ **Good:** Append `annotation_judged` events; derive status from latest event

### The "Search Box" Trap

❌ **Bad:** Search returns results directly to UI, no record kept

✅ **Good:** Search produces a `search_run` with inputs, outputs, and artefacts

### The "Implicit Decision" Trap

❌ **Bad:** `is_confirmed = True` set somewhere without audit trail

✅ **Good:** `judgement_event` with actor, timestamp, and reason

### The "God Object" Trap

❌ **Bad:** One giant event type with 50 optional fields

✅ **Good:** Small, focused event types that compose

# PR Review Checklist

Apply this checklist to any PR that writes durable state. For each changed component, answer the questions below.

---

## 1. Immutable Ledger + Stable IDs

**Question:** Does this write append-only events, or does it mutate existing state?

### Checklist

- [ ] Events are appended, not overwritten
- [ ] IDs are stable and addressable (`event_id`, `run_id`, `subject_ref`)
- [ ] "Updates" are implemented as new events (retire, supersede, correct)
- [ ] No `DELETE` or `UPDATE` on ledger tables (append new events instead)

### Red Flags

```python
# P1: Overwrites ledger
with open("ledger.jsonl", "w") as f:  # WRONG — destroys history
    json.dump(events, f)

# P1: In-place mutation
ledger_df.loc[ledger_df["id"] == event_id, "status"] = "confirmed"  # WRONG

# CORRECT: Append new event
with open("ledger.jsonl", "a") as f:
    f.write(json.dumps({"event_type": "status_changed", "status": "confirmed", ...}) + "\n")
```

### Quinlan Examples

**Good:** `wb` CLI appends to `$WORKBENCH_EVIDENCE_ROOT/stocks/{TICKER}/ledger.jsonl`

**Bad:** Direct writes with mode `"w"` to any `.jsonl` file

---

## 2. Scope as First-Class Input

**Question:** Is scope explicit throughout, or are there ambient globals?

### Checklist

- [ ] Operations accept explicit `scope` parameter (or equivalent fields)
- [ ] Scope includes: workspace/user context, actor, as_of timestamp
- [ ] No global mutable state like `current_ticker`, `current_user`
- [ ] Time-dependent logic uses `as_of`, not `datetime.now()` at execution time

### Red Flags

```python
# P2: Implicit context (recoverable but should fix)
def get_evidence():
    return load_evidence(CURRENT_TICKER)  # WRONG — where does CURRENT_TICKER come from?

# P2: Missing actor tracking
def add_note(ticker: str, text: str):
    # WRONG — who added this note? When?
    ledger.append({"type": "note", "text": text})

# CORRECT: Explicit scope
def add_note(ticker: str, text: str, *, actor: str, actor_type: str, as_of: datetime | None = None):
    ledger.append({
        "type": "note",
        "text": text,
        "actor": actor,
        "actor_type": actor_type,
        "occurred_at": (as_of or datetime.now(UTC)).isoformat(),
    })
```

### Quinlan Examples

**Good:** `wb add-stock TICKER --actor claude --actor-type ai --actor-model claude-opus-4-5`

**Bad:** Functions that read from environment variables or module-level globals for context

---

## 3. Run Envelope + Artefacts

**Question:** Does each retrieval/tool/model call produce a durable record?

### Checklist

- [ ] Retrieval operations produce a run record (not just return data)
- [ ] Run records include: `run_id`, `run_type`, `inputs`, `outputs`, `artefacts`
- [ ] Artefacts written to `data/debug/{feature}/{run_id}/`
- [ ] Run manifest (`run_manifest.json`) links everything together
- [ ] Parent/child runs are linkable (`parent_run_id` if applicable)

### Red Flags

```python
# P2: Search returns data but no durable record
def search_transcripts(query: str) -> list[Transcript]:
    results = vector_db.search(query)
    return results  # WRONG — no audit trail, can't debug later

# CORRECT: Produce run record
def search_transcripts(query: str, *, run_id: str | None = None) -> SearchRun:
    run_id = run_id or generate_run_id()
    results = vector_db.search(query)

    # Write artefacts
    artefact_dir = Path(f"data/debug/transcript_search/{run_id}")
    artefact_dir.mkdir(parents=True, exist_ok=True)
    (artefact_dir / "results.json").write_text(json.dumps([r.dict() for r in results]))

    return SearchRun(
        run_id=run_id,
        run_type="transcript_search",
        inputs={"query": query},
        outputs={"result_count": len(results)},
        artefacts=[str(artefact_dir / "results.json")],
    )
```

### Quinlan Examples

**Good:** Scanner writes to `data/debug/scanner/{run_id}/` with `run_manifest.json`

**Bad:** Tool calls that only exist in chat logs

---

## 4. Projection Boundary

**Question:** Is "current state" derived via a projection, or stored as the only truth?

### Checklist

- [ ] Raw events are the system of record
- [ ] "Current state" views can be recomputed from events
- [ ] Projections are versioned (or at least documented)
- [ ] Role-safe views filter based on scope/capabilities, not ad-hoc logic

### Red Flags

```python
# P2: Current state as only truth
def get_stock_status(ticker: str) -> str:
    return db.query("SELECT status FROM stocks WHERE ticker = ?", ticker)
    # WRONG if there's no event history — how did it get this status?

# CORRECT: Derive from events
def get_stock_status(ticker: str) -> str:
    events = load_ledger(ticker)
    status_events = [e for e in events if e["event_type"] in ("stage_changed", "oic_assigned")]
    if not status_events:
        return "new"
    return status_events[-1]["new_status"]  # Derived from event stream
```

### Signs You're Missing a Projection Boundary

- You have a "status" column that gets `UPDATE`d rather than event-sourced
- Changing the definition of "confirmed" requires a data migration
- You can't answer "what was the status on date X?"

### Quinlan Examples

**Good:** Evidence ledger is append-only; UI derives current state by reading events

**Needs work:** If we had a "stocks" table with mutable `status` column

---

## 5. Judgements + Evals as Events

**Question:** Are decisions recorded as explicit events, or implicit state changes?

### Checklist

- [ ] Human confirmations are events (`judged`, `confirmed`, `rejected`)
- [ ] Events include who, when, and why (not just what)
- [ ] Automated checks produce eval events (even minimal ones)
- [ ] No implicit booleans like `is_approved = True` without audit trail

### Red Flags

```python
# P2: Implicit approval
evidence["is_confirmed"] = True  # WRONG — who confirmed? When? Based on what?

# CORRECT: Explicit judgement event
ledger.append({
    "event_type": "evidence_judged",
    "subject_ref": evidence_id,
    "judgement": "confirmed",
    "actor": "jeremy",
    "actor_type": "human",
    "reason": "Verified against earnings transcript",
    "occurred_at": datetime.now(UTC).isoformat(),
})
```

### Quinlan Examples

**Good:** `/review` endpoint appends review events to ledger

**Bad:** Setting `confirmed=True` in a database row without event

---

## Review Report Template

After applying this checklist, summarise findings:

```markdown
# Late Binding Review: [PR title]

## Summary
- Risk: low/medium/high
- Blocking issues: N

## Changed Components
- [component]: [ledger/projection/run/none]

## Core 5 Checks
1. Immutable ledger: PASS/FAIL — [notes]
2. Scope explicit: PASS/FAIL — [notes]
3. Run envelope + artefacts: PASS/FAIL — [notes]
4. Projection boundary: PASS/FAIL — [notes]
5. Judgements as events: PASS/FAIL — [notes]

## Required Fixes (P1 — blocking)
- [ ] ...

## Recommendations (P2/P3 — non-blocking)
- [ ] ...
```

---

## Severity Guide

| Severity | Description | Examples |
|----------|-------------|----------|
| **P1** | Destroys history or prevents replay | Ledger overwrite, missing audit trail for decisions |
| **P2** | Hinders debugging or evolution | No run artefacts, implicit context, missing `as_of` |
| **P3** | Style/future-proofing | Could add versioning, could improve ID format |

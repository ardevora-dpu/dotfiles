# Event Schema Guide

Use this guide when introducing new ledgers or event types. It covers the minimum viable schema, ID strategies, and evolution patterns.

---

## Minimum Event Envelope

Every event should include these fields:

```json
{
  "event_id": "evt_01JQXYZ...",
  "event_type": "evidence_created",
  "occurred_at": "2025-01-13T14:30:00Z",
  "subject_ref": "evidence:evt_01JQABC...",
  "scope": {
    "workspace_id": "jeremy",
    "actor": "claude",
    "actor_type": "ai",
    "actor_model": "claude-opus-4-5"
  },
  "schema_version": "1.0",
  "payload": {
    // Event-specific data
  }
}
```

### Field Descriptions

| Field | Type | Required | Purpose |
|-------|------|----------|---------|
| `event_id` | string | Yes | Unique, stable address for this event |
| `event_type` | string | Yes | What happened (past tense verb + noun) |
| `occurred_at` | ISO8601 | Yes | When it happened (UTC) |
| `subject_ref` | string | Yes | What it happened to (type:id format) |
| `scope` | object | Yes | Context: who, where, with what authority |
| `schema_version` | string | Yes | Payload version for evolution |
| `payload` | object | Yes | Event-specific data |

---

## ID Strategies

### Option 1: UUID v4 (Simple, Good Default)

```python
import uuid
event_id = f"evt_{uuid.uuid4().hex}"
```

**Pros:** No dependencies, universally unique
**Cons:** Not sortable by time

### Option 2: ULID (Sortable by Time)

```python
import ulid
event_id = f"evt_{ulid.new()}"
```

**Pros:** Lexicographically sortable by creation time
**Cons:** Requires `ulid-py` dependency

### Option 3: Prefixed UUID with Timestamp

```python
from datetime import datetime, UTC
import uuid

def generate_event_id(prefix: str = "evt") -> str:
    ts = datetime.now(UTC).strftime("%Y%m%d")
    return f"{prefix}_{ts}_{uuid.uuid4().hex[:12]}"
```

**Pros:** Human-readable date prefix, no extra dependency
**Cons:** Not cryptographically sortable within a day

### Recommendation

For Quinlan: **UUID v4 with prefix** is fine. Time ordering comes from `occurred_at`. If you later need time-ordered IDs (e.g., for pagination), migrate to ULID.

---

## Subject References

Use the format `type:id` for subject references:

```
evidence:evt_abc123
annotation:ann_def456
run:run_ghi789
stock:AAPL-US
```

### Benefits

- Self-documenting (you know the type without a lookup)
- Can route to different storage backends per type
- Supports foreign keys across ledgers

### Pattern

```python
def make_subject_ref(subject_type: str, subject_id: str) -> str:
    return f"{subject_type}:{subject_id}"

def parse_subject_ref(ref: str) -> tuple[str, str]:
    subject_type, subject_id = ref.split(":", 1)
    return subject_type, subject_id
```

---

## Event Type Naming

Use past tense verb + noun:

| Good | Bad |
|------|-----|
| `evidence_created` | `create_evidence` |
| `annotation_linked` | `link` |
| `claim_retired` | `update_claim` |
| `run_completed` | `run` |

### Event Lifecycle Pattern

Most subjects follow a lifecycle:

```
created → [modified] → [linked] → [judged] → retired
```

Define events for each meaningful state transition:

```
evidence_created
evidence_updated (if payload can change)
evidence_linked (to another subject)
evidence_judged (human/AI decision)
evidence_retired (soft delete)
```

---

## Payload Versioning

Include `schema_version` to enable evolution:

```json
{
  "schema_version": "1.0",
  "payload": {
    "ticker": "AAPL-US",
    "thesis": "Strong services growth"
  }
}
```

### Evolution Rules

1. **Additive changes** (new optional fields): Bump minor version (1.0 → 1.1)
2. **Breaking changes** (removed/renamed fields): Bump major version (1.0 → 2.0)
3. **Never remove fields from existing events** — only add new event types

### Handling Multiple Versions

```python
def process_event(event: dict) -> None:
    version = event.get("schema_version", "1.0")
    payload = event["payload"]

    if version.startswith("1."):
        # v1.x processing
        ticker = payload["ticker"]
    elif version.startswith("2."):
        # v2.x processing (different field name)
        ticker = payload["instrument_id"]
```

---

## Corrections and Supersession

Never mutate existing events. Instead:

### Pattern 1: Correction Event

```json
{
  "event_type": "evidence_corrected",
  "subject_ref": "evidence:evt_original",
  "payload": {
    "corrected_field": "thesis",
    "old_value": "Strong services growth",
    "new_value": "Strong services growth driven by Apple One",
    "reason": "Added specificity"
  }
}
```

### Pattern 2: Supersession Event

```json
{
  "event_type": "evidence_superseded",
  "subject_ref": "evidence:evt_original",
  "payload": {
    "superseded_by": "evidence:evt_new",
    "reason": "Replaced with more recent analysis"
  }
}
```

### Pattern 3: Retirement Event

```json
{
  "event_type": "evidence_retired",
  "subject_ref": "evidence:evt_original",
  "payload": {
    "reason": "No longer relevant after Q4 earnings"
  }
}
```

### Projection Logic

When building "current state" projections:

```python
def is_active(event_stream: list[dict], subject_id: str) -> bool:
    relevant = [e for e in event_stream if e["subject_ref"].endswith(subject_id)]
    for e in reversed(relevant):
        if e["event_type"].endswith("_retired"):
            return False
        if e["event_type"].endswith("_superseded"):
            return False
    return True
```

---

## Storage Patterns

### JSONL (Current Quinlan Pattern)

```
$WORKBENCH_EVIDENCE_ROOT/stocks/{TICKER}/ledger.jsonl
```

**Pros:** Simple, human-readable, append-only by nature
**Cons:** No indexing, full scan for queries

### SQLite (Future Option)

```sql
CREATE TABLE events (
    event_id TEXT PRIMARY KEY,
    event_type TEXT NOT NULL,
    occurred_at TEXT NOT NULL,
    subject_ref TEXT NOT NULL,
    scope_json TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    schema_version TEXT NOT NULL
);

CREATE INDEX idx_subject ON events(subject_ref);
CREATE INDEX idx_type ON events(event_type);
CREATE INDEX idx_occurred ON events(occurred_at);
```

**Pros:** Queryable, indexed
**Cons:** Slightly more complex writes

### Migration Path

JSONL → SQLite is straightforward:

```python
def migrate_jsonl_to_sqlite(jsonl_path: Path, db_path: Path) -> None:
    conn = sqlite3.connect(db_path)
    with open(jsonl_path) as f:
        for line in f:
            event = json.loads(line)
            conn.execute(
                "INSERT INTO events VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    event["event_id"],
                    event["event_type"],
                    event["occurred_at"],
                    event["subject_ref"],
                    json.dumps(event["scope"]),
                    json.dumps(event["payload"]),
                    event.get("schema_version", "1.0"),
                ),
            )
    conn.commit()
```

---

## Checklist for New Ledgers

Before introducing a new ledger:

- [ ] Envelope fields defined (`event_id`, `event_type`, `occurred_at`, `subject_ref`, `scope`, `schema_version`)
- [ ] ID generation strategy chosen
- [ ] Event types follow naming convention (past tense verb + noun)
- [ ] Lifecycle events defined (created, modified, linked, judged, retired)
- [ ] Payload is versioned
- [ ] Correction/supersession events defined (no in-place mutation)
- [ ] Storage location documented
- [ ] Projection logic sketched (how to derive current state)

---

## Example: New "Claims" Ledger

```python
# Event types
CLAIM_CREATED = "claim_created"
CLAIM_LINKED = "claim_linked"
CLAIM_SUPPORTED = "claim_supported"  # Evidence added
CLAIM_CHALLENGED = "claim_challenged"  # Counter-evidence
CLAIM_RETIRED = "claim_retired"

# Example event
{
    "event_id": "evt_20250113_abc123",
    "event_type": "claim_created",
    "occurred_at": "2025-01-13T15:00:00Z",
    "subject_ref": "claim:clm_xyz789",
    "scope": {
        "workspace_id": "jeremy",
        "actor": "claude",
        "actor_type": "ai",
        "actor_model": "claude-opus-4-5"
    },
    "schema_version": "1.0",
    "payload": {
        "ticker": "AAPL-US",
        "claim_text": "Services revenue will exceed $100B by FY2026",
        "confidence": "medium",
        "source_refs": ["transcript:tr_abc", "evidence:evt_def"]
    }
}

# Storage
# workspaces/jeremy/claims/ledger.jsonl

# Projection: active claims
def get_active_claims(workspace_id: str) -> list[dict]:
    events = load_claims_ledger(workspace_id)
    claims = {}
    for e in events:
        claim_id = e["subject_ref"].split(":")[1]
        if e["event_type"] == "claim_created":
            claims[claim_id] = e["payload"]
        elif e["event_type"] == "claim_retired":
            claims.pop(claim_id, None)
    return list(claims.values())
```

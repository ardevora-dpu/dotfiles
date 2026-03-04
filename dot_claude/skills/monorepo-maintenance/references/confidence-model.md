# Confidence Model for Deletion and Consolidation

Use this model to avoid over-deleting maintained but still-relevant logic.

## Evidence Classes

Class A — Reachability
- Import/call references
- Workflow/task/hook references
- Entry-point wiring

Class B — Operational Use
- Execution/test evidence
- Runtime wrappers/scheduler usage
- Recent activity linked to live workflows

Class C — Contract and Replacement
- Explicit canonical replacement exists
- Doc/runtime contract says candidate is superseded
- Migration/deprecation path is recorded

## Confidence Levels

### High Confidence (delete/archive candidate)

Require:
- At least one strong Class A signal of non-use, and
- At least one Class C signal (superseded/canonical replacement), and
- No contradictory operational signal.

Example pattern:
- compatibility wrapper exists,
- canonical path is documented and wired,
- wrapper has zero operational references.

### Medium Confidence (needs decision)

Typical pattern:
- weak or mixed reachability signals,
- possible manual use,
- partial replacement evidence,
- unclear owner.

Action:
- keep for now, tag as monitor/fix, add explicit owner and sunset review date.

### Low Confidence (monitor only)

Typical pattern:
- static analysis suggests low use but operational role is plausible,
- high ambiguity,
- insufficient cross-surface evidence.

Action:
- no deletion recommendation; capture as observation only.

## Anti-False-Positive Rules

- Do not classify `__main__` modules as unused without checking CLI invocation paths.
- Do not classify scheduler wrappers as unused from repo references alone; verify task wiring.
- Do not classify docs as obsolete only because they are rarely linked; check whether they are canonical policy docs.
- Treat generated artefacts and historical recaps separately from operational runbooks.

## Recommendation Labels

- `delete-now` — high confidence, low rollback risk
- `archive-now` — high confidence obsolete but worth retaining history
- `keep-fix` — still relevant but stale or contradictory
- `monitor` — uncertain; gather more evidence

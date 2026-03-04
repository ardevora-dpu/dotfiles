---
name: late-binding-guardrails
description: Deprecated user-level shim. Quinlan source of truth now lives at project scope.
---

# Late Binding Guardrails (Deprecated User-Level Shim)

This user-level copy is intentionally minimal.

## Source of Truth

For Quinlan work, use the project-scoped skill:

`/home/chimern/projects/quinlan-ard-517/.claude/skills/late-binding-guardrails/SKILL.md`

Project-scoped skills take precedence and are now the maintained version for this domain.

## Why

Late-binding guardrails are platform architecture, not personal preference. Keeping them in project scope avoids WSL/Windows and user-level divergence.

## If you are outside the Quinlan repo

Use this minimum checklist:

- Keep canonical state append-only
- Require explicit scope/actor attribution
- Distinguish business/event/publish/ingest times
- Persist run envelopes for retrieval/model calls
- Treat read models as versioned projections
- Capture judgements and evals as events
- Define idempotency and replay ordering

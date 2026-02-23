---
name: docs-commenting-hygiene
description: Improve docstrings and comments to match the repo documentation doctrine. Use when cleaning up docs/comments, reviewing API contracts, or standardising comment style across Python, TypeScript, and dbt/SQL.
---

# Docs Commenting Hygiene

## Quick Start

- Identify public surfaces and data transforms.
- Apply doctrine: types explain shape, code explains mechanics, comments explain intent, invariants, and risk.
- Edit only docs and comments; do not change behaviour.
- Add comments at high leverage points: PIT, grain, ordering, idempotency, caching, irreversibility.

## When to use

- The user asks to clean up documentation or comments.
- You are updating docstrings for APIs, data transforms, or helpers.
- You need to standardise comment style across Python, TypeScript, or dbt/SQL.

## Workflow

1. Read the relevant files and nearby context before editing.
2. Identify boundaries and high-risk semantics (PIT, grain, ordering, replay safety).
3. Update docstrings and comments to express intent, invariants, and risk.
4. Remove narration, restated types, and structural comments.
5. If docs and behaviour conflict, flag the mismatch instead of changing behaviour.

## Doctrine

Types and schemas explain shape.
Code explains mechanics.
Comments explain intent, invariants, and risk.

| Layer | Responsibility |
| --- | --- |
| Types | Shape and constraints |
| Docstrings | Public contract and semantics |
| Comments | Intent, invariants, risk |
| Tests | Behavioural truth and regressions |

## Invariants and Semantics Rule

Always comment when any of the following appear:
- Grain changes or implied grain
- PIT vs non-PIT assumptions
- Ordering guarantees or stability expectations
- Idempotency or replay safety
- Caching, derivation, or lossy transformations
- Irreversible or high-leverage actions

## Layer Guidance

### Python FastAPI endpoints

- Docstrings are API contracts (Google style is fine; Markdown is fine).
- Document business meaning, preconditions, postconditions, defaults, and error semantics.
- Do not restate Pydantic types or HTTP mechanics.
- Inline comments explain why behaviour exists, not what it does.

### Polars and data transforms

- Docstrings describe grain, PIT assumptions, and output semantics (NumPy style).
- Inline comments call out ordering, numerical stability, or traps.

### Internal helpers

- Comment policy decisions, not mechanics.
- Example: "We normalise to UTC to avoid mixed-zone joins later."

### pytest

- Comment only for regressions or counter-intuitive behaviour.
- Include issue IDs where available.

### TypeScript and React

- Use TSDoc on public interfaces and props.
- Document meaning and lifecycle semantics, not types.
- For Zustand or Zod, comment derived or lossy state and cache semantics.

### TanStack Query

- Document query key conventions and cache semantics.

### SQL and dbt

- YAML is canonical documentation: grain, keys, lineage, temporal semantics.
- SQL comments explain reasoning, not structure.
- Jinja comments explain macro quirks or compile-time behaviour.

## Output Expectations

- Provide a concise summary of comment and docstring changes.
- Call out any behavioural mismatches or unresolved risks.

## References

- `references/doctrine.md` - Detailed examples and patterns.

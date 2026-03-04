# Monorepo Maintenance Checklist

## 1) Scope and Constraints

- Confirm scope (full repo vs selected areas).
- Confirm time budget and output mode (report-only vs fixes).
- Confirm whether issue creation is requested.
- Record off-limits paths/systems.

## 2) Repository Topology (Live)

- Resolve workspace members from root `pyproject.toml`.
- Verify each declared member exists and has a `pyproject.toml`.
- Detect active top-level surfaces (`packages/`, `warehouse/`, `scripts/`, `workspaces/`, optional `apps/`).
- Build execution map from:
  - CI workflows
  - package entrypoints
  - scheduler/task wrappers
  - hook scripts

## 3) Structural Health

- Boundary checks (import-linter or equivalent contracts).
- Cycle checks and dependency depth hotspots.
- Generic namespace creep (`utils`, `common`, `helpers`).
- Packaging inconsistencies (source layout, naming mismatch, ownership ambiguity).

## 4) Unused Business Logic Detection

### Packages and Modules

- For each candidate module/package, gather:
  - inbound imports outside the defining package
  - references in scripts and workflows
  - references in package entrypoints (`project.scripts`, `python -m`)
  - test presence and recent execution relevance
- Treat CLI modules and `__main__` modules as potential entrypoints before classifying unused.

### Scripts

- For each script, gather:
  - references in workflows, task provisioning, wrappers, docs, and runbooks
  - whether references are self-only
  - whether script is a compatibility shim vs canonical path
  - recency and ownership signal
- Distinguish:
  - `unwired` (no operational references)
  - `manual utility` (explicitly manual, still useful)
  - `legacy shim` (superseded by canonical runtime path)

## 5) Documentation Drift and Relevance

- Config drift:
  - docs claims vs live config files (`.mcp.json`, runtime YAML, workflow files)
- Reference integrity:
  - broken repo-relative paths
  - stale file names in docs/runbooks
- Relevance drift:
  - draft/expired/deprecated docs outside archive without clear replacement
  - duplicated operational guidance with contradictory instructions

## 6) Reproducibility and Environment

- Pinning and lockfile coverage.
- Single supported environment entrypoint consistency.
- Manual setup steps not reflected in scripts/automation.

## 7) Data and dbt Surfaces (if in scope)

- Orphan model checks and dependency path checks.
- Unused table/view signals from warehouse query history (when available).
- Deprecation-first path before destructive removals.

## 8) Confidence Classification

- Apply `references/confidence-model.md`.
- Require at least two independent evidence classes for high-confidence deletion.

## 9) Reporting

Produce one table:

`Area | Candidate | Confidence | Evidence | Risk | Recommendation | Effort`

Then add:
- No-regret actions (safe now)
- Decision-required actions (non-obvious consequences)
- Follow-up automation candidates

## 10) Mutation Gate

- Do not run mutating commands without explicit user approval.
- If approved, execute in small batches with verification after each batch.
- Report exactly what changed and what remains uncertain.

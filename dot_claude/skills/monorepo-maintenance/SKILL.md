---
name: monorepo-maintenance
description: Unified monorepo health and tech debt audit. Use when you need an evidence-first report on structure drift, unused business logic (packages/scripts), stale docs, and confidence-ranked deletion candidates.
---

# Monorepo Maintenance Audit

## Overview

This skill merges structural monorepo review and tech debt review into one workflow.

Default behaviour is **report-only**. Do not mutate code, docs, or configuration until the user approves specific actions.

Core rules:
- Start with deterministic evidence, then add model inference.
- Prefer confidence-ranked findings over large noisy lists.
- Separate "unused" from "low usage" and "stale but still relevant".
- Treat deletion as a product decision, not only a static-analysis result.

## When to Use

- Quarterly monorepo hygiene and boundary checks.
- "What can we delete?" audits.
- Before adding or splitting packages.
- When scripts/docs feel stale or duplicated.
- Before broad refactors where hidden dead surfaces create risk.

## Workflow

1. Confirm audit scope.
   Capture scope, time budget, and whether to create Linear issues. Do not create issues without explicit approval.

2. Build live topology from repository contracts.
   Resolve workspace members from root `pyproject.toml`.
   Detect whether `apps/` exists before running app-specific checks.
   Map active execution surfaces from workflows, scheduled-task scripts, package entrypoints, and runtime wrappers.

3. Run structure and boundary checks.
   Validate workspace/member integrity, import boundaries, circular dependencies, and layering drift.

4. Run reachability checks for business logic.
   Analyse packages, modules, and scripts for real usage signals:
   - inbound imports or call sites
   - workflow/hook/task references
   - CLI entrypoint wiring
   - tests and runtime wrappers
   - recent change activity
   Use `references/confidence-model.md` to classify High/Medium/Low confidence.

5. Run documentation relevance and drift checks.
   Identify:
   - docs that disagree with live config/runtime
   - broken internal file references
   - non-archive docs marked draft/expired/deprecated without a current owner or replacement
   - duplicated guidance likely to drift

6. Synthesis pass.
   Merge findings into one table with evidence links and confidence.
   Split into:
   - deletion candidates
   - archive/move candidates
   - keep but fix candidates
   - monitor-only candidates

7. Present action plan.
   Propose the smallest safe set of next actions.
   Keep mutations staged and reversible. Ask for approval before each mutating batch.

8. If approved, execute mutations carefully.
   Delete in small batches, run relevant tests/checks after each batch, and report results plus residual risk.

## Subagent Pattern

When subagents are available, delegate four tracks in parallel:
- `structure-boundaries`: package topology, layering, imports, cycles.
- `reachability`: unused business logic in packages/scripts.
- `docs-drift`: stale/outdated/contradictory docs and references.
- `synthesis`: confidence scoring and deletion shortlist.

Use compact, evidence-rich handoffs. Keep the parent thread focused on decisions.

## Required Output

Use a single findings table:

`Area | Candidate | Confidence | Evidence | Risk | Recommendation | Effort`

Then provide:
- top 3 no-regret actions
- top 3 risky actions (need explicit decision)
- proposed follow-up checks to automate in CI/reporting

## References

- `references/checklist.md` — merged end-to-end audit checklist
- `references/confidence-model.md` — confidence scoring for delete/archive/keep decisions
- `references/no-regret-checks.md` — continuous checks to add (report-only first)

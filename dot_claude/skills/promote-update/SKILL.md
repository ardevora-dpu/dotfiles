---
name: promote-update
description: Timon pre-/update promotion router. Run faithful simulation, stage promotion PR, validate contracts, and gate merge approval.
argument-hint: "ARD-451"
---

# Promote Update

Route a safe pre-`/update` promotion for Jeremy runtime changes.

This skill orchestrates existing tooling interactively. Do not introduce a new Python orchestration module for this flow.

## Phase Sequence

| Phase | Name | Reference | Always run |
|------|------|-----------|------------|
| 1 | Preflight | `references/simulate-phase.md` (preflight section) | Yes |
| 2 | Simulate | `references/simulate-phase.md` | Yes |
| 3 | Build Plan | `references/build-plan-phase.md` | Yes |
| 4 | Stage PR | `references/stage-pr-phase.md` | If promotable paths > 0 |
| 5 | Validate | `references/validate-phase.md` | If PR staged |
| 6 | Parity Check | `references/parity-check-phase.md` | If PR staged |
| 7 | Summary + Merge Gate | `references/summary-phase.md` | Yes |

Load one phase reference at a time. Keep context lean.

## Core contracts

- Never auto-merge. Use `AskUserQuestion` for explicit approval.
- Idempotent runs: reuse/update existing promotion PR if one exists.
- Preserve user-managed state boundaries; do not promote bisync-managed paths.
- Persist machine-readable artefacts under `workspaces/timon/promotion-artifacts/<run-id>/`.
- Clean up temporary worktrees/files on both success and failure.

## Inputs

- Quinlan repo root (current worktree).
- Ticket identifier (default `ARD-451`).
- Checkpoint ref `origin/jeremy/checkpoints/live`.

## Output

- `promotion-plan.json` artefact.
- Updated or new promotion PR.
- Validation/parity outcomes.
- Merge recommendation and Jeremy-facing message draft.

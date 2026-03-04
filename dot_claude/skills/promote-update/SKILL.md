---
name: promote-update
description: Timon pre-/update promotion workflow. Use update-guard simulation and promote plan, then triage/stage PR and gate merge approval.
argument-hint: "ARD-451"
---

# Promote Update

Run a safe pre-`/update` promotion for Jeremy runtime changes using a hybrid model:
- Deterministic classification in `update-guard promote plan`
- Interactive decisions in this skill (triage + merge gate)

## Optional Harness Smoke

When Timon asks to "test the harness", run `references/harness-smoke-phase.md` first.
This is agent-run and dry-run only (no PR/merge side effects).

## Execution Model

**Create a task list at the start.** Use `TaskCreate` to track every phase and its sub-steps so nothing gets skipped. Mark each task `in_progress` before starting and `completed` when done. This is mandatory — the test run showed that steps get silently dropped without explicit tracking.

**Resolve paths once, reuse literals.** Each Bash tool call runs in a fresh shell — variables do not persist across calls. After creating the artefact directory, resolve `REPO_ROOT` and `ARTIFACT_DIR` to absolute paths and use those literal strings in all subsequent Bash commands. Never rely on `$ARTIFACT_DIR` surviving between separate Bash calls.

## Phase Sequence

| Phase | Name | Reference | Always run |
|------|------|-----------|------------|
| 1 | Simulate + Classify | `references/simulate-phase.md` | Yes |
| 2 | Triage + Stage PR | `references/stage-pr-phase.md` | If promote plan status is `ready` and not dry-run |
| 3 | Validate + Merge Gate | `references/summary-phase.md` | Yes |

Load one phase reference at a time.

## Core contracts

- Never auto-merge. Use `AskUserQuestion` for explicit approval.
- Idempotent runs: reuse/update existing promotion PR if one exists.
- Start with `update-guard promote status`; if status is `clean`, stop and report "no promotion needed".
- Deterministic classification lives in `update-guard promote plan` (no shell path bucketing in markdown).
- Plan selection contract: CLI writes `selected_paths_initial`; interactive triage writes `selected_paths_final`.
- Persist machine-readable artefacts under `workspaces/timon/promotion-artifacts/<run-id>/`:
  - `simulation-report.json`
  - `promotion-plan.json`
  - `final-summary.json`
- Support dry-run on request: run simulation + promote plan + summary only (no branch, PR, or merge mutation).

## Inputs

- Quinlan repo root (current worktree).
- Ticket identifier (default `ARD-451`).
- Checkpoint ref `origin/jeremy/checkpoints/live`.

## Output

- `promotion-plan.json` artefact produced by CLI.
- Updated or new promotion PR.
- Validation/parity outcomes.
- Merge recommendation and Jeremy-facing message draft.

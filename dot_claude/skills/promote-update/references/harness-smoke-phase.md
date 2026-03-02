# Harness Smoke Phase (Agent-run)

Use this phase when Timon asks to verify the promotion harness before a real promotion run.

This is not a manual operator runbook. Claude runs these steps directly.

## Goal

Validate that the skill flow and CLI glue behave correctly without PR/merge side effects.

## Contract

- Force dry-run semantics.
- Run deterministic phase only:
  - faithful simulation
  - `update-guard promote plan`
- Produce a compact machine-readable result under `workspaces/timon/promotion-artifacts/<run-id>/`.
- Never push, create PRs, or merge during harness smoke.

## Steps

1. Execute `references/simulate-phase.md` in dry-run mode.
2. Read:
   - `simulation-report.json`
   - `promotion-plan.json`
3. Write `harness-smoke-summary.json`:
```json
{
  "status": "ok|blocked",
  "simulation_safe": true,
  "promotion_plan_status": "ready|empty|unsafe",
  "selected_paths_initial_count": 0,
  "ambiguous_count": 0,
  "blockers": []
}
```
4. Report outcome to Timon in one paragraph plus file paths.

## Pass criteria

- Files exist and parse as JSON.
- Counts are internally consistent with `promotion-plan.json`.
- No git/gh side effects occurred (no branch push, no PR mutations).

# Build Plan Phase

Build `promotion-plan.json` from simulation output + checkpoint diff classification.

## Buckets

- `promotable_shared` — `promotion_report.shared_runtime`
- `promotable_platform` — `promotion_report.platform`
- `non_promotable_user_or_unknown` — discrepancy samples from:
  - `unknown_ownership_paths`
  - `non_bisynced_user_paths`
  - `checkpoint_scope_drift`
- `ambiguous` — files changed on both `origin/main` and checkpoint ref

## Compute ambiguous set

```bash
MERGE_BASE=$(git merge-base origin/main origin/jeremy/checkpoints/live)
MAIN_CHANGED=$(mktemp)
CHECKPOINT_CHANGED=$(mktemp)

git diff --name-only "$MERGE_BASE..origin/main" -- workspaces/jeremy/.claude/ workspaces/jeremy/scripts/ workspaces/jeremy/docs/ workspaces/jeremy/CLAUDE.md | sort -u > "$MAIN_CHANGED"
git diff --name-only "$MERGE_BASE..origin/jeremy/checkpoints/live" -- workspaces/jeremy/.claude/ workspaces/jeremy/scripts/ workspaces/jeremy/docs/ workspaces/jeremy/CLAUDE.md | sort -u > "$CHECKPOINT_CHANGED"
comm -12 "$MAIN_CHANGED" "$CHECKPOINT_CHANGED" > "$ARTIFACT_DIR/ambiguous-paths.txt"
```

## Interactive triage (required)

For each ambiguous file:
1. Show main vs checkpoint intent (`git show origin/main:<path>`, `git show origin/jeremy/checkpoints/live:<path>`).
2. Ask Timon whether to include, exclude, or defer.
3. Record decision in `promotion-plan.json` under `triage`.

## Write machine-readable plan

Write `$ARTIFACT_DIR/promotion-plan.json` with shape:

```json
{
  "run_id": "...",
  "ticket": "ARD-451",
  "simulation_safe": true,
  "promotable_shared": [],
  "promotable_platform": [],
  "ambiguous": [],
  "triage": [{"path": "...", "decision": "include|exclude|defer", "reason": "..."}],
  "non_promotable_user_or_unknown": []
}
```

Use included triage decisions to compute final `selected_paths` list.

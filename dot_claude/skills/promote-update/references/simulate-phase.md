# Simulate + Classify Phase

## Preflight

1. Confirm repo is clean for tracked files:
```bash
git status --porcelain --untracked-files=no
```
2. Confirm required tools:
```bash
command -v uv gh jq
```
3. Confirm Jeremy checkpoint ref is available:
```bash
git fetch origin --prune
git rev-parse --verify origin/jeremy/checkpoints/live
```
4. Create run artefact directory:
```bash
RUN_ID=$(date -u +%Y%m%d-%H%M%S)
ARTIFACT_DIR="workspaces/timon/promotion-artifacts/${RUN_ID}"
mkdir -p "$ARTIFACT_DIR"
```

## Run faithful simulation (deterministic)

```bash
SIM_ARTIFACT_ROOT="$ARTIFACT_DIR/simulation"
uv run python -m research.update_guard.cli --user jeremy simulate --strict --json --artifacts-root "$SIM_ARTIFACT_ROOT" > "$ARTIFACT_DIR/simulation-result.json"
```

Read the deterministic report path from structured output:
```bash
REPORT_PATH=$(jq -r '.report_path // empty' "$ARTIFACT_DIR/simulation-result.json")
[ -n "$REPORT_PATH" ] || { echo "simulation-report.json not found"; exit 1; }
cp "$REPORT_PATH" "$ARTIFACT_DIR/simulation-report.json"
```

Note: Update Guard creates a per-run subdirectory under `--artifacts-root`; rely on `.report_path` from JSON output instead of parsing stdout logs.

## Build promotion plan (deterministic)

```bash
uv run python -m research.update_guard.cli promote plan --simulation-report "$ARTIFACT_DIR/simulation-report.json" --artifacts-root "$ARTIFACT_DIR" | tee "$ARTIFACT_DIR/promote-plan.log"
```

Interpret exit code from `promote plan`:
- `0`: simulation safe and promotable paths exist (`status=ready`)
- `1`: simulation safe but nothing to promote (`status=empty`)
- `2`: simulation unsafe (`status=unsafe`)

## Present phase verdict

Read `simulation-report.json` and `promotion-plan.json` and summarise:
- simulation `safe` + discrepancy groups (`code`, `severity`, `count`, top samples)
- promotion buckets:
  - `promotable_shared`
  - `promotable_platform`
  - `ambiguous`
  - `non_promotable_user_or_unknown`
- informational ignore bucket:
  - `ignored_user_bisync_managed_count` (known workspace-sync managed paths; not merge blockers)
- initial selection (`selected_paths_initial`) before ambiguous triage

If status is `unsafe` or `empty`, stop before Stage PR unless Timon explicitly asks to continue for diagnosis-only output.

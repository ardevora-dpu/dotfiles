# Simulate Phase

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

## Run faithful simulation

```bash
SIM_ARTIFACT_ROOT="$ARTIFACT_DIR/simulation"
uv run python -m research.update_guard.cli --user jeremy simulate --strict --artifacts-root "$SIM_ARTIFACT_ROOT" | tee "$ARTIFACT_DIR/simulate.log"
```

Locate the simulation report written under `--artifacts-root`:
```bash
REPORT_PATH=$(find "$SIM_ARTIFACT_ROOT" -type f -name simulation-report.json | sort | tail -1)
[ -n "$REPORT_PATH" ] || { echo "simulation-report.json not found"; exit 1; }
cp "$REPORT_PATH" "$ARTIFACT_DIR/simulation-report.json"
```

Note: Update Guard creates a per-run subdirectory under `--artifacts-root`; do not assume the report path is directly `$SIM_ARTIFACT_ROOT/simulation-report.json`.

## Present verdict

Read `simulation-report.json` and summarise:
- `safe`
- discrepancy groups (`code`, `severity`, `count`, top samples)
- promotion candidates count (`promotion_report.shared_runtime`, `promotion_report.platform`)

If `safe=false`, continue to Build Plan only for diagnosis and stop before Stage PR unless Timon explicitly asks to proceed.

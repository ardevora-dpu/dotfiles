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
3. Create run artefact directory:
```bash
RUN_ID=$(date -u +%Y%m%d-%H%M%S)
ARTIFACT_DIR="workspaces/timon/promotion-artifacts/${RUN_ID}"
mkdir -p "$ARTIFACT_DIR"
```

## Run faithful simulation

```bash
uv run python -m research.update_guard.cli simulate --user jeremy --strict | tee "$ARTIFACT_DIR/simulate.log"
```

Parse the report path from CLI output marker:
```bash
REPORT_PATH=$(awk -F': ' '/\[update-guard\] simulation report:/ {print $2}' "$ARTIFACT_DIR/simulate.log" | tail -1)
```

Copy report into run artefacts:
```bash
cp "$REPORT_PATH" "$ARTIFACT_DIR/simulation-report.json"
```

## Present verdict

Read `simulation-report.json` and summarise:
- `safe`
- discrepancy groups (`code`, `severity`, `count`, top samples)
- promotion candidates count (`promotion_report.shared_runtime`, `promotion_report.platform`)

If `safe=false`, continue to Build Plan only for diagnosis and stop before Stage PR unless Timon explicitly asks to proceed.

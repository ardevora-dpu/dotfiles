# Simulate + Classify Phase

**Path convention:** All commands below use `REPO_ROOT` and `ARTIFACT_DIR` as placeholders. Replace with the absolute literal paths you resolved at the start (see SKILL.md execution model). Do not rely on shell variables persisting across Bash calls.

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
4. Create run artefact directory and resolve to absolute path:
```bash
RUN_ID=$(date -u +%Y%m%d-%H%M%S) && ARTIFACT_DIR="$(pwd)/workspaces/timon/promotion-artifacts/${RUN_ID}" && mkdir -p "$ARTIFACT_DIR" && echo "$ARTIFACT_DIR"
```
Capture the echoed absolute path and use it as a literal in all subsequent Bash calls.
5. Run drift bell (fast path):
```bash
uv run python -m research.update_guard.cli promote status --json > "ARTIFACT_DIR/promotion-status.json"
```

If `promotion-status.json` reports `"status": "clean"`, stop and report "no promotion needed before /update".

## Run faithful simulation (deterministic)

Run from `REPO_ROOT`. Replace `ARTIFACT_DIR` with the literal absolute path:
```bash
uv run python -m research.update_guard.cli --user jeremy simulate --strict --json --artifacts-root "ARTIFACT_DIR/simulation" > "ARTIFACT_DIR/simulation-report.json"
```

Sanity-check simulation output:
```bash
jq -e '.status and (.safe | type == "boolean") and (.discrepancies | type == "array")' "ARTIFACT_DIR/simulation-report.json" >/dev/null
```

Note: Update Guard still writes canonical artefacts under a per-run subdirectory in `--artifacts-root`; this phase keeps a stable copy at `ARTIFACT_DIR/simulation-report.json` for the next steps.

## Build promotion plan (deterministic)

```bash
uv run python -m research.update_guard.cli promote plan --simulation-report "ARTIFACT_DIR/simulation-report.json" --artifacts-root "ARTIFACT_DIR" 2>&1 | tee "ARTIFACT_DIR/promote-plan.log"
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

# Triage + Stage PR Phase

Stage selected promotion files into a single idempotent branch/PR.

## Input

- `$ARTIFACT_DIR/promotion-plan.json` from `update-guard promote plan`

## Interactive triage (required)

1. Read `ambiguous` from `promotion-plan.json`.
2. For each path in `ambiguous`, show both versions:
   - `git show origin/main:<path>`
   - `git show origin/jeremy/checkpoints/live:<path>`
3. Ask Timon to choose `include`, `exclude`, or `defer`.
4. Record triage decisions in `promotion-plan.json` under `triage`.
5. Compute `selected_paths_final` = `selected_paths_initial` + ambiguous items marked `include`.
6. For compatibility, set `selected_paths` = `selected_paths_final`.

## Branch and PR strategy

- Promotion branch: `timon/pre-update-promotion`
- If PR exists for this branch, update it.
- If PR does not exist, create one.

## Stage selected paths

1. Read `selected_paths_final` from `promotion-plan.json`.
2. If `selected_paths_final` is empty after triage, skip branch/PR staging and report "nothing selected for promotion".
3. Resolve checkpoint ref from `promotion-plan.json` (`checkpoint_ref` field).
4. Reset/switch promotion branch from `origin/main`:
```bash
git fetch origin --prune
git checkout -B timon/pre-update-promotion origin/main
```
5. For each selected path in `selected_paths_final`:
- If path exists in checkpoint ref: `git checkout <checkpoint_ref> -- <path>`
- If path deleted in checkpoint ref: remove locally and stage deletion.
6. Stage and commit:
```bash
git add -A -- <selected_paths_final>
git commit -m "ARD-451: pre-/update promotion from Jeremy checkpoint" || true
```
7. Push:
```bash
if git ls-remote --exit-code --heads origin timon/pre-update-promotion >/dev/null; then
  git push --force-with-lease -u origin timon/pre-update-promotion
else
  git push -u origin timon/pre-update-promotion
fi
```

Use `--force-with-lease` only when updating the existing promotion branch to avoid overwriting unexpected remote changes.

If commit is a no-op, do not create a new PR comment; report that main is already converged.

## PR body requirements

Include:
- simulation verdict and report path
- promoted path groups
- non-promoted/blocked paths
- ambiguity triage decisions
- explicit merge gate reminder

Use `gh pr create` or `gh pr edit` idempotently.

# Triage + Stage PR Phase

Stage selected promotion files into a single idempotent branch/PR.

## Input

- `ARTIFACT_DIR/promotion-plan.json` from `update-guard promote plan` (use the literal absolute path resolved at the start)

## Interactive triage (required)

1. Read `ambiguous` from `promotion-plan.json`.
2. For each path in `ambiguous`, show both versions:
   - `git show origin/main:<path>`
   - `git show origin/jeremy/checkpoints/live:<path>`
3. Ask Timon to choose `include`, `exclude`, or `defer`.
4. Record triage decisions in `promotion-plan.json` under `triage`.
5. Compute `selected_paths_final` = `selected_paths_initial` + ambiguous items marked `include`.

## Branch and PR strategy

- Promotion branch: `timon/pre-update-promotion`
- If PR exists for this branch, update it.
- If PR does not exist, create one.

## Stage selected paths

1. Read `selected_paths_final` from `promotion-plan.json`.
2. If `selected_paths_final` is empty after triage, skip branch/PR staging and report "nothing selected for promotion".
3. Resolve checkpoint ref from `promotion-plan.json` (`checkpoint_ref` field).
4. Stage in a dedicated temporary worktree so the current branch stays unchanged:
```bash
PROMO_BRANCH="timon/pre-update-promotion"
PROMO_WORKTREE=$(mktemp -d -t promote-update-XXXXXX)
git fetch origin --prune
git worktree add -B "$PROMO_BRANCH" "$PROMO_WORKTREE" origin/main
```
5. For each selected path in `selected_paths_final`:
- If path exists in checkpoint ref: `git -C "$PROMO_WORKTREE" checkout <checkpoint_ref> -- <path>`
- If path deleted in checkpoint ref: remove locally and stage deletion.
6. Stage and commit:
```bash
git -C "$PROMO_WORKTREE" add -A -- <selected_paths_final>
git -C "$PROMO_WORKTREE" commit -m "ARD-451: pre-/update promotion from Jeremy checkpoint" || true
```
7. Push:
```bash
if git ls-remote --exit-code --heads origin "$PROMO_BRANCH" >/dev/null; then
  git -C "$PROMO_WORKTREE" push --force-with-lease -u origin "$PROMO_BRANCH"
else
  git -C "$PROMO_WORKTREE" push -u origin "$PROMO_BRANCH"
fi
```
8. Always clean up the temporary worktree when done (success or failure):
```bash
git worktree remove --force "$PROMO_WORKTREE"
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

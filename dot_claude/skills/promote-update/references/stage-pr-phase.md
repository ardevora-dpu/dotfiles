# Stage PR Phase

Stage selected promotion files into a single idempotent branch/PR.

## Branch and PR strategy

- Promotion branch: `timon/pre-update-promotion`
- If PR exists for this branch, update it.
- If PR does not exist, create one.

## Stage selected paths

1. Read `selected_paths` from `promotion-plan.json`.
2. Reset/switch promotion branch from `origin/main`:
```bash
git fetch origin --prune
git checkout -B timon/pre-update-promotion origin/main
```
3. For each selected path:
- If path exists in checkpoint ref: `git checkout origin/jeremy/checkpoints/live -- <path>`
- If path deleted in checkpoint ref: remove locally and stage deletion.
4. Stage and commit:
```bash
git add -A -- <selected_paths>
git commit -m "ARD-451: pre-/update promotion from Jeremy checkpoint" || true
```
5. Push:
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

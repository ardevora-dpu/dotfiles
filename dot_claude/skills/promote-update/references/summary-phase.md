# Summary + Merge Gate Phase

## Build structured summary

Summarise from artefacts:

- simulation verdict and key discrepancies
- selected promoted files
- excluded ambiguous files + reasons
- readiness result
- parity result
- PR number/link

Also emit machine-readable summary to `$ARTIFACT_DIR/final-summary.json`.

If this run was declared dry-run, include `dry_run: true` in the summary and stop after presenting findings (no Stage PR, merge, or branch mutation).

## Merge gate (required)

Only run this gate when a promotion PR exists.

Use `AskUserQuestion` with three options:

1. `Merge now (Recommended)` — only when readiness and parity have no blocking findings.
2. `Leave PR open` — do not merge, keep branch/PR for further review.
3. `Abort and clean up` — close loop with no merge.

Never merge without this explicit decision.

## If approved to merge

```bash
gh pr merge <PR_NUMBER> --squash
```

If branch protection blocks merge and Timon explicitly approves bypass for this promotion flow, rerun with admin override:
```bash
gh pr merge <PR_NUMBER> --squash --admin
```

`--admin` bypasses normal protections, so use it only with explicit approval captured in the merge gate decision.

Then draft a Jeremy-facing note based on what was promoted:

- If merged: "Pre-update promotion is complete; you can run /update now."
- If not merged: "Do not run /update yet; promotion review still in progress."

## Cleanup contract

- Remove temporary files (`mktemp` outputs).
- Keep run artefacts in `workspaces/timon/promotion-artifacts/<run-id>/`.
- Ensure no temporary worktree remains if one was created.

## Error recovery / rollback

- Simulation unsafe: stop before Stage PR, publish discrepancy summary, and keep artefacts for diagnosis.
- Wrong files staged on promotion branch: `git checkout origin/main && git branch -D timon/pre-update-promotion` then restart from Build Plan.
- Validation failure after PR update: keep PR open, post failed checks in summary, and defer merge.
- Merge rejected or cancelled: leave PR open unless Timon chooses abort; on abort, close PR and delete remote branch.

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

## Merge gate (required)

Use `AskUserQuestion` with three options:

1. `Merge now (Recommended)` — only when readiness and parity have no blocking findings.
2. `Leave PR open` — do not merge, keep branch/PR for further review.
3. `Abort and clean up` — close loop with no merge.

Never merge without this explicit decision.

## If approved to merge

```bash
gh pr merge <PR_NUMBER> --squash --admin
```

Then draft a Jeremy-facing note based on what was promoted:

- If merged: "Pre-update promotion is complete; you can run /update now."
- If not merged: "Do not run /update yet; promotion review still in progress."

## Cleanup contract

- Remove temporary files (`mktemp` outputs).
- Keep run artefacts in `workspaces/timon/promotion-artifacts/<run-id>/`.
- Ensure no temporary worktree remains if one was created.

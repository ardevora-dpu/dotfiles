# Rollback and Retry

## Simulation unsafe

1. Stop immediately.
2. Resolve discrepancy groups from the report.
3. Re-run the flow from simulation.

## Validation failed (readiness/parity)

1. Leave PR open.
2. Fix failing contract in quinlan or dotfiles.
3. Re-run flow to refresh PR body and validation status.

## Wrong files staged

1. Reset promotion branch to `origin/main`.
2. Re-run flow and verify promotable list before commit.

## Merge rejected

1. Keep PR open for review.
2. Capture blocking items in PR comment.
3. Re-run with `--approve-merge` only after explicit approval.

# Workflow

## 1) Preflight

- Ensure quinlan tracked worktree is clean.
- Ensure `gh`, `uv`, and update_guard simulation command are available.

## 2) Faithful simulation

- Run `update_guard.cli simulate --user jeremy --strict`.
- Parse report path and confirm `safe=true`.
- Review discrepancies before promotion.

## 3) Promotion staging

- Create branch from `origin/main`.
- Promote only `promotion_report.shared_runtime` + `promotion_report.platform` paths.
- Exclude user-managed/bisync paths and unknown ownership paths.

## 4) Validation

- Run `scripts/dev/verify_jeremy_update_readiness.py --mode pr`.
- Run `check_env_parity.py --strict`.
- If either fails, do not merge.

## 5) Merge gate

- Create or update PR to `main`.
- Present summary + risks + suggested Jeremy message.
- Merge only when Timon explicitly approves.

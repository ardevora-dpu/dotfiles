---
name: timon-pre-update-promotion
description: Run faithful simulation, stage a promotion PR, run readiness/parity checks, and gate merge approval before Jeremy runs /update.
argument-hint: "--repo-root ~/projects/quinlan-ard-451 --ticket ARD-451"
---

# Timon Pre-/update Promotion

Automate the pre-`/update` maintainer workflow using ARD-460 foundations.

This is a Timon-only user skill in dotfiles.

## Purpose

1. Verify Jeremy update safety with faithful simulation.
2. Stage promotable runtime changes as a PR to `main`.
3. Validate readiness and environment parity.
4. Require explicit merge approval.

## Command

```bash
uv run python ~/.claude/skills/timon-pre-update-promotion/scripts/run_flow.py \
  --repo-root /path/to/quinlan \
  --ticket ARD-451
```

Optional flags:

```bash
--json-out /tmp/pre-update-promotion.json
--skip-merge
--approve-merge
```

## Workflow

1. Run [references/workflow.md](references/workflow.md).
2. If checks fail, use [references/rollback.md](references/rollback.md).
3. Never merge without explicit Timon approval.

## Support scripts

- `scripts/run_flow.py` — end-to-end promotion orchestration.
- `scripts/check_env_parity.py` — Timon/Jeremy settings parity contract checks.

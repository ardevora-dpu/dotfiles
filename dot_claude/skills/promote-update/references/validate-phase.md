# Validate Phase

Run deterministic readiness checks before merge recommendation.

## Mandatory

```bash
uv run python scripts/dev/verify_jeremy_update_readiness.py --mode pr
```

If this fails: block merge recommendation.

## Advisory update-guard tests

Run when promotion touches update contracts (for example `.claude/skills/update/**`, `packages/research/src/research/update_guard/**`, `ownership.yml`, `scripts/dev/**`):

```bash
uv run pytest packages/research/tests/test_update_guard_unit.py -q
uv run pytest packages/research/tests/test_update_guard_integration.py -q
```

If advisory tests fail, call it out in the summary and default recommendation to "do not merge yet".

Persist command output to:
- `$ARTIFACT_DIR/readiness.log`
- `$ARTIFACT_DIR/advisory-tests.log`

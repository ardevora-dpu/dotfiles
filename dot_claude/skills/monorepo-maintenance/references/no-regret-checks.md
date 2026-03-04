# No-Regret Continuous Checks (Report-Only First)

Start with report-only automation. Add hard failures only after two stable review cycles.

## Weekly/PR Checks

1. Topology integrity
- Declared workspace members exist.
- Optional surfaces (`apps/`) are checked only when present.

2. Boundary integrity
- Import boundary contract checks.
- Cycle detection and dependency depth hotspots.

3. Script reachability report
- List scripts with no non-self references.
- Highlight scripts not wired in workflows/tasks/hooks.

4. Module reachability report
- List modules with no inbound imports and no entrypoint wiring.
- Exclude known CLI entry modules and test-only helpers.

5. Documentation drift report
- Config claims vs live config values.
- Broken internal path references.
- Non-archive docs marked expired/draft/deprecated without replacement links.

## Suggested Output Artefacts

- `repo-hygiene-report.json` (machine-readable)
- CI summary table with:
  - High-confidence candidates
  - Medium-confidence candidates
  - Drift findings requiring doc updates

## Promotion Policy

- Cycle 1-2: report-only
- Cycle 3+: fail only on high-confidence contract breaks:
  - broken critical references
  - doc-to-config contradictions in active setup docs
  - missing canonical replacement for declared deprecations

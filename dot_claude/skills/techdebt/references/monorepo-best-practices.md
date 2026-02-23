# Monorepo Best Practices (Quick Reference)

## Principles
- Keep a single source of truth for tooling and dependency pinning.
- Prefer hermetic builds where inputs and outputs are explicit and deterministic.
- Use a project graph and affected builds to limit work to what changed.
- Invest in repo-wide tooling to keep large-scale changes safe and fast.

## Evidence and sources
- Google reports productivity gains from a single repository but emphasises the need for strong tooling and governance.
  https://cacm.acm.org/research/why-google-stores-billions-of-lines-of-code-in-a-single-repository/
- Bazel defines hermetic builds as not depending on ambient system state and being insensitive to the host machine.
  https://bazel.build/basics/hermeticity
- Reproducible Builds defines reproducibility as identical outputs from identical inputs, across time and machines.
  https://reproducible-builds.org/docs/definition/
- Nx explains project graph + caching to keep monorepo builds fast and scoped to affected work.
  https://nx.dev/concepts/how-nx-works

## Applied to Quinlan
- Toolchain pins live in `mise.toml` and should be treated as canonical.
- Python reproducibility depends on `uv.lock` plus `uv sync` through `scripts/dev/env.sh`.
- Avoid local-only scripts that bypass `scripts/dev/env.sh` or introduce new one-off steps.

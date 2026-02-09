# Tech Debt Audit Checklist

## Scope and output
- [ ] Confirm scope, time budget, and output type (report only vs fixes)
- [ ] Confirm whether to open Linear issues
- [ ] List any directories or systems that are off-limits

## Sprawl inventory
- [ ] Enumerate package manifests and lockfiles
- [ ] Identify external services and MCP servers in use
- [ ] Note toolchain pins and environment entrypoints
- [ ] Check for submodules or vendored code

## Python dead code
- [ ] Run `vulture` with `--min-confidence 80` for unused code hints
- [ ] Run `eradicate` to find commented-out code blocks
- [ ] Run `deptry` for unused dependencies in pyproject.toml
- [ ] Compare root dev group vs per-package dependencies
- [ ] Flag duplicates and heavy dependencies without clear usage

## JavaScript/Node dead code
- [ ] Run `knip` for comprehensive detection (files, exports, deps)
- [ ] Run `knip --production` to focus on shipped code
- [ ] Run `depcheck` for config-file dependencies Knip might miss

## Duplicate code and circular dependencies
- [ ] Run `jscpd` with `--min-lines 10` across packages/
- [ ] Run `madge --circular` for JS/TS circular dependencies
- [ ] Check for Python cycles if suspected

## dbt model hygiene
- [ ] Find orphan models using set subtraction (all models minus those connected to exposures)
- [ ] Run `dbt-project-evaluator` for DAG analysis (run `dbt deps` first)
- [ ] Query Snowflake ACCESS_HISTORY for tables not accessed in 90+ days
- [ ] Check for models missing `deprecation_date` before removal

## Zombie features and abandoned code
- [ ] Identify files with no git commits in 12+ months
- [ ] Check for functions with high complexity but zero coverage
- [ ] Review ownership with `git log` to find unclear maintainers
- [ ] Flag code that is maintained but never executed

## Reproducibility
- [ ] Verify `mise.toml` pins and lockfile presence
- [ ] Confirm `scripts/dev/env.sh` is the default entrypoint
- [ ] Note any manual steps in docs that lack scripts

## Dotfiles and shell stability
- [ ] Locate chezmoi source repo and confirm single source of truth
- [ ] Review `dot_bashrc` and terminal config for flaky patterns
- [ ] Check for hidden dependencies or machine-specific assumptions
- [ ] Note: Dotfiles are a separate repo — flag issues, don't modify

## Naming and structure
- [ ] Check package names match folder names
- [ ] Validate dbt naming conventions and schema tiers
- [ ] Flag mixed-purpose directories

## Output
- [ ] Produce findings table with evidence
- [ ] Prioritise actions by risk and effort
- [ ] Propose or create Linear issues if requested

---
name: techdebt
description: Audit and reduce tech debt in the Quinlan monorepo. Use for sprawl checks, dependency pruning, reproducibility audits, and dead-code cleanup.
---

# Tech Debt Audit

## Overview

This skill runs an evidence-first audit of monorepo sprawl and produces a prioritised, low-risk clean-up plan. It can stop at a report or proceed to targeted fixes with tests.

## When to use

- User asks for a tech debt sweep, repo hygiene, or "what can we delete".
- Planning a refactor that risks dependency sprawl or "works on my machine".
- Preparing for onboarding, portability, or reproducible builds.

> **Use Claude Tasks** to track the 12 steps below. This audit generates substantial output — tasks prevent skipping steps as context fills.

## Instructions

1. Confirm scope and output.
   Ask for scope (full repo vs specific packages), time budget, and output type (report only vs fixes).
   Ask whether to open Linear issues and which directories are off-limits.
   **Do not create Linear issues without explicit approval.** If the user wants issues created, ask for confirmation before creating any.

2. Inventory sprawl and tooling.
   Run these commands and summarise counts and hotspots.
   ```bash
   rg --files -g "package.json" -g "pyproject.toml" -g "uv.lock" -g "dbt_project.yml" -g "requirements*.txt"
   rg -n "mcpServers|statusLine|hooks" -S .claude .mcp.json
   rg -n "mise.toml|env.sh|machine.dsc.yaml" -S .
   git submodule status
   ```
   If a ripgrep pattern needs newline matching, use multiline mode (`rg -U` or `--multiline`). Avoid `\n` patterns without `-U`, which fail with "literal \\n is not allowed in a regex".

3. Split investigation by area.
   If subagents are available, delegate four tracks: dependency sprawl and duplication; reproducibility and environment drift; dead code and unused assets; naming conventions and package boundaries.
   If subagents are not available, work through these in order and keep notes separate.

4. Dependency audit (Python + Node).
   **Python dead code:**
   ```bash
   # Unused functions/classes (static analysis, high confidence)
   uv run vulture packages --min-confidence 80

   # Commented-out code blocks (report only — no modification)
   uvx eradicate packages/

   # Unused dependencies in pyproject.toml
   uvx deptry .
   ```
   Compare root `pyproject.toml` dev group to per-package dependencies and flag duplicates.

   **Node dead code** (run from frontend directory):
   ```bash
   # Comprehensive check: unused files, exports, deps, class members
   cd apps/repo-prompt/frontend && npx knip

   # Production-only (shipped code)
   cd apps/repo-prompt/frontend && npx knip --production

   # Config-file dependencies Knip might miss
   cd apps/repo-prompt/frontend && npx depcheck
   ```

5. Duplicate code and circular dependencies.
   ```bash
   # Duplicate code across packages (min 10 lines)
   npx jscpd packages/ --min-lines 10 --reporters console

   # Circular dependencies in JS/TS
   npx madge --circular packages/ apps/
   ```
   For Python, use `pydeps --show-cycles packages/` if cycles are suspected.

6. dbt model hygiene.
   **DAG analysis — find orphan models (not connected to any exposure):**
   ```bash
   # Step 1: List all models
   dbt ls --resource-type model --output name > all_models.txt

   # Step 2: List models connected to exposures (upstream of any exposure)
   dbt ls --select +exposure:* --resource-type model --output name > connected_models.txt

   # Step 3: Find orphans (in all but not in connected)
   comm -23 <(sort all_models.txt) <(sort connected_models.txt)
   ```

   **dbt-project-evaluator** (DAG analysis and best practices):
   ```bash
   # Ensure packages are installed (use dev target to avoid production)
   dbt deps --target dev

   # Run evaluator for orphan models, unused sources, etc.
   dbt run --select package:dbt_project_evaluator --target dev
   ```

   **Snowflake query history (requires ACCOUNTADMIN):**
   Check `references/snowflake-unused-tables.md` for queries to find tables not accessed in 90+ days.

   **Safe deprecation:** Add `deprecation_date` to model YAML before removal. See `references/dbt-deprecation.md`.

7. Zombie features and abandoned code.
   Look for code that is maintained but never used:
   - Files with no git commits in 12+ months but still imported
   - Functions with high complexity but zero test coverage
   - Feature flags that are always on/off (if using feature flags)
   - API endpoints with no recent traffic (check logs or observability)

   **Ownership check:** Use `git log --format='%an' -- <path> | sort | uniq -c | sort -rn` to find files with unclear ownership.

8. Reproducibility and "works on my machine" risk.
   Verify toolchain pins in `mise.toml`, lockfile coverage in `uv.lock`, and that `scripts/dev/env.sh` is the single entrypoint for secrets and PATH.
   Note any manual steps in docs that are not scripted.

9. Naming and structure.
   Check package names align with folder names.
   Validate dbt naming conventions: `stg_`, `int_`, `canonical`, `mart`.
   Identify mixed-purpose directories and propose splits.

10. Dotfiles and shell stability.
    Review the dotfiles repo (chezmoi source at `~/.local/share/chezmoi`), especially `dot_bashrc` and terminal config.
    Check for indirection, hidden dependencies, flaky patterns, or machine-specific assumptions.
    Prefer stable, explicit patterns; reconsolidate or simplify where appropriate.
    **Note:** Dotfiles are a separate repository — flag issues but do not modify directly.

11. Produce the report.
    Output a concise table with columns: Area, Finding, Evidence, Risk, Recommendation, Effort.
    End with a prioritised action list and suggested Linear issues if requested.
    If issue creation is requested, ask for explicit approval before creating any Linear tasks.

12. If implementing fixes:
   **Get explicit user confirmation before running any mutating commands.**
   Touch the smallest surface area.
   Prefer delete over refactor when safe.
   Run relevant tests or linters and report results.
   Avoid canonical dbt changes without downstream impact review.
   In `packages/` and `apps/`, follow Formal mode standards (types on public APIs, tests for business logic).

   **Mutating commands (use only after confirmation):**
   ```bash
   # Python: Remove commented-out code
   uvx eradicate packages/ --in-place --aggressive

   # Python: Auto-fix dead code (scope-aware)
   uvx deadcode packages/ --fix

   # Node: Auto-fix unused exports
   npx knip --fix
   ```

## Examples

**Example 1**
Input: Run a full tech debt audit and produce a prioritised report. No code changes.
Output:
```
Tech Debt Findings
Area | Finding | Evidence | Risk | Recommendation | Effort
...
```

**Example 2**
Input: Focus on dependency sprawl in packages/ and remove unused Python code.
Output:
```
- vulture findings with file paths
- deletion plan with tests to run
```

**Example 3**
Input: Check reproducibility and "works on my machine" risks across the repo.
Output:
```
- toolchain pins summary
- missing scripts or manual steps
```

## References

- `references/monorepo-best-practices.md` — Principles for hermetic builds and reproducibility
- `references/techdebt-checklist.md` — Step-by-step audit checklist
- `references/snowflake-unused-tables.md` — Queries to find tables not accessed in 90+ days
- `references/dbt-deprecation.md` — Safe model deprecation workflow
- `references/tools-quick-ref.md` — Command cheatsheet for all detection tools

# Tech Debt Detection Tools — Quick Reference

Command cheatsheet for all detection tools used in the techdebt skill.

---

## Python Dead Code

**Report only (safe for audit mode):**
```bash
# Unused functions/classes (static analysis, high confidence)
uv run vulture packages --min-confidence 80

# Scope-aware detection (report only)
uvx deadcode packages/

# Commented-out code blocks (report only)
uvx eradicate packages/

# Unused dependencies in pyproject.toml
uvx deptry .

# Cross-package dependency validation (for uv workspaces)
uvx tach check
```

**Auto-fix (requires explicit user confirmation):**
```bash
# Remove commented-out code blocks
uvx eradicate packages/ --in-place --aggressive

# Scope-aware detection with auto-fix
uvx deadcode packages/ --fix
```

---

## JavaScript/Node Dead Code

**Note:** Run these commands from the Node project directory (e.g., `cd apps/repo-prompt/frontend && ...`).

**Report only (safe for audit mode):**
```bash
# Comprehensive: unused files, exports, deps, class members
npx knip

# Production-only (shipped code)
npx knip --production

# Config-file dependencies Knip might miss
npx depcheck

# Unused files (dangling imports)
npx unimported
```

**Auto-fix (requires explicit user confirmation):**
```bash
# Auto-fix unused exports
npx knip --fix
```

---

## Duplicate Code

```bash
# Cross-language duplicate detection (150+ languages)
npx jscpd packages/ --min-lines 10 --reporters console
```

*Note: For Java projects, `pmd cpd` provides more detailed analysis. Not used in this repo.*

---

## Circular Dependencies

```bash
# JavaScript/TypeScript
npx madge --circular packages/ apps/

# Zero-config detector
npx circular-dependency-scanner packages/

# Python (requires pydeps installed)
uv run pydeps --show-cycles packages/
```

---

## dbt Model Hygiene

```bash
# Find orphan models (not connected to any exposure)
# Step 1: List all models
dbt ls --resource-type model --output name > all_models.txt

# Step 2: List models connected to exposures
dbt ls --select +exposure:* --resource-type model --output name > connected_models.txt

# Step 3: Find orphans (set subtraction)
comm -23 <(sort all_models.txt) <(sort connected_models.txt)

# List all models with deprecation dates
dbt ls --select config.deprecation_date:*
```

**dbt-project-evaluator** (DAG analysis and best practices):
```bash
# Ensure packages are installed (use dev target)
dbt deps --target dev

# Run evaluator for orphan models, unused sources, etc.
dbt run --select package:dbt_project_evaluator --target dev
```

---

## Snowflake Usage

```sql
-- Tables not accessed in 90 days (Enterprise)
-- See references/snowflake-unused-tables.md for full query

-- Quick check: most expensive tables by storage
SELECT table_name, bytes / (1024*1024*1024) AS size_gb
FROM snowflake.account_usage.tables
WHERE table_catalog = 'QUINLAN' AND deleted IS NULL
ORDER BY bytes DESC LIMIT 20;
```

---

## Ownership and Hotspots

```bash
# File ownership by commit count
git log --format='%an' -- <path> | sort | uniq -c | sort -rn

# Files with no commits in 12 months
git log --since="12 months ago" --name-only --pretty=format: | sort -u > recent.txt
git ls-files | sort > all.txt
comm -23 all.txt recent.txt

# High-churn files (potential hotspots)
git log --format=format: --name-only --since="6 months ago" | \
  grep -v '^$' | sort | uniq -c | sort -rn | head -20
```

---

## Coverage-Based Confirmation

```bash
# Run tests with coverage
uv run pytest --cov=packages --cov-report=html

# Find files with 0% coverage (never executed)
uv run coverage report --show-missing | grep "0%"
```

---

## Tool Installation

Most tools run via `npx` or `uvx` without installation. For persistent use:

```bash
# Python tools (add to dev dependencies)
uv add --dev vulture eradicate deptry

# Node tools (add to devDependencies)
npm install -D knip jscpd madge
```

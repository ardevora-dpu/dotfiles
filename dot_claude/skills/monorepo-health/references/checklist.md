# Monorepo Health Review Checklist

Use this checklist for quarterly reviews or after significant structural changes.

## 1. Workspace Integrity

### 1.1 Workspace members exist

Every member declared in `pyproject.toml` must have a corresponding directory with `pyproject.toml`.

```bash
# Check for ghost members
grep -E "^\s+\"(packages|apps)/" pyproject.toml | \
  sed 's/.*"\([^"]*\)".*/\1/' | \
  while read pkg; do
    if [ ! -f "$pkg/pyproject.toml" ]; then
      echo "GHOST: $pkg (declared but missing pyproject.toml)"
    fi
  done
```

**Fix:** Remove ghost entries or create the package.

### 1.2 No orphaned directories

Directories with only `__pycache__` are cruft from refactoring.

```bash
# Find orphaned directories
for dir in $(find apps packages -type d -name "__pycache__" -exec dirname {} \; | sort -u); do
  py_files=$(find "$dir" -type f -name "*.py" 2>/dev/null | wc -l)
  if [ "$py_files" -eq 0 ]; then
    echo "ORPHAN: $dir"
  fi
done
```

**Fix:** Delete orphaned directories.

### 1.3 Lockfile is current

```bash
uv lock --check
```

**Fix:** Run `uv lock` if check fails.

---

## 2. Dependency Health

### 2.1 No circular dependencies

Circular dependencies make refactoring impossible and indicate unclear boundaries.

```bash
# With import-linter configured
uv run lint-imports

# Quick check without import-linter
uv run python -c "
import importlib.util
import sys
# ... (complex, use import-linter instead)
"
```

**Fix:** Break cycles by:
- Extracting shared code to a new lower-level package
- Using dependency injection
- Inverting the dependency (have the lower layer define an interface)

### 2.2 Dependency depth is reasonable

Deep transitive chains slow builds and make impact analysis hard.

```bash
uv tree --depth 5 | head -50
```

Look for chains deeper than 4-5 levels.

### 2.3 No unused dependencies

```bash
# Check for unused direct dependencies (requires vulture)
uv run vulture packages/ --min-confidence 60 | grep "unused import"
```

---

## 3. Architecture Boundaries

### 3.1 Layer violations (import-linter)

With `.importlinter` configured:

```bash
uv run lint-imports
```

Without import-linter, manual spot-check:

```bash
# Check if datasources imports from higher layers (bad)
grep -r "from workbench" packages/datasources/
grep -r "from scanner" packages/datasources/
grep -r "from signals" packages/datasources/

# Check if apps are imported by packages (bad)
grep -r "from workbench_backend" packages/
```

### 3.2 Scripts not imported

`scripts/` should contain operational code, not importable modules.

```bash
# Check if anything imports from scripts
grep -r "from scripts" packages/ apps/
grep -r "import scripts" packages/ apps/
```

**Fix:** If scripts are being imported, promote them to `packages/`.

---

## 4. Code Quality

### 4.1 Dead code detection

```bash
uv run vulture packages/ --min-confidence 80 --sort-by-size | head -30
```

Focus on high-confidence findings. Review but don't auto-delete low-confidence.

### 4.2 Type coverage

```bash
# Generate type coverage report
uv run mypy packages/ --txt-report /tmp/mypy-coverage 2>/dev/null
cat /tmp/mypy-coverage/index.txt | tail -20
```

Track coverage % over time. Target: increasing trend.

### 4.3 Test coverage for formal code

```bash
uv run pytest packages/ --cov=packages --cov-report=term-missing | tail -30
```

`packages/` (Formal Mode) should have tests. `workspaces/` (Fast Mode) is optional.

---

## 5. Structural Hygiene

### 5.1 Naming consistency

Review package names for:
- **Redundant nesting**: `workbench/backend/workbench_backend` (bad)
- **Unclear purpose**: `utils`, `helpers`, `common` (vague)
- **Technology in name**: `fastapi_app`, `postgres_client` (couples to implementation)

### 5.2 Flat structure maintained

```bash
# Find deeply nested files (>6 path components)
find packages apps -type f -name "*.py" | awk -F/ 'NF>6' | head -20
```

Deep nesting suggests unclear boundaries or premature abstraction.

### 5.3 No naming collisions

```bash
# Check for duplicate directory names at different levels
find . -type d -name "notebooks" 2>/dev/null
find . -type d -name "tests" 2>/dev/null  # (tests at multiple levels is OK)
```

### 5.4 Consistent src/ layout

Check if packages use consistent layout:

```bash
# List package structures
for pkg in packages/*/; do
  if [ -d "$pkg/src" ]; then
    echo "$pkg uses src/ layout"
  else
    pkg_name=$(basename "$pkg")
    if [ -d "$pkg$pkg_name" ]; then
      echo "$pkg uses flat layout"
    fi
  fi
done
```

**Recommendation:** Standardise on `src/` layout for all packages.

---

## 6. Duplication & Sprawl

### 6.1 Rule of three check (manual)

If you see similar logic in two places, keep it local. When the third copy appears, extract it.

### 6.2 Complexity hotspots

```bash
uv run ruff check --select C901 packages apps
```

Use this as a prompt for refactoring, not an automatic gate.

### 6.3 Generic shared packages

```bash
find packages apps -mindepth 2 -maxdepth 2 -type d \( -name "utils" -o -name "common" -o -name "helpers" \) -print
```

**Fix:** If a generic package exists, rename it to a domain name or add a README/ADR that defines its scope and owner.

### 6.4 Clone detection (optional)

If you want a deeper duplication scan, consider `jscpd`. This requires adding a dependency.

---

## 7. Documentation Currency

### 7.1 ADRs match reality

Review `docs/platform/adr/` — do decisions documented there match current implementation?

### 7.2 CLAUDE.md subdirectory files are current

```bash
find . -name "CLAUDE.md" -not -path "./.git/*" -not -path "./.venv/*"
```

Review each for staleness.

### 7.3 CODEOWNERS is current (if exists)

Check that ownership assignments match current team structure.

---

## 8. Performance Indicators

### 8.1 Large files

Files >500 lines often need splitting:

```bash
find packages apps -name "*.py" -exec wc -l {} \; | \
  awk '$1 > 500 {print}' | sort -rn | head -10
```

### 8.2 High churn files

Files changing frequently may indicate unclear responsibility:

```bash
git log --format=format: --name-only --since="3 months ago" -- packages/ apps/ | \
  grep -E "\.py$" | sort | uniq -c | sort -rn | head -10
```

### 8.3 Fan-in / Fan-out

High fan-in (many dependents) = critical, needs stability.
High fan-out (many dependencies) = complex, may need refactoring.

```bash
# Fan-in: who depends on datasources?
uv tree --invert --package datasources 2>/dev/null | wc -l

# Fan-out: what does workbench depend on?
uv tree --package workbench --depth 1 2>/dev/null | wc -l
```

---

## Review Summary Template

After completing the checklist, summarise findings:

```markdown
## Monorepo Health Review - [DATE]

### Issues Found
- [ ] Issue 1 (severity: high/medium/low)
- [ ] Issue 2

### Metrics
- Type coverage: X%
- Dead code (80%+ confidence): N items
- Boundary violations: N
- Max dependency depth: N

### Actions
1. Action 1 (owner, deadline)
2. Action 2

### Notes
Any patterns observed, recommendations for next review.
```

---
name: monorepo-health
description: Audit and improve monorepo structure, detect drift, enforce boundaries. Use when adding packages, quarterly reviews, or when structure feels unwieldy. (project)
---

# Monorepo Health Review

This skill helps you maintain a healthy, navigable monorepo. Use it for **periodic reviews** (quarterly), **before adding new packages**, or **when something feels off** about the structure.

## When to Use This Skill

- Adding a new package to `packages/` or `apps/`
- Quarterly health reviews
- After a burst of feature work (drift detection)
- When imports feel convoluted
- When someone asks "where does X live?"

## The Core Problem

Python has **no import isolation**. Any package can accidentally import from any other workspace member's dependencies. Unlike Rust/Go, Python can't enforce boundaries at the language level, so **tooling and convention must do the heavy lifting**.

Small structural compromises compound into "dependency soup" that's painful to untangle.

## Quick Health Check (5 minutes)

Run these commands to get a quick pulse:

```bash
# 1. Workspace members match filesystem?
uv pip list --strict 2>&1 | head -20

# 2. Ghost members in pyproject.toml? (checks both packages/ and apps/)
grep -E "^\s+\"(packages|apps)/" pyproject.toml | sed 's/.*"\([^"]*\)".*/\1/' | while read pkg; do
  [ ! -f "$pkg/pyproject.toml" ] && echo "GHOST: $pkg declared but missing pyproject.toml"
done

# 3. Orphaned directories (pycache only)?
find apps packages -type d -name "__pycache__" -exec dirname {} \; | sort -u | while read dir; do
  files=$(find "$dir" -type f -name "*.py" 2>/dev/null | wc -l)
  [ "$files" -eq 0 ] && echo "ORPHAN: $dir (no .py files)"
done

# 4. Deep nesting check (>4 levels from root)?
find packages apps -type f -name "*.py" | awk -F/ 'NF>6 {print}' | head -10

# 5. Boundary violations (if import-linter configured)
[ -f .importlinter ] && uv run lint-imports

# 6. Reverse dependency analysis
uv tree --invert --package datasources 2>/dev/null | head -20
```

## Full Review Checklist

Load `references/checklist.md` for the comprehensive quarterly review process.

**Summary of checks:**

| Category | Automated? | Tool/Command |
|----------|------------|--------------|
| Ghost workspace members | Yes | grep + filesystem check |
| Orphaned directories | Yes | find (pycache-only dirs) |
| Circular dependencies | Yes | import-linter |
| Boundary violations | Yes | import-linter |
| Dead code | Yes | vulture |
| Type coverage | Yes | mypy --txt-report |
| Naming consistency | No | Human review |
| Ownership clarity | No | Human review |
| ADR currency | No | Human review |

## Architectural Layers (Quinlan-specific)

This repo follows a layered architecture. The layer model is enforced by `.importlinter` (see Tooling section).

```
apps/                    # Deployables (FastAPI, CLI)
    ↓ can import
packages/                # Reusable libraries
    ├── workbench/       # Domain logic, contracts
    ├── scanner/         # Tool 1 logic
    ├── signals/         # Indicators, computations
    ├── notebooks/       # Chart helpers, themes (uses datasources)
    └── datasources/     # Data access layer (lowest)

warehouse/               # dbt (SQL transformations)
scripts/                 # Operational (not imported)
workspaces/              # Fast mode scratch
```

**Default rules** (enforced by import-linter):
- `apps/` can import from `packages/`, never reverse
- Higher layers can import from lower layers, not vice versa
- `datasources/` is the base layer — should not import from other internal packages

**Escape hatches:**
- These boundaries are recommendations, not religion. If you need to break a rule, document why in a comment or ADR.
- To add an exception in import-linter, use `ignore_imports` in the contract.
- For temporary violations during refactoring, comment the contract and create a Beads issue to fix it.

## Code Shape & Duplication (Monorepo-specific)

Aim for code that stays coherent as the repo grows. Avoid sprawl and wrong abstractions.

**Guidelines:**
- **Rule of three**: tolerate duplication twice; extract on the third instance.
- **Prefer intent over DRY**: local clarity beats shared helpers. If duplication is intentional, add a short comment linking the related location.
- **Place logic at the lowest sensible layer**: domain logic stays with its domain; cross-cutting utilities move down a layer, but only when a real shared need appears.
- **Avoid generic shared packages** (`utils`, `common`, `helpers`): if you must add one, document scope and ownership in a README or ADR.

### Duplication Checks (optional)

```bash
# Complexity hotspots (sprawl risk)
uv run ruff check --select C901 packages apps

# Flag new top-level generic packages
find packages apps -mindepth 2 -maxdepth 2 -type d \( -name "utils" -o -name "common" -o -name "helpers" \) -print
```

If you want clone detection, consider `jscpd` (requires dependency approval).

## Naming Conventions

### Package naming

```
# Good: name matches import
packages/datasources/src/datasources/  → import datasources
packages/workbench/src/workbench/      → import workbench

# Bad: redundant nesting
apps/workbench/backend/workbench_backend/  # "backend" and "workbench_backend" both?
```

### Directory vs module names

- **Directory**: `kebab-case` (e.g., `workbench-backend`)
- **Python module**: `snake_case` (e.g., `workbench_backend`)
- **pyproject.toml name**: `kebab-case` (matches directory)

This is Python convention — hyphens in package names, underscores in import names.

### Flat over deep

Prefer shallow hierarchies where purpose is visible from top-level.

**Illustrative example** (not current repo structure):
```
# Good: purpose clear at top level
apps/
├── workbench-api/
├── workbench-frontend/
└── repo-prompt/

# Avoid: nested with unclear boundaries
apps/
└── workbench/
    ├── backend/
    │   └── workbench_backend/
    └── frontend/
```

The current repo has some nesting that predates these conventions. When adding new packages, prefer the flatter pattern. Refactoring existing structure is a judgement call — weigh the churn against the benefit.

## Common Anti-Patterns

Load `references/anti-patterns.md` for detailed examples.

| Anti-Pattern | Why It's Bad | Do Instead |
|--------------|--------------|------------|
| Ghost workspace member | uv can fail silently | Remove or create |
| `__pycache__`-only dirs | Confuses navigation | Delete cruft |
| Importing from `scripts/` | Scripts aren't packages | Promote to package |
| Deep redundant nesting | Verbose paths, unclear boundaries | Flatten |
| Root-level naming collision | Confusion (e.g., `notebooks/` vs `packages/notebooks`) | Rename one |
| Large scripts (>500 lines) | Should have tests, be reusable | Promote to package |

## Tooling

### import-linter (boundary enforcement)

The repo has `.importlinter` configured at the root. It defines:
- **Main layers contract**: Enforces that higher layers only import from lower layers
- **Datasources base contract**: Ensures `datasources` doesn't import from other internal packages

```bash
# Run boundary check
uv run lint-imports

# Example output when all contracts pass:
# Main application layers KEPT
# Datasources is lowest layer KEPT
# Contracts: 2 kept, 0 broken.
```

To modify boundaries, edit `.importlinter`. See [import-linter docs](https://import-linter.readthedocs.io/) for contract types.

### vulture (dead code detection)

```bash
uv run vulture packages/ --min-confidence 80 --sort-by-size
```

Focus on 80%+ confidence findings. Lower confidence has false positives.

### uv tree (dependency analysis)

```bash
# Who depends on datasources?
uv tree --invert --package datasources

# Full dependency tree
uv tree

# Outdated packages
uv tree --outdated
```

## Workflow: Adding a New Package

1. **Choose location**: `packages/` (library) or `apps/` (deployable)
2. **Naming**: `kebab-case` directory, `snake_case` module
3. **Structure**: Use `src/` layout for packages

```bash
# Create structure
mkdir -p packages/my-package/src/my_package
mkdir -p packages/my-package/tests

# Create pyproject.toml
cat > packages/my-package/pyproject.toml << 'EOF'
[project]
name = "my-package"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = []

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/my_package"]
EOF

# Add to workspace
# Edit root pyproject.toml, add to members list

# Verify
uv sync
uv run python -c "import my_package"
```

4. **Update import-linter** if adding a new layer
5. **Run health check** after adding

## Quarterly Review Process

1. Run quick health check (above)
2. Load `references/checklist.md` for full checklist
3. Fix any automated issues found
4. Review naming/ownership (human judgement)
5. Update ADRs if architecture changed
6. Document any new conventions discovered

## Key Metrics to Track

- Type coverage % (mypy)
- Dead code lines (vulture)
- Boundary violations (import-linter)
- Circular dependency count
- Max dependency depth (uv tree)

Consider tracking these in a simple JSON file over time to spot trends.

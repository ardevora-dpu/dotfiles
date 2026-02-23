# Monorepo Anti-Patterns

Common structural problems and how to fix them.

---

## 1. Ghost Workspace Members

**What it is:** A package declared in `pyproject.toml` workspace members that doesn't exist on the filesystem.

**Example:**
```toml
# pyproject.toml
[tool.uv.workspace]
members = [
    "packages/datasources",
    "packages/screening",    # <-- doesn't exist!
]
```

**Why it's bad:**
- `uv sync` may fail silently or with confusing errors
- Other developers waste time looking for non-existent code
- Indicates incomplete refactoring

**Fix:**
- Remove the entry, or
- Create the package with minimal `pyproject.toml`

---

## 2. Orphaned Directories

**What it is:** Directories containing only `__pycache__/` with no source files.

**Example:**
```
apps/workbench/workbench_api/
├── __pycache__/
└── routers/
    └── __pycache__/
```

**Why it's bad:**
- Confuses navigation ("is this code live?")
- Git won't track empty dirs, but IDE shows `__pycache__`
- Indicates incomplete cleanup after refactoring

**Fix:**
```bash
# Find and remove
find apps packages -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
# Then remove empty parent directories
find apps packages -type d -empty -delete
```

---

## 3. Redundant Nesting

**What it is:** Directory names repeated at multiple levels, creating unnecessarily deep paths.

**Example:**
```
# Bad
apps/workbench/backend/workbench_backend/routers/api.py
#    ↑         ↑       ↑
#    Three mentions of "workbench" concept

# Good
apps/workbench-api/src/workbench_api/routers/api.py
#    ↑              ↑
#    Clear: it's the workbench API
```

**Why it's bad:**
- Import paths become verbose: `from workbench_backend.routers.api import ...`
- Unclear what each level contributes
- Navigation friction ("which workbench folder?")

**Fix:**
- Flatten: merge redundant levels
- Rename: make each level's purpose distinct

---

## 4. Root-Level Naming Collision

**What it is:** Same name used for different purposes at root level.

**Example:**
```
quinlan/
├── notebooks/           # User scratch space (marimo notebooks)
└── packages/
    └── notebooks/       # Helper library (theme, charts)
```

**Why it's bad:**
- "Which notebooks?" confusion
- IDE autocomplete suggests wrong one
- Documentation becomes ambiguous

**Fix:**
- Rename one: `exploration/` for scratch space
- Or: `packages/notebook-helpers/` for the library

---

## 5. Technology-Coupled Names

**What it is:** Package names that embed implementation details.

**Example:**
```
packages/
├── fastapi-backend/     # What if we switch to Litestar?
├── postgres-client/     # What if we add MySQL?
└── redis-cache/         # Couples name to implementation
```

**Why it's bad:**
- Names become lies when implementation changes
- Encourages tight coupling ("it's the Postgres package, put all Postgres here")
- Makes migration harder (psychological barrier to changing "postgres-client")

**Good alternatives:**
```
packages/
├── api/                 # Or: web-api, http-layer
├── database/            # Or: persistence, data-access
└── cache/               # Implementation is internal detail
```

---

## 6. Scripts as Importable Modules

**What it is:** Code in `scripts/` being imported by `packages/` or `apps/`.

**Example:**
```python
# packages/signals/src/signals/indicators.py
from scripts.compute_dmi_adx import calculate_dmi  # Bad!
```

**Why it's bad:**
- `scripts/` isn't installed as a package
- Import works only when running from repo root
- No tests, types, or quality gates on scripts

**Fix:**
- If the code is reusable, promote it to a package
- If it's truly one-off operational code, don't import it

---

## 7. Inconsistent Source Layouts

**What it is:** Some packages use `src/` layout, others don't.

**Example:**
```
packages/
├── datasources/
│   └── src/              # src/ layout
│       └── datasources/
├── scanner/
│   └── src/              # src/ layout
│       └── scanner/
└── signals/
    └── signals/          # flat layout (no src/)
        └── __init__.py
```

**Why it's bad:**
- Different `pyproject.toml` configurations needed
- Cognitive overhead ("which layout is this package?")
- `hatch.build.targets.wheel.packages` varies

**Fix:**
- Pick one layout (recommendation: `src/` layout)
- Migrate all packages to match
- Document the standard

**Why `src/` layout is preferred:**
- Forces you to install the package to test it
- Prevents accidental imports of uninstalled code
- Cleaner separation of source, tests, config

---

## 8. Vague Package Names

**What it is:** Names that don't communicate purpose.

**Examples:**
```
packages/
├── utils/        # What utils? For whom?
├── common/       # Shared by what?
├── helpers/      # Helping with what?
├── core/         # Core of what?
└── shared/       # Shared between what?
```

**Why it's bad:**
- Becomes a dumping ground for miscellaneous code
- Unclear ownership ("who maintains utils?")
- Grows unbounded

**Fix:**
- Name by domain: `datasources`, `signals`, `indicators`
- Name by capability: `authentication`, `persistence`, `formatting`
- Split vague packages into focused ones

---

## 9. Circular Dependencies

**What it is:** Package A imports from B, and B imports from A.

**Example:**
```python
# packages/signals/src/signals/compute.py
from datasources.client import get_data  # OK

# packages/datasources/src/datasources/enrichment.py
from signals.indicators import add_momentum  # Circular!
```

**Why it's bad:**
- Import order becomes fragile
- Can't extract either package independently
- Indicates unclear layer boundaries

**Fix options:**
1. **Extract shared code** to a lower-level package
2. **Invert dependency** — have lower layer define interface, higher implements
3. **Dependency injection** — pass functions/objects instead of importing
4. **Merge packages** if they're truly one concept

---

## 10. Deep Transitive Dependencies

**What it is:** Long chains of package dependencies.

**Example:**
```
workbench_backend → workbench → scanner → signals → notebooks → datasources
```

**Why it's bad:**
- Change in `datasources` rebuilds everything above it
- Hard to understand impact of changes
- Slow CI (everything depends on everything)

**Fix:**
- Review: does the chain need to be this long?
- Consider interfaces to break hard dependencies
- Accept some duplication to reduce coupling

---

## 11. Missing `__init__.py`

**What it is:** Directories intended as packages but missing `__init__.py`.

**Example:**
```
packages/signals/src/signals/
├── compute.py
├── indicators/          # Missing __init__.py!
│   ├── momentum.py
│   └── volatility.py
```

**Why it's bad:**
- `from signals.indicators import momentum` fails
- Namespace packages (PEP 420) are confusing
- Tooling may not recognize the directory as a package

**Fix:**
```bash
# Find directories with .py files but no __init__.py
find packages -type d -exec sh -c '
  ls "$1"/*.py >/dev/null 2>&1 && [ ! -f "$1/__init__.py" ] && echo "$1"
' _ {} \;
```

---

## 12. Test Files in Source

**What it is:** Test files mixed into source directories.

**Example:**
```
packages/signals/src/signals/
├── compute.py
├── test_compute.py      # Bad: test in source
└── indicators.py
```

**Why it's bad:**
- Tests get installed with package
- Increases package size
- Confuses "is this production code?"

**Fix:**
- Move to `tests/` directory at package level
- Structure: `packages/signals/tests/test_compute.py`

---

## 13. Premature Abstraction

**What it is:** Extracting shared utilities after one or two uses, before the true shape of the problem is clear.

**Example:**
```python
# utils/dates.py (created after two call sites)
def as_trading_day(date):
    ...
```

**Why it's bad:**
- Creates the wrong abstraction, which is hard to unwind later
- Forces callers into an API that does not fit all cases
- Centralises change risk and increases coupling

**Fix:**
- Apply the rule of three: extract on the third copy
- Keep local versions when intent is clearer than reuse
- If you must extract early, document scope and ownership in a README or ADR

---

## Pattern Summary

| Anti-Pattern | Detection | Severity |
|--------------|-----------|----------|
| Ghost members | grep pyproject.toml + filesystem | High |
| Orphaned dirs | find pycache-only | Medium |
| Redundant nesting | Manual review | Medium |
| Naming collision | find duplicate names | Medium |
| Tech-coupled names | Manual review | Low |
| Scripts as imports | grep "from scripts" | High |
| Inconsistent layout | Check src/ presence | Low |
| Vague names | Manual review | Low |
| Circular deps | import-linter | High |
| Deep transitive | uv tree | Medium |
| Missing __init__ | find check | Medium |
| Tests in source | find test_*.py in src | Low |
| Premature abstraction | Manual review | Medium |

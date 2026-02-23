# Docs and Commenting Doctrine (Stack Specific)

## Unifying Principle

Types and schemas explain shape.
Code explains mechanics.
Comments explain intent, invariants, and risk.

The more irreversible or high leverage a mistake would be, the more you comment.

## FastAPI Endpoints

Docstrings are API contracts. Prefer Google style; Markdown is fine in descriptions.

Include:
- Business meaning of fields
- Preconditions and postconditions
- Non-obvious defaults
- Error semantics (what causes 4xx vs 5xx)

Avoid:
- Restating Pydantic types
- Explaining HTTP mechanics
- Documenting implementation details

Example:

```python
def create_run(request: CreateRunRequest) -> RunResponse:
    """
    Create a new research run for a stock.

    Args:
        request: Run configuration. start_date is interpreted as
            market-local time and rounded to the nearest trading day.

    Returns:
        The newly created run. The run is immediately visible to
        downstream evidence ingestion.

    Raises:
        HTTPException(409): If a run already exists for this stock and date.
    """
```

Inline comments should explain why behaviour exists, not what it does.

## Polars and Data Transforms

Docstrings describe data semantics: grain, PIT assumptions, and output meaning.
Inline comments flag invariants and traps: ordering, stability, and bias risks.

```python
def build_peer_frame(df: pl.DataFrame) -> pl.DataFrame:
    """
    Construct peer comparison frame.

    Parameters
    ----------
    df : DataFrame
        One row per (ticker, fiscal_period).
        Must be point-in-time safe.

    Returns
    -------
    DataFrame
        One row per (ticker, peer_set_id) with z-scored metrics.
    """

# IMPORTANT: groupby preserves order only if sorted first
result = df.sort("event_time").groupby("peer_set_id").agg(...)
```

Comment explicitly on:
- Grain changes
- PIT vs non-PIT assumptions
- Ordering guarantees
- Numerical stability

## Internal Helpers

Only comment helpers that encode policy, not mechanics.

Bad:
```python
# Helper to convert dates
```

Good:
```python
# We normalise to UTC to avoid mixed-zone joins later
```

## pytest

Comment tests only when behaviour is counter-intuitive or a regression is pinned.

```python
def test_duplicate_events_are_deduped():
    # Regression: event_id collisions caused double replay (ARD-112)
    ...
```

## TypeScript and React

Use TSDoc for public interfaces and props. Document meaning, not type shape.

```ts
interface RunCardProps {
  /** Stable run identifier; changes only on full re-run */
  runId: RunId

  /** True once evidence ingestion has completed */
  isFinal: boolean
}
```

For derived or cached state:

```ts
// Derived from server state; may lag during SSE reconnects
lastSeenEventId: string
```

## TanStack Query

Document query key conventions and caching semantics, not types.

```ts
/**
 * Query key convention:
 * ['run', runId] - single run
 * ['run', runId, 'events'] - event stream
 */
```

## SQL and dbt

YAML is canonical documentation for models. Always include grain, keys, lineage,
and temporal semantics.

```yaml
description: >
  One row per (ticker, fiscal_period).
  Data is point-in-time aligned as of report_date.
```

SQL comments should explain reasoning, not structure.

```sql
-- We deliberately exclude the current period to avoid forward-looking leakage
```

Jinja comments are for compile-time behaviour or macro quirks:

```sql
{# Adapter requires a literal for dateadd interval. #}
```

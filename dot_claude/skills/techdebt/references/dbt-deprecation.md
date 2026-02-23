# dbt Model Deprecation Workflow

Safe patterns for retiring dbt models without breaking downstream consumers.

---

## Using deprecation_date

Add to model YAML to generate warnings when referenced:

```yaml
models:
  - name: my_old_model
    deprecation_date: 2026-09-01
    description: |
      DEPRECATED: Use new_model instead.
      Will be removed after 2026-09-01.
    config:
      contract:
        enforced: true
```

**Behaviour:**
- Generates warnings when deprecated models are referenced
- Models with enforced contracts cannot be deleted before deprecation date
- Convert warnings to errors in CI:
  ```bash
  DBT_WARN_ERROR_OPTIONS='{"include": ["DeprecatedModel", "DeprecatedReference"]}'
  ```

---

## Model Versioning (dbt 1.6+)

For high-traffic models, use versioning to give consumers migration time:

```yaml
models:
  - name: customers
    latest_version: 2
    versions:
      - v: 1
        deprecation_date: 2026-06-01
      - v: 2
```

Consumers can reference specific versions: `ref('customers', v=1)`

---

## Soft Delete Pattern

Disable model without removing files:

```yaml
models:
  - name: deprecated_model
    config:
      enabled: false
```

**Advantages:**
- Model stops running
- YAML documentation remains for reference
- Easy to re-enable if needed

---

## Hard Delete Pattern

Full removal:

1. Delete the `.sql` file
2. Remove from schema YAML
3. Drop warehouse object:
   ```sql
   DROP TABLE IF EXISTS {{ target.database }}.{{ target.schema }}.model_name;
   ```

Or use a cleanup macro — see below.

---

## Cleanup Macro

Compare dbt manifest against warehouse metadata:

```sql
{% macro drop_orphaned_tables(dry_run=true) %}
  {% set manifest_tables = [] %}
  {% for node in graph.nodes.values() %}
    {% if node.resource_type == 'model' %}
      {% do manifest_tables.append(node.alias | upper) %}
    {% endif %}
  {% endfor %}

  {% set warehouse_tables = run_query("
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = '" ~ target.schema ~ "'
  ") %}

  {% for row in warehouse_tables %}
    {% if row.table_name not in manifest_tables %}
      {% if dry_run %}
        {{ log("Would drop: " ~ row.table_name, info=true) }}
      {% else %}
        {% do run_query("DROP TABLE IF EXISTS " ~ target.schema ~ "." ~ row.table_name) %}
        {{ log("Dropped: " ~ row.table_name, info=true) }}
      {% endif %}
    {% endif %}
  {% endfor %}
{% endmacro %}
```

**Always run with `dry_run=true` first.**

---

## Recommended Workflow

| Day | Action |
|-----|--------|
| 0 | Add `deprecation_date` (90 days out) |
| 0 | Notify downstream consumers |
| 30 | Check ACCESS_HISTORY for continued usage |
| 60 | Set `enabled: false` (soft delete) |
| 90 | Remove files and drop table (hard delete) |

---

## Best Practices

- **`--full-refresh` guardrail:** Always verify target before running:
  - ✅ `dbt run --full-refresh --target dev` — Safe in dev clones
  - ❌ `dbt run --full-refresh --target prod` — Never without PM approval (cost + data loss risk during rebuild)
- Document ownership using dbt `groups` and `meta` tags
- Schedule deprecation reviews quarterly
- Exclude critical tables (CANONICAL, MART) from automated cleanup

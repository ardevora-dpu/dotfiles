---
name: alembic-migrations
description: Run and manage PostgreSQL database migrations with Alembic. Use when changing database models, applying migrations, or checking migration status. Essential for any schema changes to the workbench backend.
---

# Alembic Migrations

## Purpose

Manage database schema changes for the workbench backend (PostgreSQL/Neon). This skill ensures migrations are generated, reviewed, and applied correctly.

## Prerequisites

- `DATABASE_URL` environment variable must be set
- Run commands from `apps/workbench/backend/` directory

## Quick Reference

```bash
# All commands from apps/workbench/backend/

# Check current migration state
uv run alembic current

# Generate migration after model changes
uv run alembic revision --autogenerate -m "description of change"

# Apply all pending migrations
uv run alembic upgrade head

# Rollback one migration
uv run alembic downgrade -1

# Show migration history
uv run alembic history
```

## Workflow

### 1. Before making schema changes

Check current state:

```bash
cd apps/workbench/backend
uv run alembic current
```

### 2. Make model changes

Edit `workbench_backend/db/models.py`. The SQLAlchemy model is the source of truth.

Example: Adding a new column

```python
# In models.py
class EventModel(Base):
    # ... existing columns ...
    new_column: Mapped[str | None] = mapped_column(String(100))
```

### 3. Generate migration

```bash
uv run alembic revision --autogenerate -m "Add new_column to events"
```

This creates a file in `migrations/versions/`. **Always review the generated file** - autogenerate is not perfect.

### 4. Review the migration

Check the generated file for:

- Correct `upgrade()` and `downgrade()` functions
- Index changes are included if needed
- No unintended changes (autogenerate can miss some things)

### 5. Apply migration

```bash
# Development (against DATABASE_URL)
uv run alembic upgrade head

# Verify
uv run alembic current
```

### 6. Rollback if needed

```bash
# Rollback one step
uv run alembic downgrade -1

# Rollback to specific revision
uv run alembic downgrade abc123
```

## Important Notes

### Append-only events table

The `events` table has a trigger that prevents UPDATE and DELETE. This is intentional - it's an immutable ledger. If you need to "fix" data, append a correction event instead.

### Async driver handling

Our env.py automatically converts `postgresql+asyncpg://` to `postgresql+psycopg://` because Alembic requires a sync driver. You don't need to change your DATABASE_URL.

### Autogenerate limitations

Alembic autogenerate **will detect**:
- Table additions/removals
- Column additions/removals
- Column type changes (with `compare_type=True`)
- Server default changes (with `compare_server_default=True`)
- Index additions/removals

Autogenerate **will NOT detect**:
- Table/column renames (will show as drop + add)
- Changes to CHECK constraints
- Changes to triggers or functions

For these, write manual migrations.

## Troubleshooting

### "Target database is not up to date"

Run `uv run alembic upgrade head` first.

### "Can't locate revision"

Your local migrations may be out of sync. Pull latest code and retry.

### Migration fails on Neon

Neon requires SSL. Ensure your DATABASE_URL includes `sslmode=require` or similar.

## Files

| Path | Purpose |
|------|---------|
| `apps/workbench/backend/migrations/` | Migration root |
| `migrations/env.py` | Alembic configuration |
| `migrations/versions/*.py` | Individual migrations |
| `workbench_backend/db/models.py` | SQLAlchemy models (source of truth) |

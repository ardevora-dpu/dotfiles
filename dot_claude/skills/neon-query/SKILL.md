---
name: neon-query
description: Write accurate queries against the Neon chat history database. Load before any mcp__neon__run_sql call to avoid wrong table/column names and to use the right view/index patterns.
---

# Neon Query

Use this skill whenever querying Jeremy's chat-history database in Neon Postgres.

## Connection Defaults

- **Project ID:** `shy-wildflower-46673345` — always pass as `projectId`
- **Database:** `neondb` (Neon default) — do NOT pass `databaseName`
- **Tool:** `mcp__neon__run_sql` for single statements, `mcp__neon__run_sql_transaction` for multi-statement workflows

## Query Workflow

1. Start from agent views:
`search_sessions_agent_v`, `search_messages_agent_light_v`, `search_messages_agent_v`, `search_user_prompts_agent_v`.
2. Use raw tables only when needed for index-level control or full payload inspection.
3. Add a time bound (`started_at` or `timestamp`) first, then add text filters.
4. Avoid full triple-join aggregate shapes across sessions/messages/tool usage.
5. For tool-call/result linking, prefer `message_id -> search_messages.id` when present; fall back to `tool_use_id`.

## Fast Gotchas

- Table names are `search_sessions`, `search_messages`, `search_tool_usage`, plus `sync_state` (not `search_`-prefixed).
- Message timestamp column is `timestamp`, not `created_at`.
- Session sync column is `synced_at`, not `last_synced_at` or `updated_at`.
- `thinking_config` is `jsonb`.
- `sync_state.blob_size_bytes` is `bigint`.
- `search_tool_usage` includes `id`, `message_id`, `message_uuid`, and `timestamp` columns.
- `message_class` allowed values:
`human_user_prompt`, `assistant`, `assistant_style_user`, `tool_result_payload`, `system`, `system_injected`, `command_invocation`, `summary`, `queue_operation`, `other`.

## Full-Text Search

Two FTS indexes, different purposes:

- **`user_intent_fts`** — human prompts only (~4% of rows). "What did Jeremy ask about?"
- **`content_fts`** — all messages including Claude responses (~10x more hits). "What was discussed?"

Ticker-like tokens can be awkward under `english` stemming. Prefer `simple`-config search where possible; use `ILIKE` as fallback.

```sql
-- Search human prompts
WHERE user_intent_fts @@ plainto_tsquery('english', 'search term')

-- Search all content
WHERE content_fts @@ plainto_tsquery('english', 'search term')

-- Ticker search using simple config
WHERE to_tsvector('simple', COALESCE(content_text, ''))
      @@ plainto_tsquery('simple', 'RMBS-US')

-- Fallback
WHERE content_text ILIKE '%RMBS-US%'
```

## References

- Full schema and types:
`references/schema-reference.md`
- Query templates and join patterns:
`references/query-patterns.md`
- Schema source of truth in repo:
`scripts/sync/sql/000_schema_bootstrap.sql`
`scripts/sync/sql/010_search_quality.sql`

## Quick Health Check

```sql
SELECT COUNT(*) AS files_tracked, MAX(synced_at) AS last_sync
FROM sync_state;
```

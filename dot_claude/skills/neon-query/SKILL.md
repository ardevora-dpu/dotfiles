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

## View Picker — Which View for Which Task

| Task | Use this view | Why |
|------|---------------|-----|
| List sessions, check activity | `search_sessions_agent_v` | Lightweight, pre-aggregated counters |
| Scan messages without reading content | `search_messages_agent_light_v` | Has `content_preview` (200 chars), avoids TOAST |
| Search message content by keyword/FTS | `search_messages_agent_v` | Has full `content_text` for WHERE/ILIKE/FTS |
| Search what Jeremy asked | `search_user_prompts_agent_v` | Pre-filtered to `human_user_prompt`, has `content_text` |
| Search tool calls | `search_tool_usage` (base table) | No agent view exists; cast `tool_input::text` for text search |

**Critical:** `search_messages_agent_light_v` does **NOT** have `content_text`. If you need to search or substring message content, use `search_messages_agent_v` or `search_user_prompts_agent_v`.

## Column Quick-Reference (Inline)

Columns that cause errors — memorise these:

| Want this? | Correct column | On which view/table |
|------------|----------------|---------------------|
| Session title/description | `session_summary` | `search_sessions_agent_v` (no `title` column) |
| Message text (full) | `content_text` | `search_messages_agent_v`, `search_user_prompts_agent_v` |
| Message text (preview) | `content_preview` | `search_messages_agent_light_v` only |
| Message text length | `content_text_len` | `search_messages_agent_light_v` only |
| Tool call input | `tool_input` (jsonb) | `search_tool_usage` — cast to text: `tool_input::text` |
| Tool SQL query | `sql_query` | `search_tool_usage` — auto-extracted for SQL-related tools |
| Last activity | `activity_at` | `search_sessions_agent_v` only (computed: `COALESCE(ended_at, started_at)`) |

## Query Workflow

1. **Pick the right view** using the table above. Don't default to the light view for content searches.
2. Start from agent views. Use raw tables only for index-level control or full payload inspection.
3. Add a time bound (`started_at` or `timestamp`) first, then add text filters.
4. Avoid full triple-join aggregate shapes across sessions/messages/tool usage.
5. For tool-call/result linking, prefer `message_id -> search_messages.id` when present; fall back to `tool_use_id`.

## Fast Gotchas

- Table names are `search_sessions`, `search_messages`, `search_tool_usage`, plus `sync_state` (not `search_`-prefixed).
- Message timestamp column is `timestamp`, not `created_at`.
- Session sync column is `synced_at`, not `last_synced_at` or `updated_at`.
- `thinking_config` is `jsonb`.
- `sync_state.blob_size_bytes` is `bigint`.
- `search_tool_usage.tool_input` is `jsonb` — to search as text use `tool_input::text ILIKE '%...'`.
- `message_class` allowed values:
`human_user_prompt`, `assistant`, `assistant_style_user`, `tool_result_payload`, `system`, `system_injected`, `command_invocation`, `summary`, `queue_operation`, `other`.

## Full-Text Search

Two FTS indexes, different purposes:

- **`user_intent_fts`** — human prompts only (~4% of rows). "What did Jeremy ask about?"
- **`content_fts`** — all messages including Claude responses (~10x more hits). "What was discussed?"

Both are on `search_messages` (base table) and carried through to `search_messages_agent_v` and `search_user_prompts_agent_v`. **Not available** on `search_messages_agent_light_v`.

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

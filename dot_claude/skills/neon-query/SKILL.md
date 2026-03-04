---
name: neon-query
description: Write accurate queries against the Neon chat history database. Load before any mcp__neon__run_sql call to avoid wrong table/column names and to use the right view/index patterns.
---

# Neon Query

Use this skill whenever querying the team chat-history database in Neon Postgres.

## Connection Defaults

- **Project ID:** `shy-wildflower-46673345` — always pass as `projectId`
- **Database:** `neondb` (Neon default) — do NOT pass `databaseName`
- **Tool:** `mcp__neon__run_sql` for single statements, `mcp__neon__run_sql_transaction` for multi-statement workflows

## Multi-User

The database contains sessions from all platform users. Filter by `user_name` when needed.

| `user_name` | `tool_name` | Description |
|-------------|-------------|-------------|
| `jeremy` | `claude` | PM research sessions |
| `timon` | `claude`, `codex` | Developer sessions |
| `jack` | `claude` | Communications/inspection sessions |

Every table and view carries `source_id`, `user_name`, `tool_name`, `platform_name`, `machine_name` for provenance filtering.

## Engine Defaults (Current)

- **Default retrieval engine:** `BM25` (`pg_search`) for ranked message search.
- **Fallback retrieval engine:** Postgres FTS (`content_fts`, `user_intent_fts`).
- **Substring fallback:** trigram-backed `ILIKE` on `content_text` and `tool_input::text`.

## Timeout-Safe Contract (Strict)

1. Never run broad `content_json::text` scans for discovery queries.
2. Always constrain by session scope/time window first.
3. Prefer ranked BM25 search over raw `ILIKE` for broad discovery.
4. Use FTS fallback when BM25 is unavailable or query parser behaviour is unsuitable.
5. Use trigram `ILIKE` only for exact fragments/ticker-like probes.

## View Picker — Which Surface for Which Task

| Task | Use this view/table | Why |
|------|---------------------|-----|
| List sessions, check activity | `chat_sessions_agent_v` | Lightweight, pre-aggregated counters |
| Scan messages without full text | `chat_messages_agent_light_v` | Has `content_preview` (200 chars), avoids TOAST |
| Ranked message search | `chat_messages` + `chat_sessions_agent_v` | `BM25`/`FTS` indexes on base table |
| Search what a user asked | `chat_user_prompts_agent_v` | Pre-filtered to `human_user_prompt` |
| Search tool calls | `chat_tool_usage` | Includes `tool_fts`, trigram index on `tool_input::text` |
| System events / token counts | `chat_events_agent_v` | Token usage, event timeline |

**Critical:** `chat_messages_agent_light_v` does **NOT** include `content_text`. Use `chat_messages_agent_v` for FTS/ILIKE.

## Column Quick-Reference

| Want this? | Correct column | On which view/table |
|------------|----------------|---------------------|
| Session summary | `session_summary` | `chat_sessions_agent_v` |
| Message text (full) | `content_text` or `content` | `chat_messages`, `chat_messages_agent_v`, `chat_user_prompts_agent_v` |
| Message preview | `content_preview` or `content` | `chat_messages_agent_light_v` |
| Message role | `record_type` or `role` | All message views |
| Tool input text search | `tool_input::text` | `chat_tool_usage` |
| Tool SQL query | `sql_query` | `chat_tool_usage` |
| Last activity timestamp | `activity_at` | `chat_sessions_agent_v` |
| Session owner | `user_name` | All tables and views |

**View aliases:** Agent views expose `role` (= `record_type`), `content` (= `content_text` or `content_preview`), `created_at` (= `timestamp`).

## Query Workflow

1. Build a constrained session base (user, session kind, time window).
2. Run ranked retrieval on messages (`BM25` default; `FTS` fallback).
3. Join back to session metadata for context.
4. Use trigram `ILIKE` probes only for exact fragment lookups.
5. Avoid triple-join aggregate scans without pre-aggregation.

## Search Templates

```sql
-- BM25 default (ranked discussion search)
SELECT
  s.session_id,
  s.user_name,
  s.started_at,
  m.id,
  m.timestamp,
  LEFT(m.content_text, 220) AS preview,
  paradedb.score(m.id) AS score
FROM public.chat_messages m
JOIN public.chat_sessions_agent_v s
  ON s.source_id = m.source_id
 AND s.session_id = m.session_id
WHERE s.started_at >= now() - interval '14 days'
  AND m.content_text @@@ 'workflow timeout token usage'
ORDER BY score DESC, m.timestamp DESC NULLS LAST
LIMIT 20;

-- FTS fallback
SELECT
  s.session_id,
  s.user_name,
  s.started_at,
  m.id,
  m.timestamp,
  LEFT(m.content_text, 220) AS preview,
  ts_rank_cd(m.content_fts, websearch_to_tsquery('english', 'workflow timeout token usage')) AS score
FROM public.chat_messages m
JOIN public.chat_sessions_agent_v s
  ON s.source_id = m.source_id
 AND s.session_id = m.session_id
WHERE s.started_at >= now() - interval '14 days'
  AND m.content_fts @@ websearch_to_tsquery('english', 'workflow timeout token usage')
ORDER BY score DESC, m.timestamp DESC NULLS LAST
LIMIT 20;

-- Trigram exact-fragment fallback (do not broad-scan content_json::text)
SELECT
  m.session_id,
  m.user_name,
  m.timestamp,
  LEFT(m.content_text, 220) AS preview
FROM public.chat_messages m
JOIN public.chat_sessions_agent_v s
  ON s.source_id = m.source_id
 AND s.session_id = m.session_id
WHERE s.started_at >= now() - interval '30 days'
  AND m.content_text ILIKE '%ignored null byte in input%'
ORDER BY m.timestamp DESC
LIMIT 20;

-- Tool-input exact-fragment search (trigram-backed)
SELECT
  t.session_id,
  t.user_name,
  t.timestamp,
  t.tool_name,
  LEFT(t.tool_input::text, 220) AS tool_input_preview
FROM public.chat_tool_usage t
JOIN public.chat_sessions_agent_v s
  ON s.source_id = t.source_id
 AND s.session_id = t.session_id
WHERE s.started_at >= now() - interval '30 days'
  AND t.tool_input::text ILIKE '%RMBS-US%'
ORDER BY t.timestamp DESC
LIMIT 20;
```

## Fast Gotchas

- Table names are `chat_sessions`, `chat_messages`, `chat_tool_usage`, `chat_events`, plus `chat_sync_state`.
- Views are `chat_sessions_agent_v`, `chat_messages_agent_v`, `chat_messages_agent_light_v`, `chat_user_prompts_agent_v`, `chat_events_agent_v`.
- Message timestamp is `timestamp` (or alias `created_at` on views).
- Session sync column is `synced_at`, not `updated_at`.
- `thinking_config` and `tool_input` are `jsonb`.
- All joins between sessions and messages/events/tools require `source_id AND session_id` (composite key).
- `message_class` values:
`human_user_prompt`, `assistant`, `assistant_style_user`, `tool_result_payload`, `system`, `system_injected`, `command_invocation`, `summary`, `queue_operation`, `other`.

## References

- Schema source of truth:
  - `scripts/sync/sql/000_schema_bootstrap.sql`
  - `scripts/sync/sql/010_search_quality.sql`
  - `scripts/sync/sql/030_tool_result_text_backfill.sql`

## Quick Health Check

```sql
SELECT source_id, COUNT(*) AS files_tracked, MAX(synced_at) AS last_sync
FROM chat_sync_state
GROUP BY source_id
ORDER BY last_sync DESC;
```

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
- **Fallback retrieval engine:** Postgres FTS (`content_fts`, `prompt_fts`, `prompt_simple_fts`).
- **Substring fallback:** trigram-backed `ILIKE` on `content_text` and `tool_input::text`.

## Timeout-Safe Contract (Strict)

1. Never run broad `content_json::text` scans for discovery queries.
2. Always constrain by session scope/time window first.
3. Prefer ranked BM25 search over raw `ILIKE` for broad discovery.
4. Use FTS fallback when BM25 is unavailable or query parser behaviour is unsuitable.
5. Use trigram `ILIKE` only for exact fragments/ticker-like probes.
6. Never call `to_tsvector(...)` on agent views for discovery queries; use the precomputed FTS columns directly.

## Transport Fallback

If Neon MCP transport fails twice or query timing looks suspicious:

1. keep the SQL shape narrow and index-aware
2. inspect the plan with direct `psql`
3. debug the query shape there first
4. then bring the corrected query back to `mcp__neon__run_sql`

Use direct `psql` for diagnosis, not as the default path for normal agent work.

## View Picker — Which Surface for Which Task

| Task | Use this view/table | Why |
|------|---------------------|-----|
| List sessions, check activity | `chat_sessions_agent_v` | Lightweight, pre-aggregated counters |
| Scan messages without full text | `chat_messages_agent_light_v` | Has `content_preview` (200 chars), avoids TOAST |
| Ranked message search | `chat_messages_agent_v` + `chat_sessions_agent_v` | `BM25`/`FTS` on enriched projections |
| Search what a user asked | `chat_user_prompts_agent_v` | Purpose-built prompt surface with named prompt search columns |
| Search tool calls | `chat_tool_calls_agent_v` | Current live MCP-safe path for tool archaeology |
| System events / token counts | `chat_events_agent_v` | Token usage, event timeline |

**Critical:** `chat_messages_agent_light_v` does **NOT** include `content_text`. Use `chat_messages_agent_v` for FTS/ILIKE.

## Column Quick-Reference

| Want this? | Correct column | On which view/table |
|------------|----------------|---------------------|
| Session summary | `session_summary` | `chat_sessions_agent_v` |
| Message text (full) | `content_text` or `content` | `chat_messages_agent_v` |
| Prompt text | `prompt_text` | `chat_user_prompts_agent_v` |
| Prompt FTS (English) | `prompt_fts` | `chat_user_prompts_agent_v` |
| Prompt FTS (simple) | `prompt_simple_fts` | `chat_user_prompts_agent_v` |
| Message preview | `content_preview` or `content` | `chat_messages_agent_light_v` |
| Message role | `record_type` or `role` | All message views |
| Tool input text search | `tool_input::text` | `chat_tool_calls_agent_v` |
| Tool SQL query | `sql_query` | `chat_tool_calls_agent_v` |
| File-path session discovery | `normalised_tool_file_path` | `chat_tool_calls_agent_v` |
| Exact OIC ticker lookup | `artifact_ticker_region` | `chat_tool_calls_agent_v` |
| Evidence-relative path | `evidence_relative_path` | `chat_tool_calls_agent_v` |
| Bridged session join key | `source_session_id` | `chat_tool_calls_agent_v`, `chat_sessions_agent_v` |
| Last activity timestamp | `activity_at` | `chat_sessions_agent_v` |
| Session owner | `user_name` | All tables and views |

**View aliases:** Message views expose `role` (= `record_type`), `content` (= `content_text` or `content_preview`), `created_at` (= `timestamp`). Prompt views deliberately expose `prompt_text` instead of a generic `content` alias.

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
FROM public.chat_messages_agent_v m
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
FROM public.chat_messages_agent_v m
JOIN public.chat_sessions_agent_v s
  ON s.source_id = m.source_id
 AND s.session_id = m.session_id
WHERE s.started_at >= now() - interval '14 days'
  AND m.content_fts @@ websearch_to_tsquery('english', 'workflow timeout token usage')
ORDER BY score DESC, m.timestamp DESC NULLS LAST
LIMIT 20;

-- Prompt search ("what did Jeremy ask?")
SELECT
  s.session_id,
  s.user_name,
  s.started_at,
  m.id,
  m.created_at,
  LEFT(m.prompt_text, 220) AS preview
FROM public.chat_user_prompts_agent_v m
JOIN public.chat_sessions_agent_v s
  ON s.source_id = m.source_id
 AND s.session_id = m.session_id
WHERE s.started_at >= now() - interval '14 days'
  AND m.prompt_fts @@ websearch_to_tsquery('english', 'counterfactual comparison case')
ORDER BY m.created_at DESC
LIMIT 20;

-- Exact-token / ticker-friendly prompt search
SELECT
  s.session_id,
  s.user_name,
  s.started_at,
  m.id,
  m.created_at,
  LEFT(m.prompt_text, 220) AS preview
FROM public.chat_user_prompts_agent_v m
JOIN public.chat_sessions_agent_v s
  ON s.source_id = m.source_id
 AND s.session_id = m.session_id
WHERE s.started_at >= now() - interval '30 days'
  AND m.prompt_simple_fts @@ plainto_tsquery('simple', 'three reasoning paths')
ORDER BY m.created_at DESC
LIMIT 20;

-- Trigram exact-fragment fallback (do not broad-scan content_json::text)
SELECT
  m.session_id,
  m.user_name,
  m.timestamp,
  LEFT(m.content_text, 220) AS preview
FROM public.chat_messages_agent_v m
JOIN public.chat_sessions_agent_v s
  ON s.source_id = m.source_id
 AND s.session_id = m.session_id
WHERE s.started_at >= now() - interval '30 days'
  AND m.content_text ILIKE '%ignored null byte in input%'
ORDER BY m.timestamp DESC
LIMIT 20;

-- Tool-call archaeology on the current live target
SELECT
  session_id,
  user_name,
  created_at,
  tool_name_used AS tool_name,
  LEFT(tool_input::text, 220) AS tool_input_preview
FROM public.chat_tool_calls_agent_v
WHERE user_name = 'jeremy'
  AND created_at >= now() - interval '30 days'
  AND (
    artifact_ticker_region = 'RMBS-US'
    OR normalised_tool_file_path ILIKE '%RMBS-US%'
  )
ORDER BY created_at DESC
LIMIT 20;
```

## Fast Gotchas

- Primary ingest table is `chat_raw_records`.
- Current live MCP query surfaces are `chat_sessions_agent_v`, `chat_messages_agent_v`, `chat_messages_agent_light_v`, `chat_user_prompts_agent_v`, `chat_tool_calls_agent_v`, `chat_events_agent_v`, and `chat_raw_records`.
- Local docs may mention `chat_records_enriched`, `chat_sessions_mat`, or `chat_tool_usage`; confirm they exist before using them on a live target.
- Message timestamp is `timestamp` (or alias `created_at` on views).
- Session sync column is `synced_at`, not `updated_at`.
- `thinking_config` and `tool_input` are `jsonb`.
- Day-to-day tool archaeology should start with `chat_tool_calls_agent_v`; fall back to `chat_raw_records` only for raw forensics.
- For `Write` / `Edit` discovery, prefer `artifact_ticker_region`; fall back to `normalised_tool_file_path` when the extractor is null.
- All joins between sessions and messages/events require `source_id AND session_id` (composite key).
- `message_class` values:
`human_user_prompt`, `assistant`, `assistant_style_user`, `tool_result_payload`, `system`, `system_injected`, `command_invocation`, `summary`, `queue_operation`, `other`.

## References

- Schema source of truth:
  - `scripts/sync/sql/000_schema_bootstrap.sql`
  - `scripts/sync/sql/005_raw_projections.sql`
  - `scripts/sync/sql/010_search_quality.sql`

## Quick Health Check

```sql
SELECT source_id, COUNT(*) AS files_tracked, MAX(synced_at) AS last_sync
FROM chat_sync_state
GROUP BY source_id
ORDER BY last_sync DESC;
```

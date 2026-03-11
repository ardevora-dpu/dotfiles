# Neon Chat Schema Reference (Late-Binding)

Validated against:

- `scripts/sync/sql/000_schema_bootstrap.sql`
- `scripts/sync/sql/005_raw_projections.sql`
- `scripts/sync/sql/010_search_quality.sql`

## Architecture

The current schema is late-binding:

1. **Raw ingest facts**: `chat_raw_records`
2. **Derived projections**: `chat_records_enriched`, `chat_sessions_mat`
3. **Agent query interface**: `chat_*_agent_v` views

Do not use legacy `search_*` names.

## Core Objects

### `public.chat_sync_state`

Tracks Azure blob sync progress per source lane + file.

Key columns:

- `source_id`
- `file_path`
- `blob_last_modified`
- `blob_size_bytes`
- `last_line_processed`
- `synced_at`

### `public.chat_raw_records`

Raw immutable ingest table (one row per parsed JSONL record fragment).

Key columns:

- Identity: `id`, `source_id`, `file_path`, `line_num`, `line_sub`
- Provenance: `user_name`, `tool_name`, `platform_name`, `machine_name`
- Content: `record_type`, `record_category`, `content_text`, `content_json`
- Metadata: `timestamp`, `model`, `git_branch`, `cwd`
- Tool/event fields: `tool_use_id`, `tool_name_used`, `tool_input`, `sql_query`, `event_type`, `payload_json`

### `public.chat_records_enriched` (materialised view)

Record-level projection used by agent views.

Adds/standardises:

- Authoritative `session_id` (including subagent file-derived IDs)
- `session_kind` (`main`, `subagent`, `summary_only`)
- `parent_session_id`
- `message_class`
- `user_intent_fts`

### `public.chat_sessions_mat` (materialised view)

Session-level rollups from enriched records.

Key columns:

- IDs: `source_id`, `session_id`, `source_session_id`
- Time: `started_at`, `ended_at`, `activity_at`
- Counts: `message_count`, `user_prompt_count`, `assistant_message_count`, `tool_result_count`, `tool_call_count`, `distinct_tool_count`
- Workflow: `active_duration_minutes`, `branch_count`, `sidechain_count`, `session_summary`, `session_kind`
- Tokens: `input_tokens_total`, `output_tokens_total`
- Context: `git_branch`, `cwd`, `project_path`

## Agent Views (Preferred Query Surface)

### `public.chat_sessions_agent_v`

Main-session rollups for usage and workflow analytics.

### `public.chat_messages_agent_v`

Main-session message stream with full text/payload fields.

Aliases:

- `role` = `record_type`
- `content` = `content_text`
- `created_at` = `timestamp`

### `public.chat_messages_agent_light_v`

Main-session message stream with preview text only.

Use for broad scans; does not include full payload-heavy columns.

### `public.chat_user_prompts_agent_v`

Likely human-authored prompts only (`message_class='human_user_prompt'`).

### `public.chat_events_agent_v`

Main-session event stream (telemetry/lifecycle/token events).

## Search and Index Notes

### BM25

- `idx_raw_records_bm25` on `chat_raw_records`
- `idx_enriched_bm25` on `chat_records_enriched`

Use `content_text @@@ 'query terms'` on `chat_messages_agent_v` for ranked retrieval.

### FTS

- `idx_enriched_content_fts` on `chat_records_enriched(content_fts)`
- `idx_enriched_user_intent_fts` on `chat_records_enriched(user_intent_fts)`

Use FTS as BM25 fallback (`@@ websearch_to_tsquery(...)`).

## Join Contract (Important)

Always join cross-object queries using both keys:

- `source_id`
- `session_id`

Never join sessions/messages by `session_id` alone.

## Quick Freshness Check

```sql
SELECT source_id, COUNT(*) AS files_tracked, MAX(synced_at) AS last_sync
FROM chat_sync_state
GROUP BY source_id
ORDER BY last_sync DESC;
```

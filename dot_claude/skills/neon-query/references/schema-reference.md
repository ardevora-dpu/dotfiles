# Neon Chat Schema Reference

Validated against Neon project `shy-wildflower-46673345` on `2026-03-01`.

## Base Tables

### `public.search_sessions`

Session metadata with pre-computed rollup counters.

| Column | Type | Semantic |
|---|---|---|
| `id` | `integer` | Auto-increment PK |
| `session_id` | `text` | Claude session UUID (unique, natural key) |
| `project_path` | `text` | Azure blob parent directory |
| `file_path` | `text` | Full blob path |
| `started_at` | `timestamptz` | First message timestamp |
| `ended_at` | `timestamptz` | Last message timestamp |
| `message_count` | `integer` | Total messages |
| `git_branch` | `text` | Git branch from first message |
| `cwd` | `text` | Working directory |
| `synced_at` | `timestamptz` | When record was last synced |
| `user_name` | `text` | Always "jeremy" |
| `session_summary` | `text` | Latest summary record text (may be null) |
| `branch_count` | `integer` | Branching forks (parent_uuid with >1 child) |
| `sidechain_count` | `integer` | Off-path messages |
| `parent_session_id` | `text` | Parent UUID for subagent sessions |
| `session_kind` | `text` | `'main'` / `'subagent'` / `'summary_only'` |
| `active_duration_minutes` | `integer` | Summed message gaps (5min cap per gap) |
| `user_prompt_count` | `integer` | Human-authored prompts |
| `assistant_message_count` | `integer` | Assistant responses |
| `tool_result_count` | `integer` | Tool result messages |
| `tool_call_count` | `integer` | Tool invocations (from search_tool_usage) |
| `distinct_tool_count` | `integer` | Unique tool names used |
| `input_tokens_total` | `bigint` | Sum of input_tokens |
| `output_tokens_total` | `bigint` | Sum of output_tokens |
| `last_tool_at` | `timestamptz` | Most recent tool usage timestamp |

**Does NOT have:** `title`, `name`, `description`, `created_at`, `updated_at`.

### `public.search_messages`

All parsed messages. Contains TOAST columns (`content_text`, `content_json`) that can be several MB per row.

| Column | Type | Semantic |
|---|---|---|
| `id` | `integer` | Auto-increment PK |
| `session_id` | `text` | Session reference |
| `message_uuid` | `text` | Message UUID from JSONL |
| `message_idx` | `integer` | Line number in JSONL (1-indexed) |
| `record_type` | `text` | JSONL type: `user`, `assistant`, `system`, `summary`, `queue-operation` |
| `timestamp` | `timestamptz` | Message timestamp |
| `content_text` | `text` | Searchable text (flattened from content blocks) |
| `content_json` | `jsonb` | Full message.content object (raw) |
| `model` | `text` | e.g. `claude-opus-4-6` |
| `git_branch` | `text` | Git context |
| `cwd` | `text` | Working directory |
| `input_tokens` | `integer` | message.usage.input_tokens |
| `output_tokens` | `integer` | message.usage.output_tokens |
| `content_fts` | `tsvector` | Generated: `to_tsvector('english', content_text)` |
| `parent_uuid` | `text` | For branching conversations |
| `is_sidechain` | `boolean` | Off-path message flag |
| `thinking_config` | `jsonb` | Extended thinking metadata |
| `tool_use_id` | `text` | Tool result reference (from tool_result blocks) |
| `message_class` | `text` | Classified message type (see below) |
| `user_intent_fts` | `tsvector` | FTS vector, populated only for `human_user_prompt` |

**Does NOT have:** `content_preview`, `content_text_len`, `is_user_authored` (those are on the views).

**`message_class` values and meanings:**

| Value | What it means |
|-------|---------------|
| `human_user_prompt` | Genuine human-authored message |
| `assistant` | Claude response |
| `tool_result_payload` | User message containing tool_result block |
| `system` | System message |
| `system_injected` | System prefix injected into user turn (skill loads, reminders) |
| `command_invocation` | Contains `<command-name>` tag |
| `assistant_style_user` | User message that reads like assistant output |
| `summary` | Context compaction summary |
| `queue_operation` | Queue management message |
| `other` | Unclassified |

### `public.search_tool_usage`

Extracted tool calls from assistant messages.

| Column | Type | Semantic |
|---|---|---|
| `id` | `integer` | Auto-increment PK |
| `message_id` | `integer` | FK to search_messages(id) |
| `session_id` | `text` | Denormalised session reference |
| `tool_name` | `text` | Tool name (e.g. `Bash`, `Read`, `mcp__neon__run_sql`) |
| `tool_input` | `jsonb` | Full tool input object — **cast to text for search: `tool_input::text`** |
| `timestamp` | `timestamptz` | Inherited from parent message |
| `sql_query` | `text` | Auto-extracted for SQL tools (neon, snowflake) |
| `file_path` | `text` | Auto-extracted from tool_input path fields |
| `tool_fts` | `tsvector` | Generated: tool_name + sql_query + file_path |
| `message_uuid` | `text` | Denormalised message UUID |
| `tool_use_id` | `text` | block.id from tool_use content block |

**Does NOT have:** `tool_input_text`, `tool_output`, `result`, `command`.

### `public.sync_state`

Blob sync progress tracking.

| Column | Type | Semantic |
|---|---|---|
| `id` | `integer` | Auto-increment PK |
| `file_path` | `text` | Azure blob path (unique) |
| `blob_last_modified` | `timestamptz` | Last modification from Azure |
| `blob_size_bytes` | `bigint` | File size for change detection |
| `last_line_processed` | `integer` | Resume point for incremental sync |
| `synced_at` | `timestamptz` | When sync completed |

## Agent Views

All agent views filter to `session_kind = 'main'` (excludes subagent sessions).

### `public.search_sessions_agent_v`

Session overview. COALESCEs counters to 0. Adds computed `activity_at`.

Columns:
`session_id`, `project_path`, `file_path`, `started_at`, `ended_at`, `message_count`,
`active_duration_minutes`, `user_prompt_count`, `assistant_message_count`,
`tool_result_count`, `tool_call_count`, `distinct_tool_count`, `input_tokens_total`,
`output_tokens_total`, `last_tool_at`, `session_summary`, `branch_count`,
`sidechain_count`, `git_branch`, `cwd`, `user_name`, `parent_session_id`,
`session_kind`, `synced_at`, `activity_at`

**Does NOT have:** `id`, `title`.

### `public.search_messages_agent_v`

Full message content including TOAST columns. Use for content search, FTS, and detailed analysis.

Columns:
`id`, `session_id`, `message_uuid`, `message_idx`, `record_type`, `timestamp`,
**`content_text`**, **`content_json`**, `model`, `git_branch`, `cwd`, `input_tokens`,
`output_tokens`, `parent_uuid`, `is_sidechain`, `thinking_config`, `tool_use_id`,
`message_class`, `user_intent_fts`, `is_user_authored`, `is_tool_result`,
`is_system_injected`, `is_assistant_style_user`

### `public.search_messages_agent_light_v`

Lightweight scan view. Excludes TOAST columns for fast metadata scanning.

Columns:
`id`, `session_id`, `message_uuid`, `message_idx`, `record_type`, `timestamp`,
**`content_preview`** (first 200 chars), **`content_text_len`**, `model`, `git_branch`, `cwd`,
`input_tokens`, `output_tokens`, `parent_uuid`, `is_sidechain`, `tool_use_id`,
`message_class`, `is_user_authored`, `is_tool_result`, `is_system_injected`,
`is_assistant_style_user`

**Does NOT have:** `content_text`, `content_json`, `content_fts`, `user_intent_fts`, `thinking_config`. Cannot be used for FTS or ILIKE content search.

### `public.search_user_prompts_agent_v`

Human prompts only (pre-filtered to `message_class = 'human_user_prompt'`). Built on `search_messages_agent_v` so includes full content.

Columns:
`id`, `session_id`, `message_uuid`, `message_idx`, `record_type`, `timestamp`,
**`content_text`**, **`content_json`**, `model`, `git_branch`, `cwd`, `input_tokens`,
`output_tokens`, `parent_uuid`, `is_sidechain`, `thinking_config`, `tool_use_id`,
`message_class`, `user_intent_fts`

**Does NOT have:** the boolean flags (`is_user_authored` etc.) — they're always true here.

## FTS Indexes

| Index | Table | Config | Expression | Use for |
|-------|-------|--------|-----------|---------|
| `idx_messages_fts` | messages | `english` | `content_fts` (stored) | Natural language search across all messages |
| `idx_messages_user_intent_fts` | messages | mixed | `user_intent_fts` (stored) | What did Jeremy ask? |
| `idx_messages_simple_fts` | messages | `simple` | `to_tsvector('simple', COALESCE(content_text, ''))` | Ticker symbols, identifiers |
| `idx_tool_fts` | tool_usage | `english` | `tool_fts` (stored) | Tool name + SQL + file path search |
| `idx_tool_simple_fts` | tool_usage | `simple` | `to_tsvector('simple', tool_name \|\| ' ' \|\| sql_query \|\| ' ' \|\| file_path)` | Literal tool search |

## Key Indexes (for query planning)

| Table | Index | Columns | Notes |
|-------|-------|---------|-------|
| sessions | `idx_sessions_started` | `started_at DESC` | Time-range session queries |
| sessions | `idx_sessions_user_kind_started` | `user_name, session_kind, started_at DESC` | Filtered session lists |
| messages | `idx_messages_timestamp` | `timestamp DESC` | Time-range message queries |
| messages | `idx_messages_session_class_idx` | `session_id, message_class, message_idx` | Per-session class filtering |
| messages | `idx_messages_human_prompt_idx` | `session_id, message_idx` (partial) | Fast human prompt lookup |
| tool_usage | `idx_tool_session_name` | `session_id, tool_name` | Per-session tool filtering |
| tool_usage | `idx_tool_session_timestamp` | `session_id, timestamp DESC` | Per-session tool timeline |

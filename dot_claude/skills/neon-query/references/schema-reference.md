# Neon Chat Schema Reference

Validated against `scripts/sync/sql/000_schema_bootstrap.sql` and `010_search_quality.sql` on `2026-03-04`.

## Base Tables

### `public.chat_sessions`

Session metadata with pre-computed rollup counters.

| Column | Type | Semantic |
|---|---|---|
| `id` | `integer` | Auto-increment PK |
| `source_id` | `text` | Source lane identifier (e.g. `timon_claude_windows`) |
| `session_id` | `text` | Claude/Codex session UUID |
| `source_session_id` | `text` | Globally unique session key |
| `user_name` | `text` | Session owner: `jeremy`, `timon`, or `jack` |
| `tool_name` | `text` | `claude` or `codex` |
| `platform_name` | `text` | `windows` or `wsl` |
| `machine_name` | `text` | `default` or `legacy` |
| `project_path` | `text` | Azure blob parent directory |
| `file_path` | `text` | Full blob path |
| `started_at` | `timestamptz` | First message timestamp |
| `ended_at` | `timestamptz` | Last message timestamp |
| `message_count` | `integer` | Total messages |
| `git_branch` | `text` | Git branch from first message |
| `cwd` | `text` | Working directory |
| `synced_at` | `timestamptz` | When record was last synced |
| `session_summary` | `text` | Latest summary record text (may be null) |
| `branch_count` | `integer` | Branching forks (parent_uuid with >1 child) |
| `sidechain_count` | `integer` | Off-path messages |
| `parent_session_id` | `text` | Parent UUID for subagent sessions |
| `session_kind` | `text` | `'main'` / `'subagent'` / `'summary_only'` |
| `active_duration_minutes` | `integer` | Summed message gaps (5min cap per gap) |
| `user_prompt_count` | `integer` | Human-authored prompts |
| `assistant_message_count` | `integer` | Assistant responses |
| `tool_result_count` | `integer` | Tool result messages |
| `tool_call_count` | `integer` | Tool invocations (from chat_tool_usage) |
| `distinct_tool_count` | `integer` | Unique tool names used |
| `input_tokens_total` | `bigint` | Sum of input_tokens |
| `output_tokens_total` | `bigint` | Sum of output_tokens |
| `last_tool_at` | `timestamptz` | Most recent tool usage timestamp |

**Unique key:** `(source_id, session_id)`. **Does NOT have:** `title`, `name`, `description`, `created_at`, `updated_at`.

### `public.chat_messages`

All parsed messages. Contains TOAST columns (`content_text`, `content_json`) that can be several MB per row.

| Column | Type | Semantic |
|---|---|---|
| `id` | `integer` | Auto-increment PK |
| `source_id` | `text` | Source lane identifier |
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
| `user_name` | `text` | Provenance: session owner |
| `tool_name` | `text` | Provenance: `claude` or `codex` |
| `platform_name` | `text` | Provenance: `windows` or `wsl` |
| `machine_name` | `text` | Provenance: `default` or `legacy` |

**Unique key:** `(source_id, session_id, message_idx)`. **Does NOT have:** `content_preview`, `content_text_len`, `is_user_authored`, `role`, `content`, `created_at` (those are view aliases).

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

### `public.chat_events`

System events (token counts, lifecycle signals). Separate from messages.

| Column | Type | Semantic |
|---|---|---|
| `id` | `integer` | Auto-increment PK |
| `source_id` | `text` | Source lane identifier |
| `session_id` | `text` | Session reference |
| `event_uuid` | `text` | Event UUID from JSONL |
| `event_idx` | `integer` | Line number in JSONL |
| `event_type` | `text` | e.g. `token_count`, `login`, `system` |
| `timestamp` | `timestamptz` | Event timestamp |
| `content_text` | `text` | Event text (if any) |
| `payload_json` | `jsonb` | Full event payload |
| `input_tokens` | `bigint` | Token count (for `token_count` events) |
| `output_tokens` | `bigint` | Token count (for `token_count` events) |
| `user_name` | `text` | Provenance |
| `tool_name` | `text` | Provenance |
| `platform_name` | `text` | Provenance |
| `machine_name` | `text` | Provenance |
| `git_branch` | `text` | Git context |
| `cwd` | `text` | Working directory |

**Unique key:** `(source_id, session_id, event_idx)`.

### `public.chat_tool_usage`

Extracted tool calls from assistant messages.

| Column | Type | Semantic |
|---|---|---|
| `id` | `integer` | Auto-increment PK |
| `message_id` | `integer` | FK to chat_messages(id) |
| `source_id` | `text` | Source lane identifier |
| `session_id` | `text` | Denormalised session reference |
| `tool_name` | `text` | Tool name (e.g. `Bash`, `Read`, `mcp__neon__run_sql`) |
| `tool_input` | `jsonb` | Full tool input object — **cast to text for search: `tool_input::text`** |
| `timestamp` | `timestamptz` | Inherited from parent message |
| `sql_query` | `text` | Auto-extracted for SQL tools (neon, snowflake) |
| `file_path` | `text` | Auto-extracted from tool_input path fields |
| `tool_fts` | `tsvector` | Generated: tool_name + sql_query + file_path |
| `message_uuid` | `text` | Denormalised message UUID |
| `tool_use_id` | `text` | block.id from tool_use content block |
| `user_name` | `text` | Provenance |
| `tool_name_source` | `text` | Provenance: tool that produced the session |
| `platform_name` | `text` | Provenance |
| `machine_name` | `text` | Provenance |

**Does NOT have:** `tool_input_text`, `tool_output`, `result`, `command`.

### `public.chat_sync_state`

Blob sync progress tracking (per source lane).

| Column | Type | Semantic |
|---|---|---|
| `id` | `integer` | Auto-increment PK |
| `source_id` | `text` | Source lane identifier |
| `user_name` | `text` | Provenance |
| `tool_name` | `text` | Provenance |
| `platform_name` | `text` | Provenance |
| `machine_name` | `text` | Provenance |
| `file_path` | `text` | Azure blob path |
| `blob_last_modified` | `timestamptz` | Last modification from Azure |
| `blob_size_bytes` | `bigint` | File size for change detection |
| `last_line_processed` | `integer` | Resume point for incremental sync |
| `synced_at` | `timestamptz` | When sync completed |

**Unique key:** `(source_id, file_path)`.

## Agent Views

All agent views filter to `session_kind = 'main'` (excludes subagent sessions).

### `public.chat_sessions_agent_v`

Session overview. COALESCEs counters to 0. Adds computed `activity_at`.

Columns:
`source_id`, `session_id`, `source_session_id`, `user_name`, `tool_name`, `platform_name`,
`machine_name`, `project_path`, `file_path`, `started_at`, `ended_at`, `message_count`,
`active_duration_minutes`, `user_prompt_count`, `assistant_message_count`,
`tool_result_count`, `tool_call_count`, `distinct_tool_count`, `input_tokens_total`,
`output_tokens_total`, `last_tool_at`, `session_summary`, `branch_count`,
`sidechain_count`, `git_branch`, `cwd`, `parent_session_id`,
`session_kind`, `synced_at`, `activity_at`

**Does NOT have:** `id`, `title`.

### `public.chat_messages_agent_v`

Full message content including TOAST columns. Use for content search, FTS, and detailed analysis.

**Aliases:** `role` (= `record_type`), `content` (= `content_text`), `created_at` (= `timestamp`).

Columns:
`id`, `source_id`, `session_id`, `message_uuid`, `message_idx`, `record_type`, **`role`**,
`timestamp`, **`created_at`**, **`content_text`**, **`content`**, **`content_json`**, `model`,
`git_branch`, `cwd`, `input_tokens`, `output_tokens`, `parent_uuid`, `is_sidechain`,
`thinking_config`, `tool_use_id`, `message_class`, `user_intent_fts`,
`user_name`, `tool_name`, `platform_name`, `machine_name`,
`is_user_authored`, `is_tool_result`, `is_system_injected`, `is_assistant_style_user`

### `public.chat_messages_agent_light_v`

Lightweight scan view. Excludes TOAST columns for fast metadata scanning.

**Aliases:** `role` (= `record_type`), `content` (= first 200 chars of `content_text`), `created_at` (= `timestamp`).

Columns:
`id`, `source_id`, `session_id`, `message_uuid`, `message_idx`, `record_type`, **`role`**,
`timestamp`, **`created_at`**, **`content_preview`** (first 200 chars), **`content`** (first 200 chars),
**`content_text_len`**, `model`, `git_branch`, `cwd`, `input_tokens`, `output_tokens`,
`parent_uuid`, `is_sidechain`, `tool_use_id`, `message_class`,
`user_name`, `tool_name`, `platform_name`, `machine_name`,
`is_user_authored`, `is_tool_result`, `is_system_injected`, `is_assistant_style_user`

**Does NOT have:** `content_text`, `content_json`, `content_fts`, `user_intent_fts`, `thinking_config`. Cannot be used for FTS or ILIKE content search.

### `public.chat_user_prompts_agent_v`

Human prompts only (pre-filtered to `message_class = 'human_user_prompt'`). Built on `chat_messages_agent_v` so includes full content and aliases.

Columns:
`id`, `source_id`, `session_id`, `message_uuid`, `message_idx`, `record_type`, `role`,
`timestamp`, `created_at`, `content_text`, `content`, `content_json`, `model`,
`git_branch`, `cwd`, `input_tokens`, `output_tokens`, `parent_uuid`, `is_sidechain`,
`thinking_config`, `tool_use_id`, `message_class`, `user_intent_fts`,
`user_name`, `tool_name`, `platform_name`, `machine_name`

### `public.chat_events_agent_v`

System events for main sessions. Token counts, lifecycle signals.

Columns:
`id`, `source_id`, `session_id`, `event_uuid`, `event_idx`, `event_type`,
`timestamp`, `created_at`, `content_text`, `payload_json`,
`input_tokens`, `output_tokens`,
`user_name`, `tool_name`, `platform_name`, `machine_name`,
`git_branch`, `cwd`

## FTS Indexes

| Index | Table | Config | Expression | Use for |
|-------|-------|--------|-----------|---------|
| `idx_chat_messages_fts` | chat_messages | `english` | `content_fts` (stored) | Natural language search across all messages |
| `idx_chat_messages_user_intent_fts` | chat_messages | mixed | `user_intent_fts` (stored) | What did a user ask? |
| `idx_chat_messages_simple_fts` | chat_messages | `simple` | `to_tsvector('simple', COALESCE(content_text, ''))` | Ticker symbols, identifiers |

## Key Indexes (for query planning)

| Table | Index | Columns | Notes |
|-------|-------|---------|-------|
| chat_sessions | `idx_chat_sessions_started` | `started_at DESC` | Time-range session queries |
| chat_sessions | `idx_chat_sessions_user_tool_platform` | `user_name, tool_name, platform_name, started_at DESC` | Per-user filtered lists |
| chat_sessions | `idx_chat_sessions_kind_started` | `session_kind, started_at DESC` | Session kind filtering |
| chat_sessions | `idx_chat_sessions_source` | `source_id, started_at DESC` | Per-lane queries |
| chat_messages | `idx_chat_messages_timestamp` | `timestamp DESC` | Time-range message queries |
| chat_messages | `idx_chat_messages_session_class_idx` | `source_id, session_id, message_class, message_idx` | Per-session class filtering |
| chat_messages | `idx_chat_messages_human_prompt_idx` | `source_id, session_id, message_idx` (partial) | Fast human prompt lookup |
| chat_messages | `idx_chat_messages_user_tool_platform` | `user_name, tool_name, platform_name, timestamp DESC` | Per-user message filtering |
| chat_tool_usage | `idx_chat_tool_usage_session_name` | `source_id, session_id, tool_name` | Per-session tool filtering |
| chat_tool_usage | `idx_chat_tool_usage_session_timestamp` | `source_id, session_id, timestamp DESC` | Per-session tool timeline |
| chat_sync_state | `idx_chat_sync_state_user_tool_platform` | `user_name, tool_name, platform_name, synced_at DESC` | Per-user sync status |

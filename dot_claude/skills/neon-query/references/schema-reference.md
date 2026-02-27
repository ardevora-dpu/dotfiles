# Neon Chat Schema Reference

Validated against Neon project `shy-wildflower-46673345` on `2026-02-27`.

## Contents

- [Base Tables](#base-tables)
- [`public.search_sessions`](#publicsearch_sessions)
- [`public.search_messages`](#publicsearch_messages)
- [`public.search_tool_usage`](#publicsearch_tool_usage)
- [`public.sync_state`](#publicsync_state)
- [Agent Views](#agent-views)
- [`public.search_sessions_agent_v`](#publicsearch_sessions_agent_v)
- [`public.search_messages_agent_v`](#publicsearch_messages_agent_v)
- [`public.search_messages_agent_light_v`](#publicsearch_messages_agent_light_v)
- [`public.search_user_prompts_agent_v`](#publicsearch_user_prompts_agent_v)

## Base Tables

### `public.search_sessions`

| Column | Type |
|---|---|
| `id` | `integer` |
| `session_id` | `text` |
| `project_path` | `text` |
| `file_path` | `text` |
| `started_at` | `timestamptz` |
| `ended_at` | `timestamptz` |
| `message_count` | `integer` |
| `git_branch` | `text` |
| `cwd` | `text` |
| `synced_at` | `timestamptz` |
| `user_name` | `text` |
| `session_summary` | `text` |
| `branch_count` | `integer` |
| `sidechain_count` | `integer` |
| `parent_session_id` | `text` |
| `session_kind` | `text` |
| `active_duration_minutes` | `integer` |
| `user_prompt_count` | `integer` |
| `assistant_message_count` | `integer` |
| `tool_result_count` | `integer` |
| `tool_call_count` | `integer` |
| `distinct_tool_count` | `integer` |
| `input_tokens_total` | `bigint` |
| `output_tokens_total` | `bigint` |
| `last_tool_at` | `timestamptz` |

### `public.search_messages`

| Column | Type |
|---|---|
| `id` | `integer` |
| `session_id` | `text` |
| `message_uuid` | `text` |
| `message_idx` | `integer` |
| `record_type` | `text` |
| `timestamp` | `timestamptz` |
| `content_text` | `text` |
| `content_json` | `jsonb` |
| `model` | `text` |
| `git_branch` | `text` |
| `cwd` | `text` |
| `input_tokens` | `integer` |
| `output_tokens` | `integer` |
| `content_fts` | `tsvector` |
| `parent_uuid` | `text` |
| `is_sidechain` | `boolean` |
| `thinking_config` | `jsonb` |
| `tool_use_id` | `text` |
| `message_class` | `text` |
| `user_intent_fts` | `tsvector` |

Allowed `message_class` values:

- `tool_result_payload`
- `system_injected`
- `command_invocation`
- `assistant_style_user`
- `human_user_prompt`
- `assistant`
- `system`
- `summary`
- `queue_operation`
- `other`

### `public.search_tool_usage`

| Column | Type |
|---|---|
| `id` | `integer` |
| `message_id` | `integer` |
| `session_id` | `text` |
| `tool_name` | `text` |
| `tool_input` | `jsonb` |
| `timestamp` | `timestamptz` |
| `sql_query` | `text` |
| `file_path` | `text` |
| `tool_fts` | `tsvector` |
| `message_uuid` | `text` |
| `tool_use_id` | `text` |

### `public.sync_state`

| Column | Type |
|---|---|
| `id` | `integer` |
| `file_path` | `text` |
| `blob_last_modified` | `timestamptz` |
| `blob_size_bytes` | `bigint` |
| `last_line_processed` | `integer` |
| `synced_at` | `timestamptz` |

## Agent Views

### `public.search_sessions_agent_v`

Columns:
`session_id`, `project_path`, `file_path`, `started_at`, `ended_at`, `message_count`,
`active_duration_minutes`, `user_prompt_count`, `assistant_message_count`,
`tool_result_count`, `tool_call_count`, `distinct_tool_count`, `input_tokens_total`,
`output_tokens_total`, `last_tool_at`, `session_summary`, `branch_count`,
`sidechain_count`, `git_branch`, `cwd`, `user_name`, `parent_session_id`,
`session_kind`, `synced_at`, `activity_at`

### `public.search_messages_agent_v`

Columns:
`id`, `session_id`, `message_uuid`, `message_idx`, `record_type`, `timestamp`,
`content_text`, `content_json`, `model`, `git_branch`, `cwd`, `input_tokens`,
`output_tokens`, `parent_uuid`, `is_sidechain`, `thinking_config`, `tool_use_id`,
`message_class`, `user_intent_fts`, `is_user_authored`, `is_tool_result`,
`is_system_injected`, `is_assistant_style_user`

### `public.search_messages_agent_light_v`

Columns:
`id`, `session_id`, `message_uuid`, `message_idx`, `record_type`, `timestamp`,
`content_preview`, `content_text_len`, `model`, `git_branch`, `cwd`, `input_tokens`,
`output_tokens`, `parent_uuid`, `is_sidechain`, `tool_use_id`, `message_class`,
`is_user_authored`, `is_tool_result`, `is_system_injected`, `is_assistant_style_user`

### `public.search_user_prompts_agent_v`

Columns:
`id`, `session_id`, `message_uuid`, `message_idx`, `record_type`, `timestamp`,
`content_text`, `content_json`, `model`, `git_branch`, `cwd`, `input_tokens`,
`output_tokens`, `parent_uuid`, `is_sidechain`, `thinking_config`, `tool_use_id`,
`message_class`, `user_intent_fts`

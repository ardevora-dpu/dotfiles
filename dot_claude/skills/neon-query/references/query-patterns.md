# Neon Query Patterns

These are copy/paste-safe templates for the chat-history schema.

## Contents

- [1) Health and Freshness](#1-health-and-freshness)
- [2) Recent Main Sessions](#2-recent-main-sessions)
- [3) What Did Jeremy Ask?](#3-what-did-jeremy-ask)
- [4) What Was Discussed? (All Messages)](#4-what-was-discussed-all-messages)
- [5) Ticker Search](#5-ticker-search)
- [6) Search Message Content by Keyword](#6-search-message-content-by-keyword)
- [7) Search Tool Inputs](#7-search-tool-inputs)
- [8) Link Tool Calls to Results](#8-link-tool-calls-to-results)
- [9) Timeout-Safe Session Hit Aggregation](#9-timeout-safe-session-hit-aggregation)

## 1) Health and Freshness

```sql
SELECT COUNT(*) AS files_tracked, MAX(synced_at) AS last_sync
FROM sync_state;
```

## 2) Recent Main Sessions

```sql
SELECT session_id, started_at, message_count, active_duration_minutes,
       user_prompt_count, tool_call_count, session_summary
FROM search_sessions_agent_v
WHERE started_at >= now() - interval '7 days'
ORDER BY started_at DESC
LIMIT 100;
```

## 3) What Did Jeremy Ask?

Uses `search_user_prompts_agent_v` — pre-filtered to human prompts, has full `content_text`.

```sql
SELECT session_id, timestamp, LEFT(content_text, 300) AS prompt_preview
FROM search_user_prompts_agent_v
WHERE user_intent_fts @@ plainto_tsquery('english', 'search term')
ORDER BY timestamp DESC
LIMIT 50;
```

## 4) What Was Discussed? (All Messages)

Uses `search_messages_agent_v` — has full `content_text` for FTS and ILIKE.

```sql
SELECT session_id, timestamp, message_class,
       LEFT(content_text, 300) AS msg_preview
FROM search_messages_agent_v
WHERE content_fts @@ plainto_tsquery('english', 'peer group regime')
ORDER BY timestamp DESC
LIMIT 50;
```

## 5) Ticker Search

Prefer `simple` config first (uses GIN index), then fallback to `ILIKE` if needed.

```sql
-- Simple FTS (fast, uses index)
SELECT session_id, timestamp, LEFT(content_text, 300) AS msg_preview
FROM search_messages_agent_v
WHERE to_tsvector('simple', COALESCE(content_text, ''))
      @@ plainto_tsquery('simple', 'RMBS-US')
ORDER BY timestamp DESC
LIMIT 50;
```

Fallback for exact hyphenated match:

```sql
SELECT session_id, timestamp, LEFT(content_text, 300) AS msg_preview
FROM search_messages_agent_v
WHERE content_text ILIKE '%RMBS-US%'
ORDER BY timestamp DESC
LIMIT 50;
```

## 6) Search Message Content by Keyword

The most common pattern — find messages mentioning a topic and show snippets.
Always use `search_messages_agent_v` (not the light view) when you need content.

```sql
SELECT m.session_id, m.timestamp, m.message_class,
       LEFT(m.content_text, 400) AS snippet
FROM search_messages_agent_v m
WHERE m.timestamp >= '2026-01-01'
  AND m.content_text ILIKE '%10-k%'
ORDER BY m.timestamp DESC
LIMIT 30;
```

Filter to just human prompts:

```sql
SELECT m.session_id, m.timestamp,
       LEFT(m.content_text, 500) AS prompt
FROM search_user_prompts_agent_v m
WHERE m.timestamp >= '2026-01-01'
  AND m.content_text ILIKE '%filing%'
ORDER BY m.timestamp ASC
LIMIT 50;
```

## 7) Search Tool Inputs

`tool_input` is jsonb — cast to text for ILIKE search.

```sql
SELECT t.session_id, t.timestamp, t.tool_name,
       LEFT(t.tool_input::text, 300) AS input_preview
FROM search_tool_usage t
WHERE t.timestamp >= '2026-01-01'
  AND t.tool_name = 'Bash'
  AND t.tool_input::text ILIKE '%sec_filing%'
ORDER BY t.timestamp ASC
LIMIT 30;
```

Search by SQL query content (auto-extracted for SQL tools):

```sql
SELECT t.session_id, t.timestamp, t.tool_name,
       LEFT(t.sql_query, 300) AS sql_preview
FROM search_tool_usage t
WHERE t.timestamp >= '2026-01-01'
  AND t.sql_query IS NOT NULL
  AND t.sql_query ILIKE '%SCREEN_WEEKLY%'
ORDER BY t.timestamp DESC
LIMIT 20;
```

## 8) Link Tool Calls to Results

Prefer `message_id` join when present; it is direct and reliable.

```sql
SELECT
  t.tool_name,
  t.timestamp AS tool_called_at,
  LEFT(COALESCE(t.sql_query, ''), 200) AS sql_preview,
  LEFT(COALESCE(m.content_text, ''), 300) AS result_preview
FROM search_tool_usage t
LEFT JOIN search_messages m
  ON m.id = t.message_id
WHERE t.timestamp >= now() - interval '30 days'
ORDER BY t.timestamp DESC
LIMIT 100;
```

Fallback for older rows where `message_id` is null:

```sql
SELECT
  t.tool_name,
  t.timestamp AS tool_called_at,
  LEFT(COALESCE(t.sql_query, ''), 200) AS sql_preview,
  LEFT(COALESCE(m.content_text, ''), 300) AS result_preview
FROM search_tool_usage t
LEFT JOIN search_messages m
  ON m.tool_use_id = t.tool_use_id
WHERE t.message_id IS NULL
  AND t.timestamp >= now() - interval '30 days'
ORDER BY t.timestamp DESC
LIMIT 100;
```

## 9) Timeout-Safe Session Hit Aggregation

```sql
WITH base_sessions AS (
  SELECT session_id, started_at, message_count
  FROM search_sessions
  WHERE user_name = 'jeremy'
    AND session_kind = 'main'
    AND started_at >= now() - interval '7 days'
),
msg_hits AS (
  SELECT m.session_id, COUNT(*)::int AS msg_hits
  FROM search_messages m
  WHERE m.content_text ILIKE '%RMBS-US%'
  GROUP BY m.session_id
),
tool_hits AS (
  SELECT t.session_id, COUNT(*)::int AS tool_hits
  FROM search_tool_usage t
  WHERE t.file_path ILIKE '%RMBS-US%'
     OR t.tool_input::text ILIKE '%RMBS-US%'
     OR COALESCE(t.sql_query, '') ILIKE '%RMBS-US%'
  GROUP BY t.session_id
)
SELECT
  b.session_id,
  b.started_at,
  b.message_count,
  COALESCE(m.msg_hits, 0) AS msg_hits,
  COALESCE(t.tool_hits, 0) AS tool_hits,
  (COALESCE(m.msg_hits, 0) + COALESCE(t.tool_hits, 0)) AS total_hits
FROM base_sessions b
LEFT JOIN msg_hits m ON m.session_id = b.session_id
LEFT JOIN tool_hits t ON t.session_id = b.session_id
WHERE (COALESCE(m.msg_hits, 0) + COALESCE(t.tool_hits, 0)) > 0
ORDER BY total_hits DESC, b.started_at DESC
LIMIT 50;
```

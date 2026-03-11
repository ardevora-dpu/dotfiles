# Neon Query Patterns

Copy/paste-safe templates for the chat-history schema.

## Contents

- [1) Health and Freshness](#1-health-and-freshness)
- [2) Recent Main Sessions](#2-recent-main-sessions)
- [3) What Did a User Ask?](#3-what-did-a-user-ask)
- [4) What Was Discussed? (All Messages)](#4-what-was-discussed-all-messages)
- [5) Ticker Search](#5-ticker-search)
- [6) Search Message Content by Keyword](#6-search-message-content-by-keyword)
- [7) Search Tool Inputs](#7-search-tool-inputs)
- [8) Link Tool Calls to Results](#8-link-tool-calls-to-results)
- [9) Timeout-Safe Session Hit Aggregation](#9-timeout-safe-session-hit-aggregation)
- [10) Per-User Activity Summary](#10-per-user-activity-summary)

## 1) Health and Freshness

```sql
SELECT source_id, COUNT(*) AS files_tracked, MAX(synced_at) AS last_sync
FROM chat_sync_state
GROUP BY source_id
ORDER BY last_sync DESC;
```

## 2) Recent Main Sessions

```sql
SELECT session_id, user_name, tool_name, started_at, message_count,
       active_duration_minutes, user_prompt_count, tool_call_count,
       session_summary
FROM chat_sessions_agent_v
WHERE started_at >= now() - interval '7 days'
ORDER BY started_at DESC
LIMIT 100;
```

Filter to a specific user:

```sql
SELECT session_id, started_at, message_count, session_summary
FROM chat_sessions_agent_v
WHERE user_name = 'timon'
  AND started_at >= now() - interval '7 days'
ORDER BY started_at DESC
LIMIT 50;
```

## 3) What Did a User Ask?

Uses `chat_user_prompts_agent_v` — pre-filtered to human prompts, has full `content_text`.

```sql
SELECT session_id, user_name, timestamp, LEFT(content_text, 300) AS prompt_preview
FROM chat_user_prompts_agent_v
WHERE user_intent_fts @@ plainto_tsquery('english', 'search term')
ORDER BY timestamp DESC
LIMIT 50;
```

Filter to one user:

```sql
SELECT session_id, timestamp, LEFT(content_text, 300) AS prompt_preview
FROM chat_user_prompts_agent_v
WHERE user_name = 'jeremy'
  AND user_intent_fts @@ plainto_tsquery('english', 'peer group')
ORDER BY timestamp DESC
LIMIT 50;
```

## 4) What Was Discussed? (All Messages)

Uses `chat_messages_agent_v` — has full `content_text` for FTS and ILIKE.

```sql
SELECT session_id, user_name, timestamp, message_class,
       LEFT(content_text, 300) AS msg_preview
FROM chat_messages_agent_v
WHERE content_fts @@ plainto_tsquery('english', 'peer group regime')
ORDER BY timestamp DESC
LIMIT 50;
```

## 5) Ticker Search

Prefer `simple` config first (uses GIN index), then fallback to `ILIKE` if needed.

```sql
-- Simple FTS (fast, uses index)
SELECT session_id, user_name, timestamp, LEFT(content_text, 300) AS msg_preview
FROM chat_messages_agent_v
WHERE to_tsvector('simple', COALESCE(content_text, ''))
      @@ plainto_tsquery('simple', 'RMBS-US')
ORDER BY timestamp DESC
LIMIT 50;
```

Fallback for exact hyphenated match:

```sql
SELECT session_id, user_name, timestamp, LEFT(content_text, 300) AS msg_preview
FROM chat_messages_agent_v
WHERE content_text ILIKE '%RMBS-US%'
ORDER BY timestamp DESC
LIMIT 50;
```

## 6) Search Message Content by Keyword

Always use `chat_messages_agent_v` (not the light view) when you need content.

```sql
SELECT m.session_id, m.user_name, m.timestamp, m.message_class,
       LEFT(m.content_text, 400) AS snippet
FROM chat_messages_agent_v m
WHERE m.timestamp >= '2026-01-01'
  AND m.content_text ILIKE '%10-k%'
ORDER BY m.timestamp DESC
LIMIT 30;
```

Filter to just human prompts:

```sql
SELECT m.session_id, m.user_name, m.timestamp,
       LEFT(m.content_text, 500) AS prompt
FROM chat_user_prompts_agent_v m
WHERE m.timestamp >= '2026-01-01'
  AND m.content_text ILIKE '%filing%'
ORDER BY m.timestamp ASC
LIMIT 50;
```

## 7) Search Tool Inputs

`tool_input` lives on `chat_records_enriched` for rows with `tool_name_used`.
Cast to text for `ILIKE` probes.

```sql
SELECT t.session_id, t.user_name, t.timestamp, t.tool_name_used AS tool_name,
       LEFT(t.tool_input::text, 300) AS input_preview
FROM chat_records_enriched t
JOIN chat_sessions_mat s
  ON s.source_id = t.source_id
 AND s.session_id = t.session_id
WHERE s.session_kind = 'main'
  AND t.timestamp >= '2026-01-01'
  AND t.tool_name_used = 'Bash'
  AND t.tool_input::text ILIKE '%sec_filing%'
ORDER BY t.timestamp ASC
LIMIT 30;
```

Search by SQL query content (auto-extracted for SQL tools):

```sql
SELECT t.session_id, t.user_name, t.timestamp, t.tool_name_used AS tool_name,
       LEFT(t.sql_query, 300) AS sql_preview
FROM chat_records_enriched t
JOIN chat_sessions_mat s
  ON s.source_id = t.source_id
 AND s.session_id = t.session_id
WHERE s.session_kind = 'main'
  AND t.timestamp >= '2026-01-01'
  AND t.sql_query IS NOT NULL
  AND t.sql_query ILIKE '%SCREEN_WEEKLY%'
ORDER BY t.timestamp DESC
LIMIT 20;
```

## 8) Link Tool Calls to Result Messages

Link tool-call rows (`tool_name_used`) to result payload messages by
`source_id + session_id + tool_use_id`.

```sql
SELECT
  t.tool_name_used AS tool_name,
  t.user_name,
  t.timestamp AS tool_called_at,
  LEFT(COALESCE(t.sql_query, ''), 200) AS sql_preview,
  LEFT(COALESCE(m.content_text, ''), 300) AS result_preview
FROM chat_records_enriched t
LEFT JOIN chat_messages_agent_v m
  ON m.source_id = t.source_id
 AND m.session_id = t.session_id
 AND m.tool_use_id = t.tool_use_id
WHERE t.timestamp >= now() - interval '30 days'
  AND t.tool_name_used IS NOT NULL
ORDER BY t.timestamp DESC
LIMIT 100;
```

## 9) Timeout-Safe Session Hit Aggregation

```sql
WITH base_sessions AS (
  SELECT source_id, session_id, started_at, message_count
  FROM chat_sessions_agent_v
  WHERE started_at >= now() - interval '7 days'
),
msg_hits AS (
  SELECT m.source_id, m.session_id, COUNT(*)::int AS msg_hits
  FROM chat_messages_agent_v m
  WHERE m.content_text ILIKE '%RMBS-US%'
  GROUP BY m.source_id, m.session_id
),
tool_hits AS (
  SELECT t.source_id, t.session_id, COUNT(*)::int AS tool_hits
  FROM chat_records_enriched t
  JOIN chat_sessions_mat s
    ON s.source_id = t.source_id
   AND s.session_id = t.session_id
  WHERE s.session_kind = 'main'
    AND t.tool_name_used IS NOT NULL
    AND (
         t.tool_input::text ILIKE '%RMBS-US%'
     OR COALESCE(t.sql_query, '') ILIKE '%RMBS-US%'
    )
  GROUP BY t.source_id, t.session_id
)
SELECT
  b.session_id,
  b.started_at,
  b.message_count,
  COALESCE(m.msg_hits, 0) AS msg_hits,
  COALESCE(t.tool_hits, 0) AS tool_hits,
  (COALESCE(m.msg_hits, 0) + COALESCE(t.tool_hits, 0)) AS total_hits
FROM base_sessions b
LEFT JOIN msg_hits m
  ON m.source_id = b.source_id AND m.session_id = b.session_id
LEFT JOIN tool_hits t
  ON t.source_id = b.source_id AND t.session_id = b.session_id
WHERE (COALESCE(m.msg_hits, 0) + COALESCE(t.tool_hits, 0)) > 0
ORDER BY total_hits DESC, b.started_at DESC
LIMIT 50;
```

## 10) Per-User Activity Summary

```sql
SELECT
  user_name,
  tool_name,
  COUNT(*) AS sessions,
  SUM(user_prompt_count) AS total_prompts,
  SUM(input_tokens_total + output_tokens_total) AS total_tokens,
  MIN(started_at) AS earliest,
  MAX(started_at) AS latest
FROM chat_sessions_agent_v
WHERE started_at >= now() - interval '30 days'
GROUP BY user_name, tool_name
ORDER BY total_prompts DESC;
```

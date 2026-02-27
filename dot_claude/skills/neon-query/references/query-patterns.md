# Neon Query Patterns

These are copy/paste-safe templates for the chat-history schema.

## Contents

- [1) Health and Freshness](#1-health-and-freshness)
- [2) Recent Main Sessions](#2-recent-main-sessions)
- [3) What Did Jeremy Ask?](#3-what-did-jeremy-ask)
- [4) What Was Discussed? (All Messages)](#4-what-was-discussed-all-messages)
- [5) Ticker Search](#5-ticker-search)
- [6) Link Tool Calls to Results](#6-link-tool-calls-to-results)
- [7) Timeout-Safe Session Hit Aggregation](#7-timeout-safe-session-hit-aggregation)

## 1) Health and Freshness

```sql
SELECT COUNT(*) AS files_tracked, MAX(synced_at) AS last_sync
FROM sync_state;
```

## 2) Recent Main Sessions

```sql
SELECT session_id, started_at, message_count, git_branch
FROM search_sessions_agent_v
WHERE started_at >= now() - interval '7 days'
ORDER BY started_at DESC
LIMIT 100;
```

## 3) What Did Jeremy Ask?

```sql
SELECT s.session_id, s.started_at, LEFT(m.content_text, 300) AS prompt_preview
FROM search_sessions_agent_v s
JOIN search_user_prompts_agent_v m ON m.session_id = s.session_id
WHERE m.user_intent_fts @@ plainto_tsquery('english', 'search term')
ORDER BY s.started_at DESC
LIMIT 50;
```

## 4) What Was Discussed? (All Messages)

```sql
SELECT s.session_id, s.started_at, LEFT(m.content_text, 300) AS msg_preview
FROM search_sessions_agent_v s
JOIN search_messages m ON m.session_id = s.session_id
WHERE m.content_fts @@ plainto_tsquery('english', 'peer group regime')
ORDER BY s.started_at DESC
LIMIT 50;
```

## 5) Ticker Search

Prefer `simple` config first, then fallback to `ILIKE` if needed.

```sql
SELECT session_id, timestamp, LEFT(content_text, 300) AS msg_preview
FROM search_messages
WHERE to_tsvector('simple', COALESCE(content_text, ''))
      @@ plainto_tsquery('simple', 'RMBS-US')
ORDER BY timestamp DESC
LIMIT 50;
```

Fallback:

```sql
SELECT session_id, timestamp, LEFT(content_text, 300) AS msg_preview
FROM search_messages
WHERE content_text ILIKE '%RMBS-US%'
ORDER BY timestamp DESC
LIMIT 50;
```

## 6) Link Tool Calls to Results

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

## 7) Timeout-Safe Session Hit Aggregation

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

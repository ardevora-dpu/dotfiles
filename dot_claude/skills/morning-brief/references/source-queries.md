# Source Queries Reference

Exact API calls, parameters, and field extraction per source. Each section is self-contained — agents read only their section.

## Google Calendar

**Discover calendars:**
```
gcal_list_calendars {}
```
Returns array with `id`, `summary`, `accessRole`. Known calendars:
- `primary` / `timonvanrensburg@gmail.com` — Timon's personal
- `lpmullertz@gmail.com` — Laura's calendar (reader access)
- ArdDPU Work Calendar — currently empty, skip

To find Laura's calendar: search for "Laura" or "lpmullertz" in summary/id. Do not hardcode the ID.

**Fetch events:**
```
gcal_list_events {
  "calendarId": "<id>",
  "timeMin": "{period_start}",
  "timeMax": "{period_end}",
  "timeZone": "Europe/London",
  "condenseEventDetails": false
}
```
Use `"primary"` for Timon, `"lpmullertz@gmail.com"` for Laura.
Returns envelope: `summary`, `timeZone`, `events[]`. Event fields: `id`, `summary`, `eventType`, `description`, `start.dateTime`, `start.timeZone`, `end.dateTime`.

**Free time (today only):**
```
gcal_find_my_free_time {
  "calendarIds": ["primary", "lpmullertz@gmail.com"],
  "timeMin": "<today>T06:00:00",
  "timeMax": "<today>T23:59:59",
  "timeZone": "Europe/London"
}
```
Returns `freeSlots[]` with `start`, `end`, `duration` (string, e.g. "690 minutes").

## Outlook Calendar

```
list-calendar-events {
  "filter": "start/dateTime ge '{period_start}' and start/dateTime lt '{period_end}'",
  "select": ["id", "subject", "start", "end", "location", "attendees", "organizer", "isAllDay", "bodyPreview"]
}
```
One calendar only (Ardevora work calendar, isDefault: true, owner: t.vanrensburg@ardevora.com).

## Linear — My Queue

**Fetch issues by state (must query each state separately):**
```
list_issues {
  "assignee": "t.vanrensburg@ardevora.com",
  "state": "In Progress",
  "limit": 50
}
```
Repeat for states: `"In Progress"`, `"Todo"`, `"Backlog"`.

State filter uses **name strings** (In Progress, Todo, Backlog, Done, In Review, Canceled), NOT type enums (unstarted, started, completed). Type-based queries return empty.

**Current cycle:**
```
list_cycles {
  "teamId": "2d73c05d-4229-4298-9697-ee123d911d3b"
}
```
Requires `teamId` (fails without it). Returns cycles with `number`, `startsAt`, `endsAt`, `completedScopeHistory`, `scopeHistory`, `isCurrent`.

**Issues in current cycle:**
```
list_issues {
  "assignee": "t.vanrensburg@ardevora.com",
  "cycle": "<cycle_number>",
  "limit": 50
}
```
Cycle number as string (e.g. `"8"`).

**Milestones:**
```
list_projects {
  "team": "2d73c05d-4229-4298-9697-ee123d911d3b"
}
```
Then for each project with upcoming milestones:
```
list_milestones {
  "project": "<project_name>"
}
```
Use project **name** string, not UUID. Returns `name`, `targetDate`, `progress`.

**Issue details (if needed):**
```
get_issue {
  "id": "<UUID>"
}
```
Must use UUID, not identifier like "ARD-451".

## Linear — Team

```
list_issues {
  "team": "2d73c05d-4229-4298-9697-ee123d911d3b",
  "updatedAt": "-P{days}D",
  "limit": 25,
  "orderBy": "updatedAt"
}
```
`updatedAt: "-P3D"` = updated in last 3 days. Use the period length (e.g. `-P1D` for 24h, `-P7D` for weekly).

Team members for grouping:
- t.vanrensburg@ardevora.com (Timon) — skip, covered by Work Queue
- j.lang@ardevora.com (Jeremy)
- j.algeo@ardevora.com (Jack)
- a.mcguire@ardevora.com (Aisling)
- h.spear@ardevora.com (Helen)

Query multiple states if needed: `"In Progress"`, `"Todo"`, `"Done"`, `"In Review"`.

## Outlook Email

```
list-mail-folder-messages {
  "mailFolderId": "Inbox",
  "top": 30,
  "filter": "receivedDateTime ge {period_start_iso}",
  "select": ["subject", "from", "receivedDateTime", "bodyPreview", "importance", "isRead"],
  "orderby": ["receivedDateTime desc"]
}
```
Folder name `"Inbox"` works directly (no ID lookup needed). Fields: `subject`, `from`, `receivedDateTime`, `bodyPreview`, `importance`, `isRead`.

**Metadata only** — never fetch full email body unless explicitly asked.

## Gmail

```
gmail_search_messages {
  "q": "newer_than:{days}d is:unread in:inbox -category:promotions -category:updates -category:social -from:substack.com -from:medium.com -from:beehiiv.com -from:readthejoe.com -from:joincolossus.com",
  "maxResults": 30
}
```
Account: timonvanrensburg@gmail.com (personal, not work). Use `category:personal` filter or the exclusion pattern above. Inbox is well-filtered — most mail is newsletters/promotions. The exclusion pattern above catches the main newsletter sources.

Message fields: `id`, `threadId`, `labelIds`, `snippet`, `headers` (Subject, From, To).

For starred/important items:
```
gmail_search_messages {
  "q": "newer_than:30d is:starred",
  "maxResults": 20
}
```

## MS To Do

**Step 1 — find task lists:**
```
list-todo-task-lists {}
```
Returns two lists: "Tasks" (defaultList) and "Flagged Emails" (flaggedEmails).

**Step 2 — fetch tasks:**
```
list-todo-tasks {
  "todoTaskListId": "<flagged_emails_list_id>",
  "fetchAllPages": true
}
```
Do NOT use `select` parameter — causes 400 error. Returns full task objects with: `importance`, `status`, `title`, `createdDateTime`, `lastModifiedDateTime`, `linkedResources` (points to source emails).

Filter to non-completed tasks client-side (`status !== "completed"`).

## Teams

**Step 1 — list all chats:**
```
list-chats {
  "top": 50,
  "select": ["id", "topic", "chatType", "lastUpdatedDateTime"],
  "expand": ["members"]
}
```
No `orderby` support — the API rejects `orderby: ["lastUpdatedDateTime desc"]`.

**Step 2 — filter client-side:**
Keep chats where `lastUpdatedDateTime >= period_start`. Sort by `lastUpdatedDateTime` descending. Take top 10 most recent.

**Step 3 — fetch messages per active chat:**
```
list-chat-messages {
  "chatId": "<chat_id>",
  "top": 15
}
```
API limitations:
- No `select` parameter (returns 400: "Query option 'Select' is not allowed")
- No `orderby` support — messages return oldest-first
- `top` must be a number, not a string
- Meeting chats (`19:meeting_*@thread.v2`) return `messageType: "unknownFutureValue"` for system messages — filter these out

Sort messages client-side by `createdDateTime` descending after retrieval.

**Do NOT use channel messages** (`list-channel-messages`) — they return oldest-first with no pagination control, making recent messages inaccessible without paginating entire history.

## Neon

**Always pass:** `projectId: "shy-wildflower-46673345"`. Do not pass `databaseName`.

**Query 1 — Session summary:**
```sql
SELECT
  session_id, started_at, ended_at, message_count,
  user_prompt_count, tool_call_count, distinct_tool_count,
  input_tokens_total, output_tokens_total,
  active_duration_minutes, sidechain_count, cwd_short
FROM search_sessions
WHERE started_at > NOW() - INTERVAL '{period_days} days'
ORDER BY started_at DESC
```
Use `search_sessions` (raw table) for `user_prompt_count`, `tool_call_count`, `distinct_tool_count`, `input_tokens_total`, `output_tokens_total`. These columns do NOT exist on `search_sessions_agent_v`.

Column is `started_at`, NOT `created_at`.

**Query 2 — Ticker extraction:**
```sql
SELECT
  (regexp_match(cwd, E'\\\\([A-Z0-9]+-[A-Z]{2})\\\\'))[1] as ticker,
  COUNT(*) as sessions,
  SUM(message_count) as messages,
  SUM(active_duration_minutes) as active_mins,
  MAX(started_at) as last_active
FROM search_sessions_agent_v
WHERE started_at > NOW() - INTERVAL '{period_days} days'
GROUP BY ticker
ORDER BY active_mins DESC
```
Note escape string prefix `E'...'` with double backslashes for literal backslash in Postgres regex.

**Query 3 — What Jeremy typed:**
```sql
SELECT s.cwd_short, m.content_text, m.timestamp
FROM search_user_prompts_agent_v m
JOIN search_sessions_agent_v s ON m.session_id = s.session_id
WHERE m.timestamp > NOW() - INTERVAL '{period_days} days'
  AND m.content_text NOT LIKE '%<task-notification>%'
ORDER BY m.timestamp DESC
LIMIT 30
```
Column is `timestamp`, NOT `created_at`.

**Query 4 — Tool usage:**
```sql
SELECT tool_name, COUNT(*) as uses
FROM search_tool_usage
WHERE timestamp > NOW() - INTERVAL '{period_days} days'
GROUP BY tool_name
ORDER BY uses DESC
LIMIT 15
```

**Key table routing:**
| Use case | Table/view |
|----------|-----------|
| Rich session stats (prompt/token counts) | `search_sessions` (raw) |
| Session-level with cwd/branch | `search_sessions_agent_v` |
| User prompts (what Jeremy typed) | `search_user_prompts_agent_v` |
| Tool usage counts | `search_tool_usage` |

Do not use semicolons at the end of SQL statements — they cause syntax errors in the Neon MCP.

## Otter

**Search for meetings:**
```
otter__search {
  "query": "",
  "created_after": "YYYY/MM/DD",
  "created_before": "YYYY/MM/DD",
  "include_shared_meetings": true,
  "username": "Timon van Rensburg"
}
```
Date format is `YYYY/MM/DD` (slashes, not hyphens, not ISO).

Returns `results[]` with: `id` (this is the `speech_id`), `title`, `url`, `start_time` (format: "YYYY/MM/DD HH:MM:SS"), `duration` (e.g. "1h 28m"), `short_summary`, `action_items[]`, `calendar_participants[]`.

**Fetch full transcript:**
```
otter__fetch {
  "id": "<speech_id>"
}
```
Returns JSON with `id`, `title`, `text` (full transcript). Format: `[H:MM:SS] Speaker Name: spoken text`.

Transcripts are large (~80K chars for a 78-min meeting). Process in the sub-agent — do not return raw transcript to main context. Fetch max 2 transcripts per brief run.

## Snowflake

**Task pipeline status:**
```sql
SELECT name, state, scheduled_time, completed_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  SCHEDULED_TIME_RANGE_START => DATEADD('day', -{period_days}, CURRENT_TIMESTAMP()),
  RESULT_LIMIT => 100
))
ORDER BY scheduled_time DESC
```
Known tasks: `DBT_UPSTREAM_TASK`, `DBT_DOWNSTREAM_TASK`, `ADX_REFRESH_TASK`, `APPLY_OVERRIDES_TASK`, `DBT_OWNERSHIP_GUARD_TASK`, `SEND_ACCOUNT_NOTIFICATIONS_TASK`, `EVENT_DRIVEN_SCANNER_PROBE`.

**SCREEN_WEEKLY freshness:**
```sql
SELECT MAX(week_end_date) as latest_week_end,
       DATEDIFF('day', MAX(week_end_date), CURRENT_DATE()) as days_stale
FROM MART.SCREEN_WEEKLY
```
Column is `week_end_date`, NOT `AS_OF_DATE`.

**Credit usage:**
```sql
SELECT DATE(start_time) as day,
       warehouse_name,
       SUM(credits_used) as credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD('day', -{period_days}, CURRENT_TIMESTAMP())
GROUP BY day, warehouse_name
ORDER BY day DESC
```

## GitHub

**Open PRs:**
```bash
gh pr list --state open --json number,title,author,createdAt,updatedAt,reviewDecision,isDraft,labels
```
`reviewDecision` values: `APPROVED`, `CHANGES_REQUESTED`, `REVIEW_REQUIRED`, or empty string.

**Recently merged PRs:**
```bash
gh pr list --state merged --limit 20 --search "merged:>={period_start_date}" --json number,title,author,mergedAt
```

**CI status (latest runs):**
```bash
gh run list --limit 5 --json status,conclusion,name,createdAt,headBranch
```
`conclusion` values: `success`, `failure`, `cancelled`.

## Quota

```bash
uv run python scripts/dev/claude-usage.py
```
Parses `~/.claude/accounts/` and checks live utilisation via OAuth usage endpoint. Returns a formatted table with account names, usage percentages, and reset times. Parse the table output for: account name, usage %, time until reset.

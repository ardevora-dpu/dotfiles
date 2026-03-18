# Source Queries Reference

Exact API calls, parameters, and field extraction per source. Each section is self-contained — agents read only their section.

## Google Calendar (via `gws` CLI)

All Google Calendar queries use the `gws` CLI (authenticated, credentials cached at `~/.config/gws/`). Run via Bash tool.

**List all calendars:**
```bash
GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file gws calendar calendarList list --format json
```
Returns `items[]` with `id`, `summary`, `accessRole`. Known calendars:
- `timonvanrensburg@gmail.com` — Timon's personal (use as `calendarId` for primary)
- `lpmullertz@gmail.com` — Laura's calendar (reader access)
- ArdDPU Work Calendar — currently empty, skip

**Today's agenda (quick overview):**
```bash
GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file gws calendar +agenda
```
Returns a table of upcoming events across all calendars. Good for a quick scan.

**Fetch events for a period:**
```bash
GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file gws calendar events list --params '{"calendarId":"timonvanrensburg@gmail.com","timeMin":"{period_start}","timeMax":"{period_end}","timeZone":"Europe/London","singleEvents":true,"orderBy":"startTime"}' --format json
```
Repeat for Laura's calendar with `"calendarId":"lpmullertz@gmail.com"`.

Returns JSON with `items[]`. Event fields: `id`, `summary`, `description`, `start.dateTime`, `end.dateTime`, `location`, `attendees`.

**Free/busy (today only):**
```bash
GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file gws calendar freebusy query --json '{"timeMin":"{today}T06:00:00Z","timeMax":"{today}T23:59:59Z","timeZone":"Europe/London","items":[{"id":"timonvanrensburg@gmail.com"},{"id":"lpmullertz@gmail.com"}]}' --format json
```
Returns `calendars.<id>.busy[]` with `start` and `end` times. Compute free slots by inverting busy blocks.

**Note:** Always prefix gws commands with `GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file` to ensure sub-agents can access credentials without OS keyring. `gws` outputs a `Using keyring backend: file` line to stderr — ignore it. Parse JSON from stdout only.

## Outlook Calendar

**Timon's calendar (default):**
```
list-calendar-events {
  "filter": "start/dateTime ge '{period_start}' and start/dateTime lt '{period_end}'",
  "select": ["id", "subject", "start", "end", "location", "attendees", "organizer", "isAllDay", "bodyPreview"]
}
```

**Team member calendars** (requires `list-specific-calendar-events` with userId):
```
list-specific-calendar-events {
  "userId": "<email>",
  "calendarId": "calendar",
  "filter": "start/dateTime ge '{period_start}' and start/dateTime lt '{period_end}'",
  "select": ["subject", "start", "end", "location", "attendees", "organizer"]
}
```

**Team calendars via Graph API** (delegated Reviewer access granted):
```bash
uv run --group outlook python -c "
import msal, requests, json
from pathlib import Path
cache = msal.SerializableTokenCache()
cache.deserialize((Path.home() / '.cache' / 'outlook-move-token.json').read_text())
app = msal.PublicClientApplication('084a3e9f-a9f4-43f7-89f9-d229cf97853e', authority='https://login.microsoftonline.com/common', token_cache=cache)
result = app.acquire_token_silent(['https://graph.microsoft.com/.default'], account=app.get_accounts()[0])
h = {'Authorization': f'Bearer {result[\"access_token\"]}'}
team = {'Aisling':'a.mcguire@ardevora.com','Jack':'j.algeo@ardevora.com','Helen':'h.spear@ardevora.com','Jeremy':'j.lang@ardevora.com','Bill':'w.pattisson@ardevora.com'}
out = {}
for name, email in team.items():
    r = requests.get(f'https://graph.microsoft.com/v1.0/users/{email}/calendarView', headers=h, params={'startDateTime':'{period_start}','endDateTime':'{period_end}','\$select':'subject,start,end,organizer,attendees','\$top':'20'}, timeout=15)
    out[name] = r.json().get('value',[]) if r.status_code == 200 else []
print(json.dumps(out, indent=2))
"
```
Replace `{period_start}` and `{period_end}` with ISO timestamps. Returns a JSON object keyed by person name, each containing an array of events.

Team members:
- `a.mcguire@ardevora.com` (Aisling — ops, vendor management, JPM/UBS onboarding)
- `j.algeo@ardevora.com` (Jack — COO, communications)
- `h.spear@ardevora.com` (Helen — governance, legal)
- `j.lang@ardevora.com` (Jeremy — PM, research)
- `w.pattisson@ardevora.com` (William/Bill — investor, non-exec)

This gives the brief visibility into who is advancing which objectives today. Critical for avoiding false drift warnings (e.g. "AMC stalled" when Aisling has a JPM call at 14:00).

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

## Outlook Email — Inbox Triage

**Fetch inbox messages for classification:**
```
list-mail-folder-messages {
  "mailFolderId": "Inbox",
  "top": 50,
  "filter": "receivedDateTime ge {period_start_iso}",
  "select": ["id", "subject", "from", "receivedDateTime", "bodyPreview", "importance", "isRead"],
  "orderby": ["receivedDateTime desc"]
}
```
For first run (no triage-manifest.json), use `"fetchAllPages": true` and omit the filter to process the full inbox backlog.

Fields: `id` (needed for moves), `subject`, `from`, `receivedDateTime`, `bodyPreview` (first 255 chars — primary classification signal), `importance`, `isRead`.

**Execute moves via Graph API helper:**
```bash
echo '<json_manifest>' | uv run --group outlook python workspaces/timon/scripts/outlook_move.py
```
Manifest format: `[{"messageId":"<id>","destinationFolderId":"<folder_id>"}]`
Returns: `{"moved": N, "failed": N, "errors": [...]}`

**Folder IDs (stable, hardcoded):**
| Folder | ID |
|--------|-----|
| Inbox | `AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAAAAAEMAAA=` |
| Broker Notes | `AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQXAAA=` |
| Quant & Data | `AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQUAAA=` |
| Newsletters | `AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQVAAA=` |
| Invoices | `AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQTAAA=` |
| Platform Alerts | `AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYVG0pcAAA=` |

**Classification heuristics** (use bodyPreview + subject + sender domain):
- **Platform Alerts** (highest priority — classify BEFORE other categories): GitHub Actions (notifications@github.com + "Run failed" / "PR run failed"), Snowflake alerts (no-reply@snowflake.net + "Task Failed" / "security violation"), Azure budget alerts (azure-noreply@microsoft.com), Anthropic login links (mail.anthropic.com + "Secure link to log in"), AlphaSense usage alerts (noreply@alpha-sense.com + "Consumption"), Mortimer House automated (no-reply@mail.nexudus.com)
- Broker Notes: domains like ms.com, bofa, citi.com, jefferies.com, bernstein, barclays, ubs.com + "research", "note", "morning mail"
- Quant & Data: wolfe-qes, ubs-primeview, s3partners, db-qis + "factor", "flow", "short interest", "positioning"
- Newsletters: substack.com, beehiiv.com, alphasignal, huggingface, medium + subscription patterns
- Invoices: "invoice", "statement", "receipt", "billing" + stripe.com, microsoft.com, github.com, anthropic (but NOT login links or CI notifications — those go to Platform Alerts)
- Actionable (stays in inbox): colleague emails requiring a response, active vendor threads needing human judgement. Note: read old thread replies (isRead: true, older than 7 days) are NOT actionable — archive or skip.
- Uncertain: leave in inbox when confidence is low

## Outlook Email — Folder Intelligence

Read recently-arrived items in each subfolder to extract signal. Each folder has a different signal tier.

**Newsletters** (most detail — CPD/learning):
```
list-mail-folder-messages {
  "mailFolderId": "AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQVAAA=",
  "top": 20,
  "filter": "receivedDateTime ge {period_start_iso}",
  "select": ["subject", "from", "receivedDateTime", "bodyPreview"],
  "orderby": ["receivedDateTime desc"]
}
```

**Broker Notes** (notable events only):
```
list-mail-folder-messages {
  "mailFolderId": "AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQXAAA=",
  "top": 20,
  "filter": "receivedDateTime ge {period_start_iso}",
  "select": ["subject", "from", "receivedDateTime", "bodyPreview"],
  "orderby": ["receivedDateTime desc"]
}
```

**Quant & Data** (standouts only):
```
list-mail-folder-messages {
  "mailFolderId": "AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQUAAA=",
  "top": 10,
  "filter": "receivedDateTime ge {period_start_iso}",
  "select": ["subject", "from", "receivedDateTime", "bodyPreview"],
  "orderby": ["receivedDateTime desc"]
}
```

**Invoices** (cost management):
```
list-mail-folder-messages {
  "mailFolderId": "AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQTAAA=",
  "top": 10,
  "filter": "receivedDateTime ge {period_start_iso}",
  "select": ["subject", "from", "receivedDateTime", "bodyPreview"],
  "orderby": ["receivedDateTime desc"]
}
```

## Gmail (via `gws` CLI)

All Gmail queries use the `gws` CLI (authenticated, credentials cached at `~/.config/gws/`). Run via Bash tool.

Account: timonvanrensburg@gmail.com (personal, not work).

**Inbox triage (quick overview):**
```bash
GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file gws gmail +triage
```
Returns a table of recent inbox messages with date, from, id, subject. Good for a quick scan.

**Search inbox (unread, filtered):**
```bash
GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file gws gmail users messages list --params '{"userId":"me","q":"is:unread newer_than:{days}d in:inbox -category:promotions -category:updates -category:social","maxResults":30}' --format json
```
Returns `messages[]` with `id` and `threadId`. Must fetch individual messages for content.

**Read a specific message (metadata + snippet):**
```bash
GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file gws gmail users messages get --params '{"userId":"me","id":"<message_id>","format":"metadata","metadataHeaders":["Subject","From","Date"]}' --format json
```
Returns `snippet` (first ~100 chars of body), `payload.headers[]` with Subject/From/Date, `labelIds`.

**Read full message body:**
```bash
GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file gws gmail users messages get --params '{"userId":"me","id":"<message_id>","format":"full"}' --format json
```
Returns full payload including body parts. Use only when needed for deep content extraction.

**Starred/important items:**
```bash
GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file gws gmail users messages list --params '{"userId":"me","q":"is:starred newer_than:30d","maxResults":20}' --format json
```

**Note:** Always prefix gws commands with `GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file`. `gws` outputs `Using keyring backend: file` to stderr — ignore it. Parse JSON from stdout. Gmail is personal email — surface calendar invites (Laura), security alerts, and anything life-relevant. This is the "here is what is happening in your life" dimension of the brief.

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

Query via `psycopg` using `DATABASE_URL`. Do not use the retired Neon MCP.

### Multi-User Session Summary

**Query 1 — Root sessions (all users):**
```sql
SELECT
  root_session_ref, user_name, activity_at,
  active_duration_minutes, session_count, message_count,
  user_prompt_count, tool_call_count,
  input_tokens_total, output_tokens_total,
  session_summary
FROM chat_root_sessions_agent_v
WHERE user_name IN ('jeremy', 'timon', 'jack')
  AND activity_at >= NOW() - INTERVAL '{period_days} days'
ORDER BY user_name, activity_at DESC
```

**Query 2 — Jeremy ticker extraction** (Jeremy-specific, uses cwd paths):
```sql
SELECT
  (regexp_match(cwd, E'\\\\([A-Z0-9]+-[A-Z]{2})\\\\'))[1] as ticker,
  COUNT(*) as sessions,
  SUM(message_count) as messages,
  SUM(active_duration_minutes) as active_mins,
  MAX(started_at) as last_active
FROM chat_sessions_agent_v
WHERE user_name = 'jeremy'
  AND started_at > NOW() - INTERVAL '{period_days} days'
GROUP BY ticker
ORDER BY active_mins DESC
```
Note escape string prefix `E'...'` with double backslashes for literal backslash in Postgres regex.

**Query 3 — User prompts (all users):**
```sql
SELECT s.user_name, m.prompt_text, m.created_at, s.root_session_ref
FROM chat_user_prompts_agent_v m
JOIN chat_root_sessions_agent_v s
  ON m.root_session_ref = s.root_session_ref
WHERE m.created_at > NOW() - INTERVAL '{period_days} days'
  AND s.user_name IN ('jeremy', 'timon', 'jack')
  AND m.prompt_text NOT LIKE '%<task-notification>%'
ORDER BY m.created_at DESC
LIMIT 50
```

**Query 4 — Tool usage (all users):**
```sql
SELECT s.user_name, t.called_tool_name AS tool_name, COUNT(*) AS uses
FROM chat_tool_calls_agent_v t
JOIN chat_root_sessions_agent_v s
  ON t.root_session_ref = s.root_session_ref
WHERE s.user_name IN ('jeremy', 'timon', 'jack')
  AND t.called_tool_name IS NOT NULL
  AND t.created_at > NOW() - INTERVAL '{period_days} days'
GROUP BY s.user_name, t.called_tool_name
ORDER BY s.user_name, uses DESC
```

**Query 5 — Jeremy artefact context** (Jeremy-specific):
```sql
SELECT
  t.created_at,
  t.called_tool_name,
  t.normalised_tool_file_path,
  t.artifact_ticker_region,
  t.evidence_relative_path
FROM chat_tool_calls_agent_v t
JOIN chat_root_sessions_agent_v s
  ON t.root_session_ref = s.root_session_ref
WHERE s.user_name = 'jeremy'
  AND t.created_at > NOW() - INTERVAL '{period_days} days'
ORDER BY t.created_at DESC
LIMIT 30
```

**Key table routing:**
| Use case | Table/view |
|----------|-----------|
| Root session overview (all users) | `chat_root_sessions_agent_v` |
| Per-session detail (subagent trees) | `chat_session_nodes_agent_v` |
| User prompts (what people typed) | `chat_user_prompts_agent_v` |
| Tool usage (tool names, SQL, paths) | `chat_tool_calls_agent_v` |
| Freshness check | `chat_sync_freshness_v` |

**Gotcha:** Check `chat_sync_freshness_v.is_current` before drawing conclusions. If stale, note it.

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
       DATEDIFF('day', MAX(week_end_date), CURRENT_DATE()) as days_since_last,
       -- Expected: latest week_end_date should be the most recent Friday
       -- Refreshes run on Saturdays. A week_end_date of last Friday is NORMAL mid-week.
       CASE
         WHEN MAX(week_end_date) >= DATE_TRUNC('week', CURRENT_DATE()) - INTERVAL '2 days'
         THEN 'current'  -- latest Friday or newer = on schedule
         ELSE 'stale'    -- older than last Friday = missed a refresh
       END as status
FROM MART.SCREEN_WEEKLY
```
Column is `week_end_date`, NOT `AS_OF_DATE`.

**IMPORTANT:** SCREEN_WEEKLY is a weekly artefact. It refreshes on Saturdays and covers the week ending the preceding Friday. A `days_since_last` of 2-6 is NORMAL depending on day of week. Only flag as stale if `status = 'stale'` (meaning the Saturday refresh didn't run). Do NOT report raw day count as "X days stale" — this caused false alarms across 5 consecutive briefs.

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

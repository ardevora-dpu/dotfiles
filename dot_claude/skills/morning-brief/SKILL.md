---
name: morning-brief
description: >
  Layered morning briefing from calendar, Linear, email, Teams, Neon,
  Otter, Snowflake, GitHub, and quota. Use when asked for "morning brief",
  "catch me up", "what did I miss", or "/morning-brief".
---

# Morning Brief

Daily catch-up and direction-setting briefing aggregated from 11 data sources.

## Purpose

Both catch-up ("what happened while I wasn't looking") and direction-setting ("what matters today").

**Reader outcome:** Oriented in 30 seconds from the exec summary, full detail below, actions consolidated at the top. If nothing needs a response, say so.

**Voice:** Ardevora style — British spelling, claims proportional to evidence, serious peer tone. No superlatives, no exclamation marks, no hype.

## Parameters

- No args → 24-hour lookback from now
- `3d` → 3 days
- `weekly` → 7 days
- `Xd` → X days (any integer)
- `since monday`, `since friday` → natural language date (resolve to midnight UTC)

Compute `period_start` (ISO datetime) and `period_end` (now). Pass both to every sub-agent.

## Execution Flow

```
1. PARSE parameters → compute period_start, period_end
2. CREATE state directory if missing: workspaces/timon/.local/morning-brief/
3. DISPATCH 8 sub-agents in parallel (see Agent Dispatch Table)
   └── Each reads its section from references/source-queries.md
4. COLLECT results — best-effort, note failures
4.5. DIFF — Read the most recent previous brief (brief-YYYY-MM-DD.md, sorted
     by filename descending, skip today's). Pass its content as context to the
     synthesis step. If no previous brief exists, skip diffing.
5. LOAD references/assembly-format.md for voice and structural requirements
6. SYNTHESISE: actions at top, exec summary, then expand/merge/skip based on findings
   (with previous brief context for delta tagging — see assembly-format.md § Delta Awareness)
7. WRITE brief to workspaces/timon/.local/morning-brief/brief-YYYY-MM-DD.md
8. UPDATE last-run.json
9. PRESENT to terminal
```

Sub-agents are REQUIRED — the main context does not gather evidence directly. This follows the weekly-recap pattern: agents do collection, main Claude does synthesis.

## Agent Dispatch Table

8 parallel agents. Each receives: `period_start`, `period_end`, and instructions to read its section from `references/source-queries.md`.

| # | Agent | Sources | Key Tools |
|---|-------|---------|-----------|
| 1 | **Schedule** | Google Cal (mine + Laura's) + Outlook Cal | `gcal_list_events`, `gcal_list_calendars`, `gcal_find_my_free_time`, `ms365__list-calendar-events` |
| 2 | **Work Queue** | Linear (my tickets + cycles + milestones) | `linear__list_issues`, `linear__list_cycles` |
| 3 | **Team Status** | Linear (team-wide: all assignees) | `linear__list_issues` (filter by updatedAt) |
| 4 | **Inbox** | Outlook email + Gmail + MS To Do flagged | `ms365__list-mail-folder-messages`, `gmail_search_messages`, `ms365__list-todo-tasks` |
| 5 | **Jeremy Research** | Neon | `psycopg` + `DATABASE_URL` |
| 6 | **Meetings** | Otter (full transcript) | `otter__search`, `otter__fetch` + load `references/otter-analysis.md` |
| 7 | **Messages** | Teams (auto-discover active chats) | `ms365__list-chats`, `ms365__list-chat-messages` |
| 8 | **Platform + Code** | Snowflake + GitHub + Quota | `snowflake__run_snowflake_query`, `gh` CLI, quota script |

## Per-Agent Prompt Templates

### Agent 1: Schedule

```
You are gathering calendar data for Timon's morning brief.
Period: {period_start} to {period_end}

Read the "Google Calendar" and "Outlook Calendar" sections from
references/source-queries.md for exact API calls.

Steps:
1. Call gcal_list_calendars to discover all calendars. Find Laura's calendar
   (search for "Laura" in calendar summary/name).
2. Fetch events from your primary Google Calendar for the period.
3. Fetch events from Laura's calendar for the same period.
4. Fetch Outlook calendar events for the period.
5. Call gcal_find_my_free_time for today to identify available blocks.

Return structured markdown:
- Merged timeline of all events (source noted parenthetically)
- Conflicts or double-bookings flagged
- Free blocks for today
- Laura's items woven naturally into the timeline, not segregated
- Mark items needing preparation or response with [ACTION]
```

### Agent 2: Work Queue

```
You are gathering Timon's Linear work queue for the morning brief.
Period: {period_start} to {period_end}

Read the "Linear — My Queue" section from references/source-queries.md
for exact API calls and field names.

Steps:
1. Fetch my issues: assignee "t.vanrensburg@ardevora.com", states
   "In Progress", "Todo", "Backlog"
2. Fetch current cycle for sprint progress
3. Note milestone deadlines if any are approaching

Return structured markdown:
- Issues sorted by priority (Urgent > High > Medium > Low)
- Flag overdue items with [ACTION]
- Include sprint completion percentage and cycle dates
- Milestone deadlines within 2 weeks
- Note anything that changed status in the period
```

### Agent 3: Team Status

```
You are gathering team-wide Linear activity for the morning brief.
Period: {period_start} to {period_end}

Read the "Linear — Team" section from references/source-queries.md
for exact API calls.

Steps:
1. Fetch all issues for team UUID 2d73c05d-4229-4298-9697-ee123d911d3b
   updated within the period
2. Group by assignee

Return structured markdown:
- Grouped by person (skip people with no activity in the period)
- Per person: what completed, what's in progress, what's overdue
- Cross-person dependencies or blockers
- Skip Timon's items (covered by Work Queue agent)
```

### Agent 4: Inbox

```
You are gathering email and to-do data for the morning brief.
Period: {period_start} to {period_end}

Read the "Outlook Email", "Gmail", and "MS To Do" sections from
references/source-queries.md for exact API calls and known limitations.

Steps:
1. Fetch Outlook inbox messages for the period (top 30, newest first)
2. Fetch Gmail messages: category:personal only, for the period
3. Fetch MS To Do "Flagged Emails" task list, then open tasks

IMPORTANT: Metadata only — subjects, senders, timestamps. Never fetch
email body content unless specifically asked.

Return structured markdown:
- Categorise each email: colleague, broker/research, automated/alerts
- Surface flagged emails and open to-do items as [ACTION]
- Note email volume and any patterns (burst from one sender, etc.)
- Gmail items noted separately (personal category only)
```

### Agent 5: Jeremy Research

```
You are analysing Jeremy's research activity for the morning brief.
Period: {period_start} to {period_end}

Read the "Neon" section from references/source-queries.md for exact
SQL queries, table names, and column references.

Query Neon via `psycopg` using `DATABASE_URL`. Do not use the retired Neon MCP.

Steps:
1. Query `chat_sessions_agent_v` for Jeremy's sessions in the period (column: `started_at`,
   not `created_at`). Get `user_prompt_count`, `tool_call_count`, `active_duration_minutes`,
   sidechain_count, cwd, git_branch.
2. Extract tickers from cwd using regex pattern.
3. Query `chat_user_prompts_agent_v` for what Jeremy actually typed (`prompt_text`).
4. Query `chat_tool_calls_agent_v` for tool patterns (`called_tool_name`, `normalised_tool_file_path`, `artifact_ticker_region`), joining back to `chat_sessions_agent_v` on `source_id` + `session_id` if session context is needed.

Return structured markdown:
- Session count and total active duration
- Tickers researched (extracted from cwd paths)
- Session intensity assessment: active_duration + sidechain_count indicates
  depth. High sidechains often mean heavy retrying or complex analysis.
- What's working vs what looks like it's struggling
- Key research themes from prompt content
- Make judgements: "B-SYS stage 3 had 280 sidechains — likely heavy retrying"
  is better than "Jeremy had some sessions"
```

### Agent 6: Meetings

```
You are analysing meeting transcripts for the morning brief.
Period: {period_start} to {period_end}

Read the "Otter" section from references/source-queries.md for API calls.
Then load references/otter-analysis.md for the full transcript analysis prompt.

Steps:
1. Search Otter for meetings in the period (created_after/created_before)
2. For the top 2 most recent meetings, fetch full transcripts using
   otter__fetch with the speech_id
3. Apply the analysis framework from references/otter-analysis.md to
   each transcript

Return structured markdown per meeting:
- Meeting title, date, participants
- Full analysis per otter-analysis.md framework (decisions, open items,
  friction, vibe, action items, key quotes)
- Mark action items assigned to Timon with [ACTION]

Full candour on interpersonal dynamics. Don't just list — assess.
```

### Agent 7: Messages

```
You are gathering Teams chat activity for the morning brief.
Period: {period_start} to {period_end}

Read the "Teams" section from references/source-queries.md for API calls
and known limitations.

Steps:
1. List all chats (top 50) — no hardcoded chat IDs
2. Filter client-side: keep chats where lastUpdatedDateTime >= period_start
3. For the top 10 most recently updated chats, fetch messages (top 15 each,
   newest first)

IMPORTANT: No $select on messages, no $orderby on chat list (API limitations).

Return structured markdown:
- Active threads grouped by chat/topic
- Decisions made in chat
- Open questions needing response marked with [ACTION]
- Items that surfaced but weren't resolved
```

### Agent 8: Platform + Code

```
You are gathering platform health and code activity for the morning brief.
Period: {period_start} to {period_end}

Read the "Snowflake", "GitHub", and "Quota" sections from
references/source-queries.md for exact queries and commands.

Steps:
1. Snowflake: query task history, SCREEN_WEEKLY freshness, credit usage
2. GitHub: open PRs, recently merged PRs, CI status (latest 5 runs)
3. Quota: run the diagnostics script and parse output

Return structured markdown with traffic-light status:
- Green items: one line each (e.g., "All 12 tasks passed, SCREEN_WEEKLY
  fresh as of Sunday")
- Problems: expanded detail with what failed and impact
- Open PRs with review status
- Recently merged PRs (in the period)
- CI pass/fail for recent runs
- Quota utilisation summary
- Credit spend vs typical average if data available
```

## Resilience

- **Best-effort:** If an agent fails (MCP timeout, auth error), note it in the brief footer and continue with the others. Never fail the whole brief because one source is down.
- **Single retry:** Each agent gets one retry on transient failure before being marked failed.
- **Degraded output:** A brief with 5/8 agents is still valuable. Present what you have, list what's missing.
- **Failed sources:** Note at the bottom of the brief: "Sources unavailable: [list with error summary]"

## State Management

**Directory:** `workspaces/timon/.local/morning-brief/`

**Files:**
- `brief-YYYY-MM-DD.md` — rendered brief (keep last 5, delete older on each run)
- `last-run.json` — run metadata:
  ```json
  {
    "period_start": "2026-03-02T08:00:00Z",
    "period_end": "2026-03-03T08:00:00Z",
    "ran_at": "2026-03-03T08:15:00Z",
    "sources": {
      "schedule": "ok",
      "work_queue": "ok",
      "team_status": "ok",
      "inbox": "ok",
      "jeremy_research": "failed",
      "meetings": "ok",
      "messages": "ok",
      "platform": "ok"
    }
  }
  ```

**First run:** Works without prior state. Creates directory, defaults to 24h lookback.

## Critical Constraints

Repeated here for attention — these are non-negotiable:

1. **Sub-agents REQUIRED** — do not gather evidence in main context
2. **Best-effort resilience** — one failure never blocks the brief
3. **No hardcoded chat IDs** for Teams — always discover dynamically
4. **Always query Neon via `psycopg` using `DATABASE_URL`** for research-session lookups
5. **Metadata-first for email** — never fetch body content unless explicitly asked
6. **British spelling throughout** the output
7. **Laura's calendar** discovered dynamically from `gcal_list_calendars`, not hardcoded
8. **Neon session time column is `started_at`** not `created_at`

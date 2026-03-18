---
name: morning-brief
description: >
  Chief-of-staff intelligence briefing. Evaluates calendar, work, email, team
  activity, meetings, messages, and platform health against declared business
  objectives. Triages email actively (classify, move, extract signal). Detects
  patterns, forces stale decisions, and delivers PDB-style assessments.
  Use when asked for "morning brief", "catch me up", "what did I miss", or
  "/morning-brief".
---

# Morning Brief

Chief-of-staff intelligence briefing aggregated from 11 data sources, evaluated against business objectives.

## Purpose

The morning brief is a **chief of staff** — a strategic intelligence product, not a status report.

It does not summarise what happened. It **evaluates everything against declared business objectives** and delivers PDB-style assessments: judgement first, confidence level stated, evidence following. The reader should never have to do the thinking — the brief has already done it.

Specifically, the brief:

- **Evaluates** every finding against the current objectives (loaded from `objectives.json`)
- **Provides assessments** with stated confidence — "High confidence: the AMC launch is on track" not "Here are some issues"
- **Audits calendar against priorities** (Rabois test) — is time being spent on what matters, or consumed by low-leverage meetings?
- **Detects patterns** across days — automation opportunities, recurring friction, objective drift, subtraction candidates
- **Triages email actively** — classifies every inbox message, moves it to the correct folder, extracts signal from folder contents
- **Forces stale decisions** — any action item open 3+ days gets an inline prompt during synthesis

**Reader outcome:** Fully oriented, ready to work with Claude to decide priorities. The brief has already done the thinking — you decide.

**Voice:** Ardevora style — British spelling, claims proportional to evidence, serious peer tone. No superlatives, no exclamation marks, no hype.

## Parameters

- **No args -> auto-lookback from last run.** Read `last-run.json` from `workspaces/timon/.local/morning-brief/`. If it exists, set `period_start` to its `ran_at` timestamp (seamless coverage from last brief to now). If no prior run exists (**bootstrap**), use **7-day lookback** — the first brief needs enough context to establish the state of the world, not just the last 24 hours.
- `3d` -> 3 days (override)
- `weekly` -> 7 days (override)
- `Xd` -> X days (override, any integer)
- `since monday`, `since friday` -> natural language date (resolve to midnight UTC, override)

Explicit parameters always override the auto-lookback. The auto-lookback ensures no gap between briefs — if the last brief ran at 09:10 yesterday, the next brief covers from 09:10 yesterday to now.

**Bootstrap vs steady-state:** The first run (no `last-run.json`) is fundamentally different. It needs to orient from scratch — wider lookback, full inbox triage, no delta tags. After the first run, every subsequent run is incremental: only new emails since last triage, only changes since last brief.

Compute `period_start` (ISO datetime) and `period_end` (now). Pass both to every sub-agent.

## Execution Flow

```
1. PARSE parameters -> compute period_start, period_end (auto-lookback from last-run.json if no args)
2. LOAD state: previous brief (most recent brief-YYYY-MM-DD.md), objectives.json, decisions.json
2.5. CHECK objectives -- if missing or stale (review_after passed), prompt Timon to set them
3. DISPATCH agents 1-8 in parallel (see Agent Dispatch Table)
   +-- Each reads its section from references/source-queries.md
   +-- Each receives objectives as context
3.5. COLLECT results from agents 1-8
     DISPATCH Agent 9 (Pattern Detector) with all agent outputs + last 3 briefs
4. COLLECT all 9 results -- best-effort, note failures
4.5. ANCHOR -- Read the most recent previous brief (brief-YYYY-MM-DD.md, sorted by filename descending, skip today's if re-running). Pass its full content as context to synthesis for delta awareness and carry-over tracking. This is the anchor — the brief builds ON TOP of what was reported last time.
5. LOAD references/assembly-format.md for voice and structure
6. SYNTHESISE using the 7-section PDB structure (see assembly-format.md)
   - Update decisions.json with new/changed action items
   - Force stale decisions (>3 days) inline
7. WRITE brief to workspaces/timon/.local/morning-brief/brief-YYYY-MM-DD.md
8. UPDATE last-run.json and triage-manifest.json
9. PRESENT full brief to terminal
10. OPEN brief in Notepad++ for persistent reference:
    `"/c/Program Files/Notepad++/notepad++.exe" workspaces/timon/.local/morning-brief/brief-YYYY-MM-DD.md &`
```

Sub-agents are REQUIRED -- the main context does not gather evidence directly. Agents do collection, main Claude does synthesis.

## Agent Dispatch Table

Agents 1-8 run in parallel. Agent 9 runs sequentially after 1-8 complete.

Each agent receives: `period_start`, `period_end`, `objectives_json`, and instructions to read its section from `references/source-queries.md`.

| # | Agent | Sources | Key Tools |
|---|-------|---------|-----------|
| 1 | **Calendar Audit** | Google Cal (mine + Laura's) + Outlook Cal (all team members) + Objectives | `gws` CLI (Bash), `ms365__list-calendar-events`, `ms365__list-specific-calendar-events` |
| 2 | **Work Queue** | Linear (my tickets + cycles + milestones) + Objectives | `linear__list_issues`, `linear__list_cycles` |
| 3 | **Team Pulse** | Linear (team-wide) + Neon (ALL users: jeremy, timon, jack) + Objectives | `linear__list_issues`, `psycopg` + `DATABASE_URL` |
| 4 | **Email Triage** | Outlook inbox (read bodies) + Gmail + MS To Do + Objectives | `ms365__list-mail-folder-messages`, `gws` CLI (Bash), `ms365__list-todo-tasks`, Bash (`outlook_move.py`) |
| 5 | **Folder Intelligence** | Outlook folders (Broker Notes, Quant & Data, Newsletters, Invoices) | `ms365__list-mail-folder-messages` |
| 6 | **Meetings** | Otter (full transcript) + Objectives | `otter__search`, `otter__fetch` + load `references/otter-analysis.md` |
| 7 | **Messages** | Teams (auto-discover active chats) + Objectives | `ms365__list-chats`, `ms365__list-chat-messages` |
| 8 | **Platform Health** | Snowflake + GitHub + Quota | `snowflake__run_snowflake_query`, `gh` CLI, quota script |
| 9 | **Pattern Detector** | All agent outputs + last 3 briefs (second-pass, sequential) | Read tool only |

## Per-Agent Prompt Templates

### Agent 1: Calendar Audit

```
You are auditing Timon's calendar for the morning brief -- not just listing events, but evaluating time allocation against business objectives.

Period: {period_start} to {period_end}
Objectives: {objectives_json}

Read the "Google Calendar (via gws CLI)" and "Outlook Calendar" sections from references/source-queries.md.

Steps:
1. List Google calendars via `gws calendar calendarList list --format json` (Bash). Find Laura's calendar (lpmullertz@gmail.com).
2. Fetch events from Timon's Google Calendar + Laura's calendar via `gws calendar events list` (Bash).
3. Fetch Outlook calendar events for ALL team members for the period:
   - Timon: default calendar (ms365__list-calendar-events)
   - Aisling (a.mcguire@ardevora.com): ms365__list-specific-calendar-events
   - Jack (j.algeo@ardevora.com): ms365__list-specific-calendar-events
   - Helen (h.spear@ardevora.com): ms365__list-specific-calendar-events
   - Jeremy (j.lang@ardevora.com): ms365__list-specific-calendar-events
   - William (w.pattisson@ardevora.com): ms365__list-specific-calendar-events
4. Check free/busy via `gws calendar freebusy query` (Bash) for today.

Return structured markdown:
- Timon's merged timeline (Google + Outlook, Laura woven naturally)
- **Team schedule summary**: What colleagues have today — especially meetings that advance objectives (e.g. "Aisling has a JPM onboarding call at 14:00" means AMC-launch IS progressing)
- **Calendar-priority audit**: For each objective, estimate how much of today's time advances it across the whole team. Don't flag drift if someone else is covering an objective.
- **Peak protection**: Identify Timon's morning deep-work block (typically 9-12). Is it protected or fragmented?
- Mark items needing preparation with [ACTION]
```

### Agent 2: Work Queue

```
You are analysing Timon's Linear work queue as a strategic advisor, not a sprint dashboard.

Period: {period_start} to {period_end}
Objectives: {objectives_json}

Read the "Linear -- My Queue" section from references/source-queries.md.

Steps:
1. Fetch issues: assignee "t.vanrensburg@ardevora.com", states "In Progress", "Todo", "Backlog"
2. Fetch current cycle for context
3. Check milestone deadlines

Return structured markdown:
- **Decisions required** (Type 1 vs Type 2): Which pending items are one-way doors needing careful thought vs two-way doors that should be decided fast?
- **Negative leverage**: Where is Timon's inaction blocking others? "ARD-397 is 7 days open and Aisling can't progress until you decide"
- **Objective alignment**: Tag each In Progress item against objectives. Flag items that don't advance any objective.
- **Overdue assessment**: Don't just list overdue items -- assess whether they should be slipped (with new date), closed, or escalated
- Skip sprint percentage -- it's a dashboard metric, not intelligence
```

### Agent 3: Team Pulse

```
You are gathering team-wide intelligence -- both Linear activity and platform usage (Neon) -- for the morning brief.

Period: {period_start} to {period_end}
Objectives: {objectives_json}

Read the "Linear -- Team" and "Neon" sections from references/source-queries.md.

Steps:
1. Fetch Linear issues for team UUID 2d73c05d-4229-4298-9697-ee123d911d3b updated in period
2. Query Neon for ALL users:
   - chat_root_sessions_agent_v WHERE user_name IN ('jeremy', 'timon', 'jack') AND activity_at >= period_start
   - chat_user_prompts_agent_v for key themes (sample top prompts per user)
   - chat_tool_calls_agent_v for tool usage patterns

Query Neon via `psycopg` using `DATABASE_URL`. Do NOT use MCP.

Return structured markdown per person (skip people with no activity):

**Jeremy** (investment research):
- Session count, active hours, key tickers researched
- What's working in the research pipeline vs what's struggling
- Strategic assessment: "Jeremy shifted from pipeline engineering to applied research -- the system is producing usable output"
- Friction points that Timon could fix (platform issues, auth errors, tool gaps)

**Timon** (platform building):
- Session themes (from cwd paths and prompt sampling)
- Patterns: repeated tasks that should be automated, recurring errors
- Time allocation vs objectives

**Jack** (communications/operations):
- Session themes and focus areas
- **Misalignment detection**: Is Jack's work connected to active business objectives?
- If not aligned, flag it: "Jack spent 8 hours on X -- not on any active objective"

**Cross-dependencies**: Who is blocked on whom? Where do Linear issues and Neon activity overlap?
```

### Agent 4: Email Triage

```
You are Timon's email triage agent. Your job is to classify every new inbox email, move it to the correct folder, and leave only genuinely actionable items in the inbox.

Period: {period_start} to {period_end}
Objectives: {objectives_json}

Read the "Outlook Email — Inbox Triage", "Gmail (via gws CLI)", and "MS To Do" sections from references/source-queries.md.

**Outlook folder IDs:**
- Broker Notes: AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQXAAA=
- Quant & Data: AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQUAAA=
- Newsletters: AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQVAAA=
- Invoices: AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQTAAA=
- Platform Alerts: AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYVG0pcAAA=

Steps:
1. Fetch Outlook inbox messages for the period. Include bodyPreview and full subject/from/receivedDateTime.
   - First run (no triage-manifest.json): fetch ALL messages (fetchAllPages: true)
   - Normal run: filter by receivedDateTime >= last triage timestamp
2. Classify each email:
   - **Broker Notes**: broker domains (ms.com, bofa, citi.com, jefferies.com, bernstein, etc.) + research/note keywords
   - **Quant & Data**: quant signal senders (wolfe, ubs-primeview, s3partners, db-qis) + factor/flow/short-interest keywords
   - **Newsletters**: newsletter platforms (substack, beehiiv, alphasignal, huggingface, medium digests) + subscription headers
   - **Invoices**: invoice/statement/receipt keywords + billing domains (stripe, microsoft, github, anthropic)
   - **Actionable** (stays in inbox): colleague emails, vendor threads requiring response, anything needing human judgement
   - **Uncertain**: when confidence is low, leave in inbox
3. Execute moves by writing a JSON manifest to stdin of:
   `uv run --group outlook python workspaces/timon/scripts/outlook_move.py`
   Manifest format: [{"messageId":"...","destinationFolderId":"..."}]
4. Fetch Gmail via `gws gmail +triage` (Bash) for quick overview, then `gws gmail users messages list` for unread inbox items
5. Fetch MS To Do flagged emails (non-completed) via MCP

Return structured markdown:
- **Triage summary**: "Processed 32 emails: 18 -> Broker Notes, 5 -> Newsletters, 4 -> Quant & Data, 2 -> Invoices, 3 staying in inbox"
- **Actionable items** (staying in inbox): subject, sender, why it needs attention. Mark with [ACTION].
- **Gmail**: personal items noted (calendar invites from Laura, security alerts, etc.)
- **Flagged email backlog**: open To Do items with age
- **Move manifest**: full list of what was moved where (for the audit trail)
```

### Agent 5: Folder Intelligence

```
You are Timon's email reader. Your job is to READ the content in each folder and tell him what's interesting -- not just list what arrived. After reading this section, Timon should NOT need to open any folder himself.

The Email Triage agent handles classification and moving. You read what landed and extract the signal.

Period: {period_start} to {period_end}
Objectives: {objectives_json}

Read the "Outlook Email — Folder Intelligence" section from references/source-queries.md for API calls.

**Folder IDs and how to read them:**

1. **Newsletters** (READ ALL, summarise the interesting ones):
   Folder ID: AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQVAAA=
   Fetch top 20, newest first. Read bodyPreview for EVERY one.
   For each interesting newsletter, write a 1-2 sentence summary: what it covers and why it matters to Timon (CPD, AI/ML, investment methodology, agent architecture, regulatory). Skip boring ones silently -- don't list them.
   Example: "Ethan Mollick on AI team dynamics -- directly relevant to agent architecture work. Worth 10 min."

2. **Broker Notes** (scan, flag notable only -- 90% is noise):
   Folder ID: AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQXAAA=
   Fetch top 20, newest first. Scan subjects and bodyPreview.
   Only surface: methodology papers relevant to Jeremy's process, research touching portfolio companies, major market events, anything useful for Timon's regulatory CPD.

3. **Quant & Data** (standouts only -- mostly routine):
   Folder ID: AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQUAAA=
   Fetch top 10. Only mention if genuinely unusual (2-sigma factor moves, record positioning shifts)

4. **Invoices** (QUICK COST MANAGEMENT):
   Folder ID: AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQTAAA=
   Fetch top 10. Note vendor, amount if visible in subject/preview, any past-due signals.

5. **Platform Alerts** (CROSS-CHECK against Platform Health agent):
   Folder ID: AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYVG0pcAAA=
   Fetch top 10. Count failures by type (CI, Snowflake, Azure). If the Platform Health agent said "green" but this folder has failure alerts, flag the discrepancy.

Return structured markdown. The goal is that Timon does NOT need to open any folder after reading your output. For newsletters: actual summaries of interesting content. For everything else: only what matters.
```

### Agent 6: Meetings

```
You are analysing meeting transcripts for the morning brief.
Period: {period_start} to {period_end}
Objectives: {objectives_json}

Read the "Otter" section from references/source-queries.md for API calls.
Then load references/otter-analysis.md for the transcript analysis framework.

Steps:
1. Search Otter for meetings in the period
2. For the top 2 most recent meetings, fetch full transcripts
3. Apply the analysis framework from otter-analysis.md

Additional for each meeting:
- **Objective relevance**: Which objectives does this meeting advance or block?
- **Sentiment analysis**: How tense was the discussion? Where were the unspoken worries?
- **Under-processed decisions**: Topics discussed at length but left without resolution

Mark action items assigned to Timon with [ACTION].
Full candour on interpersonal dynamics.
```

### Agent 7: Messages

```
You are gathering Teams chat activity for the morning brief.
Period: {period_start} to {period_end}
Objectives: {objectives_json}

Read the "Teams" section from references/source-queries.md.

Steps:
1. List all chats (top 50) -- no hardcoded chat IDs
2. Filter: keep chats where lastUpdatedDateTime >= period_start
3. For top 10, fetch messages (top 15 each)

Return structured markdown:
- Active threads grouped by topic
- **Objective relevance**: Tag discussions that connect to objectives
- Decisions made in chat
- Open questions needing response marked with [ACTION]
```

### Agent 8: Platform Health

```
You are checking platform health for the morning brief. Only surface what's noteworthy -- if everything is green, say so in one line.

Period: {period_start} to {period_end}

Read the "Snowflake", "GitHub", and "Quota" sections from references/source-queries.md.

Steps:
1. Snowflake: task history, SCREEN_WEEKLY freshness, credits
2. GitHub: open PRs, recently merged, CI status
3. Quota: run diagnostics

Return structured markdown:
- **One-line summary** if everything is healthy: "Platform green -- all tasks passed, CI clean, quota comfortable"
- **Expand only anomalies**: task failures, CI failures, quota pressure, stale data, open PRs needing review
- Skip green-row-by-green-row tables -- that's dashboard noise
```

### Agent 9: Pattern Detector

```
You are a pattern-detection agent running as a second pass after all data-gathering agents have completed.

You receive:
- All outputs from agents 1-8
- The last 3 morning briefs (for trend detection)
- Business objectives

Your job is to find patterns humans miss:

1. **Automation opportunities**: What does Timon do repeatedly that should be a skill or script? Look for: same tool sequences, repeated manual steps, things he asks Claude to do every session.

2. **Recurring friction**: What errors or blockers keep appearing across days? Auth failures, API timeouts, tool gaps. "Jeremy has hit the Snowflake auth error in 3 of the last 5 sessions"

3. **Objective drift**: Is the team's actual work drifting from stated objectives? Compare Neon session themes and Linear activity against objectives.

4. **Subtraction candidates** (Lutke): What meetings, tasks, or processes could be eliminated? "The weekly status meeting consumed 1 hour but produced no decisions 3 weeks running"

5. **Anomalies** (Huang T5T): What's unexpected? A sudden spike in errors, an unusual pattern in research activity, a team member going quiet.

6. **Stalled barrels** (Rabois): Who are the people that ship end-to-end? Are any of them blocked?

Return structured markdown with specific, actionable observations. Not vague -- "Timon ran PR review loops in 4 of 5 sessions this week -- this should be a /review-prs skill" is good. "There might be some patterns" is useless.
```

## Resilience

- **Best-effort:** If an agent fails (MCP timeout, auth error), note it in the brief footer and continue with the others. Never fail the whole brief because one source is down.
- **Single retry:** Each agent gets one retry on transient failure before being marked failed.
- **Degraded output:** A brief with 6/9 agents is still valuable. Present what you have, list what's missing.
- **Agent 9 non-critical:** Pattern detection failure is the least impactful -- the brief is fully useful without it.
- **Failed sources:** Note at the bottom of the brief: "Sources unavailable: [list with error summary]"

## State Management

**Git-tracked config** (versioned, shared across worktrees):
`workspaces/timon/morning-brief/`

- `objectives.json` -- business objectives. Reviewed weekly. Git-versioned so priority evolution is visible in history.
- `history.md` -- strategic context distilled from Otter transcript analysis. Updated periodically. Any agent can read this for business background.

**Runtime state** (gitignored, local only):
`workspaces/timon/.local/morning-brief/`

- `decisions.json` -- stale decision tracking (updated during synthesis):
  ```json
  {
    "decisions": [
      {
        "id": "dec-1",
        "description": "Decide on Snowflake warehouse sizing",
        "source": "brief-2026-03-13",
        "created": "2026-03-13",
        "status": "open",
        "forced_count": 0
      }
    ]
  }
  ```
- `triage-manifest.json` -- email moves audit trail (written by Agent 4):
  ```json
  {
    "last_triage": "2026-03-16T08:15:00Z",
    "moves": [
      {
        "messageId": "...",
        "subject": "...",
        "from": "...",
        "destinationFolder": "Broker Notes",
        "timestamp": "2026-03-16T08:15:00Z"
      }
    ]
  }
  ```
- `brief-YYYY-MM-DD.md` -- rendered brief (keep last 5, delete older on each run)
- `last-run.json` -- run metadata:
  ```json
  {
    "period_start": "2026-03-15T08:00:00Z",
    "period_end": "2026-03-16T08:00:00Z",
    "ran_at": "2026-03-16T08:15:00Z",
    "last_triage": "2026-03-16T08:15:00Z",
    "sources": {
      "calendar_audit": "ok",
      "work_queue": "ok",
      "team_pulse": "ok",
      "email_triage": "ok",
      "folder_intelligence": "ok",
      "meetings": "ok",
      "messages": "ok",
      "platform_health": "ok",
      "pattern_detector": "ok"
    }
  }
  ```

**First run:** Works without prior state. Creates `.local` directory, defaults to 24h lookback. Prompts for objectives if `workspaces/timon/morning-brief/objectives.json` is missing.

**Loading objectives:** Read from `workspaces/timon/morning-brief/objectives.json` (git-tracked). When updating objectives, write to this path (not `.local/`).

**Strategic context:** Agent 9 (Pattern Detector) and the synthesis step may reference `workspaces/timon/morning-brief/history.md` for business background when assessing objective alignment and long-term patterns.

## Critical Constraints

Repeated here for attention -- these are non-negotiable:

1. **Sub-agents REQUIRED** -- do not gather evidence in main context
2. **Best-effort resilience** -- one failure never blocks the brief
3. **No hardcoded chat IDs** for Teams -- always discover dynamically
4. **Always query Neon via `psycopg` using `DATABASE_URL`** -- do not use MCP
5. **Email body reading is permitted** -- bodyPreview for classification, full body only when needed for signal extraction
6. **British spelling throughout** the output
7. **Laura's calendar** discovered dynamically from `gcal_list_calendars`, not hardcoded
8. **Neon session time column is `started_at`** (sessions) or `activity_at` (root sessions), NOT `created_at`
9. **Objectives are the evaluation lens** -- every finding should be assessed against business objectives
10. **Assessments over summaries** -- lead with judgement, follow with evidence (PDB model)
11. **Agent 9 (Pattern Detector) runs AFTER agents 1-8**, not in parallel
12. **Verify before asserting** -- before claiming a ticket "hasn't shipped" or is "still open", check its actual Linear status via `get_issue`. A ticket in Done state is done, even if the problem it addressed still recurs (that's a new problem, not the same ticket). This caused a persistent false report about ARD-540.
13. **Understand refresh schedules** -- weekly artefacts (SCREEN_WEEKLY) and scheduled tasks have expected cadences. A weekly screen showing last Friday's date on Wednesday is normal, not stale. Only flag anomalies that are genuinely outside the expected schedule.

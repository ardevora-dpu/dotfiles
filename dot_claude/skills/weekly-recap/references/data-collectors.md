# Data Collectors

Technical reference for accessing each data source. For philosophy and approach, see the Evidence Gathering section in SKILL.md.

## Sub-Agent Guidance

You are gathering evidence for a recap that helps the team understand what happened, why it matters, and where we're heading. Your job is not to fill in templates - it's to ensure nothing valuable gets lost.

**Your approach:**
1. **One-shot comprehensively** - Try to capture everything important in your first pass
2. **Use your intelligence** - Extract, infer, connect (within this source), and analyse
3. **Structure how you like** - Pick the format that best serves what you found
4. **List everything else** - Bullet points for items that might be relevant (main Claude will triage with user)
5. **Note striking observations** - Meta-learnings about the source itself, if genuinely insightful

**You have context:**
- The previous recap (what's changed since then?)
- The current direction (what are we moving towards?)
- Use these to frame your analysis

**Success criteria:**
- Reading the source directly reveals nothing you missed
- Your evidence surfaces actionable insights
- Reading it gives confidence about what happened

---

## Technical Reference

## Pre-Flight Check (Teams + Emails)

Run this BEFORE main evidence gathering, during SCOPE. Surfaces potentially relevant items for user to include/exclude.

### Teams Chats

Check for recent Teams conversations that might contain relevant discussions.

```
Tool: mcp__ms365__list-chats
Parameters:
  top: 50
  orderby: ["lastUpdatedDateTime desc"]
```

**Output for user:** List of chat titles/participants with last update date. User picks which to include.

**Do NOT fetch message content during pre-flight.** Only fetch messages for approved chats during COLLECT phase.

### Internal Emails

Check Inbox for internal emails (non-transcript, non-automated).

```
Tool: mcp__ms365__list-mail-folder-messages
Parameters:
  mailFolderId: "Inbox"
  filter: "receivedDateTime ge {start_date} and from/emailAddress/address ne 'noreply@otter.ai'"
  select: ["id", "subject", "from", "receivedDateTime"]
  top: 50
  orderby: ["receivedDateTime desc"]
```

**Filtering:**
- Exclude Otter notification emails (transcripts come from Otter MCP directly)
- Exclude automated notifications (Linear, GitHub, etc.)
- Focus on internal (@ardevora.com) and investor correspondence

**Output for user:** List of email subjects grouped by sender. User picks which to include.

### Privacy

- Pre-flight shows **metadata only** (titles, subjects, dates)
- User explicitly selects what to include
- Full content only fetched for approved items
- See `references/email-privacy.md` for handling rules

---

## Communications Agent (Teams + Emails)

**Only runs if user selected items during SCOPE pre-flight.**

This agent receives the list of selected chat IDs and email IDs from main Claude.

### Fetching Selected Teams Chats

For each selected chat:

```
Tool: mcp__ms365__list-chat-messages
Parameters:
  chatId: "{selected_chat_id}"
  top: 50
  orderby: ["createdDateTime desc"]
```

### Fetching Selected Emails

For each selected email:

```
Tool: mcp__ms365__get-mail-message
Parameters:
  messageId: "{selected_email_id}"
  select: ["subject", "body", "from", "receivedDateTime"]
```

### Output: comms-summary.md

Structure the evidence around key discussions and decisions:
- What was discussed and why it matters
- Any decisions or commitments made
- Follow-up items or unresolved questions
- Cross-reference to other sources if relevant (e.g., "relates to ARD-123")

**Do NOT copy raw message content.** Summarise and extract insights.

---

## Linear

### Query Pattern

```
Tool: mcp__linear__list_issues
Parameters:
  team: "Ardevora DPU"
  updatedAt: "{start_date}"  # ISO-8601 date (e.g., "2026-01-20") or duration (e.g., "-P7D")
```

**Note:** The `updatedAt` parameter accepts:
- ISO-8601 date string: `"2026-01-20"` (issues updated on/after this date)
- ISO-8601 duration: `"-P7D"` (issues updated in last 7 days), `"-P1D"` (last day)

### Data Extracted

| Field | Usage |
|-------|-------|
| `id` | Unique identifier |
| `identifier` | Human-readable ID (ARD-123) |
| `title` | Issue title |
| `state` | Current status |
| `labels` | Workstream attribution |
| `assignee` | Secondary attribution |
| `completedAt` | When marked done |
| `description` | Context (truncated) |

### Grouping

**Group by what happened, not by status.** The goal is narrative, not a status report.

Instead of status buckets, consider:
- What got done this period (and why it matters)
- What's blocked and why (not just "has blocked label")
- What shifted priority (moved up, deprioritised, scope changed)
- What's newly created vs carried over

Use state/labels as filters to find relevant issues, but structure the evidence around the story of what happened.

### Rate Limits

Linear MCP has no strict rate limits for reads, but batch requests sensibly:
- Max 50 issues per request
- Paginate if more results expected

---

## Git

### Commands

```bash
# Commits in date range
git log --since="{start_date}" --until="{end_date}" \
    --pretty=format:"%H|%h|%an|%ae|%s|%ad" --date=short

# Summary by author
git shortlog --since="{start_date}" --until="{end_date}" -sn

# PRs merged (by commit message pattern)
git log --since="{start_date}" --grep="Merge pull request" --oneline
```

### Data Extracted

| Field | Source | Usage |
|-------|--------|-------|
| `hash` | %H | Full commit SHA |
| `short_hash` | %h | Display ID |
| `author_name` | %an | Display name |
| `author_email` | %ae | Workstream attribution |
| `subject` | %s | Commit message |
| `date` | %ad | Grouping |

### Issue Reference Extraction

Parse commit subjects for Linear references:

```python
import re
ISSUE_PATTERN = re.compile(r'ARD-(\d+)', re.IGNORECASE)

def extract_issue_refs(subject: str) -> list[str]:
    return ISSUE_PATTERN.findall(subject)
```

### Filtering

- Exclude merge commits (optional): `--no-merges`
- Limit to main branch: add `main` or `origin/main`
- Include all branches: omit branch specifier

---

## Jeremy's Research (Combined Sources)

Jeremy's research activity is captured across three sources that should be combined for a complete picture.

### Source 1: Neon Sessions (Chat Logs)

Claude Code sessions synced to Neon via the Jeremy harness. Query Neon directly - do not use local session files.

```
Tool: mcp__neon__run_sql
Parameters:
  projectId: "shy-wildflower-46673345"
  sql: |
    SELECT session_id, started_at::date, message_count,
           sidechain_count, branch_count,
           LEFT(session_summary, 100) as summary
    FROM search_sessions_agent_v
    WHERE started_at >= '{start_date}'
    ORDER BY started_at DESC
```

**Available Tables:**

| Table | Purpose |
|-------|---------|
| `search_sessions_agent_v` | Agent-safe main-session metadata + workflow rollups (`git_branch`, `session_summary`, `branch_count`, `sidechain_count`, `active_duration_minutes`) |
| `search_messages_agent_v` | Agent-safe full message stream for main sessions (`record_type`, `content_text`, `message_class`) |
| `search_user_prompts_agent_v` | Agent-safe likely human prompts (`content_text`, `message_class`, `user_intent_fts`) |
| `search_sessions` | Raw sessions (includes subagents and summary-only rows) |
| `search_messages` | Raw message stream (includes tool_result payloads in `record_type='user'`) |
| `search_tool_usage` | Tool calls made in sessions (`tool_name`, `tool_input`, `tool_use_id`, `sql_query`) |

**Workflow Metadata (use these for deeper analysis):**

| Column | Meaning |
|--------|---------|
| `is_sidechain` | TRUE = abandoned approach (what Jeremy tried but didn't keep) |
| `sidechain_count` | Sessions with high counts = lots of iteration/exploration |
| `branch_count` | Regeneration points (Claude retried a response) |
| `session_summary` | Auto-generated summary for quick understanding |
| `active_duration_minutes` | Gap-capped active time estimate for session effort |
| `thinking_config` | Extended thinking usage |
| `tool_use_id` | Links tool results to calls (join `search_messages` ↔ `search_tool_usage`) |

**Sample deep-dive query:**

```sql
SELECT LEFT(content_text, 500) as preview, record_type, is_sidechain
FROM search_messages_agent_v
WHERE session_id = '{session_id}'
ORDER BY timestamp
LIMIT 20
```

**Find sessions with heavy exploration (for recap insights):**

```sql
SELECT session_id, sidechain_count, session_summary
FROM search_sessions_agent_v
WHERE started_at >= '{start_date}'
  AND sidechain_count > 5
ORDER BY sidechain_count DESC
```

**Find sessions by topic (full-text search on user prompts):**

```sql
SELECT s.session_id, s.started_at, s.git_branch,
       LEFT(m.content_text, 150) as prompt_preview,
       ts_rank(m.user_intent_fts, websearch_to_tsquery('english', 'valuation analyst')) as relevance
FROM search_user_prompts_agent_v m
JOIN search_sessions_agent_v s ON m.session_id = s.session_id
WHERE m.user_intent_fts @@ websearch_to_tsquery('english', 'valuation analyst')
  AND s.started_at >= '{start_date}'
ORDER BY relevance DESC, m.timestamp DESC
LIMIT 10;
```

### Source 2: Evidence Folder (Persisted Research)

Jeremy persists research artifacts to his workspace. This is where OICs, peer analysis, and regime evidence live.

**Location:** `workspaces/jeremy/evidence/**/*.md`

**Structure:**
```
workspaces/jeremy/evidence/
├── {review_period}/           # e.g., jan2026_review
│   └── {Sector}/
│       └── {Theme}/
│           └── {TICKER}/
│               ├── oic_development/
│               │   └── YYYY-MM-DD_*.md
│               ├── peer_analysis/
│               └── CG-P_charts/
```

**Discovery:**

```bash
# Find all evidence files in date range
find workspaces/jeremy/evidence -name "2026-01-*.md" -o -name "2026-02-*.md"

# Or use Glob tool
Glob pattern: workspaces/jeremy/evidence/**/2026-0{1,2}-*.md
```

**Key file patterns:**
- `*_oic.md`, `*_oic_v*.md` — OIC development drafts
- `*_oic-assessment.md` — Final OIC assessment
- `*_oic-rejection.md` — Rejected cases (with reasoning)
- `*_peer-correlation*.md` — Peer group analysis
- `*_alphasense_*.md` — AlphaSense research findings

### Source 3: Jeremy's Branch (Work in Progress)

Jeremy works on a dedicated branch. Check for uncommitted or recently pushed work.

**Branch discovery (dynamic):**

1. First, check Neon for his most recent active branch:
```sql
SELECT DISTINCT git_branch
FROM search_sessions_agent_v
WHERE started_at >= '{start_date}' AND git_branch LIKE 'jeremy/%'
ORDER BY started_at DESC LIMIT 1
```

2. Fall back to git if Neon doesn't have it:
```bash
# List all jeremy branches, sorted by last commit
git branch -r | grep jeremy/ | while read branch; do
  echo "$(git log -1 --format='%ci' $branch) $branch"
done | sort -r | head -1
```

**Recent activity on discovered branch:**

```bash
git log origin/{jeremy_branch} --since="{start_date}" --oneline
```

**Files changed:**

```bash
git diff main...origin/{jeremy_branch} --stat
```

Replace `{jeremy_branch}` with the dynamically discovered branch name.

### Combining Sources

The Jeremy/Research agent should:

1. Query Neon for session count and high-level activity
2. **Use workflow metadata** to identify interesting sessions:
   - High `sidechain_count` = sessions where Jeremy explored multiple approaches
   - `session_summary` for quick session understanding
   - `is_sidechain = TRUE` messages show abandoned approaches (what didn't work)
3. Explore evidence folder for persisted research artifacts
4. Check branch for recent commits
5. Synthesise into a narrative: methodology evolution, OICs completed/rejected, interesting examples, quantitative summary

**Workflow Archaeology Tips:**
- Sessions with many sidechains reveal Jeremy's exploration process
- Abandoned approaches (`is_sidechain = TRUE`) are often more insightful than final answers
- Use `thinking_config IS NOT NULL` to find sessions using extended thinking

**Context:** Jeremy uses OIC methodology with three-leg validation. See `workspaces/jeremy/CLAUDE.md` for his full research workflow.

---

## Otter.ai (Otter MCP)

Meeting transcripts accessed directly via the Otter MCP server (`mcp__otter__*`).

### Available Tools

| Tool | Purpose |
|------|---------|
| `mcp__otter__search` | List meetings by date range, attendee, or keyword |
| `mcp__otter__fetch` | Get full verbatim transcript for a specific meeting |
| `mcp__otter__get_user_info` | User profile and current server time |

### Collection Logic

```
Step 1: List meetings in the recap period
Tool: mcp__otter__search
Parameters:
  created_after: "{period_start}"    # ISO date, e.g. "2026-02-17"
  created_before: "{period_end}"     # ISO date, e.g. "2026-02-23"

Returns per meeting:
  - id (otter_id)        → use for fetch
  - title                → meeting name
  - created_at           → meeting date
  - summary              → AI-generated summary
  - action_items         → extracted action items
  - attendees            → participant list
```

**Advantage over previous approach:** `search` returns summaries and action items directly — often sufficient without fetching the full transcript.

```
Step 2: Fetch full transcript (only if needed)
Tool: mcp__otter__fetch
Parameters:
  speech_id: "{otter_id_from_step_1}"

Returns:
  - Full verbatim transcript with speaker attribution
  - Use when summary alone doesn't capture enough detail
```

### Data Extracted

| Field | Usage |
|-------|-------|
| `id` | Otter meeting ID for fetching full transcript |
| `title` | Meeting name |
| `created_at` | Meeting date |
| `summary` | AI-generated meeting summary |
| `action_items` | Extracted action items (often sufficient for recap) |
| `attendees` | Participant names |

### Filtering

`mcp__otter__search` supports several filter parameters:

- **Date range:** `created_after` / `created_before` — primary filter for recap periods
- **Attendee:** `attendee` — filter by participant name
- **Keyword:** `keyword` — search meeting titles
- **Transcript keyword:** `keyword_in_transcript` — full-text search within transcripts

Combine filters to narrow results (e.g. date range + attendee for a specific person's meetings).

### Privacy

- `search` returns **metadata + summaries** — no raw transcript
- Show meeting titles, dates, and summaries in pre-flight
- User approves which meetings to include
- Fetch full transcript (`mcp__otter__fetch`) only for approved meetings
- **Never include raw transcripts** in recap — summarise key points

---

## Outlook (MS365 MCP)

### Metadata Collection

```
Tool: mcp__ms365__list-mail-folder-messages
Parameters:
  mailFolderId: "Inbox" (or specific folder ID)
  select: ["id", "from", "toRecipients", "subject", "receivedDateTime", "hasAttachments"]
  top: 100
  orderby: ["receivedDateTime desc"]
```

Returns:
```json
{
  "value": [
    {
      "id": "AAMkAG...",
      "from": {"emailAddress": {"address": "sender@example.com"}},
      "toRecipients": [{"emailAddress": {"address": "recipient@ardevora.com"}}],
      "subject": "Re: Q1 Planning",
      "receivedDateTime": "2025-01-20T14:30:00Z",
      "hasAttachments": false
    }
  ]
}
```

### Content Fetch (After Approval)

```
Tool: mcp__ms365__get-mail-message
Parameters:
  messageId: "AAMkAG..."
  select: ["subject", "body", "from", "receivedDateTime"]
```

Returns full body content.

### Categorisation

Group emails by sender domain for approval:

| Category | Domain Pattern |
|----------|----------------|
| Internal | `*@ardevora.com` |
| Investors | Known investor domains |
| Vendors | `*@linear.app`, `*@otter.ai`, etc. |
| Newsletters | Common newsletter senders |
| Other | Everything else |

### See Also

- `references/email-privacy.md` for handling rules

---

## Teams Recordings (OneDrive)

Native Teams meeting transcripts are **not accessible** via the MS365 MCP — they require the Communications API
(`/communications/onlineMeetings/{id}/transcripts`) which isn't exposed. However, we can detect recordings
and prompt the user for transcripts.

### Why transcripts aren't accessible

| What | Storage | MCP Access |
|------|---------|------------|
| Meeting recordings (MP4) | OneDrive `/Recordings/` | ✅ Yes |
| Meeting transcripts | Graph Communications API | ❌ No (requires `OnlineMeetingTranscript.Read.All`) |

### Detection Pattern

Check for Teams recordings not captured by Otter:

```
Step 1: Get OneDrive ID
Tool: mcp__ms365__list-drives
Parameters:
  select: ["id", "name", "driveType"]

Extract: drives.find(d => d.name === "OneDrive").id
```

```
Step 2: List recordings in time window
Tool: mcp__ms365__list-folder-files
Parameters:
  driveId: "{onedrive_id}"
  driveItemId: "root:/Recordings:"   # Or use folder ID from previous lookup
  select: ["id", "name", "size", "createdDateTime"]
  filter: "createdDateTime ge {start_date}"

Returns: List of MP4 files with meeting names and dates
```

### Filename Parsing

Teams recording filenames follow this pattern:
```
{Meeting Title}-{YYYYMMDD}_{HHMMSS}-Meeting Recording.mp4
```

Examples:
- `Call with Jeremy Lang-20260120_172436-Meeting Recording.mp4`
- `Workbench Update-20260116_120912-Meeting Recording.mp4`

Extract meeting title and date from filename for display.

### User Prompt Pattern

During pre-flight, if recordings found that don't match Otter transcripts:

```
AskUserQuestion:
  question: "Found 2 Teams meetings without Otter transcripts. Include any?"
  options:
    - label: "Call with Jeremy Lang (Jan 20)"
      description: "Paste transcript if available"
    - label: "Workbench Update (Jan 16)"
      description: "Paste transcript if available"
    - label: "Skip all"
      description: "Continue without these meetings"
  multiSelect: true
```

If user selects meetings, prompt for transcript content (paste) or note as "recording only, no transcript".

### Privacy

- Only show meeting titles and dates (no video content)
- User controls which meetings to include
- Pasted transcripts treated same as Otter transcripts (summarised, not included raw)

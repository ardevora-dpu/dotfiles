---
name: weekly-recap
description: Generate activity recap for the team. Use when asked for "what we did this week", "monthly update", or "/weekly-recap".
---

# Activity Recap

Generate recap emails that help the team understand what happened, why it matters, and where we're heading.

## Purpose

Help time-constrained expert peers reach shared understanding and make sound decisions.

**Objectives:**
- **Velocity signal** — Show we're making progress, build momentum
- **Coordination** — Help each person understand what others are doing
- **Accountability** — Track what was committed vs delivered
- **Learning** — Explain technical/investment concepts so everyone can follow

**Reader outcome:**
- Informed ("I know what happened across the business")
- Aligned ("I understand why we're doing this")
- Energised ("We're making real progress")
- Clear on priorities ("I know what matters now")

**Pain addressed:**
- Silos (don't know what others are doing)
- Lost in the thick (can't see the forest for the trees)
- Meetings rehash old ground
- Decisions lack context

## Audience

The 6 team members: Jeremy, Jack, Timon, Aisling, Helen, Bill.

They're experts in their domains but may not understand other workstreams. Jeremy's investment methodology and Timon's platform work need contextual explanation for the others.

## Workflow

```
1. SCOPE
   ├── Determine date range
   ├── Pre-flight check: Teams chats + emails
   │   └── Surface titles/subjects for user to pick what to include
   ├── List transcripts available in date range
   ├── Ask: "Include/exclude anything? Any context I should know?"
   └── WAIT for confirmation

2. DIRECTION ⛔
   ├── Ask: "What are we all moving towards right now?"
   ├── Understand current priorities, sprint focus, key milestones
   └── WAIT — this shapes what gets emphasis in the recap

3. COLLECT
   ├── Load previous recap (most recent docs/recaps/*/final.md)
   │   └── If none exists (first run): note this, skip "what's changed" framing
   ├── Launch sub-agents with: date range, direction, previous recap
   │   └── Sub-agents are REQUIRED — do not gather evidence directly
   ├── Write to docs/recaps/{date}/evidence/*.md
   └── Evidence persists for audit

4. ASSESS ⛔
   ├── Read all evidence files
   ├── Identify what's strong, what's thin, what's missing
   ├── Present quality summary with "other items" from all agents
   ├── Ask: "Dig deeper on anything, or proceed?"
   ├── If user requests deeper dive: launch targeted follow-up agent
   └── WAIT for response

5. DRAFT
   ├── Write recap email following style guide
   ├── Present draft for feedback
   └── Iterate until approved (target 1-2 rounds as skill matures)

6. SEND ⛔
   ├── Preview final version
   ├── Ask: "Send to the team?"
   ├── Send via MS365 MCP
   └── Save final recap to docs/recaps/{date}/final.md

7. LEARN
   ├── Ask: "Anything to improve for next time?"
   ├── Update glossary with newly explained terms
   └── Capture learnings in manifest.json
```

Checkpoints marked ⛔ require user response before continuing.

## Sub-Agent Specification

Launch these agents during COLLECT. Each receives: date range, direction statement, and previous recap (if exists).

| Agent | Sources | Output File | Focus |
|-------|---------|-------------|-------|
| **Per-transcript** | Each Otter transcript | `meetings/{slug}.md` | One agent per transcript (they're large). Decisions, context, concerns, sub-text. |
| **Linear** | All Linear issues | `linear-summary.md` | What got done, blocked, shifted priority. Group by what happened, not status. |
| **Timon/Platform** | Git history, PRs | `timon-platform.md` | What shipped and why it matters. Platform evolution, tooling improvements. |
| **Jeremy/Research** | Neon sessions + evidence folder + branch | `jeremy-research.md` | Deep dive: methodology evolution, OICs completed, interesting examples, narrative arc. |
| **Communications** | Selected Teams chats + emails (from pre-flight) | `comms-summary.md` | Only runs if user selected items in SCOPE. Key discussions, decisions, threads. |

**Parallelisation:** Transcript agents run in parallel with each other. Linear, Timon, Jeremy, and Communications agents can also run in parallel.

**Conditional agents:** Communications agent only launches if user selected Teams chats or emails during SCOPE pre-flight. If nothing selected, skip this agent.

**Follow-up agents:** If ASSESS reveals gaps, launch targeted agents with specific questions. Append to existing evidence files (don't overwrite).

## Data Sources

| Source | What it tells us | Access |
|--------|------------------|--------|
| Otter transcripts | Meeting decisions, discussions | Otter MCP (`mcp__otter__search`, `mcp__otter__fetch`) |
| Linear | Work tracked, completed, blocked | `mcp__linear__list_issues` |
| Git commits | What was shipped | `git log` |
| Neon sessions | Jeremy's research activity | `mcp__neon__run_sql` |
| GitHub PRs | Platform deliverables | `gh pr list` |

### Transcript Filtering

Use `mcp__otter__search` with `created_after` / `created_before` to filter by date range. The `search` response includes summaries and action items directly — fetch the full transcript only when the summary lacks detail.

## Output Format

**Delivery:** HTML email via MS365 MCP

**Typography:** Use the recap typography rules below
- Calibri 11pt
- No bold
- No headers (structure comes from paragraph logic)
- No em-dashes (use regular dashes or parentheses)
- British spelling throughout

**Structure:**
- Opening paragraph: 10-second orientation (what happened, why it matters)
- Body: Prose with paragraph breaks between topics
- Appendix: Snappy bullets for technical details by domain

**Length:** Varies — monthly is longer, weekly is shorter. Match length to content.

## Writing Approach

Claude has full creative discretion on what's important and how to present it.

### Voice
- Analytical observer ("The data suggests" not "We found")
- Evidence-forward, serious peer tone
- Claims proportional to evidence
- Flag uncertainties when they change interpretation

### Curation
- Balanced coverage: all workstreams get attention
- More space for what matters most this period
- Technical details go in appendix, not body
- Skip routine updates; focus on what's genuinely interesting

### Teaching
- Contextual: explain enough that significance is clear
- Don't lecture, but don't assume everyone knows what "CG-P" or "OIC" means
- First-time terms get parenthetical explanation
- Check glossary to avoid re-explaining terms from previous recaps

### What to avoid
- Superlatives ("remarkable", "impressive", "significant")
- Hype ("game-changing", "revolutionary")
- Exclamation marks
- Bold or headers
- Em-dashes
- Vague counts ("many", "several" — use numbers)
- Passive voice
- Evidence dumps (lists of things without context)

### What works
- Specific numbers
- Parenthetical context
- Active voice
- "So what" — why does this matter?
- Narrative flow between topics

## Glossary

Track explained terms in `docs/recaps/glossary.json`.

On first use in recap history, explain the term. On subsequent recaps, use freely without re-explaining.

Format:
```json
{
  "OIC": {
    "full": "Original Investment Case",
    "explained_in": "2026-02-02-ytd"
  }
}
```

## Evidence Gathering

Evidence gathering is where the recap's value is created or lost. Sub-agents should leverage Claude's full intelligence to surface insights that move the company forward.

### Philosophy

**Purpose:** Synthesis input + knowledge capture. Not just data extraction - intelligent analysis that surfaces what matters.

**Intelligence level:** Sub-agents should:
- **Extract** what's explicitly stated
- **Infer** what it means and why it matters
- **Connect** dots across the source (sparingly - cross-source connections come from main Claude)
- **Analyse** patterns, gaps, and implications

**Context:** Sub-agents receive the previous recap so they can note what's changed, what's progressing, and what's new.

### What Success Looks Like

An evidence file succeeds when:
- Reading the source directly reveals nothing the agent missed
- It surfaces actionable insights, not just raw data
- Reading it gives confidence you know what happened
- It captures things that would otherwise be lost between meetings

### Structure

Sub-agents choose their own structure based on what they found. The only requirement: **nothing important gets lost**.

Typical pattern:
1. **Main insights** - Prose covering the most important findings with full context
2. **Other items** - Bullet list of everything else that happened (potential expansion areas)
3. **Observations** - Striking meta-learnings about the source itself (only if genuinely insightful)

### Source-Specific Guidance

**Jeremy's research (Neon + evidence folder + branch):**

Jeremy's research is captured across three sources that should be combined:

1. **Neon sessions** — Chat logs from Claude Code sessions. Query `search_sessions` and `search_messages` tables. Shows what questions he asked, what stocks he explored, how his thinking evolved.

2. **Evidence folder** — `workspaces/jeremy/evidence/**/*.md`. Structured research artifacts organized by review period → sector → stock → analysis type. Look for OIC development files, peer analysis, regime charts.

3. **His branch** — Discover dynamically: first check Neon `search_sessions.git_branch` for his most recent active branch, then fall back to `git branch -r | grep jeremy/` and pick the most recently updated. Check what files changed, what research he's persisted.

**What to capture:**
- Methodology evolution (how his process is changing)
- OICs completed or rejected (with brief thesis)
- Interesting examples (surprising findings, edge cases)
- Quantitative summary (session count, stocks reviewed, OIC counts)
- Narrative arc (the story of his research journey this period)

**Context:** Jeremy uses OIC methodology with three-leg validation. See `workspaces/jeremy/CLAUDE.md` for his full research workflow.

**Meeting transcripts:**
Don't just extract decisions and action items. Capture:
- Context and reasoning (WHY something was decided)
- Emerging concerns raised but not resolved
- Sub-text and short mentions that might matter
- Inefficiencies in how meetings run (if striking)

**Linear issues:**
Group by what happened, not by status. What got done? What's blocked and why? What shifted priority?

**Timon/Platform (Git + PRs):**
Focus on what was shipped and why it matters, not commit counts. Look for:
- Features that enable new workflows
- Infrastructure improvements
- Tooling for Jeremy's research
- Data pipeline changes

### ASSESS Checkpoint

After evidence gathering, main Claude:
1. Reads all evidence files
2. Identifies what's strong, thin, or missing
3. Reviews the "other items" bullets across all sources
4. Asks user: "Given all this context, anything you want me to dig deeper on?"

This is where cross-source patterns emerge and gaps get filled.

### File Structure

Evidence and final recap persist in `docs/recaps/{date}/`:

```
docs/recaps/{date}/
├── evidence/
│   ├── timon-platform.md
│   ├── jeremy-research.md
│   ├── linear-summary.md
│   ├── comms-summary.md    # Only if Teams/emails selected in SCOPE
│   └── meetings/
│       └── {meeting-slug}.md
├── final.md          # Saved after SEND - the actual recap that was emailed
└── manifest.json
```

Evidence files are INPUT for synthesis, not templates to copy. Transform structured data into narrative prose.

## Storage & Retention

**After SEND:** Save the final recap to `docs/recaps/{date}/final.md`. This becomes the "previous recap" for future runs.

**Evidence retention:** Keep forever for audit trail. Evidence files show what was considered when writing the recap.

**Previous recap access:** Sub-agents receive the most recent `final.md` to note what's changed since last time. If no previous recap exists (first run), skip "what's changed" framing and focus on establishing baseline.

**Glossary persistence:** `docs/recaps/glossary.json` tracks all explained terms across all recaps. Check before explaining a term - if already explained, use freely without re-explaining.

## Manifest

Each recap has a `manifest.json`:

```json
{
  "date_range": {"start": "2026-01-01", "end": "2026-02-02"},
  "direction": "Portfolio completion sprint — 100 cases by late Feb",
  "sources": {"transcripts": 7, "linear_issues": 93, "commits": 76},
  "sent": {"status": true, "sent_at": "2026-02-02T14:00:00Z"},
  "terms_explained": ["OIC", "CG-P", "Three-Leg Validation"],
  "learnings": []
}
```

## Reference Files

- `references/style-guide.md` — Detailed writing guidance and examples
- `references/workstream-mapping.md` — How to attribute items to workstreams

## Workstreams

| Workstream | Description | Key People |
|------------|-------------|------------|
| Product & Tech | Data platform, tools, automation | Timon |
| Investment | Stock analysis, OICs, regime signals | Jeremy |
| Commercial | Distribution, revenue, wealth platforms | Jack, Helen |
| Legal & Regulatory | FCA, lawyers, Capricorn, compliance | Aisling, Bill |

Structure (by-workstream vs by-theme) is Claude's choice based on what makes the content clearest.

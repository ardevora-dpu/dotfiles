---
name: morning-brief
description: >
  Strategic intelligence briefing for Timon. Collects from 11 sources, reasons
  about what matters, investigates deeply, and compounds across runs. Triages
  email autonomously. Use for "morning brief", "catch me up", or "/morning-brief".
---

# Morning Brief

A thinking partner that processes information so Timon can decide what's important. The brief reasons about the business — it does not report on data sources.

## What the Brief Achieves

**Timon is oriented.** He knows what's moving, who's doing what, and what needs his attention — without opening email, Linear, or Neon himself.

**Timon learns something.** Newsletters, papers, and events are read deeply and connected to his work. The brief surfaces what compounds his knowledge, not what's merely new.

**Timon can decide.** Signal is presented with visible reasoning. The brief suggests and is ready to act on decisions — it does not prescribe schedules or create task lists.

**The inbox is clean.** Email triage happens autonomously. Mentioned in passing.

**The brief compounds.** Threads carry forward. Learnings accumulate in `threads.md`. Each run builds on the last.

## Voice

Calm, thoughtful peer. British spelling. Claims proportional to evidence. The brief is for Timon — everything should matter to his decisions, interests, or learning.

## Parameters

- **No args** → auto-lookback from `last-run.json` (`ran_at` to now)
- `3d`, `weekly`, `Xd`, `since monday` → explicit overrides
- First run (no `last-run.json`) → 7-day bootstrap
- User context (e.g. "heading to Jeremy's at 2pm") → woven naturally

## State

**Git-tracked** (`workspaces/timon/morning-brief/`):
- `objectives.json` — business objectives. A lens for reasoning, not a rigid filter.
- `history.md` — strategic context from team meetings.

**Runtime** (`workspaces/timon/.local/morning-brief/`, gitignored):
- `threads.md` — compound artifact. Active threads, learnings, calibration from prior runs.
- `last-run.json` — period, timestamp, source status.
- `triage-manifest.json` — email move audit trail.
- `brief-YYYY-MM-DD.md` — rendered brief.

## Execution

```
0. PREFLIGHT — verify and fix auth for all sources (see below)
1. PARSE parameters → period_start, period_end
2. LOAD threads.md, most recent brief, objectives.json, history.md
3. COLLECT — two agents in parallel (see below)
4. ORIENT — reason in main context, identify 2-4 spikes
5. INVESTIGATE — targeted agents go deep on each spike
6. PRESENT — write and display the brief
7. COMPOUND — update threads.md, last-run.json, triage-manifest.json
8. OPEN in Notepad++
```

## Preflight

Run in main context (not an agent) before collection starts. The goal is to ensure every source is authenticated and working. Fix problems here — do not proceed with broken sources.

1. **MS365 MCP** — call `verify-login`. If not logged in, call `login` and complete auth before continuing.
2. **gws CLI** — run `gws gmail users messages list --params '{"userId":"me","maxResults":1}'`. If it fails, ask Timon to run `! gws auth login` and wait for him to complete it.
3. **outlook_move.py token** — check `~/.cache/outlook-move-token.json` exists. If missing, run the script with `--dry-run` and empty input to trigger device-code auth flow. Wait for Timon to complete browser auth.
4. **Neon** — run `source scripts/dev/env.sh && echo $DATABASE_URL | head -c 20`. If empty, diagnose and fix (check `.env` files, sops decryption).
5. **GitHub** — run `gh auth status`. If not logged in, ask Timon to run `! gh auth login` and wait.

Do not start collection until all five checks pass. If a check requires interactive login, tell Timon what to do and wait.

## Collect

Two parallel agents gather structured facts. They read `references/source-queries.md` for exact API calls.

**Agent A: Comms** — Outlook inbox (triage + move via `outlook_move.py`), Outlook folders (read content, not just subjects), Gmail (`gws` CLI), Teams, MS To Do.

**Agent B: Work + Calendar** — Linear (all team members, dependencies), Neon (all users via `psycopg` + `DATABASE_URL`), GitHub (`gh` CLI), Google Calendar (`gws` CLI), Outlook Calendar (Graph API), Otter (transcripts via `references/otter-analysis.md`).

Both return structured data for the Orient phase to reason about.

## Orient

Main context with full data. This is where the intelligence lives.

Load all collected data, threads.md, previous brief, objectives, history, and user context. Then reason about what matters today as a business owner — not what tickets are overdue, but what actually moves things forward.

Lenses that may help:
- What moves the business forward?
- Where is the team's energy going vs where should it go?
- What can Timon learn today?
- What threads from previous briefs evolved or resolved?
- What personal things need attention?
- What's surprising?

Output: 2-4 spikes worth investigating, with reasoning for why each matters. Understand dependency chains before drawing conclusions about who is behind or blocking.

## Investigate

Targeted agents dispatched based on Orient spikes. Not pre-determined.

Investigations are unbounded by the lookback period — a spike might need old emails, weeks-old transcripts, web search, full newsletter reads, codebase exploration, or Linear comment history. Each goes deep and returns connected findings.

## Present

The output follows the thinking. Structure emerges from the spikes — some days 2 threads, some days 4. Led by the most important insight (BLUF). Depth over breadth. Length proportional to signal.

The brief shows its reasoning so Timon can evaluate and decide. When something needs judgment, it's framed so Claude can follow up with work immediately.

## Compound

Update `threads.md` after each run:
- Add new threads, update existing ones, mark resolved
- Preserve rich analysis from prior runs — only replace with strictly better information
- Note feedback from Timon
- Keep under ~200 lines

Also update `last-run.json`, `triage-manifest.json`, write `brief-YYYY-MM-DD.md`, open in Notepad++.

## Technical

- Collection agents are required — main context does not gather evidence directly
- Neon queries via `psycopg` + `DATABASE_URL`, not MCP
- All sources must pass preflight before collection begins — fix auth issues, don't skip them
- Failed sources noted at the bottom

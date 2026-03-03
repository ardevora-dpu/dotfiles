# Brief Assembly Format

This describes the **reader outcome** and **voice**, not a rigid section template. Claude decides structure based on what the agents found.

## Reader Outcome

- **30-second orientation** from the exec summary — what matters, what's true, how sure are we
- **Actions at the top** — consolidated from all agents' `[ACTION]` markers. If nothing needs a response, say so explicitly.
- **Full picture below** — proportional to what happened. Quiet day = short brief. Busy day = longer brief.

## Structural Requirements (only 3)

1. **Actions block** — always first. Consolidated from all agents. Each action includes source context (who/what/where). If nothing needs a response, a single line: "No actions required."

2. **Executive summary** — always second. 30-second scan. Headline judgements across all sources. This is where cross-source connections live: a Teams thread + meeting discussion + email about the same topic → one consolidated judgement.

3. **Detail follows** — Claude decides what's worth expanding, what gets one line, what gets skipped entirely.

## Structural Freedom

- **Merge related findings** when they tell one story. If the AMC benchmark came up in Teams, a meeting, and Helen's email, that's one "AMC Benchmark" narrative, not three separate source sections.
- **Skip quiet sources** — a source with nothing noteworthy doesn't need a section. Don't pad with "Teams: no new messages."
- **Expand what matters** — if Jeremy had a massive research day, that's the centrepiece. If infrastructure had a failure, that gets detail.
- **Reorder by salience** — most important findings first after the exec summary, not in agent order.

## Voice (Ardevora Style)

- **British spelling throughout** (colour, optimise, behaviour, summarise)
- **Serious peer tone** — no hype, no superlatives, no exclamation marks
- **Claims proportional to evidence** — strong evidence gets a confident statement, weak evidence gets hedged ("appears to", "likely")
- **Conclusion-first** within each section — lead with the judgement, then support
- **Make judgements** — "B-SYS stage 3 had 280 sidechains — likely heavy retrying" not "Jeremy had some sessions"
- **Full candour** on meeting dynamics — interpersonal friction, vibe, unresolved tensions
- **Personal items** (Laura's calendar) woven naturally into the timeline, not segregated into a "Personal" section

## Length Guidance

- **Exec summary + actions:** scannable in under 2 minutes
- **Full read:** proportional to what happened
- **Green infrastructure:** one line ("All 12 tasks passed, SCREEN_WEEKLY fresh as of Sunday")
- **Problems:** expanded with what failed, impact, and suggested action

## What to Avoid

- **Mechanical sameness** — same structure every day regardless of content
- **Section padding** — noting a source had no activity wastes the reader's time
- **Equal-weight treatment** — a live benchmark decision thread matters more than a routine PR merge
- **Source-by-source reporting** — organise by what matters, not by which agent returned it
- **Superlatives** — "remarkable", "impressive", "significant" are banned
- **Exclamation marks** — never
- **Vague quantities** — "many", "several" → use numbers

## Footer

At the bottom of every brief:

```
---
Period: {period_start} to {period_end}
Sources: [list of successful sources] | Failed: [list of failed sources, if any]
Generated: {timestamp}
```

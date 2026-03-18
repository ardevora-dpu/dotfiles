# Brief Assembly Format — Chief of Staff Intelligence Product

This describes the **structure**, **voice**, and **evaluation lens** for the morning brief. The brief is not a status dashboard — it is a strategic intelligence product that thinks about the business, challenges the plan, and keeps the reader focused on what moves things forward.

## Reader Outcome

After reading this brief, Timon should be:
- **Fully oriented** — complete picture of what happened, what's coming, what matters
- **Ready to decide** — decisions are pre-processed with recommendations and time estimates
- **Challenged where needed** — the brief surfaces uncomfortable truths (misaligned time, stale decisions, drift from objectives)
- **Unburdened** — email triaged, noise filtered, routine handled autonomously

## The Evaluation Lens

**Everything** in the brief is filtered through the business objectives (loaded from `objectives.json`). A finding that advances an objective gets prominent treatment. A finding irrelevant to all objectives goes to "Not Today" or gets skipped entirely. The brief doesn't just report what happened — it evaluates whether it matters.

Load `references/objectives-framework.md` for the full evaluation rubric.

## The 7 Sections

The brief has exactly 7 sections, in this order. Every section is required (even if short). The order is deliberate — strategic context first when cognitive energy is highest, operational detail later.

### 1. State of Play

Where do the business objectives actually stand? Not status — **assessment**.

For each objective, provide a PDB-style assessment:
- Lead with the judgement: "AMC launch is blocked on JPM onboarding. Nothing you can do today."
- State confidence: high / moderate / low
- Identify the current blocker or next move
- Connect evidence from multiple sources (Linear + email + Teams + Neon)

This section should be 3-8 sentences per objective. If an objective has no new developments, one sentence: "Hiring: no change. Still zero hours allocated."

**The Rabois test lives here.** Compare actual time allocation (from calendar + Neon sessions) against objectives. If there's a gap, say it: "You said AMC launch is the priority. Yesterday you spent 6 hours on tech debt and 0 on AMC."

### 2. What Changed Overnight

Signals that shift the picture since the last brief. This is the delta section — new developments only, evaluated against objectives.

- Lead with new/changed items. Use `[NEW]` and `[CHANGED]` tags.
- Each signal gets an **assessment**, not just a summary: "JPM sent onboarding docs — this unblocks AMC external readiness. Respond today."
- Cross-source connections: if an email, a Teams message, and a Linear update are about the same thing, merge them into one assessment.
- Compact carry-over at the bottom: "Still open from previous briefs: [one-liner per item with days-open count]"

### 3. Your Day

Calendar audit + **interactive** priority setting. This section protects Timon's time and helps him decide what to work on — it does NOT hand him a finished plan.

- **Peak protection**: Identify the morning deep-work block. Is it protected or fragmented by meetings?
- **Team calendar context**: Show what colleagues have scheduled (Aisling's JPM calls, Jack's meetings, etc.) so Timon sees the full picture of who is doing what today.
- **Subtraction candidates** (Lütke): "The 10am meeting has produced no decisions 3 weeks running. Consider cancelling."
- **Probing questions with options**: Instead of a prescriptive sequence, present 2-3 focused questions that force a priority decision. Each question has a recommended option. Example:

  > **Focus question:** The risk disclosure tickets (ARD-574, ARD-551) advance AMC launch directly. The tech stack audit (ARD-558) doesn't. Which is your morning focus?
  > - **(A) Risk tickets** [recommended — directly unblocks AMC external readiness]
  > - (B) Tech stack audit
  > - (C) Something else

  > **Decisions today:** ARD-397 has been open 7 days and blocks Aisling. Slip to 27 Mar, close, or decide now? (~5 min)

  The brief surfaces the highest-leverage choices and lets Timon decide. It challenges if his choice doesn't align with objectives, but doesn't prescribe a rigid sequence.

- **Important:** Only surface decisions and tasks that are genuinely Timon's responsibility. Don't assign vendor follow-ups (JPM, UBS) unless Timon is the actual owner. Check Linear assignees.

### 4. What I Noticed

Pattern Detector output. This is where the brief earns its chief-of-staff role.

- **Automation opportunities**: "You ran PR review loops in 4 of 5 sessions — this should be a skill"
- **Recurring friction**: "Jeremy hit the same Snowflake auth error in 3 sessions this week — 15 min/day lost"
- **Misalignment**: "Jack spent 8 hours on website copy — not on any active objective. Is this intentional?"
- **Anomalies**: Unexpected patterns — spikes, silences, shifts in behaviour
- **Stalled barrels** (Rabois): People who ship end-to-end that are currently blocked

Each observation should be specific and actionable, not vague.

### 5. What I Handled

Autonomous actions the brief took, PLUS a curated read of what's in each folder. This section should feel like a knowledgeable colleague who read all your email and is telling you what's worth knowing.

- **Email triage summary**: "Processed 32 emails: 18 → Broker Notes, 5 → Newsletters, 4 → Quant & Data, 2 → Invoices, 3 staying in inbox"

- **Folder reads** — the Folder Intelligence agent READS the content and reports what's genuinely interesting, not just what arrived. Filter by quality, not category — a great piece on any topic beats a mediocre piece on Timon's exact domain. Skip marketing fluff, vendor promos, and updates on things that have been obvious for a long time.
  - **Newsletters** (PRIMARY — curated highlights): Present 2-4 best items with 1-2 sentence summaries + why it matters + estimated read time. Skip the rest silently. Timon can ask Claude to expand on any item he wants to drill into.
    - Tag CPD-eligible items with [CPD] — Timon is FCA-regulated and needs to demonstrate professional development informally (investment methodology, risk management, regulatory, compliance, market structure).
    - **Surface events**: London/UK in-person meetups, free online webinars under 1 hour, and paid conferences worth the investment. Include: name, date, location, one-line assessment. E.g. "S&P ECM webinar: IPO Renaissance — Thu 19 Mar, 14:00 GMT, online free. Good AMC launch context. [CPD]"
  - **Broker Notes** (scan, flag notable only): 90% is noise. Only surface methodology papers, portfolio-company research, major market events, or CPD-eligible content. Tag with [CPD] where applicable.
  - **Quant & Data** (scan for standouts): Only mention if genuinely unusual (2σ moves, record positioning). Most is routine.
  - **Invoices** (quick cost summary): Vendor, amount, any past-due signals.
  - **Platform Alerts** (cross-check against Platform Health agent): If the Platform Health agent said "green" but Platform Alerts folder has failure notifications, flag the discrepancy.

- **Actionable items remaining in inbox**: list with subject, sender, why it needs attention

The goal: after reading this section, Timon should NOT need to open any of these folders himself. The brief has read them for him and surfaced everything worth knowing.

### 6. Not Today

Things the brief considered surfacing but deliberately excluded, with a one-line reason each. This makes the editorial judgement transparent and trains trust.

Examples:
- "SCREEN_WEEKLY 3 days stale — normal for Sunday, no action needed"
- "3 routine PRs merged — no review issues"
- "Aisling's compliance checklist update — no action needed from you"
- "12 automated CI notifications — all passed"

If the brief excluded nothing notable, skip this section.

### 7. Stale Decisions

Items carried forward for 3+ days without resolution. Each gets an inline forcing prompt:

```
**ARD-397** (7 days) — Backup pricing decision. Blocking Aisling's AMC onboarding work.
→ **Slip** to [date] | **Close** (done/irrelevant) | **Decide now**
```

Type 1 decisions (irreversible) get forced at 2 days. Type 2 at 3 days.

If no stale decisions exist, skip this section.

## Delta Awareness

When a previous brief is available, compare findings against it and surface what actually changed.

### Tagging

- **`[NEW]`** — first appearance
- **`[CHANGED]`** — present before but status/urgency/context shifted
- **`[CARRY-OVER]`** — unchanged from previous brief

Lead with new and changed items in section 2. Collapse carry-overs into compact format. Skip re-analysing meetings already covered — note "covered in yesterday's brief" and only surface new follow-ups.

### When no previous brief exists

First run or after a gap: treat everything as `[NEW]` and omit the delta framing.

## Voice

### Keep (Ardevora style)
- British spelling throughout (colour, optimise, behaviour, summarise)
- Serious peer tone — no hype, no superlatives, no exclamation marks
- Claims proportional to evidence
- Conclusion-first within each section
- Full candour on interpersonal dynamics and meeting tension
- Personal items (Laura's calendar) woven naturally, not segregated

### Add (Chief of Staff)
- **Opinionated when evidence supports it** — "This is higher leverage than what you planned" is good
- **Challenge the plan** — if today's schedule doesn't advance objectives, say so
- **Surface what the reader doesn't want to hear** — stale decisions, misaligned effort, uncomfortable truths
- **PDB assessment model** — lead with the assessment, follow with evidence, state confidence level
- **Pre-digest, don't add load** — "4 items need you, 28 were filed" not "here are 32 emails"
- **Constrained choices where possible** — "I recommend X. Approve/override?" reduces decision fatigue

### Avoid
- Dashboard regurgitation (sprint percentages, green/green health tables)
- Equal-weight treatment (a live benchmark decision matters more than a routine PR merge)
- Source-by-source reporting (organise by impact, not by which agent returned it)
- Vague quantities ("many", "several" → use numbers)
- Superlatives and exclamation marks
- Section padding (noting a source had no activity)

## Length

- **Sections 1-3**: scannable in 2-3 minutes. This is the essential intelligence.
- **Sections 4-7**: proportional to what happened. Quiet day = short. Busy day = longer.
- **Green infrastructure**: one line
- **Problems and decisions**: expanded with what failed, impact, and recommendation

## Footer

```
---
Period: {period_start} to {period_end}
Objectives: {objective_labels}
Sources: [successful] | Failed: [failed, if any]
Generated: {timestamp}
```

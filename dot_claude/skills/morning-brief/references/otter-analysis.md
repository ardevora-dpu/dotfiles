# Otter Transcript Analysis Framework

Apply this framework to each meeting transcript. The goal is insight the reader wouldn't get from Otter's auto-generated summary — the dynamics behind the decisions, not just the decisions themselves.

## What to Extract

### 1. Decisions Made
Confirmed outcomes — something was agreed, not still debated. Include who decided and any conditions attached.

### 2. Decisions Left Open
Especially ones that people *think* are decided but aren't. A topic discussed at length without a clear resolution is an open decision, even if the conversation moved on.

### 3. Action Items by Person
Include implicit ones — things someone agreed to do but weren't formally stated as action items. Format: `[ACTION] Person: what they committed to`.

### 4. Friction Points
Disagreements, frustration, repeated circling on the same topic. Don't sanitise — if two people talked past each other for 10 minutes, say so. If someone's suggestion was dismissed without engagement, note it.

### 5. Silent Inefficiencies
- Unlinked dependencies ("we need X before Y" but no one owns X)
- Missing prerequisites (decisions that require information no one has)
- Urgency not matched to deadlines (something is "critical" but the next step is in 3 weeks)
- Topics that should have been resolved async but consumed meeting time

### 6. Vibe
2-3 sentences: Is this team functioning well? Where is the stress? Is energy focused or scattered? Are people engaged or going through the motions?

### 7. Key Quotes
Only the ones that capture the room — a phrase that crystallises a tension, a moment of clarity, or an unguarded admission. Max 3-4 per meeting.

## Judgement Guidance

- **Full candour** on interpersonal dynamics. This is a private briefing for Timon, not a diplomatic summary for the group.
- **Claims proportional to evidence** — if someone seemed frustrated, say "seemed frustrated" not "was angry". If the evidence is strong (raised voice, repeated interruptions), be direct.
- **Don't just list — assess.** "The benchmark discussion consumed 20 minutes without resolution because Jack and Helen have different definitions of 'ready'" is better than "Benchmark was discussed."
- **Action items Otter would miss** — Otter catches explicit "I'll do X by Friday". Catch the implicit ones: someone said "we should probably..." and no one pushed back, which means it's now theirs.

# Business Objectives Framework

The morning brief evaluates **everything** against declared business objectives. Every signal, every action item, every recommendation is filtered through: "does this move the business forward?"

## How Objectives Work

Timon declares 2-3 business objectives (stored in `workspaces/timon/morning-brief/objectives.json`, git-tracked). These persist for weeks/months and are reviewed weekly. They are the answer to Slootman's question: "If you could do just one thing for the remainder of the year, what would that be?"

Strategic history is available at `workspaces/timon/morning-brief/history.md` — a distilled record of business decisions, team dynamics, and strategic arc from Otter transcript analysis. Agents should reference this when evaluating objective alignment or assessing long-term patterns.

Every sub-agent receives the objectives as context and must:

1. **Tag findings** that advance, block, or are irrelevant to each objective
2. **Surface negative leverage** (Grove) — where Timon's inaction on an objective is blocking someone else
3. **Detect drift** — when actual time allocation doesn't match declared priorities (Rabois calendar-priority test)

## For the Synthesis Step

The synthesis step uses objectives for:

### State of Play (Section 1)
Open with a PDB-style assessment per objective:
- Where does it actually stand? (assessment, not status)
- What's the blocker right now?
- What would move it forward today?
- Confidence level: high / moderate / low

### Calendar-Priority Audit (Section 3: Your Day)
Compare today's calendar + yesterday's Neon sessions against objectives:
- How much time was actually spent on each objective?
- Is the calendar aligned with priorities, or is the day full of low-leverage tasks?
- Specific recommendation: "Protect your morning for X — it's the highest-leverage use of your peak hours"

### Misalignment Detection (Section 4: What I Noticed)
Flag when team members are spending time on work that doesn't connect to any active objective:
- "Jack spent 6 hours on website copy — none of your objectives involve website"
- "You planned to work on tech debt but AMC launch is blocked on your decision"

## Objective Evaluation Rubric

When tagging a finding against objectives, use this lens:

| Signal | Disposition |
|--------|-------------|
| Directly advances an objective | Surface prominently with leverage annotation |
| Blocks an objective (someone waiting on Timon) | **Decisions Required** — flag as negative leverage |
| Tangential (related but not directly advancing) | Mention briefly in context |
| Irrelevant to all objectives | **Not Today** section, or skip entirely |

## When Objectives Are Missing or Stale

If `objectives.json` doesn't exist or `review_after` has passed:
1. Note it prominently: "No business objectives set. The brief can't evaluate what matters without them."
2. Prompt Timon to set objectives before continuing
3. Suggest starting points based on active Linear milestones and recent patterns

## Anti-Patterns

- Don't treat objectives as a checklist — they're a lens, not tasks
- Don't force every finding to connect to an objective — some things matter independently (platform outages, security issues)
- Don't soften the alignment gap — if the calendar contradicts stated objectives, say so directly
- Don't let objectives go stale — if the same objectives persist for 4+ weeks without review, prompt for refresh

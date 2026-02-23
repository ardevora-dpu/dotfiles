# Writing Style Guide

The recap helps time-constrained expert peers reach shared understanding. It should leave readers feeling informed, aligned, energised, and clear on priorities.

## Core Principles

### 10-Second Orientation

Within 10 seconds, an expert should answer:
- What is this about?
- What's the current takeaway?
- Why does it matter?

The opening paragraph does this work. Don't bury the lead.

### Claims Proportional to Evidence

Strong language requires strong support. When uncertain, say so — but only when uncertainty changes interpretation.

| Calibration | Example |
|-------------|---------|
| Confident | "Jeremy completed 13 investment cases" |
| Qualified | "UBS onboarding appears delayed (Mark hasn't responded in two weeks)" |
| Uncertain | "The tax treatment remains unclear — we're seeking legal opinion" |

### Educational Without Lecturing

Most team members don't understand other workstreams in detail. Jeremy's investment methodology and Timon's platform work need explanation — but contextual, not tutorial.

Explain enough that the significance is clear. Don't assume everyone knows what "CG-P" or "Three-Leg Validation" means, but don't write a textbook either.

## Voice

- **Analytical observer:** "The data suggests" not "We believe"
- **Evidence-forward:** Lead with what happened, not interpretation
- **Serious peer tone:** No hype, no marketing, no condescension
- **Active voice:** "The team shipped" not "was shipped by the team"

## What to Avoid

| Pattern | Problem |
|---------|---------|
| Superlatives ("remarkable", "impressive") | Empty calories — use numbers instead |
| Hype ("game-changing", "revolutionary") | Marketing language, not peer communication |
| Exclamation marks | Undermines serious tone |
| Bold or headers | Breaks email typography rules |
| Em-dashes | Use regular dashes or parentheses |
| Vague counts ("many", "several") | Meaningless — use specific numbers |
| Passive voice | Obscures who did what |
| Evidence dumps | Lists without context don't help understanding |

## What Works

| Pattern | Why |
|---------|-----|
| Specific numbers | "13 cases" not "many cases" |
| Parenthetical context | "OIC (Original Investment Case — the structured thesis document)" |
| Active voice | Clear who did what |
| "So what" | Explain why it matters, not just what happened |
| Narrative flow | Topics connect logically, not randomly |

## Explaining Terms

On first appearance in recap history, explain the term inline:

```
Jeremy completed 13 OICs (Original Investment Cases — structured
documents capturing thesis, evidence, and conviction level for each stock).
```

After first explanation, use the term freely. Track explained terms in `docs/recaps/glossary.json` to avoid re-explaining in future recaps.

## Transforming Evidence into Narrative

Evidence files contain structured data. The recap transforms this into prose that tells a story.

**Evidence file:**
```
| 6857-JP | Advantest | COMPLETE | VERY HIGH |
Thesis: AI testing pureplay, 59% SoC share, AB never broke
```

**Recap:**
```
Advantest makes the equipment that tests AI chips — every chip NVIDIA
ships gets tested on their machines. They have 59% market share in SoC
testing. The thesis: analysts are stuck in a "semiconductor cycle"
mental model, treating Advantest as cyclical when it's actually an AI
infrastructure pureplay.
```

The transformation:
1. Start with what the company does (context)
2. Add the key fact that makes it interesting
3. Explain the thesis in plain terms
4. Skip the jargon codes (COMPLETE, VERY HIGH) — convey meaning instead

## Curation

Not everything deserves equal space. Claude has discretion to:

- Give more space to what matters most this period
- Skip routine updates that don't add insight
- Put technical details in the appendix
- Choose structure (by-workstream vs by-theme) based on content

The goal is insight, not comprehensive coverage.

## Final Check

Before sending, verify:

- [ ] Opening paragraph provides 10-second orientation
- [ ] No superlatives or hype language
- [ ] Terms explained on first use (check glossary)
- [ ] Specific numbers, not vague counts
- [ ] Active voice throughout
- [ ] "So what" clear for key items
- [ ] British spelling
- [ ] No bold, no headers, no em-dashes

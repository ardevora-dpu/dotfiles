# Output Format

The recap is delivered as an HTML email via MS365 MCP.

**What gets saved:**
- `docs/recaps/{date}/evidence/*.md` — Evidence files from sub-agents (kept forever for audit)
- `docs/recaps/{date}/final.md` — The recap body that was emailed (serves as previous recap reference)
- `docs/recaps/{date}/manifest.json` — Metadata about sources, date range, terms explained
- `docs/recaps/glossary.json` — Cross-recap term tracking (updated after each recap)

## Typography

Follow the recap typography rules:

- **Font:** Calibri 11pt (Outlook default)
- **Bold:** Never — maintain uniform typographic texture
- **Headers:** Never — structure comes from paragraph logic, not visual formatting
- **Italics:** Maximum one per email, for unusual emphasis only
- **Em-dashes:** Never — use regular dashes or parentheses

## Structure

```
[Opening paragraph — 10-second orientation]

[Body paragraphs — prose with logical breaks between topics]

[Appendix — OPTIONAL, snappy bullets for technical details by domain]

---
Sent via Claude Code (MS365 MCP)
```

**The appendix is optional.** Use it when there are technical details or metrics that matter for the record but would interrupt narrative flow. For shorter weekly recaps with limited technical content, skip the appendix entirely.

### Opening Paragraph

The first paragraph answers:
- What happened (velocity signal)
- Why it matters (so what)
- What we're moving towards (direction)

This is the "10-second orientation" — an expert should be able to scan this and know what the recap covers.

### Body

Prose paragraphs grouped by topic. New paragraph when the argument shifts (e.g., from findings to implications, or from one workstream to another).

No headers. Structure comes from:
- Paragraph breaks
- Topic sentences
- Logical flow

### Appendix

For technical details that matter but would interrupt the narrative flow.

**Bullets are allowed in the appendix** (unlike the main body, which should stay prose-first unless structure genuinely needs bullets). The appendix is a special section for technical details where bullets aid scannability.

Format options:

```
---

Platform: 76 PRs merged, monitoring dashboard shipped, chat sync to Neon complete.
Investment: 13 cases completed (4 high conviction), Three-Leg Validation framework codified.
Legal: FCA application submitted, Capricorn onboarding complete, LEI received.
```

Or with bullets when there are multiple items per workstream:

```
---

Platform:
- 76 PRs merged
- Monitoring dashboard shipped
- Chat sync to Neon complete

Investment:
- 13 cases completed (4 high conviction)
- Three-Leg Validation framework codified
```

Use this for:
- Counts and metrics
- Technical deliverables list
- Items that need to be recorded but don't need narrative explanation

## Length

| Type | Guidance |
|------|----------|
| Weekly | Shorter — hit the highlights, 3-5 body paragraphs |
| Monthly | Longer — more context, more depth, 8-12 body paragraphs |
| Custom (YTD, etc.) | Match length to content — as long as it needs to be |

## Email Metadata

When sending via MS365 MCP:

- **Subject:** "What We Did — [Date Range]" (e.g., "What We Did — January 2026")
- **To:** Jeremy, Jack, Timon, Aisling, Helen, Bill
- **Format:** HTML

## Footer

Always append:

```
---
Sent via Claude Code (MS365 MCP)
```

# Example: ARD-157 Broker Coverage Audit

This email went through 10 iterations before reaching this final form. It demonstrates all the principles in the email-style skill.

## The Final Email

**Subject:** ARD-157: Bloomberg vs AlphaSense broker coverage audit
**To:** Jeremy Lang
**CC:** Jack Algeo

---

Jeremy,

AlphaSense has equivalent broker coverage to Bloomberg. The only material gap is historical depth.

The original concern that Wells Fargo and Barclays were missing is incorrect. Both are present and are strategic investors in the platform. Goldman Sachs, Morgan Stanley, Citi, BofA, Cowen, and Bernstein also invested in the Series C round (2021). This investor base is significant: it explains why AlphaSense operates through direct partnerships rather than third-party aggregation, and it suggests the major banks have a stake in the platform's success and longevity.

Several exclusive distribution deals affect coverage:

- Citi aftermarket → S&P Global (on AlphaSense, not Bloomberg)
- BofA aftermarket → LSEG/Refinitiv (not Bloomberg)
- Bloomberg Intelligence → Bloomberg only
- Tegus transcripts → AlphaSense only

Bloomberg is missing more bulge bracket aftermarket content than AlphaSense.

The reports that did not surface in LLM searches are present in the platform but not indexed for AI (certain brokers contractually prohibit AI/LLM indexing while still providing the underlying content). Their reports remain accessible via traditional keyword search but will not appear in Smart Search results. AlphaSense does not disclose which brokers impose these restrictions, but we can test individual brokers systematically if needed.

The meaningful gap is historical depth. AlphaSense archives begin in 2009; Bloomberg claims coverage back to approximately 2007. Our Azure backup covers this period. Pre-2009 historical extraction should be prioritised before Bloomberg cancellation.

Timon

---

## Why This Works

### Headline + Journey
- **First sentence** states the takeaway: "AlphaSense has equivalent broker coverage to Bloomberg."
- **Body** walks through evidence: investor base → exclusive deals → AI indexing → historical depth
- **Close** is a statement of intent woven into the final paragraph, not a separate "Next steps:" section

### Typography
- No bold text in the email body
- No headers or numbered sections
- Uniform visual texture throughout

### Bullets Used Correctly
- Only one bullet list, for 4 parallel facts (the exclusive distribution deals)
- Intro sentence before: "Several exclusive distribution deals affect coverage:"
- Arrow notation: `Citi aftermarket → S&P Global`
- Concluding sentence after: "Bloomberg is missing more bulge bracket aftermarket content than AlphaSense."

### Parentheses for Qualifications
- "...not indexed for AI (certain brokers contractually prohibit AI/LLM indexing while still providing the underlying content)."
- Keeps the main clause clean while adding supporting detail inline

### Voice
- Analytical observer: "The original concern...is incorrect", "This investor base is significant"
- No "I found" or "We discovered"

### Warmth
- Opens with just "Jeremy," — no "Hope you're well"
- Closes with just "Timon" — no "Best regards" or "Thanks"

## What Failed in Earlier Drafts

| Draft | Problem | Lesson |
|-------|---------|--------|
| 1 | Tables for everything, bold headers, numbered sections | Felt like a report, not an email |
| 2 | "Short version:" and "The interesting finding" labels | Just write the short version first |
| 3 | Very casual tone | Lost information density |
| 4-5 | Tables without bold | Still ugly structure |
| 6 | Georgia font | Looked "literary"/italic in dark mode |
| 7-9 | Incremental fixes | Font → Calibri, parentheses for qualifications |
| 10 | Final | All principles applied |

# Workstream Mapping

Rules for attributing Linear issues, Git commits, and meeting topics to workstreams.

## Workstream Definitions

| Workstream | Description | Key People |
|------------|-------------|------------|
| **Product & Tech** | Data platform, screens, tool development, automation | Timon |
| **Investment** | Stock analysis, positions, regime signals, Jeremy's research | Jeremy |
| **Commercial** | Distribution, revenue modelling, client fees, wealth platforms | Jack, Helen |
| **Legal & Regulatory** | FCA, lawyers, Capricorn, restructuring, compliance | Aisling, Bill |

## Attribution Priority

1. **Linear Label** — Highest priority
2. **Meeting Topic** — For Otter transcripts
3. **Linear Assignee** — Secondary
4. **Git Author** — Fallback for commits
5. **Default** — Commercial (if no other match)

## Linear Labels → Workstream

| Label Pattern | Workstream |
|---------------|------------|
| `platform`, `infra`, `data`, `tooling`, `automation`, `screen` | Product & Tech |
| `research`, `oic`, `regime`, `screening`, `analysis`, `stock` | Investment |
| `distribution`, `revenue`, `client`, `commercial`, `fees` | Commercial |
| `legal`, `regulatory`, `fca`, `compliance`, `restructure`, `capricorn` | Legal & Regulatory |

## Linear Assignees → Workstream

| Assignee | Workstream |
|----------|------------|
| Timon | Product & Tech |
| Jeremy | Investment |
| Jack | Commercial |
| Helen | Commercial |
| Aisling | Legal & Regulatory |
| Bill | Legal & Regulatory |

## Git Authors → Workstream

| Email Pattern | Workstream |
|---------------|------------|
| `t.vanrensburg@*`, `timon@*` | Product & Tech |
| `jeremy@*` | Investment |
| `j.algeo@*`, `jack@*` | Commercial |
| `*@ardevora.com` (fallback) | Commercial |

## Meeting Topic Keywords → Workstream

Used for Otter transcript attribution:

| Keywords | Workstream |
|----------|------------|
| `screen`, `data`, `pipeline`, `platform`, `tool`, `claude` | Product & Tech |
| `stock`, `regime`, `position`, `research`, `OIC`, `signal` | Investment |
| `AMC`, `UBS`, `fees`, `revenue`, `platform`, `distribution`, `client` | Commercial |
| `FCA`, `Capricorn`, `lawyer`, `Taylor`, `MHA`, `restructure`, `compliance` | Legal & Regulatory |

Note: "platform" is ambiguous — use context (tech vs wealth platform).

## Dedupe Rules

### Issue ↔ Commit Linking

Commits that reference Linear issues (e.g., `ARD-123`) are attributed to the issue's workstream, not the author's default.

```
Commit: "fix: resolve data gap in SPG loader (ARD-145)"
        └─→ Look up ARD-145 → Product & Tech label → Product & Tech workstream
```

### Avoiding Double-Counting

When a commit references an issue:
- Show the issue in its workstream section
- Do NOT also show the commit separately
- Commit details appear as sub-items under the issue

### Orphan Commits

Commits without issue references:
- Attribute by author pattern
- Group under "Other commits" subsection

## Multi-Workstream Items

Some items span workstreams. Rules:

1. **Primary label wins** — If issue has both labels, use first applied
2. **Cross-reference** — Mention in secondary workstream with "See also: Product & Tech"
3. **Don't duplicate** — Never show full item in multiple sections

## Example: Weekly Meeting Attribution

A typical weekly meeting may touch all four workstreams:

```
[Otter] - Weekly meeting - 2026-01-27

Topics discussed:
├── UBS AMC setup, fees → Commercial
├── FCA application status → Legal & Regulatory
├── Capital restructuring → Legal & Regulatory
├── Wealth platform exploration (7IM, Fnz) → Commercial
├── Revenue dashboard (Jack) → Commercial
└── Screen environment for Jeremy → Product & Tech
```

The sub-agent processing the transcript should tag each topic with its workstream.

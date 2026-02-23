# Email Privacy

Rules for handling email content in the weekly recap.

## Core Principle

**Metadata-first, content-on-approval, no persistence.**

Email content is sensitive. The recap workflow enforces explicit user consent at each step.

## Enforced Flow

### 1. Scan Phase

Call `mcp__ms365__list-mail-folder-messages` to retrieve **metadata only**:
- From address
- To addresses
- Subject line
- Date/time
- Has attachments (boolean)

**No content fetched** at this stage.

### 2. Present Phase

Show user a summary via AskUserQuestion:

```markdown
I found emails from the past 7 days:

| Category | Count | Sample Senders |
|----------|-------|----------------|
| Internal (@ardevora.com) | 23 | Jeremy, Jack, Aisling |
| Investors | 4 | john@capitalfund.com |
| Vendors | 8 | support@otter.ai, noreply@linear.app |
| Newsletters | 31 | (various) |

Which should I include in the recap?
```

### 3. Approve Phase

User explicitly selects categories or specific senders.

**Default: none selected** (opt-in, not opt-out)

Options:
- [ ] Internal
- [ ] Investors
- [ ] Vendors
- [ ] None (skip email section)

### 4. Fetch Phase

Only after approval, call `mcp__ms365__get-mail-message` for selected items.

- Content loaded into memory
- **Never written to disk**
- Process immediately, discard after recap generation

### 5. Redaction Phase

Before including email content in recap:

1. **Strip signatures** — Remove email signature blocks
2. **Remove reply chains** — Exclude quoted previous messages
3. **Summarise** — Do not copy verbatim; synthesise key points
4. **Anonymise if requested** — Replace names/companies if sensitive

### 6. Send Confirmation

Before `mcp__ms365__send-mail` executes:

```markdown
Ready to send this recap to:
- jeremy@ardevora.com
- jack@ardevora.com
- timon@ardevora.com
- aisling@ardevora.com
- helen@ardevora.com
- bill@ardevora.com

Send now?
```

Must receive explicit "yes" — no auto-send.

## Category Definitions

| Category | Domain Patterns | Example Senders |
|----------|-----------------|-----------------|
| **Internal** | `*@ardevora.com` | Team members |
| **Investors** | Configured list of investor domains | Capital allocators |
| **Vendors** | `*@linear.app`, `*@otter.ai`, `*@snowflake.com` | Service providers |
| **Newsletters** | `*@substack.com`, `noreply@*`, `newsletter@*` | Automated sends |
| **Other** | Everything else | Ad-hoc correspondence |

## What NOT to Include

Never include in recap:

- **Personal emails** — Non-work correspondence
- **HR/legal sensitive** — Compensation, legal matters, personnel issues
- **Client confidential** — Detailed investment positions, proprietary data
- **Attachments** — Never summarise attachment contents
- **Credentials** — Any email containing passwords, tokens, keys

## Handling Flags

If email subject or body contains these patterns, flag for manual review:

- `CONFIDENTIAL`
- `PRIVILEGED`
- `DO NOT FORWARD`
- `INTERNAL ONLY`
- `[SENSITIVE]`

Show user: "This email is marked [FLAG]. Include anyway?"

## No Persistence

Email content must never be:
- Written to any file
- Stored in state file
- Logged to console
- Cached between sessions

The only persistent record is the recap email itself, which is sent to approved recipients.

## Audit Trail

The recap footer includes:
- Number of emails reviewed (metadata)
- Number of emails included (with approval)
- Categories included

Example:
```
Sources:
- Email: 12 threads included (Internal, Investors) from 47 reviewed
```

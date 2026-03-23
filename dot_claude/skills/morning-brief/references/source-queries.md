# Source Reference

Non-obvious identifiers, quirks, and custom tooling that agents can't discover from MCP tool descriptions alone. For standard tools (gh, Linear MCP, Otter MCP, Snowflake MCP), the agent should explore the tool interface directly.

## Team

| Person | Email | Role |
|--------|-------|------|
| Timon | t.vanrensburg@ardevora.com | Developer / Deputy CIO |
| Jeremy | j.lang@ardevora.com | PM / CIO |
| Jack | j.algeo@ardevora.com | COO |
| Aisling | a.mcguire@ardevora.com | Operations |
| Helen | h.spear@ardevora.com | Governance / Legal |
| William (Bill) | w.pattisson@ardevora.com | Investor / Non-exec |

## Linear

- Team UUID: `2d73c05d-4229-4298-9697-ee123d911d3b`
- State filter uses **name strings**: `In Progress`, `Todo`, `Backlog`, `Done`, `In Review`, `Canceled` — not type enums
- `get_issue` requires UUID, not identifier like "ARD-451"

## Outlook — Folder IDs

| Folder | ID |
|--------|-----|
| Broker Notes | `AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQXAAA=` |
| Quant & Data | `AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQUAAA=` |
| Newsletters | `AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQVAAA=` |
| Invoices | `AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYS_lQTAAA=` |
| Platform Alerts | `AAMkADI1ZjMzYjAxLTU1YjgtNGZlNi04OTYzLTJmMGY4ZWJmZTAwNAAuAAAAAAB-MjB7XCnFQoJr4qsvWi3fAQALLRiXQ9E4RrZVqF_1812tAAYVG0pcAAA=` |

## Outlook — Email Move Script

```bash
echo '<json_manifest>' | uv run --group outlook python workspaces/timon/scripts/outlook_move.py
```
Manifest: `[{"messageId":"<id>","destinationFolderId":"<folder_id>"}]`

## Google Workspace CLI (`gws`)

Always prefix with `GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file` for sub-agent credential access. Stderr outputs `Using keyring backend: file` — ignore it, parse stdout.

Shortcuts: `gws gmail +triage`, `gws calendar +agenda`

Laura's calendar ID: `lpmullertz@gmail.com`

## Neon

Query via `psycopg` using `DATABASE_URL`. Do not use MCP.

Key views:
| View | Purpose |
|------|---------|
| `chat_root_sessions_agent_v` | Root session overview (all users) |
| `chat_session_nodes_agent_v` | Per-session detail (subagent trees) |
| `chat_user_prompts_agent_v` | User prompts (what people typed) |
| `chat_tool_calls_agent_v` | Tool usage (tool names, SQL, paths) |
| `chat_sync_freshness_v` | Sync freshness — check `is_current` before drawing conclusions |

Session time columns: `started_at` (sessions), `activity_at` (root sessions).

Jeremy ticker extraction uses cwd path regex: `E'\\\\([A-Z0-9]+-[A-Z]{2})\\\\'`

## Otter

Date format is `YYYY/MM/DD` (slashes, not ISO). Transcripts are large (~80K chars) — process in the sub-agent.

## MS365 MCP Gotchas

- **Teams**: `list-chats` does not support `orderby`. `list-chat-messages` does not support `select`. Filter and sort client-side.
- **MS To Do**: `list-todo-tasks` does not support `select` parameter (400 error). Fetch full objects, filter client-side.

## Quota

```bash
uv run python scripts/dev/claude-usage.py
```

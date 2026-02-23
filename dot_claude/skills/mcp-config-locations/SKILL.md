---
name: mcp-config-locations
description: Quick reference for MCP server configuration locations across CLI tools (Claude Code, Codex, Gemini)
---

# MCP Configuration Locations

This skill provides quick reference for where MCP servers are configured across different AI CLI tools.

## Config File Locations

| CLI Tool | Config Path | Format |
|----------|-------------|--------|
| **Claude Code** | `~/.claude.json` | JSON (`mcpServers` key) |
| **Codex** | `~/.codex/config.toml` | TOML (`[mcp_servers.*]` sections) |
| **Gemini** | `~/.gemini/settings.json` | JSON (`mcpServers` key) |

## Adding an MCP Server

### Claude Code (~/.claude.json)
```json
{
  "mcpServers": {
    "server-name": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "package-name"],
      "env": {}
    }
  }
}
```

### Codex (~/.codex/config.toml)
```toml
[mcp_servers.server-name]
command = "npx"
args = ["-y", "package-name"]

[mcp_servers.server-name.env]
API_KEY = "value"
```

### Gemini (~/.gemini/settings.json)
```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "package-name"],
      "env": {}
    }
  }
}
```

## Currently Configured Servers

Servers shared across all CLIs (Windows native):
- **linear** - Linear issue tracking
- **snowflake** - Snowflake Labs MCP (local, uses `~/.snowflake/config.toml`)
- **dbt-mcp** - dbt Labs MCP for dbt CLI integration (project exploration, lineage, commands)
- **neon** - Neon Postgres (HTTP-based)

Chrome DevTools MCP is not supported on Windows native; use the Claude for Chrome extension instead.

## Snowflake MCP Setup

The `snowflake-labs-mcp` provides Snowflake integration:

```bash
# Config file: ~/.mcp/snowflake-config.yaml
# Connection: uses ~/.snowflake/config.toml
```

All three CLIs now use identical configuration:
- Command: `uvx --python 3.12 snowflake-labs-mcp`
- Args: `--service-config-file ~/.mcp/snowflake-config.yaml --connection-name <your-connection>`

See `docs/platform/ai/mcp-setup.md` for full setup instructions.

## dbt MCP Setup

The `dbt-mcp` server provides dbt CLI integration:

```bash
# Required environment variables:
DBT_PROJECT_DIR=/path/to/dbt/project    # Contains dbt_project.yml
DBT_PATH=/path/to/dbt/executable         # Output of `which dbt` or `uv run which dbt`
```

All three CLIs use identical configuration:
- Command: `uvx dbt-mcp` (or full path `C:\\Users\\you\\AppData\\Local\\uv\\bin\\uvx.exe`)
- Env: `DBT_PROJECT_DIR`, `DBT_PATH`

**Tools provided:**
- `dbt_build`, `dbt_run`, `dbt_test` - Execute dbt commands
- `get_model_details` - Model info, lineage, dependencies
- `list_models` - List all models in the project

## Notes

- Changes require CLI restart to take effect
- Claude Code also supports project-level MCP in `.mcp.json`

# Converge mcpServers in ~/.claude.json per user profile.
# Uses modify_ script semantics: reads current file from stdin, outputs updated version.
# Only touches mcpServers — all other keys are preserved as-is.
[Console]::In.ReadToEnd() | uv run python -c "import json, os, pathlib, sys

raw = sys.stdin.read()
try:
    data = json.loads(raw)
except (json.JSONDecodeError, ValueError):
    data = {}

if not isinstance(data, dict):
    data = {}

user_file = pathlib.Path.home() / '.quinlan-user'
user = user_file.read_text(encoding='utf-8').strip().lower() if user_file.exists() else 'unknown'
is_timon = user == 'timon'
is_jack = user == 'jack'

# MCP server definitions per user.
servers = {}

if is_timon:
    servers['ms365'] = {
        'type': 'stdio',
        'command': 'cmd',
        'args': [
            '/c', 'npx', '-y', '@softeria/ms-365-mcp-server@0.43.2',
            '--org-mode',
            '--preset', 'mail',
            '--preset', 'calendar',
            '--preset', 'users',
            '--preset', 'contacts',
            '--preset', 'work',
        ],
        'env': {'LOG_LEVEL': 'error'},
    }
    servers['otter'] = {'type': 'http', 'url': 'https://mcp.otter.ai/mcp'}
elif is_jack:
    servers['otter'] = {'type': 'http', 'url': 'https://mcp.otter.ai/mcp'}

# Only set mcpServers for managed profiles.
if is_timon or is_jack:
    data['mcpServers'] = servers

json.dump(data, sys.stdout, indent=2)
sys.stdout.write('\n')
"

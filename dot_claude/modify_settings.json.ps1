# Claude settings convergence policy for Timon + Jeremy.
# ARD451_PROFILE_TIMON, ARD451_PROFILE_JEREMY markers are used by parity checks.
# Uses modify_ script semantics so Claude Code writes outside enforced keys are preserved.
[Console]::In.ReadToEnd() | uv run python -c "import json, os, pathlib, sys

raw = sys.stdin.read()
try:
    data = json.loads(raw)
except (json.JSONDecodeError, ValueError):
    data = {}

if not isinstance(data, dict):
    data = {}

profile = (os.getenv('QUINLAN_SETTINGS_PROFILE') or os.getenv('USERNAME') or '').lower()
is_timon = profile in {'chimern', 'azuread\\\\timonvanrensburg', 'timonvanrensburg'}
is_jeremy = profile in {'jeremy', 'jlang', 'azuread\\\\jeremylang'}

home = pathlib.Path.home().as_posix()
statusline_command = f'bash {home}/.claude/statusline-command.sh'
bash_env = f'{home}/.config/quinlan-shell/bash-env.sh'

# Shared enforced keys (all supported profiles).
data['statusLine'] = {'type': 'command', 'command': statusline_command}
env_block = data.get('env', {})
if not isinstance(env_block, dict):
    env_block = {}
env_block['BASH_ENV'] = bash_env
env_block['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'] = '1'
data['env'] = env_block

if is_timon:
    # ARD451_PROFILE_TIMON
    data['autoUpdatesChannel'] = 'latest'
    data['model'] = 'opus'
    plugins = data.get('enabledPlugins', [])
    if not isinstance(plugins, list):
        plugins = []
    if 'pyright-lsp' not in plugins:
        plugins.append('pyright-lsp')
    data['enabledPlugins'] = plugins
elif is_jeremy:
    # ARD451_PROFILE_JEREMY
    data['autoUpdatesChannel'] = 'stable'
else:
    # Non-target profiles keep automatic updates conservative by default.
    data.setdefault('autoUpdatesChannel', 'stable')

json.dump(data, sys.stdout, indent=2)
sys.stdout.write('\n')
"

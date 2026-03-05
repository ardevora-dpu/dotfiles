# Claude settings convergence policy for Timon + Jeremy + Jack.
# ARD451_PROFILE_TIMON, ARD451_PROFILE_JEREMY, ARD507_PROFILE_JACK markers are used by parity checks.
# Uses modify_ script semantics so Claude Code writes outside enforced keys are preserved.
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
is_jeremy = user == 'jeremy'
is_jack = user == 'jack'

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
elif is_jack:
    # ARD507_PROFILE_JACK
    data['autoUpdatesChannel'] = 'stable'
else:
    # Non-target profiles keep automatic updates conservative by default.
    data.setdefault('autoUpdatesChannel', 'stable')

json.dump(data, sys.stdout, indent=2)
sys.stdout.write('\n')
"

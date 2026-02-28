# Ensure autoUpdatesChannel is "latest" for Timon.
# Jeremy stays on stable (his machine doesn't use chezmoi).
# Uses modify_ script so Claude Code's own writes to settings.json are preserved.
[Console]::In.ReadToEnd() | uv run python -c "import json,sys; d=json.load(sys.stdin); d['autoUpdatesChannel']='latest'; json.dump(d,sys.stdout,indent=2); print()"

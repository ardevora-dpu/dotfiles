# Parity Check Phase

Use inline reasoning (not a standalone script) to verify settings parity policy.

## Inputs

- Dotfiles modify template: `~/.local/share/chezmoi/dot_claude/modify_settings.json.ps1`
- Identity source contract: `~/.quinlan-user`
- Backup filter contract: `scripts/backup/claude-backup.cmd`

## Checks

1. `modify_settings.json.ps1` reads `~/.quinlan-user` and branches on `timon` / `jeremy`.
2. Shared enforced keys are present:
- `statusLine`
- `env.BASH_ENV`
- `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`
3. Timon-only keys present:
- `autoUpdatesChannel=latest`
- `model=opus`
- `enabledPlugins` includes `pyright-lsp`
4. Jeremy-only keys present:
- `autoUpdatesChannel=latest`
5. Backup script includes:
- `settings.json`
- `settings.local.json`

## Output format

Write `$ARTIFACT_DIR/parity-summary.json`:

```json
{
  "status": "pass|warn|fail",
  "blocking": [],
  "informational": []
}
```

Treat intentional Timon/Jeremy divergence as informational, not blocking.

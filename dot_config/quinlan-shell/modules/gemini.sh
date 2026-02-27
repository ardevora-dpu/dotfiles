# Timon-only Gemini CLI launcher.
#
# Gemini CLI on Windows hardcodes powershell.exe (5.1) for its shell tool,
# which breaks on modern PowerShell syntax (e.g. &&). Setting COMSPEC to
# pwsh.exe makes Gemini use PowerShell 7 instead.
#
# MSYS2 gotcha: mixed-case "ComSpec" inline prefix does NOT override the
# Windows-level env var for native child processes. All-uppercase "COMSPEC"
# does, because MSYS2 treats it as a case-insensitive match.
# Tracking: https://github.com/google-gemini/gemini-cli/issues/15493

_QUINLAN_PWSH_PATH="C:/Program Files/PowerShell/7/pwsh.exe"

g() {
    if [[ ! -x "$_QUINLAN_PWSH_PATH" ]]; then
        echo "[gemini] PowerShell 7 not found: $_QUINLAN_PWSH_PATH" >&2
        echo "[gemini] Install via: winget install Microsoft.PowerShell" >&2
        return 1
    fi

    if ! command -v gemini >/dev/null 2>&1; then
        echo "[gemini] Gemini CLI not found on PATH." >&2
        echo "[gemini] Install via: npm install -g @google/gemini-cli" >&2
        return 1
    fi

    COMSPEC="$_QUINLAN_PWSH_PATH" gemini "$@"
}

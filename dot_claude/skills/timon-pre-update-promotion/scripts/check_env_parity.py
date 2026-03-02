#!/usr/bin/env python3
"""Environment parity checks for Timon pre-/update promotion."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any


DOTFILES_ROOT = Path(__file__).resolve().parents[4]
MODIFY_SCRIPT = DOTFILES_ROOT / "dot_claude" / "modify_settings.json.ps1"
CHEZMOI_IGNORE = DOTFILES_ROOT / ".chezmoiignore.tmpl"
STATUSLINE_SCRIPT = DOTFILES_ROOT / "dot_claude" / "statusline-command.sh"


def _normalise_username(raw: str) -> str:
    return (raw or "").strip().lower()


def _deep_get(data: dict[str, Any], key_path: str) -> Any:
    current: Any = data
    for part in key_path.split("."):
        if not isinstance(current, dict) or part not in current:
            return None
        current = current[part]
    return current


def _build_profile_settings(home: str, profile: str) -> dict[str, Any]:
    shared = {
        "statusLine.type": "command",
        "statusLine.command": f"bash {home}/.claude/statusline-command.sh",
        "env.BASH_ENV": f"{home}/.config/quinlan-shell/bash-env.sh",
        "env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    }
    if profile == "timon":
        return {
            **shared,
            "autoUpdatesChannel": "latest",
            "model": "opus",
            "enabledPlugins": ["pyright-lsp"],
        }
    return {
        **shared,
        "autoUpdatesChannel": "stable",
    }


def _check_template_contract(blocking: list[str], informational: list[str]) -> None:
    if not MODIFY_SCRIPT.exists():
        blocking.append(f"Missing settings modify template: {MODIFY_SCRIPT}")
        return

    modify_text = MODIFY_SCRIPT.read_text(encoding="utf-8")
    if "ARD451_PROFILE_TIMON" not in modify_text:
        blocking.append("modify_settings template is missing ARD451_PROFILE_TIMON marker")
    if "ARD451_PROFILE_JEREMY" not in modify_text:
        blocking.append("modify_settings template is missing ARD451_PROFILE_JEREMY marker")

    if not CHEZMOI_IGNORE.exists():
        blocking.append(f"Missing chezmoi ignore template: {CHEZMOI_IGNORE}")
    else:
        ignore_text = CHEZMOI_IGNORE.read_text(encoding="utf-8")
        if "$isJeremy" not in ignore_text:
            blocking.append(".chezmoiignore.tmpl is missing $isJeremy gate")

    if not STATUSLINE_SCRIPT.exists():
        blocking.append(f"Missing statusline script template: {STATUSLINE_SCRIPT}")

    if STATUSLINE_SCRIPT.exists() and not os.access(STATUSLINE_SCRIPT, os.X_OK):
        informational.append("statusline-command.sh is not executable in dotfiles source")


def _check_policy_alignment(blocking: list[str], informational: list[str]) -> None:
    placeholder_home = "${HOME}"
    timon = _build_profile_settings(placeholder_home, "timon")
    jeremy = _build_profile_settings(placeholder_home, "jeremy")

    shared_keys = [
        "statusLine.type",
        "statusLine.command",
        "env.BASH_ENV",
        "env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS",
    ]
    for key in shared_keys:
        if timon.get(key) != jeremy.get(key):
            blocking.append(f"Shared setting '{key}' diverges between Timon and Jeremy profiles")

    informational.append(
        "Intentional divergence: autoUpdatesChannel (Timon=latest, Jeremy=stable)"
    )
    informational.append("Intentional divergence: model pinned for Timon only")
    informational.append("Intentional divergence: pyright-lsp plugin enabled for Timon only")


def _check_live_timon_settings(blocking: list[str], informational: list[str]) -> None:
    username = _normalise_username(os.getenv("USERNAME", ""))
    is_timon = username in {"chimern", "azuread\\timonvanrensburg", "timonvanrensburg"}
    if not is_timon:
        informational.append("Live Timon settings check skipped (current user is not Timon profile)")
        return

    settings_path = Path.home() / ".claude" / "settings.json"
    if not settings_path.exists():
        informational.append(f"Live settings file not found: {settings_path}")
        return

    try:
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        blocking.append(f"Live settings JSON is invalid: {settings_path}")
        return

    expected = _build_profile_settings(Path.home().as_posix(), "timon")
    for key in [
        "statusLine.type",
        "statusLine.command",
        "env.BASH_ENV",
        "env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS",
        "autoUpdatesChannel",
    ]:
        value = _deep_get(settings, key)
        if value != expected[key]:
            blocking.append(
                f"Live Timon settings mismatch for '{key}' (expected '{expected[key]}', got '{value}')"
            )


def run_checks() -> dict[str, Any]:
    blocking: list[str] = []
    informational: list[str] = []

    _check_template_contract(blocking, informational)
    _check_policy_alignment(blocking, informational)
    _check_live_timon_settings(blocking, informational)

    status = "pass"
    if blocking:
        status = "fail"
    elif informational:
        status = "warn"

    return {
        "status": status,
        "blocking": blocking,
        "informational": informational,
    }


def _print_text(payload: dict[str, Any]) -> None:
    print(f"Parity status: {payload['status']}")
    if payload["blocking"]:
        print("Blocking findings:")
        for item in payload["blocking"]:
            print(f"- {item}")
    if payload["informational"]:
        print("Informational findings:")
        for item in payload["informational"]:
            print(f"- {item}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Check Timon/Jeremy settings parity contract.")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Return non-zero if blocking findings are present.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    payload = run_checks()

    if args.format == "json":
        print(json.dumps(payload, indent=2))
    else:
        _print_text(payload)

    if args.strict and payload["blocking"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

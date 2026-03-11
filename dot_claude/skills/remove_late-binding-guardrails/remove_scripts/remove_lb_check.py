#!/usr/bin/env python3
"""
Late-binding quick checks.

Scans changed files for catastrophic late-binding violations.
Intentionally simple and low false-positive.

Usage:
    uv run python .claude/skills/late-binding-guardrails/scripts/lb_check.py
    uv run python .claude/skills/late-binding-guardrails/scripts/lb_check.py --base origin/main
    uv run python .claude/skills/late-binding-guardrails/scripts/lb_check.py --all  # scan all files

Exit codes:
    0: No P1 findings
    1: P1 findings present (blocking)
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass
class Finding:
    severity: str  # P1, P2, P3
    path: str
    line: int | None
    title: str
    body: str


def run(cmd: list[str]) -> str:
    """Run a command and return stdout."""
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except subprocess.CalledProcessError:
        return ""


def get_changed_files(base: str) -> list[str]:
    """Get list of changed files relative to base."""
    # Try the specified base
    out = run(["git", "diff", "--name-only", f"{base}...HEAD"])
    if out:
        return [p for p in out.splitlines() if p]

    # Fallback: compare to HEAD~1
    out = run(["git", "diff", "--name-only", "HEAD~1"])
    if out:
        return [p for p in out.splitlines() if p]

    # Fallback: staged files
    out = run(["git", "diff", "--name-only", "--cached"])
    return [p for p in out.splitlines() if p]


def get_all_tracked_files() -> list[str]:
    """Get all tracked files in the repo."""
    out = run(["git", "ls-files"])
    return [p for p in out.splitlines() if p]


def scan_file(path: Path) -> list[Finding]:
    """Scan a single file for late-binding violations."""
    try:
        txt = path.read_text(errors="ignore")
    except Exception:
        return []

    lines = txt.splitlines()
    findings: list[Finding] = []

    # === P1: Catastrophic violations ===

    # Overwriting a JSONL ledger (destroys history)
    if "ledger.jsonl" in txt or "ledger.json" in txt:
        for i, line in enumerate(lines, 1):
            # Match: open("...ledger.jsonl", "w") or mode="w"
            if re.search(r'open\([^)]*ledger[^)]*,\s*["\']w["\']', line):
                findings.append(
                    Finding(
                        severity="P1",
                        path=str(path),
                        line=i,
                        title="Ledger overwritten in-place",
                        body='Found open(..., "w") on ledger file. This destroys history. Use append mode ("a") or append-only event patterns.',
                    )
                )
            # Match: mode="w" in same line as ledger
            if "ledger" in line.lower() and re.search(r'mode\s*=\s*["\']w["\']', line):
                findings.append(
                    Finding(
                        severity="P1",
                        path=str(path),
                        line=i,
                        title="Ledger overwritten in-place",
                        body='Found mode="w" with ledger file. This destroys history. Use append mode ("a").',
                    )
                )

    # Direct DELETE/UPDATE on ledger tables (SQL)
    if path.suffix == ".sql":
        for i, line in enumerate(lines, 1):
            # Heuristic: DELETE FROM or UPDATE on ledger-like tables
            # Tightened to avoid false positives on "event_date" or non-ledger tables
            lower = line.lower()
            if "delete from" in lower or "update " in lower:
                # "ledger" is specific enough
                # For events, require table-name patterns: _events, events_, event_log
                is_ledger_table = "ledger" in lower
                is_events_table = (
                    "_events" in lower  # suffix: audit_events
                    or "events_" in lower  # prefix: events_log
                    or "event_log" in lower  # common pattern
                )
                if is_ledger_table or is_events_table:
                    findings.append(
                        Finding(
                            severity="P1",
                            path=str(path),
                            line=i,
                            title="Mutable operation on event table",
                            body="DELETE/UPDATE on ledger or events table. Append new events instead of mutating.",
                        )
                    )

    # === P2: Implicit context smells ===

    # Global mutable state like current_ticker, current_user
    implicit_context_pattern = re.compile(
        r"\b(current_ticker|current_user|current_workspace|CURRENT_TICKER|CURRENT_USER)\b"
    )
    has_scope = "scope" in txt.lower() or "Scope" in txt

    for i, line in enumerate(lines, 1):
        if implicit_context_pattern.search(line):
            # Only flag if there's no "scope" in the file (reduces false positives)
            if not has_scope:
                findings.append(
                    Finding(
                        severity="P2",
                        path=str(path),
                        line=i,
                        title="Possible implicit context",
                        body="Found global context variable without explicit Scope. Consider threading scope explicitly.",
                    )
                )
                break  # One warning per file is enough

    # === P2: Missing actor tracking ===

    # If file writes to ledger but doesn't reference "actor"
    if path.suffix == ".py":
        writes_ledger = any(
            "ledger" in line.lower() and ("write" in line.lower() or "append" in line.lower())
            for line in lines
        )
        has_actor = "actor" in txt

        if writes_ledger and not has_actor:
            findings.append(
                Finding(
                    severity="P2",
                    path=str(path),
                    line=None,
                    title="Ledger write without actor tracking",
                    body="File writes to ledger but doesn't reference 'actor'. Events should include who performed the action.",
                )
            )

    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Late-binding quick checks")
    parser.add_argument(
        "--base",
        default="origin/main",
        help="Git ref to compare against (default: origin/main)",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Scan all tracked files, not just changed ones",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output JSON only (no summary text)",
    )
    args = parser.parse_args()

    # Get files to scan
    if args.all:
        file_paths = get_all_tracked_files()
    else:
        file_paths = get_changed_files(args.base)

    # Filter to relevant file types
    relevant_suffixes = {".py", ".ts", ".tsx", ".sql", ".js", ".jsx"}
    files = [
        Path(p)
        for p in file_paths
        if Path(p).exists() and Path(p).suffix in relevant_suffixes
    ]

    # Scan
    all_findings: list[Finding] = []
    for f in files:
        all_findings.extend(scan_file(f))

    # Build report
    report = {
        "tool": "late_binding_check",
        "files_scanned": len(files),
        "findings": [asdict(f) for f in all_findings],
        "summary": {
            "p1_count": sum(1 for f in all_findings if f.severity == "P1"),
            "p2_count": sum(1 for f in all_findings if f.severity == "P2"),
            "p3_count": sum(1 for f in all_findings if f.severity == "P3"),
        },
    }

    # Output
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(json.dumps(report, indent=2))
        print()

        if not all_findings:
            print("✓ No late-binding violations found")
        else:
            p1_count = report["summary"]["p1_count"]
            p2_count = report["summary"]["p2_count"]

            if p1_count:
                print(f"✗ {p1_count} P1 (blocking) finding(s)")
            if p2_count:
                print(f"⚠ {p2_count} P2 (warning) finding(s)")

    # Exit code
    has_p1 = report["summary"]["p1_count"] > 0
    return 1 if has_p1 else 0


if __name__ == "__main__":
    raise SystemExit(main())

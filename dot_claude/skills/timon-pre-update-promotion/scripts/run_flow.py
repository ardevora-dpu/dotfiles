#!/usr/bin/env python3
"""Run Timon's pre-/update promotion workflow."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path


CHECKPOINT_REF = "origin/jeremy/checkpoints/live"
SIM_REPORT_MARKER = "[update-guard] simulation report:"


class WorkflowError(RuntimeError):
    pass


@dataclass(slots=True)
class CommandResult:
    command: list[str]
    returncode: int
    stdout: str
    stderr: str


@dataclass(slots=True)
class ValidationResult:
    ok: bool
    detail: str


def _run(
    command: list[str],
    *,
    cwd: Path,
    check: bool = True,
) -> CommandResult:
    proc = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )
    result = CommandResult(
        command=command,
        returncode=proc.returncode,
        stdout=proc.stdout or "",
        stderr=proc.stderr or "",
    )
    if check and proc.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise WorkflowError(f"Command failed ({proc.returncode}): {' '.join(command)}\n{detail}")
    return result


def _run_git(repo_root: Path, *args: str, check: bool = True) -> CommandResult:
    return _run(["git", *args], cwd=repo_root, check=check)


def _parse_report_path(text: str) -> Path:
    for line in text.splitlines():
        if SIM_REPORT_MARKER in line:
            return Path(line.split(SIM_REPORT_MARKER, 1)[1].strip())
    raise WorkflowError("Could not find simulation report path in CLI output")


def _ensure_clean_tracked_worktree(repo_root: Path) -> None:
    tracked = _run_git(repo_root, "status", "--porcelain", "--untracked-files=no")
    if tracked.stdout.strip():
        raise WorkflowError(
            "Tracked changes detected in quinlan worktree. Commit or stash changes before promotion."
        )


def _run_simulation(repo_root: Path) -> tuple[dict, Path, CommandResult]:
    result = _run(
        [
            "uv",
            "run",
            "python",
            "-m",
            "research.update_guard.cli",
            "simulate",
            "--user",
            "jeremy",
            "--strict",
        ],
        cwd=repo_root,
        check=False,
    )

    output = "\n".join(part for part in [result.stdout, result.stderr] if part.strip())
    report_path = _parse_report_path(output)
    payload = json.loads(report_path.read_text(encoding="utf-8"))
    return payload, report_path, result


def _promotion_candidates(report: dict) -> list[str]:
    promotion = report.get("promotion_report", {})
    shared = promotion.get("shared_runtime", [])
    platform = promotion.get("platform", [])
    return sorted({*shared, *platform})


def _blocked_samples(report: dict) -> list[str]:
    blocked_codes = {
        "unknown_ownership_paths",
        "non_bisynced_user_paths",
        "checkpoint_scope_drift",
    }
    blocked: set[str] = set()
    for discrepancy in report.get("discrepancies", []):
        if discrepancy.get("code") in blocked_codes:
            blocked.update(discrepancy.get("samples", []))
    return sorted(blocked)


def _ref_has_path(repo_root: Path, ref: str, rel_path: str) -> bool:
    result = _run_git(repo_root, "cat-file", "-e", f"{ref}:{rel_path}", check=False)
    return result.returncode == 0


def _apply_promotable_paths(repo_root: Path, ref: str, paths: list[str]) -> None:
    for rel_path in paths:
        if _ref_has_path(repo_root, ref, rel_path):
            _run_git(repo_root, "checkout", ref, "--", rel_path)
            continue

        _run_git(repo_root, "rm", "-f", "--ignore-unmatch", "--", rel_path, check=False)
        local_path = repo_root / rel_path
        if local_path.is_file():
            local_path.unlink()
        elif local_path.is_dir():
            shutil.rmtree(local_path, ignore_errors=True)

    if paths:
        _run_git(repo_root, "add", "-A", "--", *paths)


def _has_staged_changes(repo_root: Path) -> bool:
    result = _run_git(repo_root, "diff", "--cached", "--quiet", check=False)
    return result.returncode != 0


def _checkout_promotion_branch(repo_root: Path, branch: str) -> None:
    _run_git(repo_root, "fetch", "origin", "main", "--prune")
    _run_git(repo_root, "checkout", "-B", branch, "origin/main")


def _commit_changes(repo_root: Path, report_path: Path) -> str:
    _run_git(
        repo_root,
        "commit",
        "-m",
        "chore(update): pre-/update promotion from Jeremy checkpoint",
        "-m",
        f"Simulation report: {report_path}",
    )
    return _run_git(repo_root, "rev-parse", "HEAD").stdout.strip()


def _build_pr_body(
    *,
    report: dict,
    report_path: Path,
    promotable_paths: list[str],
    blocked_paths: list[str],
    readiness: ValidationResult | None,
    parity: ValidationResult | None,
) -> str:
    discrepancy_lines = []
    for item in report.get("discrepancies", []):
        code = item.get("code", "unknown")
        severity = item.get("severity", "unknown")
        count = item.get("count", 0)
        summary = item.get("summary", "")
        discrepancy_lines.append(f"- `{code}` [{severity}] ({count}): {summary}")

    promoted = "\n".join(f"- `{path}`" for path in promotable_paths[:200])
    blocked = "\n".join(f"- `{path}`" for path in blocked_paths[:200])
    readiness_line = readiness.detail if readiness else "not run"
    parity_line = parity.detail if parity else "not run"

    return "\n".join(
        [
            "## Pre-/update promotion",
            "",
            f"- Simulation report: `{report_path}`",
            f"- Simulation safe verdict: `{report.get('safe')}`",
            f"- Update guard simulation status: `{report.get('update_guard_status')}`",
            "",
            "### Promoted paths (shared/platform only)",
            promoted or "- none",
            "",
            "### Non-promoted paths",
            blocked or "- none",
            "",
            "### Discrepancies",
            "\n".join(discrepancy_lines) or "- none",
            "",
            "### Validation",
            f"- readiness: {readiness_line}",
            f"- parity: {parity_line}",
            "",
            "### Merge gate",
            "- Do not merge without explicit maintainer approval.",
        ]
    )


def _find_existing_pr_number(repo_root: Path, branch: str) -> str:
    result = _run(
        [
            "gh",
            "pr",
            "list",
            "--head",
            branch,
            "--base",
            "main",
            "--json",
            "number",
            "--jq",
            ".[0].number // \"\"",
        ],
        cwd=repo_root,
    )
    return result.stdout.strip()


def _create_or_update_pr(repo_root: Path, *, branch: str, title: str, body: str) -> str:
    existing = _find_existing_pr_number(repo_root, branch)
    if existing:
        _run(["gh", "pr", "edit", existing, "--title", title, "--body", body], cwd=repo_root)
        return existing

    _run(
        [
            "gh",
            "pr",
            "create",
            "--base",
            "main",
            "--head",
            branch,
            "--title",
            title,
            "--body",
            body,
        ],
        cwd=repo_root,
    )
    created = _find_existing_pr_number(repo_root, branch)
    if not created:
        raise WorkflowError("PR create succeeded but PR number could not be resolved")
    return created


def _run_readiness(repo_root: Path) -> ValidationResult:
    result = _run(
        ["uv", "run", "python", "scripts/dev/verify_jeremy_update_readiness.py", "--mode", "pr"],
        cwd=repo_root,
        check=False,
    )
    ok = result.returncode == 0
    if ok:
        return ValidationResult(True, "passed")
    detail = result.stdout.strip() or result.stderr.strip() or "failed"
    return ValidationResult(False, f"failed: {detail}")


def _run_parity_check(dotfiles_root: Path) -> ValidationResult:
    parity_script = (
        dotfiles_root
        / "dot_claude"
        / "skills"
        / "timon-pre-update-promotion"
        / "scripts"
        / "check_env_parity.py"
    )
    result = _run(
        [sys.executable, str(parity_script), "--format", "json", "--strict"],
        cwd=dotfiles_root,
        check=False,
    )

    detail = "passed"
    ok = result.returncode == 0
    if result.stdout.strip():
        try:
            payload = json.loads(result.stdout)
        except json.JSONDecodeError:
            payload = None
        if payload:
            status = payload.get("status", "unknown")
            blocking = len(payload.get("blocking", []))
            info = len(payload.get("informational", []))
            detail = f"status={status}, blocking={blocking}, informational={info}"
    if not ok and detail == "passed":
        detail = result.stderr.strip() or "failed"
    return ValidationResult(ok, detail)


def _merge_pr(repo_root: Path, pr_number: str) -> None:
    _run(["gh", "pr", "merge", pr_number, "--squash", "--admin"], cwd=repo_root)


def _build_jeremy_message(pr_number: str | None, safe: bool, readiness_ok: bool, parity_ok: bool) -> str:
    if not pr_number:
        return "No promotion PR was created. Do not ask Jeremy to run /update yet."

    if safe and readiness_ok and parity_ok:
        return (
            f"Promotion PR #{pr_number} is ready. After merge, message Jeremy: "
            "\"Pre-update promotion is complete; you can run /update now.\""
        )

    return (
        f"Promotion PR #{pr_number} is open but not merge-ready. "
        "Resolve findings before asking Jeremy to run /update."
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run Timon pre-/update promotion workflow.")
    parser.add_argument("--repo-root", default=".", help="Path to quinlan repo root")
    parser.add_argument("--ticket", default="ARD-451", help="Ticket identifier for PR metadata")
    parser.add_argument("--json-out", help="Optional JSON summary path")
    parser.add_argument(
        "--skip-merge",
        action="store_true",
        help="Prepare branch and PR but never merge.",
    )
    parser.add_argument(
        "--approve-merge",
        action="store_true",
        help="Merge automatically after successful checks (explicit approval mode).",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    repo_root = Path(args.repo_root).expanduser().resolve()
    dotfiles_root = Path(__file__).resolve().parents[4]

    if args.skip_merge and args.approve_merge:
        raise SystemExit("--skip-merge and --approve-merge cannot be used together")

    _ensure_clean_tracked_worktree(repo_root)

    report, report_path, simulation_cmd = _run_simulation(repo_root)
    safe = bool(report.get("safe", False))
    promotable_paths = _promotion_candidates(report)
    blocked_paths = _blocked_samples(report)

    timestamp = datetime.now(UTC).strftime("%Y%m%d-%H%M%S")
    branch = f"timon/pre-update-promotion-{timestamp}"
    commit_sha = ""
    pr_number = ""

    readiness = ValidationResult(False, "not run")
    parity = ValidationResult(False, "not run")
    merge_performed = False

    if safe and promotable_paths:
        _checkout_promotion_branch(repo_root, branch)
        _apply_promotable_paths(repo_root, CHECKPOINT_REF, promotable_paths)

        if _has_staged_changes(repo_root):
            commit_sha = _commit_changes(repo_root, report_path)
            _run_git(repo_root, "push", "-u", "origin", branch)

            readiness = _run_readiness(repo_root)
            parity = _run_parity_check(dotfiles_root)

            pr_body = _build_pr_body(
                report=report,
                report_path=report_path,
                promotable_paths=promotable_paths,
                blocked_paths=blocked_paths,
                readiness=readiness,
                parity=parity,
            )
            pr_title = f"{args.ticket}: pre-/update promotion from Jeremy checkpoint"
            pr_number = _create_or_update_pr(repo_root, branch=branch, title=pr_title, body=pr_body)

            if args.approve_merge and readiness.ok and parity.ok and not args.skip_merge:
                _merge_pr(repo_root, pr_number)
                merge_performed = True

    summary = {
        "ticket": args.ticket,
        "safe": safe,
        "simulation_exit": simulation_cmd.returncode,
        "simulation_report": str(report_path),
        "promotion_branch": branch if commit_sha else "",
        "promotion_commit": commit_sha,
        "promotion_pr": pr_number,
        "promotable_paths": promotable_paths,
        "blocked_samples": blocked_paths,
        "readiness": {"ok": readiness.ok, "detail": readiness.detail},
        "parity": {"ok": parity.ok, "detail": parity.detail},
        "merge_performed": merge_performed,
        "jeremy_message": _build_jeremy_message(pr_number or None, safe, readiness.ok, parity.ok),
    }

    print("Pre-/update promotion summary")
    print(f"- safe simulation: {safe}")
    print(f"- simulation report: {report_path}")
    print(f"- promotable paths: {len(promotable_paths)}")
    print(f"- blocked samples: {len(blocked_paths)}")
    print(f"- readiness: {readiness.detail}")
    print(f"- parity: {parity.detail}")
    if pr_number:
        print(f"- promotion PR: #{pr_number}")
    if merge_performed:
        print("- merge: completed")
    elif pr_number:
        print("- merge: pending explicit approval")
    print(f"- operator message: {summary['jeremy_message']}")

    if args.json_out:
        out_path = Path(args.json_out).expanduser().resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    if not safe:
        return 2
    if promotable_paths and commit_sha and (not readiness.ok or not parity.ok):
        return 3
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except WorkflowError as exc:
        print(f"[pre-update-promotion][error] {exc}", file=sys.stderr)
        raise SystemExit(1)

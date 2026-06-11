"""Require changelog entries for release-impacting changes."""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path


CHANGELOG_PATH = "CHANGELOG.md"

RELEASE_IMPACTING_PATHS = {
    "contracts": (
        "smart-contracts/",
    ),
    "deployment-artifacts": (
        "deployments/config/",
        "deployments/schema/",
        "deployments/examples/",
        "deployments/address-books/",
        "docs/deployment.md",
    ),
    "release-artifacts": (
        "release-artifacts/",
    ),
    "release-tooling": (
        ".github/workflows/ci.yml",
        "Makefile",
        "scripts/check.sh",
        "scripts/check.ps1",
        "scripts/generate_release_artifacts.py",
        "scripts/check_abi_compatibility.py",
        "scripts/generate_deployment_manifest.py",
        "scripts/generate_address_books.py",
        "scripts/generate_release_checksums.py",
        "scripts/check_changelog.py",
        "docs/tooling.md",
        "docs/release-policy.md",
    ),
    "release-process": (
        ".github/PULL_REQUEST_TEMPLATE.md",
        "CONTRIBUTING.md",
        "SECURITY.md",
    ),
}

PLACEHOLDER_ENTRIES = {
    "tbd",
    "todo",
    "none",
    "n/a",
    "placeholder",
    "_tbd_",
    "_none_",
}

UNRELEASED_RE = re.compile(r"^##\s+\[?Unreleased\]?\s*$", re.IGNORECASE)
LEVEL_TWO_HEADING_RE = re.compile(r"^##\s+")


class ChangelogError(RuntimeError):
    """Raised when changelog validation cannot continue."""


def git_executable() -> str | None:
    return shutil.which("git")


def normalize_path(path: str) -> str:
    return path.replace("\\", "/").removeprefix("./")


def release_impact_group(path: str) -> str | None:
    normalized = normalize_path(path)
    if normalized == CHANGELOG_PATH:
        return None
    for group, patterns in RELEASE_IMPACTING_PATHS.items():
        for pattern in patterns:
            if pattern.endswith("/") and normalized.startswith(pattern):
                return group
            if normalized == pattern:
                return group
    return None


def release_impacting_files(changed_files: list[str]) -> list[tuple[str, str]]:
    impacted = []
    for changed_file in changed_files:
        group = release_impact_group(changed_file)
        if group is not None:
            impacted.append((normalize_path(changed_file), group))
    return sorted(impacted)


def git_output(repo_root: Path, args: list[str], required: bool = False) -> list[str]:
    git_path = git_executable()
    if git_path is None:
        if required:
            raise ChangelogError("git executable was not found")
        return []
    try:
        result = subprocess.run(
            [git_path, *args],
            cwd=repo_root,
            check=True,
            encoding="utf-8",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        if required:
            raise ChangelogError("git executable was not found") from exc
        return []
    except subprocess.CalledProcessError as exc:
        if required:
            message = exc.stderr.strip() or exc.stdout.strip() or str(exc)
            raise ChangelogError(f"git {' '.join(args)} failed: {message}") from exc
        return []
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def git_single(repo_root: Path, args: list[str]) -> str | None:
    lines = git_output(repo_root, args)
    return lines[0] if lines else None


def collect_changed_files(repo_root: Path, base_ref: str | None) -> list[str]:
    changed: set[str] = set()
    if base_ref:
        changed.update(
            git_output(repo_root, ["diff", "--name-only", f"{base_ref}...HEAD"], required=True)
        )
    else:
        changed.update(git_output(repo_root, ["diff", "--name-only", "HEAD"], required=True))
        changed.update(git_output(repo_root, ["diff", "--name-only", "--cached"], required=True))
        changed.update(
            git_output(repo_root, ["ls-files", "--others", "--exclude-standard"], required=True)
        )
        origin_main = git_single(repo_root, ["rev-parse", "--verify", "origin/main"])
        head = git_single(repo_root, ["rev-parse", "--verify", "HEAD"])
        if origin_main and head and origin_main != head:
            changed.update(
                git_output(
                    repo_root,
                    ["diff", "--name-only", "origin/main...HEAD"],
                    required=True,
                )
            )
    return sorted(normalize_path(path) for path in changed)


def unreleased_section(changelog_text: str) -> list[str]:
    lines = changelog_text.splitlines()
    start_index = None
    for index, line in enumerate(lines):
        if UNRELEASED_RE.match(line.strip()):
            start_index = index + 1
            break
    if start_index is None:
        return []

    section = []
    for line in lines[start_index:]:
        if LEVEL_TWO_HEADING_RE.match(line.strip()):
            break
        section.append(line)
    return section


def unreleased_entries(changelog_text: str) -> list[str]:
    entries = []
    for line in unreleased_section(changelog_text):
        stripped = line.strip()
        if not stripped.startswith("- "):
            continue
        entry = stripped[2:].strip()
        normalized = entry.lower().strip(".")
        if not entry or entry.startswith("<!--"):
            continue
        if normalized in PLACEHOLDER_ENTRIES:
            continue
        if "placeholder" in normalized:
            continue
        entries.append(entry)
    return entries


def validate_changelog_state(
    changed_files: list[str], changelog_text: str | None
) -> tuple[list[str], list[tuple[str, str]]]:
    normalized_changed = [normalize_path(path) for path in changed_files]
    impacted = release_impacting_files(normalized_changed)
    errors = []
    if not impacted:
        return errors, impacted

    if CHANGELOG_PATH not in normalized_changed:
        errors.append(
            f"{CHANGELOG_PATH} must be updated when release-impacting files change"
        )
    if changelog_text is None:
        errors.append(f"{CHANGELOG_PATH} is missing")
        return errors, impacted
    if not unreleased_section(changelog_text):
        errors.append(f"{CHANGELOG_PATH} must contain a '## Unreleased' section")
    if not unreleased_entries(changelog_text):
        errors.append(
            f"{CHANGELOG_PATH} must contain a non-placeholder Unreleased bullet"
        )
    return errors, impacted


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Check changelog coverage for release-impacting changes."
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path.cwd(),
        help="Repository root. Defaults to the current directory.",
    )
    parser.add_argument(
        "--base-ref",
        help="Git ref or SHA to diff against with '<base>...HEAD'.",
    )
    parser.add_argument(
        "--changed-file",
        action="append",
        dest="changed_files",
        default=[],
        help="Explicit changed file for tests or manual checks. May be repeated.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    repo_root = args.repo_root.resolve()

    try:
        changed_files = (
            sorted(normalize_path(path) for path in args.changed_files)
            if args.changed_files
            else collect_changed_files(repo_root, args.base_ref)
        )
    except ChangelogError as exc:
        print(f"changelog gate failed: {exc}", file=sys.stderr)
        return 1
    changelog_path = repo_root / CHANGELOG_PATH
    changelog_text = (
        changelog_path.read_text(encoding="utf-8")
        if changelog_path.exists()
        else None
    )

    errors, impacted = validate_changelog_state(changed_files, changelog_text)
    if errors:
        print("changelog gate failed:", file=sys.stderr)
        for path, group in impacted:
            print(f"- release-impacting path ({group}): {path}", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    if impacted:
        print(
            "changelog gate passed: "
            f"{len(impacted)} release-impacting file(s) covered"
        )
    else:
        print("changelog gate passed: no release-impacting files changed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

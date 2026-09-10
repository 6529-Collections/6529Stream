#!/usr/bin/env python3
"""Validate local Markdown links across repository documentation."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote


DEFAULT_INCLUDED_ROOTS = [
    Path("AGENTS.md"),
    Path("README.md"),
    Path("CONTRIBUTING.md"),
    Path("SECURITY.md"),
    Path("CHANGELOG.md"),
    Path(".github"),
    Path("docs"),
    Path("ops"),
    Path("release-artifacts"),
]

EXCLUDED_PARTS = {
    ".git",
    ".venv",
    ".venv-tools",
    "cache",
    "out",
    "broadcast",
    "node_modules",
    "tmp",
}

EXCLUDED_MARKDOWN_SUFFIXES = {
    ".generated.md",
}

FENCED_CODE_RE = re.compile(
    r"^[ \t]*(?P<fence>`{3,}|~{3,})[^\n]*\n.*?^[ \t]*(?P=fence)[ \t]*$",
    re.MULTILINE | re.DOTALL,
)
REFERENCE_LINK_RE = re.compile(
    r"^[ \t]{0,3}\[[^\]\n]+\]:[ \t]*(<[^>\n]+>|\S+)",
    re.MULTILINE,
)
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
HTML_ANCHOR_RE = re.compile(r"<a\s+[^>]*\bname=[\"']([^\"']+)[\"']", re.IGNORECASE)
LINE_ANCHOR_RE = re.compile(r"^L[1-9][0-9]*(?:-L[1-9][0-9]*)?$")


class MarkdownLinkError(ValueError):
    """Raised when repository Markdown links are invalid."""


@dataclass(frozen=True)
class LinkFailure:
    document: str
    target: str
    reason: str

    def message(self) -> str:
        return f"{self.document}: {self.target} ({self.reason})"


def repo_relative(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise MarkdownLinkError(f"path escapes repository: {path}") from exc


def should_skip_path(path: Path, repo_root: Path) -> bool:
    """Return whether a path is outside the checked Markdown set."""
    try:
        relative = path.resolve().relative_to(repo_root.resolve())
    except ValueError:
        return True

    if any(part in EXCLUDED_PARTS for part in relative.parts):
        return True
    return any(path.name.endswith(suffix) for suffix in EXCLUDED_MARKDOWN_SUFFIXES)


def markdown_files(repo_root: Path, included_roots: list[Path]) -> list[Path]:
    """Collect checked Markdown files from configured roots."""
    files: dict[str, Path] = {}
    for included_root in included_roots:
        root = included_root if included_root.is_absolute() else repo_root / included_root
        if not root.exists():
            raise MarkdownLinkError(f"included Markdown root is missing: {included_root}")

        candidates = [root] if root.is_file() else sorted(root.rglob("*.md"))
        for candidate in candidates:
            if candidate.suffix.lower() != ".md" or should_skip_path(candidate, repo_root):
                continue
            files[repo_relative(candidate, repo_root)] = candidate
    return [files[key] for key in sorted(files)]


def strip_fenced_code(text: str) -> str:
    """Remove fenced code blocks before scanning prose links."""
    return FENCED_CODE_RE.sub("", text)


def markdown_link_targets(text: str) -> list[str]:
    """Return inline and reference-definition link targets from Markdown text."""
    targets: list[str] = []
    position = 0
    while True:
        opener = text.find("](", position)
        if opener == -1:
            break

        start = opener + 2
        depth = 1
        index = start
        while index < len(text):
            char = text[index]
            if char == "\\":
                index += 2
                continue
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    targets.append(text[start:index])
                    break
            index += 1

        position = index + 1 if depth == 0 else start

    targets.extend(match.group(1) for match in REFERENCE_LINK_RE.finditer(text))
    return targets


def split_link_target(raw_target: str) -> tuple[str, str]:
    """Split a Markdown link target into path and fragment components."""
    target = raw_target.strip()
    if target.startswith("<") and ">" in target:
        target = target[1 : target.find(">")]
    if " " in target:
        target = target.split(" ", 1)[0]
    path_part, separator, fragment = target.partition("#")
    return unquote(path_part), unquote(fragment) if separator else ""


def is_external_target(path_part: str) -> bool:
    """Return whether a link target should be ignored by local checks."""
    lowered = path_part.lower()
    return (
        not path_part
        or "://" in lowered
        or lowered.startswith("mailto:")
        or lowered.startswith("tel:")
        or lowered.startswith("javascript:")
    )


def resolve_target(repo_root: Path, document: Path, path_part: str) -> Path:
    """Resolve a Markdown local link target."""
    if path_part.startswith("/"):
        target = repo_root / path_part.lstrip("/")
    else:
        target = document.parent / path_part
    return target.resolve()


def slugify_heading(heading: str) -> str:
    """Return a GitHub-compatible Markdown heading slug."""
    heading = heading.strip().rstrip("#").strip().lower()
    heading = re.sub(r"<[^>]+>", "", heading)
    heading = re.sub(r"[^\w\s-]", "", heading, flags=re.UNICODE)
    heading = re.sub(r"\s+", "-", heading)
    heading = re.sub(r"-+", "-", heading)
    return heading.strip("-")


def markdown_anchors(text: str) -> set[str]:
    """Return heading and explicit HTML anchors available in Markdown text."""
    anchors: set[str] = set()
    counts: dict[str, int] = {}
    for match in HEADING_RE.finditer(text):
        slug = slugify_heading(match.group(2))
        if not slug:
            continue
        count = counts.get(slug, 0)
        anchors.add(slug if count == 0 else f"{slug}-{count}")
        counts[slug] = count + 1

    anchors.update(match.group(1) for match in HTML_ANCHOR_RE.finditer(text))
    return anchors


def line_count(path: Path) -> int:
    """Return the number of lines in a text file."""
    return len(path.read_text(encoding="utf-8").splitlines())


def validate_fragment(target_path: Path, fragment: str) -> str | None:
    """Return a failure reason when a local fragment is invalid."""
    if not fragment:
        return None

    if LINE_ANCHOR_RE.match(fragment):
        end = fragment.split("-L")[-1].removeprefix("L")
        if int(end) > line_count(target_path):
            return f"line anchor exceeds file length: #{fragment}"
        return None

    if target_path.suffix.lower() != ".md":
        return None

    anchors = markdown_anchors(target_path.read_text(encoding="utf-8"))
    normalized = fragment.lower()
    if normalized not in anchors:
        return f"missing Markdown anchor: #{fragment}"
    return None


def validate_document(repo_root: Path, document: Path) -> list[LinkFailure]:
    """Validate all local links in one Markdown document."""
    relative_document = repo_relative(document, repo_root)
    text = strip_fenced_code(document.read_text(encoding="utf-8"))
    failures: list[LinkFailure] = []

    for raw_target in markdown_link_targets(text):
        path_part, fragment = split_link_target(raw_target)

        if path_part == "":
            if validate_fragment(document, fragment):
                failures.append(
                    LinkFailure(relative_document, raw_target, f"missing local anchor: #{fragment}")
                )
            continue

        if is_external_target(path_part):
            continue

        try:
            target_path = resolve_target(repo_root, document, path_part)
            relative_target = repo_relative(target_path, repo_root)
        except MarkdownLinkError as exc:
            failures.append(LinkFailure(relative_document, raw_target, str(exc)))
            continue

        if not target_path.exists():
            failures.append(LinkFailure(relative_document, raw_target, "target is missing"))
            continue

        fragment_error = validate_fragment(target_path, fragment)
        if fragment_error:
            failures.append(LinkFailure(relative_document, relative_target, fragment_error))

    return failures


def validate_markdown_links(repo_root: Path, included_roots: list[Path]) -> None:
    """Validate repository Markdown link targets and anchors."""
    documents = markdown_files(repo_root, included_roots)
    failures: list[LinkFailure] = []
    for document in documents:
        failures.extend(validate_document(repo_root, document))

    if failures:
        details = "\n  - ".join(failure.message() for failure in failures[:50])
        remaining = len(failures) - 50
        suffix = f"\n  ... and {remaining} more" if remaining > 0 else ""
        raise MarkdownLinkError(
            f"Markdown link check failed with {len(failures)} failure(s):\n  - "
            + details
            + suffix
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse Markdown link checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--include",
        type=Path,
        action="append",
        dest="included_roots",
        help="File or directory to scan. May be repeated.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the Markdown link checker CLI."""
    args = parse_args(argv or [])
    repo_root = args.repo_root.resolve()
    included_roots = args.included_roots or DEFAULT_INCLUDED_ROOTS

    try:
        validate_markdown_links(repo_root, included_roots)
    except MarkdownLinkError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print("Markdown links are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

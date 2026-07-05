#!/usr/bin/env python3
"""Shared helpers for the spec-conformance checker family.

These helpers back the Verification Tooling Backlog checkers
(docs/launch-conformance-matrix.md [LCM-TOOLING]): Markdown table and
section parsing, bracketed requirement-anchor extraction, and keccak256
recomputation. Keccak uses the pinned eth-hash tool when importable and
falls back to the Foundry ``cast keccak`` subprocess, matching the
hashing style of scripts/check_mint_manager_domain_constants.py.
"""

from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


class SpecConformanceError(RuntimeError):
    """Raised when shared spec-conformance parsing or hashing fails."""


FENCED_CODE_RE = re.compile(
    r"^[ \t]*(?P<fence>`{3,}|~{3,})[^\n]*\n.*?^[ \t]*(?P=fence)[ \t]*$",
    re.MULTILINE | re.DOTALL,
)
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")
INLINE_LINK_RE = re.compile(r"\[[^\]\n]*\]\([^)\n]*\)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
ANCHOR_RE = re.compile(r"\[(?P<anchor>[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)\]")
# OQ- markers belong to the open-question register convention; P0-/P1-/P2-
# ids are baseline-era roadmap tracker ids (ops/ROADMAP.md), not spec
# requirement anchors under docs/spec-policy.md (Requirement Anchors).
EXCLUDED_ANCHOR_PREFIXES = ("OQ-", "P0-", "P1-", "P2-")
HEX32_RE = re.compile(r"0x[0-9a-fA-F]{64}")


def read_text(path: Path) -> str:
    """Read UTF-8 document text."""
    return path.read_text(encoding="utf-8")


def strip_fenced_code(text: str) -> str:
    """Blank out fenced code blocks, preserving line numbering."""

    def blank(match: re.Match[str]) -> str:
        return "\n" * match.group(0).count("\n")

    return FENCED_CODE_RE.sub(blank, text)


def strip_inline_code(text: str) -> str:
    """Blank out inline code spans, preserving length coarsely."""
    return INLINE_CODE_RE.sub(" ", text)


def strip_inline_links(text: str) -> str:
    """Blank out whole inline Markdown links (text and target)."""
    return INLINE_LINK_RE.sub(" ", text)


def markdown_docs(repo_root: Path, subdir: str = "docs") -> list[Path]:
    """Return sorted Markdown files under a repository subdirectory."""
    root = repo_root / subdir
    if not root.is_dir():
        raise SpecConformanceError(f"missing Markdown root: {root}")
    return sorted(root.rglob("*.md"))


def normalize_cell(value: str) -> str:
    """Trim a table cell and unwrap one full-cell backtick span."""
    cell = value.strip()
    if cell.startswith("`") and cell.endswith("`") and len(cell) >= 2:
        cell = cell[1:-1]
    return " ".join(cell.split())


def first_backtick_span(cell: str) -> str | None:
    """Return the first inline-code span content in a table cell."""
    match = re.search(r"`([^`]+)`", cell)
    return match.group(1) if match else None


@dataclass(frozen=True)
class MarkdownTable:
    """One parsed Markdown table with raw and header-mapped rows."""

    path: Path
    header_line: int
    headers: tuple[str, ...]
    rows: tuple[tuple[int, tuple[str, ...]], ...]
    ragged_lines: tuple[int, ...] = ()

    def mapped_rows(self) -> list[tuple[int, dict[str, str]]]:
        """Return rows as header->raw-cell dictionaries."""
        return [
            (line, dict(zip(self.headers, cells)))
            for line, cells in self.rows
        ]


_ESCAPED_PIPE_SENTINEL = "\x00"


def _split_row(line: str) -> list[str] | None:
    stripped = line.strip()
    if not stripped.startswith("|") or not stripped.endswith("|") or len(stripped) < 2:
        return None
    masked = stripped.replace("\\|", _ESCAPED_PIPE_SENTINEL)
    return [
        cell.replace(_ESCAPED_PIPE_SENTINEL, "\\|").strip()
        for cell in masked[1:-1].split("|")
    ]


def iter_tables(path: Path, text: str) -> list[MarkdownTable]:
    """Parse every Markdown pipe table in a document."""
    tables: list[MarkdownTable] = []
    lines = text.splitlines()
    index = 0
    while index < len(lines) - 1:
        header_cells = _split_row(lines[index])
        divider_cells = _split_row(lines[index + 1])
        if (
            header_cells is None
            or divider_cells is None
            or not divider_cells
            or not all(re.fullmatch(r":?-{3,}:?", cell) for cell in divider_cells)
        ):
            index += 1
            continue
        headers = tuple(normalize_cell(cell) for cell in header_cells)
        rows: list[tuple[int, tuple[str, ...]]] = []
        ragged: list[int] = []
        cursor = index + 2
        while cursor < len(lines):
            cells = _split_row(lines[cursor])
            if cells is None:
                break
            if len(cells) != len(headers):
                ragged.append(cursor + 1)
                padded = list(cells[: len(headers)])
                padded.extend([""] * (len(headers) - len(padded)))
                cells = padded
            rows.append((cursor + 1, tuple(cells)))
            cursor += 1
        tables.append(
            MarkdownTable(
                path=path,
                header_line=index + 1,
                headers=headers,
                rows=tuple(rows),
                ragged_lines=tuple(ragged),
            )
        )
        index = cursor
    return tables


@dataclass(frozen=True)
class Section:
    """A heading-delimited document slice."""

    path: Path
    heading: str
    level: int
    start_line: int
    end_line: int
    text: str


def iter_sections(path: Path, text: str) -> list[Section]:
    """Split a document into heading-delimited sections.

    Each section runs from its heading to the next heading of any level.
    Text before the first heading is returned with an empty heading.
    """
    lines = text.splitlines()
    boundaries: list[tuple[int, int, str]] = []
    fence_masked = strip_fenced_code(text).splitlines()
    for line_index, line in enumerate(fence_masked):
        match = re.match(r"^(#{1,6})\s+(.+?)\s*$", line)
        if match:
            boundaries.append((line_index, len(match.group(1)), match.group(2)))
    sections: list[Section] = []
    if not boundaries or boundaries[0][0] > 0:
        end = boundaries[0][0] if boundaries else len(lines)
        sections.append(
            Section(path, "", 0, 1, end, "\n".join(lines[0:end]))
        )
    for position, (line_index, level, heading) in enumerate(boundaries):
        end = (
            boundaries[position + 1][0]
            if position + 1 < len(boundaries)
            else len(lines)
        )
        sections.append(
            Section(
                path,
                heading,
                level,
                line_index + 1,
                end,
                "\n".join(lines[line_index:end]),
            )
        )
    return sections


def anchors_in_text(text: str) -> list[str]:
    """Return bracketed requirement anchors cited in prose text."""
    prose = strip_inline_links(strip_inline_code(strip_fenced_code(text)))
    found: list[str] = []
    for match in ANCHOR_RE.finditer(prose):
        anchor = match.group("anchor")
        if anchor.startswith(EXCLUDED_ANCHOR_PREFIXES):
            continue
        found.append(anchor)
    return found


_KECCAK_BACKEND = None


def _load_keccak_backend():
    global _KECCAK_BACKEND
    if _KECCAK_BACKEND is not None:
        return _KECCAK_BACKEND
    try:
        from eth_hash.auto import keccak as eth_keccak  # type: ignore

        def backend(preimage: str) -> str:
            return "0x" + eth_keccak(preimage.encode("utf-8")).hex()

    except ImportError:  # pragma: no cover - depends on environment

        def backend(preimage: str) -> str:
            return _cast_keccak256(preimage)

    _KECCAK_BACKEND = backend
    return backend


def _cast_keccak256(preimage: str) -> str:
    try:
        result = subprocess.run(
            ["cast", "keccak", preimage],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise SpecConformanceError(
            "eth-hash is not importable and cast is unavailable; "
            "one keccak256 backend is required"
        ) from exc
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.strip()
        raise SpecConformanceError(f"cast keccak failed for {preimage!r}: {stderr}") from exc
    digest = result.stdout.strip().lower()
    if not re.fullmatch(r"0x[0-9a-f]{64}", digest):
        raise SpecConformanceError(f"cast returned invalid keccak256 digest: {digest}")
    return digest


def keccak256_hex(preimage: str) -> str:
    """Return the lowercase 0x-prefixed keccak256 of a string preimage."""
    return _load_keccak_backend()(preimage).lower()


def ascii_safe(value: str) -> str:
    """Return console-safe ASCII text for cp1252 terminals."""
    return value.encode("ascii", "backslashreplace").decode("ascii")

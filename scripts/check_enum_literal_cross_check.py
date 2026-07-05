#!/usr/bin/env python3
"""Cross-check matrix-named enum literals against their owning specs.

The enum-literal cross-check row of the Verification Tooling Backlog
(docs/launch-conformance-matrix.md [LCM-TOOLING]; the docs-side lint for
[LCM-GOLDEN] test 25) requires every enum literal named in the matrix —
the lifecycle reconciliation matrix and the Numeric ID Catalog coverage
list included — to appear verbatim in the owning spec's enum
definition.

Two legs:

1. Lifecycle reconciliation matrix: every ``StreamTokenLifecycle``,
   ``TokenURIReadStatus``, and ``EntropyStatus`` literal in the pinned
   block exists in the owning enum definition at its home
   (docs/stream-long-term-architecture.md,
   docs/metadata-router-and-renderer.md,
   docs/stream-entropy-coordinator.md), and ``EntropyStatus`` has no
   ``UNKNOWN`` member, exactly as the matrix asserts.
2. Every backticked ALL-CAPS literal the matrix names must appear
   verbatim in at least one spec-inventory document or ADR (the owning
   homes), with pinned numeric values (``NAME = 0``, ``bit 2``) verified
   against the home's assignment, comment, parenthetical, value-first
   table, or enum-position form. EVM opcode and context names cited by
   the static-analysis gates are not enum literals and are excluded.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import ascii_safe, read_text  # noqa: E402


MATRIX_PATH = Path("docs/launch-conformance-matrix.md")
SPEC_POLICY_PATH = Path("docs/spec-policy.md")
LIFECYCLE_HOMES = {
    "StreamTokenLifecycle": Path("docs/stream-long-term-architecture.md"),
    "TokenURIReadStatus": Path("docs/metadata-router-and-renderer.md"),
    "EntropyStatus": Path("docs/stream-entropy-coordinator.md"),
}
LIFECYCLE_MARKER = "Lifecycle reconciliation matrix"
EVM_NAMES = {
    "CALL", "DELEGATECALL", "STATICCALL", "CREATE", "CREATE2", "SELFDESTRUCT",
    "TIMESTAMP", "NUMBER", "PREVRANDAO", "BLOCKHASH", "COINBASE", "BASEFEE",
    "GASLIMIT", "GASPRICE", "BALANCE", "SELFBALANCE",
}
LITERAL_TOKEN_RE = re.compile(r"`([A-Z][A-Z0-9_]*(?:\s*=\s*[^`]+)?)`")
ENUM_BLOCK_RE = re.compile(r"enum\s+(?P<name>\w+)\s*\{(?P<body>[^}]*)\}", re.DOTALL)


class EnumLiteralError(RuntimeError):
    """Raised when a matrix-named enum literal has no home definition."""


def enum_members(text: str, enum_name: str) -> list[str]:
    """Ordered members of a named enum definition in document text."""
    for match in ENUM_BLOCK_RE.finditer(text):
        if match.group("name") != enum_name:
            continue
        members: list[str] = []
        for line in match.group("body").splitlines():
            line = line.split("//", 1)[0]
            for token in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", line):
                members.append(token)
        return members
    return []


def lifecycle_block(matrix_text: str) -> list[tuple[str, str]]:
    """(enum, literal) pairs from the lifecycle reconciliation block."""
    start = matrix_text.find(LIFECYCLE_MARKER)
    if start == -1:
        raise EnumLiteralError(f"missing marker: {LIFECYCLE_MARKER}")
    fence_open = matrix_text.find("```", start)
    fence_close = matrix_text.find("```", fence_open + 3)
    if fence_open == -1 or fence_close == -1:
        raise EnumLiteralError("missing fenced lifecycle reconciliation block")
    block = matrix_text[fence_open:fence_close].splitlines()
    header_index = next(
        (i for i, line in enumerate(block) if "StreamTokenLifecycle" in line), None
    )
    if header_index is None:
        raise EnumLiteralError("lifecycle block lacks its column header")
    header = block[header_index]
    columns = [
        ("StreamTokenLifecycle", header.index("StreamTokenLifecycle")),
        ("TokenURIReadStatus", header.index("TokenURIReadStatus")),
        ("EntropyStatus", header.index("EntropyStatus")),
    ]
    pairs: list[tuple[str, str]] = []
    for line in block[header_index + 1 :]:
        if not line.strip():
            continue
        for position, (enum_name, offset) in enumerate(columns):
            end = columns[position + 1][1] if position + 1 < len(columns) else len(line)
            cell = line[offset:end] if offset < len(line) else ""
            for token in re.findall(r"\b[A-Z][A-Z0-9_]{2,}\b", cell):
                pairs.append((enum_name, token))
    if not pairs:
        raise EnumLiteralError("lifecycle block names no literals")
    return pairs


def validate_lifecycle_matrix(repo_root: Path, matrix_text: str) -> list[str]:
    failures: list[str] = []
    members_by_enum = {
        enum_name: enum_members(read_text(repo_root / home), enum_name)
        for enum_name, home in LIFECYCLE_HOMES.items()
    }
    for enum_name, members in members_by_enum.items():
        if not members:
            failures.append(
                f"{LIFECYCLE_HOMES[enum_name].as_posix()}: missing enum "
                f"{enum_name} definition"
            )
    for enum_name, literal in lifecycle_block(matrix_text):
        members = members_by_enum.get(enum_name, [])
        if members and literal not in members:
            failures.append(
                f"lifecycle matrix literal {enum_name}.{literal} does not exist "
                f"in the owning enum at {LIFECYCLE_HOMES[enum_name].as_posix()}"
            )
    entropy_members = members_by_enum.get("EntropyStatus", [])
    if entropy_members and "UNKNOWN" in entropy_members:
        failures.append(
            "EntropyStatus declares UNKNOWN; the matrix pins that no such "
            "member exists"
        )
    return failures


def home_documents(repo_root: Path) -> dict[Path, str]:
    """Spec-inventory documents plus ADRs, excluding the matrix itself."""
    policy = read_text(repo_root / SPEC_POLICY_PATH)
    section = policy[policy.find("## Specification Inventory") :]
    homes: dict[Path, str] = {}
    for match in re.finditer(r"\]\(([^)#]+\.md)\)", section):
        path = ((repo_root / SPEC_POLICY_PATH).parent / match.group(1)).resolve()
        if not path.exists():
            continue
        relative = Path("docs") / path.relative_to((repo_root / "docs").resolve())
        if relative == MATRIX_PATH:
            continue
        homes[relative] = read_text(path)
    for path in sorted((repo_root / "docs" / "adr").glob("*.md")):
        homes[path.relative_to(repo_root)] = read_text(path)
    if not homes:
        raise EnumLiteralError("no home documents resolved from the inventory")
    return homes


def value_pinned_at_home(name: str, value: str, text: str) -> bool:
    """Whether a home document pins ``name`` to ``value`` in any form."""
    escaped_value = re.escape(value)
    for line in text.splitlines():
        if not re.search(rf"\b{re.escape(name)}\b", line):
            continue
        if re.search(
            rf"(=\s*{escaped_value}\b|//\s*{escaped_value}\b|"
            rf"\({escaped_value}\)|\(value\s+{escaped_value}\b)",
            line,
        ):
            return True
        if re.match(rf"\s*{escaped_value}\s+{re.escape(name)}\b", line):
            return True
    for match in ENUM_BLOCK_RE.finditer(text):
        members = enum_members(text, match.group("name"))
        if name in members and value.isdigit() and members.index(name) == int(value):
            return True
    return False


def validate_matrix_literals(repo_root: Path, matrix_text: str) -> tuple[list[str], int]:
    homes = home_documents(repo_root)
    failures: list[str] = []
    checked = 0
    for token in sorted({match.group(1) for match in LITERAL_TOKEN_RE.finditer(matrix_text)}):
        normalized = " ".join(token.split())
        name, _, value = (part.strip() for part in normalized.partition("="))
        if not re.fullmatch(r"[A-Z][A-Z0-9_]*", name) or name in EVM_NAMES:
            continue
        checked += 1
        holding = [
            path
            for path, text in homes.items()
            if re.search(rf"\b{re.escape(name)}\b", text)
        ]
        if not holding:
            failures.append(
                f"matrix literal {name} appears in no spec-inventory or ADR home"
            )
            continue
        if value and not any(
            value_pinned_at_home(name, value, homes[path]) for path in holding
        ):
            failures.append(
                f"matrix pins {name} = {value}; no home document pins that value"
            )
    return failures, checked


def validate_repo(repo_root: Path) -> tuple[int, int]:
    matrix_text = read_text(repo_root / MATRIX_PATH)
    failures = validate_lifecycle_matrix(repo_root, matrix_text)
    literal_failures, checked = validate_matrix_literals(repo_root, matrix_text)
    failures.extend(literal_failures)
    if failures:
        details = "\n  - ".join(failures)
        raise EnumLiteralError(
            f"enum literal cross-check failed with {len(failures)} failure(s):"
            f"\n  - {details}"
        )
    return checked, len(lifecycle_block(matrix_text))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=Path(__file__).resolve().parent.parent,
        type=Path,
        help="Repository root to validate.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        literal_count, lifecycle_count = validate_repo(args.repo_root)
    except EnumLiteralError as exc:
        print(ascii_safe(f"enum literal cross-check failed: {exc}"), file=sys.stderr)
        return 1
    print(
        f"enum literals are current: {literal_count} matrix literals and "
        f"{lifecycle_count} lifecycle cells verified against their homes"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

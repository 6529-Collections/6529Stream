#!/usr/bin/env python3
"""Derive asserted spec counts from their counted sources.

The prose-count row of the Verification Tooling Backlog
(docs/launch-conformance-matrix.md [LCM-TOOLING]; [LCM-GENESIS];
ADR 0014 decision V9) requires asserted counts to derive from counted
sources:

1. [LCM-GENESIS] inventory arithmetic: the owning statement's deployable
   total, numbered-entry count, and probe-entry count against the
   ``Mandatory genesis contracts`` block (numbered entries, the probe
   range, and the shared cadence probe), and the per-row GGP probe count
   against the [LTA-GGP] inventory table;
2. the no-restated-numeral rule: no document outside the owning
   statement restates the deployable-contract total as a numeral;
3. the [AA-GATES] suite count named by the matrix against the numbered
   suite list at its home;
4. any ``<n> schemas`` assertion tied to [CMC-GENESIS-SCHEMAS] against
   the pinned schema table.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import (  # noqa: E402
    ascii_safe,
    iter_tables,
    markdown_docs,
    read_text,
)


MATRIX_PATH = Path("docs/launch-conformance-matrix.md")
ARTIST_PATH = Path("docs/stream-artist-authority.md")
CMC_PATH = Path("docs/collection-metadata-contract.md")
UMBRELLA_PATH = Path("docs/stream-long-term-architecture.md")
GENESIS_BLOCK_MARKER = "Mandatory genesis contracts:"
OWNING_STATEMENT_RE = re.compile(
    r"(?P<total>\d+) deployable\s+production contracts[^.]*?"
    r"(?P<numbered>\d+|[a-z-]+) numbered\s+entries[^.]*?"
    r"(?P<probes>\d+|[a-z-]+) Permanent-class probe\s+contracts of\s+entries\s+"
    r"(?P<span_start>\d+)[–—-](?P<span_end>\d+)",
    re.DOTALL,
)
ENTRY_RE = re.compile(r"^\s{0,3}(?P<start>\d+)(?:-(?P<end>\d+))?\s+\S", re.MULTILINE)
AA_GATES_ASSERTION_RE = re.compile(r"the (?P<count>\d+|[a-z-]+) \[AA-GATES\] suites")
SCHEMA_ASSERTION_RE = re.compile(
    r"(?P<count>\d+|[a-z-]+)\s+(?:genesis\s+)?schemas[^.]{0,120}\[CMC-GENESIS-SCHEMAS\]"
    r"|\[CMC-GENESIS-SCHEMAS\][^.]{0,120}?(?P<count2>\d+)\s+schemas"
)
RESTATED_TOTAL_RE = re.compile(
    r"\b(?P<count>\d+)(?:\s+deployable)?[ -]+(?:production\s+)?contracts?\b"
)
WORD_NUMBERS = {
    "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
    "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11,
    "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
    "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
    "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
}


class ProseCountError(RuntimeError):
    """Raised when an asserted count drifts from its counted source."""


def parse_number(token: str) -> int:
    token = token.strip().lower()
    if token.isdigit():
        return int(token)
    if token in WORD_NUMBERS:
        return WORD_NUMBERS[token]
    if "-" in token:
        head, _, tail = token.partition("-")
        if head in WORD_NUMBERS and tail in WORD_NUMBERS:
            return WORD_NUMBERS[head] + WORD_NUMBERS[tail]
    raise ProseCountError(f"unparseable count token: {token!r}")


def genesis_block_entries(
    matrix_text: str, probe_span: tuple[int, int]
) -> tuple[int, int, int]:
    """Return (numbered_entries, probe_entries, max_entry) from the block.

    ``probe_span`` is the owning statement's probe entry range; every
    inventory number inside it counts as a probe entry.
    """
    start = matrix_text.find(GENESIS_BLOCK_MARKER)
    if start == -1:
        raise ProseCountError(f"missing marker: {GENESIS_BLOCK_MARKER}")
    fence_open = matrix_text.find("```", start)
    fence_close = matrix_text.find("```", fence_open + 3)
    if fence_open == -1 or fence_close == -1:
        raise ProseCountError("missing fenced genesis inventory block")
    block = matrix_text[fence_open:fence_close]
    numbered = 0
    probes = 0
    max_entry = 0
    seen: set[int] = set()
    for match in ENTRY_RE.finditer(block):
        entry_start = int(match.group("start"))
        entry_end = int(match.group("end") or entry_start)
        if entry_end < entry_start:
            raise ProseCountError(f"inverted entry range {entry_start}-{entry_end}")
        span = set(range(entry_start, entry_end + 1))
        if span & seen:
            raise ProseCountError(f"duplicate genesis entry number in {sorted(span & seen)}")
        seen.update(span)
        max_entry = max(max_entry, entry_end)
        for entry in span:
            if probe_span[0] <= entry <= probe_span[1]:
                probes += 1
            else:
                numbered += 1
    if seen != set(range(1, max_entry + 1)):
        missing = sorted(set(range(1, max_entry + 1)) - seen)
        raise ProseCountError(f"genesis inventory skips entries: {missing}")
    return numbered, probes, max_entry


def ggp_inventory_count(repo_root: Path) -> int:
    text = read_text(repo_root / UMBRELLA_PATH)
    for table in iter_tables(UMBRELLA_PATH, text):
        if table.headers == ("Parameter", "Host", "Normative home"):
            return len(table.rows)
    raise ProseCountError(f"missing [LTA-GGP] inventory table in {UMBRELLA_PATH.as_posix()}")


def validate_genesis_inventory(repo_root: Path, matrix_text: str) -> list[str]:
    failures: list[str] = []
    owning = OWNING_STATEMENT_RE.search(matrix_text)
    if owning is None:
        return ["missing [LCM-GENESIS] owning inventory statement"]
    total = parse_number(owning.group("total"))
    numbered_claim = parse_number(owning.group("numbered"))
    probes_claim = parse_number(owning.group("probes"))
    probe_span = (int(owning.group("span_start")), int(owning.group("span_end")))
    numbered, probes, max_entry = genesis_block_entries(matrix_text, probe_span)
    if numbered != numbered_claim:
        failures.append(
            f"owning statement claims {numbered_claim} numbered entries; the "
            f"genesis block lists {numbered}"
        )
    if probes != probes_claim:
        failures.append(
            f"owning statement claims {probes_claim} probe entries; the genesis "
            f"block lists {probes}"
        )
    if numbered_claim + probes_claim != total:
        failures.append(
            f"owning statement arithmetic drifts: {numbered_claim} + "
            f"{probes_claim} != {total}"
        )
    if max_entry != total:
        failures.append(
            f"genesis block numbering tops out at {max_entry}, owning statement "
            f"claims {total}"
        )
    ggp_rows = ggp_inventory_count(repo_root)
    revision_claims = {
        parse_number(match.group(1))
        for match in re.finditer(r"\(([a-z-]+|\d+) at this\s+revision", matrix_text)
    }
    for claim in sorted(revision_claims):
        if claim != ggp_rows:
            failures.append(
                f"matrix claims {claim} [LTA-GGP] inventory rows at this revision; "
                f"the inventory table has {ggp_rows}"
            )
    if probes != ggp_rows + 1:
        failures.append(
            f"probe entries ({probes}) drift from the [LTA-GGP] inventory "
            f"({ggp_rows}) plus the shared cadence probe"
        )
    return failures


def validate_no_restated_total(repo_root: Path, matrix_text: str) -> list[str]:
    owning = OWNING_STATEMENT_RE.search(matrix_text)
    if owning is None:
        return []
    total = parse_number(owning.group("total"))
    failures: list[str] = []
    for path in markdown_docs(repo_root):
        relative = path.relative_to(repo_root)
        text = read_text(path)
        for match in re.finditer(
            rf"\b{total}\b[^.\n]{{0,60}}?(deployable|production contracts|-contract inventory)",
            text,
        ):
            if relative == MATRIX_PATH and abs(match.start() - owning.start()) < 400:
                continue
            line = text.count("\n", 0, match.start()) + 1
            failures.append(
                f"{relative.as_posix()}:{line}: restates the deployable-contract "
                f"total ({total}) outside the owning [LCM-GENESIS] statement"
            )
    return failures


def count_top_level_items(section: str) -> int:
    return len(re.findall(r"^\d+\.\s", section, re.MULTILINE))


def validate_aa_gates_count(repo_root: Path, matrix_text: str) -> list[str]:
    assertion = AA_GATES_ASSERTION_RE.search(matrix_text)
    if assertion is None:
        return ["matrix no longer asserts the [AA-GATES] suite count"]
    claimed = parse_number(assertion.group("count"))
    artist_text = read_text(repo_root / ARTIST_PATH)
    heading = re.search(r"^##\s+.*\[AA-GATES\].*$", artist_text, re.MULTILINE)
    if heading is None:
        return [f"missing [AA-GATES] home section in {ARTIST_PATH.as_posix()}"]
    section = artist_text[heading.end() :]
    next_heading = re.search(r"^##\s", section, re.MULTILINE)
    if next_heading is not None:
        section = section[: next_heading.start()]
    counted = count_top_level_items(section)
    if counted != claimed:
        return [
            f"matrix asserts {claimed} [AA-GATES] suites; the home lists {counted}"
        ]
    return []


def schema_table_count(repo_root: Path) -> int:
    text = read_text(repo_root / CMC_PATH)
    heading = text.find("[CMC-GENESIS-SCHEMAS]")
    if heading == -1:
        raise ProseCountError(f"missing [CMC-GENESIS-SCHEMAS] in {CMC_PATH.as_posix()}")
    section = text[heading:]
    for table in iter_tables(CMC_PATH, section):
        if table.headers and table.headers[0] == "Schema name":
            return len(table.rows)
    raise ProseCountError("missing [CMC-GENESIS-SCHEMAS] schema table")


def validate_schema_count(repo_root: Path) -> list[str]:
    counted = schema_table_count(repo_root)
    failures: list[str] = []
    for path in markdown_docs(repo_root):
        relative = path.relative_to(repo_root)
        text = read_text(path)
        for match in SCHEMA_ASSERTION_RE.finditer(text):
            token = match.group("count") or match.group("count2")
            try:
                claimed = parse_number(token)
            except ProseCountError:
                continue
            if claimed != counted:
                line = text.count("\n", 0, match.start()) + 1
                failures.append(
                    f"{relative.as_posix()}:{line}: asserts {claimed} genesis "
                    f"schemas; the [CMC-GENESIS-SCHEMAS] table pins {counted}"
                )
    return failures


def validate_repo(repo_root: Path) -> dict[str, int]:
    matrix_text = read_text(repo_root / MATRIX_PATH)
    failures = validate_genesis_inventory(repo_root, matrix_text)
    failures.extend(validate_no_restated_total(repo_root, matrix_text))
    failures.extend(validate_aa_gates_count(repo_root, matrix_text))
    failures.extend(validate_schema_count(repo_root))
    if failures:
        details = "\n  - ".join(failures)
        raise ProseCountError(
            f"prose count check failed with {len(failures)} failure(s):\n  - {details}"
        )
    owning = OWNING_STATEMENT_RE.search(matrix_text)
    assert owning is not None
    probe_span = (int(owning.group("span_start")), int(owning.group("span_end")))
    numbered, probes, total = genesis_block_entries(matrix_text, probe_span)
    return {
        "numbered": numbered,
        "probes": probes,
        "total": total,
        "schemas": schema_table_count(repo_root),
    }


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
        counts = validate_repo(args.repo_root)
    except ProseCountError as exc:
        print(ascii_safe(f"prose count check failed: {exc}"), file=sys.stderr)
        return 1
    print(
        "prose counts derive from counted sources: "
        f"{counts['numbered']} numbered + {counts['probes']} probe genesis "
        f"entries = {counts['total']}; {counts['schemas']} genesis schemas"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

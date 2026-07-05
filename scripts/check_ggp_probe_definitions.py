#!/usr/bin/env python3
"""Validate per-parameter probe definitions and failure-direction classes.

The probe-definition row of the Verification Tooling Backlog
(docs/launch-conformance-matrix.md [LCM-TOOLING]; Governed gas and time
parameters gate; ADR 0012 decision T1) requires exactly one probe
definition and one pinned failure-direction class per [LTA-GGP]
inventory row at its home — what the probe executes, the
permissioned-path equivalent, and what ``evidenceHash`` commits to.

Static verification per inventory row, at the normative home document
named by the [LTA-GGP] inventory table:

1. exactly one failure-direction class is assigned to the parameter —
   either a sentence naming the parameter and exactly one of
   ``FORWARDING_CAP``, ``FAIL_CLOSED_PRECHECK``, or ``MIN_GAS_GATE``, or
   a heading section naming the parameter whose text pins exactly one
   class (the ``The parameter's release-manifest failure-direction
   class is ...`` convention); zero assignments or assignments to two
   different classes fail;
2. the home describes the parameter's probe (the parameter and the word
   ``probe`` in one sentence or one section), and the home records what
   ``evidenceHash`` commits to (document-level presence).

Governed Time Parameters carry no failure-direction class; their
[EC-TIME] home must describe the shared cadence probe.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import (  # noqa: E402
    ascii_safe,
    first_backtick_span,
    iter_sections,
    iter_tables,
    read_text,
    strip_fenced_code,
)


UMBRELLA_PATH = Path("docs/stream-long-term-architecture.md")
COORDINATOR_PATH = Path("docs/stream-entropy-coordinator.md")
INVENTORY_HEADERS = ("Parameter", "Host", "Normative home")
FAILURE_CLASSES = ("FORWARDING_CAP", "FAIL_CLOSED_PRECHECK", "MIN_GAS_GATE")
GTP_NAMES_SOURCE = "Requirements [EC-TIME]"
SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?])\s+")


class ProbeDefinitionError(RuntimeError):
    """Raised when a GGP row lacks a probe definition or a pinned class."""


def ggp_inventory(repo_root: Path) -> list[tuple[str, Path]]:
    """Return (parameter, home document) pairs from the [LTA-GGP] table."""
    text = read_text(repo_root / UMBRELLA_PATH)
    for table in iter_tables(UMBRELLA_PATH, text):
        if table.headers != INVENTORY_HEADERS:
            continue
        entries: list[tuple[str, Path]] = []
        for line, cells in table.mapped_rows():
            name = first_backtick_span(cells["Parameter"])
            if name is None:
                raise ProbeDefinitionError(
                    f"{UMBRELLA_PATH.as_posix()}:{line}: inventory row without "
                    "a backticked parameter name"
                )
            home_match = re.search(r"\]\(([^)#]+\.md)\)", cells["Normative home"])
            if home_match is not None:
                home = Path("docs") / home_match.group(1)
            elif "this document" in cells["Normative home"]:
                home = UMBRELLA_PATH
            else:
                raise ProbeDefinitionError(
                    f"{UMBRELLA_PATH.as_posix()}:{line}: {name} names no home "
                    "document"
                )
            entries.append((name, home))
        if entries:
            return entries
    raise ProbeDefinitionError(
        f"missing [LTA-GGP] inventory table in {UMBRELLA_PATH.as_posix()}"
    )


def sentences(text: str) -> list[str]:
    """Split prose into approximate sentences with whitespace collapsed."""
    prose = " ".join(strip_fenced_code(text).split())
    return SENTENCE_SPLIT_RE.split(prose)


def sentence_class_assignments(parameter: str, home_sentences: list[str]) -> set[str]:
    """Classes assigned by sentences naming the parameter directly."""
    assigned: set[str] = set()
    for sentence in home_sentences:
        if f"`{parameter}`" not in sentence:
            continue
        named = {cls for cls in FAILURE_CLASSES if f"`{cls}`" in sentence}
        if len(named) == 1:
            assigned.update(named)
    return assigned


def section_class_assignments(parameter: str, sections: list[str]) -> set[str]:
    """Classes pinned by sections that name the parameter unambiguously."""
    assigned: set[str] = set()
    for section in sections:
        if f"`{parameter}`" not in section:
            continue
        named = {cls for cls in FAILURE_CLASSES if f"`{cls}`" in section}
        if len(named) == 1:
            assigned.update(named)
    return assigned


def probe_described(parameter: str, home_sentences: list[str], sections: list[str]) -> bool:
    if any(
        f"`{parameter}`" in sentence and "probe" in sentence.lower()
        for sentence in home_sentences
    ):
        return True
    return any(
        f"`{parameter}`" in section and "probe" in section.lower()
        for section in sections
    )


def validate_repo(repo_root: Path) -> tuple[int, int]:
    """Validate probe definitions; return (ggp_count, gtp_probe_count)."""
    inventory = ggp_inventory(repo_root)
    failures: list[str] = []
    home_cache: dict[Path, tuple[list[str], list[str]]] = {}
    for parameter, home in inventory:
        if home not in home_cache:
            home_path = repo_root / home
            if not home_path.exists():
                failures.append(f"{parameter}: home document {home.as_posix()} is missing")
                continue
            home_text = read_text(home_path)
            section_texts = [
                " ".join(strip_fenced_code(section.text).split())
                for section in iter_sections(home, home_text)
            ]
            home_cache[home] = (sentences(home_text), section_texts)
        home_sentences, home_sections = home_cache[home]
        assigned = sentence_class_assignments(parameter, home_sentences)
        if not assigned:
            assigned = section_class_assignments(parameter, home_sections)
        if not assigned:
            failures.append(
                f"{parameter}: no pinned failure-direction class at "
                f"{home.as_posix()} ([LTA-GGP] requirement 10)"
            )
        elif len(assigned) > 1:
            failures.append(
                f"{parameter}: ambiguous failure-direction classes at "
                f"{home.as_posix()}: {', '.join(sorted(assigned))}"
            )
        if not probe_described(parameter, home_sentences, home_sections):
            failures.append(
                f"{parameter}: no probe definition at {home.as_posix()} "
                "([LTA-GGP-PROBES])"
            )
        if "evidenceHash" not in "".join(home_sentences):
            failures.append(
                f"{parameter}: home {home.as_posix()} never records what "
                "evidenceHash commits to"
            )

    coordinator_text = read_text(repo_root / COORDINATOR_PATH)
    gtp_probe_count = 0
    if GTP_NAMES_SOURCE not in coordinator_text:
        failures.append(
            f"missing {GTP_NAMES_SOURCE!r} home section in {COORDINATOR_PATH.as_posix()}"
        )
    elif "cadence probe" not in coordinator_text:
        failures.append(
            f"{COORDINATOR_PATH.as_posix()}: [EC-TIME] never describes the "
            "shared entropy cadence probe"
        )
    else:
        gtp_probe_count = 1

    if failures:
        details = "\n  - ".join(failures)
        raise ProbeDefinitionError(
            f"probe definition check failed with {len(failures)} failure(s):"
            f"\n  - {details}"
        )
    return len(inventory), gtp_probe_count


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
        ggp_count, gtp_probe_count = validate_repo(args.repo_root)
    except ProbeDefinitionError as exc:
        print(ascii_safe(f"probe definition check failed: {exc}"), file=sys.stderr)
        return 1
    print(
        f"probe definitions are current: {ggp_count} GGP rows verified, "
        f"{gtp_probe_count} shared cadence probe home"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

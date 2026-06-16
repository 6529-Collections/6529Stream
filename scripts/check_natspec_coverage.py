#!/usr/bin/env python3
"""Validate NatSpec coverage for the release protocol surface."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SURFACE_SCHEMA = "6529stream.protocol-surface-report.v1"
BASELINE_SCHEMA = "6529stream.natspec-coverage-baseline.v1"
DEFAULT_SURFACE_REPORT = Path("release-artifacts/latest/protocol-surface-report.json")
DEFAULT_BASELINE = Path("release-artifacts/baselines/v0.1.0/natspec-coverage.json")

DECLARATION_RE = {
    "function": re.compile(r"\bfunction\s+([A-Za-z_][A-Za-z0-9_]*)\s*\("),
    "event": re.compile(r"\bevent\s+([A-Za-z_][A-Za-z0-9_]*)\s*\("),
    "custom_error": re.compile(r"\berror\s+([A-Za-z_][A-Za-z0-9_]*)\s*\("),
}
PUBLIC_VARIABLE_RE = re.compile(
    r"^\s*(?:mapping\s*\(.+\)|[A-Za-z_][A-Za-z0-9_\[\].]*(?:\s+[A-Za-z_][A-Za-z0-9_\[\].]*)*)"
    r"\s+public\s+(?:constant\s+|immutable\s+)?([A-Za-z_][A-Za-z0-9_]*)\b"
)


class NatSpecCoverageError(ValueError):
    """Raised when NatSpec coverage validation fails."""


@dataclass(frozen=True)
class SurfaceItem:
    contract: str
    source: str
    kind: str
    name: str
    signature: str
    arity: int

    @property
    def item_id(self) -> str:
        return f"{self.contract}:{self.kind}:{self.signature}"


@dataclass(frozen=True)
class Declaration:
    source: str
    kind: str
    name: str
    arity: int | None
    line: int
    natspec: bool


@dataclass(frozen=True)
class CoverageGap:
    item: SurfaceItem
    status: str
    line: int | None

    @property
    def item_id(self) -> str:
        return self.item.item_id


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise NatSpecCoverageError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise NatSpecCoverageError(f"invalid JSON in {path}: {exc}") from exc


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise NatSpecCoverageError(f"path escapes repository: {path}") from exc


def signature_arity(signature: str) -> int:
    start = signature.find("(")
    end = signature.rfind(")")
    if start < 0 or end < start:
        raise NatSpecCoverageError(f"invalid ABI signature: {signature}")
    params = signature[start + 1 : end]
    if params == "":
        return 0

    depth = 0
    count = 1
    for char in params:
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == "," and depth == 0:
            count += 1
    return count


def surface_items(report: dict[str, Any]) -> list[SurfaceItem]:
    if report.get("schema_version") != SURFACE_SCHEMA:
        raise NatSpecCoverageError(
            f"protocol surface report must use schema {SURFACE_SCHEMA}"
        )

    contracts = report.get("contracts")
    if not isinstance(contracts, dict) or not contracts:
        raise NatSpecCoverageError("protocol surface report has no contracts")

    items: list[SurfaceItem] = []
    for contract_name, contract in sorted(contracts.items()):
        if not isinstance(contract, dict):
            raise NatSpecCoverageError(f"{contract_name} report must be an object")
        source = contract.get("source")
        if not isinstance(source, str) or not source:
            raise NatSpecCoverageError(f"{contract_name} is missing source")

        for kind, report_key in (
            ("function", "functions"),
            ("event", "events"),
            ("custom_error", "custom_errors"),
        ):
            entries = contract.get(report_key, [])
            if not isinstance(entries, list):
                raise NatSpecCoverageError(f"{contract_name}.{report_key} must be a list")
            for entry in entries:
                name = entry.get("name")
                signature = entry.get("signature")
                if not isinstance(name, str) or not isinstance(signature, str):
                    raise NatSpecCoverageError(
                        f"{contract_name}.{report_key} entry is missing name/signature"
                    )
                items.append(
                    SurfaceItem(
                        contract=contract_name,
                        source=source,
                        kind=kind,
                        name=name,
                        signature=signature,
                        arity=signature_arity(signature),
                    )
                )
    return sorted(items, key=lambda item: item.item_id)


def line_has_natspec(lines: list[str], declaration_index: int) -> bool:
    index = declaration_index - 1
    while index >= 0 and lines[index].strip() == "":
        index -= 1
    if index < 0:
        return False

    stripped = lines[index].strip()
    if stripped.startswith("///"):
        return True
    if stripped.endswith("*/"):
        while index >= 0:
            candidate = lines[index].strip()
            if candidate.startswith("/**"):
                return True
            if candidate.startswith("/*") and not candidate.startswith("/**"):
                return False
            index -= 1
    return False


def declaration_header(lines: list[str], start_index: int) -> str:
    parts = []
    for index in range(start_index, min(len(lines), start_index + 40)):
        line = lines[index].split("//", 1)[0].strip()
        if line:
            parts.append(line)
        joined = " ".join(parts)
        if "{" in joined or ";" in joined:
            return joined
    return " ".join(parts)


def count_declaration_parameters(header: str) -> int:
    start = header.find("(")
    if start < 0:
        return 0

    depth = 0
    chars = []
    for char in header[start + 1 :]:
        if char == "(":
            depth += 1
            chars.append(char)
        elif char == ")":
            if depth == 0:
                break
            depth -= 1
            chars.append(char)
        else:
            chars.append(char)

    params = "".join(chars).strip()
    if params == "":
        return 0

    depth = 0
    count = 1
    for char in params:
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == "," and depth == 0:
            count += 1
    return count


def scan_source(repo_root: Path, source: str) -> list[Declaration]:
    source_path = repo_root / source
    if not source_path.is_file():
        raise NatSpecCoverageError(f"missing source file: {source}")

    lines = source_path.read_text(encoding="utf-8").splitlines()
    declarations: list[Declaration] = []
    for index, line in enumerate(lines):
        for kind, pattern in DECLARATION_RE.items():
            match = pattern.search(line)
            if match is None:
                continue
            header = declaration_header(lines, index)
            declarations.append(
                Declaration(
                    source=source,
                    kind=kind,
                    name=match.group(1),
                    arity=count_declaration_parameters(header),
                    line=index + 1,
                    natspec=line_has_natspec(lines, index),
                )
            )

        match = PUBLIC_VARIABLE_RE.search(line)
        if match is not None:
            declarations.append(
                Declaration(
                    source=source,
                    kind="variable",
                    name=match.group(1),
                    arity=None,
                    line=index + 1,
                    natspec=line_has_natspec(lines, index),
                )
            )

    return declarations


def declaration_for_item(
    item: SurfaceItem,
    declarations_by_source: dict[str, list[Declaration]],
) -> Declaration | None:
    declarations = declarations_by_source.get(item.source, [])
    exact = [
        declaration
        for declaration in declarations
        if declaration.kind == item.kind
        and declaration.name == item.name
        and declaration.arity == item.arity
    ]
    if exact:
        return exact[0]

    generated_getters = [
        declaration
        for declaration in declarations
        if declaration.kind == "variable" and declaration.name == item.name
    ]
    if generated_getters:
        return generated_getters[0]

    same_name = [
        declaration
        for declaration in declarations
        if declaration.kind == item.kind and declaration.name == item.name
    ]
    if len(same_name) == 1:
        return same_name[0]
    return None


def coverage_gaps(repo_root: Path, report: dict[str, Any]) -> list[CoverageGap]:
    items = surface_items(report)
    sources = sorted({item.source for item in items})
    declarations_by_source = {
        source: scan_source(repo_root, source) for source in sources
    }

    gaps: list[CoverageGap] = []
    for item in items:
        declaration = declaration_for_item(item, declarations_by_source)
        if declaration is None:
            gaps.append(CoverageGap(item=item, status="declaration_not_in_source", line=None))
            continue
        if declaration.kind == "variable" and not declaration.natspec:
            gaps.append(
                CoverageGap(
                    item=item,
                    status="public_variable_getter_missing_natspec",
                    line=declaration.line,
                )
            )
            continue
        if not declaration.natspec:
            gaps.append(
                CoverageGap(item=item, status="missing_natspec", line=declaration.line)
            )
    return sorted(gaps, key=lambda gap: gap.item_id)


def default_reason(status: str) -> str:
    if status == "declaration_not_in_source":
        return (
            "ABI entry is inherited from a dependency or generated outside the "
            "first-party declaration body; keep explicit until the source surface "
            "is documented or intentionally excluded."
        )
    if status == "public_variable_getter_missing_natspec":
        return (
            "Compiler-generated public getter currently lacks NatSpec on the "
            "state variable; keep explicit until the variable is documented."
        )
    return (
        "Current first-party release surface lacks nearby NatSpec; keep explicit "
        "until the Solidity declaration receives NatSpec."
    )


def baseline_from_gaps(gaps: list[CoverageGap]) -> dict[str, Any]:
    return {
        "schema_version": BASELINE_SCHEMA,
        "scope": "release-relevant protocol surface from protocol-surface-report.json",
        "policy": (
            "New missing NatSpec entries fail unless this baseline is deliberately "
            "updated with a reason. Baseline entries are documentation debt, not "
            "proof of complete API documentation."
        ),
        "exclusions": [
            {
                "id": gap.item_id,
                "contract": gap.item.contract,
                "source": gap.item.source,
                "kind": gap.item.kind,
                "signature": gap.item.signature,
                "status": gap.status,
                "line": gap.line,
                "reason": default_reason(gap.status),
                "follow_up": "CON-006 follow-up NatSpec burn-down or accepted exclusion review.",
            }
            for gap in gaps
        ],
    }


def validate_baseline(value: Any) -> dict[str, dict[str, Any]]:
    if not isinstance(value, dict):
        raise NatSpecCoverageError("NatSpec baseline must be an object")
    if value.get("schema_version") != BASELINE_SCHEMA:
        raise NatSpecCoverageError(f"NatSpec baseline must use schema {BASELINE_SCHEMA}")
    exclusions = value.get("exclusions")
    if not isinstance(exclusions, list):
        raise NatSpecCoverageError("NatSpec baseline exclusions must be a list")

    by_id: dict[str, dict[str, Any]] = {}
    for index, raw in enumerate(exclusions):
        if not isinstance(raw, dict):
            raise NatSpecCoverageError(f"NatSpec exclusion {index} must be an object")
        item_id = raw.get("id")
        if not isinstance(item_id, str) or item_id == "":
            raise NatSpecCoverageError(f"NatSpec exclusion {index} is missing id")
        if item_id in by_id:
            raise NatSpecCoverageError(f"duplicate NatSpec exclusion: {item_id}")
        for field in ("contract", "source", "kind", "signature", "status", "reason", "follow_up"):
            if not isinstance(raw.get(field), str) or raw[field] == "":
                raise NatSpecCoverageError(f"NatSpec exclusion {item_id} is missing {field}")
        by_id[item_id] = raw
    return by_id


def validate_coverage(repo_root: Path, surface_report: Path, baseline_path: Path) -> None:
    report = load_json(surface_report)
    gaps = coverage_gaps(repo_root, report)
    baseline = validate_baseline(load_json(baseline_path))
    gap_ids = {gap.item_id for gap in gaps}
    baseline_ids = set(baseline)

    stale = sorted(baseline_ids - gap_ids)
    if stale:
        raise NatSpecCoverageError(
            "NatSpec baseline has stale exclusions: " + ", ".join(stale[:20])
        )

    missing = [gap for gap in gaps if gap.item_id not in baseline]
    if missing:
        rendered = ", ".join(f"{gap.item_id} ({gap.status})" for gap in missing[:20])
        raise NatSpecCoverageError("undocumented protocol surface missing baseline: " + rendered)

    for gap in gaps:
        entry = baseline[gap.item_id]
        expected = {
            "contract": gap.item.contract,
            "source": gap.item.source,
            "kind": gap.item.kind,
            "signature": gap.item.signature,
            "status": gap.status,
        }
        for key, value in expected.items():
            if entry.get(key) != value:
                raise NatSpecCoverageError(
                    f"NatSpec baseline {gap.item_id} has stale {key}: "
                    f"expected {value}, got {entry.get(key)}"
                )
        if entry.get("line") != gap.line:
            raise NatSpecCoverageError(
                f"NatSpec baseline {gap.item_id} has stale line: "
                f"expected {gap.line}, got {entry.get('line')}"
            )

    covered = len(surface_items(report)) - len(gaps)
    print(
        "NatSpec coverage baseline is current: "
        f"{covered} documented entries, {len(gaps)} explicit exclusions"
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--surface-report", type=Path, default=DEFAULT_SURFACE_REPORT)
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument(
        "--write-baseline",
        action="store_true",
        help="Write the current missing NatSpec baseline instead of checking it.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    surface_report = args.surface_report
    if not surface_report.is_absolute():
        surface_report = repo_root / surface_report
    baseline = args.baseline
    if not baseline.is_absolute():
        baseline = repo_root / baseline

    try:
        if args.write_baseline:
            report = load_json(surface_report)
            gaps = coverage_gaps(repo_root, report)
            write_json(baseline, baseline_from_gaps(gaps))
            print(normalize_repo_path(baseline, repo_root))
            return 0
        validate_coverage(repo_root, surface_report, baseline)
    except NatSpecCoverageError as exc:
        print(f"NatSpec coverage check failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

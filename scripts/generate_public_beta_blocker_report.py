#!/usr/bin/env python3
"""Generate a deterministic public-beta evidence blocker report."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

import check_public_beta_evidence as evidence_checker


GENERATOR_VERSION = "1"
SCRIPT_NAME = Path(__file__).name
DEFAULT_OUTPUT = Path("release-artifacts/latest/public-beta-blockers.md")
INCOMPLETE_STATUSES = evidence_checker.REQUIREMENT_STATUSES - {"complete"}
STATUS_ORDER = (
    "missing",
    "pending",
    "blocked",
    "accepted_risk",
    "not_applicable",
    "complete",
)
PHASES = (
    (
        evidence_checker.PUBLIC_BETA_PHASE,
        "Public Beta",
        evidence_checker.PUBLIC_BETA_REQUIREMENTS,
    ),
    (
        evidence_checker.PRODUCTION_PHASE,
        "Production Release",
        evidence_checker.PRODUCTION_REQUIREMENTS,
    ),
)
VALIDATION_COMMANDS = (
    ("Shared evidence status manifest", "python scripts/test_public_beta_evidence.py"),
    ("Shared evidence status manifest", "python scripts/check_public_beta_evidence.py"),
    (
        "Public beta blocker report",
        "python scripts/test_public_beta_blocker_report.py",
    ),
    (
        "Public beta blocker report",
        "python scripts/generate_public_beta_blocker_report.py --check",
    ),
    (
        "Non-local release evidence",
        "python scripts/test_non_local_release_evidence.py",
    ),
    (
        "Non-local release evidence",
        "python scripts/check_non_local_release_evidence.py",
    ),
    (
        "Drop authorization signing evidence",
        "python scripts/test_drop_authorization_signing_evidence.py",
    ),
    (
        "Drop authorization signing evidence",
        "python scripts/check_drop_authorization_signing_evidence.py",
    ),
    (
        "Signer custody readiness evidence",
        "python scripts/test_signer_custody_readiness.py",
    ),
    (
        "Signer custody readiness evidence",
        "python scripts/check_signer_custody_readiness.py",
    ),
    ("Release signatures", "python scripts/test_release_signatures.py"),
    ("Release signatures", "python scripts/check_release_signatures.py"),
    ("Ceremony evidence", "python scripts/test_ceremony_evidence.py"),
    ("Ceremony evidence", "python scripts/check_ceremony_evidence.py"),
    ("Randomizer operations", "python scripts/test_randomizer_operations.py"),
    ("Randomizer operations", "python scripts/check_randomizer_operations.py"),
    (
        "Marketplace/indexer evidence",
        "python scripts/test_marketplace_indexer_evidence.py",
    ),
    (
        "Marketplace/indexer evidence",
        "python scripts/check_marketplace_indexer_evidence.py",
    ),
    ("Release manifest", "python scripts/test_release_manifest.py"),
    ("Release manifest", "python scripts/generate_release_manifest.py --check"),
    ("Release checksums", "python scripts/test_release_checksums.py"),
    ("Release checksums", "python scripts/generate_release_checksums.py --check"),
)


class PublicBetaBlockerReportError(RuntimeError):
    """Raised when blocker-report generation cannot safely continue."""


def resolve_repo_path(repo_root: Path, path: Path) -> Path:
    """Resolve a path relative to the repository root."""
    return path if path.is_absolute() else repo_root / path


def normalize_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path when possible."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def markdown_cell(value: Any) -> str:
    """Escape a value for a compact Markdown table cell."""
    text = " ".join(str(value).split())
    if not text:
        return "none"
    return text.replace("\\", "\\\\").replace("|", "\\|")


def markdown_table(headers: list[str], rows: list[list[Any]]) -> str:
    """Build a deterministic Markdown table."""
    lines = [
        "| " + " | ".join(markdown_cell(header) for header in headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(markdown_cell(cell) for cell in row) + " |")
    return "\n".join(lines)


def load_evidence_document(evidence_path: Path, repo_root: Path) -> dict[str, Any]:
    """Load and validate the shared evidence status manifest."""
    resolved = resolve_repo_path(repo_root, evidence_path)
    try:
        data = evidence_checker.load_json(resolved)
        evidence_checker.validate_evidence_document(data, repo_root, str(resolved))
    except evidence_checker.PublicBetaEvidenceError as exc:
        raise PublicBetaBlockerReportError(
            f"invalid public beta evidence {normalize_path(resolved, repo_root)}: {exc}"
        ) from exc
    if not isinstance(data, dict):
        raise PublicBetaBlockerReportError("public beta evidence must be an object")
    return data


def canonical_requirements(data: dict[str, Any]) -> dict[str, dict[str, dict[str, Any]]]:
    """Return requirement rows by phase and ID in the checker-defined universe."""
    by_phase: dict[str, dict[str, dict[str, Any]]] = {
        phase: {} for phase, _, _ in PHASES
    }
    for item in data["requirements"]:
        by_phase[item["phase"]][item["id"]] = item
    return by_phase


def evidence_posture(requirement: dict[str, Any]) -> str:
    """Summarize whether evidence is absent, local-template-only, or reviewed."""
    status = requirement["status"]
    evidence = requirement["evidence"]
    if status == "not_applicable":
        return "not-applicable"
    if status == "accepted_risk":
        return "risk-accepted"
    if not evidence:
        return "external/future"

    paths = [str(reference.get("path", "")) for reference in evidence]
    if paths and all("template" in Path(path).name for path in paths):
        return "local-template-only"
    if status == "complete":
        return "reviewed-external"
    return "retained-incomplete"


def risk_summary(requirement: dict[str, Any]) -> str:
    """Summarize risk-acceptance metadata without expanding full notes."""
    risk_acceptance = requirement["risk_acceptance"]
    if risk_acceptance is None:
        return "none"
    return (
        f"{risk_acceptance['accepted_by']}; "
        f"expires {risk_acceptance['expires_at']}; "
        f"{risk_acceptance['reference']}"
    )


def requirement_table_rows(
    by_phase: dict[str, dict[str, dict[str, Any]]],
    phase: str,
    requirement_ids: tuple[str, ...],
    statuses: frozenset[str] | set[str],
) -> list[list[Any]]:
    """Build table rows for matching requirements."""
    rows: list[list[Any]] = []
    for requirement_id in requirement_ids:
        requirement = by_phase[phase][requirement_id]
        if requirement["status"] not in statuses:
            continue
        rows.append(
            [
                f"`{requirement_id}`",
                f"`{requirement['status']}`",
                requirement["owner"],
                evidence_posture(requirement),
                len(requirement["evidence"]),
                risk_summary(requirement),
                requirement["notes"],
            ]
        )
    return rows


def summary_rows(
    data: dict[str, Any],
    by_phase: dict[str, dict[str, dict[str, Any]]],
) -> list[list[Any]]:
    """Build status-count rows for each phase."""
    rows: list[list[Any]] = []
    for phase, label, requirement_ids in PHASES:
        counts = {status: 0 for status in STATUS_ORDER}
        for requirement_id in requirement_ids:
            counts[by_phase[phase][requirement_id]["status"]] += 1
        incomplete = sum(counts[status] for status in INCOMPLETE_STATUSES)
        rows.append(
            [
                label,
                f"`{data['status'][phase]}`",
                counts["missing"],
                counts["pending"],
                counts["blocked"],
                counts["accepted_risk"],
                counts["not_applicable"],
                counts["complete"],
                incomplete,
            ]
        )
    return rows


def external_future_rows(by_phase: dict[str, dict[str, dict[str, Any]]]) -> list[list[Any]]:
    """List rows that still have no retained evidence references."""
    rows: list[list[Any]] = []
    for phase, label, requirement_ids in PHASES:
        for requirement_id in requirement_ids:
            requirement = by_phase[phase][requirement_id]
            if requirement["status"] == "complete" or requirement["evidence"]:
                continue
            rows.append(
                [
                    label,
                    f"`{requirement_id}`",
                    f"`{requirement['status']}`",
                    requirement["notes"],
                ]
            )
    return rows


def reviewed_rows(by_phase: dict[str, dict[str, dict[str, Any]]]) -> list[list[Any]]:
    """List completed rows backed by retained evidence."""
    rows: list[list[Any]] = []
    for phase, label, requirement_ids in PHASES:
        for requirement_id in requirement_ids:
            requirement = by_phase[phase][requirement_id]
            if requirement["status"] != "complete":
                continue
            rows.append(
                [
                    label,
                    f"`{requirement_id}`",
                    evidence_posture(requirement),
                    len(requirement["evidence"]),
                    requirement["notes"],
                ]
            )
    return rows


def build_output_text(repo_root: Path, evidence_path: Path, output_path: Path) -> str:
    """Build the Markdown blocker report."""
    data = load_evidence_document(evidence_path, repo_root)
    by_phase = canonical_requirements(data)
    redaction_policy = data["redaction_policy"]
    resolved_evidence = resolve_repo_path(repo_root, evidence_path)
    resolved_output = resolve_repo_path(repo_root, output_path)

    lines = [
        "# Public Beta Evidence Blocker Report",
        "",
        (
            "This generated report is derived only from the committed shared "
            "release evidence status manifest. It preserves the no-secret "
            "policy and does not change readiness claims."
        ),
        "",
        "The committed baseline remains intentionally blocked for public beta and production.",
        "",
        "## Report Metadata",
        "",
        markdown_table(
            ["Field", "Value"],
            [
                ["Generated by", f"`scripts/{SCRIPT_NAME}:{GENERATOR_VERSION}`"],
                ["Generator version", f"`{GENERATOR_VERSION}`"],
                ["Output", f"`{normalize_path(resolved_output, repo_root)}`"],
                ["Source manifest", f"`{normalize_path(resolved_evidence, repo_root)}`"],
                ["Schema version", f"`{data['schema_version']}`"],
                ["Release version", f"`{data['release_version']}`"],
                ["Source repository", data["source"]["repository"]],
                ["Source git commit", f"`{data['source']['git_commit']}`"],
                ["Source dirty", f"`{str(data['source']['source_dirty']).lower()}`"],
                ["CI run", f"`{data['source']['ci_run']}`"],
                ["Public beta status", f"`{data['status'][evidence_checker.PUBLIC_BETA_PHASE]}`"],
                [
                    "Production release status",
                    f"`{data['status'][evidence_checker.PRODUCTION_PHASE]}`",
                ],
                ["No-secret policy", f"`{str(redaction_policy['no_secrets']).lower()}`"],
                [
                    "Redacted field families",
                    ", ".join(f"`{field}`" for field in redaction_policy["redacted_fields"]),
                ],
            ],
        ),
        "",
        "## Status Summary",
        "",
        (
            "Rows are incomplete when their status is any value other than "
            "`complete`. The evidence checker treats `missing`, `pending`, and "
            "`blocked` as blocking statuses; `accepted_risk` and `not_applicable` "
            "remain visible here because they are not completion evidence."
        ),
        "",
        markdown_table(
            [
                "Phase",
                "Overall Status",
                "Missing",
                "Pending",
                "Blocked",
                "Accepted Risk",
                "Not Applicable",
                "Complete",
                "Incomplete",
            ],
            summary_rows(data, by_phase),
        ),
    ]

    for phase, label, requirement_ids in PHASES:
        rows = requirement_table_rows(by_phase, phase, requirement_ids, INCOMPLETE_STATUSES)
        lines.extend(
            [
                "",
                f"## Incomplete {label} Rows",
                "",
                markdown_table(
                    [
                        "Requirement",
                        "Status",
                        "Owner",
                        "Evidence Posture",
                        "Evidence Count",
                        "Risk Acceptance",
                        "Notes",
                    ],
                    rows,
                )
                if rows
                else "No incomplete rows.",
            ]
        )

    reviewed = reviewed_rows(by_phase)
    lines.extend(
        [
            "",
            "## Reviewed External Evidence Rows",
            "",
            markdown_table(
                ["Phase", "Requirement", "Evidence Posture", "Evidence Count", "Notes"],
                reviewed,
            )
            if reviewed
            else "No reviewed external evidence rows are complete in the committed baseline.",
            "",
            "## External Evidence Still Required",
            "",
            markdown_table(
                ["Phase", "Requirement", "Status", "Required Retained Evidence"],
                external_future_rows(by_phase),
            ),
            "",
            "## Validation Commands",
            "",
            markdown_table(
                ["Evidence Family", "Command"],
                [[family, f"`{command}`"] for family, command in VALIDATION_COMMANDS],
            ),
        ]
    )

    return "\n".join(lines) + "\n"


def write_output(repo_root: Path, evidence_path: Path, output_path: Path) -> Path:
    """Generate and write the committed report."""
    resolved_output = resolve_repo_path(repo_root, output_path)
    output_text = build_output_text(repo_root, evidence_path, output_path)
    resolved_output.parent.mkdir(parents=True, exist_ok=True)
    resolved_output.write_text(output_text, encoding="utf-8", newline="\n")
    return resolved_output


def check_output(repo_root: Path, evidence_path: Path, output_path: Path) -> int:
    """Check that the committed report matches generated output."""
    resolved_output = resolve_repo_path(repo_root, output_path)
    if not resolved_output.exists():
        print(
            f"missing {normalize_path(resolved_output, repo_root)}",
            file=sys.stderr,
        )
        print(
            "run `python scripts/generate_public_beta_blocker_report.py` "
            "and commit the regenerated file",
            file=sys.stderr,
        )
        return 1

    expected_text = build_output_text(repo_root, evidence_path, output_path)
    actual_text = resolved_output.read_text(encoding="utf-8")
    if actual_text != expected_text:
        print(
            f"changed {normalize_path(resolved_output, repo_root)}",
            file=sys.stderr,
        )
        print(
            "run `python scripts/generate_public_beta_blocker_report.py` "
            "and commit the regenerated file",
            file=sys.stderr,
        )
        return 1

    print("public beta blocker report is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--evidence", type=Path, default=evidence_checker.DEFAULT_EVIDENCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the generator CLI."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    try:
        if args.check:
            return check_output(repo_root, args.evidence, args.output)
        written = write_output(repo_root, args.evidence, args.output)
    except PublicBetaBlockerReportError as exc:
        print(f"public beta blocker report generation failed: {exc}", file=sys.stderr)
        return 1
    print(normalize_path(written, repo_root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

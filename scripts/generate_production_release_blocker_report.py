#!/usr/bin/env python3
"""Generate a deterministic production-release evidence blocker report."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

import check_non_local_release_evidence as non_local_checker
import check_public_beta_evidence as evidence_checker
import generate_public_beta_blocker_report as shared_report


GENERATOR_VERSION = "1"
SCRIPT_NAME = Path(__file__).name
DEFAULT_OUTPUT = Path("release-artifacts/latest/production-release-blockers.md")
PRODUCTION_PHASE = evidence_checker.PRODUCTION_PHASE
PRODUCTION_REQUIREMENTS = evidence_checker.PRODUCTION_REQUIREMENTS
INCOMPLETE_STATUSES = shared_report.INCOMPLETE_STATUSES
STATUS_ORDER = shared_report.STATUS_ORDER
VALIDATION_COMMANDS = (
    ("Evidence status manifest", "python scripts/test_public_beta_evidence.py"),
    ("Evidence status manifest", "python scripts/check_public_beta_evidence.py"),
    (
        "Production release blocker report",
        "python scripts/test_production_release_blocker_report.py",
    ),
    (
        "Production release blocker report",
        "python scripts/generate_production_release_blocker_report.py --check",
    ),
    (
        "Non-local release evidence",
        "python scripts/test_non_local_release_evidence.py",
    ),
    (
        "Non-local release evidence",
        "python scripts/check_non_local_release_evidence.py",
    ),
    ("Release signatures", "python scripts/test_release_signatures.py"),
    ("Release signatures", "python scripts/check_release_signatures.py"),
    (
        "Signer custody readiness evidence",
        "python scripts/test_signer_custody_readiness.py",
    ),
    (
        "Signer custody readiness evidence",
        "python scripts/check_signer_custody_readiness.py",
    ),
    ("Release manifest", "python scripts/test_release_manifest.py"),
    ("Release manifest", "python scripts/generate_release_manifest.py --check"),
    ("Release checksums", "python scripts/test_release_checksums.py"),
    ("Release checksums", "python scripts/generate_release_checksums.py --check"),
)


class ProductionReleaseBlockerReportError(RuntimeError):
    """Raised when production-report generation cannot safely continue."""


def normalize_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path when possible."""
    return shared_report.normalize_path(path, repo_root)


def resolve_repo_path(repo_root: Path, path: Path) -> Path:
    """Resolve a path relative to the repository root."""
    return shared_report.resolve_repo_path(repo_root, path)


def load_evidence_document(evidence_path: Path, repo_root: Path) -> dict[str, Any]:
    """Load and validate the evidence manifest."""
    try:
        return shared_report.load_evidence_document(evidence_path, repo_root)
    except shared_report.PublicBetaBlockerReportError as exc:
        raise ProductionReleaseBlockerReportError(str(exc)) from exc


def canonical_requirements(data: dict[str, Any]) -> dict[str, dict[str, dict[str, Any]]]:
    """Return requirement rows by phase and ID in the checker-defined universe."""
    return shared_report.canonical_requirements(data)


def production_template_map(repo_root: Path) -> dict[str, Path]:
    """Return production requirement IDs mapped to checked template paths."""
    try:
        non_local_checker.validate_production_release_template_set(repo_root)
        paths = non_local_checker.production_release_template_paths(repo_root)
        by_requirement = {}
        for path in paths:
            evidence = non_local_checker.require_dict(
                non_local_checker.load_json(path),
                str(path),
            )
            requirement_id = non_local_checker.require_string(
                evidence.get("public_beta_requirement_id"),
                f"{path}.public_beta_requirement_id",
            )
            if requirement_id in PRODUCTION_REQUIREMENTS:
                by_requirement[requirement_id] = path
    except non_local_checker.NonLocalReleaseEvidenceError as exc:
        raise ProductionReleaseBlockerReportError(
            f"invalid production-release template set: {exc}"
        ) from exc

    missing = sorted(set(PRODUCTION_REQUIREMENTS) - set(by_requirement))
    if missing:
        raise ProductionReleaseBlockerReportError(
            "missing production-release template(s): " + ", ".join(missing)
        )
    return by_requirement


def summary_rows(
    data: dict[str, Any],
    by_phase: dict[str, dict[str, dict[str, Any]]],
) -> list[list[Any]]:
    """Build status-count rows for the production release phase."""
    counts = {status: 0 for status in STATUS_ORDER}
    for requirement_id in PRODUCTION_REQUIREMENTS:
        counts[by_phase[PRODUCTION_PHASE][requirement_id]["status"]] += 1
    incomplete = sum(counts[status] for status in INCOMPLETE_STATUSES)
    return [
        [
            "Production Release",
            f"`{data['status'][PRODUCTION_PHASE]}`",
            counts["missing"],
            counts["pending"],
            counts["blocked"],
            counts["accepted_risk"],
            counts["not_applicable"],
            counts["complete"],
            incomplete,
        ]
    ]


def production_requirement_rows(
    by_phase: dict[str, dict[str, dict[str, Any]]],
    template_paths: dict[str, Path],
    repo_root: Path,
    statuses: frozenset[str] | set[str],
) -> list[list[Any]]:
    """Build production requirement rows for matching statuses."""
    rows: list[list[Any]] = []
    status_rank = {status: index for index, status in enumerate(STATUS_ORDER)}
    selected: list[tuple[str, str, dict[str, Any]]] = []
    for requirement_id in PRODUCTION_REQUIREMENTS:
        requirement = by_phase[PRODUCTION_PHASE][requirement_id]
        status = requirement["status"]
        if status not in statuses:
            continue
        selected.append((status, requirement_id, requirement))
    for _, requirement_id, requirement in sorted(
        selected,
        key=lambda item: (status_rank[item[0]], item[1]),
    ):
        rows.append(
            [
                f"`{requirement_id}`",
                f"`{requirement['status']}`",
                requirement["owner"],
                shared_report.evidence_posture(requirement),
                len(requirement["evidence"]),
                f"`{normalize_path(template_paths[requirement_id], repo_root)}`",
                shared_report.risk_summary(requirement),
                requirement["notes"],
            ]
        )
    return rows


def external_future_rows(
    by_phase: dict[str, dict[str, dict[str, Any]]],
    template_paths: dict[str, Path],
    repo_root: Path,
) -> list[list[Any]]:
    """List production rows that still have no retained evidence references."""
    rows: list[list[Any]] = []
    for requirement_id in PRODUCTION_REQUIREMENTS:
        requirement = by_phase[PRODUCTION_PHASE][requirement_id]
        if requirement["status"] == "complete" or requirement["evidence"]:
            continue
        rows.append(
            [
                f"`{requirement_id}`",
                f"`{requirement['status']}`",
                f"`{normalize_path(template_paths[requirement_id], repo_root)}`",
                requirement["notes"],
            ]
        )
    return rows


def reviewed_rows(by_phase: dict[str, dict[str, dict[str, Any]]]) -> list[list[Any]]:
    """List completed production rows backed by retained evidence."""
    rows: list[list[Any]] = []
    for requirement_id in PRODUCTION_REQUIREMENTS:
        requirement = by_phase[PRODUCTION_PHASE][requirement_id]
        if requirement["status"] != "complete":
            continue
        rows.append(
            [
                f"`{requirement_id}`",
                shared_report.evidence_posture(requirement),
                len(requirement["evidence"]),
                requirement["notes"],
            ]
        )
    return rows


def build_output_text(repo_root: Path, evidence_path: Path, output_path: Path) -> str:
    """Build the Markdown production blocker report."""
    data = load_evidence_document(evidence_path, repo_root)
    by_phase = canonical_requirements(data)
    templates = production_template_map(repo_root)
    redaction_policy = data["redaction_policy"]
    resolved_evidence = resolve_repo_path(repo_root, evidence_path)
    resolved_output = resolve_repo_path(repo_root, output_path)

    lines = [
        "# Production Release Evidence Blocker Report",
        "",
        (
            "This generated report is derived only from the committed evidence "
            "status manifest and the checked production-release evidence "
            "templates. It preserves the no-secret policy and does not change "
            "readiness claims."
        ),
        "",
        "The committed baseline remains intentionally blocked for production release.",
        "",
        "## Report Metadata",
        "",
        shared_report.markdown_table(
            ["Field", "Value"],
            [
                ["Generated by", f"`scripts/{SCRIPT_NAME}:{GENERATOR_VERSION}`"],
                ["Generator version", f"`{GENERATOR_VERSION}`"],
                ["Output", f"`{normalize_path(resolved_output, repo_root)}`"],
                ["Source manifest", f"`{normalize_path(resolved_evidence, repo_root)}`"],
                [
                    "Template directory",
                    f"`{non_local_checker.PRODUCTION_RELEASE_TEMPLATE_DIR.as_posix()}`",
                ],
                ["Schema version", f"`{data['schema_version']}`"],
                ["Release version", f"`{data['release_version']}`"],
                ["Source repository", data["source"]["repository"]],
                ["Source git commit", f"`{data['source']['git_commit']}`"],
                ["Source dirty", f"`{str(data['source']['source_dirty']).lower()}`"],
                ["CI run", f"`{data['source']['ci_run']}`"],
                ["Production release status", f"`{data['status'][PRODUCTION_PHASE]}`"],
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
            "`blocked` as blocking statuses; `accepted_risk` and "
            "`not_applicable` remain visible here because they are not "
            "completion evidence."
        ),
        "",
        shared_report.markdown_table(
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
        "",
        "## Incomplete Production Release Rows",
        "",
        shared_report.markdown_table(
            [
                "Requirement",
                "Status",
                "Owner",
                "Evidence Posture",
                "Evidence Count",
                "Template",
                "Risk Acceptance",
                "Notes",
            ],
            production_requirement_rows(
                by_phase,
                templates,
                repo_root,
                INCOMPLETE_STATUSES,
            ),
        ),
        "",
        "## Reviewed Production Evidence Rows",
        "",
    ]

    reviewed = reviewed_rows(by_phase)
    lines.append(
        shared_report.markdown_table(
            ["Requirement", "Evidence Posture", "Evidence Count", "Notes"],
            reviewed,
        )
        if reviewed
        else "No reviewed production evidence rows are complete in the committed baseline."
    )
    lines.extend(
        [
            "",
            "## Production Evidence Still Required",
            "",
            shared_report.markdown_table(
                ["Requirement", "Status", "Template", "Required Retained Evidence"],
                external_future_rows(by_phase, templates, repo_root),
            ),
            "",
            "## Validation Commands",
            "",
            shared_report.markdown_table(
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
            "run `python scripts/generate_production_release_blocker_report.py` "
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
            "run `python scripts/generate_production_release_blocker_report.py` "
            "and commit the regenerated file",
            file=sys.stderr,
        )
        return 1

    print("production release blocker report is current")
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
    except ProductionReleaseBlockerReportError as exc:
        print(
            f"production release blocker report generation failed: {exc}",
            file=sys.stderr,
        )
        return 1
    print(normalize_path(written, repo_root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

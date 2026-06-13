#!/usr/bin/env python3
"""Generate non-local release evidence metadata from a retained artifact."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

import check_non_local_release_evidence as evidence_checker


DEFAULT_REDACTED_FIELDS = [
    "private_key",
    "mnemonic",
    "seed_phrase",
    "api_key",
    "rpc_url",
    "unreleased_drop_payload",
]
DEFAULT_REDACTION_STATEMENT = (
    "Retained artifact was reviewed for the no-secret boundary; secrets and "
    "unreleased drop payloads were removed or were never present."
)


class NonLocalEvidenceGeneratorError(RuntimeError):
    """Raised when evidence generation cannot continue."""


def load_json(path: Path) -> Any:
    """Load JSON with generator-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise NonLocalEvidenceGeneratorError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise NonLocalEvidenceGeneratorError(f"invalid JSON in {path}: {exc}") from exc


def json_text(value: object) -> str:
    """Serialize deterministic JSON with a trailing newline."""
    return json.dumps(value, indent=2, sort_keys=False) + "\n"


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json_text(value), encoding="utf-8", newline="\n")


def repo_relative_path(repo_root: Path, path: Path, label: str) -> str:
    """Return a repository-relative path using forward slashes."""
    resolved_root = repo_root.resolve()
    resolved_path = path.resolve()
    try:
        relative = resolved_path.relative_to(resolved_root)
    except ValueError as exc:
        raise NonLocalEvidenceGeneratorError(
            f"{label} must stay inside the repository"
        ) from exc
    return relative.as_posix()


def require_existing_file(path: Path, label: str) -> None:
    """Require an input path to exist as a file."""
    if not path.is_file():
        raise NonLocalEvidenceGeneratorError(f"{label} references missing file: {path}")


def git_output(repo_root: Path, args: list[str]) -> str:
    """Run git and return trimmed stdout."""
    git_path = shutil.which("git")
    if git_path is None:
        raise NonLocalEvidenceGeneratorError("git executable was not found")
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
        raise NonLocalEvidenceGeneratorError("git executable was not found") from exc
    except subprocess.CalledProcessError as exc:
        message = exc.stderr.strip() or exc.stdout.strip() or str(exc)
        raise NonLocalEvidenceGeneratorError(
            f"git {' '.join(args)} failed: {message}"
        ) from exc
    return result.stdout.strip()


def default_git_commit(repo_root: Path) -> str:
    """Return the current HEAD commit for source metadata."""
    return git_output(repo_root, ["rev-parse", "HEAD"])


def parse_chain_id(value: str) -> int | str:
    """Parse a CLI chain ID value."""
    if value == "not_applicable":
        return value
    try:
        parsed = int(value, 10)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            "chain ID must be an integer or not_applicable"
        ) from exc
    if parsed < 1:
        raise argparse.ArgumentTypeError("chain ID must be greater than zero")
    return parsed


def template_redacted_fields(template: dict[str, Any]) -> list[str]:
    """Return the template redaction fields or a conservative default."""
    policy = template.get("redaction_policy")
    if isinstance(policy, dict):
        fields = policy.get("redacted_fields")
        if isinstance(fields, list):
            strings = [field for field in fields if isinstance(field, str) and field]
            if strings:
                return strings
    return DEFAULT_REDACTED_FIELDS


def template_repository(template: dict[str, Any]) -> str:
    """Return the template repository source or the canonical upstream URL."""
    source = template.get("source")
    if isinstance(source, dict):
        repository = source.get("repository")
        if isinstance(repository, str) and repository:
            return repository
    return "https://github.com/6529-Collections/6529Stream"


def default_operator_notes(template_path: str, requirement_id: str) -> str:
    """Return a safe default operator note."""
    return (
        f"Generated from {template_path} for {requirement_id}; replace with "
        "operator and reviewer notes before marking the requirement complete."
    )


def build_evidence_document(args: argparse.Namespace, repo_root: Path) -> dict[str, Any]:
    """Build checker-compatible evidence metadata from CLI arguments."""
    template_path = args.template if args.template.is_absolute() else repo_root / args.template
    retained_path = (
        args.retained_artifact
        if args.retained_artifact.is_absolute()
        else repo_root / args.retained_artifact
    )
    require_existing_file(template_path, "template")
    require_existing_file(retained_path, "retained artifact")

    template = evidence_checker.require_dict(load_json(template_path), str(template_path))
    evidence_checker.validate_evidence_document(template, repo_root, str(template_path))
    if template.get("record_type") != "template":
        raise NonLocalEvidenceGeneratorError("template must use record_type: template")

    requirement_id = evidence_checker.require_string(
        template.get("public_beta_requirement_id"),
        "template.public_beta_requirement_id",
    )
    source_git_commit = args.source_git_commit or default_git_commit(repo_root)
    template_relative = repo_relative_path(repo_root, template_path, "template")
    retained_relative = repo_relative_path(repo_root, retained_path, "retained artifact")
    redacted_fields = args.redacted_field or template_redacted_fields(template)

    document = {
        "schema_version": evidence_checker.EVIDENCE_SCHEMA,
        "evidence_id": args.evidence_id
        or f"{requirement_id.replace('_', '-')}-{args.environment}-evidence",
        "record_type": "evidence",
        "review_status": args.review_status,
        "environment": args.environment,
        "chain_id": args.chain_id,
        "block_or_reference": args.block_or_reference,
        "command_or_source_system": args.command_or_source_system,
        "retained_path": retained_relative,
        "sha256": evidence_checker.file_sha256(retained_path),
        "redaction_statement": args.redaction_statement,
        "owner": args.owner,
        "reviewer": args.reviewer,
        "public_beta_requirement_id": requirement_id,
        "source": {
            "repository": args.source_repository or template_repository(template),
            "git_commit": source_git_commit,
            "source_dirty": args.source_dirty,
            "ci_run": args.source_ci_run,
        },
        "redaction_policy": {
            "no_secrets": True,
            "redacted_fields": redacted_fields,
        },
        "template_notice": (
            "Generated evidence metadata. This file is not completion evidence "
            "until it is reviewed and linked from public-beta evidence."
        ),
        "operator_notes": args.operator_notes
        or default_operator_notes(template_relative, requirement_id),
    }
    evidence_checker.validate_evidence_document(document, repo_root, str(args.output))
    return document


def check_output(output_path: Path, generated: dict[str, Any]) -> None:
    """Verify the existing output matches the generated document."""
    if not output_path.is_file():
        raise NonLocalEvidenceGeneratorError(
            f"{output_path} is missing; rerun without --check and commit the output"
        )
    existing = load_json(output_path)
    if existing != generated:
        raise NonLocalEvidenceGeneratorError(
            f"{output_path} is stale; rerun scripts/generate_non_local_release_evidence.py"
        )


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser."""
    parser = argparse.ArgumentParser(
        description=(
            "Generate checker-compatible non-local release evidence metadata "
            "from a committed template and retained artifact."
        )
    )
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--retained-artifact", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--environment",
        choices=sorted(evidence_checker.ENVIRONMENTS),
        required=True,
    )
    parser.add_argument("--chain-id", type=parse_chain_id, required=True)
    parser.add_argument("--block-or-reference", required=True)
    parser.add_argument("--command-or-source-system", required=True)
    parser.add_argument("--owner", required=True)
    parser.add_argument("--reviewer", default="TBD")
    parser.add_argument(
        "--review-status",
        choices=["pending_review", "reviewed"],
        default="pending_review",
    )
    parser.add_argument("--evidence-id")
    parser.add_argument("--source-repository")
    parser.add_argument("--source-git-commit")
    parser.add_argument("--source-ci-run", default="TBD")
    parser.add_argument("--source-dirty", action="store_true")
    parser.add_argument(
        "--redaction-statement",
        default=DEFAULT_REDACTION_STATEMENT,
    )
    parser.add_argument(
        "--redacted-field",
        action="append",
        default=[],
        help="Redacted field name. May be repeated. Defaults to the template policy.",
    )
    parser.add_argument("--operator-notes")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check that the existing output matches instead of writing it.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the non-local evidence generator."""
    parser = build_parser()
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    output_path = args.output if args.output.is_absolute() else repo_root / args.output
    try:
        generated = build_evidence_document(args, repo_root)
        if args.check:
            check_output(output_path, generated)
            print(f"{output_path} is current")
        else:
            write_json(output_path, generated)
            print(f"wrote {output_path}")
    except (NonLocalEvidenceGeneratorError, evidence_checker.NonLocalReleaseEvidenceError) as exc:
        print(f"non-local evidence generation failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

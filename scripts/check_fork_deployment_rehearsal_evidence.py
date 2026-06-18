#!/usr/bin/env python3
"""Validate retained fork deployment rehearsal evidence artifacts."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path


REQUIREMENT_ID = "fork_deployment_rehearsal"
DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/evidence/fork-deployment-rehearsal/"
        "fork-deployment-rehearsal-retained-artifact-template.md"
    )
]

REQUIRED_HEADINGS = [
    "# Fork Deployment Rehearsal Retained Artifact",
    "## Evidence Status",
    "## Source And Fork Reference",
    "## Required Retained Artifacts",
    "## Rehearsal Results",
    "## Review",
    "## Redaction",
    "## Validation Commands",
    "## Operator Notes",
]

REQUIRED_FIELDS = {
    "Requirement ID",
    "Review status",
    "Readiness claim",
    "Environment",
    "Chain ID",
    "Repository",
    "Git commit",
    "CI run or operator transcript",
    "Fork block number",
    "Fork block hash",
    "Command",
    "Sanitized command transcript",
    "Sanitized Foundry broadcast",
    "Generated deployment manifest",
    "Generated address book",
    "Verification status",
    "Gas or invariant summary",
    "Release manifest/checksum digests",
    "Deployment completed",
    "Manifest generated",
    "Address book generated",
    "Verification checked",
    "Gas or invariant summary checked",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "Unreleased drop payloads removed",
}

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
REVIEW_DECISIONS = {"template", "pending_review", "reviewed", "changes_requested"}
FINAL_VALUE_FIELDS = [
    "Git commit",
    "CI run or operator transcript",
    "Fork block number",
    "Fork block hash",
    "Command",
    "Sanitized command transcript",
    "Sanitized Foundry broadcast",
    "Generated deployment manifest",
    "Generated address book",
    "Verification status",
    "Gas or invariant summary",
    "Release manifest/checksum digests",
    "Deployment completed",
    "Manifest generated",
    "Address book generated",
    "Verification checked",
    "Gas or invariant summary checked",
    "Operator",
    "Reviewer",
]
RETAINED_FILE_FIELDS = [
    "Sanitized command transcript",
    "Sanitized Foundry broadcast",
    "Generated deployment manifest",
    "Generated address book",
]
OPTIONAL_PATH_FIELD_LABELS = [
    "Gas or invariant summary",
]

REQUIRED_COMMANDS = [
    "python scripts/test_fork_deployment_rehearsal_evidence.py",
    "python scripts/check_fork_deployment_rehearsal_evidence.py",
    "python scripts/generate_non_local_release_evidence.py",
    "python scripts/check_non_local_release_evidence.py",
    "python scripts/check_public_beta_evidence.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]

FIELD_RE = re.compile(r"^- (?P<label>[^:]+): (?P<value>.*)$")
SHA256_RE = re.compile(r"sha256:[0-9a-f]{64}")
SECRET_VALUE_RE = re.compile(
    r"\b("
    r"private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|"
    r"api[_ -]?key|password|unreleased[_ -]?drop[_ -]?payload"
    r")\s*[:=]",
    re.IGNORECASE,
)
CLI_SECRET_RE = re.compile(
    r"("
    r"--(?:private-key|mnemonic|seed(?:-phrase)?)\b(?:\s+|=)\S+|"
    r"--rpc-url\b(?:\s+|=)(?!(?:<redacted(?:\s+[^>]+)?>|redacted(?:[_-][a-z0-9]+)*\b))\S+|"
    r"\bAuthorization\s*:\s*Bearer\s+\S+|"
    r"\bBearer\s+[A-Za-z0-9._~+/=-]{12,}|"
    r"https?://[^\s`]*(?:alchemy|ankr|blastapi|chainstack|infura|quicknode)[^\s`]*|"
    r"https?://[^\s`]*[?&](?:api[_-]?key|apikey|token|secret)=[^\s`&]+"
    r")",
    re.IGNORECASE,
)


class ForkDeploymentRehearsalEvidenceError(RuntimeError):
    """Raised when fork deployment rehearsal evidence is invalid."""


def normalize_value(value: str) -> str:
    """Normalize a Markdown field value."""
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and len(value) >= 2:
        value = value[1:-1]
    return value.strip()


def read_text(path: Path) -> str:
    """Read UTF-8 text with checker-specific errors."""
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise ForkDeploymentRehearsalEvidenceError(
            f"missing required file: {path}"
        ) from exc
    except UnicodeDecodeError as exc:
        raise ForkDeploymentRehearsalEvidenceError(
            f"{path} must be valid UTF-8"
        ) from exc


def file_sha256(path: Path) -> str:
    """Return a sha256: digest for one file."""
    hasher = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                hasher.update(chunk)
    except FileNotFoundError as exc:
        raise ForkDeploymentRehearsalEvidenceError(
            f"missing required file: {path}"
        ) from exc
    return "sha256:" + hasher.hexdigest()


def validate_no_secret_values(path: Path, text: str) -> None:
    """Reject secret-shaped key/value, CLI, and provider URL material."""
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise ForkDeploymentRehearsalEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CLI_SECRET_RE.search(text)
    if match:
        raise ForkDeploymentRehearsalEvidenceError(
            f"{path} contains secret-like CLI or URL text: {match.group(0)}"
        )


def repo_root_for(path: Path) -> Path:
    """Return the root used for repo-relative retained artifact paths."""
    cwd = Path.cwd().resolve()
    resolved = path.resolve()
    try:
        resolved.relative_to(cwd)
    except ValueError:
        # Standalone --evidence files resolve retained paths beside that artifact.
        return resolved.parent
    return cwd


def resolve_repo_relative_path(root: Path, value: str) -> Path:
    """Resolve a retained artifact path while rejecting escapes."""
    candidate = Path(value)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ForkDeploymentRehearsalEvidenceError(
            f"retained artifact path must be repo-relative: {value}"
        )
    resolved = (root / candidate).resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError as exc:
        raise ForkDeploymentRehearsalEvidenceError(
            f"retained artifact path escapes repository: {value}"
        ) from exc
    return resolved


def split_retained_file_reference(value: str) -> tuple[str, str | None]:
    """Split a retained file reference into path text and optional digest."""
    cleaned = value.strip().replace("`", "")
    matches = list(SHA256_RE.finditer(cleaned))
    if len(matches) > 1:
        raise ForkDeploymentRehearsalEvidenceError(
            f"retained artifact reference has multiple sha256 digests: {value}"
        )
    match = matches[0] if matches else None
    digest = match.group(0) if match else None
    path_text = cleaned[: match.start()] if match else cleaned
    path_text = path_text.strip().rstrip(" /,;")
    if not path_text:
        raise ForkDeploymentRehearsalEvidenceError(
            f"retained artifact reference is missing a path: {value}"
        )
    return path_text, digest


def looks_like_path_reference(value: str) -> bool:
    """Return whether a free-form field value should be validated as a path."""
    path_text, _digest = split_retained_file_reference(value)
    if any(marker in path_text for marker in ("/", "\\")):
        return " " not in path_text and "=" not in path_text
    return False


def validate_retained_file_reference(
    artifact_path: Path,
    root: Path,
    label: str,
    value: str,
) -> None:
    """Validate one referenced retained artifact file."""
    path_text, expected_digest = split_retained_file_reference(value)
    target = resolve_repo_relative_path(root, path_text)
    if not target.is_file():
        raise ForkDeploymentRehearsalEvidenceError(
            f"{artifact_path} field {label!r} points to missing retained file: "
            f"{path_text}"
        )
    validate_no_secret_values(target, read_text(target))
    if expected_digest is not None:
        actual_digest = file_sha256(target)
        if actual_digest != expected_digest:
            raise ForkDeploymentRehearsalEvidenceError(
                f"{artifact_path} field {label!r} sha256 mismatch for {path_text}: "
                f"expected {expected_digest}, got {actual_digest}"
            )


def validate_referenced_artifacts(path: Path, fields: dict[str, str]) -> None:
    """Validate retained file references for non-template evidence."""
    # Standalone --evidence files outside the repo resolve retained paths beside
    # that artifact; committed repo-rooted evidence should be checked from repo root.
    root = repo_root_for(path)
    for label in RETAINED_FILE_FIELDS:
        validate_retained_file_reference(path, root, label, fields[label])
    for label in OPTIONAL_PATH_FIELD_LABELS:
        if looks_like_path_reference(fields[label]):
            validate_retained_file_reference(path, root, label, fields[label])


def validate_headings(path: Path, text: str) -> None:
    """Require canonical headings in order."""
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise ForkDeploymentRehearsalEvidenceError(
                f"{path} is missing required heading: {heading}"
            ) from exc
        cursor = index + 1


def field_map(path: Path, text: str) -> dict[str, str]:
    """Extract Markdown bullet fields."""
    fields: dict[str, str] = {}
    for line in text.splitlines():
        match = FIELD_RE.match(line.strip())
        if not match:
            continue
        label = match.group("label").strip()
        value = normalize_value(match.group("value"))
        if label in fields:
            raise ForkDeploymentRehearsalEvidenceError(
                f"{path} has duplicate field: {label}"
            )
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise ForkDeploymentRehearsalEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    """Require one field to match an expected value."""
    actual = fields[label]
    if actual != expected:
        raise ForkDeploymentRehearsalEvidenceError(
            f"{path} field {label!r} must be {expected!r}, got {actual!r}"
        )


def is_placeholder(value: str) -> bool:
    """Return whether a value is still placeholder/template text."""
    lowered = value.lower()
    return lowered in {"tbd", "template", "template-only"} or "<" in value


def validate_review_state(path: Path, text: str, fields: dict[str, str]) -> None:
    """Validate template, pending-review, and reviewed state semantics."""
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        expected = ", ".join(sorted(REVIEW_STATUSES))
        raise ForkDeploymentRehearsalEvidenceError(
            f"{path} field 'Review status' must be one of: {expected}"
        )

    review_decision = fields["Review decision"]
    if review_decision not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise ForkDeploymentRehearsalEvidenceError(
            f"{path} field 'Review decision' must be one of: {expected}"
        )

    if review_status == "template":
        if "Template only. This file is not completion evidence." not in text:
            raise ForkDeploymentRehearsalEvidenceError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        return

    if "Template only. This file is not completion evidence." in text:
        raise ForkDeploymentRehearsalEvidenceError(
            f"{path} non-template evidence must remove the template-only notice"
        )

    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise ForkDeploymentRehearsalEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )

    require_field_value(path, fields, "No secrets retained", "yes")
    require_field_value(path, fields, "Private RPC URLs removed", "yes")
    require_field_value(path, fields, "Private keys removed", "yes")
    require_field_value(path, fields, "Unreleased drop payloads removed", "yes")

    if review_status == "reviewed":
        require_field_value(path, fields, "Review decision", "reviewed")


def validate_commands(path: Path, text: str) -> None:
    """Require the artifact to carry the validation sequence."""
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise ForkDeploymentRehearsalEvidenceError(
                f"{path} is missing validation command: {command}"
            )


def validate_artifact(path: Path) -> None:
    """Validate one retained fork deployment rehearsal artifact."""
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)

    require_field_value(path, fields, "Requirement ID", REQUIREMENT_ID)
    require_field_value(path, fields, "Readiness claim", "blocked")
    require_field_value(path, fields, "Environment", "fork")
    require_field_value(path, fields, "Chain ID", "1")
    validate_review_state(path, text, fields)
    if fields["Review status"] != "template":
        validate_referenced_artifacts(path, fields)
    validate_commands(path, text)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Validate retained fork deployment rehearsal evidence artifacts"
    )
    parser.add_argument(
        "--evidence",
        type=Path,
        action="append",
        help="Evidence Markdown path to validate; may be repeated.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the checker."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    paths = args.evidence or DEFAULT_EVIDENCE
    try:
        for path in paths:
            validate_artifact(path)
    except ForkDeploymentRehearsalEvidenceError as exc:
        print(f"fork deployment rehearsal evidence check failed: {exc}", file=sys.stderr)
        return 1
    print("fork deployment rehearsal evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

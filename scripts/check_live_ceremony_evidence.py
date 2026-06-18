#!/usr/bin/env python3
"""Validate retained live ceremony evidence artifacts."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path


REQUIREMENT_ID = "live_ceremony_evidence"
DEFAULT_REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVIDENCE_RELATIVE = Path(
    "release-artifacts/evidence/live-ceremony/"
    "live-ceremony-retained-artifact-template.md"
)
DEFAULT_EVIDENCE = [
    DEFAULT_REPO_ROOT / DEFAULT_EVIDENCE_RELATIVE
]

REQUIRED_HEADINGS = [
    "# Live Ceremony Retained Artifact",
    "## Evidence Status",
    "## Live Deployment Context",
    "## Participants And Governance",
    "## Ceremony Transactions",
    "## Dry Runs And Monitoring",
    "## Required Retained Artifacts",
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
    "Release commit",
    "Deployment version",
    "Live block or reference",
    "Deployer",
    "Admin Safe or multisig",
    "Pause guardian",
    "Emergency recipient",
    "Drop signer",
    "Signer manager",
    "Ownership transfer transaction",
    "Role grant and revoke transactions",
    "Signer setup transactions",
    "Metadata and freeze ceremony",
    "Auction ceremony",
    "Emergency controls ceremony",
    "Dry-run mint evidence",
    "Dry-run auction evidence",
    "Monitoring handoff",
    "Live deployment manifest",
    "Live address book",
    "Safe or multisig export",
    "Explorer transaction bundle",
    "Post-state views",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "Signer-service secrets removed",
    "Unreleased drop payloads removed",
}

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
REVIEW_DECISIONS = {"template", "pending_review", "reviewed", "changes_requested"}
FINAL_VALUE_FIELDS = [
    "Release commit",
    "Deployment version",
    "Live block or reference",
    "Deployer",
    "Admin Safe or multisig",
    "Pause guardian",
    "Emergency recipient",
    "Drop signer",
    "Signer manager",
    "Ownership transfer transaction",
    "Role grant and revoke transactions",
    "Signer setup transactions",
    "Metadata and freeze ceremony",
    "Auction ceremony",
    "Emergency controls ceremony",
    "Dry-run mint evidence",
    "Dry-run auction evidence",
    "Monitoring handoff",
    "Live deployment manifest",
    "Live address book",
    "Safe or multisig export",
    "Explorer transaction bundle",
    "Post-state views",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
]
RETAINED_FILE_FIELDS = [
    "Metadata and freeze ceremony",
    "Auction ceremony",
    "Emergency controls ceremony",
    "Dry-run mint evidence",
    "Dry-run auction evidence",
    "Monitoring handoff",
    "Live deployment manifest",
    "Live address book",
    "Safe or multisig export",
    "Explorer transaction bundle",
    "Post-state views",
    "Release manifest/checksum digests",
]

REQUIRED_COMMANDS = [
    "python scripts/test_live_ceremony_evidence.py",
    "python scripts/check_live_ceremony_evidence.py",
    "python scripts/generate_non_local_release_evidence.py",
    "python scripts/check_non_local_release_evidence.py",
    "python scripts/check_public_beta_evidence.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]
REQUIRED_TEMPLATE_ARGUMENT = (
    "--template "
    "release-artifacts/evidence/production-release-templates/"
    "live-ceremony-evidence-template.json"
)

FIELD_RE = re.compile(r"^- (?P<label>[^:]+): (?P<value>.*)$")
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
SHA256_REF_RE = re.compile(r"sha256:[0-9a-f]{64}")
SECRET_VALUE_RE = re.compile(
    r"\b("
    r"private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|"
    r"api[_ -]?key|password|bearer[_ -]?token|signer[_ -]?service[_ -]?secret|"
    r"unreleased[_ -]?drop[_ -]?payload"
    r")\s*[:=]",
    re.IGNORECASE,
)
CLI_SECRET_RE = re.compile(
    r"("
    r"--(?:private-key|mnemonic|seed(?:-phrase)?)\b(?:\s+|=)\S+|"
    r"--rpc-url\b(?:\s+|=)(?!<redacted>|redacted\b)\S+|"
    r"\bAuthorization\s*:\s*Bearer\s+\S+|"
    r"\bBearer\s+[A-Za-z0-9._~+/=-]{12,}|"
    r"https?://[^\s`/@:]+:[^\s`/@]+@[^\s`]+|"
    r"https?://[^\s`]*(?:alchemy|infura|quicknode)[^\s`]*|"
    r"https?://[^\s`]*[?&](?:api[_-]?key|apikey|token|secret)=[^\s`&]+"
    r")",
    re.IGNORECASE,
)
# Retained artifact digests must use sha256:<64 lowercase hex>, and Ethereum
# transaction hashes must keep their 0x prefix. Bare 64-hex strings are treated
# as secret-shaped key material so future live ceremony evidence fails closed
# instead of retaining private keys or unlabelled digests.
BARE_HEX_KEY_RE = re.compile(
    r"(?<![0-9a-fA-FxX:])(?:[0-9a-fA-F]{64})(?![0-9a-fA-F])"
)


class LiveCeremonyEvidenceError(RuntimeError):
    """Raised when live ceremony evidence is invalid."""


def normalize_value(value: str) -> str:
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and len(value) >= 2:
        value = value[1:-1]
    return value.strip()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise LiveCeremonyEvidenceError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise LiveCeremonyEvidenceError(f"{path} must be valid UTF-8") from exc


def file_sha256(path: Path) -> str:
    """Return a sha256: digest for one file."""
    hasher = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                hasher.update(chunk)
    except FileNotFoundError as exc:
        raise LiveCeremonyEvidenceError(f"missing required file: {path}") from exc
    return "sha256:" + hasher.hexdigest()


def validate_no_secret_values(path: Path, text: str) -> None:
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise LiveCeremonyEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CLI_SECRET_RE.search(text)
    if match:
        raise LiveCeremonyEvidenceError(
            f"{path} contains secret-like CLI or URL text: {match.group(0)}"
        )
    match = BARE_HEX_KEY_RE.search(text)
    if match:
        raise LiveCeremonyEvidenceError(
            f"{path} contains bare 64-hex secret-like text: {match.group(0)}"
        )


def split_retained_file_reference(value: str) -> tuple[str, str | None]:
    """Split a retained file reference into path text and optional digest."""
    cleaned = value.strip()
    if "`" in cleaned:
        raise LiveCeremonyEvidenceError(
            f"retained artifact reference must not contain backticks: {value}"
        )
    matches = list(SHA256_REF_RE.finditer(cleaned))
    if len(matches) > 1:
        raise LiveCeremonyEvidenceError(
            f"retained artifact reference has multiple sha256 digests: {value}"
        )
    if not matches and re.search(r"sha256:", cleaned, re.IGNORECASE):
        raise LiveCeremonyEvidenceError(
            f"retained artifact reference has malformed sha256 digest: {value}"
        )
    match = matches[0] if matches else None
    digest = match.group(0) if match else None
    if match:
        path_with_separator = cleaned[: match.start()]
        if path_with_separator.endswith(" / "):
            path_text = path_with_separator[:-3].strip()
        elif path_with_separator.endswith(" "):
            path_text = path_with_separator.rstrip()
        else:
            raise LiveCeremonyEvidenceError(
                "retained artifact reference must separate path and sha256 digest "
                f"with whitespace or ' / ': {value}"
            )
        suffix = cleaned[match.end() :].strip()
        if suffix:
            raise LiveCeremonyEvidenceError(
                f"retained artifact reference has trailing text after sha256 digest: {value}"
            )
    else:
        path_text = cleaned.strip()
    if not path_text:
        raise LiveCeremonyEvidenceError(
            f"retained artifact reference is missing a path: {value}"
        )
    return path_text, digest


def resolve_retained_path(
    artifact_path: Path, repo_root: Path, label: str, value: str
) -> tuple[Path, str, str | None]:
    """Resolve and constrain a retained artifact path."""
    path_text, expected_digest = split_retained_file_reference(value)
    if re.search(r"\s", path_text):
        raise LiveCeremonyEvidenceError(
            f"{artifact_path} field {label!r} must be one repo-relative path"
        )
    retained_path = Path(path_text)
    if retained_path.is_absolute() or retained_path.drive or retained_path.root:
        raise LiveCeremonyEvidenceError(
            f"{artifact_path} field {label!r} must be repo-relative"
        )
    if "\\" in path_text:
        raise LiveCeremonyEvidenceError(
            f"{artifact_path} field {label!r} must use forward slashes"
        )
    if ".." in retained_path.parts:
        raise LiveCeremonyEvidenceError(
            f"{artifact_path} field {label!r} must not escape the repository"
        )
    candidate = repo_root / retained_path
    cursor = repo_root
    for part in retained_path.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            raise LiveCeremonyEvidenceError(
                f"{artifact_path} field {label!r} must not use symlinked retained files"
            )
    resolved = candidate.resolve()
    try:
        resolved.relative_to(repo_root)
    except ValueError as exc:
        raise LiveCeremonyEvidenceError(
            f"{artifact_path} field {label!r} must stay inside the repository"
        ) from exc
    return resolved, path_text, expected_digest


def validate_referenced_artifacts(
    path: Path, fields: dict[str, str], repo_root: Path
) -> None:
    """Require pending/reviewed retained artifact paths to exist and be no-secret."""
    for label in RETAINED_FILE_FIELDS:
        if is_placeholder(fields[label]):
            raise LiveCeremonyEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )
        target, path_text, expected_digest = resolve_retained_path(
            path, repo_root, label, fields[label]
        )
        if not target.is_file():
            raise LiveCeremonyEvidenceError(
                f"{path} field {label!r} points to missing retained file: {path_text}"
            )
        validate_no_secret_values(target, read_text(target))
        if expected_digest is not None:
            actual_digest = file_sha256(target)
            if actual_digest != expected_digest:
                raise LiveCeremonyEvidenceError(
                    f"{path} field {label!r} sha256 mismatch for {path_text}: "
                    f"expected {expected_digest}, got {actual_digest}"
                )


def validate_headings(path: Path, text: str) -> None:
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise LiveCeremonyEvidenceError(
                f"{path} is missing required heading: {heading}"
            ) from exc
        cursor = index + 1


def field_map(path: Path, text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in text.splitlines():
        match = FIELD_RE.match(line.strip())
        if not match:
            continue
        label = match.group("label").strip()
        value = normalize_value(match.group("value"))
        if label in fields:
            raise LiveCeremonyEvidenceError(f"{path} has duplicate field: {label}")
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise LiveCeremonyEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    actual = fields[label]
    if actual != expected:
        raise LiveCeremonyEvidenceError(
            f"{path} field {label!r} must be {expected!r}, got {actual!r}"
        )


def require_address(path: Path, fields: dict[str, str], label: str) -> None:
    if not ADDRESS_RE.fullmatch(fields[label]):
        raise LiveCeremonyEvidenceError(f"{path} field {label!r} must be an address")


def is_placeholder(value: str) -> bool:
    lowered = value.lower()
    return lowered in {"tbd", "template", "template-only"} or bool(
        ANGLE_PLACEHOLDER_RE.fullmatch(value)
    )


def validate_review_state(
    path: Path, text: str, fields: dict[str, str], repo_root: Path
) -> None:
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        expected = ", ".join(sorted(REVIEW_STATUSES))
        raise LiveCeremonyEvidenceError(
            f"{path} field 'Review status' must be one of: {expected}"
        )

    review_decision = fields["Review decision"]
    if review_decision not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise LiveCeremonyEvidenceError(
            f"{path} field 'Review decision' must be one of: {expected}"
        )

    if review_status == "template":
        if "Template only. This file is not completion evidence." not in text:
            raise LiveCeremonyEvidenceError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        return

    if "Template only. This file is not completion evidence." in text:
        raise LiveCeremonyEvidenceError(
            f"{path} non-template evidence must remove the template-only notice"
        )
    if review_decision == "template":
        raise LiveCeremonyEvidenceError(
            f"{path} non-template evidence must advance the review decision"
        )

    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise LiveCeremonyEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )

    for label in (
        "Deployer",
        "Admin Safe or multisig",
        "Pause guardian",
        "Emergency recipient",
        "Drop signer",
        "Signer manager",
    ):
        require_address(path, fields, label)

    require_field_value(path, fields, "No secrets retained", "yes")
    require_field_value(path, fields, "Private RPC URLs removed", "yes")
    require_field_value(path, fields, "Private keys removed", "yes")
    require_field_value(path, fields, "Signer-service secrets removed", "yes")
    require_field_value(path, fields, "Unreleased drop payloads removed", "yes")

    if review_status == "reviewed":
        require_field_value(path, fields, "Review decision", "reviewed")
    validate_referenced_artifacts(path, fields, repo_root)


def validate_commands(path: Path, text: str) -> None:
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise LiveCeremonyEvidenceError(
                f"{path} is missing validation command: {command}"
            )
    if REQUIRED_TEMPLATE_ARGUMENT not in text:
        raise LiveCeremonyEvidenceError(
            f"{path} is missing validation command argument: {REQUIRED_TEMPLATE_ARGUMENT}"
        )


def validate_artifact(path: Path, repo_root: Path | None = None) -> None:
    repo_root = (repo_root or DEFAULT_REPO_ROOT).resolve()
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)

    require_field_value(path, fields, "Requirement ID", REQUIREMENT_ID)
    require_field_value(path, fields, "Readiness claim", "blocked")
    require_field_value(path, fields, "Environment", "live")
    require_field_value(path, fields, "Chain ID", "1")
    validate_review_state(path, text, fields, repo_root)
    validate_commands(path, text)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate retained live ceremony evidence artifacts"
    )
    parser.add_argument(
        "--evidence",
        type=Path,
        action="append",
        help="Evidence Markdown path to validate; may be repeated.",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=DEFAULT_REPO_ROOT,
        help="Repository root used for default evidence and retained paths.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    paths = args.evidence or [repo_root / DEFAULT_EVIDENCE_RELATIVE]
    try:
        for path in paths:
            validate_artifact(path, repo_root=repo_root)
    except LiveCeremonyEvidenceError as exc:
        print(f"live ceremony evidence check failed: {exc}", file=sys.stderr)
        return 1
    print("live ceremony evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

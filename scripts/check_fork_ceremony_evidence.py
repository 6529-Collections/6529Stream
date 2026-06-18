#!/usr/bin/env python3
"""Validate retained fork/testnet ceremony evidence artifacts."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_REPO_ROOT = Path(__file__).resolve().parents[1]
REQUIREMENT_ID = "fork_testnet_ceremony_evidence"
EVIDENCE_TYPE = "fork_testnet_ceremony_evidence"
ALLOWED_ENVIRONMENTS = {"fork", "testnet"}
DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/evidence/fork-ceremony/"
        "fork-ceremony-retained-artifact-template.md"
    )
]

REQUIRED_HEADINGS = [
    "# Fork/Testnet Ceremony Retained Artifact",
    "## Evidence Status",
    "## Fork/Testnet Deployment Context",
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
    "Evidence type",
    "Review status",
    "Readiness claim",
    "Environment",
    "Chain ID",
    "Repository",
    "Git commit",
    "CI run or operator transcript",
    "Fork/testnet block or reference",
    "Network and deployment version",
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
    "Deployment manifest",
    "Address book",
    "Safe or multisig export",
    "Explorer or fork transaction bundle",
    "Post-state views",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "API keys removed",
    "Signer-service secrets removed",
    "Unreleased drop payloads removed",
}

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
REVIEW_DECISIONS = {"template", "pending_review", "reviewed", "changes_requested"}
FINAL_VALUE_FIELDS = [
    "Git commit",
    "CI run or operator transcript",
    "Fork/testnet block or reference",
    "Network and deployment version",
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
    "Deployment manifest",
    "Address book",
    "Safe or multisig export",
    "Explorer or fork transaction bundle",
    "Post-state views",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
]
ADDRESS_FIELDS = [
    "Deployer",
    "Admin Safe or multisig",
    "Pause guardian",
    "Emergency recipient",
    "Drop signer",
    "Signer manager",
]
YES_FIELDS = [
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "API keys removed",
    "Signer-service secrets removed",
    "Unreleased drop payloads removed",
]
# File existence/no-secret scans apply only to the canonical retained artifact
# rows. Ceremony reference fields may be tx hashes, Safe ids, transcript labels,
# or repo paths; release manifest/checksum fields may be digest strings.
RETAINED_PATH_FIELDS = [
    "Deployment manifest",
    "Address book",
    "Safe or multisig export",
    "Explorer or fork transaction bundle",
    "Post-state views",
]

REQUIRED_COMMANDS = [
    "python scripts/test_fork_ceremony_evidence.py",
    "python scripts/check_fork_ceremony_evidence.py",
    "python scripts/generate_non_local_release_evidence.py",
    "python scripts/check_non_local_release_evidence.py",
    "python scripts/check_public_beta_evidence.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]
REQUIRED_TEMPLATE_ARGUMENT = (
    "--template "
    "release-artifacts/evidence/public-beta-templates/"
    "fork-testnet-ceremony-evidence-template.json"
)

FIELD_RE = re.compile(r"^- (?P<label>[^:]+): (?P<value>.*)$")
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
CHAIN_ID_RE = re.compile(r"^[1-9][0-9]*$")
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
    r"--rpc-url\b(?:\s+|=)"
    r"(?!(?:<redacted(?: [^>]*)?>|REDACTED_(?:LOCAL_ANVIL_FORK|FORK_RPC|TESTNET_RPC|RPC_URL))(?=\s|$))\S+|"
    r"\bAuthorization\s*:\s*Bearer\s+\S+|"
    r"\bBearer\s+[A-Za-z0-9._~+/=-]{12,}|"
    r"https?://[^\s`/@:]+:[^\s`/@]+@[^\s`]+|"
    r"https?://[^\s`]*(?:alchemy|ankr|blastapi|chainstack|infura|quicknode)[^\s`]*|"
    r"https?://[^\s`]*[?&](?:api[_-]?key|apikey|token|secret)=[^\s`&]+"
    r")",
    re.IGNORECASE,
)
BARE_HEX_KEY_RE = re.compile(
    r"(?<!sha256:)(?<![0-9a-fA-FxX])(?:[0-9a-fA-F]{64})(?![0-9a-fA-F])"
)


class ForkCeremonyEvidenceError(RuntimeError):
    """Raised when fork/testnet ceremony evidence is invalid."""


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
        raise ForkCeremonyEvidenceError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise ForkCeremonyEvidenceError(f"{path} must be valid UTF-8") from exc


def validate_no_secret_values(path: Path, text: str) -> None:
    """Reject secret-shaped key/value, CLI, provider URL, and token material."""
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise ForkCeremonyEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CLI_SECRET_RE.search(text)
    if match:
        raise ForkCeremonyEvidenceError(
            f"{path} contains secret-like CLI or URL text: {match.group(0)}"
        )
    match = BARE_HEX_KEY_RE.search(text)
    if match:
        raise ForkCeremonyEvidenceError(
            f"{path} contains bare 64-hex secret-like text: {match.group(0)}"
        )


def validate_headings(path: Path, text: str) -> None:
    """Require canonical headings in order."""
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise ForkCeremonyEvidenceError(
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
            raise ForkCeremonyEvidenceError(f"{path} has duplicate field: {label}")
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise ForkCeremonyEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    """Require one field to match an expected value."""
    actual = fields[label]
    if actual != expected:
        raise ForkCeremonyEvidenceError(
            f"{path} field {label!r} must be {expected!r}, got {actual!r}"
        )


def require_environment(path: Path, fields: dict[str, str]) -> None:
    """Require a fork or testnet environment marker."""
    value = fields["Environment"]
    if value not in ALLOWED_ENVIRONMENTS:
        expected = ", ".join(sorted(ALLOWED_ENVIRONMENTS))
        raise ForkCeremonyEvidenceError(
            f"{path} field 'Environment' must be one of: {expected}"
        )


def require_positive_chain_id(path: Path, fields: dict[str, str]) -> None:
    """Require a positive decimal chain ID with no leading zeroes."""
    value = fields["Chain ID"]
    if not CHAIN_ID_RE.fullmatch(value):
        raise ForkCeremonyEvidenceError(
            f"{path} field 'Chain ID' must be a positive integer"
        )
    chain_id = int(value, 10)
    if chain_id <= 0 or str(chain_id) != value:
        raise ForkCeremonyEvidenceError(
            f"{path} field 'Chain ID' must be a positive integer"
        )


def require_address(path: Path, fields: dict[str, str], label: str) -> None:
    """Require a field to be an address."""
    if not ADDRESS_RE.fullmatch(fields[label]):
        raise ForkCeremonyEvidenceError(f"{path} field {label!r} must be an address")


def is_placeholder(value: str) -> bool:
    """Return whether a value still looks like template text."""
    lowered = value.lower()
    return lowered in {"tbd", "template", "template-only"} or bool(
        ANGLE_PLACEHOLDER_RE.search(value)
    )


def validate_review_state(path: Path, text: str, fields: dict[str, str]) -> None:
    """Validate template, pending-review, and reviewed state transitions."""
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        expected = ", ".join(sorted(REVIEW_STATUSES))
        raise ForkCeremonyEvidenceError(
            f"{path} field 'Review status' must be one of: {expected}"
        )

    review_decision = fields["Review decision"]
    if review_decision not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise ForkCeremonyEvidenceError(
            f"{path} field 'Review decision' must be one of: {expected}"
        )

    if review_status == "template":
        if "Template only. This file is not completion evidence." not in text:
            raise ForkCeremonyEvidenceError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        return

    if "Template only. This file is not completion evidence." in text:
        raise ForkCeremonyEvidenceError(
            f"{path} non-template evidence must remove the template-only notice"
        )
    if review_decision == "template":
        raise ForkCeremonyEvidenceError(
            f"{path} non-template evidence must advance the review decision"
        )

    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise ForkCeremonyEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )
    for label in ADDRESS_FIELDS:
        require_address(path, fields, label)
    for label in YES_FIELDS:
        require_field_value(path, fields, label, "yes")
    if review_status == "reviewed":
        require_field_value(path, fields, "Review decision", "reviewed")


def validate_commands(path: Path, text: str) -> None:
    """Require the commands needed to reproduce the evidence check."""
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise ForkCeremonyEvidenceError(
                f"{path} is missing validation command: {command}"
            )
    if REQUIRED_TEMPLATE_ARGUMENT not in text:
        raise ForkCeremonyEvidenceError(
            f"{path} is missing template argument: {REQUIRED_TEMPLATE_ARGUMENT}"
        )


def resolve_retained_path(
    path: Path, repo_root: Path, label: str, value: str
) -> Path:
    """Resolve and constrain a retained artifact path."""
    if re.search(r"\s", value):
        raise ForkCeremonyEvidenceError(
            f"{path} field {label!r} must be one repo-relative path"
        )
    retained_path = Path(value)
    if retained_path.is_absolute() or retained_path.drive or retained_path.root:
        raise ForkCeremonyEvidenceError(
            f"{path} field {label!r} must be repo-relative"
        )
    if ".." in retained_path.parts:
        raise ForkCeremonyEvidenceError(
            f"{path} field {label!r} must not escape the repository"
        )
    resolved = (repo_root / retained_path).resolve()
    try:
        resolved.relative_to(repo_root)
    except ValueError as exc:
        raise ForkCeremonyEvidenceError(
            f"{path} field {label!r} must stay inside the repository"
        ) from exc
    return resolved


def validate_retained_paths(
    path: Path, fields: dict[str, str], repo_root: Path
) -> None:
    """Require reviewed retained-artifact references to exist and be clean."""
    for label in RETAINED_PATH_FIELDS:
        retained_path = resolve_retained_path(path, repo_root, label, fields[label])
        if not retained_path.is_file():
            raise ForkCeremonyEvidenceError(
                f"{path} field {label!r} references missing file: "
                f"{fields[label]}"
            )
        retained_text = read_text(retained_path)
        validate_no_secret_values(retained_path, retained_text)


def validate_artifact(path: Path, repo_root: Path | None = None) -> None:
    """Validate one retained fork/testnet ceremony artifact."""
    repo_root = (repo_root or Path.cwd()).resolve()
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)

    require_field_value(path, fields, "Requirement ID", REQUIREMENT_ID)
    require_field_value(path, fields, "Evidence type", EVIDENCE_TYPE)
    require_field_value(path, fields, "Readiness claim", "blocked")
    require_environment(path, fields)
    require_positive_chain_id(path, fields)
    validate_review_state(path, text, fields)
    if fields["Review status"] != "template":
        validate_retained_paths(path, fields, repo_root)
    validate_commands(path, text)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Validate retained fork/testnet ceremony evidence artifacts"
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=DEFAULT_REPO_ROOT,
        help="Repository root used for default evidence and retained paths.",
    )
    parser.add_argument(
        "--evidence",
        type=Path,
        action="append",
        help="Evidence Markdown path to validate; may be repeated.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the fork/testnet ceremony evidence checker."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    paths = args.evidence or [repo_root / path for path in DEFAULT_EVIDENCE]
    try:
        for path in paths:
            validate_artifact(path, repo_root=repo_root)
    except ForkCeremonyEvidenceError as exc:
        print(f"fork ceremony evidence check failed: {exc}", file=sys.stderr)
        return 1
    print("fork ceremony evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

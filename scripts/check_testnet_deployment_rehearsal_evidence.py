#!/usr/bin/env python3
"""Validate retained testnet deployment rehearsal evidence artifacts."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path


REQUIREMENT_ID = "testnet_deployment_rehearsal"
DEFAULT_REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVIDENCE = [
    DEFAULT_REPO_ROOT
    / (
        "release-artifacts/evidence/testnet-deployment-rehearsal/"
        "testnet-deployment-rehearsal-retained-artifact-template.md"
    )
]

REQUIRED_HEADINGS = [
    "# Testnet Deployment Rehearsal Retained Artifact",
    "## Evidence Status",
    "## Source And Testnet Reference",
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
    "Testnet name",
    "Chain ID",
    "Repository",
    "Git commit",
    "CI run or operator transcript",
    "Testnet block or reference",
    "Deployment transaction references",
    "Command",
    "Sanitized command transcript",
    "Sanitized Foundry broadcast",
    "Generated deployment manifest",
    "Generated address book",
    "Explorer verification status",
    "Gas or invariant summary",
    "Release manifest/checksum digests",
    "Deployment completed",
    "Manifest generated",
    "Address book generated",
    "Transaction references retained",
    "Explorer status checked",
    "Gas or invariant summary checked",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "API keys removed",
    "Unreleased drop payloads removed",
}

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
REVIEW_DECISIONS = {"template", "pending_review", "reviewed", "changes_requested"}
FINAL_VALUE_FIELDS = [
    "Git commit",
    "CI run or operator transcript",
    "Testnet block or reference",
    "Deployment transaction references",
    "Command",
    "Sanitized command transcript",
    "Sanitized Foundry broadcast",
    "Generated deployment manifest",
    "Generated address book",
    "Explorer verification status",
    "Gas or invariant summary",
    "Release manifest/checksum digests",
    "Deployment completed",
    "Manifest generated",
    "Address book generated",
    "Transaction references retained",
    "Explorer status checked",
    "Gas or invariant summary checked",
    "Operator",
    "Reviewer",
]
REVIEWED_YES_FIELDS = [
    "Deployment completed",
    "Manifest generated",
    "Address book generated",
    "Transaction references retained",
    "Explorer status checked",
    "Gas or invariant summary checked",
]
RETAINED_FILE_FIELDS = [
    "Sanitized command transcript",
    "Sanitized Foundry broadcast",
    "Generated deployment manifest",
    "Generated address book",
    "Gas or invariant summary",
]

REQUIRED_COMMANDS = [
    "python scripts/test_testnet_deployment_rehearsal_evidence.py",
    "python scripts/check_testnet_deployment_rehearsal_evidence.py",
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
    r"api[_ -]?key|password|bearer[_ -]?token|"
    r"unreleased[_ -]?drop[_ -]?payload"
    r")\s*[:=]",
    re.IGNORECASE,
)
CLI_SECRET_RE = re.compile(
    r"("
    r"--(?:private-key|mnemonic|seed(?:-phrase)?)\b(?:\s+|=)\S+|"
    r"--rpc-url\b(?:\s+|=)"
    r"(?!(?:<redacted(?: [^>]*)?>|REDACTED_(?:SEPOLIA_RPC|TESTNET_RPC|RPC_URL))(?=\s|$))\S+|"
    r"\bAuthorization\s*:\s*Bearer\s+\S+|"
    r"\bBearer\s+[A-Za-z0-9._~+/=-]{12,}|"
    r"https?://[^\s`/@:]+:[^\s`/@]+@[^\s`]+|"
    r"https?://[^\s`]*(?:alchemy|infura|quicknode|api[_-]?key|apikey|token|secret)[^\s`]*"
    r")",
    re.IGNORECASE,
)
# Retained artifact digests must use sha256:<64 lowercase hex>, and Ethereum
# block/transaction hashes must keep their 0x prefix. Bare 64-hex strings are
# treated as secret-shaped key material so future templates fail closed instead
# of accidentally retaining private keys or unlabelled digests.
BARE_HEX_KEY_RE = re.compile(
    r"(?<![0-9a-fA-FxX:])(?:[0-9a-fA-F]{64})(?![0-9a-fA-F])"
)


class TestnetDeploymentRehearsalEvidenceError(RuntimeError):
    """Raised when testnet deployment rehearsal evidence is invalid."""


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
        raise TestnetDeploymentRehearsalEvidenceError(
            f"missing required file: {path}"
        ) from exc
    except UnicodeDecodeError as exc:
        raise TestnetDeploymentRehearsalEvidenceError(
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
        raise TestnetDeploymentRehearsalEvidenceError(
            f"missing required file: {path}"
        ) from exc
    return "sha256:" + hasher.hexdigest()


def validate_no_secret_values(path: Path, text: str) -> None:
    """Reject secret-shaped key/value, CLI, URL, token, and bare-key material."""
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise TestnetDeploymentRehearsalEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CLI_SECRET_RE.search(text)
    if match:
        raise TestnetDeploymentRehearsalEvidenceError(
            f"{path} contains secret-like CLI or URL text: {match.group(0)}"
        )
    match = BARE_HEX_KEY_RE.search(text)
    if match:
        raise TestnetDeploymentRehearsalEvidenceError(
            f"{path} contains bare 64-hex secret-like text: {match.group(0)}"
        )


def split_retained_file_reference(value: str) -> tuple[str, str | None]:
    """Split a retained file reference into path text and optional digest."""
    cleaned = value.strip().replace("`", "")
    matches = list(SHA256_RE.finditer(cleaned))
    if len(matches) > 1:
        raise TestnetDeploymentRehearsalEvidenceError(
            f"retained artifact reference has multiple sha256 digests: {value}"
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
            raise TestnetDeploymentRehearsalEvidenceError(
                "retained artifact reference must separate path and sha256 digest "
                f"with whitespace or ' / ': {value}"
            )
        suffix = cleaned[match.end() :].strip()
        if suffix:
            raise TestnetDeploymentRehearsalEvidenceError(
                f"retained artifact reference has trailing text after sha256 digest: {value}"
            )
    else:
        path_text = cleaned.strip()
    if not path_text:
        raise TestnetDeploymentRehearsalEvidenceError(
            f"retained artifact reference is missing a path: {value}"
        )
    return path_text, digest


def resolve_retained_path(
    artifact_path: Path, repo_root: Path, label: str, value: str
) -> tuple[Path, str, str | None]:
    """Resolve and constrain a retained artifact path."""
    path_text, expected_digest = split_retained_file_reference(value)
    if re.search(r"\s", path_text):
        raise TestnetDeploymentRehearsalEvidenceError(
            f"{artifact_path} field {label!r} must be one repo-relative path"
        )
    retained_path = Path(path_text)
    if retained_path.is_absolute() or retained_path.drive or retained_path.root:
        raise TestnetDeploymentRehearsalEvidenceError(
            f"{artifact_path} field {label!r} must be repo-relative"
        )
    if "\\" in path_text or ".." in retained_path.parts:
        raise TestnetDeploymentRehearsalEvidenceError(
            f"{artifact_path} field {label!r} must not escape the repository"
        )
    candidate = repo_root / retained_path
    cursor = repo_root
    for part in retained_path.parts:
        cursor = cursor / part
        # Reject symlinked directories as well as symlinked leaf files before
        # resolve() can follow them outside the reviewed evidence tree.
        if cursor.is_symlink():
            raise TestnetDeploymentRehearsalEvidenceError(
                f"{artifact_path} field {label!r} must not use symlinked retained files"
            )
    resolved = candidate.resolve()
    try:
        resolved.relative_to(repo_root)
    except ValueError as exc:
        raise TestnetDeploymentRehearsalEvidenceError(
            f"{artifact_path} field {label!r} must stay inside the repository"
        ) from exc
    return resolved, path_text, expected_digest


def validate_referenced_artifacts(
    path: Path, fields: dict[str, str], repo_root: Path
) -> None:
    """Require reviewed retained artifact paths to exist and be no-secret."""
    for label in RETAINED_FILE_FIELDS:
        if is_placeholder(fields[label]):
            raise TestnetDeploymentRehearsalEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )
        target, path_text, expected_digest = resolve_retained_path(
            path,
            repo_root,
            label,
            fields[label],
        )
        if not target.is_file():
            raise TestnetDeploymentRehearsalEvidenceError(
                f"{path} field {label!r} points to missing retained file: {path_text}"
            )
        validate_no_secret_values(target, read_text(target))
        if expected_digest is not None:
            actual_digest = file_sha256(target)
            if actual_digest != expected_digest:
                raise TestnetDeploymentRehearsalEvidenceError(
                    f"{path} field {label!r} sha256 mismatch for {path_text}: "
                    f"expected {expected_digest}, got {actual_digest}"
                )


def validate_headings(path: Path, text: str) -> None:
    """Require canonical headings in order."""
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise TestnetDeploymentRehearsalEvidenceError(
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
            raise TestnetDeploymentRehearsalEvidenceError(
                f"{path} has duplicate field: {label}"
            )
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise TestnetDeploymentRehearsalEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    """Require one field to match an expected value."""
    actual = fields[label]
    if actual != expected:
        raise TestnetDeploymentRehearsalEvidenceError(
            f"{path} field {label!r} must be {expected!r}, got {actual!r}"
        )


def is_placeholder(value: str) -> bool:
    """Return whether a value is still placeholder/template text."""
    lowered = value.lower()
    return lowered in {"tbd", "template", "template-only"} or "<" in value


def validate_review_state(
    path: Path, text: str, fields: dict[str, str], repo_root: Path
) -> None:
    """Validate template, pending-review, and reviewed state semantics."""
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        expected = ", ".join(sorted(REVIEW_STATUSES))
        raise TestnetDeploymentRehearsalEvidenceError(
            f"{path} field 'Review status' must be one of: {expected}"
        )

    review_decision = fields["Review decision"]
    if review_decision not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise TestnetDeploymentRehearsalEvidenceError(
            f"{path} field 'Review decision' must be one of: {expected}"
        )

    if review_status == "template":
        if "Template only. This file is not completion evidence." not in text:
            raise TestnetDeploymentRehearsalEvidenceError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        return

    if "Template only. This file is not completion evidence." in text:
        raise TestnetDeploymentRehearsalEvidenceError(
            f"{path} non-template evidence must remove the template-only notice"
        )

    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise TestnetDeploymentRehearsalEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )

    require_field_value(path, fields, "No secrets retained", "yes")
    require_field_value(path, fields, "Private RPC URLs removed", "yes")
    require_field_value(path, fields, "Private keys removed", "yes")
    require_field_value(path, fields, "API keys removed", "yes")
    require_field_value(path, fields, "Unreleased drop payloads removed", "yes")

    if review_status == "reviewed":
        require_field_value(path, fields, "Review decision", "reviewed")
        for label in REVIEWED_YES_FIELDS:
            require_field_value(path, fields, label, "yes")
    validate_referenced_artifacts(path, fields, repo_root)


def validate_commands(path: Path, text: str) -> None:
    """Require the artifact to carry the validation sequence."""
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise TestnetDeploymentRehearsalEvidenceError(
                f"{path} is missing validation command: {command}"
            )


def validate_artifact(path: Path, repo_root: Path | None = None) -> None:
    """Validate one retained testnet deployment rehearsal artifact."""
    repo_root = (repo_root or DEFAULT_REPO_ROOT).resolve()
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)

    require_field_value(path, fields, "Requirement ID", REQUIREMENT_ID)
    require_field_value(path, fields, "Readiness claim", "blocked")
    require_field_value(path, fields, "Environment", "testnet")
    require_field_value(path, fields, "Testnet name", "sepolia")
    require_field_value(path, fields, "Chain ID", "11155111")
    validate_review_state(path, text, fields, repo_root)
    validate_commands(path, text)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Validate retained testnet deployment rehearsal evidence artifacts"
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
    """Run the checker."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    paths = args.evidence or DEFAULT_EVIDENCE
    repo_root = args.repo_root.resolve()
    try:
        for path in paths:
            validate_artifact(path, repo_root=repo_root)
    except TestnetDeploymentRehearsalEvidenceError as exc:
        print(
            f"testnet deployment rehearsal evidence check failed: {exc}",
            file=sys.stderr,
        )
        return 1
    print("testnet deployment rehearsal evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

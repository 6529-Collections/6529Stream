#!/usr/bin/env python3
"""Validate retained live randomizer operations evidence artifacts."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path


REQUIREMENT_ID = "live_randomizer_operations_evidence"
DEFAULT_REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVIDENCE_RELATIVE = Path(
    "release-artifacts/evidence/live-randomizer-operations/"
    "live-randomizer-operations-retained-artifact-template.md"
)
DEFAULT_EVIDENCE = [DEFAULT_REPO_ROOT / DEFAULT_EVIDENCE_RELATIVE]

REQUIRED_HEADINGS = [
    "# Live Randomizer Operations Retained Artifact",
    "## Evidence Status",
    "## Live Deployment Context",
    "## Provider Configuration",
    "## Funding And Reserve Status",
    "## Request Health",
    "## Lifecycle Controls",
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
    "VRF adapter",
    "VRF coordinator",
    "VRF provider epoch",
    "VRF funding status",
    "VRF evidence",
    "arRNG adapter",
    "arRNG controller",
    "arRNG provider epoch",
    "arRNG funding status",
    "arRNG refund recipient",
    "arRNG evidence",
    "Randomizer reserve status",
    "Pending request count",
    "Stale request handling",
    "Failed request handling",
    "Retry evidence",
    "Provider migration status",
    "Request tracking",
    "Callback validation",
    "Pending request migration block",
    "Pause policy",
    "Emergency withdrawal boundary",
    "Monitoring handoff",
    "Live deployment manifest",
    "Live address book",
    "Randomizer operations JSON",
    "Provider dashboard or export",
    "Explorer transaction bundle",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "Provider dashboard secrets removed",
    "Signer-service secrets removed",
    "Unreleased drop payloads removed",
}

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
REVIEW_DECISIONS = {"template", "pending_review", "reviewed", "changes_requested"}
FUNDING_STATUSES = {"funded", "pending", "blocked"}
CONTROL_STATUSES = {"passed", "failed", "blocked", "pending"}
FINAL_VALUE_FIELDS = [
    "Release commit",
    "Deployment version",
    "Live block or reference",
    "VRF adapter",
    "VRF coordinator",
    "VRF provider epoch",
    "VRF funding status",
    "VRF evidence",
    "arRNG adapter",
    "arRNG controller",
    "arRNG provider epoch",
    "arRNG funding status",
    "arRNG refund recipient",
    "arRNG evidence",
    "Randomizer reserve status",
    "Pending request count",
    "Stale request handling",
    "Failed request handling",
    "Retry evidence",
    "Provider migration status",
    "Request tracking",
    "Callback validation",
    "Pending request migration block",
    "Pause policy",
    "Emergency withdrawal boundary",
    "Monitoring handoff",
    "Live deployment manifest",
    "Live address book",
    "Randomizer operations JSON",
    "Provider dashboard or export",
    "Explorer transaction bundle",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
]

ADDRESS_FIELDS = (
    "VRF adapter",
    "VRF coordinator",
    "arRNG adapter",
    "arRNG controller",
    "arRNG refund recipient",
)
PROVIDER_EPOCH_FIELDS = ("VRF provider epoch", "arRNG provider epoch")
FUNDING_FIELDS = ("VRF funding status", "arRNG funding status")
CONTROL_FIELDS = (
    "Request tracking",
    "Callback validation",
    "Pending request migration block",
    "Stale request handling",
    "Failed request handling",
    "Retry evidence",
    "Provider migration status",
    "Pause policy",
    "Emergency withdrawal boundary",
)
REDACTION_FIELDS = (
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "Provider dashboard secrets removed",
    "Signer-service secrets removed",
    "Unreleased drop payloads removed",
)
RETAINED_FILE_FIELDS = [
    "VRF evidence",
    "arRNG evidence",
    "Monitoring handoff",
    "Live deployment manifest",
    "Live address book",
    "Randomizer operations JSON",
    "Provider dashboard or export",
    "Explorer transaction bundle",
    "Release manifest/checksum digests",
]

REQUIRED_COMMANDS = [
    "python scripts/test_live_randomizer_operations_evidence.py",
    "python scripts/check_live_randomizer_operations_evidence.py",
    "python scripts/check_randomizer_operations.py",
    "python scripts/generate_non_local_release_evidence.py",
    "python scripts/check_non_local_release_evidence.py",
    "python scripts/check_public_beta_evidence.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]
REQUIRED_TEMPLATE_ARGUMENT = (
    "--template "
    "release-artifacts/evidence/production-release-templates/"
    "live-randomizer-operations-evidence-template.json"
)

FIELD_RE = re.compile(r"^- (?P<label>[^:]+): (?P<value>.*)$")
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
UINT_RE = re.compile(r"^(0|[1-9][0-9]*)$")
SHA256_REF_RE = re.compile(r"sha256:[0-9a-f]{64}")
SECRET_VALUE_RE = re.compile(
    r"\b("
    r"private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|"
    r"api[_ -]?key|password|bearer[_ -]?token|provider[_ -]?dashboard[_ -]?secret|"
    r"signer[_ -]?service[_ -]?secret|unreleased[_ -]?drop[_ -]?payload"
    r")\s*[:=]",
    re.IGNORECASE,
)
CLI_SECRET_RE = re.compile(
    r"("
    r"--(?:private-key|mnemonic|seed(?:-phrase)?)\b(?:\s+|=)\S+|"
    r"--rpc-url\b(?:\s+|=)(?!<redacted>|redacted\b)\S+|"
    r"\bAuthorization\s*:\s*Bearer\s+\S+|"
    r"\bBearer\s+(?:<[^>\s]+>|[A-Za-z0-9._~+/=-]{12,})|"
    r"https?://[^\s`/@:]+:[^\s`/@]+@[^\s`]+|"
    r"https?://[^\s`]*(?:alchemy|infura|quicknode)[^\s`]*|"
    r"https?://[^\s`]*[?&](?:api[_-]?key|apikey|token|secret)=[^\s`&]+"
    r")",
    re.IGNORECASE,
)
BARE_HEX_KEY_RE = re.compile(
    r"(?<![0-9a-fA-FxX:])(?:[0-9a-fA-F]{64})(?![0-9a-fA-F])"
)


class LiveRandomizerOperationsEvidenceError(RuntimeError):
    """Raised when live randomizer operations evidence is invalid."""


def normalize_value(value: str) -> str:
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and len(value) >= 2:
        value = value[1:-1]
    return value.strip()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise LiveRandomizerOperationsEvidenceError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise LiveRandomizerOperationsEvidenceError(f"{path} must be valid UTF-8") from exc


def file_sha256(path: Path) -> str:
    """Return a sha256: digest for one file."""
    hasher = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                hasher.update(chunk)
    except FileNotFoundError as exc:
        raise LiveRandomizerOperationsEvidenceError(f"missing required file: {path}") from exc
    except OSError as exc:
        raise LiveRandomizerOperationsEvidenceError(
            f"could not read retained file for sha256: {path}: {exc}"
        ) from exc
    return "sha256:" + hasher.hexdigest()


def validate_no_secret_values(path: Path, text: str) -> None:
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise LiveRandomizerOperationsEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CLI_SECRET_RE.search(text)
    if match:
        raise LiveRandomizerOperationsEvidenceError(
            f"{path} contains secret-like CLI or URL text: {match.group(0)}"
        )
    match = BARE_HEX_KEY_RE.search(text)
    if match:
        raise LiveRandomizerOperationsEvidenceError(
            f"{path} contains bare 64-hex secret-like text: {match.group(0)}"
        )


def split_retained_file_reference(value: str) -> tuple[str, str | None]:
    """Split a retained file reference into path text and optional digest."""
    cleaned = value.strip()
    if "`" in cleaned:
        raise LiveRandomizerOperationsEvidenceError(
            f"retained artifact reference must not contain backticks: {value}"
        )
    matches = list(SHA256_REF_RE.finditer(cleaned))
    if len(matches) > 1:
        raise LiveRandomizerOperationsEvidenceError(
            f"retained artifact reference has multiple sha256 digests: {value}"
        )
    if not matches and re.search(r"sha256:", cleaned, re.IGNORECASE):
        raise LiveRandomizerOperationsEvidenceError(
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
            raise LiveRandomizerOperationsEvidenceError(
                "retained artifact reference must separate path and sha256 digest "
                f"with whitespace or ' / ': {value}"
            )
        suffix = cleaned[match.end() :].strip()
        if suffix:
            raise LiveRandomizerOperationsEvidenceError(
                f"retained artifact reference has trailing text after sha256 digest: {value}"
            )
    else:
        path_text = cleaned.strip()
    if not path_text:
        raise LiveRandomizerOperationsEvidenceError(
            f"retained artifact reference is missing a path: {value}"
        )
    return path_text, digest


def resolve_retained_path(
    artifact_path: Path, repo_root: Path, label: str, value: str
) -> tuple[Path, str, str | None]:
    """Resolve and constrain a retained artifact path."""
    path_text, expected_digest = split_retained_file_reference(value)
    if re.search(r"\s", path_text):
        raise LiveRandomizerOperationsEvidenceError(
            f"{artifact_path} field {label!r} must be one repo-relative path"
        )
    retained_path = Path(path_text)
    if retained_path.is_absolute() or retained_path.drive or retained_path.root:
        raise LiveRandomizerOperationsEvidenceError(
            f"{artifact_path} field {label!r} must be repo-relative"
        )
    if "\\" in path_text:
        raise LiveRandomizerOperationsEvidenceError(
            f"{artifact_path} field {label!r} must use forward slashes"
        )
    if ".." in retained_path.parts:
        raise LiveRandomizerOperationsEvidenceError(
            f"{artifact_path} field {label!r} must not escape the repository"
        )
    candidate = repo_root / retained_path
    cursor = repo_root
    for part in retained_path.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            raise LiveRandomizerOperationsEvidenceError(
                f"{artifact_path} field {label!r} must not use symlinked retained files"
            )
    resolved = candidate.resolve()
    try:
        resolved.relative_to(repo_root)
    except ValueError as exc:
        raise LiveRandomizerOperationsEvidenceError(
            f"{artifact_path} field {label!r} must stay inside the repository"
        ) from exc
    return resolved, path_text, expected_digest


def validate_referenced_artifacts(
    path: Path, fields: dict[str, str], repo_root: Path
) -> None:
    """Require pending/reviewed retained artifact paths to exist and be no-secret."""
    for label in RETAINED_FILE_FIELDS:
        if is_placeholder(fields[label]):
            raise LiveRandomizerOperationsEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )
        target, path_text, expected_digest = resolve_retained_path(
            path, repo_root, label, fields[label]
        )
        if not target.is_file():
            raise LiveRandomizerOperationsEvidenceError(
                f"{path} field {label!r} points to missing retained file: {path_text}"
            )
        validate_no_secret_values(target, read_text(target))
        if expected_digest is not None:
            actual_digest = file_sha256(target)
            if actual_digest != expected_digest:
                raise LiveRandomizerOperationsEvidenceError(
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
            raise LiveRandomizerOperationsEvidenceError(
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
            raise LiveRandomizerOperationsEvidenceError(f"{path} has duplicate field: {label}")
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise LiveRandomizerOperationsEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    actual = fields[label]
    if actual != expected:
        raise LiveRandomizerOperationsEvidenceError(
            f"{path} field {label!r} must be {expected!r}, got {actual!r}"
        )


def require_address(path: Path, fields: dict[str, str], label: str) -> None:
    if not ADDRESS_RE.fullmatch(fields[label]):
        raise LiveRandomizerOperationsEvidenceError(
            f"{path} field {label!r} must be an address"
        )


def require_uint(path: Path, fields: dict[str, str], label: str) -> None:
    if not UINT_RE.fullmatch(fields[label]):
        raise LiveRandomizerOperationsEvidenceError(
            f"{path} field {label!r} must be an unsigned integer"
        )


def require_enum(
    path: Path, fields: dict[str, str], label: str, choices: set[str]
) -> None:
    if fields[label] not in choices:
        expected = ", ".join(sorted(choices))
        raise LiveRandomizerOperationsEvidenceError(
            f"{path} field {label!r} must be one of: {expected}"
        )


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
        raise LiveRandomizerOperationsEvidenceError(
            f"{path} field 'Review status' must be one of: {expected}"
        )

    review_decision = fields["Review decision"]
    if review_decision not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise LiveRandomizerOperationsEvidenceError(
            f"{path} field 'Review decision' must be one of: {expected}"
        )

    if review_status == "template":
        if "Template only. This file is not completion evidence." not in text:
            raise LiveRandomizerOperationsEvidenceError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        return

    if "Template only. This file is not completion evidence." in text:
        raise LiveRandomizerOperationsEvidenceError(
            f"{path} non-template evidence must remove the template-only notice"
        )
    if review_decision == "template":
        raise LiveRandomizerOperationsEvidenceError(
            f"{path} non-template evidence must advance the review decision"
        )

    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise LiveRandomizerOperationsEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )
    for label in ADDRESS_FIELDS:
        require_address(path, fields, label)
    for label in PROVIDER_EPOCH_FIELDS + ("Pending request count",):
        require_uint(path, fields, label)
    for label in FUNDING_FIELDS:
        require_enum(path, fields, label, FUNDING_STATUSES)
    for label in CONTROL_FIELDS:
        require_enum(path, fields, label, CONTROL_STATUSES)
    for label in REDACTION_FIELDS:
        require_field_value(path, fields, label, "yes")
    validate_referenced_artifacts(path, fields, repo_root)

    if review_status == "reviewed":
        require_field_value(path, fields, "Review decision", "reviewed")
        for label in FUNDING_FIELDS:
            require_field_value(path, fields, label, "funded")
        for label in CONTROL_FIELDS:
            require_field_value(path, fields, label, "passed")


def validate_commands(path: Path, text: str) -> None:
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise LiveRandomizerOperationsEvidenceError(
                f"{path} is missing required validation command: {command}"
            )
    if REQUIRED_TEMPLATE_ARGUMENT not in text:
        raise LiveRandomizerOperationsEvidenceError(
            f"{path} validation commands must use {REQUIRED_TEMPLATE_ARGUMENT}"
        )


def validate_evidence(path: Path, repo_root: Path = DEFAULT_REPO_ROOT) -> None:
    repo_root = repo_root.resolve()
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


def validate_many(paths: list[Path], repo_root: Path = DEFAULT_REPO_ROOT) -> None:
    if not paths:
        raise LiveRandomizerOperationsEvidenceError(
            "no live randomizer operations evidence files configured"
        )
    for path in paths:
        validate_evidence(path, repo_root=repo_root)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", nargs="*", type=Path, default=DEFAULT_EVIDENCE)
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=DEFAULT_REPO_ROOT,
        help="Repository root for retained artifact path resolution.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        validate_many(args.evidence, repo_root=args.repo_root)
    except LiveRandomizerOperationsEvidenceError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print("live randomizer operations evidence is valid")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

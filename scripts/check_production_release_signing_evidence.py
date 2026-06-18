#!/usr/bin/env python3
"""Validate retained production release-signing evidence artifacts."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
REQUIREMENT_ID = "production_release_signing"
SUPPORTED_REQUIREMENTS = {"production_signatures", "signed_git_tag"}
DEFAULT_REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVIDENCE_RELATIVE = Path(
    "release-artifacts/evidence/production-release-signing/"
    "production-release-signing-retained-artifact-template.md"
)
DEFAULT_EVIDENCE = [DEFAULT_REPO_ROOT / DEFAULT_EVIDENCE_RELATIVE]

CHECK_RELEASE_SIGNATURES_PATH = SCRIPT_DIR / "check_release_signatures.py"
CHECK_RELEASE_SIGNATURES_SPEC = importlib.util.spec_from_file_location(
    "check_release_signatures", CHECK_RELEASE_SIGNATURES_PATH
)
assert CHECK_RELEASE_SIGNATURES_SPEC is not None
assert CHECK_RELEASE_SIGNATURES_SPEC.loader is not None
release_signatures = importlib.util.module_from_spec(CHECK_RELEASE_SIGNATURES_SPEC)
CHECK_RELEASE_SIGNATURES_SPEC.loader.exec_module(release_signatures)

REQUIRED_HEADINGS = [
    "# Production Release Signing Retained Artifact",
    "## Release Signing Context",
    "## Signature Evidence",
    "## Review And Redaction",
    "## Validation Commands",
    "## Operator Notes",
]

FIELD_RE = re.compile(r"^- ([^:\n]+): `([^`\n]*)`$", re.MULTILINE)
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")
GIT_COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
FINGERPRINT_RE = re.compile(r"^[0-9a-fA-F]{40,64}$")
SHA256_REF_RE = re.compile(r"sha256:[0-9a-f]{64}")
SHA256_PREFIX_RE = re.compile(r"sha256:", re.IGNORECASE)
TAG_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/-]*$")

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
REQUIRED_FIELDS = [
    "Requirement ID",
    "Supported requirements",
    "Readiness claim",
    "Environment",
    "Review status",
    "Release version",
    "Signed Git tag",
    "Release commit",
    "Signer fingerprint",
    "Signer custody summary",
    "Signer rotation/revocation policy",
    "Release manifest/checksum digests",
    "Checksum bundle",
    "Detached checksum signature evidence",
    "Signed Git tag verification evidence",
    "Release signature evidence JSON",
    "Verification command outputs",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Production signatures tracker updated",
    "Signed tag tracker updated",
    "Release signature checker executed",
    "Signed release tag checker executed",
]
RETAINED_FILE_FIELDS = [
    "Release manifest/checksum digests",
    "Checksum bundle",
    "Detached checksum signature evidence",
    "Signed Git tag verification evidence",
    "Release signature evidence JSON",
    "Verification command outputs",
]
REVIEWED_REQUIRED_YES_FIELDS = [
    "No secrets retained",
    "Production signatures tracker updated",
    "Signed tag tracker updated",
    "Release signature checker executed",
    "Signed release tag checker executed",
]

REQUIRED_COMMANDS = [
    "python scripts/test_production_release_signing_evidence.py",
    "python scripts/check_production_release_signing_evidence.py",
    "python scripts/test_release_signatures.py",
    "python scripts/check_release_signatures.py",
    "python scripts/test_signed_release_tag.py",
    "python scripts/check_signed_release_tag.py",
    "python scripts/generate_release_evidence_packet_index.py --check",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]

SECRET_VALUE_RE = re.compile(
    r"\b(private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|api[_ -]?key|password)\s*[:=]",
    re.IGNORECASE,
)
CLI_SECRET_RE = re.compile(
    r"("
    r"--(?:private-key|mnemonic|seed(?:-phrase)?)\b(?:\s+|=)\S+|"
    r"--rpc-url\b(?:\s+|=)(?!<redacted>|redacted\b)\S+|"
    r"\bAuthorization\s*:\s*Bearer\s+\S+|"
    r"\bBearer\s+(?:<[^>\s]+>|[A-Za-z0-9._~+/=-]{12,})|"
    r"https?://[^\s`/@:]+:[^\s`/@]+@[^\s`]+|"
    r"https?://[^\s`]*(?:alchemy|infura|quicknode|api[_-]?key|apikey|token|secret)[^\s`]*|"
    r"https?://[^\s`]*[?&](?:api[_-]?key|apikey|token|secret)=[^\s`&]+"
    r")",
    re.IGNORECASE,
)
BARE_HEX_KEY_RE = re.compile(
    r"(?<![0-9a-fA-FxX:])(?:[0-9a-fA-F]{64})(?![0-9a-fA-F])"
)


class ProductionReleaseSigningEvidenceError(RuntimeError):
    """Raised when production release-signing evidence is invalid."""


def read_text(path: Path) -> str:
    """Read one UTF-8 text file."""
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise ProductionReleaseSigningEvidenceError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise ProductionReleaseSigningEvidenceError(f"{path} must be valid UTF-8") from exc
    except OSError as exc:
        raise ProductionReleaseSigningEvidenceError(f"could not read {path}: {exc}") from exc


def file_sha256(path: Path) -> str:
    """Return a sha256: digest for one file."""
    hasher = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                hasher.update(chunk)
    except FileNotFoundError as exc:
        raise ProductionReleaseSigningEvidenceError(f"missing required file: {path}") from exc
    except OSError as exc:
        raise ProductionReleaseSigningEvidenceError(
            f"could not read retained file for sha256: {path}: {exc}"
        ) from exc
    return "sha256:" + hasher.hexdigest()


def retained_file_bytes(path: Path) -> bytes:
    """Read one retained artifact as bytes with checker-specific errors."""
    try:
        return path.read_bytes()
    except FileNotFoundError as exc:
        raise ProductionReleaseSigningEvidenceError(f"missing required file: {path}") from exc
    except OSError as exc:
        raise ProductionReleaseSigningEvidenceError(
            f"could not read retained file: {path}: {exc}"
        ) from exc


def repo_root_for(path: Path) -> Path:
    """Return the root used for repo-relative retained artifact paths."""
    cwd = Path.cwd().resolve()
    resolved = path.resolve()
    try:
        resolved.relative_to(cwd)
    except ValueError:
        return resolved.parent
    return cwd


def field_map(path: Path, text: str) -> dict[str, str]:
    """Extract backtick-delimited checklist fields from the retained artifact."""
    fields: dict[str, str] = {}
    for match in FIELD_RE.finditer(text):
        label, value = match.groups()
        if label in fields:
            raise ProductionReleaseSigningEvidenceError(f"{path} duplicates field {label!r}")
        fields[label] = value.strip()
    missing = [field for field in REQUIRED_FIELDS if field not in fields]
    if missing:
        raise ProductionReleaseSigningEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def validate_headings(path: Path, text: str) -> None:
    """Ensure the retained artifact keeps its required review sections."""
    for heading in REQUIRED_HEADINGS:
        if heading not in text:
            raise ProductionReleaseSigningEvidenceError(f"{path} is missing heading: {heading}")


def validate_commands(path: Path, text: str) -> None:
    """Ensure operators keep the validation command block visible."""
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise ProductionReleaseSigningEvidenceError(
                f"{path} is missing validation command: {command}"
            )


def validate_no_secret_values(path: Path, text: str, *, reject_bare_hex: bool = True) -> None:
    """Reject secret-shaped key/value, CLI, and provider URL material."""
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise ProductionReleaseSigningEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CLI_SECRET_RE.search(text)
    if match:
        raise ProductionReleaseSigningEvidenceError(
            f"{path} contains secret-like CLI or URL text: {match.group(0)}"
        )
    match = BARE_HEX_KEY_RE.search(text) if reject_bare_hex else None
    if match:
        raise ProductionReleaseSigningEvidenceError(
            f"{path} contains bare 64-hex secret-like text: {match.group(0)}"
        )


def is_placeholder(value: str) -> bool:
    """Return true when a field still contains template placeholder text."""
    normalized = value.strip().lower()
    return (
        normalized in {"", "tbd", "template", "template-only", "n/a"}
        or normalized.startswith("tbd ")
        or bool(ANGLE_PLACEHOLDER_RE.search(value))
    )


def split_retained_file_reference(value: str) -> tuple[str, str | None]:
    """Split a retained file reference into path text and optional digest."""
    cleaned = value.strip()
    if "`" in cleaned:
        raise ProductionReleaseSigningEvidenceError(
            f"retained artifact reference must not contain backticks: {value}"
        )
    digest_prefixes = [
        match
        for match in SHA256_PREFIX_RE.finditer(cleaned)
        if cleaned[: match.start()].endswith(" / ")
        or (match.start() > 0 and cleaned[match.start() - 1].isspace())
    ]
    if len(digest_prefixes) > 1:
        raise ProductionReleaseSigningEvidenceError(
            f"retained artifact reference has multiple sha256 digests: {value}"
        )
    if not digest_prefixes:
        strict_matches = list(SHA256_REF_RE.finditer(cleaned))
        if strict_matches:
            raise ProductionReleaseSigningEvidenceError(
                "retained artifact reference must separate path and sha256 digest "
                f"with whitespace or ' / ': {value}"
            )
        path_text = cleaned.strip()
        if not path_text:
            raise ProductionReleaseSigningEvidenceError(
                f"retained artifact reference is missing a path: {value}"
            )
        return path_text, None
    digest_start = digest_prefixes[0].start()
    match = SHA256_REF_RE.match(cleaned[digest_start:])
    if not match:
        raise ProductionReleaseSigningEvidenceError(
            f"retained artifact reference has malformed sha256 digest: {value}"
        )
    digest = match.group(0)
    digest_end = digest_start + match.end()
    path_with_separator = cleaned[:digest_start]
    if path_with_separator.endswith(" / "):
        path_text = path_with_separator[:-3].strip()
    elif path_with_separator.endswith(" "):
        path_text = path_with_separator.rstrip()
    else:
        raise ProductionReleaseSigningEvidenceError(
            "retained artifact reference must separate path and sha256 digest "
            f"with whitespace or ' / ': {value}"
        )
    suffix = cleaned[digest_end:].strip()
    if suffix:
        raise ProductionReleaseSigningEvidenceError(
            f"retained artifact reference has trailing text after sha256 digest: {value}"
        )
    if not path_text:
        raise ProductionReleaseSigningEvidenceError(
            f"retained artifact reference is missing a path: {value}"
        )
    return path_text, digest


def resolve_retained_path(
    artifact_path: Path, repo_root: Path, label: str, value: str
) -> tuple[Path, str, str | None]:
    """Resolve and constrain a retained artifact path."""
    path_text, expected_digest = split_retained_file_reference(value)
    if re.search(r"\s", path_text):
        raise ProductionReleaseSigningEvidenceError(
            f"{artifact_path} field {label!r} must be one repo-relative path"
        )
    retained_path = Path(path_text)
    if retained_path.is_absolute() or retained_path.drive or retained_path.root:
        raise ProductionReleaseSigningEvidenceError(
            f"{artifact_path} field {label!r} must be repo-relative"
        )
    if "\\" in path_text:
        raise ProductionReleaseSigningEvidenceError(
            f"{artifact_path} field {label!r} must use forward slashes"
        )
    if ".." in retained_path.parts:
        raise ProductionReleaseSigningEvidenceError(
            f"{artifact_path} field {label!r} must not escape the repository"
        )
    root = repo_root.resolve()
    candidate = root / retained_path
    cursor = root
    for part in retained_path.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            raise ProductionReleaseSigningEvidenceError(
                f"{artifact_path} field {label!r} must not use symlinked retained files"
            )
    resolved = candidate.resolve()
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise ProductionReleaseSigningEvidenceError(
            f"{artifact_path} field {label!r} must stay inside the repository"
        ) from exc
    return resolved, path_text, expected_digest


def validate_referenced_artifacts(
    path: Path, fields: dict[str, str], repo_root: Path
) -> dict[str, Path]:
    """Require retained artifact paths to exist, match hashes, and be no-secret."""
    targets: dict[str, Path] = {}
    for label in RETAINED_FILE_FIELDS:
        target, path_text, expected_digest = resolve_retained_path(
            path, repo_root, label, fields[label]
        )
        if not target.is_file():
            raise ProductionReleaseSigningEvidenceError(
                f"{path} field {label!r} points to missing retained file: {path_text}"
            )
        content = retained_file_bytes(target)
        try:
            retained_text = content.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise ProductionReleaseSigningEvidenceError(f"{target} must be valid UTF-8") from exc
        validate_no_secret_values(
            target,
            retained_text,
            reject_bare_hex=label != "Checksum bundle",
        )
        if expected_digest is not None:
            actual_digest = "sha256:" + hashlib.sha256(content).hexdigest()
            if actual_digest != expected_digest:
                raise ProductionReleaseSigningEvidenceError(
                    f"{path} field {label!r} sha256 mismatch for {path_text}: "
                    f"expected {expected_digest}, got {actual_digest}"
                )
        targets[label] = target
    return targets


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    """Require a field to match one exact value."""
    value = fields[label]
    if value != expected:
        raise ProductionReleaseSigningEvidenceError(
            f"{path} field {label!r} must be {expected!r}, got {value!r}"
        )


def require_non_placeholder(path: Path, fields: dict[str, str], label: str) -> str:
    """Require a field to be filled with non-template content."""
    value = fields[label]
    if is_placeholder(value):
        raise ProductionReleaseSigningEvidenceError(f"{path} field {label!r} must be filled")
    return value


def validate_supported_requirements(path: Path, value: str) -> None:
    """Require both production release-signing tracker IDs."""
    parsed = {part.strip() for part in value.split(",") if part.strip()}
    if parsed != SUPPORTED_REQUIREMENTS:
        raise ProductionReleaseSigningEvidenceError(
            f"{path} supported requirements must be production_signatures, signed_git_tag"
        )


def validate_tag_name(path: Path, tag: str) -> None:
    """Reject unsafe Git tag names in reviewed retained artifacts."""
    if not TAG_NAME_RE.fullmatch(tag):
        raise ProductionReleaseSigningEvidenceError(f"{path} signed Git tag is not safe")
    if (
        tag.startswith("/")
        or tag.startswith("-")
        or tag.endswith("/")
        or "//" in tag
        or "@{" in tag
        or tag == "@"
        or ".." in tag
    ):
        raise ProductionReleaseSigningEvidenceError(f"{path} signed Git tag is not safe")
    for component in tag.split("/"):
        if (
            component in {"", ".", ".."}
            or component.startswith(".")
            or component.endswith(".lock")
            or component.endswith(".")
        ):
            raise ProductionReleaseSigningEvidenceError(f"{path} signed Git tag is not safe")


def validate_release_signature_json(
    path: Path, fields: dict[str, str], targets: dict[str, Path], repo_root: Path
) -> None:
    """Validate the referenced release-signature JSON with the existing checker."""
    signature_json = targets["Release signature evidence JSON"]
    try:
        release_signatures.validate_evidence(signature_json, repo_root)
        data = release_signatures.load_json(signature_json)
    except release_signatures.ReleaseSignatureEvidenceError as exc:
        raise ProductionReleaseSigningEvidenceError(
            f"{path} has invalid release signature evidence JSON: {exc}"
        ) from exc

    network = data.get("network", {})
    environment = str(network.get("environment", ""))
    if environment not in {"mainnet", "production"}:
        raise ProductionReleaseSigningEvidenceError(
            f"{path} release signature evidence JSON must be mainnet or production"
        )
    if str(data.get("release_version", "")) != fields["Release version"]:
        raise ProductionReleaseSigningEvidenceError(
            f"{path} release signature evidence JSON release_version mismatch"
        )
    source_commit = str(data.get("source", {}).get("git_commit", "")).lower()
    if source_commit != fields["Release commit"].lower():
        raise ProductionReleaseSigningEvidenceError(
            f"{path} release signature evidence JSON source.git_commit mismatch"
        )


def validate_review_state(
    path: Path, text: str, fields: dict[str, str], repo_root: Path
) -> None:
    """Validate template, pending-review, and reviewed state semantics."""
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        raise ProductionReleaseSigningEvidenceError(
            f"{path} field 'Review status' must be one of: {', '.join(sorted(REVIEW_STATUSES))}"
        )

    if review_status == "template":
        return

    for label in [
        "Release version",
        "Signed Git tag",
        "Release commit",
        "Signer fingerprint",
        "Signer custody summary",
        "Signer rotation/revocation policy",
    ]:
        require_non_placeholder(path, fields, label)

    if not GIT_COMMIT_RE.fullmatch(fields["Release commit"]):
        raise ProductionReleaseSigningEvidenceError(
            f"{path} field 'Release commit' must be a 40-character git commit"
        )
    if not FINGERPRINT_RE.fullmatch(fields["Signer fingerprint"]):
        raise ProductionReleaseSigningEvidenceError(
            f"{path} field 'Signer fingerprint' must be a 40-64 character hex fingerprint"
        )
    validate_tag_name(path, fields["Signed Git tag"])

    for label in REVIEWED_REQUIRED_YES_FIELDS:
        require_field_value(path, fields, label, "yes")
    if review_status == "pending_review":
        require_field_value(path, fields, "Review decision", "pending_review")
        require_non_placeholder(path, fields, "Reviewer")
    else:
        require_field_value(path, fields, "Review decision", "reviewed")
        require_non_placeholder(path, fields, "Reviewer")

    targets = validate_referenced_artifacts(path, fields, repo_root)
    validate_release_signature_json(path, fields, targets, repo_root)

    validate_no_secret_values(path, text, reject_bare_hex=False)


def validate_artifact(path: Path, repo_root: Path | None = None) -> None:
    """Validate one retained production release-signing artifact."""
    root = (repo_root or repo_root_for(path)).resolve()
    text = read_text(path)
    validate_no_secret_values(path, text, reject_bare_hex=False)
    validate_headings(path, text)
    validate_commands(path, text)
    fields = field_map(path, text)

    require_field_value(path, fields, "Requirement ID", REQUIREMENT_ID)
    validate_supported_requirements(path, fields["Supported requirements"])
    require_field_value(path, fields, "Readiness claim", "blocked")
    require_field_value(path, fields, "Environment", "release_signing")
    validate_review_state(path, text, fields, root)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Validate retained production release-signing evidence artifacts"
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
        help=(
            "Repository root for retained artifact path resolution. Defaults to "
            "this checkout; tests or external artifact audits may override it "
            "when validating evidence outside the current working tree."
        ),
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the checker."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    paths = args.evidence or DEFAULT_EVIDENCE
    try:
        for path in paths:
            validate_artifact(path, repo_root=args.repo_root)
    except ProductionReleaseSigningEvidenceError as exc:
        print(f"production release-signing check failed: {exc}", file=sys.stderr)
        return 1
    print("production release-signing evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

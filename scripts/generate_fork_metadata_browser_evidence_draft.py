#!/usr/bin/env python3
"""Generate a fork/testnet metadata browser evidence draft from capture outputs."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

import check_fork_metadata_browser_evidence as evidence_checker


CAPTURE_SCHEMA = "6529stream.rehearsal-metadata-browser-capture.v1"
EVIDENCE_SCHEMA = evidence_checker.SUMMARY_SCHEMA
DEFAULT_SUMMARY_NAME = "browser-summary.json"
DEFAULT_TOKEN_URI_NAME = "token-uri.txt"
DEFAULT_TRANSCRIPT_NAME = "browser-transcript.md"
DEFAULT_RELEASE_DIGESTS = "release-artifacts/latest/release-manifest.json and SHA256SUMS"


class ForkMetadataBrowserEvidenceDraftError(RuntimeError):
    """Raised when metadata browser evidence draft generation is invalid."""


def read_text(path: Path) -> str:
    """Read UTF-8 text with draft-generator errors."""
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise ForkMetadataBrowserEvidenceDraftError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise ForkMetadataBrowserEvidenceDraftError(f"{path} must be valid UTF-8") from exc


def load_json(path: Path) -> Any:
    """Load JSON with draft-generator errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ForkMetadataBrowserEvidenceDraftError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ForkMetadataBrowserEvidenceDraftError(f"invalid JSON in {path}: {exc}") from exc


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text with deterministic newlines."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")


def require_dict(value: Any, context: str) -> dict[str, Any]:
    """Require a JSON value to be an object."""
    if not isinstance(value, dict):
        raise ForkMetadataBrowserEvidenceDraftError(f"{context} must be an object")
    return value


def require_string(value: Any, context: str) -> str:
    """Require a JSON value to be a non-empty string."""
    if not isinstance(value, str) or not value:
        raise ForkMetadataBrowserEvidenceDraftError(f"{context} must be a non-empty string")
    return value


def require_bool(value: Any, context: str) -> bool:
    """Require a JSON value to be a boolean."""
    if not isinstance(value, bool):
        raise ForkMetadataBrowserEvidenceDraftError(f"{context} must be a boolean")
    return value


def require_array(value: Any, context: str) -> list[Any]:
    """Require a JSON value to be an array."""
    if not isinstance(value, list):
        raise ForkMetadataBrowserEvidenceDraftError(f"{context} must be an array")
    return value


def require_int(value: Any, context: str) -> int:
    """Require a JSON value to be a non-negative integer."""
    if not isinstance(value, int) or isinstance(value, bool) or value < 0:
        raise ForkMetadataBrowserEvidenceDraftError(
            f"{context} must be a non-negative integer"
        )
    return value


def token_uri_digest(token_uri_text: str) -> str:
    """Return a sha256 digest for raw tokenURI text, or preserve digest text."""
    value = token_uri_text.strip()
    if evidence_checker.SHA256_RE.fullmatch(value):
        return value
    return "sha256:" + hashlib.sha256(value.encode("utf-8")).hexdigest()


def validate_no_secret_file(path: Path) -> None:
    """Reject secret-shaped retained input before writing any derived files."""
    evidence_checker.validate_no_secret_values(path, read_text(path))


def validate_distinct_paths(paths: list[Path]) -> None:
    """Reject output/input path collisions that would overwrite evidence."""
    seen: dict[str, Path] = {}
    for path in paths:
        key = str(path.resolve()).casefold()
        if key in seen:
            raise ForkMetadataBrowserEvidenceDraftError(
                f"metadata browser evidence draft paths must be distinct: "
                f"{seen[key]} and {path}"
            )
        seen[key] = path


def parse_contract(value: str) -> tuple[str, str]:
    """Parse one NAME=0x... contract argument."""
    if "=" not in value:
        raise ForkMetadataBrowserEvidenceDraftError(
            f"contract argument must use NAME=0x... form: {value}"
        )
    name, address = value.split("=", 1)
    name = name.strip()
    address = address.strip()
    if not name:
        raise ForkMetadataBrowserEvidenceDraftError("contract name must not be empty")
    normalized = evidence_checker.require_address(address, f"contract {name}")
    return name, normalized


def parse_contracts(values: list[str]) -> dict[str, dict[str, str]]:
    """Parse contract arguments into the evidence summary shape."""
    contracts: dict[str, dict[str, str]] = {}
    seen_addresses: dict[str, str] = {}
    for value in values:
        name, address = parse_contract(value)
        if name in contracts:
            raise ForkMetadataBrowserEvidenceDraftError(f"duplicate contract name: {name}")
        if address in seen_addresses:
            raise ForkMetadataBrowserEvidenceDraftError(
                f"duplicate contract address {address} for {seen_addresses[address]} and {name}"
            )
        contracts[name] = {"address": address}
        seen_addresses[address] = name
    if not contracts:
        raise ForkMetadataBrowserEvidenceDraftError("at least one --contract is required")
    return contracts


def validate_capture_summary(path: Path, data: dict[str, Any]) -> None:
    """Validate the local capture summary before conversion."""
    schema = require_string(data.get("schema_version"), f"{path}.schema_version")
    if schema != CAPTURE_SCHEMA:
        raise ForkMetadataBrowserEvidenceDraftError(
            f"{path}.schema_version must be {CAPTURE_SCHEMA!r}"
        )
    chain_id = data.get("chain_id")
    if not isinstance(chain_id, int) or isinstance(chain_id, bool) or chain_id <= 0:
        raise ForkMetadataBrowserEvidenceDraftError(f"{path}.chain_id must be positive")
    require_int(data.get("collection_id"), f"{path}.collection_id")
    require_int(data.get("token_id"), f"{path}.token_id")
    digest = require_string(data.get("token_uri_sha256"), f"{path}.token_uri_sha256")
    if not evidence_checker.SHA256_RE.fullmatch(digest):
        raise ForkMetadataBrowserEvidenceDraftError(
            f"{path}.token_uri_sha256 must be sha256:<hex>"
        )
    sandbox = require_dict(data.get("sandbox"), f"{path}.sandbox")
    for key in ("dependency_loaded", "draw_is_function", "parent_access_blocked"):
        if not require_bool(sandbox.get(key), f"{path}.sandbox.{key}"):
            raise ForkMetadataBrowserEvidenceDraftError(f"{path}.sandbox.{key} must be true")
    for key in ("unexpected_requests", "page_errors", "console_errors"):
        values = require_array(sandbox.get(key), f"{path}.sandbox.{key}")
        if values:
            raise ForkMetadataBrowserEvidenceDraftError(f"{path}.sandbox.{key} must be empty")


def evidence_path_value(artifact_path: Path, target_path: Path) -> str:
    """Return the path string the checker will resolve for a retained file."""
    cwd = Path.cwd().resolve()
    artifact_resolved = artifact_path.resolve()
    target_resolved = target_path.resolve()
    try:
        artifact_resolved.relative_to(cwd)
        return target_resolved.relative_to(cwd).as_posix()
    except ValueError:
        try:
            return target_resolved.relative_to(artifact_resolved.parent).as_posix()
        except ValueError as exc:
            raise ForkMetadataBrowserEvidenceDraftError(
                f"{target_path} must be inside {cwd} or beside {artifact_path}"
            ) from exc


def build_evidence_summary(
    *,
    capture: dict[str, Any],
    environment: str,
    chain_id: int,
    git_commit: str,
    command_or_source_system: str,
    contracts: dict[str, dict[str, str]],
) -> dict[str, Any]:
    """Convert a capture summary into the fork/testnet evidence summary schema."""
    sandbox = require_dict(capture.get("sandbox"), "capture.sandbox")
    return {
        "schema_version": EVIDENCE_SCHEMA,
        "environment": environment,
        "chain_id": chain_id,
        "no_secrets": True,
        "source": {
            "git_commit": git_commit,
            "command_or_source_system": command_or_source_system,
        },
        "contracts": contracts,
        "token_results": [
            {
                "token_id": int(capture["token_id"]),
                "collection_id": int(capture["collection_id"]),
                "token_uri_sha256": str(capture["token_uri_sha256"]),
                "sandbox": {
                    "metadata_fetched_from_deployed_contract": True,
                    "browser_executed": True,
                    "dependency_loaded": bool(sandbox["dependency_loaded"]),
                    "draw_is_function": bool(sandbox["draw_is_function"]),
                    "parent_access_blocked": bool(sandbox["parent_access_blocked"]),
                    "unexpected_requests": list(sandbox["unexpected_requests"]),
                    "page_errors": list(sandbox["page_errors"]),
                    "console_errors": list(sandbox["console_errors"]),
                },
            }
        ],
    }


def render_artifact(
    *,
    output_path: Path,
    environment: str,
    chain_id: int,
    git_commit: str,
    ci_run_or_transcript: str,
    block_or_reference: str,
    deployment_version: str,
    contracts: dict[str, dict[str, str]],
    token_id: int,
    collection_id: int,
    summary_output: Path,
    token_uri_output: Path,
    transcript_output: Path,
    release_digests: str,
    operator: str,
    reviewer: str,
) -> str:
    """Render the pending-review retained artifact Markdown."""
    contract_field = ", ".join(
        f"{name}={record['address']}" for name, record in sorted(contracts.items())
    )
    summary_field = evidence_path_value(output_path, summary_output)
    token_field = evidence_path_value(output_path, token_uri_output)
    transcript_field = evidence_path_value(output_path, transcript_output)
    return "\n".join(
        [
            "# Fork/Testnet Metadata Browser Retained Artifact",
            "",
            "## Evidence Status",
            "",
            "- Requirement ID: `fork_testnet_metadata_browser_evidence`",
            "- Evidence type: `fork_testnet_metadata_browser_evidence`",
            "- Review status: `pending_review`",
            "- Readiness claim: `blocked`",
            f"- Environment: `{environment}`",
            f"- Chain ID: `{chain_id}`",
            "",
            "## Source And Fork/Testnet Reference",
            "",
            "- Repository: `https://github.com/6529-Collections/6529Stream`",
            f"- Git commit: `{git_commit}`",
            f"- CI run or operator transcript: `{ci_run_or_transcript}`",
            f"- Fork/testnet block or reference: `{block_or_reference}`",
            f"- Network and deployment version: `{deployment_version}`",
            f"- Contract addresses: `{contract_field}`",
            f"- Token IDs: `{token_id}`",
            f"- Collection IDs: `{collection_id}`",
            "",
            "## Required Retained Artifacts",
            "",
            f"- Browser summary JSON: `{summary_field}`",
            f"- Generated tokenURI or digest: `{token_field}`",
            f"- Browser transcript or screenshot: `{transcript_field}`",
            f"- Release manifest/checksum digests: `{release_digests}`",
            "",
            "## Browser Results",
            "",
            "- Metadata fetched from deployed contracts: `yes`",
            "- Browser sandbox executed: `yes`",
            "- Unexpected outbound requests blocked: `yes`",
            "- Console and page errors absent: `yes`",
            "- Animation bootstrap verified: `yes`",
            "- Parent frame isolation verified: `yes`",
            "- Token and collection IDs retained: `yes`",
            "",
            "## Review",
            "",
            f"- Operator: `{operator}`",
            f"- Reviewer: `{reviewer}`",
            "- Review decision: `pending_review`",
            "",
            "## Redaction",
            "",
            "- No secrets retained: `yes`",
            "- Private RPC URLs removed: `yes`",
            "- Private keys removed: `yes`",
            "- API keys removed: `yes`",
            "- Unreleased drop payloads removed: `yes`",
            "",
            "## Validation Commands",
            "",
            "```sh",
            "python scripts/test_generate_fork_metadata_browser_evidence_draft.py",
            "python scripts/test_fork_metadata_browser_evidence.py",
            "python scripts/check_fork_metadata_browser_evidence.py",
            "python scripts/generate_non_local_release_evidence.py --template "
            "release-artifacts/evidence/public-beta-templates/"
            "fork-testnet-metadata-browser-evidence-template.json --retained-artifact "
            f"{evidence_path_value(output_path, output_path)} --output "
            "release-artifacts/evidence/fork-metadata-browser/"
            "fork-metadata-browser-evidence.json "
            f"--environment {environment} --chain-id {chain_id} "
            f"--block-or-reference \"{block_or_reference}\" "
            f"--command-or-source-system \"{ci_run_or_transcript}\" "
            f"--owner \"{operator}\" --reviewer \"{reviewer}\" "
            f"--source-git-commit {git_commit} --source-ci-run \"{ci_run_or_transcript}\"",
            "python scripts/check_non_local_release_evidence.py",
            "python scripts/check_public_beta_evidence.py",
            "python scripts/generate_release_manifest.py --check",
            "python scripts/generate_release_checksums.py --check",
            "```",
            "",
            "## Operator Notes",
            "",
            "- Generated from retained metadata-browser capture outputs for issue #218.",
            "- This file is pending review and is not completion evidence until the "
            "shared public-beta evidence manifest links reviewed retained evidence.",
            "- This generator requires an explicit deployed-contract assertion; do not "
            "use local-only capture outputs for public-beta readiness claims.",
            "",
        ]
    )


def generate_draft(args: argparse.Namespace) -> list[Path]:
    """Generate converted summary JSON and retained artifact Markdown."""
    if not args.metadata_fetched_from_deployed_contract:
        raise ForkMetadataBrowserEvidenceDraftError(
            "--metadata-fetched-from-deployed-contract is required"
        )

    capture_summary_path = args.capture_summary_json
    token_uri_path = args.token_uri_output
    transcript_path = args.transcript_output
    output_path = args.output
    summary_output = args.summary_output or (output_path.parent / DEFAULT_SUMMARY_NAME)
    retained_token_uri_output = args.retained_token_uri_output or (
        output_path.parent / DEFAULT_TOKEN_URI_NAME
    )
    retained_transcript_output = args.retained_transcript_output or (
        output_path.parent / DEFAULT_TRANSCRIPT_NAME
    )
    validate_distinct_paths(
        [
            capture_summary_path,
            token_uri_path,
            transcript_path,
            output_path,
            summary_output,
            retained_token_uri_output,
            retained_transcript_output,
        ]
    )
    for path in (capture_summary_path, token_uri_path, transcript_path):
        validate_no_secret_file(path)

    capture = require_dict(load_json(capture_summary_path), str(capture_summary_path))
    validate_capture_summary(capture_summary_path, capture)
    token_digest = token_uri_digest(read_text(token_uri_path))
    if token_digest != capture["token_uri_sha256"]:
        raise ForkMetadataBrowserEvidenceDraftError(
            "tokenURI output digest does not match capture summary token_uri_sha256"
        )
    token_uri_text = read_text(token_uri_path)
    transcript_text = read_text(transcript_path)

    environment = evidence_checker.require_environment(output_path, args.environment)
    chain_id = args.chain_id if args.chain_id is not None else int(capture["chain_id"])
    if chain_id != int(capture["chain_id"]):
        raise ForkMetadataBrowserEvidenceDraftError(
            "requested chain ID must match capture summary chain_id"
        )
    contracts = parse_contracts(args.contract)
    summary = build_evidence_summary(
        capture=capture,
        environment=environment,
        chain_id=chain_id,
        git_commit=args.git_commit,
        command_or_source_system=args.ci_run_or_operator_transcript,
        contracts=contracts,
    )
    artifact = render_artifact(
        output_path=output_path,
        environment=environment,
        chain_id=chain_id,
        git_commit=args.git_commit,
        ci_run_or_transcript=args.ci_run_or_operator_transcript,
        block_or_reference=args.block_or_reference,
        deployment_version=args.deployment_version,
        contracts=contracts,
        token_id=int(capture["token_id"]),
        collection_id=int(capture["collection_id"]),
        summary_output=summary_output,
        token_uri_output=retained_token_uri_output,
        transcript_output=retained_transcript_output,
        release_digests=args.release_digests,
        operator=args.operator,
        reviewer=args.reviewer,
    )
    evidence_checker.validate_no_secret_values(output_path, json.dumps(summary, sort_keys=True))
    evidence_checker.validate_no_secret_values(retained_token_uri_output, token_uri_text)
    evidence_checker.validate_no_secret_values(retained_transcript_output, transcript_text)
    evidence_checker.validate_no_secret_values(output_path, artifact)

    write_json(summary_output, summary)
    write_text(retained_token_uri_output, token_uri_text)
    write_text(retained_transcript_output, transcript_text)
    write_text(output_path, artifact)
    evidence_checker.validate_artifact(output_path)
    return [summary_output, retained_token_uri_output, retained_transcript_output, output_path]


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description=(
            "Generate a pending-review fork/testnet metadata browser retained "
            "artifact from retained browser-capture outputs"
        )
    )
    parser.add_argument("--capture-summary-json", type=Path, required=True)
    parser.add_argument("--token-uri-output", type=Path, required=True)
    parser.add_argument("--transcript-output", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--summary-output", type=Path)
    parser.add_argument("--retained-token-uri-output", type=Path)
    parser.add_argument("--retained-transcript-output", type=Path)
    parser.add_argument("--environment", choices=sorted(evidence_checker.ALLOWED_ENVIRONMENTS), required=True)
    parser.add_argument("--chain-id", type=int)
    parser.add_argument("--git-commit", required=True)
    parser.add_argument("--ci-run-or-operator-transcript", required=True)
    parser.add_argument("--block-or-reference", required=True)
    parser.add_argument("--deployment-version", required=True)
    parser.add_argument("--contract", action="append", default=[], help="Contract NAME=0x...; may be repeated")
    parser.add_argument("--operator", required=True)
    parser.add_argument("--reviewer", required=True)
    parser.add_argument("--release-digests", default=DEFAULT_RELEASE_DIGESTS)
    parser.add_argument(
        "--metadata-fetched-from-deployed-contract",
        action="store_true",
        help="Required assertion that the capture came from deployed fork/testnet contracts.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the generator."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        written = generate_draft(args)
    except (ForkMetadataBrowserEvidenceDraftError, evidence_checker.ForkMetadataBrowserEvidenceError) as exc:
        print(f"fork/testnet metadata browser evidence draft generation failed: {exc}", file=sys.stderr)
        return 1
    print("wrote fork/testnet metadata browser evidence draft: " + ", ".join(str(path) for path in written))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

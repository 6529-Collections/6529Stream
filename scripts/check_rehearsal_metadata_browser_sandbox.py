#!/usr/bin/env python3
"""Execute rehearsal-generated metadata in the browser sandbox."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


CHECKER_PATH = Path(__file__).with_name("check_metadata_browser_sandbox.py")
SPEC = importlib.util.spec_from_file_location("check_metadata_browser_sandbox", CHECKER_PATH)
assert SPEC is not None and SPEC.loader is not None
sandbox_checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = sandbox_checker
SPEC.loader.exec_module(sandbox_checker)

EXPECTED_EVIDENCE_KIND = "local-anvil-deployment-rehearsal"
FORK_TESTNET_EVIDENCE_KIND = "fork-testnet-deployment-rehearsal"
EXPECTED_EVIDENCE_KINDS = {EXPECTED_EVIDENCE_KIND, FORK_TESTNET_EVIDENCE_KIND}
EXPECTED_EXTERNAL_SCRIPT_URL = "https://cdn.6529.io/stream/rehearsal.js"
REHEARSAL_SCRIPT = "script/RehearseMetadataBrowser.s.sol:RehearseMetadataBrowser"
DEFAULT_FORK_SENDER = "0x0000000000000000000000000000000000006537"
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
    r"--rpc-url\b(?:\s+|=)(?!<redacted>|redacted\b)\S+|"
    r"\bAuthorization\s*:\s*Bearer\s+\S+|"
    r"\bBearer\s+[A-Za-z0-9._~+/=-]{12,}|"
    r"https?://[^\s`]*(?:alchemy|ankr|blastapi|chainstack|infura|quicknode)[^\s`]*|"
    r"https?://[^\s`]*[?&](?:api[_-]?key|apikey|token|secret)=[^\s`&]+"
    r")",
    re.IGNORECASE,
)
RETURN_FIELDS = (
    "evidenceKind",
    "chainId",
    "deploymentManifestHash",
    "collectionId",
    "tokenId",
    "tokenHash",
    "tokenDataRaw",
    "externalScriptUrl",
    "tokenUri",
)


class RehearsalMetadataBrowserError(ValueError):
    """Raised when the rehearsal metadata browser check fails."""


@dataclass(frozen=True)
class RehearsalBrowserCheckResult:
    """Complete Forge-to-Chromium rehearsal evidence and browser result."""

    evidence: dict[str, Any]
    sandbox_result: sandbox_checker.SandboxResult
    forge_command: str | None = None


@dataclass(frozen=True)
class ForgeRehearsalOptions:
    """Operator-selected Forge execution mode for the metadata rehearsal."""

    rpc_url: str | None = None
    broadcast: bool = False
    unlocked: bool = False
    sender: str | None = None


def forge_environment() -> dict[str, str]:
    """Return an environment that can find a standard Foundry install."""

    env = os.environ.copy()
    foundry_bin = Path.home() / ".foundry" / "bin"
    if foundry_bin.exists():
        env["PATH"] = f"{foundry_bin}{os.pathsep}{env.get('PATH', '')}"
    return env


def resolve_forge(env: dict[str, str]) -> str:
    """Return the forge executable path or raise with setup guidance."""

    forge = shutil.which("forge", path=env.get("PATH"))
    if forge is None:
        raise RehearsalMetadataBrowserError(
            "forge was not found. Run the repository bootstrap script, then retry "
            "the rehearsal metadata browser check."
        )
    return forge


def parse_forge_json_records(stdout: str) -> list[dict[str, Any]]:
    """Extract JSON object records from Forge stdout."""

    decoder = json.JSONDecoder()
    records: list[dict[str, Any]] = []
    index = 0
    while index < len(stdout):
        object_start = stdout.find("{", index)
        array_start = stdout.find("[", index)
        starts = [start for start in (object_start, array_start) if start != -1]
        if not starts:
            break
        start = min(starts)
        try:
            parsed, end = decoder.raw_decode(stdout[start:])
        except json.JSONDecodeError:
            index = start + 1
            continue

        if isinstance(parsed, dict):
            records.append(parsed)
        elif isinstance(parsed, list):
            records.extend(record for record in parsed if isinstance(record, dict))
        index = start + end

    if not records:
        raise RehearsalMetadataBrowserError(
            "forge metadata rehearsal did not produce parseable JSON records"
        )
    return records


def build_forge_command(forge: str, options: ForgeRehearsalOptions) -> list[str]:
    """Build the Forge command without retaining secret-bearing operator inputs."""

    command = [
        forge,
        "script",
        REHEARSAL_SCRIPT,
        "--sig",
        "run()",
        "--via-ir",
        "--json",
    ]
    if options.rpc_url:
        command.extend(["--rpc-url", options.rpc_url])
    if options.broadcast:
        command.append("--broadcast")
    if options.unlocked:
        command.append("--unlocked")
    if options.sender:
        command.extend(["--sender", options.sender])
    return command


def redacted_forge_command(options: ForgeRehearsalOptions) -> str:
    """Return a no-secret command summary suitable for retained evidence notes."""

    command = [
        "forge",
        "script",
        REHEARSAL_SCRIPT,
        "--sig",
        '"run()"',
        "--via-ir",
        "--json",
    ]
    if options.rpc_url:
        command.extend(["--rpc-url", "REDACTED_LOCAL_OR_OPERATOR_RPC"])
    if options.broadcast:
        command.append("--broadcast")
    if options.unlocked:
        command.append("--unlocked")
    if options.sender:
        command.extend(["--sender", options.sender])
    return " ".join(command)


def run_forge_rehearsal(options: ForgeRehearsalOptions | None = None) -> dict[str, Any]:
    """Run the local metadata rehearsal script and return Forge's JSON output."""

    options = options or ForgeRehearsalOptions()
    env = forge_environment()
    forge = resolve_forge(env)
    command = build_forge_command(forge, options)
    completed = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        env=env,
    )
    if completed.returncode != 0:
        raise RehearsalMetadataBrowserError(
            "forge metadata rehearsal failed:\n"
            f"stdout:\n{completed.stdout[-4000:]}\n"
            f"stderr:\n{completed.stderr[-4000:]}"
        )
    records = parse_forge_json_records(completed.stdout)
    for record in reversed(records):
        if "returned" in record or "returns" in record:
            return record
    raise RehearsalMetadataBrowserError(
        "forge metadata rehearsal did not include returned ABI data or decoded returns"
    )


def read_word(data: bytes, index: int, *, base: int = 0) -> bytes:
    """Read one ABI word by index."""

    start = base + (index * 32)
    end = start + 32
    if end > len(data):
        raise RehearsalMetadataBrowserError("returned rehearsal ABI data is truncated")
    return data[start:end]


def word_to_int(word: bytes) -> int:
    """Convert an ABI word to an integer."""

    return int.from_bytes(word, byteorder="big")


def decode_string(data: bytes, offset_word: bytes, field: str, *, base: int = 0) -> str:
    """Decode a dynamic ABI string from a tuple offset word."""

    offset = base + word_to_int(offset_word)
    if offset + 32 > len(data):
        raise RehearsalMetadataBrowserError(f"{field} offset is outside returned ABI data")
    length = word_to_int(data[offset : offset + 32])
    start = offset + 32
    end = start + length
    if end > len(data):
        raise RehearsalMetadataBrowserError(f"{field} bytes are outside returned ABI data")
    try:
        return data[start:end].decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise RehearsalMetadataBrowserError(f"{field} is not valid UTF-8") from exc


def decode_rehearsal_return(returned: Any) -> dict[str, Any]:
    """Decode the ABI-encoded rehearsal result returned by Forge."""

    if not isinstance(returned, str) or not returned.startswith("0x"):
        raise RehearsalMetadataBrowserError("forge output is missing returned ABI data")
    try:
        data = bytes.fromhex(returned[2:])
    except ValueError as exc:
        raise RehearsalMetadataBrowserError("returned rehearsal ABI data is not hex") from exc
    if len(data) < len(RETURN_FIELDS) * 32:
        raise RehearsalMetadataBrowserError("returned rehearsal ABI data is too short")
    base = 0
    if word_to_int(read_word(data, 0)) == 32 and len(data) >= 32 + len(RETURN_FIELDS) * 32:
        base = 32

    return {
        "evidenceKind": decode_string(
            data, read_word(data, 0, base=base), "evidenceKind", base=base
        ),
        "chainId": str(word_to_int(read_word(data, 1, base=base))),
        "deploymentManifestHash": "0x" + read_word(data, 2, base=base).hex(),
        "collectionId": str(word_to_int(read_word(data, 3, base=base))),
        "tokenId": str(word_to_int(read_word(data, 4, base=base))),
        "tokenHash": "0x" + read_word(data, 5, base=base).hex(),
        "tokenDataRaw": decode_string(
            data, read_word(data, 6, base=base), "tokenDataRaw", base=base
        ),
        "externalScriptUrl": decode_string(
            data, read_word(data, 7, base=base), "externalScriptUrl", base=base
        ),
        "tokenUri": decode_string(data, read_word(data, 8, base=base), "tokenUri", base=base),
    }


def extract_decoded_rehearsal_value(forge_output: dict[str, Any]) -> str:
    """Extract Forge's decoded return value string from broadcast JSON output."""

    returns = forge_output.get("returns")
    if not isinstance(returns, dict):
        raise RehearsalMetadataBrowserError("forge output is missing returned ABI data")
    result = returns.get("result")
    if not isinstance(result, dict):
        raise RehearsalMetadataBrowserError("forge output is missing decoded result")
    value = result.get("value")
    if not isinstance(value, str) or not value:
        raise RehearsalMetadataBrowserError("forge decoded result value is missing")
    return value


def decode_rehearsal_value_string(value: str) -> dict[str, Any]:
    """Decode Forge's human-readable tuple string for broadcast-mode returns."""

    body = value.strip()
    if not body.startswith("(") or not body.endswith(")"):
        raise RehearsalMetadataBrowserError("forge decoded result is not a tuple string")
    body = body[1:-1]
    head = body.split(", ", 6)
    if len(head) != 7:
        raise RehearsalMetadataBrowserError("forge decoded result has wrong field count")
    (
        evidence_kind,
        chain_id,
        deployment_manifest_hash,
        collection_id,
        token_id,
        token_hash,
        rest,
    ) = head
    external_marker = f", {EXPECTED_EXTERNAL_SCRIPT_URL}, "
    if external_marker not in rest:
        raise RehearsalMetadataBrowserError(
            "forge decoded result is missing the expected external script URL"
        )
    token_data_raw, token_uri = rest.split(external_marker, 1)
    return {
        "evidenceKind": evidence_kind,
        "chainId": chain_id,
        "deploymentManifestHash": deployment_manifest_hash,
        "collectionId": collection_id,
        "tokenId": token_id,
        "tokenHash": token_hash,
        "tokenDataRaw": token_data_raw,
        "externalScriptUrl": EXPECTED_EXTERNAL_SCRIPT_URL,
        "tokenUri": token_uri,
    }


def extract_rehearsal_evidence(forge_output: dict[str, Any]) -> dict[str, Any]:
    """Extract rehearsal evidence from the Forge ABI return payload."""

    returned = forge_output.get("returned")
    if returned is not None:
        return decode_rehearsal_return(returned)
    return decode_rehearsal_value_string(extract_decoded_rehearsal_value(forge_output))


def as_int(value: Any, field: str) -> int:
    """Convert a Forge decoded integer value into Python int."""

    try:
        if isinstance(value, int):
            return value
        if isinstance(value, str):
            return int(value, 0)
    except ValueError as exc:
        raise RehearsalMetadataBrowserError(f"{field} is not an integer: {value!r}") from exc
    raise RehearsalMetadataBrowserError(f"{field} is not an integer: {value!r}")


def as_bytes32(value: Any, field: str) -> str:
    """Validate and normalize a Forge decoded bytes32 value."""

    if not isinstance(value, str) or not value.startswith("0x") or len(value) != 66:
        raise RehearsalMetadataBrowserError(f"{field} is not bytes32: {value!r}")
    return value.lower()


def parse_token_data(raw: Any) -> tuple[int, ...]:
    """Parse the rehearsal token data string into expected browser bootstrap values."""

    if not isinstance(raw, str):
        raise RehearsalMetadataBrowserError(f"tokenDataRaw is not a string: {raw!r}")
    if raw.strip() == "":
        return ()
    values: list[int] = []
    for part in raw.split(","):
        try:
            values.append(int(part.strip()))
        except ValueError as exc:
            raise RehearsalMetadataBrowserError(
                f"tokenDataRaw contains a non-integer value: {raw!r}"
            ) from exc
    return tuple(values)


def validate_rehearsal_evidence(evidence: dict[str, Any]) -> None:
    """Validate the evidence envelope before launching Chromium."""

    if evidence.get("evidenceKind") not in EXPECTED_EVIDENCE_KINDS:
        raise RehearsalMetadataBrowserError(
            f"unexpected evidence kind: {evidence.get('evidenceKind')!r}"
        )
    if evidence.get("externalScriptUrl") != EXPECTED_EXTERNAL_SCRIPT_URL:
        raise RehearsalMetadataBrowserError(
            f"unexpected external script URL: {evidence.get('externalScriptUrl')!r}"
        )
    as_int(evidence.get("chainId"), "chainId")
    as_int(evidence.get("collectionId"), "collectionId")
    as_int(evidence.get("tokenId"), "tokenId")
    as_bytes32(evidence.get("deploymentManifestHash"), "deploymentManifestHash")
    as_bytes32(evidence.get("tokenHash"), "tokenHash")
    parse_token_data(evidence.get("tokenDataRaw"))
    token_uri = evidence.get("tokenUri")
    if not isinstance(token_uri, str) or not token_uri.startswith(
        sandbox_checker.fixture_checker.JSON_DATA_URI_PREFIX
    ):
        raise RehearsalMetadataBrowserError("tokenUri is not an on-chain metadata data URI")


def build_expected_bootstrap(evidence: dict[str, Any]) -> object:
    """Build expected browser bootstrap values from the rehearsal evidence."""

    return sandbox_checker.ExpectedBootstrap(
        hash_value=as_bytes32(evidence["tokenHash"], "tokenHash"),
        token_id=as_int(evidence["tokenId"], "tokenId"),
        token_data_raw=str(evidence["tokenDataRaw"]),
        token_data=parse_token_data(evidence["tokenDataRaw"]),
    )


def token_uri_sha256(token_uri: str) -> str:
    """Return the retained sha256 digest for a generated tokenURI string."""

    return "sha256:" + hashlib.sha256(token_uri.encode("utf-8")).hexdigest()


def build_capture_summary(result: RehearsalBrowserCheckResult) -> dict[str, Any]:
    """Build a deterministic retained summary for the browser rehearsal run."""

    evidence = result.evidence
    sandbox_result = result.sandbox_result
    return {
        "schema_version": "6529stream.rehearsal-metadata-browser-capture.v1",
        "evidence_kind": evidence["evidenceKind"],
        "forge_command": result.forge_command,
        "chain_id": as_int(evidence["chainId"], "chainId"),
        "deployment_manifest_hash": as_bytes32(
            evidence["deploymentManifestHash"],
            "deploymentManifestHash",
        ),
        "collection_id": as_int(evidence["collectionId"], "collectionId"),
        "token_id": as_int(evidence["tokenId"], "tokenId"),
        "token_hash": as_bytes32(evidence["tokenHash"], "tokenHash"),
        "token_data_raw": str(evidence["tokenDataRaw"]),
        "token_uri_sha256": token_uri_sha256(str(evidence["tokenUri"])),
        "external_script_url": str(evidence["externalScriptUrl"]),
        "sandbox": {
            "expected_script_requests": list(sandbox_result.expected_script_requests),
            "unexpected_requests": list(sandbox_result.unexpected_requests),
            "page_errors": list(sandbox_result.page_errors),
            "console_errors": list(sandbox_result.console_errors),
            "dependency_loaded": sandbox_result.dependency_loaded,
            "dependency_url": sandbox_result.dependency_url,
            "script_count": sandbox_result.script_count,
            "hash_value": sandbox_result.hash_value,
            "token_id": sandbox_result.token_id,
            "token_data_raw": sandbox_result.token_data_raw,
            "token_data_is_array": sandbox_result.token_data_is_array,
            "token_data_values": list(sandbox_result.token_data_values),
            "draw_is_function": sandbox_result.draw_is_function,
            "parent_access_blocked": sandbox_result.parent_access_blocked,
            "parent_access_error_name": sandbox_result.parent_access_error_name,
        },
    }


def build_capture_transcript(result: RehearsalBrowserCheckResult) -> str:
    """Render a redacted retained transcript for the browser rehearsal run."""

    evidence = result.evidence
    sandbox_result = result.sandbox_result
    summary = build_capture_summary(result)
    return "\n".join(
        [
            "# Rehearsal Metadata Browser Capture Transcript",
            "",
            "This retained transcript contains no RPC URLs, private keys, API keys, "
            "signing material, or unreleased drop payloads.",
            "",
            "## Source",
            "",
            f"- Rehearsal script: `{REHEARSAL_SCRIPT}`",
            f"- Forge command: `{summary['forge_command'] or 'default local command'}`",
            f"- Evidence kind: `{evidence['evidenceKind']}`",
            f"- Chain ID: `{summary['chain_id']}`",
            f"- Deployment manifest hash: `{summary['deployment_manifest_hash']}`",
            f"- Collection ID: `{summary['collection_id']}`",
            f"- Token ID: `{summary['token_id']}`",
            f"- Token hash: `{summary['token_hash']}`",
            f"- Token data raw: `{summary['token_data_raw']}`",
            f"- tokenURI digest: `{summary['token_uri_sha256']}`",
            f"- External script URL: `{summary['external_script_url']}`",
            "",
            "## Browser Sandbox Result",
            "",
            "- Browser executed: `yes`",
            f"- Expected script requests: `{', '.join(sandbox_result.expected_script_requests)}`",
            f"- Unexpected requests: `{len(sandbox_result.unexpected_requests)}`",
            f"- Page errors: `{len(sandbox_result.page_errors)}`",
            f"- Console errors: `{len(sandbox_result.console_errors)}`",
            f"- Dependency loaded: `{'yes' if sandbox_result.dependency_loaded else 'no'}`",
            f"- Script count: `{sandbox_result.script_count}`",
            f"- draw is function: `{'yes' if sandbox_result.draw_is_function else 'no'}`",
            f"- Parent frame access blocked: `{'yes' if sandbox_result.parent_access_blocked else 'no'}`",
            f"- Parent access error name: `{sandbox_result.parent_access_error_name}`",
            "",
        ]
    )


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON while creating parent directories."""

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")


def validate_no_secret_text(label: str, text: str) -> None:
    """Reject secret-shaped capture output before it is retained."""

    match = SECRET_VALUE_RE.search(text)
    if match:
        raise RehearsalMetadataBrowserError(
            f"{label} contains secret-like key/value text: {match.group(0)}"
        )
    match = CLI_SECRET_RE.search(text)
    if match:
        raise RehearsalMetadataBrowserError(
            f"{label} contains secret-like CLI or URL text: {match.group(0)}"
        )


def validate_distinct_output_paths(paths: list[Path]) -> None:
    """Reject duplicate capture output paths before any file is written."""

    seen: dict[str, Path] = {}
    for path in paths:
        key = str(path.resolve()).casefold()
        if key in seen:
            raise RehearsalMetadataBrowserError(
                f"capture output paths must be distinct: {seen[key]} and {path}"
            )
        seen[key] = path


def write_capture_outputs(
    result: RehearsalBrowserCheckResult,
    *,
    summary_json: Path | None,
    token_uri_output: Path | None,
    transcript_output: Path | None,
) -> list[Path]:
    """Write requested retained capture artifacts and return their paths."""

    validate_distinct_output_paths(
        [path for path in (summary_json, token_uri_output, transcript_output) if path]
    )
    written: list[Path] = []
    if summary_json is not None:
        summary = build_capture_summary(result)
        validate_no_secret_text(
            str(summary_json),
            json.dumps(summary, indent=2, sort_keys=True),
        )
        write_json(summary_json, summary)
        written.append(summary_json)
    if token_uri_output is not None:
        token_uri = str(result.evidence["tokenUri"]) + "\n"
        validate_no_secret_text(str(token_uri_output), token_uri)
        write_text(token_uri_output, token_uri)
        written.append(token_uri_output)
    if transcript_output is not None:
        transcript = build_capture_transcript(result)
        validate_no_secret_text(str(transcript_output), transcript)
        write_text(transcript_output, transcript)
        written.append(transcript_output)
    return written


def check_rehearsal_browser_sandbox(
    *,
    timeout_ms: int,
    headed: bool,
    forge_options: ForgeRehearsalOptions | None = None,
) -> RehearsalBrowserCheckResult:
    """Run the full Forge-to-Chromium rehearsal metadata browser check."""

    forge_options = forge_options or ForgeRehearsalOptions()
    forge_output = run_forge_rehearsal(forge_options)
    evidence = extract_rehearsal_evidence(forge_output)
    validate_rehearsal_evidence(evidence)
    fixture = sandbox_checker.load_animation_from_token_uri(
        str(evidence["tokenUri"]),
        label="rehearsal on-chain tokenURI",
    )
    if fixture.external_script_url != evidence["externalScriptUrl"]:
        raise RehearsalMetadataBrowserError(
            "generated metadata external script URL does not match rehearsal evidence"
        )
    result = sandbox_checker.run_browser_sandbox(
        fixture,
        timeout_ms=timeout_ms,
        headed=headed,
    )
    sandbox_checker.validate_sandbox_result(
        result,
        expected_external_script_url=fixture.external_script_url,
        expected_bootstrap=build_expected_bootstrap(evidence),
    )
    return RehearsalBrowserCheckResult(
        evidence=evidence,
        sandbox_result=result,
        forge_command=redacted_forge_command(forge_options),
    )


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser for the rehearsal browser checker."""

    parser = argparse.ArgumentParser(
        description="Execute local deployment-rehearsal metadata in a browser sandbox."
    )
    parser.add_argument(
        "--timeout-ms",
        type=int,
        default=10_000,
        help="Browser operation timeout in milliseconds.",
    )
    parser.add_argument(
        "--headed",
        action="store_true",
        help="Run Chromium with a visible browser window for local debugging.",
    )
    parser.add_argument(
        "--summary-json",
        type=Path,
        help="Optional path for a deterministic retained browser summary JSON.",
    )
    parser.add_argument(
        "--token-uri-output",
        type=Path,
        help="Optional path for the generated tokenURI snapshot.",
    )
    parser.add_argument(
        "--transcript-output",
        type=Path,
        help="Optional path for a redacted retained browser transcript.",
    )
    parser.add_argument(
        "--forge-rpc-url",
        help=(
            "Optional Forge RPC URL for fork/testnet capture. This value is used "
            "only for command execution and is never written to retained outputs."
        ),
    )
    parser.add_argument(
        "--forge-broadcast",
        action="store_true",
        help="Pass --broadcast to Forge for fork/testnet deployed-contract capture.",
    )
    parser.add_argument(
        "--forge-unlocked",
        action="store_true",
        help="Pass --unlocked to Forge for an Anvil fork with impersonated senders.",
    )
    parser.add_argument(
        "--forge-sender",
        help=(
            "Optional Forge --sender address. For the default rehearsal config on "
            f"Anvil forks, use {DEFAULT_FORK_SENDER}."
        ),
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the rehearsal metadata browser sandbox check from the command line."""

    args = build_parser().parse_args(argv)
    try:
        forge_options = ForgeRehearsalOptions(
            rpc_url=args.forge_rpc_url,
            broadcast=args.forge_broadcast,
            unlocked=args.forge_unlocked,
            sender=args.forge_sender,
        )
        result = check_rehearsal_browser_sandbox(
            timeout_ms=args.timeout_ms,
            headed=args.headed,
            forge_options=forge_options,
        )
        written = write_capture_outputs(
            result,
            summary_json=args.summary_json,
            token_uri_output=args.token_uri_output,
            transcript_output=args.transcript_output,
        )
    except (
        RehearsalMetadataBrowserError,
        sandbox_checker.BrowserSandboxError,
        sandbox_checker.fixture_checker.MetadataFixtureError,
    ) as exc:
        print(f"rehearsal metadata browser sandbox check failed: {exc}", file=sys.stderr)
        return 1

    print(
        "Validated rehearsal metadata browser sandbox "
        f"for chain {as_int(result.evidence['chainId'], 'chainId')} "
        f"collection {as_int(result.evidence['collectionId'], 'collectionId')} "
        f"token {as_int(result.evidence['tokenId'], 'tokenId')} "
        f"with dependency {result.evidence['externalScriptUrl']}"
    )
    if written:
        print("Wrote retained capture artifact(s): " + ", ".join(str(path) for path in written))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

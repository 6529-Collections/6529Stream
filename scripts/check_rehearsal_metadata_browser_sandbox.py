#!/usr/bin/env python3
"""Execute rehearsal-generated metadata in the browser sandbox."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


CHECKER_PATH = Path(__file__).with_name("check_metadata_browser_sandbox.py")
SPEC = importlib.util.spec_from_file_location("check_metadata_browser_sandbox", CHECKER_PATH)
assert SPEC is not None and SPEC.loader is not None
sandbox_checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = sandbox_checker
SPEC.loader.exec_module(sandbox_checker)

EXPECTED_EVIDENCE_KIND = "local-anvil-deployment-rehearsal"
EXPECTED_EXTERNAL_SCRIPT_URL = "https://cdn.6529.io/stream/rehearsal.js"
REHEARSAL_SCRIPT = "script/RehearseMetadataBrowser.s.sol:RehearseMetadataBrowser"
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


def run_forge_rehearsal() -> dict[str, Any]:
    """Run the local metadata rehearsal script and return Forge's JSON output."""

    env = forge_environment()
    forge = resolve_forge(env)
    command = [
        forge,
        "script",
        REHEARSAL_SCRIPT,
        "--sig",
        "run()",
        "--via-ir",
        "--json",
    ]
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
        if "returned" in record:
            return record
    raise RehearsalMetadataBrowserError(
        "forge metadata rehearsal did not include returned ABI data"
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


def extract_rehearsal_evidence(forge_output: dict[str, Any]) -> dict[str, Any]:
    """Extract rehearsal evidence from the Forge ABI return payload."""

    returned = forge_output.get("returned")
    if returned is None:
        raise RehearsalMetadataBrowserError("forge output is missing returned ABI data")
    return decode_rehearsal_return(returned)


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

    if evidence.get("evidenceKind") != EXPECTED_EVIDENCE_KIND:
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


def check_rehearsal_browser_sandbox(*, timeout_ms: int, headed: bool) -> dict[str, Any]:
    """Run the full Forge-to-Chromium rehearsal metadata browser check."""

    forge_output = run_forge_rehearsal()
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
    return evidence


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
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the rehearsal metadata browser sandbox check from the command line."""

    args = build_parser().parse_args(argv)
    try:
        evidence = check_rehearsal_browser_sandbox(
            timeout_ms=args.timeout_ms,
            headed=args.headed,
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
        f"for chain {as_int(evidence['chainId'], 'chainId')} "
        f"collection {as_int(evidence['collectionId'], 'collectionId')} "
        f"token {as_int(evidence['tokenId'], 'tokenId')} "
        f"with dependency {evidence['externalScriptUrl']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

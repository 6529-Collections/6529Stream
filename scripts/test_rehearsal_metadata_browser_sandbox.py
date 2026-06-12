#!/usr/bin/env python3
"""Focused tests for rehearsal metadata browser sandbox checks."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_rehearsal_metadata_browser_sandbox.py")
SPEC = importlib.util.spec_from_file_location(
    "check_rehearsal_metadata_browser_sandbox",
    SCRIPT_PATH,
)
assert SPEC is not None and SPEC.loader is not None, (
    f"Failed to load module spec from {SCRIPT_PATH}: {SPEC!r}"
)
rehearsal_checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = rehearsal_checker
SPEC.loader.exec_module(rehearsal_checker)


def valid_evidence() -> dict[str, object]:
    """Return a minimal decoded rehearsal evidence payload."""

    return {
        "evidenceKind": rehearsal_checker.EXPECTED_EVIDENCE_KIND,
        "chainId": "31337",
        "deploymentManifestHash": "0x" + "12" * 32,
        "collectionId": "1",
        "tokenId": "10000000000",
        "tokenHash": "0x" + "34" * 32,
        "tokenDataRaw": "1,2,3",
        "externalScriptUrl": rehearsal_checker.EXPECTED_EXTERNAL_SCRIPT_URL,
        "tokenUri": "data:application/json;base64,e30=",
    }


def word(value: int) -> bytes:
    """Encode an integer as one ABI word."""

    return value.to_bytes(32, byteorder="big")


def bytes32_word(value: str) -> bytes:
    """Encode a bytes32 hex string as one ABI word."""

    return bytes.fromhex(value[2:])


def string_tail(value: str) -> bytes:
    """Encode a dynamic ABI string tail."""

    encoded = value.encode("utf-8")
    padding = (32 - (len(encoded) % 32)) % 32
    return word(len(encoded)) + encoded + (b"\x00" * padding)


def forge_output_with_return(
    evidence: dict[str, object],
    *,
    wrapped: bool = False,
) -> dict[str, object]:
    """Wrap decoded evidence in Forge's raw ABI return shape."""

    dynamic_fields = [
        str(evidence["evidenceKind"]),
        str(evidence["tokenDataRaw"]),
        str(evidence["externalScriptUrl"]),
        str(evidence["tokenUri"]),
    ]
    tails = [string_tail(value) for value in dynamic_fields]
    head_size = len(rehearsal_checker.RETURN_FIELDS) * 32
    offsets: list[int] = []
    cursor = head_size
    for tail in tails:
        offsets.append(cursor)
        cursor += len(tail)

    head = b"".join(
        [
            word(offsets[0]),
            word(int(str(evidence["chainId"]))),
            bytes32_word(str(evidence["deploymentManifestHash"])),
            word(int(str(evidence["collectionId"]))),
            word(int(str(evidence["tokenId"]))),
            bytes32_word(str(evidence["tokenHash"])),
            word(offsets[1]),
            word(offsets[2]),
            word(offsets[3]),
        ]
    )
    payload = head + b"".join(tails)
    if wrapped:
        payload = word(32) + payload
    return {"returned": "0x" + payload.hex()}


class RehearsalMetadataBrowserTests(unittest.TestCase):
    """Unit tests for the rehearsal metadata browser checker."""

    def test_decodes_rehearsal_abi_return_from_forge_output(self) -> None:
        """The Forge returned ABI payload is decoded without tuple-string parsing."""

        evidence = rehearsal_checker.extract_rehearsal_evidence(
            forge_output_with_return(valid_evidence())
        )

        self.assertEqual(evidence["tokenDataRaw"], "1,2,3")
        self.assertEqual(
            evidence["externalScriptUrl"], rehearsal_checker.EXPECTED_EXTERNAL_SCRIPT_URL
        )

    def test_decodes_wrapped_rehearsal_abi_return_from_forge_output(self) -> None:
        """Single-return tuple wrappers are accepted across Forge output shapes."""

        evidence = rehearsal_checker.extract_rehearsal_evidence(
            forge_output_with_return(valid_evidence(), wrapped=True)
        )

        self.assertEqual(evidence["evidenceKind"], rehearsal_checker.EXPECTED_EVIDENCE_KIND)
        self.assertEqual(evidence["tokenHash"], "0x" + "34" * 32)

    def test_parses_noisy_forge_stdout_records(self) -> None:
        """Forge stdout can include non-JSON text around JSON records."""

        returned = forge_output_with_return(valid_evidence())["returned"]
        stdout = (
            "Compiling...\n"
            '{"status":"ok"}\n'
            "noise with {unparseable brace\n"
            f'{{"returned":"{returned}"}}\n'
        )

        records = rehearsal_checker.parse_forge_json_records(stdout)

        self.assertEqual(records[-1]["returned"], returned)

    def test_rejects_missing_rehearsal_return(self) -> None:
        """Forge output must contain the structured rehearsal return payload."""

        with self.assertRaisesRegex(
            rehearsal_checker.RehearsalMetadataBrowserError,
            "returned ABI data",
        ):
            rehearsal_checker.extract_rehearsal_evidence({"raw_logs": []})

    def test_validates_rehearsal_evidence_envelope(self) -> None:
        """A complete payload with the expected evidence fields is accepted."""

        rehearsal_checker.validate_rehearsal_evidence(valid_evidence())

    def test_rejects_wrong_evidence_kind(self) -> None:
        """The browser gate is tied to the local deployment-rehearsal source."""

        evidence = valid_evidence()
        evidence["evidenceKind"] = "committed-fixture"

        with self.assertRaisesRegex(
            rehearsal_checker.RehearsalMetadataBrowserError,
            "evidence kind",
        ):
            rehearsal_checker.validate_rehearsal_evidence(evidence)

    def test_rejects_bad_token_uri_shape(self) -> None:
        """The evidence tokenURI must be on-chain JSON metadata."""

        evidence = valid_evidence()
        evidence["tokenUri"] = "ipfs://metadata"

        with self.assertRaisesRegex(
            rehearsal_checker.RehearsalMetadataBrowserError,
            "tokenUri",
        ):
            rehearsal_checker.validate_rehearsal_evidence(evidence)

    def test_parse_token_data_values(self) -> None:
        """The tokenDataRaw string maps to browser bootstrap array values."""

        self.assertEqual(rehearsal_checker.parse_token_data("1, 2,3"), (1, 2, 3))

    def test_parse_empty_token_data(self) -> None:
        """Empty tokenDataRaw maps to an empty tuple."""

        self.assertEqual(rehearsal_checker.parse_token_data(""), ())
        self.assertEqual(rehearsal_checker.parse_token_data("  "), ())

    def test_rejects_non_integer_token_data(self) -> None:
        """Malformed tokenDataRaw values fail before Chromium launches."""

        with self.assertRaisesRegex(
            rehearsal_checker.RehearsalMetadataBrowserError,
            "non-integer",
        ):
            rehearsal_checker.parse_token_data("1,nope,3")

    def test_builds_expected_bootstrap_from_evidence(self) -> None:
        """The expected browser bootstrap values come from rehearsal evidence."""

        expected = rehearsal_checker.build_expected_bootstrap(valid_evidence())

        self.assertEqual(expected.hash_value, "0x" + "34" * 32)
        self.assertEqual(expected.token_id, 10_000_000_000)
        self.assertEqual(expected.token_data_raw, "1,2,3")
        self.assertEqual(expected.token_data, (1, 2, 3))


if __name__ == "__main__":
    unittest.main()

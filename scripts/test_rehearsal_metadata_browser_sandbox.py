#!/usr/bin/env python3
"""Focused tests for rehearsal metadata browser sandbox checks."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
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


def valid_sandbox_result() -> object:
    """Return a browser sandbox result matching valid_evidence()."""

    return rehearsal_checker.sandbox_checker.SandboxResult(
        expected_script_requests=(rehearsal_checker.EXPECTED_EXTERNAL_SCRIPT_URL,),
        unexpected_requests=(),
        page_errors=(),
        console_errors=(),
        dependency_loaded=True,
        dependency_url=rehearsal_checker.EXPECTED_EXTERNAL_SCRIPT_URL,
        script_count=2,
        hash_value="0x" + "34" * 32,
        token_id=10_000_000_000,
        token_data_raw="1,2,3",
        token_data_is_array=True,
        token_data_values=(1, 2, 3),
        draw_is_function=True,
        parent_access_blocked=True,
        parent_access_error_name="SecurityError",
    )


def valid_check_result() -> object:
    """Return a complete rehearsal browser result fixture."""

    return rehearsal_checker.RehearsalBrowserCheckResult(
        evidence=valid_evidence(),
        sandbox_result=valid_sandbox_result(),
    )


def valid_check_result_with_evidence(**updates: object) -> object:
    """Return a complete rehearsal browser result with evidence overrides."""

    evidence = valid_evidence()
    evidence.update(updates)
    return rehearsal_checker.RehearsalBrowserCheckResult(
        evidence=evidence,
        sandbox_result=valid_sandbox_result(),
    )


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


def forge_output_with_decoded_return(evidence: dict[str, object]) -> dict[str, object]:
    """Wrap decoded evidence in Forge's broadcast-mode return shape."""

    value = (
        f"({evidence['evidenceKind']}, {evidence['chainId']}, "
        f"{evidence['deploymentManifestHash']}, {evidence['collectionId']}, "
        f"{evidence['tokenId']}, {evidence['tokenHash']}, "
        f"{evidence['tokenDataRaw']}, {evidence['externalScriptUrl']}, "
        f"{evidence['tokenUri']})"
    )
    return {
        "returns": {
            "result": {
                "internal_type": (
                    "struct RehearseMetadataBrowser.MetadataBrowserResult"
                ),
                "value": value,
            }
        }
    }


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

    def test_decodes_forge_broadcast_return_shape(self) -> None:
        """Fork broadcast JSON returns a decoded tuple string instead of raw ABI."""

        source = valid_evidence()
        source["evidenceKind"] = rehearsal_checker.FORK_TESTNET_EVIDENCE_KIND
        evidence = rehearsal_checker.extract_rehearsal_evidence(
            forge_output_with_decoded_return(source)
        )

        self.assertEqual(evidence["evidenceKind"], rehearsal_checker.FORK_TESTNET_EVIDENCE_KIND)
        self.assertEqual(evidence["chainId"], "31337")
        self.assertEqual(evidence["tokenDataRaw"], "1,2,3")
        self.assertEqual(evidence["tokenUri"], "data:application/json;base64,e30=")

    def test_builds_default_forge_command(self) -> None:
        """The default command keeps the existing local simulation path."""

        command = rehearsal_checker.build_forge_command(
            "forge",
            rehearsal_checker.ForgeRehearsalOptions(),
        )

        self.assertEqual(
            command,
            [
                "forge",
                "script",
                rehearsal_checker.REHEARSAL_SCRIPT,
                "--sig",
                "run()",
                "--via-ir",
                "--json",
            ],
        )

    def test_builds_fork_forge_command(self) -> None:
        """Fork capture can opt into RPC, broadcast, unlocked, and sender flags."""

        command = rehearsal_checker.build_forge_command(
            "forge",
            rehearsal_checker.ForgeRehearsalOptions(
                rpc_url="http://127.0.0.1:8547",
                broadcast=True,
                unlocked=True,
                sender=rehearsal_checker.DEFAULT_FORK_SENDER,
            ),
        )

        self.assertIn("--rpc-url", command)
        self.assertIn("http://127.0.0.1:8547", command)
        self.assertIn("--broadcast", command)
        self.assertIn("--unlocked", command)
        self.assertIn("--sender", command)
        self.assertIn(rehearsal_checker.DEFAULT_FORK_SENDER, command)

    def test_redacted_forge_command_omits_rpc_url(self) -> None:
        """Retained command summaries must not include operator RPC URLs."""

        command = rehearsal_checker.redacted_forge_command(
            rehearsal_checker.ForgeRehearsalOptions(
                rpc_url="https://example.invalid/private-token",
                broadcast=True,
                unlocked=True,
                sender=rehearsal_checker.DEFAULT_FORK_SENDER,
            )
        )

        self.assertIn("REDACTED_LOCAL_OR_OPERATOR_RPC", command)
        self.assertNotIn("private-token", command)

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

    def test_builds_capture_summary_from_rehearsal_result(self) -> None:
        """The retained capture summary records Forge and Chromium evidence."""

        result = valid_check_result()

        summary = rehearsal_checker.build_capture_summary(result)

        self.assertEqual(
            summary["schema_version"],
            "6529stream.rehearsal-metadata-browser-capture.v1",
        )
        self.assertEqual(summary["chain_id"], 31337)
        self.assertEqual(summary["collection_id"], 1)
        self.assertEqual(summary["token_id"], 10_000_000_000)
        self.assertEqual(summary["token_hash"], "0x" + "34" * 32)
        self.assertRegex(str(summary["token_uri_sha256"]), r"^sha256:[0-9a-f]{64}$")
        self.assertEqual(summary["sandbox"]["unexpected_requests"], [])
        self.assertTrue(summary["sandbox"]["draw_is_function"])
        self.assertEqual(summary["sandbox"]["parent_access_error_name"], "SecurityError")

    def test_builds_capture_transcript_without_secret_shaped_fields(self) -> None:
        """The transcript summarizes the run without credential-shaped keys."""

        transcript = rehearsal_checker.build_capture_transcript(valid_check_result())

        self.assertIn("Rehearsal Metadata Browser Capture Transcript", transcript)
        self.assertIn("tokenURI digest", transcript)
        self.assertIn("Parent frame access blocked: `yes`", transcript)
        self.assertNotIn("api_key=", transcript)
        self.assertNotIn("--private-key", transcript)

    def test_writes_requested_capture_outputs(self) -> None:
        """Optional capture output paths are written with parent directories."""

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            summary_path = root / "retained" / "summary.json"
            token_uri_path = root / "retained" / "token-uri.txt"
            transcript_path = root / "retained" / "transcript.md"

            written = rehearsal_checker.write_capture_outputs(
                valid_check_result(),
                summary_json=summary_path,
                token_uri_output=token_uri_path,
                transcript_output=transcript_path,
            )

            self.assertEqual(written, [summary_path, token_uri_path, transcript_path])
            self.assertTrue(summary_path.is_file())
            self.assertTrue(token_uri_path.is_file())
            self.assertTrue(transcript_path.is_file())
            self.assertIn("schema_version", summary_path.read_text(encoding="utf-8"))
            self.assertTrue(
                token_uri_path.read_text(encoding="utf-8").startswith(
                    "data:application/json;base64,"
                )
            )
            self.assertIn(
                "Browser Sandbox Result",
                transcript_path.read_text(encoding="utf-8"),
            )

    def test_rejects_duplicate_capture_output_paths(self) -> None:
        """Operators cannot accidentally point multiple outputs at one file."""

        with tempfile.TemporaryDirectory() as temp_dir:
            output_path = Path(temp_dir) / "retained" / "capture.txt"

            with self.assertRaisesRegex(
                rehearsal_checker.RehearsalMetadataBrowserError,
                "must be distinct",
            ):
                rehearsal_checker.write_capture_outputs(
                    valid_check_result(),
                    summary_json=output_path,
                    token_uri_output=output_path,
                    transcript_output=None,
                )

    def test_rejects_secret_shaped_capture_output(self) -> None:
        """Generated capture outputs are scanned before they are retained."""

        with tempfile.TemporaryDirectory() as temp_dir:
            transcript_path = Path(temp_dir) / "retained" / "transcript.md"

            with self.assertRaisesRegex(
                rehearsal_checker.RehearsalMetadataBrowserError,
                "secret-like",
            ):
                rehearsal_checker.write_capture_outputs(
                    valid_check_result_with_evidence(tokenDataRaw="api_key=hidden"),
                    summary_json=None,
                    token_uri_output=None,
                    transcript_output=transcript_path,
                )


if __name__ == "__main__":
    unittest.main()

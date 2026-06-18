#!/usr/bin/env python3
"""Focused tests for the fork/testnet metadata browser evidence draft generator."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


GENERATOR_PATH = Path(__file__).with_name(
    "generate_fork_metadata_browser_evidence_draft.py"
)
GENERATOR_SPEC = importlib.util.spec_from_file_location(
    "generate_fork_metadata_browser_evidence_draft",
    GENERATOR_PATH,
)
assert GENERATOR_SPEC is not None and GENERATOR_SPEC.loader is not None
generator = importlib.util.module_from_spec(GENERATOR_SPEC)
GENERATOR_SPEC.loader.exec_module(generator)

CHECKER_PATH = Path(__file__).with_name("check_fork_metadata_browser_evidence.py")
CHECKER_SPEC = importlib.util.spec_from_file_location(
    "check_fork_metadata_browser_evidence",
    CHECKER_PATH,
)
assert CHECKER_SPEC is not None and CHECKER_SPEC.loader is not None
checker = importlib.util.module_from_spec(CHECKER_SPEC)
CHECKER_SPEC.loader.exec_module(checker)


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


def capture_summary(**updates: object) -> dict[str, object]:
    """Return a valid retained rehearsal capture summary."""
    value: dict[str, object] = {
        "schema_version": "6529stream.rehearsal-metadata-browser-capture.v1",
        "evidence_kind": "metadata-browser-rehearsal",
        "chain_id": 1,
        "deployment_manifest_hash": "0x" + "12" * 32,
        "collection_id": 1,
        "token_id": 10_000_000_000,
        "token_hash": "0x" + "34" * 32,
        "token_data_raw": "1,2,3",
        "token_uri_sha256": (
            "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        ),
        "external_script_url": "https://example.invalid/dependency.js",
        "sandbox": {
            "expected_script_requests": ["https://example.invalid/dependency.js"],
            "unexpected_requests": [],
            "page_errors": [],
            "console_errors": [],
            "dependency_loaded": True,
            "dependency_url": "https://example.invalid/dependency.js",
            "script_count": 2,
            "hash_value": "0x" + "34" * 32,
            "token_id": 10_000_000_000,
            "token_data_raw": "1,2,3",
            "token_data_is_array": True,
            "token_data_values": [1, 2, 3],
            "draw_is_function": True,
            "parent_access_blocked": True,
            "parent_access_error_name": "SecurityError",
        },
    }
    value.update(updates)
    return value


def seed_capture_files(root: Path) -> tuple[Path, Path, Path]:
    """Create retained capture files and return their paths."""
    summary = root / "capture" / "summary.json"
    token = root / "capture" / "token-uri.txt"
    transcript = root / "capture" / "transcript.md"
    write_json(summary, capture_summary())
    write_text(
        token,
        "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
    )
    write_text(transcript, "# Transcript\n\nNo secrets retained.\n")
    return summary, token, transcript


def valid_argv(root: Path) -> list[str]:
    """Return valid generator CLI arguments for a temp root."""
    summary, token, transcript = seed_capture_files(root)
    return [
        "--capture-summary-json",
        str(summary),
        "--token-uri-output",
        str(token),
        "--transcript-output",
        str(transcript),
        "--summary-output",
        str(root / "retained" / "browser-summary.json"),
        "--output",
        str(root / "retained" / "metadata-browser-evidence.md"),
        "--environment",
        "fork",
        "--chain-id",
        "1",
        "--git-commit",
        "1234567890abcdef1234567890abcdef12345678",
        "--ci-run-or-operator-transcript",
        "ci-run-123",
        "--block-or-reference",
        "fork block 25316366",
        "--deployment-version",
        "fork-mainnet-6529stream-v0.1.0-001",
        "--contract",
        "StreamCore=0x1111111111111111111111111111111111111111",
        "--operator",
        "release-operator",
        "--reviewer",
        "release-reviewer",
        "--metadata-fetched-from-deployed-contract",
    ]


class ForkMetadataBrowserEvidenceDraftTests(unittest.TestCase):
    """Draft generator behavior."""

    def test_generates_checker_valid_pending_review_artifact(self) -> None:
        """Generated pending-review drafts pass the existing evidence checker."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            with redirect_stdout(StringIO()):
                result = generator.main(valid_argv(root))

            output = root / "retained" / "metadata-browser-evidence.md"
            summary = root / "retained" / "browser-summary.json"
            token = root / "retained" / "token-uri.txt"
            transcript = root / "retained" / "browser-transcript.md"
            self.assertEqual(result, 0)
            self.assertTrue(output.is_file())
            self.assertTrue(summary.is_file())
            self.assertTrue(token.is_file())
            self.assertTrue(transcript.is_file())
            checker.validate_artifact(output)
            converted = json.loads(summary.read_text(encoding="utf-8"))
            self.assertEqual(
                converted["schema_version"],
                "6529stream.fork-testnet-metadata-browser-evidence.v1",
            )
            self.assertEqual(converted["token_results"][0]["token_id"], 10_000_000_000)

    def test_rejects_missing_deployed_contract_assertion(self) -> None:
        """The helper cannot silently convert local-only capture into evidence."""
        with tempfile.TemporaryDirectory() as temp_dir:
            argv = valid_argv(Path(temp_dir))
            argv.remove("--metadata-fetched-from-deployed-contract")

            with self.assertRaisesRegex(
                generator.ForkMetadataBrowserEvidenceDraftError,
                "metadata-fetched-from-deployed-contract",
            ):
                generator.generate_draft(generator.parse_args(argv))

    def test_rejects_wrong_capture_schema(self) -> None:
        """Only PR #554-style capture summaries are accepted."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            argv = valid_argv(root)
            summary = root / "capture" / "summary.json"
            data = json.loads(summary.read_text(encoding="utf-8"))
            data["schema_version"] = "wrong"
            write_json(summary, data)

            with self.assertRaisesRegex(
                generator.ForkMetadataBrowserEvidenceDraftError,
                "schema_version",
            ):
                generator.generate_draft(generator.parse_args(argv))

    def test_rejects_token_uri_digest_mismatch(self) -> None:
        """The retained tokenURI output must match the capture summary digest."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            argv = valid_argv(root)
            write_text(root / "capture" / "token-uri.txt", "different token uri\n")

            with self.assertRaisesRegex(
                generator.ForkMetadataBrowserEvidenceDraftError,
                "tokenURI output digest",
            ):
                generator.generate_draft(generator.parse_args(argv))

    def test_rejects_secret_shaped_transcript_before_writing(self) -> None:
        """Secret-shaped retained inputs fail before output files are written."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            argv = valid_argv(root)
            write_text(root / "capture" / "transcript.md", "--private-key 0xabc123\n")

            with self.assertRaisesRegex(
                generator.evidence_checker.ForkMetadataBrowserEvidenceError,
                "secret-like CLI",
            ):
                generator.generate_draft(generator.parse_args(argv))
            self.assertFalse((root / "retained" / "metadata-browser-evidence.md").exists())

    def test_rejects_output_path_collision(self) -> None:
        """Generated files cannot overwrite source capture files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            argv = valid_argv(root)
            summary_path = root / "capture" / "summary.json"
            index = argv.index("--summary-output") + 1
            argv[index] = str(summary_path)

            with self.assertRaisesRegex(
                generator.ForkMetadataBrowserEvidenceDraftError,
                "paths must be distinct",
            ):
                generator.generate_draft(generator.parse_args(argv))

    def test_main_reports_generation_errors(self) -> None:
        """CLI errors return non-zero with a concise stderr message."""
        with tempfile.TemporaryDirectory() as temp_dir:
            argv = valid_argv(Path(temp_dir))
            argv.remove("--metadata-fetched-from-deployed-contract")

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.main(argv)

            self.assertEqual(result, 1)
            self.assertIn("draft generation failed", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()

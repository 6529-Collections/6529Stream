#!/usr/bin/env python3
"""Focused tests for deterministic release notes generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_release_notes.py")
SPEC = importlib.util.spec_from_file_location("generate_release_notes", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def file_record(root: Path, relative_path: str) -> dict[str, object]:
    path = root / relative_path
    return {
        "path": relative_path,
        "sha256": generator.file_sha256(path),
        "size_bytes": path.stat().st_size,
    }


def seed_release_notes_tree(root: Path) -> dict[str, Path]:
    latest = root / "release-artifacts" / "latest"
    changelog = root / "CHANGELOG.md"
    release_manifest = latest / "release-manifest.json"
    bytecode_proof = latest / "bytecode-release-proof.json"
    risk_register = latest / "risk-register.json"
    json_output = latest / "release-notes.json"
    md_output = latest / "release-notes.md"

    write_text(
        changelog,
        "# Changelog\n\n"
        "## Unreleased\n\n"
        "### Added\n\n"
        "- Added deterministic release notes.\n",
    )
    write_json(
        risk_register,
        {
            "schema_version": "6529stream.risk-register.v1",
            "risks": [
                {
                    "id": "RISK-001",
                    "area": "release_evidence",
                    "status": "open_blocker",
                },
                {
                    "id": "RISK-002",
                    "area": "audit_boundary",
                    "status": "accepted_local_baseline",
                },
            ],
        },
    )
    write_json(
        release_manifest,
        {
            "schema_version": "6529stream.release-manifest.v1",
            "release": {
                "project": "6529Stream",
                "status": "pre_audit_local_baseline",
                "protocol_versions": ["0.1.0"],
                "deployment_versions": ["anvil-001"],
            },
            "release_artifacts": {
                "public_beta_evidence": {
                    "status": {
                        "public_beta": "blocked",
                        "production_release": "blocked",
                    }
                }
            },
        },
    )
    write_json(
        bytecode_proof,
        {
            "schema_version": "6529stream.bytecode-release-proof.v1",
            "proof_status": {
                "local_and_fork": "generated_from_committed_artifacts",
                "production": "missing_reviewed_live_proof",
            },
            "contract_proofs": [
                {"proof_id": "anvil-001:StreamCore"},
                {"proof_id": "anvil-001:StreamMinter"},
            ],
        },
    )
    return {
        "root": root,
        "changelog": changelog,
        "release_manifest": release_manifest,
        "bytecode_proof": bytecode_proof,
        "risk_register": risk_register,
        "json_output": json_output,
        "md_output": md_output,
    }


class ReleaseNotesTests(unittest.TestCase):
    def test_committed_release_notes_are_current(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            self.assertEqual(generator.main(["--repo-root", str(repo_root), "--check"]), 0)

    def test_generator_writes_json_and_markdown(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_notes_tree(root)
            written = generator.write_outputs(
                root,
                Path("release-artifacts/latest/release-notes.json"),
                Path("release-artifacts/latest/release-notes.md"),
                Path("CHANGELOG.md"),
                Path("release-artifacts/latest/release-manifest.json"),
                Path("release-artifacts/latest/bytecode-release-proof.json"),
                Path("release-artifacts/latest/risk-register.json"),
            )
            self.assertEqual([path.name for path in written], ["release-notes.json", "release-notes.md"])
            notes = json.loads(paths["json_output"].read_text(encoding="utf-8"))
            self.assertEqual(notes["schema_version"], generator.RELEASE_NOTES_SCHEMA)
            self.assertEqual(notes["release"]["status"], "pre_audit_local_baseline")
            self.assertEqual(notes["readiness"]["public_beta"], "blocked")
            self.assertEqual(notes["artifact_summary"]["bytecode_release_proof"]["contract_proof_count"], 2)
            self.assertIn("Added deterministic release notes.", notes["changelog"]["entries"])
            markdown = paths["md_output"].read_text(encoding="utf-8")
            self.assertIn("## Boundary", markdown)
            self.assertIn("do not prove live deployment", markdown)

    def test_generator_preserves_wrapped_changelog_bullets(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_notes_tree(root)
            write_text(
                root / "CHANGELOG.md",
                "# Changelog\n\n"
                "## Unreleased\n\n"
                "### Added\n\n"
                "- Added deterministic release notes from changelog and committed\n"
                "  release evidence, including wrapped continuation lines.\n"
                "- Added a second entry.\n",
            )
            generator.write_outputs(
                root,
                Path("release-artifacts/latest/release-notes.json"),
                Path("release-artifacts/latest/release-notes.md"),
                Path("CHANGELOG.md"),
                Path("release-artifacts/latest/release-manifest.json"),
                Path("release-artifacts/latest/bytecode-release-proof.json"),
                Path("release-artifacts/latest/risk-register.json"),
            )
            notes = json.loads(paths["json_output"].read_text(encoding="utf-8"))
            self.assertEqual(
                notes["changelog"]["entries"][0],
                "Added deterministic release notes from changelog and committed "
                "release evidence, including wrapped continuation lines.",
            )
            markdown = paths["md_output"].read_text(encoding="utf-8")
            self.assertIn("wrapped continuation lines", markdown)

    def test_check_mode_accepts_current_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_notes_tree(root)
            generator.write_outputs(
                root,
                Path("release-artifacts/latest/release-notes.json"),
                Path("release-artifacts/latest/release-notes.md"),
                Path("CHANGELOG.md"),
                Path("release-artifacts/latest/release-manifest.json"),
                Path("release-artifacts/latest/bytecode-release-proof.json"),
                Path("release-artifacts/latest/risk-register.json"),
            )
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.main(["--repo-root", str(root), "--check"])
            self.assertEqual(result, 0)

    def test_check_mode_rejects_stale_markdown(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_notes_tree(root)
            generator.write_outputs(
                root,
                Path("release-artifacts/latest/release-notes.json"),
                Path("release-artifacts/latest/release-notes.md"),
                Path("CHANGELOG.md"),
                Path("release-artifacts/latest/release-manifest.json"),
                Path("release-artifacts/latest/bytecode-release-proof.json"),
                Path("release-artifacts/latest/risk-register.json"),
            )
            write_text(root / "release-artifacts/latest/release-notes.md", "stale\n")
            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.main(["--repo-root", str(root), "--check"])
            self.assertEqual(result, 1)
            self.assertIn("changed release-artifacts/latest/release-notes.md", stderr.getvalue())

    def test_generator_rejects_missing_unreleased_entries(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_notes_tree(root)
            write_text(root / "CHANGELOG.md", "# Changelog\n\n## Unreleased\n\n")
            with self.assertRaisesRegex(generator.ReleaseNotesError, "no non-placeholder"):
                generator.build_notes(
                    root,
                    Path("release-artifacts/latest/release-notes.json"),
                    Path("release-artifacts/latest/release-notes.md"),
                    Path("CHANGELOG.md"),
                    Path("release-artifacts/latest/release-manifest.json"),
                    Path("release-artifacts/latest/bytecode-release-proof.json"),
                    Path("release-artifacts/latest/risk-register.json"),
                )

    def test_generator_rejects_risk_area_count_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_notes_tree(root)
            write_json(
                root / "release-artifacts/latest/risk-register.json",
                {
                    "schema_version": "6529stream.risk-register.v1",
                    "risks": [
                        {
                            "id": "RISK-001",
                            "area": "release_evidence",
                            "status": "open_blocker",
                        },
                        {
                            "id": "RISK-002",
                            "status": "accepted_local_baseline",
                        },
                    ],
                },
            )
            with self.assertRaisesRegex(generator.ReleaseNotesError, "risk area counts"):
                generator.build_notes(
                    root,
                    Path("release-artifacts/latest/release-notes.json"),
                    Path("release-artifacts/latest/release-notes.md"),
                    Path("CHANGELOG.md"),
                    Path("release-artifacts/latest/release-manifest.json"),
                    Path("release-artifacts/latest/bytecode-release-proof.json"),
                    Path("release-artifacts/latest/risk-register.json"),
                )

    def test_generator_rejects_risk_status_count_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_notes_tree(root)
            write_json(
                root / "release-artifacts/latest/risk-register.json",
                {
                    "schema_version": "6529stream.risk-register.v1",
                    "risks": [
                        {
                            "id": "RISK-001",
                            "area": "release_evidence",
                            "status": "open_blocker",
                        },
                        {
                            "id": "RISK-002",
                            "area": "audit_boundary",
                        },
                    ],
                },
            )
            with self.assertRaisesRegex(generator.ReleaseNotesError, "risk status counts"):
                generator.build_notes(
                    root,
                    Path("release-artifacts/latest/release-notes.json"),
                    Path("release-artifacts/latest/release-notes.md"),
                    Path("CHANGELOG.md"),
                    Path("release-artifacts/latest/release-manifest.json"),
                    Path("release-artifacts/latest/bytecode-release-proof.json"),
                    Path("release-artifacts/latest/risk-register.json"),
                )

    def test_generator_rejects_secret_shaped_changelog_entry(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_notes_tree(root)
            write_text(
                root / "CHANGELOG.md",
                "# Changelog\n\n## Unreleased\n\n- Rotated private_key=value.\n",
            )
            with self.assertRaisesRegex(generator.ReleaseNotesError, "secret-shaped"):
                generator.build_notes(
                    root,
                    Path("release-artifacts/latest/release-notes.json"),
                    Path("release-artifacts/latest/release-notes.md"),
                    Path("CHANGELOG.md"),
                    Path("release-artifacts/latest/release-manifest.json"),
                    Path("release-artifacts/latest/bytecode-release-proof.json"),
                    Path("release-artifacts/latest/risk-register.json"),
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)

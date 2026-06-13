#!/usr/bin/env python3
"""Tests for non-local release evidence metadata generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_non_local_release_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "generate_non_local_release_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)

checker = generator.evidence_checker


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def seed_template(root: Path) -> Path:
    """Create a valid public-beta template for generator tests."""
    retained_path = (
        root
        / "release-artifacts"
        / "evidence"
        / "public-beta-templates"
        / "retained-artifact-template.txt"
    )
    write_text(retained_path, "template retained artifact\n")
    template_path = (
        root
        / "release-artifacts"
        / "evidence"
        / "public-beta-templates"
        / "fork-deployment-rehearsal-template.json"
    )
    template = {
        "schema_version": checker.EVIDENCE_SCHEMA,
        "evidence_id": "public-beta-template-fork-deployment-rehearsal",
        "record_type": "template",
        "review_status": "template",
        "environment": "fork",
        "chain_id": 1,
        "block_or_reference": "template-only reference",
        "command_or_source_system": "template-only source",
        "retained_path": generator.repo_relative_path(
            root, retained_path, "retained artifact"
        ),
        "sha256": checker.file_sha256(retained_path),
        "redaction_statement": "Template contains no secrets.",
        "owner": "TBD",
        "reviewer": "TBD",
        "public_beta_requirement_id": "fork_deployment_rehearsal",
        "source": {
            "repository": "https://github.com/6529-Collections/6529Stream",
            "git_commit": "0" * 40,
            "source_dirty": False,
            "ci_run": "template",
        },
        "redaction_policy": {
            "no_secrets": True,
            "redacted_fields": [
                "private_key",
                "mnemonic",
                "seed_phrase",
                "api_key",
                "rpc_url",
                "unreleased_drop_payload",
            ],
        },
        "template_notice": "Template only. This file is not completion evidence.",
        "operator_notes": "Template for fork_deployment_rehearsal.",
    }
    write_json(template_path, template)
    return template_path


def base_args(root: Path, template: Path, retained: Path, output: Path) -> list[str]:
    """Return common generator CLI args."""
    return [
        "--repo-root",
        str(root),
        "--template",
        str(template),
        "--retained-artifact",
        str(retained),
        "--output",
        str(output),
        "--environment",
        "fork",
        "--chain-id",
        "1",
        "--block-or-reference",
        "fork block 19000000",
        "--command-or-source-system",
        "forge script script/RehearseDeployment.s.sol",
        "--owner",
        "release-operator",
        "--source-git-commit",
        "1" * 40,
        "--source-ci-run",
        "https://github.com/6529-Collections/6529Stream/actions/runs/1",
    ]


class NonLocalReleaseEvidenceGeneratorTests(unittest.TestCase):
    """Generator behavior for retained non-local release evidence."""

    def test_generates_pending_review_evidence_and_computes_hash(self) -> None:
        """Generated evidence validates and points at the retained artifact."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = seed_template(root)
            retained = root / "release-artifacts" / "evidence" / "fork" / "run.md"
            output = root / "release-artifacts" / "evidence" / "fork" / "evidence.json"
            write_text(retained, "sanitized fork transcript\n")

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.main(base_args(root, template, retained, output))

            self.assertEqual(result, 0)
            evidence = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(evidence["record_type"], "evidence")
            self.assertEqual(evidence["review_status"], "pending_review")
            self.assertEqual(
                evidence["public_beta_requirement_id"],
                "fork_deployment_rehearsal",
            )
            self.assertEqual(evidence["retained_path"], "release-artifacts/evidence/fork/run.md")
            self.assertEqual(evidence["sha256"], checker.file_sha256(retained))
            checker.validate_evidence(output, root)

    def test_check_mode_accepts_current_output(self) -> None:
        """Check mode succeeds when generated metadata matches the file."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = seed_template(root)
            retained = root / "release-artifacts" / "evidence" / "fork" / "run.md"
            output = root / "release-artifacts" / "evidence" / "fork" / "evidence.json"
            write_text(retained, "sanitized fork transcript\n")
            args = base_args(root, template, retained, output)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(generator.main(args), 0)
                self.assertEqual(generator.main([*args, "--check"]), 0)

    def test_check_mode_rejects_stale_output(self) -> None:
        """Check mode fails when the retained artifact hash changes."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = seed_template(root)
            retained = root / "release-artifacts" / "evidence" / "fork" / "run.md"
            output = root / "release-artifacts" / "evidence" / "fork" / "evidence.json"
            write_text(retained, "sanitized fork transcript\n")
            args = base_args(root, template, retained, output)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(generator.main(args), 0)
            write_text(retained, "updated sanitized fork transcript\n")

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.main([*args, "--check"])

            self.assertEqual(result, 1)
            self.assertIn("is stale", stderr.getvalue())

    def test_rejects_missing_retained_artifact(self) -> None:
        """The retained artifact must exist before metadata generation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = seed_template(root)
            retained = root / "release-artifacts" / "evidence" / "fork" / "missing.md"
            output = root / "release-artifacts" / "evidence" / "fork" / "evidence.json"

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.main(base_args(root, template, retained, output))

            self.assertEqual(result, 1)
            self.assertIn("retained artifact references missing file", stderr.getvalue())
            self.assertFalse(output.exists())

    def test_reviewed_evidence_requires_named_reviewer(self) -> None:
        """Reviewed output cannot keep the default TBD reviewer."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template = seed_template(root)
            retained = root / "release-artifacts" / "evidence" / "fork" / "run.md"
            output = root / "release-artifacts" / "evidence" / "fork" / "evidence.json"
            write_text(retained, "sanitized fork transcript\n")

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.main(
                    [
                        *base_args(root, template, retained, output),
                        "--review-status",
                        "reviewed",
                    ]
                )

            self.assertEqual(result, 1)
            self.assertIn("reviewer must be set", stderr.getvalue())
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)

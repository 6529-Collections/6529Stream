#!/usr/bin/env python3
"""Focused tests for risk register generation and validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


CHECKER_PATH = Path(__file__).with_name("check_risk_register.py")
CHECKER_SPEC = importlib.util.spec_from_file_location("check_risk_register", CHECKER_PATH)
assert CHECKER_SPEC is not None and CHECKER_SPEC.loader is not None
checker = importlib.util.module_from_spec(CHECKER_SPEC)
CHECKER_SPEC.loader.exec_module(checker)

GENERATOR_PATH = Path(__file__).with_name("generate_risk_register.py")
GENERATOR_SPEC = importlib.util.spec_from_file_location("generate_risk_register", GENERATOR_PATH)
assert GENERATOR_SPEC is not None and GENERATOR_SPEC.loader is not None
generator = importlib.util.module_from_spec(GENERATOR_SPEC)
GENERATOR_SPEC.loader.exec_module(generator)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def file_ref(path: Path, root: Path) -> dict[str, str]:
    return {
        "path": path.resolve().relative_to(root.resolve()).as_posix(),
        "sha256": checker.file_sha256(path),
    }


def seed_file(root: Path, relative_path: str, text: str = "seed\n") -> Path:
    path = root / relative_path
    write_text(path, text)
    return path


def minimal_register(root: Path) -> dict[str, object]:
    source = seed_file(root, "docs/source.md")
    evidence = seed_file(root, "docs/evidence.md")
    risks = []
    for index, area in enumerate(sorted(checker.REQUIRED_AREAS), start=1):
        risk_id = f"RISK-T{index:02d}-{index:03d}"
        if area == "audit_boundary":
            risk_id = "RISK-AUD-002"
        risks.append(
            {
                "id": risk_id,
                "title": f"{area} risk",
                "area": area,
                "severity": "medium",
                "status": "open_blocker",
                "owner": "TBD",
                "target_gate": "Gate F",
                "source": "unit test",
                "mitigation": "Retain evidence and track remediation.",
                "residual_risk": "The risk remains until evidence is reviewed.",
                "evidence": [file_ref(evidence, root)],
                "checks": ["python scripts/check_risk_register.py"],
                "tracking": ["https://github.com/6529-Collections/6529Stream/issues/388"],
                "risk_acceptance": None,
            }
        )
    risks = sorted(risks, key=lambda item: item["id"])
    return {
        "schema_version": checker.RISK_REGISTER_SCHEMA,
        "generated_by": "unit-test",
        "maturity": "pre_audit_local_baseline",
        "readiness_boundary": "No open blocker is release approval.",
        "source_documents": [file_ref(source, root)],
        "status_taxonomy": {status: f"{status} description" for status in checker.VALID_STATUSES},
        "risk_acceptance_policy": "Accepted risks need owner approval.",
        "risks": risks,
        "redaction_policy": {
            "no_secrets": True,
            "redacted_fields": ["private_key", "mnemonic", "api_key", "rpc_url"],
        },
        "operator_notes": "unit test",
    }


class RiskRegisterTests(unittest.TestCase):
    def test_accepts_committed_risk_register(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])
        self.assertEqual(result, 0)

    def test_generator_check_accepts_current_output(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = generator.main(["--repo-root", str(repo_root), "--check"])
        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_register(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            register_path = root / checker.DEFAULT_REGISTER
            write_json(register_path, minimal_register(root))

            checker.validate_risk_register(root, register_path)

    def test_rejects_missing_aud_002_row(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            register = minimal_register(root)
            register["risks"] = [
                risk for risk in register["risks"] if risk["id"] != "RISK-AUD-002"
            ]
            write_json(root / checker.DEFAULT_REGISTER, register)

            with self.assertRaisesRegex(
                checker.RiskRegisterError, "RISK-AUD-002|audit_boundary"
            ):
                checker.validate_risk_register(root, root / checker.DEFAULT_REGISTER)

    def test_rejects_duplicate_risk_ids(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            register = minimal_register(root)
            register["risks"][1]["id"] = register["risks"][0]["id"]
            register["risks"] = sorted(register["risks"], key=lambda item: item["id"])
            write_json(root / checker.DEFAULT_REGISTER, register)

            with self.assertRaisesRegex(checker.RiskRegisterError, "duplicate risk id"):
                checker.validate_risk_register(root, root / checker.DEFAULT_REGISTER)

    def test_rejects_missing_required_field(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            register = minimal_register(root)
            del register["risks"][0]["mitigation"]
            write_json(root / checker.DEFAULT_REGISTER, register)

            with self.assertRaisesRegex(checker.RiskRegisterError, "missing required field"):
                checker.validate_risk_register(root, root / checker.DEFAULT_REGISTER)

    def test_rejects_invalid_status(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            register = minimal_register(root)
            register["risks"][0]["status"] = "done"
            write_json(root / checker.DEFAULT_REGISTER, register)

            with self.assertRaisesRegex(checker.RiskRegisterError, "must be one of"):
                checker.validate_risk_register(root, root / checker.DEFAULT_REGISTER)

    def test_rejects_invalid_accepted_risk_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            register = minimal_register(root)
            register["risks"][0]["status"] = "accepted_risk"
            register["risks"][0]["risk_acceptance"] = {
                "accepted_by": "maintainer",
                "accepted_at": "not-a-date",
                "expires_at": "2026-12-31",
                "reference": "https://github.com/6529-Collections/6529Stream/issues/388",
                "notes": "temporary exception",
            }
            write_json(root / checker.DEFAULT_REGISTER, register)

            with self.assertRaisesRegex(checker.RiskRegisterError, "ISO-8601"):
                checker.validate_risk_register(root, root / checker.DEFAULT_REGISTER)

    def test_rejects_missing_evidence_path(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            register = minimal_register(root)
            register["risks"][0]["evidence"][0]["path"] = "docs/missing.md"
            write_json(root / checker.DEFAULT_REGISTER, register)

            with self.assertRaisesRegex(checker.RiskRegisterError, "references missing file"):
                checker.validate_risk_register(root, root / checker.DEFAULT_REGISTER)

    def test_rejects_path_escape(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            register = minimal_register(root)
            register["risks"][0]["evidence"][0]["path"] = "../outside.md"
            write_json(root / checker.DEFAULT_REGISTER, register)

            with self.assertRaisesRegex(checker.RiskRegisterError, "inside the repository"):
                checker.validate_risk_register(root, root / checker.DEFAULT_REGISTER)

    def test_rejects_stale_hash(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            register = minimal_register(root)
            write_json(root / checker.DEFAULT_REGISTER, register)
            (root / register["risks"][0]["evidence"][0]["path"]).write_text(
                "changed\n", encoding="utf-8", newline="\n"
            )

            with self.assertRaisesRegex(checker.RiskRegisterError, "sha256 mismatch"):
                checker.validate_risk_register(root, root / checker.DEFAULT_REGISTER)

    def test_rejects_empty_checks(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            register = minimal_register(root)
            register["risks"][0]["checks"] = []
            write_json(root / checker.DEFAULT_REGISTER, register)

            with self.assertRaisesRegex(checker.RiskRegisterError, "checks must not be empty"):
                checker.validate_risk_register(root, root / checker.DEFAULT_REGISTER)

    def test_rejects_secret_like_key_or_value(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            register = minimal_register(root)
            register["risks"][0]["api_key"] = "redacted"
            write_json(root / checker.DEFAULT_REGISTER, register)

            with self.assertRaisesRegex(
                checker.RiskRegisterError, "secret-shaped key|unexpected field"
            ):
                checker.validate_risk_register(root, root / checker.DEFAULT_REGISTER)

            register = minimal_register(root)
            register["risks"][0]["mitigation"] = "api_key=abc123"
            write_json(root / checker.DEFAULT_REGISTER, register)

            with self.assertRaisesRegex(checker.RiskRegisterError, "secret-shaped assignment"):
                checker.validate_risk_register(root, root / checker.DEFAULT_REGISTER)


if __name__ == "__main__":
    unittest.main(verbosity=2)

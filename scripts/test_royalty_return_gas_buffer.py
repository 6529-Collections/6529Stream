#!/usr/bin/env python3
"""Focused hostile tests for issue #671 shared-buffer planning evidence."""

from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT_DIR = Path(__file__).resolve().parent


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


generator = load_module(
    "generate_royalty_return_gas_buffer",
    SCRIPT_DIR / "generate_royalty_return_gas_buffer.py",
)
checker = load_module(
    "check_royalty_return_gas_buffer",
    SCRIPT_DIR / "check_royalty_return_gas_buffer.py",
)


class SharedBufferEvidenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.evidence = generator.build_evidence()

    def _check_mutation(self, mutation, diagnostic: str) -> None:
        mutated = copy.deepcopy(self.evidence)
        mutation(mutated)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "evidence.json"
            path.write_text(json.dumps(mutated, indent=2) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(checker.SharedBufferCheckError, diagnostic):
                checker.validate_evidence(path)

    def test_committed_evidence_is_current(self) -> None:
        checker.validate_evidence()
        self.assertEqual(
            checker.DEFAULT_EVIDENCE.read_text(encoding="utf-8"),
            generator.render_evidence(),
        )

    def test_generator_writes_repository_lf_bytes(self) -> None:
        with tempfile.TemporaryDirectory(dir=generator.REPO_ROOT) as tmp:
            output = Path(tmp) / "royalty-return-gas-buffer.json"
            self.assertEqual(generator.main(["--output", str(output)]), 0)
            rendered = output.read_bytes()
            self.assertNotIn(b"\r\n", rendered)
            self.assertEqual(rendered, generator.render_evidence().encode("utf-8"))

    def test_generator_check_rejects_crlf_serialization(self) -> None:
        with tempfile.TemporaryDirectory(dir=generator.REPO_ROOT) as tmp:
            output = Path(tmp) / "royalty-return-gas-buffer.json"
            output.write_bytes(
                generator.render_evidence().replace("\n", "\r\n").encode("utf-8")
            )
            self.assertEqual(
                generator.main(["--output", str(output), "--check"]),
                1,
            )

    def test_python_38_toml_fallback_preserves_compiler_profile(self) -> None:
        with mock.patch.object(generator, "tomllib", None):
            profile = generator._compiler_profile()
        self.assertEqual(profile["solc_version"], "0.8.19")
        self.assertEqual(profile["evm_version"], "paris")
        self.assertEqual(profile["optimizer_runs"], 200)
        self.assertTrue(profile["optimizer_enabled"])
        self.assertTrue(profile["via_ir"])
        self.assertEqual(profile["bytecode_hash"], "none")

    def test_rejects_completion_overclaim(self) -> None:
        self._check_mutation(
            lambda value: value.__setitem__("status", "complete"),
            r"evidence drift at \$\.status",
        )

    def test_rejects_twenty_third_buffer_claim(self) -> None:
        self._check_mutation(
            lambda value: value["shared_parameter"].__setitem__(
                "metadata_specific_buffer_added", True
            ),
            "metadata_specific_buffer_added",
        )

    def test_rejects_returndata_cap_drift(self) -> None:
        self._check_mutation(
            lambda value: value["returndata_policy"].__setitem__(
                "metadata_max_abi_bytes", 65_537
            ),
            "metadata_max_abi_bytes",
        )

    def test_rejects_measurement_drift(self) -> None:
        self._check_mutation(
            lambda value: value["measurements"]["scenarios"][1].__setitem__(
                "measured_gas",
                value["measurements"]["scenarios"][1]["measured_gas"] + 1,
            ),
            r"scenarios\[1\]\.measured_gas",
        )

    def test_rejects_floor_not_measurement_derived(self) -> None:
        self._check_mutation(
            lambda value: value["sizing"].__setitem__(
                "planning_immutable_floor",
                value["sizing"]["planning_immutable_floor"] - 10_000,
            ),
            "planning_immutable_floor",
        )

    def test_rejects_missing_raise_ordering(self) -> None:
        self._check_mutation(
            lambda value: value["governance_and_raise_chain"][
                "tested_orderings"
            ].pop(),
            "tested_orderings",
        )

    def test_rejects_fixed_stipend_readiness_overclaim(self) -> None:
        self._check_mutation(
            lambda value: value["fixed_stipend_compatibility"].__setitem__(
                "status", "complete"
            ),
            "fixed_stipend_compatibility.status",
        )

    def test_rejects_source_hash_drift(self) -> None:
        self._check_mutation(
            lambda value: value["sources"][0].__setitem__(
                "sha256", "sha256:" + "00" * 32
            ),
            r"sources\[0\]\.sha256",
        )

    def test_rejects_stream_core_delta_claim(self) -> None:
        self._check_mutation(
            lambda value: value["core_boundary"].__setitem__(
                "stream_core_delta_bytes", -1
            ),
            "stream_core_delta_bytes",
        )

    def test_rejects_removed_limitations(self) -> None:
        self._check_mutation(
            lambda value: value.__setitem__("limitations", []),
            "limitations",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)

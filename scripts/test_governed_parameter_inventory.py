#!/usr/bin/env python3
"""Focused regressions for check_governed_parameter_inventory.py."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from typing import Callable

import check_governed_parameter_inventory as checker


ROOT = Path(__file__).resolve().parents[1]
INVENTORY_PATH = ROOT / checker.DEFAULT_INVENTORY
SCHEMA_PATH = ROOT / checker.DEFAULT_SCHEMA
SOURCE_VERIFICATION_PATH = Path(
    "release-artifacts/latest/source-verification-inputs.json"
)
FIXTURE_SOURCE_PATH = Path("smart-contracts/StreamCore.sol")
SHARED_BUFFER_EVIDENCE_PATH = Path(
    "release-artifacts/royalty-return-gas-buffer.json"
)
NORMATIVE_PATHS = tuple(
    sorted(
        {Path(row["normative_path"]) for row in checker.EXPECTED_ROWS}
        | {Path(row["path"]) for row in checker.EXPECTED_NORMATIVE_SOURCES}
    )
)


def load_inventory() -> dict[str, object]:
    value = json.loads(INVENTORY_PATH.read_text(encoding="utf-8"))
    assert isinstance(value, dict)
    return value


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class GovernedParameterInventoryTests(unittest.TestCase):
    def _validate_mutation(
        self,
        mutation: Callable[[dict[str, object]], None],
        pattern: str,
    ) -> None:
        temporary, root, path, inventory = self._fixture_root()
        try:
            mutation(inventory)
            write_json(path, inventory)
            with self.assertRaisesRegex(
                checker.GovernedParameterInventoryError,
                pattern,
            ):
                checker.validate_inventory(root, path)
        finally:
            temporary.cleanup()

    def _fixture_root(
        self,
    ) -> tuple[tempfile.TemporaryDirectory[str], Path, Path, dict[str, object]]:
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        required = (
            *NORMATIVE_PATHS,
            checker.GENESIS_PROFILE,
            checker.DEFAULT_SCHEMA,
            SOURCE_VERIFICATION_PATH,
            FIXTURE_SOURCE_PATH,
            SHARED_BUFFER_EVIDENCE_PATH,
        )
        for relative in required:
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        inventory = load_inventory()
        inventory_path = root / checker.DEFAULT_INVENTORY
        write_json(inventory_path, inventory)
        return temporary, root, inventory_path, inventory

    def _host_facts(
        self,
        inventory: dict[str, object],
        row_index: int,
    ) -> list[dict[str, object]]:
        row = inventory["parameters"][row_index]
        expected = checker.EXPECTED_ROWS[row_index]
        facts: list[dict[str, object]] = []
        for index, profile in enumerate(row["expected_hosts"]["profiles"]):
            genesis = 1_000 + index
            facts.append(
                {
                    "profile_key": profile["key"],
                    "genesis_value": genesis,
                    "immutable_floor": 500 + index,
                    "failure_class_id": (
                        expected["failure_class_id"]
                        if expected["family"] == "GGP"
                        else None
                    ),
                    "wall_clock_floor_seconds": (
                        None if expected["family"] == "GGP" else 6_000 + index
                    ),
                }
            )
        return facts

    def _measurement_document(
        self,
        inventory: dict[str, object],
        row_index: int,
    ) -> dict[str, object]:
        row = inventory["parameters"][row_index]
        expected = checker.EXPECTED_ROWS[row_index]
        return {
            "schema_version": checker.MEASUREMENT_EVIDENCE_SCHEMA,
            "candidate_id": "candidate-mainnet-v1",
            "candidate_commit": "a" * 40,
            "review_status": "reviewed",
            "parameter_id": row["parameter_id"],
            "covered_profile_keys": list(expected["host_keys"]),
            "host_facts": self._host_facts(inventory, row_index),
            "consumer_audit": {
                "review_status": "reviewed",
                "consumers": list(expected["guarded_consumers"]),
            },
        }

    def _fixed_document(
        self,
        inventory: dict[str, object],
        row_index: int,
    ) -> dict[str, object]:
        row = inventory["parameters"][row_index]
        expected = checker.EXPECTED_ROWS[row_index]
        return {
            "schema_version": checker.FIXED_STIPEND_EVIDENCE_SCHEMA,
            "candidate_id": "candidate-mainnet-v1",
            "candidate_commit": "a" * 40,
            "review_status": "reviewed",
            "parameter_id": row["parameter_id"],
            "covered_profile_keys": list(expected["host_keys"]),
            "host_facts": self._host_facts(inventory, row_index),
            "disposition": expected["fixed_disposition"],
            "consumers": list(expected["fixed_consumers"]),
        }

    def _install_measurement(
        self,
        root: Path,
        inventory: dict[str, object],
        row_index: int,
        document: dict[str, object] | None = None,
    ) -> Path:
        path = (
            root
            / checker.EVIDENCE_ROOT
            / f"measurement-{row_index + 1}.json"
        )
        write_json(
            path,
            document or self._measurement_document(inventory, row_index),
        )
        inventory["parameters"][row_index]["measurement_evidence"].update(
            {
                "status": "complete",
                "path": path.relative_to(root).as_posix(),
                "sha256": sha256(path),
            }
        )
        return path

    def _install_fixed(
        self,
        root: Path,
        inventory: dict[str, object],
        row_index: int,
        document: dict[str, object] | None = None,
    ) -> Path:
        path = root / checker.EVIDENCE_ROOT / f"fixed-{row_index + 1}.json"
        write_json(path, document or self._fixed_document(inventory, row_index))
        inventory["parameters"][row_index]["fixed_stipend_compatibility"].update(
            {
                "status": "complete",
                "evidence_path": path.relative_to(root).as_posix(),
                "evidence_sha256": sha256(path),
            }
        )
        return path

    def _install_complete_candidate(
        self,
        root: Path,
        inventory: dict[str, object],
    ) -> None:
        source_verification = root / SOURCE_VERIFICATION_PATH
        candidate_path = root / checker.CANDIDATE_ROOT / "production-candidate.json"
        write_json(candidate_path, {"schema_version": "opaque.unrecognized"})
        bindings: list[dict[str, object]] = []
        binding_index = 0
        for row_index, row in enumerate(inventory["parameters"]):
            expected = checker.EXPECTED_ROWS[row_index]
            for profile in row["expected_hosts"]["profiles"]:
                binding_index += 1
                profile_id = profile["id"]
                genesis = 10_000 + binding_index
                bindings.append(
                    {
                        "candidate_instance_id": profile["key"].lower(),
                        "contract_name": "StreamCore",
                        "contract_source": FIXTURE_SOURCE_PATH.as_posix(),
                        "parameter_id": row["parameter_id"],
                        "profile_id": profile_id,
                        "profile_key": profile["key"],
                        "host_address": f"0x{profile_id:040x}",
                        "runtime_code_keccak256": f"0x{profile_id:064x}",
                        "governance_authority": "0x" + "f" * 40,
                        "source_verification_binding": {
                            "path": SOURCE_VERIFICATION_PATH.as_posix(),
                            "sha256": sha256(source_verification),
                            "target_name": "StreamCore",
                            "target_source": FIXTURE_SOURCE_PATH.as_posix(),
                        },
                        "genesis_value": genesis,
                        "immutable_floor": genesis // 2,
                        "failure_class_id": (
                            expected["failure_class_id"]
                            if expected["family"] == "GGP"
                            else None
                        ),
                        "wall_clock_floor_seconds": (
                            None
                            if expected["family"] == "GGP"
                            else 6_000 + binding_index
                        ),
                        "genesis_revision": 1,
                    }
                )
        inventory["candidate_binding"].update(
            {
                "status": "complete",
                "blocked_by_issue": None,
                "candidate_id": "candidate-mainnet-v1",
                "candidate_commit": "a" * 40,
                "candidate_artifact_path": candidate_path.relative_to(root).as_posix(),
                "candidate_artifact_sha256": sha256(candidate_path),
                "host_bindings": bindings,
            }
        )

    def test_committed_planning_inventory_and_schema_pass(self) -> None:
        inventory = checker.validate_inventory(ROOT, checker.DEFAULT_INVENTORY)
        self.assertEqual(inventory["status"], "planning")
        self.assertEqual(len(inventory["parameters"]), 25)
        self.assertEqual(
            inventory["inventory_summary"]["expected_host_binding_count"],
            50,
        )

    def test_schema_is_valid_draft_2020_12_and_rejects_boolean_integers(self) -> None:
        schema = checker._load_json(SCHEMA_PATH, "test schema")
        inventory = load_inventory()
        checker._validate_schema(schema, inventory, "inventory")
        inventory["governance_policy"]["action_class"]["id"] = True
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "does not satisfy.*schema",
        ):
            checker._validate_schema(schema, inventory, "inventory")

    def test_require_complete_rejects_planning_inventory(self) -> None:
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "production completeness required",
        ):
            checker.validate_inventory(
                ROOT,
                checker.DEFAULT_INVENTORY,
                require_complete=True,
            )

    def test_parameter_id_family_and_order_are_exact(self) -> None:
        self._validate_mutation(
            lambda value: value["parameters"][0].__setitem__(
                "parameter_id",
                "0x" + "0" * 64,
            ),
            "parameter_id must recompute",
        )
        self._validate_mutation(
            lambda value: value["parameters"][0].__setitem__("family", "GTP"),
            "does not satisfy.*schema|family must be GGP",
        )
        self._validate_mutation(
            lambda value: value["parameters"][0].__setitem__("order", 2),
            "order must be 1",
        )

    def test_boolean_manual_policy_fields_are_rejected_by_schema(self) -> None:
        fields = (
            ("governance action", lambda value: value["governance_policy"]["action_class"].__setitem__("id", True)),
            ("row order", lambda value: value["parameters"][0].__setitem__("order", True)),
            ("failure class", lambda value: value["parameters"][0]["gas"]["failure_class"].__setitem__("id", True)),
        )
        for name, mutation in fields:
            with self.subTest(name=name):
                self._validate_mutation(mutation, "does not satisfy.*schema")

    def test_uint256_and_uint64_overflow_are_rejected(self) -> None:
        def uint256_overflow(value: dict[str, object]) -> None:
            fact = value["parameters"][0]["gas"]["genesis_value"]
            fact.update({"status": "complete", "value": checker.UINT256_MAX + 1})

        def uint64_overflow(value: dict[str, object]) -> None:
            fact = value["parameters"][22]["time"]["wall_clock_floor_seconds"]
            fact.update({"status": "complete", "value": checker.UINT64_MAX + 1})

        self._validate_mutation(uint256_overflow, "does not satisfy.*schema")
        self._validate_mutation(uint64_overflow, "does not satisfy.*schema")

    def test_genesis_profile_record_is_hash_and_schema_bound(self) -> None:
        self._validate_mutation(
            lambda value: value["genesis_profile"].__setitem__(
                "sha256",
                "0" * 64,
            ),
            "genesis_profile.sha256 mismatch",
        )
        self._validate_mutation(
            lambda value: value["genesis_profile"].__setitem__(
                "schema_version",
                "fixture.wrong",
            ),
            "does not satisfy.*schema",
        )

    def test_genesis_profile_file_drift_is_rejected(self) -> None:
        temporary, root, inventory_path, _ = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        profile = root / checker.GENESIS_PROFILE
        profile.write_text(
            profile.read_text(encoding="utf-8") + "\n",
            encoding="utf-8",
        )
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "genesis_profile.sha256 mismatch",
        ):
            checker.validate_inventory(root, inventory_path)

    def test_forbidden_surface_list_is_exact_and_does_not_forbid_status_read(self) -> None:
        inventory = load_inventory()
        self.assertEqual(
            inventory["governance_policy"]["forbidden_surfaces"],
            [
                "lower_mutation",
                "standalone_parameter_probe_contract",
                "probe_binding",
                "emergency_mutation",
                "rebind",
                "conditional_mutation",
                "permissionless_mutation",
            ],
        )
        self.assertIn(
            "ENTROPY_RESULT_PROBE_GAS_LIMIT",
            [row["name"] for row in inventory["parameters"]],
        )
        self._validate_mutation(
            lambda value: value["governance_policy"]["forbidden_surfaces"].pop(),
            "does not satisfy.*schema",
        )

    def test_sale_delegate_and_provider_host_sets_are_exact(self) -> None:
        inventory = load_inventory()
        delegate = inventory["parameters"][10]["expected_hosts"]
        self.assertEqual(delegate["count"], 5)
        self.assertEqual(
            [profile["key"] for profile in delegate["profiles"]],
            [
                "DELEGATE_REGISTRY_GATE",
                "FIXED_PRICE_SALE_ADAPTER",
                "ENGLISH_AUCTION_HOUSE",
                "DUTCH_AUCTION_ADAPTER",
                "PRIVATE_SALE_ADAPTER",
            ],
        )
        for row_index in (9, 11, 12, 13):
            self.assertEqual(
                len(inventory["parameters"][row_index]["expected_hosts"]["profiles"]),
                4,
            )
        self.assertEqual(
            len(inventory["parameters"][18]["expected_hosts"]["profiles"]),
            2,
        )

    def test_nested_cap_fixed_stipend_rows_are_explicit(self) -> None:
        inventory = load_inventory()
        expected_required = {0, 1, 3, 7, 10, 14, 15, 18, 21}
        actual_required = {
            index
            for index, row in enumerate(inventory["parameters"])
            if row["fixed_stipend_compatibility"]["disposition"]
            == "evidence_required"
        }
        self.assertEqual(actual_required, expected_required)
        for index in expected_required:
            self.assertTrue(
                inventory["parameters"][index]["fixed_stipend_compatibility"][
                    "consumers"
                ]
            )

    def test_shared_buffer_planning_is_explicit_and_candidate_incomplete(self) -> None:
        inventory = load_inventory()
        planning = inventory["shared_buffer_planning"]
        self.assertEqual(planning["status"], "planning_target_fixture")
        self.assertEqual(
            planning["guarded_consumers"],
            [
                "StreamCore.royaltyInfo(uint256,uint256)",
                "StreamCore.tokenURI(uint256)",
                "StreamCore.contractURI()",
            ],
        )
        self.assertEqual(planning["genesis_value"]["value"], 2_910_000)
        self.assertEqual(planning["immutable_floor"]["value"], 1_460_000)
        self.assertEqual(
            planning["fixed_stipend_compatibility"]["status"], "missing"
        )
        checker.validate_inventory(ROOT, INVENTORY_PATH)

    def test_shared_buffer_planning_hash_and_raise_chain_are_bound(self) -> None:
        self._validate_mutation(
            lambda value: value["shared_buffer_planning"]["planning_evidence"].__setitem__(
                "sha256", "0" * 64
            ),
            "planning_evidence.sha256 mismatch",
        )
        self._validate_mutation(
            lambda value: value["shared_buffer_planning"][
                "independent_raise_chain"
            ]["limit_parameters"].reverse(),
            "does not satisfy.*schema",
        )

    def test_shared_buffer_cannot_overclaim_fixed_stipend_completion(self) -> None:
        self._validate_mutation(
            lambda value: value["shared_buffer_planning"][
                "fixed_stipend_compatibility"
            ].__setitem__("status", "complete"),
            "does not satisfy.*schema",
        )

    def test_structured_measurement_and_fixed_evidence_are_categorically_blocked(
        self,
    ) -> None:
        temporary, root, inventory_path, inventory = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        self._install_measurement(root, inventory, 0)
        self._install_fixed(root, inventory, 0)
        write_json(inventory_path, inventory)
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "complete governed-parameter evidence is unsupported",
        ):
            checker.validate_inventory(root, inventory_path)

    def test_evidence_failure_class_rejects_boolean_alias_for_one(self) -> None:
        for evidence_kind in ("measurement", "fixed"):
            with self.subTest(evidence_kind=evidence_kind):
                temporary, root, inventory_path, inventory = self._fixture_root()
                self.addCleanup(temporary.cleanup)
                if evidence_kind == "measurement":
                    document = self._measurement_document(inventory, 0)
                    installer = self._install_measurement
                else:
                    document = self._fixed_document(inventory, 0)
                    installer = self._install_fixed
                document["host_facts"][0]["failure_class_id"] = True
                installer(root, inventory, 0, document)
                write_json(inventory_path, inventory)
                with self.assertRaisesRegex(
                    checker.GovernedParameterInventoryError,
                    "failure_class_id must be an integer",
                ):
                    checker.validate_inventory(root, inventory_path)

    def test_normative_sources_must_exist_and_resolve_their_anchors(self) -> None:
        temporary, root, inventory_path, _ = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        adr = root / "docs/adr/0017-raise-only-parameter-governance.md"
        adr.unlink()
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            r"normative_sources\[2\].path references a missing or inaccessible file",
        ):
            checker.validate_inventory(root, inventory_path)

        shutil.copyfile(ROOT / adr.relative_to(root), adr)
        adr.write_text(
            adr.read_text(encoding="utf-8").replace("## Decision", "## Outcome"),
            encoding="utf-8",
            newline="\n",
        )
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            r"normative_sources\[2\].anchor does not identify a Markdown heading",
        ):
            checker.validate_inventory(root, inventory_path)

    def test_parameter_normative_anchor_requires_a_declaration(self) -> None:
        temporary, root, inventory_path, _ = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        source = root / "docs/revenue-splits-and-royalties.md"
        source.write_text(
            source.read_text(encoding="utf-8").replace(
                "Requirements [RSR-GGP]:",
                "Requirements:",
                1,
            ),
            encoding="utf-8",
            newline="\n",
        )
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            r"normative anchor \[RSR-GGP\] has no declaration",
        ):
            checker.validate_inventory(root, inventory_path)

    def test_evidence_host_facts_are_host_local_not_logical_row_equality(self) -> None:
        temporary, root, inventory_path, inventory = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        document = self._measurement_document(inventory, 18)
        document["host_facts"][0]["genesis_value"] = 111_111
        document["host_facts"][0]["immutable_floor"] = 55_555
        document["host_facts"][1]["genesis_value"] = 222_222
        document["host_facts"][1]["immutable_floor"] = 66_666
        self._install_measurement(root, inventory, 18, document)
        write_json(inventory_path, inventory)
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "complete governed-parameter evidence is unsupported",
        ):
            checker.validate_inventory(root, inventory_path)

    def test_measurement_and_fixed_evidence_must_share_host_facts(self) -> None:
        temporary, root, inventory_path, inventory = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        self._install_measurement(root, inventory, 0)
        fixed = self._fixed_document(inventory, 0)
        fixed["host_facts"][0]["genesis_value"] += 1
        self._install_fixed(root, inventory, 0, fixed)
        write_json(inventory_path, inventory)
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "same candidate and host facts",
        ):
            checker.validate_inventory(root, inventory_path)

    def test_opaque_or_unreviewed_measurement_evidence_is_rejected(self) -> None:
        temporary, root, inventory_path, inventory = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        self._install_measurement(
            root,
            inventory,
            0,
            {"schema_version": "opaque.unreviewed"},
        )
        write_json(inventory_path, inventory)
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "keys must be exactly",
        ):
            checker.validate_inventory(root, inventory_path)

        document = self._measurement_document(inventory, 0)
        document["review_status"] = "draft"
        self._install_measurement(root, inventory, 0, document)
        write_json(inventory_path, inventory)
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "review_status must be reviewed",
        ):
            checker.validate_inventory(root, inventory_path)

    def test_evidence_candidate_commit_and_profile_coverage_are_exact(self) -> None:
        for field, mutation, pattern in (
            (
                "commit",
                lambda document: document.__setitem__("candidate_commit", "A" * 40),
                "40 lowercase",
            ),
            (
                "profiles",
                lambda document: document["covered_profile_keys"].pop(),
                "covered_profile_keys",
            ),
            (
                "parameter",
                lambda document: document.__setitem__(
                    "parameter_id",
                    "0x" + "0" * 64,
                ),
                "parameter_id must be",
            ),
        ):
            with self.subTest(field=field):
                temporary, root, inventory_path, inventory = self._fixture_root()
                self.addCleanup(temporary.cleanup)
                document = self._measurement_document(inventory, 18)
                mutation(document)
                self._install_measurement(root, inventory, 18, document)
                write_json(inventory_path, inventory)
                with self.assertRaisesRegex(
                    checker.GovernedParameterInventoryError,
                    pattern,
                ):
                    checker.validate_inventory(root, inventory_path)

    def test_consumer_completion_requires_reviewed_consumer_audit(self) -> None:
        def complete_consumers(value: dict[str, object]) -> None:
            value["parameters"][0]["guarded_consumers"]["status"] = "complete"

        self._validate_mutation(
            complete_consumers,
            "cannot be complete without reviewed measurement",
        )

        temporary, root, inventory_path, inventory = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        inventory["parameters"][0]["guarded_consumers"]["status"] = "complete"
        self._install_measurement(root, inventory, 0)
        write_json(inventory_path, inventory)
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "complete governed-parameter evidence is unsupported",
        ):
            checker.validate_inventory(root, inventory_path)

    def test_evidence_digest_is_verified(self) -> None:
        temporary, root, inventory_path, inventory = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        self._install_measurement(root, inventory, 0)
        inventory["parameters"][0]["measurement_evidence"]["sha256"] = "0" * 64
        write_json(inventory_path, inventory)
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "sha256 mismatch",
        ):
            checker.validate_inventory(root, inventory_path)

    def test_reference_paths_reject_windows_and_portability_tricks(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            invalid = (
                "/Windows/win.ini",
                "C:outside.json",
                "release-artifacts/evidence/governed-parameters/../x.json",
                "release-artifacts/evidence/governed-parameters/./x.json",
                r"release-artifacts\evidence\governed-parameters\x.json",
                "release-artifacts/evidence/governed-parameters/CON.json",
                "release-artifacts/evidence/governed-parameters/trailing. /x.json",
            )
            for value in invalid:
                with self.subTest(value=value), self.assertRaisesRegex(
                    checker.GovernedParameterInventoryError,
                    "normalized portable|must be below",
                ):
                    checker._resolve_reference(
                        root,
                        value,
                        "reference",
                        required_root=checker.EVIDENCE_ROOT,
                    )

    def test_inventory_input_is_confined_to_release_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            outside = Path(temporary) / "inventory.json"
            write_json(outside, load_inventory())
            with self.assertRaisesRegex(
                checker.GovernedParameterInventoryError,
                "must stay inside the repository",
            ):
                checker.validate_inventory(ROOT, outside)

        temporary, root, inventory_path, _ = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        outside = root / "outside.json"
        write_json(outside, load_inventory())
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "must be below release-artifacts",
        ):
            checker.validate_inventory(root, outside)

        linked_inventory = inventory_path.with_name("linked-inventory.json")
        try:
            os.symlink(inventory_path, linked_inventory)
        except OSError as exc:
            self.skipTest(f"symlink creation unavailable: {exc}")
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "symlink, junction, or reparse",
        ):
            checker.validate_inventory(root, linked_inventory)

    def test_reference_paths_reject_symlink_components(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            evidence = root / checker.EVIDENCE_ROOT
            evidence.mkdir(parents=True)
            target = root / "target.json"
            write_json(target, {"value": 1})
            link = evidence / "link.json"
            try:
                os.symlink(target, link)
            except OSError as exc:
                self.skipTest(f"symlink creation unavailable: {exc}")
            with self.assertRaisesRegex(
                checker.GovernedParameterInventoryError,
                "symlink, junction, or reparse",
            ):
                checker._resolve_reference(
                    root,
                    link.relative_to(root).as_posix(),
                    "reference",
                    required_root=checker.EVIDENCE_ROOT,
                )

    def test_candidate_complete_is_always_blocked_without_issue_656_model(self) -> None:
        temporary, root, inventory_path, inventory = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        self._install_complete_candidate(root, inventory)
        write_json(inventory_path, inventory)
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "unsupported until issue #656",
        ):
            checker.validate_inventory(root, inventory_path)

    def test_candidate_complete_requires_null_blocker(self) -> None:
        temporary, root, inventory_path, inventory = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        self._install_complete_candidate(root, inventory)
        inventory["candidate_binding"]["blocked_by_issue"] = (
            checker.PRODUCTION_CANDIDATE_ISSUE
        )
        write_json(inventory_path, inventory)
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "does not satisfy.*schema",
        ):
            checker.validate_inventory(root, inventory_path)

    def test_candidate_binding_requires_instance_code_authority_and_source(self) -> None:
        required = (
            "candidate_instance_id",
            "contract_name",
            "contract_source",
            "runtime_code_keccak256",
            "governance_authority",
            "source_verification_binding",
        )
        for field in required:
            with self.subTest(field=field):
                temporary, root, inventory_path, inventory = self._fixture_root()
                self.addCleanup(temporary.cleanup)
                self._install_complete_candidate(root, inventory)
                del inventory["candidate_binding"]["host_bindings"][0][field]
                write_json(inventory_path, inventory)
                with self.assertRaisesRegex(
                    checker.GovernedParameterInventoryError,
                    field,
                ):
                    checker.validate_inventory(root, inventory_path)

    def test_candidate_zero_address_and_boolean_facts_are_rejected(self) -> None:
        for field, value in (
            ("host_address", "0x" + "0" * 40),
            ("governance_authority", "0x" + "0" * 40),
            ("genesis_revision", True),
            ("failure_class_id", True),
        ):
            with self.subTest(field=field):
                temporary, root, inventory_path, inventory = self._fixture_root()
                self.addCleanup(temporary.cleanup)
                self._install_complete_candidate(root, inventory)
                inventory["candidate_binding"]["host_bindings"][0][field] = value
                write_json(inventory_path, inventory)
                with self.assertRaisesRegex(
                    checker.GovernedParameterInventoryError,
                    "does not satisfy.*schema",
                ):
                    checker.validate_inventory(root, inventory_path)

    def test_candidate_replicated_profile_identity_must_be_consistent(self) -> None:
        temporary, root, inventory_path, inventory = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        self._install_complete_candidate(root, inventory)
        stream_core = [
            binding
            for binding in inventory["candidate_binding"]["host_bindings"]
            if binding["profile_key"] == "STREAM_CORE"
        ]
        self.assertGreaterEqual(len(stream_core), 2)
        stream_core[1]["host_address"] = "0x" + "e" * 40
        write_json(inventory_path, inventory)
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "one consistent instance/address/code/authority/source identity",
        ):
            checker.validate_inventory(root, inventory_path)

    def test_candidate_host_facts_are_not_forced_equal_across_replicas(self) -> None:
        temporary, root, inventory_path, inventory = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        self._install_complete_candidate(root, inventory)
        bindings = inventory["candidate_binding"]["host_bindings"]
        vrf = [
            binding
            for binding in bindings
            if binding["parameter_id"]
            == inventory["parameters"][18]["parameter_id"]
        ]
        self.assertEqual(len(vrf), 2)
        self.assertNotEqual(vrf[0]["genesis_value"], vrf[1]["genesis_value"])
        write_json(inventory_path, inventory)
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "unsupported until issue #656",
        ):
            checker.validate_inventory(root, inventory_path)

    def test_candidate_incomplete_state_is_exact(self) -> None:
        self._validate_mutation(
            lambda value: value["candidate_binding"].__setitem__(
                "candidate_id",
                "candidate-mainnet-v1",
            ),
            "does not satisfy.*schema",
        )
        self._validate_mutation(
            lambda value: value["candidate_binding"].__setitem__(
                "blocked_by_issue",
                None,
            ),
            "does not satisfy.*schema",
        )

    def test_unknown_keys_duplicate_keys_and_status_drift_are_rejected(self) -> None:
        self._validate_mutation(
            lambda value: value["parameters"][0].__setitem__("extra", True),
            "does not satisfy.*schema",
        )
        self._validate_mutation(
            lambda value: value.__setitem__("status", "complete"),
            "inventory.status must be 'planning'",
        )
        text = INVENTORY_PATH.read_text(encoding="utf-8").replace(
            '"status": "planning"',
            '"status": "planning",\n  "status": "planning"',
            1,
        )
        temporary, root, path, _ = self._fixture_root()
        self.addCleanup(temporary.cleanup)
        path.write_text(text, encoding="utf-8")
        with self.assertRaisesRegex(
            checker.GovernedParameterInventoryError,
            "duplicate JSON key",
        ):
            checker.validate_inventory(root, path)


if __name__ == "__main__":
    unittest.main()

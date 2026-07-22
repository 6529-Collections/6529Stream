#!/usr/bin/env python3
"""Focused tests for the canonical genesis deployment profile checker."""

from __future__ import annotations

import copy
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path

import check_genesis_deployment_profile as checker

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
PROFILE_PATH = REPO_ROOT / checker.DEFAULT_PROFILE
CONTRACTS_PATH = REPO_ROOT / checker.DEFAULT_CONTRACTS
SCHEMA_PATH = REPO_ROOT / "release-artifacts/schema/genesis-deployment-profile.schema.json"


def load_json(path: Path) -> object:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def copy_normative_documents(root: Path) -> None:
    for relative in (
        Path(checker.NORMATIVE_SOURCE),
        checker.GGP_INVENTORY_SOURCE,
        checker.GTP_MIRROR_SOURCE,
    ):
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text((REPO_ROOT / relative).read_text(encoding="utf-8"), encoding="utf-8", newline="\n")


def candidate_config(candidates: list[dict[str, object]]) -> dict[str, object]:
    return {
        "schema_version": checker.CONTRACTS_SCHEMA,
        "production_contracts": sorted(candidates, key=lambda candidate: str(candidate["name"])),
    }


def complete_fixture(profile: dict[str, object]) -> tuple[dict[str, object], dict[str, object]]:
    """Build an exact synthetic candidate without blessing real aliases."""
    completed = copy.deepcopy(profile)
    entries = completed["entries"]
    assert isinstance(entries, list)
    candidates: list[dict[str, object]] = []
    for entry in entries:
        assert isinstance(entry, dict)
        entry_id = entry["id"]
        name = f"FixtureGenesisEntry{entry_id:02d}"
        aliases = entry["approved_aliases"]
        assert isinstance(aliases, list)
        aliases.append(name)
        candidates.append(
            {
                "name": name,
                "source": f"smart-contracts/fixtures/Entry{entry_id}.sol",
                "deployment_scope": entry["deployment_scope"],
                "verified_interfaces": list(entry["required_interfaces"]),
                "verified_markers": list(entry["required_markers"]),
            }
        )
    return completed, candidate_config(candidates)


class GenesisDeploymentProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.profile = load_json(PROFILE_PATH)
        cls.contracts = load_json(CONTRACTS_PATH)

    def test_committed_profile_is_structurally_valid_and_count_is_derived(self) -> None:
        profile = copy.deepcopy(self.profile)
        self.assertNotIn("total", profile)
        self.assertNotIn("entry_count", profile)
        entries = checker.validate_profile_document(profile)
        expected_count = (
            len(checker.FIXED_CONTRACT_KEYS) + len(checker.GGP_PARAMETERS) + 1
        )
        self.assertEqual(len(entries), expected_count)
        self.assertEqual([entry["id"] for entry in entries], list(range(1, len(entries) + 1)))
        checker.validate_document_mirrors(entries, REPO_ROOT)

    def test_json_schema_matches_version_and_forbids_independent_total(self) -> None:
        schema = load_json(SCHEMA_PATH)
        self.assertEqual(
            schema["properties"]["schema_version"]["const"], checker.PROFILE_SCHEMA
        )
        self.assertFalse(schema["additionalProperties"])
        self.assertNotIn("total", schema["properties"])
        self.assertNotIn("entry_count", schema["properties"])

    def test_json_schema_semantic_conditionals_match_checker_rules(self) -> None:
        schema = load_json(SCHEMA_PATH)
        conditionals = schema["$defs"]["entry"]["allOf"]

        kind_rules = {
            rule["if"]["properties"]["kind"]["const"]: rule["then"]["properties"]
            for rule in conditionals
            if "kind" in rule["if"]["properties"]
        }
        self.assertEqual(set(kind_rules), {"contract", "ggp_probe", "gtp_probe"})
        self.assertEqual(
            set(kind_rules["contract"]["implementation"]["properties"]["mode"]["enum"]),
            {
                "exact",
                "one_of",
                "manifest_equivalent",
                "distinct_instance",
                "role_bound",
            },
        )
        self.assertEqual(kind_rules["contract"]["parameters"]["maxItems"], 0)
        self.assertEqual(
            kind_rules["ggp_probe"]["implementation"]["properties"]["mode"]["const"],
            "parameter_bound",
        )
        self.assertEqual(
            kind_rules["ggp_probe"]["implementation"]["properties"]["names"]["maxItems"],
            0,
        )
        self.assertEqual(
            (
                kind_rules["ggp_probe"]["parameters"]["minItems"],
                kind_rules["ggp_probe"]["parameters"]["maxItems"],
            ),
            (1, 1),
        )
        self.assertEqual(
            kind_rules["gtp_probe"]["implementation"]["properties"]["mode"]["const"],
            "shared_parameter_bound",
        )
        self.assertEqual(
            (
                kind_rules["gtp_probe"]["parameters"]["minItems"],
                kind_rules["gtp_probe"]["parameters"]["maxItems"],
            ),
            (3, 3),
        )

        mode_rules = {}
        for rule in conditionals:
            implementation = rule["if"]["properties"].get("implementation")
            if implementation is None:
                continue
            modes = implementation["properties"]["mode"].get("enum")
            if modes is not None:
                mode_rules[frozenset(modes)] = rule["then"]["properties"][
                    "implementation"
                ]["properties"]["names"]
        self.assertEqual(
            mode_rules[
                frozenset(
                    {"exact", "one_of", "distinct_instance", "shared_parameter_bound"}
                )
            ]["minItems"],
            1,
        )
        self.assertEqual(
            mode_rules[
                frozenset({"manifest_equivalent", "role_bound", "parameter_bound"})
            ]["maxItems"],
            0,
        )

    def test_numbering_gap_duplicate_and_reordering_fail(self) -> None:
        for mutation in ("gap", "duplicate", "reorder"):
            with self.subTest(mutation=mutation):
                profile = copy.deepcopy(self.profile)
                entries = profile["entries"]
                if mutation == "gap":
                    entries.pop(10)
                elif mutation == "duplicate":
                    entries[10]["id"] = entries[9]["id"]
                else:
                    entries[9], entries[10] = entries[10], entries[9]
                with self.assertRaisesRegex(checker.GenesisProfileError, "contiguous"):
                    checker.validate_profile_document(profile)

    def test_forbidden_independent_total_fails_closed(self) -> None:
        profile = copy.deepcopy(self.profile)
        profile["total"] = (
            len(checker.FIXED_CONTRACT_KEYS) + len(checker.GGP_PARAMETERS) + 1
        )
        with self.assertRaisesRegex(checker.GenesisProfileError, "unsupported fields: total"):
            checker.validate_profile_document(profile)

    def test_exact_ggp_probe_inventory_includes_newest_rows(self) -> None:
        entries = checker.validate_profile_document(copy.deepcopy(self.profile))
        parameters = tuple(entry["parameters"][0] for entry in entries[35:57])
        self.assertEqual(parameters, checker.GGP_PARAMETERS)
        self.assertIn("REVEAL_ATTEMPT_GAS_LIMIT", parameters)
        self.assertIn("SALE_NFT_DELIVERY_GAS_LIMIT", parameters)

    def test_shared_cadence_probe_serves_exact_gtp_inventory(self) -> None:
        entries = checker.validate_profile_document(copy.deepcopy(self.profile))
        cadence = entries[-1]
        self.assertEqual(cadence["kind"], "gtp_probe")
        self.assertEqual(tuple(cadence["parameters"]), checker.GTP_PARAMETERS)
        self.assertEqual(cadence["multiplicity"], {"minimum": 1, "maximum": 1})

    def test_governance_and_provider_disjunctions_are_pinned(self) -> None:
        entries = checker.validate_profile_document(copy.deepcopy(self.profile))
        self.assertEqual(entries[1]["implementation"]["mode"], "manifest_equivalent")
        self.assertEqual(entries[1]["approved_aliases"], [])
        self.assertEqual(entries[31]["implementation"]["mode"], "one_of")
        self.assertEqual(
            entries[31]["implementation"]["names"],
            ["StreamEntropyProviderARRNG", "StreamEntropyProviderPyth"],
        )
        self.assertEqual(entries[19]["implementation"]["mode"], "role_bound")
        self.assertEqual(entries[19]["implementation"]["names"], [])

        profile = copy.deepcopy(self.profile)
        profile["entries"][1]["implementation"]["names"] = ["StreamAdmins"]
        with self.assertRaisesRegex(checker.GenesisProfileError, "must be empty"):
            checker.validate_profile_document(profile)

    def test_document_mirror_rejects_requirement_drift(self) -> None:
        entries = checker.validate_profile_document(copy.deepcopy(self.profile))
        entries[0]["requirement"] = "RenamedCoreWithoutSpecAmendment"
        with self.assertRaisesRegex(checker.GenesisProfileError, "is not mirrored"):
            checker.validate_document_mirrors(entries, REPO_ROOT)

    def test_document_mirror_reports_missing_parser_markers(self) -> None:
        entries = checker.validate_profile_document(copy.deepcopy(self.profile))
        cases = (
            (
                Path(checker.NORMATIVE_SOURCE),
                checker.LCM_GENESIS_HEADING,
                "LCM-GENESIS section heading",
            ),
            (
                checker.GGP_INVENTORY_SOURCE,
                checker.GGP_INVENTORY_LABEL,
                "GGP inventory label",
            ),
            (
                checker.GTP_MIRROR_SOURCE,
                checker.TARGET_PARAMETER_SECTION_HEADING,
                "target parameter mirror section heading",
            ),
            (
                checker.GTP_MIRROR_SOURCE,
                checker.TARGET_PARAMETER_TABLE_END,
                "target parameter table end heading",
            ),
        )
        for relative, marker, diagnostic in cases:
            with self.subTest(source=str(relative), marker=marker):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    copy_normative_documents(root)
                    target = root / relative
                    target.write_text(
                        target.read_text(encoding="utf-8").replace(
                            marker, "REMOVED_PARSER_MARKER", 1
                        ),
                        encoding="utf-8",
                        newline="\n",
                    )
                    with self.assertRaisesRegex(checker.GenesisProfileError, diagnostic):
                        checker.validate_document_mirrors(entries, root)

    def test_fallbacks_and_split_wallet_scope_are_distinct(self) -> None:
        entries = checker.validate_profile_document(copy.deepcopy(self.profile))
        self.assertEqual(entries[33]["deployment_scope"], "fallback_instance")
        self.assertEqual(entries[33]["distinct_from"], [30])
        self.assertEqual(entries[34]["deployment_scope"], "fallback_instance")
        self.assertEqual(entries[34]["distinct_from"], [11])
        self.assertEqual(entries[5]["deployment_scope"], "implementation")
        self.assertEqual(
            self.profile["factory_spawned_exclusions"][0]["implementation_entry_id"], 6
        )

    def test_duplicate_approved_alias_fails_even_when_candidate_does_not_use_it(self) -> None:
        profile = copy.deepcopy(self.profile)
        profile["entries"][0]["approved_aliases"].append("ReviewedButAmbiguousAlias")
        profile["entries"][1]["approved_aliases"].append("ReviewedButAmbiguousAlias")
        with self.assertRaisesRegex(checker.GenesisProfileError, "alias"):
            checker.validate_profile_document(profile)

    def test_malformed_probe_kind_raises_profile_error(self) -> None:
        profile = copy.deepcopy(self.profile)
        probe = profile["entries"][len(checker.FIXED_CONTRACT_KEYS)]
        probe["kind"] = "contract"
        probe["deployment_scope"] = "singleton"
        probe["implementation"] = {"mode": "role_bound", "names": []}
        probe["parameters"] = []
        with self.assertRaises(checker.GenesisProfileError):
            checker.validate_profile_document(profile)

    def test_committed_candidate_is_explicitly_incomplete(self) -> None:
        audit = checker.audit_profile(checker.DEFAULT_PROFILE, checker.DEFAULT_CONTRACTS, REPO_ROOT)
        self.assertEqual(
            audit.entry_count,
            len(checker.FIXED_CONTRACT_KEYS) + len(checker.GGP_PARAMETERS) + 1,
        )
        self.assertGreater(len(audit.blockers), 0)
        joined = "\n".join(audit.blockers)
        self.assertIn("StreamMintManager", joined)
        self.assertIn("StreamSplitWallet", joined)
        self.assertIn("expected 'implementation'", joined)
        self.assertIn("SHARED_ENTROPY_CADENCE_PROBE", joined)

    def test_synthesized_exact_candidate_passes(self) -> None:
        profile, contracts = complete_fixture(copy.deepcopy(self.profile))
        entries = checker.validate_profile_document(profile)
        candidates = checker.validate_contract_config(contracts)
        self.assertEqual(checker.completeness_blockers(entries, candidates), [])

    def test_missing_and_extra_candidates_fail(self) -> None:
        profile, contracts = complete_fixture(copy.deepcopy(self.profile))
        entries = checker.validate_profile_document(profile)
        candidates = checker.validate_contract_config(contracts)
        missing = candidates[:-1]
        self.assertTrue(
            any("SHARED_ENTROPY_CADENCE_PROBE" in blocker for blocker in checker.completeness_blockers(entries, missing))
        )
        extra = candidates + [
            {
                "name": "UnapprovedExtra",
                "source": "smart-contracts/fixtures/Extra.sol",
                "deployment_scope": "singleton",
                "verified_interfaces": [],
                "verified_markers": [],
            }
        ]
        self.assertTrue(
            any("extra or has no reviewed profile alias" in blocker for blocker in checker.completeness_blockers(entries, extra))
        )

    def test_duplicate_and_ambiguous_satisfaction_fail(self) -> None:
        profile, contracts = complete_fixture(copy.deepcopy(self.profile))
        entries = checker.validate_profile_document(profile)
        candidates = checker.validate_contract_config(contracts)
        duplicate_name = "FixtureDuplicateEntry01"
        entries[0]["approved_aliases"].append(duplicate_name)
        duplicate = candidates + [
            {
                "name": duplicate_name,
                "source": "smart-contracts/fixtures/Duplicate.sol",
                "deployment_scope": entries[0]["deployment_scope"],
                "verified_interfaces": entries[0]["required_interfaces"],
                "verified_markers": entries[0]["required_markers"],
            }
        ]
        self.assertTrue(
            any("satisfied more than once" in blocker for blocker in checker.completeness_blockers(entries, duplicate))
        )

        ambiguous_profile, ambiguous_contracts = complete_fixture(copy.deepcopy(self.profile))
        ambiguous_entries = checker.validate_profile_document(ambiguous_profile)
        shared_alias = "FixtureGenesisEntry01"
        ambiguous_entries[1]["approved_aliases"].append(shared_alias)
        ambiguous_candidates = checker.validate_contract_config(ambiguous_contracts)
        self.assertTrue(
            any("ambiguously matches" in blocker for blocker in checker.completeness_blockers(ambiguous_entries, ambiguous_candidates))
        )

    def test_wrong_scope_interface_and_marker_fail(self) -> None:
        profile, contracts = complete_fixture(copy.deepcopy(self.profile))
        entries = checker.validate_profile_document(profile)
        candidates = checker.validate_contract_config(contracts)
        candidates[0]["deployment_scope"] = "fallback_instance"
        candidates[1]["verified_interfaces"] = []
        candidates[1]["verified_markers"] = []
        blockers = "\n".join(checker.completeness_blockers(entries, candidates))
        self.assertIn("deployment_scope", blockers)
        self.assertIn("lacks verified interfaces", blockers)
        self.assertIn("lacks verified markers", blockers)

    def test_unreviewed_legacy_alias_does_not_satisfy_target(self) -> None:
        entries = checker.validate_profile_document(copy.deepcopy(self.profile))
        candidates = checker.validate_contract_config(
            candidate_config(
                [
                    {
                        "name": "StreamAdmins",
                        "source": "smart-contracts/StreamAdmins.sol",
                        "deployment_scope": "singleton",
                    }
                ]
            )
        )
        blockers = "\n".join(checker.completeness_blockers(entries, candidates))
        self.assertIn("no reviewed profile alias", blockers)
        self.assertIn("GOVERNANCE_LAYER", blockers)

    def test_cli_default_passes_but_strict_mode_fails_current_candidate(self) -> None:
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            default_result = checker.main(["--repo-root", str(REPO_ROOT)])
            strict_result = checker.main(
                ["--repo-root", str(REPO_ROOT), "--require-complete"]
            )
        self.assertEqual(default_result, 0)
        self.assertEqual(strict_result, 1)

    def test_cli_strict_mode_rejects_v1_catalog_without_concrete_candidate_model(self) -> None:
        profile, contracts = complete_fixture(copy.deepcopy(self.profile))
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_json(root / checker.DEFAULT_PROFILE, profile)
            write_json(root / checker.DEFAULT_CONTRACTS, contracts)
            copy_normative_documents(root)
            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = checker.main(
                    ["--repo-root", str(root), "--require-complete"]
                )
        self.assertEqual(result, 1)
        self.assertIn(checker.CONCRETE_CANDIDATE_MODEL_BLOCKER, stderr.getvalue())


if __name__ == "__main__":
    unittest.main()

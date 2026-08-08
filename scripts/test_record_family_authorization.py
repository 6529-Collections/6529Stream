#!/usr/bin/env python3
"""Hostile regressions for check_record_family_authorization.py."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Any, Callable

import check_record_family_authorization as checker


ROOT = Path(__file__).resolve().parents[1]


def _read(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    assert isinstance(value, dict)
    return value


def _write(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class RecordFamilyAuthorizationTests(unittest.TestCase):
    def _fixture(self) -> tuple[tempfile.TemporaryDirectory[str], Path]:
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        inventory = _read(ROOT / checker.DEFAULT_INVENTORY)
        source_catalog = _read(ROOT / checker.DEFAULT_SOURCE_CATALOG)
        required: set[Path] = {
            checker.DEFAULT_INVENTORY,
            checker.DEFAULT_INVENTORY_SCHEMA,
            checker.DEFAULT_SOURCE_CATALOG,
            checker.DEFAULT_SOURCE_CATALOG_SCHEMA,
            checker.DEFAULT_EVIDENCE_TEMPLATE,
            checker.DEFAULT_EVIDENCE_SCHEMA,
            checker.DEFAULT_GRANT_MAP_SCHEMA,
            Path("release-artifacts/genesis-deployment-profile.json"),
        }
        required.update(Path(row["path"]) for row in inventory["normative_sources"])
        current = inventory["current_implementation"]
        for row in current["contracts"]:
            required.add(Path(row["source_path"]))
            required.add(Path(row["interface_path"]))
        for row in current["known_fail_open_behaviors"]:
            required.add(Path(row["source_path"]))
        for row in source_catalog["source_bindings"]:
            required.add(Path(row["path"]))
        for relative in source_catalog["source_tests"]:
            required.add(Path(relative))
        for relative in sorted(required):
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        return temporary, root

    def _complete_evidence_fixture(
        self,
        target_phase: str = "public_beta",
    ) -> tuple[
        tempfile.TemporaryDirectory[str],
        Path,
        dict[str, Any],
        Path,
        dict[str, Any],
    ]:
        temporary, root = self._fixture()
        inventory_path = root / checker.DEFAULT_INVENTORY
        inventory = _read(inventory_path)
        source_catalog_path = (
            root / "release-artifacts/record-family-authorization-source-catalog.json"
        )
        source_catalog = _read(source_catalog_path)
        evidence = _read(root / checker.DEFAULT_EVIDENCE_TEMPLATE)
        evidence_relative = next(
            Path(row["path"])
            for row in inventory["retained_evidence"]
            if row["phase"] == target_phase
        )
        evidence_path = root / evidence_relative
        profile_path = root / "release-artifacts/genesis-deployment-profile.json"
        candidate_path = (
            root
            / "deployments/record-family-authorization/mainnet-candidate-identity.json"
        )
        grant_path = root / checker.EXPECTED_GRANT_MAP_PATHS[target_phase]
        candidate_sha = "11" * 32
        candidate = {
            "status": "complete",
            "candidate_id": "mainnet-record-family-v1",
            "candidate_identity_sha256": candidate_sha,
            "candidate_identity_keccak256": "0x" + "22" * 32,
            "candidate_identity_path": candidate_path.relative_to(root).as_posix(),
            "source_commit": "a" * 40,
            "release_build": "mainnet-release-v1",
            "genesis_profile_sha256": _sha256(profile_path),
        }
        _write(
            candidate_path,
            {
                "schema_version": "6529stream.genesis-deployment-candidate-identity.v1",
                "candidate_id": candidate["candidate_id"],
                "candidate_identity_sha256": candidate_sha,
                "candidate_identity_keccak256": candidate[
                    "candidate_identity_keccak256"
                ],
                "source_commit": candidate["source_commit"],
                "release_build": candidate["release_build"],
                "genesis_profile_sha256": candidate["genesis_profile_sha256"],
            },
        )

        review = {
            "reviewer": "independent-reviewer",
            "reviewed_at": "2026-07-24T00:00:00Z",
            "reference": "https://review.example/record-family-authorization-v1",
        }
        classifier = {
            "status": "complete",
            "host_address": "0x" + "31" * 20,
            "contract_address": "0x" + "31" * 20,
            "module_type": "0x" + "33" * 32,
            "interface_id": source_catalog["classifier"]["interface_id"],
            "marker": source_catalog["classifier"]["marker_selector"],
            "schema": "0x" + "36" * 32,
            "revision": source_catalog["classifier"]["schema_version"],
            "configuration_revision": 13,
            "configuration_hash": "0x" + "63" * 32,
            "configuration_authority": "0x" + "45" * 20,
            "pending_configuration_authority": "0x" + "00" * 20,
            "pending_configuration_authority_disposition": None,
            "record_type_count": 14,
            "observed_chain_id": 1,
            "observed_block_number": 19_000_000,
            "observed_block_hash": "0x" + "42" * 32,
            "observed_block_finalized": True,
            "runtime_codehash": "0x" + "43" * 32,
            "grant_map_sha256": None,
        }
        implementation_rows = [
            {
                "contract": "StreamCollectionMetadata",
                "source_path": "smart-contracts/domains/metadata/StreamCollectionMetadata.sol",
                "source_sha256": _sha256(
                    root / "smart-contracts/domains/metadata/StreamCollectionMetadata.sol"
                ),
                "interface_path": "smart-contracts/interfaces/stream/IStreamCollectionMetadata.sol",
                "interface_sha256": _sha256(
                    root / "smart-contracts/interfaces/stream/IStreamCollectionMetadata.sol"
                ),
                "address": classifier["host_address"],
                "record_family_registry": classifier["host_address"],
                "configuration_authority": classifier["configuration_authority"],
                "pending_configuration_authority": classifier[
                    "pending_configuration_authority"
                ],
                "configuration_revision": classifier["configuration_revision"],
                "configuration_hash": classifier["configuration_hash"],
                "record_type_count": classifier["record_type_count"],
                "observed_chain_id": classifier["observed_chain_id"],
                "observed_block_number": classifier["observed_block_number"],
                "observed_block_hash": classifier["observed_block_hash"],
                "observed_block_finalized": classifier[
                    "observed_block_finalized"
                ],
                "runtime_sha256": "42" * 32,
                "runtime_keccak256": classifier["runtime_codehash"],
                "interface_ids": [
                    source_catalog["host_bindings"][0]["interface_id"],
                    source_catalog["classifier"]["interface_id"],
                ],
                "marker": "STREAM_COLLECTION_METADATA",
                "revision": classifier["revision"],
            },
            {
                "contract": "StreamPreservationRecords",
                "source_path": "smart-contracts/domains/preservation/StreamPreservationRecords.sol",
                "source_sha256": _sha256(
                    root / "smart-contracts/domains/preservation/StreamPreservationRecords.sol"
                ),
                "interface_path": "smart-contracts/interfaces/stream/IStreamPreservationRecords.sol",
                "interface_sha256": _sha256(
                    root / "smart-contracts/interfaces/stream/IStreamPreservationRecords.sol"
                ),
                "address": "0x" + "51" * 20,
                "record_family_registry": classifier["host_address"],
                "configuration_authority": classifier["configuration_authority"],
                "pending_configuration_authority": classifier[
                    "pending_configuration_authority"
                ],
                "configuration_revision": classifier["configuration_revision"],
                "configuration_hash": classifier["configuration_hash"],
                "record_type_count": classifier["record_type_count"],
                "observed_chain_id": classifier["observed_chain_id"],
                "observed_block_number": classifier["observed_block_number"],
                "observed_block_hash": classifier["observed_block_hash"],
                "observed_block_finalized": classifier[
                    "observed_block_finalized"
                ],
                "runtime_sha256": "52" * 32,
                "runtime_keccak256": "0x" + "53" * 32,
                "interface_ids": [source_catalog["host_bindings"][1]["interface_id"]],
                "marker": "STREAM_PRESERVATION_RECORDS",
                "revision": 1,
            },
        ]
        class_rows = []
        for index, name in enumerate(checker.EXPECTED_AUTHORIZATION_CLASSES):
            catalog_row = source_catalog["authorization_classes"][index]
            class_rows.append(
                {
                    "name": name,
                    "authorization_class_id": catalog_row["id"],
                    "mode": catalog_row["mode"],
                }
            )
        authority_provider_rows = [
            {
                "authorization_class_id": row["id"],
                "provider": f"0x{row['id'] + 301:040x}",
                "runtime_codehash": f"0x{row['id'] + 401:064x}",
                "revision": 1,
            }
            for row in source_catalog["authorization_classes"]
            if row["mode"] == "live_provider"
        ]
        class_modes = {row["id"]: row["mode"] for row in source_catalog["authorization_classes"]}
        family_rows = []
        for index, (name, patterns) in enumerate(checker.EXPECTED_FAMILY_GROUPS):
            catalog_row = source_catalog["family_groups"][index]
            admission_class_ids = list(
                catalog_row["allowed_authorization_class_ids"]
            )
            family_rows.append(
                {
                    "name": name,
                    "normative_patterns": list(patterns),
                    "family_id": catalog_row["id"],
                    "allowed_authorization_class_ids": list(admission_class_ids),
                    "record_type_admissions": [
                        {
                            "record_type_id": f"0x{index + 101:064x}",
                            "authorization_class_ids": list(admission_class_ids),
                            "lock_allowed": name != "INDEPENDENT",
                        }
                    ],
                    "grants": [
                        {
                            "authorization_class_id": class_id,
                            "account": f"0x{index * 10 + class_id + 501:040x}",
                            "revision": 1,
                        }
                        for class_id in admission_class_ids
                        if class_modes[class_id] == "family_grant"
                    ],
                }
            )
        grant_document = {
            "schema_version": checker.GRANT_MAP_SCHEMA_VERSION,
            "target_phase": target_phase,
            "source_catalog_binding": {
                "path": source_catalog_path.relative_to(root).as_posix(),
                "schema_version": source_catalog["schema_version"],
                "sha256": _sha256(source_catalog_path),
            },
            "candidate_binding": {
                key: candidate[key]
                for key in (
                    "candidate_id",
                    "candidate_identity_sha256",
                    "candidate_identity_keccak256",
                    "source_commit",
                    "release_build",
                    "genesis_profile_sha256",
                )
            },
            "classifier_binding": {
                key: classifier[key]
                for key in (
                    "host_address",
                    "contract_address",
                    "module_type",
                    "interface_id",
                    "marker",
                    "schema",
                    "revision",
                    "configuration_revision",
                    "configuration_hash",
                    "configuration_authority",
                    "pending_configuration_authority",
                    "pending_configuration_authority_disposition",
                    "record_type_count",
                    "observed_chain_id",
                    "observed_block_number",
                    "observed_block_hash",
                    "observed_block_finalized",
                    "runtime_codehash",
                )
            },
            "authorization_classes": class_rows,
            "authority_providers": authority_provider_rows,
            "family_groups": family_rows,
            "implementation_bindings": implementation_rows,
            "independent_review": {"status": "reviewed", **review},
        }
        _write(grant_path, grant_document)
        grant_sha = _sha256(grant_path)
        classifier["grant_map_sha256"] = grant_sha

        implementation_evidence: list[dict[str, Any]] = []
        support_paths: dict[str, Path] = {}
        for index, row in enumerate(implementation_rows):
            support_path = (
                root
                / "deployments/record-family-authorization"
                / f"implementation-{index + 1}-support.json"
            )
            support_paths[f"implementation_{index}"] = support_path
            support = {
                "schema_version": "6529stream.record-family-authorization-support.v1",
                "artifact_type": "implementation_binding",
                "target_phase": target_phase,
                "candidate_identity_sha256": candidate_sha,
                "grant_map_sha256": grant_sha,
                **{
                    key: row[key]
                    for key in (
                        "contract",
                        "source_path",
                        "source_sha256",
                        "interface_path",
                        "interface_sha256",
                        "address",
                        "record_family_registry",
                        "configuration_authority",
                        "pending_configuration_authority",
                        "configuration_revision",
                        "configuration_hash",
                        "record_type_count",
                        "observed_chain_id",
                        "observed_block_number",
                        "observed_block_hash",
                        "observed_block_finalized",
                        "runtime_sha256",
                        "runtime_keccak256",
                        "interface_ids",
                        "marker",
                        "revision",
                    )
                },
            }
            _write(support_path, support)
            implementation_evidence.append(
                {
                    **{
                        key: row[key]
                        for key in (
                            "contract",
                            "source_path",
                            "source_sha256",
                            "interface_path",
                            "interface_sha256",
                            "address",
                            "record_family_registry",
                            "configuration_authority",
                            "pending_configuration_authority",
                            "configuration_revision",
                            "configuration_hash",
                            "record_type_count",
                            "observed_chain_id",
                            "observed_block_number",
                            "observed_block_hash",
                            "observed_block_finalized",
                            "runtime_sha256",
                            "runtime_keccak256",
                            "interface_ids",
                            "marker",
                            "revision",
                        )
                    },
                    "evidence_path": support_path.relative_to(root).as_posix(),
                    "evidence_sha256": _sha256(support_path),
                }
            )

        expected_groups = [name for name, _ in checker.EXPECTED_FAMILY_GROUPS]
        snapshot_path = (
            root
            / "deployments/record-family-authorization/snapshot-intersection-support.json"
        )
        support_paths["snapshot"] = snapshot_path
        _write(
            snapshot_path,
            {
                "schema_version": "6529stream.record-family-authorization-support.v1",
                "artifact_type": "snapshot_intersection",
                "target_phase": target_phase,
                "candidate_identity_sha256": candidate_sha,
                "grant_map_sha256": grant_sha,
                "covered_family_groups": expected_groups,
            },
        )
        lifecycle_path = (
            root
            / "deployments/record-family-authorization/authority-lifecycle-support.json"
        )
        support_paths["lifecycle"] = lifecycle_path
        _write(
            lifecycle_path,
            {
                "schema_version": "6529stream.record-family-authorization-support.v1",
                "artifact_type": "authority_lifecycle",
                "target_phase": target_phase,
                "candidate_identity_sha256": candidate_sha,
                "grant_map_sha256": grant_sha,
                "rotation_revision": 1,
                "revocation_revision": 1,
                "proposal_old_authority": "0x" + "44" * 20,
                "proposed_authority": "0x" + "45" * 20,
                "proposal_configuration_revision": 10,
                "proposal_configuration_hash": "0x" + "61" * 32,
                "acceptance_old_authority": "0x" + "44" * 20,
                "accepted_authority": "0x" + "45" * 20,
                "acceptance_configuration_revision": 11,
                "acceptance_configuration_hash": "0x" + "62" * 32,
                "cancellation_authority": "0x" + "45" * 20,
                "cancelled_pending_authority": "0x" + "46" * 20,
                "cancellation_configuration_revision": 13,
                "cancellation_configuration_hash": "0x" + "63" * 32,
                "record_family_registry": classifier["host_address"],
                "observed_chain_id": classifier["observed_chain_id"],
                "observed_block_number": classifier["observed_block_number"],
                "observed_block_hash": classifier["observed_block_hash"],
                "observed_block_finalized": classifier["observed_block_finalized"],
                "observed_configuration_authority": classifier[
                    "configuration_authority"
                ],
                "observed_pending_configuration_authority": classifier[
                    "pending_configuration_authority"
                ],
                "observed_configuration_revision": classifier[
                    "configuration_revision"
                ],
                "observed_configuration_hash": classifier["configuration_hash"],
                "commitment_linkage_status": "reviewed",
                "commitment_linkage_reference": (
                    "https://review.example/authority-commitment-linkage-v1"
                ),
                "observed_at_commit": candidate["source_commit"],
            },
        )
        phases: list[dict[str, Any]] = []
        for phase in ("public_beta", "production_release"):
            if target_phase == "public_beta" and phase == "production_release":
                phases.append(
                    {
                        "phase": phase,
                        "status": "missing",
                        "review_status": "unreviewed",
                        "evidence_path": None,
                        "evidence_sha256": None,
                    }
                )
                continue
            phase_path = (
                root
                / "deployments/record-family-authorization"
                / f"{phase}-phase-support.json"
            )
            support_paths[f"phase_{phase}"] = phase_path
            _write(
                phase_path,
                {
                    "schema_version": "6529stream.record-family-authorization-support.v1",
                    "artifact_type": "phase_support",
                    "target_phase": target_phase,
                    "candidate_identity_sha256": candidate_sha,
                    "grant_map_sha256": grant_sha,
                    "phase": phase,
                    "status": "complete",
                },
            )
            phases.append(
                {
                    "phase": phase,
                    "status": "complete",
                    "review_status": "reviewed",
                    "evidence_path": phase_path.relative_to(root).as_posix(),
                    "evidence_sha256": _sha256(phase_path),
                }
            )

        evidence.update(
            {
                "record_type": "retained_evidence",
                "review_status": "reviewed",
                "evidence_id": (
                    "record-family-authorization-public-beta-v1"
                    if target_phase == "public_beta"
                    else "record-family-authorization-production-release-v1"
                ),
                "target_phase": target_phase,
                "inventory_binding": {
                    "status": "complete",
                    "path": checker.DEFAULT_INVENTORY.as_posix(),
                    "schema_version": checker.INVENTORY_SCHEMA_VERSION,
                    "sha256": _sha256(inventory_path),
                },
                "candidate_binding": candidate,
                "profile_binding": {
                    "status": "complete",
                    "path": "release-artifacts/genesis-deployment-profile.json",
                    "schema_version": "6529stream.genesis-deployment-profile.v2",
                    "sha256": _sha256(profile_path),
                },
                "classifier_binding": classifier,
                "implementation_bindings": {
                    "status": "complete",
                    "review_status": "reviewed",
                    "contracts": implementation_evidence,
                },
                "grant_map": {
                    "status": "complete",
                    "review_status": "reviewed",
                    "path": grant_path.relative_to(root).as_posix(),
                    "schema_path": checker.DEFAULT_GRANT_MAP_SCHEMA.as_posix(),
                    "schema_version": checker.GRANT_MAP_SCHEMA_VERSION,
                    "sha256": grant_sha,
                    "family_group_count": 14,
                    "authorization_class_count": 8,
                    "candidate_identity_sha256": candidate_sha,
                },
                "snapshot_intersection": {
                    "status": "complete",
                    "review_status": "reviewed",
                    "covered_family_groups": expected_groups,
                    "evidence_path": snapshot_path.relative_to(root).as_posix(),
                    "evidence_sha256": _sha256(snapshot_path),
                },
                "authority_lifecycle": {
                    "status": "complete",
                    "review_status": "reviewed",
                    "rotation_revision": 1,
                    "revocation_revision": 1,
                    "proposal_old_authority": "0x" + "44" * 20,
                    "proposed_authority": "0x" + "45" * 20,
                    "proposal_configuration_revision": 10,
                    "proposal_configuration_hash": "0x" + "61" * 32,
                    "acceptance_old_authority": "0x" + "44" * 20,
                    "accepted_authority": "0x" + "45" * 20,
                    "acceptance_configuration_revision": 11,
                    "acceptance_configuration_hash": "0x" + "62" * 32,
                    "cancellation_authority": "0x" + "45" * 20,
                    "cancelled_pending_authority": "0x" + "46" * 20,
                    "cancellation_configuration_revision": 13,
                    "cancellation_configuration_hash": "0x" + "63" * 32,
                    "record_family_registry": classifier["host_address"],
                    "observed_chain_id": classifier["observed_chain_id"],
                    "observed_block_number": classifier["observed_block_number"],
                    "observed_block_hash": classifier["observed_block_hash"],
                    "observed_block_finalized": classifier[
                        "observed_block_finalized"
                    ],
                    "observed_configuration_authority": classifier[
                        "configuration_authority"
                    ],
                    "observed_pending_configuration_authority": classifier[
                        "pending_configuration_authority"
                    ],
                    "observed_configuration_revision": classifier[
                        "configuration_revision"
                    ],
                    "observed_configuration_hash": classifier[
                        "configuration_hash"
                    ],
                    "commitment_linkage_status": "reviewed",
                    "commitment_linkage_reference": (
                        "https://review.example/authority-commitment-linkage-v1"
                    ),
                    "observed_at_commit": candidate["source_commit"],
                    "evidence_path": lifecycle_path.relative_to(root).as_posix(),
                    "evidence_sha256": _sha256(lifecycle_path),
                },
                "phases": phases,
                "review": review,
                "template_notice": (
                    "Retained evidence does not by itself satisfy public-beta or "
                    "production release mode; family-scoped implementation enforcement "
                    "and the hard release stop must be independently cleared."
                ),
            }
        )
        predecessor_path: Path | None = None
        predecessor_grant_path: Path | None = None
        if target_phase == "production_release":
            predecessor_path = root / next(
                row["path"]
                for row in inventory["retained_evidence"]
                if row["phase"] == "public_beta"
            )
            predecessor_grant_path = (
                root / checker.EXPECTED_GRANT_MAP_PATHS["public_beta"]
            )
            predecessor_grant = copy.deepcopy(grant_document)
            predecessor_grant["target_phase"] = "public_beta"
            _write(predecessor_grant_path, predecessor_grant)
            predecessor_grant_sha = _sha256(predecessor_grant_path)

            predecessor = copy.deepcopy(evidence)
            predecessor["evidence_id"] = (
                "record-family-authorization-public-beta-v1"
            )
            predecessor["target_phase"] = "public_beta"
            predecessor["classifier_binding"][
                "grant_map_sha256"
            ] = predecessor_grant_sha
            predecessor["grant_map"].update(
                {
                    "path": predecessor_grant_path.relative_to(root).as_posix(),
                    "sha256": predecessor_grant_sha,
                }
            )

            predecessor_contracts: list[dict[str, Any]] = []
            for index, row in enumerate(
                predecessor["implementation_bindings"]["contracts"]
            ):
                support_path = (
                    root
                    / "deployments/record-family-authorization"
                    / f"public-beta-predecessor-implementation-{index + 1}-support.json"
                )
                support = {
                    "schema_version": "6529stream.record-family-authorization-support.v1",
                    "artifact_type": "implementation_binding",
                    "target_phase": "public_beta",
                    "candidate_identity_sha256": candidate_sha,
                    "grant_map_sha256": predecessor_grant_sha,
                    **{
                        key: row[key]
                        for key in (
                            "contract",
                            "source_path",
                            "source_sha256",
                            "interface_path",
                            "interface_sha256",
                            "address",
                            "record_family_registry",
                            "configuration_authority",
                            "pending_configuration_authority",
                            "configuration_revision",
                            "configuration_hash",
                            "record_type_count",
                            "observed_chain_id",
                            "observed_block_number",
                            "observed_block_hash",
                            "observed_block_finalized",
                            "runtime_sha256",
                            "runtime_keccak256",
                            "interface_ids",
                            "marker",
                            "revision",
                        )
                    },
                }
                _write(support_path, support)
                predecessor_contracts.append(
                    {
                        **{
                            key: row[key]
                            for key in (
                                "contract",
                                "source_path",
                                "source_sha256",
                                "interface_path",
                                "interface_sha256",
                                "address",
                                "record_family_registry",
                                "configuration_authority",
                                "pending_configuration_authority",
                                "configuration_revision",
                                "configuration_hash",
                                "record_type_count",
                                "observed_chain_id",
                                "observed_block_number",
                                "observed_block_hash",
                                "observed_block_finalized",
                                "runtime_sha256",
                                "runtime_keccak256",
                                "interface_ids",
                                "marker",
                                "revision",
                            )
                        },
                        "evidence_path": support_path.relative_to(root).as_posix(),
                        "evidence_sha256": _sha256(support_path),
                    }
                )
            predecessor["implementation_bindings"][
                "contracts"
            ] = predecessor_contracts

            predecessor_snapshot_path = (
                root
                / "deployments/record-family-authorization"
                / "public-beta-predecessor-snapshot-intersection-support.json"
            )
            _write(
                predecessor_snapshot_path,
                {
                    "schema_version": "6529stream.record-family-authorization-support.v1",
                    "artifact_type": "snapshot_intersection",
                    "target_phase": "public_beta",
                    "candidate_identity_sha256": candidate_sha,
                    "grant_map_sha256": predecessor_grant_sha,
                    "covered_family_groups": expected_groups,
                },
            )
            predecessor["snapshot_intersection"].update(
                {
                    "evidence_path": predecessor_snapshot_path.relative_to(
                        root
                    ).as_posix(),
                    "evidence_sha256": _sha256(predecessor_snapshot_path),
                }
            )

            predecessor_lifecycle_path = (
                root
                / "deployments/record-family-authorization"
                / "public-beta-predecessor-authority-lifecycle-support.json"
            )
            _write(
                predecessor_lifecycle_path,
                {
                    "schema_version": "6529stream.record-family-authorization-support.v1",
                    "artifact_type": "authority_lifecycle",
                    "target_phase": "public_beta",
                    "candidate_identity_sha256": candidate_sha,
                    "grant_map_sha256": predecessor_grant_sha,
                    "rotation_revision": 1,
                    "revocation_revision": 1,
                    "proposal_old_authority": "0x" + "44" * 20,
                    "proposed_authority": "0x" + "45" * 20,
                    "proposal_configuration_revision": 10,
                    "proposal_configuration_hash": "0x" + "61" * 32,
                    "acceptance_old_authority": "0x" + "44" * 20,
                    "accepted_authority": "0x" + "45" * 20,
                    "acceptance_configuration_revision": 11,
                    "acceptance_configuration_hash": "0x" + "62" * 32,
                    "cancellation_authority": "0x" + "45" * 20,
                    "cancelled_pending_authority": "0x" + "46" * 20,
                    "cancellation_configuration_revision": 13,
                    "cancellation_configuration_hash": "0x" + "63" * 32,
                    "record_family_registry": classifier["host_address"],
                    "observed_chain_id": classifier["observed_chain_id"],
                    "observed_block_number": classifier["observed_block_number"],
                    "observed_block_hash": classifier["observed_block_hash"],
                    "observed_block_finalized": classifier[
                        "observed_block_finalized"
                    ],
                    "observed_configuration_authority": classifier[
                        "configuration_authority"
                    ],
                    "observed_pending_configuration_authority": classifier[
                        "pending_configuration_authority"
                    ],
                    "observed_configuration_revision": classifier[
                        "configuration_revision"
                    ],
                    "observed_configuration_hash": classifier[
                        "configuration_hash"
                    ],
                    "commitment_linkage_status": "reviewed",
                    "commitment_linkage_reference": (
                        "https://review.example/authority-commitment-linkage-v1"
                    ),
                    "observed_at_commit": candidate["source_commit"],
                },
            )
            predecessor["authority_lifecycle"].update(
                {
                    "evidence_path": predecessor_lifecycle_path.relative_to(
                        root
                    ).as_posix(),
                    "evidence_sha256": _sha256(predecessor_lifecycle_path),
                }
            )

            predecessor_phase_path = (
                root
                / "deployments/record-family-authorization"
                / "public-beta-predecessor-phase-support.json"
            )
            _write(
                predecessor_phase_path,
                {
                    "schema_version": "6529stream.record-family-authorization-support.v1",
                    "artifact_type": "phase_support",
                    "target_phase": "public_beta",
                    "candidate_identity_sha256": candidate_sha,
                    "grant_map_sha256": predecessor_grant_sha,
                    "phase": "public_beta",
                    "status": "complete",
                },
            )
            predecessor["phases"][0] = {
                "phase": "public_beta",
                "status": "complete",
                "review_status": "reviewed",
                "evidence_path": predecessor_phase_path.relative_to(root).as_posix(),
                "evidence_sha256": _sha256(predecessor_phase_path),
            }
            predecessor["phases"][1] = {
                "phase": "production_release",
                "status": "missing",
                "review_status": "unreviewed",
                "evidence_path": None,
                "evidence_sha256": None,
            }
            _write(predecessor_path, predecessor)
            evidence["phases"][0] = {
                "phase": "public_beta",
                "status": "complete",
                "review_status": "reviewed",
                "evidence_path": predecessor_path.relative_to(root).as_posix(),
                "evidence_sha256": _sha256(predecessor_path),
            }
        _write(evidence_path, evidence)
        state = {
            "grant_path": grant_path,
            "grant_document": grant_document,
            "candidate_path": candidate_path,
            "support_paths": support_paths,
            "predecessor_path": predecessor_path,
            "predecessor_grant_path": predecessor_grant_path,
        }
        return temporary, root, evidence, evidence_path, state

    def _expect_complete_failure(
        self,
        root: Path,
        evidence: dict[str, Any],
        evidence_path: Path,
        pattern: str,
    ) -> None:
        _write(evidence_path, evidence)
        with self.assertRaisesRegex(checker.RecordFamilyAuthorizationError, pattern):
            checker.validate_package(
                root,
                evidence_template_path=evidence_path.relative_to(root),
            )

    def _rebind_grant_map(
        self,
        root: Path,
        evidence: dict[str, Any],
        state: dict[str, Any],
    ) -> None:
        grant_path = state["grant_path"]
        _write(grant_path, state["grant_document"])
        grant_sha = _sha256(grant_path)
        evidence["grant_map"]["sha256"] = grant_sha
        evidence["classifier_binding"]["grant_map_sha256"] = grant_sha
        support_bindings: list[tuple[Path, dict[str, Any]]] = []
        for row in evidence["implementation_bindings"]["contracts"]:
            support_bindings.append((root / row["evidence_path"], row))
        support_bindings.extend(
            (
                (
                    root / evidence["snapshot_intersection"]["evidence_path"],
                    evidence["snapshot_intersection"],
                ),
                (
                    root / evidence["authority_lifecycle"]["evidence_path"],
                    evidence["authority_lifecycle"],
                ),
            )
        )
        support_bindings.extend(
            (root / row["evidence_path"], row)
            for row in evidence["phases"]
            if row["status"] == "complete"
        )
        for support_path, binding in support_bindings:
            support = _read(support_path)
            support["grant_map_sha256"] = grant_sha
            _write(support_path, support)
            binding["evidence_sha256"] = _sha256(support_path)

    def _update_implementation_binding(
        self,
        root: Path,
        evidence: dict[str, Any],
        state: dict[str, Any],
        index: int,
        **changes: Any,
    ) -> None:
        evidence_row = evidence["implementation_bindings"]["contracts"][index]
        grant_row = state["grant_document"]["implementation_bindings"][index]
        support_path = root / evidence_row["evidence_path"]
        support = _read(support_path)
        for key, value in changes.items():
            evidence_row[key] = value
            grant_row[key] = value
            support[key] = value
        _write(support_path, support)
        evidence_row["evidence_sha256"] = _sha256(support_path)

    def _mutate_complete(
        self,
        mutation: Callable[[Path, dict[str, Any], Path, dict[str, Any]], None],
        pattern: str,
        *,
        target_phase: str = "public_beta",
        rebind_grant: bool = False,
    ) -> None:
        temporary, root, evidence, evidence_path, state = (
            self._complete_evidence_fixture(target_phase)
        )
        try:
            mutation(root, evidence, evidence_path, state)
            if rebind_grant:
                self._rebind_grant_map(root, evidence, state)
            self._expect_complete_failure(root, evidence, evidence_path, pattern)
        finally:
            temporary.cleanup()

    def _mutate_inventory(
        self,
        mutation: Callable[[dict[str, Any]], None],
        pattern: str,
    ) -> None:
        temporary, root = self._fixture()
        try:
            path = root / checker.DEFAULT_INVENTORY
            value = _read(path)
            mutation(value)
            _write(path, value)
            with self.assertRaisesRegex(checker.RecordFamilyAuthorizationError, pattern):
                checker.validate_package(root)
        finally:
            temporary.cleanup()

    def _mutate_evidence(
        self,
        mutation: Callable[[dict[str, Any]], None],
        pattern: str,
    ) -> None:
        temporary, root = self._fixture()
        try:
            path = root / checker.DEFAULT_EVIDENCE_TEMPLATE
            value = _read(path)
            mutation(value)
            _write(path, value)
            with self.assertRaisesRegex(checker.RecordFamilyAuthorizationError, pattern):
                checker.validate_package(root)
        finally:
            temporary.cleanup()

    def test_committed_planning_package_passes(self) -> None:
        inventory, evidence = checker.validate_package(ROOT)
        self.assertEqual(len(inventory["authorization_classes"]), 8)
        self.assertEqual(len(inventory["family_groups"]), 14)
        self.assertEqual(
            len(inventory["current_implementation"]["mutation_surfaces"]), 5
        )
        self.assertEqual(evidence["record_type"], "template")

    def test_require_complete_is_unconditionally_blocked(self) -> None:
        old = checker.IMPLEMENTATION_COMPLETION_SUPPORTED
        os.environ["RECORD_FAMILY_AUTHORIZATION_COMPLETE"] = "1"
        checker.IMPLEMENTATION_COMPLETION_SUPPORTED = True
        try:
            with self.assertRaisesRegex(
                checker.RecordFamilyAuthorizationError,
                "candidate_bound_record_family_evidence_not_available",
            ):
                checker.validate_package(ROOT, require_complete=True)
            self.assertEqual(
                checker.completion_blockers(ROOT), [checker.COMPLETION_BLOCKER]
            )
        finally:
            checker.IMPLEMENTATION_COMPLETION_SUPPORTED = old
            os.environ.pop("RECORD_FAMILY_AUTHORIZATION_COMPLETE", None)

    def test_cli_require_complete_fails(self) -> None:
        self.assertEqual(checker.main(["--repo-root", str(ROOT), "--require-complete"]), 1)

    def test_inventory_status_cannot_claim_complete(self) -> None:
        self._mutate_inventory(
            lambda value: value.__setitem__("status", "complete"),
            "status",
        )

    def test_inventory_top_level_order_is_exact(self) -> None:
        def mutate(value: dict[str, Any]) -> None:
            item = value.pop("tracking_issue")
            value["tracking_issue"] = item

        self._mutate_inventory(mutate, "keys/order")

    def test_duplicate_json_key_is_rejected(self) -> None:
        temporary, root = self._fixture()
        try:
            path = root / checker.DEFAULT_INVENTORY
            text = path.read_text(encoding="utf-8")
            path.write_text(
                text.replace(
                    '"schema_version":',
                    '"schema_version": "duplicate",\n  "schema_version":',
                    1,
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                checker.RecordFamilyAuthorizationError, "duplicate JSON key"
            ):
                checker.validate_package(root)
        finally:
            temporary.cleanup()

    def test_non_interoperable_json_numbers_are_rejected(self) -> None:
        cases = (
            ("1.5", "floating-point JSON number"),
            ("Infinity", "non-finite JSON number"),
            ("NaN", "non-finite JSON number"),
            (str(2**53), "outside the interoperable I-JSON range"),
            (str(-(2**53)), "outside the interoperable I-JSON range"),
        )
        for literal, pattern in cases:
            with self.subTest(literal=literal):
                temporary, root = self._fixture()
                try:
                    path = root / checker.DEFAULT_INVENTORY
                    text = path.read_text(encoding="utf-8")
                    path.write_text(
                        text.replace(
                            '"status": "planning"',
                            f'"status": {literal}',
                            1,
                        ),
                        encoding="utf-8",
                    )
                    with self.assertRaisesRegex(
                        checker.RecordFamilyAuthorizationError,
                        pattern,
                    ):
                        checker.validate_package(root)
                finally:
                    temporary.cleanup()

    def test_schema_ids_are_exact(self) -> None:
        temporary, root = self._fixture()
        try:
            path = root / checker.DEFAULT_EVIDENCE_SCHEMA
            value = _read(path)
            value["$id"] = "https://6529.io/wrong.json"
            _write(path, value)
            with self.assertRaisesRegex(checker.RecordFamilyAuthorizationError, r"schema \$id"):
                checker.validate_package(root)
        finally:
            temporary.cleanup()

    def test_normative_anchor_must_exist(self) -> None:
        temporary, root = self._fixture()
        try:
            target = root / "docs/collection-metadata-contract.md"
            target.write_text("anchor removed\n", encoding="utf-8")
            with self.assertRaisesRegex(
                checker.RecordFamilyAuthorizationError,
                "must occur exactly once",
            ):
                checker.validate_package(root)
        finally:
            temporary.cleanup()

    def test_normative_home_anchor_must_be_unique(self) -> None:
        temporary, root = self._fixture()
        try:
            target = root / "docs/collection-metadata-contract.md"
            anchor = checker.EXPECTED_NORMATIVE_SOURCES[0]["anchor"]
            target.write_text(
                target.read_text(encoding="utf-8") + f"\n{anchor}\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                checker.RecordFamilyAuthorizationError,
                "must occur exactly once.*got 2",
            ):
                checker.validate_package(root)
        finally:
            temporary.cleanup()

    def test_class_and_family_rows_bind_exact_normative_homes(self) -> None:
        self._mutate_inventory(
            lambda value: value["authorization_classes"][0][
                "normative_source"
            ].__setitem__("anchor", checker.FAMILY_GROUP_HOME["anchor"]),
            r"authorization_classes\[0\] normative source mismatch",
        )
        self._mutate_inventory(
            lambda value: value["family_groups"][0][
                "normative_source"
            ].__setitem__("anchor", checker.AUTHORIZATION_CLASS_HOME["anchor"]),
            r"family_groups\[0\] normative source mismatch",
        )

    def test_source_function_and_authorization_shape_are_observed(self) -> None:
        temporary, root = self._fixture()
        try:
            target = root / "smart-contracts/domains/metadata/StreamCollectionMetadata.sol"
            text = target.read_text(encoding="utf-8")
            target.write_text(
                text.replace(
                    "_recordFamilyRegistry.requireRecordWriter",
                    "_recordFamilyRegistry.requireRecordWriterDrifted",
                    1,
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                checker.RecordFamilyAuthorizationError,
                "source_bindings.*digest",
            ):
                checker.validate_package(root)
        finally:
            temporary.cleanup()

    def test_lock_fragment_drift_fails_with_typed_checker_error(self) -> None:
        source = (
            ROOT / "smart-contracts/domains/metadata/StreamCollectionMetadata.sol"
        ).read_text(encoding="utf-8")
        lock_start = source.index("function lockCollectionRecord")
        lock_end = source.index("function collectionRecord(", lock_start)
        lock_fragment = source[lock_start:lock_end]

        def replace_in_lock(old: str, new: str) -> str:
            self.assertIn(old, lock_fragment)
            return source[:lock_start] + lock_fragment.replace(old, new, 1) + source[lock_end:]

        reversed_fragment = lock_fragment.replace(
            "_requireRecordWriter", "__WRITER_ANCHOR__", 1
        ).replace("_rememberRecordType", "_requireRecordWriter", 1).replace(
            "__WRITER_ANCHOR__", "_rememberRecordType", 1
        )
        cases = (
            (
                source.replace(
                    "function lockCollectionRecord",
                    "function driftedLockCollectionRecord",
                    1,
                ),
                "metadata host lock-function boundaries are missing or reordered",
            ),
            (
                source[:lock_end]
                + source[lock_end:].replace(
                    "function collectionRecord(",
                    "function driftedCollectionRecord(",
                    1,
                ),
                "metadata host lock-function boundaries are missing or reordered",
            ),
            (
                replace_in_lock("_requireRecordWriter", "_driftedRecordWriter"),
                "metadata host lock authorization/capacity anchors are missing",
            ),
            (
                replace_in_lock("_rememberRecordType", "_driftedRememberRecordType"),
                "metadata host lock authorization/capacity anchors are missing",
            ),
            (
                source[:lock_start] + reversed_fragment + source[lock_end:],
                "lock family authorization must precede record-type capacity consumption",
            ),
        )
        for drifted_source, pattern in cases:
            with self.subTest(pattern=pattern):
                with self.assertRaisesRegex(
                    checker.RecordFamilyAuthorizationError,
                    pattern,
                ):
                    checker._validate_metadata_lock_fragment(drifted_source)

    def test_as_built_contract_and_interface_hashes_are_checked_without_git(
        self,
    ) -> None:
        paths = (
            "smart-contracts/domains/metadata/StreamCollectionMetadata.sol",
            "smart-contracts/interfaces/stream/IStreamCollectionMetadata.sol",
            "smart-contracts/domains/preservation/StreamPreservationRecords.sol",
            "smart-contracts/interfaces/stream/IStreamPreservationRecords.sol",
        )
        for relative in paths:
            with self.subTest(relative=relative):
                temporary, root = self._fixture()
                try:
                    self.assertFalse((root / ".git").exists())
                    target = root / relative
                    target.write_text(
                        target.read_text(encoding="utf-8")
                        + "\n// anchor-preserving hostile source drift\n",
                        encoding="utf-8",
                    )
                    with self.assertRaisesRegex(
                        checker.RecordFamilyAuthorizationError,
                        "source_bindings.*digest",
                    ):
                        checker.validate_package(root)
                finally:
                    temporary.cleanup()

    def test_authorization_classes_exact_count_order_and_names(self) -> None:
        mutations = (
            lambda value: value["authorization_classes"].pop(),
            lambda value: value["authorization_classes"].append(
                copy.deepcopy(value["authorization_classes"][0])
            ),
            lambda value: value["authorization_classes"].reverse(),
            lambda value: value["authorization_classes"][0].__setitem__(
                "name", "ARTIST_ADMIN"
            ),
        )
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                self._mutate_inventory(mutation, "authorization")

    def test_authorization_class_ids_remain_unpinned(self) -> None:
        self._mutate_inventory(
            lambda value: value["authorization_classes"][0].__setitem__(
                "onchain_id", "0x" + "11" * 32
            ),
            "onchain_id",
        )

    def test_family_groups_exact_count_order_and_names(self) -> None:
        mutations = (
            lambda value: value["family_groups"].pop(),
            lambda value: value["family_groups"].append(
                copy.deepcopy(value["family_groups"][0])
            ),
            lambda value: value["family_groups"].reverse(),
            lambda value: value["family_groups"][11].__setitem__(
                "name", "IDENTITY"
            ),
        )
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                self._mutate_inventory(mutation, "family")

    def test_identity_display_is_one_normative_group(self) -> None:
        self._mutate_inventory(
            lambda value: value["family_groups"][11].__setitem__(
                "normative_patterns", ["IDENTITY_*"]
            ),
            "family groups/order/patterns",
        )

    def test_wildcard_ids_and_guessed_mappings_are_rejected(self) -> None:
        def add_id(value: dict[str, Any]) -> None:
            value["family_groups"][0]["declared_record_type_ids"] = [
                "0x" + "11" * 32
            ]

        self._mutate_inventory(add_id, "declared_record_type_ids")
        for index in (0, 1, 2):
            with self.subTest(family=checker.EXPECTED_FAMILY_GROUPS[index][0]):
                self._mutate_inventory(
                    lambda value, index=index: value["family_groups"][index].__setitem__(
                        "authorization_classes", ["GLOBAL_ADMIN"]
                    ),
                    "authorization_classes",
                )

    def test_all_five_surface_identities_are_pinned(self) -> None:
        for index in range(5):
            with self.subTest(index=index):
                self._mutate_inventory(
                    lambda value, index=index: value["current_implementation"][
                        "mutation_surfaces"
                    ][index].__setitem__("selector", "0x00000000"),
                    rf"mutation_surfaces\[{index}\] exact identity mismatch",
                )

    def test_all_five_surface_authorization_facts_are_pinned(self) -> None:
        fields = {
            "function_admin_authorized": False,
            "global_admin_authorized": False,
            "family_classifier_enforced": True,
            "family_authorization_enforced": True,
            "authorization_class_emitted": True,
        }
        for index in range(5):
            for field, wrong in fields.items():
                with self.subTest(index=index, field=field):
                    self._mutate_inventory(
                        lambda value, index=index, field=field, wrong=wrong: value[
                            "current_implementation"
                        ]["mutation_surfaces"][index].__setitem__(field, wrong),
                        field.replace("_", ".*"),
                    )

    def test_lock_surface_cannot_be_omitted(self) -> None:
        self._mutate_inventory(
            lambda value: value["current_implementation"]["mutation_surfaces"].pop(3),
            "mutation_surfaces.*too short",
        )

    def test_fail_open_rows_are_exact_and_open(self) -> None:
        self._mutate_inventory(
            lambda value: value["current_implementation"][
                "known_fail_open_behaviors"
            ][0].__setitem__("status", "accepted"),
            "open_blocker",
        )
        self._mutate_inventory(
            lambda value: value["current_implementation"][
                "known_fail_open_behaviors"
            ].pop(),
            "known_fail_open_behaviors.*too short",
        )

    def test_snapshot_intersection_cannot_claim_completion(self) -> None:
        self._mutate_inventory(
            lambda value: value["snapshot_policy"].__setitem__(
                "family_authorization_enforced", True
            ),
            "family_authorization_enforced",
        )

    def test_classifier_binding_cannot_be_fabricated(self) -> None:
        self._mutate_inventory(
            lambda value: value["classifier_binding"].__setitem__(
                "interface_id", "0x12345678"
            ),
            "interface_id",
        )

    def test_candidate_binding_cannot_be_fabricated(self) -> None:
        self._mutate_inventory(
            lambda value: value["candidate_binding"].__setitem__(
                "candidate_id", "candidate-mainnet-v1"
            ),
            "candidate_id",
        )

    def test_inventory_blocker_set_is_exact(self) -> None:
        self._mutate_inventory(
            lambda value: value["blockers"].remove(
                "implementation_not_supported_in_this_slice"
            ),
            "blockers/order",
        )

    def test_family_group_blocker_sets_are_exact(self) -> None:
        inventory = _read(ROOT / checker.DEFAULT_INVENTORY)
        for index, row in enumerate(inventory["family_groups"]):
            expected = list(checker.COMMON_FAMILY_GROUP_BLOCKERS)
            if row["name"] in checker.ADMIN_REJECTION_FAMILY_GROUPS:
                expected.extend(
                    checker.ADMIN_REJECTION_FAMILY_GROUP_BLOCKERS
                )
            if row["name"] == "SNAPSHOT":
                expected.extend(checker.SNAPSHOT_FAMILY_GROUP_EXTRA_BLOCKERS)
            self.assertEqual(row["blockers"], expected)

            mutations = (
                lambda blockers: blockers.append("unexpected_blocker"),
                lambda blockers: blockers.pop(),
                lambda blockers: blockers.reverse(),
                lambda blockers: blockers.__setitem__(
                    0, "unexpected_blocker"
                ),
            )
            for mutation_name, mutation in zip(
                ("add", "remove", "reorder", "substitute"),
                mutations,
                strict=True,
            ):
                def mutate_blockers(
                    value: dict[str, Any],
                    index: int = index,
                    mutation: Callable[[list[str]], None] = mutation,
                ) -> None:
                    mutation(value["family_groups"][index]["blockers"])

                with self.subTest(
                    index=index,
                    family=row["name"],
                    mutation=mutation_name,
                ):
                    self._mutate_inventory(
                        mutate_blockers,
                        rf"family_groups\[{index}\] blockers mismatch",
                    )

    def test_template_raw_inventory_hash_is_recomputed(self) -> None:
        self._mutate_evidence(
            lambda value: value["inventory_binding"].__setitem__(
                "sha256", "0" * 64
            ),
            "raw inventory SHA-256",
        )

    def test_template_cannot_claim_evidence_or_review(self) -> None:
        self._mutate_evidence(
            lambda value: value.__setitem__("record_type", "retained_evidence"),
            "evidence does not satisfy its schema",
        )
        self._mutate_evidence(
            lambda value: value.__setitem__("review_status", "reviewed"),
            "unreviewed.*was expected",
        )

    def test_candidate_and_profile_split_brain_is_rejected(self) -> None:
        self._mutate_evidence(
            lambda value: value["candidate_binding"].__setitem__(
                "source_commit", "a" * 40
            ),
            "candidate_binding.source_commit",
        )
        self._mutate_evidence(
            lambda value: value["profile_binding"].__setitem__(
                "sha256", "a" * 64
            ),
            "profile binding mismatch",
        )

    def test_missing_runtime_grant_snapshot_and_lifecycle_cannot_be_promoted(self) -> None:
        mutations = (
            (lambda value: value["implementation_bindings"].__setitem__("status", "complete"), r"implementation_bindings.*'missing' was expected"),
            (lambda value: value["grant_map"].__setitem__("status", "complete"), r"grant_map.*'missing' was expected"),
            (lambda value: value["snapshot_intersection"].__setitem__("status", "complete"), r"snapshot_intersection.*'missing' was expected"),
            (lambda value: value["authority_lifecycle"].__setitem__("status", "complete"), r"authority_lifecycle.*'missing' was expected"),
        )
        for mutation, pattern in mutations:
            with self.subTest(pattern=pattern):
                self._mutate_evidence(mutation, pattern)

    def test_phase_rows_are_exact_missing_and_unreviewed(self) -> None:
        self._mutate_evidence(
            lambda value: value["phases"].reverse(),
            "phases",
        )
        self._mutate_evidence(
            lambda value: value["phases"][0].__setitem__("status", "complete"),
            "phases",
        )
        self._mutate_evidence(
            lambda value: value["phases"].pop(),
            "phases",
        )

    def test_phase_evidence_cannot_cycle_through_downstream_release_outputs(self) -> None:
        for path in (
            checker.DEFAULT_EVIDENCE_TEMPLATE.as_posix(),
            checker.DEFAULT_INVENTORY.as_posix(),
            "release-artifacts/latest/release-manifest.json",
            "release-artifacts/latest/risk-register.json",
            "release-artifacts/latest/release-notes.json",
            "release-artifacts/latest/release-notes.md",
            "release-artifacts/latest/release-candidate-lockfile.json",
            "release-artifacts/latest/SHA256SUMS",
            "release-artifacts/latest/release-checksums.json",
        ):
            with self.subTest(path=path):
                self._mutate_evidence(
                    lambda value, path=path: value["phases"][0].__setitem__(
                        "evidence_path", path
                    ),
                    "cyclic/downstream evidence path",
                )

    def test_grant_map_cannot_name_raw_candidate_or_downstream_artifacts(self) -> None:
        for path, pattern in (
            (
                "deployments/config/mainnet-genesis-candidate.json",
                "raw candidate artifact path",
            ),
            (
                "release-artifacts/latest/risk-register.json",
                "cyclic/downstream evidence path",
            ),
        ):
            with self.subTest(path=path):
                self._mutate_evidence(
                    lambda value, path=path: value["grant_map"].__setitem__(
                        "path", path
                    ),
                    pattern,
                )

    def test_grant_document_transit_paths_are_forbidden(self) -> None:
        cases = (
            (
                "path",
                "release-artifacts/latest/release-manifest.json",
                "cyclic/downstream evidence path",
            ),
            (
                "source_path",
                "release-artifacts/latest/release-manifest.json",
                "cyclic/downstream evidence path",
            ),
            (
                "interface_path",
                "release-artifacts/latest/release-manifest.json",
                "cyclic/downstream evidence path",
            ),
            (
                "path",
                "deployments/config/mainnet-genesis-candidate.json",
                "raw candidate artifact path",
            ),
            (
                "source_path",
                "deployments/config/mainnet-genesis-candidate.json",
                "raw candidate artifact path",
            ),
            (
                "interface_path",
                "deployments/config/mainnet-genesis-candidate.json",
                "raw candidate artifact path",
            ),
        )
        for field, path, pattern in cases:
            with self.subTest(field=field, path=path):
                self._mutate_complete(
                    lambda _root, _evidence, _path, state, field=field, path=path: state[
                        "grant_document"
                    ]["implementation_bindings"][0].__setitem__(field, path),
                    pattern,
                    rebind_grant=True,
                )

        def bind_grant_to_itself(
            root: Path,
            _evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            state["grant_document"]["implementation_bindings"][0]["path"] = state[
                "grant_path"
            ].relative_to(root).as_posix()

        self._mutate_complete(
            bind_grant_to_itself,
            "cyclic/downstream evidence path",
            rebind_grant=True,
        )

    def test_raw_candidate_artifact_hash_key_is_forbidden(self) -> None:
        self._mutate_evidence(
            lambda value: value["candidate_binding"].__setitem__(
                "candidate_artifact_sha256", "a" * 64
            ),
            "forbidden raw candidate hash key",
        )

    def test_terminal_dot_segments_are_rejected(self) -> None:
        self._mutate_inventory(
            lambda value: value["normative_sources"][0].__setitem__(
                "path", "docs/."
            ),
            "schema",
        )
        self._mutate_inventory(
            lambda value: value["normative_sources"][0].__setitem__(
                "path", "docs/.."
            ),
            "schema",
        )

    def test_symlink_or_reparse_source_is_rejected(self) -> None:
        temporary, root = self._fixture()
        try:
            target = root / "docs/collection-metadata-contract.md"
            outside = root.parent / f"{root.name}-outside.md"
            outside.write_text("CMC-AUTHZ\n", encoding="utf-8")
            target.unlink()
            try:
                target.symlink_to(outside)
            except OSError as exc:
                self.skipTest(f"symlink creation unavailable: {exc}")
            with self.assertRaisesRegex(
                checker.RecordFamilyAuthorizationError,
                "symlink, junction, or reparse",
            ):
                checker.validate_package(root)
        finally:
            try:
                outside.unlink(missing_ok=True)
            except UnboundLocalError:
                pass
            temporary.cleanup()

    def test_template_notice_and_redaction_policy_are_not_optional(self) -> None:
        self._mutate_evidence(
            lambda value: value.__setitem__("template_notice", "looks complete"),
            "non-evidence release boundary",
        )
        self._mutate_evidence(
            lambda value: value["redaction_policy"].__setitem__(
                "no_secrets", False
            ),
            "no_secrets",
        )

    def test_template_authority_lifecycle_evidence_remains_absent(self) -> None:
        for field in (
            "rotation_revision",
            "revocation_revision",
            "proposal_old_authority",
            "proposed_authority",
            "proposal_configuration_revision",
            "proposal_configuration_hash",
            "acceptance_old_authority",
            "accepted_authority",
            "acceptance_configuration_revision",
            "acceptance_configuration_hash",
            "cancellation_authority",
            "cancelled_pending_authority",
            "cancellation_configuration_revision",
            "cancellation_configuration_hash",
            "record_family_registry",
            "observed_chain_id",
            "observed_block_number",
            "observed_block_hash",
            "observed_block_finalized",
            "observed_configuration_authority",
            "observed_pending_configuration_authority",
            "observed_configuration_revision",
            "observed_configuration_hash",
            "commitment_linkage_status",
            "commitment_linkage_reference",
        ):
            with self.subTest(field=field):
                self._mutate_evidence(
                    lambda value, field=field: value["authority_lifecycle"].__setitem__(
                        field,
                        (
                            "0x" + "77" * 20
                            if "authority" in field or field == "record_family_registry"
                            else "0x" + "78" * 32
                            if field.endswith("_hash")
                            else True
                            if field == "observed_block_finalized"
                            else "reviewed"
                            if field == "commitment_linkage_status"
                            else "https://review.example/commitment-linkage"
                            if field == "commitment_linkage_reference"
                            else 1
                        ),
                    ),
                    rf"authority_lifecycle\.{field} must remain null",
                )

    def test_retained_public_beta_and_production_reach_only_the_named_656_stop(
        self,
    ) -> None:
        for target_phase in ("public_beta", "production_release"):
            with self.subTest(target_phase=target_phase):
                temporary, root, evidence, evidence_path, _state = (
                    self._complete_evidence_fixture(target_phase)
                )
                try:
                    self._expect_complete_failure(
                        root,
                        evidence,
                        evidence_path,
                        (
                            "candidate_identity_dependency_unavailable: inventory "
                            "candidate binding remains blocked on the serialized #656"
                        ),
                    )
                finally:
                    temporary.cleanup()

    def test_each_exact_normative_fragment_rejects_anchor_preserving_drift(
        self,
    ) -> None:
        for relative, label, start, _end, _digest in checker.NORMATIVE_FRAGMENT_BINDINGS:
            with self.subTest(label=label):
                temporary, root = self._fixture()
                try:
                    path = root / relative
                    text = path.read_text(encoding="utf-8")
                    self.assertEqual(text.count(start), 1)
                    path.write_text(
                        text.replace(start, start + " [hostile-drift]", 1),
                        encoding="utf-8",
                    )
                    with self.assertRaisesRegex(
                        checker.RecordFamilyAuthorizationError,
                        rf"{label} content drifted from the exact normative owned section",
                    ):
                        checker.validate_package(root)
                finally:
                    temporary.cleanup()

    def test_owner_record_normative_mirror_rejects_anchor_preserving_drift(
        self,
    ) -> None:
        temporary, root = self._fixture()
        try:
            path = root / "docs/launch-conformance-matrix.md"
            text = path.read_text(encoding="utf-8")
            path.write_text(
                text.replace("| Owner records |", "| Owner records | hostile |", 1),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                checker.RecordFamilyAuthorizationError,
                "owner-record conformance row drifted from the exact normative mirror",
            ):
                checker.validate_package(root)
        finally:
            temporary.cleanup()

    def test_candidate_projection_profile_and_lifecycle_cross_bindings_are_exact(
        self,
    ) -> None:
        cases = (
            (
                lambda root, evidence, _path, state: _write(
                    state["candidate_path"],
                    {
                        **_read(state["candidate_path"]),
                        "source_commit": "b" * 40,
                    },
                ),
                "candidate identity projection source_commit mismatch",
            ),
            (
                lambda _root, evidence, _path, _state: evidence[
                    "profile_binding"
                ].__setitem__("sha256", "71" * 32),
                "candidate/profile digest mismatch",
            ),
            (
                lambda _root, evidence, _path, _state: evidence[
                    "authority_lifecycle"
                ].__setitem__("observed_at_commit", "b" * 40),
                "candidate/lifecycle source commit mismatch",
            ),
        )
        for mutation, pattern in cases:
            with self.subTest(pattern=pattern):
                self._mutate_complete(mutation, pattern)

    def test_evidence_id_and_real_inventory_phase_path_must_agree(self) -> None:
        self._mutate_complete(
            lambda _root, evidence, _path, _state: evidence.__setitem__(
                "evidence_id", "record-family-authorization-production-release-v1"
            ),
            r"evidence_id.*record-family-authorization-public-beta-v1.*was expected",
        )

        temporary, root, evidence, public_path, _state = (
            self._complete_evidence_fixture("public_beta")
        )
        try:
            production_path = root / next(
                row["path"]
                for row in _read(root / checker.DEFAULT_INVENTORY)[
                    "retained_evidence"
                ]
                if row["phase"] == "production_release"
            )
            _write(production_path, evidence)
            self._expect_complete_failure(
                root,
                evidence,
                production_path,
                "retained evidence input path/target_phase mismatch",
            )
            self.assertTrue(public_path.is_file())
            self.assertTrue(production_path.is_file())
        finally:
            temporary.cleanup()

    def test_public_beta_and_production_phase_matrices_are_not_interchangeable(
        self,
    ) -> None:
        def promote_public_successor(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            _state: dict[str, Any],
        ) -> None:
            phase_path = (
                root
                / "deployments/record-family-authorization/production-release-phase-support.json"
            )
            first_support = _read(root / evidence["phases"][0]["evidence_path"])
            first_support["phase"] = "production_release"
            _write(phase_path, first_support)
            evidence["phases"][1] = {
                "phase": "production_release",
                "status": "complete",
                "review_status": "reviewed",
                "evidence_path": phase_path.relative_to(root).as_posix(),
                "evidence_sha256": _sha256(phase_path),
            }

        self._mutate_complete(
            promote_public_successor,
            r"phases.*evidence_path.*not of type 'null'",
        )

        def remove_production_predecessor(
            _root: Path,
            evidence: dict[str, Any],
            _path: Path,
            _state: dict[str, Any],
        ) -> None:
            evidence["phases"][0].update(
                {
                    "status": "missing",
                    "review_status": "unreviewed",
                    "evidence_path": None,
                    "evidence_sha256": None,
                }
            )

        self._mutate_complete(
            remove_production_predecessor,
            r"phases.*evidence_path.*None is not of type 'string'",
            target_phase="production_release",
        )

    def test_production_predecessor_path_hash_and_envelope_identity_are_exact(
        self,
    ) -> None:
        def substitute_arbitrary_real_support(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            arbitrary = state["support_paths"]["phase_public_beta"]
            self.assertTrue(arbitrary.is_file())
            evidence["phases"][0]["evidence_path"] = arbitrary.relative_to(
                root
            ).as_posix()
            evidence["phases"][0]["evidence_sha256"] = _sha256(arbitrary)

        self._mutate_complete(
            substitute_arbitrary_real_support,
            "production predecessor must bind the canonical public-beta retained envelope path",
            target_phase="production_release",
        )

        def mutate_predecessor_without_rebinding(
            _root: Path,
            _evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            predecessor_path = state["predecessor_path"]
            predecessor = _read(predecessor_path)
            predecessor["review"]["reference"] = "review://mutated-predecessor"
            _write(predecessor_path, predecessor)

        self._mutate_complete(
            mutate_predecessor_without_rebinding,
            "canonical public-beta retained predecessor file digest mismatch",
            target_phase="production_release",
        )

        def invalidate_predecessor_schema(
            _root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            predecessor_path = state["predecessor_path"]
            predecessor = _read(predecessor_path)
            predecessor.pop("inventory_binding")
            _write(predecessor_path, predecessor)
            evidence["phases"][0]["evidence_sha256"] = _sha256(predecessor_path)

        self._mutate_complete(
            invalidate_predecessor_schema,
            r"canonical public-beta retained predecessor.*inventory_binding.*required",
            target_phase="production_release",
        )

        def change_predecessor_identity(
            _root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            predecessor_path = state["predecessor_path"]
            predecessor = _read(predecessor_path)
            predecessor["evidence_id"] = (
                "record-family-authorization-production-release-v1"
            )
            _write(predecessor_path, predecessor)
            evidence["phases"][0]["evidence_sha256"] = _sha256(predecessor_path)

        self._mutate_complete(
            change_predecessor_identity,
            r"canonical public-beta retained predecessor.*evidence_id.*public-beta-v1.*was expected",
            target_phase="production_release",
        )

        def split_predecessor_candidate_projection(
            _root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            predecessor_path = state["predecessor_path"]
            predecessor = _read(predecessor_path)
            predecessor["candidate_binding"][
                "candidate_identity_sha256"
            ] = "f4" * 32
            predecessor["grant_map"][
                "candidate_identity_sha256"
            ] = "f4" * 32
            _write(predecessor_path, predecessor)
            evidence["phases"][0]["evidence_sha256"] = _sha256(predecessor_path)

        self._mutate_complete(
            split_predecessor_candidate_projection,
            "candidate identity projection candidate_identity_sha256 mismatch",
            target_phase="production_release",
        )

        def split_predecessor_grant_binding(
            _root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            predecessor_path = state["predecessor_path"]
            predecessor = _read(predecessor_path)
            predecessor["grant_map"][
                "candidate_identity_sha256"
            ] = "f5" * 32
            _write(predecessor_path, predecessor)
            evidence["phases"][0]["evidence_sha256"] = _sha256(predecessor_path)

        self._mutate_complete(
            split_predecessor_grant_binding,
            "candidate/grant-map identity mismatch",
            target_phase="production_release",
        )

    def test_third_phase_and_wrong_real_phase_support_path_fail_closed(self) -> None:
        self._mutate_complete(
            lambda _root, evidence, _path, _state: evidence["phases"].append(
                copy.deepcopy(evidence["phases"][0])
            ),
            r"phases.*(was expected|too long|items)",
        )

        def wrong_real_phase_path(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            lifecycle_path = state["support_paths"]["lifecycle"]
            evidence["phases"][0]["evidence_path"] = lifecycle_path.relative_to(
                root
            ).as_posix()
            evidence["phases"][0]["evidence_sha256"] = _sha256(lifecycle_path)

        self._mutate_complete(
            wrong_real_phase_path,
            "phase support public_beta must be a distinct file from authority-lifecycle support",
        )

    def test_grant_map_empty_foreign_count_and_reorder_are_rejected(self) -> None:
        cases = (
            (
                lambda grant: grant["family_groups"][5].__setitem__("grants", []),
                "active grants do not exactly cover admitted family-grant classes",
            ),
            (
                lambda grant: grant["authorization_classes"][0].__setitem__(
                    "name", "FOREIGN_SIGNER"
                ),
                r"grant map artifact.*authorization_classes.*ARTIST_SIGNER.*was expected",
            ),
            (
                lambda grant: grant["family_groups"].pop(),
                r"grant map artifact.*family_groups.*too short",
            ),
            (
                lambda grant: grant["authorization_classes"].reverse(),
                r"grant map artifact.*authorization_classes.*was expected",
            ),
            (
                lambda grant: grant["implementation_bindings"].pop(),
                r"grant map artifact.*implementation_bindings.*too short",
            ),
        )
        for mutation, pattern in cases:
            with self.subTest(pattern=pattern):
                self._mutate_complete(
                    lambda _root, _evidence, _path, state, mutation=mutation: mutation(
                        state["grant_document"]
                    ),
                    pattern,
                    rebind_grant=True,
                )

    def test_grant_map_duplicates_and_foreign_references_are_rejected(self) -> None:
        cases = (
            (
                lambda grant: grant["authorization_classes"][1].__setitem__(
                    "authorization_class_id",
                    grant["authorization_classes"][0]["authorization_class_id"],
                ),
                "grant-map authorization classes do not exactly match the source catalog",
            ),
            (
                lambda grant: grant["family_groups"][1]["record_type_admissions"][
                    0
                ].__setitem__(
                    "record_type_id",
                    grant["family_groups"][0]["record_type_admissions"][0][
                        "record_type_id"
                    ],
                ),
                "grant-map declared record-type IDs must be globally unique",
            ),
            (
                lambda grant: grant["family_groups"][0]["record_type_admissions"][
                    0
                ].__setitem__("authorization_class_ids", [8]),
                "references a class outside the source catalog family mask",
            ),
        )
        for mutation, pattern in cases:
            with self.subTest(pattern=pattern):
                self._mutate_complete(
                    lambda _root, _evidence, _path, state, mutation=mutation: mutation(
                        state["grant_document"]
                    ),
                    pattern,
                    rebind_grant=True,
                )

    def test_grant_map_catalog_classes_and_providers_are_exact(self) -> None:
        cases = (
            (
                lambda grant: grant["source_catalog_binding"].__setitem__(
                    "sha256", "91" * 32
                ),
                "grant-map source catalog binding mismatch",
            ),
            (
                lambda grant: grant["authorization_classes"][0].__setitem__(
                    "mode", "family_grant"
                ),
                "grant-map authorization classes do not exactly match the source catalog",
            ),
            (
                lambda grant: grant["authority_providers"][0].__setitem__(
                    "authorization_class_id", 8
                ),
                "grant-map authority providers must exactly cover live-provider classes",
            ),
        )
        for mutation, pattern in cases:
            with self.subTest(pattern=pattern):
                self._mutate_complete(
                    lambda _root, _evidence, _path, state, mutation=mutation: mutation(
                        state["grant_document"]
                    ),
                    pattern,
                    rebind_grant=True,
                )

    def test_classifier_configuration_observation_is_exact_and_cross_bound(self) -> None:
        self._mutate_complete(
            lambda _root, _evidence, _path, state: state["grant_document"][
                "classifier_binding"
            ].__setitem__("configuration_hash", "0x" + "93" * 32),
            "grant-map classifier binding mismatch",
            rebind_grant=True,
        )

        def wrong_admission_count(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            evidence["classifier_binding"]["record_type_count"] = 13
            state["grant_document"]["classifier_binding"]["record_type_count"] = 13
            for index in range(2):
                self._update_implementation_binding(
                    root,
                    evidence,
                    state,
                    index,
                    record_type_count=13,
                )

        self._mutate_complete(
            wrong_admission_count,
            "classifier record-type count does not match exact grant-map admissions",
            rebind_grant=True,
        )

        def split_block_observation(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            self._update_implementation_binding(
                root,
                evidence,
                state,
                1,
                observed_block_hash="0x" + "94" * 32,
            )

        self._mutate_complete(
            split_block_observation,
            "implementation configuration observations must exactly match the classifier",
            rebind_grant=True,
        )

        def unfinalized_support_observation(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            _state: dict[str, Any],
        ) -> None:
            row = evidence["implementation_bindings"]["contracts"][1]
            support_path = root / row["evidence_path"]
            support = _read(support_path)
            support["observed_block_finalized"] = False
            _write(support_path, support)
            row["evidence_sha256"] = _sha256(support_path)

        self._mutate_complete(
            unfinalized_support_observation,
            (
                "implementation support StreamPreservationRecords "
                "observed_block_finalized mismatch"
            ),
        )

    def test_family_masks_locks_and_active_grants_are_exact(self) -> None:
        cases = (
            (
                lambda grant: grant["family_groups"][0].__setitem__(
                    "family_id", "0x" + "91" * 32
                ),
                r"family_groups\[0\] family ID does not match the source catalog",
            ),
            (
                lambda grant: grant["family_groups"][0].__setitem__(
                    "allowed_authorization_class_ids", [8]
                ),
                r"family_groups\[0\] allowed classes do not match the source catalog",
            ),
            (
                lambda grant: grant["family_groups"][0]["record_type_admissions"][
                    0
                ].__setitem__("authorization_class_ids", [8]),
                "references a class outside the source catalog family mask",
            ),
            (
                lambda grant: grant["family_groups"][3]["record_type_admissions"][
                    0
                ]["authorization_class_ids"].reverse(),
                "authorization classes must be strictly ordered",
            ),
            (
                lambda grant: grant["family_groups"][2]["record_type_admissions"][
                    0
                ].__setitem__("lock_allowed", True),
                "lock policy mismatch",
            ),
            (
                lambda grant: grant["family_groups"][5].__setitem__("grants", []),
                "active grants do not exactly cover admitted family-grant classes",
            ),
            (
                lambda grant: grant["family_groups"][0]["grants"].append(
                    {
                        "authorization_class_id": 1,
                        "account": "0x" + "92" * 20,
                        "revision": 1,
                    }
                ),
                "is not an exact active family-grant class",
            ),
            (
                lambda grant: grant["family_groups"][5]["grants"].reverse(),
                "grants must be strictly ordered",
            ),
        )
        for mutation, pattern in cases:
            with self.subTest(pattern=pattern):
                self._mutate_complete(
                    lambda _root, _evidence, _path, state, mutation=mutation: mutation(
                        state["grant_document"]
                    ),
                    pattern,
                    rebind_grant=True,
                )

        def append_out_of_order_admission(
            _root: Path,
            _evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            admission = copy.deepcopy(
                state["grant_document"]["family_groups"][0][
                    "record_type_admissions"
                ][0]
            )
            admission["record_type_id"] = "0x" + "00" * 31 + "01"
            state["grant_document"]["family_groups"][0][
                "record_type_admissions"
            ].append(admission)

        self._mutate_complete(
            append_out_of_order_admission,
            "record-type admissions must be strictly ordered",
            rebind_grant=True,
        )

    def test_classifier_and_grant_bindings_cannot_be_fabricated(self) -> None:
        self._mutate_complete(
            lambda _root, evidence, _path, _state: evidence[
                "classifier_binding"
            ].__setitem__("grant_map_sha256", "73" * 32),
            "classifier/grant-map digest mismatch",
        )
        def fabricate_classifier(
            _root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            address = "0x" + "fa" * 20
            evidence["classifier_binding"]["contract_address"] = address
            state["grant_document"]["classifier_binding"][
                "contract_address"
            ] = address

        self._mutate_complete(
            fabricate_classifier,
            "classifier binding must match exactly one implementation binding",
            rebind_grant=True,
        )
        self._mutate_complete(
            lambda _root, evidence, _path, _state: evidence["grant_map"].__setitem__(
                "candidate_identity_sha256", "72" * 32
            ),
            "candidate/grant-map identity mismatch",
        )

    def test_grant_map_path_is_exact_and_phase_specific(self) -> None:
        for target_phase in ("public_beta", "production_release"):
            other_phase = (
                "production_release"
                if target_phase == "public_beta"
                else "public_beta"
            )
            with self.subTest(target_phase=target_phase, variant="other-phase"):
                def other_phase_path(
                    root: Path,
                    evidence: dict[str, Any],
                    _path: Path,
                    state: dict[str, Any],
                    other_phase: str = other_phase,
                ) -> None:
                    other_path = root / checker.EXPECTED_GRANT_MAP_PATHS[other_phase]
                    if not other_path.exists():
                        shutil.copyfile(state["grant_path"], other_path)
                    evidence["grant_map"]["path"] = other_path.relative_to(
                        root
                    ).as_posix()

                self._mutate_complete(
                    other_phase_path,
                    "grant-map path must match the canonical phase-specific candidate-bound artifact path",
                    target_phase=target_phase,
                )
            with self.subTest(target_phase=target_phase, variant="arbitrary"):
                def arbitrary_real_path(
                    root: Path,
                    evidence: dict[str, Any],
                    _path: Path,
                    state: dict[str, Any],
                ) -> None:
                    arbitrary = (
                        root
                        / "deployments/record-family-authorization"
                        / "arbitrary-record-family-authorization-grant-map.json"
                    )
                    shutil.copyfile(state["grant_path"], arbitrary)
                    evidence["grant_map"]["path"] = arbitrary.relative_to(
                        root
                    ).as_posix()

                self._mutate_complete(
                    arbitrary_real_path,
                    "grant-map path must match the canonical phase-specific candidate-bound artifact path",
                    target_phase=target_phase,
                )

    def test_runtime_bindings_require_unique_identity_and_grant_agreement(self) -> None:
        self._mutate_complete(
            lambda _root, evidence, _path, _state: evidence[
                "implementation_bindings"
            ]["contracts"][1].__setitem__("contract", "StreamCollectionMetadata"),
            "implementation contract bindings must be unique",
        )
        self._mutate_complete(
            lambda _root, evidence, _path, _state: evidence[
                "implementation_bindings"
            ]["contracts"][1].__setitem__(
                "address",
                evidence["implementation_bindings"]["contracts"][0]["address"],
            ),
            "implementation addresses must be unique",
        )

        def wrong_preservation_registry(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            self._update_implementation_binding(
                root,
                evidence,
                state,
                1,
                record_family_registry="0x" + "f2" * 20,
            )

        self._mutate_complete(
            wrong_preservation_registry,
            "implementation registry bindings must exactly match the classifier host",
            rebind_grant=True,
        )
        self._mutate_complete(
            lambda _root, _evidence, _path, state: state["grant_document"][
                "implementation_bindings"
            ][1].__setitem__("record_family_registry", "0x" + "f3" * 20),
            r"grant-map implementation_bindings\[1\]\.record_family_registry mismatch",
            rebind_grant=True,
        )

        def fabricate_bound_runtime(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            _state: dict[str, Any],
        ) -> None:
            row = evidence["implementation_bindings"]["contracts"][0]
            row["runtime_sha256"] = "f1" * 32
            support_path = root / row["evidence_path"]
            support = _read(support_path)
            support["runtime_sha256"] = row["runtime_sha256"]
            _write(support_path, support)
            row["evidence_sha256"] = _sha256(support_path)

        self._mutate_complete(
            fabricate_bound_runtime,
            r"grant-map implementation_bindings\[0\]\.runtime_sha256 mismatch",
        )

    def test_current_and_pending_configuration_authority_observation_is_exact(self) -> None:
        def drift_current_authority(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            self._update_implementation_binding(
                root,
                evidence,
                state,
                1,
                configuration_authority="0x" + "f4" * 20,
            )

        self._mutate_complete(
            drift_current_authority,
            "implementation configuration observations must exactly match the classifier",
            rebind_grant=True,
        )

        def stage_unreviewed_pending_takeover(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            pending = "0x" + "f5" * 20
            evidence["classifier_binding"]["pending_configuration_authority"] = pending
            state["grant_document"]["classifier_binding"][
                "pending_configuration_authority"
            ] = pending
            for index in range(2):
                self._update_implementation_binding(
                    root,
                    evidence,
                    state,
                    index,
                    pending_configuration_authority=pending,
                )

        self._mutate_complete(
            stage_unreviewed_pending_takeover,
            "pending_configuration_authority_disposition",
            rebind_grant=True,
        )

        def stage_reviewed_pending_authority(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            pending = "0x" + "f7" * 20
            disposition = {
                "status": "reviewed",
                "reviewer": "independent-reviewer",
                "reviewed_at": "2026-07-24T00:00:00Z",
                "reference": "https://review.example/pending-authority-v1",
                "rationale": "Reviewed in-flight transfer retained at the finalized observation.",
            }
            evidence["classifier_binding"].update(
                {
                    "pending_configuration_authority": pending,
                    "pending_configuration_authority_disposition": disposition,
                    "configuration_revision": 14,
                    "configuration_hash": "0x" + "64" * 32,
                }
            )
            state["grant_document"]["classifier_binding"].update(
                {
                    "pending_configuration_authority": pending,
                    "pending_configuration_authority_disposition": disposition,
                    "configuration_revision": 14,
                    "configuration_hash": "0x" + "64" * 32,
                }
            )
            for index in range(2):
                self._update_implementation_binding(
                    root,
                    evidence,
                    state,
                    index,
                    pending_configuration_authority=pending,
                    configuration_revision=14,
                    configuration_hash="0x" + "64" * 32,
                )
            lifecycle = evidence["authority_lifecycle"]
            lifecycle.update(
                {
                    "observed_pending_configuration_authority": pending,
                    "observed_configuration_revision": 14,
                    "observed_configuration_hash": "0x" + "64" * 32,
                }
            )
            lifecycle_support_path = root / lifecycle["evidence_path"]
            lifecycle_support = _read(lifecycle_support_path)
            lifecycle_support.update(
                {
                    "observed_pending_configuration_authority": pending,
                    "observed_configuration_revision": 14,
                    "observed_configuration_hash": "0x" + "64" * 32,
                }
            )
            _write(lifecycle_support_path, lifecycle_support)
            lifecycle["evidence_sha256"] = _sha256(lifecycle_support_path)

        self._mutate_complete(
            stage_reviewed_pending_authority,
            "candidate_identity_dependency_unavailable",
            rebind_grant=True,
        )

        def stage_invalid_pending_review_timestamp(
            root: Path,
            evidence: dict[str, Any],
            path: Path,
            state: dict[str, Any],
        ) -> None:
            stage_reviewed_pending_authority(root, evidence, path, state)
            evidence["classifier_binding"][
                "pending_configuration_authority_disposition"
            ]["reviewed_at"] = "2026-07-24T00:00:00+00:00"

        self._mutate_complete(
            stage_invalid_pending_review_timestamp,
            r"pending_configuration_authority_disposition.*reviewed_at.*not valid",
            rebind_grant=True,
        )

    def test_authority_lifecycle_event_tuple_support_cannot_drift(self) -> None:
        cases = (
            ("accepted_authority", "0x" + "f6" * 20),
            ("acceptance_configuration_revision", 99),
            ("acceptance_configuration_hash", "0x" + "f8" * 32),
        )
        for field, replacement in cases:
            with self.subTest(field=field):
                def drift_lifecycle_support(
                    root: Path,
                    evidence: dict[str, Any],
                    _path: Path,
                    _state: dict[str, Any],
                    field: str = field,
                    replacement: Any = replacement,
                ) -> None:
                    lifecycle = evidence["authority_lifecycle"]
                    support_path = root / lifecycle["evidence_path"]
                    support = _read(support_path)
                    support[field] = replacement
                    _write(support_path, support)
                    lifecycle["evidence_sha256"] = _sha256(support_path)

                self._mutate_complete(
                    drift_lifecycle_support,
                    rf"authority-lifecycle support {field} mismatch",
                )

    def test_authority_lifecycle_reconciles_to_same_finalized_observation(self) -> None:
        def update_lifecycle_binding(
            root: Path,
            evidence: dict[str, Any],
            **changes: Any,
        ) -> None:
            lifecycle = evidence["authority_lifecycle"]
            lifecycle.update(changes)
            support_path = root / lifecycle["evidence_path"]
            support = _read(support_path)
            support.update(changes)
            _write(support_path, support)
            lifecycle["evidence_sha256"] = _sha256(support_path)

        def observation_before_terminal(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            evidence["classifier_binding"].update(
                {
                    "configuration_revision": 12,
                    "configuration_hash": "0x" + "62" * 32,
                }
            )
            state["grant_document"]["classifier_binding"].update(
                {
                    "configuration_revision": 12,
                    "configuration_hash": "0x" + "62" * 32,
                }
            )
            for index in range(2):
                self._update_implementation_binding(
                    root,
                    evidence,
                    state,
                    index,
                    configuration_revision=12,
                    configuration_hash="0x" + "62" * 32,
                )
            update_lifecycle_binding(
                root,
                evidence,
                observed_configuration_revision=12,
                observed_configuration_hash="0x" + "62" * 32,
            )

        self._mutate_complete(
            observation_before_terminal,
            "authority lifecycle revision cannot exceed the finalized classifier observation",
            rebind_grant=True,
        )

        def terminal_authority_mismatch(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            authority = "0x" + "f9" * 20
            evidence["classifier_binding"]["configuration_authority"] = authority
            state["grant_document"]["classifier_binding"][
                "configuration_authority"
            ] = authority
            for index in range(2):
                self._update_implementation_binding(
                    root,
                    evidence,
                    state,
                    index,
                    configuration_authority=authority,
                )
            update_lifecycle_binding(
                root,
                evidence,
                observed_configuration_authority=authority,
            )

        self._mutate_complete(
            terminal_authority_mismatch,
            "authority lifecycle terminal authority does not match the finalized classifier observation",
            rebind_grant=True,
        )

        lifecycle_identity_cases = (
            (
                "record_family_registry",
                "0x" + "fa" * 20,
                "authority lifecycle registry address does not match the classifier host",
            ),
            (
                "observed_chain_id",
                2,
                "authority lifecycle chain/block observation does not match the finalized classifier observation",
            ),
            (
                "observed_block_number",
                19_000_001,
                "authority lifecycle chain/block observation does not match the finalized classifier observation",
            ),
            (
                "observed_block_hash",
                "0x" + "fb" * 32,
                "authority lifecycle chain/block observation does not match the finalized classifier observation",
            ),
            (
                "observed_configuration_revision",
                14,
                "authority lifecycle final revision/hash does not match the finalized classifier observation",
            ),
            (
                "observed_configuration_hash",
                "0x" + "fc" * 32,
                "authority lifecycle final revision/hash does not match the finalized classifier observation",
            ),
        )
        for field, replacement, pattern in lifecycle_identity_cases:
            with self.subTest(field=field):
                self._mutate_complete(
                    lambda root, evidence, _path, _state,
                    field=field, replacement=replacement: update_lifecycle_binding(
                        root,
                        evidence,
                        **{field: replacement},
                    ),
                    pattern,
                )

    def test_source_catalog_registry_topology_is_exact(self) -> None:
        temporary, root = self._fixture()
        try:
            catalog_path = (
                root / "release-artifacts/record-family-authorization-source-catalog.json"
            )
            catalog = _read(catalog_path)
            catalog["host_bindings"][1]["registry_binding"] = "embedded_self"
            _write(catalog_path, catalog)
            with self.assertRaisesRegex(
                checker.RecordFamilyAuthorizationError,
                "source host bindings mismatch",
            ):
                checker.validate_package(root)
        finally:
            temporary.cleanup()

    def test_source_provenance_fields_are_required_resolved_and_digest_bound(
        self,
    ) -> None:
        self._mutate_complete(
            lambda _root, evidence, _path, _state: evidence[
                "implementation_bindings"
            ]["contracts"][0].pop("interface_sha256"),
            r"implementation_bindings.*interface_sha256.*required",
        )

        def nonexistent_metadata_source(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            self._update_implementation_binding(
                root,
                evidence,
                state,
                0,
                source_path=(
                    "smart-contracts/domains/metadata/"
                    "MissingCollectionMetadata.sol"
                ),
                source_sha256="a1" * 32,
            )

        self._mutate_complete(
            nonexistent_metadata_source,
            r"implementation_bindings.*source_path.*StreamCollectionMetadata\.sol.*was expected",
            rebind_grant=True,
        )

        def nonexistent_metadata_interface(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            self._update_implementation_binding(
                root,
                evidence,
                state,
                0,
                interface_path=(
                    "smart-contracts/interfaces/stream/"
                    "IMissingCollectionMetadata.sol"
                ),
                interface_sha256="a2" * 32,
            )

        self._mutate_complete(
            nonexistent_metadata_interface,
            r"implementation_bindings.*interface_path.*IStreamCollectionMetadata\.sol.*was expected",
            rebind_grant=True,
        )

        def wrong_metadata_source_hash(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            self._update_implementation_binding(
                root,
                evidence,
                state,
                0,
                source_sha256="a3" * 32,
            )

        self._mutate_complete(
            wrong_metadata_source_hash,
            r"grant-map implementation_bindings\[0\]\.source file digest mismatch",
            rebind_grant=True,
        )

    def test_source_provenance_rejects_alternate_paths_and_host_transplant(
        self,
    ) -> None:
        def alternate_collection_source(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            original = root / evidence["implementation_bindings"]["contracts"][0][
                "source_path"
            ]
            alternate = root / "smart-contracts/domains/metadata/AlternateCollectionMetadata.sol"
            shutil.copyfile(original, alternate)
            self._update_implementation_binding(
                root,
                evidence,
                state,
                0,
                source_path=alternate.relative_to(root).as_posix(),
                source_sha256=_sha256(alternate),
            )

        self._mutate_complete(
            alternate_collection_source,
            (
                r"grant map artifact.*implementation_bindings.*source_path.*"
                r"StreamCollectionMetadata\.sol.*was expected"
            ),
            rebind_grant=True,
        )

        def transplant_preservation_sources(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            donor = evidence["implementation_bindings"]["contracts"][0]
            self._update_implementation_binding(
                root,
                evidence,
                state,
                1,
                source_path=donor["source_path"],
                source_sha256=donor["source_sha256"],
                interface_path=donor["interface_path"],
                interface_sha256=donor["interface_sha256"],
            )

        self._mutate_complete(
            transplant_preservation_sources,
            r"implementation_bindings.*interface_path.*IStreamPreservationRecords\.sol.*was expected",
            rebind_grant=True,
        )

    def test_embedded_classifier_source_symlink_and_hardlink_aliases_are_rejected(
        self,
    ) -> None:
        temporary, root, evidence, evidence_path, _state = (
            self._complete_evidence_fixture()
        )
        try:
            source_path = (
                root
                / evidence["implementation_bindings"]["contracts"][0]["source_path"]
            )
            outside = root.parent / f"{root.name}-outside-metadata.sol"
            shutil.copyfile(source_path, outside)
            source_path.unlink()
            try:
                source_path.symlink_to(outside)
            except OSError as exc:
                self.skipTest(f"source symlink creation unavailable: {exc}")
            self._expect_complete_failure(
                root,
                evidence,
                evidence_path,
                "symlink, junction, or reparse point",
            )
        finally:
            try:
                outside.unlink(missing_ok=True)
            except UnboundLocalError:
                pass
            temporary.cleanup()

        temporary, root, evidence, evidence_path, state = (
            self._complete_evidence_fixture()
        )
        try:
            row = evidence["implementation_bindings"]["contracts"][0]
            source_path = root / row["source_path"]
            interface_path = root / row["interface_path"]
            source_path.unlink()
            try:
                os.link(interface_path, source_path)
            except OSError as exc:
                self.skipTest(f"source hardlink creation unavailable: {exc}")
            self._update_implementation_binding(
                root,
                evidence,
                state,
                0,
                source_sha256=_sha256(source_path),
            )
            self._rebind_grant_map(root, evidence, state)
            self._expect_complete_failure(
                root,
                evidence,
                evidence_path,
                r"source_bindings\[4\] file digest mismatch",
            )
        finally:
            temporary.cleanup()

    def test_support_files_must_exist_be_nonzero_and_match_bound_content(self) -> None:
        def delete_support(
            _root: Path,
            evidence: dict[str, Any],
            _path: Path,
            _state: dict[str, Any],
        ) -> None:
            (root := _root / evidence["implementation_bindings"]["contracts"][0]["evidence_path"]).unlink()

        self._mutate_complete(
            delete_support,
            "implementation support StreamCollectionMetadata.path does not exist",
        )
        self._mutate_complete(
            lambda _root, evidence, _path, _state: evidence[
                "implementation_bindings"
            ]["contracts"][0].__setitem__("evidence_sha256", "0" * 64),
            r"implementation_bindings.*evidence_sha256.*does not match",
        )

        def mutate_implementation_support(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            _state: dict[str, Any],
        ) -> None:
            row = evidence["implementation_bindings"]["contracts"][0]
            support_path = root / row["evidence_path"]
            support = _read(support_path)
            support["marker"] = "FABRICATED_MARKER"
            _write(support_path, support)
            row["evidence_sha256"] = _sha256(support_path)

        self._mutate_complete(
            mutate_implementation_support,
            "implementation support StreamCollectionMetadata marker mismatch",
        )

    def test_snapshot_lifecycle_and_phase_support_are_content_bound(self) -> None:
        def mutate_bound_support(
            root: Path,
            evidence: dict[str, Any],
            section: str,
            field: str,
            value: Any,
        ) -> None:
            binding = evidence[section]
            support_path = root / binding["evidence_path"]
            support = _read(support_path)
            support[field] = value
            _write(support_path, support)
            binding["evidence_sha256"] = _sha256(support_path)

        cases = (
            (
                lambda root, evidence, _path, _state: mutate_bound_support(
                    root,
                    evidence,
                    "snapshot_intersection",
                    "covered_family_groups",
                    list(reversed(evidence["snapshot_intersection"]["covered_family_groups"])),
                ),
                "snapshot-intersection support family coverage mismatch",
            ),
            (
                lambda root, evidence, _path, _state: mutate_bound_support(
                    root,
                    evidence,
                    "authority_lifecycle",
                    "observed_at_commit",
                    "b" * 40,
                ),
                "authority-lifecycle support observed_at_commit mismatch",
            ),
        )
        for mutation, pattern in cases:
            with self.subTest(pattern=pattern):
                self._mutate_complete(mutation, pattern)

        def mutate_phase_support(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            _state: dict[str, Any],
        ) -> None:
            row = evidence["phases"][0]
            support_path = root / row["evidence_path"]
            support = _read(support_path)
            support["phase"] = "production_release"
            _write(support_path, support)
            row["evidence_sha256"] = _sha256(support_path)

        self._mutate_complete(
            mutate_phase_support,
            "phase support public_beta content mismatch",
        )

    def test_support_headers_bind_candidate_grant_and_target_phase(self) -> None:
        fields = (
            ("candidate_identity_sha256", "f2" * 32, "candidate identity mismatch"),
            ("grant_map_sha256", "f3" * 32, "grant-map digest mismatch"),
            ("target_phase", "production_release", "target_phase mismatch"),
        )
        for field, value, pattern in fields:
            with self.subTest(field=field):
                def mutate(
                    root: Path,
                    evidence: dict[str, Any],
                    _path: Path,
                    _state: dict[str, Any],
                    field: str = field,
                    value: str = value,
                ) -> None:
                    row = evidence["implementation_bindings"]["contracts"][0]
                    support_path = root / row["evidence_path"]
                    support = _read(support_path)
                    support[field] = value
                    _write(support_path, support)
                    row["evidence_sha256"] = _sha256(support_path)

                self._mutate_complete(mutate, pattern)

    def test_review_fields_and_grant_review_must_be_real_and_equal(self) -> None:
        self._mutate_complete(
            lambda _root, evidence, _path, _state: evidence["review"].__setitem__(
                "reviewer", " "
            ),
            r"review.*reviewer.*does not match",
        )
        self._mutate_complete(
            lambda _root, evidence, _path, _state: evidence["review"].__setitem__(
                "reviewed_at", "2026-07-24T01:00:00+01:00"
            ),
            r"evidence does not satisfy its schema.*reviewed_at.*not valid under any",
        )

        def invalid_evidence_review_timestamp(
            _root: Path,
            evidence: dict[str, Any],
            _path: Path,
            _state: dict[str, Any],
        ) -> None:
            evidence["review"]["reviewed_at"] = "2026-99-99T99:99:99Z"

        self._mutate_complete(
            invalid_evidence_review_timestamp,
            r"evidence does not satisfy its schema.*reviewed_at.*not valid under any",
        )

        def invalid_grant_review_timestamp(
            _root: Path,
            _evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            state["grant_document"]["independent_review"][
                "reviewed_at"
            ] = "2026-99-99T99:99:99Z"

        self._mutate_complete(
            invalid_grant_review_timestamp,
            (
                r"grant map artifact.*independent_review.*reviewed_at.*"
                r"does not match"
            ),
            rebind_grant=True,
        )
        def non_https_review(
            _root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
        ) -> None:
            reference = "review://not-retained"
            evidence["review"]["reference"] = reference
            state["grant_document"]["independent_review"][
                "reference"
            ] = reference

        self._mutate_complete(
            non_https_review,
            "review.reference must be a retained HTTPS review record",
            rebind_grant=True,
        )

        self._mutate_complete(
            lambda _root, _evidence, _path, state: state["grant_document"][
                "independent_review"
            ].__setitem__("reviewer", "different-reviewer"),
            "grant-map independent review does not match the retained envelope",
            rebind_grant=True,
        )
        self._mutate_complete(
            lambda _root, _evidence, _path, state: state["grant_document"][
                "independent_review"
            ].__setitem__("reviewer", " "),
            r"grant map artifact.*independent_review.*reviewer.*does not match",
            rebind_grant=True,
        )

    def test_complete_paths_reject_case_dot_space_device_and_unicode_aliases(
        self,
    ) -> None:
        cases = (
            (
                "Deployments/record-family-authorization/implementation-1-support.json",
                "exact on-disk path casing",
            ),
            (
                r"deployments\record-family-authorization\implementation-1-support.json",
                "normalized portable repository-relative path",
            ),
            (
                "deployments/./record-family-authorization/implementation-1-support.json",
                "normalized portable repository-relative path",
            ),
            (
                "deployments/../record-family-authorization/implementation-1-support.json",
                "normalized portable repository-relative path",
            ),
            (
                "deployments/record-family-authorization./implementation-1-support.json",
                "leading/trailing space or dot aliases",
            ),
            (
                "deployments/record-family-authorization /implementation-1-support.json",
                "leading/trailing space or dot aliases",
            ),
            (
                "deployments/CON/implementation-1-support.json",
                "Windows device-name alias",
            ),
            (
                "RELEAS~1/implementation-1-support.json",
                "DOS 8.3 short-name alias",
            ),
            (
                "deployments/record-family-authorization/cafe\u0301.json",
                "canonical NFC Unicode",
            ),
        )
        for raw_path, pattern in cases:
            with self.subTest(raw_path=raw_path):
                self._mutate_complete(
                    lambda _root, evidence, _path, _state, raw_path=raw_path: evidence[
                        "implementation_bindings"
                    ]["contracts"][0].__setitem__("evidence_path", raw_path),
                    pattern,
                )

    def test_complete_support_symlink_or_reparse_is_rejected(self) -> None:
        temporary, root, evidence, evidence_path, state = (
            self._complete_evidence_fixture()
        )
        try:
            support_path = state["support_paths"]["lifecycle"]
            outside = root.parent / f"{root.name}-outside-lifecycle.json"
            shutil.copyfile(support_path, outside)
            support_path.unlink()
            try:
                support_path.symlink_to(outside)
            except OSError as exc:
                self.skipTest(f"symlink creation unavailable: {exc}")
            self._expect_complete_failure(
                root,
                evidence,
                evidence_path,
                "symlink, junction, or reparse point",
            )
        finally:
            try:
                outside.unlink(missing_ok=True)
            except UnboundLocalError:
                pass
            temporary.cleanup()

    def test_complete_support_junction_is_rejected_on_windows(self) -> None:
        if os.name != "nt":
            self.skipTest("directory junction hostile is Windows-specific")
        temporary, root, evidence, evidence_path, state = (
            self._complete_evidence_fixture()
        )
        try:
            target_dir = root / "deployments/record-family-authorization"
            junction = root / "deployments/record-family-authorization-junction"
            completed = subprocess.run(
                ["cmd", "/c", "mklink", "/J", str(junction), str(target_dir)],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
                text=True,
            )
            if completed.returncode != 0:
                self.skipTest(
                    f"junction creation unavailable: {completed.stderr.strip()}"
                )
            actual = state["support_paths"]["implementation_0"]
            evidence["implementation_bindings"]["contracts"][0][
                "evidence_path"
            ] = (junction / actual.name).relative_to(root).as_posix()
            self._expect_complete_failure(
                root,
                evidence,
                evidence_path,
                "symlink, junction, or reparse point",
            )
        finally:
            if "junction" in locals() and junction.exists():
                subprocess.run(
                    ["cmd", "/c", "rmdir", str(junction)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                )
            temporary.cleanup()

    def test_complete_support_hardlink_collision_is_rejected_where_supported(
        self,
    ) -> None:
        temporary, root, evidence, evidence_path, state = (
            self._complete_evidence_fixture()
        )
        try:
            lifecycle_path = state["support_paths"]["lifecycle"]
            phase_path = state["support_paths"]["phase_public_beta"]
            phase_path.unlink()
            try:
                os.link(lifecycle_path, phase_path)
            except OSError as exc:
                self.skipTest(f"hardlink creation unavailable: {exc}")
            evidence["phases"][0]["evidence_sha256"] = _sha256(phase_path)
            self._expect_complete_failure(
                root,
                evidence,
                evidence_path,
                "phase support public_beta must be a distinct file from authority-lifecycle support",
            )
        finally:
            temporary.cleanup()

    def test_all_complete_bound_files_reject_hardlink_alias_to_release_tail(
        self,
    ) -> None:
        cases = (
            (
                "inventory",
                lambda root, _evidence, _path, _state: (
                    root / checker.DEFAULT_INVENTORY
                ),
            ),
            (
                "evidence envelope",
                lambda _root, _evidence, path, _state: path,
            ),
            (
                "candidate identity projection",
                lambda _root, _evidence, _path, state: state[
                    "candidate_path"
                ],
            ),
            (
                "genesis profile",
                lambda root, _evidence, _path, _state: (
                    root / "release-artifacts/genesis-deployment-profile.json"
                ),
            ),
            (
                "grant map",
                lambda _root, _evidence, _path, state: state[
                    "grant_path"
                ],
            ),
            (
                "implementation support",
                lambda _root, _evidence, _path, state: state[
                    "support_paths"
                ]["implementation_0"],
            ),
            (
                "implementation source",
                lambda root, evidence, _path, _state: (
                    root
                    / evidence["implementation_bindings"]["contracts"][0][
                        "source_path"
                    ]
                ),
            ),
            (
                "implementation interface",
                lambda root, evidence, _path, _state: (
                    root
                    / evidence["implementation_bindings"]["contracts"][0][
                        "interface_path"
                    ]
                ),
            ),
            (
                "snapshot-intersection support",
                lambda _root, _evidence, _path, state: state[
                    "support_paths"
                ]["snapshot"],
            ),
            (
                "authority-lifecycle support",
                lambda _root, _evidence, _path, state: state[
                    "support_paths"
                ]["lifecycle"],
            ),
            (
                "phase support public_beta",
                lambda _root, _evidence, _path, state: state[
                    "support_paths"
                ]["phase_public_beta"],
            ),
        )
        for label, select_path in cases:
            with self.subTest(label=label):
                temporary, root, evidence, evidence_path, state = (
                    self._complete_evidence_fixture()
                )
                try:
                    target = select_path(root, evidence, evidence_path, state)
                    forbidden = (
                        root
                        / "release-artifacts/latest/release-manifest.json"
                    )
                    forbidden.parent.mkdir(parents=True, exist_ok=True)
                    try:
                        os.link(target, forbidden)
                    except OSError as exc:
                        self.skipTest(
                            f"hardlink creation unavailable: {exc}"
                        )
                    self._expect_complete_failure(
                        root,
                        evidence,
                        evidence_path,
                        (
                            rf"{re.escape(label)}(?: [A-Za-z0-9_]+)? "
                            r"must not alias forbidden "
                            r"release output.*release-manifest\.json"
                        ),
                    )
                finally:
                    temporary.cleanup()

    def test_complete_bound_file_rejects_hardlink_alias_to_any_release_tail_file(
        self,
    ) -> None:
        temporary, root, evidence, evidence_path, state = (
            self._complete_evidence_fixture()
        )
        try:
            target = state["support_paths"]["phase_public_beta"]
            forbidden = root / "release-artifacts/latest/abi-checksums.json"
            forbidden.parent.mkdir(parents=True, exist_ok=True)
            try:
                os.link(target, forbidden)
            except OSError as exc:
                self.skipTest(f"hardlink creation unavailable: {exc}")
            self._expect_complete_failure(
                root,
                evidence,
                evidence_path,
                (
                    r"phase support public_beta must not alias forbidden "
                    r"release output.*abi-checksums\.json"
                ),
            )
        finally:
            temporary.cleanup()

    def test_release_tail_child_junction_is_rejected_before_recursion(
        self,
    ) -> None:
        if os.name != "nt":
            self.skipTest("directory junction hostile is Windows-specific")
        temporary, root, evidence, evidence_path, _state = (
            self._complete_evidence_fixture()
        )
        outside = tempfile.TemporaryDirectory()
        junction = root / "release-artifacts/latest/junction"
        try:
            outside_path = Path(outside.name)
            _write(outside_path / "outside.json", {"outside": True})
            junction.parent.mkdir(parents=True, exist_ok=True)
            completed = subprocess.run(
                [
                    "cmd",
                    "/c",
                    "mklink",
                    "/J",
                    str(junction),
                    str(outside_path),
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            if completed.returncode != 0:
                self.skipTest(
                    f"junction creation unavailable: {completed.stderr.strip()}"
                )
            self._expect_complete_failure(
                root,
                evidence,
                evidence_path,
                (
                    r"release output release-artifacts/latest/junction "
                    r"must not be a symlink, junction, or reparse point"
                ),
            )
        finally:
            if junction.exists():
                subprocess.run(
                    ["cmd", "/c", "rmdir", str(junction)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                )
            outside.cleanup()
            temporary.cleanup()

    def test_release_tail_lstat_error_is_rejected(self) -> None:
        class ErroringPath:
            def __fspath__(self) -> str:
                raise PermissionError("hostile reserved-artifact inspection error")

        with self.assertRaisesRegex(
            checker.RecordFamilyAuthorizationError,
            r"cannot inspect hostile release-tail path",
        ):
            checker._lstat_or_missing(
                ErroringPath(),  # type: ignore[arg-type]
                "hostile release-tail path",
            )

    def test_reserved_envelope_and_grant_paths_are_role_bound(self) -> None:
        def bind_phase_support_to_reserved(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
            *,
            phase_index: int,
            source_key: str,
            reserved_path: Path,
        ) -> None:
            source = state["support_paths"][source_key]
            target = root / reserved_path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            evidence["phases"][phase_index]["evidence_path"] = (
                reserved_path.as_posix()
            )
            evidence["phases"][phase_index]["evidence_sha256"] = _sha256(
                target
            )

        self._mutate_complete(
            lambda root, evidence, path, state: bind_phase_support_to_reserved(
                root,
                evidence,
                path,
                state,
                phase_index=0,
                source_key="phase_public_beta",
                reserved_path=Path(
                    "deployments/record-family-authorization/"
                    "production-release-record-family-authorization-"
                    "evidence.json"
                ),
            ),
            "reserved record-family artifact path is forbidden",
        )
        self._mutate_complete(
            lambda root, evidence, path, state: bind_phase_support_to_reserved(
                root,
                evidence,
                path,
                state,
                phase_index=0,
                source_key="phase_public_beta",
                reserved_path=Path(
                    "deployments/record-family-authorization/"
                    "production-release-record-family-authorization-"
                    "grant-map.json"
                ),
            ),
            "reserved record-family artifact path is forbidden",
        )
        self._mutate_complete(
            lambda root, evidence, path, state: bind_phase_support_to_reserved(
                root,
                evidence,
                path,
                state,
                phase_index=1,
                source_key="phase_production_release",
                reserved_path=Path(
                    "deployments/record-family-authorization/"
                    "public-beta-record-family-authorization-grant-map.json"
                ),
            ),
            "reserved record-family artifact path is forbidden",
            target_phase="production_release",
        )

    def test_reserved_artifact_hardlink_alias_is_rejected(self) -> None:
        temporary, root, evidence, evidence_path, state = (
            self._complete_evidence_fixture()
        )
        try:
            reserved = (
                root
                / "deployments/record-family-authorization/"
                "production-release-record-family-authorization-evidence.json"
            )
            reserved.parent.mkdir(parents=True, exist_ok=True)
            try:
                os.link(state["candidate_path"], reserved)
            except OSError as exc:
                self.skipTest(f"hardlink creation unavailable: {exc}")
            self._expect_complete_failure(
                root,
                evidence,
                evidence_path,
                (
                    "candidate identity projection must not alias forbidden "
                    "release output.*production-release-record-family-"
                    "authorization-evidence\\.json"
                ),
            )
        finally:
            temporary.cleanup()

    def test_support_paths_reject_generated_tail_and_wrong_namespace(self) -> None:
        def move_phase_support(
            root: Path,
            evidence: dict[str, Any],
            _path: Path,
            state: dict[str, Any],
            destination: Path,
        ) -> None:
            source = state["support_paths"]["phase_public_beta"]
            target = root / destination
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            evidence["phases"][0]["evidence_path"] = destination.as_posix()
            evidence["phases"][0]["evidence_sha256"] = _sha256(target)

        self._mutate_complete(
            lambda root, evidence, path, state: move_phase_support(
                root,
                evidence,
                path,
                state,
                Path("release-artifacts/latest/abi-checksums.json"),
            ),
            "generated release-tail evidence path is forbidden",
        )
        self._mutate_complete(
            lambda root, evidence, path, state: move_phase_support(
                root,
                evidence,
                path,
                state,
                Path("docs/phase-support.json"),
            ),
            "must remain in the dedicated record-family authorization namespace",
        )


if __name__ == "__main__":
    unittest.main()

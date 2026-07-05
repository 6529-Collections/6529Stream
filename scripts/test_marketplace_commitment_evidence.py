#!/usr/bin/env python3
"""Focused tests for the W1-signal commitment evidence checker."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_marketplace_commitment_evidence.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location(
    "check_marketplace_commitment_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8", newline="\n")


MANIFEST = {
    "schema": checker.MANIFEST_SCHEMA,
    "targets": [
        {"targetId": "alpha", "name": "Alpha", "resolutionMechanism": "api"},
        {"targetId": "beta", "name": "Beta", "resolutionMechanism": "contract-metadata"},
        {"targetId": "gamma-indexer", "name": "Gamma", "resolutionMechanism": "api"},
    ],
    "topTwo": ["alpha", "beta"],
    "majorIndependentIndexers": ["gamma-indexer"],
}


def commitment(counterparty: str, **overrides) -> dict:
    payload = {
        "counterpartyId": counterparty,
        "signerIdentity": "Jane Signer, Head of Integrations",
        "date": "2026-07-01",
        "scope": {
            "w1CollectionIdentitySignal": True,
            "perCollectionIdentityRendering": True,
        },
        "authenticity": {"method": "pgp-signature", "reference": "sig.asc"},
        "artifactHash": "0x" + "ab" * 32,
    }
    payload.update(overrides)
    return payload


def evidence(commitments: list[dict], **extra) -> dict:
    payload = {
        "schema": checker.EVIDENCE_SCHEMA,
        "targetManifest": "marketplace-target-manifest.json",
        "commitments": commitments,
    }
    payload.update(extra)
    return payload


def fixture(root: Path, payload: dict) -> Path:
    write(root / "marketplace-target-manifest.json", MANIFEST)
    path = root / "commitments.json"
    write(path, payload)
    return path


class CommitmentEvidenceTests(unittest.TestCase):
    def test_committed_repo_has_no_commitment_evidence_yet(self) -> None:
        self.assertFalse((REPO_ROOT / checker.DEFAULT_EVIDENCE_PATH).exists())

    def test_accepts_two_qualifying_commitments_with_top_two_member(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = fixture(root, evidence([commitment("alpha"), commitment("gamma-indexer")]))
            total, qualifying = checker.validate_evidence(root, path)
            self.assertEqual((total, qualifying), (2, 2))

    def test_rejects_unqualified_counterparty_and_conversation_only(self) -> None:
        bad = [
            commitment("unknown-venue"),
            commitment("alpha", conversationOnly=True),
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = fixture(root, evidence(bad))
            with self.assertRaises(checker.CommitmentEvidenceError) as ctx:
                checker.validate_evidence(root, path)
            message = str(ctx.exception)
            self.assertIn("not in the rule 1 pinned", message)
            self.assertIn("conversation-only", message)

    def test_rejects_two_commitments_without_privileged_source(self) -> None:
        manifest = dict(MANIFEST, topTwo=["beta"], majorIndependentIndexers=["beta"])
        payload = evidence([commitment("alpha"), commitment("alpha")])
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(root / "marketplace-target-manifest.json", manifest)
            path = root / "commitments.json"
            write(path, payload)
            with self.assertRaises(checker.CommitmentEvidenceError) as ctx:
                checker.validate_evidence(root, path)
            self.assertIn("tripwire", str(ctx.exception))

    def test_accepts_unmet_gate_with_valid_tripwire_and_risk_acceptance(self) -> None:
        payload = evidence(
            [commitment("alpha")],
            tripwire={
                "fcpDeploymentDecisionRecord": {
                    "recordHash": "0x" + "cd" * 32,
                    "outcome": "no-go",
                },
                "facadeBound": False,
                "riskAcceptance": {
                    "ownerSignature": "0x" + "ef" * 32,
                    "unmetCommitmentCount": 1,
                    "outreachRecord": "outreach.md",
                    "acceptedExposure": "per-collection display exposure",
                },
            },
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = fixture(root, payload)
            total, qualifying = checker.validate_evidence(root, path)
            self.assertEqual((total, qualifying), (1, 1))

    def test_rejects_no_go_tripwire_without_risk_acceptance(self) -> None:
        payload = evidence(
            [commitment("alpha")],
            tripwire={
                "fcpDeploymentDecisionRecord": {
                    "recordHash": "0x" + "cd" * 32,
                    "outcome": "no-go",
                },
                "facadeBound": False,
            },
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = fixture(root, payload)
            with self.assertRaises(checker.CommitmentEvidenceError) as ctx:
                checker.validate_evidence(root, path)
            self.assertIn("risk-acceptance record missing", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Validate W1-signal integration commitments ([LCM-MARKETPLACE] rule 7).

The commitment-evidence row of the Verification Tooling Backlog
(docs/launch-conformance-matrix.md [LCM-TOOLING]; [LCM-MARKETPLACE]
rule 7; ADR 0015 decision W2) validates every recorded
collection-identity integration commitment against the rule 7 evidence
class and its pinned counterparty qualification, and the marketplace
integration commitments gate consumes the result.

Neither the pinned marketplace-target manifest ([LCM-MARKETPLACE]
rule 1) nor any commitment artifact exists yet; until the evidence lands
at ``release-artifacts/latest/marketplace-integration-commitments.json``
this checker passes with a note. The JSON evidence schema is defined
conservatively from the rule text:

- top-level: ``schema`` ``6529.stream.marketplace-commitments.v1``,
  ``targetManifest`` (repo-relative path to the rule 1 pinned manifest),
  ``commitments`` list, optional ``tripwire`` record.
- per commitment: ``counterpartyId`` (a rule 1 manifest target),
  ``signerIdentity``, ``date`` (ISO), ``scope`` covering both
  ``w1CollectionIdentitySignal`` and ``perCollectionIdentityRendering``,
  ``authenticity`` (``method`` plus ``reference``), and ``artifactHash``
  hash coverage. Best-effort/conversation-only artifacts
  (``bestEffortOnly``/``conversationOnly`` true, or a missing signer)
  are unqualifying.
- gate: at least two qualifying commitments with at least one from a
  rule 1 top-two target or a named major independent indexer; otherwise
  the recorded ``tripwire`` must carry the [FCP-DEPLOYMENT] decision
  record and, on a no-go or a go with no facade bound, the rule
  6-pattern owner-signed risk-acceptance record naming the unmet count,
  the outreach record, and the accepted exposure.

The pinned marketplace-target manifest schema (rule 1):
``{"schema": "6529.stream.marketplace-target-manifest.v1", "targets":
[{"targetId", "name", "resolutionMechanism"}], "topTwo": [ids],
"majorIndependentIndexers": [ids]}`` with at least three targets.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import ascii_safe  # noqa: E402


DEFAULT_EVIDENCE_PATH = Path(
    "release-artifacts/latest/marketplace-integration-commitments.json"
)
EVIDENCE_SCHEMA = "6529.stream.marketplace-commitments.v1"
MANIFEST_SCHEMA = "6529.stream.marketplace-target-manifest.v1"
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}")
HASH_RE = re.compile(r"^(0x)?[0-9a-fA-F]{64}$")
REQUIRED_SCOPE = ("w1CollectionIdentitySignal", "perCollectionIdentityRendering")
MINIMUM_TARGETS = 3
REQUIRED_COMMITMENTS = 2


class CommitmentEvidenceError(RuntimeError):
    """Raised when recorded commitments fail the rule 7 evidence class."""


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise CommitmentEvidenceError(f"{path}: unreadable JSON: {exc}") from exc


def load_target_manifest(repo_root: Path, evidence: dict) -> dict:
    manifest_ref = evidence.get("targetManifest")
    if not manifest_ref:
        raise CommitmentEvidenceError(
            "evidence names no targetManifest ([LCM-MARKETPLACE] rule 1 pinned "
            "manifest)"
        )
    manifest = load_json(repo_root / Path(manifest_ref))
    if manifest.get("schema") != MANIFEST_SCHEMA:
        raise CommitmentEvidenceError(
            f"target manifest schema {manifest.get('schema')!r} is not "
            f"{MANIFEST_SCHEMA!r}"
        )
    targets = manifest.get("targets", [])
    if len(targets) < MINIMUM_TARGETS:
        raise CommitmentEvidenceError(
            f"target manifest pins {len(targets)} targets; rule 1 requires at "
            f"least {MINIMUM_TARGETS}"
        )
    return manifest


def commitment_disqualifiers(commitment: dict, target_ids: set[str]) -> list[str]:
    """Reasons a recorded commitment fails the rule 7 evidence class."""
    reasons: list[str] = []
    counterparty = commitment.get("counterpartyId")
    if not counterparty:
        reasons.append("no named counterparty")
    elif counterparty not in target_ids:
        reasons.append(
            f"counterparty {counterparty!r} is not in the rule 1 pinned "
            "marketplace-target manifest"
        )
    if not commitment.get("signerIdentity"):
        reasons.append("no signer identity (intent statements do not qualify)")
    date = commitment.get("date", "")
    if not DATE_RE.match(str(date)):
        reasons.append("no parseable date")
    scope = commitment.get("scope", {})
    for scope_key in REQUIRED_SCOPE:
        if not scope.get(scope_key):
            reasons.append(f"scope does not cover {scope_key}")
    authenticity = commitment.get("authenticity", {})
    if not authenticity.get("method") or not authenticity.get("reference"):
        reasons.append("no verifiable authenticity method and reference")
    artifact_hash = commitment.get("artifactHash", "")
    if not HASH_RE.match(str(artifact_hash)):
        reasons.append("no hash coverage over the written artifact")
    if commitment.get("bestEffortOnly") or commitment.get("conversationOnly"):
        reasons.append(
            "best-effort outreach and conversation-only records are unqualifying"
        )
    return reasons


def validate_tripwire(evidence: dict) -> list[str]:
    """Validate the tripwire branch when the two-commitment gate is unmet."""
    tripwire = evidence.get("tripwire")
    if not isinstance(tripwire, dict):
        return [
            "two-commitment gate unmet with no recorded tripwire outcome "
            "([FCP-DEPLOYMENT]; ADR 0015 decision W3)"
        ]
    failures: list[str] = []
    decision = tripwire.get("fcpDeploymentDecisionRecord", {})
    if not decision.get("recordHash") or decision.get("outcome") not in {"go", "no-go"}:
        failures.append(
            "tripwire lacks the [FCP-DEPLOYMENT] decision record (recordHash "
            "plus go/no-go outcome)"
        )
        return failures
    needs_risk_acceptance = decision["outcome"] == "no-go" or not tripwire.get(
        "facadeBound"
    )
    if needs_risk_acceptance:
        risk = tripwire.get("riskAcceptance", {})
        for field in ("ownerSignature", "unmetCommitmentCount", "outreachRecord", "acceptedExposure"):
            if not risk.get(field):
                failures.append(
                    f"rule 6-pattern risk-acceptance record missing {field!r}"
                )
    return failures


def validate_evidence(repo_root: Path, path: Path) -> tuple[int, int]:
    evidence = load_json(path)
    if evidence.get("schema") != EVIDENCE_SCHEMA:
        raise CommitmentEvidenceError(
            f"evidence schema {evidence.get('schema')!r} is not {EVIDENCE_SCHEMA!r}"
        )
    manifest = load_target_manifest(repo_root, evidence)
    target_ids = {target.get("targetId") for target in manifest.get("targets", [])}
    privileged = set(manifest.get("topTwo", [])) | set(
        manifest.get("majorIndependentIndexers", [])
    )
    if not privileged:
        raise CommitmentEvidenceError(
            "target manifest pins no top-two targets or major independent "
            "indexers ([LCM-MARKETPLACE] rule 7 qualification)"
        )
    commitments = evidence.get("commitments", [])
    failures: list[str] = []
    qualifying: list[dict] = []
    for position, commitment in enumerate(commitments):
        reasons = commitment_disqualifiers(commitment, target_ids)
        if reasons:
            label = commitment.get("counterpartyId") or f"commitment[{position}]"
            failures.extend(f"{label}: {reason}" for reason in reasons)
        else:
            qualifying.append(commitment)
    gate_met = len(qualifying) >= REQUIRED_COMMITMENTS and any(
        commitment["counterpartyId"] in privileged for commitment in qualifying
    )
    if not gate_met:
        # The tripwire outcome clears the gate shortfall (never the
        # per-commitment evidence-class failures recorded above).
        failures.extend(validate_tripwire(evidence))
    if failures:
        unique = sorted(set(failures))
        details = "\n  - ".join(unique)
        raise CommitmentEvidenceError(
            f"commitment evidence failed with {len(unique)} failure(s):"
            f"\n  - {details}"
        )
    return len(commitments), len(qualifying)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=Path(__file__).resolve().parent.parent,
        type=Path,
        help="Repository root to validate.",
    )
    parser.add_argument(
        "--evidence",
        type=Path,
        default=None,
        help=(
            "Evidence path override (default: "
            "release-artifacts/latest/marketplace-integration-commitments.json)."
        ),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    evidence_path = args.evidence or (args.repo_root / DEFAULT_EVIDENCE_PATH)
    if not evidence_path.exists():
        print(
            "commitment evidence check passes vacuously: no W1-signal "
            "integration commitments are recorded yet at "
            f"{DEFAULT_EVIDENCE_PATH.as_posix()} (the gate binds before the "
            "first public sale; [LCM-MARKETPLACE] rule 7)"
        )
        return 0
    try:
        total, qualifying = validate_evidence(args.repo_root, evidence_path)
    except CommitmentEvidenceError as exc:
        print(ascii_safe(f"commitment evidence check failed: {exc}"), file=sys.stderr)
        return 1
    print(
        f"commitment evidence is current: {qualifying} qualifying of {total} "
        "recorded commitments"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

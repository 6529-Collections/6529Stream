#!/usr/bin/env python3
"""Fail-closed checker for the proposed artist shared-mechanics decision register."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any

from jsonschema import Draft202012Validator

PACKET_PATH = Path(
    "docs/architecture/artist-operation-shared-mechanics-freeze-v1.json"
)
SCHEMA_PATH = Path(
    "docs/architecture/artist-operation-shared-mechanics-freeze-v1.schema.json"
)
MATRIX_PATH = Path("docs/architecture/artist-semantic-owner-matrix-v2.json")
ARTIST_SOURCE_ROOT = Path("smart-contracts/domains/artist")
COORDINATOR_INTERFACE_PATH = Path(
    "smart-contracts/interfaces/stream/IStreamArtistOperationCoordinator.sol"
)

PACKET_SCHEMA = "6529stream.artist-operation-shared-mechanics-freeze.v1"
PACKET_STATUS = "PROPOSED_PARTIAL_DECISION_RESOLUTION"
PACKET_MATURITY = "pre_audit_source_blocked"
JSON_SCHEMA_ID = (
    "https://6529.io/schemas/artist-operation-shared-mechanics-freeze-v1.schema.json"
)
EVALUATED_COMMIT = "eef6a4cc5070186cc6517cca90bd9ffe1f74ea06"
EVALUATED_TREE = "1a56c7b27ed304f96f551d1bebd0aa93a4ee164e"
SCHEMA_SHA256 = "d61b29f63c662494047fc1b30bf72035ab7d586a23fe45c2bb6f2d8a0ae795b0"
SELECTED_SHAPE_SHA256 = "9417c5fe3f8187ab75463384b1ef0932233369b097de459df5d10f86e80cc11b"
PHASE_ORDER_SHA256 = "9faa90a8cd9027448dfdf344f23c9719ad0488e9f79d3a78f4fd40adab7075aa"
FIXED_INVARIANTS_SHA256 = "5e4ae8a539187ab0c29969f189d956b41c2002ac046e80023644e85c19381543"
OPERATION_PROJECTION_SHA256 = "027cc006e9ea5248c0ed4ff573dc52d594a72ddf73036b3c62745d843f673120"
DECISION_ROWS_SHA256 = "163d573fef499772e7cbf56080b78bff0eff1e60693033c8535e3ba9e96b75f9"
GATE_STATE_SHA256 = "f76ff6d113b0fde161464ab70ee84dc00022c322bb53b3b0bb8e20036aa5cf12"
EXCLUSIONS_SHA256 = "3d917a006edccebf17dd61967de693dd8f75e44273cbd9117419fc14cb8a01bc"

TOP_LEVEL_FIELDS = frozenset(
    {
        "schema",
        "status",
        "maturity",
        "evaluated_base",
        "authority_bindings",
        "selected_shape",
        "phase_order",
        "fixed_invariants",
        "operation_projection",
        "decision_rows",
        "gate_state",
        "exclusions",
    }
)

MARKDOWN_HEADING_RE = re.compile(r"^[ ]{0,3}(#{1,6})[ \t]+(.+?)[ \t]*$")
MARKDOWN_FENCE_RE = re.compile(r"^[ ]{0,3}(`{3,}|~{3,})(.*)$")
MARKDOWN_FENCE_CLOSE_RE = re.compile(r"^[ ]{0,3}(`+|~+)[ \t]*$")

EXPECTED_AUTHORITY_BINDINGS = (
    (
        "coordinator_source_gate",
        "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md",
        "df2f039ee0a8991cba38da084d2e41158bb857cfa005d8fcad45b30d592b727a",
    ),
    (
        "adr_0023",
        "docs/adr/0023-modular-artist-authority-domain-ownership.md",
        "b3a7f322518aeb63638572486292be511f67202e09db58471ac867eb3fa8c113",
    ),
    (
        "semantic_owner_matrix",
        "docs/architecture/artist-semantic-owner-matrix-v2.json",
        "bc4b55c68c504ee7d74965d7fa0d1edbe6de816e567e076442781b81232320a2",
    ),
    (
        "semantic_owner_matrix_schema",
        "docs/architecture/artist-semantic-owner-matrix-v2.schema.json",
        "b242c5480ecdf8e4aa57dc02d76fd8cd81631298eeda0b96cbba9b036d72b473",
    ),
    (
        "semantic_owner_matrix_checker",
        "scripts/check_artist_semantic_owner_matrix.py",
        "75be5171655556711282de41a3feb909b0a9fdded45c565f66597d984427152b",
    ),
    (
        "semantic_owner_matrix_tests",
        "scripts/test_artist_semantic_owner_matrix.py",
        "126269436e56b83f9e996b9b1e0961ebac08740a38a8e9789c70c302a8b0654f",
    ),
    (
        "archive_v2_implementation",
        "smart-contracts/domains/artist/StreamArtistArchiveV2.sol",
        "1228ef5451258927b8141a842c437d4738f41fb66bbfff57e805919252552778",
    ),
    (
        "archive_v2_interface",
        "smart-contracts/interfaces/stream/IStreamArtistArchiveV2.sol",
        "2e488c13527383b63864eb484203e2fed6349def941043ca9435cc728a29a80e",
    ),
    (
        "registry_v2_implementation",
        "smart-contracts/domains/artist/StreamArtistRegistryV2.sol",
        "038560c0a8811b7ed4a816d011813d9c529e16091bd646f153c63390578a2430",
    ),
    (
        "registry_v2_interface",
        "smart-contracts/interfaces/stream/IStreamArtistRegistryV2.sol",
        "6b56d095a7abdde99967c18ebef1c089ef91e9cff1c5477c2c1cc5d601059a54",
    ),
)

EXPECTED_DECISION_PHASES = (
    ("entrypoint_abi", "shared_mechanics"),
    ("registry_ingress", "shared_mechanics"),
    ("original_caller", "shared_mechanics"),
    ("owner_snapshots", "owner_domain_packets"),
    ("owner_mutations", "owner_domain_packets"),
    ("owner_storage", "owner_domain_packets"),
    ("replay_keys", "shared_mechanics"),
    ("normative_owner_events", "owner_domain_packets"),
    ("provider_reads", "shared_mechanics"),
    ("role_authority", "shared_mechanics"),
    ("signer_validation", "shared_mechanics"),
    ("recipe_commitment", "shared_mechanics"),
    ("archive_evidence", "shared_mechanics"),
    ("composite_manifest", "shared_mechanics"),
    ("operation_lock", "shared_mechanics"),
    ("construction", "shared_mechanics"),
    ("errors", "cross_surface_closure"),
    ("native_value", "shared_mechanics"),
    ("gas_and_call_discipline", "shared_mechanics"),
)

EXPECTED_ACCEPTED_DECISIONS = (
    "registry_ingress",
    "original_caller",
    "native_value",
)
EXPECTED_REGISTRY_INGRESS_OPTION = "immutable_registry_only_typed_facade_v1"
EXPECTED_REGISTRY_INGRESS_OPTION_DISPOSITIONS = (
    ("direct_coordinator_ingress", "rejected"),
    ("dual_registry_and_direct_ingress", "rejected"),
    ("caller_supplied_original_caller", "rejected"),
    ("trusted_forwarder_or_meta_transaction_ingress", "rejected"),
    ("generic_selector_or_calldata_dispatch", "rejected"),
    ("immutable_registry_only_typed_facade_v1", "accepted"),
)
EXPECTED_REGISTRY_INGRESS_VALUES = {
    "registry_ingress_mode": "immutable_registry_only_typed_facade",
    "registry_entrypoint_count": 57,
    "registry_entrypoint_mutability": "external_nonpayable",
    "registry_captures_immediate_msg_sender": True,
    "registry_original_caller_input_present": False,
    "coordinator_entrypoint_count": 57,
    "coordinator_first_common_argument_type": "address",
    "coordinator_first_common_argument_name": "originalCaller",
    "coordinator_requires_immutable_registry_sender": True,
    "coordinator_requires_nonzero_original_caller": True,
    "direct_coordinator_ingress": False,
    "dual_ingress": False,
    "trusted_forwarder_ingress": False,
    "generic_dispatch": False,
}
EXPECTED_REGISTRY_INGRESS_OBLIGATIONS = {
    "encoding_obligations": (
        "each of the 57 Registry facade entries is typed, external and nonpayable and has no caller-supplied originalCaller field",
        "each of the 57 matching typed Coordinator operation projections has the same first common argument address originalCaller while its selector, remaining parameters and returns remain unresolved",
        "Registry and Coordinator expose no generic selector, calldata, fallback or receive surface and authorize no direct or alternate ingress path",
    ),
    "call_obligations": (
        "Registry captures its immediate msg.sender and forwards that same address as originalCaller to the one immutably bound Coordinator",
        "Coordinator accepts every typed operation only from its immutable Registry and rejects address zero originalCaller before snapshots, calls or effects",
        "direct callers, a fake Registry, a substituted Registry authority and caller injection never reach an owner, provider, validator or Archive call",
    ),
    "error_obligations": (
        "direct or fake-Registry Coordinator ingress rejects before any state, event, evidence or collaborator effect without selecting an exact custom-error ABI in this packet",
        "zero originalCaller rejects before any state, event, evidence or collaborator effect without selecting an exact custom-error ABI in this packet, while caller-supplied or altered Registry forwarding fails exact source and trace acceptance",
        "unknown selectors, generic calldata and alternate ingress have no effect and remain rejected by the absent fallback, receive and generic-routing surfaces",
    ),
    "test_obligations": (
        "for every one of 57 operation projections prove Registry-only typed nonpayable ingress, immediate msg.sender capture, no originalCaller input and the same first common Coordinator address originalCaller field",
        "for every one of 57 operation projections prove direct Coordinator, fake Registry, zero caller and caller-injection attempts reject before any owner, provider, validator, Archive, state, event or evidence effect",
        "prove caller-supplied, dual, trusted-forwarder, unknown-selector and generic-calldata routes do not exist and have no effect",
        "prove immutable Registry authority substitution rejects at runtime and any forwarded-caller substitution fails exact source and forwarding-trace acceptance rather than being normalized",
    ),
    "evidence": (
        "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md#frozen-facts-that-source-must-preserve",
        "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md#blocking-acceptance-surfaces",
        "docs/adr/0023-modular-artist-authority-domain-ownership.md#slim-registry",
        "docs/adr/0023-modular-artist-authority-domain-ownership.md#stateless-atomic-operation-coordinator",
        "docs/architecture/artist-semantic-owner-matrix-v2.json#operations",
    ),
}
EXPECTED_ORIGINAL_CALLER_OPTION = "immediate_registry_sender_forwarded_unchanged_v1"
EXPECTED_ORIGINAL_CALLER_OPTION_DISPOSITIONS = (
    ("tx_origin_derived", "rejected"),
    ("signer_substitution", "rejected"),
    ("role_or_governance_actor_substitution", "rejected"),
    ("provider_owner_or_coordinator_substitution", "rejected"),
    ("caller_supplied_or_trusted_forwarder_claim", "rejected"),
    ("immediate_registry_sender_forwarded_unchanged_v1", "accepted"),
)
EXPECTED_ORIGINAL_CALLER_VALUES = {
    "definition": "immediate_registry_submitter",
    "registry_capture_expression": "msg.sender",
    "coordinator_transport_type": "address",
    "coordinator_transport_position": "first_common_argument",
    "coordinator_zero_original_caller_allowed": False,
    "owner_transport": "unchanged",
    "owner_requires_immutable_coordinator_sender": True,
    "tx_origin_authoritative": False,
    "signer_substitutes_original_caller": False,
    "role_or_governance_actor_substitutes_original_caller": False,
    "provider_owner_or_coordinator_substitutes_original_caller": False,
    "relayer_may_differ_from_signer": True,
}
EXPECTED_ORIGINAL_CALLER_OBLIGATIONS = {
    "encoding_obligations": (
        "originalCaller is one bare address and the first common argument in each of 57 typed Coordinator operation projections",
        "Registry operation calldata contains no caller-asserted originalCaller and Registry derives it only from the immediate msg.sender",
        "exact owner mutation parameter order and context packing remain unresolved, but every eventual mutating owner call must carry the same originalCaller address unchanged",
    ),
    "call_obligations": (
        "Coordinator verifies immutable Registry msg.sender and nonzero originalCaller before snapshots and forwards that address unchanged to every mutating owner in the recipe",
        "each mutating owner verifies its immutable Coordinator msg.sender before authenticating the unchanged originalCaller against its own exact authority rules",
        "originalCaller is never replaced by tx.origin, a signer, role holder, governance actor, provider, owner, Coordinator or trusted-forwarder claim",
        "a relayer may be originalCaller while a distinct signer satisfies an independently frozen signature rule",
    ),
    "error_obligations": (
        "zero originalCaller rejects before any state, event, evidence or downstream effect without selecting an exact custom-error ABI in this packet, while altered or injected caller derivation fails exact source, ABI and trace acceptance",
        "Registry or Coordinator authority substitution rejects before any owner mutation and owner calls from any address other than the immutable Coordinator reject before owner effects",
        "tx.origin, signer, role, governance, provider, owner or Coordinator identity mismatch is never normalized into originalCaller",
    ),
    "test_obligations": (
        "for every one of 57 operation projections assert Registry msg.sender is the sole derivation and the identical nonzero address reaches every mutating owner",
        "prove direct and fake-Registry calls, zero caller and immutable-authority substitution reject with no effects and prove caller injection or altered owner forwarding fails exact source, ABI and trace acceptance",
        "prove tx.origin mismatch does not change originalCaller and prove a valid relayer distinct from the signer remains the authenticated originalCaller",
        "prove signer, role, governance, provider, owner and Coordinator identities cannot substitute for originalCaller",
        "prove unknown selectors and generic calldata cannot manufacture or forward an originalCaller and have no effect",
    ),
    "evidence": (
        "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md#frozen-facts-that-source-must-preserve",
        "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md#blocking-acceptance-surfaces",
        "docs/adr/0023-modular-artist-authority-domain-ownership.md#slim-registry",
        "docs/adr/0023-modular-artist-authority-domain-ownership.md#stateless-atomic-operation-coordinator",
        "docs/architecture/artist-semantic-owner-matrix-v2.json#operations",
    ),
}
EXPECTED_NATIVE_VALUE_OPTION = "nonpayable_zero_value_end_to_end_v1"
EXPECTED_NATIVE_VALUE_OPTION_DISPOSITIONS = (
    ("payable_passthrough_or_custody", "rejected"),
    ("payable_with_in_body_zero_value_check", "rejected"),
    ("nonpayable_with_explicit_fallback_or_receive_revert", "rejected"),
    ("nonpayable_with_redundant_zero_value_commitment_fields", "rejected"),
    ("nonpayable_zero_value_end_to_end_v1", "accepted"),
)
EXPECTED_NATIVE_VALUE_VALUES = {
    "registry_entrypoint_count": 57,
    "coordinator_entrypoint_count": 57,
    "registry_entrypoint_mutability": "external_nonpayable",
    "coordinator_entrypoint_mutability": "external_nonpayable",
    "fallback_present": False,
    "receive_present": False,
    "typed_owner_call_value_wei": 0,
    "typed_provider_call_value_wei": 0,
    "typed_validator_call_value_wei": 0,
    "archive_call_value_wei": 0,
    "forced_balance_forwarded": False,
    "forced_balance_recoverable_by_protocol": False,
}
EXPECTED_NATIVE_VALUE_OBLIGATIONS = {
    "encoding_obligations": (
        "each of the 57 Registry facade ABI entries and 57 matching Coordinator ABI entries encodes stateMutability as nonpayable",
        "native value is transaction-envelope state and is absent from operation calldata, recipe commitments, replay preimages, Archive evidence and the composite manifest",
        "the Registry and Coordinator ABIs contain neither fallback nor receive entries",
    ),
    "call_obligations": (
        "every typed owner, provider, validator and Archive call executes with exactly zero wei",
        "forced native balance is never read as operation input and is never forwarded, withdrawn, refunded or incorporated into a protocol decision",
    ),
    "error_obligations": (
        "nonzero value sent to a recognized operation selector reverts in the Solidity nonpayable ABI dispatcher before function-body execution and commits no protocol custom-error selector",
        "empty calldata or an unknown selector reverts because fallback and receive are absent and commits no protocol custom-error selector",
        "downstream nonzero-call-value drift is forbidden rather than normalized or refunded",
    ),
    "test_obligations": (
        "for every one of 57 operation pairs assert both Registry and Coordinator ABI stateMutability equals nonpayable",
        "for every one of 57 operation pairs send nonzero value and prove rejection before any owner, provider, validator, Archive, state, event or evidence effect",
        "prove empty calldata and unknown selectors reject value because fallback and receive are absent",
        "instrument each typed collaborator category and prove exact zero call value",
        "force native balance into Registry and Coordinator and prove representative and maximum-call recipes neither read nor forward nor recover it",
    ),
    "evidence": (
        "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md#frozen-facts-that-source-must-preserve",
        "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md#blocking-acceptance-surfaces",
        "docs/adr/0023-modular-artist-authority-domain-ownership.md#stateless-atomic-operation-coordinator",
        "docs/architecture/artist-semantic-owner-matrix-v2.json#operations",
    ),
}

EXPECTED_PRESENT_ARTIST_SOURCES = (
    "smart-contracts/domains/artist/StreamArtistArchiveV2.sol",
    "smart-contracts/domains/artist/StreamArtistRegistryV2.sol",
)

EXPECTED_ABSENT_ARTIST_SOURCES = (
    "smart-contracts/domains/artist/StreamArtistOperationCoordinator.sol",
    "smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol",
    "smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol",
    "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol",
    "smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol",
    "smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol",
    "smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol",
    "smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol",
    "smart-contracts/domains/artist/StreamArtistRegistryValidatorBase.sol",
)

EXPECTED_669_ROW = {
    "path": "smart-contracts/domains/artist/StreamArtistRegistryValidatorBase.sol",
    "site": "_validateSignerProof",
    "kind": "call-option",
    "operation": "staticcall",
    "expression": "context.erc1271GasCap",
    "call_syntax": "address(<signer>).staticcall{gas: context.erc1271GasCap}",
    "expected_count": 1,
    "path_class": "user-path",
    "lane": "artist-authority",
    "issue": "#669",
    "disposition": "open-remediation-required",
}


class FreezeError(ValueError):
    """Raised when the proposed decision register is not exact."""


def _reject_constant(value: str) -> Any:
    raise FreezeError(f"non-finite JSON number is forbidden: {value}")


def _reject_float(value: str) -> Any:
    raise FreezeError(f"floating-point JSON number is forbidden: {value}")


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise FreezeError(f"duplicate JSON member is forbidden: {key}")
        result[key] = value
    return result


def _walk_numbers(value: Any, path: str = "$") -> None:
    if isinstance(value, bool) or value is None or isinstance(value, str):
        return
    if isinstance(value, int):
        if abs(value) > (2**53 - 1):
            raise FreezeError(f"unsafe JSON integer at {path}")
        return
    if isinstance(value, float):
        if not math.isfinite(value):
            raise FreezeError(f"non-finite JSON number at {path}")
        raise FreezeError(f"floating-point JSON number at {path}")
    if isinstance(value, list):
        for index, item in enumerate(value):
            _walk_numbers(item, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            _walk_numbers(item, f"{path}.{key}")
        return
    raise FreezeError(f"unsupported JSON value at {path}")


def load_strict_json(path: Path) -> Any:
    try:
        raw = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise FreezeError(f"cannot read UTF-8 JSON {path}: {exc}") from exc
    try:
        value = json.loads(
            raw,
            object_pairs_hook=_strict_object,
            parse_constant=_reject_constant,
            parse_float=_reject_float,
        )
    except (json.JSONDecodeError, FreezeError) as exc:
        raise FreezeError(f"invalid strict JSON {path}: {exc}") from exc
    _walk_numbers(value)
    return value


def _canonical_digest(value: Any) -> str:
    encoded = json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _github_heading_slug(heading: str) -> str:
    heading = heading.strip().rstrip("#").strip().lower()
    heading = re.sub(r"<[^>]+>", "", heading)
    heading = re.sub(r"[^\w -]", "", heading, flags=re.UNICODE)
    return heading.replace(" ", "-")


def _markdown_heading_anchors(text: str) -> set[str]:
    anchors: set[str] = set()
    fence_marker: str | None = None
    fence_length = 0
    in_html_comment = False
    for raw_line in text.splitlines():
        if fence_marker is not None:
            closing = MARKDOWN_FENCE_CLOSE_RE.match(raw_line)
            if (
                closing is not None
                and closing.group(1)[0] == fence_marker
                and len(closing.group(1)) >= fence_length
            ):
                fence_marker = None
                fence_length = 0
            continue

        line_began_in_html_comment = in_html_comment
        if not line_began_in_html_comment:
            opening = MARKDOWN_FENCE_RE.match(raw_line)
            if opening is not None:
                run = opening.group(1)
                if run[0] == "~" or "`" not in opening.group(2):
                    fence_marker = run[0]
                    fence_length = len(run)
                    continue

        visible: list[str] = []
        cursor = 0
        while cursor < len(raw_line):
            if in_html_comment:
                end = raw_line.find("-->", cursor)
                if end == -1:
                    visible.append(" " * (len(raw_line) - cursor))
                    cursor = len(raw_line)
                    continue
                visible.append(" " * (end + 3 - cursor))
                cursor = end + 3
                in_html_comment = False
                continue

            start = raw_line.find("<!--", cursor)
            if start == -1:
                visible.append(raw_line[cursor:])
                cursor = len(raw_line)
                continue
            visible.append(raw_line[cursor:start])
            end = raw_line.find("-->", start + 4)
            if end == -1:
                visible.append(" " * (len(raw_line) - start))
                cursor = len(raw_line)
                in_html_comment = True
                continue
            visible.append(" " * (end + 3 - start))
            cursor = end + 3

        if line_began_in_html_comment:
            continue
        line = "".join(visible)
        match = MARKDOWN_HEADING_RE.match(line)
        if match is None:
            continue
        slug = _github_heading_slug(match.group(2))
        if not slug:
            continue
        candidate = slug
        suffix = 0
        while candidate in anchors:
            suffix += 1
            candidate = f"{slug}-{suffix}"
        anchors.add(candidate)
    return anchors


def _resolve_evidence_reference(root: Path, reference: str) -> None:
    if (
        reference != reference.strip()
        or reference.count("#") != 1
        or "\\" in reference
    ):
        raise FreezeError(f"malformed evidence reference: {reference!r}")
    relative, anchor = reference.split("#", 1)
    parts = relative.split("/")
    posix_path = PurePosixPath(relative)
    if (
        not relative
        or not anchor
        or posix_path.is_absolute()
        or any(part in {"", ".", ".."} for part in parts)
        or ":" in parts[0]
    ):
        raise FreezeError(
            f"evidence reference must be repository-relative file#anchor: {reference!r}"
        )

    root = root.resolve()
    try:
        target = (root / Path(*parts)).resolve()
        target.relative_to(root)
    except (OSError, ValueError) as exc:
        raise FreezeError(f"evidence reference escapes repository: {reference!r}") from exc

    suffix = target.suffix.lower()
    if suffix not in {".md", ".json"}:
        raise FreezeError(f"unsupported evidence target type: {reference!r}")
    if not target.is_file():
        raise FreezeError(f"evidence target is missing: {reference!r}")

    if suffix == ".md":
        try:
            text = target.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            raise FreezeError(f"evidence Markdown target is unreadable: {reference!r}") from exc
        if anchor not in _markdown_heading_anchors(text):
            raise FreezeError(f"evidence Markdown heading is missing: {reference!r}")
        return

    try:
        document = load_strict_json(target)
    except FreezeError as exc:
        raise FreezeError(f"evidence JSON target is unreadable: {reference!r}") from exc
    if not isinstance(document, dict):
        raise FreezeError(f"evidence JSON target is not a top-level object: {reference!r}")
    if anchor not in document:
        raise FreezeError(f"evidence JSON top-level key is missing: {reference!r}")


def _require_digest(label: str, value: Any, expected: str) -> None:
    observed = _canonical_digest(value)
    if observed != expected:
        raise FreezeError(f"{label} drifted: {observed} != {expected}")


def _validate_schema(packet: Any, schema: Any) -> None:
    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(packet), key=lambda item: list(item.path))
    if errors:
        first = errors[0]
        location = "$" + "".join(f"[{part!r}]" for part in first.path)
        raise FreezeError(f"schema violation at {location}: {first.message}")


def _check_meta(packet: dict[str, Any], schema: dict[str, Any], schema_path: Path) -> None:
    if set(packet) != TOP_LEVEL_FIELDS:
        missing = sorted(TOP_LEVEL_FIELDS - set(packet))
        extra = sorted(set(packet) - TOP_LEVEL_FIELDS)
        raise FreezeError(
            f"critical top-level fields drifted: missing={missing}, extra={extra}"
        )
    if packet.get("schema") != PACKET_SCHEMA:
        raise FreezeError("packet schema id drifted")
    if packet.get("status") != PACKET_STATUS:
        raise FreezeError("packet must remain a Proposed partial decision resolution")
    if packet.get("maturity") != PACKET_MATURITY:
        raise FreezeError("packet must remain pre-audit and source-blocked")
    if packet.get("evaluated_base") != {
        "commit": EVALUATED_COMMIT,
        "tree": EVALUATED_TREE,
    }:
        raise FreezeError("evaluated base or tree drifted")
    if schema.get("$id") != JSON_SCHEMA_ID:
        raise FreezeError("JSON Schema $id drifted")
    try:
        schema_digest = hashlib.sha256(schema_path.read_bytes()).hexdigest()
    except OSError as exc:
        raise FreezeError(f"cannot read schema bytes {schema_path}: {exc}") from exc
    if schema_digest != SCHEMA_SHA256:
        raise FreezeError(
            f"schema sha256 drifted: {schema_digest} != {SCHEMA_SHA256}"
        )


def _check_authorities(root: Path, packet: dict[str, Any]) -> None:
    actual = tuple(
        (row["id"], row["path"], row["sha256"])
        for row in packet["authority_bindings"]
    )
    if actual != EXPECTED_AUTHORITY_BINDINGS:
        raise FreezeError("authority binding identity, order, or digest drifted")
    for authority_id, relative, expected in EXPECTED_AUTHORITY_BINDINGS:
        path = root / relative
        try:
            observed = hashlib.sha256(path.read_bytes()).hexdigest()
        except OSError as exc:
            raise FreezeError(
                f"authority {authority_id} is unreadable: {relative}: {exc}"
            ) from exc
        if observed != expected:
            raise FreezeError(
                f"authority {authority_id} sha256 drifted: {observed} != {expected}"
            )


def _check_register(root: Path, packet: dict[str, Any]) -> None:
    _require_digest(
        "selected dependency shape",
        packet["selected_shape"],
        SELECTED_SHAPE_SHA256,
    )
    _require_digest("phase order", packet["phase_order"], PHASE_ORDER_SHA256)
    _require_digest(
        "fixed architecture invariants",
        packet["fixed_invariants"],
        FIXED_INVARIANTS_SHA256,
    )
    _require_digest(
        "57-operation projection policy",
        packet["operation_projection"],
        OPERATION_PROJECTION_SHA256,
    )
    _require_digest(
        "decision rows",
        packet["decision_rows"],
        DECISION_ROWS_SHA256,
    )
    _require_digest("gate state", packet["gate_state"], GATE_STATE_SHA256)
    _require_digest("bounded exclusions", packet["exclusions"], EXCLUSIONS_SHA256)

    rows = packet["decision_rows"]
    actual = tuple((row["surface_id"], row["phase"]) for row in rows)
    if actual != EXPECTED_DECISION_PHASES:
        raise FreezeError("decision surface identity, phase, or order drifted")
    accepted_rows = tuple(
        row for row in rows if row["decision_status"] == "accepted"
    )
    unresolved_rows = tuple(
        row for row in rows if row["decision_status"] == "unresolved"
    )
    if len(accepted_rows) + len(unresolved_rows) != len(rows):
        raise FreezeError("decision status inventory drifted")
    for row in rows:
        if row["accepted"] is not (row["decision_status"] == "accepted"):
            raise FreezeError(
                f"decision {row['surface_id']} accepted boolean disagrees with status"
            )
    accepted = tuple(row["surface_id"] for row in accepted_rows)
    if accepted != EXPECTED_ACCEPTED_DECISIONS:
        raise FreezeError("accepted decision identity or count drifted")
    gate = packet["gate_state"]
    if (
        gate["accepted_decision_count"] != len(accepted_rows)
        or gate["unresolved_decision_count"] != len(unresolved_rows)
        or gate["accepted_decision_count"] + gate["unresolved_decision_count"]
        != len(rows)
    ):
        raise FreezeError("gate decision counts disagree with decision rows")

    for row in rows:
        if row["decision_status"] == "accepted":
            if (
                row["surface_id"] not in EXPECTED_ACCEPTED_DECISIONS
                or row["source_blocking"]
                or row["unresolved_decisions"]
                or row["evidence_required"]
            ):
                raise FreezeError(
                    f"decision {row['surface_id']} acceptance state drifted"
                )
            resolution = row["resolution"]
            accepted_options = tuple(
                option
                for option in resolution["considered_options"]
                if option["disposition"] == "accepted"
            )
            if len(accepted_options) != 1:
                raise FreezeError(
                    f"decision {row['surface_id']} must have exactly one accepted option"
                )
            if accepted_options[0]["option_id"] != row["selected_option"]:
                raise FreezeError(
                    f"decision {row['surface_id']} selected option disagrees with disposition"
                )

            dispositions = tuple(
                (option["option_id"], option["disposition"])
                for option in resolution["considered_options"]
            )
            surface = row["surface_id"]
            if surface == "registry_ingress":
                expected_option = EXPECTED_REGISTRY_INGRESS_OPTION
                expected_dispositions = EXPECTED_REGISTRY_INGRESS_OPTION_DISPOSITIONS
                expected_values = EXPECTED_REGISTRY_INGRESS_VALUES
                expected_obligations = EXPECTED_REGISTRY_INGRESS_OBLIGATIONS
            elif surface == "original_caller":
                expected_option = EXPECTED_ORIGINAL_CALLER_OPTION
                expected_dispositions = EXPECTED_ORIGINAL_CALLER_OPTION_DISPOSITIONS
                expected_values = EXPECTED_ORIGINAL_CALLER_VALUES
                expected_obligations = EXPECTED_ORIGINAL_CALLER_OBLIGATIONS
            elif surface == "native_value":
                expected_option = EXPECTED_NATIVE_VALUE_OPTION
                expected_dispositions = EXPECTED_NATIVE_VALUE_OPTION_DISPOSITIONS
                expected_values = EXPECTED_NATIVE_VALUE_VALUES
                expected_obligations = EXPECTED_NATIVE_VALUE_OBLIGATIONS
            else:
                raise FreezeError(
                    f"accepted decision {surface} has no exact checker binding"
                )
            diagnostic = surface.replace("_", "-")
            if row["selected_option"] != expected_option:
                raise FreezeError(f"{diagnostic} selected option drifted")
            if dispositions != expected_dispositions:
                raise FreezeError(f"{diagnostic} considered options drifted")
            if resolution["selected_values"] != expected_values:
                raise FreezeError(f"{diagnostic} exact values drifted")
            for field, expected in expected_obligations.items():
                if tuple(resolution[field]) != expected:
                    raise FreezeError(f"{diagnostic} {field} drifted")
            for reference in resolution["evidence"]:
                _resolve_evidence_reference(root, reference)
            continue
        if (
            row["selected_option"] is not None
            or row["accepted"]
            or not row["source_blocking"]
            or row.get("resolution") is not None
        ):
            raise FreezeError(
                f"decision {row['surface_id']} overclaims selection or acceptance"
            )


def _check_matrix_projection(matrix: dict[str, Any], packet: dict[str, Any]) -> None:
    requirements = matrix["source_requirements"]
    if (
        requirements["interface_and_storage_freeze_complete"]
        or requirements["implementation_authorized"]
    ):
        raise FreezeError("semantic-owner matrix overclaims freeze or authorization")
    operations = matrix["operations"]
    if [row["operation_id"] for row in operations] != list(range(1, 58)):
        raise FreezeError("matrix operation identities are not exact ordered 1..57")

    recipes: list[str] = []
    entrypoints: list[str] = []
    for operation in operations:
        recipe = operation["coordinator_recipe"]
        if set(recipe) != {
            "recipe_id",
            "facade_entrypoint",
            "generic_dispatch",
            "original_caller_authenticated",
            "snapshot_ids",
            "actions",
            "atomicity",
        }:
            raise FreezeError(
                f"operation {operation['operation_id']} recipe field inventory drifted"
            )
        if recipe["generic_dispatch"] or not recipe["original_caller_authenticated"]:
            raise FreezeError(
                f"operation {operation['operation_id']} became generic or unauthenticated"
            )
        source = operation["source_requirements"]
        if source["source_present"] or source["implementation_authorized"]:
            raise FreezeError(
                f"operation {operation['operation_id']} overclaims source or authorization"
            )
        recipes.append(recipe["recipe_id"])
        entrypoints.append(recipe["facade_entrypoint"])
    if len(set(recipes)) != 57 or len(set(entrypoints)) != 57:
        raise FreezeError("57 recipe identities or facade entrypoints are not unique")

    stop = "FINALITY_DEPENDENCY_ABI_AND_ADR0020_NOT_FROZEN"
    for operation in operations:
        observed = operation["source_requirements"]["effective_implementation_stops"]
        expected = [stop] if operation["operation_id"] == 22 else []
        if observed != expected:
            raise FreezeError(
                f"operation {operation['operation_id']} effective stop drifted"
            )

    projection = packet["operation_projection"]
    if (
        projection["operation_count"] != len(operations)
        or projection["ingress_mode"]
        != "immutable_registry_only_typed_facade"
        or projection["registry_original_caller_capture"]
        != "immediate_msg_sender"
        or projection["registry_original_caller_input_present"]
        or projection["coordinator_first_common_argument"]
        != "address originalCaller"
        or projection["coordinator_ingress_authority"] != "immutable_registry"
        or projection["coordinator_zero_original_caller_policy"]
        != "reject_before_effects"
        or projection["owner_original_caller_forwarding"]
        != "same_address_unchanged"
        or projection["owner_mutation_authority"] != "immutable_coordinator"
        or not projection["relayer_may_differ_from_signer"]
        or projection["registry_state_mutability"] != "nonpayable"
        or projection["coordinator_state_mutability"] != "nonpayable"
        or projection["typed_collaborator_call_value_wei"] != 0
        or projection["source_present"]
        or projection["implementation_authorized"]
        or projection["operation_22_effective_stop"] != stop
    ):
        raise FreezeError("57-operation ingress/caller/value/source projection drifted")

    directory = matrix["directory"]
    coordinator = matrix["operation_coordinator"]
    archive = matrix["archive"]
    if any(
        directory[field]
        for field in (
            "owns_semantic_authority",
            "semantic_storage",
            "owns_records",
            "owns_replay_state",
            "owns_current_or_latest_state",
            "generic_routing",
            "arbitrary_selector_or_calldata",
            "delegatecall",
            "upgrade_path",
            "mutable_rebinding",
        )
    ):
        raise FreezeError("Registry gained semantic authority or generic mutability")
    if any(
        coordinator[field]
        for field in (
            "owns_semantic_authority",
            "semantic_storage",
            "record_storage",
            "replay_storage",
            "normative_event_emitter",
            "generic_selector_route",
            "generic_calldata_route",
            "delegatecall",
            "upgrade_path",
            "mutable_recipe",
        )
    ):
        raise FreezeError("Coordinator gained authority, storage, routing, or mutability")
    if any(
        archive[field]
        for field in (
            "owns_semantic_authority",
            "owns_authorization",
            "owns_records",
            "owns_replay_state",
            "owns_current_or_latest_state",
            "usable_for_authentication",
            "usable_for_replay_decisions",
            "usable_for_current_state_decisions",
            "usable_for_latest_state_decisions",
            "generic_routing",
            "delegatecall",
            "upgrade_path",
        )
    ):
        raise FreezeError("Archive gained semantic or routing authority")

    call_row = matrix["external_dependencies"]["issue_669"]["reserved_call_row"]
    if call_row != EXPECTED_669_ROW:
        raise FreezeError("issue 669 exact stateless staticcall reservation drifted")


def _check_source_absence(root: Path) -> None:
    for relative in EXPECTED_ABSENT_ARTIST_SOURCES:
        if (root / relative).exists():
            raise FreezeError(f"source-blocked artist component became present: {relative}")
    if (root / COORDINATOR_INTERFACE_PATH).exists():
        raise FreezeError("Coordinator interface became present or was presented as accepted")
    observed = tuple(
        sorted(
            path.relative_to(root).as_posix()
            for path in (root / ARTIST_SOURCE_ROOT).rglob("*.sol")
        )
    )
    if observed != EXPECTED_PRESENT_ARTIST_SOURCES:
        raise FreezeError(
            f"canonical artist source set drifted: observed={observed}, "
            f"expected={EXPECTED_PRESENT_ARTIST_SOURCES}"
        )


def check(root: Path) -> dict[str, int]:
    packet_path = root / PACKET_PATH
    schema_path = root / SCHEMA_PATH
    matrix_path = root / MATRIX_PATH
    packet = load_strict_json(packet_path)
    schema = load_strict_json(schema_path)
    matrix = load_strict_json(matrix_path)
    if not isinstance(packet, dict) or not isinstance(schema, dict) or not isinstance(matrix, dict):
        raise FreezeError("packet, schema, and semantic-owner matrix must be JSON objects")

    _check_meta(packet, schema, schema_path)
    _validate_schema(packet, schema)
    _check_authorities(root, packet)
    _check_register(root, packet)
    _check_matrix_projection(matrix, packet)
    _check_source_absence(root)
    return {
        "authority_bindings": len(packet["authority_bindings"]),
        "phases": len(packet["phase_order"]),
        "decision_rows": len(packet["decision_rows"]),
        "accepted_decisions": sum(row["accepted"] for row in packet["decision_rows"]),
        "unresolved_decisions": sum(
            row["decision_status"] == "unresolved" for row in packet["decision_rows"]
        ),
        "operations": len(matrix["operations"]),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root (defaults to the checker repository)",
    )
    args = parser.parse_args(argv)
    try:
        counts = check(args.root.resolve())
    except FreezeError as exc:
        print(f"artist shared-mechanics freeze check failed: {exc}", file=sys.stderr)
        return 1
    print(
        "artist shared-mechanics freeze check passed: "
        f"{counts['authority_bindings']} authority bindings, "
        f"{counts['phases']} dependency phases, "
        f"{counts['decision_rows']} decision rows, "
        f"{counts['accepted_decisions']} accepted and "
        f"{counts['unresolved_decisions']} unresolved source-blocking decisions, "
        f"{counts['operations']} operations; source remains unauthorized"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

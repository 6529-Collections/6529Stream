#!/usr/bin/env python3
"""Hostile tests for the proposed artist shared-mechanics decision register."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from types import ModuleType
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
CHECKER_PATH = REPO_ROOT / "scripts/check_artist_operation_shared_mechanics_freeze.py"


def _load_checker() -> ModuleType:
    spec = importlib.util.spec_from_file_location("artist_mechanics_checker", CHECKER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load artist shared-mechanics checker")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CHECKER = _load_checker()


class ArtistOperationSharedMechanicsFreezeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        copied = {
            CHECKER.PACKET_PATH,
            CHECKER.SCHEMA_PATH,
            CHECKER.MATRIX_PATH,
            *(
                Path(relative)
                for _, relative, _ in CHECKER.EXPECTED_AUTHORITY_BINDINGS
            ),
        }
        for relative in copied:
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPO_ROOT / relative, destination)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def _read(self, relative: Path) -> dict[str, Any]:
        return json.loads((self.root / relative).read_text(encoding="utf-8"))

    def _write(self, relative: Path, value: dict[str, Any]) -> None:
        (self.root / relative).write_text(
            json.dumps(value, indent=2) + "\n",
            encoding="utf-8",
        )

    def _packet(self) -> dict[str, Any]:
        return self._read(CHECKER.PACKET_PATH)

    def _write_packet(self, packet: dict[str, Any]) -> None:
        self._write(CHECKER.PACKET_PATH, packet)

    @staticmethod
    def _native_row(packet: dict[str, Any]) -> dict[str, Any]:
        return next(
            row for row in packet["decision_rows"] if row["surface_id"] == "native_value"
        )

    def _assert_rejected(self, expected: str | None = None) -> None:
        if expected is None:
            with self.assertRaises(CHECKER.FreezeError):
                CHECKER.check(self.root)
        else:
            with self.assertRaisesRegex(CHECKER.FreezeError, expected):
                CHECKER.check(self.root)

    def _check_with_rebound_authority(
        self,
        *,
        authority_id: str,
        relative: Path,
        updated_text: str,
        expected_error: str | None,
    ) -> dict[str, int] | None:
        target = self.root / relative
        target.write_text(updated_text, encoding="utf-8")
        rebound_digest = hashlib.sha256(target.read_bytes()).hexdigest()
        packet = self._packet()
        binding = next(
            row
            for row in packet["authority_bindings"]
            if row["id"] == authority_id
        )
        binding["sha256"] = rebound_digest
        self._write_packet(packet)

        rebound_authorities = tuple(
            (
                bound_id,
                path,
                rebound_digest if bound_id == authority_id else digest,
            )
            for bound_id, path, digest in CHECKER.EXPECTED_AUTHORITY_BINDINGS
        )
        original_authorities = CHECKER.EXPECTED_AUTHORITY_BINDINGS
        original_decision_digest = CHECKER.DECISION_ROWS_SHA256
        try:
            CHECKER.EXPECTED_AUTHORITY_BINDINGS = rebound_authorities
            CHECKER.DECISION_ROWS_SHA256 = CHECKER._canonical_digest(
                packet["decision_rows"]
            )
            if expected_error is not None:
                self._assert_rejected(expected_error)
                return None
            return CHECKER.check(self.root)
        finally:
            CHECKER.EXPECTED_AUTHORITY_BINDINGS = original_authorities
            CHECKER.DECISION_ROWS_SHA256 = original_decision_digest

    def test_baseline_is_exact(self) -> None:
        counts = CHECKER.check(self.root)
        self.assertEqual(counts, {
            "authority_bindings": 10,
            "phases": 4,
            "decision_rows": 19,
            "accepted_decisions": 1,
            "unresolved_decisions": 18,
            "operations": 57,
        })

    def test_safety_posture_is_independently_literal(self) -> None:
        packet = self._packet()
        self.assertEqual(packet["status"], "PROPOSED_PARTIAL_DECISION_RESOLUTION")
        self.assertEqual(packet["maturity"], "pre_audit_source_blocked")
        self.assertFalse(packet["selected_shape"]["comprehensive_freeze_complete"])
        self.assertFalse(packet["selected_shape"]["typed_abi_only_authorizes_source"])
        self.assertFalse(packet["gate_state"]["interface_and_storage_freeze_complete"])
        self.assertFalse(packet["gate_state"]["coordinator_interface_accepted"])
        self.assertFalse(packet["gate_state"]["coordinator_source_present"])
        self.assertFalse(packet["gate_state"]["implementation_authorized"])
        self.assertEqual(
            packet["phase_order"][0]["state"], "partial_decision_resolution"
        )
        self.assertFalse(packet["operation_projection"]["source_present"])
        self.assertFalse(packet["operation_projection"]["implementation_authorized"])
        self.assertEqual(packet["gate_state"]["accepted_decision_count"], 1)
        self.assertEqual(packet["gate_state"]["unresolved_decision_count"], 18)
        accepted = [row for row in packet["decision_rows"] if row["accepted"]]
        self.assertEqual([row["surface_id"] for row in accepted], ["native_value"])
        self.assertFalse(accepted[0]["source_blocking"])
        unresolved = [row for row in packet["decision_rows"] if not row["accepted"]]
        self.assertEqual(len(unresolved), 18)
        self.assertTrue(all(row["source_blocking"] for row in unresolved))
        matrix = self._read(CHECKER.MATRIX_PATH)
        self.assertEqual(len(matrix["operations"]), 57)
        self.assertTrue(
            all(
                not operation["source_requirements"]["source_present"]
                and not operation["source_requirements"]["implementation_authorized"]
                for operation in matrix["operations"]
            )
        )

    def test_duplicate_json_member_is_rejected(self) -> None:
        path = self.root / CHECKER.PACKET_PATH
        raw = path.read_text(encoding="utf-8")
        path.write_text(raw.replace("{", '{"schema":"shadow",', 1), encoding="utf-8")
        self._assert_rejected("duplicate JSON member")

    def test_unsafe_integer_is_rejected(self) -> None:
        path = self.root / CHECKER.PACKET_PATH
        raw = path.read_text(encoding="utf-8")
        path.write_text(
            raw.replace('"operation_count": 57', '"operation_count": 9007199254740992', 1),
            encoding="utf-8",
        )
        self._assert_rejected("unsafe JSON integer")

    def test_schema_digest_is_independently_pinned(self) -> None:
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["title"] = "tampered"
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._assert_rejected("schema sha256 drifted")

    def test_extra_top_level_readiness_claim_is_rejected(self) -> None:
        packet = self._packet()
        packet["production_ready"] = True
        self._write_packet(packet)
        self._assert_rejected("critical top-level fields drifted")

    def test_status_or_maturity_promotion_is_rejected(self) -> None:
        for field, value, expected in (
            ("status", "ACCEPTED", "Proposed partial decision resolution"),
            ("maturity", "production_ready", "pre-audit and source-blocked"),
        ):
            with self.subTest(field=field):
                packet = self._packet()
                packet[field] = value
                self._write_packet(packet)
                self._assert_rejected(expected)
                shutil.copy2(REPO_ROOT / CHECKER.PACKET_PATH, self.root / CHECKER.PACKET_PATH)

    def test_authority_bytes_are_pinned(self) -> None:
        relative = Path(
            "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md"
        )
        path = self.root / relative
        path.write_text(path.read_text(encoding="utf-8") + "\nclaim drift\n", encoding="utf-8")
        self._assert_rejected("authority coordinator_source_gate sha256 drifted")

    def test_coupled_authority_and_packet_tamper_is_rejected(self) -> None:
        relative = Path(
            "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md"
        )
        path = self.root / relative
        path.write_text(path.read_text(encoding="utf-8") + "\nclaim drift\n", encoding="utf-8")
        packet = self._packet()
        packet["authority_bindings"][0]["sha256"] = "0" * 64
        self._write_packet(packet)
        self._assert_rejected("authority binding identity, order, or digest drifted")

    def test_evidence_references_and_duplicate_heading_slugs_resolve(self) -> None:
        packet = self._packet()
        for reference in self._native_row(packet)["resolution"]["evidence"]:
            with self.subTest(reference=reference):
                CHECKER._resolve_evidence_reference(self.root, reference)

        duplicate = self.root / "docs/duplicate-headings.md"
        duplicate.write_text(
            "# Repeated Heading\n\n## Repeated Heading\n",
            encoding="utf-8",
        )
        CHECKER._resolve_evidence_reference(
            self.root,
            "docs/duplicate-headings.md#repeated-heading",
        )
        CHECKER._resolve_evidence_reference(
            self.root,
            "docs/duplicate-headings.md#repeated-heading-1",
        )

    def test_markdown_heading_parser_excludes_fences_and_html_comments(self) -> None:
        relative = Path("docs/heading-parser-hostiles.md")
        target = self.root / relative
        target.write_text(
            "\n".join(
                (
                    "# Real Before",
                    "   ````python",
                    "# Backtick Phantom",
                    "```",
                    "## Short Close Phantom",
                    "   ````",
                    "~~~ text",
                    "# Tilde Phantom",
                    "```",
                    "## Wrong Marker Phantom",
                    "~~~~",
                    "<!-- # Single Comment Phantom -->",
                    "<!--",
                    "## Multiline Comment Phantom",
                    "-->## Close Line Phantom",
                    "   ### Real After",
                    "```markdown <!-- comment token",
                    "# Fence Info Phantom",
                    "```",
                    "## Real After Fence Info",
                    "# Repeated Real",
                    "# Repeated Real",
                    "",
                )
            ),
            encoding="utf-8",
        )
        for anchor in (
            "real-before",
            "real-after",
            "real-after-fence-info",
            "repeated-real",
            "repeated-real-1",
        ):
            with self.subTest(anchor=anchor, expected="present"):
                CHECKER._resolve_evidence_reference(
                    self.root,
                    f"{relative.as_posix()}#{anchor}",
                )
        for anchor in (
            "backtick-phantom",
            "short-close-phantom",
            "tilde-phantom",
            "wrong-marker-phantom",
            "single-comment-phantom",
            "multiline-comment-phantom",
            "close-line-phantom",
            "fence-info-phantom",
        ):
            with self.subTest(anchor=anchor, expected="absent"):
                with self.assertRaisesRegex(
                    CHECKER.FreezeError,
                    "evidence Markdown heading is missing",
                ):
                    CHECKER._resolve_evidence_reference(
                        self.root,
                        f"{relative.as_posix()}#{anchor}",
                    )

    def test_evidence_reference_shape_and_target_fail_closed(self) -> None:
        unsupported = self.root / "docs/evidence.txt"
        unsupported.write_text("unsupported\n", encoding="utf-8")
        unreadable = self.root / "docs/unreadable.md"
        unreadable.write_bytes(b"\xff")
        cases = (
            ("docs/evidence.md", "malformed evidence reference"),
            ("docs/evidence.md#heading#extra", "malformed evidence reference"),
            ("/docs/evidence.md#heading", "repository-relative"),
            ("C:/docs/evidence.md#heading", "repository-relative"),
            ("docs/../evidence.md#heading", "repository-relative"),
            ("docs/missing.md#heading", "evidence target is missing"),
            ("docs/evidence.txt#heading", "unsupported evidence target type"),
            ("docs/unreadable.md#heading", "evidence Markdown target is unreadable"),
        )
        for reference, expected in cases:
            with self.subTest(reference=reference):
                with self.assertRaisesRegex(CHECKER.FreezeError, expected):
                    CHECKER._resolve_evidence_reference(self.root, reference)

    def test_evidence_json_top_level_key_must_exist(self) -> None:
        with self.assertRaisesRegex(
            CHECKER.FreezeError,
            "evidence JSON top-level key is missing",
        ):
            CHECKER._resolve_evidence_reference(
                self.root,
                "docs/architecture/artist-semantic-owner-matrix-v2.json#missing_key",
            )

    def test_evidence_heading_rename_survives_all_digest_rebinding(self) -> None:
        relative = Path(
            "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md"
        )
        target = self.root / relative
        text = target.read_text(encoding="utf-8")
        self._check_with_rebound_authority(
            authority_id="coordinator_source_gate",
            relative=relative,
            updated_text=text.replace(
                "## Frozen Facts That Source Must Preserve",
                "## Renamed Facts That Source Must Preserve",
                1,
            ),
            expected_error="evidence Markdown heading is missing",
        )

    def test_fenced_phantom_anchor_survives_all_digest_rebinding(self) -> None:
        relative = Path(
            "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md"
        )
        target = self.root / relative
        text = target.read_text(encoding="utf-8")
        heading = "## Frozen Facts That Source Must Preserve"
        self._check_with_rebound_authority(
            authority_id="coordinator_source_gate",
            relative=relative,
            updated_text=text.replace(heading, f"```markdown\n{heading}\n```", 1),
            expected_error="evidence Markdown heading is missing",
        )

    def test_comment_close_line_phantom_survives_all_digest_rebinding(self) -> None:
        relative = Path(
            "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md"
        )
        target = self.root / relative
        text = target.read_text(encoding="utf-8")
        heading = "## Frozen Facts That Source Must Preserve"
        self._check_with_rebound_authority(
            authority_id="coordinator_source_gate",
            relative=relative,
            updated_text=text.replace(heading, f"<!--\n-->{heading}", 1),
            expected_error="evidence Markdown heading is missing",
        )

    def test_fence_info_comment_token_preserves_real_rebound_heading(self) -> None:
        relative = Path(
            "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md"
        )
        target = self.root / relative
        text = target.read_text(encoding="utf-8")
        heading = "## Frozen Facts That Source Must Preserve"
        counts = self._check_with_rebound_authority(
            authority_id="coordinator_source_gate",
            relative=relative,
            updated_text=text.replace(
                heading,
                f"```markdown <!-- comment token\n# Fenced Info Phantom\n```\n{heading}",
                1,
            ),
            expected_error=None,
        )
        self.assertIsNotNone(counts)
        self.assertEqual(counts["accepted_decisions"], 1)
        with self.assertRaisesRegex(
            CHECKER.FreezeError,
            "evidence Markdown heading is missing",
        ):
            CHECKER._resolve_evidence_reference(
                self.root,
                f"{relative.as_posix()}#fenced-info-phantom",
            )

    def test_selected_shape_cannot_become_typed_abi_only(self) -> None:
        packet = self._packet()
        packet["selected_shape"]["option"] = "B"
        packet["selected_shape"]["scope"] = "typed_abi_only"
        self._write_packet(packet)
        self._assert_rejected("schema violation|selected dependency shape")

    def test_typed_abi_alone_cannot_authorize_source(self) -> None:
        packet = self._packet()
        packet["selected_shape"]["typed_abi_only_authorizes_source"] = True
        packet["gate_state"]["implementation_authorized"] = True
        self._write_packet(packet)
        self._assert_rejected("schema violation|selected dependency shape|gate state")

    def test_phase_order_cannot_skip_shared_mechanics(self) -> None:
        packet = self._packet()
        packet["phase_order"][0], packet["phase_order"][1] = (
            packet["phase_order"][1],
            packet["phase_order"][0],
        )
        self._write_packet(packet)
        self._assert_rejected("phase order")

    def test_unresolved_decision_cannot_be_selected_or_accepted(self) -> None:
        packet = self._packet()
        row = packet["decision_rows"][0]
        row["decision_status"] = "accepted"
        row["selected_option"] = "invented ABI"
        row["accepted"] = True
        row["source_blocking"] = False
        self._write_packet(packet)
        self._assert_rejected("schema violation|decision.*overclaims|decision rows")

    def test_decision_surface_omission_is_rejected_by_schema_cardinality(self) -> None:
        packet = self._packet()
        packet["decision_rows"].pop()
        self._write_packet(packet)
        self._assert_rejected(
            r"schema violation at \$\['decision_rows'\]: .* is too short"
        )

    def test_twentieth_unknown_decision_surface_is_rejected_by_schema_cardinality(
        self,
    ) -> None:
        packet = self._packet()
        extra = dict(packet["decision_rows"][0])
        extra["surface_id"] = "unknown_future_surface"
        packet["decision_rows"].append(extra)
        self._write_packet(packet)
        self._assert_rejected(
            r"schema violation at \$\['decision_rows'\]: .* is too long"
        )

    def test_decision_surface_reorder_is_rejected_by_checker_digest(self) -> None:
        packet = self._packet()
        packet["decision_rows"][0], packet["decision_rows"][1] = (
            packet["decision_rows"][1],
            packet["decision_rows"][0],
        )
        self._write_packet(packet)
        self._assert_rejected("decision rows drifted")

    def test_native_value_exact_values_reach_independent_guard(self) -> None:
        packet = self._packet()
        row = next(
            row for row in packet["decision_rows"] if row["surface_id"] == "native_value"
        )
        row["resolution"]["selected_values"][
            "registry_entrypoint_mutability"
        ] = "external_payable"
        row["resolution"]["selected_values"]["typed_owner_call_value_wei"] = 1
        self._write_packet(packet)

        original_digest = CHECKER.DECISION_ROWS_SHA256
        try:
            CHECKER.DECISION_ROWS_SHA256 = CHECKER._canonical_digest(
                packet["decision_rows"]
            )
            self._assert_rejected("native-value exact values drifted")
        finally:
            CHECKER.DECISION_ROWS_SHA256 = original_digest

    def test_native_value_obligations_and_evidence_reach_independent_guards(
        self,
    ) -> None:
        for field in CHECKER.EXPECTED_NATIVE_VALUE_OBLIGATIONS:
            for mutation in ("delete", "replace"):
                with self.subTest(field=field, mutation=mutation):
                    packet = self._packet()
                    values = self._native_row(packet)["resolution"][field]
                    if mutation == "delete":
                        values.pop()
                    else:
                        values[0] = "same-cardinality hostile replacement"
                    self._write_packet(packet)

                    original_digest = CHECKER.DECISION_ROWS_SHA256
                    try:
                        CHECKER.DECISION_ROWS_SHA256 = CHECKER._canonical_digest(
                            packet["decision_rows"]
                        )
                        self._assert_rejected(f"native-value {field} drifted")
                    finally:
                        CHECKER.DECISION_ROWS_SHA256 = original_digest
                        shutil.copy2(
                            REPO_ROOT / CHECKER.PACKET_PATH,
                            self.root / CHECKER.PACKET_PATH,
                        )

    def test_native_value_considered_options_reach_independent_guard(self) -> None:
        packet = self._packet()
        row = next(
            row for row in packet["decision_rows"] if row["surface_id"] == "native_value"
        )
        row["resolution"]["considered_options"][0][
            "option_id"
        ] = "renamed_payable_passthrough_or_custody"
        self._write_packet(packet)

        original_digest = CHECKER.DECISION_ROWS_SHA256
        try:
            CHECKER.DECISION_ROWS_SHA256 = CHECKER._canonical_digest(
                packet["decision_rows"]
            )
            self._assert_rejected("native-value considered options drifted")
        finally:
            CHECKER.DECISION_ROWS_SHA256 = original_digest

    def test_accepted_options_cannot_be_zero_or_multiple(self) -> None:
        for mutation in ("zero", "multiple"):
            with self.subTest(mutation=mutation):
                packet = self._packet()
                options = self._native_row(packet)["resolution"]["considered_options"]
                if mutation == "zero":
                    options[-1]["disposition"] = "rejected"
                else:
                    options[0]["disposition"] = "accepted"
                self._write_packet(packet)
                self._assert_rejected("schema violation")

                schema = self._read(CHECKER.SCHEMA_PATH)
                considered = schema["$defs"]["decisionResolution"]["properties"][
                    "considered_options"
                ]
                considered["minContains"] = 0 if mutation == "zero" else 1
                considered["maxContains"] = 1 if mutation == "zero" else 2
                self._write(CHECKER.SCHEMA_PATH, schema)

                original_schema_digest = CHECKER.SCHEMA_SHA256
                original_decision_digest = CHECKER.DECISION_ROWS_SHA256
                try:
                    CHECKER.SCHEMA_SHA256 = hashlib.sha256(
                        (self.root / CHECKER.SCHEMA_PATH).read_bytes()
                    ).hexdigest()
                    CHECKER.DECISION_ROWS_SHA256 = CHECKER._canonical_digest(
                        packet["decision_rows"]
                    )
                    self._assert_rejected("must have exactly one accepted option")
                finally:
                    CHECKER.SCHEMA_SHA256 = original_schema_digest
                    CHECKER.DECISION_ROWS_SHA256 = original_decision_digest
                    shutil.copy2(
                        REPO_ROOT / CHECKER.PACKET_PATH,
                        self.root / CHECKER.PACKET_PATH,
                    )
                    shutil.copy2(
                        REPO_ROOT / CHECKER.SCHEMA_PATH,
                        self.root / CHECKER.SCHEMA_PATH,
                    )

    def test_selected_option_must_match_sole_accepted_option(self) -> None:
        packet = self._packet()
        row = self._native_row(packet)
        row["selected_option"] = row["resolution"]["considered_options"][0][
            "option_id"
        ]
        self._write_packet(packet)

        original_digest = CHECKER.DECISION_ROWS_SHA256
        try:
            CHECKER.DECISION_ROWS_SHA256 = CHECKER._canonical_digest(
                packet["decision_rows"]
            )
            self._assert_rejected("selected option disagrees with disposition")
        finally:
            CHECKER.DECISION_ROWS_SHA256 = original_digest

    def test_accepted_boolean_reaches_independent_status_guard(self) -> None:
        packet = self._packet()
        self._native_row(packet)["accepted"] = False
        self._write_packet(packet)

        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["$defs"]["decisionRow"]["allOf"][1]["then"]["properties"][
            "accepted"
        ]["const"] = False
        self._write(CHECKER.SCHEMA_PATH, schema)

        original_schema_digest = CHECKER.SCHEMA_SHA256
        original_decision_digest = CHECKER.DECISION_ROWS_SHA256
        try:
            CHECKER.SCHEMA_SHA256 = hashlib.sha256(
                (self.root / CHECKER.SCHEMA_PATH).read_bytes()
            ).hexdigest()
            CHECKER.DECISION_ROWS_SHA256 = CHECKER._canonical_digest(
                packet["decision_rows"]
            )
            self._assert_rejected("accepted boolean disagrees with status")
        finally:
            CHECKER.SCHEMA_SHA256 = original_schema_digest
            CHECKER.DECISION_ROWS_SHA256 = original_decision_digest

    def test_gate_count_drift_reaches_row_derived_guard(self) -> None:
        packet = self._packet()
        packet["gate_state"]["accepted_decision_count"] = 2
        packet["gate_state"]["unresolved_decision_count"] = 17
        self._write_packet(packet)

        schema = self._read(CHECKER.SCHEMA_PATH)
        gate_properties = schema["$defs"]["gateState"]["properties"]
        gate_properties["accepted_decision_count"]["const"] = 2
        gate_properties["unresolved_decision_count"]["const"] = 17
        self._write(CHECKER.SCHEMA_PATH, schema)

        original_schema_digest = CHECKER.SCHEMA_SHA256
        original_gate_digest = CHECKER.GATE_STATE_SHA256
        try:
            CHECKER.SCHEMA_SHA256 = hashlib.sha256(
                (self.root / CHECKER.SCHEMA_PATH).read_bytes()
            ).hexdigest()
            CHECKER.GATE_STATE_SHA256 = CHECKER._canonical_digest(packet["gate_state"])
            self._assert_rejected("gate decision counts disagree with decision rows")
        finally:
            CHECKER.SCHEMA_SHA256 = original_schema_digest
            CHECKER.GATE_STATE_SHA256 = original_gate_digest

    def test_accepted_decision_requires_resolution(self) -> None:
        packet = self._packet()
        row = next(
            row for row in packet["decision_rows"] if row["surface_id"] == "native_value"
        )
        del row["resolution"]
        self._write_packet(packet)
        self._assert_rejected("schema violation.*resolution.*required")

    def test_unresolved_decision_cannot_smuggle_resolution(self) -> None:
        packet = self._packet()
        native = next(
            row for row in packet["decision_rows"] if row["surface_id"] == "native_value"
        )
        packet["decision_rows"][0]["resolution"] = native["resolution"]
        self._write_packet(packet)
        self._assert_rejected("schema violation.*resolution.*not of type 'null'")

    def test_gate_counts_cannot_overclaim_resolution_or_authorization(self) -> None:
        packet = self._packet()
        packet["gate_state"]["accepted_decision_count"] = 19
        packet["gate_state"]["unresolved_decision_count"] = 0
        packet["gate_state"]["implementation_authorized"] = True
        self._write_packet(packet)
        self._assert_rejected("schema violation|gate state")

    def test_native_value_acceptance_cannot_revert_to_unresolved(self) -> None:
        packet = self._packet()
        row = next(
            row for row in packet["decision_rows"] if row["surface_id"] == "native_value"
        )
        row["decision_status"] = "unresolved"
        row["selected_option"] = None
        row["accepted"] = False
        row["source_blocking"] = True
        row["unresolved_decisions"] = ["native-value semantics reopened"]
        row["evidence_required"] = ["new acceptance packet"]
        del row["resolution"]
        self._write_packet(packet)

        original_digest = CHECKER.DECISION_ROWS_SHA256
        try:
            CHECKER.DECISION_ROWS_SHA256 = CHECKER._canonical_digest(
                packet["decision_rows"]
            )
            self._assert_rejected("accepted decision identity or count drifted")
        finally:
            CHECKER.DECISION_ROWS_SHA256 = original_digest

    def test_second_decision_cannot_be_smuggled_as_accepted(self) -> None:
        packet = self._packet()
        native = next(
            row for row in packet["decision_rows"] if row["surface_id"] == "native_value"
        )
        row = packet["decision_rows"][0]
        row["unresolved_decisions"] = []
        row["evidence_required"] = []
        row["decision_status"] = "accepted"
        row["selected_option"] = native["selected_option"]
        row["accepted"] = True
        row["source_blocking"] = False
        row["resolution"] = native["resolution"]
        self._write_packet(packet)

        original_digest = CHECKER.DECISION_ROWS_SHA256
        try:
            CHECKER.DECISION_ROWS_SHA256 = CHECKER._canonical_digest(
                packet["decision_rows"]
            )
            self._assert_rejected("accepted decision identity or count drifted")
        finally:
            CHECKER.DECISION_ROWS_SHA256 = original_digest

    def test_registry_and_archive_roles_cannot_expand(self) -> None:
        packet = self._packet()
        packet["fixed_invariants"]["registry_role"] = "semantic_authority"
        packet["fixed_invariants"]["archive_role"] = "current_state_owner"
        self._write_packet(packet)
        self._assert_rejected("schema violation|fixed architecture invariants")

    def test_coordinator_cannot_gain_authority_or_persistent_state(self) -> None:
        packet = self._packet()
        packet["fixed_invariants"]["coordinator_owns_semantic_authority"] = True
        packet["fixed_invariants"]["coordinator_owns_persistent_state"] = True
        self._write_packet(packet)
        self._assert_rejected("schema violation|fixed architecture invariants")

    def test_generic_routing_delegatecall_and_rebinding_are_rejected(self) -> None:
        packet = self._packet()
        invariants = packet["fixed_invariants"]
        invariants["generic_selector_or_calldata_route"] = True
        invariants["delegatecall"] = True
        invariants["mutable_rebinding"] = True
        self._write_packet(packet)
        self._assert_rejected("schema violation|fixed architecture invariants")

    def test_original_caller_and_snapshot_order_cannot_weaken(self) -> None:
        packet = self._packet()
        packet["fixed_invariants"]["original_caller_required"] = False
        packet["fixed_invariants"]["snapshots_before_first_mutation"] = False
        self._write_packet(packet)
        self._assert_rejected("schema violation|fixed architecture invariants")

    def test_payable_or_value_forwarding_drift_is_rejected(self) -> None:
        packet = self._packet()
        projection = packet["operation_projection"]
        projection["registry_state_mutability"] = "payable"
        projection["coordinator_state_mutability"] = "payable"
        projection["typed_collaborator_call_value_wei"] = 1
        self._write_packet(packet)
        self._assert_rejected("schema violation|57-operation projection")

    def test_unknown_signatures_cannot_be_invented_in_this_slice(self) -> None:
        packet = self._packet()
        packet["operation_projection"]["registry_signature_status"] = "accepted"
        packet["operation_projection"]["coordinator_signature_status"] = "accepted"
        self._write_packet(packet)
        self._assert_rejected("schema violation|57-operation projection")

    def test_operation_22_stop_cannot_be_removed(self) -> None:
        packet = self._packet()
        packet["fixed_invariants"]["operation_22_stop"] = ""
        packet["operation_projection"]["operation_22_effective_stop"] = ""
        packet["gate_state"]["operation_22_stop_preserved"] = False
        self._write_packet(packet)
        self._assert_rejected("schema violation|fixed architecture invariants")

    def test_missing_authority_is_reported_as_freeze_error(self) -> None:
        relative = Path("smart-contracts/interfaces/stream/IStreamArtistArchiveV2.sol")
        (self.root / relative).unlink()
        self._assert_rejected("authority archive_v2_interface is unreadable")

    def test_coordinator_source_or_interface_presence_fails_closed(self) -> None:
        for relative in (
            Path("smart-contracts/domains/artist/StreamArtistOperationCoordinator.sol"),
            CHECKER.COORDINATOR_INTERFACE_PATH,
        ):
            with self.subTest(relative=relative):
                path = self.root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("pragma solidity 0.8.19;\n", encoding="utf-8")
                self._assert_rejected("source-blocked artist component|Coordinator interface")
                path.unlink()

    def test_unmodeled_artist_source_fails_closed(self) -> None:
        path = self.root / CHECKER.ARTIST_SOURCE_ROOT / "StreamArtistRegistryV3.sol"
        path.write_text("pragma solidity 0.8.19;\n", encoding="utf-8")
        self._assert_rejected("canonical artist source set drifted")

    def test_issue_669_exact_staticcall_row_remains_bound(self) -> None:
        matrix = self._read(CHECKER.MATRIX_PATH)
        row = matrix["external_dependencies"]["issue_669"]["reserved_call_row"]
        self.assertEqual(row, CHECKER.EXPECTED_669_ROW)
        row["call_syntax"] = "signer.staticcall(context.erc1271GasCap)"
        self._write(CHECKER.MATRIX_PATH, matrix)
        matrix_digest = hashlib.sha256(
            (self.root / CHECKER.MATRIX_PATH).read_bytes()
        ).hexdigest()

        packet = self._packet()
        matrix_binding = next(
            binding
            for binding in packet["authority_bindings"]
            if binding["id"] == "semantic_owner_matrix"
        )
        matrix_binding["sha256"] = matrix_digest
        self._write_packet(packet)

        rebound_authorities = tuple(
            (
                authority_id,
                relative,
                matrix_digest if authority_id == "semantic_owner_matrix" else digest,
            )
            for authority_id, relative, digest in CHECKER.EXPECTED_AUTHORITY_BINDINGS
        )
        original_authorities = CHECKER.EXPECTED_AUTHORITY_BINDINGS
        try:
            CHECKER.EXPECTED_AUTHORITY_BINDINGS = rebound_authorities
            self._assert_rejected(
                "issue 669 exact stateless staticcall reservation drifted"
            )
        finally:
            CHECKER.EXPECTED_AUTHORITY_BINDINGS = original_authorities


if __name__ == "__main__":
    unittest.main()

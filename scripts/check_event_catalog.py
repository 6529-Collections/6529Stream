#!/usr/bin/env python3
"""Validate the v1 machine-readable event catalog ([LCM-EVENTS]).

The event-catalog row of the Verification Tooling Backlog
(docs/launch-conformance-matrix.md [LCM-TOOLING]; [LCM-EVENTS];
[LCM-REVIEW-ENTRY] condition 3; [LCM-GOLDEN] tests 8 and 20; ADR 0014
decision V6) binds the catalog generated from the spec set. The v1
catalog does not exist yet; until it lands at
``release-artifacts/latest/event-catalog.json`` this checker passes with
a note (the legacy ABI-derived ``event-topic-catalog.json`` is a
different pre-spec artifact and only its [LCM-GOLDEN] test 20
at-most-three-indexed-fields bound is asserted here).

When the catalog is present, per [LCM-EVENTS]:

1. ``schema`` is ``6529.stream.event-catalog.v1`` and the file is the
   RFC 8785/JCS canonical encoding of its content (sorted keys, compact
   separators, UTF-8).
2. Every event carries signature, ``topic0`` (recomputed as the
   keccak256 of the signature), ``schemaVersion``, owner, status
   (``active``/``archived``), ``indexed``/``unindexed`` field lists,
   ``supersedes``/``replacedBy``, ``semanticsURI``, and
   ``semanticsHash``.
3. schemaVersion discipline: ``schemaVersion`` appears among the event's
   fields unless the event is a listed standard-shape exemption
   (ERC-721/ERC-4906/ERC-7572 signatures) or carries the ``mirrorOf``
   tag of a required same-execution standard-shape mirror — the facade
   ``Transfer`` mirror of ``ControlledOwnershipChanged``
   ([FCP-EXCLUSIVITY] rule 2) is the pinned example.
4. At most three ``indexed`` fields per event ([LCM-GOLDEN] test 20).
5. Supersession links are closed: ``supersedes``/``replacedBy`` name
   catalog signatures; a replaced event is ``archived``; an archived
   replacement chain is never dropped.
6. A governed-configuration event (``governedConfiguration`` true)
   carries ``actionId`` among its fields ([GOV-ACTION-ID]).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import ascii_safe, keccak256_hex  # noqa: E402


DEFAULT_CATALOG_PATH = Path("release-artifacts/latest/event-catalog.json")
LEGACY_CATALOG_PATH = Path("release-artifacts/latest/event-topic-catalog.json")
CATALOG_SCHEMA = "6529.stream.event-catalog.v1"
SIGNATURE_RE = re.compile(r"^[A-Za-z_]\w*\((?:[^\s()]*)\)$")
REQUIRED_EVENT_FIELDS = (
    "signature",
    "topic0",
    "schemaVersion",
    "owner",
    "status",
    "indexed",
    "unindexed",
    "supersedes",
    "replacedBy",
    "semanticsURI",
    "semanticsHash",
)
STATUSES = {"active", "archived"}


class EventCatalogError(RuntimeError):
    """Raised when the v1 event catalog violates [LCM-EVENTS]."""


def canonical_json_bytes(payload: object) -> bytes:
    return json.dumps(
        payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")


def load_catalog(path: Path) -> dict:
    raw = path.read_bytes()
    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise EventCatalogError(f"{path}: not valid UTF-8 JSON: {exc}") from exc
    if raw.rstrip(b"\n") != canonical_json_bytes(payload):
        raise EventCatalogError(
            f"{path}: not RFC 8785/JCS canonical (sorted keys, compact separators)"
        )
    return payload


def standard_exemptions(catalog: dict) -> set[str]:
    listed = catalog.get("standardExemptions", [])
    if not isinstance(listed, list):
        raise EventCatalogError("standardExemptions must be a list of signatures")
    return set(listed)


def validate_event(event: dict, exemptions: set[str], signatures: set[str]) -> list[str]:
    failures: list[str] = []
    signature = event.get("signature", "<missing>")
    for field in REQUIRED_EVENT_FIELDS:
        if field not in event:
            failures.append(f"{signature}: missing required field {field!r}")
    if failures:
        return failures
    if not SIGNATURE_RE.fullmatch(signature):
        failures.append(f"{signature}: not a canonical event signature")
        return failures
    expected_topic0 = keccak256_hex(signature)
    if str(event["topic0"]).lower() != expected_topic0:
        failures.append(
            f"{signature}: topic0 drifted: catalog pins {event['topic0']}, "
            f"keccak256 of the signature is {expected_topic0}"
        )
    if event["status"] not in STATUSES:
        failures.append(f"{signature}: unknown status {event['status']!r}")
    indexed = event["indexed"]
    unindexed = event["unindexed"]
    if not isinstance(indexed, list) or not isinstance(unindexed, list):
        failures.append(f"{signature}: indexed/unindexed must be field-name lists")
        return failures
    if len(indexed) > 3:
        failures.append(
            f"{signature}: {len(indexed)} indexed fields exceed the log topic "
            "limit of three ([LCM-GOLDEN] test 20)"
        )
    fields = set(indexed) | set(unindexed)
    is_exempt = signature in exemptions
    is_mirror = bool(event.get("mirrorOf"))
    if "schemaVersion" not in fields and not is_exempt and not is_mirror:
        failures.append(
            f"{signature}: no schemaVersion field, no standard-shape exemption, "
            "and no required-mirror tag ([LCM-EVENTS])"
        )
    if is_mirror and event["mirrorOf"] not in signatures:
        failures.append(
            f"{signature}: mirrorOf names {event['mirrorOf']!r}, which is not a "
            "catalog event"
        )
    for superseded in event["supersedes"]:
        if superseded not in signatures:
            failures.append(
                f"{signature}: supersedes {superseded!r}, which is not in the catalog"
            )
    replaced_by = event["replacedBy"]
    if replaced_by is not None:
        if replaced_by not in signatures:
            failures.append(
                f"{signature}: replacedBy {replaced_by!r}, which is not in the catalog"
            )
        if event["status"] != "archived":
            failures.append(
                f"{signature}: replaced events must be archived forever "
                "([LCM-GOLDEN] test 8)"
            )
    if event.get("governedConfiguration") and "actionId" not in fields:
        failures.append(
            f"{signature}: governed-configuration event without an actionId "
            "field ([LCM-EVENTS]; [GOV-ACTION-ID])"
        )
    semantics_hash = event["semanticsHash"]
    if not isinstance(semantics_hash, dict) or not {
        "algorithm",
        "digest",
    } <= set(semantics_hash):
        failures.append(f"{signature}: semanticsHash needs algorithm and digest")
    return failures


def validate_catalog(path: Path) -> int:
    catalog = load_catalog(path)
    if catalog.get("schema") != CATALOG_SCHEMA:
        raise EventCatalogError(
            f"{path}: schema {catalog.get('schema')!r} is not {CATALOG_SCHEMA!r}"
        )
    events = catalog.get("events")
    if not isinstance(events, list) or not events:
        raise EventCatalogError(f"{path}: catalog carries no events")
    signatures = {event.get("signature") for event in events}
    if len(signatures) != len(events):
        raise EventCatalogError(f"{path}: duplicate event signatures")
    exemptions = standard_exemptions(catalog)
    failures: list[str] = []
    for event in events:
        failures.extend(validate_event(event, exemptions, signatures))
    supersessions = {
        event["signature"]: event["replacedBy"]
        for event in events
        if event.get("replacedBy")
    }
    for old, new in supersessions.items():
        replacement = next((e for e in events if e.get("signature") == new), None)
        if replacement is not None and old not in replacement.get("supersedes", []):
            failures.append(
                f"{new}: does not list {old} in supersedes despite replacing it"
            )
    if failures:
        details = "\n  - ".join(failures)
        raise EventCatalogError(
            f"event catalog failed with {len(failures)} failure(s):\n  - {details}"
        )
    return len(events)


def validate_legacy_indexed_bound(repo_root: Path) -> int | None:
    """Assert the golden test 20 bound over the legacy topic catalog.

    Returns the checked event count, or None when the legacy artifact is
    absent. The bound cannot fail for ABI-derived entries, so this is a
    guard against a hand-edited catalog, not a substitute for the v1
    catalog checks.
    """
    legacy_path = repo_root / LEGACY_CATALOG_PATH
    if not legacy_path.exists():
        return None
    legacy = json.loads(legacy_path.read_text(encoding="utf-8"))
    topics = legacy.get("topics", [])
    for topic in topics:
        indexed = [
            field for field in topic.get("inputs", []) if field.get("indexed")
        ]
        if len(indexed) > 3:
            raise EventCatalogError(
                f"{LEGACY_CATALOG_PATH.as_posix()}: {topic.get('signature')} "
                f"records {len(indexed)} indexed fields; the log topic limit "
                "is three ([LCM-GOLDEN] test 20)"
            )
    return len(topics)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=Path(__file__).resolve().parent.parent,
        type=Path,
        help="Repository root to validate.",
    )
    parser.add_argument(
        "--catalog",
        type=Path,
        default=None,
        help="Catalog path override (default: release-artifacts/latest/event-catalog.json).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        legacy_count = validate_legacy_indexed_bound(args.repo_root)
    except EventCatalogError as exc:
        print(ascii_safe(f"event catalog check failed: {exc}"), file=sys.stderr)
        return 1
    legacy_note = (
        f"; legacy topic catalog indexed bound holds over {legacy_count} events"
        if legacy_count is not None
        else ""
    )
    catalog_path = args.catalog or (args.repo_root / DEFAULT_CATALOG_PATH)
    if not catalog_path.exists():
        print(
            "event catalog check passes vacuously: the v1 machine-readable "
            f"catalog does not exist yet at {DEFAULT_CATALOG_PATH.as_posix()} "
            "([LCM-REVIEW-ENTRY] condition 3 tracks its creation)" + legacy_note
        )
        return 0
    try:
        event_count = validate_catalog(catalog_path)
    except EventCatalogError as exc:
        print(ascii_safe(f"event catalog check failed: {exc}"), file=sys.stderr)
        return 1
    print(f"event catalog is current: {event_count} events validated" + legacy_note)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

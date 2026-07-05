#!/usr/bin/env python3
"""Validate the genesis spec bundle named by ``specBundleHash``.

The spec-bundle Final-status row of the Verification Tooling Backlog
(docs/launch-conformance-matrix.md [LCM-TOOLING]; Operations gate;
[LCM-GOLDEN] test 14; [LTA-MANIFEST]; ADR 0014 decision V9) requires the
bundle named by the deployment manifest's ``specBundleHash`` to
enumerate every specification-inventory document at Final status with
per-document content hashes, with the bundle hash recomputing from the
enumerated contents.

Per [LCM-REVIEW-ENTRY] condition 7 this checker satisfies the backlog by
existing and passing against rehearsal fixtures (its self-test carries
them); the gate row binds the production run. No bundle exists yet;
until it lands at ``release-artifacts/latest/spec-bundle.json`` the
checker passes with a note.

Conservative bundle schema: ``{"schema": "6529.stream.spec-bundle.v1",
"specBundleHash": sha256-hex, "documents": [{"path", "status",
"sha256"}]}``. The bundle hash recomputes as the SHA-256 of the
RFC 8785-style canonical JSON of the ``documents`` list; each document
hash recomputes from the enumerated file's bytes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import ascii_safe, read_text  # noqa: E402


DEFAULT_BUNDLE_PATH = Path("release-artifacts/latest/spec-bundle.json")
SPEC_POLICY_PATH = Path("docs/spec-policy.md")
BUNDLE_SCHEMA = "6529.stream.spec-bundle.v1"


class SpecBundleError(RuntimeError):
    """Raised when the genesis spec bundle drifts from the inventory."""


def inventory_documents(repo_root: Path) -> set[str]:
    """Repo-relative spec-inventory document paths from spec-policy."""
    policy = read_text(repo_root / SPEC_POLICY_PATH)
    section = policy[policy.find("## Specification Inventory") :]
    documents: set[str] = set()
    for match in re.finditer(r"\]\(([^)#]+\.md)\)", section):
        path = ((repo_root / SPEC_POLICY_PATH).parent / match.group(1)).resolve()
        if not path.is_file():
            continue
        relative = Path("docs") / path.relative_to((repo_root / "docs").resolve())
        # The ADR row points at the decision-record index; ADRs carry
        # per-ADR status and are not bundle members.
        if relative.parts[:2] == ("docs", "adr"):
            continue
        documents.add(relative.as_posix())
    if not documents:
        raise SpecBundleError("no inventory documents resolved from spec-policy")
    return documents


def bundle_hash(documents: list[dict]) -> str:
    canonical = json.dumps(
        documents, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    return hashlib.sha256(canonical).hexdigest()


def validate_bundle(repo_root: Path, path: Path) -> int:
    try:
        bundle = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SpecBundleError(f"{path}: invalid JSON: {exc}") from exc
    if bundle.get("schema") != BUNDLE_SCHEMA:
        raise SpecBundleError(
            f"bundle schema {bundle.get('schema')!r} is not {BUNDLE_SCHEMA!r}"
        )
    documents = bundle.get("documents")
    if not isinstance(documents, list) or not documents:
        raise SpecBundleError("bundle enumerates no documents")
    failures: list[str] = []
    enumerated: set[str] = set()
    for entry in documents:
        doc_path = entry.get("path", "<missing>")
        enumerated.add(doc_path)
        if entry.get("status") != "Final":
            failures.append(
                f"{doc_path}: status {entry.get('status')!r} is not Final"
            )
        target = repo_root / doc_path
        if not target.is_file():
            failures.append(f"{doc_path}: enumerated file is missing")
            continue
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        if str(entry.get("sha256", "")).lower() != digest:
            failures.append(f"{doc_path}: content hash does not recompute")
    inventory = inventory_documents(repo_root)
    for missing in sorted(inventory - enumerated):
        failures.append(f"inventory document {missing} is not enumerated")
    for extra in sorted(enumerated - inventory):
        failures.append(f"bundle enumerates non-inventory document {extra}")
    expected = bundle_hash(documents)
    if str(bundle.get("specBundleHash", "")).lower() != expected:
        failures.append(
            f"specBundleHash does not recompute: expected {expected}"
        )
    if failures:
        details = "\n  - ".join(failures)
        raise SpecBundleError(
            f"spec bundle failed with {len(failures)} failure(s):\n  - {details}"
        )
    return len(documents)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=Path(__file__).resolve().parent.parent,
        type=Path,
        help="Repository root to validate.",
    )
    parser.add_argument(
        "--bundle",
        type=Path,
        default=None,
        help="Bundle path override (default: release-artifacts/latest/spec-bundle.json).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    bundle_path = args.bundle or (args.repo_root / DEFAULT_BUNDLE_PATH)
    if not bundle_path.exists():
        try:
            count = len(inventory_documents(args.repo_root))
        except SpecBundleError as exc:
            print(ascii_safe(f"spec bundle check failed: {exc}"), file=sys.stderr)
            return 1
        print(
            "spec bundle check passes vacuously: no genesis spec bundle exists "
            f"yet at {DEFAULT_BUNDLE_PATH.as_posix()}; {count} inventory "
            "documents await enumeration at Final status"
        )
        return 0
    try:
        count = validate_bundle(args.repo_root, bundle_path)
    except SpecBundleError as exc:
        print(ascii_safe(f"spec bundle check failed: {exc}"), file=sys.stderr)
        return 1
    print(f"spec bundle is current: {count} Final documents recompute")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

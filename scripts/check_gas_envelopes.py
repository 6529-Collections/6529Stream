#!/usr/bin/env python3
"""Validate local gas snapshot measurements against release gas envelopes."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ENVELOPES = (
    REPO_ROOT / "release-artifacts/baselines/v0.1.0/gas-envelopes.json"
)
EXPECTED_SCHEMA_VERSION = "6529stream.gas-envelopes.v1"
SNAPSHOT_LINE_RE = re.compile(r"^(?P<test>[^ ]+) \(gas: (?P<gas>[0-9]+)\)$")


class GasEnvelopeError(ValueError):
    """Raised when gas envelope validation fails."""


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise GasEnvelopeError(f"gas envelope file missing: {path}") from exc
    except json.JSONDecodeError as exc:
        raise GasEnvelopeError(f"invalid gas envelope JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise GasEnvelopeError("gas envelope file must contain a JSON object")
    return value


def parse_snapshot(path: Path) -> dict[str, int]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError as exc:
        raise GasEnvelopeError(f"gas snapshot file missing: {path}") from exc

    measurements: dict[str, int] = {}
    for line_number, raw_line in enumerate(lines, start=1):
        line = raw_line.strip()
        if not line:
            continue
        match = SNAPSHOT_LINE_RE.match(line)
        if not match:
            raise GasEnvelopeError(f"invalid gas snapshot line {line_number}: {raw_line!r}")
        test = match.group("test")
        if test in measurements:
            raise GasEnvelopeError(f"duplicate gas snapshot test: {test}")
        measurements[test] = int(match.group("gas"))
    if not measurements:
        raise GasEnvelopeError("gas snapshot has no measurements")
    return measurements


def _require_string(value: dict[str, Any], key: str) -> str:
    raw = value.get(key)
    if not isinstance(raw, str) or not raw.strip():
        raise GasEnvelopeError(f"gas envelope missing non-empty `{key}`")
    return raw


def _require_positive_int(value: dict[str, Any], key: str) -> int:
    raw = value.get(key)
    if not isinstance(raw, int) or isinstance(raw, bool) or raw <= 0:
        raise GasEnvelopeError(f"gas envelope `{key}` must be a positive integer")
    return raw


def validate_envelopes(envelope_path: Path) -> list[str]:
    data = load_json(envelope_path)
    if data.get("schema_version") != EXPECTED_SCHEMA_VERSION:
        raise GasEnvelopeError(
            "unexpected gas envelope schema_version: "
            f"{data.get('schema_version')!r}"
        )

    snapshot_raw = data.get("snapshot_path")
    if not isinstance(snapshot_raw, str) or not snapshot_raw.strip():
        raise GasEnvelopeError("gas envelope file must declare `snapshot_path`")
    snapshot_path = Path(snapshot_raw)
    if not snapshot_path.is_absolute():
        snapshot_path = REPO_ROOT.joinpath(snapshot_raw).resolve()

    measurements = parse_snapshot(snapshot_path)
    envelopes = data.get("envelopes")
    if not isinstance(envelopes, list) or not envelopes:
        raise GasEnvelopeError("gas envelope file must contain non-empty `envelopes`")

    covered: set[str] = set()
    messages: list[str] = []
    flows: set[str] = set()

    for index, raw_envelope in enumerate(envelopes):
        if not isinstance(raw_envelope, dict):
            raise GasEnvelopeError(f"gas envelope row {index} must be an object")
        test = _require_string(raw_envelope, "test")
        flow = _require_string(raw_envelope, "flow")
        rationale = _require_string(raw_envelope, "rationale")
        max_gas = _require_positive_int(raw_envelope, "max_gas")
        if test in covered:
            raise GasEnvelopeError(f"duplicate gas envelope test: {test}")
        if flow in flows:
            raise GasEnvelopeError(f"duplicate gas envelope flow: {flow}")
        if test not in measurements:
            raise GasEnvelopeError(f"gas envelope test missing from snapshot: {test}")
        measured = measurements[test]
        if measured > max_gas:
            raise GasEnvelopeError(
                f"{test} gas {measured} exceeds envelope {max_gas} ({flow})"
            )
        if len(rationale.split()) < 3:
            raise GasEnvelopeError(f"gas envelope rationale is too terse for {test}")
        covered.add(test)
        flows.add(flow)
        messages.append(f"{test}: {measured} <= {max_gas} ({flow})")

    uncovered = sorted(set(measurements) - covered)
    if uncovered:
        raise GasEnvelopeError(
            "gas snapshot measurements missing envelopes: " + ", ".join(uncovered)
        )
    return messages


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--envelopes",
        type=Path,
        default=DEFAULT_ENVELOPES,
        help="Path to gas envelope JSON.",
    )
    args = parser.parse_args(argv)

    try:
        messages = validate_envelopes(args.envelopes)
    except GasEnvelopeError as exc:
        print(f"gas envelope check failed: {exc}", file=sys.stderr)
        return 1

    for message in messages:
        print(message)
    print("gas envelopes are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

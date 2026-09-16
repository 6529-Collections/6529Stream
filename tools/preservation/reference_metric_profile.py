"""Generate exact immutable additive metric supplement interpretation documents."""
import argparse
import json
from pathlib import Path
from tools.museum.canonical import keccak256

ROOT = Path(__file__).resolve().parents[2]
DOCUMENTS = {
    "SCHEMA": "STREAM_REFERENCE_METRIC_SUPPLEMENT_ABI_V1",
    "PROFILE": "STREAM_REFERENCE_METRIC_SUPPLEMENT_PROFILE_V1",
}


def generated():
    lines = ["// SPDX-License-Identifier: MIT", "pragma solidity ^0.8.19;", "",
             "/// @notice Generated additive metric documents; original reference definitions are unchanged.",
             "library StreamReferenceMetricDefinitions {"]
    for name, identity in DOCUMENTS.items():
        raw = (ROOT / "schemas/records" / (identity + ".json")).read_bytes()
        parsed = json.loads(raw)
        if raw != (json.dumps(parsed, sort_keys=True, separators=(",", ":")) + "\n").encode():
            raise ValueError("noncanonical definition: " + identity)
        lines.extend([f'    bytes32 internal constant {name}_ID = keccak256("{identity}");',
                      f"    string internal constant {name}_DOCUMENT = {json.dumps(raw.decode(), ensure_ascii=True)};",
                      f"    bytes32 internal constant {name}_HASH = {keccak256(raw)};",
                      f"    uint32 internal constant {name}_BYTES = {len(raw)};"])
    return "\n".join(lines + ["}", ""])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = ROOT / "smart-contracts/domains/records/StreamReferenceMetricDefinitions.sol"
    source = generated()
    if args.check:
        if path.read_text(encoding="utf8") != source:
            raise SystemExit("metric supplement definitions differ")
    else:
        path.write_text(source, encoding="utf8", newline="\n")


if __name__ == "__main__":
    main()

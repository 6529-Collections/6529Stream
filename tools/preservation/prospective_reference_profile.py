"""Exact additive prospective ABI/schema/profile bytes, independent of existing V1 definitions."""
import argparse
import json
import re
from pathlib import Path
from Crypto.Hash import keccak

ROOT = Path(__file__).resolve().parents[2]
FILES = {
    "P": "smart-contracts/interfaces/stream/preservation/StreamProspectiveReferenceTypes.sol",
    "R": "smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol",
    "E": "smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol",
    "F": "smart-contracts/interfaces/stream/metadata/StreamConservationFloorTypes.sol",
    "M": "smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol",
    "V": "smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol",
}
NAMES = ["STREAM_PROSPECTIVE_REFERENCE_ABI_V1", "STREAM_PROSPECTIVE_NAMED_SIMULATION_PROFILE_V1", "STREAM_ABI_PROSPECTIVE_REFERENCE_V1"]

def canonical(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")

def digest(raw):
    return keccak.new(digest_bits=256, data=raw).hexdigest()

def abi_types():
    structs = {}
    for alias, path in FILES.items():
        text = (ROOT / path).read_text(encoding="utf-8-sig")
        text = re.sub(r"/\*[\s\S]*?\*/|//[^\n]*", "", text)
        for name, body in re.findall(r"struct\s+(\w+)\s*\{([^}]*)\}", text):
            fields = []
            for line in body.split(";"):
                if not line.strip():
                    continue
                parts = line.strip().split()
                assert len(parts) == 2, (name, line)
                fields.append(parts)
            structs[alias + "." + name] = (alias, fields)
    def parameter(typ, name, origin="P"):
        base = typ.split("[")[0]
        suffix = typ[len(base):]
        key = base if "." in base else origin + "." + base
        if key in structs:
            alias, fields = structs[key]
            return {"name": name, "type": "tuple" + suffix, "components": [parameter(t, n, alias) for t, n in fields]}
        if key == "M.PayloadSourceType":
            base = "uint8"
        assert re.fullmatch(r"address|bool|string|bytes(?:[1-9]|[12][0-9]|3[0-2])?|uint(?:8|16|32|64|128|256)", base), base
        return {"name": name, "type": base + suffix}
    return parameter

def outputs():
    p = abi_types()
    schema = {"name": NAMES[0], "version": 1, "encoding": "Solidity ABI 0.8.19 canonical re-encoding",
        "payload": [{"name": "domain", "type": "bytes32"}, p("Publication", "publication"), p("Source", "source"), p("Evidence", "evidence"), {"name": "environmentJSON", "type": "bytes"}],
        "receipt": p("Receipt", "receipt"), "execution": p("Execution", "execution"),
        "enums": {"PayloadSourceType": ["NONE", "INLINE_CHUNKS", "SSTORE2", "ETHFS", "DEPENDENCY_REGISTRY", "IPFS", "ARWEAVE", "HTTPS", "WEB3_CALL"]},
        "payloadDomain": "6529STREAM_PROSPECTIVE_REFERENCE_PAYLOAD_V1", "maximumPayloadBytes": 524288}
    profile = {"name": NAMES[1], "schema": NAMES[0], "canonicalization": NAMES[2], "version": 1,
        "scope": "COLLECTION pre-sale or newly introduced semantic release, independently of minted count.",
        "claim": "Curator-attributed STATIC still/BYTE_EXACT execution of one or two named simulation vectors; no EVM execution proof or universal seed coverage.",
        "source": "Actual permanent Core-bound Floor latest source row and exact currentReleaseContext; complete current selected stable/chunked script bytes and full media manifest. Source identity includes provider/runtime/config, selected Core pointers, renderer/catalog and artist. Existing actual-token snapshots and finality are not inferred.",
        "deployment": "Core-bound Floor then reference host then provider then original governed Floor source admission. Reference derives the provider after deployment, never constructor-pins its future runtime.",
        "simulation": "Fixed encoder STREAM_PROSPECTIVE context with named seed and opaque Base64 input, no tokenId/serial/finalized/Coordinator. Every vector is declared and retained; zero seed is a legitimate simulation value. One or two unique ASCII alphanumeric/underscore/hyphen names up to64bytes; input at most4096bytes.",
        "renderer": "Original selected renderer/version/context/read-set and active constructor-fixed STATIC classification are retained as provenance. The fixed prospective encoder is a separate source-pinned executable input convention, not an actual token render or finality adapter.",
        "archive": "Original complete environment ZIP and each PNG have full object identity and current dual-receipt coverage. Exact HTML and raw script plus full media ABI descriptor occur in the complete package-file inventory. Execution is canonical attributed ABI retained separately, avoiding a ZIP self-hash cycle. Current fixity refresh preserves saved original coverage identities.",
        "environment": "Original STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1 complete Windows/AMD64 software/sRGB/DPR1 still package and platform prerequisite inventory; named engine/toolchain bytes. Actual ZIP membership, executable dependency completeness and browser replay are verified offline, never inferred from inventory declarations alone.",
        "packagePaths": ["prospective/script.js", "prospective/media.abi", "prospective/<vectorName>.html"],
        "authority": "Actual current selected Metadata CURATOR collection class3 before global scope0 class8, nonzero grant revision; permissionless uploads/preparation confer no publication authority. Publication rechecks head, complete source and writer late; current reads retain original recorder/grant provenance.",
        "history": "Immutable original full Publication and canonical payload; current getter refuses source/runtime/head or archive drift. Permanent Floor may independently preserve an already-successful identical semantic release receipt.",
        "laterRequired": "Actual terminal/finalized token outputs, original serial/identity and required first/last capture coverage remain separate post-mint and finality requirements.",
        "unsupported": "Library bundles, alternate/opaque media denominators, non-native presentation, DYNAMIC works, other capture/acceptance classes and VIEW require separate implemented profiles; none is silently accepted.",
        "media": "Full semantic shared-media descriptor is bound; display/master bytes and their preservation requirements remain independently enforced by the original master/floor producer. A media URI is not archive proof.",
        "bounds": {"scriptBytes": 24576, "htmlBytes": 40960, "captures": [1, 2], "inputBytes": 4096}}
    canon = {"name": NAMES[2], "version": 1, "encoding": "abi.encode(payloadDomain,Publication,Source,Evidence,bytes environmentJSON)",
        "rules": "Exact ABI offsets/widths/padding and re-encoding equality; all tuple and array order retained. Publication.expectedSourceHash is normalized to authenticated source for preview. Environment is original complete canonical JSON. Execution is abi.encode(Execution). No receipt recordedAt or record hash enters the payload.",
        "domains": {"source": "6529STREAM_PROSPECTIVE_SOURCE_V1", "record": "6529STREAM_PROSPECTIVE_REFERENCE_RECORD_V1", "chain": "6529STREAM_PROSPECTIVE_REFERENCE_CHAIN_V1", "evidence": "6529STREAM_PROSPECTIVE_COLLECTION_REFERENCE_EVIDENCE_V1"}}
    values = [schema, profile, canon]
    result = {f"schemas/preservation/prospective/{name}.json": canonical(value) for name, value in zip(NAMES, values)}
    lines = ["// SPDX-License-Identifier: MIT", "pragma solidity ^0.8.19;", "", "// Generated by tools.preservation.prospective_reference_profile; do not edit.", "library StreamProspectiveReferenceDefinitions {"]
    for label, name, value in zip(["SCHEMA", "PROFILE", "CANON"], NAMES, values):
        raw = canonical(value)
        lines += [f'    bytes32 public constant {label}_ID = keccak256("{name}");', f'    bytes32 public constant {label}_HASH = 0x{digest(raw)};', f'    uint32 public constant {label}_BYTES = {len(raw)};']
    lines += ["}", ""]
    result["smart-contracts/domains/records/StreamProspectiveReferenceDefinitions.sol"] = "\n".join(lines).encode()
    return result

def main():
    parser = argparse.ArgumentParser(); parser.add_argument("--check", action="store_true"); args = parser.parse_args()
    for name, raw in outputs().items():
        target = ROOT / name
        if args.check:
            assert target.read_bytes() == raw, name
        else:
            target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(raw)
    print("Prospective definitions exact.")
if __name__ == "__main__":
    main()

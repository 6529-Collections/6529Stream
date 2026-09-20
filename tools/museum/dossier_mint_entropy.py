"""Compose retained mint evidence and optional complete original-coordinator history.

The existing examination stays byte-for-byte intact. Missing coordinator reads
are unknown, including when a renderer happens to display a finished image.
"""
from copy import deepcopy
from pathlib import Path
from tempfile import TemporaryDirectory

from . import dossier_gather as gather
from . import object_dossier as base
from . import object_dossier_native as native
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_abi import decode
from .chain_history import LOG_FIELDS
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .independent_wire import require

MODE = "token_mint_entropy_examination"
PROFILE = "STREAM_MUSEUM_MINT_ENTROPY_EXAMINATION_V1"
INPUTS = ("anchor.json", "transcript.json", "snapshot.json")
PIN_NAMES = {"anchorHash", "transcriptHash", "snapshotHash", "provenance"}
TOOL_NAMES = ("dossier_mint_entropy.py", "token_mint_evidence.py", "mint_entropy_source.py")
CLAIMS = {"originalExaminationReplayed": True, "originalMintEvidenceRetained": True,
    "entropyStateInferredFromRenderer": False, "syntheticEvidencePromoted": False,
    "canonicalAcquisitionPacketEmitted": False, "fullObjectDossierConformance": False,
    "sourceConsensusVerified": False, "institutionalAcceptance": False, "networkFetch": False}
QUALIFICATION = ("Original retained mint and optional original-coordinator evidence are replayed and joined. "
    "Complete means within the declared source reader and bounded RPC history, not a consensus proof. "
    "Unknown entropy is never an exemption, terminal status or absent history. "
    "This is an examination package, not a complete canonical acquisition packet or object dossier.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_export_profile",
    "baseMode": gather.MODE, "entropySourceCount": "0_or_1",
    "scope": "One unchanged verified examination, its actual mint originals, and optional complete bounded original-coordinator capture.",
    "joins": "Exact source identity, original coordinator, mint events and commitment; shared runtime pins and repeated RPC answers.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "mint/entropy requires explicit public disclosure before source reads")


def _originals(files, manifest):
    """Extract the fixture only after the containing examination has been replayed."""
    retained = {name: files["source/retained/" + name] for name in base.RETENTION_NAMES}
    with TemporaryDirectory(prefix="stream-mint-originals-") as temporary:
        directory = Path(temporary) / "retained"
        write_tree(retained, directory)
        originals, _ = base.read_fixture(directory, manifest["retainedManifestHash"])
    return originals


def _merge_transcript(raw, reads, pins):
    rows = loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)["calls"]
    native._merge_rpc_results(rows, reads)
    for row in rows:
        if row["method"] != "eth_getCode":
            continue
        address, block = row["params"]
        code = hex_bytes(row["result"])
        # These are already-replayed sources. Keep even addresses discovered by
        # their concrete readers, instead of considering only input code pins.
        if code:
            digest = keccak256(code)
            require(address not in pins or pins[address] == digest, "mint/entropy observed runtime conflict")
            pins[address] = digest


def _shared_observations(examination, originals, reference):
    pins = {p["address"]: p["runtimeHash"] for p in reference["sourceAnchor"]["runtimePins"]}
    reads = {p["requestHash"]: p["resultHash"] for p in reference["rpcReadPins"]}
    evidence = loads(originals["deployment-evidence.json"], maximum=MAX_BYTES, canonical=True)
    native._merge_rpc_results([{"method": "eth_getTransactionReceipt", "params": [evidence["tokenMint"]["transactionHash"]],
        "result": evidence["tokenMint"]["receipt"]}], reads)
    for view in evidence["tokenSourceBlockViews"].values():
        native._merge_rpc_results([{"method": "eth_call", "params": [{"to": view["to"], "data": view["data"]},
            {"blockHash": view["blockHash"], "requireCanonical": True}], "result": view["result"]}], reads)
    for name in ("transcript.json", "publication-transcript.json", "interpretation-transcript.json"):
        if name in originals:
            _merge_transcript(originals[name], reads, pins)
    inputs = loads(examination["inputs/sources.json"], maximum=MAX_MANIFEST, canonical=True)
    for row in inputs["sources"]:
        anchor = loads(examination["sources/" + row["anchorPath"]], maximum=524288, canonical=True)
        declared = anchor.get("codePins", [])
        if "coreRuntimeHash" in anchor:
            declared = [*declared, {"address": anchor["core"], "runtimeHash": anchor["coreRuntimeHash"]}]
        for pin in declared:
            address, digest = pin["address"], pin["runtimeHash"]
            require(address not in pins or pins[address] == digest, "mint/entropy shared runtime conflict")
            pins[address] = digest
        _merge_transcript(examination["sources/" + row["transcriptPath"]], reads, pins)
    return pins, reads


def _inputs(files, pins):
    require(type(files) is dict and set(files) == set(INPUTS), "mint/entropy exact capture triplet required")
    base._bounded(files)
    require(type(pins) is dict and set(pins) == PIN_NAMES
        and pins["provenance"] in ("synthetic_fixture", "trusted_rpc"), "mint/entropy explicit capture pins/provenance required")
    for name, limit in (("anchor", 524288), ("transcript", MAX_TRANSCRIPT), ("snapshot", MAX_BYTES)):
        raw, digest = files[name + ".json"], pins[name + "Hash"]
        require(0 < len(raw) <= limit and any(hex_bytes(digest, 32)) and keccak256(raw) == digest,
            "mint/entropy original " + name + " pin/bound differs")


def _normalized(log):
    return {key: log[key] for key in LOG_FIELDS}


def _entropy(examination, originals, reference, mint, files, pins):
    """Replay first; common labels alone cannot turn two captures into one state."""
    from .mint_entropy_source import MintEntropySource
    _inputs(files, pins)
    source = MintEntropySource(files["anchor.json"], ReplayTransport(files["transcript.json"], pins["transcriptHash"]),
        provenance=pins["provenance"])
    shared_pins, reads = _shared_observations(examination, originals, reference)
    native._join_anchor("mint_entropy", source.a, reference, shared_pins)
    state = reference["sourceState"]
    require(source.a["tokenId"] == state["tokenId"] and source.a["collectionId"] == state["collectionId"],
        "mint/entropy exact token/collection differs")
    original_coordinator = mint["mint"]["identity"]["coordinatorAtMint"]
    deployment = loads(originals["deployment-evidence.json"], maximum=MAX_BYTES, canonical=True)
    artifact = deployment["artifacts"]["StreamEntropyCoordinator"]
    require(source.a["coordinator"] == original_coordinator and artifact["address"] == original_coordinator
        and source.pins[original_coordinator] == artifact["runtimeHash"],
        "mint/entropy original coordinator deployment/runtime differs")
    snapshot = source.snapshot()
    require(snapshot == files["snapshot.json"] and source.transcript() == files["transcript.json"],
        "mint/entropy original source replay differs")
    native._merge_observed_code(source, shared_pins)
    native._merge_rpc_results(source.reader.rows, reads)
    result = loads(snapshot, maximum=MAX_BYTES, canonical=True)
    _join_mint(result, mint)
    return result


def _join_mint(result, mint):
    # Defined over concrete reader and original-mint reports, not caller claims.
    original = mint["mint"]
    facts = mint["sourceBlockViews"]["coreFacts"]
    expected = original["identity"] | {"lifecycle": facts["lifecycle"], "burned": facts["burned"]}
    require({key: result["identity"].get(key) for key in expected} == expected,
        "mint/entropy original Core identity differs")
    require(result["identity"]["tokenDataHash"] == original["tokenData"]["keccak256"],
        "mint/entropy original token data differs")
    require(result["mint"]["mintCommitment"] == original["mintCommitment"], "mint/entropy original mint commitment differs")
    for key in ("registered", "entropyRegistered", "transfer"):
        require(_normalized(result["mint"]["logs"][key]) == _normalized(original["logs"][key]),
            "mint/entropy original mint event differs: " + key)
    current_owner, = decode(("address",), hex_bytes(result["mint"]["tokenTransfers"][-1]["topics"][2], 32))
    require(current_owner == facts["owner"], "mint/entropy original source-block owner differs")


def _tools(snapshot=None):
    expected = {"tool/" + name + ".txt" for name in TOOL_NAMES}
    if snapshot is None:
        snapshot = {"tool/" + name + ".txt": Path(__file__).with_name(name).read_bytes().replace(b"\r\n", b"\n") for name in TOOL_NAMES}
    require(type(snapshot) is dict and set(snapshot) == expected, "mint/entropy inert tool snapshot set differs")
    for raw in snapshot.values():
        require(type(raw) is bytes and 0 < len(raw) <= MAX_MANIFEST and b"\r" not in raw, "mint/entropy inert tool bounds/encoding")
        raw.decode("utf-8")
    return snapshot | {"tool/source-index.json": dumps({"mode": "inert_implementation_provenance",
        "completeRuntimeArchive": False, "files": [base._ref(p, b) for p, b in sorted(snapshot.items())]})}


def _report(original, original_hash, mint, entropy):
    items = deepcopy(original["items"])
    for row in items:
        row["evidence"] = [("examination/packet/fields.json#" + p if p.startswith("/") else "examination/" + p)
            for p in row["evidence"]]
    item = items[3]
    require(item["item"] == "4", "mint/entropy base item order differs")
    item["evidence"] = ["mint/report.json"]
    if entropy is None:
        item["remaining"] = "Original coordinator tokenEntropy/tokenSeed/status reads and complete Requested/Finalized history are not retained. Renderer output does not supply them."
        observation = {"status": "unresolved", "packetFragmentPath": None, "terminalEligible": None,
            "missing": ["status", "seed", "provider", "providerEpoch", "providerConfigHash", "requestKey",
                "providerRequestId", "requestAttempt", "completeEntropyRequestedFinalizedHistory"]}
    else:
        item.update(status="derived_within_source_profile", remaining="RPC source provenance remains externally admitted; consensus verification and overall finality are not claimed.")
        item["evidence"].extend(["entropy/packet-fragment.json", "entropy/source/snapshot.json", "entropy/leaf-preimage.bin"])
        observation = {"status": "complete_within_source_profile", "packetFragmentPath": "entropy/packet-fragment.json",
            "terminalEligible": entropy["terminalEligible"], "observedStatus": entropy["observedStatus"],
            "observedStatusLabel": entropy["observedStatusLabel"], "missing": []}
    return {"profile": PROFILE, "sourceState": original["sourceState"], "sourceAnchor": original["sourceAnchor"],
        "baseExamination": {"manifestHash": original_hash, "fieldsPath": "examination/packet/fields.json"},
        "mintEvidence": {"reportPath": "mint/report.json", "identity": mint["mint"]["identity"]},
        "entropy": observation, "items": items,
        "unresolvedItems": [r["item"] for r in items if r["status"] == "unresolved"],
        "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}


def _examination(report):
    lines = ["# Mint and entropy examination", "", QUALIFICATION, "",
        "Entropy evidence: `" + report["entropy"]["status"] + "`.", "",
        "| Item | Requirement | Status | Remaining evidence |", "| --- | --- | --- | --- |"]
    lines += ["| " + " | ".join((r["item"], r["name"], r["status"], r["remaining"])) + " |" for r in report["items"]]
    lines += ["", "Original mint bytes and event links: `mint/report.json`.",
        "The earlier examination is retained unchanged under `examination/`.", ""]
    return "\n".join(lines).encode("utf-8")


def compose(examination, examination_hash, *, disclosure, entropy_files=None, entropy_pins=None, tool_snapshot=None):
    """Replay and compose; optional entropy input is one exact externally pinned triplet."""
    _public(disclosure)
    require((entropy_files is None) == (entropy_pins is None), "mint/entropy capture and pins must be supplied together")
    previous = gather.verify(examination, examination_hash)
    files = dict(previous.files)
    manifest = loads(previous.manifest, maximum=MAX_MANIFEST, canonical=True)
    originals = _originals(files, manifest)
    reference = native.reference_from_originals(previous.report["sourceState"], originals)
    from .token_mint_evidence import extract
    extracted, mint = extract(reference, originals)
    entropy = None if entropy_files is None else _entropy(files, originals, reference, mint, entropy_files, entropy_pins)
    payloads = {"examination/" + p: b for p, b in files.items()}
    payloads.update(_tools(tool_snapshot))
    require(not set(payloads) & set(extracted), "mint/entropy extracted path collision")
    payloads.update(extracted)
    payloads["mint/report.json"] = dumps(mint)
    if entropy is not None:
        from .mint_entropy_source import PROFILE_BYTES as SOURCE_PROFILE_BYTES
        from ..metadata import genesis_dossier_profile as packet
        fragment = entropy["entropy"]
        definitions = packet.definitions()
        require(packet.Draft202012Validator({"$defs": definitions, **packet.ref("entropy")}).is_valid(fragment),
            "mint/entropy canonical packet fragment shape differs")
        packet._typed(fragment, packet.ref("entropy"), definitions)
        require(packet._entropy_hash(fragment["leaf"]) == fragment["leafHash"], "mint/entropy exact LTA leaf differs")
        payloads.update({"entropy/source/" + p: b for p, b in entropy_files.items()})
        payloads["entropy/packet-fragment.json"] = dumps(fragment)
        payloads["entropy/leaf-preimage.bin"] = hex_bytes(entropy["entropyLeafBytes"])
        require(keccak256(payloads["entropy/leaf-preimage.bin"]) == fragment["leafHash"], "mint/entropy leaf bytes differ")
        payloads["definitions/mint-entropy-source-profile.json"] = SOURCE_PROFILE_BYTES
    report = _report(previous.report, examination_hash, mint, entropy)
    report["entropy"]["provenance"] = None if entropy_pins is None else entropy_pins["provenance"]
    payloads.update({"packet/fields.json": dumps(report), "packet/examination.md": _examination(report),
        "definitions/mint-entropy-examination-profile.json": PROFILE_BYTES})
    base._bounded(payloads)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "examinationManifestHash": examination_hash, "entropyPins": entropy_pins,
        "files": [base._ref(p, b) for p, b in sorted(payloads.items())], "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "mint/entropy manifest bound")
    payloads["manifest.json"] = raw
    base._bounded(payloads)
    return base.Assembly(tuple(sorted(payloads.items())), raw, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files)
    raw = files.get("manifest.json", b"")
    require(keccak256(raw) == expected_hash, "mint/entropy external manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "profile", "version", "profileHash", "examinationManifestHash",
        "entropyPins", "files", "claims", "qualification"} and value["mode"] == MODE and value["profile"] == PROFILE
        and value["version"] == "1" and value["profileHash"] == PROFILE_HASH and value["claims"] == CLAIMS
        and value["qualification"] == QUALIFICATION, "mint/entropy closed manifest differs")
    require(value["files"] == [base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"],
        "mint/entropy original file commitments differ")
    tools = {"tool/" + p + ".txt": files.get("tool/" + p + ".txt") for p in TOOL_NAMES}
    entropy_files = {p[len("entropy/source/"):]: b for p, b in files.items() if p.startswith("entropy/source/")}
    require(bool(entropy_files) == (value["entropyPins"] is not None), "mint/entropy original capture presence differs")
    rebuilt = compose({p[len("examination/"):]: b for p, b in files.items() if p.startswith("examination/")},
        value["examinationManifestHash"], disclosure="public", entropy_files=entropy_files or None,
        entropy_pins=value["entropyPins"], tool_snapshot=tools)
    require(dict(rebuilt.files) == files, "mint/entropy source reconstruction differs")
    return rebuilt


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("canonical acquisition packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedItems"]))


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("build")
    build.add_argument("--examination", type=Path, required=True)
    build.add_argument("--examination-hash", required=True)
    build.add_argument("--entropy", type=Path, help="Optional directory with exactly anchor.json, transcript.json and snapshot.json")
    for name in ("anchor-hash", "transcript-hash", "snapshot-hash"):
        build.add_argument("--entropy-" + name)
    build.add_argument("--provenance", choices=("synthetic_fixture", "trusted_rpc"))
    build.add_argument("--disclosure", required=True)
    build.add_argument("--output", type=Path, required=True)
    for name in ("verify", "complete-packet"):
        command = sub.add_parser(name)
        command.add_argument("directory", type=Path)
        command.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    if args.command == "build":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        pins = {"anchorHash": args.entropy_anchor_hash, "transcriptHash": args.entropy_transcript_hash,
            "snapshotHash": args.entropy_snapshot_hash, "provenance": args.provenance}
        require(all(v is None for v in pins.values()) if args.entropy is None else all(v is not None for v in pins.values()),
            "mint/entropy optional capture requires all three external hashes and explicit provenance")
        inputs = [args.examination] + ([] if args.entropy is None else [args.entropy])
        _destination(args.output, inputs)
        result = compose(read_tree(args.examination), args.examination_hash, disclosure=args.disclosure,
            entropy_files=None if args.entropy is None else read_tree(args.entropy), entropy_pins=None if args.entropy is None else pins)
        _publish(dict(result.files), args.output, inputs)
    elif args.command == "complete-packet":
        complete_packet(read_tree(args.directory), args.manifest_hash)
        return
    else:
        result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "entropyEvidence": result.report["entropy"]["status"], "canonicalPacketReady": False,
        "unresolvedItems": result.report["unresolvedItems"]}).decode("utf-8"))


if __name__ == "__main__":
    main()

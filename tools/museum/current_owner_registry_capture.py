"""Opt-in Registry coverage at the existing final local Owner/Museum block.

No deployment, registration, new source block, or runtime/source admission is
performed here. The caller supplies and retains its external admission artifact.
"""
import hashlib
from pathlib import Path
import urllib.parse

from .canonical import dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import calldata, decode
from .chain_rpc import ReplayTransport
from .canonical_composition_observations_v1 import reconcile
from .genesis_registry_source_v1 import (COMMON, COLLECTION_METADATA, PROFILE,
    SOURCE_REVISION, GenesisRegistrySource)
from . import genesis_registry_plan_v1 as plan_module
from . import genesis_registry_coverage_v1 as coverage_module
from .independent_wire import ZERO_ADDRESS, require
from .dossier_hosts_source import POINTER
from .owner_record_source import OwnerRecordSource
from .package_recorded import verify_recorded_package
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport
from .repository_exchange import _publish

MAX_BRIDGE = 16 * 1024 * 1024
QUALIFICATION = ("Read-only fixed 51-name Registry coverage at the existing final local Owner/Museum "
    "block. The external runtime/source bridge is retained and byte-pinned, not semantically "
    "verified by this adapter. Reader SOURCE_REVISION is not deployment-build provenance. "
    "No registrations, full Registry history, consensus, complete dossier, institutional "
    "acceptance, full VIEW workflow or actual-chain acceptance is inferred.")


def bridge_bytes(raw, expected_hash):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_BRIDGE,
        "Registry runtime bridge byte bound")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        "Registry external runtime bridge commitment differs")
    return raw, expected_hash


def configure_parser(parser):
    parser.add_argument("--registry-runtime-bridge", type=Path,
        help="Opt in to read-only Registry coverage with a separately admitted runtime/source artifact")
    parser.add_argument("--registry-runtime-bridge-hash",
        help="External Keccak-256 commitment of the exact runtime/source admission artifact")


def prepare_arguments(args):
    path, digest = args.registry_runtime_bridge, args.registry_runtime_bridge_hash
    require((path is None) == (digest is None), "Registry runtime bridge requires file and external hash")
    args.registry_bridge = None
    if path is not None:
        require(path.stat().st_size <= MAX_BRIDGE, "Registry runtime bridge byte bound")
        with path.open("rb") as stream:
            raw = stream.read(MAX_BRIDGE + 1)
        args.registry_bridge = bridge_bytes(raw, digest)
        # Refuse a missing/changed frozen plan before the existing process starts.
        plan_module.prepare()


def configure_fixture(fixture, args):
    fixture.registry_bridge = args.registry_bridge


def _read(reader, target, signature, outputs, inputs=(), values=()):
    return decode(outputs, hex_bytes(reader.call(target, calldata(signature, inputs, values))),
        maximum=65536)


def discover_anchor(common, artifacts, reader, runtime_bridge_hash, token_id):
    """Discover only at the caller's retained block; expected code comes from artifacts."""
    require(common["chainId"] == "31337" and common["environment"] == "local_evm_fixture",
        "Registry owner bridge is local chain 31337 only")
    require(reader.block == {"blockHash": common["blockHash"], "requireCanonical": True},
        "Registry discovery block differs")
    require(type(artifacts) is dict and 0 < len(artifacts) <= 4096,
        "Registry deployment artifact bound")
    require(any(hex_bytes(runtime_bridge_hash, 32)), "Registry runtime admission missing")
    core = common["core"]
    pointer, = _read(reader, core, "getSatellitePointer(bytes32)", (POINTER,),
        ("bytes32",), (COLLECTION_METADATA,))
    metadata, admission_registry = pointer[0], pointer[5]
    require(metadata != ZERO_ADDRESS and admission_registry != ZERO_ADDRESS
        and pointer[3] == COLLECTION_METADATA, "Registry selected Metadata pointer differs")
    schemas, = _read(reader, metadata, "schemaRegistry()", ("address",))
    store, = _read(reader, metadata, "chunkStore()", ("address",))
    governance, = _read(reader, schemas, "governanceAuthority()", ("address",))
    roles = (core, metadata, admission_registry, schemas, store, governance)
    require(len(set(roles)) == 6 and all(any(hex_bytes(a, 20)) for a in roles),
        "Registry exactly six original roles required")
    pins = []
    for address in sorted(roles):
        rows = [row for row in artifacts.values() if row.get("address") == address]
        require(len(rows) == 1 and any(hex_bytes(rows[0]["runtimeHash"], 32)),
            "Registry role lacks one original deployment runtime: " + address)
        pins.append({"address": address, "runtimeHash": rows[0]["runtimeHash"]})
    pin_map = {row["address"]: row["runtimeHash"] for row in pins}
    require(pointer[1] == pin_map[metadata], "Registry pointer/deployment runtime differs")
    identity = _read(reader, core, "tokenCollectionIdentity(uint256)",
        ("bool", "uint256", "uint256", "bool"), ("uint256",), (token_id,))
    require(identity[0] and identity[1] > 0, "Registry joined owner token identity absent")
    anchor = {"profile": PROFILE, **{key: common[key] for key in COMMON},
        "coreRuntimeHash": pin_map[core], "codePins": pins,
        "runtimeAdmission": {"sourceCommit": SOURCE_REVISION,
            "kind": "externally_admitted_runtime", "artifactHash": runtime_bridge_hash}}
    return dumps(anchor), str(identity[1])


def _observation(name, anchor_raw, transcript_raw):
    """Only call after that source's concrete replay succeeds."""
    transcript = loads(transcript_raw, maximum=64 * 1024 * 1024, canonical=True)
    pins = {row["params"][0]: keccak256(hex_bytes(row["result"]))
        for row in transcript["calls"] if row["method"] == "eth_getCode"}
    return {"kind": "rpc", "name": name,
        "anchor": loads(anchor_raw, maximum=524288, canonical=True),
        "transcript": transcript, "runtimePins": pins, "provenance": "trusted_rpc"}


def capture_registry(fixture, output, account_hash, captured):
    """Add separate coverage and join evidence after the original Owner export."""
    raw_bridge, bridge_hash = bridge_bytes(*fixture.registry_bridge)
    output = Path(output)
    require(urllib.parse.urlparse(fixture.endpoint).hostname == "127.0.0.1",
        "Registry owner capture loopback only")
    original = verify_recorded_package(output / "package", account_hash)
    account_files = dict(original.files)
    account_raw = account_files["inputs/anchor.json"]
    account = loads(account_raw, maximum=524288, canonical=True)
    inputs, owner_pins, _, _, _ = captured
    for name, key in (("anchor.json", "anchorHash"), ("transcript.json", "transcriptHash")):
        require(keccak256(inputs[name]) == owner_pins[key], "Registry original owner input differs")
    owner = OwnerRecordSource(inputs["anchor.json"],
        ReplayTransport(inputs["transcript.json"], owner_pins["transcriptHash"]), provenance="trusted_rpc")
    require(keccak256(owner.snapshot()) == owner_pins["sourceHash"],
        "Registry original owner replay differs")
    for key in COMMON:
        require(owner.a[key] == account[key], "Registry account/owner source differs: " + key)
    require(inputs["deployment-evidence.json"] == account_files["inputs/deployment-evidence.json"]
        and keccak256(inputs["deployment-evidence.json"]) == account["deploymentEvidenceHash"],
        "Registry shared deployment evidence differs")
    evidence = loads(inputs["deployment-evidence.json"], maximum=64 * 1024 * 1024, canonical=True)
    require(evidence["nativeInputManifestSha256"] == hashlib.sha256(fixture.manifest_raw).hexdigest(),
        "Registry deployment native manifest differs")
    token_ids = {uint(row["tokenId"]) for row in owner.a["records"]}
    require(len(token_ids) == 1 and next(iter(token_ids)) == fixture.token_id,
        "Registry one original owner token required")
    transport = PublicRpcTransport(fixture.endpoint)
    discovery = PublicRecordingReader(transport, account["blockHash"])
    anchor_raw, collection = discover_anchor(account, evidence["artifacts"], discovery,
        bridge_hash, fixture.token_id)
    discovery_raw = discovery.transcript()
    discovery_replay = PublicReplayTransport(discovery_raw, keccak256(discovery_raw))
    replay = PublicRecordingReader(discovery_replay, account["blockHash"])
    require(discover_anchor(account, evidence["artifacts"], replay, bridge_hash, fixture.token_id)
        == (anchor_raw, collection), "Registry discovery replay differs")
    discovery_replay.finish()
    plan = plan_module.prepare()
    source = GenesisRegistrySource(anchor_raw, transport, plan_files=dict(plan.files),
        plan_hash=plan.manifest_hash, provenance="trusted_rpc")
    snapshot_raw = source.snapshot()
    transcript_raw = source.transcript()
    covered = coverage_module.assemble(dict(plan.files), plan.manifest_hash, anchor_raw,
        keccak256(anchor_raw), transcript_raw, keccak256(transcript_raw),
        provenance="trusted_rpc", disclosure="public")
    require(dict(covered.files)["source/snapshot.json"] == snapshot_raw,
        "Registry source/offline coverage differs")
    verified = coverage_module.verify(dict(covered.files), covered.manifest_hash)
    registry_observation = coverage_module.observation(dict(verified.files), verified.manifest_hash)
    reference = {**{key: account[key] for key in COMMON},
        "collectionId": collection, "tokenId": str(fixture.token_id)}
    discovery_observation = _observation("owner-registry-discovery", anchor_raw, discovery_raw)
    discovery_observation["runtimePins"] = {row["address"]: row["runtimeHash"]
        for row in loads(anchor_raw)["codePins"]}
    joined = reconcile(reference, [
        _observation("owner-account-source", account_raw, account_files["inputs/transcript.json"]),
        _observation("owner-record-source", inputs["anchor.json"], inputs["transcript.json"]),
        discovery_observation, registry_observation])
    report = {"mode": "current_owner_registry_join_v1", "accountManifestHash": account_hash,
        "ownerInputPins": owner_pins, "coverageManifestHash": covered.manifest_hash,
        "registryAnchorHash": keccak256(anchor_raw), "registrySnapshotHash": keccak256(snapshot_raw),
        "registryTranscriptHash": keccak256(transcript_raw),
        "discoveryTranscriptHash": keccak256(discovery_raw), "runtimeBridgeHash": bridge_hash,
        "readerSourceRevision": SOURCE_REVISION,
        "nativeInputManifestSha256": evidence["nativeInputManifestSha256"],
        "coverage": covered.report["nativeSource"]["coverage"], "sourceJoin": joined,
        "runtimeBridgeSemanticsVerified": False, "registrationPerformed": False,
        "qualification": QUALIFICATION}
    # Publish only after complete concrete replay and cross-source consistency.
    require(not (output / "registry-coverage").exists(), "Registry coverage output exists")
    for name in ("registry-discovery-transcript.json", "registry-runtime-bridge.bin", "registry-capture.json"):
        require(not (output / name).exists(), "Registry integration output exists")
    _publish(dict(covered.files), output / "registry-coverage", [])
    for name, raw in (("registry-discovery-transcript.json", discovery_raw),
            ("registry-runtime-bridge.bin", raw_bridge), ("registry-capture.json", dumps(report))):
        with (output / name).open("xb") as stream:
            stream.write(raw)
    return report

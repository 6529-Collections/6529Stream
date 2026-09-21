"""Coherent synthetic attributed retrieval over the exact new inventory profile."""

from copy import deepcopy
import base64
from hashlib import sha256

from . import view_preservation_bundle_wire_v1 as archive
from . import view_preservation_inventory_sources_v1 as sources
from . import view_preservation_inventory_types_v1 as it
from . import view_preservation_retrieval_inventory_v1 as inventory_wire
from . import view_preservation_retrieval_types_v1 as t
from . import view_preservation_retrieval_wire_v1 as wire
from .canonical import hex_bytes, keccak256 as K, schema_id as H
from .chain_abi import decode, encode
from .independent_wire import ZERO as Z, json_values
from .native_finality_wire import from_json
from .test_view_preservation_bundle_wire_v1 import checkpoint, zero
from .test_view_preservation_retrieval_inventory_v1 import supplied as inventory_supplied


MEDIA_BYTES = b"synthetic attributed VIEW retrieval bytes; no network request"
MANIFEST_BYTES = b"synthetic attributed Arweave manifest bytes; paths remain uninterpreted"


def A(number): return "0x" + format(number, "040x")
def D(label): return H("synthetic VIEW retrieval " + label)
def _hash(kinds, values): return K(encode(kinds, values))
def _transaction(raw): return D("Arweave transaction " + K(raw))
def _ar(transaction):
    return "ar://" + base64.urlsafe_b64encode(hex_bytes(transaction, 32)).rstrip(b"=").decode("ascii")


def _archive(context, graph, source, media_bytes):
    artist = source[10]; host = graph["externalCoverage"]["address"]
    chain = int(context["chainId"]); digest = "0x" + sha256(media_bytes).hexdigest()
    obj = (artist, D("media schema"), H("RAW_BYTES"), K(media_bytes), digest,
        D("Arweave data root"), len(media_bytes), D("media format"),
        D("format catalogue"), D("format catalogue bytes"))
    object_key = archive.external_object_hash(obj, chain, host, context["core"])
    writer = A(99102)
    family = (D("institutional family id"), D("institutional network"),
        D("institutional protocol"), D("institutional addressing"),
        D("institutional custodian"), D("institutional funding"),
        D("institutional retrieval"), D("institutional jurisdiction"), 2, writer,
        H("STREAM_INSTITUTIONAL_EXTERNAL_OBJECT_POSSESSION_V1"))
    families = (D("endowed original family"), archive._domain(
        "6529STREAM_EXTERNAL_ARCHIVE_FAMILY_V1", ("uint256", "address", t.ARCHIVE_FAMILY),
        (chain, host, family)))
    native_key = D("native checkpoint " + object_key)
    transaction = _transaction(media_bytes)
    uri = source[9]; locators = (hex_bytes(transaction), uri.encode("utf-8"))
    receipts, fixities, receipt_keys, fixity_keys, hashes = [], [], [], [], []
    for index, (family_key, location) in enumerate(zip(families, locators)):
        receipt = (object_key, family_key, K(location),
            H("CONTENT_ADDRESSED_INCLUSION" if index == 0 else "ATTESTED_POSSESSION"),
            D("endowed proof") if index == 0 else H("STREAM_INSTITUTIONAL_EXTERNAL_OBJECT_POSSESSION_V1"),
            native_key if index == 0 else D("institutional proof"),
            A(99101) if index == 0 else writer, 110, index, 200)
        key = archive._domain("6529STREAM_EXTERNAL_RECEIPT_V1",
            ("uint256", "address", archive.RECEIPT), (chain, host, receipt))
        receipt_keys.append(key)
        raw = encode((archive.RECEIPT, "bytes", "bytes"),
            (receipt, location, b"synthetic retained receipt signature"))
        receipts.append("0x" + raw.hex()); hashes.append(_hash(("bytes32", "bytes"), (key, raw)))
        fixity = (key, object_key, family_key, K(location), D("fixity profile"), digest,
            digest, obj[3], obj[3], obj[5], obj[5], obj[6], obj[6], 111, 1,
            D("fixity report"), Z, Z, A(99200 + index), index, 200)
        fkey = archive._domain("6529STREAM_EXTERNAL_FIXITY_V1",
            ("uint256", "address", archive.EXTERNAL_FIXITY), (chain, host, fixity))
        fixity_keys.append(fkey)
        body = encode((archive.EXTERNAL_FIXITY, "bytes"),
            (fixity, b"synthetic retained fixity signature"))
        fixities.append("0x" + body.hex())
    for key, body in zip(fixity_keys, fixities):
        hashes.append(_hash(("bytes32", "bytes"), (key, hex_bytes(body))))
    native, native_hash = checkpoint(native_key, True, transaction_id=transaction,
        data_root=obj[5], data_size=obj[6], payload_digest=digest, content_hash=obj[3])
    hashes.append(native_hash)
    coverage = (Z, object_key, artist, *obj[3:7], *families, *receipt_keys, *fixity_keys,
        native_key, archive.EXTERNAL_PROFILE)
    coverage = (archive.external_coverage_hash(coverage, chain, host), *coverage[1:])
    commitment = _hash(("address", "bytes32", it.ADMISSION[3], ("bytes32",) * 5),
        (host, graph["externalCoverage"]["runtimeHash"], coverage, tuple(hashes)))
    admission = ((1, coverage[0], object_key), commitment, Z, coverage, zero(it.ADMISSION[4]))
    evidence = {"object": json_values(obj), "receipts": receipts, "fixities": fixities,
        "checkpoint": native}
    pair = (*coverage[1:11], coverage[11], coverage[12], *coverage[13:])
    return obj, admission, evidence, pair, family, transaction


def supplied(*, count=1, burned=False, route="direct"):
    """Return a complete direct-HTTPS retrieval fixture and exact parent inputs."""
    require_route = route in ("direct", "redirect", "mirror", "manifest")
    if not require_route:
        raise ValueError("unsupported retrieval fixture route")
    primary_transaction = _transaction(MEDIA_BYTES)
    manifest_transaction = _transaction(MANIFEST_BYTES)
    requested_uri = ("https://example.invalid/master.png" if route == "direct" else
        "https://origin.invalid/master.png" if route in ("redirect", "mirror") else
        _ar(manifest_transaction) + "/master.png")
    inventory, context, graph, witness, configuration = inventory_supplied(
        requested_uri, count=count, burned=burned)
    shared = archive._Originals(context, graph)
    _, inventory_result = inventory_wire.validate(
        inventory, context, graph, witness, configuration, originals=shared)
    source = from_json(t.SOURCE, inventory_result["retrievalSource"])
    source_row, source_bundle, _, snapshot_row = sources.selected(inventory["value"]["reference"])
    source_proof = deepcopy(source_row["sourceProof"])
    obj, admission, evidence, pair, family, _ = _archive(
        context, graph, source, MEDIA_BYTES)
    resolved_uri = requested_uri
    steps, manifest_evidence = (), []
    if route in ("redirect", "mirror"):
        resolved_uri = _ar(primary_transaction)
        steps = ((1 if route == "redirect" else 2, requested_uri, resolved_uri,
            302 if route == "redirect" else 0, Z, Z, b""),)
    elif route == "manifest":
        resolved_uri = _ar(primary_transaction)
        manifest_obj, manifest_admission, manifest_source, manifest_pair, manifest_family, _ = _archive(
            context, graph, source, MANIFEST_BYTES)
        steps = ((3, requested_uri, resolved_uri, 0, manifest_admission[3][1],
            manifest_admission[3][0], MANIFEST_BYTES),)
        manifest_evidence = [{"admission": json_values(manifest_admission),
            "sourceEvidence": manifest_source, "currentPair": json_values(manifest_pair),
            "secondFamily": {"family": json_values(manifest_family),
                "status": "1", "revision": "1"}}]
    second = decode((archive.RECEIPT, "bytes", "bytes"), hex_bytes(evidence["receipts"][1]),
        maximum=65536)[0]
    observed_at, deadline, nonce = 120, 139, 17
    observation = (source, obj, admission[3], steps, resolved_uri, second[6],
        observed_at, nonce, deadline)
    raw = encode((t.OBSERVATION, "bytes"), (observation, b"synthetic historical Safe signature"))
    receipt = [Z, wire.source_key(source), wire.observation_hash(configuration, witness["address"], observation),
        admission[3][1], admission[3][0], second[6], 136, K(raw), len(raw)]
    receipt[0] = wire.record_hash(configuration, witness["address"], receipt)
    log = {"address": witness["address"], "topics": [t.RECORDED_TOPIC, receipt[0], receipt[1],
        "0x" + encode(("address",), (receipt[5],)).hex()],
        "data": "0x" + encode((t.RECEIPT,), (tuple(receipt),)).hex(),
        "blockNumber": "0x24", "blockHash": D("block36"),
        "transactionHash": D("transaction36"), "transactionIndex": "0x0",
        "logIndex": "0x0", "removed": False}
    current = {"checkpointSource": deepcopy(source_bundle["output"]["checkpoint"]["source"]),
        "artistPresentation": deepcopy(snapshot_row["source"][2]),
        "admission": json_values(admission), "sourceEvidence": evidence,
        "currentPair": json_values(pair),
        "secondFamily": {"family": json_values(family), "status": "1", "revision": "1"},
        "manifestEvidence": manifest_evidence}
    record = {"recordHash": receipt[0], "receipt": json_values(tuple(receipt)),
        "payloadHex": "0x" + raw.hex(), "publication": {"log": log, "timestamp": "136"},
        "revocation": None, "current": current, "status": "operative",
        "nativeState": {"revoked": False, "nonceUsed": True}}
    dependencies = (tuple(graph[key]["address"] for key in archive.DEPENDENCY_ROLES),
        tuple(graph[key]["runtimeHash"] for key in archive.DEPENDENCY_ROLES),
        int(context["chainId"]), 100000, 8000000)
    retrieval = {"sourceRevision": t.SOURCE_REVISION, "profile": t.PROFILE,
        "witness": witness, "configuration": json_values(configuration),
        "configurationHash": wire.configuration_hash(configuration),
        "bundleDependencies": json_values(dependencies), "records": [record],
        "scopeEpochs": [{"scope": json_values(source[0]), "epoch": "0"}],
        "itemBindings": [],
        "historyCoverage": {"retainedRecordCount": 1, "retainedRevocationCount": 0,
            "eventHistoryCompleteness": "bounded_retained_rows"}, "sourceBindings": None}
    wire._record_call(shared, witness["address"], "record(bytes32)", ("bytes32",),
        (receipt[0],), (t.RECEIPT,), (tuple(receipt),))
    wire._record_call(shared, witness["address"], "encoded(bytes32)", ("bytes32",),
        (receipt[0],), ("bytes",), (raw,))
    wire._record_call(shared, witness["address"], "revoked(bytes32)", ("bytes32",),
        (receipt[0],), ("bool",), (False,))
    wire._record_call(shared, witness["address"], "nonceUsed(bytes32)", ("bytes32",),
        (wire.nonce_key(receipt[5], nonce),), ("bool",), (True,))
    wire._record_call(shared, configuration[4],
        "currentSource((uint8,uint256,uint256,bytes32))", (t.SCOPE,), (source[0],),
        (wire.output_types.SOURCE,), (from_json(wire.output_types.SOURCE,
            current["checkpointSource"]),))
    artist = from_json(t.ARTIST_PRESENTATION, current["artistPresentation"])
    wire._record_call(shared, configuration[2], "artistPresentation(uint256)",
        ("uint256",), (source[0][1],), (t.ARTIST_PRESENTATION,), (artist,))
    actual, transformed, current_observation, route = wire._archive_current(
        current, observation, context, graph, dependencies, tuple(receipt), witness,
        configuration, retrieval["configurationHash"], shared)
    wire._record_call(shared, witness["address"], "requireCorrespondence(bytes32)",
        ("bytes32",), (receipt[0],), (t.SOURCE, t.RECEIPT, it.ADMISSION),
        (source, tuple(receipt), actual))
    wire._record_call(shared, witness["address"],
        "revocationEpoch((uint8,uint256,uint256,bytes32))", (t.SCOPE,), (source[0],),
        ("uint64",), (0,))
    operative = {"source": source, "receipt": tuple(receipt), "admission": actual,
        "transformed": transformed, "currentObservation": current_observation, "route": route}
    item = wire.obligation_item(source)
    index = next(i for i, row in enumerate(inventory_result["items"]) if row == item)
    artifact_environment = (D("onchain environment"), 1)
    external_environment = (D("external environment"), 1)
    original_environment = archive.environment_hash(
        dependencies, *artifact_environment, *external_environment)
    saved = (actual[0], transformed, *actual[2:])
    binding = {"planId": inventory_result["planId"], "index": str(index),
        "item": json_values(item), "witnessRecordHash": receipt[0],
        "savedAdmission": json_values(saved), "originalEnvironment": original_environment,
        "environmentHash": wire.environment_hash(original_environment, witness["address"],
            witness["runtimeHash"], source[0], 0),
        "currentObservation": current_observation,
        "environment": {"dependencies": json_values(dependencies),
            "artifact": json_values(artifact_environment),
            "external": json_values(external_environment)},
        "sourceBindings": None}
    calls = inventory_wire.item_binding_reads(binding, inventory_result, context, graph, witness, 0)
    binding["sourceBindings"] = {"blockHash": context["blockHash"],
        "provenance": inventory_result["provenance"], "calls": calls}
    inventory_wire.validate_item_binding(binding, inventory_result, context, graph, witness,
        configuration, operative, 0, originals=shared)
    retrieval["itemBindings"] = [binding]
    retrieval["sourceBindings"] = {"blockHash": context["blockHash"],
        "provenance": inventory_result["provenance"], "calls": deepcopy(shared.calls)}
    return {"retrieval": retrieval, "context": context, "graph": graph,
        "inventory": inventory, "sourceProof": source_proof,
        "mediaBytesByRecord": {receipt[0]: "0x" + MEDIA_BYTES.hex()},
        "_shared": shared, "_inventoryResult": inventory_result,
        "_admission": admission, "_observation": observation, "_receipt": tuple(receipt)}

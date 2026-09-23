"""Closed supplied original scoped factory-policy V2 finality; authentication is external."""
import argparse
import copy
from pathlib import Path

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from tools.museum import native_scoped_policy_finality_wire_v2 as wire
from tools.museum import scoped_policy_content_types_v2 as types
from tools.museum import scoped_policy_content_wire_v2 as content_wire
from tools.museum import scoped_policy_preservation_types_v2 as preservation
from tools.museum import scoped_policy_static_components_v2 as static
from tools.museum import scoped_policy_factory_v2 as factory
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads, subject_id, uint
from tools.museum.independent_wire import ZERO, ZERO_ADDRESS, require
from . import acquisition_scoped_static_finality_v1 as neutral
from .acquisition_packet_v5 import _typed

ROOT = Path(__file__).resolve().parents[2]
NAME = "STREAM_ACQUISITION_SCOPED_POLICY_FINALITY_V2"
SOURCE_PROFILE = "STREAM_MUSEUM_PUBLIC_SCOPED_POLICY_FINALITY_SOURCE_V2"
SOURCE_REVISION = wire.SOURCE_REVISION
MAX_BYTES, MAX_EVENTS, MAX_ORIGINAL_BYTES = neutral.MAX_BYTES, neutral.MAX_EVENTS, neutral.MAX_ORIGINAL_BYTES
SOURCE_REF_FIELDS, COMMON = neutral.SOURCE_REF_FIELDS, neutral.COMMON
closed, ref, nullable, array, blob, abi = neutral.closed, neutral.ref, neutral.nullable, neutral.array, neutral.blob, neutral.abi
CLAIMS = {"completeAuthority": False, "sourceAuthenticated": False, "historicalCoreFactsPreimageRecovered": False,
    "historicalMetadataComponentPreimageRecovered": False, "historicalTerminalAdmissionPreimageRecovered": False,
    "historicalRendererExecutionReenacted": False, "historicalGovernanceAuthorizationReexecuted": False,
    "transactionHashesRecomputed": False, "actualChainAcceptance": False}
QUALIFICATION = ("Prospective unregistered supplied-data scoped factory-policy V2 finality. Complete original ordered "
    "membership, policy/readiness and output hash rows, V1/V2 root history, six STATIC component preimages, original "
    "V2 snapshot/reference payloads and native finality/governance observations are retained. Current token burns "
    "remain separate. Core facts, metadata-component facts and terminal-admission preimages remain hash-only. "
    "Reference samples preserve original HTML commitments and bytes without proving all-token rendering, image "
    "capture, runtime execution or archive liveness. Supplied RPC observations do not prove signed transactions, "
    "runtime admission, consensus, historical authority, EVM execution, complete source coverage or acquisition acceptance. "
    "COLLECTION, VIEW, current-authority factory and other codecs are unsupported by this branch.")
RULES = [
    "Numeric version2 identifies this additive scoped factory-policy V2 fragment; frozen earlier definitions remain unchanged.",
    "The original three-profile catalogue remains retained; the seven-child original publication factory determines the selected scoped source graph without a current-eligibility substitution.",
    "All original root predecessors and V1/V2 binding events are retained. The selected V2 root must be the latest same-scope root before original finalization; current head is a separate observation.",
    "Complete ordered membership, selection and policy V2 output rows reconstruct the canonical manifest and token proof with at most818 outputs.",
    "Terminal DISABLED/NOT_REQUIRED and finalized readiness are distinct original branches. Terminal admission remains an opaque commitment; no fabricated finalized seed or current entropy substitution is allowed.",
    "The exact original policy snapshot/reference payloads and first/last sample commitments join retained policies, output rows, source identities, locks and the exact native definitions.",
    "Supported original direct Executor inputs reconstruct complete ordered calls and action ID metadata; unavailable or indirect inputs remain explicitly partial.",
    "Supplied commitment consistency never establishes source authenticity, historical authorization, renderer execution, full archival coverage or complete packet acceptance.",
]


def definitions():
    h, a, u = abi("bytes32"), abi("address"), abi("uint256")
    prior = neutral.definitions()
    d = {key: copy.deepcopy(prior[key]) for key in ("sourceRef", "sourceState", "identity", "chunk", "execution", "log", "event", "definition", "historicalCoreFacts")}
    d["graph"] = closed({key: closed({"address": a, "runtimeHash": h}) for key in wire.GRAPH_KEYS})
    d["finality"] = closed({"record": abi(wire.SCOPED_RECORD), "components": array(abi(wire.COMPONENT), 32, 1),
        "manifestRef": abi(wire.base.MANIFEST_REF), "manifestBytes": blob(wire.MAX_MANIFEST),
        "executionWitness": abi(wire.base.EXECUTION_WITNESS), "archiveWitness": abi(wire.base.ARCHIVE_WITNESS), "inputsHash": h})
    d["rootRow"] = closed({"recordHash": h, "record": abi(types.ROOT_RECORD), "aggregate": abi(types.ROOT_AGGREGATE), "binding": abi(types.ROOT_BINDING)})
    d["roots"] = closed({"selectedRootHash": h, "scopeHead": h, "collectionAggregate": abi(types.ROOT_AGGREGATE), "history": array(ref("rootRow"), types.MAX_HISTORY, 1)})
    d["checkpoint"] = closed({"id": h, "salt": h, "plan": abi(types.CONTENT_PLAN),
        "outputs": array(abi(types.OUTPUT), types.MAX_OUTPUTS, 1), "selectionPlan": abi(types.SELECTION_PLAN),
        "selectionRows": array(abi(types.SELECTION_ROW), types.MAX_OUTPUTS, 1), "factoryDependencies": abi(types.FACTORY_DEPENDENCIES)})
    d["outputManifest"] = closed({"recordHash": h, "planHash": h, "record": abi(types.OUTPUT_MANIFEST),
        "plan": abi(types.OUTPUT_PLAN), "artifactHash": h, "artifact": abi(types.ARTIFACT),
        "coverage": abi(types.COVERAGE), "chunks": array(ref("chunk"), types.MAX_PARTS, 1)})
    d["content"] = closed({"roots": ref("roots"), "checkpoint": ref("checkpoint"), "manifest": ref("outputManifest")})
    for family, p, r, source, deps in (("snapshot", preservation.SNAPSHOT_PUBLICATION, preservation.SNAPSHOT_RECEIPT,
            preservation.SNAPSHOT_SOURCE, preservation.SNAPSHOT_DEPS), ("reference", preservation.REFERENCE_PUBLICATION,
            preservation.REFERENCE_RECEIPT, preservation.REFERENCE_SOURCE, preservation.REFERENCE_DEPS)):
        props = {"dependencies": abi(deps), "publication": abi(p), "receipt": abi(r), "source": abi(source),
            "payload": blob(preservation.MAX_PAYLOAD), "lock": abi(preservation.SNAPSHOT_LOCK), "head": h,
            "history": array(closed({"publication": abi(p), "receipt": abi(r)}), preservation.MAX_HISTORY, 1)}
        if family == "snapshot": props["entropyDependencies"] = abi(preservation.POLICY_DEPS)
        else:
            props["environment"] = blob(preservation.MAX_PAYLOAD)
            props["objects"] = array(closed({"objectHash": h, "identity": abi(preservation.EXTERNAL_OBJECT)}), 3, 1)
        d[family] = closed(props)
    d["membership"] = copy.deepcopy(prior["membership"])
    for key in ("tokens","identities","lifecycles","inventoryTokens","progressHistory"):
        d["membership"]["properties"][key]["maxItems"] = types.MAX_OUTPUTS
    d["factoryChildren"] = closed({
        "terminalReadiness":closed({"core":a,"metadataRouter":a,"entropySourceSet":a,"readGas":u,"sourceGas":u}),
        "policyContent":closed({"selectionCheckpoint":a,"entropySourceSet":a,"terminalReadiness":a,"executor":a,"gas":abi((factory.GAS_CONFIG,)*2)}),
        "outputManifest":closed({"core":a,"contentCheckpoint":a,"artifactCoverage":a,"executor":a,"gas":abi(factory.GAS_CONFIG)}),
        "policySnapshot":abi(preservation.SNAPSHOT_DEPS),"policyReference":abi(preservation.REFERENCE_DEPS),
        "renderCriticalInventory":abi(wire.INVENTORY_DEPENDENCIES),"bundleCoverage":abi(factory.BUNDLE_DEPS)})
    d["factory"] = closed({"profile":{"const":factory.PROFILE},"chainId":u,"factory":a,"factoryRuntimeHash":h,
        "recipe":abi(factory.RECIPE),"recipeHash":h,"sourceFactoryDependencies":abi(preservation.POLICY_DEPS),
        "sourceFactoryDependenciesHash":h,"graph":abi(factory.GRAPH),"childDependencies":ref("factoryChildren"),
        "preparationEvents":array(closed({"graphId":h,"inventoryPlan":h,"childIndex":u,"child":a,"codeHash":h}),7,7)})
    d["providerConfiguration"] = closed({**{k:abi(wire.PROVIDER_CONFIG) for k in ("originalConfiguration","scopedConfiguration","policyConfiguration","selectedConfiguration")},
        "inventoryDependencies":abi(wire.INVENTORY_DEPENDENCIES),"profiles":abi((wire.PROFILE,)*3),
        "collectionPolicyOutput":closed({"address":a,"runtimeHash":h}),"factoryBinding":abi(wire.FACTORY_BINDING),"sourceConfigurationHash":h})
    adapter_fields = ("family", "address", "runtimeHash", "core", "coreCodeHash", "host", "hostCodeHash", "evidenceProvider",
        "evidenceProviderCodeHash", "metadataHost", "metadataHostCodeHash")
    d["adapter"] = closed({k: a if k in ("address", "core", "host", "evidenceProvider", "metadataHost") else h for k in adapter_fields})
    d["provider"] = closed({"configuration": ref("providerConfiguration"), "discoveryConfiguration": abi(wire.DISCOVERY_CONFIG),
        "discoverySourceConfigurationHash": h, "adapters": array(ref("adapter"), 7, 7),
        "moduleIdentities": closed({k: abi(("bytes32", "bytes32")) for k in ("router", "metadata")})})
    d["staticContext"] = closed({"chainId": u, **{k: a for k in ("core", "metadata", "router", "selection")},
        **{k: h for k in ("routerCodeHash", "selectionCodeHash", "routerModuleVersion", "routerModuleManifestHash")},
        "adapters": array(closed({"family": h, "address": a, "runtimeHash": h}), 6, 6)})
    d["staticOriginal"] = closed({"configRecordHash": h, "configRecord": abi(static.CONFIG_RECORD),
        "rawSource": abi(static.RAW_SOURCE), "selectedConfig": abi(static.METADATA_CONFIG)})
    d["staticComponents"] = closed({"context": ref("staticContext"), "authenticated": abi(static.AUTHENTICATED_SELECTION),
        "plan": abi(types.SELECTION_PLAN), "rows": array(abi(types.SELECTION_ROW), types.MAX_OUTPUTS, 1),
        "originals": array(ref("staticOriginal"), types.MAX_OUTPUTS, 1), "artistPresentation": abi(static.ARTIST_PRESENTATION),
        "componentExpectations": array(abi(wire.COMPONENT), 9, 9)})
    d["bundle"] = closed({"scope":abi(wire.SCOPE), **{k: ref(k) for k in ("factory", "provider", "finality", "content", "snapshot", "reference", "membership", "staticComponents", "execution")}})
    neutral._transaction_definitions(d)
    d["claims"] = closed({k: {"const": v} for k, v in CLAIMS.items()})
    d["fragment"] = closed({"schema": {"const": NAME}, "version": {"const": 2}, "sourceRef": ref("sourceRef"),
        "sourceState": ref("sourceState"), "graph": ref("graph"), "identity": ref("identity"), "bundle": ref("bundle"),
        "events": array(ref("event"), MAX_EVENTS, 1), "definitions": array(ref("definition"), len(wire.definitions()), len(wire.definitions())),
        "headers": array(blob(MAX_ORIGINAL_BYTES), 2, 1), "transactions": closed({k: ref("transaction") for k in ("schedule", "execution")}),
        "reconstruction": ref("governance"), "historicalCoreFacts": ref("historicalCoreFacts"),
        "claims": ref("claims"), "qualification": {"const": QUALIFICATION}})
    d["tokenProof"] = closed({"kind": {"const": "native_scoped_policy_token_content_proof_v2"}, "subjectId": h,
        "scope": abi(wire.SCOPE), "rootRecordHash": h, "manifestHash": h, "root": h, "leafCount": abi("uint64"),
        "leafIndex": abi("uint64"), "leaf": abi(wire.base.LEAF), "leafHash": h, "proof": array(h, 16)})
    return d


def schema_document_bytes():
    return dumps({"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:6529stream:schema:" + NAME,
        "title": NAME, "description": QUALIFICATION, **ref("fragment"), "$defs": definitions(),
        "x-stream-source-profile": SOURCE_PROFILE, "x-stream-source-review": SOURCE_REVISION, "x-stream-constraints": RULES})


SCHEMA_BYTES = schema_document_bytes()
SCHEMA_HASH = keccak256(SCHEMA_BYTES)


def token_proof(value):
    source, bundle, graph = value["sourceState"], value["bundle"], value["graph"]
    statement = wire.validate_finality(bundle["finality"], source, graph, bundle["scope"])["statement"]
    proof = content_wire.validate(bundle["content"], source, graph, statement)["targetProof"]
    return {"kind": "native_scoped_policy_token_content_proof_v2", "subjectId": subject_id("token", source["chainId"], source["core"],
        source["collectionId"], token_id=source["tokenId"]), "scope": copy.deepcopy(bundle["scope"]),
        **copy.deepcopy(proof)}


def native_record_keys(value):
    graph, bundle = value["graph"], value["bundle"]
    return {(graph["finality"]["address"], bundle["finality"]["record"][2])} | {
        (graph["router"]["address"], row["recordHash"]) for row in bundle["content"]["roots"]["history"]} | {
        (graph["policySnapshot"]["address"], row["receipt"][0]) for row in bundle["snapshot"]["history"]} | {
        (graph["policyReference"]["address"], row["receipt"][1][0]) for row in bundle["reference"]["history"]}


def event_observations(value):
    for row in value["events"]:
        log = row["log"]
        publication = {k: str(neutral.governance.quantity(log[k])) if k in ("blockNumber", "transactionIndex", "logIndex") else log[k]
            for k in ("blockHash", "blockNumber", "transactionHash", "transactionIndex", "logIndex")}
        yield publication, row["timestamp"], ("native_scoped_policy_finality_event", log["address"], tuple(log["topics"]), log["data"])


def runtime_observations(value):
    for row in value["graph"].values(): yield row["address"], row["runtimeHash"]
    bundle = value["bundle"]
    configuration = bundle["provider"]["configuration"]
    output = configuration["collectionPolicyOutput"]
    yield output["address"], output["runtimeHash"]
    for key in ("originalConfiguration", "scopedConfiguration", "policyConfiguration", "selectedConfiguration"):
        for address, digest in zip(configuration[key][0], configuration[key][1]): yield address, digest
    inventory = configuration["inventoryDependencies"]
    for offset in (0, 2):
        for address, digest in zip(inventory[offset], inventory[offset + 1]):
            if address != ZERO_ADDRESS or digest != ZERO: yield address, digest
    if inventory[4] != ZERO_ADDRESS or inventory[5] != ZERO: yield inventory[4], inventory[5]
    for group in (bundle["snapshot"]["dependencies"], bundle["reference"]["dependencies"], bundle["snapshot"]["entropyDependencies"]):
        for address, digest in zip(group[0], group[1]): yield address, digest
    for row in bundle["snapshot"]["source"][9][5]: yield row[0], row[1]
    recipe = bundle["factory"]["recipe"]
    for addresses,pins in ((recipe[1],recipe[2]),(recipe[0][0],recipe[0][1]),(recipe[0][2],recipe[0][3])):
        for address,digest in zip(addresses,pins):
            if address != ZERO_ADDRESS or digest != ZERO: yield address,digest
    for address,digest in zip(bundle["content"]["checkpoint"]["factoryDependencies"][0],bundle["content"]["checkpoint"]["factoryDependencies"][1]):yield address,digest
    for chunk in bundle["membership"]["parts"]:yield chunk["pointer"],chunk["codeHash"]
    publication = bundle["membership"]["publication"]
    if publication is not None: yield publication[4], publication[5]
    for row in bundle["content"]["checkpoint"]["outputs"]: yield row[4][0], row[4][1]
    for row in bundle["provider"]["adapters"]: yield row["address"], row["runtimeHash"]
    for row in bundle["content"]["manifest"]["chunks"]: yield row["pointer"], row["codeHash"]
    for row in bundle["content"]["checkpoint"]["selectionRows"]:
        yield row[5][0], row[5][1]; yield row[5][3], row[5][4]
        for a, h in zip(row[6], row[7]):
            if a != ZERO_ADDRESS: yield a, h
    e = bundle["execution"]
    yield e["callDataPointer"], keccak256(hex_bytes(e["runtime"]))


def validate(raw):
    try:
        value = loads(raw, maximum=MAX_BYTES, canonical=True)
        schema = loads(SCHEMA_BYTES, maximum=MAX_BYTES)
        Draft202012Validator(schema).validate(value); _typed(value, ref("fragment"), schema["$defs"])
        refs, source, identity = value["sourceRef"], value["sourceState"], value["identity"]
        require(all(any(hex_bytes(refs[k], 32)) for k in SOURCE_REF_FIELDS[:-1]), "policy source pin empty")
        require(all(uint(source[k]) > 0 for k in ("chainId", "collectionId", "tokenId")) and source["core"] != ZERO_ADDRESS
            and all(source[k] != ZERO for k in ("blockHash", "stateRoot", "deploymentEvidenceHash")), "policy source identity")
        require(identity["tokenId"] == source["tokenId"] and identity["collectionId"] == source["collectionId"]
            and uint(identity["collectionSerial"]) > 0 and identity["burned"] == (identity["lifecycle"] == "3"), "policy token identity")
        membership = value["bundle"]["membership"]
        indices = [i for i, token in enumerate(membership["tokens"]) if token == source["tokenId"]]
        require(len(indices) == 1, "policy target original membership")
        index = indices[0]
        require(membership["identities"][index] == [True, source["collectionId"], identity["collectionSerial"], identity["burned"]]
            and membership["lifecycles"][index] == identity["lifecycle"], "policy current membership identity")
        pins = {}
        for a, h in runtime_observations(value):
            require(a != ZERO_ADDRESS and h != ZERO and pins.setdefault(a, h) == h, "policy supplied runtime contradiction")
        report = wire.validate_bundle(value["bundle"], source, value["graph"])
        require(value["historicalCoreFacts"] == report["historicalCoreFacts"], "policy historical Core hash")
        expected = {r["id"]: r["bytes"] for r in wire.definitions()}
        actual = {r["documentId"]: hex_bytes(r["payloadHex"]) for r in value["definitions"]}
        require(len(actual) == len(value["definitions"]) and actual == expected, "policy original definition bytes")
        wire.validate_event_join(value["bundle"], source, value["graph"], value["events"])
        normalized = neutral._normalized_transactions(value)
        require(value["reconstruction"] == wire.validate_governance(value["bundle"], source, value["graph"], normalized, value["events"]),
            "policy governance reconstruction differs")
        proof = token_proof(value)
        wire.base.verify_proof(proof["leafHash"], uint(proof["leafIndex"]), uint(proof["leafCount"]), proof["proof"], proof["root"])
        return value
    except MuseumError: raise
    except (ValidationError, ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid supplied scoped factory-policy V2 finality fragment") from exc


def _source_profile_hash():
    from tools.museum import public_scoped_policy_finality_source_v2 as source
    require(source.PROFILE == SOURCE_PROFILE and source.SOURCE_REVISION == SOURCE_REVISION, "policy source implementation differs")
    return source.PROFILE_HASH


def semanticProjection(snapshot, source_ref):
    try:
        require(type(source_ref) is dict and set(source_ref) == set(SOURCE_REF_FIELDS)
            and snapshot["profile"] == SOURCE_PROFILE and snapshot["profileHash"] == _source_profile_hash()
            and snapshot["sourceReviewCommit"] == SOURCE_REVISION and snapshot["version"] == "2", "policy snapshot profile differs")
        require(source_ref == {"sourceProfileHash": snapshot["profileHash"], "anchorHash": snapshot["anchorHash"],
            "transcriptHash": snapshot["transcriptHash"], "snapshotHash": keccak256(dumps(snapshot)),
            "provenance": snapshot["provenance"]}, "policy snapshot source reference differs")
        value = {"schema": NAME, "version": 2, "sourceRef": copy.deepcopy(source_ref),
            "sourceState": {k: snapshot["source"][k] for k in COMMON}, "claims": dict(CLAIMS), "qualification": QUALIFICATION}
        for k in ("graph", "identity", "bundle", "events", "definitions", "headers", "transactions", "reconstruction", "historicalCoreFacts"):
            value[k] = copy.deepcopy(snapshot[k])
        return validate(dumps(value))
    except MuseumError: raise
    except (ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid policy V2 snapshot projection") from exc


def documents(): return {NAME: SCHEMA_BYTES}
def outputs(): return {"schemas/records/"+name+".json": raw for name, raw in documents().items()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    for path, raw in outputs().items():
        destination = ROOT / path
        if args.check: require(destination.is_file() and destination.read_bytes() == raw, "generated policy V2 fragment differs")
        else: destination.write_bytes(raw)
    print("scoped factory-policy V2 supplied definition matches; source authentication remains separate.")


if __name__ == "__main__": main()

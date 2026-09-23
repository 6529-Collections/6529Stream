"""Pure, explicitly synthetic supplied finality bytes; no RPC/EVM acceptance."""
import copy
import unittest

from . import native_finality_wire as w
from .canonical import MuseumError, dumps, hex_bytes, keccak256, schema_id
from .chain_abi import Array, calldata, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values


def A(number): return "0x" + format(number, "040x")
def H(label): return keccak256(("synthetic-finality-wire:" + str(label)).encode())
def _json(value):
    if type(value) is dict: return {key: _json(item) for key, item in value.items()}
    if type(value) in (tuple, list): return [_json(item) for item in value]
    return json_values(value)


def supplied(context=None, graph=None, *, count=3, token_index=2, finality_uri="", artist_id=None,
             root_timestamp=None, finality_timestamp=None):
    """Return (bundle, context, graph), all JSON-safe synthetic native ABI facts.

    Caller overrides bind this pure fixture to a coherent synthetic source map;
    they do not make these bytes a native execution or an authenticated capture.
    """
    context = copy.deepcopy(context) if context is not None else {
        "chainId": "31337", "core": A(2), "collectionId": "1", "tokenId": "41",
        "blockNumber": "5", "blockHash": H("block5"), "timestamp": "1790000000",
        "stateRoot": H("state5"), "environment": "local_evm_fixture",
        "deploymentEvidenceHash": H("deployment")}
    graph = copy.deepcopy(graph) if graph is not None else {
        name: {"address": context["core"] if name == "core" else A(20000 + index),
               "runtimeHash": H("runtime:" + name)} for index, name in enumerate(w.GRAPH_KEYS)}
    chain, cid, token, stamp = (int(context[key]) for key in ("chainId", "collectionId", "tokenId", "timestamp"))
    root_stamp = stamp - 2 if root_timestamp is None else int(root_timestamp)
    finality_stamp = stamp - 1 if finality_timestamp is None else int(finality_timestamp)
    if not 0 < root_stamp <= finality_stamp <= stamp:
        raise MuseumError("synthetic finality fixture publication timestamps")
    if not 0 < count <= w.MAX_LEAVES or not 0 <= token_index < count or token <= token_index:
        raise MuseumError("synthetic finality fixture leaf limits")
    addr = lambda key: graph[key]["address"]
    leaves = tuple((token - token_index + i, H((i, "metadata")), H((i, "image")),
                    H((i, "animation")), ZERO, H((i, "tokenData"))) for i in range(count))
    root = w.tree_root(chain, addr("core"), leaves)
    checkpoint = (cid, count, count, H("inventory"), H("serving"), root,
                  w.leaf_chain(chain, addr("core"), leaves))
    checkpoint_hash = w.checkpoint_hash(chain, addr("checkpoint"), addr("core"), addr("router"), addr("inventory"), checkpoint)
    leaf_bytes = encode(w.LEAF_ENVELOPE, (w.LEAF_SCHEMA, chain, addr("core"), addr("checkpoint"), checkpoint_hash,
                                        cid, root, count, leaves))
    parts = tuple(leaf_bytes[i:i + w.CHUNK_BYTES] for i in range(0, len(leaf_bytes), w.CHUNK_BYTES))
    artist = H("artist") if artist_id is None else artist_id
    artifact = (artist, w.LEAF_SCHEMA, w.LEAF_CANON, 1, keccak256(leaf_bytes), len(leaf_bytes),
                tuple(keccak256(part) for part in parts), tuple(len(part) for part in parts))
    artifact_hash = w.artifact_hash(chain, addr("artifacts"), addr("core"), artifact)
    coverage = (H("coverage"), artifact_hash, *artifact[:3], artifact[4], artifact[5], len(parts),
                H("archive-family-one"), H("archive-family-two"), 1, H("coverage-evidence-chain"))
    manifest = (checkpoint_hash, artifact_hash, coverage[0], artist, root, keccak256(leaf_bytes), cid, count, len(leaf_bytes))
    plan_hash = w.manifest_plan_hash(chain, addr("leafManifest"), addr("core"), addr("checkpoint"), addr("artifacts"), manifest)
    manifest_hash = w.manifest_record_hash(plan_hash)
    route = w.route_hash(chain, tuple(addr(key) for key in w.ROUTE_KEYS), tuple(graph[key]["runtimeHash"] for key in w.ROUTE_KEYS))
    root_record = [(cid, ZERO, manifest_hash, "ipfs://synthetic-leaf-manifest"), root, count, manifest[5], artist,
                   1, H("binding"), A(22001), 7, 1, route, ZERO, ZERO, 0]
    root_record[11] = w.root_state_hash(chain, addr("router"), root_record)
    root_record[12:14] = [H("artist-root-consent"), root_stamp]
    root_hash = w.root_hash(chain, addr("router"), root_record)
    independent = tuple((family, A(23000 + index), "0x12345678", H((index, "component-code")),
                         H((index, "version")), H((index, "manifest")), H((index, "data")))
                        for index, family in enumerate(w.INDEPENDENT_FAMILIES))
    proof = (H("sanction"), H("sanction-artifact"), H("sanction-coverage"))
    sanction = (w.SANCTION, addr("artist"), "0x12345678", graph["artist"]["runtimeHash"],
                H("artist-version"), H("artist-manifest"), proof[0])
    components = tuple(sorted((*independent, sanction), key=lambda row: row[0]))
    inputs = (root_hash, H("snapshot-record"), H("reference-record"), H("intent"), ZERO,
              H("interview"), H("rights"), H("work-description"), H("render-inventory"), H("bundle-coverage"))
    scope = (0, cid, 0, ZERO)
    statement = (scope, H("original-core-facts"), root, count, w.LEAF_SCHEMA, H("snapshot-manifest"),
                 H("reference-manifest"), inputs, independent, 1, 1, 1)
    input_bytes = encode(w.INPUT_ENVELOPE, (w.INPUT_SCHEMA, w.INPUT_CANON, chain, addr("core"), addr("metadata"), addr("finality"), statement))
    manifest_ref = (finality_uri, keccak256(finality_uri.encode()), keccak256(input_bytes), w.INPUT_SCHEMA, w.INPUT_CANON)
    component_hash = w.components_hash(components)
    finality_hash = w.finality_hash(chain, addr("core"), cid, statement[1], component_hash, manifest_ref)
    finality = (True, finality_hash, manifest_ref[2], manifest_ref[1], finality_uri, component_hash, addr("finality"), finality_stamp)
    archive = (w.archive_evidence_hash(chain, addr("core"), addr("finality"), addr("artifacts"), proof), proof)
    witness = (H("action"), A(22002), H("reason"), H("role-mutation"), 1)
    execution = w.execution_context(chain, addr("finality"), addr("core"), addr("metadata"), statement, finality_hash, component_hash, archive[0])
    call = hex_bytes(calldata(w.FINALIZE_SIGNATURE, w.FINALIZE_TYPES, (cid, components, finality_hash, manifest_ref, proof)))
    action = (3, 2, addr("finality"), 0, "0x" + call[:4].hex(), keccak256(call), execution["scopeHash"],
              execution["oldValueHash"], execution["newValueHash"], max(0, finality_stamp - 10), finality_stamp + 259200,
              witness[1], A(22003), ZERO_ADDRESS, ZERO_ADDRESS, witness[2], "synthetic original reason", H("calls"))
    bundle = {"finality": {"record": finality, "components": components, "manifestRef": manifest_ref,
        "manifestBytes": input_bytes, "executionWitness": witness, "archiveWitness": archive,
        "inputsHash": execution["inputsHash"]},
        "content": {"selectedRootHash": root_hash, "rootHead": root_hash,
            "rootHistory": [{"recordHash": root_hash, "record": root_record}],
            "manifest": {"recordHash": manifest_hash, "planHash": plan_hash, "record": manifest, "plan": (manifest, count, manifest_hash)},
            "checkpoint": {"planHash": checkpoint_hash, "profile": w.INLINE_PROFILE, "plan": checkpoint, "leaves": leaves},
            "artifact": {"artifactHash": artifact_hash, "artifact": artifact, "coverage": coverage,
                "chunks": [{"pointer": A(24000 + index), "codeHash": keccak256(b"\0" + part), "runtime": b"\0" + part}
                           for index, part in enumerate(parts)]}},
        "execution": {"action": action, "callDataPointer": A(25000), "callDatas": [call],
            "runtime": b"\0" + encode((Array("bytes", 64),), ((call,),))}}
    return _json(bundle), context, graph


def event_rows(bundle, context, graph):
    """Synthetic original event payloads at coherent positions, without receipts."""
    expected = list(w.expected_events(bundle, context, graph))
    action = w.from_json(w.GOVERNANCE_ACTION, bundle["execution"]["action"])
    witness = w.from_json(w.EXECUTION_WITNESS, bundle["finality"]["executionWitness"])
    derived = w.validate_bundle(bundle, context, graph)
    action_topics = (witness[0], w._topic("uint8", action[1]), w._topic("address", action[2]))
    executor = graph["executor"]["address"]
    def extra(name, topics, types, values):
        return {"kind": name, "address": executor, "topics": (w.EVENTS[name], *topics), "data": "0x" + encode(types, values).hex()}
    published = extra("governanceCalldataPublished", (derived["execution"]["callDataKey"],), w.GOVERNANCE_CALLDATA_DATA,
        (1, bundle["execution"]["callDataPointer"], A(22009)))
    scheduled = extra("governanceScheduled", action_topics, w.GOVERNANCE_SCHEDULED_DATA,
        (1, *action[3:11], 17, action[11], action[15], action[16], action[17]))
    executed = extra("governanceExecuted", action_topics, w.GOVERNANCE_EXECUTED_DATA,
        (1, *action[3:9], action[12], action[17]))
    rank = {kind: i for i, kind in enumerate(("checkpoint_started", "leaf_verified", "checkpoint_completed",
        "artifact_recorded", "coverage_completed", "manifest_started", "manifest_verified", "root_published",
        "governanceCalldataPublished", "governanceScheduled", "finality_finalized", "pointer_recorded",
        "freeze_executed", "execution_witness", "archive_witness", "governanceExecuted"))}
    ordered = sorted([*expected, published, scheduled, executed], key=lambda row: rank[row["kind"]])
    result, counters = [], {}
    root_time = int(bundle["content"]["rootHistory"][0]["record"][13])
    finality_time = int(bundle["finality"]["record"][7])
    for row in ordered:
        group = 1 if rank[row["kind"]] < 7 else 2 if rank[row["kind"]] < 10 else 4
        stamp = root_time - 1 if group == 1 else root_time if group == 2 else finality_time
        index = counters.get(group, 0); counters[group] = index + 1
        log = {"address": row["address"], "blockHash": H("event-block" + str(group)), "blockNumber": hex(group),
            "transactionHash": H("event-tx" + str(group)), "transactionIndex": "0x0", "logIndex": hex(index),
            "topics": [topic if topic is not None else H("original-coverage-plan") for topic in row["topics"]], "data": row["data"]}
        result.append({"log": log, "timestamp": str(stamp)})
    return result


class NativeFinalityWireTests(unittest.TestCase):
    def test_synthetic_bundle_preserves_original_hashes_and_limits(self):
        bundle, context, graph = supplied()
        result = w.validate_bundle(bundle, context, graph)
        self.assertEqual(result["targetProof"]["leafIndex"], "2")
        self.assertEqual(result["targetProof"]["leafCount"], "3")
        self.assertEqual(result["historicalCoreFacts"]["status"], "hash_only")
        self.assertFalse(result["actualChainAcceptance"])
        self.assertFalse(result["execution"]["actionIdPreimageReconstructed"])
        self.assertFalse(result["artifactCoverage"]["perChunkArchivePreimagesReconstructed"])
        self.assertEqual(len(w.definitions()), 6)
        self.assertEqual([len(row["bytes"]) for row in w.definitions()], [903, 677, 1014, 603, 1647, 2016])

    def test_odd_leaf_promotion_and_orientation_independent_preimage(self):
        bundle, context, graph = supplied()
        leaves = w.from_json(Array(w.LEAF, w.MAX_LEAVES), bundle["content"]["checkpoint"]["leaves"])
        chain, core = int(context["chainId"]), context["core"]
        digests = [keccak256(encode(("bytes32", "uint256", "address", *w.LEAF), (w.LEAF_DOMAIN, chain, core, *leaf))) for leaf in leaves]
        first = keccak256(encode(("bytes32", "bytes32", "bytes32"), (w.NODE_DOMAIN, digests[0], digests[1])))
        root = keccak256(encode(("bytes32", "bytes32", "bytes32"), (w.NODE_DOMAIN, first, digests[2])))
        self.assertEqual(w.tree_root(chain, core, leaves), root)
        self.assertEqual(w.proof_for(chain, core, leaves, 2), (first,))
        self.assertTrue(w.verify_proof(digests[2], 2, 3, (first,), root))
        for index, count, proof in ((1, 3, (first,)), (2, 3, (digests[2], first)), (2, 3, ()), (3, 3, (first,))):
            with self.subTest(index=index, proof=proof), self.assertRaises(MuseumError):
                w.verify_proof(digests[2], index, count, proof, root)
        duplicated_odd = w.node_hash(first, w.node_hash(digests[2], digests[2]))
        self.assertNotEqual(root, duplicated_odd)

    def test_complete_maximum_leaf_bytes_and_bound(self):
        bundle, context, graph = supplied(count=w.MAX_LEAVES)
        result = w.validate_bundle(bundle, context, graph)
        self.assertEqual(result["targetProof"]["leafCount"], "2729")
        self.assertEqual(len(bundle["content"]["artifact"]["chunks"]), 64)
        leaves = w.from_json(Array(w.LEAF, w.MAX_LEAVES), bundle["content"]["checkpoint"]["leaves"])
        with self.assertRaisesRegex(MuseumError, "leaf bound"):
            w.tree_root(int(context["chainId"]), context["core"], (*leaves, (leaves[-1][0] + 1, *leaves[-1][1:])))

    def test_original_manifest_domain_and_canonical_bytes(self):
        for mutation in ("trailing", "domain", "scope", "policy", "families"):
            bundle, context, graph = supplied()
            raw = hex_bytes(bundle["finality"]["manifestBytes"])
            if mutation == "trailing": changed = raw + b"\0" * 32
            else:
                envelope = list(w.decode(w.INPUT_ENVELOPE, raw)); statement = list(envelope[6])
                if mutation == "domain": envelope[4] = A(909)
                if mutation == "scope": statement[0] = (1, 1, 41, ZERO)
                if mutation == "policy": statement[9] = 2
                if mutation == "families": statement[8] = (*statement[8][1:], statement[8][0])
                envelope[6] = statement; changed = encode(w.INPUT_ENVELOPE, envelope)
            bundle["finality"]["manifestBytes"] = "0x" + changed.hex()
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): w.validate_bundle(bundle, context, graph)

    def test_leaf_part_stop_hash_order_and_denominator(self):
        for mutation in ("stop", "bytes", "hash", "order", "omit", "same_pointer"):
            bundle, context, graph = supplied(count=100)
            parts = bundle["content"]["artifact"]["chunks"]
            if mutation == "stop": parts[0]["runtime"] = "0x01" + parts[0]["runtime"][4:]
            if mutation == "bytes": parts[0]["runtime"] = parts[0]["runtime"][:-2] + "ff"
            if mutation == "hash": parts[0]["codeHash"] = H("wrong")
            if mutation == "order": parts[1], parts[2] = parts[2], parts[1]
            if mutation == "omit": parts.pop()
            if mutation == "same_pointer": parts[1]["pointer"] = parts[0]["pointer"]
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): w.validate_bundle(bundle, context, graph)

    def test_checkpoint_profile_completion_and_inline_semantics(self):
        for mutation in ("profile", "count", "animation", "content", "tokenData", "order"):
            bundle, context, graph = supplied()
            checkpoint = bundle["content"]["checkpoint"]
            if mutation == "profile": checkpoint["profile"] = H("chunked")
            if mutation == "count": checkpoint["plan"][2] = "2"
            if mutation in ("animation", "content", "tokenData"):
                checkpoint["leaves"][0][{"animation": 3, "content": 4, "tokenData": 5}[mutation]] = H("nonzero") if mutation == "content" else ZERO
            if mutation == "order": checkpoint["leaves"].reverse()
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): w.validate_bundle(bundle, context, graph)

    def test_sanction_component_and_archive_are_distinct_required_commitments(self):
        for mutation in ("missing", "signerclass", "archive", "host", "hash"):
            bundle, context, graph = supplied()
            f = bundle["finality"]; sanction = next(row for row in f["components"] if row[0] == w.SANCTION)
            if mutation == "missing": f["components"].remove(sanction)
            if mutation == "signerclass": f["components"][0][2] = "0x00000000"
            if mutation == "archive": f["archiveWitness"][1][0] = H("other-sanction")
            if mutation == "host": sanction[1] = A(998)
            if mutation == "hash": f["record"][5] = H("other-components")
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): w.validate_bundle(bundle, context, graph)

    def test_finality_uri_uses_whole_call_bound_not_root_uri_rule(self):
        for uri in ("", "local arbitrary " + "u" * 3000):
            bundle, context, graph = supplied(finality_uri=uri)
            self.assertEqual(w.validate_bundle(bundle, context, graph)["statement"][3], "3")
        bundle, context, graph = supplied(finality_uri="u" * 33000)
        with self.assertRaises(MuseumError): w.validate_bundle(bundle, context, graph)

    def test_scheduled_call_bytes_duplicates_carrier_and_window(self):
        for mutation in ("duplicate", "missing", "carrier", "expired", "proposer", "state"):
            bundle, context, graph = supplied()
            execution = bundle["execution"]
            if mutation == "duplicate": execution["callDatas"].append(execution["callDatas"][0])
            if mutation == "missing": execution["callDatas"][0] = "0x12345678"
            if mutation == "carrier": execution["runtime"] += "00"
            if mutation == "expired": execution["action"][10] = "1"
            if mutation == "proposer": execution["action"][11] = A(999)
            if mutation == "state": execution["action"][0] = "1"
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): w.validate_bundle(bundle, context, graph)

    def test_root_native_scope_authority_state_and_route(self):
        for mutation in ("scope", "authority", "consent", "state", "head", "route", "uri"):
            bundle, context, graph = supplied()
            root = bundle["content"]["rootHistory"][0]["record"]
            if mutation == "scope": root[0][0] = "2"
            if mutation == "authority": root[8] = "1"
            if mutation == "consent": root[12] = ZERO
            if mutation == "state": root[11] = H("wrong-state")
            if mutation == "head": bundle["content"]["rootHead"] = H("missing-head")
            if mutation == "route": graph["provider"]["runtimeHash"] = H("replacement")
            if mutation == "uri": root[0][3] = "http://example.org"
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): w.validate_bundle(bundle, context, graph)

    def test_exact_original_events_and_governance_publication(self):
        bundle, context, graph = supplied()
        rows = event_rows(bundle, context, graph)
        result = w.validate_event_join(bundle, context, graph, rows)
        self.assertFalse(result["sourceAuthenticated"])
        publication = next(row["log"] for row in rows if row["log"]["topics"][0] == w.EVENTS["governanceCalldataPublished"])
        observation = w.validate_calldata_publication(bundle, context, graph, publication)
        self.assertNotEqual(observation["publisher"], bundle["finality"]["executionWitness"][1])
        for mutation in ("key", "pointer", "publisher"):
            wrong = copy.deepcopy(publication)
            if mutation == "key": wrong["topics"][1] = H("wrong")
            else:
                values = list(w.decode(w.GOVERNANCE_CALLDATA_DATA, hex_bytes(wrong["data"])))
                values[1 if mutation == "pointer" else 2] = A(999) if mutation == "pointer" else ZERO_ADDRESS
                wrong["data"] = "0x" + encode(w.GOVERNANCE_CALLDATA_DATA, values).hex()
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): w.validate_calldata_publication(bundle, context, graph, wrong)

    def test_event_missing_extra_order_and_timestamp_mutations(self):
        for mutation in ("missing", "duplicate", "order", "timestamp", "transaction", "gap"):
            bundle, context, graph = supplied(); rows = event_rows(bundle, context, graph)
            if mutation == "missing": rows.pop(1)
            if mutation == "duplicate": rows.insert(1, copy.deepcopy(rows[0]))
            if mutation == "order": rows[1], rows[2] = rows[2], rows[1]
            if mutation == "timestamp": rows[0]["timestamp"] = "1"
            if mutation == "transaction": rows[-1]["log"]["transactionHash"] = H("other-execution")
            if mutation == "gap": rows[-2]["log"]["logIndex"] = hex(int(rows[-2]["log"]["logIndex"], 16) + 10)
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): w.validate_event_join(bundle, context, graph, rows)

    def test_coherent_newer_root_cannot_leave_older_root_selected_at_finality(self):
        bundle, context, graph = supplied()
        content = bundle["content"]; chain = int(context["chainId"])
        successor = w.from_json(w.ROOT_RECORD, content["rootHistory"][0]["record"])
        successor = list(successor)
        successor[0] = (*successor[0][:1], content["selectedRootHash"], successor[0][2], "ipfs://later-original-root")
        successor[11] = w.root_state_hash(chain, graph["router"]["address"], successor)
        successor[12] = H("later-root-consent")
        digest = w.root_hash(chain, graph["router"]["address"], successor)
        content["rootHistory"].append({"recordHash": digest, "record": _json(successor)})
        content["rootHead"] = digest
        # Both root hashes, state hashes, predecessor, timestamp and all retained
        # event bytes are coherent. Only the impossible selected head differs.
        w.validate_bundle(bundle, context, graph)
        with self.assertRaisesRegex(MuseumError, "selected root is not the final root head"):
            w.validate_event_join(bundle, context, graph, event_rows(bundle, context, graph))

    def test_strict_abi_widths_and_closed_groups(self):
        for value in (True, -1, 256, "01", "1\n"):
            with self.subTest(value=value), self.assertRaises((MuseumError, ValueError)):
                w.from_json("uint8", value)
        bundle, context, graph = supplied(); bundle["fullProof"] = True
        with self.assertRaises(MuseumError): w.validate_bundle(bundle, context, graph)
        bundle, context, graph = supplied(); graph["provider"] = {**graph["provider"], "accepted": True}
        with self.assertRaises(MuseumError): w.validate_bundle(bundle, context, graph)


if __name__ == "__main__": unittest.main()

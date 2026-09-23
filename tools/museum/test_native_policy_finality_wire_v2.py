"""Literal policy V2 statement/provider joins; synthetic facts, no EVM claim."""
from copy import deepcopy
import unittest

from . import native_policy_finality_wire_v2 as w
from . import native_finality_wire as base
from .canonical import MuseumError, hex_bytes, keccak256, schema_id
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS
from .test_native_finality_wire import A, H, _json


def supplied(*, count=3):
    context = {"chainId": "31337", "core": A(2), "collectionId": "1", "tokenId": "41",
        "blockNumber": "5", "blockHash": H("block5"), "timestamp": "1790000000", "stateRoot": H("state5"),
        "environment": "local_evm_fixture", "deploymentEvidenceHash": H("deployment")}
    graph = {name: {"address": A(2) if name == "core" else A(30000+i), "runtimeHash": H("policy:"+name)}
        for i, name in enumerate(w.GRAPH_KEYS)}
    independent = []
    for i, family in enumerate(base.INDEPENDENT_FAMILIES):
        role = {schema_id("ENTROPY_COORDINATOR"): "entropySourceSet", schema_id("REFERENCE_RENDER"): "policyReference"}.get(family)
        address, code = (graph[role]["address"], graph[role]["runtimeHash"]) if role else (A(40000+i), H("component:"+str(i)))
        independent.append((family, address, w.COMPONENT_INTERFACE, code, H("v"+str(i)), H("m"+str(i)), H("d"+str(i))))
    inputs = tuple(H("input"+str(i)) if i != 4 else ZERO for i in range(10))
    entropy = (graph["entropySourceSet"]["address"], graph["entropySourceSet"]["runtimeHash"], w.ENTROPY_PROFILE,
        H("inventoryPlan"), H("inventoryHash"), H("policyChain"), 1, w.SNAPSHOT_PROFILE, w.REFERENCE_PROFILE)
    s = ((0, 1, 0, ZERO), H("coreFacts"), H("root"), count, w.LEAF_SCHEMA,
        H("snapshotManifest"), H("referenceManifest"), inputs, tuple(independent), entropy, 1, 1)
    return seal(s, context, graph), context, graph, s


def seal(statement, context, graph):
    chain, cid, stamp = (int(context[k]) for k in ("chainId", "collectionId", "timestamp"))
    addr = lambda k: graph[k]["address"]
    proof = (H("sanction"), H("sanctionArtifact"), H("sanctionCoverage"))
    sanction = (base.SANCTION, addr("artist"), w.COMPONENT_INTERFACE, graph["artist"]["runtimeHash"], H("artistVersion"), H("artistManifest"), proof[0])
    components = tuple(sorted((*statement[8], sanction), key=lambda c: c[0]))
    raw = encode(w.INPUT_ENVELOPE, (w.INPUT_SCHEMA, w.INPUT_CANON, chain, addr("core"), addr("metadata"), addr("finality"), statement))
    manifest = ("", keccak256(b""), keccak256(raw), w.INPUT_SCHEMA, w.INPUT_CANON)
    digest = base.components_hash(components)
    record_hash = base.finality_hash(chain, addr("core"), cid, statement[1], digest, manifest)
    archive = (base.archive_evidence_hash(chain, addr("core"), addr("finality"), addr("artifacts"), proof), proof)
    witness = (H("action"), A(42001), H("reason"), H("roleMutation"), 1)
    execution = base.execution_context(chain, addr("finality"), addr("core"), addr("metadata"), statement, record_hash, digest, archive[0])
    call = hex_bytes(calldata(base.FINALIZE_SIGNATURE, base.FINALIZE_TYPES, (cid, components, record_hash, manifest, proof)))
    action = (3, 2, addr("finality"), 0, "0x"+call[:4].hex(), keccak256(call), execution["scopeHash"], execution["oldValueHash"],
        execution["newValueHash"], stamp-10, stamp+100, witness[1], A(42002), ZERO_ADDRESS, ZERO_ADDRESS, witness[2], "", H("calls"))
    return _json({"finality": {"record": (True, record_hash, manifest[2], manifest[1], manifest[0], digest, addr("finality"), stamp-1),
        "components": components, "manifestRef": manifest, "manifestBytes": raw, "executionWitness": witness,
        "archiveWitness": archive, "inputsHash": execution["inputsHash"]},
        "execution": {"action": action, "callDataPointer": A(42003), "callDatas": (call,),
            "runtime": b"\0" + encode((Array("bytes", 64),), ((call,),))}})


def provider_fixture(context, graph):
    targets = tuple(graph[k]["address"] for k in w.PROVIDER_TARGETS)
    hashes = tuple(graph[k]["runtimeHash"] for k in w.PROVIDER_TARGETS)
    indices = (0, 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21)
    d = (tuple(targets[i] for i in indices), tuple(hashes[i] for i in indices),
        (graph["artist"]["address"], *[A(50000+i) for i in range(4)]),
        (graph["artist"]["runtimeHash"], *[H("artistSource"+str(i)) for i in range(4)]),
        A(50010), H("extraDependency"), int(context["chainId"]), 100000, 300000, 500000, 200000, 1000000)
    policy = (targets, hashes, int(context["chainId"]), 100000, 3000000, 1000000, keccak256(encode((w.INVENTORY_DEPENDENCIES,), (d,))))
    configs = []
    for n in range(2):
        addresses, pins = list(targets), list(hashes)
        for i in (8, 9, 10, 18, 19):
            # Both inherited configurations retain the same original factory.
            addresses[i] = A(51000+(0 if i == 10 else n)*100+i)
            pins[i] = H("inherited:"+str((0 if i == 10 else n, i)))
        configs.append((tuple(addresses), tuple(pins), *policy[2:6], H("inventory"+str(n))))
    profiles = tuple((w.PROFILE_HASHES[i], c[0][9], c[1][9], c[0][8], c[1][8], c[0][10], c[1][10],
        keccak256(encode((w.PROVIDER_CONFIG,), (c,)))) for i, c in enumerate((*configs, policy)))
    pc = (graph["core"]["address"], graph["router"]["address"], graph["router"]["runtimeHash"], policy[2], policy[3],
        graph["outputManifest"]["address"], graph["outputManifest"]["runtimeHash"], profiles)
    digest = base._hash("6529STREAM_FINALITY_SOURCE_CONFIGURATION_V1", ("uint256", "address", w.PROFILE_CONTEXT),
        (policy[2], graph["provider"]["address"], pc))
    return _json({"originalConfiguration": configs[0], "scopedConfiguration": configs[1], "policyConfiguration": policy,
        "inventoryDependencies": d, "profiles": profiles, "configurationHash": digest})


class PolicyFinalityTests(unittest.TestCase):
    def test_literal_statement_and_original_collection_endpoint(self):
        b, x, g, s = supplied()
        f = w.validate_finality(b["finality"], x, g)
        self.assertEqual(f["statement"], s)
        self.assertEqual(f["historicalCoreFacts"]["status"], "hash_only")
        w.validate_execution(b["execution"], x, g, f)
        self.assertEqual(len(w.expected_finality_events(b, x, g)), 5)
        raw = hex_bytes(b["finality"]["manifestBytes"])
        self.assertEqual(len(raw), 224 + 1024 + 32 + 9 * 224)
        self.assertEqual(int.from_bytes(raw[192:224], "big"), 224)
        self.assertEqual(int.from_bytes(raw[224+640:224+672], "big"), 1024)

    def test_old_and_scoped_profiles_refused(self):
        b, x, g, s = supplied()
        for scope in ((1, 1, 41, ZERO), (2, 1, 0, H("scope")), (4, 1, 0, H("scope"))):
            changed = list(s); changed[0] = scope
            with self.subTest(scope=scope), self.assertRaises(MuseumError):
                w.validate_finality(seal(tuple(changed), x, g)["finality"], x, g)
        b["finality"]["manifestBytes"] = "0x" + encode(base.INPUT_ENVELOPE,
            (base.INPUT_SCHEMA, base.INPUT_CANON, int(x["chainId"]), g["core"]["address"], g["metadata"]["address"],
                g["finality"]["address"], (*s[:9], 1, 1, 1))).hex()
        with self.assertRaises(MuseumError): w.validate_finality(b["finality"], x, g)

    def test_original_entropy_profile_or_count_cannot_be_relabelled(self):
        _, x, g, s = supplied()
        for index, value in ((0, A(99)), (1, H("wrongRuntime")), (2, H("V1")), (6, 0), (6, 4), (7, w.REFERENCE_PROFILE), (8, w.SNAPSHOT_PROFILE)):
            entropy = list(s[9]); entropy[index] = value
            changed = (*s[:9], tuple(entropy), *s[10:])
            with self.subTest(index=index,value=value), self.assertRaises(MuseumError):
                w.validate_finality(seal(changed, x, g)["finality"], x, g)

    def test_canonical_bytes_and_complete_manifest_bound(self):
        b, x, g, s = supplied()
        for suffix in ("00", "00"*32):
            bad = deepcopy(b); bad["finality"]["manifestBytes"] += suffix
            with self.assertRaises(MuseumError): w.validate_finality(bad["finality"], x, g)
        for count in (0, 819):
            changed = (*s[:3], count, *s[4:])
            with self.assertRaises(MuseumError): w.validate_finality(seal(changed, x, g)["finality"], x, g)

    def test_entropy_and_reference_component_sources_are_exact(self):
        _, x, g, s = supplied()
        for family in ("ENTROPY_COORDINATOR", "REFERENCE_RENDER"):
            rows = list(s[8]); i = next(i for i,c in enumerate(rows) if c[0] == schema_id(family))
            c = list(rows[i]); c[1] = A(77); rows[i] = tuple(c)
            changed = (*s[:8], tuple(rows), *s[9:])
            with self.assertRaises(MuseumError): w.validate_finality(seal(changed, x, g)["finality"], x, g)

    def test_provider_catalogue_and_original_roles(self):
        _, x, g, _ = supplied(); p = provider_fixture(x, g)
        result = w.validate_provider(p, x, g)
        self.assertEqual(result["configurationHash"], p["configurationHash"])
        for key, path, val in (("originalConfiguration", (0,6), g["outputManifest"]["address"]),
                ("policyConfiguration", (0,7), g["policyContent"]["address"]),
                ("profiles", (2,0), w.REFERENCE_PROFILE), ("inventoryDependencies", (0,5), A(10))):
            bad = deepcopy(p); bad[key][path[0]][path[1]] = val
            with self.subTest(key=key,path=path), self.assertRaises(MuseumError): w.validate_provider(bad, x, g)

    def test_duplicate_address_requires_consistent_runtime(self):
        b, x, g, _ = supplied(); g["roles"] = deepcopy(g["executor"])
        w.validate_finality(b["finality"], x, g)
        g["roles"]["runtimeHash"] = H("different")
        with self.assertRaises(MuseumError): w.validate_finality(b["finality"], x, g)

    def test_definition_hashes_frozen_to_native(self):
        defs = w.definitions()[:2]
        self.assertEqual([len(d["bytes"]) for d in defs], [2073, 1933])
        self.assertEqual([d["hash"] for d in defs], [
            "0x4b066dacd57688c1ae7eb25198717c4e3263f9ee7bed1208412f7b26583dffba",
            "0x200a31382ca9faf49fee38299b55a21a2189fd52a61dbb82dd7131704fc155c0"])


if __name__ == "__main__": unittest.main()

"""Literal policy V2 statement/provider joins; synthetic facts, no EVM claim."""
from copy import deepcopy
import unittest

from . import native_scoped_policy_finality_wire_v2 as w
from . import native_finality_wire as base
from .canonical import MuseumError, hex_bytes, keccak256, schema_id
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS
from .test_native_finality_wire import A, H, _json


def supplied(*, count=3, scope_type=2):
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
    scope = (scope_type, 1, 41 if scope_type == 1 else 0, ZERO if scope_type == 1 else H("scope"))
    s = (scope, H("coreFacts"), H("root"), count, w.LEAF_SCHEMA,
        H("snapshotManifest"), H("referenceManifest"), inputs, tuple(independent), 1, 1, 1)
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
    record_hash = w.finality_hash(chain, addr("core"), statement[0], statement[1], digest, manifest)
    archive = (base.archive_evidence_hash(chain, addr("core"), addr("finality"), addr("artifacts"), proof), proof)
    witness = (H("action"), A(42001), H("reason"), H("roleMutation"), 1)
    execution = base.execution_context(chain, addr("finality"), addr("core"), addr("metadata"), statement, record_hash, digest, archive[0])
    call = hex_bytes(calldata(w.FINALIZE_SIGNATURE, w.FINALIZE_TYPES, (statement[0], components, record_hash, manifest, proof)))
    action = (3, 2, addr("finality"), 0, "0x"+call[:4].hex(), keccak256(call), execution["scopeHash"], execution["oldValueHash"],
        execution["newValueHash"], stamp-10, stamp+100, witness[1], A(42002), ZERO_ADDRESS, ZERO_ADDRESS, witness[2], "", H("calls"))
    return _json({"finality": {"record": (True, statement[0], record_hash, manifest[2], manifest[1], digest, manifest[0], addr("finality"), stamp-1),
        "components": components, "manifestRef": manifest, "manifestBytes": raw, "executionWitness": witness,
        "archiveWitness": archive, "inputsHash": execution["inputsHash"]},
        "execution": {"action": action, "callDataPointer": A(42003), "callDatas": (call,),
            "runtime": b"\0" + encode((Array("bytes", 64),), ((call,),))}})


class ScopedPolicyFinalityTests(unittest.TestCase):
    def test_exact_scoped_manifest_endpoint_and_components(self):
        for kind,count in ((1,1),(2,3),(3,3)):
            b,x,g,s = supplied(scope_type=kind,count=count)
            f=w.validate_finality(b["finality"],x,g,s[0])
            self.assertEqual(f["statement"],s)
            self.assertEqual(f["historicalCoreFacts"]["status"],"hash_only")
            w.validate_execution(b["execution"],x,g,f)
            self.assertEqual(len(w.expected_finality_events({**b,"scope":s[0]},x,g)),5)
            self.assertEqual(b["execution"]["callDatas"][0][:10], schema_id(w.FINALIZE_SIGNATURE)[:10])

    def test_wrong_profile_scope_or_count_rejected(self):
        _,x,g,s=supplied()
        for scope,count in (((0,1,0,ZERO),3),((4,1,0,H("view")),3),((1,1,41,ZERO),3),(s[0],819)):
            with self.subTest(scope=scope,count=count),self.assertRaises(MuseumError):
                changed=(scope,*s[1:3],count,*s[4:])
                b=seal(changed,x,g)
                w.validate_finality(b["finality"],x,g,scope)

    def test_native_component_identity_and_interface_not_relabelled(self):
        _,x,g,s=supplied()
        for family in ("ENTROPY_COORDINATOR","REFERENCE_RENDER"):
            rows=list(s[8]);i=next(i for i,c in enumerate(rows) if c[0]==schema_id(family))
            for index,value in ((1,A(99)),(2,schema_id("finalityState(uint256)")[:10]),(3,H("othercode"))):
                changed=list(rows[i]);changed[index]=value;other=list(rows);other[i]=tuple(changed)
                ns=(*s[:8],tuple(other),*s[9:]);b=seal(ns,x,g)
                with self.subTest(family=family,index=index),self.assertRaises(MuseumError):w.validate_finality(b["finality"],x,g,s[0])

    def test_exact_manifest_bytes_and_record_time(self):
        b,x,g,s=supplied()
        for key in ("manifestBytes","record"):
            changed=deepcopy(b)
            if key=="manifestBytes": changed["finality"][key]+="00"
            else: changed["finality"][key][8]=str(int(x["timestamp"])+1)
            with self.subTest(key=key),self.assertRaises(MuseumError):w.validate_finality(changed["finality"],x,g,s[0])

    def test_original_scoped_definitions_are_identical(self):
        from . import native_scoped_finality_wire as original
        self.assertEqual(w.definitions()[:2],original.definitions()[:2])
        self.assertEqual(len({r["id"] for r in w.definitions()}),len(w.definitions()))
        self.assertTrue(all(keccak256(r["bytes"])==r["hash"] for r in w.definitions()))

    def test_original_call_carrier_cannot_omit_or_duplicate_finalize(self):
        b,x,g,s=supplied();f=w.validate_finality(b["finality"],x,g,s[0])
        for calls in ([],b["execution"]["callDatas"]*2):
            changed=deepcopy(b["execution"]);changed["callDatas"]=calls
            with self.assertRaises(MuseumError):w.validate_execution(changed,x,g,f)


if __name__=="__main__": unittest.main()

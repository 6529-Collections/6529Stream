"""Synthetic native-wire citation controls; no RPC, execution or consensus claim."""
from copy import deepcopy
from pathlib import Path
import unittest
from unittest.mock import patch

from . import canonical_citation_source as c
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id
from .chain_abi import calldata, encode
from .chain_rpc import ReplayTransport

ROOT = Path(__file__).resolve().parents[2]


def A(n): return "0x" + n.to_bytes(20, "big").hex()
def H(label): return keccak256(str(label).encode())


class Transport:
    def __init__(self, responses): self.responses = responses
    def request(self, method, params):
        try: return deepcopy(self.responses[dumps([method, params])])
        except KeyError as exc: raise MuseumError("unexpected synthetic citation request") from exc


class Fixture:
    """Reusable source fixture; retained old manifest is adapted as explicit synthetic data."""
    def __init__(self, *, finalized=True, token_finality=False, snapshot=True, recovery=False, burned=False, multi_family=False):
        self.responses, self.rows, self.recoveries = {}, [], []
        self.core, self.router, self.finality, self.snapshots, self.recovery = A(1), A(5), A(10), A(11), A(12)
        self.runtimes = {A(i): bytes([0x60, i]) for i in range(1, 13)}
        self.anchor = {"profile": c.PROFILE, "chainId": "31337", "core": self.core, "tokenId": "41", "collectionId": "1",
            "blockHash": H("block"), "blockNumber": "2", "timestamp": "1002", "stateRoot": H("state"),
            "environment": "local_evm_fixture", "deploymentEvidenceHash": H("synthetic citation deployment"),
            "codePins": [{"address": a, "runtimeHash": keccak256(raw)} for a, raw in self.runtimes.items()],
            "router": self.router, "originalFinality": self.finality, "recovery": self.recovery if recovery else None,
            "snapshots": {"host": self.snapshots, "profile": "inline_v1", "records": []} if snapshot else None}
        self.block = {"hash": H("block"), "number": "0x2", "timestamp": hex(1002), "stateRoot": H("state")}
        self.put("eth_chainId", [], hex(31337))
        self.put("eth_getBlockByHash", [H("block"), False], self.block)
        for address, raw in self.runtimes.items(): self.code(address, raw)
        self.call(self.core, "tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"), (True, 1, 7, burned), ("uint256",), (41,))
        self.call(self.core, "tokenLifecycle(uint256)", ("uint8",), (3 if burned else 2,), ("uint256",), (41,))
        for host in (self.router, self.finality): self.call(host, "core()", ("address",), (self.core,))
        self.call(self.router, "servingOriginalFinalityAnchor()", ("address", "bytes32"), (self.finality, keccak256(self.runtimes[self.finality])))
        self.call(self.router, "originalFinalityAnchor(uint256)", ("address", "bytes32"), (c.ZERO_ADDRESS, c.ZERO), ("uint256",), (1,))
        for sig, expected in (("streamModuleType()", "ARTWORK_FINALITY_REGISTRY"), ("streamModuleVersion()", "6529stream.canonical-artwork-finality.v1")):
            self.call(self.finality, sig, ("bytes32",), (schema_id(expected),))
        self.scopes = ((0, 1, 0, c.ZERO), (1, 1, 41, c.ZERO))
        self.originals = []
        self.components = [(schema_id("METADATA_ROUTER"), A(20), "0x12345678", H("component code"), H("version"), H("manifest"), H("data"))]
        if multi_family:
            self.components.append((schema_id("RENDERER"), A(22), "0x12345678", H("renderer code"), H("version"), H("manifest"), H("data")))
            self.components.sort()
        self.add_finality(self.scopes[0], finalized)
        self.add_finality(self.scopes[1], token_finality)
        if snapshot: self.add_snapshot()
        if recovery: self.add_recovery()

    @property
    def ref(self): return {"blockHash": self.anchor["blockHash"], "requireCanonical": True}
    def put(self, method, params, value): self.responses[dumps([method, params])] = value
    def code(self, address, raw): self.put("eth_getCode", [address, self.ref], "0x" + raw.hex())
    def call(self, host, signature, outputs, values, inputs=(), args=()):
        self.put("eth_call", [{"to": host, "data": calldata(signature, inputs, args), "gas": "0x1312d00"}, self.ref], "0x" + encode(outputs, values).hex())
    def call_key(self, host, sig, inputs=(), args=()):
        return dumps(["eth_call", [{"to": host, "data": calldata(sig, inputs, args), "gas": "0x1312d00"}, self.ref]])
    def source(self): return c.CanonicalCitationSource(dumps(self.anchor), Transport(self.responses))
    def result(self): return loads(self.source().snapshot(), maximum=c.MAX_OUTPUT)

    def add_finality(self, scope, finalized):
        components = self.components if finalized else []
        raw = b"original finality bytes " + bytes([scope[0]])
        ch = keccak256(encode(("bytes32", c.Array(c.COMPONENT, 32)), (schema_id("6529STREAM_FINALITY_COMPONENTS_V1"), components)))
        r = ((True, scope, H("finality" + str(scope[0])), keccak256(raw), keccak256(b"ipfs://finality"), ch,
            "ipfs://finality", self.finality, 1001) if finalized else
            (False, (0, 0, 0, c.ZERO), c.ZERO, c.ZERO, c.ZERO, c.ZERO, "", c.ZERO_ADDRESS, 0))
        self.originals.append(r)
        self.call(self.finality, "artworkScopeFinalityRecord(" + c.SCOPE_SIG + ")", (c.SCOPED,), (r,), (c.SCOPE,), (scope,))
        if scope[0] == 0:
            self.call(self.finality, "collectionFinalityRecord(uint256)", (c.COLLECTION,), ((r[0], r[2], r[3], r[4], r[6], r[5], r[7], r[8]),), ("uint256",), (1,))
        self.call(self.finality, "finalityComponentCountForScope(" + c.SCOPE_SIG + ")", ("uint256",), (len(components),), (c.SCOPE,), (scope,))
        self.call(self.finality, "finalityComponentsForScope(" + c.SCOPE_SIG + ",uint256,uint256)", (c.Array(c.COMPONENT, 32),), (components,), (c.SCOPE, "uint256", "uint256"), (scope, 0, len(components)))
        self.call(self.finality, "verifyArtworkScopeFinality(" + c.SCOPE_SIG + ")", ("bool", "bytes32", "bytes32"), (False, r[2], r[5]), (c.SCOPE,), (scope,))
        if finalized:
            self.call(self.finality, "finalityManifestStored(bytes32)", ("bool",), (True,), ("bytes32",), (r[3],))
            self.call(self.finality, "finalityManifestBytes(bytes32)", ("bytes",), (raw,), ("bytes32",), (r[3],))
            self.call(self.finality, "finalityExecutionWitness(bytes32)", (c.WITNESS,), ((H("action"), A(30), H("reason"), H("role"), 1),), ("bytes32",), (r[2],))

    def add_snapshot(self, *, edit=None, raw_override=None, document=None, profile="inline_v1", recorded_at=1001):
        value = deepcopy(document) if document else loads((ROOT / "test/fixtures/metadata/snapshot-native-onchain.json").read_bytes())
        self.anchor["snapshots"]["profile"] = profile
        targets = tuple(A(i) for i in range(1, 10))
        hashes = tuple(keccak256(self.runtimes[x]) for x in targets)
        value["sources"] = [{"address": x, "runtimeHash": h, "role": str(i)} for i, (x, h) in enumerate(zip(targets, hashes))]
        value["subject"] = subject_id("collection", "31337", self.core, "1")
        if profile == "chunked_v1":
            lib = value["library"]
            if lib is not None: lib["bundleId"] = c.chunked.bundle_hash(value, lib, True)
            s = value["script"]
            s["libraryBundle"] = c.ZERO if lib is None else lib["bundleId"]
            s["bundleId"] = c.chunked.bundle_hash(value, s, False)
            s["manifest"]["sourcePointer"] = s["bundleId"]
            s["manifestHash"] = c.chunked.manifest_hash(value)
        i = len(self.rows)
        value["publication"].update(snapshotId=H("snapshot" + str(i)), predecessor=self.rows[-1][0] if i else c.ZERO, revision=str(i + 1))
        if edit: edit(value)
        raw = dumps(value) if raw_override is None else raw_override
        pub = value["publication"]
        p = (1, pub["snapshotId"], pub["predecessor"], i, H("source"), value["entropy"]["planId"], pub["manifestURI"], int(pub["effectiveAt"]), pub["reasonHash"])
        r = [c.ZERO, 1, p[1], p[2], i + 1, c.ZERO, keccak256(raw), len(raw), p[4], p[5], pub["publisher"],
            int(pub["authorizationClass"]), int(pub["grantRevision"]), int(pub["displayAuthorizationClass"]), int(pub["displayGrantRevision"]), p[7], recorded_at, p[8], value["schemaHash"], value["profileHash"], keccak256(c.JCS_BYTES)]
        digest = c.snapshot_hash(31337, self.snapshots, self.core, A(2), p, r, profile)
        r[0] = digest
        r[5] = c.snapshot_chain(31337, self.snapshots, self.core, 1, self.rows[-1][2][5] if i else c.ZERO, r[4], digest, profile)
        r = tuple(r)
        self.rows.append((digest, p, r, raw))
        self.anchor["snapshots"]["records"].append(digest)
        self.call(self.snapshots, "dependencies()", (c.DEPENDENCIES,), ((targets, hashes, 31337, 100000, 100000, 100000, 100000),))
        for sig, address in (("core()", self.core), ("metadataHost()", A(2)), ("schemaRegistry()", A(3)), ("chunkStore()", A(4)), ("metadataRouter()", self.router)):
            self.call(self.snapshots, sig, ("address",), (address,))
        self.call(self.snapshots, "snapshotCount(uint256)", ("uint256",), (len(self.rows),), ("uint256",), (1,))
        self.call(self.snapshots, "currentSnapshot(uint256)", (c.RECEIPT,), (r,), ("uint256",), (1,))
        self.call(self.snapshots, "latestSnapshotHash(uint256)", ("bytes32",), (r[6],), ("uint256",), (1,))
        self.call(self.snapshots, "snapshotRecordAt(uint256,uint256)", ("bytes32",), (digest,), ("uint256", "uint256"), (1, i))
        self.call(self.snapshots, "snapshotRecord(bytes32)", (c.PUBLICATION, c.RECEIPT), (p, r), ("bytes32",), (digest,))
        self.call(self.snapshots, "snapshotHash(uint256,bytes32)", ("bytes32",), (r[6],), ("uint256", "bytes32"), (1, p[1]))
        self.call(self.snapshots, "snapshotManifestChunkCount(bytes32)", ("uint256",), ((len(raw) + 8191) // 8192,), ("bytes32",), (digest,))
        for n in range((len(raw) + 8191) // 8192):
            part, pointer = raw[n * 8192:(n + 1) * 8192], A(100 + i * 64 + n)
            self.call(self.snapshots, "snapshotManifestChunkAt(bytes32,uint256)", ("bytes32", "address", "uint32"), (keccak256(part), pointer, len(part)), ("bytes32", "uint256"), (digest, n))
            self.code(pointer, b"\0" + part)
        self.call(self.snapshots, "snapshotManifestPointer(uint256,bytes32)", ("address",), (A(100 + i * 64),), ("uint256", "bytes32"), (1, p[1]))
        self.call(self.snapshots, "snapshotManifestBytes(bytes32)", ("bytes",), (raw,), ("bytes32",), (digest,))
        return self.rows[-1]

    def add_recovery(self, family_index=0, *, manifest_uri="ipfs://recovery", reason_uri="ipfs://reason"):
        host = self.recovery
        for sig, value in (("core()", self.core), ("originalFinalityRegistry()", self.finality)):
            self.call(host, sig, ("address",), (value,))
        for sig, value in (("streamModuleType()", "STREAM_ARTWORK_FINALITY_RECOVERY"), ("streamModuleVersion()", "6529stream.artwork-finality-recovery.v1")):
            self.call(host, sig, ("bytes32",), (schema_id(value),))
        pointer = (host, keccak256(self.runtimes[host]), False, schema_id("STREAM_ARTWORK_FINALITY_RECOVERY"), "0x83685f5c", A(15), 1, H("module"), H("deploy"), 1)
        self.call(self.core, "getSatellitePointer(bytes32)", (c.POINTER,), (pointer,), ("bytes32",), (schema_id("ARTWORK_FINALITY_RECOVERY"),))
        family = self.components[family_index][0]
        generation = len(self.recoveries) + 1
        component = (family, A(20 + generation), "0x12345678", H("replacement code"), H("version"), H("replacement manifest"), H("replacement data"))
        manifest = [manifest_uri, keccak256(manifest_uri.encode("utf8")), c.ZERO, H("recovery schema"), H("recovery canon")]
        evidence = (1, H("approval"), A(50), H("artist"), 1, 1000, H("owner evidence"), 1, 1000, 1, 0)
        previous = self.recoveries[-1][1] if self.recoveries else c.ZERO
        old = next((r[9] for r in reversed(self.recoveries) if r[9][0] == family), self.components[family_index])
        r = [True, H("recovery action" + str(generation)), self.scopes[0], self.originals[0][2], previous, generation, c.component_hash(old), c.ZERO,
            True, component, manifest, evidence, H("recovery reason"), reason_uri, 1002]
        raw = c.recovery_intent(31337, host, r)
        manifest[2] = keccak256(raw)
        r[7] = c.recovered_hash(31337, host, r)
        r = tuple(r); self.recoveries.append(r)
        self.call(host, "finalityRecoveryRecord(bytes32)", (c.RECOVERY,), (r,), ("bytes32",), (r[1],))
        self.call(host, "finalityRecoveryManifestBytes(bytes32)", ("bytes",), (raw,), ("bytes32",), (manifest[2],))
        for scope in self.scopes:
            head = (r[1], r[7], generation) if scope[0] == 0 else (c.ZERO, c.ZERO, 0)
            self.call(host, "activeFinalityRecovery(" + c.SCOPE_SIG + ")", c.HEAD, head, (c.SCOPE,), (scope,))
            for original in self.components:
                selected = next((r for r in reversed(self.recoveries) if r[9][0] == original[0]), None)
                value, rid = (selected[9], selected[1]) if selected else (original, c.ZERO)
                self.call(host, "resolvedFinalityRoute(bytes32," + c.SCOPE_SIG + ")", c.ROUTE,
                    (True, value[1], c.component_hash(value), r[3], rid), ("bytes32", c.SCOPE), (original[0], scope))
                self.call(host, "finalityRecoveryRouteStatus(bytes32," + c.SCOPE_SIG + ")", c.STATUS,
                    (True, False, c.component_hash(value), rid), ("bytes32", c.SCOPE), (original[0], scope))


class CitationSourceTests(unittest.TestCase):
    def test_native_finality_snapshot_and_executed_recovery_choices(self):
        f = Fixture(recovery=True)
        result = f.result()
        self.assertEqual(result["identity"]["collectionSerial"], "7")
        self.assertEqual(result["originalWorkCitation"], "eip155:31337/erc721:" + f.core + "/41")
        for kind in ("fin", "snap", "rec"):
            self.assertEqual(len(result["choices"][kind]), 1)
            self.assertTrue(result["choices"][kind][0]["citation"].endswith("@" + kind + ":" + result["choices"][kind][0]["hash"]))
        self.assertNotEqual(result["choices"]["snap"][0]["hash"], f.rows[0][0])
        self.assertNotEqual(result["choices"]["rec"][0]["hash"], f.recoveries[0][1])
        self.assertFalse(result["finality"][0]["currentDiagnostic"][0])
        self.assertFalse(result["recovery"]["routes"][0]["status"][1])
        self.assertEqual(result["recovery"]["exactHeads"][1]["head"], [c.ZERO, c.ZERO, "0"])
        self.assertFalse(result["claims"]["actualChainAcceptance"])

    def test_exact_replay_preserves_source_qualification(self):
        f = Fixture(recovery=True); source = f.source(); first = source.snapshot(); transcript = source.transcript()
        self.assertIs(first, source.snapshot())
        replay = c.CanonicalCitationSource(dumps(f.anchor), ReplayTransport(transcript, keccak256(transcript)), provenance="trusted_rpc")
        expected = loads(first, maximum=c.MAX_OUTPUT); expected["mode"] = "caller_admitted_rpc"
        self.assertEqual(loads(replay.snapshot(), maximum=c.MAX_OUTPUT), expected)
        self.assertEqual(replay.transcript(), transcript)
        bad = loads(transcript, maximum=67108864); bad["calls"].append(bad["calls"][-1]); raw = dumps(bad)
        with self.assertRaisesRegex(MuseumError, "unconsumed"):
            c.CanonicalCitationSource(dumps(f.anchor), ReplayTransport(raw, keccak256(raw)), provenance="trusted_rpc").snapshot()

    def test_absent_finality_and_burned_original_identity(self):
        result = Fixture(finalized=False, snapshot=False, burned=True).result()
        self.assertTrue(result["identity"]["burned"])
        self.assertEqual(result["identity"]["lifecycle"], "3")
        self.assertEqual(result["choices"], {"fin": [], "snap": [], "rec": [], "chain": []})
        self.assertIsNone(result["snapshots"])

    def test_exact_token_scope_is_separate_from_collection(self):
        result = Fixture(token_finality=True, snapshot=False).result()
        self.assertEqual([x["scope"][0] for x in result["choices"]["fin"]], ["0", "1"])

    def test_identity_lifecycle_core_and_original_binding_reject(self):
        for outputs, values, target, sig, inputs, args in (
            (("bool", "uint256", "uint256", "bool"), (True, 2, 7, False), A(1), "tokenCollectionIdentity(uint256)", ("uint256",), (41,)),
            (("uint8",), (1,), A(1), "tokenLifecycle(uint256)", ("uint256",), (41,)),
            (("address",), (A(99),), A(10), "core()", (), ()),
            (("address", "bytes32"), (A(99), H("other")), A(5), "servingOriginalFinalityAnchor()", (), ())):
            f = Fixture(snapshot=False); f.call(target, sig, outputs, values, inputs, args)
            with self.subTest(sig=sig), self.assertRaises(MuseumError): f.source().snapshot()

    def test_finality_hash_components_and_manifests_reject(self):
        for change in ("scope", "components", "manifest", "witness", "diagnostic"):
            f = Fixture(snapshot=False); r = f.originals[0]
            if change == "scope":
                changed = list(r); changed[1] = (0, 2, 0, c.ZERO)
                f.call(f.finality, "artworkScopeFinalityRecord(" + c.SCOPE_SIG + ")", (c.SCOPED,), (changed,), (c.SCOPE,), (f.scopes[0],))
            elif change == "components":
                f.call(f.finality, "finalityComponentsForScope(" + c.SCOPE_SIG + ",uint256,uint256)", (c.Array(c.COMPONENT, 32),), ([],), (c.SCOPE, "uint256", "uint256"), (f.scopes[0], 0, 1))
            elif change == "manifest": f.call(f.finality, "finalityManifestBytes(bytes32)", ("bytes",), (b"other",), ("bytes32",), (r[3],))
            elif change == "witness": f.call(f.finality, "finalityExecutionWitness(bytes32)", (c.WITNESS,), ((c.ZERO, A(30), H("r"), H("m"), 1),), ("bytes32",), (r[2],))
            else: f.call(f.finality, "verifyArtworkScopeFinality(" + c.SCOPE_SIG + ")", ("bool", "bytes32", "bytes32"), (False, H("foreign"), r[5]), (c.SCOPE,), (f.scopes[0],))
            with self.subTest(change=change), self.assertRaises(MuseumError): f.source().snapshot()

    def test_multiple_snapshot_receipts_keep_full_history_selected_bytes_only(self):
        f = Fixture(); second = f.add_snapshot()
        f.anchor["snapshots"]["records"] = [f.rows[0][0]]
        result = f.result()["snapshots"]
        self.assertEqual(len(result["history"]), 2)
        self.assertEqual(len(result["selected"]), 1)
        self.assertEqual(result["current"][0], second[0])

    def test_snapshot_publication_time_is_monotonic_but_effective_time_is_not(self):
        f = Fixture()
        # Both rows remain individually valid and every record/chain hash is rebuilt.
        f.add_snapshot(recorded_at=1000)
        with self.assertRaisesRegex(MuseumError, "publication time regressed"):
            f.source().snapshot()
        f = Fixture()
        f.add_snapshot(recorded_at=1002, edit=lambda v: v["publication"].update(effectiveAt="999"))
        rows = f.result()["snapshots"]["history"]
        self.assertEqual([r["receipt"][16] for r in rows], ["1001", "1002"])
        self.assertEqual([r["receipt"][15] for r in rows], ["1000", "999"])

    def test_exact_recovery_head_keeps_collection_original_after_token_finality(self):
        f = Fixture(snapshot=False, token_finality=True, recovery=True)
        # Token recovery admitted inherited collection finality; an exact token finality
        # was recorded later. Change all native intent/hash/head/route observations together.
        r = list(f.recoveries[0]); r[2] = f.scopes[1]; r[14] = 1001
        r[10] = list(r[10]); raw = c.recovery_intent(31337, f.recovery, r)
        r[10][2] = keccak256(raw); r[7] = c.recovered_hash(31337, f.recovery, r)
        f.call(f.recovery, "finalityRecoveryRecord(bytes32)", (c.RECOVERY,), (r,), ("bytes32",), (r[1],))
        f.call(f.recovery, "finalityRecoveryManifestBytes(bytes32)", ("bytes",), (raw,), ("bytes32",), (r[10][2],))
        later = list(f.originals[1]); later[8] = 1002
        f.call(f.finality, "artworkScopeFinalityRecord(" + c.SCOPE_SIG + ")", (c.SCOPED,), (later,), (c.SCOPE,), (f.scopes[1],))
        for scope in f.scopes:
            original = f.components[0]
            selected, rid = (r[9], r[1]) if scope[0] == 1 else (original, c.ZERO)
            head = (r[1], r[7], r[5]) if scope[0] == 1 else (c.ZERO, c.ZERO, 0)
            f.call(f.recovery, "activeFinalityRecovery(" + c.SCOPE_SIG + ")", c.HEAD, head, (c.SCOPE,), (scope,))
            f.call(f.recovery, "resolvedFinalityRoute(bytes32," + c.SCOPE_SIG + ")", c.ROUTE,
                (True, selected[1], c.component_hash(selected), r[3], rid), ("bytes32", c.SCOPE), (original[0], scope))
            f.call(f.recovery, "finalityRecoveryRouteStatus(bytes32," + c.SCOPE_SIG + ")", c.STATUS,
                (True, False, c.component_hash(selected), rid), ("bytes32", c.SCOPE), (original[0], scope))
        result = f.result()
        self.assertEqual(len(result["choices"]["fin"]), 2)
        self.assertEqual(result["choices"]["rec"][0]["originalFinalityRecordHash"], f.originals[0][2])
        self.assertEqual(result["recovery"]["routes"][1]["route"][3], f.originals[0][2])
        self.assertNotEqual(result["recovery"]["routes"][1]["route"][3], later[2])
        # Substitution of the newer token finality is still rejected.
        f.call(f.recovery, "resolvedFinalityRoute(bytes32," + c.SCOPE_SIG + ")", c.ROUTE,
            (True, r[9][1], c.component_hash(r[9]), later[2], r[1]), ("bytes32", c.SCOPE), (r[9][0], f.scopes[1]))
        with self.assertRaisesRegex(MuseumError, "resolved original/family"):
            f.source().snapshot()

    def test_recovery_uri_limits_use_complete_native_request_abi(self):
        f = Fixture(snapshot=False, recovery=True)
        f.add_recovery(manifest_uri="ipfs://" + "é" * 1200, reason_uri="ipfs://" + "r" * 3000)
        r = f.recoveries[-1]
        self.assertGreater(len(r[10][0].encode("utf8")), 2048)
        self.assertGreater(len(r[13].encode("utf8")), 2048)
        self.assertLessEqual(len(c.recovery_request(r)), 24575)
        self.assertEqual(len(f.result()["recovery"]["records"]), 2)
        f = Fixture(snapshot=False, recovery=True)
        f.add_recovery(manifest_uri="ipfs://" + "x" * 25000)
        self.assertGreater(len(c.recovery_request(f.recoveries[-1])), 24575)
        with self.assertRaisesRegex(MuseumError, "request ABI byte bound"):
            f.source().snapshot()

    def test_chunked_large_manifest_reconstructed_without_oversized_rpc_response(self):
        from tools.metadata.test_chunked_snapshot_profile import specimen
        f = Fixture(snapshot=False)
        f.anchor["snapshots"] = {"host": f.snapshots, "profile": "chunked_v1", "records": []}
        document = specimen(parts=[b"/" * 24576] * 20, library=False)
        row = f.add_snapshot(document=document, profile="chunked_v1")
        source = f.source(); result = loads(source.snapshot(), maximum=c.MAX_OUTPUT)
        saved = result["snapshots"]["selected"][0]
        self.assertGreater(len(row[3]), c.FULL_GETTER_LIMIT)
        self.assertGreater(len(saved["chunks"]), 64)
        self.assertEqual(hex_bytes(saved["manifestBytes"]), row[3])
        self.assertFalse(saved["fullGetterCompared"])
        self.assertTrue(any(saved["chunks"][i]["chunkHash"] == saved["chunks"][j]["chunkHash"]
            for i in range(2, len(saved["chunks"]) - 2) for j in range(i + 1, len(saved["chunks"]) - 2)))
        selector = calldata("snapshotManifestBytes(bytes32)", ("bytes32",), (row[0],))
        self.assertFalse(any(r["method"] == "eth_call" and r["params"][0]["data"] == selector for r in source.reader.rows))

    def test_recovery_latest_head_and_per_family_override_are_distinct(self):
        f = Fixture(snapshot=False, recovery=True, multi_family=True); f.add_recovery(family_index=1)
        result = f.result()["recovery"]
        self.assertEqual(len(result["records"]), 2)
        self.assertEqual(result["exactHeads"][0]["head"][0], f.recoveries[1][1])
        selected = {r["route"][4] for r in result["routes"]}
        self.assertEqual(selected, {r[1] for r in f.recoveries})
        f.add_recovery(family_index=0)
        old = f.recoveries[0]
        for scope in f.scopes:
            f.call(f.recovery, "resolvedFinalityRoute(bytes32," + c.SCOPE_SIG + ")", c.ROUTE,
                (True, old[9][1], c.component_hash(old[9]), old[3], old[1]), ("bytes32", c.SCOPE), (old[9][0], scope))
            f.call(f.recovery, "finalityRecoveryRouteStatus(bytes32," + c.SCOPE_SIG + ")", c.STATUS,
                (True, False, c.component_hash(old[9]), old[1]), ("bytes32", c.SCOPE), (old[9][0], scope))
        with self.assertRaisesRegex(MuseumError, "latest family"): f.source().snapshot()

    def test_rehashed_wrong_manifest_source_and_publication_fail(self):
        for edit in (lambda v: v.update(collectionId="2"), lambda v: v["publication"].update(revision="2"),
                     lambda v: v.update(profileHash=H("wrong profile"))):
            f = Fixture(snapshot=False); f.anchor["snapshots"] = {"host": f.snapshots, "profile": "inline_v1", "records": []}
            f.add_snapshot(edit=edit)
            with self.assertRaises(MuseumError): f.source().snapshot()

    def test_snapshot_chunk_pointer_full_getter_and_chain_tamper(self):
        for change in ("chunk", "pointer", "whole", "chain", "definition", "profile"):
            f = Fixture(); digest, p, r, raw = f.rows[0]
            if change == "chunk": f.code(A(100), b"\0" + bytes([raw[0] ^ 1]) + raw[1:8192])
            elif change == "pointer": f.call(f.snapshots, "snapshotManifestPointer(uint256,bytes32)", ("address",), (A(99),), ("uint256", "bytes32"), (1, p[1]))
            elif change == "whole": f.call(f.snapshots, "snapshotManifestBytes(bytes32)", ("bytes",), (raw + b" ",), ("bytes32",), (digest,))
            elif change == "profile": f.anchor["snapshots"]["profile"] = "chunked_v1"
            else:
                bad = list(r); bad[5 if change == "chain" else 18] = H("tamper")
                f.call(f.snapshots, "snapshotRecord(bytes32)", (c.PUBLICATION, c.RECEIPT), (p, bad), ("bytes32",), (digest,))
            with self.subTest(change=change), self.assertRaises(MuseumError): f.source().snapshot()

    def test_recovery_staged_only_wrong_scope_manifest_and_route_fail(self):
        for change in ("unexecuted", "scope", "intent", "route", "lineage", "status"):
            f = Fixture(snapshot=False, recovery=True); r = list(f.recoveries[0])
            if change == "intent":
                f.call(f.recovery, "finalityRecoveryManifestBytes(bytes32)", ("bytes",), (b"x" * 704,), ("bytes32",), (r[10][2],))
            elif change == "status":
                f.call(f.recovery, "finalityRecoveryRouteStatus(bytes32," + c.SCOPE_SIG + ")", c.STATUS, (True, False, H("bad"), r[1]), ("bytes32", c.SCOPE), (r[9][0], f.scopes[0]))
            else:
                if change == "unexecuted": r[0] = False
                elif change == "scope": r[2] = (1, 1, 99, c.ZERO)
                elif change == "route": r[7] = H("bad")
                else: r[5] = 2; r[7] = c.recovered_hash(31337, f.recovery, r)
                f.call(f.recovery, "finalityRecoveryRecord(bytes32)", (c.RECOVERY,), (r,), ("bytes32",), (r[1],))
            with self.subTest(change=change), self.assertRaises(MuseumError): f.source().snapshot()

    def test_rehashed_noncanonical_abi_and_block_replay_fail(self):
        for change in ("abi", "block"):
            f = Fixture(snapshot=False); source = f.source(); source.snapshot(); value = loads(source.transcript())
            if change == "abi":
                row = next(r for r in value["calls"] if r["method"] == "eth_call")
                row["result"] += "00" * 32
            else: value["calls"][-1]["result"]["stateRoot"] = H("other state")
            raw = dumps(value)
            with self.subTest(change=change), self.assertRaises(MuseumError):
                c.CanonicalCitationSource(dumps(f.anchor), ReplayTransport(raw, keccak256(raw)), provenance="trusted_rpc").snapshot()

    def test_bounds_and_failed_capture_cannot_resume(self):
        f = Fixture(); f.call(f.snapshots, "snapshotCount(uint256)", ("uint256",), (65,), ("uint256",), (1,))
        source = f.source()
        with self.assertRaisesRegex(MuseumError, "history bound"): source.snapshot()
        with self.assertRaisesRegex(MuseumError, "cannot resume"): source.snapshot()
        with self.assertRaisesRegex(MuseumError, "snapshot required"): source.transcript()
        with patch.object(c, "MAX_OUTPUT", 100):
            with self.assertRaises(MuseumError): Fixture().source().snapshot()

    def test_selection_duplicate_foreign_and_unknown_anchor_rejected(self):
        for change in ("duplicate", "foreign", "extra"):
            f = Fixture()
            if change == "duplicate": f.anchor["snapshots"]["records"] *= 2
            elif change == "foreign": f.anchor["snapshots"]["records"] = [H("foreign record")]
            else: f.anchor["assumeFinalized"] = True
            with self.subTest(change=change), self.assertRaises(MuseumError): f.source().snapshot()


if __name__ == "__main__": unittest.main()

"""Focused synthetic controls for the fixed genesis Registry source reader."""
from copy import deepcopy
import unittest

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import Array, calldata, encode
from . import genesis_registry_plan_v1 as plan_module
from . import genesis_registry_source_v1 as source
from .independent_wire import DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, ZERO
from .publication import KINDS
from .public_history_rpc import PublicReplayTransport


def H(label):
    return keccak256(str(label).encode())


def A(number):
    return "0x" + number.to_bytes(20, "big").hex()


class Transport:
    def __init__(self, fixture):
        self.fixture = fixture
        self.calls = []

    def request(self, method, params):
        self.calls.append((method, deepcopy(params)))
        key = dumps([method, params])
        if key not in self.fixture.responses:
            raise MuseumError("unexpected synthetic genesis Registry request")
        return deepcopy(self.fixture.responses[key])


class GenesisRegistryFixture:
    """Concrete reusable 51-document, one-block Registry fixture."""

    def __init__(self):
        self.plan = plan_module.prepare()
        self.responses, self.documents, self.runtimes = {}, {}, {}
        self.core, self.metadata, self.module_registry = A(1), A(2), A(3)
        self.schemas, self.store, self.governance = A(4), A(5), A(6)
        self.block = {"hash": H("genesis Registry block"), "number": "0x2a",
            "timestamp": "0x64", "stateRoot": H("genesis Registry state"),
            "parentHash": H("genesis Registry parent"), "transactionsRoot": H("transactions"),
            "receiptsRoot": H("receipts"), "transactions": []}
        self.block_ref = {"blockHash": self.block["hash"], "requireCanonical": True}
        for number, address in enumerate((self.core, self.metadata, self.module_registry,
                self.schemas, self.store, self.governance), 1):
            self.runtimes[address] = b"\x60" + number.to_bytes(2, "big")
        self.anchor = {"profile": source.PROFILE, "chainId": "31337", "core": self.core,
            "blockHash": self.block["hash"], "blockNumber": "42", "timestamp": "100",
            "stateRoot": self.block["stateRoot"], "environment": "local_evm_fixture",
            "deploymentEvidenceHash": H("genesis deployment"),
            "coreRuntimeHash": keccak256(self.runtimes[self.core]),
            "codePins": [{"address": address, "runtimeHash": keccak256(runtime)}
                for address, runtime in self.runtimes.items()],
            "runtimeAdmission": {"sourceCommit": source.SOURCE_REVISION,
                "kind": "synthetic_fixture", "artifactHash": H("synthetic artifact")}}
        self.anchor_raw = dumps(self.anchor)
        self._install_graph()
        for index in range(len(self.plan.documents)):
            self.install_document(index)

    def put(self, method, params, result):
        self.responses[dumps([method, params])] = result

    def request(self, method, params):
        key = dumps([method, params])
        if key not in self.responses:
            raise MuseumError("unexpected synthetic genesis Registry request")
        return deepcopy(self.responses[key])

    def call(self, target, signature, outputs, values, inputs=(), arguments=()):
        self.put("eth_call", [{"to": target,
            "data": calldata(signature, inputs, arguments), "gas": "0x1312d00"}, self.block_ref],
            "0x" + encode(outputs, values).hex())

    def code(self, address, raw):
        self.runtimes[address] = raw
        self.put("eth_getCode", [address, self.block_ref], "0x" + raw.hex())

    def _install_graph(self):
        self.put("eth_chainId", [], "0x7a69")
        self.put("eth_getBlockByHash", [self.block["hash"], False], self.block)
        self.put("eth_getBlockByNumber", ["0x2a", False], self.block)
        for address, runtime in list(self.runtimes.items()):
            self.code(address, runtime)
        interface = "0x12345678"
        version, deployment, manifest = H("metadata version"), H("deployment"), H("manifest")
        pointer = (self.metadata, keccak256(self.runtimes[self.metadata]), False,
            source.COLLECTION_METADATA, interface, self.module_registry, 1,
            manifest, deployment, 1)
        self.pointer = pointer
        self.call(self.core, "getSatellitePointer(bytes32)", (source.POINTER,), (pointer,),
            ("bytes32",), (source.COLLECTION_METADATA,))
        record = (1, source.COLLECTION_METADATA, version, interface, 0,
            keccak256(self.runtimes[self.metadata]), deployment, manifest, "", 1, 1, 1)
        self.call(self.module_registry, "moduleRecord(address)", (source.MODULE_RECORD,),
            (record,), ("address",), (self.metadata,))
        self.call(self.module_registry, "isModuleEligible(address,bytes32,bytes4)", ("bool",),
            (True,), ("address", "bytes32", "bytes4"),
            (self.metadata, source.COLLECTION_METADATA, interface))
        for signature, output, value in (
                ("core()", "address", self.core),
                ("coreCodeHash()", "bytes32", keccak256(self.runtimes[self.core])),
                ("schemaRegistry()", "address", self.schemas),
                ("schemaRegistryCodeHash()", "bytes32", keccak256(self.runtimes[self.schemas])),
                ("chunkStore()", "address", self.store),
                ("chunkStoreCodeHash()", "bytes32", keccak256(self.runtimes[self.store])),
                ("governanceAuthority()", "address", self.governance),
                ("executorCodeHash()", "bytes32", keccak256(self.runtimes[self.governance]))):
            self.call(self.metadata, signature, (output,), (value,))
        for signature, output, value in (
                ("chunkStore()", "address", self.store),
                ("governanceAuthority()", "address", self.governance),
                ("governanceAuthorityCodeHash()", "bytes32", keccak256(self.runtimes[self.governance])),
                ("MAX_DOCUMENT_CHUNKS()", "uint256", 64),
                ("CHUNK_BYTES()", "uint256", 8192),
                ("MAX_DOCUMENT_BYTES()", "uint256", 524288),
                ("RAW_BYTES()", "bytes32", RAW_BYTES)):
            self.call(self.schemas, signature, (output,), (value,))
        self.call(self.store, "MAX_CHUNK_BYTES()", ("uint256",), (8192,))

    def _chunk(self, digest, raw):
        pointer = A(1000 + int(digest[2:10], 16) % 100000)
        prior = self.documents.get(("chunk", digest))
        if prior is not None:
            if prior != (pointer, raw):
                raise AssertionError("fixture hash collision")
            return pointer
        self.documents[("chunk", digest)] = (pointer, raw)
        self.call(self.store, "chunk(bytes32)", ("address", "uint32"),
            (pointer, len(raw)), ("bytes32",), (digest,))
        self.call(self.store, "readChunk(bytes32)", ("bytes",), (raw,),
            ("bytes32",), (digest,))
        self.code(pointer, b"\0" + raw)
        return pointer

    def install_document(self, index, *, content=None, status=0, exists=True,
                         kind=None, canonicalization_id=None, supersedes_id=None,
                         partial_absent=False, chunk_getter_mismatch=False,
                         aggregate=None):
        expected = self.plan.documents[index]
        identifier = schema_id(expected.name)
        if not exists:
            document = source.ZERO_DOCUMENT
            facts = list(source.ZERO_FACTS)
            if partial_absent:
                facts[0] = True
            self.call(self.schemas, "document(bytes32)", (DOCUMENT,), (document,),
                ("bytes32",), (identifier,))
            self.call(self.schemas, "documentFacts(bytes32)", (source.DOCUMENT_FACTS,),
                (tuple(facts),), ("bytes32",), (identifier,))
            self.documents[identifier] = {"index": index, "document": document, "content": None}
            return
        content = expected.content if content is None else content
        kind = expected.kind if kind is None else kind
        canonicalization_id = (expected.canonicalization_id if canonicalization_id is None
            else canonicalization_id)
        supersedes_id = expected.supersedes_id if supersedes_id is None else supersedes_id
        chunks = tuple(content[offset:offset + 8192] for offset in range(0, len(content), 8192))
        hashes = tuple(keccak256(chunk) for chunk in chunks)
        spec = (expected.name, KINDS[kind], keccak256(content), canonicalization_id,
            supersedes_id, expected.uri, len(content))
        declaration = keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, hashes)))
        document = (True, status, declaration, spec, hashes)
        facts = (True, KINDS[kind], status, spec[2], canonicalization_id,
            supersedes_id, len(content), len(hashes), declaration)
        self.call(self.schemas, "document(bytes32)", (DOCUMENT,), (document,),
            ("bytes32",), (identifier,))
        self.call(self.schemas, "documentFacts(bytes32)", (source.DOCUMENT_FACTS,), (facts,),
            ("bytes32",), (identifier,))
        for chunk_index, (digest, raw) in enumerate(zip(hashes, chunks)):
            self._chunk(digest, raw)
            returned = H("wrong ordered chunk") if chunk_getter_mismatch and chunk_index == 0 else digest
            self.call(self.schemas, "documentChunkHashAt(bytes32,uint256)", ("bytes32",),
                (returned,), ("bytes32", "uint256"), (identifier, chunk_index))
        if len(content) <= source.MAX_AGGREGATE_DOCUMENT_BYTES:
            self.call(self.schemas, "documentBytes(bytes32)", ("bytes",),
                (content if aggregate is None else aggregate,), ("bytes32",), (identifier,))
        self.documents[identifier] = {"index": index, "document": document, "content": content}

    def source(self, *, transport=None):
        return source.GenesisRegistrySource(self.anchor_raw,
            transport or self, plan_files=dict(self.plan.files),
            plan_hash=self.plan.manifest_hash, provenance="synthetic_fixture")

    def capture(self):
        reader = self.source()
        snapshot = reader.snapshot()
        return snapshot, reader.transcript()

    def replay_source(self, transcript):
        return self.source(transport=PublicReplayTransport(transcript, keccak256(transcript)))


class GenesisRegistrySourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = GenesisRegistryFixture()

    def test_complete_named_plan_and_exact_replay(self):
        f = GenesisRegistryFixture()
        raw, transcript = f.capture()
        value = loads(raw, maximum=source.MAX_OUTPUT, canonical=True)
        self.assertEqual(len(value["documents"]), 51)
        self.assertEqual(value["coverage"]["canonicalSchemaCount"], "29")
        self.assertEqual(value["coverage"]["supportDocumentCount"], "22")
        self.assertTrue(value["coverage"]["allPlanDocumentsPresentAndExact"])
        self.assertEqual(len(value["graph"]["runtimePins"]), 6 + len({
            digest for row in f.documents.values() if isinstance(row, dict) and row["content"] is not None
            for digest in row["document"][4]}))
        self.assertEqual(f.replay_source(transcript).snapshot(), raw)

    def test_absent_partial_and_conflicting_documents_stay_distinct(self):
        for mode in ("absent", "partial", "conflict"):
            f = GenesisRegistryFixture(); index = 20
            if mode == "absent": f.install_document(index, exists=False)
            elif mode == "partial": f.install_document(index, exists=False, partial_absent=True)
            else: f.install_document(index, content=b"same-name conflicting retained bytes")
            if mode == "partial":
                with self.subTest(mode=mode), self.assertRaisesRegex(MuseumError, "partial absent"):
                    f.source().snapshot()
            else:
                value = loads(f.source().snapshot(), maximum=source.MAX_OUTPUT, canonical=True)
                self.assertEqual(value["documents"][index]["outcome"], mode)
                self.assertFalse(value["documents"][index]["matchesPlan"])

    def test_statuses_raw_bootstrap_and_reference_kinds(self):
        for mode in ("deprecated", "archived", "raw-retired", "canonical-absent"):
            f = GenesisRegistryFixture()
            if mode in ("deprecated", "archived"):
                f.install_document(20, status=1 if mode == "deprecated" else 2)
                row = loads(f.source().snapshot(), maximum=source.MAX_OUTPUT)["documents"][20]
                self.assertEqual(row["outcome"], mode)
                self.assertFalse(row["currentEligible"])
                continue
            if mode == "raw-retired":
                raw_index = next(i for i, row in enumerate(f.plan.documents)
                    if schema_id(row.name) == RAW_BYTES)
                f.install_document(raw_index, status=1)
            elif mode == "canonical-absent":
                target = next(row for row in f.plan.documents if row.canonicalization_id == RAW_BYTES)
                raw_index = next(i for i, row in enumerate(f.plan.documents)
                    if schema_id(row.name) == RAW_BYTES)
                self.assertIsNotNone(target)
                f.install_document(raw_index, exists=False)
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                f.source().snapshot()

    def test_named_predecessor_kind_and_dependency_cycles_refuse(self):
        indices = [i for i, row in enumerate(self.fixture.plan.documents)
            if row.kind == "SCHEMA" and schema_id(row.name) != RAW_BYTES]
        self.assertGreaterEqual(len(indices), 2)
        first, second = indices[:2]
        first_id, second_id = (schema_id(self.fixture.plan.documents[i].name)
            for i in (first, second))
        for mode in ("wrong-kind", "self", "cycle"):
            f = GenesisRegistryFixture()
            if mode == "wrong-kind":
                f.install_document(first, supersedes_id=second_id)
                f.install_document(second, kind="DEPENDENCY")
            elif mode == "self":
                f.install_document(first, supersedes_id=first_id)
            else:
                f.install_document(first, supersedes_id=second_id)
                f.install_document(second, supersedes_id=first_id)
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                f.source().snapshot()

    def test_document_shape_refuses_before_chunk_reads(self):
        f = GenesisRegistryFixture(); index = 20
        expected = f.plan.documents[index]; identifier = schema_id(expected.name)
        digest = H("unread malformed chunk")
        spec = (expected.name, KINDS[expected.kind], digest, expected.canonicalization_id,
            expected.supersedes_id, expected.uri, 524289)
        hashes = (digest,)
        declaration = keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, hashes)))
        document = (True, 0, declaration, spec, hashes)
        facts = (True, KINDS[expected.kind], 0, digest, expected.canonicalization_id,
            expected.supersedes_id, 524289, 1, declaration)
        f.call(f.schemas, "document(bytes32)", (DOCUMENT,), (document,),
            ("bytes32",), (identifier,))
        f.call(f.schemas, "documentFacts(bytes32)", (source.DOCUMENT_FACTS,), (facts,),
            ("bytes32",), (identifier,))
        transport = Transport(f)
        with self.assertRaisesRegex(MuseumError, "size/chunk bound"):
            f.source(transport=transport).snapshot()
        target_data = calldata("documentChunkHashAt(bytes32,uint256)",
            ("bytes32", "uint256"), (identifier, 0))
        self.assertFalse(any(method == "eth_call" and params[0]["data"] == target_data
            and params[0]["to"] == f.schemas for method, params in transport.calls))

    def test_ordered_chunk_store_aggregate_and_transport_edge(self):
        for mode in ("chunk-getter", "carrier", "aggregate"):
            f = GenesisRegistryFixture(); index = 20
            if mode == "chunk-getter": f.install_document(index, chunk_getter_mismatch=True)
            elif mode == "aggregate": f.install_document(index, aggregate=b"different")
            else:
                row = f.documents[schema_id(f.plan.documents[index].name)]
                digest = row["document"][4][0]
                pointer, raw = f.documents[("chunk", digest)]
                f.code(pointer, b"\0different")
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                f.source().snapshot()
        f = GenesisRegistryFixture(); f.install_document(20, content=b"x" * 524288)
        value = loads(f.source().snapshot(), maximum=source.MAX_OUTPUT, canonical=True)
        row = value["documents"][20]
        self.assertEqual(row["aggregateGetter"], "omitted_transport_bound")
        self.assertEqual(len(hex_bytes(row["payloadHex"])), 524288)

    def test_pointer_authority_runtime_and_source_headers_are_exact(self):
        for mode in ("pointer-hash", "authority", "header"):
            f = GenesisRegistryFixture()
            if mode == "pointer-hash":
                pointer = list(f.pointer); pointer[1] = H("stale Metadata pin")
                f.call(f.core, "getSatellitePointer(bytes32)", (source.POINTER,), (tuple(pointer),),
                    ("bytes32",), (source.COLLECTION_METADATA,))
            elif mode == "authority":
                f.call(f.metadata, "executorCodeHash()", ("bytes32",), (H("wrong authority"),))
            else:
                changed = dict(f.block); changed["parentHash"] = H("different parent")
                f.put("eth_getBlockByNumber", ["0x2a", False], changed)
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                f.source().snapshot()

    def test_repeated_source_header_and_unconsumed_replay_refuse(self):
        f = GenesisRegistryFixture(); raw, transcript = f.capture()
        value = loads(transcript, maximum=67108864, canonical=True)
        value["calls"].append(deepcopy(value["calls"][-1]))
        changed = dumps(value)
        with self.assertRaisesRegex(MuseumError, "unconsumed"):
            f.replay_source(changed).snapshot()
        self.assertEqual(loads(raw, maximum=source.MAX_OUTPUT)["source"]["blockHash"], f.block["hash"])

if __name__ == "__main__":
    unittest.main()

"""Synthetic native-wire controls; no chain execution or actual producer acceptance.

The complete 39-segment fixture below is deliberately fabricated test input.
It exercises the full reader and original ABI/hash preimages, never native provenance.
"""
from copy import deepcopy
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id
from .chain_abi import Array, calldata, encode
from .chain_rpc import ReplayTransport
from . import object_inventory_source as native

ROOT = Path(__file__).resolve().parents[2]
ZERO = native.ZERO


def digest(label):
    return keccak256(label.encode())


def address(index):
    return "0x" + index.to_bytes(20, "big").hex()


def empty(kind):
    if isinstance(kind, tuple):
        return tuple(empty(k) for k in kind)
    if kind.startswith("uint"):
        return 0
    if kind == "address":
        return address(0)
    if kind == "bytes":
        return b""
    if kind == "string":
        return ""
    return ZERO


def structure(name, **changes):
    return tuple(changes.get(field, empty(native.abi_type(kind))) for kind, field in native.FIELDS[name])


def h(kinds, values):
    """ABI oracle independent of the reader's named hashing functions."""
    return keccak256(encode(kinds, values))


class SyntheticTransport:
    def __init__(self, responses):
        self.responses = responses

    def request(self, method, params):
        key = dumps([method, params])
        if key not in self.responses:
            raise MuseumError("unexpected synthetic RPC request")
        return deepcopy(self.responses[key])


class Fixture:
    """Fabricated complete native ABI graph plus receipts and parent-linked headers."""

    def __init__(self, *, waiver=False):
        self.producer, self.chain, self.cid = address(1), 31337, 1
        targets = tuple(address(i) for i in range(2, 14))
        artists = tuple(address(i) for i in range(14, 19)); content = address(19)
        runtimes = {a: b"\x60" + bytes([i]) for i, a in enumerate((self.producer, *targets, *artists, content), 1)}
        pins = {a: keccak256(code) for a, code in runtimes.items()}
        self.deps = structure("Dependencies", targets=targets, codeHashes=tuple(pins[a] for a in targets),
            artistTargets=artists, artistCodeHashes=tuple(pins[a] for a in artists), artistContentOwner=content,
            artistContentOwnerCodeHash=pins[content], chainId=self.chain, readGas=50000,
            sourceGas=12000000, selectionGas=1000000, snapshotGas=5000000, referenceGas=10000000)
        dependency_hash = h((native.DEPENDENCIES,), (self.deps,))
        subject = subject_id("collection", str(self.chain), targets[0], str(self.cid)); artist = digest("artist")
        snapshot = structure("SnapshotReceipt", recordHash=digest("snapshot-original"), collectionId=1,
            revision=1, manifestHash=digest("snapshot-json"), manifestBytes=100, recordedAt=900)
        reference = structure("ReferenceReceipt", recordHash=digest("reference-original"), collectionId=1,
            revision=1, snapshotRecordHash=snapshot[0], snapshotRevision=1, payloadHash=digest("reference-json"),
            payloadBytes=100, recordedAt=950)
        descriptions = structure("Descriptions", scopeSubject=subject, workDescriptionRecordHash=digest("work"),
            rightsStatementRecordHash=digest("rights"), workPayloadHash=digest("work-json"), rightsPayloadHash=digest("rights-json"),
            workSelectionHash=digest("work-selection"), rightsSelectionHash=digest("rights-selection"),
            workRevision=1, rightsRevision=1)
        record = structure("RecordEvidence", recordHash=digest("intent-waiver" if waiver else "intent"),
            kind=int(waiver), payloadHash=digest("intent-json"), recorder=artists[0], recordedAt=940)
        association = structure("Association", artistId=artist, bindingHash=digest("artist-binding"),
            generation=1, identityRecordHash=digest("original-identity"))
        selection = structure("Selection", record=record, association=association, origin=0,
            interviewStatus=1, revision=1, selectedAt=960, selectionHash=digest("conservation-selection"))
        self.context = structure("Context", collectionId=1, subject=subject, artistId=artist,
            snapshot=snapshot, referenceRender=reference, descriptions=descriptions, conservation=selection,
            interviewEvidenceHash=digest("interview-waiver"), nativeHash=digest("native-facts"),
            rootRecordHash=digest("root-original"), tokenInventoryHash=digest("token-inventory"),
            checkpointHash=digest("checkpoint"), tokenCount=1)
        context_hash = h((native.CONTEXT,), (self.context,))
        self.plan_id = h(("bytes32", "uint256", "address", "bytes32", native.CONTEXT),
            (digest("6529STREAM_RENDER_CRITICAL_INVENTORY_PLAN_V1"), self.chain, self.producer, dependency_hash, self.context))
        witnesses = (context_hash, reference[6], descriptions[5], descriptions[6], selection[12],
            self.context[7], self.context[9])
        self.items, self.segments = [], []
        aggregate, total = ZERO, 0
        for index in range(39):
            row = structure("Item", kind=0, role=digest("role-" + str(index)), source=targets[4],
                sourceRecord=snapshot[0], algorithm=1, canonicalizationId=schema_id("RAW_BYTES"),
                digest=hex_bytes(digest("identical-content")), uri="", byteSize=17)
            if index == 0:
                # Two occurrences of exactly the same bytes in separate roles are not collapsed.
                rows = (row, structure("Item", **dict(zip((f for _, f in native.FIELDS["Item"]), row)) | {"role": digest("other-role")}))
                witness = witnesses[index]
            elif index == 1:
                # Generic native segment encoding permits an authenticated empty applicability stage.
                # It is test-only, not claimed to originate from a real Reference publisher.
                rows, witness = (), witnesses[index]
            elif index < 7:
                rows, witness = (row,), witnesses[index]
            elif index < 38:
                document = schema_id(native.FIXED_DEFINITIONS[index - 7]) if index < 37 else digest("original-renderer-catalog")
                row = structure("Item", kind=3, role=digest("REGISTERED_INTERPRETATION_DOCUMENT"),
                    source=targets[2], sourceRecord=document, algorithm=1, canonicalizationId=schema_id("RAW_BYTES"),
                    digest=hex_bytes(digest("definition-bytes")), byteSize=40, catalogId=document,
                    catalogHash=digest("definition-bytes"), provenanceHash=digest("document-facts"))
                rows = (row,); witness = h(("bytes32", native.ITEM), (document, row))
            else:
                rows = tuple(structure("Item", kind=0, role=digest(role), source=targets[0 if i == 0 else 4],
                    sourceRecord=self.context[11], sourceIndex=71, algorithm=1,
                    canonicalizationId=schema_id("RAW_BYTES"), digest=hex_bytes(digest("token-bytes-" + str(i))),
                    byteSize=4) for i, role in enumerate(("TOKEN_DATA", "TOKEN_METADATA_JSON", "TOKEN_IMAGE", "TOKEN_ANIMATION_HTML")))
                witness = h(("bytes32", "uint64"), (self.context[11], 0))
            key = h(("bytes32", "bytes32", "uint64"), (digest("6529STREAM_RENDER_CRITICAL_SEGMENT_V1"), self.plan_id, index))
            first = ZERO
            for ordinal in reversed(range(len(rows))):
                item_hash = h(("bytes32", native.ITEM), (digest("6529STREAM_PRESERVATION_ITEM_V1"), rows[ordinal]))
                first = h(("bytes32", "bytes32", "uint64", "uint64", "bytes32", "bytes32"),
                    (digest("6529STREAM_PRESERVATION_ITEM_LINK_V1"), key, len(rows), ordinal, item_hash, first))
            segment = key, len(rows), first, witness
            aggregate = h(("bytes32", "bytes32", "uint64", native.SEGMENT),
                (digest("6529STREAM_PRESERVATION_SEGMENT_V1"), aggregate, index, segment))
            total += len(rows); self.items.append(rows); self.segments.append(segment)
        originals = (self.context[9], snapshot[0], reference[0], ZERO if waiver else record[0],
            record[0] if waiver else ZERO, self.context[7], descriptions[2], descriptions[1])
        evidence = structure("Evidence", planId=self.plan_id, collectionId=1, scopeSubject=subject, artistId=artist,
            originals=originals, sourceContextHash=context_hash, tokenInventoryHash=self.context[10], tokenCount=1,
            segmentCount=39, itemCount=total, segmentChainHash=aggregate)
        evidence_hash = h(("bytes32", "uint256", "address", "bytes32", native.EVIDENCE),
            (digest("6529STREAM_RENDER_CRITICAL_EVIDENCE_V1"), self.chain, self.producer, dependency_hash, evidence))
        self.evidence = evidence[:-1] + (evidence_hash,)
        self.plan = structure("Plan", collectionId=1, subject=subject, artistId=artist, sourceContextHash=context_hash,
            tokenCount=1, nextToken=1, segmentCount=39, itemCount=total, segmentChainHash=aggregate,
            completedStages=8, renderCriticalEvidenceHash=evidence_hash)
        self.txs = [digest("synthetic-tx-" + str(i)) for i in range(2)]
        self.blocks = {n: {"hash": digest("block-" + str(n)), "parentHash": digest("block-" + str(n - 1)),
            "number": hex(n), "timestamp": hex(n + 1000), "stateRoot": digest("state-" + str(n)),
            "transactions": [self.txs[n - 99]] if n < 101 else []} for n in (99, 100, 101)}
        self.anchor = {"profile": native.PROFILE, "chainId": str(self.chain), "blockHash": self.blocks[101]["hash"],
            "blockNumber": "101", "timestamp": "1101", "stateRoot": self.blocks[101]["stateRoot"],
            "collectionId": "1", "producer": self.producer, "dependencyHash": dependency_hash,
            "codePins": [{"address": a, "runtimeHash": pins[a]} for a in sorted(pins)], "segmentTransactions": sorted(self.txs)}
        self.receipts = {}
        for group, tx in enumerate(self.txs):
            number = 99 + group
            receipt = {"transactionHash": tx, "status": "0x1", "blockHash": self.blocks[number]["hash"],
                "blockNumber": hex(number), "transactionIndex": "0x0", "logs": []}
            for index in (range(20) if group == 0 else range(20, 39)):
                log = {k: receipt[k] for k in ("transactionHash", "blockHash", "blockNumber", "transactionIndex")}
                log.update(address=self.producer, removed=False, logIndex=hex(index if group == 0 else index - 20),
                    topics=[native.EVENT, self.plan_id, "0x" + index.to_bytes(32, "big").hex()],
                    data="0x" + encode((native.SEGMENT, Array(native.ITEM, native.MAX_SEGMENT_ITEMS)),
                        (self.segments[index], self.items[index])).hex())
                receipt["logs"].append(log)
            self.receipts[tx] = receipt
        self.responses = {}
        self.put("eth_chainId", [], hex(self.chain))
        block_ref = {"blockHash": self.anchor["blockHash"], "requireCanonical": True}
        for a, raw in runtimes.items():
            self.put("eth_getCode", [a, block_ref], "0x" + raw.hex())
        for tx, receipt in self.receipts.items():
            self.put("eth_getTransactionReceipt", [tx], receipt)
        for block in self.blocks.values():
            self.put("eth_getBlockByHash", [block["hash"], False], block)
        self.call("requireCurrent(uint256)", native.EVIDENCE, self.evidence, ("uint256",), (1,))
        self.call("inventoryEvidence(bytes32)", native.EVIDENCE, self.evidence, ("bytes32",), (self.plan_id,))
        self.call("dependencies()", native.DEPENDENCIES, self.deps)
        self.call("dependencyHash()", "bytes32", dependency_hash)
        self.call("sourceContext(bytes32)", native.CONTEXT, self.context, ("bytes32",), (self.plan_id,))
        self.call("plan(bytes32)", native.PLAN, self.plan, ("bytes32",), (self.plan_id,))
        for index, segment in enumerate(self.segments):
            self.call("inventorySegment(bytes32,uint64)", native.SEGMENT, segment,
                ("bytes32", "uint64"), (self.plan_id, index))

    def put(self, method, params, result):
        self.responses[dumps([method, params])] = result

    def call(self, signature, kind, value, inputs=(), values=()):
        self.put("eth_call", [{"to": self.producer, "data": calldata(signature, inputs, values), "gas": "0x1312d00"},
            {"blockHash": self.anchor["blockHash"], "requireCanonical": True}], "0x" + encode((kind,), (value,)).hex())

    def source(self, **kwargs):
        return native.NativeInventorySource(dumps(self.anchor), SyntheticTransport(self.responses), **kwargs)


class NativeInventoryTests(unittest.TestCase):
    def test_full_synthetic_adapter_and_exact_offline_replay(self):
        f = Fixture(); source = f.source(); raw = source.snapshot(); value = loads(raw, maximum=1048576, canonical=True)
        self.assertEqual(value["mode"], "synthetic_fixture")
        self.assertFalse(value["claims"]["actualChainAcceptance"])
        self.assertFalse(value["claims"]["itemByteAvailabilityVerified"])
        self.assertEqual(len(value["segments"]), 39)
        self.assertEqual(value["segments"][1]["items"], [])
        self.assertEqual(value["tokens"], [{"tokenId": "71", "collectionInventoryIndex": "0", "segmentIndex": "38"}])
        first = value["segments"][0]["items"]
        self.assertEqual(first[0]["digest"], first[1]["digest"])
        self.assertNotEqual(first[0]["role"], first[1]["role"])
        transcript = source.transcript()
        replay = native.NativeInventorySource(dumps(f.anchor), ReplayTransport(transcript, keccak256(transcript)))
        self.assertEqual(replay.snapshot(), raw)
        self.assertEqual(replay.transcript(), transcript)
        self.assertEqual(source.snapshot(), raw)

    def test_intent_waiver_selects_only_original_waiver(self):
        value = loads(Fixture(waiver=True).source().snapshot(), maximum=1048576, canonical=True)
        originals = value["evidence"]["originals"]
        self.assertEqual(originals["intentRecordHash"], ZERO)
        self.assertNotEqual(originals["intentWaiverRecordHash"], ZERO)

    def test_fake_native_provenance_and_bad_transcript_pin_rejected(self):
        f = Fixture()
        with self.assertRaisesRegex(MuseumError, "synthetic transport"):
            f.source(provenance="trusted_rpc")
        with self.assertRaisesRegex(MuseumError, "external commitment"):
            ReplayTransport(dumps({"version": 1, "calls": []}), ZERO)

    def test_replay_provenance_is_explicit_caller_admission_not_actual_acceptance(self):
        f = Fixture(); source = f.source(); source.snapshot(); transcript = source.transcript()
        for provenance, mode in (("synthetic_fixture", "synthetic_fixture"), ("trusted_rpc", "caller_admitted_rpc_inventory")):
            replay = native.NativeInventorySource(dumps(f.anchor), ReplayTransport(transcript, keccak256(transcript)), provenance=provenance)
            value = loads(replay.snapshot(), maximum=1048576, canonical=True)
            self.assertEqual(value["mode"], mode)
            self.assertTrue(value["provenanceDeclaredByCaller"])
            self.assertFalse(value["claims"]["actualChainAcceptance"])
            self.assertFalse(value["claims"]["consensusProof"])

    def test_same_block_transaction_log_ranges_must_be_ordered(self):
        for reversed_ranges in (False, True):
            f = Fixture(); f.blocks[99]["transactions"] = f.txs[:]; f.blocks[100]["transactions"] = []
            for group, tx in enumerate(f.txs):
                receipt = f.receipts[tx]
                receipt.update(blockHash=f.blocks[99]["hash"], blockNumber="0x63", transactionIndex=hex(group))
                for offset, log in enumerate(receipt["logs"]):
                    log.update({key: receipt[key] for key in ("blockHash", "blockNumber", "transactionIndex")})
                    start = (20 if group == 0 else 0) if reversed_ranges else (0 if group == 0 else 20)
                    log["logIndex"] = hex(start + offset)
            if reversed_ranges:
                with self.assertRaisesRegex(MuseumError, "cross-transaction log order"):
                    f.source().snapshot()
            else:
                self.assertTrue(f.source().snapshot())

    def test_historical_evidence_cannot_replace_require_current(self):
        f = Fixture(); bad = f.evidence[:-1] + (digest("other-evidence"),)
        f.call("inventoryEvidence(bytes32)", native.EVIDENCE, bad, ("bytes32",), (f.plan_id,))
        source = f.source()
        with self.assertRaisesRegex(MuseumError, "historical/current"):
            source.snapshot()
        with self.assertRaisesRegex(MuseumError, "cannot resume"):
            source.snapshot()

    def test_changed_items_and_omitted_event_do_not_satisfy_native_denominator(self):
        for change in ("item", "missing", "duplicate", "wrong-index"):
            with self.subTest(change=change):
                f = Fixture(); logs = f.receipts[f.txs[0]]["logs"]
                if change == "item":
                    item = list(f.items[0][0]); item[1] = digest("swapped-role")
                    logs[0]["data"] = "0x" + encode((native.SEGMENT, Array(native.ITEM, 1024)),
                        (f.segments[0], (tuple(item), f.items[0][1]))).hex()
                elif change == "missing":
                    del logs[3]
                elif change == "duplicate":
                    logs[3]["topics"][2] = logs[2]["topics"][2]
                else:
                    logs[3]["topics"][2] = "0x" + (1000).to_bytes(32, "big").hex()
                with self.assertRaises(MuseumError):
                    f.source().snapshot()

    def test_receipt_ancestry_membership_and_event_coordinates(self):
        for change in ("failed", "producer", "removed", "tx-index", "block-membership", "parent", "coordinate"):
            with self.subTest(change=change):
                f = Fixture(); receipt = f.receipts[f.txs[0]]; log = receipt["logs"][0]
                if change == "failed": receipt["status"] = "0x0"
                elif change == "producer": log["address"] = address(44)
                elif change == "removed": log["removed"] = True
                elif change == "tx-index": receipt["transactionIndex"] = "0x1"
                elif change == "block-membership": f.blocks[99]["transactions"] = [digest("unrelated-tx")]
                elif change == "parent": f.blocks[100]["parentHash"] = digest("wrong-parent")
                else: log["blockHash"] = digest("wrong-block")
                with self.assertRaises(MuseumError):
                    f.source().snapshot()

    def test_runtime_dependency_context_and_plan_tampering(self):
        for change in ("runtime", "dependency", "context", "plan", "count", "evidence-hash"):
            with self.subTest(change=change):
                f = Fixture()
                if change == "runtime": f.anchor["codePins"][0]["runtimeHash"] = digest("wrong-code")
                elif change == "dependency": f.call("dependencyHash()", "bytes32", digest("wrong-dependency"))
                elif change == "context":
                    c = list(f.context); c[10] = digest("wrong-inventory")
                    f.call("sourceContext(bytes32)", native.CONTEXT, tuple(c), ("bytes32",), (f.plan_id,))
                elif change == "plan":
                    p = list(f.plan); p[5] = 0
                    f.call("plan(bytes32)", native.PLAN, tuple(p), ("bytes32",), (f.plan_id,))
                else:
                    e = list(f.evidence); e[8 if change == "count" else 11] = 40000 if change == "count" else digest("self-not-zero")
                    f.call("requireCurrent(uint256)", native.EVIDENCE, tuple(e), ("uint256",), (1,))
                    f.call("inventoryEvidence(bytes32)", native.EVIDENCE, tuple(e), ("bytes32",), (f.plan_id,))
                with self.assertRaises(MuseumError):
                    f.source().snapshot()

    def test_unused_hint_and_replay_trailing_call_rejected(self):
        f = Fixture(); extra = digest("unused-hint")
        f.anchor["segmentTransactions"] = sorted(f.anchor["segmentTransactions"] + [extra])
        f.blocks[100]["transactions"].append(extra)
        f.put("eth_getTransactionReceipt", [extra], {"transactionHash": extra, "status": "0x1", "blockHash": f.blocks[100]["hash"],
            "blockNumber": "0x64", "transactionIndex": "0x1", "logs": []})
        with self.assertRaisesRegex(MuseumError, "unused transaction"):
            f.source().snapshot()
        f = Fixture(); source = f.source(); source.snapshot()
        transcript = loads(source.transcript(), maximum=67108864); transcript["calls"].append(transcript["calls"][-1])
        raw = dumps(transcript)
        with self.assertRaisesRegex(MuseumError, "unconsumed"):
            native.NativeInventorySource(dumps(f.anchor), ReplayTransport(raw, keccak256(raw))).snapshot()

    def test_empty_segment_needs_nonzero_original_witness(self):
        f = Fixture(); self.assertEqual(native.reconstruct_segment(f.segments[1][0], f.segments[1][3], ()), f.segments[1])
        with self.assertRaisesRegex(MuseumError, "witness"):
            native.reconstruct_segment(f.segments[1][0], ZERO, ())
        with self.assertRaisesRegex(MuseumError, "empty/link"):
            native.append_segment(ZERO, 0, (f.segments[1][0], 0, digest("nonzero-link"), f.segments[1][3]))

    def test_item_dynamic_abi_preimage_matches_independent_word_construction(self):
        item = Fixture().items[0][0]
        word = lambda n: n.to_bytes(32, "big")
        tail = lambda b: word(len(b)) + b + bytes(-len(b) % 32)
        digest_tail, uri_tail = tail(item[7]), tail(item[8].encode())
        heads = []
        for index, value in enumerate(item):
            if index == 7: heads.append(word(17 * 32))
            elif index == 8: heads.append(word(17 * 32 + len(digest_tail)))
            elif isinstance(value, int): heads.append(word(value))
            elif index == 2: heads.append(bytes(12) + hex_bytes(value, 20))
            else: heads.append(hex_bytes(value, 32))
        raw = hex_bytes(digest("6529STREAM_PRESERVATION_ITEM_V1"), 32) + word(64) + b"".join(heads) + digest_tail + uri_tail
        self.assertEqual(native.item_hash(item), keccak256(raw))

    def test_offline_replay_output_pins_default_provenance_and_definition_check(self):
        f = Fixture(); source = f.source(); expected = source.snapshot(); transcript = source.transcript()
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary); anchor_path = directory / "anchor.json"; transcript_path = directory / "transcript.json"
            anchor_raw = dumps(f.anchor); anchor_path.write_bytes(anchor_raw); transcript_path.write_bytes(transcript)
            with patch("socket.socket", side_effect=AssertionError("offline replay contacted network")):
                pins = native.replay(anchor_path, keccak256(anchor_raw), transcript_path, keccak256(transcript), directory / "result")
            self.assertEqual(pins["provenance"], "synthetic_fixture")
            self.assertFalse(pins["actualChainAcceptance"])
            self.assertEqual((directory / "result/snapshot.json").read_bytes(), expected)
            self.assertEqual((directory / "result/anchor.json").read_bytes(), anchor_raw)
            self.assertEqual((directory / "result/transcript.json").read_bytes(), transcript)
            with self.assertRaises(FileExistsError):
                native.replay(anchor_path, keccak256(anchor_raw), transcript_path, keccak256(transcript), directory / "result")
            with self.assertRaisesRegex(MuseumError, "anchor pin"):
                native.replay(anchor_path, ZERO, transcript_path, keccak256(transcript), directory / "bad")
            native.definitions(directory / "definitions")
            self.assertEqual(native.definitions(directory / "definitions", check=True), native.PROFILE_HASH)
            (directory / "definitions/native-inventory-profile.json").write_bytes(b"{}")
            with self.assertRaisesRegex(MuseumError, "profile differs"):
                native.definitions(directory / "definitions", check=True)


class SourceABIParityTests(unittest.TestCase):
    def test_struct_layouts_match_exact_checked_in_native_declarations(self):
        files = {
            "StreamPreservationInventoryTypes": "interfaces/stream/preservation/StreamPreservationInventoryTypes.sol",
            "StreamRenderCriticalSourceTypes": "interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol",
            "StreamSnapshotTypes": "interfaces/stream/metadata/StreamSnapshotTypes.sol",
            "StreamReferenceRenderTypes": "interfaces/stream/preservation/StreamReferenceRenderTypes.sol",
            "Description": "interfaces/stream/finality/StreamFinalityDescriptionTypes.sol",
            "Conservation": "interfaces/stream/metadata/IStreamConservationRecordSelection.sol",
            "Publication": "interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol",
        }
        mapping = {name: ("StreamPreservationInventoryTypes", name) for name in ("Item", "Segment", "Plan", "OriginalInputs", "Evidence")}
        mapping.update(Dependencies=("StreamRenderCriticalSourceTypes", "Dependencies"), Context=("StreamRenderCriticalSourceTypes", "Context"),
            SnapshotReceipt=("StreamSnapshotTypes", "Receipt"), ReferenceReceipt=("StreamReferenceRenderTypes", "Receipt"),
            Descriptions=("Description", "StreamFinalityDescriptionEvidence"), PublicationEvidence=("Publication", "Evidence"))
        mapping.update({name: ("Conservation", name) for name in ("RecordEvidence", "Association", "Selection")})
        aliases = {"Kind": "uint8", "RecordKind": "uint8", "StreamConservationRecordTypes.StatementOrigin": "uint8",
            "StreamConservationRecordTypes.InterviewStatus": "uint8", "PayloadCorrespondence": "uint8",
            "StreamSnapshotTypes.Receipt": "SnapshotReceipt", "StreamReferenceRenderTypes.Receipt": "ReferenceReceipt",
            "StreamFinalityDescriptionEvidence": "Descriptions", "IStreamConservationRecordSelection.Selection": "Selection",
            "StreamArtistRecordPublicationTypes.Evidence": "PublicationEvidence"}
        for name, (file, struct) in mapping.items():
            with self.subTest(struct=name):
                source = (ROOT / "smart-contracts" / files[file]).read_text(encoding="utf-8")
                source = re.sub(r"//[^\n]*|/\*.*?\*/", "", source, flags=re.S)
                body = re.search(r"\bstruct " + struct + r"\s*\{([^}]+)\}", source)[1]
                fields = [tuple(row.strip().split()) for row in body.split(";") if row.strip()]
                self.assertEqual(tuple((aliases.get(kind, kind), field) for kind, field in fields), native.FIELDS[name])

    def test_chain_domains_and_stage_layout_match_native_source(self):
        self.assertEqual((ROOT / "schemas/museum/object-dossier/native-inventory-profile.json").read_bytes(),
                         native.PROFILE_BYTES)
        directory = ROOT / "smart-contracts/domains/preservation"
        producer = (directory / "StreamRenderCriticalInventory.sol").read_text(encoding="utf-8")
        chains = (directory / "StreamPreservationInventoryChains.sol").read_text(encoding="utf-8")
        definitions = (directory / "StreamPreservationDocumentReads.sol").read_text(encoding="utf-8")
        for domain in ("6529STREAM_RENDER_CRITICAL_INVENTORY_PLAN_V1", "6529STREAM_RENDER_CRITICAL_SEGMENT_V1", "6529STREAM_RENDER_CRITICAL_EVIDENCE_V1"):
            self.assertIn(domain, producer)
        for domain in ("6529STREAM_PRESERVATION_ITEM_V1", "6529STREAM_PRESERVATION_ITEM_LINK_V1", "6529STREAM_PRESERVATION_SEGMENT_V1"):
            self.assertIn(domain, chains)
        self.assertRegex(definitions, r"FIXED_COUNT\s*=\s*30;")
        declared_names = re.search(r"string\[30\] memory names = \[(.*?)\];", definitions, re.S)[1]
        self.assertEqual(tuple(re.findall(r'"([A-Z0-9_]+)"', declared_names)), native.FIXED_DEFINITIONS)
        self.assertIn("_stage(id, 8)", producer)
        self.assertEqual(native.EVENT, digest("InventorySegmentRecorded(bytes32,uint64,(bytes32,uint64,bytes32,bytes32),(uint8,bytes32,address,bytes32,uint256,uint16,bytes32,bytes,string,uint64,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)[])"))


if __name__ == "__main__":
    unittest.main()

"""Synthetic exact-wire controls; no executed selection or legal permission claim."""
import copy
import unittest
from unittest.mock import patch

from tools.metadata import rights_profile
from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id
from .chain_abi import calldata, decode, encode
from .chain_rpc import ReplayTransport
from .independent_wire import RECORD, RAW_BYTES, ZERO, ZERO_ADDRESS, generic_hash
from .metadata_rights_source import (SCHEMA_NAME, SCHEMA_BYTES, SCHEMA_HASH, PROFILE_NAME,
    PROFILE_BYTES as RIGHTS_BYTES, PROFILE_HASH as RIGHTS_HASH, JCS_ID, RECORD_TYPE, RECEIPT, POINTER)
from .current_rights_source import (CurrentRightsSource, PROFILE, PROFILE_HASH, SELECTION, EMPTY_SELECTION,
    PROVIDER_CONFIG, DOCUMENT_FACTS, PRESENTATION, SUITE, RIGHTS_INTERFACE, METADATA_RECORDED, SELECTED_EVENT, selection_hash)
from .test_preservation_resources import RightsFixture, A, H


class CurrentRightsFixture(RightsFixture):
    def __init__(self, *, collection=True, token=False, burned=False, locked=False):
        super().__init__(status="unspecified")
        self.a.pop("records")
        self.a.update(profile=PROFILE, tokenId="41", collectionId="1", router=A(5), originalFinality=A(6),
            provider=A(7), rightsSelector=A(8), blockHash=H(205), blockNumber="5", stateRoot=H(305))
        for n in range(5, 9): self.codes[A(n)] = bytes([96, n, 0])
        self.a["codePins"] = [{"address": a, "runtimeHash": keccak256(self.codes[a])} for a in map(A, range(1, 9))]
        self.pins = {row["address"]: row["runtimeHash"] for row in self.a["codePins"]}
        self.blocks, self.receipts, self.requested = {}, {}, []
        for n in range(6):
            self.blocks[H(200+n)] = {"hash": H(200+n), "number": hex(n), "timestamp": hex(1780000000+n-1 if n < 5 else 1790000000),
                "stateRoot": H(300+n), "parentHash": H(199+n) if n else ZERO, "transactions": [H(400+n)]}
            self.receipts[H(400+n)] = {"transactionHash": H(400+n), "blockHash": H(200+n), "blockNumber": hex(n),
                "transactionIndex": "0x0", "status": "0x1", "logs": []}
        self.add(A(2), "tokenCollectionIdentity(uint256)", ("uint256",), (41,), ("bool", "uint256", "uint256", "bool"), (True, 1, 3, burned))
        self.add(A(2), "tokenLifecycle(uint256)", ("uint256",), (41,), ("uint8",), (3 if burned else 2,))
        for address, interfaces in ((A(2), ("0x80ac58cd",)), (A(8), (RIGHTS_INTERFACE,))):
            for interface in ("0x01ffc9a7",) + interfaces:
                self.add(address, "supportsInterface(bytes4)", ("bytes4",), (interface,), ("bool",), (True,))
            self.add(address, "supportsInterface(bytes4)", ("bytes4",), ("0xffffffff",), ("bool",), (False,))
        pointer = ("0x" + "00" * 12 + A(5)[2:], self.pins[A(5)], ZERO, schema_id("METADATA_ROUTER"), ZERO, ZERO, H(1), ZERO, ZERO, ZERO)
        self.add(A(2), "getSatellitePointer(bytes32)", ("bytes32",), (schema_id("METADATA_ROUTER"),), (POINTER,), (pointer,))
        self.add(A(5), "core()", (), (), ("address",), (A(2),))
        self.add(A(5), "servingOriginalFinalityAnchor()", (), (), ("address", "bytes32"), (A(6), self.pins[A(6)]))
        presentation = (locked, A(50), H(501), H(502), 1, H(503), A(51), H(504), H(505), 1780000000, 1780000000, H(506))
        self.add(A(5), "artistPresentation(uint256)", ("uint256",), (1,), (PRESENTATION,), (presentation,))
        self.add(A(5), "originalFinalityAnchor(uint256)", ("uint256",), (1,), ("address", "bytes32"),
            (A(6), self.pins[A(6)]) if locked else (ZERO_ADDRESS, ZERO))
        for signature, target in (("coreReads()", A(2)), ("metadataReads()", A(1)), ("scopeEvidenceProvider()", A(7))):
            self.add(A(6), signature, (), (), ("address",), (target,))
        self.add(A(6), "scopeEvidenceProviderCodeHash()", (), (), ("bytes32",), (self.pins[A(7)],))
        targets, hashes = [A(1000+n) for n in range(22)], [H(2000+n) for n in range(22)]
        for index, address in ((0, A(2)), (1, A(1)), (2, A(5)), (4, A(3)), (5, A(4)), (12, A(6)), (16, A(8))):
            targets[index], hashes[index] = address, self.pins[address]
        self.config = (tuple(targets), tuple(hashes), 31337, 500000, 16000000, 4000000, H(3000))
        self.add(A(7), "nativeConfiguration()", (), (), (PROVIDER_CONFIG,), (self.config,))
        for signature, address in (("core()", A(2)), ("metadataHost()", A(1)), ("metadataRouter()", A(5))):
            self.add(A(7), signature, (), (), ("address",), (address,))
            self.add(A(7), signature[:-2] + "CodeHash()", (), (), ("bytes32",), (self.pins[address],))
        self.add(A(7), "deploymentChainId()", (), (), ("uint256",), (31337,))
        for name, address in (("core", A(2)), ("metadata", A(1)), ("schemaRegistry", A(3)), ("chunkStore", A(4))):
            self.add(A(8), name + "()", (), (), ("address",), (address,))
            self.add(A(8), name + "CodeHash()", (), (), ("bytes32",), (self.pins[address],))
        self.add(A(8), "deploymentChainId()", (), (), ("uint256",), (31337,))
        for name, kind, raw in ((SCHEMA_NAME, 0, SCHEMA_BYTES), (PROFILE_NAME, 2, RIGHTS_BYTES), ("RFC8785_JCS", 1, JCS_BYTES)):
            key = schema_id(name); hashes = [self.chunk(raw[i:i+8192]) for i in range(0, len(raw), 8192)]
            facts = (True, kind, 0, keccak256(raw), RAW_BYTES, ZERO, len(raw), len(hashes), H(3333))
            self.add(A(3), "documentFacts(bytes32)", ("bytes32",), (key,), (DOCUMENT_FACTS,), (facts,))
            for i, digest in enumerate(hashes): self.add(A(3), "documentChunkHashAt(bytes32,uint256)", ("bytes32", "uint256"), (key, i), ("bytes32",), (digest,))
        self.selections = {kind: [] for kind in ("collection", "token")}
        self.rows, self.chain = [], ZERO
        self.update_heads()
        if collection: self.append("collection", "granted", block=1)
        if token: self.append("token", "unspecified", block=2)

    def subject(self, kind): return subject_id(kind, "31337", A(2), "1", token_id="41" if kind == "token" else "0")

    def event(self, block, address, topics, kinds, values):
        receipt = self.receipts[H(400+block)]
        log = {key: receipt[key] for key in ("transactionHash", "blockHash", "blockNumber", "transactionIndex")}
        log.update(address=address, topics=topics, data="0x" + encode(kinds, values).hex(),
            logIndex=hex(len(receipt["logs"])), removed=False)
        receipt["logs"].append(log)
        return log

    def artist_graph(self, *, artist=H(777), registration=H(778)):
        facade, coordinator, identity = A(50), A(51), A(52)
        for address, code in ((facade, b"artist facade"), (coordinator, b"artist coordinator"), (identity, b"artist Identity owner")):
            self.codes[address] = code
            self.pins[address] = keccak256(code)
            self.a["codePins"].append({"address": address, "runtimeHash": self.pins[address]})
        targets, hashes = list(self.config[0]), list(self.config[1])
        targets[11], hashes[11] = facade, self.pins[facade]
        self.config = (tuple(targets), tuple(hashes)) + self.config[2:]
        self.add(A(7), "nativeConfiguration()", (), (), (PROVIDER_CONFIG,), (self.config,))
        self.add(A(1), "artistRegistry()", (), (), ("address",), (facade,))
        self.add(A(1), "artistRegistryCodeHash()", (), (), ("bytes32",), (self.pins[facade],))
        self.add(facade, "core()", (), (), ("address",), (A(2),))
        self.add(facade, "operationCoordinator()", (), (), ("address",), (coordinator,))
        self.add(coordinator, "deploymentChainId()", (), (), ("uint256",), (31337,))
        suite = (facade, A(60), (A(61), A(62), identity, A(63), A(64), A(65), A(66)),
            A(2), A(67), A(68), A(1), A(69), A(70), H(71), A(72))
        self.add(coordinator, "suiteConfiguration()", (), (), (SUITE,), (suite,))
        for signature, target in (("core()", A(2)), ("artistRegistry()", facade), ("operationCoordinator()", coordinator)):
            self.add(identity, signature, (), (), ("address",), (target,))
        self.add(identity, "deploymentChainId()", (), (), ("uint256",), (31337,))
        self.add(identity, "authorityState(bytes32)", ("bytes32",), (artist,),
            ("address", "uint8", "uint8", "bytes32"), (A(73), 4, 3, registration))
        return artist, registration

    def append(self, kind, status, *, block=3, edit=None, select=True, cls=7, artist_identity_hash=ZERO):
        subject = self.subject(kind); previous = self.selections[kind][-1] if self.selections[kind] else EMPTY_SELECTION
        value = rights_profile.examples()[0]
        value.update(subjectId=subject, profileHash=RIGHTS_HASH, predecessor=None if previous[0] == ZERO else previous[0])
        value["licensor"]["identity"] = {"kind": "address", "address": A(9)}
        for use in rights_profile.USES: value["grants"][use]["status"] = status
        if edit: edit(value)
        raw = dumps(value); payload = self.chunk(raw)
        stamp = int(self.blocks[H(200+block)]["timestamp"], 16)
        record = (RECORD_TYPE, subject, (1, hex_bytes(payload), JCS_ID), "ipfs://rights-statement", schema_id(SCHEMA_NAME), ZERO, (0, b"", ZERO), stamp)
        digest = generic_hash(31337, A(1), A(2), 1, A(9), record)
        index = len(self.rows); self.chain = record_chain("31337", A(1), "1", RECORD_TYPE, self.chain, digest, str(index))
        receipt = (1, A(9), cls, stamp, index, self.chain, SCHEMA_HASH, keccak256(JCS_BYTES), ZERO)
        self.add(A(1), "collectionRecord(bytes32)", ("bytes32",), (digest,), (RECORD, RECEIPT), (record, receipt))
        self.add(A(1), "recordHashAt(uint256,bytes32,uint256)", ("uint256", "bytes32", "uint256"), (1, RECORD_TYPE, index), ("bytes32",), (digest,))
        publication = self.event(block, A(1), [METADATA_RECORDED, H(1), RECORD_TYPE, subject],
            (RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16"), (record, digest, self.chain, A(9), H(cls), 1))
        original = {"record": record, "receipt": receipt, "payload": raw, "recordHash": digest, "publication": publication}
        self.rows.append(original)
        if select:
            row = (digest, previous[0], payload, A(10), 1, 3, len(self.selections[kind])+1, index, stamp, 8, A(9), cls, artist_identity_hash, ZERO)
            row = row[:-1] + (selection_hash(self.a, subject, row),)
            self.selections[kind].append(row)
            original["selectionEvent"] = self.event(block, A(8), [SELECTED_EVENT, H(1), subject, digest], (SELECTION,), (row,))
            self.update_heads()
        return original

    def update_heads(self):
        for kind, rows in self.selections.items():
            subject = self.subject(kind); head = rows[-1] if rows else EMPTY_SELECTION
            self.add(A(8), "currentRights(uint256,bytes32)", ("uint256", "bytes32"), (1, subject), (SELECTION,), (head,))
            for i, row in enumerate(rows):
                self.add(A(8), "rightsSelectionAt(uint256,bytes32,uint64)", ("uint256", "bytes32", "uint64"), (1, subject, i+1), (SELECTION,), (row,))
            if rows: self.add(A(8), "requireCurrent(uint256,bytes32,bytes32,uint64)", ("uint256", "bytes32", "bytes32", "uint64"), (1, subject, head[0], head[6]), (SELECTION,), (head,))

    def request(self, method, params):
        self.requested.append((method, params))
        if method == "eth_getBlockByHash": return copy.deepcopy(self.blocks[params[0]])
        if method == "eth_getTransactionReceipt": return copy.deepcopy(self.receipts[params[0]])
        if method in ("eth_call", "eth_getCode"):
            assert params[1] == {"blockHash": self.a["blockHash"], "requireCanonical": True}
        return super().request(method, params)

    def source(self): return CurrentRightsSource(dumps(self.a), self)
    def result(self): return loads(self.source().snapshot(), maximum=8*1024*1024)


class CurrentRightsSourceTests(unittest.TestCase):
    def test_collection_and_token_complete_history_original_blocks_and_offline_replay(self):
        f = CurrentRightsFixture(token=True)
        f.append("collection", "denied", block=3)
        source = f.source(); raw = source.snapshot(); result = loads(raw, maximum=8*1024*1024)
        self.assertEqual(result["profileHash"], PROFILE_HASH)
        self.assertEqual(len(result["scopes"]["collection"]["history"]), 2)
        self.assertEqual(len(result["scopes"]["token"]["history"]), 1)
        self.assertEqual({r["publication"]["recordedBlock"] for r in result["records"]}, {"1", "2", "3"})
        self.assertEqual(result["completeness"], "unspecified")
        self.assertEqual(set(result["effectiveGrants"].values()), {"unspecified"})
        self.assertFalse(result["claims"]["legalRightsProven"])
        self.assertEqual(result["dateAssessment"], "not_assessed_no_inferred_timezone")
        self.assertEqual(source.snapshot(), raw)
        transcript = source.transcript()
        with patch("socket.socket", side_effect=AssertionError("no network")):
            replay = CurrentRightsSource(source.anchor_bytes, ReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), raw)

    def test_absent_selection_is_not_absent_publications_and_partial_precedence(self):
        f = CurrentRightsFixture(collection=False)
        f.append("collection", "granted", select=False, block=1)
        result = f.result()
        self.assertEqual(result["completeness"], "absent")
        self.assertEqual(result["records"], [])
        self.assertEqual(result["scopes"]["collection"]["status"], "absent")
        f = CurrentRightsFixture()
        f.append("token", "unspecified", block=2, edit=lambda v: v["grants"]["print"].update(status="denied"))
        result = f.result()
        self.assertEqual(result["completeness"], "partially_specified")
        self.assertEqual(result["effectiveGrants"]["print"], "denied")
        self.assertEqual(result["effectiveGrants"]["exhibition"], "unspecified")

    def test_locked_original_binding_burn_and_dates_do_not_erase_selected_evidence(self):
        f = CurrentRightsFixture(locked=True, burned=True)
        f.append("token", "denied", block=2, edit=lambda v: v.update(effectiveDates={"start": "9999-01-01", "end": None}))
        result = f.result()
        self.assertTrue(result["identity"]["burned"])
        self.assertEqual(result["effectiveGrants"]["print"], "denied")
        self.assertEqual(result["records"][-1]["value"]["effectiveDates"]["start"], "9999-01-01")

    def test_arbitrary_provider_selector_saved_anchor_and_runtime_reject(self):
        edits = [lambda f: f.add(A(6), "scopeEvidenceProvider()", (), (), ("address",), (A(99),)),
            lambda f: f.add(A(6), "scopeEvidenceProviderCodeHash()", (), (), ("bytes32",), (H(99),)),
            lambda f: f.add(A(5), "originalFinalityAnchor(uint256)", ("uint256",), (1,), ("address", "bytes32"), (A(6), f.pins[A(6)])),
            lambda f: f.codes.__setitem__(A(8), b"changed")]
        for edit in edits:
            f = CurrentRightsFixture(collection=False); edit(f)
            with self.subTest(edit=edit), self.assertRaises(MuseumError): f.source().snapshot()
        f = CurrentRightsFixture(collection=False); c = list(f.config); t = list(c[0]); t[16] = A(99); c[0] = tuple(t)
        f.add(A(7), "nativeConfiguration()", (), (), (PROVIDER_CONFIG,), (tuple(c),))
        with self.assertRaisesRegex(MuseumError, "selector configuration"): f.source().snapshot()

    def test_empty_or_truncated_heads_cannot_hide_selection_events(self):
        for truncate in (False, True):
            f = CurrentRightsFixture()
            if truncate: f.append("collection", "denied", block=2); f.selections["collection"].pop()
            else: f.selections["collection"] = []
            f.update_heads()
            with self.subTest(truncate=truncate), self.assertRaisesRegex(MuseumError, "selected event/history"): f.source().snapshot()

    def test_head_bound_partial_zero_hash_and_original_payload_negative(self):
        f = CurrentRightsFixture(collection=False)
        bad = list(EMPTY_SELECTION); bad[6] = 1
        f.add(A(8), "currentRights(uint256,bytes32)", ("uint256", "bytes32"), (1, f.subject("collection")), (SELECTION,), (tuple(bad),))
        with self.assertRaisesRegex(MuseumError, "partial empty"): f.source().snapshot()
        for field, value in ((6, 65), (13, H(99))):
            f = CurrentRightsFixture(); row = list(f.selections["collection"][0]); row[field] = value
            f.selections["collection"][0] = tuple(row); f.update_heads()
            with self.subTest(field=field), self.assertRaises(MuseumError): f.source().snapshot()
        f = CurrentRightsFixture(); content = keccak256(f.rows[0]["payload"])
        pointer, _ = decode(("address", "uint32"), hex_bytes(f.responses[(A(4), calldata("chunk(bytes32)", ("bytes32",), (content,)))]))
        f.codes[pointer] += b"x"
        with self.assertRaisesRegex(MuseumError, "SSTORE2"): f.source().snapshot()

    def test_missing_publication_selection_event_or_wrong_publication_time_reject(self):
        for edit in ("publication", "selection", "timestamp"):
            f = CurrentRightsFixture()
            if edit == "timestamp": f.blocks[H(201)]["timestamp"] = hex(1780000001)
            else:
                f.receipts[H(401)]["logs"].pop(0 if edit == "publication" else 1)
                for i, row in enumerate(f.receipts[H(401)]["logs"]): row["logIndex"] = hex(i)
            with self.subTest(edit=edit), self.assertRaises(MuseumError): f.source().snapshot()

    def test_selection_event_before_publication_and_rehashed_wrong_lineage_reject(self):
        f = CurrentRightsFixture(); logs = f.receipts[H(401)]["logs"]; logs.reverse()
        for i, row in enumerate(logs): row["logIndex"] = hex(i)
        with self.assertRaisesRegex(MuseumError, "precedes publication"): f.source().snapshot()
        f = CurrentRightsFixture(); f.append("collection", "denied", block=2)
        row = list(f.selections["collection"][1]); row[1] = H(999); row = tuple(row)
        row = row[:-1] + (selection_hash(f.a, f.subject("collection"), row),)
        f.selections["collection"][1] = row; f.update_heads()
        with self.assertRaisesRegex(MuseumError, "lineage"): f.source().snapshot()

    def test_retired_or_wrong_definition_and_noncanonical_payload_reject(self):
        f = CurrentRightsFixture(); key = (A(3), calldata("documentFacts(bytes32)", ("bytes32",), (schema_id(SCHEMA_NAME),)))
        facts, = decode((DOCUMENT_FACTS,), hex_bytes(f.responses[key])); facts = facts[:2] + (1,) + facts[3:]
        f.responses[key] = "0x" + encode((DOCUMENT_FACTS,), (facts,)).hex()
        with self.assertRaisesRegex(MuseumError, "active definition"): f.source().snapshot()
        f = CurrentRightsFixture(collection=False)
        f.append("collection", "granted_with_conditions", block=1)
        with self.assertRaisesRegex(MuseumError, "interpretation"): f.source().snapshot()

    def test_repeated_runtime_answer_collision_and_final_header_reject(self):
        f = CurrentRightsFixture(); original = f.request
        payload = f.rows[0]["payload"]; digest = keccak256(payload)
        f.add(A(4), "chunk(bytes32)", ("bytes32",), (digest,), ("address", "uint32"), (A(8), len(payload)))
        seen = 0
        def collision(method, params):
            nonlocal seen
            if method == "eth_getCode" and params[0] == A(8):
                seen += 1
                if seen == 2:
                    f.requested.append((method, params)); return "0x" + (b"\0" + payload).hex()
            return original(method, params)
        f.request = collision
        with self.assertRaisesRegex(MuseumError, "repeated RPC result"): f.source().snapshot()
        f = CurrentRightsFixture(); original = f.request
        def changed(method, params):
            result = original(method, params)
            if method == "eth_getBlockByHash" and params[0] == f.a["blockHash"] and any(m == "eth_call" for m, _ in f.requested): result["transactions"] = []
            return result
        f.request = changed
        with self.assertRaisesRegex(MuseumError, "final source header"): f.source().snapshot()

    def test_abi_provenance_and_original_profile_bytes_unchanged(self):
        f = CurrentRightsFixture(); subject = f.subject("collection")
        key = (A(8), calldata("currentRights(uint256,bytes32)", ("uint256", "bytes32"), (1, subject)))
        f.responses[key] += "00" * 32
        with self.assertRaisesRegex(MuseumError, "ABI"): f.source().snapshot()
        with self.assertRaisesRegex(MuseumError, "provenance"): CurrentRightsSource(dumps(f.a), f, provenance="trusted_rpc")
        self.assertEqual(RIGHTS_BYTES, dumps(rights_profile.profile()))
        self.assertEqual(SCHEMA_BYTES, dumps(rights_profile.schema()))

    def test_artist_licensor_known_registration_is_separate_from_current_authority(self):
        f = CurrentRightsFixture(collection=False)
        artist, registration = f.artist_graph()
        f.append("collection", "granted", block=1, artist_identity_hash=registration,
            edit=lambda v: v["licensor"].update(identity={"kind": "artist", "artistId": artist}))
        result = f.result()
        identity = result["artistLicensorIdentities"][0]
        self.assertEqual(identity["identityRecordHash"], registration)
        self.assertEqual(identity["authorityState"], [A(73), "4", "3", registration])
        self.assertEqual(result["scopes"]["collection"]["current"][10], A(9))
        self.assertNotEqual(identity["authorityState"][0], A(9))
        self.assertFalse(result["claims"]["currentGrantReauthorization"])
        self.assertFalse(result["claims"]["legalRightsProven"])

    def test_rehashed_artist_identity_mismatch_and_unknown_registration_reject(self):
        for missing in (False, True):
            f = CurrentRightsFixture(collection=False)
            artist, registration = f.artist_graph(registration=ZERO if missing else H(778))
            f.append("collection", "granted", block=1, artist_identity_hash=H(779),
                edit=lambda v: v["licensor"].update(identity={"kind": "artist", "artistId": artist}))
            expected = "unknown licensor registration" if missing else "licensor registration differs"
            with self.subTest(missing=missing), self.assertRaisesRegex(MuseumError, expected): f.source().snapshot()

    def test_artist_identity_owner_must_match_native_suite_and_core(self):
        f = CurrentRightsFixture(collection=False)
        artist, registration = f.artist_graph()
        f.append("collection", "granted", block=1, artist_identity_hash=registration,
            edit=lambda v: v["licensor"].update(identity={"kind": "artist", "artistId": artist}))
        f.add(A(52), "core()", (), (), ("address",), (A(99),))
        with self.assertRaisesRegex(MuseumError, "Identity owner binding"): f.source().snapshot()


if __name__ == "__main__": unittest.main()

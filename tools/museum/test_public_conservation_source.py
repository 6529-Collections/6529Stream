"""Synthetic native-wire controls for the public conservation source.

These fixtures exercise a pinned local-EVM shaped transcript.  They are not
evidence of a deployed selector, publisher authentication, or chain consensus.
"""
from copy import deepcopy
import unittest
from unittest.mock import patch

from tools.metadata import conservation_profile

from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id
from .chain_abi import calldata, decode, encode
from .current_rights_source import DOCUMENT_FACTS, POINTER, PROVIDER_CONFIG
from .independent_wire import RAW_BYTES, ZERO
from . import public_conservation_source as conservation
from . import artist_attestation_source as artist
from .metadata_catalog_source import ARTIST, POLICY, RECEIPT
from .public_history_rpc import PublicReplayTransport
from .test_current_rights_source import CurrentRightsFixture, A, H


class PublicConservationFixture(CurrentRightsFixture):
    """Concrete RPC transcript builder; every accepted answer is replayable."""

    def __init__(self, *, empty=False):
        super().__init__(collection=False, token=False, locked=True)
        self.a.pop("rightsSelector")
        self.a.update(profile=conservation.PROFILE, conservationSelector=A(8), artistRegistry=A(9))
        self.codes[A(9)] = b"\x60\x09\x00"
        self.pins[A(9)] = keccak256(self.codes[A(9)])
        self.a["codePins"].append({"address": A(9), "runtimeHash": self.pins[A(9)]})

        targets, hashes = list(self.config[0]), list(self.config[1])
        targets[11], hashes[11] = A(9), self.pins[A(9)]
        targets[17], hashes[17] = A(8), self.pins[A(8)]
        self.config = (tuple(targets), tuple(hashes), *self.config[2:])
        self.add(A(7), "nativeConfiguration()", (), (), (PROVIDER_CONFIG,), (self.config,))

        pointer = ("0x" + "00" * 12 + A(9)[2:], self.pins[A(9)], ZERO,
            schema_id("ARTIST_REGISTRY"), ZERO, ZERO, H(1), ZERO, ZERO, ZERO)
        self.add(A(2), "getSatellitePointer(bytes32)", ("bytes32",),
            (schema_id("ARTIST_REGISTRY"),), (POINTER,), (pointer,))
        self.add(A(1), "artistRegistry()", (), (), ("address",), (A(9),))
        self.add(A(1), "artistRegistryCodeHash()", (), (), ("bytes32",), (self.pins[A(9)],))
        self.add(A(8), "supportsInterface(bytes4)", ("bytes4",),
            (conservation.CONSERVATION_INTERFACE,), ("bool",), (True,))

        self.coordinator = A(10)
        owners = (A(11), A(12), A(13), A(14), A(15), A(16), A(17))
        for address in (self.coordinator, *owners):
            self.codes[address] = b"\x60" + bytes([int(address[-2:], 16)]) + b"\x00"
            self.pins[address] = keccak256(self.codes[address])
            self.a["codePins"].append({"address": address, "runtimeHash": self.pins[address]})
        self.suite = (A(9), A(18), owners, A(2), A(19), A(20), A(1), A(21), A(22),
            keccak256(b"primary revenue class"), A(23))
        self.add(A(9), "operationCoordinator()", (), (), ("address",), (self.coordinator,))
        self.add(self.coordinator, "suiteConfiguration()", (), (), (artist.SUITE,), (self.suite,))
        self.add(self.coordinator, "deploymentChainId()", (), (), ("uint256",), (31337,))
        for target in (A(9), owners[2], owners[0], owners[4]):
            self.add(target, "core()", (), (), ("address",), (A(2),))
            self.add(target, "operationCoordinator()", (), (), ("address",), (self.coordinator,))
        for target in (owners[2], owners[0], owners[4]):
            self.add(target, "artistRegistry()", (), (), ("address",), (A(9),))
            self.add(target, "deploymentChainId()", (), (), ("uint256",), (31337,))

        self.artist_id = keccak256(b"synthetic conservation artist")
        self.identity_hash = keccak256(b"synthetic historical identity document")
        self.binding_hash = keccak256(b"synthetic accepted binding")
        self.association = (self.artist_id, self.binding_hash, 1, self.identity_hash)
        self.binding = (self.artist_id, A(24), self.identity_hash, self.binding_hash,
            1, 1, 0, 0, A(25), True)
        self.add(owners[0], "binding(uint256)", ("uint256",), (1,), (artist.BINDING,), (self.binding,))
        self.add(owners[4], "attributionState(uint256)", ("uint256",), (1,),
            ("uint8", "uint64"), (2, 1))
        self.add(owners[2], "authorityState(bytes32)", ("bytes32",), (self.artist_id,),
            ("address", "uint8", "uint8", "bytes32"), (A(24), 1, 1, self.identity_hash))

        # All definitions are exact original bytes and declarations.  The
        # consumer must retain inactive documents but may not call them current.
        kinds = {name: (1 if name == "RFC8785_JCS" else 0 if name in conservation_profile.FAMILIES else 2)
            for name in conservation.DEFINITIONS}
        for name, raw in conservation.DEFINITIONS.items():
            key = schema_id(name)
            chunks = [self.chunk(raw[i:i + 8192]) for i in range(0, len(raw), 8192)]
            facts = (True, kinds[name], 0, keccak256(raw), RAW_BYTES, ZERO,
                len(raw), len(chunks), keccak256(("conservation-definition-" + name).encode()))
            self.add(A(3), "documentFacts(bytes32)", ("bytes32",), (key,),
                (DOCUMENT_FACTS,), (facts,))
            for index, digest in enumerate(chunks):
                self.add(A(3), "documentChunkHashAt(bytes32,uint256)",
                    ("bytes32", "uint256"), (key, index), ("bytes32",), (digest,))

        self.selections = {(kind, origin): [] for kind in ("collection", "token") for origin in (0, 1)}
        self.selection_catalogs = {}
        self.originals = []
        if not empty:
            self.append_intent("collection", origin=0, block=1)
        self.update_heads()
        for kind in ("collection", "token"):
            self.add(A(8), "intentLock(uint256,bytes32)", ("uint256", "bytes32"),
                (1, self.subject(kind)), (conservation.LOCK,), (conservation.EMPTY_LOCK,))

    def _add_original(self, value, kind, scope, origin, block, *, schema_override=None):
        subject = self.subject(scope)
        raw = dumps(value)
        payload_hash = keccak256(raw)
        self.chunk(raw)
        stamp = int(self.blocks[H(block + 200)]["timestamp"], 16)
        family, record_type = conservation.FAMILIES[kind], conservation.RECORD_TYPES[kind]
        record = (record_type, subject, (1, hex_bytes(payload_hash), conservation.JCS_ID),
            "ipfs://synthetic-conservation-original", schema_override or schema_id(family), ZERO,
            (0, b"", ZERO), stamp)
        signer = A(24) if origin == 0 else A(26)
        digest = conservation.generic_hash(31337, A(1), A(2), 1, signer, record)
        same_lane = [row for row in self.originals if row["record"][0] == record_type]
        index = len(same_lane)
        previous_chain = same_lane[-1]["receipt"][5] if same_lane else ZERO
        chain = record_chain("31337", A(1), "1", record_type, previous_chain, digest, str(index))
        authorization = keccak256(("synthetic op24 " + digest).encode())
        receipt = (1, signer, 1, stamp, index, chain,
            keccak256(conservation.DEFINITIONS[family]), keccak256(JCS_BYTES), authorization)
        self.add(A(1), "recordPolicy(bytes32)", ("bytes32",), (record_type,),
            (POLICY,), ((ARTIST, 2, True),))
        self.add(A(1), "collectionRecord(bytes32)", ("bytes32",), (digest,),
            (conservation.RECORD, RECEIPT), (record, receipt))
        self.add(A(1), "recordHashAt(uint256,bytes32,uint256)",
            ("uint256", "bytes32", "uint256"), (1, record_type, index), ("bytes32",), (digest,))
        self.add(A(1), "consumedArtistAuthorization(bytes32)", ("bytes32",),
            (authorization,), ("bool",), (True,))

        publication = (A(1), signer, 1, subject, record_type, record[4], conservation.JCS_ID,
            1, payload_hash, keccak256(record[3].encode()), record[7], digest)
        evidence = (authorization, self.artist_id, self.binding_hash, 1, signer,
            1 if origin == 0 else 3, 1 if kind == 2 else 64, stamp,
            keccak256(encode((artist.PUBLICATION,), (publication,))))
        saved = (publication, evidence, self.pins[A(1)])
        self.add(self.suite[2][4], "publicationAttestation(bytes32)", ("bytes32",),
            (authorization,), (artist.PUBLICATION_RECORD,), (saved,))
        statement = encode(("uint16", artist.PUBLICATION), (1, publication))
        attestation = (authorization, ZERO if kind == 2 else digest, artist.PUBLICATION_SCHEMA,
            keccak256(statement), 1, stamp, signer)
        self.add(self.suite[2][4], "attestationRecord(bytes32)", ("bytes32",),
            (authorization,), (artist.ATTESTATION_RECORD,), (attestation,))
        self.add(self.suite[2][4], "statementBytes(bytes32)", ("bytes32",),
            (attestation[3],), ("bytes",), (statement,))
        self.add(self.suite[2][2], "signatureBundle(bytes32)", ("bytes32",),
            (authorization,), ("bytes",), (b"synthetic original signature bytes",))
        self.add(self.suite[2][0], "bindingAt(uint256,uint64)", ("uint256", "uint64"),
            (1, 1), (artist.BINDING,), (self.binding,))

        native = (digest, kind, payload_hash, signer, stamp, index, chain,
            keccak256(encode((RECEIPT,), (receipt,))), evidence,
            keccak256(encode((artist.PUBLICATION_RECORD,), (saved,))))
        original = {"recordHash": digest, "record": record, "receipt": receipt, "payload": raw,
            "native": native, "scope": scope, "origin": origin}
        self.originals.append(original)
        self.event(block, A(1), [artist.METADATA_RECORDED, H(1), record_type, subject],
            (conservation.RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16"),
            (record, digest, chain, signer, H(1), 1))
        self.event(block, A(1), [artist.CONSUMED, authorization, digest,
            "0x" + encode(("address",), (signer,)).hex()], ("address",), (A(28),))
        if kind == 2:
            self.add(A(8), "preparedInterview(bytes32)", ("bytes32",), (digest,),
                (conservation.PREPARED,), (conservation.EMPTY_PREPARED,))
        return original

    def append_interview(self, scope="collection", *, origin=0, block=1, catalog=False):
        examples = conservation_profile.examples()
        value = deepcopy(examples["interview-derivative-av.json" if catalog else "interview-vmq.json"])
        value.update(subjectId=self.subject(scope),
            profileHash=keccak256(conservation.DEFINITIONS[conservation_profile.PROFILES[conservation_profile.INTERVIEW]]),
            predecessor=None)
        original = self._add_original(value, 2, scope, origin, block)
        original["catalogPins"] = []
        if catalog:
            name = "CONSERVATION_EXAMPLE_FORMATS_V1"; raw = dumps(examples["format-catalog.json"])
            key = schema_id(name); chunks = [self.chunk(raw[i:i + 8192]) for i in range(0, len(raw), 8192)]
            facts = (True, 2, 0, keccak256(raw), conservation.JCS_ID, ZERO,
                len(raw), len(chunks), keccak256(b"synthetic catalog registration"))
            self.add(A(3), "documentFacts(bytes32)", ("bytes32",), (key,), (DOCUMENT_FACTS,), (facts,))
            for index, digest in enumerate(chunks):
                self.add(A(3), "documentChunkHashAt(bytes32,uint256)",
                    ("bytes32", "uint256"), (key, index), ("bytes32",), (digest,))
            # Both audio and video occurrences select the same catalog document.
            original["catalogPins"] = [(key, keccak256(raw), len(raw)), (key, keccak256(raw), len(raw))]
        return original

    def prepare_interview(self, original, *, block=2):
        row = (1, self.subject(original["scope"]), self.association, original["native"], [], ZERO)
        row = row[:-1] + (conservation.preparation_hash(self.a, row),)
        self.add(A(8), "preparedInterview(bytes32)", ("bytes32",), (original["recordHash"],),
            (conservation.PREPARED,), (row,))
        self.event(block, A(8), [conservation.PREPARED_EVENT, original["recordHash"],
            "0x" + encode(("address",), (A(29),)).hex(), row[-1]], (), ())
        return row

    def lock_artist(self, scope="collection", *, block=3):
        head = self.selections[(scope, 0)][-1]
        stamp = int(self.blocks[H(block + 200)]["timestamp"], 16)
        row = (True, A(24), self.artist_id, self.identity_hash, self.binding_hash,
            1, head[0][0], head[9], stamp)
        self.add(A(8), "intentLock(uint256,bytes32)", ("uint256", "bytes32"),
            (1, self.subject(scope)), (conservation.LOCK,), (row,))
        self.event(block, A(8), [conservation.LOCKED_EVENT, H(1), self.subject(scope)],
            (conservation.LOCK,), (row,))
        return row

    def append_intent(self, scope="collection", *, origin=0, block=1, predecessor=None,
                      interview=None, schema_override=None, locator_record_hash=None, edit=None):
        subject = self.subject(scope)
        value = deepcopy(conservation_profile.examples()["intent-estate-waived.json"])
        value.update(subjectId=subject,
            profileHash=keccak256(conservation.DEFINITIONS[conservation_profile.PROFILES[conservation_profile.INTENT]]))
        value["artist"] = {"artistId": self.artist_id, "bindingGeneration": "1",
            "bindingHash": self.binding_hash,
            "statementOrigin": "artist_intent" if origin == 0 else "estate_statement"}
        prior = self.selections[(scope, origin)][-1] if self.selections[(scope, origin)] else conservation.EMPTY_SELECTION
        chosen_predecessor = prior[0][0] if predecessor is None and prior[0][0] != ZERO else predecessor
        value["predecessor"] = chosen_predecessor
        reference_hash, correspondence, interview_native = ZERO, 0, conservation.EMPTY_RECORD
        if interview is not None:
            digest = keccak256(interview["payload"])
            reference = {"hash": {"algorithm": 1, "canonicalizationId": conservation.JCS_ID,
                "digest": digest}, "uri": "ipfs://synthetic-original-interview"}
            value["interview"] = {"kind": "present", "payload": reference, "record": {
                "chainId": "31337", "core": A(2), "host": A(1),
                "recordHash": locator_record_hash or interview["recordHash"],
                "schemaId": schema_id(conservation_profile.INTERVIEW),
                "profileHash": keccak256(conservation.DEFINITIONS[conservation_profile.PROFILES[conservation_profile.INTERVIEW]])}}
            h = reference["hash"]
            reference_wire = (h["algorithm"], h["canonicalizationId"], hex_bytes(h["digest"]), reference["uri"])
            reference_hash, correspondence, interview_native = keccak256(encode((conservation.REFERENCE,), (reference_wire,))), 1, interview["native"]
        if edit is not None: edit(value)
        original = self._add_original(value, 0, scope, origin, block, schema_override=schema_override)
        native = original["native"]
        pins = [] if interview is None else interview.get("catalogPins", [])
        catalogs_hash = keccak256(encode((conservation.Array(conservation.CATALOG_PIN, conservation.MAX_CATALOGS),), (pins,)))
        row = (native, self.association, origin, 1, conservation.EMPTY_RECORD, ZERO, 0,
            prior[0][0], A(27), len(self.selections[(scope, origin)]) + 1,
            original["receipt"][3], catalogs_hash, ZERO)
        if interview is not None:
            row = (native, self.association, origin, 0, interview_native, reference_hash, correspondence,
                prior[0][0], A(27), len(self.selections[(scope, origin)]) + 1,
                original["receipt"][3], catalogs_hash, ZERO)
        row = row[:-1] + (conservation.selection_hash(self.a, subject, row),)
        self.selections[(scope, origin)].append(row)
        self.selection_catalogs[(scope, origin, row[9])] = pins
        original["selection"] = row
        self.event(block, A(8), [conservation.SELECTED_EVENT, H(1), subject, original["recordHash"]],
            (conservation.SELECTION,), (row,))
        return original

    def append_waiver(self, scope="collection", *, origin=0, block=2):
        subject = self.subject(scope); prior = self.selections[(scope, origin)][-1]
        value = deepcopy(conservation_profile.examples()["intent-waiver.json"])
        value.update(subjectId=subject,
            profileHash=keccak256(conservation.DEFINITIONS[conservation_profile.PROFILES[conservation_profile.WAIVER]]),
            predecessor=prior[0][0])
        value["artist"] = {"artistId": self.artist_id, "bindingGeneration": "1",
            "bindingHash": self.binding_hash,
            "statementOrigin": "artist_intent" if origin == 0 else "estate_statement"}
        original = self._add_original(value, 1, scope, origin, block); native = original["native"]
        catalogs_hash = keccak256(encode((conservation.Array(conservation.CATALOG_PIN, conservation.MAX_CATALOGS),), ([],)))
        row = (native, self.association, origin, 1, conservation.EMPTY_RECORD, ZERO, 0,
            prior[0][0], A(27), len(self.selections[(scope, origin)]) + 1,
            original["receipt"][3], catalogs_hash, ZERO)
        row = row[:-1] + (conservation.selection_hash(self.a, subject, row),)
        self.selections[(scope, origin)].append(row)
        self.selection_catalogs[(scope, origin, row[9])] = []
        original["selection"] = row
        self.event(block, A(8), [conservation.SELECTED_EVENT, H(1), subject, original["recordHash"]],
            (conservation.SELECTION,), (row,))
        return original

    def update_heads(self):
        if self.selections and all(type(key) is str for key in self.selections):
            return CurrentRightsFixture.update_heads(self)
        for (scope, origin), rows in self.selections.items():
            subject = self.subject(scope)
            head = rows[-1] if rows else conservation.EMPTY_SELECTION
            self.add(A(8), "currentConservation(uint256,bytes32,uint8)",
                ("uint256", "bytes32", "uint8"), (1, subject, origin), (conservation.SELECTION,), (head,))
            for revision, row in enumerate(rows, 1):
                pins = self.selection_catalogs.get((scope, origin, revision), [])
                self.add(A(8), "conservationSelectionAt(uint256,bytes32,uint8,uint64)",
                    ("uint256", "bytes32", "uint8", "uint64"), (1, subject, origin, revision),
                    (conservation.SELECTION,), (row,))
                self.add(A(8), "selectionCatalogCount(uint256,bytes32,uint8,uint64)",
                    ("uint256", "bytes32", "uint8", "uint64"), (1, subject, origin, revision),
                    ("uint256",), (len(pins),))
                for index, pin in enumerate(pins):
                    self.add(A(8), "selectionCatalogAt(uint256,bytes32,uint8,uint64,uint256)",
                        ("uint256", "bytes32", "uint8", "uint64", "uint256"),
                        (1, subject, origin, revision, index), (conservation.CATALOG_PIN,), (pin,))
            if rows:
                self.add(A(8), "requireCurrent(uint256,bytes32,uint8,bytes32,uint64)",
                    ("uint256", "bytes32", "uint8", "bytes32", "uint64"),
                    (1, subject, origin, head[0][0], head[9]), (conservation.SELECTION,), (head,))

    def subject(self, kind):
        return subject_id(kind, "31337", A(2), "1", token_id="41" if kind == "token" else "0")

    def source(self):
        return conservation.PublicConservationSource(dumps(self.a), self)

    def result(self):
        return loads(self.source().snapshot(), maximum=conservation.MAX_OUTPUT, canonical=True)

    @staticmethod
    def matches(log, query):
        if log["address"] != query["address"]: return False
        if not int(query["fromBlock"], 16) <= int(log["blockNumber"], 16) <= int(query["toBlock"], 16): return False
        for index, term in enumerate(query["topics"]):
            if term is None: continue
            if index >= len(log["topics"]) or log["topics"][index] not in (term if type(term) is list else [term]): return False
        return True

    def request(self, method, params):
        if method == "eth_getLogs":
            self.requested.append((method, deepcopy(params)))
            query, = params
            rows = [deepcopy(log) for receipt in self.receipts.values() for log in receipt["logs"]
                if self.matches(log, query)]
            return sorted(rows, key=lambda row: tuple(int(row[key], 16)
                for key in ("blockNumber", "transactionIndex", "logIndex")))
        if method == "eth_getBlockByNumber":
            self.requested.append((method, deepcopy(params)))
            assert params[1] is False
            matches = [value for value in self.blocks.values() if value["number"] == params[0]]
            assert len(matches) == 1, params
            return deepcopy(matches[0])
        return super().request(method, params)


class PublicConservationSourceTests(unittest.TestCase):
    def test_profile_and_anchor_binding_fixture(self):
        f = PublicConservationFixture()
        self.assertEqual(f.a["profile"], conservation.PROFILE)
        self.assertEqual(f.config[0][11], f.a["artistRegistry"])
        self.assertEqual(f.config[0][17], f.a["conservationSelector"])
        self.assertEqual(set(conservation.DEFINITIONS), set(conservation_profile.documents()) | {"RFC8785_JCS"})
        self.assertEqual(conservation.DEFINITIONS["RFC8785_JCS"], JCS_BYTES)

    def test_selected_artist_intent_exact_original_and_offline_replay(self):
        f = PublicConservationFixture(); source = f.source()
        with patch("socket.socket", side_effect=AssertionError("synthetic source used network")):
            raw = source.snapshot()
        result = loads(raw, maximum=conservation.MAX_OUTPUT, canonical=True)
        artist_lane = result["scopes"]["collection"]["origins"]["artist"]
        self.assertEqual((artist_lane["status"], len(artist_lane["history"]), len(artist_lane["events"])),
            ("selected", 1, 1))
        self.assertTrue(artist_lane["currentEligibility"]["eligible"])
        self.assertEqual(result["records"][0]["value"]["interview"]["kind"], "interview_waived")
        self.assertEqual(result["records"][0]["signatureVerification"],
            "retained_native_original_bytes_without_revalidation")
        self.assertFalse(result["claims"]["signatureRevalidation"])
        transcript = source.transcript()
        with patch("socket.socket", side_effect=AssertionError("replay used network")):
            replay = conservation.PublicConservationSource(source.anchor_bytes,
                PublicReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), raw)

    def test_present_parent_interview_zero_and_explicit_preparation(self):
        for prepared in (False, True):
            f = PublicConservationFixture(empty=True)
            interview = f.append_interview(block=1)
            if prepared: f.prepare_interview(interview, block=2)
            f.append_intent(block=3, interview=interview); f.update_heads()
            result = f.result()
            parent = next(row for row in result["records"] if row["recordHash"] != interview["recordHash"])
            self.assertEqual(parent["value"]["interview"]["kind"], "present")
            selected = result["scopes"]["collection"]["origins"]["artist"]["history"][0]
            self.assertEqual(selected[4][0], interview["recordHash"])
            self.assertEqual(result["preparations"][0]["status"], "prepared" if prepared else "not_prepared")
            self.assertEqual(result["preparations"][0]["adoptionUsedPreparationProven"] if prepared else False, False)

    def test_estate_parent_may_reference_artist_interview_and_duplicate_catalog_occurrences(self):
        f = PublicConservationFixture(empty=True)
        interview = f.append_interview(origin=0, block=1, catalog=True)
        parent = f.append_intent(origin=1, block=2, interview=interview); f.update_heads()
        result = f.result(); lane = result["scopes"]["collection"]["origins"]["estate"]
        pins = lane["catalogs"][0]
        self.assertEqual(len(pins), 2)
        self.assertEqual(pins[0], pins[1])
        self.assertEqual(lane["history"][0][4][8][5], "1")
        self.assertEqual(lane["history"][0][0][8][5], "3")
        self.assertEqual(lane["current"][0][0], parent["recordHash"])

        f = PublicConservationFixture(empty=True)
        interview = f.append_interview(block=1, catalog=True)
        f.append_intent(block=2, interview=interview); f.update_heads()
        pin = interview["catalogPins"][0]
        key = (A(4), calldata("chunk(bytes32)", ("bytes32",), (pin[1],)))
        pointer, _ = decode(("address", "uint32"), hex_bytes(f.responses[key]))
        f.codes[pointer] = f.codes[pointer][:-1] + bytes([f.codes[pointer][-1] ^ 1])
        with self.assertRaisesRegex(MuseumError, "SSTORE2|definition"):
            f.source().snapshot()

        f = PublicConservationFixture(empty=True)
        interview = f.append_interview(block=1, catalog=True)
        f.append_intent(block=2, interview=interview); f.update_heads()
        f.add(A(8), "selectionCatalogCount(uint256,bytes32,uint8,uint64)",
            ("uint256", "bytes32", "uint8", "uint64"), (1, f.subject("collection"), 0, 1),
            ("uint256",), (1,))
        with self.assertRaisesRegex(MuseumError, "catalog occurrence count"):
            f.source().snapshot()

        f = PublicConservationFixture(empty=True); interview = f.append_interview(block=1)
        f.append_intent(block=2, interview=interview, locator_record_hash=keccak256(b"foreign interview")); f.update_heads()
        with self.assertRaisesRegex(MuseumError, "parent interview locator"):
            f.source().snapshot()

    def test_unsupported_newest_selected_schema_does_not_fall_back_to_valid_older_head(self):
        f = PublicConservationFixture()
        bad = f.append_intent(block=2, schema_override=keccak256(b"unsupported future intent schema"))
        f.update_heads()
        self.assertEqual(f.selections[("collection", 0)][0][0][0], f.originals[0]["recordHash"])
        self.assertEqual(f.selections[("collection", 0)][-1][0][0], bad["recordHash"])
        with self.assertRaisesRegex(MuseumError, "receipt/family/definitions"):
            f.source().snapshot()

        f = PublicConservationFixture()
        malformed = f.append_intent(block=2, edit=lambda value: value.pop("display")); f.update_heads()
        self.assertEqual(f.selections[("collection", 0)][-1][0][0], malformed["recordHash"])
        with self.assertRaisesRegex(MuseumError, "malformed conservation source evidence"):
            f.source().snapshot()

    def test_complete_artist_estate_revisions_and_original_lock_order(self):
        f = PublicConservationFixture()
        waiver = f.append_waiver("collection", origin=0, block=2)
        second = f.append_intent("collection", origin=0, block=3)
        estate = f.append_intent("collection", origin=1, block=3)
        token_artist = f.append_intent("token", origin=0, block=2)
        token_estate = f.append_intent("token", origin=1, block=3)
        locked = f.lock_artist(block=4); f.update_heads()
        result = f.result(); scope = result["scopes"]["collection"]
        artist_history = scope["origins"]["artist"]["history"]
        self.assertEqual([row[0][0] for row in artist_history],
            [f.originals[0]["recordHash"], waiver["recordHash"], second["recordHash"]])
        self.assertEqual([row[0][1] for row in artist_history], ["0", "1", "0"])
        self.assertEqual([row[0][5] for row in artist_history], ["0", "0", "1"])
        self.assertEqual([row[7] for row in artist_history], [ZERO, f.originals[0]["recordHash"], waiver["recordHash"]])
        self.assertEqual([row[0][0] for row in scope["origins"]["estate"]["history"]], [estate["recordHash"]])
        self.assertEqual(scope["lock"], conservation.json_values(locked))
        self.assertIsNotNone(scope["lockEvent"])
        self.assertEqual(result["scopes"]["token"]["origins"]["artist"]["current"][0][0], token_artist["recordHash"])
        self.assertEqual(result["scopes"]["token"]["origins"]["estate"]["current"][0][0], token_estate["recordHash"])
        self.assertEqual({row["nativeEvidence"][8][5] for row in result["records"]}, {"1", "3"})

    def test_history_or_event_omission_and_order_fail_closed(self):
        f = PublicConservationFixture(); f.append_intent(block=2); f.update_heads()
        key = (A(8), calldata("conservationSelectionAt(uint256,bytes32,uint8,uint64)",
            ("uint256", "bytes32", "uint8", "uint64"), (1, f.subject("collection"), 0, 1)))
        f.responses[key] = f.responses[(A(8), calldata("conservationSelectionAt(uint256,bytes32,uint8,uint64)",
            ("uint256", "bytes32", "uint8", "uint64"), (1, f.subject("collection"), 0, 2)))]
        with self.assertRaisesRegex(MuseumError, "predecessor/time"):
            f.source().snapshot()

        f = PublicConservationFixture()
        f.receipts[H(401)]["logs"].pop()
        with self.assertRaisesRegex(MuseumError, "selected event missing"):
            f.source().snapshot()

        f = PublicConservationFixture(); logs = f.receipts[H(401)]["logs"]
        logs[1], logs[2] = logs[2], logs[1]
        for index, row in enumerate(logs): row["logIndex"] = hex(index)
        with self.assertRaisesRegex(MuseumError, "selection precedes original publication"):
            f.source().snapshot()

    def test_inactive_definition_or_changed_association_retains_history_without_current_claim(self):
        f = PublicConservationFixture()
        definition = schema_id(conservation_profile.INTENT)
        key = (A(3), calldata("documentFacts(bytes32)", ("bytes32",), (definition,)))
        facts, = decode((DOCUMENT_FACTS,), hex_bytes(f.responses[key])); facts = facts[:2] + (1,) + facts[3:]
        f.responses[key] = "0x" + encode((DOCUMENT_FACTS,), (facts,)).hex()
        result = f.result(); eligibility = result["scopes"]["collection"]["origins"]["artist"]["currentEligibility"]
        self.assertEqual(eligibility, {"checked": False, "eligible": False, "reasons": ["fixed_definition_inactive"]})
        self.assertEqual(len(result["records"]), 1)

        f = PublicConservationFixture()
        f.add(f.suite[2][4], "attributionState(uint256)", ("uint256",), (1,), ("uint8", "uint64"), (4, 1))
        result = f.result(); eligibility = result["scopes"]["collection"]["origins"]["artist"]["currentEligibility"]
        self.assertIn("current_association_differs", eligibility["reasons"])
        self.assertEqual(len(result["records"]), 1)

    def test_rehashed_original_selection_preparation_and_native_pin_tamper_reject(self):
        f = PublicConservationFixture(); original = f.originals[0]
        key = (A(1), calldata("collectionRecord(bytes32)", ("bytes32",), (original["recordHash"],)))
        record, receipt = decode((conservation.RECORD, RECEIPT), hex_bytes(f.responses[key]))
        receipt = receipt[:6] + (ZERO,) + receipt[7:]
        f.responses[key] = "0x" + encode((conservation.RECORD, RECEIPT), (record, receipt)).hex()
        with self.assertRaisesRegex(MuseumError, "receipt/family"):
            f.source().snapshot()

        f = PublicConservationFixture(); row = list(f.selections[("collection", 0)][0]); row[8] = A(30)
        row = tuple(row[:-1]) + (conservation.selection_hash(f.a, f.subject("collection"), tuple(row)),)
        f.selections[("collection", 0)][0] = row; f.update_heads()
        with self.assertRaisesRegex(MuseumError, "selected event/history"):
            f.source().snapshot()

        f = PublicConservationFixture(empty=True); interview = f.append_interview(block=1)
        prepared = list(f.prepare_interview(interview, block=2)); prepared[-1] = keccak256(b"wrong preparation")
        f.add(A(8), "preparedInterview(bytes32)", ("bytes32",), (interview["recordHash"],),
            (conservation.PREPARED,), (tuple(prepared),))
        f.append_intent(block=3, interview=interview); f.update_heads()
        with self.assertRaisesRegex(MuseumError, "preparation differs"):
            f.source().snapshot()

        f = PublicConservationFixture(); f.codes[A(8)] = b"changed selector runtime"
        with self.assertRaisesRegex(MuseumError, "runtime differs"):
            f.source().snapshot()

    def test_anchor_is_closed_and_provenance_does_not_upgrade_fixture(self):
        f = PublicConservationFixture(); anchor = loads(dumps(f.a), canonical=True)
        anchor["rightsSelector"] = A(31)
        with self.assertRaisesRegex(MuseumError, "shape/profile"):
            conservation.PublicConservationSource(dumps(anchor), f)
        with self.assertRaisesRegex(MuseumError, "provenance"):
            conservation.PublicConservationSource(dumps(f.a), f, provenance="trusted_rpc")
        result = f.result()
        self.assertEqual(result["mode"], "synthetic_fixture")
        self.assertFalse(result["claims"]["actualChainAcceptance"])
        self.assertFalse(result["claims"]["tierDeclarationProven"])

    def test_canonical_selector_artist_graph_lock_and_latest_are_not_fallbacks(self):
        f = PublicConservationFixture(); values = list(f.config); targets = list(values[0]); targets[17] = A(31)
        values[0] = tuple(targets)
        f.add(A(7), "nativeConfiguration()", (), (), (PROVIDER_CONFIG,), (tuple(values),))
        with self.assertRaisesRegex(MuseumError, "selector configuration"):
            f.source().snapshot()

        f = PublicConservationFixture(); f.add(f.suite[2][2], "core()", (), (), ("address",), (A(31),))
        with self.assertRaisesRegex(MuseumError, "reciprocal source"):
            f.source().snapshot()

        f = PublicConservationFixture(); f.lock_artist(block=3); f.update_heads()
        f.receipts[H(403)]["logs"].pop()
        with self.assertRaisesRegex(MuseumError, "Artist lock join"):
            f.source().snapshot()

        f = PublicConservationFixture()
        f.add(A(8), "currentConservation(uint256,bytes32,uint8)",
            ("uint256", "bytes32", "uint8"), (1, f.subject("collection"), 0),
            (conservation.SELECTION,), (conservation.EMPTY_SELECTION,))
        with self.assertRaisesRegex(MuseumError, "selected event/history"):
            f.source().snapshot()


if __name__ == "__main__":
    unittest.main()

"""Synthetic GeneralAttestations source controls; never native-chain evidence."""

import copy
import unittest
from unittest.mock import patch

from tools.metadata import identity_notarization_profile as notarization

from . import general_attestation_source as source
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id
from .chain_abi import Array, calldata, decode, encode
from .chain_rpc import ReplayTransport
from .independent_wire import (DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, RAW_DEFINITION, ZERO,
                               ZERO_ADDRESS)


def h(label):
    return keccak256(str(label).encode("utf-8"))


def a(value):
    return "0x" + value.to_bytes(20, "big").hex()


class Transport:
    def __init__(self, responses):
        self.responses = responses

    def request(self, method, params):
        key = dumps([method, params])
        if key not in self.responses:
            raise MuseumError("unexpected synthetic general attestation request")
        return copy.deepcopy(self.responses[key])


class ContradictoryIdentityTransport(Transport):
    """Return a second self-consistent current identity for one identical pinned read."""

    def __init__(self, responses, artist_id):
        super().__init__(responses)
        self.artist_id = artist_id
        self.current = b'{"identity":"contradictory same-block current"}'
        self.current_hash = keccak256(self.current)
        self.counts = {}

    def request(self, method, params):
        if method != "eth_call":
            return super().request(method, params)
        data = params[0]["data"]
        operative = calldata("operativeIdentityRecord(bytes32)", ("bytes32",), (self.artist_id,))
        record = calldata("identityRecordBytes(bytes32)", ("bytes32",), (self.artist_id,))
        identity = calldata("identity(bytes32)", ("bytes32",), (self.artist_id,))
        document = calldata("identityDocumentBytes(bytes32)", ("bytes32",), (self.current_hash,))
        self.counts[data] = self.counts.get(data, 0) + 1
        if data == operative and self.counts[data] == 2:
            return "0x" + encode(("bytes32",), (self.current_hash,)).hex()
        if data == record and self.counts[data] == 2:
            return "0x" + encode(("bytes",), (self.current,)).hex()
        if data == document:
            return "0x" + encode(("bytes",), (self.current,)).hex()
        if data == identity and self.counts[data] == 2:
            value = (a(14), 1, 3, 90, 111, h("registration"), "ipfs://other", "Other", 13)
            return "0x" + encode((source.IDENTITY,), (value,)).hex()
        return super().request(method, params)


class Fixture:
    """Complete synthetic four-lane host with signer, notarization and operator rows."""

    def __init__(self, *, empty=False, erc1271_empty=False, duplicate_nonce=False,
                 different_identity_history=False, artist_context=None):
        self.artist_context = artist_context
        self.responses = {} if artist_context is None else copy.deepcopy(artist_context.responses)
        self.erc1271_empty = erc1271_empty
        if artist_context is None:
            self.block = {"hash": h("general-block"), "number": "0x9", "timestamp": "0x70",
                          "stateRoot": h("general-state")}
            runtimes = {a(i): b"\x60" + bytes([i]) for i in range(1, 8)}
            self.anchor = {"profile": source.PROFILE, "chainId": "31337", "blockHash": self.block["hash"],
                "blockNumber": "9", "timestamp": "112", "stateRoot": self.block["stateRoot"],
                "environment": "local_evm_fixture", "deploymentEvidenceHash": h("general-deployment"),
                "host": a(1), "core": a(2), "schemas": a(3), "store": a(4), "metadata": a(5),
                "artistRegistry": a(6), "artistAttribution": a(7), "collectionId": "7",
                "codePins": [{"address": address, "runtimeHash": keccak256(raw)}
                             for address, raw in runtimes.items()]}
        else:
            self.block = copy.deepcopy(artist_context.block)
            host, host_raw = a(70), b"\x60\x46"
            base = artist_context.anchor
            self.anchor = {"profile": source.PROFILE, "chainId": base["chainId"],
                "blockHash": base["blockHash"], "blockNumber": base["blockNumber"],
                "timestamp": base["timestamp"], "stateRoot": base["stateRoot"],
                "environment": base["environment"], "deploymentEvidenceHash": base["deploymentEvidenceHash"],
                "host": host, "core": base["core"], "schemas": base["schemas"], "store": base["store"],
                "metadata": base["host"], "artistRegistry": base["artistRegistry"],
                "artistAttribution": artist_context.suite[2][4], "collectionId": base["collectionId"],
                "codePins": copy.deepcopy(base["codePins"]) + [{"address": host, "runtimeHash": keccak256(host_raw)}]}
            runtimes = {host: host_raw}
        self.host, self.core, self.schemas, self.store = (self.anchor[key] for key in ("host", "core", "schemas", "store"))
        self.metadata, self.artist_registry, self.artist_attribution = (
            self.anchor[key] for key in ("metadata", "artistRegistry", "artistAttribution"))
        self.pin_map = {row["address"]: row["runtimeHash"] for row in self.anchor["codePins"]}
        self.block_ref = {"blockHash": self.anchor["blockHash"], "requireCanonical": True}
        self.put("eth_chainId", [], "0x7a69")
        self.put("eth_getBlockByHash", [self.block["hash"], False], self.block)
        for address, raw in runtimes.items():
            self.put("eth_getCode", [address, self.block_ref], "0x" + raw.hex())
        for key, getter in (("core", "core"), ("schemas", "schemaRegistry"), ("store", "chunkStore"),
                            ("metadata", "metadataAuthority"), ("artistRegistry", "artistRegistry"),
                            ("artistAttribution", "artistAttribution")):
            self.call(getter + "()", ("address",), (self.anchor[key],))
            self.call(getter + "CodeHash()", ("bytes32",),
                      (self.pin_map[self.anchor[key]],))
        self.call("chunkStore()", ("address",), (self.store,), target=self.schemas)
        self.call("streamModuleType()", ("bytes32",), (schema_id("GENERAL_ATTESTATIONS"),))
        self.call("streamModuleVersion()", ("bytes32",),
                  (schema_id("6529stream.general-attestations.v1"),))
        self.call("collectionExists(uint256)", ("bool",), (True,), ("uint256",), (7,), target=self.core)
        for identifier in source.TYPES:
            classification = 2 if identifier == source.CURATORIAL else 1
            policy = (source.CURATOR_FAMILY, 1 << 3) if identifier == source.CURATORIAL else (ZERO, 0)
            self.call("verificationClass(bytes32)", ("uint8",), (classification,), ("bytes32",), (identifier,))
            self.call("operatorPolicy(bytes32)", ("bytes32", "uint16"), policy, ("bytes32",), (identifier,))

        self.pointer_number = 20 if artist_context is None else 2000
        self.documents = {}
        self.install_document("RAW_BYTES", 1, RAW_DEFINITION, RAW_BYTES)
        self.install_document(source.JCS_NAME, 1, source.JCS_BYTES, RAW_BYTES)
        self.install_document(notarization.SCHEMA_NAME, 0, notarization.SCHEMA_BYTES, RAW_BYTES)
        self.install_document(notarization.PROFILE_NAME, 2, notarization.PROFILE_BYTES, RAW_BYTES)
        self.generic_schema = schema_id("STREAM_SYNTHETIC_CURATORIAL_V1")
        self.generic_schema_bytes = dumps({"name": "synthetic general test schema", "actualChainAcceptance": False})
        self.install_document("STREAM_SYNTHETIC_CURATORIAL_V1", 0, self.generic_schema_bytes, source.JCS_ID)

        self.rows = []
        if not empty:
            first = notarization.example()
            self.historical_identity = b'{"identity":"synthetic historical"}'
            self.current_identity = b'{"identity":"synthetic rotated and disputed"}'
            first["operativeIdentityRecordHash"] = keccak256(self.historical_identity)
            second = copy.deepcopy(first)
            if different_identity_history:
                self.second_historical_identity = b'{"identity":"synthetic second historical"}'
                second["operativeIdentityRecordHash"] = keccak256(self.second_historical_identity)
            second["instrumentRef"]["uri"] = "https://evidence.example/revision-2"
            second["instrumentRef"]["hash"]["digest"] = h("revised-instrument")
            first_row = self.signed_notarization(first, index=0, nonce=10, supersedes=ZERO, previous=ZERO)
            second_row = self.signed_notarization(second, index=1, nonce=10 if duplicate_nonce else 11,
                supersedes=first_row[0], previous=first_row[2][5])
            self.rows.extend((first_row, second_row, self.operator_row(), self.artist_row()))
            self.install_identity(first["artistId"])
            if different_identity_history:
                second_hash = keccak256(self.second_historical_identity)
                self.call("identityDocumentBytes(bytes32)", ("bytes",), (self.second_historical_identity,),
                    ("bytes32",), (second_hash,), target=self.artist_registry)
        self.install_state()

    def put(self, method, params, result):
        self.responses[dumps([method, params])] = result

    def call(self, signature, outputs, result, kinds=(), values=(), target=None):
        target = self.host if target is None else target
        self.put("eth_call", [{"to": target, "data": calldata(signature, kinds, values),
            "gas": "0x1312d00"}, self.block_ref], "0x" + encode(outputs, result).hex())

    def install_chunk(self, raw):
        digest = keccak256(raw)
        pointer = a(self.pointer_number)
        self.pointer_number += 1
        self.call("chunk(bytes32)", ("address", "uint32"), (pointer, len(raw)),
                  ("bytes32",), (digest,), target=self.store)
        self.put("eth_getCode", [pointer, self.block_ref], "0x00" + raw.hex())
        return digest, pointer

    def install_document(self, name, kind, raw, canonical):
        identifier, digest = schema_id(name), keccak256(raw)
        chunk, _ = self.install_chunk(raw)
        spec = (name, kind, digest, canonical, ZERO, "ipfs://synthetic-definition", len(raw))
        declaration = keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, (chunk,))))
        value = (True, 0, declaration, spec, (chunk,))
        self.call("document(bytes32)", (DOCUMENT,), (value,), ("bytes32",), (identifier,), target=self.schemas)
        self.documents[identifier] = (raw, digest)

    def subject(self):
        return (0, 7, 0, ZERO)

    def signed_notarization(self, value, *, index, nonce, supersedes, previous):
        payload = notarization.canonical(value)
        attester = a(8)
        statement = (attester, 7, subject_id("collection", "31337", self.core, "7"), source.INSTITUTIONAL,
            "did:example:synthetic-institution", source.SCHEMA_ID, source.JCS_ID,
            "https://evidence.example/notarization", keccak256(payload), supersedes, ZERO, 100)
        scheme = source.ERC1271 if self.erc1271_empty else source.EIP712
        receipt = [attester, 1, 1, 101 + index, 0, ZERO, ZERO, nonce, 200, scheme, ZERO,
            notarization.SCHEMA_HASH, source.JCS_HASH, notarization.PROFILE_HASH, ZERO, 0, 0, 0,
            self.artist_registry, self.pin_map[self.artist_registry], value["artistId"],
            value["operativeIdentityRecordHash"], ZERO, 0]
        body = source.signed_words(statement, payload, receipt)
        authorization = keccak256(b"\x19\x01" + hex_bytes(source.domain(31337, self.host)) + hex_bytes(keccak256(body)))
        bundle = encode(("bytes32", ("bytes32",) * 15, "bytes"),
            (source.domain(31337, self.host), decode_words(body), b"" if self.erc1271_empty else b"s" * 65))
        receipt[6], receipt[10] = authorization, keccak256(bundle)
        digest = source.native_record_hash(31337, self.host, statement, tuple(receipt))
        receipt[4], receipt[5] = index, source.chain_hash(7, source.INSTITUTIONAL, previous, digest, index)
        return digest, statement, tuple(receipt), payload, bundle, b"", self.subject()

    def operator_row(self):
        payload = b"synthetic curator statement"
        statement = (a(9), 7, subject_id("collection", "31337", self.core, "7"), source.CURATORIAL,
            "did:example:asserted-party", self.generic_schema, source.JCS_ID,
            "ipfs://synthetic-curator", keccak256(payload), ZERO, ZERO, 100)
        receipt = [a(10), 2, 2, 103, 0, ZERO, ZERO, 12, 200, ZERO, ZERO,
            keccak256(self.generic_schema_bytes), source.JCS_HASH, ZERO, source.CURATOR_FAMILY,
            3, 7, 2, ZERO_ADDRESS, ZERO, ZERO, ZERO, ZERO, 0]
        digest = source.native_record_hash(31337, self.host, statement, tuple(receipt))
        receipt[5] = source.chain_hash(7, source.CURATORIAL, ZERO, digest, 0)
        return digest, statement, tuple(receipt), payload, b"", b"", self.subject()

    def install_identity(self, artist_id):
        historical = keccak256(self.historical_identity)
        current = keccak256(self.current_identity)
        self.call("identityDocumentBytes(bytes32)", ("bytes",), (self.historical_identity,),
            ("bytes32",), (historical,), target=self.artist_registry)
        self.call("operativeIdentityRecord(bytes32)", ("bytes32",), (current,),
            ("bytes32",), (artist_id,), target=self.artist_registry)
        self.call("identityRecordBytes(bytes32)", ("bytes",), (self.current_identity,),
            ("bytes32",), (artist_id,), target=self.artist_registry)
        self.call("identityDocumentBytes(bytes32)", ("bytes",), (self.current_identity,),
            ("bytes32",), (current,), target=self.artist_registry)
        identity = (a(13), 1, 4, 90, 110, historical, "ipfs://synthetic-identity",
            "Name is not identity proof", 12)
        self.call("identity(bytes32)", (source.IDENTITY,), (identity,),
            ("bytes32",), (artist_id,), target=self.artist_registry)

    def artist_row(self):
        payload, signer = b"synthetic native Artist statement", a(11)
        subject = h("native-artist-subject")
        statement_uri = "ipfs://synthetic-native-artist"
        statement = [signer, 7, subject, source.ARTIST, "did:example:synthetic-artist",
            self.generic_schema, source.JCS_ID, statement_uri, keccak256(payload), ZERO, ZERO, 100]
        artist_id, state = h("native-artist-id"), h("native-subject-state")
        terms = (7, 8, subject, state, self.generic_schema, keccak256(payload), statement_uri)
        artist_record = [ZERO, state, self.generic_schema, keccak256(payload), 1, 99, signer]
        association = (artist_id, h("native-binding"), 1, ZERO,
            (a(12), h("native-owner-code"), subject, state))
        proof = [self.artist_registry, self.pin_map[self.artist_registry], self.artist_attribution,
            self.pin_map[self.artist_attribution], 4,
            (24, artist_id, 7, ZERO), terms, tuple(artist_record), association, 1, 77]
        authorization = source.artist_authorization_hash(31337, self.core, tuple(proof))
        statement[10] = authorization
        artist_record[0] = authorization
        proof[5] = (24, artist_id, 7, authorization)
        proof[7] = tuple(artist_record)
        evidence = encode((source.ARTIST_PROOF,), (tuple(proof),))
        receipt = [signer, 1, 3, 104, 0, ZERO, ZERO, 13, 200, source.EIP712, ZERO,
            keccak256(self.generic_schema_bytes), source.JCS_HASH, ZERO, ZERO, 0, 0, 0,
            self.artist_registry, self.pin_map[self.artist_registry], artist_id, ZERO, keccak256(evidence), 1]
        body = source.signed_words(tuple(statement), payload, receipt)
        authorization_digest = keccak256(b"\x19\x01" + hex_bytes(source.domain(31337, self.host))
            + hex_bytes(keccak256(body)))
        bundle = encode(("bytes32", ("bytes32",) * 15, "bytes"),
            (source.domain(31337, self.host), decode_words(body), b"a" * 65))
        receipt[6], receipt[10] = authorization_digest, keccak256(bundle)
        digest = source.native_record_hash(31337, self.host, tuple(statement), tuple(receipt))
        receipt[5] = source.chain_hash(7, source.ARTIST, ZERO, digest, 0)
        return digest, tuple(statement), tuple(receipt), payload, bundle, evidence, None

    def install_state(self):
        pointers = {}
        for record_type in source.TYPES:
            lane = [row for row in self.rows if row[1][3] == record_type]
            head = lane[-1][2][5] if lane else ZERO
            self.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"), (head, len(lane)),
                ("uint256", "bytes32"), (7, record_type))
            latest = {}
            for index, row in enumerate(lane):
                digest, value, receipt, payload, bundle, evidence, subject = row
                self.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (digest,),
                    ("uint256", "bytes32", "uint256"), (7, record_type, index))
                self.call("attestation(bytes32)", (source.ATTESTATION, source.RECEIPT), (value, receipt),
                    ("bytes32",), (digest,))
                payload_hash, payload_pointer = self.install_chunk(payload)
                self.call("recordPayload(bytes32)", ("address", "bytes"), (payload_pointer, payload),
                    ("bytes32",), (digest,))
                pointers[(source.FAMILY, payload_hash)] = payload_pointer
                if bundle:
                    bundle_hash, bundle_pointer = self.install_chunk(bundle)
                    pointers[(source.BUNDLE_FAMILY, bundle_hash)] = bundle_pointer
                else:
                    bundle_pointer = ZERO_ADDRESS
                self.call("recordSignatureBundle(bytes32)", ("address", "bytes"), (bundle_pointer, bundle),
                    ("bytes32",), (digest,))
                self.call("recordArtistEvidence(bytes32)", ("bytes",), (evidence,), ("bytes32",), (digest,))
                if record_type != source.ARTIST:
                    self.call("recordSubject(bytes32)", (source.SUBJECT,), (subject,), ("bytes32",), (digest,))
                self.call("isAttesterNonceUsed(address,uint256)", ("bool",), (True,),
                    ("address", "uint256"), (receipt[0], receipt[7]))
                latest[(value[2], receipt[0])] = digest
            for (subject_id_, recorder), digest in latest.items():
                self.call("latestAttestationHashFor(uint256,bytes32,bytes32,address)", ("bytes32",), (digest,),
                    ("uint256", "bytes32", "bytes32", "address"), (7, record_type, subject_id_, recorder))
        self.call("payloadPointerCount(uint256)", ("uint256",), (len(pointers),), ("uint256",), (7,))
        for index, ((family, digest), pointer) in enumerate(pointers.items()):
            self.call("payloadPointerAt(uint256,uint256)", ("address", "bytes32", "bytes32"),
                (pointer, family, digest), ("uint256", "uint256"), (7, index))
        self.pointers = pointers

    def replace_record(self, row_index, *, value=None, receipt=None, payload=None, bundle=None):
        digest, old_value, old_receipt, old_payload, old_bundle, _, _ = self.rows[row_index]
        self.call("attestation(bytes32)", (source.ATTESTATION, source.RECEIPT),
            (value or old_value, receipt or old_receipt), ("bytes32",), (digest,))
        if payload is not None:
            pointer = self.pointers[(source.FAMILY, keccak256(old_payload))]
            self.call("recordPayload(bytes32)", ("address", "bytes"), (pointer, payload), ("bytes32",), (digest,))
        if bundle is not None:
            pointer = self.pointers[(source.BUNDLE_FAMILY, keccak256(old_bundle))]
            self.call("recordSignatureBundle(bytes32)", ("address", "bytes"), (pointer, bundle),
                ("bytes32",), (digest,))

    def reader(self, **kwargs):
        return source.GeneralAttestationSource(dumps(self.anchor), Transport(self.responses), **kwargs)

    def artist_overlay(self):
        if self.artist_context is None:
            raise MuseumError("joined synthetic Artist context required")
        from .artist_attestation_source import ArtistAttestationSource
        from .metadata_catalog_source import MetadataCatalogSource
        metadata = MetadataCatalogSource(dumps(self.artist_context.anchor), Transport(self.responses))
        return ArtistAttestationSource(metadata, Transport(self.responses))


def decode_words(raw):
    from .chain_abi import decode
    return decode(("bytes32",) * 15, raw)


class GeneralAttestationSourceTests(unittest.TestCase):
    def test_complete_histories_typed_notarization_operator_and_offline_replay(self):
        f = Fixture()
        reader = f.reader()
        with patch("socket.socket", side_effect=AssertionError("synthetic reader used network")):
            raw = reader.snapshot()
        result = loads(raw, maximum=source.MAX_SNAPSHOT, canonical=True)
        self.assertEqual(result["mode"], "synthetic_fixture")
        self.assertEqual(len(result["catalogue"]), 4)
        self.assertEqual(len(result["lanes"]), 4)
        self.assertEqual(len(result["records"]), 4)
        typed = [row for row in result["records"] if row["notarization"] is not None]
        self.assertEqual(len(typed), 2)
        self.assertEqual(typed[1]["value"][9], typed[0]["recordHash"])
        self.assertTrue(typed[0]["identityEvidence"]["currentDiffersFromHistorical"])
        self.assertEqual(typed[0]["identityEvidence"]["currentIdentity"][2], "4")
        self.assertEqual(typed[0]["identityEvidence"]["historicalDocumentHex"],
                         "0x" + f.historical_identity.hex())
        operator = next(row for row in result["records"] if row["value"][3] == source.CURATORIAL)
        self.assertEqual(operator["interpretation"]["verificationClass"], "OPERATOR_ASSERTED")
        self.assertEqual(operator["signatureBundleHex"], "0x")
        artist = next(row for row in result["records"] if row["value"][3] == source.ARTIST)
        self.assertIsNone(artist["subject"])
        self.assertEqual(artist["nativeArtistProof"]["authorityClass"], "1")
        self.assertEqual(artist["nativeArtistProof"]["nativeReceipt"][0], "24")
        self.assertEqual(artist["interpretation"]["authorityQualification"], "NATIVE_ARTIST_HISTORY")
        self.assertEqual(result["sourceState"], {key: f.anchor[key]
            for key in ("chainId", "core", "collectionId", "blockHash", "blockNumber")})
        self.assertFalse(result["claims"]["actualChainAcceptance"])
        self.assertFalse(result["claims"]["legalIdentityProven"])
        replay = source.GeneralAttestationSource(dumps(f.anchor),
            ReplayTransport(reader.transcript(), keccak256(reader.transcript())))
        self.assertEqual(replay.snapshot(), raw)

    def test_all_four_empty_lanes_are_authenticated_without_invented_records(self):
        result = loads(Fixture(empty=True).reader().snapshot(), maximum=source.MAX_SNAPSHOT, canonical=True)
        self.assertEqual(result["records"], [])
        self.assertEqual(result["payloadPointers"], [])
        self.assertEqual(len(result["lanes"]), 4)
        self.assertTrue(all(row["state"] == "authenticated_empty" for row in result["lanes"]))

    def test_historical_erc1271_receipt_may_retain_an_empty_signature(self):
        result = loads(Fixture(erc1271_empty=True).reader().snapshot(),
                       maximum=source.MAX_SNAPSHOT, canonical=True)
        typed = next(row for row in result["records"] if row["notarization"] is not None)
        self.assertEqual(typed["receipt"][9], source.ERC1271)
        _, _, signature = decode(("bytes32", ("bytes32",) * 15, "bytes"),
                                 hex_bytes(typed["signatureBundleHex"]), maximum=8192)
        self.assertEqual(signature, b"")

    def test_opt_in_joined_artist_fixture_shares_one_block_and_dependencies(self):
        from .test_artist_attestation_source import Fixture as ArtistFixture
        f = Fixture(artist_context=ArtistFixture())
        general = loads(f.reader().snapshot(), maximum=source.MAX_SNAPSHOT, canonical=True)
        artist = loads(f.artist_overlay().snapshot(), maximum=source.MAX_SNAPSHOT, canonical=True)
        self.assertEqual(general["sourceState"]["blockHash"], artist["sourceState"]["blockHash"])
        self.assertEqual(general["sourceState"]["core"], artist["sourceState"]["core"])
        self.assertEqual(general["sourceState"]["collectionId"], artist["sourceState"]["collectionId"])
        self.assertEqual(general["host"], a(70))
        self.assertEqual(f.pointer_number > 2000, True)

    def test_schema_profile_and_identity_mismatches_reject(self):
        for change in ("schema", "profile", "artist", "identity"):
            f = Fixture()
            value, receipt = list(f.rows[0][1]), list(f.rows[0][2])
            if change == "schema": value[5] = h("wrong-schema")
            elif change == "profile": receipt[13] = h("wrong-profile")
            elif change == "artist": receipt[20] = h("wrong-artist")
            else: receipt[21] = h("wrong-identity")
            f.replace_record(0, value=tuple(value), receipt=tuple(receipt))
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.reader().snapshot()

    def test_nonce_class_signature_and_operator_claim_boundaries_reject(self):
        for change in ("nonce", "class", "signature", "operator-class"):
            f = Fixture()
            if change == "nonce":
                receipt = f.rows[0][2]
                f.call("isAttesterNonceUsed(address,uint256)", ("bool",), (False,),
                    ("address", "uint256"), (receipt[0], receipt[7]))
            elif change == "class":
                receipt = list(f.rows[0][2]); receipt[1] = 2
                f.replace_record(0, receipt=tuple(receipt))
            elif change == "signature":
                f.replace_record(0, bundle=f.rows[0][4] + b"x")
            else:
                receipt = list(f.rows[2][2]); receipt[15] = 4
                f.replace_record(2, receipt=tuple(receipt))
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.reader().snapshot()

        with self.assertRaisesRegex(MuseumError, "reused accepted nonce"):
            Fixture(duplicate_nonce=True).reader().snapshot()

    def test_enumerated_lane_must_equal_every_stored_attestation_type(self):
        f = Fixture()
        digest = f.rows[2][0]
        f.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
            (f.rows[2][2][5], 1), ("uint256", "bytes32"), (7, source.ARTIST))
        f.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (digest,),
            ("uint256", "bytes32", "uint256"), (7, source.ARTIST, 0))
        with self.assertRaisesRegex(MuseumError, "original wire"):
            f.reader().snapshot()

    def test_record_hash_chain_supersession_and_runtime_pins_reject(self):
        for change in ("record", "chain", "supersedes", "pin"):
            f = Fixture()
            if change == "record":
                value = list(f.rows[0][1]); value[4] = "did:example:changed"
                f.replace_record(0, value=tuple(value))
            elif change == "chain":
                receipt = list(f.rows[0][2]); receipt[5] = h("wrong-chain")
                f.replace_record(0, receipt=tuple(receipt))
            elif change == "supersedes":
                value = list(f.rows[1][1]); value[9] = ZERO
                f.replace_record(1, value=tuple(value))
            else:
                f.put("eth_getCode", [a(7), f.block_ref], "0x6000")
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.reader().snapshot()

    def test_pointer_catalogue_and_definition_bytes_are_exact(self):
        for change in ("pointer", "definition"):
            f = Fixture()
            if change == "pointer":
                first = next(iter(f.pointers.items()))
                f.call("payloadPointerAt(uint256,uint256)", ("address", "bytes32", "bytes32"),
                    (a(99), first[0][0], first[0][1]), ("uint256", "uint256"), (7, 0))
            else:
                raw, _ = f.documents[source.PROFILE_ID]
                f.put("eth_getCode", [a(23), f.block_ref], "0x00" + (raw + b"x").hex())
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.reader().snapshot()

    def test_native_artist_proof_bytes_cannot_be_replaced_by_named_claims(self):
        f = Fixture()
        digest, _, _, _, _, evidence, _ = f.rows[3]
        f.call("recordArtistEvidence(bytes32)", ("bytes",), (evidence + b"named artist claim",),
            ("bytes32",), (digest,))
        with self.assertRaisesRegex(MuseumError, "Artist proof hash"):
            f.reader().snapshot()

    def test_historical_identity_bytes_are_exact_and_current_rotation_stays_separate(self):
        f = Fixture()
        historical = keccak256(f.historical_identity)
        f.call("identityDocumentBytes(bytes32)", ("bytes",), (f.historical_identity + b"changed",),
            ("bytes32",), (historical,), target=a(6))
        with self.assertRaisesRegex(MuseumError, "historical identity document"):
            f.reader().snapshot()

    def test_contradictory_same_block_current_identity_reads_reject(self):
        f = Fixture(different_identity_history=True)
        artist_id = f.rows[0][2][20]
        reader = source.GeneralAttestationSource(dumps(f.anchor),
            ContradictoryIdentityTransport(f.responses, artist_id))
        with self.assertRaisesRegex(MuseumError, "cross-source RPC result differs"):
            reader.snapshot()


if __name__ == "__main__":
    unittest.main()

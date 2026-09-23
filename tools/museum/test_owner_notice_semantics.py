"""Synthetic owner-notice semantic controls; never actual-chain evidence."""
import copy
import unittest
from unittest.mock import patch

from tools.metadata import owner_notice_profile as meaning

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id
from .chain_abi import Array, calldata, encode
from .chain_rpc import ReplayTransport
from .independent_catalog_source import (CATALOG as INDEPENDENT_CATALOG,
    PAYLOAD_FAMILY, PROFILE as INDEPENDENT_PROFILE, SIGNATURE_FAMILY, IndependentCatalogSource)
from .independent_wire import (DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, RAW_DEFINITION, RECORD,
    RECEIPT as INDEPENDENT_RECEIPT, SUBJECT, TYPE_HASH, ZERO, ZERO_ADDRESS,
    domain as independent_domain, generic_hash)
from .owner_catalog_source import OWNER_RECORD, RECEIPT, OwnerCatalogSource, domain, native_hash, signed_words
from .owner_notice_semantics import (DESIGNATED, DOCUMENTS, OwnerNoticeSemanticSource, RESPONSE,
                                     STEWARD)
from .ownership_source import OwnershipSource, PROFILE as OWNERSHIP_PROFILE, TRANSFER
from .test_owner_catalog_source import A, H, Fixture as CatalogueFixture, Transport


def _notice_value(family, subject, *, predecessor=None, response="acknowledged"):
    examples = meaning.examples()
    key = "steward-institution.json" if family == meaning.STEWARD else "recovery-acknowledged.json"
    value = copy.deepcopy(examples[key])
    value["subjectId"] = subject
    if family == meaning.STEWARD:
        value["predecessor"] = predecessor
    else:
        value["response"] = response
    return value


def _pair(raw, family, owner, index, previous, *, relayed=None, schema_name=None,
          schema_hash=None, subject=None):
    schema_name = schema_name or family
    record_type = STEWARD if family == meaning.STEWARD else RESPONSE
    subject = subject or subject_id("token", "31337", A(2), "0", token_id="71")
    record = (record_type, subject, schema_id(schema_name),
              (1, hex_bytes(keccak256(raw)), schema_id("RFC8785_JCS")), "", raw, 99)
    nonce = (117 if family == meaning.RESPONSE else 17) + index
    receipt = [71, owner, 102, index, ZERO, relayed is not None, ZERO,
               nonce if relayed else 0, 200 if relayed else 0,
               schema_hash or keccak256(DOCUMENTS[family][1]),
               keccak256(DOCUMENTS["RFC8785_JCS"][1]), schema_id(relayed or "DIRECT"), ZERO]
    if relayed:
        body = signed_words(record, receipt)
        saved_domain = domain(31337, A(1))
        signature = b"s" * 64 if relayed == "EIP712" else b""
        words = tuple("0x" + body[i:i + 32].hex() for i in range(0, len(body), 32))
        bundle = encode(("bytes32", ("bytes32",) * 14, "bytes"),
                        (saved_domain, words, signature))
        receipt[6] = keccak256(b"\x19\x01" + hex_bytes(saved_domain) + hex_bytes(keccak256(body)))
    else:
        bundle = encode(("bytes32", "address", "bytes32"),
                        (schema_id("DIRECT"), owner, keccak256(raw)))
    receipt[12] = keccak256(bundle)
    digest = native_hash(31337, A(1), A(2), record, receipt)
    receipt[4] = record_chain("31337", A(1), "71", record_type, previous, digest, str(index))
    return digest, record, tuple(receipt), bundle


class Fixture(CatalogueFixture):
    """Concrete OwnerCatalogSource inputs plus exact semantic definitions."""

    def __init__(self, *, document_status=2, burned=False, additions=()):
        super().__init__(empty=True)
        self.document_status = document_status
        self.document_rows = {}
        self.chunk_pointers = {}
        self._pointer = 100
        self.subject = subject_id("token", "31337", A(2), "0", token_id="71")
        self._install_documents()

        a_first = _notice_value(meaning.STEWARD, self.subject)
        first = self._add_notice(meaning.STEWARD, a_first, A(8), relayed=None)
        b_first = _notice_value(meaning.STEWARD, self.subject)
        second = self._add_notice(meaning.STEWARD, b_first, A(9), relayed="EIP712")
        a_next = _notice_value(meaning.STEWARD, self.subject, predecessor=first)
        third = self._add_notice(meaning.STEWARD, a_next, A(8), relayed="ERC1271")
        # A later generic same-family record is an Owner lane head, but never a typed designation head.
        generic = self._add_notice(meaning.STEWARD, {}, A(8), schema_name="SYNTHETIC_GENERIC_STEWARD_V1")
        response_a = self._add_notice(meaning.RESPONSE,
            _notice_value(meaning.RESPONSE, self.subject), A(8), relayed=None)
        response_b = self._add_notice(meaning.RESPONSE,
            _notice_value(meaning.RESPONSE, self.subject, response="objected"), A(9), relayed="EIP712")
        self.hashes = {"aFirst": first, "bFirst": second, "aCurrent": third,
            "generic": generic, "responseA": response_a, "responseB": response_b}
        for addition in additions:
            self._add_notice(**addition)
        self._install_lane_state()
        self.call("stewardDesignationFor(uint256,address)", ("bytes32",), (third,),
                  ("uint256", "address"), (71, A(8)))
        self.call("stewardDesignationFor(uint256,address)", ("bytes32",), (second,),
                  ("uint256", "address"), (71, A(9)))
        self._install_ownership(burned)
        if not burned:
            self.call("currentStewardDesignation(uint256)", ("address", "bytes32"),
                      (A(8), third), ("uint256",), (71,))

    def _chunk(self, raw):
        digest = keccak256(raw)
        data = calldata("chunk(bytes32)", ("bytes32",), (digest,))
        key = dumps(["eth_call", [{"to": A(4), "data": data, "gas": "0x1312d00"},
            {"blockHash": self.anchor["blockHash"], "requireCanonical": True}]])
        if key not in self.responses:
            pointer = A(self._pointer); self._pointer += 1
            self.call("chunk(bytes32)", ("address", "uint32"), (pointer, len(raw)),
                      ("bytes32",), (digest,), target=A(4))
            self.put("eth_getCode", [pointer, {"blockHash": self.anchor["blockHash"],
                "requireCanonical": True}], "0x00" + raw.hex())
            self.chunk_pointers[digest] = pointer
        return digest

    def _install_documents(self):
        documents = {"RAW_BYTES": (1, RAW_DEFINITION), **DOCUMENTS}
        for name, (kind, raw) in documents.items():
            digest = self._chunk(raw)
            spec = (name, kind, digest, RAW_BYTES, ZERO, "", len(raw))
            chunks = (digest,)
            declaration = keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, chunks)))
            document = (True, self.document_status, declaration, spec, chunks)
            self.document_rows[name] = document
            self.call("document(bytes32)", (DOCUMENT,), (document,), ("bytes32",),
                      (schema_id(name),), target=A(3))

    def _add_notice(self, family, value, owner, *, relayed=None, schema_name=None, raw=None,
                    schema_hash=None, designation=True):
        record_type = STEWARD if family == meaning.STEWARD else RESPONSE
        lane = [row for row in self.rows if row[1][0] == record_type]
        previous = lane[-1][2][4] if lane else ZERO
        index = len(lane)
        if raw is None:
            raw = dumps(value)
        schema = schema_name or family
        if schema_name is not None and schema_hash is None:
            schema_hash = H("definition:" + schema_name)
        row = _pair(raw, family, owner, index, previous, relayed=relayed,
                    schema_name=schema, schema_hash=schema_hash)
        self.rows.append(row)
        digest, record, receipt, bundle = row
        pointer = A(30 + len(self.rows))
        self.call("ownerRecord(bytes32)", (OWNER_RECORD, RECEIPT), (record, receipt),
                  ("bytes32",), (digest,))
        self.call("ownerRecordSignatureBundle(bytes32)", ("address", "bytes"),
                  (pointer, bundle), ("bytes32",), (digest,))
        self.put("eth_getCode", [pointer, {"blockHash": self.anchor["blockHash"],
            "requireCanonical": True}], "0x00" + bundle.hex())
        if receipt[5]:
            self.call("isOwnerRecordNonceUsed(address,uint256)", ("bool",), (True,),
                      ("address", "uint256"), (receipt[1], receipt[7]))
        self._chunk(raw)
        published = self.log(2, A(1), [self._record_event(),
            "0x" + encode(("uint256",), (71,)).hex(), record[0],
            "0x" + encode(("address",), (owner,)).hex()],
            encode((OWNER_RECORD, "bytes32", "bytes32", "bool", "uint16"),
                   (record, digest, receipt[4], receipt[5], 1)))
        if family == meaning.STEWARD and schema_name is None and designation:
            predecessor = value["predecessor"] or ZERO
            self.log(2, A(1), [DESIGNATED, "0x" + encode(("uint256",), (71,)).hex(),
                "0x" + encode(("address",), (owner,)).hex(), digest],
                encode(("bytes32", "uint16"), (predecessor, 1)))
        return digest

    @staticmethod
    def _record_event():
        from .owner_catalog_source import RECORD_EVENT
        return RECORD_EVENT

    def _install_lane_state(self):
        for record_type in (*__import__("tools.museum.owner_catalog_source", fromlist=["FIXED"]).FIXED,
                            self.custom):
            lane = [row for row in self.rows if row[1][0] == record_type]
            self.call("isOwnerRecordType(bytes32)", ("bool",), (True,),
                      ("bytes32",), (record_type,))
            self.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                      (lane[-1][2][4] if lane else ZERO, len(lane)),
                      ("uint256", "bytes32"), (71, record_type))
            for row in lane:
                self.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (row[0],),
                          ("uint256", "bytes32", "uint256"), (71, record_type, row[2][3]))
            latest = {row[2][1]: row[0] for row in lane}
            for owner, digest in latest.items():
                self.call("latestOwnerRecordHashFor(uint256,bytes32,address)", ("bytes32",),
                          (digest,), ("uint256", "bytes32", "address"), (71, record_type, owner))

    def _transfer_receipt(self, block, tx, tx_index, sender, recipient, log_index):
        receipt = {"transactionHash": tx, "blockHash": self.blocks[block]["hash"],
            "blockNumber": hex(block), "transactionIndex": hex(tx_index), "status": "0x1", "logs": []}
        log = {key: receipt[key] for key in ("transactionHash", "blockHash", "blockNumber", "transactionIndex")}
        log.update(address=A(2), data="0x", logIndex=hex(log_index), removed=False,
            topics=[TRANSFER, "0x" + encode(("address",), (sender,)).hex(),
                    "0x" + encode(("address",), (recipient,)).hex(),
                    "0x" + encode(("uint256",), (71,)).hex()])
        receipt["logs"] = [log]
        self.blocks[block]["transactions"].append(tx)
        self.receipts[tx] = receipt
        self.put("eth_getTransactionReceipt", [tx], receipt)

    def _install_ownership(self, burned):
        mint, transfer, final = H("mint"), H("transfer"), H("burn" if burned else "return")
        self._transfer_receipt(0, mint, 0, ZERO_ADDRESS, A(8), 0)
        self._transfer_receipt(1, transfer, 1, A(8), A(9), 1)
        final_to = ZERO_ADDRESS if burned else A(8)
        self._transfer_receipt(2, final, 1, A(9), final_to,
                               len(self.receipts[H("tx2")]["logs"]))
        self.call("supportsInterface(bytes4)", ("bool",), (True,), ("bytes4",),
                  ("0x80ac58cd",), target=A(2))
        self.call("tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"),
                  (True, 1, 1, burned), ("uint256",), (71,), target=A(2))
        self.call("tokenLifecycle(uint256)", ("uint8",), (3 if burned else 2,),
                  ("uint256",), (71,), target=A(2))
        if not burned:
            self.call("ownerOf(uint256)", ("address",), (A(8),),
                      ("uint256",), (71,), target=A(2))

    def catalogue(self):
        return OwnerCatalogSource(dumps(self.anchor), Transport(self.responses))

    def ownership(self):
        anchor = {"profile": OWNERSHIP_PROFILE,
            **{key: self.anchor[key] for key in ("chainId", "blockHash", "blockNumber", "timestamp",
                "stateRoot", "environment", "deploymentEvidenceHash")},
            "core": A(2), "coreRuntimeHash": next(row["runtimeHash"] for row in self.anchor["codePins"]
                if row["address"] == A(2)), "tokenId": "71", "collectionId": "1"}
        return OwnershipSource(dumps(anchor), Transport(self.responses))

    def semantic(self, *, ownership=None):
        return OwnerNoticeSemanticSource(self.catalogue(), Transport(self.responses), ownership=ownership)

    def independent(self, *, attestor=A(8), profile_hash=None, foreign_subject=False):
        """One concrete class-5 response lane over this fixture's exact source state."""
        host, runtime = A(5), b"\x60\x05"
        block_ref = {"blockHash": self.anchor["blockHash"], "requireCanonical": True}
        self.put("eth_getCode", [host, block_ref], "0x" + runtime.hex())
        pins = [row for row in self.anchor["codePins"] if row["address"] in (A(2), A(3), A(4))]
        pins.append({"address": host, "runtimeHash": keccak256(runtime)})
        anchor = {"profile": INDEPENDENT_PROFILE,
            **{key: self.anchor[key] for key in ("chainId", "blockHash", "blockNumber", "timestamp",
                "stateRoot", "environment", "deploymentEvidenceHash")},
            "host": host, "core": A(2), "schemas": A(3), "store": A(4),
            "codePins": pins, "scopeKey": "1"}
        for address in (A(2), A(3), A(4)):
            # These responses already exist for the owner reader and are identical by construction.
            self.put("eth_getCode", [address, block_ref], next(value for key, value in self.responses.items()
                if loads(key) == ["eth_getCode", [address, block_ref]]))
        for getter, value in (("core()", A(2)), ("schemaRegistry()", A(3)), ("chunkStore()", A(4))):
            self.call(getter, ("address",), (value,), target=host)
        runtime_pins = {row["address"]: row["runtimeHash"] for row in pins}
        for getter, address in (("coreCodeHash()", A(2)), ("schemaRegistryCodeHash()", A(3)),
                                ("chunkStoreCodeHash()", A(4))):
            self.call(getter, ("bytes32",), (runtime_pins[address],), target=host)
        self.call("supportsInterface(bytes4)", ("bool",), (True,), ("bytes4",),
                  ("0x771b2917",), target=host)
        self.call("streamModuleType()", ("bytes32",), (schema_id("COLLECTION_ATTESTATIONS"),), target=host)
        self.call("streamModuleVersion()", ("bytes32",),
                  (schema_id("6529stream.collection-attestations.independent.v1"),), target=host)
        self.call("streamModuleInterfaceId()", ("bytes4",), ("0x771b2917",), target=host)
        for _, record_type in INDEPENDENT_CATALOG:
            self.call("isIndependentRecordType(bytes32)", ("bool",), (True,),
                      ("bytes32",), (record_type,), target=host)
        self.call("isIndependentRecordType(bytes32)", ("bool",), (False,),
                  ("bytes32",), (ZERO,), target=host)

        token = 72 if foreign_subject else 71
        sid = subject_id("token", "31337", A(2), "1", token_id=str(token))
        value = _notice_value(meaning.RESPONSE, sid)
        if profile_hash is not None:
            value["profileHash"] = profile_hash
        payload = dumps(value); payload_hash = self._chunk(payload)
        record_type = schema_id("INDEPENDENT_PRESERVATION_EVENT")
        nonce, deadline, effective = 9001, 200, 99
        words = encode(("bytes32", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint16",
            "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint256", "uint64"),
            (TYPE_HASH, attestor, 1, sid, record_type, schema_id(meaning.RESPONSE), 1,
             keccak256(hex_bytes(payload_hash)), schema_id("RFC8785_JCS"), keccak256(b""),
             keccak256(payload),
             effective, nonce, deadline))
        saved_domain = independent_domain(31337, host)
        signature = b"s" * 64
        saved_words = tuple("0x" + words[i:i + 32].hex() for i in range(0, len(words), 32))
        bundle = encode(("bytes32", ("bytes32",) * 14, "bytes"),
                        (saved_domain, saved_words, signature))
        bundle_hash = self._chunk(bundle)
        scheme = schema_id("EIP712")
        record = (record_type, sid, (1, hex_bytes(payload_hash), schema_id("RFC8785_JCS")), "",
                  schema_id(meaning.RESPONSE), scheme,
                  (1, hex_bytes(bundle_hash), RAW_BYTES), effective)
        authorization = keccak256(b"\x19\x01" + hex_bytes(saved_domain) + hex_bytes(keccak256(words)))
        provisional = (1, attestor, 5, 102, 0, ZERO, authorization, nonce, deadline,
            keccak256(DOCUMENTS[meaning.RESPONSE][1]), keccak256(DOCUMENTS["RFC8785_JCS"][1]))
        record_hash = generic_hash(31337, host, A(2), 1, attestor, record)
        chain_hash = record_chain("31337", host, "1", record_type, ZERO, record_hash, "0")
        receipt = (*provisional[:5], chain_hash, *provisional[6:])
        subject = (1, 1, token, ZERO)
        self.call("collectionRecord(bytes32)", (RECORD, INDEPENDENT_RECEIPT),
                  (record, receipt), ("bytes32",), (record_hash,), target=host)
        self.call("recordSubject(bytes32)", (SUBJECT,), (subject,),
                  ("bytes32",), (record_hash,), target=host)
        for getter, raw in (("recordPayload(bytes32)", payload),
                            ("recordSignatureBundle(bytes32)", bundle)):
            digest = keccak256(raw)
            self.call(getter, ("address", "bytes"), (self.chunk_pointers[digest], raw),
                      ("bytes32",), (record_hash,), target=host)
        self.call("isIndependentAttestorNonceUsed(address,uint256)", ("bool",), (True,),
                  ("address", "uint256"), (attestor, nonce), target=host)
        self.call("latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)", ("bytes32",),
                  (record_hash,), ("uint256", "bytes32", "bytes32", "address"),
                  (1, record_type, sid, attestor), target=host)
        for _, lane_type in INDEPENDENT_CATALOG:
            populated = lane_type == record_type
            self.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                      (chain_hash if populated else ZERO, 1 if populated else 0),
                      ("uint256", "bytes32"), (1, lane_type), target=host)
        self.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (record_hash,),
                  ("uint256", "bytes32", "uint256"), (1, record_type, 0), target=host)
        pointers = [(self.chunk_pointers[payload_hash], PAYLOAD_FAMILY, payload_hash),
                    (self.chunk_pointers[bundle_hash], SIGNATURE_FAMILY, bundle_hash)]
        self.call("payloadPointerCount(uint256)", ("uint256",), (len(pointers),),
                  ("uint256",), (1,), target=host)
        for index, pointer in enumerate(pointers):
            self.call("payloadPointerAt(uint256,uint256)", ("address", "bytes32", "bytes32"),
                      pointer, ("uint256", "uint256"), (1, index), target=host)
        return IndependentCatalogSource(dumps(anchor), Transport(self.responses))


class OwnerNoticeSemanticTests(unittest.TestCase):
    def test_direct_relayed_statements_and_typed_per_author_heads(self):
        fixture = Fixture(); result = loads(fixture.semantic().snapshot(), maximum=16777216, canonical=True)
        self.assertEqual(result["mode"], "synthetic_fixture")
        self.assertEqual(len(result["ownerStatements"]), 6)
        supported = [row for row in result["ownerStatements"] if row["status"] == "supported"]
        self.assertEqual(len(supported), 5)
        generic = next(row for row in result["ownerStatements"]
                       if row["source"]["recordHash"] == fixture.hashes["generic"])
        self.assertEqual(generic["reasonCode"], "original_schema_or_canonicalization_unsupported")
        self.assertEqual(result["designationHeads"], [
            {"author": A(8), "recordHash": fixture.hashes["aCurrent"]},
            {"author": A(9), "recordHash": fixture.hashes["bFirst"]}])
        self.assertNotEqual(fixture.hashes["generic"], fixture.hashes["aCurrent"])
        relayed = {row["source"]["recordHash"]: row["authority"]["relayedOwnerAuthorization"]
                   for row in supported}
        self.assertFalse(relayed[fixture.hashes["aFirst"]])
        self.assertTrue(relayed[fixture.hashes["bFirst"]])
        self.assertFalse(result["claims"]["institutionalIdentityProven"])
        self.assertFalse(result["claims"]["vetoAuthorityGranted"])
        self.assertEqual(len(result["documents"]), 6)

    def test_contact_order_retained_and_duplicate_endpoint_rejected(self):
        fixture = Fixture(); result = loads(fixture.semantic().snapshot(), maximum=16777216)
        row = next(row for row in result["ownerStatements"]
                   if row["source"]["recordHash"] == fixture.hashes["aFirst"])
        self.assertEqual([item["kind"] for item in row["value"]["contactEndpoints"]],
                         ["https", "mailto", "eip155"])
        value = _notice_value(meaning.STEWARD,
            subject_id("token", "31337", A(2), "0", token_id="71"))
        value["contactEndpoints"].append(copy.deepcopy(value["contactEndpoints"][0]))
        fixture = Fixture(additions=({"family": meaning.STEWARD, "value": value, "owner": A(10)},))
        with self.assertRaisesRegex(MuseumError, "semantic payload invalid"):
            fixture.semantic().snapshot()

    def test_wrong_profile_subject_noncanonical_and_duplicate_key_reject(self):
        cases = []
        wrong_profile = _notice_value(meaning.RESPONSE,
            subject_id("token", "31337", A(2), "0", token_id="71"))
        wrong_profile["profileHash"] = H("wrong-profile")
        cases.append((dumps(wrong_profile), "profile"))
        wrong_subject = _notice_value(meaning.RESPONSE, H("wrong-subject"))
        cases.append((dumps(wrong_subject), "subject"))
        canonical = dumps(_notice_value(meaning.RESPONSE,
            subject_id("token", "31337", A(2), "0", token_id="71")))
        cases.append((b" " + canonical, "canonical"))
        cases.append((canonical[:-1] + b',"version":1}', "duplicate"))
        for raw, label in cases:
            fixture = Fixture(additions=({"family": meaning.RESPONSE, "value": {},
                "owner": A(10), "raw": raw},))
            with self.subTest(label=label), self.assertRaises(MuseumError):
                fixture.semantic().snapshot()

    def test_receipt_definition_content_hash_not_declaration_and_event_predecessor(self):
        base = Fixture()
        declaration = base.document_rows[meaning.RESPONSE][2]
        fixture = Fixture(additions=({"family": meaning.RESPONSE,
            "value": _notice_value(meaning.RESPONSE, base.subject), "owner": A(10),
            "schema_hash": declaration},))
        with self.assertRaisesRegex(MuseumError, "historical definition hash"):
            fixture.semantic().snapshot()
        fixture = Fixture()
        receipt = fixture.receipts[H("tx2")]
        event = next(log for log in receipt["logs"] if log["topics"][0] == DESIGNATED
                     and log["topics"][3] == fixture.hashes["aCurrent"])
        event["data"] = "0x" + encode(("bytes32", "uint16"), (ZERO, 1)).hex()
        with self.assertRaisesRegex(MuseumError, "predecessor differs"):
            fixture.semantic().snapshot()

    def test_original_record_wire_and_missing_designation_event_reject(self):
        fixture = Fixture(); digest, record, receipt, _ = fixture.rows[0]
        changed = list(record); changed[6] += 1
        fixture.call("ownerRecord(bytes32)", (OWNER_RECORD, RECEIPT),
                     (tuple(changed), receipt), ("bytes32",), (digest,))
        with self.assertRaises(MuseumError):
            fixture.semantic().snapshot()
        fixture = Fixture(); receipt = fixture.receipts[H("tx2")]
        receipt["logs"][:] = [log for log in receipt["logs"]
            if not (log["topics"][0] == DESIGNATED
                    and log["topics"][3] == fixture.hashes["aFirst"])]
        for index, log in enumerate(receipt["logs"]):
            log["logIndex"] = hex(index)
        fixture.receipts[H("return")]["logs"][0]["logIndex"] = hex(len(receipt["logs"]))
        with self.assertRaisesRegex(MuseumError, "predecessor differs|designation event missing"):
            fixture.semantic().snapshot()

    def test_retired_registered_documents_are_interpreted(self):
        result = loads(Fixture(document_status=2).semantic().snapshot(), maximum=16777216)
        self.assertEqual(sum(row["status"] == "supported" for row in result["ownerStatements"]), 5)

    def test_concrete_ownership_selects_transfer_back_author_and_burn_avoids_getter(self):
        fixture = Fixture(); ownership = fixture.ownership()
        result = loads(fixture.semantic(ownership=ownership).snapshot(), maximum=16777216)
        self.assertEqual(result["currentDesignation"], {"status": "recorded_notice_target",
            "owner": A(8), "recordHash": fixture.hashes["aCurrent"], "reasonCode": None})
        fixture = Fixture(burned=True); ownership = fixture.ownership()
        current_call = calldata("currentStewardDesignation(uint256)", ("uint256",), (71,))
        owner_call = calldata("ownerOf(uint256)", ("uint256",), (71,))
        self.assertFalse(any(current_call.encode() in key or owner_call.encode() in key
                             for key in fixture.responses))
        result = loads(fixture.semantic(ownership=ownership).snapshot(), maximum=16777216)
        self.assertEqual(result["currentDesignation"]["status"], "burned_no_current_owner")
        self.assertEqual(result["currentDesignation"]["owner"], ZERO_ADDRESS)

    def test_offline_replay_is_exact_with_socket_disabled(self):
        fixture = Fixture(); catalogue = fixture.catalogue(); source = OwnerNoticeSemanticSource(
            catalogue, Transport(fixture.responses))
        snapshot = source.snapshot(); catalogue_transcript = catalogue.transcript()
        semantic_transcript = source.transcript()
        with patch("socket.socket", side_effect=AssertionError("offline replay contacted network")):
            replay_catalogue = OwnerCatalogSource(dumps(fixture.anchor),
                ReplayTransport(catalogue_transcript, keccak256(catalogue_transcript)))
            replay = OwnerNoticeSemanticSource(replay_catalogue,
                ReplayTransport(semantic_transcript, keccak256(semantic_transcript)))
            self.assertEqual(replay.snapshot(), snapshot)
            self.assertEqual(replay.transcript(), semantic_transcript)

    def test_independent_current_owner_address_remains_separate_class5_voice(self):
        fixture = Fixture(); catalogue = fixture.catalogue(); ownership = fixture.ownership()
        independent = fixture.independent(attestor=A(8))
        source = OwnerNoticeSemanticSource(catalogue, Transport(fixture.responses),
            ownership=ownership, independents=(independent,))
        result = loads(source.snapshot(), maximum=16777216, canonical=True)
        self.assertEqual(len(result["independentStatements"]), 1)
        row = result["independentStatements"][0]
        self.assertEqual(row["family"], meaning.RESPONSE)
        self.assertEqual(row["authority"]["carrier"], "independent_attestor")
        self.assertEqual(row["authority"]["author"], A(8))
        self.assertFalse(row["authority"]["ownerStandingAtPublication"])
        self.assertFalse(row["authority"]["relayedOwnerAuthorization"])
        self.assertNotIn("designation", row)
        self.assertEqual(len(result["ownerStatements"]), 6)
        self.assertEqual(result["designationHeads"], [
            {"author": A(8), "recordHash": fixture.hashes["aCurrent"]},
            {"author": A(9), "recordHash": fixture.hashes["bFirst"]}])
        self.assertEqual(result["currentDesignation"]["recordHash"], fixture.hashes["aCurrent"])
        self.assertNotIn(row["source"]["recordHash"],
            {item["source"]["recordHash"] for item in result["ownerStatements"]})

    def test_independent_wrong_profile_rejects_and_foreign_token_is_not_promoted(self):
        fixture = Fixture(); independent = fixture.independent(profile_hash=H("wrong-profile"))
        with self.assertRaisesRegex(MuseumError, "subject/profile differs"):
            OwnerNoticeSemanticSource(fixture.catalogue(), Transport(fixture.responses),
                independents=(independent,)).snapshot()
        fixture = Fixture(); independent = fixture.independent(foreign_subject=True)
        result = loads(OwnerNoticeSemanticSource(fixture.catalogue(), Transport(fixture.responses),
            independents=(independent,)).snapshot(), maximum=16777216)
        self.assertEqual(result["independentStatements"], [])
        self.assertEqual(len(result["ownerStatements"]), 6)

    def test_mixed_carrier_replay_is_network_free_and_exact(self):
        fixture = Fixture(); catalogue = fixture.catalogue(); ownership = fixture.ownership()
        independent = fixture.independent()
        source = OwnerNoticeSemanticSource(catalogue, Transport(fixture.responses),
            ownership=ownership, independents=(independent,))
        snapshot = source.snapshot()
        transcripts = (catalogue.transcript(), ownership.transcript(),
                       independent.transcript(), source.transcript())
        with patch("socket.socket", side_effect=AssertionError("mixed replay contacted network")):
            replay_catalogue = OwnerCatalogSource(dumps(fixture.anchor),
                ReplayTransport(transcripts[0], keccak256(transcripts[0])))
            ownership_anchor = ownership.anchor_bytes
            replay_ownership = OwnershipSource(ownership_anchor,
                ReplayTransport(transcripts[1], keccak256(transcripts[1])))
            independent_anchor = independent.anchor_bytes
            replay_independent = IndependentCatalogSource(independent_anchor,
                ReplayTransport(transcripts[2], keccak256(transcripts[2])))
            replay = OwnerNoticeSemanticSource(replay_catalogue,
                ReplayTransport(transcripts[3], keccak256(transcripts[3])),
                ownership=replay_ownership, independents=(replay_independent,))
            self.assertEqual(replay.snapshot(), snapshot)


if __name__ == "__main__":
    unittest.main()

"""Synthetic unit boundaries for the token dossier publication mixin.

These doubles exercise call construction and evidence retention only.  They are
not RPC, deployment, receipt, or actual-chain acceptance evidence.
"""

from types import SimpleNamespace
import unittest
from unittest.mock import patch

from .canonical import MuseumError, hex_bytes, keccak256, schema_id, subject_id
from .chain_abi import encode
from .independent_wire import RAW_BYTES, RECORD, ZERO, generic_hash
from .token_dossier_publications import (CURATOR_CLASS, CURATOR_FAMILY, CURATOR_MASK,
    INDEPENDENT, INDEPENDENT_EVENT_DATA, INDEPENDENT_EVENT_TOPIC,
    INDEPENDENT_RECORD_TYPE, JCS_ID, METADATA, METADATA_EVENT_DATA,
    METADATA_EVENT_TOPIC, METADATA_RECORD_TYPE, OWNER, OWNER_EVENT_TOPIC,
    OWNER_MANIFEST_HASH, OWNER_MANIFEST_URI, OWNER_RECORD, OWNER_RECORD_TYPE,
    REGISTRY, TokenDossierPublicationsMixin)


def A(value):
    return "0x" + value.to_bytes(20, "big").hex()


def H(value):
    return "0x" + value.to_bytes(32, "big").hex()


def tx_hash(value):
    return H(1000 + value)


class Journal:
    def __init__(self):
        self.receipts = []
        self.timestamp = 1789171200
        self._tx = 0

    def _receipt(self, sender, target, data="0x01020304", logs=()):
        self._tx += 1
        digest = tx_hash(self._tx)
        receipt = {"transactionHash": digest, "blockHash": H(2000 + self._tx),
            "blockNumber": hex(100 + self._tx), "transactionIndex": "0x0",
            "status": "0x1", "logs": list(logs)}
        self.receipts.append({"transaction": {"from": sender, "to": target, "data": data},
            "transactionHash": digest, "receipt": receipt})
        return receipt

    def rpc(self, method, params):
        if method == "eth_chainId": return "0x7a69"
        if method == "eth_getBlockByNumber": return {"timestamp": hex(self.timestamp)}
        if method == "eth_getCode": return "0x60016000"
        if method == "eth_accounts": return [A(i) for i in range(1, 12)]
        raise AssertionError((method, params))


class RegistrationFixture(TokenDossierPublicationsMixin, Journal):
    def __init__(self):
        Journal.__init__(self)
        self.addresses = {REGISTRY: A(1), OWNER: A(2)}
        self.deployment = H(3)
        self.module_type = schema_id("OWNER_RECORDS")
        self.version = H(4)
        self.interface = "0x12345678"
        self.uri = OWNER_MANIFEST_URI
        self.manifest_hash = OWNER_MANIFEST_HASH
        self.saved = None
        self.governed = None

    def call(self, name, function, values=()):
        if name == OWNER:
            return {"streamModuleType": (self.module_type,), "streamModuleVersion": (self.version,),
                "streamModuleInterfaceId": (self.interface,),
                "streamModuleManifest": (self.uri, self.manifest_hash),
                "streamModuleDeploymentManifestHash": (self.deployment,),
                "streamModuleCodeHash": (keccak256(hex_bytes("0x60016000")),)}[function]
        if name == REGISTRY and function == "registrationChainHash": return (H(5), 7)
        if name == REGISTRY and function == "moduleRecord":
            return (self.saved if self.saved is not None else
                (0, ZERO, ZERO, "0x00000000", 0, ZERO, ZERO, ZERO, "", 0, 0, 0),)
        if name == REGISTRY and function == "isModuleEligible": return (self.saved is not None,)
        raise AssertionError((name, function, values))

    def read(self, target, signature, kinds=(), values=(), outputs=()):
        self.supports = (target, signature, kinds, values, outputs)
        return (True,)

    def govern_configuration(self, name, function, values, transition=None, **kwargs):
        self.governed = (name, function, values, transition)
        item = values[0]
        self.saved = (1, *item[1:], 101, 101, 1)
        self._receipt(A(8), self.addresses[REGISTRY])


class PreflightFixture(TokenDossierPublicationsMixin, Journal):
    def __init__(self):
        Journal.__init__(self)
        self.addresses = {"StreamCore": A(1), REGISTRY: A(2), METADATA: A(3),
            INDEPENDENT: A(4), "StreamArtistOnboardingRegistry": A(5)}
        self.schemas, self.store = A(6), A(7)
        self.token_buyer, self.attestor = A(8), A(9)
        self.safe_accounts = {self.attestor: (A(10), A(11))}
        self.token_scope = SimpleNamespace(token_id="1", chain_id="31337", core=A(1), collection_id="1")
        self.metadata_type = schema_id("COLLECTION_METADATA")
        self.metadata_interface = "0x12345678"

    def rpc(self, method, params):
        if method == "eth_accounts": return [self.token_buyer]
        return super().rpc(method, params)

    def call(self, name, function, values=()):
        if name == "StreamCore" and function == "ownerOf": return (self.token_buyer,)
        if name == "StreamCore" and function == "tokenCollectionIdentity": return (True, 1, 1, False)
        if name == METADATA and function == "streamModuleType": return (self.metadata_type,)
        if name == METADATA and function == "streamModuleInterfaceId": return (self.metadata_interface,)
        if name == "StreamCore" and function == "getSatellitePointer":
            runtime = keccak256(hex_bytes("0x60016000"))
            return (A(3), runtime, False, self.metadata_type, self.metadata_interface, A(2), 1, H(8), H(9), 1)
        if name == REGISTRY and function == "isModuleEligible": return (True,)
        if name == METADATA and function == "core": return (A(1),)
        if name == METADATA and function == "schemaRegistry": return (A(6),)
        if name == METADATA and function == "chunkStore": return (A(7),)
        if name == METADATA and function == "artistRegistry": return (A(5),)
        if name == INDEPENDENT and function == "core": return (A(1),)
        if name == INDEPENDENT and function == "schemaRegistry": return (A(6),)
        if name == INDEPENDENT and function == "chunkStore": return (A(7),)
        if name == "StreamSchemaRegistry" and function == "documentBytes": return (b"jcs",)
        raise AssertionError((name, function, values))


class OwnerFixture(TokenDossierPublicationsMixin, Journal):
    def __init__(self):
        Journal.__init__(self)
        self.addresses = {"StreamCore": A(1), OWNER: A(2)}
        self.token_buyer = A(8)
        self.subject = subject_id("token", "31337", A(1), "1", token_id="1")
        self.saved = None
        self.sent = None

    def data(self, name, function, values=()):
        self.sent = (name, function, values)
        return "0x01020304"

    def send(self, data, target=None, sender=None):
        record = self.sent[2][1]
        bundle = encode(("bytes32", "address", "bytes32"),
            (schema_id("DIRECT"), self.token_buyer, keccak256(record[5])))
        native_receipt = (1, self.token_buyer, self.timestamp, 0, H(31), False, ZERO, 0, 0,
            H(32), H(33), schema_id("DIRECT"), keccak256(bundle))
        record_hash = H(30)
        event = encode((OWNER_RECORD, "bytes32", "bytes32", "bool", "uint16"),
            (record, record_hash, H(31), False, 1))
        self.saved = (record_hash, record, native_receipt, bundle)
        log = {"address": target, "topics": [OWNER_EVENT_TOPIC, H(1), OWNER_RECORD_TYPE,
            "0x" + bytes(12).hex() + hex_bytes(self.token_buyer, 20).hex()], "data": "0x" + event.hex()}
        self.sender = sender
        return self._receipt(sender, target, data, (log,))

    def call(self, name, function, values=()):
        if function == "deriveOwnerSubject": return (self.subject,)
        if function == "recordChainHash": return (ZERO, 0) if self.saved is None else (H(31), 1)
        if function == "ownerRecord": return self.saved[1:3]
        if function == "ownerRecordSignatureBundle": return (A(20), self.saved[3])
        raise AssertionError((name, function, values))


class MetadataFixture(TokenDossierPublicationsMixin, Journal):
    def __init__(self):
        Journal.__init__(self)
        self.addresses = {"StreamCore": A(1), METADATA: A(2)}
        self.attestor = A(9)
        self.policy = (ZERO, 0, False)
        self.grant = (False, 0)
        self.saved = None
        self.governed = []

    def govern_configuration(self, name, function, values, transition=None, **kwargs):
        self.governed.append((name, function, values, transition))
        if function == "admitRecordType": self.policy = (values[1], values[2], True)
        if function == "setFamilyWriter": self.grant = (True, 1)
        self._receipt(A(7), A(2))

    def call(self, name, function, values=()):
        if function == "recordPolicy": return (self.policy,)
        if function in ("recordTypeTransition", "familyWriterTransition"): return (H(1), H(2), H(3))
        if function == "familyWriter": return self.grant
        if function == "recordChainHash": return (ZERO, 0) if self.saved is None else (H(41), 1)
        if function == "deriveCollectionRecordHashFor":
            return (generic_hash(31337, A(2), A(1), 1, self.attestor, values[2]),)
        if function == "collectionRecord": return self.saved[1:3]
        if function == "recordPayload": return (A(21), self.saved[3])
        raise AssertionError((name, function, values))

    def transact(self, name, function, values=(), *, safe=None):
        _, record, payload = values
        record_hash = generic_hash(31337, A(2), A(1), 1, self.attestor, record)
        native_receipt = (1, self.attestor, CURATOR_CLASS, self.timestamp, 0, H(41), H(42), H(43), ZERO)
        self.saved = (record_hash, record, native_receipt, payload)
        event = encode(METADATA_EVENT_DATA, (record, record_hash, H(41), self.attestor,
            "0x" + CURATOR_CLASS.to_bytes(32, "big").hex(), 1))
        log = {"address": A(2), "topics": [METADATA_EVENT_TOPIC, H(1), METADATA_RECORD_TYPE,
            record[1]], "data": "0x" + event.hex()}
        self.safe = safe
        return self._receipt(A(5), safe, "0x05060708", (log,))


class IndependentFixture(TokenDossierPublicationsMixin, Journal):
    def __init__(self):
        Journal.__init__(self)
        self.addresses = {"StreamCore": A(1), INDEPENDENT: A(2)}
        self.attestor = A(9)
        self.capture_context = {"nextNonce": 12}
        self.sid = subject_id("collection", "31337", A(1), "0")
        self.saved = None

    def call(self, name, function, values=()):
        if function == "deriveSubject": return (self.sid,)
        if function == "isIndependentAttestorNonceUsed": return (False,)
        if function == "recordChainHash": return (ZERO, 0) if self.saved is None else (H(51), 1)
        if function == "collectionRecord": return self.saved[1:3]
        if function == "recordSubject": return (self.saved[3],)
        if function == "recordPayload": return (A(20), self.saved[4])
        if function == "recordSignatureBundle": return (A(21), self.saved[5])
        raise AssertionError((name, function, values))

    def transact(self, name, function, values=(), *, safe=None):
        subject, request, signature = values
        self.request = request
        self.safe = safe
        self.assert_signature = signature
        bundle = b"synthetic direct bundle"
        record = (request[3], request[2], (1, request[6], request[7]), request[8], request[4],
            schema_id("DIRECT"), (1, hex_bytes(keccak256(bundle)), RAW_BYTES), request[10])
        record_hash = generic_hash(31337, A(2), A(1), 0, self.attestor, record)
        native_receipt = (0, self.attestor, 5, self.timestamp, 0, H(51), H(52), request[11],
            request[12], H(53), H(54))
        self.saved = (record_hash, record, native_receipt, subject, request[9], bundle)
        event = encode(INDEPENDENT_EVENT_DATA, (record, record_hash, H(51), self.attestor,
            "0x" + (5).to_bytes(32, "big").hex(), 1))
        log = {"address": A(2), "topics": [INDEPENDENT_EVENT_TOPIC, H(0), INDEPENDENT_RECORD_TYPE,
            record[1]], "data": "0x" + event.hex()}
        return self._receipt(A(5), safe, "0x090a0b0c", (log,))


class TokenDossierPublicationTests(unittest.TestCase):
    def test_registration_uses_native_self_description_without_interface_product(self):
        fixture = RegistrationFixture()
        result = fixture._register_native_dossier_module(OWNER, schema_id("OWNER_RECORDS"))
        self.assertEqual(result["interfaceId"], fixture.interface)
        self.assertEqual(fixture.supports[3], (fixture.interface,))
        self.assertEqual(fixture.governed[0:2], (REGISTRY, "registerModule"))
        self.assertEqual(fixture.governed[2][0][0], A(2))
        self.assertEqual(len(fixture.governed[3]), 3)
        self.assertEqual(len(result["transactions"]), 1)

    def test_registration_rejects_wrong_native_type_interface_or_uri(self):
        fixture = RegistrationFixture(); fixture.module_type = schema_id("COLLECTION_ATTESTATIONS")
        with self.assertRaisesRegex(MuseumError, "identity differs"):
            fixture._register_native_dossier_module(OWNER, schema_id("OWNER_RECORDS"))
        fixture = RegistrationFixture(); fixture.uri = "urn:mutable:alias"
        with self.assertRaisesRegex(MuseumError, "identity differs"):
            fixture._register_native_dossier_module(OWNER, schema_id("OWNER_RECORDS"))
        fixture = RegistrationFixture(); fixture.read = lambda *args: (False,)
        with self.assertRaisesRegex(MuseumError, "declared interface"):
            fixture._register_native_dossier_module(OWNER, schema_id("OWNER_RECORDS"))

    def test_preflight_binds_actual_owner_identity_and_selected_metadata(self):
        fixture = PreflightFixture()
        self.assertEqual(fixture._native_dossier_preflight(), 1)
        fixture.token_buyer = A(12)
        original_rpc = fixture.rpc
        fixture.rpc = lambda method, params: [A(8)] if method == "eth_accounts" else original_rpc(method, params)
        with self.assertRaisesRegex(MuseumError, "unlocked fixture account"):
            fixture._native_dossier_preflight()
        fixture = PreflightFixture(); fixture.metadata_type = schema_id("WRONG")
        with self.assertRaisesRegex(MuseumError, "selected registered host"):
            fixture._native_dossier_preflight()

    @patch("tools.museum.token_dossier_publications.verify_owner_record")
    def test_owner_publication_is_direct_from_actual_eoa_and_retains_wire(self, verify):
        fixture = OwnerFixture()
        result = fixture._publish_native_owner_record(1, H(6))
        self.assertEqual(fixture.sender, fixture.token_buyer)
        self.assertEqual(fixture.sent[1], "recordOwnerRecord")
        self.assertEqual(result["authorization"], "DIRECT_CURRENT_OWNER")
        self.assertEqual(result["nativeReceipt"][1], fixture.token_buyer)
        self.assertTrue(result["signatureBundle"].startswith("0x"))
        self.assertEqual(result["transaction"]["from"], fixture.token_buyer)
        verify.assert_called_once()

    @patch("tools.museum.token_dossier_publications.verify_metadata_record")
    def test_metadata_publication_uses_existing_host_curator_class3_safe(self, verify):
        fixture = MetadataFixture()
        result = fixture._publish_native_metadata_record(H(6))
        self.assertEqual(fixture.governed[0][1:3],
            ("admitRecordType", (METADATA_RECORD_TYPE, CURATOR_FAMILY, CURATOR_MASK)))
        self.assertEqual(fixture.governed[1][1:3],
            ("setFamilyWriter", (1, CURATOR_FAMILY, CURATOR_CLASS, fixture.attestor, True)))
        self.assertEqual(fixture.safe, fixture.attestor)
        self.assertEqual(result["authorizationClass"], "3")
        self.assertEqual(result["record"][3], "")
        self.assertEqual(result["nativeReceipt"][2], "3")
        verify.assert_called_once()

    @patch("tools.museum.token_dossier_publications.verify_independent_record")
    def test_independent_publication_is_safe_authored_deployment_scope_zero(self, verify):
        fixture = IndependentFixture()
        result = fixture._publish_native_deployment_record(H(6))
        self.assertEqual(fixture.safe, fixture.attestor)
        self.assertEqual(fixture.request[1], 0)
        self.assertEqual(fixture.request[11], 16)
        self.assertEqual(fixture.assert_signature, b"")
        self.assertEqual(result["scopeKey"], "0")
        self.assertEqual(result["record"][3], "")
        self.assertEqual(result["nativeReceipt"][0], "0")
        verify.assert_called_once()

    def test_complete_hook_returns_stable_three_record_evidence_and_refuses_reuse(self):
        class Fixture(TokenDossierPublicationsMixin, Journal):
            def __init__(self):
                Journal.__init__(self); self.receipts = []
                self.addresses = {OWNER: A(1), INDEPENDENT: A(2), METADATA: A(3)}
            def _native_dossier_preflight(self): return 7
            def _deploy_native_owner_host(self): return A(1)
            def _register_native_dossier_module(self, name, expected):
                return {"name": name, "host": self.addresses[name], "moduleType": expected,
                    "moduleVersion": H(1), "interfaceId": "0x12345678", "runtimeHash": H(2),
                    "deploymentManifestHash": H(3), "moduleManifestHash": H(4),
                    "moduleManifestURI": "https://example.org/module", "registry": A(4), "transactions": []}
            def register_document(self, name, kind, raw, canonical): return schema_id(name)
            def _row(self, kind, scope):
                self._receipt(A(8), self.addresses[kind])
                return {"host": self.addresses[kind], "recordHash": H(len(self.receipts)),
                    "transactionHash": self.receipts[-1]["transactionHash"]}
            def _publish_native_owner_record(self, token, schema): return self._row(OWNER, token)
            def _publish_native_metadata_record(self, schema): return self._row(METADATA, 1)
            def _publish_native_deployment_record(self, schema): return self._row(INDEPENDENT, 0)
        fixture = Fixture()
        value = fixture.publish_native_dossier_records()
        self.assertEqual(value["recordHashes"], {"owner": H(1), "metadata": H(2), "independent": H(3)})
        self.assertEqual([(row["kind"], row["scopeKey"]) for row in value["scopes"]],
            [("owner", "7"), ("metadata", "1"), ("independent", "0")])
        self.assertEqual(len(value["transactions"]), 3)
        self.assertFalse(value["actualChainAcceptance"])
        self.assertFalse(value["fullObjectDossierConformance"])
        with self.assertRaisesRegex(MuseumError, "cannot be published twice"):
            fixture.publish_native_dossier_records()


if __name__ == "__main__":
    unittest.main()

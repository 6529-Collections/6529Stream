"""Synthetic original Artist/General documentary fixtures; no personhood or runtime acceptance."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from tools.metadata import identity_notarization_profile as notar
from . import public_personhood_source as source
from . import personhood_documentary as documentary
from . import artist_attestation_source as artist
from . import general_attestation_source as general
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, RAW_BYTES, json_values
from .public_history_rpc import PublicReplayTransport
from .test_public_conservation_provider_source import PublicConservationProviderFixture, A, H, K


REFERENCE = ("uint16", "bytes32", "address", "bytes32", "bytes32", "address", "bytes32", "bytes32")
SUMMARY = ("uint16", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint256", "bytes32",
    REFERENCE, "bytes32", "address", "bytes32", "address", "bytes32", "address", "bytes32", "address", "bytes32",
    ("bytes32",) * 4, "uint256", "bytes32", "bytes32", "address", "bytes32", "bytes32", ("address",) * 6, ("bytes32",) * 6)
SELECTION = (artist.ATTESTATION_RECORD, "address", REFERENCE, "bytes32", "address", "bytes32", "bool", "bool", "uint8")
NATIVE_PREIMAGE = ("bytes32", "uint256", "address", "address", "uint256", "uint8", "bytes32", "bytes32",
    "bytes32", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64")
MODULE = ("uint8", "bytes32", "bytes32", "bytes4", "uint32", "bytes32", "bytes32", "bytes32", "string", "uint64", "uint64", "uint64")
POINTER = ("address", "bytes32", "bool", "bytes32", "bytes4", "address", "uint8", "bytes32", "bytes32", "uint64")
FACTS = ("bool", "uint8", "uint8", "bytes32", "bytes32", "bytes32", "uint32", "uint256", "bytes32")
SUMMARY_TAG = K("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1")
DOC_TAG = K("6529STREAM_ARTIST_PERSONHOOD_DOCUMENTARY_PROOF_V1")
EVIDENCE = K("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1")
WAIVER = K("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
REFERENCE_ID = K("STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1")
REFERENCE_HASH = "0x06eaf449a0abe6a4305706d589bc597f14f7d23f62acc661b4b1fff128b921c3"
SUMMARY_EVENT = "0x6e6f0693dc4333e22abef4176f288b2d5f7f9c6a34c9862422b6c339aa9705d1"
STORED_EVENT = K("ArtistStoredPayload(uint16,uint256,bytes32,bytes32,address)")
GENERAL_EVENT = K("GeneralAttestationRecorded(uint256,bytes32,bytes32,bytes32,address,uint8,uint8,bytes32,bytes32,uint16)")


def zero(kind):
    if isinstance(kind, tuple): return tuple(zero(item) for item in kind)
    if kind == "address": return ZERO_ADDRESS
    if kind == "bool": return False
    if kind.startswith("uint"): return 0
    if kind == "string": return ""
    return ZERO


class PublicPersonhoodMixin:
    """Install native personhood observations into a coherent synthetic base response map."""
    native_authority_class = 1
    def setup_personhood(self, *, mode="resolved", current_graph=None, current_binding=None):
        if mode not in ("resolved", "none", "waiver", "stale_head", "other_recorder", "imported", "imported_waiver", "legacy"):
            raise ValueError("unsupported synthetic personhood mode")
        self.personhood_mode = mode
        self.personhood_suite = None
        if current_graph is None:
            self.registry, self.coordinator, self.archive = A(10008), A(11100), A(11200)
            self.owners = tuple(A(11000 + i) for i in range(7))
        else:
            self.registry, self.coordinator, self.archive = (current_graph[key] for key in ("registry", "coordinator", "archive"))
            self.owners = tuple(current_graph["owners"])
            self.personhood_suite = tuple(current_graph["configuration"])
        imported = mode in ("imported", "imported_waiver")
        self.origin_registry = A(20008) if imported else self.registry
        self.origin_coordinator = A(21100) if imported else self.coordinator
        self.origin_archive = A(21200) if imported else self.archive
        self.origin_owners = tuple(A(21000 + i) for i in range(7)) if imported else self.owners
        self.modules, self.notary, self.recorder = A(13000), A(13001), A(13002)
        self.signer = A(12000)
        self.artist_id = K("synthetic stable original artist")
        self.registration_hash = K("synthetic original registration identity")
        self.identity_document = b'{"identity":"synthetic operative document distinct from registration"}'
        self.operative = keccak256(self.identity_document)
        self.binding_hash = K("synthetic original accepted binding")
        self.current_binding = current_binding if current_binding is not None else (
            self.artist_id, self.signer, self.registration_hash, self.binding_hash, 1, 1, 0, 0, A(9), True)
        self.artist_id, self.signer, self.registration_hash, self.binding_hash = self.current_binding[:4]
        self._payloads, self._next_pointer = {}, 30000
        for address in dict.fromkeys((self.registry, self.coordinator, self.archive, *self.owners,
                self.origin_registry, self.origin_coordinator, self.origin_archive, *self.origin_owners,
                self.modules, self.notary)):
            if address not in self.codes:
                self.codes[address] = ("synthetic personhood source " + address).encode("ascii")
            self.pins[address] = keccak256(self.codes[address])
        self._graph(self.registry, self.coordinator, self.archive, self.owners)
        if imported: self._graph(self.origin_registry, self.origin_coordinator, self.origin_archive, self.origin_owners)
        for role, target in (("COLLECTION_METADATA", A(1)), ("ARTIST_REGISTRY", self.registry), ("MODULE_REGISTRY", self.modules)):
            self._pointer(role, target)
        self.add(A(1), "core()", (), (), ("address",), (self.core,))
        self.add(A(1), "artistRegistry()", (), (), ("address",), (self.registry,))
        self.add(A(1), "artistRegistryCodeHash()", (), (), ("bytes32",), (self.pins[self.registry],))
        self.summary = zero(SUMMARY)
        self.summary_hash = ZERO
        self.general_rows = []
        self.native_record = zero(artist.ATTESTATION_RECORD)
        self.reference = zero(REFERENCE)
        if mode != "none": self._native_personhood()
        else: self._selection(0)
        self.personhood_anchor = {key: self.a[key] for key in ("chainId", "core", "collectionId", "blockHash",
            "blockNumber", "timestamp", "stateRoot", "environment", "deploymentEvidenceHash")}
        self.personhood_anchor.update(profile=source.PROFILE, host=A(1), artistRegistry=self.registry,
            runtimeAdmission={"sourceCommit": source.SOURCE_REVISION, "kind": "synthetic_fixture",
                "artifactHash": K("synthetic personhood fixture artifact " + source.SOURCE_REVISION)},
            codePins=[{"address": address, "runtimeHash": digest} for address, digest in sorted(self.pins.items())])
        self.a = self.personhood_anchor

    def _pointer(self, role, target):
        pointer = (target, self.pins[target], False, K(role), "0x00000000", ZERO_ADDRESS, 1,
            K(role + " pointer action"), K(role + " pointer reason"), 1)
        self.add(self.core, "getSatellitePointer(bytes32)", ("bytes32",), (K(role),), (POINTER,), (pointer,))

    def _graph(self, registry, coordinator, archive, owners):
        suite = self.personhood_suite if registry == self.registry and self.personhood_suite is not None else (
            registry, archive, owners, self.core, A(98), A(81), A(1), A(3), A(4), K("primary revenue"), A(89))
        for host in (registry, *owners):
            for getter, value in (("core", self.core), ("operationCoordinator", coordinator)):
                self.add(host, getter + "()", (), (), ("address",), (value,))
            self.add(host, "deploymentChainId()", (), (), ("uint256",), (31337,))
        for host in (*owners, archive):
            self.add(host, "artistRegistry()", (), (), ("address",), (registry,))
            self.add(host, "operationCoordinator()", (), (), ("address",), (coordinator,))
        self.add(coordinator, "deploymentChainId()", (), (), ("uint256",), (31337,))
        self.add(coordinator, "suiteConfiguration()", (), (), (artist.SUITE,), (suite,))
        self.add(owners[0], "binding(uint256)", ("uint256",), (1,), (artist.BINDING,), (self.current_binding,))
        self.add(owners[0], "bindingAt(uint256,uint64)", ("uint256", "uint64"), (1, 1), (artist.BINDING,), (self.current_binding,))
        self.add(owners[2], "authorityState(bytes32)", ("bytes32",), (self.artist_id,),
            ("address", "uint8", "uint8", "bytes32"), (self.signer, 1, 1, self.registration_hash))
        self.add(owners[2], "operativeIdentityRecord(bytes32)", ("bytes32",), (self.artist_id,), ("bytes32",), (self.operative,))
        self.add(owners[2], "identityDocumentBytes(bytes32)", ("bytes32",), (self.operative,), ("bytes",), (self.identity_document,))
        for name, value in (("ARTIST_SALE_FACTS_READ_GAS", 500000), ("ARTIST_FINALITY_READ_GAS", 4000000)):
            self.add(registry, "gasParameterInfo(bytes32)", ("bytes32",), (K("6529STREAM_GGP_" + name),),
                ("uint256", "uint256", "uint8", "uint64"), (value, 100000, 2, 1))

    def _carrier(self, raw):
        pointer = A(self._next_pointer); self._next_pointer += 1
        self.codes[pointer] = b"\0" + raw
        self.pins[pointer] = keccak256(self.codes[pointer])
        return pointer

    def _artist_payload(self, owner, archive, kind, raw, block, *, pointer=None, between=None):
        pointer = self._carrier(raw) if pointer is None else pointer
        digest = keccak256(raw)
        for host in (owner, archive):
            rows = self._payloads.setdefault(host, [])
            index = len(rows); rows.append((pointer, kind, digest))
            self.add(host, "storedPayloadCount()", (), (), ("uint256",), (len(rows),))
            self.add(host, "storedPayloadAt(uint256)", ("uint256",), (index,), ("address", "bytes32", "bytes32"), rows[-1])
            self.event(block, host, [STORED_EVENT, H(index), kind, digest], ("uint16", "address"), (1, pointer))
            if host == owner and between is not None: between()
        return pointer

    def _definition(self, name, kind, raw):
        digest = keccak256(raw); pointer = self._carrier(raw)
        facts = (True, kind, 0, digest, RAW_BYTES, ZERO, len(raw), 1, K("definition declaration " + name))
        self.add(A(3), "documentFacts(bytes32)", ("bytes32",), (K(name),), (FACTS,), (facts,))
        self.add(A(3), "documentChunkHashAt(bytes32,uint256)", ("bytes32", "uint256"), (K(name), 0), ("bytes32",), (digest,))
        self.add(A(4), "chunk(bytes32)", ("bytes32",), (digest,), ("address", "uint32"), (pointer, len(raw)))
        self.add(A(4), "readChunk(bytes32)", ("bytes32",), (digest,), ("bytes",), (raw,))
        frozen = (facts[0], facts[1], *facts[3:])
        frozen_types = ("bool", "uint8", "bytes32", "bytes32", "bytes32", "uint32", "uint256", "bytes32")
        return keccak256(encode(frozen_types, frozen)), pointer

    def _general(self):
        # The General report's collection domain is intentionally distinct from the selected
        # native collection: the native proof joins identity, not an invented scope equality.
        cid = 7
        subject = (0, cid, 0, ZERO)
        value = notar.example()
        value.update(artistId=self.artist_id, operativeIdentityRecordHash=self.operative)
        payload = notar.canonical(value)
        stamp = int(self.blocks[H(201)]["timestamp"], 16)
        attestation = (self.recorder, cid, subject_id("collection", "31337", self.core, str(cid)), general.INSTITUTIONAL,
            "did:example:synthetic-signer", general.SCHEMA_ID, general.JCS_ID, "ipfs://synthetic-notarization",
            keccak256(payload), ZERO, ZERO, stamp)
        receipt = [self.recorder, 1, 1, stamp, 0, ZERO, ZERO, 37, stamp + 100, general.EIP712, ZERO,
            notar.SCHEMA_HASH, general.JCS_HASH, notar.PROFILE_HASH, ZERO, 0, 0, 0, self.origin_registry,
            self.pins[self.origin_registry], self.artist_id, self.operative, ZERO, 0]
        words = general.signed_words(attestation, payload, receipt)
        bundle = encode(("bytes32", ("bytes32",) * 15, "bytes"),
            (general.domain(31337, self.notary), decode(("bytes32",) * 15, words), b"s" * 65))
        receipt[6] = keccak256(b"\x19\x01" + hex_bytes(general.domain(31337, self.notary)) + hex_bytes(keccak256(words)))
        receipt[10] = keccak256(bundle)
        digest = general.native_record_hash(31337, self.notary, attestation, tuple(receipt))
        receipt[5] = general.chain_hash(cid, general.INSTITUTIONAL, ZERO, digest, 0)
        receipt = tuple(receipt)
        payload_pointer, bundle_pointer = self._carrier(payload), self._carrier(bundle)
        self.general_record = (digest, attestation, receipt, subject, payload, bundle)
        for signature, inputs, values, outputs, returned in (
                ("attestation(bytes32)", ("bytes32",), (digest,), (general.ATTESTATION, general.RECEIPT), (attestation, receipt)),
                ("recordSubject(bytes32)", ("bytes32",), (digest,), (general.SUBJECT,), (subject,)),
                ("recordHashAt(uint256,bytes32,uint256)", ("uint256", "bytes32", "uint256"), (cid, general.INSTITUTIONAL, 0), ("bytes32",), (digest,)),
                ("recordPayload(bytes32)", ("bytes32",), (digest,), ("address", "bytes"), (payload_pointer, payload)),
                ("recordSignatureBundle(bytes32)", ("bytes32",), (digest,), ("address", "bytes"), (bundle_pointer, bundle))):
            self.add(self.notary, signature, inputs, values, outputs, returned)
        head = digest
        self.add(self.notary, "latestAttestationHashFor(uint256,bytes32,bytes32,address)",
            ("uint256", "bytes32", "bytes32", "address"), (cid, general.INSTITUTIONAL, attestation[2], self.recorder), ("bytes32",), (head,))
        for getter, kind, returned in (("core", "address", self.core), ("coreCodeHash", "bytes32", self.pins[self.core]),
                ("artistRegistry", "address", self.origin_registry), ("schemaRegistry", "address", A(3)),
                ("schemaRegistryCodeHash", "bytes32", self.pins[A(3)]), ("chunkStore", "address", A(4)),
                ("chunkStoreCodeHash", "bytes32", self.pins[A(4)]), ("streamModuleType", "bytes32", K("GENERAL_ATTESTATIONS")),
                ("streamModuleVersion", "bytes32", K("6529stream.general-attestations.v2"))):
            self.add(self.notary, getter + "()", (), (), (kind,), (returned,))
        self.add(A(3), "chunkStore()", (), (), ("address",), (A(4),))
        self.module = (1, K("GENERAL_ATTESTATIONS"), K("6529stream.general-attestations.v2"), "0xb4afac56", 4000000,
            self.pins[self.notary], K("module deployment"), K("module manifest"), "ipfs://synthetic-module", stamp - 1, stamp - 1, 1)
        self.add(self.modules, "moduleRecord(address)", ("address",), (self.notary,), (MODULE,), (self.module,))
        self.general_event = self.event(1, self.notary, [GENERAL_EVENT, H(cid), general.INSTITUTIONAL, attestation[2]],
            ("bytes32", "address", "uint8", "uint8", "bytes32", "bytes32", "uint16"), (digest, self.recorder, 1, 1, ZERO, receipt[5], 1))
        if self.personhood_mode in ("stale_head", "other_recorder"):
            later_recorder = self.recorder if self.personhood_mode == "stale_head" else A(13003)
            self.later_general_hash = self._later_general(later_recorder)
            if later_recorder == self.recorder: head = self.later_general_hash
        return payload_pointer, bundle_pointer, head

    def _later_general(self, recorder, *, block=4):
        original_hash, original, receipt, subject, payload, _bundle = self.general_record
        stamp = int(self.blocks[H(200 + block)]["timestamp"], 16)
        attestation = (recorder, *original[1:9], original_hash if recorder == self.recorder else ZERO, ZERO, stamp)
        later = list(receipt)
        later[0], later[3], later[4], later[5], later[7], later[8] = recorder, stamp, 1, ZERO, 38, stamp + 100
        words = general.signed_words(attestation, payload, tuple(later))
        bundle = encode(("bytes32", ("bytes32",) * 15, "bytes"),
            (general.domain(31337, self.notary), decode(("bytes32",) * 15, words), b"t" * 65))
        later[6] = keccak256(b"\x19\x01" + hex_bytes(general.domain(31337, self.notary)) + hex_bytes(keccak256(words)))
        later[10] = keccak256(bundle)
        digest = general.native_record_hash(31337, self.notary, attestation, tuple(later))
        later[5] = general.chain_hash(original[1], original[3], receipt[5], digest, 1)
        self.add(self.notary, "attestation(bytes32)", ("bytes32",), (digest,),
            (general.ATTESTATION, general.RECEIPT), (attestation, tuple(later)))
        self.add(self.notary, "recordHashAt(uint256,bytes32,uint256)", ("uint256", "bytes32", "uint256"),
            (original[1], original[3], 1), ("bytes32",), (digest,))
        self.add(self.notary, "latestAttestationHashFor(uint256,bytes32,bytes32,address)",
            ("uint256", "bytes32", "bytes32", "address"), (original[1], original[3], original[2], recorder), ("bytes32",), (digest,))
        self.later_general_event = self.event(block, self.notary, [GENERAL_EVENT, H(original[1]), original[3], original[2]],
            source.GENERAL_DATA, (digest, recorder, 1, 1, attestation[9], later[5], 1))
        return digest

    def _native_personhood(self):
        mode = self.personhood_mode
        waiver = mode in ("waiver", "imported_waiver")
        proof = not waiver and mode != "legacy"
        if proof:
            payload_pointer, bundle_pointer, notary_head = self._general()
            digest, attestation, receipt, subject, payload, bundle = self.general_record
            self.reference = (1, REFERENCE_HASH, self.origin_registry, self.artist_id, self.operative,
                self.notary, self.pins[self.notary], digest)
            self.statement = self._reference_statement()
        else:
            self.statement = b"synthetic original explicit waiver" if waiver else b"opaque historical evidence"
        stamp = int(self.blocks[H(202)]["timestamp"], 16)
        schema = WAIVER if waiver else EVIDENCE
        self.native_nonce = 41
        self.preimage_values = (K("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"), 31337, self.origin_registry, self.core, 1, 10,
            self.artist_id, self.operative, schema, keccak256(self.statement), K("ipfs://original-personhood"), self.artist_id,
            self.signer, self.native_authority_class, self.native_nonce, stamp)
        self.native_preimage = encode(NATIVE_PREIMAGE, self.preimage_values)
        self.native_hash = keccak256(self.native_preimage)
        self.native_record = (self.native_hash, self.operative, schema, keccak256(self.statement), 1, stamp, self.signer)
        self.native_signature = b"synthetic-original-Artist-signature"
        self.statement_pointer = self._artist_payload(self.origin_owners[4], self.origin_archive,
            K("ARTIST_PUBLICATION_STATEMENT"), self.statement, 2)
        self.native_event = self.event(2, self.origin_owners[4],
            [artist.ATTESTED, H(1), H(10), self.topic("address", self.signer)],
            ("uint16", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint8", "uint256", "uint64", "bytes32"),
            (1, self.artist_id, self.operative, schema, keccak256(self.statement), self.preimage_values[10],
                self.native_authority_class, self.native_nonce, stamp, self.native_hash))
        if proof:
            definitions = ((notar.SCHEMA_NAME, 0, notar.SCHEMA_BYTES), (notar.PROFILE_NAME, 2, notar.PROFILE_BYTES),
                ("RFC8785_JCS", 1, general.JCS_BYTES), ("STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1", 2,
                    documentary.PROFILE_BYTES))
            installed = [self._definition(*row) for row in definitions]
            self.definition_hashes = tuple(row[0] for row in installed)
            carriers = (payload_pointer, bundle_pointer, *[row[1] for row in installed])
            module_hash = keccak256(encode(("bytes32", "bytes32", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"),
                (*self.module[1:4], *self.module[5:8], keccak256(self.module[8].encode()), self.module[9])))
            documentary_hash = keccak256(encode(("bytes32", "uint256", "address", REFERENCE, general.ATTESTATION,
                general.RECEIPT, "bytes32", "bytes32", "address", "bytes32", "address", "bytes32", ("bytes32",) * 4),
                (DOC_TAG, 31337, self.core, self.reference, attestation, receipt, keccak256(encode((general.SUBJECT,), (subject,))),
                keccak256(encode(("bytes", "bytes"), (payload, bundle))), A(3), self.pins[A(3)], A(4), self.pins[A(4)], self.definition_hashes)))
            self.summary = (1, 31337, self.native_hash, keccak256(self.statement), self.artist_id, self.binding_hash, 1, 1,
                self.operative, self.reference, self.pins[self.origin_registry], self.core, self.pins[self.core], self.modules,
                self.pins[self.modules], A(3), self.pins[A(3)], A(4), self.pins[A(4)], self.definition_hashes,
                attestation[1], attestation[3], attestation[2], self.recorder, documentary_hash, module_hash,
                tuple(carriers), tuple(self.pins[address] for address in carriers))
            raw = encode(("bytes32", SUMMARY), (SUMMARY_TAG, self.summary))
            self.summary_hash = keccak256(raw)
            def retained():
                self.retained_event = self.event(2, self.origin_owners[4],
                    [SUMMARY_EVENT, self.native_hash, self.topic("address", self.origin_registry)],
                    ("uint16", "bytes32", SUMMARY), (1, self.summary_hash, self.summary))
            self.summary_pointer = self._artist_payload(self.origin_owners[4], self.origin_archive,
                K("ARTIST_PERSONHOOD_PROOF_SUMMARY"), raw, 2, between=retained)
            if mode == "imported":
                self._artist_payload(self.owners[4], self.archive, K("ARTIST_PUBLICATION_STATEMENT"), self.statement, 4, pointer=self.statement_pointer)
                def imported():
                    self.import_event = self.event(4, self.owners[4], [SUMMARY_EVENT, self.native_hash, self.topic("address", self.origin_registry)],
                        ("uint16", "bytes32", SUMMARY), (1, self.summary_hash, self.summary))
                self._artist_payload(self.owners[4], self.archive, K("ARTIST_PERSONHOOD_PROOF_SUMMARY"), raw, 4,
                    pointer=self.summary_pointer, between=imported)
        elif mode == "imported_waiver":
            self._artist_payload(self.owners[4], self.archive, K("ARTIST_PUBLICATION_STATEMENT"), self.statement, 4,
                pointer=self.statement_pointer)
        for owners in dict.fromkeys((self.origin_owners, self.owners)):
            self.add(owners[4], "attestationRecord(bytes32)", ("bytes32",), (self.native_hash,), (artist.ATTESTATION_RECORD,), (self.native_record,))
            self.add(owners[4], "statementBytes(bytes32)", ("bytes32",), (keccak256(self.statement),), ("bytes",), (self.statement,))
            self.add(owners[4], "attestationAuthorityClass(bytes32)", ("bytes32",), (self.native_hash,), ("uint8",), (self.native_authority_class,))
            self.add(owners[4], "personhoodProofSummary(bytes32)", ("bytes32",), (self.native_hash,), (SUMMARY,), (self.summary,))
            self.add(owners[4], "personhoodProofSummaryHash(bytes32)", ("bytes32",), (self.native_hash,), ("bytes32",), (self.summary_hash,))
            self.add(owners[2], "signatureBundle(bytes32)", ("bytes32",), (self.native_hash,), ("bytes",), (self.native_signature,))
        self._selection(1 if waiver else 4 if mode == "legacy" else 3 if mode == "stale_head" else 2,
            notary_head=notary_head if proof else ZERO)

    def _reference_statement(self):
        return dumps({"artistId": self.artist_id, "artistRegistry": self.origin_registry,
            "notarizationHost": self.notary, "notarizationRecordHash": self.reference[7], "notarizationRuntimeHash": self.pins[self.notary],
            "operativeIdentityRecordHash": self.operative, "profileHash": REFERENCE_HASH, "version": 1})

    def _selection(self, status, *, notary_head=ZERO):
        proof = self.summary[0] == 1
        self.selected = (self.native_record, self.origin_registry if status else ZERO_ADDRESS, self.reference,
            general.INSTITUTIONAL if proof else ZERO, self.recorder if proof else ZERO_ADDRESS, notary_head,
            status != 0, proof and status == 2, status)
        self.add(self.owners[4], "personhoodEvidence(uint256,bytes32)", ("uint256", "bytes32"), (1, self.artist_id,), (SELECTION,), (self.selected,))
        self.add(self.owners[4], "personhoodEvidenceStatus(uint256,bytes32)", ("uint256", "bytes32"), (1, self.artist_id,),
            ("bytes32", "uint8"), (self.native_record[0], status))
        self.add(self.owners[4], "personhoodAttestation(uint256,bytes32)", ("uint256", "bytes32"), (1, self.artist_id,),
            (artist.ATTESTATION_RECORD,), (self.native_record,))

    def source(self, **kwargs): return source.PublicPersonhoodSource(dumps(self.a), self, **kwargs)

    def result(self): return loads(self.source().snapshot(), maximum=source.MAX_OUTPUT)

    def set_selected(self, selected):
        self.selected = selected
        self.add(self.owners[4], "personhoodEvidence(uint256,bytes32)", ("uint256", "bytes32"),
            (1, self.artist_id), (SELECTION,), (selected,))
        self.add(self.owners[4], "personhoodEvidenceStatus(uint256,bytes32)", ("uint256", "bytes32"),
            (1, self.artist_id), ("bytes32", "uint8"), (selected[0][0], selected[-1]))

    def repin_code(self, address, raw):
        self.codes[address] = raw; self.pins[address] = keccak256(raw)
        for row in self.a["codePins"]:
            if row["address"] == address: row["runtimeHash"] = self.pins[address]

    def reorder_logs(self, block, logs):
        self.receipts[H(400 + block)]["logs"] = logs
        for index, event in enumerate(logs): event["logIndex"] = hex(index)

    def append_local_waiver(self, *, select=False):
        """Add a later coherent fresh local op24; older originals remain independently readable."""
        stamp = int(self.blocks[H(204)]["timestamp"], 16)
        statement = b"synthetic later locally signed explicit waiver"
        preimage = (K("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"), 31337, self.registry, self.core, 1, 10,
            self.artist_id, self.operative, WAIVER, keccak256(statement), K("ipfs://later-local-waiver"),
            self.artist_id, self.signer, 1, 44, stamp)
        digest = keccak256(encode(NATIVE_PREIMAGE, preimage))
        record = (digest, self.operative, WAIVER, keccak256(statement), 1, stamp, self.signer)
        self._artist_payload(self.owners[4], self.archive, K("ARTIST_PUBLICATION_STATEMENT"), statement, 4)
        event = self.event(4, self.owners[4], [artist.ATTESTED, H(1), H(10), self.topic("address", self.signer)],
            source.ATTESTED_DATA, (1, *preimage[6:11], preimage[13], preimage[14], preimage[15], digest))
        self.add(self.owners[4], "attestationRecord(bytes32)", ("bytes32",), (digest,), (artist.ATTESTATION_RECORD,), (record,))
        self.add(self.owners[4], "statementBytes(bytes32)", ("bytes32",), (record[3],), ("bytes",), (statement,))
        self.add(self.owners[4], "attestationAuthorityClass(bytes32)", ("bytes32",), (digest,), ("uint8",), (1,))
        self.add(self.owners[4], "personhoodProofSummary(bytes32)", ("bytes32",), (digest,), (SUMMARY,), (zero(SUMMARY),))
        self.add(self.owners[4], "personhoodProofSummaryHash(bytes32)", ("bytes32",), (digest,), ("bytes32",), (ZERO,))
        self.add(self.owners[2], "signatureBundle(bytes32)", ("bytes32",), (digest,), ("bytes",), (b"original later local signature",))
        if select:
            self.set_selected((record, self.registry, zero(REFERENCE), ZERO, ZERO_ADDRESS, ZERO, True, False, 1))
            self.add(self.owners[4], "personhoodAttestation(uint256,bytes32)", ("uint256", "bytes32"),
                (1, self.artist_id), (artist.ATTESTATION_RECORD,), (record,))
        self.a["codePins"] = [{"address": address, "runtimeHash": digest} for address, digest in sorted(self.pins.items())]
        return record, preimage, event


class PublicPersonhoodFixture(PublicPersonhoodMixin, PublicConservationProviderFixture):
    """Synthetic original Artist/General joins sharing the provider/RIGHTS/floor response map."""
    def __init__(self, *, mode="resolved"):
        PublicConservationProviderFixture.__init__(self)
        self.setup_personhood(mode=mode)


class PublicPersonhoodSourceTests(unittest.TestCase):
    def test_concrete_modes_replay_without_network_or_native_acceptance(self):
        for mode in ("none", "waiver", "resolved", "legacy", "stale_head", "other_recorder", "imported", "imported_waiver"):
            with self.subTest(mode=mode):
                fixture = PublicPersonhoodFixture(mode=mode)
                adapter = fixture.source(); raw = adapter.snapshot(); transcript = adapter.transcript()
                with patch("socket.socket", side_effect=AssertionError("synthetic offline replay only")):
                    replay = source.PublicPersonhoodSource(adapter.anchor_bytes, PublicReplayTransport(transcript, keccak256(transcript)))
                    self.assertEqual(replay.snapshot(), raw)

    def test_resolved_original_bytes_hash_domains_and_authority_are_separate(self):
        f = PublicPersonhoodFixture(); value = f.result()
        native, current, doc = value["native"], value["current"], value["documentary"]
        self.assertEqual(current["status"], "RESOLVED")
        self.assertEqual(current["registrationIdentityRecordHash"], f.registration_hash)
        self.assertEqual(current["operativeIdentityRecordHash"], f.operative)
        self.assertNotEqual(f.registration_hash, f.operative)
        self.assertEqual(native["recordPreimageHex"], "0x" + f.native_preimage.hex())
        self.assertEqual(native["statementHex"], "0x" + f.statement.hex())
        self.assertEqual(native["signatureHex"], "0x" + f.native_signature.hex())
        self.assertEqual(native["recordHash"], keccak256(hex_bytes(native["recordPreimageHex"])))
        self.assertEqual(current["evidenceHash"], f.summary_hash)
        self.assertNotEqual(current["evidenceHash"], f.native_hash)
        self.assertNotEqual(current["evidenceHash"], doc["documentaryHash"])
        self.assertEqual(current["evidenceHashDomain"], "personhood_proof_summary")
        self.assertEqual(native["authorization"]["authorityClass"], "1")
        self.assertEqual(native["authorization"]["nonce"], str(f.native_nonce))
        self.assertFalse(native["authorization"]["signatureCryptographyRevalidated"])
        self.assertEqual(doc["payloadHex"], "0x" + f.general_record[4].hex())
        self.assertEqual(doc["signatureBundleHex"], "0x" + f.general_record[5].hex())
        self.assertEqual(len(doc["definitions"]), 4)
        self.assertEqual(len(doc["carriers"]), 6)
        self.assertEqual(doc["attestation"][1], "7")
        self.assertEqual(native["summary"][7], "1")
        self.assertEqual(value["provenance"], "synthetic_fixture")
        for claim in ("actualChainAcceptance", "personhoodProven", "institutionalStandingProven",
                "completePersonhoodHistory", "currentSignatureRevalidation", "completeAcquisitionPacket"):
            self.assertFalse(value["claims"][claim])

    def test_none_waiver_and_opaque_evidence_do_not_manufacture_documentary_proof(self):
        none = PublicPersonhoodFixture(mode="none").result()
        self.assertEqual(none["current"]["status"], "NONE")
        self.assertIsNone(none["native"]); self.assertIsNone(none["documentary"])
        for mode in ("waiver", "legacy"):
            f = PublicPersonhoodFixture(mode=mode); value = f.result()
            self.assertIsNone(value["documentary"])
            self.assertEqual(value["native"]["summaryHash"], ZERO)
            self.assertEqual(value["native"]["statementHex"], "0x" + f.statement.hex())
            self.assertEqual(value["current"]["evidenceHash"], f.native_hash if mode == "waiver" else ZERO)
            self.assertEqual(value["current"]["status"], "WAIVER" if mode == "waiver" else "UNRESOLVED")
        self.assertTrue(value["current"]["identityCurrent"])

    def test_same_recorder_supersedes_but_another_recorder_does_not(self):
        for mode in ("stale_head", "other_recorder"):
            f = PublicPersonhoodFixture(mode=mode); value = f.result()
            self.assertEqual(value["current"]["status"], "STALE" if mode == "stale_head" else "RESOLVED")
            self.assertEqual(value["native"]["recordHash"], f.native_hash)
            self.assertEqual(value["documentary"]["recordHash"], f.general_record[0])
            self.assertEqual(value["documentary"]["recorderHistory"]["eventCount"], "2")
            self.assertEqual(len(value["documentary"]["recorderHistory"]["latestByRecorder"]), 1 if mode == "stale_head" else 2)
            self.assertNotEqual(f.later_general_hash, f.general_record[0])

    def test_import_uses_original_event_signing_domain_and_identical_summary(self):
        f = PublicPersonhoodFixture(mode="imported"); value = f.result(); native = value["native"]
        self.assertEqual(value["graph"]["current"]["registry"], f.registry)
        self.assertEqual(native["originalRegistry"], f.origin_registry)
        self.assertEqual(native["publication"]["blockNumber"], "2")
        self.assertEqual([r["publication"]["blockNumber"] for r in native["summaryRetentions"]], ["2", "4"])
        self.assertEqual(len(native["summaryCarriers"]), 4)
        domain = decode(("bytes32", "bytes32", "bytes32", "uint256", "address"), hex_bytes(native["authorization"]["domainHex"]))
        self.assertEqual(domain[-1], f.origin_registry)
        self.assertNotEqual(domain[-1], f.registry)
        self.assertEqual(native["recordPreimageHex"], "0x" + f.native_preimage.hex())

    def test_current_rotation_preserves_original_proof_without_reviving_it(self):
        f = PublicPersonhoodFixture(); changed = (*f.current_binding[:4], 2, *f.current_binding[5:])
        f.add(f.owners[0], "binding(uint256)", ("uint256",), (1,), (artist.BINDING,), (changed,))
        f.add(f.owners[2], "operativeIdentityRecord(bytes32)", ("bytes32",), (f.artist_id,), ("bytes32",), (K("later operative identity"),))
        f.set_selected((*f.selected[:6], False, True, 3))
        value = f.result()
        self.assertEqual(value["current"]["status"], "STALE")
        self.assertFalse(value["current"]["identityCurrent"])
        self.assertEqual(value["current"]["evidenceHash"], ZERO)
        self.assertEqual(value["native"]["originalBinding"][4], "1")
        self.assertEqual(value["native"]["record"][1], f.operative)
        self.assertEqual(value["documentary"]["recordHash"], f.general_record[0])

    def test_native_unresolved_is_not_upgraded_by_successful_documentary_reads(self):
        f = PublicPersonhoodFixture()
        f.set_selected((*f.selected[:3], ZERO, ZERO_ADDRESS, ZERO, False, False, 4))
        value = f.result()
        self.assertEqual(value["current"]["status"], "UNRESOLVED")
        self.assertEqual(value["current"]["evidenceHash"], ZERO)
        self.assertIsNotNone(value["documentary"])
        self.assertEqual(value["native"]["summaryHash"], f.summary_hash)

    def test_opaque_origin_absence_never_invents_native_signing_domain(self):
        f = PublicPersonhoodFixture(mode="legacy")
        # An old import can retain opaque bytes with no original-domain metadata.
        # It does not emit a fresh op24 from the current owner.
        f.reorder_logs(2, [event for event in f.receipts[H(402)]["logs"] if event is not f.native_event])
        f.set_selected((f.selected[0], ZERO_ADDRESS, *f.selected[2:]))
        value = f.result()
        self.assertEqual(value["current"]["status"], "UNRESOLVED")
        self.assertEqual(value["native"]["statementHex"], "0x" + f.statement.hex())
        self.assertEqual(value["native"]["originalOp24Correspondence"], "origin_unavailable")
        for key in ("authorization", "recordPreimageHex", "originalBinding", "signatureHex", "publication"):
            self.assertIsNone(value["native"][key])

    def test_newer_unrelated_kind10_attestation_does_not_replace_personhood_head(self):
        f = PublicPersonhoodFixture(); later = list(f.preimage_values)
        later[8], later[9], later[14], later[15] = K("synthetic C2PA schema"), K("synthetic C2PA statement"), 42, int(f.blocks[H(204)]["timestamp"], 16)
        digest = keccak256(encode(NATIVE_PREIMAGE, later))
        f.event(4, f.owners[4], [artist.ATTESTED, H(1), H(10), f.topic("address", f.signer)], source.ATTESTED_DATA,
            (1, *later[6:11], later[13], later[14], later[15], digest))
        generic = (digest, f.operative, later[8], later[9], 1, later[15], f.signer)
        f.add(f.owners[4], "attestation(uint256,uint8,bytes32)", ("uint256", "uint8", "bytes32"),
            (1, 10, f.artist_id), (artist.ATTESTATION_RECORD,), (generic,))
        value = f.result()
        self.assertEqual(value["native"]["recordHash"], f.native_hash)
        self.assertEqual(value["current"]["status"], "RESOLVED")
        generic_call = calldata("attestation(uint256,uint8,bytes32)", ("uint256", "uint8", "bytes32"), (1, 10, f.artist_id))
        self.assertFalse(any(m == "eth_call" and p[0]["data"] == generic_call for m, p in f.requested))

    def test_canonical_but_different_statement_reference_is_rejected_after_rehash(self):
        class ChangedReference(PublicPersonhoodFixture):
            def _reference_statement(self):
                value = loads(super()._reference_statement()); value["notarizationRecordHash"] = K("different original")
                return dumps(value)
        f = ChangedReference()
        self.assertEqual(keccak256(f.statement), f.native_record[3])
        self.assertEqual(f.summary[3], f.native_record[3])
        self.assertEqual(keccak256(f.native_preimage), f.native_hash)
        with self.assertRaisesRegex(MuseumError, "statement/reference differs"):
            f.result()

    def test_original_op24_nonce_signer_class_and_import_domain_cannot_be_substituted(self):
        for mutation in ("nonce", "signer", "class", "registry"):
            f = PublicPersonhoodFixture(mode="imported")
            if mutation == "signer": f.native_event["topics"][3] = f.topic("address", A(12999))
            elif mutation == "registry":
                f.set_selected((f.selected[0], f.registry, *f.selected[2:]))
            elif mutation == "class":
                f.add(f.origin_owners[4], "attestationAuthorityClass(bytes32)", ("bytes32",), (f.native_hash,), ("uint8",), (3,))
            else:
                values = list(decode(source.ATTESTED_DATA, hex_bytes(f.native_event["data"]))); values[7] += 1
                f.native_event["data"] = "0x" + encode(source.ATTESTED_DATA, values).hex()
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): f.result()

    def test_original_native_class4_is_retained_without_current_authority_revalidation(self):
        class OriginalClass4(PublicPersonhoodFixture):
            native_authority_class = 4
        f = OriginalClass4(); value = f.result()
        self.assertEqual(value["native"]["authorization"]["authorityClass"], "4")
        self.assertEqual(value["native"]["recordHash"], keccak256(f.native_preimage))
        self.assertEqual(value["native"]["signatureHex"], "0x" + f.native_signature.hex())
        self.assertFalse(value["native"]["authorization"]["signatureCryptographyRevalidated"])
        for invalid in (0, 5):
            class InvalidClass(PublicPersonhoodFixture):
                native_authority_class = invalid
            with self.subTest(invalid=invalid), self.assertRaises(MuseumError): InvalidClass().result()

    def test_original_general_reference_must_be_latest_for_its_recorder_before_op24(self):
        class SameBlockSuccessor(PublicPersonhoodFixture):
            def _later_general(self, recorder, **kwargs):
                return super()._later_general(recorder, block=2)
        before = SameBlockSuccessor(mode="stale_head")
        self.assertLess(int(before.later_general_event["logIndex"], 16), int(before.native_event["logIndex"], 16))
        with self.assertRaises(MuseumError): before.result()
        after = SameBlockSuccessor(mode="stale_head")
        logs = after.receipts[H(402)]["logs"]; logs.remove(after.later_general_event); logs.append(after.later_general_event)
        after.reorder_logs(2, logs)
        value = after.result()
        self.assertEqual(value["current"]["status"], "STALE")
        self.assertEqual(value["documentary"]["recordHash"], after.general_record[0])
        self.assertEqual(value["documentary"]["recorderHistory"]["eventCount"], "2")

    def test_original_summary_cannot_be_published_in_a_later_transaction(self):
        f = PublicPersonhoodFixture()
        original_logs = f.receipts[H(402)]["logs"]
        moved = [event for event in original_logs if event is f.retained_event or
            event["topics"][0] == STORED_EVENT and event["topics"][2] == source.SUMMARY_TYPE]
        self.assertEqual(len(moved), 3)
        f.reorder_logs(2, [event for event in original_logs if event not in moved])
        destination = f.receipts[H(404)]
        for event in moved:
            event.update({key: destination[key] for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex")})
        f.reorder_logs(4, [*destination["logs"], *moved])
        # All carrier bytes, native hash, summary hash, index getters and relative summary
        # order remain valid; only the original atomic op24 transaction is contradicted.
        with self.assertRaises(MuseumError): f.result()

    def test_none_cannot_conceal_observed_current_owner_personhood_publication(self):
        for mode in ("resolved", "waiver"):
            f = PublicPersonhoodFixture(mode=mode)
            f.set_selected(zero(SELECTION))
            f.add(f.owners[4], "personhoodAttestation(uint256,bytes32)", ("uint256", "bytes32"),
                (1, f.artist_id), (artist.ATTESTATION_RECORD,), (zero(artist.ATTESTATION_RECORD),))
            with self.subTest(mode=mode), self.assertRaises(MuseumError): f.result()

    def test_none_preserved_with_other_schema_or_other_artist_publication(self):
        for kind in ("credential_only", "different_artist"):
            f = PublicPersonhoodFixture(mode="none")
            selected_artist = f.artist_id
            original_artist = selected_artist if kind == "credential_only" else K("different original Artist")
            schema = K("synthetic credential-only C2PA schema") if kind == "credential_only" else EVIDENCE
            stamp = int(f.blocks[H(202)]["timestamp"], 16)
            preimage = (K("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"), 31337, f.registry, f.core, 1, 10,
                original_artist, f.operative, schema, K("original unrelated statement"), K("ipfs://unrelated-original"),
                original_artist, f.signer, 1, 43, stamp)
            digest = keccak256(encode(NATIVE_PREIMAGE, preimage))
            event = f.event(2, f.owners[4], [artist.ATTESTED, H(1), H(10), f.topic("address", f.signer)],
                source.ATTESTED_DATA, (1, *preimage[6:11], preimage[13], preimage[14], preimage[15], digest))
            value = f.result()
            with self.subTest(kind=kind):
                self.assertEqual(decode(source.ATTESTED_DATA, hex_bytes(event["data"]))[-1], digest)
                self.assertEqual(value["current"]["artistId"], selected_artist)
                self.assertEqual(value["current"]["status"], "NONE")
                self.assertEqual(value["current"]["evidenceHash"], ZERO)
                self.assertIsNone(value["native"])
                self.assertIsNone(value["documentary"])
                self.assertFalse(value["claims"]["completePersonhoodHistory"])

    def test_latest_local_personhood_event_controls_local_or_imported_current_head(self):
        for mode in ("resolved", "waiver", "imported", "imported_waiver"):
            stale = PublicPersonhoodFixture(mode=mode)
            prior = stale.native_hash
            later, preimage, event = stale.append_local_waiver()
            self.assertNotEqual(later[0], prior)
            self.assertEqual(later[0], keccak256(encode(NATIVE_PREIMAGE, preimage)))
            with self.subTest(mode=mode, selected="older"), self.assertRaisesRegex(MuseumError, "latest local personhood"):
                stale.result()
            current = PublicPersonhoodFixture(mode=mode)
            later, preimage, event = current.append_local_waiver(select=True)
            value = current.result()
            with self.subTest(mode=mode, selected="latest"):
                self.assertEqual(value["current"]["status"], "WAIVER")
                self.assertEqual(value["current"]["evidenceHash"], later[0])
                self.assertEqual(value["native"]["originalRegistry"], current.registry)
                self.assertEqual(value["native"]["recordPreimageHex"], "0x" + encode(NATIVE_PREIMAGE, preimage).hex())
                self.assertEqual(value["native"]["publication"]["blockNumber"], "4")

    def test_later_original_owner_observation_does_not_reselect_an_imported_head(self):
        for mode in ("imported", "imported_waiver"):
            f = PublicPersonhoodFixture(mode=mode)
            preimage = list(f.preimage_values)
            preimage[8], preimage[9] = WAIVER, K("later original-domain waiver statement")
            preimage[14], preimage[15] = 49, int(f.blocks[H(205)]["timestamp"], 16)
            digest = keccak256(encode(NATIVE_PREIMAGE, preimage))
            f.event(5, f.origin_owners[4], [artist.ATTESTED, H(1), H(10), f.topic("address", f.signer)],
                source.ATTESTED_DATA, (1, *preimage[6:11], preimage[13], preimage[14], preimage[15], digest))
            value = f.result()
            with self.subTest(mode=mode):
                self.assertEqual(value["native"]["recordHash"], f.native_hash)
                self.assertEqual(value["native"]["originalRegistry"], f.origin_registry)
                self.assertNotEqual(value["native"]["recordHash"], digest)
                self.assertFalse(any(event["address"] == f.owners[4] and event["topics"][0] == artist.ATTESTED
                    for receipt in f.receipts.values() for event in receipt["logs"]))
                self.assertEqual(value["current"]["status"], "RESOLVED" if mode == "imported" else "WAIVER")

    def test_original_binding_and_current_status_contradictions_rejected(self):
        for mutation in ("original", "compact", "identity", "recorder", "none"):
            f = PublicPersonhoodFixture()
            if mutation == "original":
                row = (K("foreign artist"), *f.current_binding[1:])
                f.add(f.origin_owners[0], "bindingAt(uint256,uint64)", ("uint256", "uint64"), (1, 1), (artist.BINDING,), (row,))
            elif mutation == "compact":
                f.add(f.owners[4], "personhoodEvidenceStatus(uint256,bytes32)", ("uint256", "bytes32"),
                    (1, f.artist_id), ("bytes32", "uint8"), (f.native_hash, 1))
            elif mutation == "identity": f.set_selected((*f.selected[:6], False, True, 2))
            elif mutation == "recorder": f.set_selected((*f.selected[:4], A(999), *f.selected[5:]))
            else: f.set_selected((*f.selected[:-1], 0))
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): f.result()

    def test_original_carrier_index_and_archive_bytes_rejected_even_with_new_runtime_pin(self):
        for mutation in ("statement", "summary", "catalogue"):
            f = PublicPersonhoodFixture()
            if mutation == "catalogue":
                f.add(f.origin_archive, "storedPayloadCount()", (), (), ("uint256",), (1,))
            else:
                pointer = f.statement_pointer if mutation == "statement" else f.summary_pointer
                raw = f.codes[pointer]; f.repin_code(pointer, raw[:-1] + bytes([raw[-1] ^ 1]))
            with self.subTest(mutation=mutation), self.assertRaisesRegex(MuseumError, "retained payload"):
                f.result()

    def test_missing_duplicate_and_out_of_order_original_events_rejected(self):
        for mutation in ("missing", "duplicate", "statement_after", "archive_before"):
            f = PublicPersonhoodFixture(); logs = f.receipts[H(402)]["logs"]
            if mutation == "missing": logs.remove(f.native_event)
            elif mutation == "duplicate": logs.append(deepcopy(f.retained_event))
            elif mutation == "statement_after":
                stored = next(e for e in logs if e["address"] == f.origin_owners[4] and e["topics"][:1] == [STORED_EVENT])
                logs.remove(stored); logs.append(stored)
            else:
                archive = next(e for e in logs if e["address"] == f.origin_archive and e["topics"][0] == STORED_EVENT
                    and e["topics"][2] == source.SUMMARY_TYPE)
                logs.remove(archive); logs.insert(logs.index(f.retained_event), archive)
            f.reorder_logs(2, logs)
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): f.result()

    def test_complete_recorder_event_history_cannot_hide_current_supersession(self):
        f = PublicPersonhoodFixture(mode="stale_head")
        logs = f.receipts[H(404)]["logs"]; logs.remove(f.later_general_event); f.reorder_logs(4, logs)
        with self.assertRaisesRegex(MuseumError, "recorder event/head differs"): f.result()

    def test_anchor_closed_admission_and_runtime_pins_fail_before_untrusted_rpc(self):
        for mutation in ("profile", "extra", "source", "provenance", "pin"):
            f = PublicPersonhoodFixture(); anchor = deepcopy(f.a)
            if mutation == "profile": anchor["profile"] = "STREAM_MUSEUM_PERSONHOOD_CALLER_COMPLETE"
            elif mutation == "extra": anchor["artistId"] = f.artist_id
            elif mutation == "source": anchor["runtimeAdmission"]["sourceCommit"] = "0" * 40
            elif mutation == "provenance": anchor["runtimeAdmission"]["kind"] = "externally_admitted_runtime"
            else: anchor["codePins"] = [r for r in anchor["codePins"] if r["address"] != f.registry]
            with self.subTest(mutation=mutation), patch.object(f, "request", side_effect=AssertionError("pre-RPC")), self.assertRaises(MuseumError):
                source.PublicPersonhoodSource(dumps(anchor), f).snapshot()
        f = PublicPersonhoodFixture(); f.codes[f.origin_owners[2]] = b"changed original Identity runtime"
        with self.assertRaisesRegex(MuseumError, "runtime/carrier differs"): f.result()

    def test_identical_query_conflict_and_replay_tamper_are_not_admitted(self):
        f = PublicPersonhoodFixture(); original_request = f.request; seen = 0
        def conflict(method, params):
            nonlocal seen
            result = original_request(method, params)
            if method == "eth_getBlockByHash" and params[0] == f.a["blockHash"]:
                seen += 1
                if seen > 1: result["stateRoot"] = K("contradictory same-block root")
            return result
        with patch.object(f, "request", side_effect=conflict), self.assertRaises(MuseumError): f.result()
        f = PublicPersonhoodFixture(); reader = f.source(); reader.snapshot(); raw = reader.transcript()
        with self.assertRaises(MuseumError): PublicReplayTransport(raw, K("wrong transcript pin"))

    def test_native_abi_widths_and_independent_hash_preimages(self):
        f = PublicPersonhoodFixture()
        self.assertEqual((REFERENCE, SUMMARY, SELECTION, FACTS),
            (documentary.REFERENCE, documentary.SUMMARY, documentary.SELECTION, documentary.DOCUMENT_FACTS))
        self.assertEqual((len(encode((REFERENCE,), (f.reference,))), len(encode((SUMMARY,), (f.summary,))),
            len(encode((SELECTION,), (f.selected,)))), (256, 1536, 704))
        self.assertEqual(len(f.statement), 590)
        self.assertEqual(len(f.native_preimage), 512)
        self.assertEqual(f.summary_hash, keccak256(encode(("bytes32", SUMMARY), (SUMMARY_TAG, f.summary))))
        self.assertEqual(len(f.codes[f.summary_pointer]), 1569)
        self.assertEqual(SUMMARY_EVENT, source.SUMMARY_EVENT)


if __name__ == "__main__": unittest.main()

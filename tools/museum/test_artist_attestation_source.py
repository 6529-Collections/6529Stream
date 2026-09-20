"""Synthetic pinned Artist/Metadata history controls, not native-chain acceptance."""
from copy import deepcopy
from pathlib import Path
import re
import subprocess
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id
from .chain_abi import encode
from .chain_rpc import ReplayTransport, RpcTransport
from . import artist_attestation_source as artist
from . import metadata_catalog_source as metadata
from .test_metadata_catalog_source import A, H, Fixture as MetadataFixture, Transport, record_pair


class Fixture(MetadataFixture):
    def __init__(self, *, rotated=False, disputed=False, delegated=False, successor=False, legacy=False, relayed=False, empty=False,
                 metadata_setup=None):
        super().__init__(empty=empty)
        if metadata_setup is not None:
            metadata_setup(self)
        if not empty:
            self.refresh_metadata()
        self.coordinator, self.archive = A(60), A(61)
        owners = tuple(A(40 + index) for index in range(7))
        self.suite = (A(5), self.archive, owners, A(2), A(62), A(63), A(64), A(65), A(66), H("primary-revenue-class"), A(67))
        self.configuration = H("immutable-native-suite-configuration")
        self.call("operationCoordinator()", ("address",), (self.coordinator,), target=A(5))
        self.call("suiteConfiguration()", (artist.SUITE,), (self.suite,), target=self.coordinator)
        self.call("deploymentChainId()", ("uint256",), (31337,), target=self.coordinator)
        self.call("configurationHash()", ("bytes32",), (self.configuration,), target=self.coordinator)
        targets = (*owners, A(5), self.archive, *self.suite[3:9], self.suite[10], self.coordinator)
        known = {row["address"] for row in self.anchor["codePins"]}
        for target in targets:
            if target not in known:
                raw = b"\x60" + hex_bytes(target)[-1:]
                self.anchor["codePins"].append({"address": target, "runtimeHash": keccak256(raw)})
                self.put("eth_getCode", [target, self.block_ref], "0x" + raw.hex())
        for target in (A(5), *owners):
            for getter, expected in (("core", A(2)), ("mintManager", A(62)), ("operationCoordinator", self.coordinator)):
                self.call(getter + "()", ("address",), (expected,), target=target)
        for index, target in enumerate(owners):
            for getter, expected in (("artistRegistry", A(5)), ("archiveV2", self.archive)):
                self.call(getter + "()", ("address",), (expected,), target=target)
            self.call("deploymentChainId()", ("uint256",), (31337,), target=target)
            self.call("domainId()", ("bytes32",), (artist.DOMAINS[index],), target=target)
        self.call("artistRegistry()", ("address",), (A(5),), target=self.archive)
        self.call("operationCoordinator()", ("address",), (self.coordinator,), target=self.archive)
        self.blocks = {n: {"hash": H("historical-block" + str(n)), "number": hex(n), "parentHash":
            H("historical-block" + str(n - 1)) if n else artist.ZERO, "timestamp": hex(90 + n),
            "stateRoot": H("historical-state" + str(n)), "transactions": []} for n in range(10)}
        self.blocks[6]["timestamp"] = hex(99); self.blocks[7]["timestamp"] = hex(99); self.blocks[8]["timestamp"] = hex(100)
        self.blocks[9] = self.block
        self.block.update(parentHash=self.blocks[8]["hash"], transactions=[])
        self.receipts = {}
        for block in self.blocks.values():
            self.put("eth_getBlockByHash", [block["hash"], False], block)
        if empty:
            return
        for digest, record, receipt, _ in self.rows[:-1]:
            self.log(6, A(1), [artist.METADATA_RECORDED, self.topic("uint256", 7), record[0], record[1]],
                encode((metadata.RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16"),
                    (record, digest, receipt[5], receipt[1], self.topic("uint8", receipt[2]), 1)))
        self.document = dumps({"displayName": "Same name is not proof of identity", "subject": "artist"})
        self.document_hash = keccak256(self.document)
        self.artist_id = artist._hash(("bytes32", "uint256", "address", "address", "bytes32", "uint256"),
            (schema_id("6529STREAM_ARTIST_ID_V1"), 31337, A(5), A(8), self.document_hash, 0))
        self.registration = self.log(1, owners[2], [artist.REGISTERED, self.artist_id, self.topic("address", A(8))],
            encode(("uint16", "bytes32", "string", "uint256"), (1, self.document_hash, "ipfs://identity", 0)))
        self.binding = (self.artist_id, A(8), self.document_hash, H("original-binding"), 1, 1, 0, 0, A(9), True)
        self.metadata_row = self.rows[-1]
        digest, record, receipt, payload = self.metadata_row
        authority_class = 2 if delegated else 3 if successor else 1
        signer = receipt[1]
        self.publication = (A(1), signer, 7, record[1], record[0], record[4], record[2][2], 1,
            keccak256(payload), keccak256(record[3].encode()), record[7], digest)
        self.statement = encode(("uint16", artist.PUBLICATION), (1, self.publication))
        self.terms = (7, 8, record[1], artist.ZERO, artist.PUBLICATION_SCHEMA, keccak256(self.statement), record[3])
        self.nonce, self.signed_at = 17, 99
        self.signature = b"native-original-signature" if relayed else b""
        self.actor = A(10) if relayed else signer
        self.authorization = keccak256(artist.attestation_preimage(31337, A(5), A(2), self.terms, self.artist_id,
            signer, authority_class, self.nonce, self.signed_at))
        new_receipt = (*receipt[:8], self.authorization)
        self.metadata_row = (digest, record, new_receipt, payload); self.rows[-1] = self.metadata_row
        self.record_response(self.metadata_row)
        self.call("consumedArtistAuthorization(bytes32)", ("bool",), (True,), ("bytes32",), (self.authorization,))
        self.publication_evidence = (self.authorization, self.artist_id, self.binding[3], 1, signer, authority_class, 1, 99,
            artist._hash((artist.PUBLICATION,), (self.publication,)))
        self.host_code = keccak256(b"\x60\x01")
        self.attestation = (self.authorization, self.terms[3], self.terms[4], self.terms[5], 1, 99, signer)
        self.call("publicationAttestation(bytes32)", (artist.PUBLICATION_RECORD,),
            ((self.publication, self.publication_evidence, self.host_code),), ("bytes32",), (self.authorization,), target=owners[4])
        self.call("attestationRecord(bytes32)", (artist.ATTESTATION_RECORD,), (self.attestation,), ("bytes32",), (self.authorization,), target=owners[4])
        self.call("statementBytes(bytes32)", ("bytes",), (self.statement,), ("bytes32",), (self.terms[5],), target=owners[4])
        self.call("signatureBundle(bytes32)", ("bytes",), (self.signature,), ("bytes32",), (self.authorization,), target=owners[2])
        self.call("attestationAuthorityClass(bytes32)", ("uint8",), (authority_class,), ("bytes32",), (self.authorization,), target=owners[4])
        self.attested = self.log(7, owners[4], [artist.ATTESTED, self.topic("uint256", 7), self.topic("uint8", 8), self.topic("address", signer)],
            encode(("uint16", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint8", "uint256", "uint64", "bytes32"),
                (1, *self.terms[2:6], self.publication[9], authority_class, self.nonce, 99, self.authorization)))
        self.effective = (self.nonce, 99, self.signature)
        self.submitted = (self.nonce, 99 if relayed else 0, self.signature)
        _, _, signed_digest = artist.signed_preimage(31337, A(5), A(2), self.terms, self.nonce, 99)
        self.proof = (signer, signed_digest, not relayed)
        self.authority = (self.artist_id, A(12) if delegated else signer, 1 if delegated else authority_class, 3 if successor else 1)
        self.grant = artist.ZERO
        delegation = ((artist.ZERO, artist.ZERO_ADDRESS, 0, 0, 0, 0, 0, artist.ZERO), artist.ZERO_ADDRESS, 0, 0, False, artist.ZERO)
        if delegated:
            terms = (self.artist_id, signer, 7, 1, 90, 200, 5, H("grant-constraints"))
            delegation = (terms, A(12), 9, 0, False, artist.ZERO)
            self.grant = artist._hash(("bytes32", "uint256", "address", *artist.GRANT, "uint256"),
                (schema_id("6529STREAM_ARTIST_DELEGATION_RECORD_V1"), 31337, A(5), *terms, 9))
            self.grant_event = self.log(2, owners[2], [artist.GRANTED, self.artist_id, self.topic("address", signer), self.topic("uint256", 7)],
                encode(("uint16", "uint32", "uint64", "uint64", "uint64", "bytes32", "uint256", "bytes32"), (1, *terms[3:], 9, self.grant)))
            self.delegate_event = self.log(7, owners[4], [artist.DELEGATED, self.authorization, self.grant, self.artist_id],
                encode(("uint16", "address"), (1, signer)))
            # Current revoked state is retained, never used to erase this prior use.
            self.call("delegationRecord(bytes32)", (artist.DELEGATION,), ((*delegation[:3], 1, True, H("later-revocation")),),
                ("bytes32",), (self.grant,), target=owners[2])
            self.call("delegatedNonceState(bytes32,address,uint256)", ("bool", "uint256"), (True, 18),
                ("bytes32", "address", "uint256"), (self.artist_id, signer, self.nonce), target=owners[2])
        else:
            self.call("nonceUsed(bytes32,uint256)", ("bool",), (True,), ("bytes32", "uint256"), (self.artist_id, self.nonce), target=owners[2])
        fact = (A(1), self.host_code, self.terms[2], self.terms[3])
        self.association = (self.artist_id, self.binding[3], 1, self.grant, fact)
        if legacy:
            self.association = (artist.ZERO, artist.ZERO, 0, artist.ZERO, (artist.ZERO_ADDRESS, artist.ZERO, artist.ZERO, artist.ZERO))
            self.payload = encode(artist.ORDINARY_PAYLOAD, (self.binding, self.terms, self.submitted, self.statement, self.proof,
                self.effective, self.authority, self.publication, self.host_code))
        else:
            admission = (self.authority, signer, self.nonce, 99, self.grant, artist.ZERO, fact)
            self.payload = encode(artist.AUTHENTICATED_PAYLOAD, (self.binding, self.terms, self.submitted, self.effective, self.proof,
                self.statement, (0, 0, artist.ZERO, artist.ZERO_ADDRESS), False, admission, delegation,
                encode((artist.PUBLICATION, "bytes32"), (self.publication, self.host_code))))
        self.call("attestationAssociation(bytes32)", (artist.ASSOCIATION,), (self.association,), ("bytes32",), (self.authorization,), target=owners[4])
        self.before = tuple((artist.DOMAINS[i], 1, H("before-state" + str(i)), H("before-record" + str(i)))
            if i in (0, 1, 2, 4) else (artist.ZERO, 0, artist.ZERO, artist.ZERO) for i in range(7))
        self.after = tuple((artist.DOMAINS[i], 2, H("after-state" + str(i)), H("after-record" + str(i)))
            if i in (2, 4) else self.before[i] for i in range(7))
        self.archive_id = artist._hash(("bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"),
            (schema_id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), 31337, A(5), self.coordinator, 24, self.actor, self.authorization))
        self.archive_raw = encode(artist.ARCHIVE, (1, self.configuration, 24, self.actor, self.authorization, self.before, self.after, self.payload))
        self.archive_event = self.log(7, self.archive, [artist.ARCHIVED, self.archive_id, self.topic("uint64", 1), keccak256(self.archive_raw)],
            encode(("address", "uint256"), (A(90), len(self.archive_raw))))
        self.install_archive(self.archive_raw)
        self.published = self.log(8, A(1), [artist.METADATA_RECORDED, self.topic("uint256", 7), record[0], record[1]],
            encode((metadata.RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16"),
                (record, digest, new_receipt[5], signer, self.topic("uint8", 1), 1)))
        self.consumed = self.log(8, A(1), [artist.CONSUMED, self.authorization, digest, self.topic("address", signer)],
            encode(("address",), (A(13),)))
        self.call("bindingAt(uint256,uint64)", (artist.BINDING,), (self.binding,), ("uint256", "uint64"), (7, 1), target=owners[0])
        current_binding = self.binding if not rotated else (*self.binding[:3], H("later-binding"), 2, *self.binding[5:])
        self.call("binding(uint256)", (artist.BINDING,), (current_binding,), ("uint256",), (7,), target=owners[0])
        attribution = (4 if disputed else 2, 2 if rotated else 1)
        self.call("attributionState(uint256)", ("uint8", "uint64"), attribution, ("uint256",), (7,), target=owners[4])
        self.call("attestation(uint256,uint8,bytes32)", (artist.ATTESTATION_RECORD,), (self.attestation,),
            ("uint256", "uint8", "bytes32"), self.terms[:3], target=owners[4])
        status = (3 if disputed else 2 if rotated else 1, self.authorization, self.terms[3], authority_class, 99)
        self.call("artistAttestationStatus(uint256,uint8,bytes32,bytes32)", ("uint8", "bytes32", "bytes32", "uint8", "uint64"), status,
            ("uint256", "uint8", "bytes32", "bytes32"), (*self.terms[:3], self.terms[3]), target=owners[4])
        current_authority = A(14) if rotated else self.authority[1]
        self.identity = (current_authority, self.authority[2], 4 if disputed else self.authority[3], 91, 110,
            self.document_hash, "ipfs://identity", "Same name is not proof of identity", 18)
        self.call("identity(bytes32)", (artist.IDENTITY,), (self.identity,), ("bytes32",), (self.artist_id,), target=owners[2])
        self.call("authorityState(bytes32)", ("address", "uint8", "uint8", "bytes32"), (*self.identity[:3], self.document_hash),
            ("bytes32",), (self.artist_id,), target=owners[2])
        self.call("operativeIdentityRecord(bytes32)", ("bytes32",), (self.document_hash,), ("bytes32",), (self.artist_id,), target=owners[2])
        self.call("identityRecordBytes(bytes32)", ("bytes",), (self.document,), ("bytes32",), (self.artist_id,), target=owners[2])
        self.call("identityDocumentBytes(bytes32)", ("bytes",), (self.document,), ("bytes32",), (self.document_hash,), target=owners[2])
        empty_cause = (artist.ZERO, (artist.ZERO, 0, artist.ZERO, artist.ZERO_ADDRESS, artist.ZERO, artist.ZERO, 0,
            artist.ZERO_ADDRESS, 0, 0, artist.ZERO, artist.ZERO, artist.ZERO, artist.ZERO, artist.ZERO))
        self.call("currentIdentityContestCause(bytes32)", (artist.CAUSE,), (empty_cause,), ("bytes32",), (self.artist_id,), target=owners[2])

    def set_record(self, index, *, canonicalization=None, schema_hash=None, canonicalization_hash=None, **kwargs):
        """Configure original bytes during metadata_setup; the last row is op24-backed."""
        row = record_pair(**kwargs)
        digest, record, receipt, payload = row
        if canonicalization is not None:
            record = (*record[:2], (*record[2][:2], canonicalization), *record[3:])
            digest = metadata.generic_hash(31337, A(1), A(2), 7, receipt[1], record)
        receipt = (*receipt[:6], schema_hash or receipt[6], canonicalization_hash or receipt[7], receipt[8])
        self.rows[index] = (digest, record, receipt, payload)
        return self.rows[index]

    def add_record(self, **kwargs):
        """Add a generic preceding original during metadata_setup (class1 stays last)."""
        self.rows.insert(-1, record_pair(**kwargs))
        return self.rows[-2]

    def refresh_metadata(self):
        """Rebuild bounded native lanes/pointers after a synthetic setup callback."""
        previous, indices, updated = {}, {}, []
        for offset, (digest, record, receipt, payload) in enumerate(self.rows):
            rt = record[0]; index = indices.get(rt, 0)
            chain = record_chain("31337", A(1), "7", rt, previous.get(rt, artist.ZERO), digest, str(index))
            receipt = (*receipt[:3], 100 if offset == len(self.rows) - 1 else 99, index, chain, *receipt[6:])
            updated.append((digest, record, receipt, payload)); previous[rt] = chain; indices[rt] = index + 1
            if rt not in self.policies:
                self.policies[rt] = (metadata.ARTIST if receipt[2] == 1 else metadata.CURATOR, 1 << receipt[2], True)
        self.rows = updated
        self.call("recordTypeCount()", ("uint256",), (len(self.policies),))
        for type_index, (rt, policy) in enumerate(self.policies.items()):
            self.call("recordTypeAt(uint256)", ("bytes32",), (rt,), ("uint256",), (type_index,))
            self.call("recordPolicy(bytes32)", (metadata.POLICY,), (policy,), ("bytes32",), (rt,))
            lane = [row for row in self.rows if row[1][0] == rt]
            self.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                (previous.get(rt, artist.ZERO), len(lane)), ("uint256", "bytes32"), (7, rt))
            for row in lane:
                self.call("latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)", ("bytes32",), (row[0],),
                    ("uint256", "bytes32", "bytes32", "address"), (7, rt, row[1][1], row[2][1]))
        self.pointers, by_hash = {}, {}
        for row in self.rows:
            digest, record, receipt, payload = row; content = keccak256(payload)
            pointer = by_hash.setdefault(content, A(100 + len(by_hash)))
            self.record_response(row)
            self.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (digest,),
                ("uint256", "bytes32", "uint256"), (7, record[0], receipt[4]))
            self.call("recordPayload(bytes32)", ("address", "bytes"), (pointer, payload), ("bytes32",), (digest,))
            self.call("chunk(bytes32)", ("address", "uint32"), (pointer, len(payload)), ("bytes32",), (content,), target=A(4))
            self.put("eth_getCode", [pointer, self.block_ref], "0x00" + payload.hex())
            self.pointers[(self.policies[record[0]][0], content)] = pointer
        self.call("payloadPointerCount(uint256)", ("uint256",), (len(self.pointers),), ("uint256",), (7,))
        for index, ((family, content), pointer) in enumerate(self.pointers.items()):
            self.call("payloadPointerAt(uint256,uint256)", ("address", "bytes32", "bytes32"),
                (pointer, family, content), ("uint256", "uint256"), (7, index))

    @staticmethod
    def topic(kind, value):
        return "0x" + encode((kind,), (value,)).hex()

    def log(self, block, address, topics, raw):
        tx = H("artist-tx" + str(block))
        if tx not in self.receipts:
            self.blocks[block]["transactions"].append(tx)
            self.receipts[tx] = {"transactionHash": tx, "blockHash": self.blocks[block]["hash"],
                "blockNumber": hex(block), "transactionIndex": "0x0", "status": "0x1", "logs": []}
            self.put("eth_getTransactionReceipt", [tx], self.receipts[tx])
        receipt = self.receipts[tx]
        log = {key: receipt[key] for key in ("transactionHash", "blockHash", "blockNumber", "transactionIndex")}
        log.update(address=address, topics=topics, data="0x" + raw.hex(), logIndex=hex(len(receipt["logs"])), removed=False)
        receipt["logs"].append(log)
        return log

    def install_archive(self, raw):
        self.archive_raw = raw
        self.archive_event["topics"][3] = keccak256(raw)
        self.archive_event["data"] = "0x" + encode(("address", "uint256"), (A(90), len(raw))).hex()
        self.call("artistEvidenceBytesV2(bytes32,uint64)", ("bytes",), (raw,), ("bytes32", "uint64"), (self.archive_id, 1), target=self.archive)
        self.call("artistEvidenceMetadataV2(bytes32,uint64)", ("bytes32", "address", "uint32", "uint64"), (keccak256(raw), A(90), len(raw), 7),
            ("bytes32", "uint64"), (self.archive_id, 1), target=self.archive)
        self.put("eth_getCode", [A(90), self.block_ref], "0x00" + raw.hex())

    def overlay(self):
        return artist.ArtistAttestationSource(self.source(), Transport(self.responses))

    def capture(self):
        source = self.overlay()
        return source, loads(source.snapshot(), maximum=artist.MAX_SNAPSHOT)


class ArtistSourceTests(unittest.TestCase):
    def test_registered_semantic_fixture_hook_retains_generic_prior(self):
        def setup(f):
            f.set_record(0, payload=dumps({"statement": "Original documentary evidence"}))
            f.set_record(-1, rt=schema_id("ARTIST_SEMANTIC_ASSERTION"), auth=1,
                schema=schema_id("STREAM_SEMANTIC_ASSERTION_V1"), canonicalization=schema_id("RFC8785_JCS"),
                payload=dumps({"fixture": "source-only canonical bytes, not validated semantics"}))
        f = Fixture(metadata_setup=setup); source, result = f.capture()
        row = result["attestations"][0]
        self.assertEqual(row["publication"]["recordType"], schema_id("ARTIST_SEMANTIC_ASSERTION"))
        self.assertEqual(row["metadataOriginal"]["payloadHex"], "0x" + f.rows[-1][3].hex())
        receipts = [c["result"] for c in loads(source.transcript(), maximum=artist.MAX_TRANSCRIPT)["calls"]
            if c["method"] == "eth_getTransactionReceipt"]
        self.assertTrue(any(r["blockNumber"] == "0x6" and len(r["logs"]) == len(f.rows) - 1 for r in receipts))

    def test_original_and_latest_attestation_are_separate(self):
        f = Fixture(); later = H("later-attestation")
        value = (later, artist.ZERO, f.terms[4], H("later-statement"), 2, 111, A(14))
        f.call("attestation(uint256,uint8,bytes32)", (artist.ATTESTATION_RECORD,), (value,),
            ("uint256", "uint8", "bytes32"), f.terms[:3], target=A(44))
        f.call("artistAttestationStatus(uint256,uint8,bytes32,bytes32)", ("uint8", "bytes32", "bytes32", "uint8", "uint64"),
            (2, later, artist.ZERO, 1, 111), ("uint256", "uint8", "bytes32", "bytes32"), (*f.terms[:3], f.terms[3]), target=A(44))
        _, result = f.capture(); row = result["attestations"][0]
        self.assertEqual(row["attestationRecordHash"], f.authorization)
        self.assertFalse(row["current"]["statusAppliesToOriginalRecord"])
        f = Fixture(); f.blocks[1]["timestamp"] = hex(92)
        with self.assertRaisesRegex(MuseumError, "registration/current identity"):
            f.capture()

    def test_immutable_source_tuple_and_archive_layout_parity(self):
        # This is a read of the explicit integration Git object, not the different
        # Artist implementation in this checkout and not a compiler invocation.
        root = Path(__file__).resolve().parents[2]
        def source(path):
            return subprocess.check_output(["git", "show", artist.SOURCE_REVISION + ":smart-contracts/" + path],
                cwd=root).decode("utf-8")
        types = source("interfaces/stream/artist/StreamArtistOnboardingTypes.sol")
        for name, expected in (("Snapshot", artist.SNAPSHOT), ("Identity", artist.IDENTITY), ("Binding", artist.BINDING),
                ("Authorization", artist.AUTHORIZATION), ("SignerApproval", artist.PROOF), ("Attestation", artist.ATTESTATION),
                ("AttestationRecord", artist.ATTESTATION_RECORD)):
            body = re.search(r"struct " + name + r"\s*\{([^}]+)\}", types).group(1)
            self.assertEqual(tuple(re.findall(r"\b(uint\d+|address|bytes\d*|string|bool)\s+\w+\s*;", body)), expected)
        operations = re.sub(r"\s+", "", source("domains/artist/StreamArtistAttestationOperations.sol"))
        self.assertIn("abi.encode(b,p,submitted,effective,proof,statement,subject,scoped,admission,delegation,subjectEvidence)", operations)
        self.assertIn("uint16(1),x.configurationHash,op,actor,record,before_,_snapshots(x,op),payload", operations)
        self.assertIn('keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1")', operations)

    def test_original_publication_bytes_signature_and_metadata_position(self):
        f = Fixture(); source, result = f.capture()
        row = result["attestations"][0]
        self.assertEqual(row["metadataRecordHash"], f.metadata_row[0])
        self.assertEqual(row["historicalAuthority"]["artistId"], f.artist_id)
        self.assertEqual(row["statementHex"], "0x" + f.statement.hex())
        self.assertEqual(row["metadataPublicationPosition"]["blockNumber"], "8")
        self.assertEqual(row["originalEvents"][0]["blockNumber"], "0x7")
        self.assertEqual(row["signatureEvidence"]["payloadLayout"], "authenticated_attestation")
        self.assertFalse(result["claims"]["reviewerIndependenceProven"])
        self.assertFalse(result["claims"]["actualChainAcceptance"])
        self.assertIs(source.snapshot(), source.snapshot())

    def test_rotation_dispute_successor_and_relays_preserve_original_authority(self):
        for options in ({"rotated": True}, {"disputed": True}, {"successor": True}, {"relayed": True}, {"legacy": True}):
            with self.subTest(options=options):
                f = Fixture(**options); _, result = f.capture(); row = result["attestations"][0]
                self.assertEqual(row["historicalAuthority"]["signer"], A(8))
                self.assertEqual(row["signatureHex"], "0x" + f.signature.hex())
                self.assertEqual(result["identities"][0]["identityDocumentHash"], f.document_hash)
                if options.get("rotated"):
                    self.assertEqual(row["current"]["identity"][0], A(14))
                if options.get("disputed"):
                    self.assertEqual(row["current"]["attestationStatus"][0], "3")

    def test_delegation_keeps_original_grant_despite_current_revocation(self):
        f = Fixture(delegated=True); _, result = f.capture(); row = result["attestations"][0]
        self.assertEqual(row["historicalAuthority"]["authorityClass"], "2")
        grant = row["signatureEvidence"]["delegation"]
        self.assertFalse(grant["originalWire"][4]); self.assertTrue(grant["currentWire"][4])
        self.assertEqual(len(grant["originalEvents"]), 2)

    def test_no_class1_rows_remains_complete_without_invented_identity(self):
        _, result = Fixture(empty=True).capture()
        self.assertEqual(result["attestations"], [])
        self.assertEqual(result["identities"], [])

    def test_code_suite_owner_and_chain_pin_mismatch(self):
        for change in ("missing", "code", "owner", "chain", "archive"):
            f = Fixture()
            if change == "missing": f.anchor["codePins"] = [p for p in f.anchor["codePins"] if p["address"] != A(44)]
            elif change == "code": f.put("eth_getCode", [A(44), f.block_ref], "0x6000")
            elif change == "owner": f.call("core()", ("address",), (A(99),), target=A(44))
            elif change == "chain": f.call("deploymentChainId()", ("uint256",), (1,), target=f.coordinator)
            else: f.call("operationCoordinator()", ("address",), (A(99),), target=f.archive)
            with self.subTest(change=change), self.assertRaises(MuseumError): f.capture()

    def test_candidate_statement_signature_and_historical_signer_tampering(self):
        for change in ("candidate", "statement", "signature", "signer", "class", "nonce"):
            f = Fixture()
            if change == "candidate":
                values = list(f.publication); values[-1] = H("other-record")
                f.call("publicationAttestation(bytes32)", (artist.PUBLICATION_RECORD,), ((tuple(values), f.publication_evidence, f.host_code),),
                    ("bytes32",), (f.authorization,), target=A(44))
            elif change == "statement": f.call("statementBytes(bytes32)", ("bytes",), (f.statement + b"x",), ("bytes32",), (f.terms[5],), target=A(44))
            elif change == "signature": f.call("signatureBundle(bytes32)", ("bytes",), (b"replacement",), ("bytes32",), (f.authorization,), target=A(42))
            elif change == "signer": f.attested["topics"][3] = f.topic("address", A(9))
            elif change == "class": f.call("attestationAuthorityClass(bytes32)", ("uint8",), (4,), ("bytes32",), (f.authorization,), target=A(44))
            else: f.call("nonceUsed(bytes32,uint256)", ("bool",), (False,), ("bytes32", "uint256"), (f.artist_id, f.nonce), target=A(42))
            with self.subTest(change=change), self.assertRaises(MuseumError): f.capture()

    def test_original_archive_actor_preimage_config_and_carrier(self):
        for change in ("actor", "configuration", "proof", "carrier", "missing"):
            f = Fixture(legacy=True)
            if change == "carrier": f.put("eth_getCode", [A(90), f.block_ref], "0x0001")
            elif change == "missing": f.archive_event["topics"][0] = H("unrelated-archive")
            else:
                actor, configuration, payload = f.actor, f.configuration, f.payload
                if change == "actor": actor = A(9)
                elif change == "configuration": configuration = H("changed-suite")
                else:
                    payload = encode(artist.ORDINARY_PAYLOAD, (f.binding, f.terms, f.submitted, f.statement, (A(9), f.proof[1], True),
                        f.effective, f.authority, f.publication, f.host_code))
                f.install_archive(encode(artist.ARCHIVE, (1, configuration, 24, actor, f.authorization, f.before, f.after, payload)))
            with self.subTest(change=change), self.assertRaises(MuseumError): f.capture()

    def test_native_publication_receipts_are_required_and_ordered(self):
        for change in ("publication", "consumption", "timestamp", "association"):
            f = Fixture()
            if change == "publication": f.published["topics"][0] = H("unrelated-publication")
            elif change == "consumption": f.consumed["topics"][1] = H("foreign-authorization")
            elif change == "timestamp": f.blocks[8]["timestamp"] = hex(101)
            else: f.call("attestationAssociation(bytes32)", (artist.ASSOCIATION,),
                ((f.artist_id, H("foreign-binding"), 1, artist.ZERO, f.association[4]),), ("bytes32",), (f.authorization,), target=A(44))
            with self.subTest(change=change), self.assertRaises(MuseumError): f.capture()

    def test_original_identity_hash_is_not_replaced_by_same_name_or_current_address(self):
        for change in ("document", "registration", "authority"):
            f = Fixture(rotated=True)
            if change == "document": f.call("identityDocumentBytes(bytes32)", ("bytes",), (b"Same name is not proof of identity",),
                ("bytes32",), (f.document_hash,), target=A(42))
            elif change == "registration": f.registration["topics"][2] = f.topic("address", A(14))
            else: f.call("authorityState(bytes32)", ("address", "uint8", "uint8", "bytes32"), (A(8), 1, 1, f.document_hash),
                ("bytes32",), (f.artist_id,), target=A(42))
            with self.subTest(change=change), self.assertRaises(MuseumError): f.capture()

    def test_missing_original_delegation_and_historical_grant_changes_fail(self):
        for change in ("event", "association", "grant"):
            f = Fixture(delegated=True)
            if change == "event": f.delegate_event["topics"][0] = H("missing-delegation")
            elif change == "association": f.call("attestationAssociation(bytes32)", (artist.ASSOCIATION,),
                ((f.artist_id, f.binding[3], 1, H("other-grant"), f.association[4]),), ("bytes32",), (f.authorization,), target=A(44))
            else:
                bad = ((f.artist_id, A(9), 7, 1, 90, 200, 5, H("grant-constraints")), A(12), 9, 1, True, H("later-revocation"))
                f.call("delegationRecord(bytes32)", (artist.DELEGATION,), (bad,), ("bytes32",), (f.grant,), target=A(42))
            with self.subTest(change=change), self.assertRaises(MuseumError): f.capture()

    def test_offline_replay_and_external_transcript_pin(self):
        f = Fixture(delegated=True); source, _ = f.capture(); original = source.metadata_catalog
        catalogue = metadata.MetadataCatalogSource(original.anchor_bytes, ReplayTransport(original.transcript(), keccak256(original.transcript())))
        replay = artist.ArtistAttestationSource(catalogue, ReplayTransport(source.transcript(), keccak256(source.transcript())))
        self.assertEqual(source.snapshot(), replay.snapshot())
        with self.assertRaisesRegex(MuseumError, "external commitment"):
            ReplayTransport(source.transcript(), H("wrong"))

    def test_shared_read_conflicts_refuse_and_trusted_mode_stays_caller_declared(self):
        f = Fixture(); catalogue = f.source(); catalogue.snapshot()
        f.block["extra"] = "contradictory answer to identical header request"
        source = artist.ArtistAttestationSource(catalogue, Transport(f.responses))
        with self.assertRaisesRegex(MuseumError, "contradict"):
            source.snapshot()
        f = Fixture()
        with patch.object(RpcTransport, "request", Transport(f.responses).request):
            catalogue = metadata.MetadataCatalogSource(dumps(f.anchor), RpcTransport("http://127.0.0.1:1"), provenance="trusted_rpc")
            source = artist.ArtistAttestationSource(catalogue, RpcTransport("http://127.0.0.1:1"))
            result = loads(source.snapshot(), maximum=artist.MAX_SNAPSHOT)
        self.assertEqual(result["mode"], "caller_admitted_rpc_artist_attestation")
        self.assertFalse(result["claims"]["actualChainAcceptance"])

    def test_concrete_source_and_explicit_bounds(self):
        with self.assertRaisesRegex(MuseumError, "concrete"):
            artist.ArtistAttestationSource({}, Transport({}))
        source = Fixture().overlay()
        with patch.object(artist, "MAX_ARCHIVE_BYTES", 1), self.assertRaises(MuseumError): source.snapshot()
        with self.assertRaisesRegex(MuseumError, "cannot resume"): source.snapshot()


if __name__ == "__main__":
    unittest.main()

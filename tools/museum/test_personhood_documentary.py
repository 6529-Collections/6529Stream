"""Focused native documentary wire joins, with explicitly synthetic original reports."""
import unittest
from unittest.mock import patch

from . import general_attestation_source as general
from . import personhood_documentary as documentary
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_abi import calldata, decode, encode, width
from .independent_wire import ZERO
from .test_public_personhood_source import PublicPersonhoodFixture, A, K


def install_general(fixture, *, attestation=None, receipt=None, payload=None, bundle=None):
    """Rehash the documentary half only; this does not recreate an admitted op24 publication."""
    _, old_a, old_r, subject, old_payload, old_bundle = fixture.general_record
    a = old_a if attestation is None else tuple(attestation)
    r = list(old_r if receipt is None else receipt)
    payload = old_payload if payload is None else payload
    bundle = old_bundle if bundle is None else bundle
    r[10] = keccak256(bundle)
    digest = general.native_record_hash(31337, fixture.notary, a, tuple(r))
    r[5] = general.chain_hash(a[1], a[3], ZERO, digest, r[4]); r = tuple(r)
    pointers = (fixture._carrier(payload), fixture._carrier(bundle))
    for signature, inputs, values, outputs, returned in (
            ("attestation(bytes32)", ("bytes32",), (digest,), (general.ATTESTATION, general.RECEIPT), (a, r)),
            ("recordSubject(bytes32)", ("bytes32",), (digest,), (general.SUBJECT,), (subject,)),
            ("recordHashAt(uint256,bytes32,uint256)", ("uint256", "bytes32", "uint256"),
                (a[1], a[3], r[4]), ("bytes32",), (digest,)),
            ("recordPayload(bytes32)", ("bytes32",), (digest,), ("address", "bytes"), (pointers[0], payload)),
            ("recordSignatureBundle(bytes32)", ("bytes32",), (digest,), ("address", "bytes"), (pointers[1], bundle)),
            ("latestAttestationHashFor(uint256,bytes32,bytes32,address)",
                ("uint256", "bytes32", "bytes32", "address"), (a[1], a[3], a[2], r[0]), ("bytes32",), (digest,))):
        fixture.add(fixture.notary, signature, inputs, values, outputs, returned)
    s = list(fixture.summary)
    reference = (*s[9][:7], digest)
    s[9] = reference; s[3] = keccak256(documentary.reference_bytes(reference))
    s[20:24] = (a[1], a[3], a[2], r[0])
    s[26] = (*pointers, *s[26][2:])
    s[27] = (keccak256(b"\0" + payload), keccak256(b"\0" + bundle), *s[27][2:])
    s[24] = keccak256(encode(("bytes32", "uint256", "address", documentary.REFERENCE,
        general.ATTESTATION, general.RECEIPT, "bytes32", "bytes32", "address", "bytes32", "address",
        "bytes32", ("bytes32",) * 4),
        (documentary.DOCUMENTARY_TAG, 31337, fixture.core, reference, a, r,
            keccak256(encode((general.SUBJECT,), (subject,))), keccak256(encode(("bytes", "bytes"), (payload, bundle))),
            s[15], s[16], s[17], s[18], s[19])))
    return tuple(s)


class PersonhoodDocumentaryTests(unittest.TestCase):
    def test_frozen_definition_bytes_and_native_static_shapes(self):
        self.assertEqual([len(row[3]) for row in documentary.definitions()], [4236, 1488, 362, 1837])
        self.assertEqual(keccak256(documentary.PROFILE_BYTES),
            "0x06eaf449a0abe6a4305706d589bc597f14f7d23f62acc661b4b1fff128b921c3")
        self.assertEqual(width(documentary.SUMMARY), 1536)
        self.assertEqual(width(documentary.SELECTION), 704)
        fixture = PublicPersonhoodFixture()
        raw = documentary.reference_bytes(fixture.reference)
        self.assertEqual(len(raw), 590)
        self.assertEqual(documentary.decode_reference(raw), fixture.reference)
        self.assertEqual(documentary.summary_hash(fixture.summary), fixture.summary_hash)
        for update in ({"version": "1"}, {"notarizationRecordHash": ZERO}, {"extra": True}):
            value = loads(raw); value.update(update)
            with self.assertRaises(MuseumError): documentary.decode_reference(dumps(value))

    def test_original_report_uses_independent_notarization_collection(self):
        fixture = PublicPersonhoodFixture()
        with patch("socket.socket", side_effect=AssertionError("offline synthetic evidence only")):
            report = documentary.verify_documentary(fixture.source(), fixture.summary)
        self.assertEqual(fixture.a["collectionId"], "1")
        self.assertEqual(report["attestation"][1], "7")
        self.assertEqual(report["facts"], [general.INSTITUTIONAL, fixture.recorder, fixture.reference[7], True])
        self.assertEqual(report["documentaryHash"], fixture.summary[24])
        self.assertEqual(len(report["definitions"]), 4)
        self.assertEqual(len(report["carriers"]), 6)
        self.assertFalse(report["generalLaneHistoryComplete"])
        self.assertFalse(report["signatureCurrentlyRevalidated"])

    def test_same_recorder_supersession_retains_original_and_ignores_other_recorder(self):
        fixture = PublicPersonhoodFixture(mode="stale_head")
        report = documentary.verify_documentary(fixture.source(), fixture.summary)
        self.assertFalse(report["facts"][3])
        self.assertNotEqual(report["facts"][2], report["recordHash"])
        self.assertEqual(report["recordHash"], fixture.reference[7])
        fixture = PublicPersonhoodFixture()
        a = fixture.general_record[1]
        fixture.add(fixture.notary, "latestAttestationHashFor(uint256,bytes32,bytes32,address)",
            ("uint256", "bytes32", "bytes32", "address"), (7, a[3], a[2], A(99999)),
            ("bytes32",), (K("different recorder's newer report"),))
        ctx = fixture.source(); report = documentary.verify_documentary(ctx, fixture.summary)
        self.assertTrue(report["facts"][3])
        target = calldata("latestAttestationHashFor(uint256,bytes32,bytes32,address)",
            ("uint256", "bytes32", "bytes32", "address"), (7, a[3], a[2], fixture.recorder))
        queries = [row["params"][0]["data"] for row in ctx.reader.rows if row["method"] == "eth_call"
            and row["params"][0]["data"].startswith(target[:10])]
        self.assertEqual(queries, [target])

    def test_document_lifecycle_is_excluded_from_immutable_facts(self):
        fixture = PublicPersonhoodFixture()
        for identifier, *_ in documentary.definitions():
            facts = fixture.source().one(A(3), "documentFacts(bytes32)", documentary.DOCUMENT_FACTS,
                ("bytes32",), (identifier,))
            archived = (*facts[:2], 2, *facts[3:])
            self.assertEqual(documentary.definition_facts_hash(facts), documentary.definition_facts_hash(archived))
            fixture.add(A(3), "documentFacts(bytes32)", ("bytes32",), (identifier,),
                (documentary.DOCUMENT_FACTS,), (archived,))
        self.assertTrue(documentary.verify_documentary(fixture.source(), fixture.summary)["facts"][3])

    def test_module_currentness_and_immutable_identity_are_separate(self):
        for status in (0, 1, 2, 3):
            with self.subTest(status=status):
                fixture = PublicPersonhoodFixture()
                module = list(fixture.module); module[0] = status; module[4] += 100; module[10] += 1; module[11] += 1
                fixture.add(fixture.modules, "moduleRecord(address)", ("address",), (fixture.notary,),
                    (documentary.MODULE,), (tuple(module),))
                report = documentary.verify_documentary(fixture.source(), fixture.summary)
                self.assertEqual(report["facts"][3], status in (1, 2))
                self.assertEqual(report["moduleIdentityHash"], fixture.summary[25])
                if status in (0, 3): self.assertEqual(report["facts"][2], ZERO)
        fixture = PublicPersonhoodFixture(); module = list(fixture.module); module[8] += "-changed"
        fixture.add(fixture.modules, "moduleRecord(address)", ("address",), (fixture.notary,),
            (documentary.MODULE,), (tuple(module),))
        with self.assertRaisesRegex(MuseumError, "original module identity differs"):
            documentary.verify_documentary(fixture.source(), fixture.summary)

    def test_empty_erc1271_signature_rejected_after_coherent_record_rehash(self):
        fixture = PublicPersonhoodFixture()
        domain, words, _ = decode(("bytes32", ("bytes32",) * 15, "bytes"), fixture.general_record[5])
        receipt = list(fixture.general_record[2]); receipt[9] = general.ERC1271
        s = install_general(fixture, receipt=receipt,
            bundle=encode(("bytes32", ("bytes32",) * 15, "bytes"), (domain, words, b"")))
        with self.assertRaisesRegex(MuseumError, "original signature preimage differs"):
            documentary.verify_documentary(fixture.source(), s)

    def test_nonempty_erc1271_remains_original_evidence_without_current_signer_call(self):
        fixture = PublicPersonhoodFixture(); receipt = list(fixture.general_record[2]); receipt[9] = general.ERC1271
        s = install_general(fixture, receipt=receipt)
        report = documentary.verify_documentary(fixture.source(), s)
        self.assertEqual(report["receipt"][9], general.ERC1271)
        self.assertFalse(report["signatureCurrentlyRevalidated"])

    def test_rehashed_wrong_signature_words_are_not_accepted(self):
        fixture = PublicPersonhoodFixture()
        domain, words, signature = decode(("bytes32", ("bytes32",) * 15, "bytes"), fixture.general_record[5])
        words = list(words); words[4] = general.ESTATE
        bundle = encode(("bytes32", ("bytes32",) * 15, "bytes"), (domain, tuple(words), signature))
        receipt = list(fixture.general_record[2])
        receipt[6] = keccak256(b"\x19\x01" + hex_bytes(domain) + hex_bytes(keccak256(encode(("bytes32",) * 15, words))))
        s = install_general(fixture, receipt=receipt, bundle=bundle)
        with self.assertRaisesRegex(MuseumError, "original signature preimage differs"):
            documentary.verify_documentary(fixture.source(), s)

    def test_empty_original_payload_rejected_despite_coherent_commitment(self):
        fixture = PublicPersonhoodFixture(); a = list(fixture.general_record[1]); a[8] = keccak256(b"")
        s = install_general(fixture, attestation=a, payload=b"")
        with self.assertRaisesRegex(MuseumError, "original payload/signature bundle differs"):
            documentary.verify_documentary(fixture.source(), s)

    def test_original_definition_and_carrier_substitutions_fail(self):
        fixture = PublicPersonhoodFixture(); identifier = documentary.definitions()[0][0]
        facts = fixture.source().one(A(3), "documentFacts(bytes32)", documentary.DOCUMENT_FACTS,
            ("bytes32",), (identifier,))
        changed = (*facts[:8], K("different immutable declaration"))
        fixture.add(A(3), "documentFacts(bytes32)", ("bytes32",), (identifier,),
            (documentary.DOCUMENT_FACTS,), (changed,))
        with self.assertRaisesRegex(MuseumError, "summary original carriers/definitions differ"):
            documentary.verify_documentary(fixture.source(), fixture.summary)
        fixture = PublicPersonhoodFixture(); _, _, digest, raw = documentary.definitions()[0]
        pointer = fixture._carrier(raw)
        fixture.add(A(4), "chunk(bytes32)", ("bytes32",), (digest,), ("address", "uint32"), (pointer, len(raw)))
        with self.assertRaisesRegex(MuseumError, "summary original carriers/definitions differ"):
            documentary.verify_documentary(fixture.source(), fixture.summary)
        fixture = PublicPersonhoodFixture(); fixture.codes[fixture.summary[26][2]] = b"\0tampered definition"
        with self.assertRaisesRegex(MuseumError, "runtime/carrier differs"):
            documentary.verify_documentary(fixture.source(), fixture.summary)

    def test_documentary_hash_uses_full_receipt_chain_position(self):
        fixture = PublicPersonhoodFixture(); digest, a, r, *_ = fixture.general_record
        changed = list(r); changed[5] = K("changed original chain position")
        self.assertEqual(general.native_record_hash(31337, fixture.notary, a, changed), digest)
        fixture.add(fixture.notary, "attestation(bytes32)", ("bytes32",), (digest,),
            (general.ATTESTATION, general.RECEIPT), (a, tuple(changed)))
        with self.assertRaisesRegex(MuseumError, "immutable documentary hash differs"):
            documentary.verify_documentary(fixture.source(), fixture.summary)

    def test_summary_documentary_projection_and_hash_are_exact(self):
        for index, replacement, message in ((20, 1, "summary original General fields differ"),
                (23, A(555), "summary original General fields differ"),
                (24, K("changed documentary commitment"), "immutable documentary hash differs")):
            with self.subTest(index=index):
                fixture = PublicPersonhoodFixture(); summary = list(fixture.summary); summary[index] = replacement
                self.assertNotEqual(documentary.summary_hash(tuple(summary)), fixture.summary_hash)
                with self.assertRaisesRegex(MuseumError, message):
                    documentary.verify_documentary(fixture.source(), tuple(summary))


if __name__ == "__main__": unittest.main()

"""Concrete synthetic Artist/schema replay; no deployed-chain acceptance claim."""
import copy
import unittest
from unittest.mock import patch

from . import attribution_dossier
from .account_profile import ASSERTION_SCHEMA_BYTES, JCS_ID, account_iri
from .canonical import MuseumError, dumps, keccak256, loads
from .chain_abi import Array, encode
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .independent_wire import DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, RAW_DEFINITION, ZERO, json_values
from .native_attribution_profile import NAME, NativeAttributionProfile
from .native_attribution_semantics import NativeAttributionSemanticSource, PROFILE, selector, select
from .schemas import NAMES
from .canonical import schema_id
from .test_artist_attestation_source import Fixture as ArtistFixture, A, H, Transport
from .test_schema_inventory import assertion_document


class Fixture(ArtistFixture):
    def __init__(self, *, mutate=None, profile_hash=None, document_status=0, **kwargs):
        self.semantic_profile = NativeAttributionProfile()
        def setup(f):
            f.set_record(0, payload=dumps({"statement": "Exact original documentary evidence"}))
            f.refresh_metadata()
            digest, record, receipt, raw = f.rows[0]
            prior = {"recordHash": digest, "record": json_values(record), "receipt": json_values(receipt)}
            value = assertion_document()
            value.update(profileHash=profile_hash or self.semantic_profile.profile_hash,
                anchorSubject={"kind": "collection", "subjectId": record[1]},
                sourceRecords=[selector(prior, A(1))])
            assertion = value["assertions"][0]
            assertion.update(assertingAgent=account_iri("31337", A(8)),
                evidence=[{"source": {"algorithm": "1", "digest": keccak256(raw), "canonicalizationId": RAW_BYTES},
                    "selectorType": "json_pointer", "selector": "/statement", "basis": "documentary_evidence"}])
            if mutate is not None: mutate(value)
            self.semantic_value = value
            f.set_record(-1, rt=schema_id("ARTIST_SEMANTIC_ASSERTION"), auth=1,
                schema=schema_id(NAMES[1]), canonicalization=JCS_ID, payload=dumps(value),
                schema_hash=keccak256(ASSERTION_SCHEMA_BYTES),
                canonicalization_hash=keccak256(self.semantic_profile.documents["RFC8785_JCS"][1]))
        super().__init__(metadata_setup=setup, **kwargs)
        self.document_rows = {}
        self.chunk_pointers = {}
        for name, (kind, raw) in {"RAW_BYTES": (1, RAW_DEFINITION), **self.semantic_profile.documents}.items():
            self.install_document(name, kind, raw, status=document_status)

    def install_document(self, name, kind, raw, *, status=0, canonical=None):
        pieces = [raw[i:i + 8192] for i in range(0, len(raw), 8192)]
        hashes = tuple(keccak256(piece) for piece in pieces)
        for digest, piece in zip(hashes, pieces):
            pointer = self.chunk_pointers.setdefault(digest, A(1000 + len(self.chunk_pointers)))
            self.call("chunk(bytes32)", ("address", "uint32"), (pointer, len(piece)),
                ("bytes32",), (digest,), target=A(4))
            self.put("eth_getCode", [pointer, self.block_ref], "0x00" + piece.hex())
        canon = canonical or (RAW_BYTES if name in ("RAW_BYTES", "RFC8785_JCS") else JCS_ID)
        spec = (name, kind, keccak256(raw), canon, ZERO, "", len(raw))
        declaration = keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, hashes)))
        row = (True, status, declaration, spec, hashes)
        self.document_rows[name] = row
        self.call("document(bytes32)", (DOCUMENT,), (row,), ("bytes32",), (schema_id(name),), target=A(3))

    def semantic(self):
        return NativeAttributionSemanticSource(self.overlay(), Transport(self.responses), profile=self.semantic_profile)


class NativeAttributionSourceTests(unittest.TestCase):
    def test_registered_original_source_and_retired_definitions_are_exact(self):
        for retired in (0, 1):
            f = Fixture(document_status=retired, rotated=True, disputed=True)
            source = f.semantic(); snapshot = loads(source.snapshot(), maximum=MAX_TRANSCRIPT)
            row = snapshot["statements"][0]
            self.assertEqual(row["status"], "supported")
            self.assertEqual(row["value"], f.semantic_value)
            self.assertEqual(row["publicationPosition"], ["8", "0", "0"])
            self.assertEqual(row["historicalAuthority"]["signer"], A(8))
            self.assertEqual(row["currentQualification"]["identity"][0], A(14))
            raw = source.transcript()
            with patch("socket.socket", side_effect=AssertionError("network forbidden")):
                replay = NativeAttributionSemanticSource(source.artist, ReplayTransport(raw, keccak256(raw)))
                self.assertEqual(replay.snapshot(), source.snapshot())

    def test_other_profile_is_explicitly_unsupported_with_original_preserved(self):
        f = Fixture(profile_hash=H("other registered profile"))
        snapshot = loads(f.semantic().snapshot(), maximum=MAX_TRANSCRIPT)
        self.assertEqual(snapshot["statements"][0]["status"], "unsupported")
        self.assertEqual(snapshot["statements"][0]["payloadHex"], "0x" + dumps(f.semantic_value).hex())
        self.assertEqual(snapshot["documents"], [])

    def test_impersonation_subject_and_original_evidence_tampering_reject(self):
        mutations = {
            "signer": lambda v: v["assertions"][0].__setitem__("assertingAgent", account_iri("31337", A(99))),
            "subject": lambda v: v["anchorSubject"].__setitem__("subjectId", H("wrong subject")),
            "selector": lambda v: v["sourceRecords"][0].__setitem__("recorder", A(99)),
            "hash": lambda v: v["assertions"][0]["evidence"][0]["source"].__setitem__("digest", H("wrong content")),
            "pointer": lambda v: v["assertions"][0]["evidence"][0].__setitem__("selector", "/absent"),
            "own_signed": lambda v: v["assertions"][0]["evidence"][0].__setitem__("basis", "own_signed_statement"),
            "page": lambda v: v["assertions"][0]["evidence"][0].__setitem__("selectorType", "document_page"),
        }
        for name, change in mutations.items():
            with self.subTest(change=name), self.assertRaises(MuseumError):
                Fixture(mutate=change).semantic().snapshot()

    def test_registered_profile_schema_and_canonicalization_bytes_cannot_be_swapped(self):
        for name in (NAME, NAMES[1], "RFC8785_JCS"):
            f = Fixture(); kind, raw = f.semantic_profile.documents[name]
            value = loads(raw); value["replacement"] = "same identifier, other bytes"
            f.install_document(name, kind, dumps(value))
            with self.subTest(name=name), self.assertRaisesRegex(MuseumError, "registered schema/profile bytes"):
                f.semantic().snapshot()

    def test_referenced_original_requires_complete_prior_publication(self):
        f = Fixture()
        # Keep valid original catalogue state but omit the generic original's event.
        receipt = next(value for value in f.receipts.values() if value["blockNumber"] == "0x6")
        receipt["logs"].pop(0)
        for index, log in enumerate(receipt["logs"]): log["logIndex"] = hex(index)
        with self.assertRaisesRegex(MuseumError, "must precede"):
            f.semantic().snapshot()

    def test_selection_and_package_reconstruct_concrete_supported_source(self):
        f = Fixture(); semantic = f.semantic()
        snapshot = loads(semantic.snapshot(), maximum=MAX_TRANSCRIPT)
        reference = {**snapshot["statements"][0]["source"], "pointer": "/assertions/0"}
        policy = {"profile": PROFILE, "sourceSnapshotHash": keccak256(semantic.snapshot()),
            "sourceAuthoritySet": [reference], "reviewerAuthoritySet": [], "singleValuedRelations": [],
            "allowSelfReview": False, "independentHumanReviewRequired": False}
        raw = dumps(policy)
        files = attribution_dossier.build_files(semantic.artist, semantic=semantic,
            selection_raw=raw, selection_hash=keccak256(raw))
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            report = attribution_dossier.verify_files(files, keccak256(files["manifest.json"]))
        self.assertEqual(report["reviewSelection"], "captured")
        self.assertEqual(len(select(snapshot, raw, keccak256(raw))["selected"]), 1)
        dossier = loads(files["dossier.json"], maximum=MAX_TRANSCRIPT)
        self.assertEqual(dossier["selection"]["selected"][0]["assertion"], f.semantic_value["assertions"][0])


if __name__ == "__main__":
    unittest.main()

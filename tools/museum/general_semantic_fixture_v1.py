"""Offline synthetic fixture for the General direct-semantic source.

The fixture replays the concrete Metadata and General V2 readers.  It does not
mock either validator and it does not claim that its synthetic signatures were
accepted by a deployed chain.
"""

from copy import deepcopy

from .account_profile import ASSERTION_SCHEMA_BYTES, JCS_ID, account_iri
from .canonical import MuseumError, dumps, keccak256, schema_id
from .chain_abi import Array, decode, encode
from .chain_rpc import MAX_TRANSCRIPT
from .general_attestation_source import (
    ESTATE, INSTITUTIONAL, chain_hash, domain, native_record_hash, signed_words,
)
from .general_semantic_profile_v1 import GeneralSemanticProfileV1
from .general_semantic_source_v1 import GeneralSemanticSourceV1
from .independent_wire import DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, ZERO, ZERO_ADDRESS
from .metadata_catalog_source import MetadataCatalogSource
from .schemas import NAMES
from .test_general_attestation_source import Transport, decode_words
from .test_general_attestation_source_v2 import Fixture as GeneralV2Fixture
from .test_native_attribution_source import Fixture as NativeFixture


AUTHORITY_ROWS = {"institution": (1, INSTITUTIONAL), "estate": (1, ESTATE),
                  "curatorial": (2, None)}
EVIDENCE_ORDER = {"prior": None, "same_time": 99, "late": 98}


class OfflineGeneralSemanticFixture:
    """One fully reconstructed General assertion over prior Metadata bytes."""

    def __init__(self, *, authority="institution", evidence_order="prior",
                 mutate=None, profile=None, review_status="unreviewed",
                 origin="direct_statement"):
        if authority not in AUTHORITY_ROWS or evidence_order not in EVIDENCE_ORDER:
            raise MuseumError("unsupported synthetic General semantic fixture variant")
        self.profile = profile or GeneralSemanticProfileV1()
        if type(self.profile) is not GeneralSemanticProfileV1:
            raise MuseumError("exact General semantic fixture profile required")
        self.native = NativeFixture()
        self.general_fixture = GeneralV2Fixture(
            generic_payload_bytes=None, artist_context=self.native)
        for name, (kind, raw) in self.profile.documents.items():
            self._install_document(name, kind, raw)

        row_index, forced_family = AUTHORITY_ROWS[authority]
        _, old_value, old_receipt, _, old_bundle, evidence, subject = \
            self.general_fixture.rows[row_index]
        value, receipt = list(old_value), list(old_receipt)
        if forced_family is not None:
            value[3] = forced_family
        value[5], value[6] = schema_id(NAMES[1]), JCS_ID
        if forced_family == ESTATE:
            value[9] = ZERO
        recorded_at = EVIDENCE_ORDER[evidence_order]
        if recorded_at is not None:
            receipt[3] = recorded_at
        receipt[11] = keccak256(ASSERTION_SCHEMA_BYTES)
        receipt[12] = keccak256(self.profile.documents["RFC8785_JCS"][1])
        receipt[13] = ZERO
        if receipt[1] == 1:
            receipt[18:24] = [ZERO_ADDRESS, ZERO, ZERO, ZERO, ZERO, 0]

        semantic = deepcopy(self.native.semantic_value)
        semantic["profileHash"] = self.profile.profile_hash
        semantic["anchorSubject"] = {"kind": "collection", "subjectId": value[2]}
        issuer = account_iri(self.general_fixture.anchor["chainId"], receipt[0])
        for entity in semantic["entities"]:
            entity["declaringAgent"] = issuer
        for assertion in semantic["assertions"]:
            assertion["assertingAgent"] = issuer
            assertion["reviewStatus"] = review_status
            assertion["origin"] = origin
        if mutate is not None:
            mutate(semantic)
        payload = dumps(semantic)
        value[8] = keccak256(payload)

        signed = receipt[1] == 1
        bundle = old_bundle if signed else b""
        if signed:
            _, _, signature = decode(("bytes32", ("bytes32",) * 15, "bytes"),
                                     old_bundle, maximum=8192)
            receipt[6], receipt[10] = ZERO, ZERO
            body = signed_words(tuple(value), payload, receipt)
            bundle = encode(("bytes32", ("bytes32",) * 15, "bytes"),
                (domain(31337, self.general_fixture.host), decode_words(body), signature))
            receipt[6] = keccak256(b"\x19\x01" + bytes.fromhex(domain(
                31337, self.general_fixture.host)[2:]) + bytes.fromhex(keccak256(body)[2:]))
            receipt[10] = keccak256(bundle)

        lane = [row for index, row in enumerate(self.general_fixture.rows)
                if index != row_index and row[1][3] == value[3] and index < row_index]
        index = len(lane)
        previous = lane[-1][2][5] if lane else ZERO
        receipt[4], receipt[5] = index, ZERO
        digest = native_record_hash(31337, self.general_fixture.host,
                                    tuple(value), tuple(receipt))
        receipt[5] = chain_hash(7, value[3], previous, digest, index)
        self.general_fixture.rows[row_index] = (
            digest, tuple(value), tuple(receipt), payload, bundle, evidence, subject)
        self.general_fixture.install_v2_state()
        self.row_index, self.semantic_value = row_index, semantic
        self.record_hash, self.payload = digest, payload

    def sources(self):
        """Return fresh concrete sources sharing one immutable response map."""
        transport = Transport(self.general_fixture.responses)
        metadata = MetadataCatalogSource(dumps(self.native.anchor), transport)
        general = self.general_fixture.reader()
        semantic = GeneralSemanticSourceV1(metadata, general,
            Transport(self.general_fixture.responses), profile=self.profile)
        return metadata, general, semantic

    def _install_document(self, name, kind, raw):
        pieces = [raw[offset:offset + 8192] for offset in range(0, len(raw), 8192)]
        hashes = []
        for piece in pieces:
            digest, _ = self.general_fixture.install_chunk(piece)
            hashes.append(digest)
        canonical = RAW_BYTES if name == "RFC8785_JCS" else JCS_ID
        spec = (name, kind, keccak256(raw), canonical, ZERO, "", len(raw))
        declaration = keccak256(encode((DOCUMENT_SPEC, Array("bytes32")),
            (spec, tuple(hashes))))
        row = (True, 0, declaration, spec, tuple(hashes))
        self.general_fixture.call("document(bytes32)", (DOCUMENT,), (row,),
            ("bytes32",), (schema_id(name),), target=self.general_fixture.schemas)

    def source(self):
        return self.sources()[2]

    def install_profile_document(self, name, raw, *, kind=None):
        """Replace one registered interpretation document for hostile controls."""
        expected_kind, _ = self.profile.documents[name]
        self._install_document(name, expected_kind if kind is None else kind, raw)

    @property
    def selected_source(self):
        return self.assertion_selectors()[0]

    def assertion_selectors(self, source=None):
        """Return exact outer selectors for this row's original assertions."""
        from .general_semantic_source_v1 import selector
        snapshot = (source or self.source()).snapshot()
        from .canonical import loads
        value = loads(snapshot, maximum=MAX_TRANSCRIPT, canonical=True)
        row = next(row for row in value["statements"]
                   if row["source"]["recordHash"] == self.record_hash)
        if row["value"] is None:
            return []
        return [selector(row["original"], self.general_fixture.anchor,
            "/assertions/" + str(index)) for index, _ in enumerate(row["value"]["assertions"])]

    def selection(self, source=None, *, indices=None, single_valued=()):
        """Build the externally pinned closed dossier selection for this row."""
        from .general_semantic_dossier_v1 import NAME
        semantic = source or self.source()
        selectors = self.assertion_selectors(semantic)
        chosen = selectors if indices is None else [selectors[index] for index in indices]
        raw = dumps({"profile": NAME, "sourceSnapshotHash": keccak256(semantic.snapshot()),
            "sourceAuthoritySet": chosen, "singleValuedRelations": list(single_valued)})
        return raw, keccak256(raw)


def build_case(**kwargs):
    """Public compact constructor used by package and CLI tests."""
    return OfflineGeneralSemanticFixture(**kwargs)

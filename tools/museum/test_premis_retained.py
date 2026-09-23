"""Synthetic full-native replay tests for retained-file PREMIS projection.

The fixture is internally consistent native wire data.  It is not an actual
deployment, trusted RPC observation, historical fixity event, or format test.

Regenerate or check the compact worked example without retaining the duplicated
full package/XSD closure::

    python -m tools.museum.test_premis_retained --generate-example
    python -m tools.museum.test_premis_retained --check-example
"""

import copy
from hashlib import sha256
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

from .account_profile import JCS_BYTES, JCS_ID
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id
from .chain_abi import Array, calldata, decode, encode
from .chain_rpc import ReplayTransport
from .independent_catalog_source import (CATALOG, PAYLOAD_FAMILY, SIGNATURE_FAMILY,
    IndependentCatalogSource, PROFILE)
from .independent_wire import (DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, RAW_DEFINITION, RECORD,
    RECEIPT, SUBJECT, TYPE_HASH, ZERO, domain, generic_hash)
from . import premis_retained as retained
from .premis_retained import MODE, PROFILE_HASH, build, project, replay, verify
from .preservation_resources import FAMILY, OBJECT_NAME, ROLE_IDS, SCHEMAS
from .test_independent_catalog_source import CatalogTransport, FIXTURE as BASE_FIXTURE


ROOT = Path(__file__).resolve().parents[2]
EXAMPLE = ROOT / "schemas/museum/premis-retained/example"

def A(number):
    return "0x" + format(number, "040x")


def H(label):
    return schema_id("synthetic retained PREMIS " + label)


class NativeTransport(CatalogTransport):
    """Serve a complete eight-lane catalogue from exact generated wires."""

    def __init__(self, rows, capture, scope, records, documents, chunks):
        super().__init__(rows, capture, scope)
        self.native_records = {row["recordHash"]: row for row in records}
        self.by_type = {}
        for row in records:
            self.by_type.setdefault(row["record"][0], []).append(row)
        self.documents = documents
        self.chunks = chunks
        pointers, seen = [], set()
        for row in records:
            for family, raw, pointer in ((PAYLOAD_FAMILY, row["payload"], row["payloadPointer"]),
                                         (SIGNATURE_FAMILY, row["bundle"], row["bundlePointer"])):
                key = (family, keccak256(raw))
                if key not in seen:
                    seen.add(key); pointers.append((pointer, *key))
        self.pointers = pointers

    def custom(self, method, params):
        if method == "eth_getCode" and params[0] in {value[0] for value in self.chunks.values()}:
            pointer = params[0]
            raw = next(raw for p, raw in self.chunks.values() if p == pointer)
            return "0x00" + raw.hex()
        if method != "eth_call":
            return None
        data = params[0]["data"]
        result = self._result
        arguments = self._arguments
        if data.startswith(calldata("recordChainHash(uint256,bytes32)")[:10]):
            scope, record_type = arguments(data, ("uint256", "bytes32"))
            if scope == self.scope:
                records = self.by_type.get(record_type, [])
                return result(("bytes32", "uint64"),
                    (ZERO if not records else records[-1]["receipt"][5], len(records)))
        if data.startswith(calldata("recordHashAt(uint256,bytes32,uint256)")[:10]):
            scope, record_type, index = arguments(data, ("uint256", "bytes32", "uint256"))
            if scope == self.scope:
                return result(("bytes32",), (self.by_type[record_type][index]["recordHash"],))
        if data.startswith(calldata("collectionRecord(bytes32)")[:10]):
            record_hash, = arguments(data, ("bytes32",))
            if record_hash in self.native_records:
                row = self.native_records[record_hash]
                return result((RECORD, RECEIPT), (row["record"], row["receipt"]))
        if data.startswith(calldata("recordSubject(bytes32)")[:10]):
            record_hash, = arguments(data, ("bytes32",))
            if record_hash in self.native_records:
                return result((SUBJECT,), (self.native_records[record_hash]["subject"],))
        for signature, field, pointer in (("recordPayload(bytes32)", "payload", "payloadPointer"),
                                           ("recordSignatureBundle(bytes32)", "bundle", "bundlePointer")):
            if data.startswith(calldata(signature)[:10]):
                record_hash, = arguments(data, ("bytes32",))
                if record_hash in self.native_records:
                    row = self.native_records[record_hash]
                    return result(("address", "bytes"), (row[pointer], row[field]))
        if data.startswith(calldata("isIndependentAttestorNonceUsed(address,uint256)")[:10]):
            attestor, nonce = arguments(data, ("address", "uint256"))
            if any(row["receipt"][1] == attestor and row["receipt"][7] == nonce
                   for row in self.native_records.values()):
                return result(("bool",), (True,))
        if data.startswith(calldata("latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)")[:10]):
            scope, record_type, sid, attestor = arguments(
                data, ("uint256", "bytes32", "bytes32", "address"))
            matches = [row for row in self.by_type.get(record_type, [])
                if scope == self.scope and row["record"][1] == sid and row["receipt"][1] == attestor]
            if matches:
                return result(("bytes32",), (matches[-1]["recordHash"],))
        if data.startswith(calldata("document(bytes32)")[:10]):
            document_id, = arguments(data, ("bytes32",))
            if document_id in self.documents:
                return result((DOCUMENT,), (self.documents[document_id],))
        if data.startswith(calldata("chunk(bytes32)")[:10]):
            digest, = arguments(data, ("bytes32",))
            if digest in self.chunks:
                pointer, raw = self.chunks[digest]
                return result(("address", "uint32"), (pointer, len(raw)))
        return None

    def request(self, method, params):
        value = self.custom(method, params)
        if value is not None:
            self.used.append((method, copy.deepcopy(params)))
            return value
        return super().request(method, params)


class Fixture:
    """Generate a compact complete native catalogue and replay artifacts."""

    scope = 77

    def __init__(self, *, schema_bytes=None, jcs_bytes=None, record_schema=None,
                 subject_object_override=None, byte_size_override=None):
        old_anchor = loads((BASE_FIXTURE / "anchor.json").read_bytes(), canonical=True)
        self.rows = loads((BASE_FIXTURE / "transcript.json").read_bytes(),
                          maximum=1048576, canonical=True)["calls"]
        self.capture = loads((BASE_FIXTURE / "source-capture.json").read_bytes(),
                             maximum=1048576, canonical=True)
        common = {key: value for key, value in old_anchor.items()
                  if key not in ("profile", "lanes")}
        self.anchor = dumps(common | {"profile": PROFILE, "scopeKey": str(self.scope)})
        self.a = loads(self.anchor, canonical=True)
        self.file = b"synthetic retained PNG bytes\x00\x01"
        self.files = {"media/shared.png": self.file}
        self.byte_size = (str(len(self.file)) if byte_size_override is None
                          else str(byte_size_override))
        self.object_schema = SCHEMAS[OBJECT_NAME] if schema_bytes is None else schema_bytes
        self.jcs = JCS_BYTES if jcs_bytes is None else jcs_bytes
        self.record_schema_name = OBJECT_NAME if record_schema is None else record_schema
        self.record_schema_id = schema_id(self.record_schema_name)
        self.chunks = {}
        self.documents = {}
        self._pointer = 1000
        self._document("RAW_BYTES", 1, RAW_DEFINITION, RAW_BYTES)
        self._document("RFC8785_JCS", 1, self.jcs, RAW_BYTES)
        self._document(self.record_schema_name, 0, self.object_schema, JCS_ID)
        first_id, second_id = H("object source"), H("object derivative")
        roles = {value: key for key, value in ROLE_IDS.items()}
        first = self._object(first_id, roles["SOURCE_MASTER"], "SHA256",
            "0x" + sha256(self.file).hexdigest(), [])
        second = self._object(second_id, roles["DISPLAY_DERIVATIVE"], "KECCAK256",
            keccak256(self.file), [{"type": "derivation", "subtype": "urn:test:derived-from",
                                    "objectId": first_id}])
        self.records = []
        previous = ZERO
        for index, value in enumerate((first, second)):
            original_object = value["object"]["objectId"]
            subject_object = subject_object_override if index == 0 and subject_object_override else original_object
            row = self._record(value, index, previous, subject_object)
            self.records.append(row); previous = row["receipt"][5]

    def _chunk(self, raw):
        digest = keccak256(raw)
        if digest not in self.chunks:
            self._pointer += 1
            self.chunks[digest] = (A(self._pointer), raw)
        return digest, self.chunks[digest][0]

    def _document(self, name, kind, raw, canonical):
        chunks = tuple(self._chunk(raw[i:i + 8192])[0] for i in range(0, len(raw), 8192))
        spec = (name, kind, keccak256(raw), canonical, ZERO, "", len(raw))
        declaration = keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, chunks)))
        self.documents[schema_id(name)] = (True, 2, declaration, spec, chunks)

    def _object(self, object_id, role, algorithm, digest, relationships):
        return {"version": "1", "collectionId": str(self.scope), "object": {
            "objectId": object_id, "objectRole": role, "uri": "ipfs://synthetic-retained-file",
            "contentHash": digest, "mimeType": "image/png", "byteSize": self.byte_size,
            "formatId": schema_id("PRONOM:fmt/13"), "schemaId": H("file bytes")},
            "hashAlgorithm": algorithm, "format": {"kind": "pronom", "puid": "fmt/13"},
            "significantProperties": [{"type": "urn:test:property", "value": "retained exact"}],
            "relationships": relationships}

    def _record(self, value, index, previous, subject_object):
        payload = dumps(value)
        subject = (2, self.scope, 0, subject_object)
        sid = subject_id("media", self.a["chainId"], self.a["core"], str(self.scope),
                         object_id=subject_object)
        attestor, nonce, deadline, effective = A(800 + index), 900 + index, 2000000000, 100 + index
        content = (1, hex_bytes(keccak256(payload)), JCS_ID)
        scheme = schema_id("DIRECT")
        # The full signature bundle commits the exact typed 14-word preimage even for DIRECT.
        word_types = ("bytes32", "address", "uint256", "bytes32", "bytes32", "bytes32",
            "uint16", "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint256", "uint64")
        uri = ""
        word_values = (TYPE_HASH, attestor, self.scope, sid, FAMILY, self.record_schema_id,
            content[0], keccak256(content[1]), content[2], keccak256(uri.encode()),
            keccak256(payload), effective, nonce, deadline)
        words_raw = encode(word_types, word_values)
        words = tuple("0x" + words_raw[i:i + 32].hex() for i in range(0, len(words_raw), 32))
        saved_domain = domain(int(self.a["chainId"]), self.a["host"])
        bundle = encode(("bytes32", ("bytes32",) * 14, "bytes"),
                        (saved_domain, words, b""))
        signature = (1, hex_bytes(keccak256(bundle)), RAW_BYTES)
        record = (FAMILY, sid, content, uri, self.record_schema_id, scheme, signature, effective)
        record_hash = generic_hash(int(self.a["chainId"]), self.a["host"], self.a["core"],
                                   self.scope, attestor, record)
        head = record_chain(self.a["chainId"], self.a["host"], str(self.scope), FAMILY,
                            previous, record_hash, str(index))
        authorization = keccak256(b"\x19\x01" + hex_bytes(saved_domain)
                                  + hex_bytes(keccak256(words_raw)))
        receipt = (self.scope, attestor, 5, 1000 + index, index, head, authorization,
                   nonce, deadline, keccak256(self.object_schema), keccak256(self.jcs))
        _, payload_pointer = self._chunk(payload)
        _, bundle_pointer = self._chunk(bundle)
        return {"recordHash": record_hash, "record": record, "receipt": receipt,
            "subject": subject, "payload": payload, "bundle": bundle,
            "payloadPointer": payload_pointer, "bundlePointer": bundle_pointer}

    def transport(self):
        return NativeTransport(self.rows, self.capture, self.scope, self.records,
                               self.documents, self.chunks)

    def catalogue(self):
        return IndependentCatalogSource(self.anchor, self.transport())

    def artifacts(self):
        catalogue = self.catalogue()
        snapshot = catalogue.snapshot(); transcript = catalogue.transcript()
        source_hash = keccak256(snapshot)
        objects = sorted(({"recordHash": row["recordHash"], "path": "media/shared.png"}
                          for row in self.records), key=lambda row: row["recordHash"])
        plan = dumps({"mode": MODE, "version": "1", "sourceSnapshotHash": source_hash,
            "profileHash": PROFILE_HASH, "objects": objects})
        return {"catalogue": catalogue, "anchor": self.anchor, "transcript": transcript,
            "snapshot": snapshot, "plan": plan, "files": dict(self.files),
            "anchorHash": keccak256(self.anchor), "transcriptHash": keccak256(transcript),
            "sourceHash": source_hash, "planHash": keccak256(plan), "profileHash": PROFILE_HASH}


def example_outputs():
    """Build the compact synthetic replay witness and expected projections."""
    artifacts = Fixture().artifacts()
    pins = {"anchor_hash": artifacts["anchorHash"],
        "transcript_hash": artifacts["transcriptHash"], "source_hash": artifacts["sourceHash"],
        "plan_hash": artifacts["planHash"], "profile_hash": PROFILE_HASH,
        "provenance": "synthetic_fixture", "disclosure": "public"}
    package = build(artifacts["anchor"], artifacts["transcript"], artifacts["plan"],
                    artifacts["files"], **pins)
    manifest_hash = keccak256(package["manifest.json"])
    verify(package, manifest_hash)
    retained_pins = dumps({"mode": MODE, "version": "1", "provenance": "synthetic_fixture",
        "qualification": "Synthetic full native-wire replay fixture; declared MIME and PRONOM fixture values are not detected media format. No historical event, trusted RPC, state proof, format detection, authority, institutional acceptance or actual-chain claim.",
        "anchorHash": pins["anchor_hash"], "transcriptHash": pins["transcript_hash"],
        "sourceSnapshotHash": pins["source_hash"], "planHash": pins["plan_hash"],
        "profileHash": pins["profile_hash"], "manifestHash": manifest_hash,
        "reportHash": keccak256(package["projection/report.json"]),
        "comparisonsHash": keccak256(package["projection/comparisons.json"]),
        "premisHash": keccak256(package["projection/premis.xml"]),
        "actualChainAcceptance": False, "historicalFixityPerformedProven": False,
        "historicalEventsInvented": False, "formatIdentified": False})
    output = {"source/anchor.json": artifacts["anchor"],
        "source/transcript.json": artifacts["transcript"], "input/plan.json": artifacts["plan"],
        "retained/media/shared.png": artifacts["files"]["media/shared.png"],
        "expected/report.json": package["projection/report.json"],
        "expected/comparisons.json": package["projection/comparisons.json"],
        "expected/premis.xml": package["projection/premis.xml"], "pins.json": retained_pins}
    output["index.json"] = dumps({"mode": MODE, "version": "1",
        "scope": "compact_synthetic_replay_inputs_and_expected_outputs",
        "fullPackageRetained": False, "xsdClosureDuplicated": False,
        "files": [{"path": path, "byteLength": str(len(raw)), "keccak256": keccak256(raw)}
                  for path, raw in sorted(output.items())],
        "qualification": "The public builder reconstructs and verifies the omitted package and pinned PREMIS dependency closure offline."})
    return output


def manage_example(*, check):
    """Write or byte-check the deterministic compact example."""
    outputs = example_outputs()
    if check:
        actual = {path.relative_to(EXAMPLE).as_posix(): path.read_bytes()
                  for path in EXAMPLE.rglob("*") if path.is_file()}
        if actual != outputs:
            raise SystemExit("retained PREMIS worked example differs")
    else:
        for relative, raw in outputs.items():
            path = EXAMPLE / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    return outputs


class PremisRetainedTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = Fixture()
        cls.a = cls.fixture.artifacts()

    def call_project(self, artifacts=None, **changes):
        a = self.a if artifacts is None else artifacts
        args = {"source_hash": a["sourceHash"], "plan_hash": a["planHash"],
            "profile_hash": a["profileHash"], "disclosure": "public"}
        args.update(changes)
        return project(a["catalogue"], a["plan"], a["files"], **args)

    def call_replay(self, artifacts=None, **changes):
        a = self.a if artifacts is None else artifacts
        args = {"anchor_hash": a["anchorHash"], "transcript_hash": a["transcriptHash"],
            "source_hash": a["sourceHash"], "plan_hash": a["planHash"],
            "profile_hash": a["profileHash"], "provenance": "synthetic_fixture",
            "disclosure": "public"}
        args.update(changes)
        return replay(a["anchor"], a["transcript"], a["plan"], a["files"], **args)

    def reject_project(self, artifacts=None, **changes):
        with self.assertRaises(MuseumError): self.call_project(artifacts, **changes)

    def test_full_native_replay_two_roles_one_file_and_exact_hashes(self):
        result = self.call_replay()
        self.assertIsNotNone(result.xml)
        report = loads(result.report, canonical=True)
        comparisons = loads(result.comparisons, canonical=True)
        source = loads(result.source, maximum=16777216, canonical=True)
        self.assertEqual((report["status"], report["selectedObjects"], report["suppliedFiles"]),
                         ("supported", "2", "1"))
        self.assertEqual(report["performedLocalComparisons"], "2")
        self.assertTrue(report["allSelectedFilesMatch"])
        self.assertEqual({row["expectedOriginalDeclaration"]["algorithm"] for row in comparisons},
                         {"SHA256", "KECCAK256"})
        self.assertEqual({row["path"] for row in comparisons}, {"media/shared.png"})
        self.assertTrue(all(row["status"] == "matches" and
            row["historicalPerformanceProven"] is False and row["historicalCheckTime"] is None
            for row in comparisons))
        self.assertEqual(len(source["lanes"]), 8)
        self.assertEqual(sum(lane["count"] != "0" for lane in source["lanes"]), 1)
        self.assertTrue(all(lane["status"] in ("authenticated_empty", "complete_history")
                            for lane in source["lanes"]))
        self.assertEqual(result.source, self.a["snapshot"])

    def test_artifacts_expose_exact_offline_inputs_and_replay_is_closed(self):
        self.assertEqual(set(("anchor", "transcript", "snapshot", "plan", "files"))
                         <= set(self.a), True)
        self.assertEqual(keccak256(self.a["anchor"]), self.a["anchorHash"])
        self.assertEqual(keccak256(self.a["transcript"]), self.a["transcriptHash"])
        source = IndependentCatalogSource(self.a["anchor"],
            ReplayTransport(self.a["transcript"], self.a["transcriptHash"]))
        self.assertEqual(source.snapshot(), self.a["snapshot"])
        self.assertEqual(source.transcript(), self.a["transcript"])

    def test_missing_and_changed_files_produce_diagnostics_and_no_xml(self):
        same_length_changed = bytes([self.fixture.file[0] ^ 1]) + self.fixture.file[1:]
        for files, reasons in (({}, {"retained_file_missing"}),
                ({"media/shared.png": self.fixture.file + b"changed"},
                 {"retained_file_differs_from_original_declaration"}),
                ({"media/shared.png": same_length_changed},
                 {"retained_file_differs_from_original_declaration"})):
            result = project(self.a["catalogue"], self.a["plan"], files,
                source_hash=self.a["sourceHash"], plan_hash=self.a["planHash"],
                profile_hash=PROFILE_HASH, disclosure="public")
            self.assertIsNone(result.xml)
            report = loads(result.report, canonical=True)
            self.assertEqual(report["status"], "unsupported")
            self.assertEqual({row["reasonCode"] for row in report["issues"]}, reasons)
            self.assertFalse(report["allSelectedFilesMatch"])
            self.assertEqual(report["performedLocalComparisons"], "0" if not files else "2")
        empty_plan = dumps({"mode": MODE, "version": "1",
            "sourceSnapshotHash": self.a["sourceHash"], "profileHash": PROFILE_HASH,
            "objects": []})
        empty = project(self.a["catalogue"], empty_plan, {}, source_hash=self.a["sourceHash"],
            plan_hash=keccak256(empty_plan), profile_hash=PROFILE_HASH, disclosure="public")
        empty_report = loads(empty.report, canonical=True)
        self.assertIsNone(empty.xml)
        self.assertEqual((empty_report["selectedObjects"], empty_report["performedLocalComparisons"]),
                         ("0", "0"))
        self.assertEqual({row["reasonCode"] for row in empty_report["issues"]},
                         {"no_selected_preservation_objects"})

    def test_correct_digest_with_wrong_declared_byte_size_produces_no_xml(self):
        fixture = Fixture(byte_size_override=len(self.fixture.file) + 1)
        artifacts = fixture.artifacts()
        result = self.call_project(artifacts)
        self.assertIsNone(result.xml)
        report = loads(result.report, canonical=True)
        self.assertEqual(report["status"], "unsupported")
        self.assertEqual({row["reasonCode"] for row in report["issues"]},
                         {"retained_file_differs_from_original_declaration"})
        comparisons = loads(result.comparisons, canonical=True)
        self.assertTrue(all(
            row["expectedOriginalDeclaration"]["digest"] ==
                row["observedLocalBytes"][row["expectedOriginalDeclaration"]["algorithm"]]
            and row["expectedOriginalDeclaration"]["byteSize"] !=
                row["observedLocalBytes"]["byteSize"]
            and row["status"] == "mismatch"
            for row in comparisons))

    def test_registered_object_schema_and_jcs_must_be_exact(self):
        for fixture in (Fixture(schema_bytes=SCHEMAS[OBJECT_NAME] + b" "),
                        Fixture(jcs_bytes=JCS_BYTES + b" "),
                        Fixture(record_schema="SYNTHETIC_FOREIGN_OBJECT_V1")):
            artifacts = fixture.artifacts()
            with self.subTest(schema=fixture.record_schema_name), self.assertRaises(MuseumError):
                self.call_project(artifacts)

    def test_media_subject_must_join_original_typed_object(self):
        artifacts = Fixture(subject_object_override=H("foreign media object")).artifacts()
        with self.assertRaisesRegex(MuseumError, "canonical object subject|original media subject"):
            self.call_project(artifacts)

    def test_provenance_is_explicit_and_synthetic_transport_cannot_claim_rpc(self):
        report = loads(self.call_project().report, canonical=True)
        self.assertEqual((report["sourceMode"], report["sourceProvenance"]),
                         ("synthetic_fixture", "synthetic_fixture"))
        self.assertFalse(report["claims"]["cryptographicStateProof"])
        with self.assertRaisesRegex(MuseumError, "synthetic transport"):
            IndependentCatalogSource(self.a["anchor"], self.fixture.transport(),
                                     provenance="trusted_rpc")
        with self.assertRaises(MuseumError):
            self.call_replay(provenance="publisher_authenticated")

    def test_external_anchor_transcript_source_plan_and_profile_pins_reject(self):
        wrong = "0x" + "99" * 32
        for changes in ({"anchor_hash": wrong}, {"transcript_hash": wrong},
                        {"source_hash": wrong}, {"plan_hash": wrong},
                        {"profile_hash": wrong}):
            with self.subTest(changes=changes), self.assertRaises(MuseumError):
                self.call_replay(**changes)
        changed = bytearray(self.a["transcript"]); changed[-2] ^= 1
        with self.assertRaises(MuseumError):
            replay(self.a["anchor"], bytes(changed), self.a["plan"], self.a["files"],
                anchor_hash=self.a["anchorHash"], transcript_hash=keccak256(bytes(changed)),
                source_hash=self.a["sourceHash"], plan_hash=self.a["planHash"],
                profile_hash=PROFILE_HASH, provenance="synthetic_fixture", disclosure="public")

    def test_plan_record_hash_order_uniqueness_paths_and_scope_are_closed(self):
        base = loads(self.a["plan"], canonical=True)
        variants = []
        value = copy.deepcopy(base); value["objects"].reverse(); variants.append(value)
        value = copy.deepcopy(base); value["objects"].append(copy.deepcopy(value["objects"][0])); variants.append(value)
        value = copy.deepcopy(base); value["objects"][0]["recordHash"] = H("absent record"); variants.append(value)
        value = copy.deepcopy(base); value["objects"][0]["path"] = "../escape"; variants.append(value)
        value = copy.deepcopy(base); value["authority"] = True; variants.append(value)
        value = copy.deepcopy(base); value["sourceSnapshotHash"] = H("wrong source"); variants.append(value)
        for value in variants:
            raw = dumps(value)
            with self.subTest(value=value), self.assertRaises(MuseumError):
                project(self.a["catalogue"], raw, self.a["files"],
                    source_hash=self.a["sourceHash"], plan_hash=keccak256(raw),
                    profile_hash=PROFILE_HASH, disclosure="public")
        extra = dict(self.a["files"]); extra["media/unselected.png"] = b"x"
        with self.assertRaises(MuseumError):
            project(self.a["catalogue"], self.a["plan"], extra,
                source_hash=self.a["sourceHash"], plan_hash=self.a["planHash"],
                profile_hash=PROFILE_HASH, disclosure="public")

    def test_file_and_plan_bounds_reject_without_large_allocations(self):
        with patch("tools.museum.premis_retained.MAX_FILE", len(self.fixture.file) - 1):
            self.reject_project()
        with patch("tools.museum.premis_retained.MAX_FILES_BYTES", len(self.fixture.file) - 1):
            self.reject_project()
        with patch("tools.museum.premis_retained.MAX_PLAN", len(self.a["plan"]) - 1):
            self.reject_project()
        self.reject_project(disclosure="restricted")

    def test_projection_does_not_invent_event_time_format_detection_or_authority(self):
        result = self.call_project()
        report = loads(result.report, canonical=True)
        provenance = loads(result.provenance, canonical=True)
        comparisons = loads(result.comparisons, canonical=True)
        self.assertNotIn(b"<premis:event", result.xml)
        self.assertNotIn(b"<premis:agent", result.xml)
        self.assertNotIn(b"eventDateTime", result.xml)
        self.assertTrue(all(row["kind"] == "object" for row in provenance))
        self.assertTrue(all(row["authority"]["humanIdentityProven"] is False
                            and row["authority"]["currentSignatureRevalidation"] is False
                            for row in provenance))
        self.assertTrue(all(row["observationBasis"] == "current_offline_byte_comparison"
                            for row in comparisons))
        for claim in ("historicalFixityPerformedProven", "historicalEventsInvented",
                      "currentAuthorityProven", "formatIdentified", "institutionalAcceptance"):
            self.assertFalse(report["claims"][claim])

    def test_closed_package_rebuilds_every_output_and_rejects_rehashed_substitution(self):
        pins = {"anchor_hash": self.a["anchorHash"], "transcript_hash": self.a["transcriptHash"],
            "source_hash": self.a["sourceHash"], "plan_hash": self.a["planHash"],
            "profile_hash": PROFILE_HASH, "provenance": "synthetic_fixture", "disclosure": "public"}
        package = build(self.a["anchor"], self.a["transcript"], self.a["plan"],
                        self.a["files"], **pins)
        manifest_hash = keccak256(package["manifest.json"])
        report = verify(package, manifest_hash)
        self.assertEqual((report["status"], report["performedLocalComparisons"]),
                         ("supported", "2"))
        changed = dict(package)
        report_value = loads(changed["projection/report.json"], canonical=True)
        report_value["status"] = "unsupported"
        changed["projection/report.json"] = dumps(report_value)
        manifest = loads(changed["manifest.json"], canonical=True)
        manifest["files"] = retained._inventory(
            {path: raw for path, raw in changed.items() if path != "manifest.json"})
        changed["manifest.json"] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            verify(changed, keccak256(changed["manifest.json"]))
        changed = dict(package)
        manifest = loads(changed["manifest.json"], canonical=True)
        manifest["files"][0]["byteLength"] = str(int(manifest["files"][0]["byteLength"]) + 1)
        changed["manifest.json"] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, "inventory differs"):
            verify(changed, keccak256(changed["manifest.json"]))

    def test_checked_in_compact_example_rebuilds_public_package_exactly(self):
        retained.definitions(check=True)
        expected = example_outputs()
        actual = {path.relative_to(EXAMPLE).as_posix(): path.read_bytes()
                  for path in EXAMPLE.rglob("*") if path.is_file()}
        self.assertEqual(actual, expected)
        pins = loads(actual["pins.json"], canonical=True)
        package = build(actual["source/anchor.json"], actual["source/transcript.json"],
            actual["input/plan.json"], {"media/shared.png": actual["retained/media/shared.png"]},
            anchor_hash=pins["anchorHash"], transcript_hash=pins["transcriptHash"],
            source_hash=pins["sourceSnapshotHash"], plan_hash=pins["planHash"],
            profile_hash=pins["profileHash"], provenance=pins["provenance"], disclosure="public")
        self.assertEqual(keccak256(package["manifest.json"]), pins["manifestHash"])
        report = verify(package, pins["manifestHash"])
        self.assertEqual(package["projection/report.json"], actual["expected/report.json"])
        self.assertEqual(package["projection/comparisons.json"], actual["expected/comparisons.json"])
        self.assertEqual(package["projection/premis.xml"], actual["expected/premis.xml"])
        self.assertEqual((report["sourceMode"], report["sourceProvenance"]),
                         ("synthetic_fixture", "synthetic_fixture"))
        self.assertFalse(report["claims"]["historicalFixityPerformedProven"])
        index = loads(actual["index.json"], canonical=True)
        self.assertFalse(index["fullPackageRetained"])
        self.assertFalse(index["xsdClosureDuplicated"])
        self.assertEqual({row["path"] for row in index["files"]}, set(actual) - {"index.json"})


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] in ("--generate-example", "--check-example"):
        outputs = manage_example(check=sys.argv[1] == "--check-example")
        print(dumps({"examplePath": EXAMPLE.as_posix(), "files": str(len(outputs)),
            "indexHash": keccak256(outputs["index.json"]),
            "pinsHash": keccak256(outputs["pins.json"])}).decode())
    else:
        unittest.main()

"""Synthetic original-wire regression controls, never actual source-capture evidence."""
import copy
from hashlib import sha256
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import Array, encode
from .chain_rpc import ReplayTransport
from .citations import canonical_citation, parse_citation
from .independent_wire import DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, ZERO
from .institutional import NAMES, SCHEMAS, PROFILE_BYTES, PROFILE_HASH, JCS_ID, admit, render, project_institutional, validate_payload, validator
from .institutional_source import InstitutionalOwnerSource, PROFILE
from .institutional_package import build_institutional_package, verify_institutional_package
from .owner_record_source import OwnerRecordSource
from .package import write_package
from .package_recorded import build_recorded_package
from .test_exhibitions import date, reference
from .test_loans import OwnerFixture, party
from .test_package import changed
from .test_package_recorded import inputs, pins
from .test_preservation_resources import A, H
from .test_recorded_account import ROOT, load_source


def payload(family, *, suffix="", anchor=None):
    anchor = anchor or {"chainId": "31337", "core": A(2), "blockNumber": "20"}
    value = {"version": "1", "recordId": "urn:test:institutional:" + family.lower() + suffix,
        "tokenId": "41", "recordedDate": date(), "supersedes": []}
    binding = {"instrument": reference(20), "custodian": party("Instrument custodian", "custodian"),
        "transfer": {"chainId": anchor["chainId"], "core": anchor["core"], "tokenId": "41", "blockNumber": anchor["blockNumber"],
            "transactionHash": H(19), "logIndex": "3", "from": A(8), "to": A(9)}}
    extra = {"ACCESSION": {"accessionIdentifier": "2026.41\r\nΔ", "acquiringInstitution": party("Named museum", "museum"), "titleBinding": binding},
        "DEACCESSION": {"reasonClass": "urn:test:reason:transfer", "disposition": reference(21), "titleBinding": binding},
        "REDEMPTION_CLAIM": {"program": H(12), "entitlementDescription": "One physical print — token remains", "fulfillment": None},
        "CITATION": {"citedWork": canonical_citation(anchor["chainId"], anchor["core"], "41", {"kind": "chain", "hash": H(8)}),
            "citingWork": reference(13), "contextNote": "Exact author's context\n<not interpreted markup>"}}
    return {**value, **extra[family]}


class InstitutionalFixture(OwnerFixture):
    def __init__(self, *, anchor=None, families=None, edit=None):
        super().__init__(anchor=anchor)
        self.a["records"] = []  # The new source profile excludes unrelated owner lanes.
        self.a["profile"] = PROFILE
        self.evidence = dumps({"mode": "synthetic_institutional_wire_control", "notAnActualDeployment": True})
        self.a["deploymentEvidenceHash"] = keccak256(self.evidence)
        for family, raw in SCHEMAS.items():
            name = NAMES[family]; chunks = [self.chunk(raw[i:i+8192]) for i in range(0, len(raw), 8192)]
            spec = (name, 0, keccak256(raw), JCS_ID, ZERO, "", len(raw))
            doc = (True, 0, keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, chunks))), spec, chunks)
            self.add(self.a["schemas"], "document(bytes32)", ("bytes32",), (schema_id(name),), (DOCUMENT,), (doc,))
            self.documents[name] = raw
        self.selected = []
        for family in (families if families is not None else NAMES):
            value = payload(family, anchor=self.a)
            if edit: edit(family, value)
            self.selected.append(self.append(family, NAMES[family], value))
        self.heads()

    def heads(self):
        for (token, family), hashes in self.lanes.items():
            self.add(self.a["host"], "recordChainHash(uint256,bytes32)", ("uint256", "bytes32"), (token, family),
                ("bytes32", "uint64"), (self.rows[hashes[-1]][1][4], len(hashes)))

    def adapter(self): return InstitutionalOwnerSource(dumps(self.a), self)

    def replay(self):
        synthetic = self.adapter(); synthetic.snapshot(); transcript = synthetic.reader.transcript()
        source = InstitutionalOwnerSource(dumps(self.a), ReplayTransport(transcript, keccak256(transcript)), provenance="trusted_rpc")
        return source, {"anchor.json": dumps(self.a), "transcript.json": transcript, "deployment-evidence.json": self.evidence}, synthetic


class CitationTests(unittest.TestCase):
    def test_canonical_typed_namespaces_and_large_exact_numbers(self):
        for n in (2**53-1, 2**53, 2**53+1, 2**256-1):
            for kind in ("fin", "snap", "chain"):
                citation = canonical_citation(str(n), A(2), str(n), {"kind": kind, "hash": H(1)})
                self.assertEqual(parse_citation(citation, require_state=True)["tokenId"], str(n))
    def test_reject_aliases_untyped_state_zero_and_noncanonical_integers(self):
        good = canonical_citation("1", A(2), "41", {"kind": "fin", "hash": H(1)})
        for bad in (good.replace("eip155:1", "eip155:01"), good.replace("@fin:", "@"), good.replace("@fin:", "@recovery:"),
                    good.replace("/41", "/0"), good.replace("/41", "/" + str(2**256)), good.replace(H(1), ZERO), good + " ",
                    good.replace(A(2), "0x" + "AB"*20)):
            with self.subTest(bad=bad), self.assertRaises(MuseumError): parse_citation(bad, require_state=True)
        with self.assertRaises(MuseumError): parse_citation(good.split("@")[0], require_state=True)


class InstitutionalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.model = validator(ROOT)

    def test_all_families_keep_distinct_qualified_facts(self):
        f = InstitutionalFixture(); source = f.adapter(); source.snapshot()
        rows = admit(source, f.selected); files = render(rows, self.model)
        report = loads(files["institutional/report.json"])
        self.assertFalse(any(report["claims"].values()))
        self.assertEqual({r["family"] for r in rows}, set(NAMES))
        self.assertTrue(report["missingPublicEvidence"])
        self.assertIn("2026.41\r\nΔ", [r["value"].get("accessionIdentifier") for r in rows])
        resources = loads(files["institutional/index.json"])["resources"]
        self.assertEqual({r["type"] for r in resources}, {"LinguisticObject", "Group"})
        self.assertFalse(any(r["type"] in ("Acquisition", "TransferOfCustody") for r in resources))
        coverage = loads(files["institutional/coverage.json"], maximum=524288)
        self.assertTrue(any(r["sourcePath"] == "/fulfillment" and r["value"] is None for r in coverage))
        self.assertTrue(any(r["sourcePath"] == "/supersedes" and r["value"] == [] for r in coverage))
        self.assertEqual(files, render(admit(source, list(reversed(f.selected))), self.model))

    def test_original_v1_source_profile_and_capture_remain_unchanged(self):
        f = OwnerFixture(); s = f.adapter(); raw = s.snapshot()
        self.assertNotIn("additionalEvidence", loads(raw, maximum=2097152))
        with self.assertRaisesRegex(MuseumError, "anchor shape"): OwnerRecordSource(dumps(InstitutionalFixture().a), f)

    def test_first_claim_wins_full_lane_and_supplements_cannot_reset_primacy(self):
        f = InstitutionalFixture(families=["REDEMPTION_CLAIM"]); first = f.selected[0]
        v = payload("REDEMPTION_CLAIM", suffix="-second"); v["supersedes"] = [first]
        second = f.append("REDEMPTION_CLAIM", NAMES["REDEMPTION_CLAIM"], v)
        v = payload("REDEMPTION_CLAIM", suffix="-different"); v["program"] = H(99)
        third = f.append("REDEMPTION_CLAIM", NAMES["REDEMPTION_CLAIM"], v); f.heads()
        s = f.adapter(); s.snapshot(); rows = admit(s, [second, third])
        by_hash = {r["source"]["recordHash"]: r for r in rows}
        self.assertEqual(by_hash[second]["primacy"]["operativeClaim"], first)
        self.assertEqual(by_hash[second]["primacy"]["disposition"], "supplemental_documentation")
        self.assertEqual(by_hash[third]["primacy"]["disposition"], "operative_claim")
        f.a["records"] = [r for r in f.a["records"] if r["recordHash"] != first]
        with self.assertRaisesRegex(MuseumError, "complete redemption selection"): f.adapter().snapshot()

    def test_wrong_lane_head_and_unrecognized_earlier_schema_reject(self):
        f = InstitutionalFixture(families=["REDEMPTION_CLAIM"])
        f.add(f.a["host"], "recordChainHash(uint256,bytes32)", ("uint256", "bytes32"), (41, schema_id("REDEMPTION_CLAIM")), ("bytes32", "uint64"), (H(88), 1))
        with self.assertRaisesRegex(MuseumError, "head differs"): f.adapter().snapshot()
        f = InstitutionalFixture(families=[])
        first = f.append("REDEMPTION_CLAIM", "STREAM_VALUATION_V1", {"opaque": "old schema"})
        second = f.append("REDEMPTION_CLAIM", NAMES["REDEMPTION_CLAIM"], payload("REDEMPTION_CLAIM")); f.heads()
        s = f.adapter()
        with self.assertRaisesRegex(MuseumError, "public schema|exact original"):
            s.snapshot(); admit(s, [second])

    def test_schema_token_and_title_transfer_mismatch_reject(self):
        mutations = [lambda v: v["titleBinding"]["transfer"].update(tokenId="42"),
            lambda v: v["titleBinding"]["transfer"].update(core=A(99)),
            lambda v: v["titleBinding"]["transfer"].update(blockNumber="21"),
            lambda v: v["titleBinding"]["transfer"].update(chainId="1"),
            lambda v: v["acquiringInstitution"].update(kind="Person"),
            lambda v: v.update(unrequested="must reject")]
        for mutate in mutations:
            f = InstitutionalFixture(families=["ACCESSION"], edit=lambda _, v: mutate(v)); s = f.adapter()
            with self.subTest(mutate=mutate), self.assertRaises(MuseumError):
                s.snapshot(); admit(s, f.selected)
        for kind in ("fin", "snap", "chain"):
            f = InstitutionalFixture(families=["CITATION"], edit=lambda _, v: v.update(citedWork=canonical_citation("31337", A(2), "42", {"kind": kind, "hash": H(8)})))
            s = f.adapter()
            with self.assertRaisesRegex(MuseumError, "cited work"):
                s.snapshot(); admit(s, f.selected)

    def test_exact_instrument_bytes_and_missing_versus_verified(self):
        raw = b"Public synthetic instrument\r\n\xce\x94"
        for algorithm in ("1", "2"):
            h = {"algorithm": algorithm, "digest": keccak256(raw) if algorithm == "1" else "0x" + sha256(raw).hexdigest(), "canonicalizationId": RAW_BYTES}
            f = InstitutionalFixture(families=["ACCESSION"], edit=lambda _, v: v["titleBinding"]["instrument"].update(hash=h))
            s = f.adapter(); s.snapshot(); key = keccak256(dumps(h))
            rows = admit(s, f.selected, documents={key: raw})
            ref = next(r for r in rows[0]["references"] if r["sourcePath"] == "/titleBinding/instrument")
            self.assertTrue(ref["bytesVerified"])
            with self.assertRaisesRegex(MuseumError, "digest"): admit(s, f.selected, documents={key: raw+b"!"})
            with self.assertRaisesRegex(MuseumError, "unreferenced"): admit(s, f.selected, documents={H(87): raw})
        with self.assertRaises(MuseumError): admit(s, f.selected, documents={key: b"x"*1048577})

    def test_identity_collision_invalid_dates_and_missing_commitments_reject(self):
        for mutate in (lambda v: v["acquiringInstitution"].update(entityId=v["recordId"]),
            lambda v: v["acquiringInstitution"].update(entityId="eip155:1:0x01"),
            lambda v: v["recordedDate"].update(earliest="2026-99-01T00:00:00Z"),
            lambda v: v["titleBinding"]["instrument"]["hash"].update(digest=ZERO)):
            f = InstitutionalFixture(families=["ACCESSION"], edit=lambda _, v: mutate(v)); s = f.adapter()
            with self.assertRaises(MuseumError):
                s.snapshot(); admit(s, f.selected)
        with self.assertRaises(MuseumError): validate_payload("CITATION", b'{"version":"1","version":"1"}')

    def test_public_projection_requires_concrete_pinned_recorded_source(self):
        f = InstitutionalFixture(); synthetic = f.adapter(); raw = synthetic.snapshot()
        plan = dumps({"version": "1", "ownerSourceHash": keccak256(raw), "records": f.selected})
        with self.assertRaisesRegex(MuseumError, "concrete recorded"): project_institutional(synthetic, plan, source_hash=keccak256(raw), plan_hash=keccak256(plan), profile_hash=PROFILE_HASH, model=self.model)
        source, _, _ = f.replay(); raw = source.snapshot(); plan = dumps({"version": "1", "ownerSourceHash": keccak256(raw), "records": f.selected})
        with patch("socket.socket", side_effect=AssertionError("offline")):
            self.assertTrue(project_institutional(source, plan, source_hash=keccak256(raw), plan_hash=keccak256(plan), profile_hash=PROFILE_HASH, model=self.model))
        with self.assertRaises(MuseumError): project_institutional(source, plan, source_hash=H(99), plan_hash=keccak256(plan), profile_hash=PROFILE_HASH, model=self.model)

    def test_package_preserves_source_and_rejects_rehashed_output_tampering(self):
        actual = load_source(); f = InstitutionalFixture(anchor=actual.anchor); source, owner_inputs, _ = f.replay(); raw = source.snapshot()
        owner_pins = {"anchorHash": keccak256(owner_inputs["anchor.json"]), "transcriptHash": keccak256(owner_inputs["transcript.json"]), "sourceHash": keccak256(raw)}
        plan = dumps({"version": "1", "ownerSourceHash": keccak256(raw), "records": f.selected})
        original = build_recorded_package(inputs(), root=ROOT, disclosure="public", **pins())
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); write_package(original, root / "source")
            kwargs = dict(plan_hash=keccak256(plan), profile_hash=PROFILE_HASH, owner_inputs=owner_inputs, owner_pins=owner_pins, disclosure="public")
            with patch("socket.socket", side_effect=AssertionError("offline")):
                package = build_institutional_package(root / "source", original.manifest_hash, plan, **kwargs)
                for name, content in original.files: self.assertEqual(dict(package.files)["source/" + name], content)
                self.assertEqual(dict(package.files)["owner-records/deployment-evidence.json"], f.evidence)
                write_package(package, root / "export")
                self.assertEqual(verify_institutional_package(root / "export", package.manifest_hash), package)
            bad = changed(package, "institutional/report.json", dumps({"legalTitleProven": True}))
            write_package(bad, root / "bad")
            with self.assertRaisesRegex(MuseumError, "semantic reconstruction"): verify_institutional_package(root / "bad", bad.manifest_hash)
            kwargs["disclosure"] = "restricted"
            with self.assertRaisesRegex(MuseumError, "public classification"): build_institutional_package(root / "source", original.manifest_hash, plan, **kwargs)

    def test_mutable_source_views_cannot_change_pinned_output(self):
        f = InstitutionalFixture(); source, _, _ = f.replay(); raw = source.snapshot()
        plan = dumps({"version": "1", "ownerSourceHash": keccak256(raw), "records": f.selected})
        options = dict(source_hash=keccak256(raw), plan_hash=keccak256(plan), profile_hash=PROFILE_HASH, model=self.model)
        original = project_institutional(source, plan, **options)
        h = f.selected[0]; v = loads(hex_bytes(source.records[h]["payloadHex"]))
        v["accessionIdentifier"] = "forged after capture"
        source.records[h]["payloadHex"] = "0x" + dumps(v).hex()
        source.redemption_lanes.clear()
        self.assertEqual(project_institutional(source, plan, **options), original)
        source.reader.rows[0]["result"] = "tampered transcript"
        with self.assertRaises(MuseumError): project_institutional(source, plan, **options)

    def test_entire_retained_source_closure_rejects_unrelated_or_opaque_lanes(self):
        f = InstitutionalFixture(families=["ACCESSION"])
        f.append("VALUATION", "STREAM_VALUATION_V1", {"confidential": True, "amount": "12345.0045"})
        with self.assertRaisesRegex(MuseumError, "family"): f.adapter().snapshot()
        # Even an unselected immediate predecessor cannot put an opaque source
        # payload into the retained transcript through a supported family.
        f = InstitutionalFixture(families=[])
        old = f.append("ACCESSION", "STREAM_VALUATION_V1", {"confidential": True, "amount": "12345.0045"})
        f.append("ACCESSION", NAMES["ACCESSION"], payload("ACCESSION"))
        f.a["records"] = [r for r in f.a["records"] if r["recordHash"] != old]
        with self.assertRaisesRegex(MuseumError, "predecessor public schema"): f.adapter().snapshot()

    def test_generated_definitions_match_exact_candidate_bytes(self):
        for family, raw in SCHEMAS.items(): self.assertEqual((ROOT / "institutional" / (NAMES[family] + ".json")).read_bytes(), raw)
        self.assertEqual((ROOT / "institutional/profile.json").read_bytes(), PROFILE_BYTES)


if __name__ == "__main__": unittest.main()

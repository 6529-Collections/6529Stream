"""Actual registered local records, exact account authority and retained model controls."""

import copy
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .account_profile import (ACCOUNT_PREFIX, JCS_BYTES, JCS_ID, JCS_NAME, NAME, PROFILE_SCHEMA_BYTES,
                              AccountProjectionProfile, account_iri)
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import Array, calldata, decode, encode
from .chain_rpc import ReplayTransport
from .independent_publication import IndependentPublicationAdapter
from .independent_source import IndependentSourceAdapter
from .independent_wire import DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, RAW_DEFINITION, verify_document
from .projection import CRM, LA, project_fixture
from .projection_v2 import CONTENT, CONTENT_KIND
from .recorded_projection import output_files, replay_source
from .recorded_selection import project_recorded, select_recorded
from .recorded_semantic import RegisteredInterpretationCapture, RecordedSemanticSource, resolve_pointer
from .review import REVIEW_RELATION, _selector, _validate
from .schemas import NAMES

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
FIXTURE = ROOT / "account-profile/local-fixture"
SOURCE_HASH = "0x440a82dcf5a444b1a3e11f82575c497c05eb19511cc824f4c16b79b656d16822"
PUBLICATION_HASH = "0x5630ecffe7bc9e149ac7cc1cd244acbfb64a91d1f6e02c0d9f862db744984dcb"
INTERPRETATION_HASH = "0xb5477ea0ac4e93eb25affaff3f9636f3f31610c160e77d17596fd39257aff78e"
PROFILE_HASH = "0xa7c728732beeb6fa94be1e870cd54dc470a6050986e084393e7308a1b542075f"


def load_source():
    return replay_source(ROOT, FIXTURE, source_hash=SOURCE_HASH, publication_hash=PUBLICATION_HASH,
        interpretation_hash=INTERPRETATION_HASH, profile_hash=PROFILE_HASH)


class RecordedAccountTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = load_source()
        cls.selection = loads((FIXTURE / "selection.json").read_bytes())
        cls.plan = loads((FIXTURE / "plan.json").read_bytes())
        cls.original = cls.source.record(cls.plan["entityAuthoritySet"][0])
        cls.negatives = {loads(r.payload)["assertions"][0]["rationale"].removeprefix("Actual signed negative: "): r
            for r in cls.source.state.records if r.selector.schema_id == schema_id(NAMES[1])
            and loads(r.payload)["assertions"][0]["rationale"].startswith("Actual signed negative: ")}

    def select(self, policy):
        return select_recorded(self.source, dumps(policy), policy_hash=keccak256(dumps(policy)))

    def project(self, policy=None, plan=None):
        policy = copy.deepcopy(self.selection if policy is None else policy)
        plan = copy.deepcopy(self.plan if plan is None else plan)
        plan["selectionPolicyHash"] = keccak256(dumps(policy))
        return project_recorded(self.source, dumps(policy), dumps(plan), selection_hash=keccak256(dumps(policy)), plan_hash=keccak256(dumps(plan)))

    def testActualRegisteredRecordsProduceFourExactOfflineModelResources(self):
        with patch("socket.socket", side_effect=AssertionError("offline projection opened network")):
            result = self.project()
        for name, raw in output_files(result).items():
            self.assertEqual(raw, (FIXTURE / name).read_bytes(), name)
        self.assertEqual(len(self.source.records), 18)
        by_id = {r.identifier: loads(r.expanded)[0] for r in result.resources}
        self.assertEqual(by_id["urn:local:semantic:work"]["@type"], [CRM + "E89_Propositional_Object"])
        self.assertEqual(by_id["urn:local:semantic:text"][CRM + "P190_has_symbolic_content"],
            [{"@value": "A\r\n& < > 🧭 115792089237316195423570985008687907853269984665640564039457584007913129639935"}])
        report = loads(result.report)
        self.assertEqual(report["sourceEvidence"]["environment"], "local_evm_fixture")
        self.assertFalse(any(report["claims"].values()))
        self.assertFalse(report["sourceEvidence"]["humanIdentityEstablished"])

    def testOriginalSchemasAndAcyclicRegisteredProfileDocumentsRemainExact(self):
        profile = self.source.profile
        self.assertEqual(profile.profile_hash, PROFILE_HASH)
        _validate(PROFILE_SCHEMA_BYTES, profile.profile_bytes)
        for name, (_, raw) in profile.documents.items():
            self.assertEqual(raw, (ROOT / "account-profile" / (name + ".json")).read_bytes())
            if name in NAMES:
                self.assertEqual(raw, (ROOT / (name + ".json")).read_bytes())
            if name != NAME:
                self.assertNotIn(PROFILE_HASH.encode(), raw)
        self.assertEqual(JCS_BYTES, (ROOT / "account-profile/RFC8785_JCS.json").read_bytes())
        self.assertEqual(keccak256(JCS_BYTES), "0xbc33af15c6b6374052871a5fdfa255f900f56fa594f650b2d0814c681fdb35a9")
        for name, _ in profile.documents.items():
            self.assertIn(schema_id(name), self.source.interpretation_bytes.decode())
        with self.assertRaisesRegex(MuseumError, "profile pin"):
            AccountProjectionProfile(ROOT, expected_hash="0x" + "11" * 32)

    def testRetiredDefinitionsAndHistoricalAccountEvidenceDoNotRequireCurrentSigner(self):
        value = loads(self.source.interpretation_bytes, maximum=67108864)
        for name in (JCS_NAME, NAMES[1]):
            row = next(d for d in value["documents"] if d["documentId"] == schema_id(name))
            doc, = decode((DOCUMENT,), hex_bytes(row["rawViewHex"]))
            self.assertEqual(doc[1], 2)
        facts = loads(self.original.authority_evidence)
        self.assertEqual(facts["agentIri"], "urn:6529stream:account:eip155:31337:0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
        self.assertFalse(facts["humanIdentityEstablished"])
        self.assertEqual(facts["publicationPosition"], [str(x) for x in self.source.positions[self.original.selector.record_hash]])
        self.assertNotIn("isValidSignature", self.source.interpretation_bytes.decode())

    def testSameAccountReviewIsOptedInSelfReviewNeverIndependent(self):
        result = self.select(self.selection)
        mapping = next(c for c in result.selected if loads(c.assertion)["origin"] == "human_mapping")
        self.assertEqual(mapping.basis, "account_confirmed_SELF_review")
        evidence = loads(mapping.review_evidence[0])
        self.assertIs(evidence["selfReview"], True)
        original = self.source.record(evidence["assertionRecord"])
        review = self.source.record(evidence["reviewRecord"])
        self.assertEqual(original.selector.recorder, review.selector.recorder)
        self.assertLess(self.source.positions[original.selector.record_hash], self.source.positions[review.selector.record_hash])
        self.assertEqual(loads(original.payload)["assertions"][1]["createdAt"], loads(review.payload)["assertions"][0]["createdAt"])
        for field, value, message in (("allowAccountSelfReview", False, "opt-in"),
                                     ("independentReviewRequired", True, "independent human review"),
                                     ("allowAccountSelfReview", 1, "boolean")):
            policy = copy.deepcopy(self.selection); policy[field] = value
            with self.assertRaisesRegex(MuseumError, message): self.select(policy)

    def testActualDifferentAccountReviewIsExplicitlyUnsupported(self):
        foreign = next(r for r in self.source.state.records if r.selector.schema_id == schema_id(NAMES[1])
            and loads(r.payload)["assertions"][0]["relation"] == REVIEW_RELATION
            and r.selector.recorder != self.original.selector.recorder)
        policy = copy.deepcopy(self.selection)
        policy["reviewerAuthoritySet"] = [_selector(foreign, "/assertions/0")]
        with self.assertRaisesRegex(MuseumError, "cross-account review is unsupported"):
            self.select(policy)
        self.assertEqual(len(self.select(self.selection).selected), 4)

    def testActuallySignedWrongChainCaseLeadingZeroAndSpoofedAgentRejectWhenSelected(self):
        for tag in ("wrong_chain", "leading_zero", "upper_case", "foreign_account"):
            record = self.negatives[tag]
            self.assertEqual(record.selector.recorder, self.original.selector.recorder)
            self.assertNotEqual(loads(record.payload)["assertions"][0]["assertingAgent"], loads(self.original.authority_evidence)["agentIri"])
            policy = copy.deepcopy(self.selection)
            policy["sourceAuthoritySet"] = [_selector(record, "/assertions/0")]
            policy["reviewerAuthoritySet"] = []
            with self.subTest(tag=tag), self.assertRaisesRegex(MuseumError, "asserting account"):
                self.select(policy)

    def testWholeSelectedPayloadRejectsEntitySpoofAccountPersonAndProfileSubstitution(self):
        for tag, message in (("declaring_agent", "declaring account"), ("account_person", "declared entity"),
                             ("wrong_profile", "semantic profile")):
            record = self.negatives[tag]
            policy = copy.deepcopy(self.selection)
            policy["sourceAuthoritySet"] = [_selector(record, "/assertions/0")]
            policy["reviewerAuthoritySet"] = []
            with self.subTest(tag=tag), self.assertRaisesRegex(MuseumError, message): self.select(policy)

    def testRehashedExternalAgentPlanCannotInventPersonOrNormalizeAccount(self):
        account = self.plan["externalEntities"][0]["id"]
        for changed in ({"id": account, "kind": "person"}, {"id": account.replace(":31337:", ":1:"), "kind": "account"},
                        {"id": account.replace(":31337:", ":031337:"), "kind": "account"},
                        {"id": account.upper(), "kind": "account"},
                        {"id": ACCOUNT_PREFIX + "31337:0x" + "11" * 20, "kind": "account"}):
            plan = copy.deepcopy(self.plan); plan["externalEntities"] = [changed]
            with self.assertRaisesRegex(MuseumError, "external account reference"): self.project(plan=plan)

    def testExactSelectorEveryWordAndPointerIsBoundAfterPolicyRehash(self):
        row = self.selection["sourceAuthoritySet"][0]
        for field in row:
            changed = copy.deepcopy(row)
            changed[field] = ("/assertions/00" if field == "pointer" else "0x" + "11" * 32 if field.endswith("Hash")
                              else "changed")
            policy = copy.deepcopy(self.selection); policy["sourceAuthoritySet"] = [changed]
            with self.subTest(field=field), self.assertRaises(MuseumError): self.select(policy)
        policy = copy.deepcopy(self.selection); policy["sourceAuthoritySet"] *= 2
        with self.assertRaisesRegex(MuseumError, "duplicated"): self.select(policy)

    def testOriginalCustomByteRecordsNeverBecomeSemanticThroughSelectionMetadata(self):
        original = next(r for r in self.source.state.records if r.selector.schema_id != schema_id(NAMES[1]))
        policy = copy.deepcopy(self.selection); policy["sourceAuthoritySet"] = [_selector(original, "/exactText")]
        with self.assertRaises(MuseumError): self.select(policy)
        with self.assertRaisesRegex(MuseumError, "original schema/family"):
            self.source.payload(original)

    def testUnselectedSignedNegativesCannotVetoAndEveryOriginalByteIsRetained(self):
        result = self.project()
        sidecar = loads(result.sidecar, maximum=67108864)
        self.assertEqual(len(sidecar["publicSources"]), 18)
        for row in sidecar["publicSources"]:
            source = self.source.records[row["selector"]["recordHash"]]
            self.assertEqual(hex_bytes(row["payloadHex"]), source.payload)
            self.assertEqual(hex_bytes(row["schemaHex"]), source.schema)
            self.assertEqual(hex_bytes(row["authorityEvidenceHex"]), source.authority_evidence)
        coverage = loads(result.coverage, maximum=67108864)
        self.assertEqual(len(coverage), 3)
        rows = [r for c in coverage for r in c["fields"]]
        self.assertTrue(any(r["exactHex"] == "0x6e756c6c" for r in rows))
        self.assertTrue(any(r["presence"] == "absent" for r in rows))

    def testActualConflictingContentWithholdsOnlyContentWithoutRecencyPreference(self):
        policy = copy.deepcopy(self.selection)
        policy["sourceAuthoritySet"].append(_selector(self.negatives["conflicting_content"], "/assertions/0"))
        first = self.project(policy)
        policy["sourceAuthoritySet"].reverse()
        second = self.project(policy)
        self.assertEqual(first.resources, second.resources)
        text = next(loads(r.content) for r in first.resources if r.identifier == "urn:local:semantic:text")
        self.assertNotIn("content", text)
        self.assertEqual(len(loads(first.sidecar, maximum=67108864)["withheldClaims"]), 2)

    def testReturnedPayloadMutationNeverChangesHistoricalReadOrSameProjection(self):
        value = self.source.payload(self.original)
        value["assertions"][0]["assertingAgent"] = "urn:hostile"
        value["entities"].clear()
        self.assertEqual(len(self.source.payload(self.original)["entities"]), 4)
        self.assertEqual(self.project().report, (FIXTURE / "report.json").read_bytes())

    def testPointersAreExactAndNeverRepairLexicalSource(self):
        raw = dumps({"~key/name": [None, "A\r\n&🧭"]})
        self.assertEqual(resolve_pointer(raw, "/~0key~1name/1"), dumps("A\r\n&🧭"))
        self.assertEqual(resolve_pointer(b"not JSON at all", ""), b"not JSON at all")
        for pointer in ("/~0key~1name/01", "/~2bad", "/~0key~1name/2", "/missing"):
            with self.assertRaises(MuseumError): resolve_pointer(raw, pointer)

    def testFixtureEntrypointAndBooleanCannotPromoteRecordedOrSyntheticState(self):
        with self.assertRaisesRegex(MuseumError, "recorded canonical selection"):
            project_fixture(self.source.state, dumps(self.selection), dumps(self.plan),
                selection_hash=keccak256(dumps(self.selection)), plan_hash=keccak256(dumps(self.plan)),
                profile_hash=PROFILE_HASH, profile=self.source.profile)
        with self.assertRaisesRegex(MuseumError, "concrete recorded"):
            select_recorded(self.source.state, dumps(self.selection), policy_hash=keccak256(dumps(self.selection)))
        with self.assertRaisesRegex(MuseumError, "concrete registered"):
            RecordedSemanticSource(True, profile_hash=PROFILE_HASH)

    def testCanonicalAccountHelperRejectsWidthsZeroAndNoncanonicalHex(self):
        address = "0x" + "ab" * 20
        self.assertEqual(account_iri(str((1 << 256) - 1), address), ACCOUNT_PREFIX + str((1 << 256) - 1) + ":" + address)
        for chain, addr in (("01", address), (str(1 << 256), address), (1, address), ("1", address.upper()),
                            ("1", "0x" + "00" * 20), ("1", address + "00")):
            with self.assertRaises(MuseumError): account_iri(chain, addr)

    def interpretation(self, rows):
        source = IndependentSourceAdapter((FIXTURE / "anchor.json").read_bytes(),
            ReplayTransport((FIXTURE / "transcript.json").read_bytes(), SOURCE_HASH), provenance="trusted_rpc")
        publication = IndependentPublicationAdapter(source, (FIXTURE / "publication-hints.json").read_bytes(),
            ReplayTransport((FIXTURE / "publication-transcript.json").read_bytes(), PUBLICATION_HASH), provenance="trusted_rpc")
        raw = dumps({"version": 1, "calls": rows})
        return RegisteredInterpretationCapture(publication, self.source.profile, ReplayTransport(raw, keccak256(raw)))

    def testRehashedRegistryCatalogKindRejectsDespiteValidDeclaration(self):
        rows = loads((FIXTURE / "interpretation-transcript.json").read_bytes(), maximum=67108864)["calls"]
        row = next(r for r in rows if r["method"] == "eth_call" and r["params"][0]["data"] == calldata("document(bytes32)", ("bytes32",), (schema_id(NAME),)))
        d, = decode((DOCUMENT,), hex_bytes(row["result"]))
        spec = list(d[3]); spec[1] = 3
        declaration = keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, d[4])))
        row["result"] = "0x" + encode((DOCUMENT,), ((d[0], d[1], declaration, spec, d[4]),)).hex()
        with self.assertRaisesRegex(MuseumError, "document kind mismatch"): self.interpretation(rows).snapshot()

    def testValidAlternateCanonicalizationStillRejectsExactJcsBootstrapRule(self):
        # Synthetic but fully re-encoded registry declaration/closure: the alternate
        # kind1 document uses actual RAW_BYTES chunks, then itself resolves RAW_BYTES.
        rows = loads((FIXTURE / "interpretation-transcript.json").read_bytes(), maximum=67108864)["calls"]
        def docrow(identifier):
            return next(i for i,r in enumerate(rows) if r["method"] == "eth_call"
                and r["params"][0]["data"] == calldata("document(bytes32)", ("bytes32",), (identifier,)))
        jcs_index, raw_index = docrow(JCS_ID), docrow(RAW_BYTES)
        d, = decode((DOCUMENT,), hex_bytes(rows[jcs_index]["result"]))
        alt_name = "SYNTHETIC_VALID_RAW_ALTERNATIVE"
        alt = schema_id(alt_name)
        spec = list(d[3]); spec[3] = alt
        rows[jcs_index]["result"] = "0x" + encode((DOCUMENT,), ((d[0], d[1],
            keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, d[4]))), spec, d[4]),)).hex()
        raw_row = copy.deepcopy(rows[raw_index])
        raw_d, = decode((DOCUMENT,), hex_bytes(raw_row["result"]))
        alt_spec = list(raw_d[3]); alt_spec[0] = alt_name
        alt_d = (True, 0, keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (alt_spec, raw_d[4]))), alt_spec, raw_d[4])
        alt_raw = encode((DOCUMENT,), (alt_d,))
        verify_document(alt, alt_raw, RAW_DEFINITION, 1)
        alt_row = copy.deepcopy(raw_row)
        alt_row["params"][0]["data"] = calldata("document(bytes32)", ("bytes32",), (alt,))
        alt_row["result"] = "0x" + alt_raw.hex()
        rows = rows[:raw_index] + [alt_row] + rows[raw_index+1:raw_index+3] + [raw_row] + rows[raw_index+3:]
        capture = self.interpretation(rows)
        with self.assertRaisesRegex(MuseumError, "registered interpretation canonicalization mismatch"):
            capture.snapshot()
        self.assertIn(alt, capture.probe.documents)
        self.assertIn(RAW_BYTES, capture.probe.documents)
        with self.assertRaisesRegex(MuseumError, "cannot resume"): capture.snapshot()

    def testOfflineCliBindsAllExternalCommitmentsAndExactOutputs(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "export"
            command = [sys.executable, "-m", "tools.museum.recorded_projection", "--input", str(FIXTURE), "--output", str(output),
                "--source-hash", SOURCE_HASH, "--publication-hash", PUBLICATION_HASH, "--interpretation-hash", INTERPRETATION_HASH,
                "--profile-hash", PROFILE_HASH, "--selection-hash", keccak256(dumps(self.selection)), "--plan-hash", keccak256(dumps(self.plan))]
            result = subprocess.run(command, capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(set(p.name for p in output.iterdir()), set(output_files(self.project())))
            for path in output.iterdir(): self.assertEqual(path.read_bytes(), (FIXTURE / path.name).read_bytes())
            self.assertFalse(loads(result.stdout.encode())["cryptographicStateProof"])


if __name__ == "__main__": unittest.main()

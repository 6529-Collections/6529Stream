import copy
import unittest

from jsonschema import Draft202012Validator
from tools.metadata import genesis_dossier_profile as p


class GenesisDossierProfileTests(unittest.TestCase):
    def setUp(self):
        self.examples = p.examples()
        self.packet = self.examples["acquisition-packet.json"]
        self.dossier = self.examples["object-dossier.json"]

    def check(self, value):
        return p.validate(value["schema"], p.dumps(value))

    def reject(self, value, message=None):
        with self.assertRaises(p.DossierError) as caught:
            self.check(value)
        if message is not None: self.assertIn(message, str(caught.exception))

    def record(self, kind, schema, scope="token"):
        record = copy.deepcopy(self.packet["tombstone"]["record"])
        record.update(recordType=p.keccak256(kind.encode()), schemaId=p.keccak256(schema.encode()), recordHash=p._h(kind + "-" + scope), subjectKind=scope)
        record["subjectId"] = self.packet["sourceState"]["subjectId" if scope == "token" else "collectionSubjectId"]
        return record

    def refresh_inventory(self, dossier):
        packet = dossier["acquisitionPacket"]
        for lane in dossier["recordInventory"]:
            previous = p.ZERO
            for i, entry in enumerate(lane["entries"]):
                entry["index"] = str(i)
                previous = p._chain_step(packet["sourceState"], lane["head"], previous, entry["record"]["recordHash"], i)
                entry["chainHash"] = previous
            lane["head"].update(count=str(len(lane["entries"])), headHash=previous)
        dossier["recordInventory"].sort(key=lambda lane: p._head_key(lane["head"]))
        packet["recordChainHeads"] = [copy.deepcopy(lane["head"]) for lane in dossier["recordInventory"]]
        dossier["semanticPackage"]["sourceHeadHashes"] = [head["headHash"] for head in packet["recordChainHeads"]]
        digest = next(h["headHash"] for h in packet["recordChainHeads"] if h["headHash"] != p.ZERO)
        packet["citation"]["qualifier"] = {"kind": "chain", "hash": digest}
        packet["citation"]["qualified"] = packet["citation"]["work"] + "@chain:" + digest
        dossier["packaging"]["ocflObjectId"] = packet["citation"]["qualified"]

    def add_entry(self, dossier, lane, record):
        template = next(l["entries"][0] for l in dossier["recordInventory"] if l["entries"])
        entry = copy.deepcopy(template); entry["record"] = record
        for key in ("envelopePath", "payloadPath", "signatureBundlePath"):
            component = copy.deepcopy(next(c for c in dossier["components"] if c["path"] == entry[key]))
            component["path"] = "data/extra-" + record["recordHash"][2:] + "-" + key + ".json"
            component["hash"]["digest"] = p._h(component["path"])
            dossier["components"].append(component); entry[key] = component["path"]
        dossier["components"].sort(key=lambda c: c["path"])
        lane["entries"].append(entry)
        self.refresh_inventory(dossier)
        return entry

    def test_documents_examples_and_generator_exact(self):
        self.assertEqual(set(p.documents()), {p.OBJECT, p.PACKET})
        for definition in p.schemas().values(): Draft202012Validator.check_schema(definition)
        for value in self.examples.values(): self.assertEqual(self.check(value), value)
        for path, raw in p.outputs().items(): self.assertEqual((p.ROOT / path).read_bytes(), raw)
        self.assertEqual(self.dossier["institutionalEvidence"], {"repositoryIngestReports": [], "practitionerReviews": []})

    def test_all_nineteen_requirement_branches_are_required(self):
        self.assertEqual(set(p.PACKET_REQUIREMENTS), {str(i) for i in range(1, 20)})
        for fields in p.PACKET_REQUIREMENTS.values():
            for field in fields:
                value = copy.deepcopy(self.packet); del value[field]
                with self.subTest(field=field): self.reject(value)

    def test_canonical_bytes_duplicates_unknown_fields_and_bounds(self):
        raw = p.dumps(self.packet)
        for bad in (raw + b"\n", b'{"schema":"x","schema":"x"}', b" " * (p.MAX_BYTES + 1)):
            with self.assertRaises(p.DossierError): p.validate(p.PACKET, bad)
        value = copy.deepcopy(self.packet); value["fullConformance"] = True; self.reject(value)
        value = copy.deepcopy(self.packet); value["sourceState"]["chainId"] = "01"; self.reject(value)
        value = copy.deepcopy(self.packet); value["sourceState"]["blockNumber"] = str(1 << 64); self.reject(value)
        value = copy.deepcopy(self.packet); value["sourceState"]["chainId"] = str(1 << 256); self.reject(value)
        value = copy.deepcopy(self.packet); value["sourceState"]["tokenId"] = "0"; self.reject(value, "nonzero source identity")
        value = copy.deepcopy(self.packet); value["version"] = 1.0
        with self.assertRaises(p.MuseumError): p.dumps(value)

    def test_exact_subject_identity_and_citation_joins(self):
        for path, replacement in ((["subjectId"], p._h("wrong")),
            (["sourceState", "collectionSubjectId"], p._h("wrong")),
            (["erc721Identity", "catalogNumber"], "7"),
            (["citation", "qualified"], self.packet["citation"]["work"] + "@" + p._h("untyped"))):
            value = copy.deepcopy(self.packet); target = value
            for key in path[:-1]: target = target[key]
            target[path[-1]] = replacement
            with self.subTest(path=path): self.reject(value)
        value = copy.deepcopy(self.packet)
        value["citation"]["qualifier"]["kind"] = "fin"
        value["citation"]["qualified"] = value["citation"]["qualified"].replace("@chain:", "@fin:")
        self.reject(value, "finality citation")

    def test_snapshot_citation_requires_exact_typed_manifest_commitment(self):
        value = copy.deepcopy(self.packet)
        manifest = p._reference("snapshot-manifest")
        value["citation"]["qualifier"] = {"kind": "snap", "hash": manifest["hash"]["digest"]}
        value["citation"]["qualified"] = value["citation"]["work"] + "@snap:" + manifest["hash"]["digest"]
        self.reject(value, "snapshot citation")
        value["snapshotCommitment"] = {"host": "0x" + "66" * 20, "collectionId": "2", "snapshotId": p._h("snapshot-id"),
            "recordHash": p._h("snapshot-record"), "manifest": manifest, "sourceHash": p._h("snapshot-source"),
            "revision": "1", "recordedBlock": "99"}
        self.check(value)
        for field, bad in (("collectionId", "3"), ("recordedBlock", "101"), ("revision", "0")):
            bad_value = copy.deepcopy(value); bad_value["snapshotCommitment"][field] = bad
            self.reject(bad_value, "snapshot commitment")
        manifest["hash"]["digest"] = p._h("wrong-manifest"); self.reject(value, "snapshot citation")
        manifest["hash"]["algorithm"] = 2; self.reject(value, "snapshot commitment")

    def test_six_hashref_algorithms_and_utf8_uri_bounds(self):
        for algorithm in range(1, 7):
            value = copy.deepcopy(self.packet)
            digest = value["legalInstrument"]["instrument"]["hash"]
            digest["algorithm"] = algorithm
            if algorithm in (4, 5): digest["digest"] = "0xaabb"
            self.check(value)
            digest["digest"] = "0xaa"
            if algorithm not in (4, 5): self.reject(value, "digest length")
        value = copy.deepcopy(self.packet)
        value["legalInstrument"]["instrument"]["uri"] = "https://e.example/" + "é" * 1100
        self.reject(value, "UTF8")
        value["legalInstrument"]["instrument"]["uri"] = "file:///secret"; self.reject(value, "URI")

    def test_entropy_exact_native_preimage_and_event_joins(self):
        self.assertEqual(p.keccak256(b"6529STREAM_EXPORT_ENTROPY_LEAF_V1"),
            "0x0160b86ab41aa57205650b067fbed4e57e8e346b664d01f1a4595213af403c73")
        value = copy.deepcopy(self.packet); value["entropy"]["leaf"]["requestAttempt"] = "1"
        self.reject(value, "entropy leaf")
        value["entropy"]["leafHash"] = p._entropy_hash(value["entropy"]["leaf"]); self.check(value)
        value["entropy"]["events"][1]["emitter"] = "0x" + "44" * 20
        self.reject(value, "event source")
        value = copy.deepcopy(self.packet); value["entropy"]["events"].pop(); self.reject(value, "finalized entropy")

    def test_finalized_entropy_sequence_rejects_reversed_or_later_request(self):
        value = copy.deepcopy(self.packet)
        events = value["entropy"]["events"]
        events[0]["event"], events[1]["event"] = events[1]["event"], events[0]["event"]
        self.reject(value, "event sequence")
        value = copy.deepcopy(self.packet)
        extra = copy.deepcopy(value["entropy"]["events"][0]); extra["blockNumber"] = "82"
        value["entropy"]["events"].append(extra); self.reject(value, "event sequence")
        value["entropy"]["events"][1]["event"] = "EntropyRequested"
        extra["event"] = "EntropyFinalized"; self.check(value)

    def test_native_artist_attestation_status_keeps_exact_original_record_observation(self):
        observation = self.packet["attribution"]["attestation"]
        self.check(self.packet)
        observation["attestationRecordHash"] = p._h("original-native-attestation")
        self.reject(self.packet, "absent attestation tuple")
        observation.update(attestedSubjectStateHash=p._h("original-state"), authorityClass="2", signedAt="80")
        observation.update(nativeStatus="1", statusLabel="CURRENT")
        self.reject(self.packet, "current attestation state")
        self.packet["attribution"].update(state="artist_accepted", bindingGeneration="1",
            binding={"status": "present", "record": self.record("ARTIST_BINDING", "synthetic-binding", "collection")})
        self.reject(self.packet, "current attestation state")
        observation["attestedSubjectStateHash"] = observation["currentSubjectStateHash"]; self.check(self.packet)
        observation.update(subjectKind="8", attestedSubjectStateHash=p._h("kind8-original-state")); self.check(self.packet)
        observation.update(subjectKind="1", nativeStatus="2", statusLabel="STALE"); self.check(self.packet)
        self.packet["attribution"]["state"] = "claimed"; self.check(self.packet)
        self.packet["attribution"]["state"] = "disputed"; self.reject(self.packet, "disputed attribution")
        observation.update(nativeStatus="3", statusLabel="DISPUTED"); self.check(self.packet)
        self.assertEqual(observation["attestationRecordHash"], p._h("original-native-attestation"))
        self.packet["attribution"]["state"] = "claimed"; self.reject(self.packet, "disputed attribution")
        self.packet["attribution"]["state"] = "disputed"
        observation["statusLabel"] = "CURRENT"; self.reject(self.packet, "status label")
        observation["statusLabel"] = "DISPUTED"; observation["observedBlockHash"] = p._h("different-read-block")
        self.reject(self.packet, "observation context")
        observation["observedBlockHash"] = self.packet["sourceState"]["blockHash"]
        observation["attestationRecordHash"] = p.ZERO; self.reject(self.packet, "original record")
        observation["nativeStatus"] = "4"; self.reject(self.packet)

    def test_token_rights_overrides_even_explicit_unspecified(self):
        rights = self.packet["rights"]
        rights["collection"]["grants"] = {u: "granted" for u in p.USES}
        rights["token"] = {"record": self.record("RIGHTS_STATEMENT", "STREAM_RIGHTS_V1"),
            "grants": {u: "unspecified" for u in p.USES}}
        self.check(self.packet)
        rights["token"]["grants"]["print"] = "denied"
        self.reject(self.packet, "rights precedence")
        rights["effectiveGrants"]["print"] = "denied"; rights["completeness"] = "partially_specified"
        self.check(self.packet)
        rights["token"] = None; rights["effectiveGrants"] = rights["collection"]["grants"].copy(); rights["completeness"] = "specified"
        self.check(self.packet)
        rights["collection"] = None; rights["effectiveGrants"] = {u: "unspecified" for u in p.USES}; rights["completeness"] = "absent"
        self.check(self.packet)

    def test_transfer_continuity_burn_and_title_binding(self):
        ownership = self.packet["ownershipProvenance"]
        next_owner = "0x" + "55" * 20
        hop = {"from": ownership["currentOwner"], "to": next_owner, "blockNumber": "99", "transactionHash": p._h("sale"), "logIndex": "0"}
        ownership["transfers"].append(hop); ownership["currentOwner"] = next_owner
        ownership["titleBindings"] = [{"record": self.record("ACCESSION", "STREAM_ACCESSION_V1"), "mode": "TITLE_BINDING",
            "transferIndex": "1", "transactionHash": hop["transactionHash"], "from": hop["from"], "to": hop["to"], "instrument": p._reference("sale-instrument")}]
        self.check(self.packet)
        ownership["titleBindings"][0]["transactionHash"] = p._h("different-hop"); self.reject(self.packet, "title transfer")
        ownership["titleBindings"] = []; hop["from"] = next_owner; self.reject(self.packet, "continuity")
        hop["from"] = ownership["transfers"][0]["to"]; hop["to"] = p.ZERO_ADDRESS
        ownership["currentOwner"] = p.ZERO_ADDRESS; self.packet["sourceState"]["burned"] = True
        self.check(self.packet)
        self.packet["sourceState"]["burned"] = False; self.reject(self.packet, "owner/burn")

    def test_mode_total_coverage_and_drill_acceptance(self):
        value = self.examples["script-packet.json"]
        value["scriptDrill"] = {"status": "recorded", "report": p._reference("drill"), "acceptanceMode": "BYTE_EXACT",
            "outcome": "TOLERABLE_VARIANCE", "referenceRender": self.record("REFERENCE_RENDER", "STREAM_REFERENCE_RENDER_V1", "collection"), "curatedEvidence": None}
        self.reject(value, "acceptance mode")
        value["scriptDrill"]["acceptanceMode"] = "PERCEPTUAL_TOLERANCE"; self.check(value)
        value["preservation"]["coverage"] = "covered"; self.reject(value, "mode-total")

    def test_curated_equivalence_requires_attributed_examiner_and_intent_join(self):
        value = self.examples["script-packet.json"]
        curated = {"attestation": self.record("INDEPENDENT_CONDITION", "STREAM_CONDITION_REPORT_V1"),
            "verificationClass": "SIGNER_VERIFIED", "artistIntentRecordHash": value["conservation"]["artistIntent"]["record"]["recordHash"],
            "examinerInstitution": p._reference("institution"), "examinerName": "Synthetic Conservator",
            "examinerCredential": p._reference("credential"), "fieldEvaluation": p._reference("evaluation")}
        value["scriptDrill"] = {"status": "recorded", "report": p._reference("drill"), "acceptanceMode": "CURATED_EQUIVALENCE",
            "outcome": "TOLERABLE_VARIANCE", "referenceRender": self.record("REFERENCE_RENDER", "STREAM_REFERENCE_RENDER_V1", "collection"), "curatedEvidence": curated}
        self.check(value)
        curated["verificationClass"] = "OPERATOR_ASSERTED"; self.reject(value)
        curated["verificationClass"] = "SIGNER_VERIFIED"; curated["artistIntentRecordHash"] = p._h("different-intent")
        self.reject(value, "attestation/intent")
        value = copy.deepcopy(self.packet); value["metadataMode"] = "SERVICE_BACKED"
        value["preservation"]["coverage"] = "service_backed_mutable"; self.check(value)
        value["preservation"]["coverage"] = "covered"; self.reject(value, "mode-total")

    def test_personhood_context_and_required_c2pa_validation_refs(self):
        phood = {"status": "present", "artistId": self.packet["attribution"]["artistId"],
            "operativeIdentityRecordHash": p._h("identity"), "legalPersonReference": p._reference("legal-person"),
            "record": self.record("INSTITUTIONAL_VERIFICATION", "STREAM_IDENTITY_NOTARIZATION_V1", "collection")}
        self.packet["attribution"]["personhood"] = phood; self.check(self.packet)
        phood["artistId"] = p._h("other-artist"); self.reject(self.packet, "personhood")
        phood["artistId"] = self.packet["attribution"]["artistId"]
        c2pa = {"status": "present", "record": self.record("C2PA_REFERENCE", "STREAM_C2PA_REFERENCE_V1"),
            "validationStatus": p.keccak256(b"VALID"), "validatorClass": p._h("validator-class"),
            "assetHash": p._h("asset"), "committedMediaHash": p._h("asset"),
            **{key: p._reference(key) for key in ("validationReport", "validatorIdentity", "softwareVersion", "trustAnchorSet")}}
        self.packet["c2pa"] = c2pa; self.check(self.packet)
        c2pa["assetHash"] = p._h("wrong"); self.reject(self.packet, "INVALID")
        c2pa["validationStatus"] = p.keccak256(b"INVALID"); self.check(self.packet)
        del c2pa["trustAnchorSet"]; self.reject(self.packet)

    def test_recovery_response_binds_exact_recovery_and_manifest(self):
        manifest = p._reference("recovery")
        response = {"record": self.record("RECOVERY_RESPONSE", "STREAM_RECOVERY_RESPONSE_V1"),
            "recoveryId": p._h("recovery-id"), "manifestHash": manifest["hash"]["digest"]}
        self.packet["recoveryLineage"] = {"status": "present", "lineage": [{"recoveryId": response["recoveryId"],
            "manifest": manifest, "status": "executed", "artworkBytesChanged": True, "responses": [response]}]}
        self.check(self.packet)
        response["manifestHash"] = p._h("different"); self.reject(self.packet, "recovery response")

    def test_funding_age_default_tier_and_future_record(self):
        for branch, key, bad in (("platformSustainability", "horizonStatus", "meets_floor"),
                                ("conservation", "tier", "MUSEUM_GRADE")):
            value = copy.deepcopy(self.packet); value[branch][key] = bad; self.reject(value)
        value = copy.deepcopy(self.packet); value["platformSustainability"]["stateExport"]["ageSeconds"] = "99"; self.reject(value)
        value = copy.deepcopy(self.packet); value["tombstone"]["record"]["recordedBlock"] = "101"; self.reject(value, "beyond source")

    def test_full_declared_inventory_heads_records_and_paths(self):
        value = copy.deepcopy(self.dossier); value["recordInventory"].pop(); self.reject(value)
        value = copy.deepcopy(self.dossier)
        lane = next(l for l in value["recordInventory"] if l["entries"])
        lane["entries"][0]["chainHash"] = p._h("different"); self.reject(value, "chain hash")
        value = copy.deepcopy(self.dossier); value["components"].pop(); self.reject(value, "missing component")
        value = copy.deepcopy(self.dossier); value["recordInventory"] = [l for l in value["recordInventory"] if l["head"]["lane"] != "owner"]
        value["acquisitionPacket"]["recordChainHeads"] = [l["head"] for l in value["recordInventory"]]
        self.reject(value, "four lanes")

    def test_native_collection_family_keeps_mixed_token_subject_denominator(self):
        value = copy.deepcopy(self.dossier)
        lane = next(l for l in value["recordInventory"] if p._kind(l["head"], "WORK_DESCRIPTION"))
        original = lane["entries"][0]["record"]
        other = copy.deepcopy(original)
        other.update(recordHash=p._h("second-token-work-description"),
            subjectId=p.subject_id("token", "1", value["acquisitionPacket"]["sourceState"]["core"], "2", token_id="124"))
        self.add_entry(value, lane, other)
        self.assertEqual(lane["head"]["scopeKey"], "2")
        self.assertEqual(lane["head"]["count"], "2")
        self.assertNotEqual(lane["entries"][0]["record"]["subjectId"], lane["entries"][1]["record"]["subjectId"])
        self.assertEqual(value["acquisitionPacket"]["tombstone"]["record"], original)
        self.check(value)
        missing = copy.deepcopy(value)
        next(l for l in missing["recordInventory"] if p._kind(l["head"], "WORK_DESCRIPTION"))["entries"].pop()
        self.reject(missing, "lane count")
        middle = copy.deepcopy(value)
        next(l for l in middle["recordInventory"] if p._kind(l["head"], "WORK_DESCRIPTION"))["entries"][0]["chainHash"] = p._h("forged-middle")
        self.reject(middle, "chain hash step")
        selected = copy.deepcopy(value); selected["acquisitionPacket"]["tombstone"]["record"] = other
        self.reject(selected, "subject join")
        split = copy.deepcopy(value); split["acquisitionPacket"]["recordChainHeads"].append(copy.deepcopy(lane["head"]))
        split["acquisitionPacket"]["recordChainHeads"].sort(key=p._head_key)
        self.reject(split, "sorted and unique")

    def test_actual_native_scope_keys_and_unknown_bytes32_family(self):
        for lane_name, bad_scope in (("metadata", "123"), ("general", "0"), ("owner", "2"), ("independent", "123")):
            value = copy.deepcopy(self.packet)
            next(h for h in value["recordChainHeads"] if h["lane"] == lane_name)["scopeKey"] = bad_scope
            value["recordChainHeads"].sort(key=p._head_key)
            self.reject(value, "native lane scope")
        value = copy.deepcopy(self.dossier)
        lane = next(l for l in value["recordInventory"] if l["head"]["lane"] == "owner")
        unknown = "0x" + "ab" * 32
        lane["head"]["recordType"] = unknown
        record = self.record("unknown", "synthetic-unknown-schema"); record["recordType"] = unknown
        entry = self.add_entry(value, lane, record)
        self.assertEqual(entry["chainHash"], p.record_chain("1", record["host"], "123", unknown, p.ZERO, record["recordHash"], "0"))
        self.check(value)
        lane = next(l for l in value["recordInventory"] if l["head"]["lane"] == "independent")
        lane["head"]["scopeKey"] = "0"
        record = self.record("INDEPENDENT_CONDITION", "STREAM_CONDITION_REPORT_V1", "collection")
        record.update(subjectKind="deployment", subjectId=p._h("deployment-original-subject"))
        self.add_entry(value, lane, record); self.check(value)
        bad = copy.deepcopy(self.packet); bad["rights"]["collection"]["record"]["recordType"] = unknown
        self.reject(bad, "rights scope/schema")
        bad["rights"]["collection"]["record"]["recordType"] = "RIGHTS_STATEMENT"; self.reject(bad)

    def test_general_chain_uses_own_six_word_preimage(self):
        from tools.museum.general_attestation_source import chain_hash
        value = copy.deepcopy(self.dossier)
        lane = next(l for l in value["recordInventory"] if l["head"]["lane"] == "general")
        record = self.record("INSTITUTIONAL_VERIFICATION", "synthetic-institutional-schema")
        entry = self.add_entry(value, lane, record)
        expected = chain_hash(2, record["recordType"], p.ZERO, record["recordHash"], 0)
        self.assertEqual(entry["chainHash"], expected); self.check(value)
        entry["chainHash"] = p.record_chain("1", record["host"], "2", record["recordType"], p.ZERO, record["recordHash"], "0")
        self.reject(value, "chain hash step")

    def test_packaging_fetch_and_render_critical_rules(self):
        extra = {"path": "data/zzz-master.bin", "role": "media", "hash": p._reference("master")["hash"],
            "byteLength": "123", "renderCritical": False, "disposition": "fetch", "retrievalURI": "ipfs://synthetic-master",
            "archiveReceipts": copy.deepcopy(self.dossier["tooling"]["archiveReceipts"])}
        self.dossier["components"].append(extra)
        self.reject(self.dossier, "self-containment")
        self.dossier["packaging"]["selfContainment"] = "fetch_dependent"
        self.dossier["acquisitionPacket"]["dossierBag"]["selfContainment"] = "fetch_dependent"
        self.check(self.dossier)
        extra["renderCritical"] = True; self.reject(self.dossier, "fetch-only")
        extra["renderCritical"] = False; extra["archiveReceipts"].pop(); self.reject(self.dossier, "dual-family")

    def test_portable_component_paths_reject_reserved_case_and_directory_collisions(self):
        for paths in (("data/CON.json",), ("data/COM1.bin",), ("data/trailing.",),
                      ("data/Extra.json", "data/extra.json"), ("data/Foo/a.json", "data/foo/b.json"),
                      ("data/extra", "data/extra/child.json")):
            with self.subTest(paths=paths):
                value = copy.deepcopy(self.dossier)
                for path in paths:
                    extra = copy.deepcopy(value["components"][0]); extra["path"] = path
                    value["components"].append(extra)
                value["components"].sort(key=lambda c: c["path"])
                self.reject(value)

    def test_semantic_source_state_inventory_and_acyclicity(self):
        for field, replacement in (("sourceStateHash", p._h("wrong-state")),
            ("selectedRecordHashes", [p._h("unknown-record")]),
            ("sourceHeadHashes", []), ("manifestPath", "data/missing.json")):
            value = copy.deepcopy(self.dossier); value["semanticPackage"][field] = replacement; self.reject(value)
        self.dossier["semanticPackage"]["subsequentExportRecordHash"] = self.dossier["semanticPackage"]["selectedRecordHashes"][0]
        self.reject(self.dossier, "cyclic")

    def test_tool_pins_and_no_institutional_promotion(self):
        self.dossier["tooling"]["manifestToolSourceHash"] = p._h("other-source"); self.reject(self.dossier, "system-manifest")
        self.dossier["tooling"]["manifestToolSourceHash"] = self.dossier["tooling"]["sourceArchive"]["hash"]["digest"]
        self.dossier["tooling"]["archiveReceipts"][1]["storageFamily"] = self.dossier["tooling"]["archiveReceipts"][0]["storageFamily"]
        self.reject(self.dossier, "distinct families")
        self.dossier["institutionalEvidence"]["accepted"] = True; self.reject(self.dossier)


if __name__ == "__main__": unittest.main()

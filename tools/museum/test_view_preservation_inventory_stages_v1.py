import copy
import unittest

from . import artist_attestation_source as artist
from . import view_preservation_inventory_stages_v1 as stages
from . import view_preservation_inventory_types_v1 as types
from . import view_preservation_inventory_references_v1 as references
from . import view_preservation_reference_types_v1 as reference_types
from . import view_preservation_inventory_sources_v1 as inventory_sources
from . import public_conservation_source as conservation_source
from .canonical import hex_bytes, keccak256, schema_id
from .canonical import dumps
from .native_finality_wire import from_json
from .independent_wire import json_values
from tools.metadata import work_profile, rights_profile, conservation_profile
from .chain_abi import Array, encode
from .independent_wire import ZERO, ZERO_ADDRESS
from .independent_wire import generic_hash


def A(n):
    return "0x" + format(n, "040x")


def H(label):
    return keccak256(label.encode())


def _json(value):
    if isinstance(value, dict):
        return {key: _json(row) for key, row in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json(row) for row in value]
    return json_values(value)


def zero(kind):
    if isinstance(kind, Array):
        return ()
    if isinstance(kind, tuple):
        return tuple(zero(item) for item in kind)
    if kind == "address":
        return ZERO_ADDRESS
    if kind == "bool":
        return False
    if kind in ("bytes", "string"):
        return b"" if kind == "bytes" else ""
    if kind.startswith("uint"):
        return 0
    return "0x" + "0" * (int(kind[5:]) * 2 if kind.startswith("bytes") else 64)


def _original_source(context, deps, subject, payload, index, authority_class,
                     record_type, schema_name, profile_name):
    definitions = {row["name"]: row for row in types.definitions()}
    record = (schema_id(record_type), subject,
              (1, hex_bytes(keccak256(payload)), schema_id("RFC8785_JCS")),
              "", schema_id(schema_name), ZERO, (0, b"", ZERO), 100 + index)
    receipt = (int(context["collectionId"]), A(84000 + index), authority_class,
               101 + index, 0, H(record_type + " chain"),
               definitions[schema_name]["hash"], definitions[profile_name]["hash"],
               H(record_type + " authorization"))
    record_hash = generic_hash(int(context["chainId"]), deps[0][1], deps[0][0],
                               int(context["collectionId"]), receipt[1], record)
    source = {"record": record, "receipt": receipt, "recordHashAt": record_hash,
              "derivedRecordHash": record_hash, "payloadHex": "0x" + payload.hex(),
              "pointer": A(84100 + index),
              "pointerRuntime": "0x" + (b"\x00" + payload).hex()}
    return record_hash, source, receipt


def _suite(deps):
    owners = [A(84200 + index) for index in range(7)]
    owners[2], owners[4], owners[6] = deps[2][2], deps[2][3], deps[4]
    return (deps[2][0], deps[2][4], tuple(owners), deps[0][0], A(84220),
            A(84221), deps[0][4], A(84222), A(84223), H("fixture revenue"), A(84224))


def _artist_source(context, deps, suite, subject, artist_id, binding_hash,
                   generation, original_record, original_source, label):
    record, receipt = original_source["record"], original_source["receipt"]
    signer = receipt[1]
    publication = (deps[0][1], signer, receipt[0], record[1], record[0],
                   record[4], record[2][2], record[2][0],
                   "0x" + record[2][1].hex(), keccak256(record[3].encode()),
                   record[7], original_record)
    statement = encode(("uint16", artist.PUBLICATION), (1, publication))
    attestation = (int(context["collectionId"]), 7, subject, original_record,
                   schema_id("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
                   keccak256(statement), "")
    effective = (11 + generation, 105, b"")
    record_hash = keccak256(artist.attestation_preimage(
        int(context["chainId"]), deps[2][0], deps[0][0], attestation,
        artist_id, signer, 1, effective[0], effective[1]))
    evidence = (record_hash, artist_id, binding_hash, generation, signer, 1, 2,
                effective[1], keccak256(encode((artist.PUBLICATION,), (publication,))))
    binding = (artist_id, A(84320), H(label + " identity"), binding_hash,
               generation, 1, 2, 3, A(84321), True)
    authority = (artist_id, signer, 1, 1)
    _, _, digest = artist.signed_preimage(int(context["chainId"]), deps[2][0],
                                          deps[0][0], attestation,
                                          effective[0], effective[1])
    payload = (binding, attestation, effective, statement, (signer, digest, True),
               effective, authority, publication, deps[1][1])
    tail = encode((artist.ORDINARY_PAYLOAD,), (payload,))[32:]
    snapshots = (zero(artist.SNAPSHOT),) * 7
    envelope = (1, H("fixture coordinator config"), 24, signer, record_hash,
                snapshots, snapshots, tail)
    raw = encode((artist.ARCHIVE,), (envelope,))[32:]
    source = {"actor": signer, "suite": suite,
              "coordinatorConfigurationHash": H("fixture coordinator config"),
              "archiveRegistry": deps[2][0], "archiveCoordinator": deps[2][1],
              "evidenceHex": "0x" + raw.hex(),
              "evidenceMetadata": (keccak256(raw), A(84322), len(raw), 106),
              "pointerRuntime": "0x" + (b"\x00" + raw).hex(),
              "savedPublication": (publication, evidence, deps[1][1])}
    return evidence, source


class FixedStageFixture:
    def __init__(self):
        addresses = tuple(A(i) for i in range(1, 13))
        hashes = tuple(H("runtime" + str(i)) for i in range(1, 13))
        artist_targets = tuple(A(100 + i) for i in range(5))
        artist_hashes = tuple(H("artist runtime" + str(i)) for i in range(5))
        self.deps = (addresses, hashes, artist_targets, artist_hashes,
                     A(106), H("content owner runtime"), 31337,
                     100000, 200000, 300000, 400000, 500000)
        self.graph = {name: {"address": addresses[index], "runtimeHash": hashes[index]}
                      for name, index in {"core": 0, "metadata": 1, "schemas": 2,
                          "store": 3, "router": 4, "viewSnapshot": 5,
                          "work": 7, "rights": 8, "conservation": 9}.items()}
        scope = (4, 7, 0, H("view scope"))
        context = list(zero(types.CONTEXT)); context[0] = scope
        context[1], context[2] = H("subject"), H("artist")
        snapshot_receipt = list(context[3]); snapshot_receipt[0] = H("snapshot"); snapshot_receipt[3] = 2
        context[3] = tuple(snapshot_receipt)
        self.aggregate, self.legacy = (3, H("root chain")), H("legacy family")
        signed_family = keccak256(encode(
            ("bytes32", "uint256", "address", "address", "uint256", "bytes32", stages.AGGREGATE),
            (schema_id("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"), 31337,
             addresses[4], addresses[0], 7, self.legacy, self.aggregate)))
        owners = list(A(200 + i) for i in range(7))
        owners[2], owners[4], owners[6] = artist_targets[2], artist_targets[3], A(106)
        owners = tuple(owners)
        self.suite = (artist_targets[0], artist_targets[4], owners, addresses[0],
                      A(300), A(301), addresses[4], A(302), A(303), H("revenue"), A(304))
        binding = (H("artist"), A(400), H("identity"), H("binding"), 5, 1, 2, 3, A(401), True)
        terms = (7, addresses[4], schema_id("CONTENT_ROOT"), signed_family)
        authorization = (9, 120, b"")
        actor, observed = A(402), 110
        approval = (actor, stages._consent_digest(31337, artist_targets[0], addresses[0], terms, authorization), True)
        consent = stages._consent_record(31337, artist_targets[0], addresses[0], terms,
                                         H("artist"), actor, 1, 9, observed)
        saved = (consent, H("artist"), 5, terms, 1)
        publication = (scope, H("predecessor"), H("snapshot"), 2, "ipfs://manifest")
        root = (publication, addresses[5], hashes[5], H("snapshot manifest"), H("snapshot source"),
                H("content root"), 1, H("output manifest"), H("artist"), 5, H("binding"), A(500), 7, 1,
                H("route"), H("state"), consent, 115)
        root_hash = keccak256(encode(
            ("bytes32", "uint256", "address", "address", stages.ROOT_RECORD, stages.AGGREGATE),
            (schema_id("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"), 31337,
             addresses[4], addresses[0], root, self.aggregate)))
        context[9] = root_hash; self.context = tuple(context)
        payload = (binding, terms, authorization, approval, H("prior"))
        payload_tail = encode((stages.CONTENT_PAYLOAD,), (payload,))[32:]
        snapshots = (zero(artist.SNAPSHOT),) * 7
        envelope = (1, H("coordinator config"), 17, actor, consent,
                    snapshots, snapshots, payload_tail)
        evidence = encode((artist.ARCHIVE,), (envelope,))[32:]
        evidence_id = keccak256(encode(
            ("bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"),
            (schema_id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
             31337, artist_targets[0], artist_targets[1], 17, actor, consent)))
        self.source = {"rootRecord": root, "aggregate": self.aggregate,
            "legacyFamilyHash": self.legacy, "actor": actor, "observedAt": observed,
            "suite": self.suite, "coordinatorConfigurationHash": H("coordinator config"),
            "archiveRegistry": artist_targets[0], "archiveCoordinator": artist_targets[1],
            "evidenceHex": "0x" + evidence.hex(),
            "evidenceMetadata": (keccak256(evidence), A(700), len(evidence), 116),
            "pointerRuntime": "0x" + (b"\x00" + evidence).hex(), "savedConsent": saved}
        self.row = stages._root_authorization(self.context, self.deps, self.source)

    def original(self, payload=b'{"source":"exact"}'):
        record = (H("record type"), H("subject"),
                  (1, hex_bytes(keccak256(payload)), schema_id("RFC8785_JCS")),
                  "", H("schema"), ZERO, (0, b"", ZERO), 101)
        receipt = (7, A(900), 1, 102, 0, H("record chain"), H("schema def"),
                   H("profile def"), H("artist authorization"))
        record_hash = generic_hash(31337, self.deps[0][1], self.deps[0][0],
                                   7, receipt[1], record)
        source = {"record": record, "receipt": receipt,
                  "recordHashAt": record_hash, "derivedRecordHash": record_hash,
                  "payloadHex": "0x" + payload.hex(), "pointer": A(901),
                  "pointerRuntime": "0x" + (b"\x00" + payload).hex()}
        return record_hash, keccak256(payload), source

    def artist_publication(self, original_record, original_source, subject_kind=7):
        record, receipt = original_source["record"], original_source["receipt"]
        signer, actor = receipt[1], A(951)
        publication = (self.deps[0][1], signer, receipt[0], record[1], record[0],
                       record[4], record[2][2], record[2][0],
                       "0x" + record[2][1].hex(), keccak256(record[3].encode()),
                       record[7], original_record)
        statement = encode(("uint16", artist.PUBLICATION), (1, publication))
        # Artist subject kind7 retains the original state hash; kind8 is the
        # native record-subject branch and requires an explicit zero state.
        attestation = (7, subject_kind, H("subject"),
                       original_record if subject_kind == 7 else ZERO,
                       schema_id("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
                       keccak256(statement), "")
        effective = (11, 106, b"")
        record_hash = keccak256(artist.attestation_preimage(
            31337, self.deps[2][0], self.deps[0][0], attestation,
            H("artist"), signer, 1, effective[0], effective[1]))
        expected = (record_hash, H("artist"), H("binding"), 5, signer, 1, 2,
                    effective[1], keccak256(encode((artist.PUBLICATION,), (publication,))))
        binding = (H("artist"), A(952), H("identity"), H("binding"), 5, 1, 2, 3, A(953), True)
        authority = (H("artist"), signer, 1, 1)
        _, _, digest = artist.signed_preimage(31337, self.deps[2][0], self.deps[0][0],
                                               attestation, effective[0], effective[1])
        approval = (signer, digest, True)
        payload = (binding, attestation, effective, statement, approval, effective,
                   authority, publication, self.deps[1][1])
        payload_tail = encode((artist.ORDINARY_PAYLOAD,), (payload,))[32:]
        snapshots = (zero(artist.SNAPSHOT),) * 7
        envelope = (1, H("coordinator config"), 24, signer, record_hash,
                    snapshots, snapshots, payload_tail)
        evidence = encode((artist.ARCHIVE,), (envelope,))[32:]
        source = {"actor": signer, "suite": self.suite,
            "coordinatorConfigurationHash": H("coordinator config"),
            "archiveRegistry": self.deps[2][0], "archiveCoordinator": self.deps[2][1],
            "evidenceHex": "0x" + evidence.hex(),
            "evidenceMetadata": (keccak256(evidence), A(954), len(evidence), 107),
            "pointerRuntime": "0x" + (b"\x00" + evidence).hex(),
            "savedPublication": (publication, expected, self.deps[1][1])}
        return expected, source


def build_fixed_stages(value, context, graph):
    """Build exact original stages 2--6 for the complete inventory fixture."""
    from . import view_preservation_inventory_fixture_v1 as fixture

    deps = from_json(types.DEPENDENCIES, value["dependencies"])
    reference_row, _, _, _ = inventory_sources.selected(value["reference"])
    reference_source = from_json(reference_types.SOURCE, reference_row["source"])
    subject = reference_source[0]
    artist_id = reference_source[2][2][3]
    association_source = reference_source[2][2]
    generation, binding_hash = association_source[4], association_source[5]
    identity_record_hash = association_source[7]
    suite = _suite(deps)

    work_witness = list(zero(types.WORK))
    work_witness[0], work_witness[1], work_witness[3] = (
        subject, keccak256(dumps(work_profile.profile())), 1)
    work_witness[5] = ("Original description unavailable", 20260921)
    work_witness = tuple(work_witness)
    work_payload = references.serialize_work(work_witness)
    work_hash, work_original, _ = _original_source(
        context, deps, subject, work_payload, 1, 7, "WORK_DESCRIPTION",
        "STREAM_WORK_DESCRIPTION_V1", "STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1")

    doc = (False, "", ZERO)
    grant = (0, (0, "", doc), "")
    rights_witness = (subject, keccak256(dumps(rights_profile.profile())), 0,
        (0, artist_id, "", ZERO_ADDRESS, ZERO), (grant,) * 6,
        20260101, 0, True, doc, False, 0, ZERO)
    rights_payload = references.serialize_rights(rights_witness)
    rights_hash, rights_original, _ = _original_source(
        context, deps, subject, rights_payload, 2, 7, "RIGHTS",
        "STREAM_RIGHTS_V1", "STREAM_RIGHTS_JSON_PROFILE_V1")

    ref = (1, schema_id("RAW_BYTES"), hex_bytes(H("fixture statement")),
           "https://example.invalid/fixture-statement")
    empty_interview_record = zero(conservation_source.RECORD_EVIDENCE)
    # The typed intent-waiver's interview union is independently explicit.
    typed_empty_record = zero(types._witness_type("CONSERVATION_InterviewRecord"))
    waiver_witness = (subject,
        keccak256(dumps(conservation_profile.profile(conservation_profile.WAIVER))),
        ZERO, (artist_id, generation, binding_hash, 0), ref,
        (1, typed_empty_record, ref))
    waiver_payload = references.serialize_waiver(waiver_witness)
    waiver_hash, waiver_original, waiver_receipt = _original_source(
        context, deps, subject, waiver_payload, 3, 1, "ARTIST_INTENT_WAIVER",
        "STREAM_ARTIST_INTENT_WAIVER_V1",
        "STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1")
    publication, artist_source = _artist_source(
        context, deps, suite, subject, artist_id, binding_hash, generation,
        waiver_hash, waiver_original, "fixture ARTIST_INTENT_WAIVER")

    work_selection = list(zero(stages.WORK_SELECTION))
    work_selection[0], work_selection[2], work_selection[7] = (
        work_hash, keccak256(work_payload), 1)
    work_selection[14], work_selection[21] = 1, H("fixture work selection")
    descriptions = (subject, work_hash, rights_hash, keccak256(work_payload),
                    keccak256(rights_payload), work_selection[21],
                    H("fixture rights selection"), 1, 1)

    record_evidence = (waiver_hash, 1, keccak256(waiver_payload),
        waiver_receipt[1], waiver_receipt[3], waiver_receipt[2],
        waiver_receipt[5], H("fixture waiver receipt"), publication,
        keccak256(encode((artist.EVIDENCE,), (publication,))))
    association = (artist_id, binding_hash, generation, identity_record_hash)
    interview_hash = H("fixture explicit interview waiver")
    conservation = (record_evidence, association, 0, 1, empty_interview_record,
        H("fixture waiver archive reference"), 0, ZERO, A(84400), 1, 104,
        ZERO, H("fixture conservation selection"))

    # Build and bind the original op17 consent before deriving Context/rootHash.
    _, reference_bundle, _, _ = inventory_sources.selected(value["reference"])
    root_bundle = reference_bundle["root"]
    root_entry = next(row for row in root_bundle["history"]
                      if row["recordHash"] == root_bundle["selectedRecordHash"])
    root = from_json(stages.ROOT_RECORD, root_entry["record"])
    aggregate = from_json(stages.AGGREGATE, root_entry["aggregate"])
    legacy = H("fixture original root family")
    signed_family = keccak256(encode(
        ("bytes32", "uint256", "address", "address", "uint256", "bytes32",
         stages.AGGREGATE),
        (schema_id("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"), deps[6],
         deps[0][4], deps[0][0], int(context["collectionId"]), legacy, aggregate)))
    terms = (int(context["collectionId"]), deps[0][4], schema_id("CONTENT_ROOT"),
             signed_family)
    observed = min(root[17], 108)
    authorization = (31, max(root[17], observed), b"")
    actor = A(84401)
    approval = (actor, stages._consent_digest(deps[6], deps[2][0], deps[0][0],
                                               terms, authorization), True)
    consent = stages._consent_record(deps[6], deps[2][0], deps[0][0], terms,
                                     root[8], actor, 1, authorization[0], observed)
    fixture.bind_root_consent(value, context, graph, consent)
    root_entry = next(row for row in root_bundle["history"]
                      if row["recordHash"] == root_bundle["selectedRecordHash"])
    root = from_json(stages.ROOT_RECORD, root_entry["record"])
    binding = (root[8], A(84402), H("fixture root identity"), root[10], root[9],
               1, 2, 3, A(84403), True)
    content_tail = encode((stages.CONTENT_PAYLOAD,),
                          ((binding, terms, authorization, approval,
                            H("fixture prior content root state")),))[32:]
    snapshots = (zero(artist.SNAPSHOT),) * 7
    envelope = (1, H("fixture coordinator config"), 17, actor, consent,
                snapshots, snapshots, content_tail)
    evidence = encode((artist.ARCHIVE,), (envelope,))[32:]
    root_source = {"rootRecord": root, "aggregate": aggregate,
        "legacyFamilyHash": legacy, "actor": actor, "observedAt": str(observed),
        "suite": suite, "coordinatorConfigurationHash": H("fixture coordinator config"),
        "archiveRegistry": deps[2][0], "archiveCoordinator": deps[2][1],
        "evidenceHex": "0x" + evidence.hex(),
        "evidenceMetadata": (keccak256(evidence), A(84404), len(evidence), root[17]),
        "pointerRuntime": "0x" + (b"\x00" + evidence).hex(),
        "savedConsent": (consent, root[8], root[9], terms, 1)}

    fixture.set_context(value, descriptions, conservation, interview_hash)
    native_context = from_json(types.CONTEXT, value["context"])
    sources = (
        {"original": work_original, "typedWitness": work_witness,
         "selection": tuple(work_selection), "artist": None},
        {"original": rights_original, "typedWitness": rights_witness},
        {"original": waiver_original, "typedWitness": waiver_witness,
         "artist": artist_source},
        None,
        root_source)
    entries = []
    for stage, source in enumerate(sources, 2):
        if stage < 6:
            rows, witness = stages._typed_stage(stage, native_context, deps, source,
                                                value["documents"])
        else:
            rows = (stages._root_authorization(native_context, deps, source),)
            witness = native_context[9]
        entries.append({"stage": str(stage), "index": "0",
                        "items": json_values(rows), "sourceWitnessHash": witness,
                        "source": _json(source) if source is not None else None})
    return {"descriptions": json_values(descriptions),
            "conservation": json_values(conservation),
            "interviewHash": interview_hash, "entries": entries}


class FixedStageTests(unittest.TestCase):
    def test_full_original_root_authorization_preimage(self):
        f = FixedStageFixture()
        result = stages.validate_fixed_stage(6, 0, [f.row], f.context[9],
                                             f.context, f.deps, f.source, f.graph)
        self.assertEqual(result["rows"], (f.row,))
        self.assertEqual(f.row[0], 6)
        self.assertEqual(f.row[1], schema_id("ORIGINAL_VIEW_PRESERVATION_CONTENT_ROOT_AUTHORIZATION"))

    def test_every_authority_domain_is_recomputed(self):
        for path in ("legacyFamilyHash", "observedAt", "archiveRegistry",
                     "coordinatorConfigurationHash", "pointerRuntime"):
            f = FixedStageFixture(); bad = copy.deepcopy(f.source)
            bad[path] = (H("changed") if path not in ("observedAt", "pointerRuntime")
                         else 109 if path == "observedAt" else "0x" + b"\x00changed".hex())
            with self.assertRaises(ValueError, msg=path):
                stages.validate_fixed_stage(6, 0, [f.row], f.context[9],
                                             f.context, f.deps, bad, f.graph)

    def test_no_supplied_item_shortcut_for_typed_stages(self):
        f = FixedStageFixture()
        with self.assertRaisesRegex(ValueError, "typed-stage source shape"):
            stages.validate_fixed_stage(2, 0, [], f.context[5][5], f.context,
                                         f.deps, {"expectedItems": []}, f.graph)

    def test_work_stage_reconstructs_exact_payload_and_selection(self):
        f = FixedStageFixture()
        witness = list(zero(types.WORK))
        witness[0], witness[1], witness[3] = (f.context[1],
            keccak256(dumps(work_profile.profile())), 1)
        witness[5] = ("original description unavailable", 20260921)
        witness = tuple(witness)
        payload = stages.references.serialize_work(witness)
        record_hash, payload_hash, original = f.original(payload)
        selection = list(zero(stages.WORK_SELECTION))
        selection[0], selection[2], selection[7] = record_hash, payload_hash, 1
        selection[21] = H("work selection")
        descriptions = (f.context[1], record_hash, H("rights record"), payload_hash,
                        H("rights payload"), selection[21], H("rights selection"), 1, 1)
        context = list(f.context); context[5] = descriptions; context = tuple(context)
        source = {"original": original, "typedWitness": witness,
                  "selection": tuple(selection), "artist": None}
        rows, expected_witness = stages._typed_stage(2, context, f.deps, source, None)
        result = stages.validate_fixed_stage(2, 0, rows, expected_witness,
                                             context, f.deps, source, f.graph)
        self.assertEqual(result["rows"], rows)
        changed = copy.deepcopy(source); changed["selection"] = list(selection)
        changed["selection"][21] = H("changed selection")
        with self.assertRaisesRegex(ValueError, "work selected record/hash"):
            stages.validate_fixed_stage(2, 0, rows, expected_witness,
                                         context, f.deps, changed, f.graph)

    def test_intent_and_present_interview_stages_join_original_op24(self):
        from .test_view_preservation_inventory_references_v1 import intent, interview

        f = FixedStageFixture()
        intent_witness = list(intent(present=True)); intent_witness[0] = f.context[1]
        intent_witness = tuple(intent_witness)
        intent_payload = references.serialize_intent(intent_witness)
        intent_hash, _, intent_original = f.original(intent_payload)
        intent_evidence, intent_artist = f.artist_publication(intent_hash, intent_original)
        intent_receipt = from_json(stages.RECEIPT, intent_original["receipt"])
        intent_record = (intent_hash, 0, keccak256(intent_payload), intent_receipt[1],
            intent_receipt[3], intent_receipt[4], intent_receipt[5], H("intent receipt"),
            intent_evidence, keccak256(encode((artist.EVIDENCE,), (intent_evidence,))))

        interview_witness = list(interview()); interview_witness[0] = f.context[1]
        interview_witness = tuple(interview_witness)
        interview_payload = references.serialize_interview(interview_witness)
        interview_hash, _, interview_original = f.original(interview_payload)
        interview_evidence, interview_artist = f.artist_publication(
            interview_hash, interview_original)
        interview_receipt = from_json(stages.RECEIPT, interview_original["receipt"])
        interview_record = (interview_hash, 2, keccak256(interview_payload),
            interview_receipt[1], interview_receipt[3], interview_receipt[4],
            interview_receipt[5], H("interview receipt"), interview_evidence,
            keccak256(encode((artist.EVIDENCE,), (interview_evidence,))))
        selection = (intent_record, (H("artist"), H("binding"), 5, H("identity")),
                     0, 0, interview_record, H("interview archive"), 0, ZERO,
                     A(990), 1, 106, ZERO, H("intent selection"))
        context = list(f.context); context[6] = selection
        context[7] = H("interview evidence"); context = tuple(context)
        stage4 = {"original": intent_original, "typedWitness": intent_witness,
                  "artist": intent_artist}
        rows4, witness4 = stages._typed_stage(4, context, f.deps, stage4, None)
        self.assertEqual(stages.validate_fixed_stage(
            4, 0, rows4, witness4, context, f.deps, stage4, f.graph)["rows"], rows4)
        stage5 = {"original": interview_original, "typedWitness": interview_witness,
                  "artist": interview_artist}
        rows5, witness5 = stages._typed_stage(5, context, f.deps, stage5, None)
        self.assertEqual(stages.validate_fixed_stage(
            5, 0, rows5, witness5, context, f.deps, stage5, f.graph)["rows"], rows5)

    def test_original_metadata_pair_is_derived_from_complete_preimages(self):
        f = FixedStageFixture(); record_hash, payload_hash, source = f.original()
        rows, payload = stages._original(f.context, f.deps, record_hash,
                                         payload_hash, source)
        self.assertEqual(payload, b'{"source":"exact"}')
        self.assertEqual([row[0] for row in rows], [0, 2])
        for key in ("recordHashAt", "derivedRecordHash", "pointerRuntime"):
            bad = copy.deepcopy(source)
            bad[key] = H("wrong") if key != "pointerRuntime" else "0x00"
            with self.assertRaises(ValueError, msg=key):
                stages._original(f.context, f.deps, record_hash, payload_hash, bad)

    def test_original_artist_op24_bundle_is_fully_reconstructed(self):
        f = FixedStageFixture(); original, _, original_source = f.original()
        expected, source = f.artist_publication(original, original_source)
        row = stages._artist_item(f.deps, expected, original, source, original_source)
        self.assertEqual(row[0], 6)
        self.assertEqual(row[2], f.suite[1])
        for key in ("archiveCoordinator", "coordinatorConfigurationHash", "savedPublication"):
            bad = copy.deepcopy(source)
            bad[key] = H("wrong") if key != "savedPublication" else zero(stages.PUBLICATION_RECORD)
            with self.assertRaises(ValueError, msg=key):
                stages._artist_item(f.deps, expected, original, bad, original_source)
        changed_original = copy.deepcopy(original_source)
        changed_original["record"] = list(changed_original["record"])
        changed_original["record"][7] += 1
        with self.assertRaisesRegex(ValueError, "publication/original Metadata"):
            stages._artist_item(f.deps, expected, original, source, changed_original)

    def test_original_artist_kind8_uses_zero_subject_state(self):
        f = FixedStageFixture(); original, _, original_source = f.original()
        expected, source = f.artist_publication(original, original_source, subject_kind=8)
        row = stages._artist_item(f.deps, expected, original, source, original_source)
        self.assertEqual(row[0], 6)

    def test_complete_builder_all_fixture_modes(self):
        from .view_preservation_inventory_fixture_v1 import supplied
        for case in ((1, "disabled", False), (3, "not_required", False),
                     (3, "not_required", True)):
            value, _, _ = supplied(*case)
            self.assertEqual([int(row["stage"]) for row in value["segments"]
                              if 2 <= int(row["stage"]) <= 6], [2, 3, 4, 5, 6])


if __name__ == "__main__":
    unittest.main()

"""Exact fd861 VIEW preservation fixed-stage evidence.

Rows are reconstructed from retained native preimages.  The validator never
accepts caller-authored inventory rows as source evidence.  Stage 6 includes
the historical scoped-root/family calculation and the complete Archive op17
content-consent envelope.  Stage 7 uses one shared document denominator.
"""

from . import artist_attestation_source as artist
from . import view_preservation_inventory_items_v1 as item_tools
from . import view_preservation_inventory_references_v1 as references
from . import view_preservation_inventory_types_v1 as native_types
from . import view_preservation_snapshot_types_v1 as snapshot
from .independent_wire import RECORD, generic_hash
from .metadata_catalog_source import RECEIPT
from .canonical import hex_bytes, keccak256, schema_id, uint
from .chain_abi import decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, require
from .native_finality_wire import _bytes, _closed, from_json

ITEM = native_types.ITEM
DEPENDENCIES = native_types.DEPENDENCIES
ROOT_RECORD, AGGREGATE = snapshot.ROOT_RECORD, snapshot.AGGREGATE
CONSENT = ("uint256", "address", "bytes32", "bytes32")
CONTENT_PAYLOAD = (artist.BINDING, CONSENT, artist.AUTHORIZATION, artist.PROOF, "bytes32")
CONSENT_RECORD = ("bytes32", "bytes32", "uint64", CONSENT, "uint8")
EVIDENCE_METADATA = ("bytes32", "address", "uint32", "uint64")
PUBLICATION_RECORD = artist.PUBLICATION_RECORD
WORK_ASSOCIATION = ("bytes32", "bytes32", "uint64", "bytes32")
# fd861 StreamWorkRecordDefinitions.CANON_HASH (not its JSON PROFILE_HASH).
WORK_CANON_HASH = "0xbc33af15c6b6374052871a5fdfa255f900f56fa594f650b2d0814c681fdb35a9"
WORK_SELECTION = ("bytes32", "bytes32", "bytes32", "address", "uint8", "uint256",
    "uint64", "uint64", "uint64", "bytes32", "uint64", "uint8", "address", "uint8",
    "uint8", "uint8", WORK_ASSOCIATION, artist.EVIDENCE, "bytes32", "bytes32", "bytes32", "bytes32")
DEFINITIONS = tuple((row["name"], row["id"], row["hash"])
                    for row in native_types.definitions())


def _address(value):
    return value["address"] if isinstance(value, dict) else value


def _typed(kind, value, label):
    try:
        result = from_json(kind, value)
        encode((kind,), (result,))
        return result
    except (KeyError, TypeError, ValueError) as exc:
        raise ValueError(label) from exc


def _bindings(deps, graph):
    deps = _typed(DEPENDENCIES, deps, "VIEW inventory dependency shape")
    roles = {"core": 0, "metadata": 1, "schemas": 2, "store": 3,
             "router": 4, "viewSnapshot": 5, "work": 7,
             "rights": 8, "conservation": 9}
    require(isinstance(graph, dict) and all(role in graph for role in roles),
            "VIEW inventory fixed-stage graph roles")
    for role, index in roles.items():
        row = graph[role]
        require(_address(row) == deps[0][index],
                "VIEW inventory dependency graph address")
        if isinstance(row, dict) and "runtimeHash" in row:
            require(row["runtimeHash"] == deps[1][index],
                    "VIEW inventory dependency graph runtime")
    return deps


def _decode_tail(kind, raw, label):
    try:
        return decode((kind,), bytes(31) + b"\x20" + raw,
                      maximum=max(131072, len(raw) + 32))[0]
    except (TypeError, ValueError) as exc:
        raise ValueError(label) from exc


def _retained(evidence_id, evidence, value, runtime):
    metadata = _typed(EVIDENCE_METADATA, value,
                      "VIEW inventory Archive metadata")
    runtime = _bytes(runtime, 65536, "VIEW inventory Archive carrier runtime")
    require(metadata[1] != ZERO_ADDRESS and metadata[0] == keccak256(evidence)
            and metadata[2] == len(evidence)
            and metadata[3] > 0 and runtime == b"\x00" + evidence,
            "VIEW inventory Archive retained bytes")
    retained = keccak256(encode(
        ("bytes32", "bytes32", "address", "bytes32", "uint32", "uint64"),
        (evidence_id, metadata[0], metadata[1], keccak256(runtime),
         metadata[2], metadata[3])))
    return retained


def _original(context, deps, record_hash, payload_hash, source):
    """Exact StreamPreservationOriginalReads.items reconstruction."""
    _closed(source, ("record", "receipt", "recordHashAt", "derivedRecordHash",
                     "payloadHex", "pointer", "pointerRuntime"),
            "VIEW inventory original Metadata source")
    record = _typed(RECORD, source["record"], "VIEW inventory original record")
    receipt = _typed(RECEIPT, source["receipt"], "VIEW inventory original receipt")
    payload = _bytes(source["payloadHex"], 8192, "VIEW inventory original payload")
    runtime = _bytes(source["pointerRuntime"], 8193,
                     "VIEW inventory original payload carrier")
    require(receipt[0] == context[0][1] and record[1] == context[1]
            and receipt[1] != ZERO_ADDRESS and receipt[3] > 0
            and receipt[5] != ZERO and record[2][0] == 1
            and record[2][2] == schema_id("RFC8785_JCS")
            and record[2][1] == hex_bytes(payload_hash)
            and len(payload) > 0 and keccak256(payload) == payload_hash,
            "VIEW inventory original record/receipt/payload")
    require(record[5] == ZERO and record[6] == (0, b"", ZERO),
            "VIEW inventory original detached signature unsupported")
    derived = generic_hash(deps[6], deps[0][1], deps[0][0],
                           context[0][1], receipt[1], record)
    require(source["recordHashAt"] == record_hash
            and source["derivedRecordHash"] == record_hash
            and derived == record_hash,
            "VIEW inventory original record getter/hash")
    require(source["pointer"] != ZERO_ADDRESS
            and runtime == b"\x00" + payload,
            "VIEW inventory original payload pointer")
    first = item_tools.bytes_item(0, "ORIGINAL_METADATA_RECORD_AND_RECEIPT",
                                  deps[0][1], record_hash, 0,
                                  encode((RECORD, RECEIPT), (record, receipt)))
    second = list(item_tools.bytes_item(2, "ORIGINAL_TYPED_METADATA_PAYLOAD",
                                       deps[0][1], record_hash, 0, payload))
    second[6], second[10] = schema_id("RFC8785_JCS"), record[4]
    second[16] = keccak256(encode(("address", "bytes32"),
                                  (source["pointer"], keccak256(runtime))))
    return (first, tuple(second)), payload


def _artist_item(deps, expected, original_record, source, original_source=None):
    """Exact historical Artist op24 publication bundle reconstruction."""
    _closed(source, ("actor", "suite", "coordinatorConfigurationHash",
                     "archiveRegistry", "archiveCoordinator", "evidenceHex",
                     "evidenceMetadata", "pointerRuntime", "savedPublication"),
            "VIEW inventory Artist publication source")
    expected = _typed(artist.EVIDENCE, expected,
                      "VIEW inventory expected Artist publication evidence")
    suite = _typed(artist.SUITE, source["suite"], "VIEW inventory Artist suite")
    saved = _typed(PUBLICATION_RECORD, source["savedPublication"],
                   "VIEW inventory saved Artist publication")
    actor = source["actor"]
    require(actor != ZERO_ADDRESS and expected[0] != ZERO and original_record != ZERO,
            "VIEW inventory Artist publication locator")
    require(suite[0] == deps[2][0] and suite[1] == deps[2][4]
            and suite[2][2] == deps[2][2] and suite[2][4] == deps[2][3]
            and suite[3] == deps[0][0] and suite[6] == deps[0][4]
            and source["archiveRegistry"] == suite[0]
            and source["archiveCoordinator"] == deps[2][1],
            "VIEW inventory historical Artist suite bindings")
    evidence_id = keccak256(encode(
        ("bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"),
        (schema_id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
         deps[6], suite[0], deps[2][1], 24, actor, expected[0])))
    evidence = _bytes(source["evidenceHex"], 65536,
                      "VIEW inventory Archive op24 evidence")
    envelope = _decode_tail(artist.ARCHIVE, evidence,
                            "VIEW inventory Archive op24 envelope")
    require(envelope[:5] == (1, source["coordinatorConfigurationHash"], 24,
                             actor, expected[0]),
            "VIEW inventory Archive op24 envelope fields")
    p = _decode_tail(artist.ORDINARY_PAYLOAD, envelope[7],
                     "VIEW inventory Archive op24 payload")
    binding, attestation, submitted, statement, approval, effective, authority, publication, metadata_pin = p
    require(saved[1] == expected and saved[0] == publication
            and saved[2] == deps[1][1] and metadata_pin == deps[1][1]
            and publication[0] == deps[0][1] and publication[11] == original_record
            and publication[1] == expected[4]
            and keccak256(encode((artist.PUBLICATION,), (publication,))) == expected[8]
            and binding[0] == expected[1] and binding[3] == expected[2]
            and binding[4] == expected[3] and binding[9]
            and authority[0] == expected[1] and authority[1] == expected[4]
            and authority[2] == expected[5] and approval[0] == expected[4]
            and effective[1] == expected[7] and effective[0] == submitted[0]
            and keccak256(effective[2]) == keccak256(submitted[2])
            and attestation[0] == publication[2] and attestation[2] == publication[3]
            and attestation[4] == schema_id("6529STREAM_ARTIST_RECORD_PUBLICATION_V1")
            and attestation[5] == keccak256(statement)
            and keccak256(statement) == keccak256(encode(("uint16", artist.PUBLICATION),
                                                         (1, publication))),
            "VIEW inventory original Artist publication correspondence")
    require((attestation[1] == 7 and attestation[3] == original_record)
            or (attestation[1] == 8 and attestation[3] == ZERO),
            "VIEW inventory original Artist subject kind")
    require(isinstance(original_source, dict),
            "VIEW inventory Artist original Metadata source required")
    original = _typed(RECORD, original_source["record"],
                      "VIEW inventory Artist original Metadata record")
    receipt = _typed(RECEIPT, original_source["receipt"],
                     "VIEW inventory Artist original Metadata receipt")
    require(publication[2] == receipt[0] and publication[3] == original[1]
            and publication[4] == original[0] and publication[5] == original[4]
            and publication[6] == original[2][2]
            and publication[7] == original[2][0]
            and len(original[2][1]) == 32
            and publication[8] == "0x" + original[2][1].hex()
            and publication[9] == keccak256(original[3].encode())
            and publication[10] == original[7]
            and publication[1] == receipt[1],
            "VIEW inventory Artist publication/original Metadata fields")
    direct = approval[2]
    require((direct and actor == expected[4] and not effective[2]
             and submitted[1] in (0, effective[1]))
            or (not direct and bool(effective[2]) and submitted[1] == effective[1]),
            "VIEW inventory original Artist signature mode")
    _, _, digest = artist.signed_preimage(deps[6], suite[0], deps[0][0],
                                           attestation, effective[0], effective[1])
    require(approval[1] == digest
            and keccak256(artist.attestation_preimage(
                deps[6], suite[0], deps[0][0], attestation, binding[0],
                authority[1], authority[2], effective[0], effective[1])) == expected[0],
            "VIEW inventory original Artist digest/record")
    retained = _retained(evidence_id, evidence, source["evidenceMetadata"],
                         source["pointerRuntime"])
    row = list(item_tools.bytes_item(6, "ORIGINAL_ARTIST_PUBLICATION_AUTHORIZATION",
                                    suite[1], evidence_id, 1, evidence))
    row[16] = keccak256(encode(
        ("bytes32", artist.EVIDENCE, "address", ("address",) * 5,
         ("bytes32",) * 5, "bytes32", "bool"),
        (original_record, expected, actor, deps[2], deps[3], retained, direct)))
    return tuple(row)


def _domain(chain_id, registry):
    return keccak256(encode(
        ("bytes32", "bytes32", "bytes32", "uint256", "address"),
        (schema_id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
         schema_id("6529StreamArtistRegistry"), schema_id("1"),
         chain_id, registry)))


def _consent_digest(chain_id, registry, core, terms, authorization):
    body = keccak256(encode(
        ("bytes32", "address", "address", "uint256", "bytes32", "bytes32",
         "uint256", "uint64"),
        (schema_id("StreamArtistContentConsent(address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline)"),
         core, terms[1], terms[0], terms[2], terms[3],
         authorization[0], authorization[1])))
    return keccak256(b"\x19\x01" + hex_bytes(_domain(chain_id, registry))
                     + hex_bytes(body))


def _consent_record(chain_id, registry, core, terms, artist_id, signer,
                    authority_class, nonce, observed_at):
    return keccak256(encode(
        ("bytes32", "uint256", "address", "address", "address", "uint256",
         "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"),
        (schema_id("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"), chain_id,
         registry, terms[1], core, terms[0], terms[2], terms[3], artist_id,
         signer, authority_class, nonce, observed_at)))


def _root_authorization(context, deps, source):
    _closed(source, ("rootRecord", "aggregate", "legacyFamilyHash", "actor",
                     "observedAt", "suite", "coordinatorConfigurationHash",
                     "archiveRegistry", "archiveCoordinator", "evidenceHex",
                     "evidenceMetadata", "pointerRuntime", "savedConsent"),
            "VIEW inventory root-authorization source")
    root = _typed(ROOT_RECORD, source["rootRecord"],
                  "VIEW inventory scoped root record")
    aggregate = _typed(AGGREGATE, source["aggregate"],
                       "VIEW inventory scoped root aggregate")
    suite = _typed(artist.SUITE, source["suite"], "VIEW inventory Artist suite")
    saved = _typed(CONSENT_RECORD, source["savedConsent"],
                   "VIEW inventory saved content consent")
    actor, legacy = source["actor"], source["legacyFamilyHash"]
    observed = (uint(source["observedAt"], 64) if type(source["observedAt"]) is str
                else source["observedAt"])
    require(aggregate[0] > 0 and aggregate[1] != ZERO and legacy != ZERO
            and actor != ZERO_ADDRESS and type(observed) is int
            and 0 < observed < 1 << 64,
            "VIEW inventory root original aggregate/actor")
    require(root[8] == context[2] and root[0][0] == context[0]
            and root[1] == deps[0][5] and root[2] == deps[1][5]
            and root[0][2] == context[3][0] and root[0][3] == context[3][3]
            and root[16] != ZERO,
            "VIEW inventory scoped root context")
    root_hash = keccak256(encode(
        ("bytes32", "uint256", "address", "address", ROOT_RECORD, AGGREGATE),
        (schema_id("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"), deps[6],
         deps[0][4], deps[0][0], root, aggregate)))
    require(root_hash == context[9], "VIEW inventory scoped root record hash")
    signed_family = keccak256(encode(
        ("bytes32", "uint256", "address", "address", "uint256", "bytes32", AGGREGATE),
        (schema_id("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"), deps[6],
         deps[0][4], deps[0][0], context[0][1], legacy, aggregate)))
    require(suite[0] == deps[2][0] and suite[1] == deps[2][4]
            and suite[2][2] == deps[2][2] and suite[2][4] == deps[2][3]
            and suite[2][6] == deps[4] and suite[3] == deps[0][0]
            and suite[6] == deps[0][4]
            and source["archiveRegistry"] == suite[0]
            and source["archiveCoordinator"] == deps[2][1],
            "VIEW inventory historical Artist suite bindings")
    evidence_id = keccak256(encode(
        ("bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"),
        (schema_id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
         deps[6], suite[0], deps[2][1], 17, actor, root[16])))
    # Native IO.read permits a 65,600-byte ABI return: 64 bytes of dynamic
    # envelope plus at most 65,536 exact evidence bytes.
    evidence = _bytes(source["evidenceHex"], 65536,
                      "VIEW inventory Archive op17 evidence")
    envelope = _decode_tail(artist.ARCHIVE, evidence,
                            "VIEW inventory Archive op17 envelope")
    require(envelope[:5] == (1, source["coordinatorConfigurationHash"], 17,
                             actor, root[16]),
            "VIEW inventory Archive op17 envelope fields")
    binding, terms, authorization, approval, prior_state = _decode_tail(
        CONTENT_PAYLOAD, envelope[7], "VIEW inventory Archive op17 content payload")
    require(saved[:3] == (root[16], root[8], root[9]) and saved[3] == terms
            and saved[4] in (1, 3), "VIEW inventory saved content consent")
    require(terms == (context[0][1], deps[0][4], schema_id("CONTENT_ROOT"), signed_family)
            and binding[0] == root[8] and binding[3] == root[10]
            and binding[4] == root[9] and binding[9]
            and approval[0] != ZERO_ADDRESS and prior_state not in (ZERO, signed_family)
            and observed <= root[17] and authorization[1] >= observed,
            "VIEW inventory original content consent terms")
    require((approval[2] and actor == approval[0] and not authorization[2])
            or (not approval[2] and bool(authorization[2])),
            "VIEW inventory original content consent signature mode")
    require(approval[1] == _consent_digest(deps[6], suite[0], deps[0][0],
                                           terms, authorization),
            "VIEW inventory original content consent digest")
    require(root[16] == _consent_record(deps[6], suite[0], deps[0][0], terms,
                                        root[8], approval[0], saved[4],
                                        authorization[0], observed),
            "VIEW inventory original content consent record")
    retained = _retained(evidence_id, evidence, source["evidenceMetadata"],
                         source["pointerRuntime"])
    row = list(item_tools.bytes_item(
        6, "ORIGINAL_VIEW_PRESERVATION_CONTENT_ROOT_AUTHORIZATION",
        suite[1], evidence_id, 1, evidence))
    row[16] = keccak256(encode(
        ("bytes32", AGGREGATE, "bytes32", "bytes32", "address", "uint64",
         "bytes32", "bytes32"),
        (root_hash, aggregate, legacy, signed_family, actor, observed, retained,
         keccak256(encode((DEPENDENCIES,), (deps,))))))
    return tuple(row)


def _definition(index, documents, schemas):
    require(type(index) is int and 0 <= index < len(DEFINITIONS),
            "VIEW inventory definition index")
    name, identifier, expected_hash = DEFINITIONS[index]
    row = item_tools.document(identifier, expected_hash, schemas, documents)
    return name, row, keccak256(encode(("bytes32", ITEM), (identifier, row)))


def _catalogs(rows, deps, documents):
    """Reproduce Documents.authenticateCatalogs for derived catalog rows."""
    catalogs = tuple(row for row in rows if row[0] == 3)
    if not catalogs:
        return
    require(isinstance(documents, dict),
            "VIEW inventory catalog global documents required")
    for row in catalogs:
        actual = item_tools.document(row[12], row[13], deps[0][2], documents)
        require(actual[9] == row[9]
                and keccak256(actual[7]) == keccak256(row[7]),
                "VIEW inventory registered catalog bytes")


def _typed_stage(stage, context, deps, source, documents):
    """Derive stages 2--5 solely from original records and typed witnesses."""
    if stage == 5 and context[6][3] == 1:
        require(source is None and context[6][4][0] == ZERO,
                "VIEW inventory explicit interview waiver")
        row = list(item_tools.absent("INTERVIEW_ORIGINAL_EXPLICITLY_WAIVED",
                                     deps[0][1], context[6][0][0], 0))
        row[16] = context[7]
        return (tuple(row),), context[7]

    keys = (("original", "typedWitness", "selection", "artist") if stage == 2
            else ("original", "typedWitness") if stage == 3
            else ("original", "typedWitness", "artist"))
    _closed(source, keys, "VIEW inventory typed-stage source")

    if stage == 2:
        descriptions = context[5]
        record_hash, payload_hash = descriptions[1], descriptions[3]
        selected = _typed(WORK_SELECTION, source["selection"],
                          "VIEW inventory work selection")
        require(selected[0] == record_hash and selected[21] == descriptions[5]
                and selected[2] == payload_hash and selected[7] == descriptions[7]
                and record_hash != ZERO and payload_hash != ZERO and selected[7] > 0,
                "VIEW inventory work selected record/hash")
        unhashed = selected[:21] + (ZERO,)
        require(selected[21] == keccak256(encode(
            ("bytes32", "uint256", "address", "address", "address", "address",
             "address", "uint256", "bytes32", WORK_SELECTION),
            (schema_id("6529STREAM_WORK_SELECTION_V1"), deps[6], deps[0][7],
             deps[0][0], deps[0][1], deps[0][2], deps[0][3], context[0][1],
             context[1], unhashed))), "VIEW inventory work selection preimage")
        _, exact, refs = references.derive_work(
            deps[0][1], record_hash, payload_hash, source["typedWitness"])
        originals, payload = _original(context, deps, record_hash, payload_hash,
                                       source["original"])
        require(payload == exact, "VIEW inventory work exact original payload")
        receipt = _typed(RECEIPT, source["original"]["receipt"],
                         "VIEW inventory work original receipt")
        definitions = {name: digest for name, _, digest in DEFINITIONS}
        require(receipt[4] == selected[8] and receipt[1] == selected[12]
                and receipt[2] == selected[13] and receipt[5] == selected[9]
                and receipt[6] == definitions["STREAM_WORK_DESCRIPTION_V1"]
                and receipt[7] == WORK_CANON_HASH
                and receipt[8] == selected[17][0],
                "VIEW inventory work selection/original receipt")
        if selected[17][0] != ZERO:
            require(source["artist"] is not None,
                    "VIEW inventory work original Artist source")
            originals += (_artist_item(deps, selected[17], record_hash,
                                       source["artist"], source["original"]),)
        else:
            require(source["artist"] is None,
                    "VIEW inventory work unexpected original Artist source")
        _catalogs(refs, deps, documents)
        return originals + refs, descriptions[5]

    if stage == 3:
        descriptions = context[5]
        record_hash, payload_hash = descriptions[2], descriptions[4]
        _, exact, refs = references.derive_rights(
            deps[0][1], record_hash, payload_hash, source["typedWitness"])
        originals, payload = _original(context, deps, record_hash, payload_hash,
                                       source["original"])
        require(payload == exact, "VIEW inventory rights exact original payload")
        return originals + refs, descriptions[6]

    record = context[6][0] if stage == 4 else context[6][4]
    record_hash, payload_hash = record[0], record[2]
    if stage == 4:
        require(record[1] in (0, 1), "VIEW inventory intent record kind")
        derive = references.derive_intent if record[1] == 0 else references.derive_waiver
        expected_witness = context[6][12]
    else:
        require(context[6][3] == 0 and record_hash != ZERO,
                "VIEW inventory present interview")
        derive, expected_witness = references.derive_interview, context[7]
    _, exact, refs = derive(deps[0][1], record_hash, payload_hash,
                            source["typedWitness"])
    originals, payload = _original(context, deps, record_hash, payload_hash,
                                   source["original"])
    require(payload == exact, "VIEW inventory conservation exact original payload")
    originals += (_artist_item(deps, record[8], record_hash, source["artist"],
                               source["original"]),)
    if stage == 5:
        _catalogs(refs, deps, documents)
    return originals + refs, expected_witness


def validate_fixed_stage(stage, index, items, witness, context, deps, source,
                         graph, *, documents=None):
    """Validate a fixed stage from closed source preimages.

    Stages 2--5 reconstruct exact canonical typed payloads, original generic
    records and any required op24 evidence. Caller-authored rows never serve as
    authority.
    """
    require(type(stage) is int and 2 <= stage <= 7 and type(index) is int,
            "VIEW inventory fixed stage/index")
    context = _typed(native_types.CONTEXT, context, "VIEW inventory context")
    deps = _bindings(deps, graph)
    rows = tuple(from_json(ITEM, value) for value in items)
    if stage in (2, 3, 4, 5):
        require(index == 0, "VIEW inventory typed-stage occurrence")
        expected, expected_witness = _typed_stage(stage, context, deps, source,
                                                  documents)
        require(rows == expected and witness == expected_witness,
                "VIEW inventory typed-stage rows/witness")
        return {"stage": stage, "index": 0, "rows": rows,
                "nextStage": stage + 1}
    if stage == 6:
        require(index == 0 and len(rows) == 1,
                "VIEW inventory root authorization occurrence")
        expected = _root_authorization(context, deps, source)
        require(rows == (expected,) and witness == context[9],
                "VIEW inventory root authorization row/witness")
        return {"stage": 6, "index": 0, "rows": rows, "nextStage": 7}
    if stage == 7:
        require(source is None and isinstance(documents, dict),
                "VIEW inventory definition global documents required")
        name, expected, expected_witness = _definition(index, documents, deps[0][2])
        require(rows == (expected,) and witness == expected_witness,
                "VIEW inventory definition row/witness")
        return {"stage": 7, "index": index, "definition": name,
                "rows": rows, "nextStage": 8 if index == 35 else 7}
    require(False, "VIEW inventory fixed stage unsupported")

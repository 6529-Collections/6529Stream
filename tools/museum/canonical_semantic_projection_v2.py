"""Deterministic Linked Art projection of an admitted canonical source inventory.

The source inventory is verified by ``canonical_semantic_sources_v2`` before
this adapter is called.  This module binds a closed occurrence selection to
that complete inventory, emits attributed record and family-specific field
statements for selected occurrences, and retains every original and semantic leaf.  It never promotes
candidate titles, creators, owners, recorders, or subjects into people,
institutions, legal title, or unconditional work facts.
"""

from copy import deepcopy
from pathlib import Path

from .canonical import MuseumError, dumps, keccak256, loads, subject_id, record_chain, uint
from . import canonical_semantic_sources_v2 as sources
from . import owner_family_semantics_v1 as owner_meaning
from .independent_wire import ZERO, require
from .owner_notice_dossier import DEFAULT_MODEL_ROOT
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator


PROFILE = "STREAM_MUSEUM_CANONICAL_SEMANTIC_PROJECTION_V2"
SELECTION_PROFILE = "STREAM_MUSEUM_CANONICAL_SEMANTIC_SELECTION_V2"
RULE = "urn:6529stream:museum:canonical-semantic:v2:"
OUTPUT_PREFIX = "semantic/"
MAX_INPUT_BYTES = 64 * 1024 * 1024
MAX_OUTPUT_BYTES = 64 * 1024 * 1024
MAX_ROWS = 8192
MAX_LEAVES = 262144
MAX_RESOURCE_BYTES = 262144
OWNER_FAMILIES = ("ACCESSION", "CONDITION_REPORT", "EXHIBITION", "LOAN",
    "DEACCESSION", "CITATION", "VALUATION", "STEWARD_DESIGNATION",
    "RECOVERY_RESPONSE", "REDEMPTION_CLAIM")
FAMILIES = ("WORK", "CONDITION", *OWNER_FAMILIES, "OWNER_UNKNOWN")
STATUSES = (
    "current_native_head", "historical_native_selection", "unselected_original",
    "explicit_original_selection", "historical_original", "selected_condition",
    "selected_condition_unresolved", "other_subject",
)
SELECTION_BASES = (
    "native_work_revision", "explicit_accession_record",
    "receipt_ordered_condition", "none",
)

INDEX_PATH = OUTPUT_PREFIX + "index.json"
STATE_PATH = OUTPUT_PREFIX + "source-state.json"
SELECTION_PATH = OUTPUT_PREFIX + "selection.json"
ASSERTIONS_PATH = OUTPUT_PREFIX + "assertions.json"
COVERAGE_PATH = OUTPUT_PREFIX + "coverage.json"
PROVENANCE_PATH = OUTPUT_PREFIX + "provenance.json"
OWNER_RELATIONS_PATH = OUTPUT_PREFIX + "owner-relations.json"
REPORT_PATH = OUTPUT_PREFIX + "report.json"
PROFILE_PATH = OUTPUT_PREFIX + "profile.json"
CROSSWALK_PATH = OUTPUT_PREFIX + "crosswalk.json"

QUALIFICATION = (
    "Projection of a separately verified canonical source inventory. Linked Art "
    "resources describe attributed record statements and their retained digital "
    "payload occurrences. Selection does not prove current eligibility, human or "
    "institutional identity, legal title, authorship, performed activity, file "
    "retrieval, fixity, archival status, consensus, or global history."
)
CLAIMS = {
    "sourceInventoryVerifiedHere": False,
    "completeInventoryDenominatorBound": True,
    "completeOriginalAndSemanticLeafCoverage": True,
    "orderedDuplicateOccurrencesPreserved": True,
    "selectedAndAlternativeOccurrencesSeparated": True,
    "nativeCurrentnessRetainedWithoutEligibilityPromotion": True,
    "linkedArtResourcesShapeValidatedOffline": True,
    "candidateTitlesOrCreatorsPromotedToWorkFacts": False,
    "ownerPromotedToArtistOrInstitution": False,
    "personOrGroupInferred": False,
    "legalTitleInferred": False,
    "activityOrPerformanceInferred": False,
    "fileRetrievalOrArchiveStatusInferred": False,
    "linkedArtApiConformanceClaimed": False,
    "profileRegistered": False,
    "allNamedOwnerFamiliesSupported": True,
    "ownerInterpretationIndependentlyRecomputed": True,
    "nativeOwnerLaneOrderRecomputed": True,
    "everySelectedOwnerSemanticLeafAccounted": True,
    "ownerStatementsBecomeSpecializedState": False,
    "redemptionFulfillmentInferred": False,
}


def _rule(name, source, target, cardinality, transformation, uncertainty,
          positive, negative):
    return {
        "id": RULE + name,
        "sourceProfile": "STREAM_MUSEUM_CANONICAL_SEMANTIC_SOURCES_V2",
        "sourceSelector": source,
        "target": target,
        "cardinality": cardinality,
        "transformation": transformation,
        "authority": "exact original row authority and selector",
        "uncertainty": uncertainty,
        "reverseCorrespondence": (
            "The assertion sidecar retains the occurrence ID, exact selector, "
            "original row, parsed semantic value, currentness, pointers, and leaves."
        ),
        "positiveTest": positive,
        "negativeTest": negative,
    }


CROSSWALK = {
    "name": "STREAM_MUSEUM_CANONICAL_SEMANTIC_CROSSWALK_V2",
    "version": "2",
    "rules": [
        _rule("attributed-statement", "/rows/*[interpretation.status=interpreted]",
            "LinguisticObject", "one distinct resource per selected occurrence",
            "Describe the exact interpreted record as an attributed statement; do not create a Work, Person, Group, Activity, or legal-title assertion.",
            "Original authority is a retained record mode and does not prove authorship, identity, assent, legal effect, or current eligibility.",
            "test_default_selection_emits_distinct_validated_statements_and_payloads",
            "test_conflicting_candidates_never_flatten_into_work_or_agent_facts"),
        _rule("payload-carrier", "/rows/*/pointers/payload",
            "DigitalObject digitally_carries LinguisticObject",
            "zero or one occurrence-specific carrier per selected statement",
            "Create a carrier only when the verified row has an exact payload pointer; keep occurrence identity distinct even when hashes repeat.",
            "The pointer is retained evidence, not retrieval, fixity, format detection, or archival custody.",
            "test_default_selection_emits_distinct_validated_statements_and_payloads",
            "test_missing_unknown_reordered_or_rehashed_selection_rejects"),
        _rule("candidate-fields", "/rows/*/semantic/**",
            "typed sidecar only", "all values, ordered duplicates, nulls, and empty containers",
            "Retain candidate title, creator, owner, recorder, subject, condition, and other family fields exactly in the assertion sidecar.",
            "No candidate is promoted into an unconditional work, agent, ownership, or identity fact.",
            "test_conflicting_candidates_never_flatten_into_work_or_agent_facts",
            "test_missing_unknown_reordered_or_rehashed_selection_rejects"),
        _rule("complete-coverage", "/leaves/*", "coverage ledger",
            "every original and semantic leaf exactly once",
            "Retain every leaf; family-specific owner predicates carry qualified field mappings, while original transport and residual fields stay retention-only.",
            "Retention does not strengthen opaque or historical source meaning.",
            "test_leaf_coverage_preserves_original_semantic_null_empty_and_duplicates",
            "test_missing_unknown_reordered_or_rehashed_selection_rejects"),
    ],
}
CROSSWALK["rules"].extend(_rule(
    "owner-" + family.lower(), "/rows/*[family=" + family + "]/ownerMeaning/relations/*",
    "LinguisticObject part_of original record statement; exact typed relation sidecar",
    "one field statement per declared predicate occurrence; residual fields remain retention-only",
    "Quote the family-specific predicate and value as a declaration of the original token owner, retaining exact payload JSON pointer, native subject, authority and currentness.",
    "Declared parties, resources, dates, valuations, loans, notice responses and redemption programs are not independently authenticated acts, identities, rights or state transitions.",
    "test_all_ten_owner_families_emit_typed_field_statements",
    "test_rehashed_typed_meaning_authority_and_subject_tampering_rejects")
    for family in OWNER_FAMILIES)
CROSSWALK_BYTES = dumps(CROSSWALK)
CROSSWALK_HASH = keccak256(CROSSWALK_BYTES)
PROFILE_BYTES = dumps({
    "name": PROFILE,
    "version": "2",
    "status": "prospective_unregistered_projection_profile",
    "selectionProfile": SELECTION_PROFILE,
    "crosswalkHash": CROSSWALK_HASH,
    "validationPolicyHash": VALIDATION_HASH,
    "ownerInterpretationProfileHash": owner_meaning.PROFILE_HASH,
    "context": CONTEXT,
    "families": list(FAMILIES),
    "rules": {
        "denominator": "Bind the complete admitted row and leaf inventory before applying selection; recompute each native owner lane index, hash chain, head and per-author latest before deriving meaning.",
        "defaultSelection": "Select every interpreted row whose verified currentness.selected is true; eligibility remains exactly as observed.",
        "historicalSelection": "An explicit ordered occurrence selection may include interpreted retained history but cannot relabel it current.",
        "identity": "Every occurrence, statement, and payload carrier has a distinct stable identity; equal names or hashes never merge entities.",
        "semantics": "Owner family predicates become qualified field statements within their original record statement, with exact subject, authority, payload pointers and retained values. WORK and condition retain their V1 mappings. No declared party or activity becomes an authenticated real-world entity.",
        "alternatives": "Every unselected, conflicting, opaque, stale, and other-subject row remains visible in the index and coverage ledger.",
        "conservation": "Any existing conservation graph remains a retained explicit family reference and is not reinterpreted here.",
    },
    "claims": CLAIMS,
    "qualification": QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _hash(value):
    return keccak256(dumps(value))


def _model(root):
    return validator(Path(root))


def _inventory_hash(inventory):
    return sources.inventory_hash(inventory)


def _inventory(inventory):
    required = {
        "profileHash", "sourceManifestHash", "sourceState", "sourceStateHash",
        "rows", "leaves", "denominators", "conservation", "claims",
        "qualification", "finality", "recordHeads", "sourceBindings",
        "disclosure", "definitions", "ownerDefinitions",
    }
    require(type(inventory) is dict and set(inventory) == required
        and inventory["profileHash"] == sources.PROFILE_HASH
        and inventory["disclosure"] == "public",
        "canonical semantic inventory shape")
    require(type(inventory["profileHash"]) is str
        and type(inventory["sourceManifestHash"]) is str
        and type(inventory["sourceStateHash"]) is str
        and _hash(inventory["sourceState"]) == inventory["sourceStateHash"],
        "canonical semantic inventory source bindings")
    rows, leaves = inventory["rows"], inventory["leaves"]
    require(type(rows) is list and len(rows) <= MAX_ROWS
        and type(leaves) is list and len(leaves) <= MAX_LEAVES,
        "canonical semantic inventory row/leaf bounds")
    seen = set()
    row_keys = {
        "occurrenceId", "family", "selector", "original", "semantic",
        "interpretation", "authority", "currentness", "pointers", "catalog", "ownerMeaning",
    }
    current_keys = {"status", "selected", "selectionBasis", "selection", "eligibility"}
    for row in rows:
        require(type(row) is dict and set(row) == row_keys
            and type(row["occurrenceId"]) is str and row["occurrenceId"] not in seen
            and row["family"] in FAMILIES, "canonical semantic inventory row shape")
        seen.add(row["occurrenceId"])
        require(row["occurrenceId"] == keccak256(dumps({
            "profileHash": sources.PROFILE_HASH,
            "sourceManifestHash": inventory["sourceManifestHash"],
            "selector": row["selector"], "originalPointer": row["pointers"]["original"]})),
            "canonical semantic occurrence identity differs")
        interpretation = row["interpretation"]
        require(type(interpretation) is dict
            and set(interpretation) == {"status", "reason"}
            and interpretation["status"] in ("interpreted", "opaque")
            and ((interpretation["status"] == "interpreted" and interpretation["reason"] is None
                  and row["semantic"] is not None)
                 or (interpretation["status"] == "opaque"
                     and type(interpretation["reason"]) is str)),
            "canonical semantic interpretation shape")
        current = row["currentness"]
        require(type(current) is dict and set(current) == current_keys
            and current["status"] in STATUSES and type(current["selected"]) is bool
            and current["selectionBasis"] in SELECTION_BASES
            and type(current["eligibility"]) is str,
            "canonical semantic currentness shape")
        require(type(row["pointers"]) is dict
            and set(row["pointers"]) == {"original", "payload", "projection", "authority", "currentness"},
            "canonical semantic pointer shape")
    expected_leaf_keys = {"occurrenceId", "section", "jsonPointer", "valueType", "value"}
    leaf_counts = {identifier: 0 for identifier in seen}
    for leaf in leaves:
        require(type(leaf) is dict and set(leaf) == expected_leaf_keys
            and leaf["occurrenceId"] in seen and leaf["section"] in ("original", "semantic", "catalog")
            and type(leaf["jsonPointer"]) is str and type(leaf["valueType"]) is str,
            "canonical semantic leaf shape")
        leaf_counts[leaf["occurrenceId"]] += 1
    require(all(leaf_counts.values()), "canonical semantic row without leaf coverage")
    expected = []
    for row in rows:
        expected.extend(sources.leaves(row["original"], row["occurrenceId"], "original"))
        if row["semantic"] is not None:
            expected.extend(sources.leaves(row["semantic"], row["occurrenceId"], "semantic"))
        if row["catalog"] is not None:
            require(type(row["catalog"]) is dict and set(row["catalog"]) == {
                "value", "bytesHex", "source", "bytesSource", "registrationAuthenticated"}
                and row["catalog"]["registrationAuthenticated"] is False,
                "canonical semantic catalog shape")
            expected.extend(sources.leaves(row["catalog"]["value"], row["occurrenceId"], "catalog"))
    require(leaves == expected, "canonical semantic complete leaf denominator differs")
    return rows, leaves




def _owner_lanes(rows, denominator, state, host):
    """The saved native indices, not semantic annotation order, fix primacy."""
    by_hash = {row["original"]["recordHash"]: row["original"] for row in rows}
    require(len(by_hash) == len(rows), "canonical owner duplicate native original")
    catalogue = denominator["catalogue"]
    lanes = denominator["lanes"]
    require(type(catalogue) is list and type(lanes) is list
        and len(catalogue) <= sources.owner_wire.MAX_TYPES,
        "canonical owner catalogue bound")
    types = [entry["recordType"] for entry in catalogue]
    require(len(types) == len(set(types)) and set(sources.owner_wire.FIXED) <= set(types)
        and [lane["recordType"] for lane in lanes] == types,
        "canonical owner complete lane catalogue differs")
    used = set()
    for lane in lanes:
        hashes, previous, latest = lane["records"], ZERO, {}
        require(type(hashes) is list and len(hashes) == uint(lane["count"], 64)
            and len(set(hashes)) == len(hashes), "canonical owner lane count differs")
        for index, digest in enumerate(hashes):
            require(digest in by_hash and digest not in used,
                "canonical owner lane missing or duplicated original")
            original = by_hash[digest]
            record, receipt = original["record"], original["receipt"]
            require(record[0] == lane["recordType"] and receipt[3] == str(index)
                and receipt[4] == record_chain(state["chainId"], host, state["tokenId"],
                    lane["recordType"], previous, digest, str(index)),
                "canonical owner lane original index/chain differs")
            previous = receipt[4]
            latest[receipt[1]] = digest
            used.add(digest)
        require(lane["head"] == previous
            and lane["state"] == ("complete_history" if hashes else "authenticated_empty")
            and lane["latestByAuthor"] == [{"owner": owner, "recordHash": digest}
                for owner, digest in sorted(latest.items())],
            "canonical owner lane head/per-author latest differs")
    require(used == set(by_hash), "canonical owner original lane denominator differs")

def _owners(inventory, *, plan_files=None, plan_hash=None):
    """Recompute typed meaning over the full admitted owner denominator.

    This is supplied-data consistency. The source reader separately verifies
    the native receipts and source pointers before constructing this inventory.
    Neither an inventory flag nor a caller-provided derived meaning is trusted.
    """
    plan = sources._plan(plan_files, plan_hash)
    require(inventory["ownerDefinitions"] == sources._definition_summary(plan),
        "canonical owner definition denominator differs")
    defs = owner_meaning.definitions(dict(plan.files), plan.manifest_hash)
    owners = [row for row in inventory["rows"]
        if row["selector"]["kind"] == "native_owner_family"]
    require(all(row["ownerMeaning"] is None for row in inventory["rows"]
        if row["selector"]["kind"] != "native_owner_family"),
        "canonical owner interpretation on non-owner occurrence")
    denominator = inventory["denominators"]["owner"]
    require(denominator["recordCount"] == str(len(owners)),
        "canonical owner record denominator differs")
    state = inventory["sourceState"]
    _owner_lanes(owners, denominator, state, owners[0]["selector"]["host"] if owners else None)
    if not owners:
        return
    subject = subject_id("token", state["chainId"], state["core"], "0", token_id=state["tokenId"])
    host = owners[0]["selector"]["host"]
    context = deepcopy(state)
    context.update(host=host, subjectId=subject)
    for row in owners:
        selector, original = row["selector"], row["original"]
        record = original["record"]
        require(selector == {
            "kind": "native_owner_family", "chainId": state["chainId"],
            "core": state["core"], "host": host, "recordHash": original["recordHash"],
            "recordType": record[0], "subjectId": subject, "schemaId": record[2],
            "canonicalizationId": record[3][2], "sourceId": None}
            and record[1] == subject and original["receipt"][0] == state["tokenId"],
            "canonical owner exact subject and native selector differ")
        require(row["authority"] == original["authority"] == {
            "mode": "historical_native_owner_receipt", "owner": original["receipt"][1],
            "currentOwnerProven": False, "legalTitleProven": False},
            "canonical owner authority differs from original receipt")
    result = owner_meaning.annotate(owner_meaning.interpret_all(
        [row["original"] for row in owners], context, defs), denominator["lanes"])
    require(result["laneAnalysis"] == denominator["laneAnalysis"],
        "canonical owner lane analysis differs")
    require(len(result["rows"]) == len(owners), "canonical owner meaning denominator differs")
    for row, expected in zip(owners, result["rows"]):
        chosen = row["selector"]["recordHash"] == denominator["selectedOriginal"]["recordHash"]
        require(row["currentness"] == {
            "status": "explicit_original_selection" if chosen else "historical_original",
            "selected": chosen,
            "selectionBasis": "explicit_accession_record" if chosen else "none",
            "selection": denominator["selectedOriginal"] if chosen else None,
            "eligibility": "not_asserted"}
            and (not chosen or (row["family"] == "ACCESSION" and expected["status"] == "typed")),
            "canonical owner explicit selection/currentness differs")
        require(row["ownerMeaning"] == expected and row["semantic"] == expected["semantic"]
            and row["family"] == expected["family"]
            and row["interpretation"] == {
                "status": "interpreted" if expected["status"] == "typed" else "opaque",
                "reason": expected["reason"]},
            "canonical owner derived semantic interpretation differs")
        if expected["status"] == "typed":
            require(row["pointers"]["payload"] is not None,
                "canonical owner typed payload pointer absent")

def default_selection(inventory, *, plan_files=None, plan_hash=None):
    """Return the canonical current-observed occurrence selection."""
    rows, _ = _inventory(inventory)
    _owners(inventory, plan_files=plan_files, plan_hash=plan_hash)
    selected = [row["occurrenceId"] for row in rows
        if row["interpretation"]["status"] == "interpreted"
        and row["currentness"]["selected"]]
    return dumps({
        "profile": SELECTION_PROFILE,
        "version": "2",
        "sourceManifestHash": inventory["sourceManifestHash"],
        "sourceStateHash": inventory["sourceStateHash"],
        "inventoryHash": _inventory_hash(inventory),
        "policy": "current_observed",
        "reason": "verified_current_selection_without_eligibility_promotion",
        "selectedOccurrenceIds": selected,
    })


def historical_selection(inventory, occurrence_ids, *, plan_files=None, plan_hash=None):
    """Build a closed explicit historical-review selection for known rows."""
    rows, _ = _inventory(inventory)
    _owners(inventory, plan_files=plan_files, plan_hash=plan_hash)
    require(type(occurrence_ids) is list and occurrence_ids
        and len(occurrence_ids) <= MAX_ROWS
        and all(type(value) is str for value in occurrence_ids)
        and len(set(occurrence_ids)) == len(occurrence_ids),
        "canonical semantic historical selection identifiers")
    by_id = {row["occurrenceId"]: row for row in rows}
    require(all(identifier in by_id
        and by_id[identifier]["interpretation"]["status"] == "interpreted"
        and by_id[identifier]["currentness"]["status"] != "other_subject"
        for identifier in occurrence_ids),
        "canonical semantic historical selection unsupported occurrence")
    return dumps({
        "profile": SELECTION_PROFILE,
        "version": "2",
        "sourceManifestHash": inventory["sourceManifestHash"],
        "sourceStateHash": inventory["sourceStateHash"],
        "inventoryHash": _inventory_hash(inventory),
        "policy": "explicit_historical",
        "reason": "retained_historical_occurrence_review",
        "selectedOccurrenceIds": occurrence_ids,
    })


def _selection(inventory, rows, raw, expected_hash):
    require(type(raw) is bytes and len(raw) <= 1024 * 1024
        and keccak256(raw) == expected_hash, "canonical semantic selection external hash differs")
    value = loads(raw, maximum=1024 * 1024, canonical=True)
    require(type(value) is dict and set(value) == {
        "profile", "version", "sourceManifestHash", "sourceStateHash",
        "inventoryHash", "policy", "reason", "selectedOccurrenceIds",
    } and value["profile"] == SELECTION_PROFILE and value["version"] == "2"
        and value["sourceManifestHash"] == inventory["sourceManifestHash"]
        and value["sourceStateHash"] == inventory["sourceStateHash"]
        and value["inventoryHash"] == _inventory_hash(inventory)
        and value["policy"] in ("current_observed", "explicit_historical"),
        "canonical semantic selection shape/bindings")
    ids = value["selectedOccurrenceIds"]
    require(type(ids) is list and len(ids) <= MAX_ROWS
        and all(type(identifier) is str for identifier in ids)
        and len(set(ids)) == len(ids), "canonical semantic selection occurrence IDs")
    by_id = {row["occurrenceId"]: row for row in rows}
    require(all(identifier in by_id for identifier in ids)
        and all(by_id[identifier]["interpretation"]["status"] == "interpreted" for identifier in ids),
        "canonical semantic selection unknown or opaque occurrence")
    require(all(by_id[identifier]["currentness"]["status"] != "other_subject" for identifier in ids),
        "canonical semantic selection cannot cross subject")
    if value["policy"] == "current_observed":
        expected = [row["occurrenceId"] for row in rows
            if row["interpretation"]["status"] == "interpreted"
            and row["currentness"]["selected"]]
        require(ids == expected
            and value["reason"] == "verified_current_selection_without_eligibility_promotion",
            "canonical semantic current-observed selection differs")
    else:
        require(ids and value["reason"] == "retained_historical_occurrence_review",
            "canonical semantic historical selection reason")
    return value, by_id


def _record_key(row):
    selector = row["selector"]
    value = {key: selector[key] for key in (
        "kind", "chainId", "core", "host", "recordHash", "subjectId")}
    if selector["kind"] in ("native_owner_family", "native_owner_condition"):
        value["kind"] = "native_owner"
    if selector["sourceId"] is not None and value["kind"] != "native_owner":
        value["sourceId"] = selector["sourceId"]
    return keccak256(dumps(value))


def _identity(row, kind):
    return RULE + kind + ":" + row["occurrenceId"].removeprefix("0x")


def _type(family):
    return {"id": RULE + "family:" + family.lower(), "type": "Type",
        "_label": family.lower() + " attributed statement"}


def _resource(row):
    statement_id = _identity(row, "record-statement")
    semantic_bytes = dumps(row["semantic"])
    statement = {
        "@context": CONTEXT,
        "id": statement_id,
        "type": "LinguisticObject",
        "_label": row["family"].title() + " attributed record statement",
        "content": semantic_bytes.decode("utf-8"),
        "classified_as": [_type(row["family"])],
        "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}],
    }
    resources = [("statement", statement)]
    if row["pointers"]["payload"] is not None:
        carrier_id = _identity(row, "payload-occurrence")
        carrier = {
            "@context": CONTEXT,
            "id": carrier_id,
            "type": "DigitalObject",
            "_label": row["family"].title() + " retained payload occurrence",
            "classified_as": [{"id": RULE + "payload-carrier", "type": "Type",
                "_label": "retained payload carrier"}],
            "digitally_carries": [{"id": statement_id, "type": "LinguisticObject"}],
            "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}],
        }
        resources.append(("payload", carrier))
    return resources



def _owner_relations(row):
    """Attributed predicates; identifiers never denote an inferred real actor."""
    meaning = row["ownerMeaning"]
    if meaning is None or meaning["status"] != "typed":
        return []
    result = []
    for index, relation in enumerate(meaning["relations"]):
        result.append({
            "id": _identity(row, "owner-field-" + str(index)),
            "recordStatement": _identity(row, "record-statement"),
            "family": row["family"],
            "predicate": relation["predicate"],
            "value": deepcopy(relation["value"]),
            "sourcePointer": deepcopy(row["pointers"]["payload"]),
            "payloadJsonPointer": relation["sourcePointer"],
            "sourcePathBase": "input/",
            "selector": deepcopy(row["selector"]),
            "authority": deepcopy(row["authority"]),
            "currentness": deepcopy(row["currentness"]),
            "qualification": relation["qualification"],
            "status": ("retained_payload_field" if relation["predicate"].startswith("retains-payload-field:")
                else "attributed_owner_declaration"),
            "independentFactEstablished": False,
            "rule": RULE + "owner-" + row["family"].lower(),
        })
    return result


def _owner_resources(row, relations):
    resources = []
    for index, relation in enumerate(relations):
        predicate = relation["predicate"]
        # Keep the declared value exact while making its attributed predicate
        # explicit. The URI/classification names the statement, not a Person,
        # Group, Activity, custody event, operative notice or redeemed object.
        resource = {
            "@context": CONTEXT,
            "id": relation["id"],
            "type": "LinguisticObject",
            "_label": row["family"].replace("_", " ").title() + " — " + predicate,
            "content": ("The original owner payload retains " + predicate.removeprefix("retains-payload-field:")
                if relation["status"] == "retained_payload_field"
                else "The original token owner declares " + predicate) + ": "
                + dumps(relation["value"]).decode("utf-8") + ". "
                + relation["qualification"],
            "classified_as": [_type(row["family"]), {
                "id": RULE + "owner-predicate:" + keccak256(predicate.encode("utf-8"))[2:],
                "type": "Type", "_label": predicate}],
            "part_of": [{"id": relation["recordStatement"], "type": "LinguisticObject"}],
            "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}],
        }
        resources.append(("owner_field:" + str(index), resource))
    return resources


def _field_coverage(leaf, row, selected, relations):
    if not selected or leaf["section"] != "semantic" or row["ownerMeaning"] is None:
        return {}
    pointer = leaf["jsonPointer"]
    candidates = [relation for relation in relations
        if pointer == relation["payloadJsonPointer"]
        or pointer.startswith(relation["payloadJsonPointer"] + "/")]
    # Every mapped value is a qualified family declaration. Native transport
    # fields and opaque rows remain losslessly retained with no mapped claim.
    require(candidates, "canonical owner semantic leaf lacks a typed predicate")
    width = max(len(relation["payloadJsonPointer"]) for relation in candidates)
    candidates = [relation for relation in candidates if len(relation["payloadJsonPointer"]) == width]
    retained = all(relation["status"] == "retained_payload_field" for relation in candidates)
    return {"disposition": "retained_stream_only" if retained else "mapped_attributed_owner_declaration",
        "reason": ("exact declared payload field retained without a field-level CRM mapping" if retained else
            "exact field within a family-specific original-owner declaration; no independent fact or activity inferred"),
        "statements": [relation["id"] for relation in candidates],
        "rules": sorted({relation["rule"] for relation in candidates})}

def _candidate_rows(rows):
    result = []
    for row in rows:
        if row["interpretation"]["status"] != "interpreted":
            continue
        semantic = row["semantic"]
        candidates = []
        if isinstance(semantic, dict):
            for key, value in semantic.items():
                if key.lower() in ("title", "name", "creator", "artist", "maker", "author"):
                    candidates.append({"field": key, "value": deepcopy(value)})
        result.append({"occurrenceId": row["occurrenceId"], "family": row["family"],
            "selector": deepcopy(row["selector"]), "candidates": candidates,
            "disposition": "attributed_candidate_only",
            "unconditionalWorkOrAgentFact": False})
    return result


def _candidate_conflicts(rows):
    groups = {}
    for row in rows:
        if row["family"] != "WORK" or row["interpretation"]["status"] != "interpreted":
            continue
        value = row["semantic"]
        if not isinstance(value, dict):
            continue
        selector = row["selector"]
        scope = {"kind": selector["kind"], "chainId": selector["chainId"],
            "core": selector["core"], "subjectId": selector["subjectId"]}
        for field in ("title", "creator"):
            if field not in value:
                continue
            groups.setdefault((dumps(scope), field), []).append({
                "occurrenceId": row["occurrenceId"], "value": deepcopy(value[field]),
                "valueHash": _hash(value[field]), "currentness": deepcopy(row["currentness"]),
                "authority": deepcopy(row["authority"])})
    result = []
    for (scope_raw, field), candidates in groups.items():
        hashes = {row["valueHash"] for row in candidates}
        result.append({"scope": loads(scope_raw, canonical=True), "predicate": field,
            "candidates": candidates, "distinctValueCount": str(len(hashes)),
            "disagreement": len(hashes) > 1,
            "disposition": "qualified_alternatives_no_precedence"})
    return result


def _project(inventory, selection_raw, selection_hash, model):
    rows, leaves = _inventory(inventory)
    selection, by_id = _selection(inventory, rows, selection_raw, selection_hash)
    selected_ids, files, resource_index, provenance, assertions = (
        set(selection["selectedOccurrenceIds"]), {}, [], [], [])
    relation_rows = {row["occurrenceId"]: _owner_relations(row) for row in rows}
    resource_bytes = 0
    for identifier in selection["selectedOccurrenceIds"]:
        row = by_id[identifier]
        emitted = []
        for role, resource in _resource(row) + _owner_resources(row, relation_rows[identifier]):
            raw = dumps(resource)
            expanded = model.validate_and_expand(raw, maximum=MAX_RESOURCE_BYTES).expanded_bytes
            stem = keccak256(resource["id"].encode("utf-8"))[2:]
            path = OUTPUT_PREFIX + "resources/" + stem + ".json"
            expanded_path = OUTPUT_PREFIX + "expanded/" + stem + ".json"
            require(path not in files and expanded_path not in files,
                "canonical semantic resource path collision")
            resource_bytes += len(raw) + len(expanded)
            require(resource_bytes <= MAX_OUTPUT_BYTES, "canonical semantic resource aggregate bound")
            files[path], files[expanded_path] = raw, expanded
            resource_index.append({"id": resource["id"], "type": resource["type"],
                "role": role, "path": path, "expandedPath": expanded_path,
                "occurrenceId": identifier})
            emitted.append({"role": role, "id": resource["id"], "path": path})
            field = (relation_rows[identifier][int(role.split(":")[1])]
                if role.startswith("owner_field:") else None)
            provenance.append({"entity": resource["id"], "occurrenceId": identifier,
                "selector": deepcopy(row["selector"]), "authority": deepcopy(row["authority"]),
                "currentness": deepcopy(row["currentness"]),
                "sourcePointer": deepcopy(row["pointers"]["payload"] if role == "payload" or field is not None
                    else (row["pointers"]["projection"] or row["pointers"]["payload"]
                        or row["pointers"]["original"])),
                "sourcePathBase": "input/",
                "rule": field["rule"] if field is not None else RULE + ("payload-carrier" if role == "payload" else "attributed-statement"),
                "payloadJsonPointer": field["payloadJsonPointer"] if field is not None else None,
                "predicate": field["predicate"] if field is not None else None,
                "qualification": QUALIFICATION})
        assertions.append({"occurrenceId": identifier, "family": row["family"],
            "recordIdentity": RULE + "record:" + _record_key(row).removeprefix("0x"),
            "payloadByteIdentity": RULE + "payload-bytes:"
                + keccak256(dumps(row["semantic"])).removeprefix("0x"),
            "selector": deepcopy(row["selector"]), "original": deepcopy(row["original"]),
            "semantic": deepcopy(row["semantic"]), "ownerMeaning": deepcopy(row["ownerMeaning"]),
            "authority": deepcopy(row["authority"]),
            "currentness": deepcopy(row["currentness"]), "pointers": deepcopy(row["pointers"]),
            "resources": emitted, "status": "attributed_statement_only",
            "ownerRelations": relation_rows[identifier]})

    alternatives = [{"occurrenceId": row["occurrenceId"], "family": row["family"],
        "selector": deepcopy(row["selector"]), "interpretation": deepcopy(row["interpretation"]),
        "authority": deepcopy(row["authority"]), "currentness": deepcopy(row["currentness"]),
        "ownerMeaning": deepcopy(row["ownerMeaning"]),
        "disposition": "selected" if row["occurrenceId"] in selected_ids else "retained_alternative"}
        for row in rows]
    coverage = []
    for leaf in leaves:
        coverage.append(deepcopy(leaf) | {
            "disposition": "retained_stream_only",
            "reason": "exact field retained in source/assertion sidecar; no field-level CRM mapping claimed",
        } | _field_coverage(leaf, by_id[leaf["occurrenceId"]], leaf["occurrenceId"] in selected_ids,
            relation_rows[leaf["occurrenceId"]]))

    files[STATE_PATH] = dumps({"profile": PROFILE,
        "sourceManifestHash": inventory["sourceManifestHash"],
        "sourceStateHash": inventory["sourceStateHash"],
        "sourceState": deepcopy(inventory["sourceState"]),
        "finality": deepcopy(inventory["finality"]),
        "recordHeads": deepcopy(inventory["recordHeads"]),
        "sourceBindings": deepcopy(inventory["sourceBindings"]),
        "disclosure": deepcopy(inventory["disclosure"]),
        "definitions": deepcopy(inventory["definitions"]),
        "ownerDefinitions": deepcopy(inventory["ownerDefinitions"]),
        "conservation": deepcopy(inventory["conservation"])})
    files[SELECTION_PATH] = selection_raw
    files[ASSERTIONS_PATH] = dumps({"profile": PROFILE, "selected": assertions,
        "candidateFields": _candidate_rows(rows),
        "candidateConflicts": _candidate_conflicts(rows),
        "qualification": QUALIFICATION})
    files[COVERAGE_PATH] = dumps({"profile": PROFILE,
        "inventoryHash": _inventory_hash(inventory), "leaves": coverage,
        "leafCount": str(len(coverage)),
        "originalLeafCount": str(sum(row["section"] == "original" for row in coverage)),
        "semanticLeafCount": str(sum(row["section"] == "semantic" for row in coverage)),
        "complete": True})
    files[OWNER_RELATIONS_PATH] = dumps({"profile": PROFILE, "relations": [
        relation for identifier in selection["selectedOccurrenceIds"]
        for relation in relation_rows[identifier]],
        "laneAnalysis": deepcopy(inventory["denominators"]["owner"].get("laneAnalysis")),
        "qualification": QUALIFICATION})
    files[PROVENANCE_PATH] = dumps(provenance)
    files[INDEX_PATH] = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH,
        "validationPolicyHash": VALIDATION_HASH, "inventoryHash": _inventory_hash(inventory),
        "selectionHash": selection_hash, "resources": resource_index,
        "occurrences": alternatives})
    files[REPORT_PATH] = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH,
        "version": "2", "status": "supported",
        "completeness": "complete_with_stream_extensions",
        "sourceProfileHash": inventory["profileHash"],
        "sourceManifestHash": inventory["sourceManifestHash"],
        "sourceStateHash": inventory["sourceStateHash"],
        "inventoryHash": _inventory_hash(inventory), "selectionHash": selection_hash,
        "selectionPolicy": selection["policy"],
        "rowCount": str(len(rows)), "selectedCount": str(len(assertions)),
        "alternativeCount": str(len(rows) - len(assertions)),
        "resourceCount": str(len(resource_index)), "leafCount": str(len(leaves)),
        "recordIdentityRule": "chain/core/host/native authority class/recordHash/subjectId plus sourceId only when present; owner-family and owner-condition occurrences share native OwnerRecords identity",
        "payloadByteIdentityRule": "Keccak256 exact canonical interpreted semantic bytes retained per occurrence",
        "crossExportOccurrenceIdentityClaimed": False,
        "crosswalkHash": CROSSWALK_HASH, "validationPolicyHash": VALIDATION_HASH,
        "claims": CLAIMS, "qualification": QUALIFICATION})
    files[PROFILE_PATH], files[CROSSWALK_PATH] = PROFILE_BYTES, CROSSWALK_BYTES
    require(sum(map(len, files.values())) <= MAX_OUTPUT_BYTES,
        "canonical semantic projection output bound")
    return files


def render(inventory, selection_raw, selection_hash, *, model_root=DEFAULT_MODEL_ROOT,
           plan_files=None, plan_hash=None):
    """Render a closed selection from a separately admitted source inventory."""
    try:
        require(len(dumps(inventory)) <= MAX_INPUT_BYTES, "canonical semantic input bound")
        _inventory(inventory)
        _owners(inventory, plan_files=plan_files, plan_hash=plan_hash)
        model = _model(str(Path(model_root).resolve()))
        return _project(deepcopy(inventory), selection_raw, selection_hash,
            model)
    except MuseumError:
        raise
    except (KeyError, IndexError, TypeError, ValueError, OverflowError,
            UnicodeError, RecursionError) as exc:
        raise MuseumError("malformed canonical semantic projection input") from exc

"""Deterministic candidate resources from policy-selected fixture assertions.

This is the first resource projection, not a registered export or chain adapter.
Original records remain separate from the deliberately smaller Linked Art graph.
"""

from dataclasses import dataclass
from pathlib import Path

from .canonical import MuseumError, dumps, keccak256, loads, schema_id, uint
from .coverage import verify_coverage
from .dependencies import OfflineDocuments
from .identity import EntityDeclaration, KINDS, entity_index
from .linked_art import PinnedLinkedArt, format_checker
from .review import ASSERTION_SCHEMA_BYTES, _selector, _validate
from .schema_inventory import EVALUATION_PROFILE_HASH, inventory_exact
from .schemas import NAMES
from .semantic_selection import select_canonical_fixture
from .source import public_records
from .vocabulary import Vocabulary

CRM = "http://www.cidoc-crm.org/cidoc-crm/"
DIG = "http://www.ics.forth.gr/isl/CRMdig/"
LA = "https://linked.art/ns/terms/"
CONTEXT = "https://linked.art/ns/v1/linked-art.json"
RULE = "urn:6529stream:museum:projection:v1:"

# A generic event is not necessarily an Activity. Generic information is not
# necessarily visual or linguistic. These remain explicit extension entities.
CLASSES = {
    "visual_content": ("VisualItem", CRM + "E36_Visual_Item"),
    "digital_object": ("DigitalObject", DIG + "D1_Digital_Object"),
    "physical_object": ("HumanMadeObject", CRM + "E22_Human-Made_Object"),
    "person": ("Person", CRM + "E21_Person"), "group": ("Group", CRM + "E74_Group"),
    "place": ("Place", CRM + "E53_Place"), "set": ("Set", LA + "Set"),
}
EXTENSION_CLASSES = {"abstract_work": CRM + "E89_Propositional_Object",
                     "information_object": CRM + "E73_Information_Object", "event": CRM + "E5_Event"}
RELATIONS = {
    LA + "digitally_shows": "digitally_shows",
    CRM + "P65_shows_visual_item": "shows",
    CRM + "P138_represents": "represents",
    CRM + "P129_is_about": "about",
}


def crosswalk_document():
    """Definition bytes have no final parent-profile hash dependency."""
    base = {"sourceSchemaId": schema_id(NAMES[1]), "sourceSchemaHash": keccak256(ASSERTION_SCHEMA_BYTES),
            "sourceSchemaVersion": "1", "authorityRule": "exact_selected_selector_and_fixture_issuer",
            "controlledTerms": [], "uncertaintyTreatment": "retain original evidence without strengthening",
            "reverseCorrespondence": "exact source selector and bytes in provenance/source sidecar"}
    rows = []
    for kind in sorted(KINDS):
        target = CLASSES.get(kind)
        rows.append(base | {"rule": RULE + "kind:" + kind, "sourceSelector": "/entities/*/kind",
                    "sourceSubjectKind": kind, "targetClass": target[1] if target else EXTENSION_CLASSES.get(kind),
                    "targetPath": "/type" if target else None, "cardinality": "one per selected declaration",
                    "transformation": "explicit kind to class" if target else "typed Stream extension; no Linked Art shape claim",
                    "positiveTest": "test_explicit_kinds_and_generic_extensions_remain_distinct",
                    "negativeTest": "test_wrong_domain_and_dangling_reference_reject"})
    rows.append(base | {"rule": RULE + "name", "sourceSelector": "/entities/*/names/*",
                "sourceSubjectKind": "selected supported entity", "targetClass": CRM + "E41_Appellation",
                "targetPath": "/identified_by/*", "cardinality": "preserve source order and repetitions",
                "transformation": "identifier kind to Identifier; other names to Name; exact content",
                "positiveTest": "test_name_order_exact_text_and_unmapped_language_are_retained",
                "negativeTest": "test_entity_issuer_and_every_selector_word_are_required"})
    for predicate, prop in sorted(RELATIONS.items()):
        rows.append(base | {"rule": RULE + "relation:" + prop, "sourceSelector": "/assertions/*",
                    "sourceSubjectKind": "selected domain-compatible entity", "targetClass": None,
                    "targetPath": "/" + prop + "/*", "cardinality": "one row per selected assertion",
                    "transformation": "exact predicate/entity reference with finite domain and range checks",
                    "controlledTerms": [predicate],
                    "positiveTest": "test_carriers_depiction_and_about_expand_to_exact_predicates",
                    "negativeTest": "test_wrong_domain_and_dangling_reference_reject"})
    return {"mode": "candidate_canonical_assertion_crosswalk", "version": "1", "rules": rows,
            "displayLabelRule": "first supplied name, otherwise exact stable identifier; display aid only",
            "coverageRule": "inventory whole selected record before projection; retain every other field",
            "limits": {"records": "512", "entities": "512", "externalEntities": "512",
                       "sourceBytes": "16777216", "encodedOutputBytes": "67108864"},
            "fullSourceFamilyCrosswalkComplete": False}


CROSSWALK_BYTES = dumps(crosswalk_document())
CROSSWALK_HASH = keccak256(CROSSWALK_BYTES)


class ProjectionProfile:
    version = "1"
    rule_prefix = RULE
    crosswalk_bytes = CROSSWALK_BYTES
    crosswalk_hash = CROSSWALK_HASH
    validation_directory = "linked-art"
    classes = CLASSES
    relations = RELATIONS

    def __init__(self, root: Path, crosswalk_bytes: bytes, *, crosswalk_hash: str,
                 validation_hash: str, vocabulary_hash: str):
        if crosswalk_bytes != self.crosswalk_bytes or keccak256(crosswalk_bytes) != crosswalk_hash:
            raise MuseumError("unsupported or mismatched projection crosswalk")
        validation = (root / self.validation_directory / "validation-policy.json").read_bytes()
        vocab = (root / "standards/vocabulary-policy.json").read_bytes()
        if keccak256(vocab) != vocabulary_hash:
            raise MuseumError("projection vocabulary policy hash mismatch")
        vi = loads((root / self.validation_directory / "validation-index.json").read_bytes(), maximum=65536)
        oi = loads((root / "standards/vocabulary-index.json").read_bytes(), maximum=65536)
        self.linked_art = PinnedLinkedArt(OfflineDocuments(root, vi), validation, validation_hash)
        self.vocabulary = Vocabulary(OfflineDocuments(root / "standards", oi), loads(vocab, canonical=True))
        self.identity = dumps({"crosswalkHash": crosswalk_hash, "validationPolicyHash": validation_hash,
                               "vocabularyPolicyHash": vocabulary_hash,
                               "derivedSchemaHashes": dict(self.linked_art.derived_schema_hashes)})

    def content_specializations(self, selection, entities, policy):
        return {}

    def literal_content(self, assertion, resource_class):
        return None


@dataclass(frozen=True)
class ProjectedResource:
    identifier: str
    content: bytes
    expanded: bytes


@dataclass(frozen=True)
class Projection:
    resources: tuple[ProjectedResource, ...]
    sidecar: bytes
    coverage: bytes
    provenance: bytes
    report: bytes


def _entity(state, row, profile_hash):
    if not isinstance(row, dict) or not isinstance(row.get("pointer"), str) or not row["pointer"].startswith("/entities/"):
        raise MuseumError("entity selector required")
    index = uint(row["pointer"][len("/entities/"):], 64)
    matches = [r for r in public_records(state) if r.selector.record_hash == row.get("recordHash")]
    if len(matches) != 1 or row != _selector(matches[0], row["pointer"]):
        raise MuseumError("entity record selector mismatch")
    record = matches[0]
    if record.schema != ASSERTION_SCHEMA_BYTES or record.selector.schema_id != schema_id(NAMES[1]):
        raise MuseumError("entity assertion schema mismatch")
    payload = _validate(record.schema, record.payload)
    if (payload["profileHash"] != profile_hash or payload["anchorSubject"]["subjectId"] != record.selector.subject_id
            or index >= len(payload["entities"])):
        raise MuseumError("entity profile, subject or index mismatch")
    value = payload["entities"][index]
    facts = loads(record.authority_evidence, canonical=True)
    if (facts.get("mode") != "synthetic_fixture" or facts.get("recorder") != record.selector.recorder
            or facts.get("recordType") != record.selector.record_type
            or facts.get("authorizationClass") != record.selector.authorization_class
            or facts.get("agentIri") != value["declaringAgent"]):
        raise MuseumError("entity fixture issuer or family mismatch")
    return value, record


def project_fixture(state, selection_bytes: bytes, plan_bytes: bytes, *, selection_hash: str,
                    plan_hash: str, profile_hash: str, profile: ProjectionProfile) -> Projection:
    rules, classes, relations = profile.rule_prefix, profile.classes, profile.relations
    selection = select_canonical_fixture(state, selection_bytes, policy_hash=selection_hash, profile_hash=profile_hash)
    if keccak256(plan_bytes) != plan_hash:
        raise MuseumError("projection plan hash mismatch")
    plan = loads(plan_bytes, maximum=524288, canonical=True)
    if (not isinstance(plan, dict) or set(plan) != {"mode", "version", "sourceStateHash", "profileHash",
            "selectionPolicyHash", "crosswalkHash", "entityAuthoritySet", "externalEntities"}
            or plan["mode"] != "synthetic_resource_projection" or plan["version"] != profile.version
            or plan["sourceStateHash"] != state.commitment or plan["profileHash"] != profile_hash
            or plan["selectionPolicyHash"] != selection_hash or plan["crosswalkHash"] != profile.crosswalk_hash):
        raise MuseumError("projection plan scope mismatch")
    for key in ("entityAuthoritySet", "externalEntities"):
        if (not isinstance(plan[key], list) or len(plan[key]) > 512
                or len({dumps(v) for v in plan[key]}) != len(plan[key])):
            raise MuseumError("invalid projection plan entries")
    external = {}
    for item in plan["externalEntities"]:
        if (not isinstance(item, dict) or set(item) != {"id", "kind"} or item["kind"] not in KINDS
                or not isinstance(item["id"], str) or not format_checker().conforms(item["id"], "uri")
                or item["id"] in external):
            raise MuseumError("invalid external entity declaration")
        external[item["id"]] = item["kind"]
    public = sorted(public_records(state), key=lambda r: r.selector.record_hash)
    if sum(len(r.payload) + len(r.schema) + len(r.authority_evidence) for r in public) > 16 * 1024 * 1024:
        raise MuseumError("projection source byte limit")
    declarations, selected_rows, entities, records = [], {}, {}, {}
    for row in plan["entityAuthoritySet"]:
        value, record = _entity(state, row, profile_hash)
        declaration = EntityDeclaration(value["id"], value["kind"], row["recordHash"], row["pointer"], value["declaringAgent"])
        declarations.append(declaration)
        selected_rows[(row["recordHash"], row["pointer"])] = value["declaringAgent"]
        entities.setdefault(value["id"], (value, row))
        records[row["recordHash"]] = record
    references = []
    for value, _ in entities.values():
        references.extend([value["declaringAgent"], *value["predecessors"]])
    for claim in selection.selected:
        assertion = loads(claim.assertion)
        references.extend([assertion["subject"], assertion["assertingAgent"]])
        if "entity" in assertion["object"]:
            references.append(assertion["object"]["entity"])
        references.extend(loads(e)["reviewer"] for e in claim.review_evidence)
    selected_entities, _ = entity_index(tuple(declarations), selected_rows, tuple(references), frozenset(external))
    policy = loads(selection_bytes)
    specializations = profile.content_specializations(selection, entities, policy)
    resolved_classes = {identifier: classes.get(value["kind"]) for identifier, (value, _) in entities.items()}
    resolved_classes.update({identifier: value["resourceClass"] for identifier, value in specializations.items()})
    scope = {row["recordHash"] for row in policy["sourceAuthoritySet"] + policy["reviewerAuthoritySet"]}
    scope.update(records)
    records = {r.selector.record_hash: r for r in public if r.selector.record_hash in scope}
    inventories = {key: inventory_exact(r.schema, r.payload, schema_hash=r.selector.schema_hash,
                    payload_hash=r.payload_hash, evaluation_hash=EVALUATION_PROFILE_HASH) for key, r in records.items()}
    resources, extensions, provenance, mapped, retained_claims = {}, [], [], set(), []
    reference_types = []

    def evidence(entity, target, row, source_pointer, rule, basis):
        provenance.append({"entity": entity, "targetPointer": target, "source": row,
                           "sourcePointer": source_pointer, "rule": rule, "basis": basis})
        mapped.add((row["recordHash"], source_pointer))

    for declaration in selected_entities:
        value, row = entities[declaration.identifier]
        kind = value["kind"]
        resource_class = resolved_classes[value["id"]]
        if resource_class is None:
            extensions.append({"id": value["id"], "kind": kind, "crmClass": EXTENSION_CLASSES.get(kind),
                               "declaration": value, "source": row,
                               "rule": rules + "kind:" + kind})
            if value["id"] in specializations:
                extensions[-1]["contentKind"] = specializations[value["id"]]["contentKind"]
                extensions[-1]["contentKindEvidence"] = specializations[value["id"]]["evidence"]
            continue
        label = value["names"][0]["value"] if value["names"] else value["id"]
        resource = {"@context": CONTEXT, "id": value["id"], "type": resource_class[0], "_label": label}
        resources[value["id"]] = resource
        for target, field in (("/id", "/id"), ("/type", "/kind"),
                              ("/_label", "/names/0/value" if value["names"] else "/id")):
            evidence(value["id"], target, row, row["pointer"] + field, rules + "kind:" + kind, "selected declaration")
        if value["id"] in specializations:
            for item in specializations[value["id"]]["evidence"]:
                evidence(value["id"], "/type", item["selector"], item["selector"]["pointer"] + "/object/literal/lexicalValue",
                         rules + "content-kind", item["basis"])
                evidence(value["id"], "/type", item["selector"], item["selector"]["pointer"] + "/relation",
                         rules + "content-kind", item["basis"])
        if value["names"]:
            resource["identified_by"] = []
        for i, name in enumerate(value["names"]):
            resource["identified_by"].append({"type": "Identifier" if name["kind"] == "identifier" else "Name",
                                               "content": name["value"]})
            for target, field in (("/type", "/kind"), ("/content", "/value")):
                evidence(value["id"], "/identified_by/" + str(i) + target, row,
                         row["pointer"] + "/names/" + str(i) + field, rules + "name", "selected declaration")

    def kind_of(identifier):
        return entities[identifier][0]["kind"] if identifier in entities else external[identifier]

    def class_of(identifier):
        return resolved_classes[identifier] if identifier in entities else classes.get(external[identifier])

    for claim in selection.selected:
        assertion, row = loads(claim.assertion), loads(claim.selector)
        subject, predicate = assertion["subject"], assertion["relation"]
        target = assertion["object"].get("entity")
        reason = "no supported exact Linked Art rule; retain typed assertion"
        if any(item["selector"] == row for item in specializations.get(subject, {}).get("evidence", [])):
            reason = "explicit content-kind evidence retained with its resource specialization or typed extension"
        content = profile.literal_content(assertion, class_of(subject))
        if content is not None and subject in resources:
            resources[subject]["content"] = content
            evidence(subject, "/content", row, row["pointer"] + "/object/literal/lexicalValue", rules + "content", claim.basis)
            evidence(subject, "/content", row, row["pointer"] + "/relation", rules + "content", claim.basis)
            reason = "mapped exact linguistic content; original qualifiers and evidence retained"
        elif predicate in relations and target is not None and subject in resources and class_of(target) is not None:
            subject_class, target_class = class_of(subject)[1], class_of(target)[1]
            profile.vocabulary.require_relation(subject_class, predicate, target_class)
            prop = relations[predicate]
            values = resources[subject].setdefault(prop, [])
            i = len(values)
            values.append({"id": target, "type": class_of(target)[0]})
            for suffix, field in (("/id", "/object/entity"), ("/type", "/object/entity")):
                evidence(subject, "/" + prop + "/" + str(i) + suffix, row, row["pointer"] + field,
                         rules + "relation:" + prop, claim.basis)
            if target in entities:
                _, target_row = entities[target]
                evidence(subject, "/" + prop + "/" + str(i) + "/type", target_row,
                         target_row["pointer"] + "/kind", rules + "kind:" + kind_of(target), "selected target declaration")
                for item in specializations.get(target, {}).get("evidence", []):
                    evidence(subject, "/" + prop + "/" + str(i) + "/type", item["selector"],
                             item["selector"]["pointer"] + "/object/literal/lexicalValue", rules + "content-kind", item["basis"])
            else:
                reference_types.append({"entity": subject, "targetPointer": "/" + prop + "/" + str(i) + "/type",
                                        "externalEntity": target, "kind": kind_of(target), "planHash": plan_hash})
            evidence(subject, "/" + prop, row, row["pointer"] + "/relation", rules + "relation:" + prop, claim.basis)
            reason = "mapped exact entity relation; original authority and review evidence retained"
        retained_claims.append({"selector": row, "assertion": assertion, "basis": claim.basis,
                               "reviewEvidence": [loads(e) for e in claim.review_evidence], "projectionReason": reason})
    output = []
    for identifier, resource in sorted(resources.items()):
        expanded = profile.linked_art.validate_and_expand(dumps(resource))
        if loads(expanded.expanded_bytes, maximum=16 * 1024 * 1024)[0].get("@type") != [class_of(identifier)[1]]:
            raise MuseumError("expanded entity class differs from the crosswalk")
        output.append(ProjectedResource(identifier, expanded.source_bytes, expanded.expanded_bytes))
    coverage = []
    for key, inv in sorted(inventories.items()):
        rows = [{"pointer": f.pointer, "presence": f.presence, "exactHex": "0x" + f.exact.hex(),
                 "disposition": "mapped" if (key, f.pointer) in mapped else "retained_stream_only",
                 "rule": rules + "coverage", "reason": "source bytes retained; emitted source field" if (key, f.pointer) in mapped
                 else "source bytes retained; no stronger projection claim"} for f in inv.fields]
        verify_coverage(inv.fields, rows)
        coverage.append({"recordHash": key, "schemaHash": inv.schema_hash, "payloadHash": inv.payload_hash,
                         "evaluationHash": inv.evaluation_hash, "fields": rows})
    sidecar = dumps({"mode": "synthetic_projection_sidecar", "selectedClaims": retained_claims,
        "withheldClaims": [{"selector": loads(c.selector), "assertion": loads(c.assertion),
                            "reviewEvidence": [loads(e) for e in c.review_evidence]} for c in selection.withheld],
        "extensionEntities": extensions, "externalEntities": sorted(plan["externalEntities"], key=lambda v: v["id"]),
        "diagnostics": [{"selector": loads(d.selector), "reason": d.reason} for d in selection.diagnostics],
        "publicSources": [{"selector": _selector(r, ""), "payloadHex": "0x" + r.payload.hex(),
                           "schemaHex": "0x" + r.schema.hex(), "authorityEvidenceHex": "0x" + r.authority_evidence.hex(),
                           "inventoryScope": r.selector.record_hash in scope} for r in public]})
    coverage_raw, provenance_raw = dumps(coverage), dumps(sorted(provenance, key=dumps))
    report = dumps({"mode": "synthetic_candidate_resource_projection", "version": profile.version, "sourceStateHash": state.commitment,
        "profileHash": profile_hash, "selectionPolicyHash": selection_hash, "planHash": plan_hash,
        "projectionDependencies": loads(profile.identity), "sidecarHash": keccak256(sidecar),
        "profileDerivedPaths": [{"entity": r.identifier, "targetPointer": "/@context", "value": CONTEXT,
                                  "basis": "exact validation policy/context bytes"} for r in output],
        "externalTypeProvenance": reference_types,
        "coverageHash": keccak256(coverage_raw), "provenanceHash": keccak256(provenance_raw),
        "entities": [{"id": r.identifier, "kind": "linked_art", "contentHash": keccak256(r.content),
                      "expandedHash": keccak256(r.expanded)} for r in output]
                    + [{"id": e["id"], "kind": "stream_extension", "sidecarHash": keccak256(sidecar)} for e in extensions],
        "claims": {"registered": False, "authenticatedChainState": False, "fullMuseumScope": False,
                   "losslessLinkedArt": False, "linkedArtApi": False}})
    size = sum(len(r.content) + len(r.expanded) for r in output) + len(sidecar) + len(coverage_raw) + len(provenance_raw) + len(report)
    if size > 64 * 1024 * 1024:
        raise MuseumError("encoded projection byte limit")
    return Projection(tuple(output), sidecar, coverage_raw, provenance_raw, report)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Generate/check the candidate definition crosswalk")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = Path(__file__).resolve().parents[2] / "schemas/museum/projection/crosswalk.json"
    if args.check:
        if path.read_bytes() != CROSSWALK_BYTES:
            raise MuseumError("projection crosswalk bytes differ")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(CROSSWALK_BYTES)
    print("candidate_unregistered", CROSSWALK_HASH, len(CROSSWALK_BYTES))


if __name__ == "__main__":
    main()

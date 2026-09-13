"""Versioned abstract-work and explicit nonvisual-content fixture projection."""

from pathlib import Path

from .canonical import MuseumError, dumps, keccak256, loads
from .projection import CLASSES, CRM, LA, RELATIONS, ProjectionProfile, crosswalk_document

RULE = "urn:6529stream:museum:projection:v2:"
CONTENT_KIND = "urn:6529stream:museum:content-kind:v1"
CONTENT = CRM + "P190_has_symbolic_content"
STRING = "http://www.w3.org/2001/XMLSchema#string"
LINGUISTIC = ("LinguisticObject", CRM + "E33_Linguistic_Object")
KINDS = ("linguistic", "nonlinguistic_sound", "software", "structured_multimedia")
V2_CLASSES = CLASSES | {"abstract_work": ("PropositionalObject", CRM + "E89_Propositional_Object")}
V2_RELATIONS = RELATIONS | {LA + "digitally_carries": "digitally_carries", CRM + "P128_carries": "carries"}


def crosswalk_v2_document():
    result = crosswalk_document()
    result["version"] = "2"
    for row in result["rules"]:
        row["rule"] = row["rule"].replace(":projection:v1:", ":projection:v2:")
        if row["sourceSubjectKind"] == "abstract_work":
            row.update(targetPath="/type", transformation="explicit abstract kind to independently validated E89 resource",
                       positiveTest="test_abstract_work_is_explicit_separate_and_never_invented",
                       negativeTest="test_wrong_type_and_content_predicates_never_force_linguistic_carriers")
    base = result["rules"][0] | {"sourceSelector": "/assertions/*", "cardinality": "one per admitted exact assertion",
                               "sourceSubjectKind": "explicit compatible selected content entity"}
    result["rules"].extend([
        base | {"rule": RULE + "content-kind", "controlledTerms": [CONTENT_KIND, *KINDS],
                "targetClass": LINGUISTIC[1], "targetPath": "/type or typed extension sidecar",
                "transformation": "explicit linguistic declaration specializes statement/information_object to E33; three nonlinguistic kinds remain E73 extension with exact original kind evidence",
                "positiveTest": "test_linguistic_text_and_both_carriers_have_exact_expansion_and_provenance",
                "negativeTest": "test_kind_conflicts_withhold_specialization_without_hiding_originals"},
        base | {"rule": RULE + "content", "controlledTerms": [CONTENT, STRING],
                "targetClass": LINGUISTIC[1], "targetPath": "/content",
                "transformation": "exact selected xsd:string lexicalValue on explicitly linguistic entity; non-null language/unit/precision retained only",
                "positiveTest": "test_linguistic_text_and_both_carriers_have_exact_expansion_and_provenance",
                "negativeTest": "test_conflicting_content_and_qualified_text_are_not_silently_flattened"},
    ])
    for predicate, prop in ((LA + "digitally_carries", "digitally_carries"), (CRM + "P128_carries", "carries")):
        result["rules"].append(base | {"rule": RULE + "relation:" + prop, "controlledTerms": [predicate],
            "targetClass": LINGUISTIC[1], "targetPath": "/" + prop + "/*",
            "transformation": "exact entity relation to explicit linguistic content; generic E73 reference stays precise extension assertion",
            "positiveTest": "test_linguistic_text_and_both_carriers_have_exact_expansion_and_provenance",
            "negativeTest": "test_wrong_type_and_content_predicates_never_force_linguistic_carriers"})
    result["contentKindLiteral"] = {"relation": CONTENT_KIND, "datatype": STRING, "values": list(KINDS),
        "language": None, "unit": None, "precision": None,
        "compatibleKinds": {"linguistic": ["statement", "information_object"],
                            "nonlinguistic": ["information_object"]}}
    result["requiredSingleValuedRelations"] = [CONTENT_KIND, CONTENT]
    result["nonvisualRule"] = "No media-type, filename, readable code or visual carrier inference. E73 relationships, durations, technical literals and dependency history remain exact retained_stream_only where this finite crosswalk has no faithful Linked Art path."
    result["scope"] = "Versioned public-fixture projection; no authenticated chain adapter, complete source-family mapping or archival-format acceptance."
    return result


CROSSWALK_V2_BYTES = dumps(crosswalk_v2_document())
CROSSWALK_V2_HASH = keccak256(CROSSWALK_V2_BYTES)


def _plain_string(value):
    return (isinstance(value, dict) and set(value) == {"lexicalValue", "datatype", "language", "unit", "precision"}
            and isinstance(value["lexicalValue"], str) and value["datatype"] == STRING
            and all(value[k] is None for k in ("language", "unit", "precision")))


class ProjectionProfileV2(ProjectionProfile):
    version = "2"
    rule_prefix = RULE
    crosswalk_bytes = CROSSWALK_V2_BYTES
    crosswalk_hash = CROSSWALK_V2_HASH
    validation_directory = "linked-art-v2"
    classes = V2_CLASSES
    relations = V2_RELATIONS

    def content_specializations(self, selection, entities, policy):
        if not {CONTENT_KIND, CONTENT}.issubset(set(policy["singleValuedRelations"])):
            raise MuseumError("v2 requires content-kind and content conflict withholding")
        result = {}
        for claim in selection.selected:
            assertion = loads(claim.assertion)
            if assertion["relation"] != CONTENT_KIND:
                continue
            value = assertion["object"].get("literal")
            subject = assertion["subject"]
            if (not _plain_string(value) or value["lexicalValue"] not in KINDS or subject not in entities
                    or entities[subject][0]["kind"] not in ("information_object", "statement")
                    or (value["lexicalValue"] != "linguistic" and entities[subject][0]["kind"] != "information_object")):
                raise MuseumError("incompatible explicit content-kind declaration")
            kind = value["lexicalValue"]
            item = result.setdefault(subject, {"contentKind": kind, "resourceClass": LINGUISTIC if kind == "linguistic" else None,
                                              "evidence": []})
            if item["contentKind"] != kind:
                raise MuseumError("unwithheld content-kind conflict")
            item["evidence"].append({"selector": loads(claim.selector), "basis": claim.basis,
                                     "reviewEvidence": [loads(e) for e in claim.review_evidence]})
        return result

    def literal_content(self, assertion, resource_class):
        if assertion["relation"] != CONTENT or resource_class != LINGUISTIC:
            return None
        value = assertion["object"].get("literal")
        # Qualifiers have meaning. This finite string path cannot drop them;
        # retain the original assertion rather than normalize/coerce its value.
        return value["lexicalValue"] if _plain_string(value) else None


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = Path(__file__).resolve().parents[2] / "schemas/museum/projection/crosswalk-v2.json"
    if args.check:
        if path.read_bytes() != CROSSWALK_V2_BYTES:
            raise MuseumError("v2 projection crosswalk bytes differ")
    else:
        path.write_bytes(CROSSWALK_V2_BYTES)
    print("candidate_unregistered", CROSSWALK_V2_HASH, len(CROSSWALK_V2_BYTES))


if __name__ == "__main__":
    main()

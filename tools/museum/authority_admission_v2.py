"""Authenticated V2 authority mapping admission and declaration continuity."""
from .authority import need
from .authority_v2 import _body, RELATION
from .canonical import dumps, loads, schema_id
from .recorded_selection import select_recorded
from .typed_authority_profile import TypedAuthorityProfile, NAMES, ASSERTION_SCHEMA_BYTES
from .typed_declarations import declaration_evidence, resolve_declaration


def candidates(source, selection_bytes, selection_hash):
    need(type(source.profile) is TypedAuthorityProfile, "V2 authority requires registered typed profile")
    selection = select_recorded(source, selection_bytes, policy_hash=selection_hash)
    policy = loads(selection_bytes, maximum=524288, canonical=True)
    admitted = {claim.selector: claim for claim in selection.selected}; result = []
    for selector in policy["sourceAuthoritySet"]:
        assertion, issuer, position = source.assertion(selector)
        if assertion["relation"] != RELATION: continue
        record = source.record(selector); payload = source.payload(record)
        need(record.selector.schema_id == schema_id(NAMES[1]) and record.schema == ASSERTION_SCHEMA_BYTES
            and payload["profileHash"] == source.profile_hash, "V2 authority original must bind the typed schema/profile")
        body = _body(assertion)
        alignments = [value for value in payload["authorityAlignments"] if value["assertionId"] == assertion["id"]]
        need(alignments == [body["alignment"]], "original v2 alignment differs from exact assertion binding")
        declaration, lineage = resolve_declaration(source, selector, assertion, body)
        selected = admitted.get(dumps(selector)); reviewed = selected is not None and bool(selected.review_evidence)
        result.append({"assertion": assertion, "eligible": reviewed, "eligibilityReason": "mapping_lacks_selected_authenticated_review",
            "source": selector, "reviews": [] if selected is None else [loads(raw, canonical=True) for raw in selected.review_evidence],
            "basis": "not_selected" if selected is None else selected.basis, "position": [str(v) for v in position],
            "entityDeclaration": declaration, "declarationLineage": lineage})
    return result, selection


def bind_declarations(source, original_plan_bytes, rows):
    plan = loads(original_plan_bytes, maximum=524288, canonical=True); original = {}
    for selector in plan["entityAuthoritySet"]:
        value, _ = source.entity(source.state, selector, source.profile_hash)
        original[value["id"]] = declaration_evidence(value, selector)
    external = {value["id"] for value in plan["externalEntities"]}
    for row in rows:
        identifier = row["assertion"]["subject"]; original_declaration = original.get(identifier)
        if not row["eligible"]: continue
        if identifier in external:
            row.update(eligible=False, eligibilityReason="original_external_identity_cannot_be_redeclared")
        elif original_declaration is not None and original_declaration not in [row["entityDeclaration"], *row["declarationLineage"]]:
            row.update(eligible=False, eligibilityReason="original_selected_declaration_reuse_not_established")
    # Same lineage may coexist. Selected sibling branches have no implicit winner.
    groups = {}
    for row in rows:
        if row["eligible"]: groups.setdefault(row["assertion"]["subject"], []).append(row)
    for group in groups.values():
        divergent = any(a["entityDeclaration"] not in [b["entityDeclaration"], *b["declarationLineage"]]
            and b["entityDeclaration"] not in a["declarationLineage"] for a in group for b in group)
        if divergent:
            for row in group: row.update(eligible=False, eligibilityReason="ambiguous_selected_declaration_branches")

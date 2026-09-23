"""Manifest-pinned General account selection; no human independence inference."""
import re
from pathlib import Path
from .canonical import dumps, hex_bytes, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .general_attestation_source_v2 import GeneralAttestationSourceV2
from .general_publication_v1 import GeneralPublicationAdapterV1
from .general_review_profile_v1 import CLAIMS, QUALIFICATION
from .general_semantic_source_v2 import GeneralSemanticSourceV2, admission
from .independent_wire import require

NAME = "STREAM_MUSEUM_GENERAL_REVIEW_SELECTION_V1"
MAX_POLICY = 1048576


def select(source, policy_raw, policy_hash):
    require(type(source) is GeneralSemanticSourceV2, "concrete General review source required")
    snapshot_raw = source.snapshot(); snapshot = loads(snapshot_raw, maximum=MAX_TRANSCRIPT, canonical=True)
    require(type(policy_raw) is bytes and len(policy_raw) <= MAX_POLICY and any(hex_bytes(policy_hash, 32))
        and keccak256(policy_raw) == policy_hash, "General review selection external pin differs")
    policy = loads(policy_raw, maximum=MAX_POLICY, canonical=True)
    require(type(policy) is dict and set(policy) == {"profile", "sourceSnapshotHash", "sourceAuthoritySet", "reviewerAuthoritySet",
        "allowAuthorSelfReview", "singleValuedRelations"} and policy["profile"] == NAME
        and policy["sourceSnapshotHash"] == keccak256(snapshot_raw), "General review policy shape or snapshot differs")
    require(type(policy["allowAuthorSelfReview"]) is bool, "explicit author self-review policy required")
    for name in ("sourceAuthoritySet", "reviewerAuthoritySet", "singleValuedRelations"):
        values = policy[name]
        require(type(values) is list and len(values) <= 512 and len({dumps(v) for v in values}) == len(values),
            "General selection duplicate or bound")
    require(all(type(v) is str and len(v) <= 2048 and re.fullmatch(r"[A-Za-z][A-Za-z0-9+.-]*:[^\s]+", v)
        for v in policy["singleValuedRelations"]), "General selection relation IRI differs")
    originals = {}
    for row in snapshot["statements"]:
        if row["status"] != "supported": continue
        for index, assertion in enumerate(row["value"]["assertions"]):
            reference = {**row["source"], "pointer": "/assertions/" + str(index)}
            originals[dumps(reference)] = {"source": reference, "assertion": assertion,
                "authority": admission(row, source.a), "historicalReceipt": row["authority"],
                "anchorSubject": row["value"]["anchorSubject"], "originalProfileHash": row["value"]["profileHash"],
                "publication": row["publication"], "grantEvidence": row["grantEvidence"], "reasons": []}
    ineligible = {dumps(row["source"]) for row in snapshot["ineligibleAssertions"]}
    invalid_records = {row["source"]["recordHash"] for row in snapshot["ineligibleAssertions"] if row["scope"] == "record"}
    admitted = {}
    for name in ("sourceAuthoritySet", "reviewerAuthoritySet"):
        admitted[name] = set()
        for item in policy[name]:
            require(type(item) is dict and set(item) == {"source", "authority"}, "General admission shape differs")
            require(type(item["source"]) is dict, "General admission selector shape differs")
            key = dumps(item["source"]); row = originals.get(key)
            require(key not in ineligible and item["source"].get("recordHash") not in invalid_records, "selected General assertion is semantically ineligible")
            require(row is not None and item["authority"] == row["authority"], "General exact selector/principal/family/scope admission differs")
            require(key not in admitted[name], "General duplicate admission selector")
            admitted[name].add(key)
    review_map = {dumps(r["source"]): r for r in snapshot["reviews"]}
    require(admitted["reviewerAuthoritySet"] <= set(review_map), "selected General reviewer is not a validated review statement")
    chosen_reviews = [review_map[k] for k in sorted(admitted["reviewerAuthoritySet"])]
    selected, withheld = [], []
    for key in sorted(admitted["sourceAuthoritySet"]):
        row = originals[key]; assertion = row["assertion"]
        reviews = [r for r in chosen_reviews if r["target"] == row["source"]
            and r["reviewStatus"] not in ("withdrawn", "disputed")
            and (not r["selfReview"] or policy["allowAuthorSelfReview"])]
        row["qualifyingReviews"] = reviews
        row["reviewQualification"] = "author_confirmed_self_review" if reviews and all(r["selfReview"] for r in reviews) else (
            "explicitly_admitted_distinct_accounts" if reviews else "none")
        if assertion["reviewStatus"] in ("withdrawn", "disputed"): row["reasons"].append("original_disputed_or_withdrawn")
        if any(r["body"]["disposition"] == "rejected" for r in reviews): row["reasons"].append("selected_review_rejects_exact_revision")
        if assertion["origin"] != "direct_statement" and not any(r["body"]["disposition"] == "reviewed" for r in reviews):
            row["reasons"].append("mapping_requires_authenticated_admitted_review")
        (withheld if row["reasons"] else selected).append(row)
    groups = {}
    for row in selected:
        assertion = row["assertion"]
        if assertion["relation"] in policy["singleValuedRelations"]:
            key = (dumps(row["anchorSubject"]), assertion["subject"], assertion["relation"])
            groups.setdefault(key, []).append(row)
    for group in groups.values():
        if len({dumps(r["assertion"]["object"]) for r in group}) > 1:
            for row in group: row["reasons"].append("conflicting_selected_source_values")
    withheld.extend(r for r in selected if r["reasons"])
    return {"profile": NAME, "policy": policy, "policyHash": policy_hash,
        "selected": [r for r in selected if not r["reasons"]], "withheld": sorted(withheld, key=lambda r: dumps(r["source"])),
        "reviews": chosen_reviews, "unselectedCount": str(len(originals) - len(admitted["sourceAuthoritySet"])),
        "claims": CLAIMS, "qualification": QUALIFICATION}


def build(source, policy_raw, policy_hash, *, disclosure):
    """A replayable scoped graph bundle, not a full object-dossier conformance claim."""
    require(disclosure == "public", "General review requires public disclosure before reads")
    result = select(source, policy_raw, policy_hash)
    from .preservation_graph import CONTEXT, validator
    from .attribution_dossier import MAX_GENERAL_V2_RESOURCE
    model = validator(Path(__file__).resolve().parents[2] / "schemas/museum")
    resources, provenance = [], []
    for row in result["selected"]:
        identity = "urn:6529stream:museum:general-review:statement:" + keccak256(dumps(row["source"]))[2:]
        resource = {"@context": CONTEXT, "id": identity, "type": "LinguisticObject",
            "_label": "Historically recorded General assertion", "content": dumps(row["assertion"]).decode(),
            "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}]}
        expanded = model.validate_and_expand(dumps(resource), maximum=MAX_GENERAL_V2_RESOURCE).expanded_bytes
        resources.append({"resource": resource, "expanded": loads(expanded)})
        from .owner_notice_dossier import leaves
        provenance.extend({"entity": identity, "path": pointer, "value": value, "source": row["source"],
            "assertionRevisionHash": keccak256(dumps(row["assertion"])), "mappingRule": row["assertion"]["mappingRule"],
            "authority": row["authority"], "reviews": row["qualifyingReviews"]} for pointer, value in leaves(resource))
    return {"anchor.json": source.anchor_bytes, "general-transcript.json": source.general.transcript(),
        "general-source.json": source.general.snapshot(), "publication-hints.json": source.publications.hints_bytes,
        "publication-transcript.json": source.publications.reader.transcript(), "publications.json": source.publications.snapshot(),
        "semantic-transcript.json": source.transcript(), "semantic-source.json": source.snapshot(),
        "selection.json": policy_raw, "selection-result.json": dumps(result), "graph.json": dumps(resources),
        "provenance.json": dumps(provenance), "profile.json": source.profile.profile_bytes}


def replay(files, policy_hash, *, provenance, disclosure):
    """Explicit transcript provenance remains caller-admitted, never inferred from synthetic data."""
    general = GeneralAttestationSourceV2(files["anchor.json"], ReplayTransport(files["general-transcript.json"],
        keccak256(files["general-transcript.json"])), provenance=provenance)
    publications = GeneralPublicationAdapterV1(general, files["publication-hints.json"], ReplayTransport(
        files["publication-transcript.json"], keccak256(files["publication-transcript.json"])), provenance=provenance)
    source = GeneralSemanticSourceV2(general, publications, ReplayTransport(files["semantic-transcript.json"],
        keccak256(files["semantic-transcript.json"])))
    rebuilt = build(source, files["selection.json"], policy_hash, disclosure=disclosure)
    require(files == rebuilt, "General review replayed bundle differs")
    return rebuilt

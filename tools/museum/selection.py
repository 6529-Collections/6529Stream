"""Fixture-level policy/review semantics, separate from chain verification."""

from dataclasses import dataclass

from .canonical import MuseumError, dumps, keccak256, loads
from .source import BoundSourceState, public_records


@dataclass(frozen=True)
class Selection:
    selected: tuple[bytes, ...]
    withheld: tuple[bytes, ...]
    unselected: tuple[bytes, ...]


def select_fixture(state: BoundSourceState, policy_bytes: bytes,
                   expected_policy_hash: str, profile_hash: str) -> Selection:
    """The test adapter authenticates fixture agents only, never onchain writers.

    Rows in 'sources' and 'reviewers' select exact accepted records, field
    pointers, subject, recorder and family. Self-asserted review flags have no
    effect. Conflicts are grouped only for the policy's single-valued relations.
    """
    if state.mode != "synthetic_fixture":
        raise MuseumError("recorded/draft selection adapter not implemented")
    if keccak256(policy_bytes) != expected_policy_hash:
        raise MuseumError("selection policy hash mismatch")
    policy = loads(policy_bytes, canonical=True)
    if policy["sourceStateHash"] != state.commitment or policy["profileHash"] != profile_hash:
        raise MuseumError("selection state/profile mismatch")
    records = {r.selector.record_hash: r for r in public_records(state)}

    def admitted(row):
        required = {"recordHash", "pointer", "host", "subjectId", "schemaId", "schemaHash", "recordType",
                    "recorder", "authorizationClass", "recordIndex", "recordChainHash"}
        if set(row) != required:
            raise MuseumError("incomplete or unknown source selector field")
        record = records.get(row["recordHash"])
        if record is None:
            raise MuseumError("selected source missing or excluded")
        selector = record.selector
        expected = {"recordHash": selector.record_hash, "host": selector.host,
                    "subjectId": selector.subject_id, "schemaId": selector.schema_id,
                    "schemaHash": selector.schema_hash, "recordType": selector.record_type,
                    "recorder": selector.recorder, "authorizationClass": selector.authorization_class,
                    "recordIndex": selector.record_index, "recordChainHash": selector.record_chain_hash,
                    "pointer": row["pointer"]}
        if row != expected:
            raise MuseumError("selection authority scope mismatch")
        # Fixture evidence explicitly belongs to the source adapter. It is
        # neither a payload reviewer name nor a production verifier shortcut.
        evidence = loads(record.authority_evidence)
        if evidence.get("mode") != "synthetic_fixture" or evidence.get("recorder") != selector.recorder:
            raise MuseumError("fixture authority evidence mismatch")
        return record, evidence["agentIri"]

    def pointer(document, path):
        if path == "":
            return document
        if not isinstance(path, str) or not path.startswith("/"):
            raise MuseumError("invalid evidence pointer")
        node = document
        for part in path[1:].split("/"):
            if "~" in part.replace("~0", "").replace("~1", ""):
                raise MuseumError("invalid pointer escape")
            part = part.replace("~1", "/").replace("~0", "~")
            try:
                if isinstance(node, list):
                    if not part.isdigit() or (part.startswith("0") and part != "0"):
                        raise MuseumError("invalid array pointer")
                    node = node[int(part)]
                else:
                    node = node[part]
            except (KeyError, IndexError, TypeError) as exc:
                raise MuseumError("evidence pointer missing") from exc
        return node

    reviews = []
    for row in policy["reviewers"]:
        record, agent = admitted(row)
        review = pointer(loads(record.payload), row["pointer"])
        if review["reviewer"] != agent:
            raise MuseumError("forged reviewer identity")
        reviews.append(review)
    selected, withheld, unselected = [], [], []
    selected_rows = {(r["recordHash"], r["pointer"]): r for r in policy["sources"]}
    if len(selected_rows) != len(policy["sources"]):
        raise MuseumError("duplicate selected source")
    for row in selected_rows.values():
        record, agent = admitted(row)
        assertion = pointer(loads(record.payload), row["pointer"])
        if assertion["assertingAgent"] != agent:
            raise MuseumError("forged assertion author")
        origin, status = assertion["origin"], assertion["reviewStatus"]
        if origin not in ("direct_statement", "human_mapping", "automated_mapping", "derived_projection"):
            raise MuseumError("unknown assertion origin")
        canonical = dumps(assertion)
        eligible = status != "withdrawn" and origin == "direct_statement"
        if origin != "direct_statement" and status != "withdrawn":
            for review in reviews:
                if (review["assertionHash"] == keccak256(canonical)
                        and review["assertionSelector"] == row
                        and review["profileHash"] == profile_hash
                        and review["mappingRule"] == assertion["mappingRule"]
                        and review["disposition"] == "reviewed"):
                    is_self = review["reviewer"] == agent
                    if review["selfReview"] != is_self:
                        raise MuseumError("undisclosed self review")
                    if policy["independentReviewRequired"] and is_self:
                        continue
                    eligible = True
        (selected if eligible else unselected).append(canonical)

    # Sidecar-only disputes do not enter the selected key set and cannot veto.
    groups = {}
    for raw in selected:
        assertion = loads(raw)
        if assertion["relation"] in policy["singleValuedRelations"]:
            groups.setdefault((assertion["subject"], assertion["relation"]), []).append(raw)
    for group in groups.values():
        values = {dumps(loads(raw)["object"]) for raw in group}
        if len(values) > 1:
            withheld.extend(group)
    return Selection(tuple(sorted(set(selected) - set(withheld))),
                     tuple(sorted(withheld)), tuple(sorted(unselected)))

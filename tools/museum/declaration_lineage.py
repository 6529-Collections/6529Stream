"""Original, account-authenticated declaration edges; never implicit IRI identity."""
from .canonical import dumps, keccak256, loads
from .independent_wire import require
from .review import _selector
from .typed_declarations import declaration_evidence


def _predecessors(source, record, entity, payload):
    change = entity["lineage"]
    if change is None:
        require(not entity["predecessors"], "lineage evidence required for predecessor IDs")
        return []
    refs = change["predecessors"]
    require(len({dumps(ref["selector"]) for ref in refs}) == len(refs), "duplicate lineage predecessor selector")
    previous = []
    for ref in refs:
        selector = ref["selector"]
        require(selector in entity["sourceRecords"] and selector in payload["sourceRecords"],
            "lineage predecessor must be cited by entity and payload")
        prior = source._prior(record, selector)
        value, observed = source.entity(source.state, selector, source.profile_hash)
        require(observed is prior and keccak256(dumps(value)) == ref["declarationHash"], "lineage predecessor hash differs")
        require(value["declaringAgent"] == entity["declaringAgent"], "lineage changes authenticated declaring account")
        require(value["kind"] == entity["kind"], "lineage changes entity kind")
        previous.append(value)
    ids = [value["id"] for value in previous]
    require(len(set(ids)) == len(ids) and entity["predecessors"] == ids, "lineage predecessor IDs or order differ")
    operation = change["operation"]
    if operation == "correction":
        require(len(ids) == 1 and ids[0] == entity["id"] and not change["successors"],
            "correction must retain one predecessor identity")
    elif operation == "merge":
        require(len(ids) >= 2 and entity["id"] not in ids and not change["successors"],
            "merge requires distinct predecessor identities and a new identity")
    else:
        successors = change["successors"]
        require(len(ids) == 1 and 2 <= len(successors) <= 16 and successors == sorted(set(successors))
            and ids[0] not in successors and entity["id"] in successors,
            "split requires a complete unique new successor cohort")
        cohort = [value for value in payload["entities"] if value["id"] in successors]
        require(len(cohort) == len(successors) and {value["id"] for value in cohort} == set(successors),
            "split successor cohort missing or duplicated")
        require(all(value["lineage"] == change and value["predecessors"] == ids
            and value["kind"] == entity["kind"] and value["declaringAgent"] == entity["declaringAgent"] for value in cohort),
            "split successor lineage, kind or authority differs")
    return previous


def validate_lineage(source, record, payload):
    # Original publication ordering rejects cycles. Bound uncached admission too.
    depth = getattr(source, "_declaration_admission_depth", 0)
    require(depth <= 8, "declaration lineage exceeds eight links")
    source._declaration_admission_depth = depth + 1
    try:
        require(len({entity["id"] for entity in payload["entities"]}) == len(payload["entities"]),
            "duplicate declaration identity in lineage payload")
        for index, entity in enumerate(payload["entities"]):
            _predecessors(source, record, entity, payload)
            # A new ID cannot recycle any ancestor after a merge/split cycle.
            graph = declaration_graph(source, _selector(record, "/entities/" + str(index)),
                admitted=(entity, record))
            if entity["lineage"] is not None and entity["lineage"]["operation"] != "correction":
                require(all(node["value"]["id"] != entity["id"] for node in graph["nodes"][1:]),
                    "merge or split reuses an ancestor identity")
    finally:
        source._declaration_admission_depth = depth


def declaration_graph(source, selector, *, admitted=None):
    """Return exact selected declaration and ancestors, including old V2 links.

    Source admission authenticates each node. Edges do not transfer claims,
    dispositions, ownership or authority between the distinct identifiers.
    """
    nodes, edges, seen = [], [], {}

    def visit(row, depth, known=None):
        require(depth <= 8, "declaration lineage exceeds eight links")
        key = dumps(row)
        if key in seen and depth <= seen[key]:
            return
        first = key not in seen
        # Revisit a shared node reached by a longer branch: deduplication must
        # not hide a ninth link in a merge DAG after a shorter path was seen.
        seen[key] = depth
        value, record = known if known is not None else source.entity(source.state, row, source.profile_hash)
        if first:
            require(len(nodes) < 512, "declaration lineage node bound")
            evidence = declaration_evidence(value, row)
            evidence["authorityEvidenceHash"] = keccak256(record.authority_evidence)
            evidence["authority"] = loads(record.authority_evidence, canonical=True)
            nodes.append(evidence)
        change = value.get("lineage")
        continuation = value.get("continuation")
        refs = change["predecessors"] if change else ([continuation] if continuation else [])
        for ref in refs:
            prior = source._prior(record, ref["selector"])
            previous, observed = source.entity(source.state, ref["selector"], source.profile_hash)
            require(observed is prior and ref["declarationHash"] == keccak256(dumps(previous)), "lineage predecessor hash differs")
            if first:
                cohort = []
                if change and change["operation"] == "split":
                    payload = loads(record.payload, canonical=True)
                    cohort = [declaration_evidence(entity, _selector(record, "/entities/" + str(index)))
                        for index, entity in enumerate(payload["entities"]) if entity["id"] in change["successors"]]
                edges.append({"successor": row, "predecessor": ref["selector"], "declarationHash": ref["declarationHash"],
                    "operation": change["operation"] if change else "continuation",
                    "rationale": change["rationale"] if change else continuation["rationale"],
                    "successorCohort": change["successors"] if change else [], "successorDeclarations": cohort})
            visit(ref["selector"], depth + 1, (previous, prior))

    visit(selector, 0, admitted)
    return {"selected": selector, "nodes": nodes, "edges": edges}

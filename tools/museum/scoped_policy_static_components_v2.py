"""Scoped policy V2 STATIC originals using the unchanged native six-family hash algorithm."""
from . import policy_static_components_v2 as base
from .canonical import keccak256
from .chain_abi import encode
from .native_finality_wire import from_json
from .independent_wire import ZERO, json_values, require
from .policy_static_components_v2 import (
    MAX_ROWS, MAX_GETTER_SOURCE_BYTES, MAX_UNIQUE_SOURCE_BYTES,
    AUTHENTICATED_SELECTION, SELECTION_PLAN, SELECTION_ROW, ARTIST_PRESENTATION,
    FAMILIES, METADATA_ROUTER, CONFIG_RECORD, RAW_SOURCE, METADATA_CONFIG,
    DOMAIN, ROW_DOMAIN, FOLD_DOMAIN, SELECTION_CHAIN_DOMAIN,
)

_closed, _context = base._closed, base._context
_originals, _row_original = base._originals, base._row_original
_selection_row_hash, _expectations = base._selection_row_hash, base._expectations
_field_hash = base._field_hash


def validate(value):
    """Validate complete retained STATIC originals and reproduce six data hashes."""
    _closed(value, ("context", "authenticated", "plan", "rows", "originals", "artistPresentation",
                    "componentExpectations"), "static evidence")
    context = value["context"]
    chain = _context(context)
    authenticated = from_json(AUTHENTICATED_SELECTION, value["authenticated"])
    scope = authenticated[0]
    require(scope[1] > 0 and ((scope[0] == 1 and scope[2] > 0 and scope[3] == ZERO)
            or (scope[0] in (2, 3) and scope[2] == 0 and scope[3] != ZERO)), "static scoped policy V2 scope")
    require(all(authenticated[i] != ZERO for i in (1, 2, 3, 4, 6))
            and 0 < authenticated[5] <= MAX_ROWS, "static authenticated selection")
    plan = from_json(SELECTION_PLAN, value["plan"])
    require(plan[0] == scope and plan[1] == authenticated[3] and plan[2] != ZERO
            and plan[3] == authenticated[5] and plan[4] == plan[3]
            and plan[5] == authenticated[4], "static stored selection plan")
    require(type(value["rows"]) is list and len(value["rows"]) == authenticated[5],
            "static complete selection rows")
    rows = tuple(from_json(SELECTION_ROW, row) for row in value["rows"])
    require(scope[0] != 1 or (len(rows) == 1 and rows[0][0] == scope[2]), "static TOKEN selection")
    originals, total = _originals(value["originals"], rows, chain, context, scope)
    selected_root = ZERO
    for index, row in enumerate(rows):
        _row_original(row, originals[row[1]], chain, context, scope)
        selected = _selection_row_hash(chain, context["core"], context["router"], row)
        selected_root = keccak256(encode(("bytes32", "bytes32", "uint256", "bytes32"),
                                         (SELECTION_CHAIN_DOMAIN, selected_root, index, selected)))
    require(selected_root == authenticated[4], "static retained selection root")
    expectations = _expectations(value["componentExpectations"])
    adapters = {row["family"]: row for row in context["adapters"]}
    for family in FAMILIES:
        row = expectations[family]
        adapter = adapters[family]
        require(row[1] == adapter["address"] and row[2] != "0x00000000"
                and row[3:6] == (adapter["runtimeHash"], context["routerModuleVersion"],
                                 context["routerModuleManifestHash"]),
                "static component source/module identity")
    identity_base = (chain, context["core"], context["metadata"], context["router"],
                     context["selection"], context["selectionCodeHash"], authenticated)
    output = []
    artist = None
    for family in FAMILIES:
        identity = keccak256(encode(("bytes32", "bytes32", "uint256", "address", "address", "address",
                                     "address", "bytes32", AUTHENTICATED_SELECTION),
                                    (DOMAIN, family, *identity_base)))
        folded = ZERO
        for index, row in enumerate(rows):
            record, source, _ = originals[row[1]]
            component_row = keccak256(encode(("bytes32", "bytes32", "bytes32", "uint256", "uint256",
                                              "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"),
                                             (ROW_DOMAIN, identity, family, index, row[0], row[1], row[2],
                                              row[3], row[4], _field_hash(family, row, record, source))))
            folded = keccak256(encode(("bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint256", "bytes32"),
                                      (FOLD_DOMAIN, identity, family, folded, index, row[0], component_row)))
        if family == METADATA_ROUTER:
            require(value["artistPresentation"] is not None, "static Artist presentation missing")
            artist = from_json(ARTIST_PRESENTATION, value["artistPresentation"])
            require(artist[0] and artist[11] != ZERO and artist[11] == authenticated[6],
                    "static locked Artist presentation")
            folded = keccak256(encode(("bytes32", "bytes32", "bytes32", "bytes32", ARTIST_PRESENTATION),
                                      (FOLD_DOMAIN, identity, family, folded, artist)))
        digest = keccak256(encode(("bytes32", "bytes32", "bytes32", "uint64", "bytes32"),
                                  (DOMAIN, identity, family, authenticated[5], folded)))
        require(expectations[family][6] == digest, "static component expectation data hash")
        output.append({"family": family, "dataHash": digest, "expectationMatched": True})
    return {"selectionId": authenticated[2], "selectionRoot": selected_root,
            "tokenCount": str(authenticated[5]), "uniqueConfigRecords": str(len(originals)),
            "uniqueSourceBytes": str(total), "families": output,
            "artistPresentationJoined": artist is not None,
            "historicalSourceMode": "immutable_frozen_source_snapshot",
            "currentSelectionRevalidated": False, "currentSourceRevalidated": False,
            "qualification": "Exact stored plan, complete selection rows and immutable frozen Router source originals reproduce six supplied component data hashes; current checkpoint and current Router selection are not consulted."}


def json_report(value):
    """Return the JSON-safe validation report used by capture adapters."""
    return json_values(validate(value))


class ScopedPolicyStaticReads:
    """Read complete historical checkpoint rows and immutable frozen originals.

    The parent supplies ``a``, ``graph`` and the ordinary ``_one``/``_read``
    recording helpers.  The locked Artist presentation comes from the already
    verified original policy snapshot, never a present-day Router getter.
    """

    def _static_components(self, snapshot_result, content_result, statement):
        from .policy_content_types_v2 import CONTENT_PLAN
        from .native_scoped_finality_wire import STATEMENT

        statement = from_json(STATEMENT, statement)
        require(type(snapshot_result) is dict and type(snapshot_result.get("source")) in (list, tuple)
                and len(snapshot_result["source"]) == 10
                and type(snapshot_result.get("receipt")) in (list, tuple)
                and len(snapshot_result["receipt"]) == 17, "static verified snapshot result")
        require(type(content_result) is dict and all(key in content_result for key in
                ("contentPlan", "selectionPlan", "selectionRows")), "static verified content result")
        source = snapshot_result["source"]
        artist = from_json(ARTIST_PRESENTATION, source[2])
        source_plan = from_json(SELECTION_PLAN, source[3])
        result_plan = from_json(SELECTION_PLAN, content_result["selectionPlan"])
        content_plan = from_json(CONTENT_PLAN, content_result["contentPlan"])
        rows = tuple(from_json(SELECTION_ROW, row) for row in content_result["selectionRows"])
        require(source_plan == result_plan and source_plan[0] == statement[0]
                and content_plan[0] != ZERO and 0 < source_plan[3] <= MAX_ROWS
                and len(rows) == source_plan[3],
                "static verified snapshot/content selection join")

        selection = self.graph["staticSelection"]["address"]
        router = self.graph["router"]["address"]
        provider = self.graph["provider"]["address"]
        stored = self._one(selection, "checkpoint(bytes32)", SELECTION_PLAN,
                           ("bytes32",), (content_plan[0],))
        require(stored == source_plan, "static stored checkpoint plan differs")
        retained_rows = [self._one(selection, "selectionAt(bytes32,uint256)", SELECTION_ROW,
                                   ("bytes32", "uint256"), (content_plan[0], index))
                         for index in range(source_plan[3])]
        require(tuple(retained_rows) == rows, "static stored selection rows differ")
        originals = []
        total = 0
        for key in dict.fromkeys(row[1] for row in rows):
            record = self._one(router, "metadataConfigRecord(bytes32)", CONFIG_RECORD,
                               ("bytes32",), (key,), maximum=8192)
            raw_source, selected = self._read(router,
                "staticRenderSourceForConfig(uint256,bytes32)", (RAW_SOURCE, METADATA_CONFIG),
                ("uint256", "bytes32"), (source_plan[0][1], key), maximum=MAX_GETTER_SOURCE_BYTES)
            total += len(encode((RAW_SOURCE, METADATA_CONFIG), (raw_source, selected)))
            require(total <= MAX_UNIQUE_SOURCE_BYTES, "static unique source byte bound")
            originals.append({"configRecordHash": key, "configRecord": json_values(record),
                              "rawSource": json_values(raw_source), "selectedConfig": json_values(selected)})
        module_version = self._one(provider, "routerModuleVersion()", "bytes32")
        module_manifest = self._one(provider, "routerModuleManifestHash()", "bytes32")
        require(type(getattr(self, "provider_evidence", None)) is dict
                and type(self.provider_evidence.get("adapters")) is list,
                "static original adapter evidence missing")
        adapters = []
        by_family = {row.get("family"): row for row in self.provider_evidence["adapters"]
                     if type(row) is dict}
        for family in FAMILIES:
            require(family in by_family, "static original adapter family missing")
            row = by_family[family]
            adapters.append({"family": family, "address": row.get("address"),
                             "runtimeHash": row.get("runtimeHash")})
        value = {"context": {"chainId": self.a["chainId"], "core": self.graph["core"]["address"],
                    "metadata": self.graph["metadata"]["address"], "router": router,
                    "routerCodeHash": self.graph["router"]["runtimeHash"], "selection": selection,
                    "selectionCodeHash": self.graph["staticSelection"]["runtimeHash"],
                    "routerModuleVersion": module_version, "routerModuleManifestHash": module_manifest,
                    "adapters": adapters},
                 "authenticated": json_values((source_plan[0], snapshot_result["receipt"][15], content_plan[0],
                    source_plan[1], source_plan[5], source_plan[3], artist[11])),
                 "plan": json_values(stored), "rows": json_values(rows), "originals": originals,
                 "artistPresentation": json_values(artist),
                 "componentExpectations": json_values(statement[8])}
        validate(value)
        return value

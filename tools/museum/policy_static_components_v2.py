"""Historical STATIC component preimages for COLLECTION policy V2.

This is a pure verifier for an already retained selection checkpoint.  It does
not call ``requireCurrentCheckpoint`` or reinterpret today's Router state as
the original source.  A selected config must carry the nonzero frozen source
snapshot required by the immutable checkpoint writer; the Router's live
fallback branch is deliberately unsupported.
"""

from .canonical import hex_bytes, keccak256, schema_id, uint
from .chain_abi import encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .native_finality_wire import COMPONENT, INDEPENDENT_FAMILIES, from_json
from .scoped_static_types import ARTIST_PRESENTATION, SCOPE, SELECTION_PLAN, SELECTION_ROW, STATIC_SELECTION

SOURCE_REVISION = "896899f7ca4130f86e066587f780a3b1f755a25d"
MAX_ROWS = 818
MAX_GETTER_SOURCE_BYTES = 24000
MAX_UNIQUE_SOURCE_BYTES = 8 * 1024 * 1024

METADATA_CONFIG = ("uint8", "address", "string", "string", "uint8", "bool")
MANIFEST_SELECTION = ("address", "bytes32", "bytes32")
RAW_SOURCE = ("uint256", "bool", "string", "string", "string", "string", "string",
              MANIFEST_SELECTION, MANIFEST_SELECTION)
CONFIG_RECORD = ("bytes32", "bytes32", "uint256", "uint256", "uint64", "uint64", "uint8",
                 "bytes32", STATIC_SELECTION, METADATA_CONFIG)
AUTHENTICATED_SELECTION = (SCOPE, "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "bytes32")

FAMILY_NAMES = ("METADATA_ROUTER", "RENDERER", "RENDER_CONTEXT", "MEDIA_MANIFEST",
                "SCRIPT_SOURCE", "DEPENDENCY_SOURCE")
FAMILIES = tuple(schema_id(name) for name in FAMILY_NAMES)
METADATA_ROUTER, RENDERER, RENDER_CONTEXT, MEDIA_MANIFEST, SCRIPT_SOURCE, DEPENDENCY_SOURCE = FAMILIES

DOMAIN = schema_id("6529STREAM_AUTHENTICATED_STATIC_COMPONENT_V1")
ROW_DOMAIN = schema_id("6529STREAM_AUTHENTICATED_STATIC_COMPONENT_ROW_V1")
FOLD_DOMAIN = schema_id("6529STREAM_AUTHENTICATED_STATIC_COMPONENT_FOLD_V1")
SELECTION_ROW_DOMAIN = schema_id("6529STREAM_STATIC_SELECTION_ROW_V1")
SELECTION_CHAIN_DOMAIN = schema_id("6529STREAM_STATIC_SELECTION_CHAIN_V1")
CONFIG_RECORD_DOMAIN = schema_id("6529STREAM_STATIC_METADATA_CONFIG_RECORD_V1")
SOURCE_SNAPSHOT_DOMAIN = schema_id("6529STREAM_STATIC_SOURCE_SNAPSHOT_V1")


def _closed(value, keys, label):
    require(type(value) is dict and set(value) == set(keys), label + " shape")


def _number(value, bits=256):
    if type(value) is str:
        return uint(value, bits)
    require(type(value) is int and 0 <= value < 1 << bits, "static unsigned integer")
    return value


def _nonzero_address(value, label):
    require(value != ZERO_ADDRESS and any(hex_bytes(value, 20)), label)


def _context(value):
    _closed(value, ("chainId", "core", "metadata", "router", "routerCodeHash", "selection",
                    "selectionCodeHash", "routerModuleVersion", "routerModuleManifestHash", "adapters"),
            "static context")
    chain = _number(value["chainId"])
    require(chain > 0, "static chain identity")
    for key in ("core", "metadata", "router", "selection"):
        _nonzero_address(value[key], "static empty source address")
    require(all(value[key] != ZERO and any(hex_bytes(value[key], 32)) for key in
                ("routerCodeHash", "selectionCodeHash", "routerModuleVersion", "routerModuleManifestHash")),
            "static source identity hash")
    require(type(value["adapters"]) is list and len(value["adapters"]) == len(FAMILIES),
            "static adapter denominator")
    adapters = {}
    for row in value["adapters"]:
        _closed(row, ("family", "address", "runtimeHash"), "static adapter")
        family = row["family"]
        require(family in FAMILIES and family not in adapters, "static adapter family")
        _nonzero_address(row["address"], "static adapter address")
        require(row["runtimeHash"] != ZERO and any(hex_bytes(row["runtimeHash"], 32)),
                "static adapter runtime")
        adapters[family] = row
    require(set(adapters) == set(FAMILIES), "static adapter family denominator")
    return chain


def _selection_row_hash(chain, core, router, row):
    return keccak256(encode(("bytes32", "uint256", "address", "address", SELECTION_ROW),
                            (SELECTION_ROW_DOMAIN, chain, core, router, row)))


def _record_hash(core, router, record):
    mutable = list(record)
    mutable[0] = ZERO
    return keccak256(encode(("bytes32", "address", "address", CONFIG_RECORD),
                            (CONFIG_RECORD_DOMAIN, core, router, tuple(mutable))))


def _source_snapshot_hash(source):
    return keccak256(encode(("bytes32", RAW_SOURCE), (SOURCE_SNAPSHOT_DOMAIN, source)))


def _field_hash(family, row, record, source):
    selected = row[5]
    config = record[9]
    if family == RENDERER:
        return keccak256(encode(("address", "bytes32", "bytes32", "address", "bytes32", "bytes32",
                                "bytes32", "bytes32"),
                               (selected[0], selected[1], selected[2], selected[3], selected[4],
                                selected[5], selected[6], selected[10])))
    if family == RENDER_CONTEXT:
        return keccak256(encode(("bytes32", "bytes32", METADATA_CONFIG),
                               (selected[7], selected[8], config)))
    if family == DEPENDENCY_SOURCE:
        return keccak256(encode(("address", "bytes32", "bytes32", "bytes32", "bytes32",
                                ("address",) * 6, ("bytes32",) * 6, MANIFEST_SELECTION),
                               (selected[0], selected[1], selected[2], selected[9], selected[10],
                                row[6], row[7], source[7])))
    if family == SCRIPT_SOURCE:
        return keccak256(encode(("bytes32", MANIFEST_SELECTION),
                               (keccak256(source[6].encode("utf-8")), source[7])))
    if family == MEDIA_MANIFEST:
        return keccak256(encode(("bytes32", "bytes32", MANIFEST_SELECTION, "bytes32", "bytes32", "uint8"),
                               (keccak256(source[4].encode("utf-8")),
                                keccak256(source[5].encode("utf-8")), source[8],
                                keccak256(config[2].encode("utf-8")),
                                keccak256(config[3].encode("utf-8")), config[4])))
    require(family == METADATA_ROUTER, "static unsupported component family")
    return keccak256(encode(("bytes32", "bytes32", "bool", "uint8"),
                           (keccak256(source[2].encode("utf-8")),
                            keccak256(source[3].encode("utf-8")), source[1], config[0])))


def _originals(value, rows, chain, context, scope):
    require(type(value) is list, "static originals list")
    by_hash = {}
    total = 0
    for item in value:
        _closed(item, ("configRecordHash", "configRecord", "rawSource", "selectedConfig"),
                "static original")
        key = item["configRecordHash"]
        require(key not in by_hash and key != ZERO, "static duplicate/empty original")
        record = from_json(CONFIG_RECORD, item["configRecord"])
        source = from_json(RAW_SOURCE, item["rawSource"])
        selected_config = from_json(METADATA_CONFIG, item["selectedConfig"])
        require(record[0] == key and _record_hash(context["core"], context["router"], record) == key,
                "static config record hash")
        require(record[2] == scope[1] and record[6] > 0 and record[7] != ZERO
                and record[9][0] == 1 and record[9][5],
                "static frozen ONCHAIN config")
        require(record[9] == selected_config and source[0] == chain and source[1],
                "static original source/config")
        encoded = encode((RAW_SOURCE, METADATA_CONFIG), (source, selected_config))
        require(len(encoded) <= MAX_GETTER_SOURCE_BYTES, "static original getter byte bound")
        total += len(encoded)
        require(total <= MAX_UNIQUE_SOURCE_BYTES, "static unique source byte bound")
        by_hash[key] = (record, source, len(encoded))
    required = {row[1] for row in rows}
    require(set(by_hash) == required, "static original denominator")
    return by_hash, total


def _row_original(row, original, chain, context, scope):
    record, source, _ = original
    require(row[0] > 0 and row[1] == record[0]
            and row[2] == keccak256(encode((CONFIG_RECORD,), (record,)))
            and row[3] != ZERO and row[3] == record[7] and row[3] == _source_snapshot_hash(source)
            and row[4] == keccak256(encode((RAW_SOURCE,), (source,))),
            "static original row hashes")
    require(record[2] == scope[1] and record[3] in (0, row[0]) and record[8] == row[5]
            and record[9][1] == row[5][3], "static row/config correspondence")
    require(row[6][0:3] == (context["core"], context["router"], context["metadata"]),
            "static original source bindings")
    for index, (address, code_hash) in enumerate(zip(row[6], row[7])):
        require((address == ZERO_ADDRESS) == (code_hash == ZERO), "static source pin pairing")
        if index < 4:
            require(address != ZERO_ADDRESS and code_hash != ZERO, "static required source pin")
    selected = row[5]
    require(selected[0] != ZERO_ADDRESS and selected[1] != ZERO and selected[2] != ZERO
            and selected[3] != ZERO_ADDRESS and selected[4] != ZERO
            and all(selected[i] != ZERO for i in range(5, 11)), "static retained selection identity")


def _expectations(value):
    require(type(value) is list and len(value) in (6, 9), "static component expectation count")
    result = {}
    for raw in value:
        row = from_json(COMPONENT, raw)
        require(row[0] not in result, "static duplicate component expectation")
        result[row[0]] = row
    required = set(FAMILIES) if len(value) == 6 else set(INDEPENDENT_FAMILIES)
    require(set(result) == required, "static component expectation denominator")
    return result


def validate(value):
    """Validate complete retained STATIC originals and reproduce six data hashes."""
    _closed(value, ("context", "authenticated", "plan", "rows", "originals", "artistPresentation",
                    "componentExpectations"), "static evidence")
    context = value["context"]
    chain = _context(context)
    authenticated = from_json(AUTHENTICATED_SELECTION, value["authenticated"])
    scope = authenticated[0]
    require(scope[0] == 0 and scope[1] > 0 and scope[2] == 0 and scope[3] == ZERO,
            "static COLLECTION scope")
    require(all(authenticated[i] != ZERO for i in (1, 2, 3, 4, 6))
            and 0 < authenticated[5] <= MAX_ROWS, "static authenticated selection")
    plan = from_json(SELECTION_PLAN, value["plan"])
    require(plan[0] == scope and plan[1] == authenticated[3] and plan[2] != ZERO
            and plan[3] == authenticated[5] and plan[4] == plan[3]
            and plan[5] == authenticated[4], "static stored selection plan")
    require(type(value["rows"]) is list and len(value["rows"]) == authenticated[5],
            "static complete selection rows")
    rows = tuple(from_json(SELECTION_ROW, row) for row in value["rows"])
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


class PolicyStaticReads:
    """Read complete historical checkpoint rows and immutable frozen originals.

    The parent supplies ``a``, ``graph`` and the ordinary ``_one``/``_read``
    recording helpers.  The locked Artist presentation comes from the already
    verified original policy snapshot, never a present-day Router getter.
    """

    def _static_components(self, snapshot_result, content_result, statement):
        from .policy_content_types_v2 import CONTENT_PLAN, STATEMENT

        statement = from_json(STATEMENT, statement)
        require(type(snapshot_result) is dict and type(snapshot_result.get("source")) in (list, tuple)
                and len(snapshot_result["source"]) == 9
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

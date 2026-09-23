"""Install synthetic original membership and STATIC getter observations.

The caller owns the coherent bundle and its original event/receipt map.  This
helper adds only the getters and immutable carriers consumed by the actual
source read mixins; it does not synthesize current eligibility or edit events.
"""
from .canonical import hex_bytes, keccak256, schema_id
from .chain_abi import calldata, decode
from .independent_wire import require
from .native_finality_wire import from_json
from .scoped_static_snapshot_wire import METADATA_RECORD
from .scoped_static_types import (
    SCOPE, MEMBERSHIP_PUBLICATION, MEMBERSHIP_PROGRESS, METADATA_RECEIPT,
    SELECTION_PLAN, SELECTION_ROW,
)
from .scoped_policy_static_components_v2 import CONFIG_RECORD, RAW_SOURCE, METADATA_CONFIG


def install_membership_static_reads(fixture, bundle, context, graph):
    """Install exact responses using ``fixture.add`` and the retained bundle."""
    addresses = {role: row["address"] for role, row in graph.items()}

    def put(role, signature, outputs, values, inputs=(), arguments=()):
        fixture.add(addresses[role], signature, inputs, arguments, outputs, values)

    def carrier(pointer, raw, expected_hash):
        runtime = b"\0" + raw
        require(keccak256(runtime) == expected_hash,
                "scoped fixture retained membership carrier hash")
        require(pointer not in fixture.codes or fixture.codes[pointer] == runtime,
                "scoped fixture membership carrier address collision")
        fixture.codes[pointer] = runtime
        fixture.pins[pointer] = expected_hash
        digest = keccak256(raw)
        key = (addresses["store"], calldata("chunk(bytes32)", ("bytes32",), (digest,)))
        if key in fixture.responses:
            require(decode(("address", "uint32"), hex_bytes(fixture.responses[key]))
                    == (pointer, len(raw)), "scoped fixture immutable Store chunk collision")
        put("store", "chunk(bytes32)", ("address", "uint32"), (pointer, len(raw)),
            ("bytes32",), (digest,))

    scope = from_json(SCOPE, bundle["scope"])
    require(scope[1] == int(context["collectionId"]), "scoped fixture collection identity")
    member = bundle["membership"]
    suffix = "((uint8,uint256,uint256,bytes32))"
    if scope[0] != 1:
        publication = from_json(MEMBERSHIP_PUBLICATION, member["publication"])
        progress = from_json(MEMBERSHIP_PROGRESS, member["progress"])
        record = from_json(METADATA_RECORD, member["metadataRecord"])
        receipt = publication[7]
        put("scopeMembership", "scopeMembershipPublication" + suffix,
            (MEMBERSHIP_PUBLICATION,), (publication,), (SCOPE,), (scope,))
        put("scopeMembership", "scopeMembershipProgress" + suffix,
            (MEMBERSHIP_PROGRESS,), (progress,), (SCOPE,), (scope,))
        put("metadata", "collectionRecord(bytes32)", (METADATA_RECORD, METADATA_RECEIPT),
            (record, receipt), ("bytes32",), (publication[0],))
        put("metadata", "recordHashAt(uint256,bytes32,uint256)", ("bytes32",),
            (publication[0],), ("uint256", "bytes32", "uint256"),
            (scope[1], schema_id("SCOPE_MEMBERSHIP"), receipt[4]))
        raw = hex_bytes(member["manifestBytes"])
        put("metadata", "recordPayload(bytes32)", ("address", "bytes"),
            (publication[4], raw), ("bytes32",), (publication[0],))
        carrier(publication[4], raw, publication[5])
        for part in member["parts"]:
            runtime = hex_bytes(part["runtime"])
            require(runtime[:1] == b"\0", "scoped fixture membership STOP carrier")
            carrier(part["pointer"], runtime[1:], part["codeHash"])

    for index, token in enumerate(member["tokens"]):
        token = from_json("uint256", token)
        identity = from_json(("bool", "uint256", "uint256", "bool"), member["identities"][index])
        lifecycle = from_json("uint8", member["lifecycles"][index])
        put("scopeMembership", "scopeTokenAt((uint8,uint256,uint256,bytes32),uint256)",
            ("uint256",), (token,), (SCOPE, "uint256"), (scope, index))
        put("core", "tokenCollectionIdentity(uint256)",
            ("bool", "uint256", "uint256", "bool"), identity, ("uint256",), (token,))
        put("core", "tokenLifecycle(uint256)", ("uint8",), (lifecycle,), ("uint256",), (token,))
        if scope[0] != 1:
            inventory_token = from_json("uint256", member["inventoryTokens"][index])
            put("tokenInventory", "collectionTokenBySerial(uint256,uint256)",
                ("uint256",), (inventory_token,), ("uint256", "uint256"), (scope[1], identity[2]))

    checkpoint = bundle["content"]["checkpoint"]
    selection_id = checkpoint["plan"][0]
    plan = from_json(SELECTION_PLAN, checkpoint["selectionPlan"])
    put("staticSelection", "checkpoint(bytes32)", (SELECTION_PLAN,), (plan,),
        ("bytes32",), (selection_id,))
    for index, row in enumerate(checkpoint["selectionRows"]):
        put("staticSelection", "selectionAt(bytes32,uint256)", (SELECTION_ROW,),
            (from_json(SELECTION_ROW, row),), ("bytes32", "uint256"), (selection_id, index))
    for original in bundle["staticComponents"]["originals"]:
        key = original["configRecordHash"]
        put("router", "metadataConfigRecord(bytes32)", (CONFIG_RECORD,),
            (from_json(CONFIG_RECORD, original["configRecord"]),), ("bytes32",), (key,))
        put("router", "staticRenderSourceForConfig(uint256,bytes32)", (RAW_SOURCE, METADATA_CONFIG),
            (from_json(RAW_SOURCE, original["rawSource"]),
             from_json(METADATA_CONFIG, original["selectedConfig"])),
            ("uint256", "bytes32"), (scope[1], key))
    for role, module in bundle["provider"]["moduleIdentities"].items():
        put("provider", role + "ModuleVersion()", ("bytes32",), (module[0],))
        put("provider", role + "ModuleManifestHash()", ("bytes32",), (module[1],))

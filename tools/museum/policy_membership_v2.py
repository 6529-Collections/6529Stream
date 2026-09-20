"""Historical complete COLLECTION prefix with separately observed current burns."""
from . import native_finality_wire as base
from .canonical import schema_id, subject_id, uint
from .chain_abi import encode
from .independent_wire import ZERO, json_values, require
from .scoped_static_types import MEMBERSHIP_FACTS
from .scoped_static_snapshot_wire import membership_hash

IDENTITY = ("bool", "uint256", "uint256", "bool")
EVENT = schema_id("CollectionTokenIndexed(uint256,uint256,uint256,bytes32)")


def validate(value, context, graph, original_facts, token_ids):
    base._closed(value, ("facts", "inventoryState", "tokens", "identities", "lifecycles", "serialTokens"), "policy membership prefix")
    f = base._v(MEMBERSHIP_FACTS, value["facts"])
    cid, chain = uint(context["collectionId"]), uint(context["chainId"])
    scope = (0, cid, 0, ZERO)
    require(f == base._v(MEMBERSHIP_FACTS, original_facts)
        and f[0] == subject_id("collection", str(chain), graph["core"]["address"], str(cid))
        and f[1:3] == (ZERO, ZERO) and f[4] == ZERO
        and 0 < f[3] == f[6] <= 818 and f[5] == membership_hash(f, scope, context, graph), "policy original membership facts")
    for key in ("tokens", "identities", "lifecycles", "serialTokens"):
        require(type(value[key]) is list and len(value[key]) == f[3], "policy complete membership denominator")
    tokens = tuple(base.from_json("uint256", v) for v in value["tokens"])
    require(tokens == tuple(base.from_json("uint256", v) for v in token_ids), "policy membership/selection order")
    prefix = base._hash("6529STREAM_TOKEN_INVENTORY_V1", ("uint256", "address", "address", "uint256"),
        (chain, graph["tokenInventory"]["address"], graph["core"]["address"], cid))
    last_token, last_serial, prefixes = 0, 0, []
    for i, token in enumerate(tokens):
        identity = base._v(IDENTITY, value["identities"][i])
        lifecycle = base.from_json("uint8", value["lifecycles"][i])
        require(identity[0] and identity[1] == cid and token > last_token and identity[2] > last_serial
            and (lifecycle, identity[3]) in ((2, False), (3, True))
            and base.from_json("uint256", value["serialTokens"][i]) == token, "policy immutable token/serial/current lifecycle")
        prefix = base._hash("6529STREAM_TOKEN_INVENTORY_APPEND_V1", ("bytes32", "uint256", "uint256"),
            (prefix, identity[2], token))
        prefixes.append(prefix); last_token, last_serial = token, identity[2]
    require(prefix == f[7], "policy original complete inventory prefix")
    current = base._v(("uint256", "bytes32"), value["inventoryState"])
    require(current[0] >= f[3] and current[1] != ZERO and (current[0] != f[3] or current[1] == prefix),
        "policy current inventory observation")
    require(uint(context["tokenId"]) in tokens, "policy target outside original collection")
    return {"tokenIds": [str(t) for t in tokens], "prefixHashes": prefixes,
        "originalCount": str(f[3]), "originalPrefixHash": prefix, "currentCompletenessVerified": False}


def expected_events(value, context, graph):
    result = validate(value, context, graph, value["facts"], value["tokens"])
    return tuple({"kind": "inventory_indexed", "address": graph["tokenInventory"]["address"],
        "topics": (EVENT, base._topic("uint256", uint(context["collectionId"])), base._topic("uint256", uint(token))),
        "data": "0x" + encode(("uint256", "bytes32"),
            (base.from_json("uint256", value["identities"][i][2]), result["prefixHashes"][i])).hex()}
        for i, token in enumerate(result["tokenIds"]))


class PolicyMembershipReads:
    def _membership(self, facts, token_ids):
        f = base._v(MEMBERSHIP_FACTS, facts)
        cid, host = uint(self.a["collectionId"]), self.a["tokenInventory"]
        require(0 < f[3] <= 818, "policy original membership read bound")
        result = {"facts": facts, "inventoryState": self._read(host, "collectionInventoryState(uint256)",
            ("uint256", "bytes32"), ("uint256",), (cid,)), "tokens": [], "identities": [], "lifecycles": [], "serialTokens": []}
        for i in range(f[3]):
            token = self._one(host, "collectionTokenAt(uint256,uint256)", "uint256", ("uint256", "uint256"), (cid, i))
            identity = self._read(self.a["core"], "tokenCollectionIdentity(uint256)", IDENTITY, ("uint256",), (token,))
            result["tokens"].append(token); result["identities"].append(identity)
            result["lifecycles"].append(self._one(self.a["core"], "tokenLifecycle(uint256)", "uint8", ("uint256",), (token,)))
            result["serialTokens"].append(self._one(host, "collectionTokenBySerial(uint256,uint256)", "uint256",
                ("uint256", "uint256"), (cid, identity[2])))
        result = {k: json_values(v) for k,v in result.items()}
        validate(result, self.a, self.graph, facts, token_ids)
        return result

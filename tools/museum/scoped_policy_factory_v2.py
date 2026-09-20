"""Exact original scoped policy V2 publication-factory graph evidence.

This module models StreamScopedPolicyPublicationFactoryV2 at native source
e0b4d17b.  It deliberately excludes the separately named current-authority
factory.  Stored ``graphForPlan`` evidence is historical; ``requireCurrentGraph``
is an operative eligibility gate and is never used to rewrite that history.
"""
from . import native_finality_wire as base
from . import native_policy_finality_wire_v2 as collection
from .canonical import hex_bytes, keccak256, schema_id, uint
from .chain_abi import decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .policy_preservation_types_v2 import POLICY_DEPS
from .scoped_static_types import SCOPE, SNAPSHOT_DEPS

SOURCE_REVISION = "e0b4d17bc548f778a379773234caee545658bcdc"
PROFILE = schema_id("6529STREAM_SCOPED_POLICY_PUBLICATION_FACTORY_V2")
GRAPH_DOMAIN = schema_id("6529STREAM_SCOPED_POLICY_PUBLICATION_GRAPH_V2")
SOURCE_FACTORY_PROFILE = schema_id("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
CURRENT_AUTHORITY_PROFILE = schema_id("6529STREAM_CURRENT_AUTHORITY_SCOPED_POLICY_PUBLICATION_FACTORY_V2")
CHILD_EVENT = schema_id("ScopedPolicyPublicationChildPrepared(uint16,bytes32,bytes32,uint8,address,bytes32)")

GAS_CONFIG = ("string", "uint256", "uint256", "uint8")
RECIPE = (collection.INVENTORY_DEPENDENCIES, ("address",) * 4, ("bytes32",) * 4,
    "uint32", "uint32", "uint256", "uint256", "uint256", (GAS_CONFIG,) * 2,
    GAS_CONFIG, (GAS_CONFIG,) * 3, (GAS_CONFIG,) * 4)
GRAPH = (SCOPE, "bytes32", "address", "bytes32", "bytes32", ("address",) * 7,
    ("bytes32",) * 7, "uint8")
REFERENCE_DEPS = (("address",) * 7, ("bytes32",) * 7, "uint256", "uint256",
    "uint256", "uint256", "uint256")
BUNDLE_DEPS = (("address",) * 6, ("bytes32",) * 6, "uint256", "uint256", "uint256")
CHILDREN = ("terminalReadiness", "policyContent", "outputManifest", "policySnapshot",
    "policyReference", "renderCriticalInventory", "bundleCoverage")


def _v(kind, value):
    return base.from_json(kind, value)


def _number(value):
    if type(value) is int:
        require(0 <= value < 2**256, "scoped factory unsigned integer")
        return value
    return uint(value)


def _scope(value):
    value = _v(SCOPE, value); kind, cid, token, key = value
    require(cid > 0 and ((kind == 1 and token > 0 and key == ZERO)
        or (kind in (2, 3) and token == 0 and key != ZERO)), "scoped factory scope")
    return value


def _gas(value, name, failure):
    value = _v(GAS_CONFIG, value)
    require(value[0] == name and value[1] >= value[2] >= 1 and value[1] >= 50000
        and value[1] <= 2**32 - 1 and value[3] == failure, "scoped factory gas configuration")
    return value


def validate_recipe(value, chain_id):
    r = _v(RECIPE, value); d = r[0]; chain = _number(chain_id)
    require(d[6] == chain and d[7] >= 50000 and d[8] >= d[7]
        and d[9] >= d[7] and d[10] >= d[7] and d[11] >= d[7], "scoped factory inventory recipe")
    for i, (address, digest) in enumerate(zip(d[0], d[1])):
        require((address, digest) == (ZERO_ADDRESS, ZERO) if i in (5, 6)
            else address != ZERO_ADDRESS and digest != ZERO, "scoped factory original inventory role")
    require(all(a != ZERO_ADDRESS and h != ZERO for a, h in zip(d[2], d[3]))
        and d[4] != ZERO_ADDRESS and d[5] != ZERO, "scoped factory original Artist recipe")
    require(all(a != ZERO_ADDRESS and h != ZERO for a, h in zip(r[1], r[2]))
        and r[3] >= 50000 and r[4] >= r[3] and r[5] >= d[7]
        and r[6] >= 50000 and r[7] >= r[6], "scoped factory fixed recipe")
    _gas(r[8][0], "STATIC_CONTENT_READ_GAS", 2); _gas(r[8][1], "STATIC_CONTENT_RENDER_GAS", 2)
    _gas(r[9], "STATIC_OUTPUT_MANIFEST_READ_GAS", 2)
    for row, name in zip(r[10], ("SCOPED_POLICY_SNAPSHOT_READ_GAS",
            "SCOPED_POLICY_SNAPSHOT_SOURCE_GAS", "SCOPED_POLICY_SNAPSHOT_INVENTORY_GAS")):
        _gas(row, name, 2)
    for row, name in zip(r[11], ("SCOPED_POLICY_REFERENCE_READ_GAS",
            "SCOPED_POLICY_REFERENCE_SOURCE_GAS", "SCOPED_POLICY_REFERENCE_SNAPSHOT_GAS",
            "SCOPED_POLICY_REFERENCE_ARCHIVE_GAS")):
        _gas(row, name, 1)
    require(r[10][1][1] >= r[10][0][1] and r[10][2][1] >= r[10][0][1]
        and r[11][1][1] >= r[11][0][1] and r[11][2][1] >= r[11][1][1]
        and r[11][3][1] >= r[11][0][1], "scoped factory gas hierarchy")
    return r


def recipe_hash(chain_id, recipe):
    r = validate_recipe(recipe, chain_id)
    return keccak256(encode(("bytes32", "uint256", RECIPE), (PROFILE, _number(chain_id), r)))


def dependencies_hash(value):
    return keccak256(encode((POLICY_DEPS,), (_v(POLICY_DEPS, value),)))


def graph_id(chain_id, factory, recipe_digest, dependency_digest, graph):
    g = _v(GRAPH, graph)
    return keccak256(encode(("bytes32", "uint256", "address", "bytes32", "bytes32", SCOPE,
        "bytes32", "address", "bytes32"), (GRAPH_DOMAIN, _number(chain_id), factory, recipe_digest,
        dependency_digest, g[0], g[1], g[2], g[3])))


def snapshot_dependencies(recipe, graph):
    r, g = _v(RECIPE, recipe), _v(GRAPH, graph); d = r[0]
    targets = (*d[0][:5], r[1][0], r[1][1], g[5][1], g[5][2], d[0][10], g[2])
    hashes = (*d[1][:5], r[2][0], r[2][1], g[6][1], g[6][2], d[1][10], g[3])
    return (targets, hashes, d[6], r[10][0][1], r[10][1][1], r[10][2][1])


def reference_dependencies(recipe, graph):
    r, g = _v(RECIPE, recipe), _v(GRAPH, graph); d = r[0]
    return ((*d[0][:5], g[5][3], d[0][11]), (*d[1][:5], g[6][3], d[1][11]), d[6],
        r[11][0][1], r[11][1][1], r[11][2][1], r[11][3][1])


def inventory_dependencies(recipe, graph):
    r, g = _v(RECIPE, recipe), _v(GRAPH, graph); d = list(r[0]); a, h = list(d[0]), list(d[1])
    a[5:7], h[5:7] = list(g[5][3:5]), list(g[6][3:5]); d[0], d[1] = tuple(a), tuple(h)
    return tuple(d)


def bundle_dependencies(recipe, graph):
    r, g = _v(RECIPE, recipe), _v(GRAPH, graph); d = r[0]
    return ((d[0][0], d[0][1], g[5][5], d[0][10], d[0][11], d[2][4]),
        (d[1][0], d[1][1], g[6][5], d[1][10], d[1][11], d[3][4]),
        d[6], r[6], r[7])


def child_dependencies(recipe, graph):
    r, g = _v(RECIPE, recipe), _v(GRAPH, graph); d = r[0]
    return {"terminalReadiness": {"core": d[0][0], "metadataRouter": d[0][4],
            "entropySourceSet": g[2], "readGas": str(r[3]), "sourceGas": str(r[4])},
        "policyContent": {"selectionCheckpoint": r[1][1], "entropySourceSet": g[2],
            "terminalReadiness": g[5][0], "executor": r[1][3], "gas": json_values(r[8])},
        "outputManifest": {"core": d[0][0], "contentCheckpoint": g[5][1],
            "artifactCoverage": d[0][10], "executor": r[1][3], "gas": json_values(r[9])},
        "policySnapshot": json_values(snapshot_dependencies(r, g)),
        "policyReference": json_values(reference_dependencies(r, g)),
        "renderCriticalInventory": json_values(inventory_dependencies(r, g)),
        "bundleCoverage": json_values(bundle_dependencies(r, g))}


def _admitted_gas(actual, original, label):
    """A child may retain monotonic gas raises over its constructor minima."""
    require(actual[:3] == original[:3] and len(actual) == len(original)
        and all(actual[index] >= original[index] for index in range(3, len(original))),
        "scoped factory " + label + " dependencies")


def validate(value, context=None, graph=None, scope=None, original_configuration=None):
    base._closed(value, ("profile", "chainId", "factory", "factoryRuntimeHash", "recipe",
        "recipeHash", "sourceFactoryDependencies", "sourceFactoryDependenciesHash", "graph",
        "preparationEvents", "childDependencies"), "scoped publication factory evidence")
    require(value["profile"] == PROFILE and value["profile"] != CURRENT_AUTHORITY_PROFILE,
        "original scoped factory profile")
    chain = uint(value["chainId"]); hex_bytes(value["factory"], 20); hex_bytes(value["factoryRuntimeHash"], 32)
    r = validate_recipe(value["recipe"], chain); deps = _v(POLICY_DEPS, value["sourceFactoryDependencies"])
    require(value["recipeHash"] == recipe_hash(chain, r)
        and value["sourceFactoryDependenciesHash"] == dependencies_hash(deps), "scoped factory immutable hashes")
    require(deps[2] == chain and deps[0][:3] == (r[0][0][0], r[0][0][1], r[1][0])
        and deps[1][:3] == (r[0][1][0], r[0][1][1], r[2][0]), "scoped source-factory dependencies")
    g = _v(GRAPH, value["graph"]); _scope(g[0])
    require(g[1] != ZERO and g[2] != ZERO_ADDRESS and g[3] != ZERO and g[7] == 7
        and all(a != ZERO_ADDRESS and h != ZERO for a, h in zip(g[5], g[6]))
        and g[4] == graph_id(chain, value["factory"], value["recipeHash"],
            value["sourceFactoryDependenciesHash"], g), "scoped stored complete graph")
    events = value["preparationEvents"]
    require(type(events) is list and len(events) == 7, "scoped factory complete child event denominator")
    for index, row in enumerate(events):
        base._closed(row, ("graphId", "inventoryPlan", "childIndex", "child", "codeHash"),
            "scoped factory child event")
        require(row == {"graphId": g[4], "inventoryPlan": g[1], "childIndex": str(index),
            "child": g[5][index], "codeHash": g[6][index]}, "scoped factory child event differs")
    expected = child_dependencies(r, g)
    require(value["childDependencies"] == expected, "scoped factory child dependencies differ")
    if context is not None:
        require(type(context) is dict and chain == uint(context["chainId"]),
            "scoped factory source context differs")
    if scope is not None:
        require(g[0] == _scope(scope), "scoped factory requested scope differs")
    if graph is not None:
        require(type(graph) is dict, "scoped factory source graph")
        roles = {"publicationFactory": (value["factory"], value["factoryRuntimeHash"]),
            "sourceFactory": (r[1][2], r[2][2]), "entropySourceSet": (g[2], g[3])}
        roles.update({name: (g[5][index], g[6][index]) for index, name in enumerate(CHILDREN)})
        for name, (address, runtime) in roles.items():
            require(name in graph and graph[name] == {"address": address, "runtimeHash": runtime},
                "scoped factory graph role differs")
    if original_configuration is not None:
        original = _v(collection.PROVIDER_CONFIG, original_configuration)
        mapping = ((0, 0), (1, 1), (2, 4), (3, 5), (4, 2),
            (7, 15), (8, 16), (9, 17), (10, 20), (11, 21))
        require(original[2] == chain and all((r[0][0][left], r[0][1][left])
            == (original[0][right], original[1][right]) for left, right in mapping),
            "scoped factory original provider configuration differs")
    return {"recipe": json_values(r), "graph": json_values(g),
        "sourceFactoryDependencies": json_values(deps),
        "inventoryDependencies": json_values(inventory_dependencies(r, g)),
        "childDependencies": expected,
        "historicalStoredGraph": True, "currentEligibilityChecked": False,
        "currentAuthorityVariant": False}


class ScopedPolicyFactoryReads:
    """Mixin for a source with ``_one``, ``_history``, ``reader``, ``a`` and ``graph``."""

    def _scoped_policy_factory(self, role, scope, inventory_plan):
        host, chain = self.a[role], uint(self.a["chainId"])
        require(self._one(host, "scopedPolicyPublicationFactoryProfile()", "bytes32") == PROFILE,
            "original scoped factory profile")
        recipe = self._one(host, "recipe()", RECIPE)
        graph = self._one(host, "graphForPlan(bytes32)", GRAPH, ("bytes32",), (inventory_plan,))
        dependencies = self._one(self.a["sourceFactory"], "dependencies()", POLICY_DEPS)
        value = {"profile": PROFILE, "chainId": str(chain), "factory": host,
            "factoryRuntimeHash": self.pins[host], "recipe": json_values(recipe),
            "recipeHash": self._one(host, "recipeHash()", "bytes32"),
            "sourceFactoryDependencies": json_values(dependencies),
            "sourceFactoryDependenciesHash": self._one(host, "sourceFactoryDependenciesHash()", "bytes32"),
            "graph": json_values(graph), "preparationEvents": [],
            "childDependencies": child_dependencies(recipe, graph)}
        require(self._one(host, "core()", "address") == recipe[0][0][0]
            and self._one(host, "metadataHost()", "address") == recipe[0][0][1]
            and self._one(host, "entropySourceFactory()", "address") == self.a["sourceFactory"],
            "scoped factory immutable identity")
        require(keccak256(hex_bytes(self.reader.code(host))) == self.pins[host]
            and self.pins[self.a["sourceFactory"]] == recipe[2][2]
            and keccak256(hex_bytes(self.reader.code(self.a["sourceFactory"]))) == recipe[2][2]
            and self._one(self.a["sourceFactory"], "scopedPolicyFactoryProfile()", "bytes32")
                == SOURCE_FACTORY_PROFILE,
            "scoped factory/source runtime identity")
        require(graph[0] == _v(SCOPE, scope) and graph[1] == inventory_plan, "scoped factory stored plan/scope")
        require(self._one(graph[2], "factory()", "address") == self.a["sourceFactory"]
            and self._one(graph[2], "core()", "address") == recipe[0][0][0]
            and self._one(graph[2], "inventoryPlan()", "bytes32") == graph[1]
            and self._one(graph[2], "SOURCE_SET_PROFILE()", "bytes32")
                == schema_id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
            and keccak256(hex_bytes(self.reader.code(graph[2]))) == graph[3],
            "scoped factory stored source-set identity")
        for address, digest in zip(graph[5], graph[6]):
            require(keccak256(hex_bytes(self.reader.code(address))) == digest, "scoped factory child runtime")
        observed_snapshot = self._one(graph[5][3], "dependencies()", SNAPSHOT_DEPS)
        observed_reference = self._one(graph[5][4], "dependencies()", REFERENCE_DEPS)
        _admitted_gas(observed_snapshot, snapshot_dependencies(recipe, graph), "snapshot")
        _admitted_gas(observed_reference, reference_dependencies(recipe, graph), "reference")
        require(self._one(graph[5][5], "dependencyHash()", "bytes32")
                == keccak256(encode((collection.INVENTORY_DEPENDENCIES,), (inventory_dependencies(recipe, graph),)))
            and self._one(graph[5][6], "dependencyHash()", "bytes32")
                == keccak256(encode((BUNDLE_DEPS,), (bundle_dependencies(recipe, graph),))),
            "scoped factory child immutable dependencies")
        immutable = ((graph[5][0], (("core()", "address", recipe[0][0][0]),
                    ("coreCodeHash()", "bytes32", recipe[0][1][0]),
                    ("metadataRouter()", "address", recipe[0][0][4]),
                    ("metadataRouterCodeHash()", "bytes32", recipe[0][1][4]),
                    ("entropySourceSet()", "address", graph[2]),
                    ("entropySourceSetCodeHash()", "bytes32", graph[3]),
                    ("deploymentChainId()", "uint256", chain),
                    ("readGas()", "uint32", recipe[3]), ("sourceGas()", "uint32", recipe[4]))),
            (graph[5][1], (("core()", "address", recipe[0][0][0]),
                    ("coreCodeHash()", "bytes32", recipe[0][1][0]),
                    ("metadataRouter()", "address", recipe[0][0][4]),
                    ("routerCodeHash()", "bytes32", recipe[0][1][4]),
                    ("selectionCheckpoint()", "address", recipe[1][1]),
                    ("selectionCodeHash()", "bytes32", recipe[2][1]),
                    ("entropySourceSet()", "address", graph[2]),
                    ("entropySourceSetCodeHash()", "bytes32", graph[3]),
                    ("terminalReadiness()", "address", graph[5][0]),
                    ("terminalReadinessCodeHash()", "bytes32", graph[6][0]),
                    ("sourceFactory()", "address", recipe[1][2]),
                    ("sourceFactoryCodeHash()", "bytes32", recipe[2][2]),
                    ("factoryDependenciesHash()", "bytes32", value["sourceFactoryDependenciesHash"]),
                    ("deploymentChainId()", "uint256", chain))),
            (graph[5][2], (("core()", "address", recipe[0][0][0]),
                    ("contentCheckpoint()", "address", graph[5][1]),
                    ("checkpointCodeHash()", "bytes32", graph[6][1]),
                    ("artifactCoverage()", "address", recipe[0][0][10]),
                    ("coverageCodeHash()", "bytes32", recipe[0][1][10]),
                    ("schemaRegistry()", "address", recipe[0][0][2]),
                    ("schemaCodeHash()", "bytes32", recipe[0][1][2]),
                    ("deploymentChainId()", "uint256", chain))))
        for target, rows in immutable:
            for signature, output, expected in rows:
                require(self._one(target, signature, output) == expected,
                    "scoped factory direct child immutable differs")
        history = self._history(host, [CHILD_EVENT, graph[4], graph[1]])
        for log in history["logs"]:
            require(log["address"] == host and log["topics"][:3] == [CHILD_EVENT, graph[4], graph[1]]
                and len(log["topics"]) == 4, "scoped factory preparation event identity")
            index = int.from_bytes(hex_bytes(log["topics"][3], 32), "big")
            version, child, digest = decode(("uint16", "address", "bytes32"), hex_bytes(log["data"]), maximum=96)
            require(version == 2 and index < 7, "scoped factory preparation event payload")
            value["preparationEvents"].append({"graphId": graph[4], "inventoryPlan": graph[1],
                "childIndex": str(index), "child": child, "codeHash": digest})
        value["preparationEvents"].sort(key=lambda row: int(row["childIndex"]))
        validate(value)
        return value

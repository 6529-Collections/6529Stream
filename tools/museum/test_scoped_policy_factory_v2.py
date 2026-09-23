from copy import deepcopy
import unittest

from . import scoped_policy_factory_v2 as f
from .canonical import MuseumError, hex_bytes, keccak256
from .chain_abi import encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values
from .test_current_rights_source import A, H


def HS(value):
    return keccak256(value.encode("utf-8"))


def supplied():
    chain = 31337
    targets = [A(100 + i) for i in range(12)]; hashes = [HS("inventory " + str(i)) for i in range(12)]
    for i in (5, 6): targets[i], hashes[i] = ZERO_ADDRESS, ZERO
    artists = tuple(A(200 + i) for i in range(5)); artist_hashes = tuple(HS("artist " + str(i)) for i in range(5))
    inventory = (tuple(targets), tuple(hashes), artists, artist_hashes, A(210), HS("artist owner"),
        chain, 50000, 60000, 70000, 80000, 90000)
    gas = lambda name, value, failure: (name, value, 50000, failure)
    recipe = (inventory, (A(300), A(301), A(302), A(303)), tuple(HS("fixed " + str(i)) for i in range(4)),
        50000, 60000, 70000, 80000, 90000,
        (gas("STATIC_CONTENT_READ_GAS", 50000, 2), gas("STATIC_CONTENT_RENDER_GAS", 60000, 2)),
        gas("STATIC_OUTPUT_MANIFEST_READ_GAS", 50000, 2),
        (gas("SCOPED_POLICY_SNAPSHOT_READ_GAS", 50000, 2),
         gas("SCOPED_POLICY_SNAPSHOT_SOURCE_GAS", 60000, 2),
         gas("SCOPED_POLICY_SNAPSHOT_INVENTORY_GAS", 70000, 2)),
        (gas("SCOPED_POLICY_REFERENCE_READ_GAS", 50000, 1),
         gas("SCOPED_POLICY_REFERENCE_SOURCE_GAS", 60000, 1),
         gas("SCOPED_POLICY_REFERENCE_SNAPSHOT_GAS", 70000, 1),
         gas("SCOPED_POLICY_REFERENCE_ARCHIVE_GAS", 80000, 1)))
    source_dependencies = ((targets[0], targets[1], recipe[1][0], A(304)),
        (hashes[0], hashes[1], recipe[2][0], HS("coordinator inventory")), chain, 50000, 60000)
    factory = A(400); scope = (1, 1, 41, ZERO)
    graph = [scope, HS("inventory plan"), A(401), HS("source set"), ZERO,
        tuple(A(410 + i) for i in range(7)), tuple(HS("child " + str(i)) for i in range(7)), 7]
    rh = f.recipe_hash(chain, recipe); dh = f.dependencies_hash(source_dependencies)
    graph[4] = f.graph_id(chain, factory, rh, dh, graph)
    events = [{"graphId": graph[4], "inventoryPlan": graph[1], "childIndex": str(i),
        "child": graph[5][i], "codeHash": graph[6][i]} for i in range(7)]
    value = {"profile": f.PROFILE, "chainId": str(chain), "factory": factory,
        "factoryRuntimeHash": HS("factory"), "recipe": json_values(recipe), "recipeHash": rh,
        "sourceFactoryDependencies": json_values(source_dependencies), "sourceFactoryDependenciesHash": dh,
        "graph": json_values(graph), "preparationEvents": events,
        "childDependencies": f.child_dependencies(recipe, graph)}
    return value


class _Code:
    def __init__(self, code): self.code_by_address = code
    def code(self, address): return "0x" + self.code_by_address[address].hex()


class _Reads(f.ScopedPolicyFactoryReads):
    def __init__(self, value):
        self.value = value
        r = f._v(f.RECIPE, value["recipe"]); g = f._v(f.GRAPH, value["graph"])
        codes = {value["factory"]: b"publication factory", r[1][2]: b"source factory",
            g[2]: b"source set"}
        value["factoryRuntimeHash"] = keccak256(codes[value["factory"]])
        value["recipe"][2][2] = keccak256(codes[r[1][2]])
        value["graph"][3] = keccak256(codes[g[2]])
        for address, digest in zip(g[5], g[6]):
            body = ("child " + address).encode(); codes[address] = body
            # The read mixin authenticates actual code. Rebind the synthetic
            # graph pins and its graph hash before the read.
            self.value["graph"][6][list(g[5]).index(address)] = keccak256(body)
        r = f._v(f.RECIPE, self.value["recipe"])
        self.value["recipeHash"] = f.recipe_hash(value["chainId"], r)
        graph = f._v(f.GRAPH, self.value["graph"])
        self.value["graph"][4] = f.graph_id(value["chainId"], value["factory"], value["recipeHash"],
            value["sourceFactoryDependenciesHash"], graph)
        self.value["preparationEvents"] = [{"graphId": self.value["graph"][4],
            "inventoryPlan": graph[1], "childIndex": str(i), "child": graph[5][i],
            "codeHash": self.value["graph"][6][i]} for i in range(7)]
        self.value["childDependencies"] = f.child_dependencies(r, self.value["graph"])
        self.a = {"chainId": value["chainId"], "publicationFactory": value["factory"],
            "sourceFactory": r[1][2]}
        self.pins = {address: keccak256(body) for address, body in codes.items()}
        self.reader = _Code(codes)
        self.observed_snapshot = None
        self.observed_reference = None

    def _one(self, target, signature, output, inputs=(), values=()):
        v = self.value; r = f._v(f.RECIPE, v["recipe"]); g = f._v(f.GRAPH, v["graph"])
        table = {(v["factory"], "scopedPolicyPublicationFactoryProfile()"): f.PROFILE,
            (v["factory"], "recipe()"): r, (v["factory"], "graphForPlan(bytes32)"): g,
            (v["factory"], "recipeHash()"): v["recipeHash"],
            (v["factory"], "sourceFactoryDependenciesHash()"): v["sourceFactoryDependenciesHash"],
            (v["factory"], "core()"): r[0][0][0], (v["factory"], "metadataHost()"): r[0][0][1],
            (v["factory"], "entropySourceFactory()"): r[1][2],
            (r[1][2], "scopedPolicyFactoryProfile()"): f.SOURCE_FACTORY_PROFILE,
            (r[1][2], "dependencies()"): f._v(f.POLICY_DEPS, v["sourceFactoryDependencies"]),
            (g[2], "factory()"): r[1][2], (g[2], "core()"): r[0][0][0],
            (g[2], "inventoryPlan()"): g[1],
            (g[2], "SOURCE_SET_PROFILE()"): f.schema_id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"),
            (g[5][3], "dependencies()"): self.observed_snapshot or f.snapshot_dependencies(r, g),
            (g[5][4], "dependencies()"): self.observed_reference or f.reference_dependencies(r, g),
            (g[5][5], "dependencyHash()"): keccak256(encode((f.collection.INVENTORY_DEPENDENCIES,),
                (f.inventory_dependencies(r, g),))),
            (g[5][6], "dependencyHash()"): keccak256(encode((f.BUNDLE_DEPS,),
                (f.bundle_dependencies(r, g),)))}
        direct = {g[5][0]: {"core()": r[0][0][0], "coreCodeHash()": r[0][1][0],
                "metadataRouter()": r[0][0][4], "metadataRouterCodeHash()": r[0][1][4],
                "entropySourceSet()": g[2], "entropySourceSetCodeHash()": g[3],
                "deploymentChainId()": int(v["chainId"]), "readGas()": r[3], "sourceGas()": r[4]},
            g[5][1]: {"core()": r[0][0][0], "coreCodeHash()": r[0][1][0],
                "metadataRouter()": r[0][0][4], "routerCodeHash()": r[0][1][4],
                "selectionCheckpoint()": r[1][1], "selectionCodeHash()": r[2][1],
                "entropySourceSet()": g[2], "entropySourceSetCodeHash()": g[3],
                "terminalReadiness()": g[5][0], "terminalReadinessCodeHash()": g[6][0],
                "sourceFactory()": r[1][2], "sourceFactoryCodeHash()": r[2][2],
                "factoryDependenciesHash()": v["sourceFactoryDependenciesHash"],
                "deploymentChainId()": int(v["chainId"])},
            g[5][2]: {"core()": r[0][0][0], "contentCheckpoint()": g[5][1],
                "checkpointCodeHash()": g[6][1], "artifactCoverage()": r[0][0][10],
                "coverageCodeHash()": r[0][1][10], "schemaRegistry()": r[0][0][2],
                "schemaCodeHash()": r[0][1][2], "deploymentChainId()": int(v["chainId"])}}
        if target in direct and signature in direct[target]: return direct[target][signature]
        if "requireCurrentGraph" in signature: raise AssertionError("current gate used")
        return table[target, signature]

    def _history(self, target, filters):
        assert filters == [f.CHILD_EVENT, self.value["graph"][4], self.value["graph"][1]]
        logs = []
        for row in self.value["preparationEvents"]:
            logs.append({"address": target, "topics": [f.CHILD_EVENT, row["graphId"], row["inventoryPlan"],
                "0x" + int(row["childIndex"]).to_bytes(32, "big").hex()],
                "data": "0x" + encode(("uint16", "address", "bytes32"),
                    (2, row["child"], row["codeHash"])).hex()})
        return {"logs": logs}


class ScopedPolicyFactoryV2Tests(unittest.TestCase):
    def test_exact_recipe_graph_and_children(self):
        value = supplied(); result = f.validate(value)
        self.assertTrue(result["historicalStoredGraph"])
        self.assertFalse(result["currentEligibilityChecked"])
        self.assertEqual(set(result["childDependencies"]), set(f.CHILDREN))
        self.assertEqual(result["inventoryDependencies"][0][5:7],
            value["graph"][5][3:5])

    def test_source_context_graph_and_original_provider_join(self):
        value = supplied(); r = f._v(f.RECIPE, value["recipe"]); g = f._v(f.GRAPH, value["graph"])
        graph = {"publicationFactory": {"address": value["factory"],
            "runtimeHash": value["factoryRuntimeHash"]},
            "sourceFactory": {"address": r[1][2], "runtimeHash": r[2][2]},
            "entropySourceSet": {"address": g[2], "runtimeHash": g[3]}}
        graph.update({name: {"address": g[5][i], "runtimeHash": g[6][i]}
            for i, name in enumerate(f.CHILDREN)})
        addresses, hashes = [A(600 + i) for i in range(22)], [HS("provider " + str(i)) for i in range(22)]
        for left, right in ((0, 0), (1, 1), (2, 4), (3, 5), (4, 2),
                (7, 15), (8, 16), (9, 17), (10, 20), (11, 21)):
            addresses[right], hashes[right] = r[0][0][left], r[0][1][left]
        original = (tuple(addresses), tuple(hashes), 31337, 50000, 200000, 60000, HS("inventory"))
        result = f.validate(value, {"chainId": "31337"}, graph, value["graph"][0],
            json_values(original))
        self.assertEqual(result["sourceFactoryDependencies"], value["sourceFactoryDependencies"])
        changed = list(deepcopy(original)); changed[0] = list(changed[0]); changed[0][0] = A(999)
        with self.assertRaisesRegex(MuseumError, "original provider"):
            f.validate(value, {"chainId": "31337"}, graph, value["graph"][0], changed)

    def test_hash_recipes_are_independent_exact_abi(self):
        value = supplied(); r = f._v(f.RECIPE, value["recipe"]); g = f._v(f.GRAPH, value["graph"])
        self.assertEqual(value["recipeHash"], keccak256(encode(("bytes32", "uint256", f.RECIPE),
            (f.PROFILE, int(value["chainId"]), r))))
        self.assertEqual(g[4], keccak256(encode(("bytes32", "uint256", "address", "bytes32", "bytes32",
            f.SCOPE, "bytes32", "address", "bytes32"), (f.GRAPH_DOMAIN, int(value["chainId"]),
            value["factory"], value["recipeHash"], value["sourceFactoryDependenciesHash"], *g[:4]))))

    def test_original_slot_five_six_are_factory_children(self):
        value = supplied(); r = f._v(f.RECIPE, value["recipe"]); g = f._v(f.GRAPH, value["graph"])
        self.assertEqual(r[0][0][5:7], (ZERO_ADDRESS, ZERO_ADDRESS))
        inventory = f.inventory_dependencies(r, g)
        self.assertEqual(inventory[0][5:7], g[5][3:5])
        self.assertEqual(inventory[1][5:7], g[6][3:5])

    def test_snapshot_reference_and_bundle_projection(self):
        value = supplied(); r = f._v(f.RECIPE, value["recipe"]); g = f._v(f.GRAPH, value["graph"])
        snapshot = f.snapshot_dependencies(r, g); reference = f.reference_dependencies(r, g)
        self.assertEqual(snapshot[0][5:9], (r[1][0], r[1][1], g[5][1], g[5][2]))
        self.assertEqual(reference[0][5], g[5][3])
        self.assertEqual(f.bundle_dependencies(r, g)[0][2], g[5][5])

    def test_current_authority_variant_cannot_be_relabelled(self):
        value = supplied(); value["profile"] = f.CURRENT_AUTHORITY_PROFILE
        with self.assertRaisesRegex(MuseumError, "original scoped factory profile"): f.validate(value)

    def test_recipe_and_source_factory_mismatch_reject(self):
        value = supplied(); value["sourceFactoryDependencies"][0][2] = A(999)
        value["sourceFactoryDependenciesHash"] = f.dependencies_hash(value["sourceFactoryDependencies"])
        with self.assertRaisesRegex(MuseumError, "source-factory dependencies"): f.validate(value)

    def test_scope_and_graph_identity_reject(self):
        for scope in ((0, 1, 0, ZERO), (1, 1, 0, ZERO), (2, 1, 41, HS("release"))):
            value = supplied(); value["graph"][0] = json_values(scope)
            with self.subTest(scope=scope), self.assertRaises(MuseumError): f.validate(value)

    def test_missing_reordered_or_changed_child_event_rejects(self):
        for mutate in (lambda rows: rows.pop(), lambda rows: rows.reverse(),
                lambda rows: rows[3].update(codeHash=HS("changed"))):
            value = supplied(); mutate(value["preparationEvents"])
            with self.assertRaisesRegex(MuseumError, "child event"): f.validate(value)

    def test_recipe_gas_and_reserved_roles_reject(self):
        value = supplied(); value["recipe"][0][0][5] = A(5)
        with self.assertRaisesRegex(MuseumError, "original inventory role"): f.validate(value)
        value = supplied(); value["recipe"][10][1][1] = "49999"
        with self.assertRaises(MuseumError): f.validate(value)

    def test_historical_read_mixin_never_calls_current_gate(self):
        harness = _Reads(supplied())
        value = harness._scoped_policy_factory("publicationFactory", harness.value["graph"][0],
            harness.value["graph"][1])
        self.assertEqual(value["graph"][4], harness.value["graph"][4])
        self.assertEqual([r["childIndex"] for r in value["preparationEvents"]], [str(i) for i in range(7)])

    def test_historical_child_gas_may_raise_but_never_lower(self):
        harness = _Reads(supplied()); value = harness.value
        recipe = f._v(f.RECIPE, value["recipe"]); graph = f._v(f.GRAPH, value["graph"])
        snapshot = list(f.snapshot_dependencies(recipe, graph)); reference = list(f.reference_dependencies(recipe, graph))
        snapshot[4] += 1; reference[6] += 1
        harness.observed_snapshot, harness.observed_reference = tuple(snapshot), tuple(reference)
        harness._scoped_policy_factory("publicationFactory", value["graph"][0], value["graph"][1])
        snapshot[3] = recipe[10][0][1] - 1
        harness.observed_snapshot = tuple(snapshot)
        with self.assertRaisesRegex(MuseumError, "snapshot dependencies"):
            harness._scoped_policy_factory("publicationFactory", value["graph"][0], value["graph"][1])


if __name__ == "__main__": unittest.main()

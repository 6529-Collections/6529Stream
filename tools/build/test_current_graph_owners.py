"""Synthetic native/Forge boundary tests; no Solidity compiler or EVM execution."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

from tools.build import current_graph_owners as owners
from tools.build import prepare_current_graph as graph
from tools.build import scoped_standard_json as scoped


HOST = ("test/current/Owned.t.sol", "OwnedTest")
CREATION = graph.CREATION_SOURCE + ":" + graph.CREATION_NAME
PRODUCT = "smart-contracts/Product.sol:Product"
BASE = "smart-contracts/Base.sol:Base"
LIBRARY = "smart-contracts/Lib.sol:Lib"
FIELDS = ["abi", "metadata", "storageLayout", "evm.bytecode", "evm.deployedBytecode", "evm.methodIdentifiers"]


class NativeOwnerTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.config = self.root / "owners.json"
        self.products = self.root / "products.json"
        self.write(self.products, {"Product": PRODUCT.split(":")[0], "Base": BASE.split(":")[0]})
        self.sources = {s: {"content": "// synthetic boundary " + n + "\n"} for s, n in (
            owners.coordinate(PRODUCT), owners.coordinate(BASE), owners.coordinate(LIBRARY),
            (graph.CREATION_SOURCE, graph.CREATION_NAME), HOST)}
        for source, value in self.sources.items():
            path = self.root / source; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(value["content"], encoding="utf-8")
        self.asts = {}
        for index, source in enumerate(sorted(self.sources)):
            name = {PRODUCT.split(":")[0]: "Product", BASE.split(":")[0]: "Base", LIBRARY.split(":")[0]: "Lib",
                    graph.CREATION_SOURCE: graph.CREATION_NAME, HOST[0]: HOST[1]}[source]
            definition = {"nodeType": "ContractDefinition", "id": 100 + index, "name": name,
                          "contractKind": "library" if name in ("Lib", graph.CREATION_NAME) else "contract",
                          "abstract": name == "Base", "nodes": [], "contractDependencies": [],
                          "linearizedBaseContracts": [100 + index]}
            if name == "Base":
                definition["nodes"] = [{"nodeType": "VariableDeclaration", "mutability": "immutable",
                                         "name": "owner", "id": 501}]
            imports = [{"nodeType": "ImportDirective", "id": 600, "absolutePath": BASE.split(":")[0]}] if name == "Product" else []
            self.asts[source] = {"id": index, "ast": {"absolutePath": source, "nodeType": "SourceUnit",
                                "id": 1000 + index, "nodes": imports + [definition]}}
        base_id = self.asts[BASE.split(":")[0]]["ast"]["nodes"][0]["id"]
        self.asts[PRODUCT.split(":")[0]]["ast"]["nodes"][-1]["linearizedBaseContracts"].append(base_id)
        self.data = {"version": 1, "contexts": {}, "owners": {
            PRODUCT: "products", BASE: "products", LIBRARY: "products", CREATION: "hosts", HOST[0] + ":" + HOST[1]: "hosts"}}
        # Deliberately colliding short Forge IDs, genuinely different captures and output paths.
        self.capture("products", [PRODUCT, BASE, LIBRARY])
        self.capture("hosts", [CREATION, HOST[0] + ":" + HOST[1]])
        self.save_config()

    @staticmethod
    def write(path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(scoped.canonical(value))

    def save_config(self):
        self.write(self.config, self.data)

    def capture(self, label, coordinates, *, oversized=False):
        folder = self.root / label; capture = folder / "capture"; output = folder / "out"; cache = folder / "cache"
        capture.mkdir(parents=True, exist_ok=True)
        selection = {s: {n: list(FIELDS)} for s, n in map(owners.coordinate, coordinates)}
        request = {"language": "Solidity", "sources": copy.deepcopy(self.sources), "settings": {
            "optimizer": {"enabled": True, "runs": 200}, "viaIR": True, "evmVersion": "paris",
            "metadata": {"bytecodeHash": "none", "appendCBOR": False}, "outputSelection": selection}}
        ai, ni = scoped.split_request(request)
        ao = {"sources": copy.deepcopy(self.asts)}
        no = {"sources": {s: copy.deepcopy(v) if s in selection else {"id": v["id"]} for s, v in self.asts.items()}, "contracts": {}}
        cache_value = {"files": {}}
        for coord in coordinates:
            source, name = owners.coordinate(coord)
            metadata = {"settings": {"compilationTarget": {source: name}}}
            code = {"object": "00" * 64, "sourceMap": "", "linkReferences": {}}
            runtime = {**copy.deepcopy(code), "immutableReferences": {}}
            if name == "Product":
                runtime["immutableReferences"] = {"501": [{"start": 0, "length": 32}]}
                code["linkReferences"] = {LIBRARY.split(":")[0]: {"Lib": [{"start": 0, "length": 20}]}}
            if name == "Product" and oversized:
                runtime["object"] = "00" * 24577
            native = {"abi": [], "metadata": json.dumps(metadata), "storageLayout": {"storage": [], "types": {}},
                      "evm": {"bytecode": code, "deployedBytecode": runtime, "methodIdentifiers": {}}}
            no["contracts"].setdefault(source, {})[name] = native
            physical = {"abi": [], "metadata": metadata, "rawMetadata": native["metadata"],
                        "storageLayout": native["storageLayout"], "bytecode": code, "deployedBytecode": runtime,
                        "methodIdentifiers": {}, "ast": no["sources"][source]["ast"], "id": no["sources"][source]["id"]}
            self.write(output / Path(source).name / (name + ".json"), physical)
            cache_value["files"][source] = {"artifacts": {name: {"0.8.19": {"current": {
                "path": Path(source).name + "/" + name + ".json", "build_id": "same-short-id"}}}}}
        verification = scoped.verify_pair(ai, ao, ni, no)
        for name, value in {"requested-input.json": request, "selection.json": selection,
                            "analysis-input.json": ai, "analysis-output.json": ao,
                            "codegen-input.json": ni, "codegen-output.json": no, "verification.json": verification}.items():
            self.write(capture / name, value)
        (capture / "version.stdout").write_bytes(scoped.VERSION.encode())
        for name in ("version.stderr", "analysis-stderr.log", "codegen-stderr.log"):
            (capture / name).write_bytes(b"")
        record = {"schema": 1, "status": "VERIFIED", "compiler": "SYNTHETIC-NEVER-EXECUTE",
                  "compilerSha256": "12" * 32, "arguments": ["--standard-json"],
                  "passes": {n: {"status": "COMPLETE", "exitCode": 0, "compilerSha256": "12" * 32,
                                  "command": ["SYNTHETIC-NEVER-EXECUTE", "--standard-json"]} for n in ("analysis", "codegen")},
                  "files": {p.name: graph.sha(p.read_bytes()) for p in capture.iterdir() if p.name != "record.json"}}
        self.write(capture / "record.json", record)
        build = {"id": "same-short-id", "solcVersion": "0.8.19", "input": ni, "output": no}
        build_path = output / "build-info/same-short-id.json"; self.write(build_path, build)
        self.write(cache / "solidity-files-cache.json", cache_value)
        self.data["contexts"][label] = {"out": str(output), "cache": str(cache), "buildId": "same-short-id",
            "compilerCapture": str(capture), "buildInfoSha256": graph.sha(build_path.read_bytes()),
            "nativeInputSha256": graph.sha((capture / "codegen-input.json").read_bytes()),
            "nativeOutputSha256": graph.sha((capture / "codegen-output.json").read_bytes())}

    def run_prepare(self):
        self.save_config()
        return graph.prepare(self.root, self.products, selected_hosts=(HOST,), owners_path=self.config)

    def load(self):
        return {label: owners.load_context(self.root, self.config, label, row, self.data["owners"])
                for label, row in self.data["contexts"].items()}

    def snapshot(self):
        return {p.relative_to(self.root).as_posix(): p.read_bytes() for label in ("products", "hosts")
                for p in (self.root / label).rglob("*") if p.is_file()}

    def test_distinct_owners_with_colliding_ids_preserve_physical_and_capture_bytes(self):
        before = self.snapshot(); result = self.run_prepare()
        self.assertEqual(len(result["compilerContexts"]), 2)
        self.assertNotEqual(result["owners"][PRODUCT], result["owners"][CREATION])
        self.assertEqual({r["buildId"] for r in result["compilerContexts"].values()}, {"same-short-id"})
        self.assertEqual(before, self.snapshot())
        projected = json.loads((self.root / "artifacts/current-graph/compiled/Product.json").read_bytes())
        self.assertEqual(projected["deployedBytecode"]["immutableReferences"], {"501": [{"start": 0, "length": 32}]})
        self.assertEqual(projected["compilationHash"], scoped.sha(scoped.canonical(self.load()["products"]["build"]["input"])))

    def test_wrong_cache_product_owner_refuses_before_exports(self):
        path = self.root / "products/cache/solidity-files-cache.json"; cache = json.loads(path.read_bytes())
        cache["files"][PRODUCT.split(":")[0]]["artifacts"]["Product"]["0.8.19"]["current"]["build_id"] = "another"
        self.write(path, cache)
        with self.assertRaisesRegex(ValueError, "different native product"):
            self.run_prepare()

    def test_ambiguous_cache_refuses(self):
        path = self.root / "products/cache/solidity-files-cache.json"; cache = json.loads(path.read_bytes())
        entries = cache["files"][PRODUCT.split(":")[0]]["artifacts"]["Product"]["0.8.19"]
        entries["other"] = copy.deepcopy(entries["current"]); self.write(path, cache)
        with self.assertRaisesRegex(ValueError, "unambiguous"):
            self.run_prepare()

    def test_changed_product_or_transitive_import_refuses(self):
        for path in (PRODUCT.split(":")[0], BASE.split(":")[0]):
            original = (self.root / path).read_bytes(); (self.root / path).write_bytes(b"changed")
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "Stale compiler source"):
                self.run_prepare()
            (self.root / path).write_bytes(original)

    def test_changed_physical_executable_or_layout_refuses_without_projection(self):
        path = self.root / "products/out/Product.sol/Product.json"; original = path.read_bytes()
        for field in ("bytecode", "deployedBytecode", "storageLayout", "ast", "id"):
            value = json.loads(original)
            if field in ("bytecode", "deployedBytecode"): value[field]["object"] = "ff" * 64
            elif field == "storageLayout": value[field]["storage"] = [{"slot": "changed"}]
            elif field == "ast": value[field]["nodes"][0]["id"] += 1
            else: value[field] += 1
            self.write(path, value)
            with self.subTest(field=field), self.assertRaises(subprocess.CalledProcessError):
                self.run_prepare()
            self.assertFalse((self.root / "artifacts/current-graph/compiled").exists())
            path.write_bytes(original)

    def test_raw_capture_or_build_hash_change_refuses(self):
        for path in (self.root / "products/out/build-info/same-short-id.json", self.root / "products/capture/codegen-output.json"):
            raw = path.read_bytes(); path.write_bytes(raw + b" ")
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "evidence hash differs"):
                self.run_prepare()
            path.write_bytes(raw)

    def test_mixed_parent_owner_refuses_even_with_same_short_id(self):
        self.capture("hosts", [CREATION, HOST[0] + ":" + HOST[1], BASE])
        self.data["owners"][BASE] = "hosts"
        with self.assertRaisesRegex(ValueError, "Mixed immutable parent ownership"):
            self.run_prepare()

    def test_missing_parent_projection_and_missing_library_owner_refuse(self):
        original = self.products.read_bytes(); self.write(self.products, {"Product": PRODUCT.split(":")[0]})
        with self.assertRaisesRegex(ValueError, "Missing flat immutable parent"):
            self.run_prepare()
        self.products.write_bytes(original); del self.data["owners"][LIBRARY]
        with self.assertRaisesRegex(ValueError, "Missing explicit linked-library owner"):
            self.run_prepare()

    def test_owner_aliases_do_not_conflate_a_context(self):
        contexts = self.load(); contexts["alias"] = contexts["hosts"]
        with self.assertRaisesRegex(ValueError, "Duplicate labels"):
            owners.validate_owner_joins(contexts, self.data["owners"], json.loads(self.products.read_bytes()))

    def test_missing_owner_and_legacy_option_mix_refuse(self):
        del self.data["owners"][PRODUCT]
        with self.assertRaisesRegex(ValueError, "Missing explicit native owners"):
            self.run_prepare()
        with self.assertRaisesRegex(ValueError, "cannot be combined"):
            graph.prepare(self.root, self.products, owners_path=self.config, out=Path("out"))

    def test_getcode_detection_requires_actual_call_not_similar_strings(self):
        build = self.load()["hosts"]["build"]
        node = build["output"]["sources"][graph.CREATION_SOURCE]["ast"]["nodes"][0]
        node["nodes"].append({"nodeType": "Literal", "value": "getCode"})
        self.assertFalse(owners.getcode_creation(build, graph.CREATION_SOURCE, graph.CREATION_NAME))
        node["nodes"].append({"nodeType": "FunctionCall", "expression": {"nodeType": "MemberAccess", "memberName": "getCode"}})
        self.assertTrue(owners.getcode_creation(build, graph.CREATION_SOURCE, graph.CREATION_NAME))

    def unified_dynamic_fixture(self):
        node = self.asts[graph.CREATION_SOURCE]["ast"]["nodes"][0]
        node["nodes"] += [
            {"nodeType": "FunctionCall", "expression": {"nodeType": "MemberAccess", "memberName": "getCode"}},
            {"nodeType": "Literal", "kind": "string", "value": PRODUCT},
            {"nodeType": "Literal", "kind": "string", "value": LIBRARY}]
        self.capture("unified", [CREATION, HOST[0] + ":" + HOST[1], PRODUCT, BASE, LIBRARY])
        return self.root / "unified/out", self.root / "unified/cache"

    def test_legacy_dynamic_creation_rejects_instead_of_borrowing_product_emission(self):
        output, cache_dir = self.unified_dynamic_fixture()
        path = cache_dir / "solidity-files-cache.json"; cache = json.loads(path.read_bytes())
        cache["files"][PRODUCT.split(":")[0]]["artifacts"]["Product"]["0.8.19"]["current"]["build_id"] = "foreign"
        self.write(path, cache)
        with self.assertRaisesRegex(ValueError, "Differently owned getCode product requires explicit --owners"):
            graph.prepare(self.root, self.products, selected_hosts=(HOST,), out=output, cache_dir=cache_dir)

    def test_legacy_dynamic_creation_accepts_complete_same_owner_without_capture(self):
        output, cache_dir = self.unified_dynamic_fixture()
        result = graph.prepare(self.root, self.products, selected_hosts=(HOST,), out=output, cache_dir=cache_dir)
        self.assertTrue(result["dynamicCreationSameOwner"])
        self.assertEqual(set(result["literalArtifactSources"]), {PRODUCT, LIBRARY})
        exported = json.loads((Path(result["compilerContexts"]["same-short-id"]["nativeExports"]) / "manifest.json").read_bytes())
        self.assertIn("Lib", exported["products"])
        self.assertFalse(exported["compilerCapture"])

    def test_legacy_dynamic_nonprojection_literal_owner_must_also_match(self):
        output, cache_dir = self.unified_dynamic_fixture()
        path = cache_dir / "solidity-files-cache.json"; cache = json.loads(path.read_bytes())
        cache["files"][LIBRARY.split(":")[0]]["artifacts"]["Lib"]["0.8.19"]["current"]["build_id"] = "foreign"
        self.write(path, cache)
        with self.assertRaisesRegex(ValueError, "Differently owned getCode product requires explicit --owners"):
            graph.prepare(self.root, self.products, selected_hosts=(HOST,), out=output, cache_dir=cache_dir)

    def test_legacy_dynamic_physical_change_after_export_refuses(self):
        output, cache_dir = self.unified_dynamic_fixture()
        path = output / "Product.sol/Product.json"
        original_run = subprocess.run
        def mutate_after_export(*args, **kwargs):
            result = original_run(*args, **kwargs)
            path.write_bytes(path.read_bytes() + b" ")
            return result
        with mock.patch.object(graph.subprocess, "run", side_effect=mutate_after_export):
            with self.assertRaisesRegex(ValueError, "Dynamic physical artifact changed"):
                graph.prepare(self.root, self.products, selected_hosts=(HOST,), out=output, cache_dir=cache_dir)
        self.assertFalse((self.root / "artifacts/current-graph/compiled").exists())

    def test_strict_size_gate_rejects_oversized_genuine_to_parser_native_output(self):
        self.capture("products", [PRODUCT, BASE, LIBRARY], oversized=True)
        with self.assertRaisesRegex(AssertionError, "24577"):
            self.run_prepare()
        self.assertFalse((self.root / "artifacts/current-graph/compiled").exists())

    def test_projected_intermediate_base_with_no_own_immutables_cannot_change_owner(self):
        contexts = self.load()
        contexts["products"]["build"]["output"]["contracts"][PRODUCT.split(":")[0]]["Product"]["evm"]["deployedBytecode"]["immutableReferences"] = {}
        self.data["owners"][BASE] = "hosts"
        with self.assertRaisesRegex(ValueError, "Mixed immutable parent ownership"):
            owners.validate_owner_joins(contexts, self.data["owners"], json.loads(self.products.read_bytes()))

    def test_missing_native_parent_ast_cannot_borrow_analysis(self):
        contexts = self.load()
        del contexts["products"]["build"]["output"]["sources"][BASE.split(":")[0]]["ast"]
        with self.assertRaisesRegex(ValueError, "Missing same-native ancestor"):
            owners.validate_owner_joins(contexts, self.data["owners"], json.loads(self.products.read_bytes()))

    def test_link_target_must_be_library_in_its_own_native_ast(self):
        contexts = self.load()
        contexts["products"]["build"]["output"]["sources"][LIBRARY.split(":")[0]]["ast"]["nodes"][0]["contractKind"] = "contract"
        with self.assertRaisesRegex(ValueError, "not a native library"):
            owners.validate_owner_joins(contexts, self.data["owners"], json.loads(self.products.read_bytes()))

    def test_duplicate_json_keys_and_nonstring_coordinates_refuse(self):
        with self.assertRaisesRegex(ValueError, "Duplicate JSON key"):
            owners.strict_json(b'{"version":1,"version":1}')
        with self.assertRaises(ValueError):
            owners.coordinate(123)
        with self.assertRaises(ValueError):
            owners.owner_manifest([], {}, (), CREATION)

    def test_literal_artifact_inventory_includes_inherited_source_and_creation(self):
        contexts = self.load()
        build = contexts["hosts"]["build"]
        analysis = contexts["hosts"]["analysis"]
        for output in (build["output"], analysis["output"]):
            output["sources"][graph.CREATION_SOURCE]["ast"]["nodes"][0]["nodes"].append(
                {"nodeType": "Literal", "kind": "string", "value": PRODUCT})
        self.assertEqual(owners.literal_artifact_inventory(contexts, self.data["owners"])[PRODUCT], [graph.CREATION_SOURCE])
        del self.data["owners"][PRODUCT]
        with self.assertRaisesRegex(ValueError, "Missing literal artifact owners"):
            owners.literal_artifact_inventory(contexts, self.data["owners"])

    def test_mixed_semantic_settings_and_prelinked_libraries_refuse(self):
        for replacement in ({"metadata": {"appendCBOR": True, "bytecodeHash": "ipfs"}},
                            {"libraries": {"Lib.sol": {"L": "0x123"}}}):
            contexts = self.load()
            contexts["hosts"]["build"]["input"]["settings"].update(replacement)
            with self.assertRaisesRegex(ValueError, "compiler settings differ"):
                owners.validate_owner_joins(contexts, self.data["owners"], json.loads(self.products.read_bytes()))
        contexts = self.load()
        for context in contexts.values():
            context["build"]["input"]["settings"]["libraries"] = {"Lib.sol": {"L": "0x123"}}
        with self.assertRaisesRegex(ValueError, "Prelinked"):
            owners.validate_owner_joins(contexts, self.data["owners"], json.loads(self.products.read_bytes()))

    def test_original_evidence_cannot_overlap_managed_projection_destinations(self):
        contexts = self.load()
        contexts["hosts"]["out"] = self.root / "artifacts/current-graph"
        with self.assertRaisesRegex(ValueError, "overlaps original native evidence"):
            owners.validate_destinations(self.root / "artifacts/current-graph", self.root, contexts)

    def test_python_optimized_mode_refuses_before_filesystem_work(self):
        with mock.patch.dict("os.environ", {"PYTHONOPTIMIZE": "1"}):
            with self.assertRaisesRegex(ValueError, "enabled Python assertions"):
                self.run_prepare()

    def test_unprojected_interface_ancestor_may_remain_analysis_only(self):
        contexts = self.load()
        contract = contexts["products"]["build"]["output"]["sources"][PRODUCT.split(":")[0]]["ast"]["nodes"][-1]
        contract["linearizedBaseContracts"].append(9999)
        contexts["products"]["analysis"]["output"]["sources"][BASE.split(":")[0]]["ast"]["nodes"].append(
            {"nodeType": "ContractDefinition", "id": 9999, "name": "IUnprojected", "contractKind": "interface", "nodes": []})
        owners.validate_owner_joins(contexts, self.data["owners"], json.loads(self.products.read_bytes()))

    def test_embedded_concrete_dependency_requires_same_native_owner(self):
        contexts = self.load()
        contract = contexts["hosts"]["build"]["output"]["sources"][graph.CREATION_SOURCE]["ast"]["nodes"][0]
        child = contexts["hosts"]["analysis"]["output"]["sources"][PRODUCT.split(":")[0]]["ast"]["nodes"][-1]
        contract["contractDependencies"] = [child["id"]]
        with self.assertRaisesRegex(ValueError, "Mixed embedded construction ownership"):
            owners.validate_owner_joins(contexts, self.data["owners"], json.loads(self.products.read_bytes()))
        del self.data["owners"][PRODUCT]
        with self.assertRaisesRegex(ValueError, "Missing embedded construction owner"):
            owners.validate_owner_joins(contexts, self.data["owners"], json.loads(self.products.read_bytes()))

    def test_end_recheck_catches_cache_and_physical_mutation(self):
        context = self.load()["products"]
        path = next(iter(context["physical"])); path.write_bytes(path.read_bytes() + b" ")
        with self.assertRaisesRegex(ValueError, "Physical artifact changed"):
            owners.recheck_context(self.root, context)


if __name__ == "__main__":
    unittest.main()

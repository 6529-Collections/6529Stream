"""Synthetic compiler products in a local Git repository; no compiler or chain."""
from copy import deepcopy
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from . import token_dossier_manifest as composition


class TokenDossierManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.git_temporary = tempfile.TemporaryDirectory()
        cls.repository = Path(cls.git_temporary.name)
        cls.names = (*composition.PROJECTION_PRODUCTS, "StreamCore", composition.OWNER,
                     "OwnerBook", "Shared", "DeploymentOnly", "CRLFSource")
        cls.sources = {name: composition.OWNER_SOURCE if name == composition.OWNER else "smart-contracts/" + name + ".sol"
                       for name in cls.names}
        cls.contents = {source: ("contract " + name + " {}" + ("\r\n" if name == "CRLFSource" else "\n")).encode()
                        for name, source in cls.sources.items()}
        for source, raw in cls.contents.items():
            path = cls.repository / source; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
        cls.git("init", "-q")
        cls.git("-c", "core.autocrlf=false", "add", "smart-contracts")
        cls.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "Synthetic sources")
        cls.revision = cls.git("rev-parse", "HEAD").decode().strip()

    @classmethod
    def tearDownClass(cls):
        cls.git_temporary.cleanup()

    @classmethod
    def git(cls, *args):
        return subprocess.run(["git", "-C", str(cls.repository), *args], capture_output=True, check=True, timeout=30).stdout

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(); self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.base_products = {name: self.product(name, "base") for name in (*composition.PROJECTION_PRODUCTS, "StreamCore")}
        self.new_products = {name: self.product(name, "new") for name in (composition.OWNER, "OwnerBook", "Shared", "DeploymentOnly", "StreamCore")}
        self.link(self.new_products[composition.OWNER], "bytecode", "OwnerBook")
        self.link(self.new_products[composition.OWNER], "deployedBytecode", "Shared")
        self.link(self.new_products["OwnerBook"], "bytecode", "DeploymentOnly")
        self.safe = self.pin_file("safe.json", {"fixture": "synthetic official-Safe boundary bytes"})
        directory = self.root / "projection"; directory.mkdir()
        projection = {"artifactInputKind": "current-native-export", "compilerInputSha256": "11" * 32, "products": {}}
        for name in composition.PROJECTION_PRODUCTS:
            artifact = loads(Path(self.base_products[name]["artifact"]).read_bytes(), maximum=composition.MAX_ARTIFACT)
            value = {"contractName": name, "source": self.sources[name], "compilationHash": projection["compilerInputSha256"],
                "bytecode": artifact["bytecode"], "deployedBytecode": artifact["deployedBytecode"], "immutableDeclarations": {}}
            raw = dumps(value); (directory / (name + ".json")).write_bytes(raw)
            projection["products"][name] = {"source": self.sources[name], "projectionSha256": self.sha(raw), "projectionBytes": len(raw)}
        raw = dumps(projection); (directory / "manifest.json").write_bytes(raw)
        self.base = {"mode": composition.MODE, "products": self.base_products, "safeFixture": self.safe,
            "graphImmutableProjection": {"directory": str(directory), "manifestSha256": self.sha(raw)},
            "tokenComposition": {"version": "1", "joinedCompositionPreviouslyAccepted": False,
                "qualification": "Synthetic unchanged original lineage", "extensionCompilationSources": [{"contentUtf8": "original"}]}}
        self.supplied = {"mode": composition.MODE, "products": self.new_products}
        self.refresh()

    @staticmethod
    def sha(raw):
        return hashlib.sha256(raw).hexdigest()

    def pin_file(self, name, value):
        path = self.root / name; raw = dumps(value); path.write_bytes(raw)
        return {"path": str(path), "sha256": self.sha(raw)}

    def product(self, name, origin):
        path = self.root / origin / (name + ".json"); path.parent.mkdir(exist_ok=True)
        source = self.sources[name]
        artifact = {"abi": [], "metadata": {"compiler": {"version": "0.8.19+synthetic"},
            "settings": {"compilationTarget": {source: name}}, "sources": {source: {"keccak256": keccak256(self.contents[source])}}},
            "bytecode": {"object": "0x" + "00" * 64, "linkReferences": {}},
            "deployedBytecode": {"object": "0x" + "00" * 64, "linkReferences": {}, "immutableReferences": {}}}
        raw = dumps(artifact); path.write_bytes(raw)
        return {"source": source, "artifact": str(path), "sha256": self.sha(raw), "origin": "accepted_mint_graph",
                "acceptedGraphHead": "22" * 20}

    def edit(self, row, change):
        path = Path(row["artifact"]); value = loads(path.read_bytes(), maximum=composition.MAX_ARTIFACT)
        change(value); raw = dumps(value); path.write_bytes(raw); row["sha256"] = self.sha(raw)

    def link(self, row, field, library, *, source=None):
        source = source or self.sources[library]
        def change(value):
            value[field]["linkReferences"] = {source: {library: [{"start": 0, "length": 20}]}}
            value["metadata"]["sources"][source] = {"keccak256": keccak256(self.contents.get(source, b"unknown"))}
        self.edit(row, change)

    def refresh(self):
        self.base_pin = self.pin_file("base.json", self.base)
        self.supplied_pin = self.pin_file("products.json", self.supplied)

    def run_composition(self, *, prepare=False, **options):
        self.refresh()
        function = composition.prepare_manifest if prepare else composition.audit
        with patch("socket.socket", side_effect=AssertionError("offline composition contacted network")):
            raw = function(self.base_pin["path"], self.base_pin["sha256"], self.supplied_pin["path"], self.supplied_pin["sha256"],
                repository=self.repository, source_revision=options.pop("source_revision", self.revision), **options)
        return loads(raw, maximum=composition.MAX_MANIFEST, canonical=True)

    def test_complete_creation_and_runtime_link_closure_is_source_bound_and_prepared(self):
        report = self.run_composition()
        self.assertTrue(report["preparationReady"])
        self.assertTrue(report["closureComplete"])
        self.assertEqual(report["requiredNativeProducts"], [])
        self.assertEqual(set(report["requiredProducts"]), set(self.base_products) | {composition.OWNER, "OwnerBook", "Shared", "DeploymentOnly"})
        self.assertEqual({(row["product"], row["library"]) for row in report["linkClosure"]},
            {(composition.OWNER, "OwnerBook"), (composition.OWNER, "Shared"), ("OwnerBook", "DeploymentOnly")})
        result = self.run_composition(prepare=True)
        for key in ("mode", "tokenComposition", "safeFixture", "graphImmutableProjection"):
            self.assertEqual(result[key], self.base[key])
        self.assertEqual(result["products"]["StreamCore"], self.base_products["StreamCore"])
        self.assertEqual(result["products"][composition.OWNER]["origin"], "token_dossier_additional_link_closure")
        dossier = result["tokenDossierComposition"]
        self.assertEqual(dossier["sourceRevision"], self.revision)
        self.assertEqual(dossier["baseManifestSha256"], self.base_pin["sha256"])
        self.assertEqual(dossier["auditHash"], keccak256(dumps(report)))
        self.assertFalse(dossier["claims"]["actualNativeCaptureAcceptance"])
        self.assertFalse(dossier["claims"]["joinedCompositionPreviouslyAccepted"])

    def test_missing_owner_root_reports_known_minimum_without_inventing_dependencies(self):
        self.new_products.pop(composition.OWNER)
        report = self.run_composition()
        self.assertFalse(report["preparationReady"])
        self.assertFalse(report["closureComplete"])
        self.assertEqual(report["requiredNativeProducts"], [composition.OWNER])
        self.assertEqual(report["missingProducts"][0]["source"], composition.OWNER_SOURCE)
        self.assertNotIn("OwnerBook", report["requiredProducts"])
        with self.assertRaisesRegex(MuseumError, "incomplete/stale"): self.run_composition(prepare=True)

    def test_missing_recursive_library_reports_exact_declared_identity(self):
        self.new_products.pop("OwnerBook")
        report = self.run_composition()
        self.assertEqual(report["requiredNativeProducts"], ["OwnerBook"])
        self.assertEqual(report["missingProducts"][0]["source"], self.sources["OwnerBook"])
        self.assertIn("Shared", report["requiredProducts"])
        self.assertNotIn("DeploymentOnly", report["requiredProducts"])

    def test_stale_import_requires_explicit_replacement_and_cannot_inherit_acceptance_origin(self):
        source = self.sources["Shared"]
        self.edit(self.base_products["StreamCore"], lambda value: value["metadata"]["sources"].update({source: {"keccak256": keccak256(b"old dependency")}}))
        report = self.run_composition()
        self.assertEqual(report["requiredNativeProducts"], ["StreamCore"])
        self.assertTrue(report["staleProducts"][0]["explicitReplacementAvailable"])
        index = int(report["staleProducts"][0]["changedSourceIndices"][0])
        self.assertEqual(report["sourceChecks"][index]["source"], source)
        with self.assertRaisesRegex(MuseumError, "StreamCore"): self.run_composition(prepare=True)
        result = self.run_composition(prepare=True, replacements=["StreamCore"])
        row = result["products"]["StreamCore"]
        self.assertEqual(row["origin"], "token_dossier_explicit_replacement")
        self.assertNotIn("acceptedGraphHead", row)
        self.assertEqual(row["sha256"], self.new_products["StreamCore"]["sha256"])
        self.assertEqual(row["originalProductRow"], self.new_products["StreamCore"])

    def test_explicit_replacement_still_must_match_every_compiler_source(self):
        source = self.sources["StreamCore"]
        self.edit(self.new_products["StreamCore"], lambda value: value["metadata"]["sources"][source].update(keccak256=keccak256(b"stale")))
        report = self.run_composition(replacements=["StreamCore"])
        self.assertEqual(report["requiredNativeProducts"], ["StreamCore"])
        with self.assertRaises(MuseumError): self.run_composition(prepare=True, replacements=["StreamCore"])
        for replacements in (["StreamCore", "StreamCore"], ["Absent"], [composition.OWNER]):
            with self.subTest(replacements=replacements), self.assertRaises(MuseumError): self.run_composition(replacements=replacements)

    def test_lf_transport_is_explicit_and_does_not_normalize_semantic_changes(self):
        source = self.sources["StreamCore"]
        crlf_source = self.sources["CRLFSource"]
        def transported(value):
            value["metadata"]["sources"][source]["keccak256"] = keccak256(self.contents[source].replace(b"\n", b"\r\n"))
            value["metadata"]["sources"][crlf_source] = {"keccak256": keccak256(self.contents[crlf_source].replace(b"\r\n", b"\n"))}
        self.edit(self.base_products["StreamCore"], transported)
        self.assertFalse(self.run_composition()["preparationReady"])
        report = self.run_composition(lf_transport=True)
        self.assertTrue(report["preparationReady"])
        modes = {row["transport"] for row in report["sourceChecks"]}
        self.assertTrue({"git_crlf_to_lf", "git_lf_to_crlf", "exact_git_bytes"} <= modes)
        self.edit(self.base_products["StreamCore"], lambda value: value["metadata"]["sources"][source].update(keccak256=keccak256(b"contract Different {}\r\n")))
        self.assertFalse(self.run_composition(lf_transport=True)["preparationReady"])

    def test_git_commit_not_mutable_worktree_or_branch_is_the_source_authority(self):
        source = self.sources["StreamCore"]; path = self.repository / source; original = path.read_bytes()
        try:
            path.write_bytes(b"uncommitted edit")
            self.assertTrue(self.run_composition()["preparationReady"])
        finally:
            path.write_bytes(original)
        for revision in ("HEAD", self.revision[:8], "f" * 40):
            with self.subTest(revision=revision), self.assertRaises(MuseumError): self.run_composition(source_revision=revision)

    def test_missing_git_source_reports_stale_even_if_worktree_has_a_file(self):
        path = self.repository / "smart-contracts/Uncommitted.sol"; path.write_bytes(b"contract Uncommitted {}")
        self.addCleanup(path.unlink)
        self.edit(self.base_products["StreamCore"], lambda value: value["metadata"]["sources"].update({
            "smart-contracts/Uncommitted.sol": {"keccak256": keccak256(path.read_bytes())}}))
        report = self.run_composition()
        self.assertEqual(report["requiredNativeProducts"], ["StreamCore"])
        self.assertTrue(any(row["status"] == "source_missing_at_revision" for row in report["sourceChecks"]))

    def test_unused_manifest_products_are_not_discovered_read_or_added(self):
        self.new_products["Unused"] = {"source": "smart-contracts/Unused.sol", "artifact": str(self.root / "absent.json"), "sha256": "00" * 32}
        report = self.run_composition()
        self.assertTrue(report["preparationReady"])
        self.assertNotIn("Unused", report["requiredProducts"])

    def test_artifact_manifest_and_safe_pins_cannot_be_recomputed_silently(self):
        self.refresh()
        for which in ("base", "products", "artifact", "safe"):
            path = Path(self.base_pin["path"] if which == "base" else self.supplied_pin["path"] if which == "products"
                else self.new_products[composition.OWNER]["artifact"] if which == "artifact" else self.safe["path"])
            raw = path.read_bytes(); path.write_bytes(b"{}")
            try:
                with self.subTest(which=which), self.assertRaisesRegex(MuseumError, "input pin differs"):
                    composition.audit(self.base_pin["path"], self.base_pin["sha256"], self.supplied_pin["path"], self.supplied_pin["sha256"],
                        repository=self.repository, source_revision=self.revision)
            finally:
                path.write_bytes(raw)

    def test_contract_identity_source_paths_and_link_identity_are_closed(self):
        self.edit(self.new_products[composition.OWNER], lambda value: value["metadata"]["settings"].update(compilationTarget={composition.OWNER_SOURCE: "FakeOwner"}))
        with self.assertRaisesRegex(MuseumError, "source/contract identity"): self.run_composition()
        for source in ("../outside.sol", "/absolute.sol", "C:/absolute.sol", "smart-contracts\\File.sol"):
            with self.subTest(source=source), self.assertRaises(MuseumError): composition._source_path(source)
        self.new_products[composition.OWNER] = self.product(composition.OWNER, "new")
        self.link(self.new_products[composition.OWNER], "bytecode", "Shared", source=self.sources["OwnerBook"])
        with self.assertRaisesRegex(MuseumError, "linked source identity"): self.run_composition()

    def test_projection_templates_and_immutable_offsets_gate_preparation(self):
        name = "StreamArtistOnboardingRegistry"
        self.new_products[name] = self.product(name, "new")
        self.edit(self.new_products[name], lambda value: value["deployedBytecode"].update(object="0x" + "01" * 64))
        report = self.run_composition(replacements=[name])
        self.assertEqual(report["requiredNativeProducts"], [])
        self.assertEqual(report["projectionIssues"], [{"product": name, "reason": "fresh_projection_required_for_changed_template"}])
        with self.assertRaisesRegex(MuseumError, "projection products"): self.run_composition(prepare=True, replacements=[name])
        self.new_products[name] = self.product(name, "new")
        self.edit(self.new_products[name], lambda value: value["deployedBytecode"].update(immutableReferences={"9": [{"start": 0, "length": 32}]}))
        report = self.run_composition(replacements=[name])
        self.assertEqual(report["projectionIssues"][0]["reason"], "fresh_projection_required_for_changed_immutable_offsets")

    def test_projection_and_source_checks_are_deduplicated_and_lineage_is_unpromoted(self):
        report = self.run_composition()
        checks = report["sourceChecks"]
        self.assertEqual(len(checks), len({(row["source"], row["compilerKeccak256"]) for row in checks}))
        for row in report["products"]:
            self.assertTrue(all(int(index) < len(checks) for index in row["compilerSourceIndices"]))
        self.base["tokenComposition"]["joinedCompositionPreviouslyAccepted"] = True
        with self.assertRaisesRegex(MuseumError, "unpromoted token lineage"): self.run_composition()

    def test_explicit_fresh_projection_is_validated_and_original_lineage_is_retained(self):
        name = "StreamArtistOnboardingRegistry"
        self.new_products[name] = self.product(name, "new")
        self.edit(self.new_products[name], lambda value: value["deployedBytecode"].update(object="0x" + "01" * 64))
        old_pin = deepcopy(self.base["graphImmutableProjection"])
        old_directory = Path(old_pin["directory"])
        directory = self.root / "fresh-projection"; directory.mkdir()
        manifest = loads((old_directory / "manifest.json").read_bytes())
        for product in composition.PROJECTION_PRODUCTS:
            value = loads((old_directory / (product + ".json")).read_bytes())
            if product == name:
                artifact = loads(Path(self.new_products[name]["artifact"]).read_bytes())
                value["deployedBytecode"] = artifact["deployedBytecode"]
            raw = dumps(value); (directory / (product + ".json")).write_bytes(raw)
            manifest["products"][product]["projectionSha256"] = self.sha(raw)
            manifest["products"][product]["projectionBytes"] = len(raw)
        raw = dumps(manifest); (directory / "manifest.json").write_bytes(raw)
        pin = {"directory": str(directory), "manifestSha256": self.sha(raw)}
        result = self.run_composition(prepare=True, replacements=[name], projection=pin)
        self.assertEqual(result["graphImmutableProjection"], pin)
        self.assertEqual(result["tokenComposition"], self.base["tokenComposition"])
        self.assertEqual(result["tokenDossierComposition"]["originalGraphImmutableProjection"], old_pin)
        self.assertEqual(result["tokenDossierComposition"]["selectedGraphImmutableProjection"], pin)
        self.assertTrue(result["tokenDossierComposition"]["projectionExplicitlyReplaced"])
        with self.assertRaisesRegex(MuseumError, "input pin differs"):
            self.run_composition(replacements=[name], projection=pin | {"manifestSha256": "00" * 32})
        (directory / (name + ".json")).write_bytes(b"{}")
        with self.assertRaisesRegex(MuseumError, "input pin differs"):
            self.run_composition(replacements=[name], projection=pin)

    def test_missing_pinned_artifact_is_reported_without_replacement_discovery(self):
        Path(self.new_products["OwnerBook"]["artifact"]).unlink()
        report = self.run_composition()
        self.assertEqual(report["requiredNativeProducts"], ["OwnerBook"])
        self.assertEqual(report["missingProducts"][0]["reason"], "pinned_artifact_file_missing")

    def test_cli_audit_writes_canonical_report_and_refuses_overwrite(self):
        self.refresh(); output = self.root / "audit.json"
        argv = ["token-dossier-manifest", "audit", "--base", self.base_pin["path"], "--base-sha256", self.base_pin["sha256"],
            "--products", self.supplied_pin["path"], "--products-sha256", self.supplied_pin["sha256"],
            "--repository", str(self.repository), "--source-revision", self.revision, "--output", str(output)]
        with patch("sys.argv", argv), patch("builtins.print"), patch("socket.socket", side_effect=AssertionError("offline audit network")):
            composition.main()
            first = output.read_bytes()
            with self.assertRaises(FileExistsError): composition.main()
        self.assertEqual(output.read_bytes(), first)
        self.assertTrue(loads(first, maximum=composition.MAX_MANIFEST, canonical=True)["preparationReady"])


if __name__ == "__main__":
    unittest.main()

"""Offline owner-context joins only; synthetic bytes never represent native acceptance."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from .canonical import MuseumError
from .token_native_graph import FACADE, TokenNativeGraphMixin, predicted_runtime


IDENTITY = "StreamArtistIdentityAuthority"
MODULE = "StreamModuleBase"
GAS = "StreamGasParameterHost"
ARTIST = "StreamArtistOwner"
sha = lambda raw: hashlib.sha256(raw).hexdigest()
raw = lambda value: json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


class ProjectionOwnersTests(unittest.TestCase):
    def fixture(self, directory, *, legacy=False):
        # Equal AST IDs intentionally name different declarations in independent owners.
        specs = {MODULE: ("a", 11, "manifest"), GAS: ("a", 12, "governor"),
            FACADE: ("a", 13, "core"), ARTIST: ("b", 21 if legacy else 11, "owner"),
            IDENTITY: ("b", 22 if legacy else 12, "registry")}
        manifest = {"artifactInputKind": "current-native-export", "products": {},
            "contexts": {}, "owners": {}}
        if legacy:
            manifest["compilerInputSha256"] = "a" * 64
        else:
            manifest["mode"] = "explicit-native-owners"
        fixture = TokenNativeGraphMixin()
        fixture.products = {}
        fixture.manifest = {"products": {}}
        projections = {}
        for name, (label, ident, variable) in specs.items():
            label = "a" if legacy else label
            context = label * 64
            owner = ("1" if label == "a" else "2") * 64
            source = "smart-contracts/" + name + ".sol"
            ids = [11, 12, 13] if name == FACADE else ([specs[ARTIST][1], ident] if name == IDENTITY else [])
            offsets = {str(i): [{"start": index * 32, "length": 32}] for index, i in enumerate(ids)}
            runtime = "0x" + "00" * max(1, 32 * len(ids))
            native_offsets = {str(int(i) + (100 if legacy else 0)): sites for i, sites in offsets.items()}
            artifact = {"bytecode": {"object": "0x00", "linkReferences": {}},
                "deployedBytecode": {"object": runtime, "linkReferences": {}, "immutableReferences": native_offsets}}
            fixture.products[name] = artifact
            export_hash = sha(raw(artifact))
            fixture.manifest["products"][name] = {"source": source, "sha256": export_hash}
            declaration = {"id": ident, "source": source, "contractName": name, "variable": variable,
                "compilationHash": context, "nodeType": "VariableDeclaration", "mutability": "immutable"}
            value = {"source": source, "contractName": name, "compilationHash": context,
                "currentNativeExportSha256": export_hash, "immutableDeclarations": {str(ident): declaration},
                "bytecode": artifact["bytecode"], "deployedBytecode": artifact["deployedBytecode"] | {"immutableReferences": offsets}}
            projections[name] = value
            payload = raw(value)
            (directory / (name + ".json")).write_bytes(payload)
            row = {"source": source, "projectionSha256": sha(payload), "projectionBytes": len(payload)}
            manifest["products"][name] = row if legacy else row | {"owner": owner}
            manifest["owners"][source + ":" + name] = owner
            context_row = manifest["contexts"].setdefault(owner, {"artifactInputKind": "current-native-export",
                "compilerInputSha256": context, "products": {}})
            context_row["products"][name] = row | {"currentNativeExportSha256": export_hash}
        self.pin(fixture, directory, manifest)
        return fixture, manifest, projections

    def pin(self, fixture, directory, manifest):
        payload = raw(manifest)
        (directory / "manifest.json").write_bytes(payload)
        fixture.manifest["graphImmutableProjection"] = {"directory": str(directory), "manifestSha256": sha(payload)}

    def update_projection(self, fixture, directory, manifest, name, value):
        payload = raw(value)
        (directory / (name + ".json")).write_bytes(payload)
        row = manifest["products"][name]
        row.update(projectionSha256=sha(payload), projectionBytes=len(payload))
        manifest["contexts"][row["owner"]]["products"][name].update(
            projectionSha256=sha(payload), projectionBytes=len(payload))
        self.pin(fixture, directory, manifest)

    def test_colliding_ast_ids_remain_separate_for_each_real_owner_context(self):
        with tempfile.TemporaryDirectory() as tmp:
            f, _, _ = self.fixture(Path(tmp))
            f._load_token_graph_projection()
            self.assertEqual(f.token_declaration_ids[FACADE], {(MODULE, "manifest"): "11", (GAS, "governor"): "12", (FACADE, "core"): "13"})
            self.assertEqual(f.token_declaration_ids[IDENTITY], {(ARTIST, "owner"): "11", (IDENTITY, "registry"): "12"})
            values = {(ARTIST, "owner"): 7, (IDENTITY, "registry"): 9}
            self.assertEqual(predicted_runtime(f.products, IDENTITY, bytes(64), values,
                declaration_ids=f.token_declaration_ids[IDENTITY]), (7).to_bytes(32, "big") + (9).to_bytes(32, "big"))

    def test_legacy_single_compilation_offset_translation_is_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            f, _, _ = self.fixture(Path(tmp), legacy=True)
            f._load_token_graph_projection()
            self.assertEqual(f.token_declaration_ids[IDENTITY], {(ARTIST, "owner"): "121", (IDENTITY, "registry"): "122"})

    def test_wrong_product_owner_and_wrong_context_row_are_refused(self):
        for change, message in ((lambda m: m["owners"].__setitem__("smart-contracts/" + ARTIST + ".sol:" + ARTIST, "1" * 64), "product owner"),
                (lambda m: m["contexts"]["2" * 64]["products"][ARTIST].__setitem__("source", "wrong.sol"), "owner row")):
            with self.subTest(message=message), tempfile.TemporaryDirectory() as tmp:
                directory = Path(tmp); f, m, _ = self.fixture(directory)
                change(m); self.pin(f, directory, m)
                with self.assertRaisesRegex(MuseumError, message): f._load_token_graph_projection()

    def test_unknown_owner_mode_cannot_fall_back_to_legacy_validation(self):
        for mode in (None, "explicit-native-owner", "legacy"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as tmp:
                directory = Path(tmp); f, m, _ = self.fixture(directory, legacy=True)
                m["mode"] = mode
                self.pin(f, directory, m)
                with self.assertRaisesRegex(MuseumError, "unsupported graph projection owner mode"):
                    f._load_token_graph_projection()

    def test_byte_identical_template_with_different_native_export_pin_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            f, _, _ = self.fixture(Path(tmp))
            f.manifest["products"][ARTIST]["sha256"] = "0" * 64
            with self.assertRaisesRegex(MuseumError, "native export owner"): f._load_token_graph_projection()

    def test_explicit_owner_cannot_translate_foreign_immutable_ids_by_equal_offsets(self):
        with tempfile.TemporaryDirectory() as tmp:
            f, _, _ = self.fixture(Path(tmp))
            refs = f.products[IDENTITY]["deployedBytecode"]["immutableReferences"]
            f.products[IDENTITY]["deployedBytecode"]["immutableReferences"] = {str(int(k) + 100): v for k, v in refs.items()}
            with self.assertRaisesRegex(MuseumError, "same-owner immutable"): f._load_token_graph_projection()

    def test_missing_same_owner_declaration_cannot_borrow_equal_id_from_other_owner(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp); f, m, p = self.fixture(directory)
            value = copy.deepcopy(p[ARTIST]); value["immutableDeclarations"] = {}
            self.update_projection(f, directory, m, ARTIST, value)
            with self.assertRaisesRegex(MuseumError, "same-owner declaration closure"): f._load_token_graph_projection()

    def test_projection_compilation_and_original_export_hash_are_independently_pinned(self):
        for field, value, message in (("compilationHash", "a" * 64, "compilation identity"),
                ("currentNativeExportSha256", "0" * 64, "same-owner immutable")):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as tmp:
                directory = Path(tmp); f, m, p = self.fixture(directory)
                changed = copy.deepcopy(p[ARTIST]); changed[field] = value
                self.update_projection(f, directory, m, ARTIST, changed)
                with self.assertRaisesRegex(MuseumError, message): f._load_token_graph_projection()


if __name__ == "__main__":
    unittest.main()

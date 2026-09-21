"""Focused transport and source-closure controls for preserved replay tools."""
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from tools.preservation import reference_package as burn

from . import preserved_tool_replay_v1 as replay
from . import preserved_tool_source_v1 as source
from .canonical import MuseumError, keccak256


def declarations():
    pins = [{"name": "cpython-3.13-runtime", "role": "runtime",
        "uri": "urn:sha256:" + "11" * 32, "sha256": "11" * 32, "bytes": 1}]
    prerequisites = [{"name": "CPython", "version": "3.13.7", "platform": "windows-x86_64",
        "included": False, "pin": "cpython-3.13-runtime",
        "qualification": "Synthetic focused-test pin; no publisher authentication."}]
    return pins, prerequisites


def vectors():
    body = b"{}"
    return replay.vector_inputs([{"id": "packet", "kind": "packet_v10",
        "files": {"manifest.json": body}, "manifestHash": keccak256(body)}])


class PreservedToolSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = TemporaryDirectory(prefix="stream-source-test-")
        cls.root = Path(cls.temporary.name)
        cls.package = cls.root / "package"
        pins, prerequisites = declarations()
        repository = Path(__file__).resolve().parents[2]
        cls.revision = source._git(repository, "rev-parse", "HEAD").decode("ascii").strip()
        cls.result = source.build(repository, cls.package, source_revision=cls.revision,
            vectors=vectors(), external_pins=pins, licenses=[], prerequisites=prerequisites)
        cls.pin = source._sha((cls.package / "parts.json").read_bytes())

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def test_exact_git_closure_transport_and_categories_verify_without_execution(self):
        checked = source.verify(self.package, self.pin)
        self.assertEqual(checked.archive_bytes, (self.package / "runtime.zip").read_bytes())
        self.assertEqual(checked.report["archiveKeccak256"], keccak256(checked.archive_bytes))
        self.assertTrue(checked.report["actualClosureVerified"])
        self.assertFalse(checked.report["claims"]["restoredCodeExecuted"])
        files = dict(checked.restored_files)
        self.assertIn("tools/museum/acquisition_canonical_v10.py", files)
        self.assertIn("tools/museum/canonical_object_dossier_v3.py", files)
        self.assertIn("tools/museum/repository_exchange.py", files)
        self.assertIn("tools/preservation/reference_package.py", files)
        self.assertIn("schemas/museum/account-profile/RFC8785_JCS.json", files)
        self.assertIn("schemas/records/standards/conservation/language-subtag-registry.txt.gz", files)
        self.assertEqual(checked.report["runtimeDataFileCount"],
            str(len(checked.source_manifest["categories"]["data"])))
        self.assertNotIn("PACKAGE.json", files)
        self.assertEqual(set(dict(checked.files)), set(path.name for path in self.package.iterdir()))

    def test_restore_publishes_original_tree_without_transport_internal_manifest(self):
        destination = self.root / "restored"
        checked = source.restore_verified(self.package, self.pin, destination)
        self.assertEqual((destination / "manifest/source.json").read_bytes(),
            dict(checked.restored_files)["manifest/source.json"])
        self.assertFalse((destination / "PACKAGE.json").exists())

    def test_changed_part_or_extra_transport_entry_refuses(self):
        with TemporaryDirectory(prefix="stream-source-change-") as temporary:
            changed = Path(temporary) / "package"; changed.mkdir()
            for path in self.package.iterdir():
                (changed / path.name).write_bytes(path.read_bytes())
            part = changed / "part-000000.bin"
            body = bytearray(part.read_bytes()); body[-1] ^= 1; part.write_bytes(body)
            with self.assertRaisesRegex(MuseumError, "part bytes"):
                source.verify(changed, self.pin)
        with TemporaryDirectory(prefix="stream-source-extra-") as temporary:
            changed = Path(temporary) / "package"; changed.mkdir()
            for path in self.package.iterdir():
                (changed / path.name).write_bytes(path.read_bytes())
            (changed / "ignored.bin").write_bytes(b"ignored")
            with self.assertRaises(MuseumError):
                source.verify(changed, self.pin)

    def test_actual_closure_not_a_caller_manifest_claim(self):
        restored = dict(self.result.restored_files)
        manifest = burn.canonical(self.result.source_manifest)
        restored["tools/museum/unreachable.py"] = b"VALUE = 1\n"
        changed = dict(self.result.source_manifest)
        rows = list(changed["categories"]["source"])
        body = restored["tools/museum/unreachable.py"]
        rows.append({"path": "tools/museum/unreachable.py", "bytes": len(body),
            "sha256": source._sha(body)})
        changed["categories"] = dict(changed["categories"]); changed["categories"]["source"] = sorted(
            rows, key=lambda row: row["path"])
        restored["manifest/source.json"] = burn.canonical(changed)
        with TemporaryDirectory(prefix="stream-source-repack-") as temporary:
            root = Path(temporary) / "root"; root.mkdir()
            for path, raw in restored.items():
                target = root / path; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(raw)
            package = Path(temporary) / "package"
            declaration = {"profile": source.NAME, "profileHash": source.PROFILE_HASH,
                "sourceRevision": self.result.source_manifest["sourceRevision"],
                "sourceManifestSha256": source._sha(restored["manifest/source.json"]),
                "archiveKind": "V10_V3_EXACT_SOURCE_AND_REPLAY_INPUTS"}
            burn.package_tree(root, package, declaration)
            pin = source._sha((package / "parts.json").read_bytes())
            with self.assertRaisesRegex(MuseumError, "actual import closure"):
                source.verify(package, pin)

    def test_category_rows_are_a_unique_typed_denominator(self):
        restored = dict(self.result.restored_files)
        changed = dict(self.result.source_manifest)
        changed["categories"] = dict(changed["categories"])
        changed["categories"]["locks"] = list(changed["categories"]["locks"])
        changed["categories"]["locks"].append(dict(changed["categories"]["locks"][-1]))
        changed["categories"]["locks"].sort(key=lambda row: row["path"])
        restored["manifest/source.json"] = burn.canonical(changed)
        with TemporaryDirectory(prefix="stream-source-duplicate-") as temporary:
            root = Path(temporary) / "root"; root.mkdir()
            for path, raw in restored.items():
                target = root / path; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(raw)
            package = Path(temporary) / "package"
            declaration = {"profile": source.NAME, "profileHash": source.PROFILE_HASH,
                "sourceRevision": self.result.source_manifest["sourceRevision"],
                "sourceManifestSha256": source._sha(restored["manifest/source.json"]),
                "archiveKind": "V10_V3_EXACT_SOURCE_AND_REPLAY_INPUTS"}
            burn.package_tree(root, package, declaration)
            pin = source._sha((package / "parts.json").read_bytes())
            with self.assertRaisesRegex(MuseumError, "category order"):
                source.verify(package, pin)

        transport = source.verify_transport(self.package, self.pin)
        changed = dict(self.result.source_manifest)
        changed["categories"] = dict(changed["categories"])
        changed["categories"]["source"] = [dict(row)
            for row in changed["categories"]["source"]]
        changed["categories"]["source"][0]["bytes"] = False
        raw = burn.canonical(changed)
        files = dict(transport.restored_files); files["manifest/source.json"] = raw
        declaration = dict(transport.package_manifest["declaration"])
        declaration["sourceManifestSha256"] = source._sha(raw)
        package_manifest = dict(transport.package_manifest)
        package_manifest["declaration"] = declaration
        malformed = source.Transport(transport.files, tuple(sorted(files.items())),
            transport.archive_bytes, package_manifest, transport.report)
        with self.assertRaisesRegex(MuseumError, "category byte count"):
            source._verify_restored(malformed)

    def test_missing_local_import_cannot_shrink_the_actual_closure(self):
        files = {
            "tools/__init__.py": b"",
            "tools/example/__init__.py": b"",
            "tools/example/main.py": b"from . import missing\n",
        }
        with self.assertRaisesRegex(MuseumError, "local import absent"):
            source._closure(set(files), lambda path: files[path], ("tools.example.main",))

    def test_required_dynamic_data_cannot_be_coherently_omitted(self):
        transport = source.verify_transport(self.package, self.pin)
        missing = source.REQUIRED_DATA_PATHS[0]
        changed = dict(self.result.source_manifest)
        changed["categories"] = dict(changed["categories"])
        changed["categories"]["data"] = [row for row in changed["categories"]["data"]
            if row["path"] != missing]
        raw = burn.canonical(changed)
        files = dict(transport.restored_files)
        files.pop(missing); files["manifest/source.json"] = raw
        declaration = dict(transport.package_manifest["declaration"])
        declaration["sourceManifestSha256"] = source._sha(raw)
        package_manifest = dict(transport.package_manifest)
        package_manifest["declaration"] = declaration
        malformed = source.Transport(transport.files, tuple(sorted(files.items())),
            transport.archive_bytes, package_manifest, transport.report)
        with self.assertRaisesRegex(MuseumError, "runtime data prefix denominator"):
            source._verify_restored(malformed)

    def test_vector_descriptor_has_no_ignored_occurrences(self):
        invalid = vectors(); invalid["ignored.json"] = b"{}"
        pins, prerequisites = declarations()
        with self.assertRaisesRegex(MuseumError, "vector order or denominator"):
            source.build(Path(__file__).resolve().parents[2], self.root / "bad-vector",
                vectors=invalid, external_pins=pins, licenses=[], prerequisites=prerequisites)

    def test_external_pin_and_cpython_prerequisite_are_mandatory(self):
        pins, prerequisites = declarations()
        with self.assertRaisesRegex(MuseumError, "external pins required"):
            source.build(Path(__file__).resolve().parents[2], self.root / "bad-pin",
                vectors=vectors(), external_pins=[], licenses=[], prerequisites=prerequisites)
        with self.assertRaisesRegex(MuseumError, "CPython 3.13"):
            source.build(Path(__file__).resolve().parents[2], self.root / "bad-runtime",
                vectors=vectors(), external_pins=pins, licenses=[], prerequisites=[{
                    **prerequisites[0], "name": "Other", "version": "1"}])

    def test_preflight_bounds_internal_package_before_restore(self):
        with TemporaryDirectory(prefix="stream-source-inner-") as temporary:
            root = Path(temporary) / "root"; root.mkdir(); (root / "a").write_bytes(b"")
            package = Path(temporary) / "package"
            burn.package_tree(root, package, {"large": "x" * 2048})
            pin = source._sha((package / "parts.json").read_bytes())
            with patch.object(source, "MAX_MEMBER", 1024):
                with self.assertRaisesRegex(MuseumError, "ZIP member metadata"):
                    source.verify_transport(package, pin)
            with patch.object(source, "MAX_EXPANDED", 0):
                with self.assertRaisesRegex(MuseumError, "expanded byte bound"):
                    source.verify_transport(package, pin)


if __name__ == "__main__":
    unittest.main()

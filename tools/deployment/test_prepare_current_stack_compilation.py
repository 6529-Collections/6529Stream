"""Retained compiler evidence must survive preparation of a writable demo cache."""

import json
import tempfile
import unittest
from pathlib import Path

from tools.deployment import generate_current_stack_artifacts as exporter
from tools.deployment.prepare_current_stack_compilation import inventory, prepare
from tools.deployment.test_current_stack_artifacts import fixture


def paired_fixture(root: Path):
    out, config, _ = fixture(root)
    cache = root / "cache"
    cache.mkdir()
    (cache / "solidity-files-cache.json").write_bytes(exporter.encoded({
        "paths": {"artifacts": out.as_posix(), "build_infos": (out / "build-info").as_posix(),
                  "sources": "smart-contracts", "tests": "test/current", "scripts": "script/current"},
        "builds": ["one"], "profiles": {"retained": {"viaIR": True}},
    }))
    return out, cache, config


class CurrentCompilationPreparationTests(unittest.TestCase):
    def test_relative_cache_paths_bind_to_repo_root_outside_process_cwd(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertNotEqual(root.resolve(), Path.cwd().resolve())
            out, cache, config = paired_fixture(root)
            path = cache / "solidity-files-cache.json"
            data = exporter.load(path)
            data["paths"]["artifacts"] = out.relative_to(root).as_posix()
            data["paths"]["build_infos"] = (out / "build-info").relative_to(root).as_posix()
            path.write_bytes(exporter.encoded(data))
            result = prepare(root, out, cache, root / "demo", config)
            self.assertEqual(result["artifact_directory"], (root / "demo/out").resolve().as_posix())

    def test_copy_preserves_evidence_and_rebases_only_output_locations(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            out, cache, config = paired_fixture(root)
            before = inventory(out), inventory(cache)
            result = prepare(root, out, cache, root / "demo", config)
            self.assertEqual((inventory(out), inventory(cache)), before)
            self.assertEqual(inventory(root / "demo/out"), before[0])
            old = exporter.load(cache / "solidity-files-cache.json")
            copied = exporter.load(root / "demo/cache/solidity-files-cache.json")
            copied["paths"]["artifacts"] = old["paths"]["artifacts"]
            copied["paths"]["build_infos"] = old["paths"]["build_infos"]
            self.assertEqual(copied, old)
            self.assertEqual(result["source_count"], 2)
            self.assertTrue((root / "demo/compilation-workspace.json").is_file())

    def test_stale_source_fails_before_creating_destination(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            out, cache, config = paired_fixture(root)
            (root / "smart-contracts/core/Example.sol").write_text("contract Different {}")
            with self.assertRaisesRegex(exporter.CurrentArtifactError, "source is stale"):
                prepare(root, out, cache, root / "demo", config)
            self.assertFalse((root / "demo").exists())

    def test_mismatched_cache_or_profile_cannot_be_relabelled(self):
        for field, value in (("artifacts", "different/out"), ("tests", "test"), ("scripts", "script")):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                out, cache, config = paired_fixture(root)
                path = cache / "solidity-files-cache.json"
                data = exporter.load(path)
                data["paths"][field] = value
                path.write_bytes(exporter.encoded(data))
                with self.assertRaises(exporter.CurrentArtifactError):
                    prepare(root, out, cache, root / "demo", config)
                self.assertFalse((root / "demo").exists())

    def test_existing_or_overlapping_destinations_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            out, cache, config = paired_fixture(root)
            before = inventory(out), inventory(cache)
            for destination in (out, cache, out / "nested", cache / "nested", root):
                with self.subTest(destination=destination), self.assertRaises(exporter.CurrentArtifactError):
                    prepare(root, out, cache, destination, config)
            self.assertEqual((inventory(out), inventory(cache)), before)

    def test_missing_build_info_cannot_be_copied_as_reusable_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            out, cache, config = paired_fixture(root)
            path = cache / "solidity-files-cache.json"
            data = json.loads(path.read_text())
            data["builds"] = ["missing"]
            path.write_bytes(exporter.encoded(data))
            with self.assertRaisesRegex(exporter.CurrentArtifactError, "missing or invalid build-info"):
                prepare(root, out, cache, root / "demo", config)


if __name__ == "__main__":
    unittest.main(verbosity=2)

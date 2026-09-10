"""Ensure offline checker imports stay inside the materialized release snapshot."""

from pathlib import Path
import sys
import tempfile
import types
import unittest

from tools.build import verify_release_artifacts as verifier


class SnapshotPackageLoadingTests(unittest.TestCase):
    def write_snapshot(self, root: Path, *, helper: bool = True) -> None:
        files = {
            "tools/__init__.py": 'ORIGIN = "snapshot"\n',
            "tools/protocol/__init__.py": 'ORIGIN = "snapshot"\n',
            "tools/protocol/check_governed_parameter_inventory.py":
                'from tools.protocol import check_governed_parameter_identifiers as helper\n'
                'BOUND_VALUE = helper.VALUE\n',
        }
        if helper:
            files["tools/protocol/check_governed_parameter_identifiers.py"] = 'VALUE = "bound bytes"\n'
        for relative, content in files.items():
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")

    def test_preloaded_parent_and_child_cannot_redirect_snapshot_imports(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_snapshot(root)
            originals = {name: value for name, value in sys.modules.items() if name == "tools" or name.startswith("tools.")}
            original_path = list(sys.path)
            poisoned_name = "tools.protocol.check_governed_parameter_identifiers"
            previous = sys.modules.get(poisoned_name)
            poisoned = types.ModuleType(poisoned_name)
            poisoned.VALUE = "unbound live checkout"
            poisoned.__file__ = str(root.parent / "live.py")
            sys.modules[poisoned_name] = poisoned
            try:
                checker = verifier._load_snapshot_checker(root, "check_governed_parameter_inventory")
                self.assertEqual(checker.BOUND_VALUE, "bound bytes")
                self.assertIs(sys.modules[poisoned_name], poisoned)
                self.assertEqual(sys.path, original_path)
                for name, module in originals.items():
                    if name != poisoned_name:
                        self.assertIs(sys.modules[name], module)
            finally:
                if previous is None:
                    sys.modules.pop(poisoned_name, None)
                else:
                    sys.modules[poisoned_name] = previous

    def test_missing_bound_helper_fails_and_restores_import_state(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_snapshot(root, helper=False)
            original_path = list(sys.path)
            originals = {name: value for name, value in sys.modules.items() if name == "tools" or name.startswith("tools.")}
            with self.assertRaises(verifier.ReleaseArtifactVerificationError):
                verifier._load_snapshot_checker(root, "check_governed_parameter_inventory")
            self.assertEqual(sys.path, original_path)
            after = {name: value for name, value in sys.modules.items() if name == "tools" or name.startswith("tools.")}
            self.assertEqual(after, originals)

    def test_preloaded_name_does_not_hide_an_unreviewed_snapshot_import(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_snapshot(root)
            source = root / "tools/protocol/check_governed_parameter_inventory.py"
            source.write_text(source.read_text(encoding="utf-8") + "from tools.protocol import snapshot_extra\n", encoding="utf-8")
            (root / "tools/protocol/snapshot_extra.py").write_text("VALUE = 1\n", encoding="utf-8")
            name = "tools.protocol.snapshot_extra"
            previous = sys.modules.get(name)
            preloaded = types.ModuleType(name)
            sys.modules[name] = preloaded
            try:
                with self.assertRaisesRegex(verifier.ReleaseArtifactVerificationError, "unreviewed materialized"):
                    verifier._load_snapshot_checker(root, "check_governed_parameter_inventory")
                self.assertIs(sys.modules[name], preloaded)
            finally:
                if previous is None:
                    sys.modules.pop(name, None)
                else:
                    sys.modules[name] = previous


if __name__ == "__main__":
    unittest.main()

"""Check isolation, immutable inputs and failure behavior of historical artist checks."""

import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

from tools.protocol import run_frozen_artist_checks as runner
from tools.protocol import check_artist_operation_extension as current

ROOT = Path(__file__).resolve().parents[2]


class FrozenArtistChecksTests(unittest.TestCase):
    def test_archive_rejects_unsafe_paths_and_links(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name in ("/absolute", "../outside", "docs/../../outside", "C:/drive", "C:drive", "//server/share", "a\\b", "./a", "a//b", ".git/config"):
                with self.subTest(name=name), self.assertRaises(runner.HistoricalCheckError):
                    runner.validate_member(tarfile.TarInfo(name), root)
            for kind in (tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.CHRTYPE, tarfile.FIFOTYPE):
                member = tarfile.TarInfo("docs/link")
                member.type = kind
                with self.subTest(kind=kind), self.assertRaises(runner.HistoricalCheckError):
                    runner.validate_member(member, root)

    def test_archive_validates_every_member_before_writing(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root / "input.tar"
            destination = root / "tree"
            destination.mkdir()
            with tarfile.open(archive, "w") as output:
                valid = tarfile.TarInfo("docs/valid.txt")
                valid.size = 1
                output.addfile(valid, io.BytesIO(b"a"))
                output.addfile(tarfile.TarInfo("../outside"))
            with self.assertRaises(runner.HistoricalCheckError):
                runner.extract_archive(archive, destination)
            self.assertEqual(list(destination.iterdir()), [])

    def test_preserved_inputs_reject_current_and_baseline_mutation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            live, old = root / "live", root / "old"
            live.mkdir()
            old.mkdir()
            for directory in (live, old):
                (directory / "packet.json").write_bytes(b"frozen")
                (directory / "checker.py").write_bytes(b"same checker")
            with patch.object(runner, "HISTORICAL", {"packet.json": hashlib.sha256(b"frozen").hexdigest()}), patch.object(runner, "PRESERVED_TOOLS", ("checker.py",)):
                runner.validate_preserved_inputs(live, old)
                for directory in (live, old):
                    (directory / "packet.json").write_bytes(b"changed")
                    with self.assertRaises(runner.HistoricalCheckError):
                        runner.validate_preserved_inputs(live, old)
                    (directory / "packet.json").write_bytes(b"frozen")
                (live / "checker.py").write_bytes(b"ignored new checker")
                with self.assertRaises(runner.HistoricalCheckError):
                    runner.validate_preserved_inputs(live, old)

    def test_unknown_gate_rejected_before_process_launch(self):
        with patch.object(runner.subprocess, "check_output") as called:
            for name in ("tools.other.module", "../current", "matrix; echo unsafe"):
                with self.assertRaises(runner.HistoricalCheckError):
                    runner.run_gate(Path.cwd(), name)
            called.assert_not_called()

    def test_current_design_mutation_is_not_hidden_by_historical_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            live, baseline = Path(temporary) / "live", Path(temporary) / "baseline"
            for directory in (live, baseline):
                for relative in (*runner.HISTORICAL, *runner.PRESERVED_TOOLS, current.MANIFEST.as_posix()):
                    target = directory / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(ROOT / relative, target)
            # Current prose is allowed to evolve; frozen packets and code are not.
            (live / "docs/stream-artist-authority.md").write_bytes(b"Current clarified authority")
            (baseline / "docs/stream-artist-authority.md").write_bytes(b"Historical authority")
            runner.validate_preserved_inputs(live, baseline)
            current.check(live)
            manifest = json.loads((live / current.MANIFEST).read_bytes())
            manifest["status"] = "IMPLEMENTED"
            (live / current.MANIFEST).write_bytes(json.dumps(manifest).encode("utf-8"))
            runner.validate_preserved_inputs(live, baseline)
            with self.assertRaisesRegex(current.ExtensionError, "cannot claim implementation"):
                current.check(live)

    def test_entrypoints_keep_current_checks_outside_the_historical_runner(self):
        for relative in ("Makefile", "scripts/check.sh", "scripts/check.ps1", ".github/workflows/ci.yml"):
            source = (ROOT / relative).read_text(encoding="utf-8")
            with self.subTest(path=relative):
                for alias, old in runner.GATES.items():
                    self.assertRegex(source, rf'run_frozen_artist_checks[" ]+{alias}')
                    self.assertNotIn(f"tools.protocol.test_{old}", source)
                    self.assertNotIn(f"tools.protocol.check_{old}", source)
                self.assertIn("tools.protocol.test_frozen_artist_checks", source)
                self.assertIn("tools.protocol.test_artist_operation_extension", source)
                self.assertIn("tools.protocol.check_artist_operation_extension", source)
                self.assertIn("tools.build.check_solidity_source_layout", source)
                self.assertIn("tools.build.check_abi_compatibility", source)
                self.assertIn("forge test", source)
                self.assertNotIn("stream-artist57-", source)
                self.assertNotIn("--repo-root", source)

    def test_baseline_mismatch_has_no_archive_or_fallback(self):
        with patch.object(runner.subprocess, "check_output", return_value="0" * 40), patch.object(runner.subprocess, "run") as called:
            with self.assertRaises(runner.HistoricalCheckError):
                runner.run_gate(Path.cwd(), "matrix")
            called.assert_not_called()

    def test_failure_propagates_and_temporary_tree_is_removed(self):
        paths = []
        original_cwd = Path.cwd()
        def fake_run(argv, **kwargs):
            if argv[0] == "git":
                return subprocess.CompletedProcess(argv, 0)
            paths.append(kwargs["cwd"])
            self.assertEqual(argv[1:], ["-m", "tools.protocol.test_artist_semantic_owner_matrix"])
            self.assertNotIn("PYTHONPATH", kwargs["env"])
            return subprocess.CompletedProcess(argv, 7)
        with patch.object(runner.subprocess, "check_output", return_value=runner.BASELINE), patch.object(runner.subprocess, "run", side_effect=fake_run), patch.object(runner, "extract_archive"), patch.object(runner, "validate_preserved_inputs"):
            self.assertEqual(runner.run_gate(original_cwd, "matrix"), 7)
        self.assertEqual(Path.cwd(), original_cwd)
        self.assertEqual(len(paths), 1)
        self.assertFalse(paths[0].exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)

"""Developer repository exchange over complete, independently pinned bags.

All fixtures are local synthetic transports unless a test explicitly names the
retained dossier fixture.  They do not establish source authority or repository
acceptance.
"""
from copy import deepcopy
from hashlib import sha256
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .bagit import build_bag, read_tree, verify_bag, verify_bag_files, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .hydration import hydrate_bag
from .ocfl import build_version
from .repository_exchange import export_bag, import_version, inspect_object
from .test_bagit import description, remote_description


def _standard(predecessor=None, script=b"draw(1);"):
    d, payloads = description({"render/script.js": script}, predecessor or "0x" + "00" * 32)
    return build_bag(dumps(d), payloads)


def _semantic_bag(*, corrupt=False, predecessor=None):
    from .package_v2 import build_fixture_package
    from .test_package_v2 import ROOT, inputs

    args, pins = inputs()
    package = build_fixture_package(*args, root=ROOT, **pins)
    nested = {"semantic/" + name: raw for name, raw in package.files}
    nested["semantic/manifest.json"] = package.manifest
    if corrupt:
        name = next(name for name in sorted(nested) if name != "semantic/manifest.json")
        nested[name] += b"!"
    d, payloads = description(nested, predecessor or "0x" + "00" * 32)
    d["semanticPackages"] = [{"prefix": "semantic", "manifestHash": package.manifest_hash}]
    return build_bag(dumps(d), payloads)


class RepositoryExchangeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.first_bag = _standard()
        self.first_path = self.root / "bag-v1"
        write_tree(self.first_bag.files, self.first_path)

    def tearDown(self):
        self.temp.cleanup()

    def export_first(self):
        output = self.root / "object-v1"
        result = export_bag(self.first_path, self.first_bag.manifest_hash, output,
            created="2026-09-20T00:00:00Z", message="Synthetic exchange version one")
        return output, result

    def export_second(self):
        first_path, first = self.export_first()
        second_bag = _standard(self.first_bag.manifest_hash, b"draw(2);")
        second_path = self.root / "bag-v2"; write_tree(second_bag.files, second_path)
        output = self.root / "object-v2"
        second = export_bag(second_path, second_bag.manifest_hash, output,
            created="2026-09-20T01:00:00Z", message="Synthetic exchange version two",
            previous=first_path, previous_inventory_hash=first.object.inventory_hash)
        return first_path, first, second_path, second_bag, output, second

    def test_two_verbatim_versions_deduplicate_and_restore_either_version(self):
        _, first, _, second_bag, output, inspected = self.export_second()
        self.assertEqual(inspected.object, inspect_object(output, inspected.object.inventory_hash).object)
        self.assertEqual(tuple(row.version for row in inspected.versions), ("v1", "v2"))
        self.assertFalse(inspected.report["qualification"]["sourceAuthorityProven"])
        self.assertFalse(inspected.report["qualification"]["currentConformance"])
        self.assertEqual(dict(inspected.versions[0].bag.files), dict(self.first_bag.files))
        self.assertEqual(dict(inspected.versions[1].bag.files), dict(second_bag.files))
        inventory = loads(inspected.object.inventory, canonical=True)
        shared = sha256(dumps({"type": "object"})).hexdigest()
        self.assertEqual(len(inventory["manifest"][shared]), 1)
        for version, bag in (("v1", self.first_bag), ("v2", second_bag)):
            restored = self.root / ("restored-" + version)
            receipt = import_version(output, inspected.object.inventory_hash, version, bag.manifest_hash, restored)
            self.assertEqual(read_tree(restored), dict(bag.files))
            self.assertEqual(receipt["selectedVersion"], version)
            self.assertEqual(receipt["bagManifestHash"], bag.manifest_hash)
            self.assertEqual(receipt["inventoryHash"], inspected.object.inventory_hash)
        self.assertEqual(first.versions[0].bag, self.first_bag)

    def test_wrong_external_pins_aliases_and_missing_versions_reject_without_output(self):
        output, result = self.export_first()
        bad = keccak256(b"wrong external pin")
        rejected_export = self.root / "wrong-bag-pin"
        with self.assertRaises(MuseumError):
            export_bag(self.first_path, bad, rejected_export,
                created="2026-09-20T01:00:00Z", message="wrong pin")
        self.assertFalse(rejected_export.exists())
        successor = _standard(self.first_bag.manifest_hash, b"draw(2);")
        successor_path = self.root / "successor-for-wrong-pin"; write_tree(successor.files, successor_path)
        for previous, previous_hash in ((None, result.object.inventory_hash), (output, None), (output, bad)):
            target = self.root / ("bad-previous-" + str(len(list(self.root.iterdir()))))
            with self.assertRaises(MuseumError):
                export_bag(successor_path, successor.manifest_hash, target,
                    created="2026-09-20T01:00:00Z", message="bad predecessor pair",
                    previous=previous, previous_inventory_hash=previous_hash)
            self.assertFalse(target.exists())
        for version, inventory_hash, bag_hash in (("v1", bad, self.first_bag.manifest_hash),
                ("v1", result.object.inventory_hash, bad), ("head", result.object.inventory_hash, self.first_bag.manifest_hash),
                ("latest", result.object.inventory_hash, self.first_bag.manifest_hash),
                ("v01", result.object.inventory_hash, self.first_bag.manifest_hash),
                ("v2", result.object.inventory_hash, self.first_bag.manifest_hash)):
            destination = self.root / ("reject-" + version + "-" + inventory_hash[-4:] + bag_hash[-4:])
            with self.subTest(version=version, inventory=inventory_hash, bag=bag_hash), self.assertRaises(MuseumError):
                import_version(output, inventory_hash, version, bag_hash, destination)
            self.assertFalse(destination.exists())
        with self.assertRaises(MuseumError):
            inspect_object(output, bad)

    def test_historical_content_fixity_empty_and_extra_directories_reject(self):
        _, _, _, _, output, result = self.export_second()
        baseline = read_tree(output)
        content_name = next(name for name in baseline if name.startswith("v1/content/"))
        for mutation in ("content", "extra_file", "empty_directory"):
            damaged = self.root / ("damaged-" + mutation); write_tree(baseline, damaged)
            if mutation == "content":
                (damaged / content_name).write_bytes((damaged / content_name).read_bytes() + b"!")
            elif mutation == "extra_file":
                (damaged / "undeclared").write_bytes(b"x")
            else:
                (damaged / "empty").mkdir()
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError):
                inspect_object(damaged, result.object.inventory_hash)

    def test_semantic_tamper_behind_valid_transport_blocks_export_and_import(self):
        valid = _semantic_bag(); valid_path = self.root / "semantic-valid"; write_tree(valid.files, valid_path)
        valid_object = self.root / "semantic-valid-object"
        valid_inspection = export_bag(valid_path, valid.manifest_hash, valid_object,
            created="2026-09-20T00:00:00Z", message="Valid synthetic nested semantic package")
        valid_restored = self.root / "semantic-valid-restored"
        import_version(valid_object, valid_inspection.object.inventory_hash, "v1", valid.manifest_hash, valid_restored)
        self.assertEqual(read_tree(valid_restored), dict(valid.files))
        corrupt = _semantic_bag(corrupt=True)
        self.assertEqual(verify_bag_files(corrupt.files, corrupt.manifest_hash), corrupt)
        corrupt_path = self.root / "semantic-corrupt"; write_tree(corrupt.files, corrupt_path)
        with self.assertRaises(MuseumError): verify_bag(corrupt_path, corrupt.manifest_hash)
        rejected = self.root / "rejected-object"
        with self.assertRaises(MuseumError):
            export_bag(corrupt_path, corrupt.manifest_hash, rejected,
                created="2026-09-20T00:00:00Z", message="must not write")
        self.assertFalse(rejected.exists())

        # OCFL transport validation alone intentionally does not replay nested
        # semantics.  A valid immutable object around the corrupt bag must
        # still fail the exchange's stronger import inspection.
        object_value = build_version(corrupt, created="2026-09-20T00:00:00Z",
            message="Valid transport around corrupt declared semantics")
        damaged = self.root / "damaged-object"; write_tree(object_value.files, damaged)
        restored = self.root / "must-not-import"
        with self.assertRaises(MuseumError):
            import_version(damaged, object_value.inventory_hash, "v1", corrupt.manifest_hash, restored)
        self.assertFalse(restored.exists())

    def test_corrupt_historical_semantics_block_valid_later_selection_and_successor(self):
        corrupt = _semantic_bag(corrupt=True)
        first = build_version(corrupt, created="2026-09-20T00:00:00Z", message="corrupt declared semantics")
        valid = _semantic_bag(predecessor=corrupt.manifest_hash)
        second = build_version(valid, created="2026-09-20T01:00:00Z", message="valid later semantics",
            previous=first, previous_inventory_hash=first.inventory_hash)
        source = self.root / "history-corrupt"; write_tree(second.files, source)
        restored = self.root / "history-selected-v2"
        with self.assertRaises(MuseumError):
            import_version(source, second.inventory_hash, "v2", valid.manifest_hash, restored)
        self.assertFalse(restored.exists())
        third_bag = _standard(valid.manifest_hash, b"draw(3);")
        third_path = self.root / "history-v3-bag"; write_tree(third_bag.files, third_path)
        third = self.root / "history-v3-object"
        with self.assertRaises(MuseumError):
            export_bag(third_path, third_bag.manifest_hash, third,
                created="2026-09-20T02:00:00Z", message="cannot outrun bad history",
                previous=source, previous_inventory_hash=second.inventory_hash)
        self.assertFalse(third.exists())

    def test_hydrated_bag_preserves_exact_provenance_through_export_and_import(self):
        d, embedded = remote_description()
        original = build_bag(dumps(d), embedded)
        hydrated = hydrate_bag(original, {"remote/master.bin": b"declared remote preservation master"})
        path = self.root / "hydrated"; write_tree(hydrated.files, path)
        output = self.root / "hydrated-object"
        inspected = export_bag(path, hydrated.manifest_hash, output,
            created="2026-09-20T00:00:00Z", message="Synthetic hydrated transport")
        restored = self.root / "hydrated-restored"
        receipt = import_version(output, inspected.object.inventory_hash, "v1", hydrated.manifest_hash, restored)
        self.assertEqual(read_tree(restored), dict(hydrated.files))
        self.assertEqual(loads((restored / "stream-manifest.json").read_bytes())["sourceBagManifestHash"], original.manifest_hash)
        self.assertEqual(receipt["selected"]["bagMode"], "stream_bagit_hydrated_package")
        self.assertFalse(receipt["qualification"]["sourceAuthorityProven"])

    def test_existing_scoped_dossier_adapter_is_replayed_not_reclassified(self):
        # This retained fixture is an actual adapter route over a local captured
        # source.  Its own qualifications remain authoritative; exchange only
        # preserves and replays the bytes.
        from .test_dossier import DossierTests
        DossierTests.setUpClass()
        try:
            scoped = DossierTests.bag
            scoped_path = self.root / "scoped"; write_tree(scoped.files, scoped_path)
            output = self.root / "scoped-object"
            with patch("socket.socket", side_effect=AssertionError("repository exchange used network")):
                inspected = export_bag(scoped_path, scoped.manifest_hash, output,
                    created="2026-09-20T00:00:00Z", message="Retained scoped adapter transport")
                self.assertEqual(inspected.versions[0].summary["bagMode"], "stream_museum_dossier_bagit_package")
                self.assertFalse(inspected.report["qualification"]["fullDossierConformance"])
                restored = self.root / "scoped-restored"
                receipt = import_version(output, inspected.object.inventory_hash, "v1", scoped.manifest_hash, restored)
            self.assertEqual(read_tree(restored), dict(scoped.files))
            self.assertEqual(receipt["selected"]["bagMode"], "stream_museum_dossier_bagit_package")
        finally:
            DossierTests.tearDownClass()

    def test_existing_or_nested_outputs_fail_without_mutating_inputs(self):
        before = read_tree(self.first_path)
        existing = self.root / "existing"; existing.mkdir()
        for output in (existing, self.first_path / "nested-output"):
            with self.subTest(output=output), self.assertRaises((MuseumError, FileExistsError)):
                export_bag(self.first_path, self.first_bag.manifest_hash, output,
                    created="2026-09-20T00:00:00Z", message="must fail")
            self.assertEqual(read_tree(self.first_path), before)
        object_path, inspected = self.export_first()
        for output in (existing, object_path / "nested-import"):
            with self.subTest(output=output), self.assertRaises((MuseumError, FileExistsError)):
                import_version(object_path, inspected.object.inventory_hash, "v1", self.first_bag.manifest_hash, output)
            self.assertEqual(read_tree(object_path), dict(inspected.object.files))

    def test_replay_limits_apply_before_exchange_write(self):
        import tools.museum.repository_exchange as exchange
        output = self.root / "bounded"
        with patch.object(exchange, "MAX_REPLAY_FILES", 1):
            with self.assertRaises(MuseumError):
                export_bag(self.first_path, self.first_bag.manifest_hash, output,
                    created="2026-09-20T00:00:00Z", message="bounded")
        self.assertFalse(output.exists())
        with patch.object(exchange, "MAX_REPLAY_BYTES", 1):
            with self.assertRaises(MuseumError):
                export_bag(self.first_path, self.first_bag.manifest_hash, output,
                    created="2026-09-20T00:00:00Z", message="bounded")
        self.assertFalse(output.exists())

        _, _, _, _, object_path, inspected = self.export_second()
        logical_bytes = sum(row.summary["bagBytes"] for row in inspected.versions)
        self.assertTrue(all(row.summary["bagBytes"] < logical_bytes for row in inspected.versions))
        with patch.object(exchange, "MAX_REPLAY_BYTES", logical_bytes - 1), \
                patch.object(exchange, "_replay") as replay:
            with self.assertRaisesRegex(MuseumError, "logical replay bound"):
                inspect_object(object_path, inspected.object.inventory_hash)
            replay.assert_not_called()
        logical_files = sum(row.summary["bagFiles"] for row in inspected.versions)
        self.assertTrue(all(row.summary["bagFiles"] < logical_files for row in inspected.versions))
        with patch.object(exchange, "MAX_REPLAY_FILES", logical_files - 1), \
                patch.object(exchange, "_replay") as replay:
            with self.assertRaisesRegex(MuseumError, "logical replay bound"):
                inspect_object(object_path, inspected.object.inventory_hash)
            replay.assert_not_called()

    def test_staging_write_and_atomic_publish_failures_leave_no_output(self):
        import tools.museum.repository_exchange as exchange
        output = self.root / "atomic-output"
        original_write = exchange.write_tree
        def partial_write(files, directory):
            original_write(files, directory)
            if Path(directory).parent.name.startswith(".stream-exchange-"):
                raise OSError("injected failure after staged files exist")
        with patch.object(exchange, "write_tree", side_effect=partial_write):
            with self.assertRaises(OSError):
                export_bag(self.first_path, self.first_bag.manifest_hash, output,
                    created="2026-09-20T00:00:00Z", message="write failure")
        self.assertFalse(output.exists())
        self.assertFalse(any(path.name.startswith(".stream-exchange-") for path in self.root.iterdir()))

        with patch.object(exchange, "_rename_new", side_effect=OSError("injected rename failure")):
            with self.assertRaises(OSError):
                export_bag(self.first_path, self.first_bag.manifest_hash, output,
                    created="2026-09-20T00:00:00Z", message="rename failure")
        self.assertFalse(output.exists())
        self.assertFalse(any(path.name.startswith(".stream-exchange-") for path in self.root.iterdir()))

        sentinel = self.root / "raced"
        original_rename = exchange._rename_new
        def race(source, destination):
            Path(destination).mkdir()
            original_rename(source, destination)
        with patch.object(exchange, "_rename_new", side_effect=race):
            with self.assertRaises(OSError):
                export_bag(self.first_path, self.first_bag.manifest_hash, sentinel,
                    created="2026-09-20T00:00:00Z", message="racing writer")
        self.assertEqual(read_tree(sentinel), {})
        self.assertFalse(any(path.name.startswith(".stream-exchange-") for path in self.root.iterdir()))

        source = self.root / "rename-source"; source.mkdir()
        destination = self.root / "rename-destination"
        with patch.object(exchange.os, "name", "posix"), patch.object(exchange.sys, "platform", "darwin"):
            with self.assertRaisesRegex(MuseumError, "no-replace"):
                exchange._rename_new(source, destination)
        self.assertTrue(source.is_dir())
        self.assertFalse(destination.exists())

    def test_cli_export_inspect_and_import_are_end_to_end(self):
        object_path = self.root / "cli-object"
        run = subprocess.run([sys.executable, "-m", "tools.museum.repository_exchange", "export",
            str(self.first_path), str(object_path), "--bag-manifest-hash", self.first_bag.manifest_hash,
            "--created", "2026-09-20T00:00:00Z", "--message", "CLI synthetic export"],
            capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        exported = loads(run.stdout.strip().encode(), canonical=True)
        inventory_hash = exported["inventoryHash"]
        run = subprocess.run([sys.executable, "-m", "tools.museum.repository_exchange", "inspect",
            str(object_path), "--inventory-hash", inventory_hash], capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual([row["version"] for row in loads(run.stdout.strip().encode(), canonical=True)["versions"]], ["v1"])
        restored = self.root / "cli-restored"
        run = subprocess.run([sys.executable, "-m", "tools.museum.repository_exchange", "import",
            str(object_path), str(restored), "--inventory-hash", inventory_hash, "--version", "v1",
            "--bag-manifest-hash", self.first_bag.manifest_hash], capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(read_tree(restored), dict(self.first_bag.files))


if __name__ == "__main__":
    unittest.main()

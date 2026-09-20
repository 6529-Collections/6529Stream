"""Synthetic concrete-source CLI mechanics; no network or actual-chain acceptance."""
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch

from . import acquisition_accession as acquisition
from . import acquisition_accession_cli as cli
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .public_history_rpc import PublicRpcTransport
from .test_acquisition_accession import JoinedFixture


class AcquisitionAccessionCliTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = JoinedFixture()
        cls.owner, cls.owner_pins, cls.ownership, cls.ownership_pins, cls.selection, cls.documents = cls.fixture.artifacts()
        cls.result = acquisition.compose(cls.owner, cls.owner_pins, cls.ownership, cls.ownership_pins,
            cls.selection, keccak256(cls.selection), disclosure="public", documents=cls.documents)

    def inputs(self, root):
        for name, files, pins in (("owner", self.owner, self.owner_pins),
                ("ownership", self.ownership, self.ownership_pins)):
            write_tree(files, root / name)
            (root / (name + "-pins.json")).write_bytes(dumps(pins))
        (root / "selection.json").write_bytes(self.selection)
        documents = root / "documents"; documents.mkdir()
        for key, raw in self.documents.items():
            (documents / (key[2:] + ".bin")).write_bytes(raw)
        return root

    def capture_options(self, root, **changes):
        return {"owner_anchor": root / "owner/anchor.json", "owner_anchor_hash": self.owner_pins["anchorHash"],
            "owner_source_profile_hash": self.owner_pins["profileHash"],
            "ownership_anchor": root / "ownership/anchor.json", "ownership_anchor_hash": self.ownership_pins["anchorHash"],
            "ownership_source_profile_hash": self.ownership_pins["profileHash"],
            "selection": root / "selection.json", "selection_hash": keccak256(self.selection),
            "rpc_env": "MUSEUM_ACCESSION_TEST_RPC", "disclosure": "public", "output": root / "output",
            "documents": root / "documents"} | changes

    def compose_options(self, root, **changes):
        return {"owner_source": root / "owner", "owner_pins": root / "owner-pins.json",
            "ownership_source": root / "ownership", "ownership_pins": root / "ownership-pins.json",
            "selection": root / "selection.json", "selection_hash": keccak256(self.selection),
            "disclosure": "public", "output": root / "output", "documents": root / "documents"} | changes

    @staticmethod
    def argv(command, options):
        return [command, *[s for key, value in options.items() if value is not None
            for s in ("--" + key.replace("_", "-"), str(value))]]

    @staticmethod
    def endpoint_guard():
        original = cli.os.environ.get
        def guarded(name, default=None):
            if name == "MUSEUM_ACCESSION_TEST_RPC": raise AssertionError("endpoint accessed before preflight")
            return original(name, default)
        return patch.object(cli.os.environ, "get", side_effect=guarded)

    def test_mocked_capture_uses_one_actual_transport_two_concrete_readers_and_replays(self):
        fixture = JoinedFixture(); seen = set()
        endpoint = "https://example.invalid/private-test-credential?token=do-not-retain"
        def request(transport, method, params):
            seen.add(id(transport))
            return fixture.request(method, params)
        with TemporaryDirectory() as temp:
            root = self.inputs(Path(temp)); stdout = io.StringIO()
            with patch.object(PublicRpcTransport, "request", new=request), \
                    patch.dict(cli.os.environ, {"MUSEUM_ACCESSION_TEST_RPC": endpoint}), \
                    patch("socket.socket", side_effect=AssertionError("synthetic transport only")), \
                    patch.object(acquisition, "verify", wraps=acquisition.verify) as verified, redirect_stdout(stdout):
                cli.main(self.argv("capture", self.capture_options(root)))
            self.assertEqual(len(seen), 1)
            verified.assert_called_once()
            files = read_tree(root / "output"); message = loads(stdout.getvalue().encode())
            self.assertEqual(message["manifestHash"], keccak256(files["manifest.json"]))
            self.assertEqual(message["provenance"], "trusted_rpc")
            self.assertFalse(message["actualChainAcceptance"])
            self.assertFalse(message["sourceConsensusVerified"])
            self.assertNotIn(endpoint, stdout.getvalue())
            self.assertNotIn(endpoint.encode(), b"".join(files.values()))
            for kind in ("owner", "ownership"):
                snapshot = loads(files["sources/" + kind + "/snapshot.json"], maximum=64 * 1024 * 1024)
                self.assertFalse(snapshot["claims"]["actualChainAcceptance"])
            selected = loads(files["accession/selected.json"])
            self.assertEqual(selected["recordHash"], fixture.selected)
            self.assertEqual(selected["instrumentEvidence"]["status"], "retained_hash_verified")
            with patch("socket.socket", side_effect=AssertionError("offline verification")), redirect_stdout(io.StringIO()):
                cli.main(["verify", str(root / "output"), "--manifest-hash", message["manifestHash"]])

    def test_offline_compose_exact_package_then_verify_with_no_endpoint(self):
        with TemporaryDirectory() as temp:
            root = self.inputs(Path(temp)); stdout = io.StringIO()
            with self.endpoint_guard(), patch.object(PublicRpcTransport, "__init__", side_effect=AssertionError("no RPC client")), \
                    patch("socket.socket", side_effect=AssertionError("offline composition")), redirect_stdout(stdout):
                cli.main(self.argv("compose", self.compose_options(root)))
            self.assertEqual(read_tree(root / "output"), dict(self.result.files))
            self.assertEqual(loads(stdout.getvalue().encode())["provenance"], "synthetic_fixture")
            with self.assertRaisesRegex(MuseumError, "manifest pin"):
                cli.verify_path(root / "output", "0x" + "ff" * 32)

    def test_disclosure_precedes_all_path_environment_and_destination_operations(self):
        root = Path("deliberately-missing-accession-input")
        with patch.object(cli, "_destination", side_effect=AssertionError("destination read")), \
                patch.object(cli, "_read", side_effect=AssertionError("file read")), self.endpoint_guard():
            for call, options in ((cli.capture_paths, self.capture_options(root, disclosure="restricted")),
                    (cli.compose_paths, self.compose_options(root, disclosure="private"))):
                with self.subTest(call=call.__name__), self.assertRaisesRegex(MuseumError, "public disclosure"):
                    call(**options)

    def test_anchor_profile_selection_and_common_identity_fail_before_endpoint(self):
        bad = "0x" + "ff" * 32
        with TemporaryDirectory() as temp:
            root = self.inputs(Path(temp))
            for changes in ({"owner_anchor_hash": bad}, {"ownership_anchor_hash": bad},
                    {"owner_source_profile_hash": bad}, {"ownership_source_profile_hash": bad},
                    {"selection_hash": bad}, {"rpc_env": "https://secret.invalid/key"}):
                with self.subTest(changes=changes), self.endpoint_guard(), self.assertRaises(MuseumError):
                    cli.capture_paths(**self.capture_options(root, **changes))
            for kind in ("owner", "ownership"):
                path = root / kind / "anchor.json"; original = path.read_bytes()
                value = loads(original); value["endpoint"] = "https://example.invalid/undeclared"
                path.write_bytes(dumps(value))
                with self.subTest(kind=kind), self.endpoint_guard(), self.assertRaises(MuseumError):
                    cli.capture_paths(**self.capture_options(root, **{kind + "_anchor_hash": keccak256(path.read_bytes())}))
                path.write_bytes(original)
            path = root / "ownership/anchor.json"; value = loads(path.read_bytes()); value["stateRoot"] = bad
            path.write_bytes(dumps(value))
            with self.endpoint_guard(), self.assertRaisesRegex(MuseumError, "source anchors differ"):
                cli.capture_paths(**self.capture_options(root, ownership_anchor_hash=keccak256(path.read_bytes())))
            path.write_bytes(self.ownership["anchor.json"])
            for update in ({"tokenId": "72"}, {"extra": True}):
                value = loads(self.selection); value.update(update); raw = dumps(value)
                (root / "selection.json").write_bytes(raw)
                with self.subTest(update=update), self.endpoint_guard(), self.assertRaisesRegex(MuseumError, "selection"):
                    cli.capture_paths(**self.capture_options(root, selection_hash=keccak256(raw)))
            self.assertFalse((root / "output").exists())

    def test_capture_requires_exact_read_only_transport_before_requests(self):
        fixture = JoinedFixture(); fixture.requested.clear()
        args = (self.owner["anchor.json"], self.owner_pins["anchorHash"], self.owner_pins["profileHash"],
            self.ownership["anchor.json"], self.ownership_pins["anchorHash"], self.ownership_pins["profileHash"],
            self.selection, keccak256(self.selection), fixture)
        with self.assertRaisesRegex(MuseumError, "explicit public read-only transport"):
            cli.capture(*args, disclosure="public")
        self.assertEqual(fixture.requested, [])

    def test_documents_strict_names_flat_files_no_empty_and_each_file_bound(self):
        for name in ("a" * 64 + ".BIN", "A" * 64 + ".bin", "0x" + "a" * 64 + ".bin", "notes.txt"):
            with self.subTest(name=name), TemporaryDirectory() as temp:
                root = Path(temp); (root / name).write_bytes(b"content")
                with self.assertRaisesRegex(MuseumError, "filename"):
                    cli.read_documents(root)
        for size in (0, cli.MAX_DOCUMENT_BYTES + 1):
            with self.subTest(size=size), TemporaryDirectory() as temp:
                root = Path(temp); (root / ("a" * 64 + ".bin")).write_bytes(b"x" * size)
                with self.assertRaisesRegex(MuseumError, "file bound"):
                    cli.read_documents(root)
        with TemporaryDirectory() as temp:
            root = Path(temp); (root / "nested").mkdir()
            with self.assertRaisesRegex(MuseumError, "flat regular files"):
                cli.read_documents(root)

    def test_documents_count_and_aggregate_bounds_fail_before_opening_members(self):
        for count, size, message in ((129, 1, "count bound"), (17, 1048576, "aggregate bound")):
            with self.subTest(count=count), TemporaryDirectory() as temp:
                root = Path(temp)
                for i in range(1, count + 1):
                    (root / (format(i, "064x") + ".bin")).write_bytes(b"x" * size)
                with patch.object(cli, "_read", side_effect=AssertionError("no member opened")), \
                        self.assertRaisesRegex(MuseumError, message):
                    cli.read_documents(root)

    def test_document_and_source_parent_links_are_rejected(self):
        with TemporaryDirectory() as temp:
            root = self.inputs(Path(temp)); linked = root / "linked"
            original = Path.is_symlink
            # Test metadata gates without requiring host symlink-creation rights.
            with patch.object(Path, "is_symlink", autospec=True,
                    side_effect=lambda p: p == linked or original(p)):
                with self.assertRaisesRegex(MuseumError, "link or junction"):
                    cli.read_documents(linked)
                with self.assertRaisesRegex(MuseumError, "link or junction"):
                    cli._read(linked / (next(iter(self.documents))[2:] + ".bin"), cli.MAX_DOCUMENT_BYTES)
            name = "b" * 64 + ".bin"
            entry = SimpleNamespace(name=name, path=str(root / "documents" / name), is_symlink=lambda: True)
            scan = MagicMock(); scan.__enter__.return_value = iter([entry])
            with patch.object(cli.os, "scandir", return_value=scan), \
                    patch.object(cli, "_read", side_effect=AssertionError("link bytes not opened")), \
                    self.assertRaisesRegex(MuseumError, "flat regular files"):
                cli.read_documents(root / "documents")

    def test_document_case_alias_inventory_fails_before_reading_bytes(self):
        with TemporaryDirectory() as temp:
            root = Path(temp)
            entries = [SimpleNamespace(name=name, path=str(root / name), is_symlink=lambda: False,
                is_file=lambda **kwargs: True) for name in ("a" * 64 + ".bin", "A" * 64 + ".bin")]
            scan = MagicMock(); scan.__enter__.return_value = iter(entries)
            with patch.object(cli.os, "scandir", return_value=scan), \
                    patch.object(cli, "_read", side_effect=AssertionError("alias bytes not opened")), \
                    self.assertRaisesRegex(MuseumError, "case alias"):
                cli.read_documents(root)

    def test_offline_exact_triplets_closed_pins_and_rehashed_capture_tamper(self):
        with TemporaryDirectory() as temp:
            root = self.inputs(Path(temp)); options = self.compose_options(root)
            extra = root / "owner/extra.json"; extra.write_bytes(b"{}")
            with self.assertRaises(MuseumError): cli.compose_paths(**options)
            extra.unlink()
            pins_path = root / "owner-pins.json"
            for value in (self.owner_pins | {"endpoint": "forbidden"}, self.owner_pins | {"profileHash": "0x" + "ff" * 32}):
                pins_path.write_bytes(dumps(value))
                with self.assertRaisesRegex(MuseumError, "closed source pins"):
                    cli.compose_paths(**options)
            pins_path.write_bytes(dumps(self.owner_pins))
            snapshot = loads(self.owner["snapshot.json"], maximum=64 * 1024 * 1024)
            snapshot["claims"]["actualChainAcceptance"] = True
            raw = dumps(snapshot); (root / "owner/snapshot.json").write_bytes(raw)
            pins_path.write_bytes(dumps(self.owner_pins | {"snapshotHash": keccak256(raw)}))
            with self.assertRaisesRegex(MuseumError, "source reconstruction"):
                cli.compose_paths(**options)
            self.assertFalse((root / "output").exists())

    def test_bad_documents_rejected_before_endpoint_and_digest_mismatch_before_publication(self):
        with TemporaryDirectory() as temp:
            root = self.inputs(Path(temp)); extra = root / "documents/extra.txt"; extra.write_bytes(b"bad")
            with self.endpoint_guard(), self.assertRaisesRegex(MuseumError, "filename"):
                cli.capture_paths(**self.capture_options(root))
            extra.unlink()
            document = next((root / "documents").iterdir()); document.write_bytes(b"wrong instrument")
            with self.assertRaisesRegex(MuseumError, "digest"):
                cli.compose_paths(**self.compose_options(root))
            self.assertFalse((root / "output").exists())

    def test_existing_overlap_and_raced_destinations_are_preserved(self):
        with TemporaryDirectory() as temp:
            root = self.inputs(Path(temp)); existing = root / "existing"; existing.mkdir()
            (existing / "keep").write_bytes(b"original")
            for output in (existing, root / "documents/output"):
                with self.subTest(output=output), self.endpoint_guard(), self.assertRaises(MuseumError):
                    cli.capture_paths(**self.capture_options(root, output=output))
            with self.assertRaisesRegex(MuseumError, "overlaps"):
                cli.compose_paths(**self.compose_options(root, output=root / "owner/output"))
            self.assertEqual((existing / "keep").read_bytes(), b"original")
            output = root / "output"
            def raced(*args, **kwargs):
                output.mkdir(); (output / "keep").write_bytes(b"race owner")
                return self.result
            with patch.object(cli, "capture", side_effect=raced), \
                    patch.dict(cli.os.environ, {"MUSEUM_ACCESSION_TEST_RPC": "https://example.invalid"}), \
                    self.assertRaisesRegex(MuseumError, "new directory"):
                cli.capture_paths(**self.capture_options(root))
            self.assertEqual({p.name: p.read_bytes() for p in output.iterdir()}, {"keep": b"race owner"})

    def test_replay_failure_prevents_publication_and_profiles_are_closed(self):
        with TemporaryDirectory() as temp:
            root = self.inputs(Path(temp))
            with patch.object(acquisition, "verify", side_effect=MuseumError("synthetic replay rejection")), \
                    patch.object(cli, "atomic_publish", side_effect=AssertionError("unverified output")), \
                    self.assertRaisesRegex(MuseumError, "replay rejection"):
                cli.compose_paths(**self.compose_options(root))
            self.assertFalse((root / "output").exists())
        stdout = io.StringIO()
        with redirect_stdout(stdout), patch.object(cli, "_read", side_effect=AssertionError("no file read")), self.endpoint_guard():
            cli.main(["profiles"])
        value = loads(stdout.getvalue().encode())
        self.assertEqual(set(value), {"acquisitionProfileHash", "sources"})
        self.assertEqual(value["acquisitionProfileHash"], acquisition.PROFILE_HASH)
        self.assertEqual(value["sources"], {"owner": self.owner_pins["profileHash"], "ownership": self.ownership_pins["profileHash"]})


if __name__ == "__main__":
    unittest.main()

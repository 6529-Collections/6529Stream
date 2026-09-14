"""Lightweight prospective-input and native-loader controls; no compiler or RPC."""
import base64
import hashlib
import io
import struct
import json
import tempfile
import sys
import unittest
import zlib
from pathlib import Path
from unittest.mock import patch, Mock
from types import SimpleNamespace

from .canonical import MuseumError, loads, schema_id
from .current_media_inputs import PREFIX, PUBLISHER, image_bytes, media_description, payloads, selected_plans
from .current_native_fixture import CurrentNativeFixture, abi_kind, patch_links
from .chain_abi import Array, encode
from .independent_wire import ZERO


class CurrentMediaInputs(unittest.TestCase):
    def test_retained_png_and_content_identifier_describe_actual_bytes(self):
        raw = image_bytes()
        self.assertEqual(raw[:8], b"\x89PNG\r\n\x1a\n")
        offset, chunks = 8, {}
        while offset < len(raw):
            size = struct.unpack(">I", raw[offset:offset + 4])[0]
            kind, data = raw[offset + 4:offset + 8], raw[offset + 8:offset + 8 + size]
            self.assertEqual(struct.unpack(">I", raw[offset + 8 + size:offset + 12 + size])[0], zlib.crc32(kind + data))
            chunks[kind] = data; offset += 12 + size
        self.assertEqual(struct.unpack(">IIBBBBB", chunks[b"IHDR"]), (1, 1, 8, 6, 0, 0, 0))
        self.assertEqual(zlib.decompress(chunks[b"IDAT"]), b"\x00\x65\x29\xff\xff")
        info = media_description(raw)
        self.assertEqual(info["bytes"], str(len(raw)))
        self.assertEqual(info["sha256"], hashlib.sha256(raw).hexdigest())
        token = info["uri"].removeprefix("ipfs://b").upper()
        self.assertEqual(base64.b32decode(token + "=" * (-len(token) % 8)), bytes.fromhex("01551220" + info["sha256"]))
        with self.assertRaises(MuseumError): media_description(raw + b"x")

    def test_prospective_payloads_satisfy_original_schema_without_empty_assertions(self):
        address = "0x" + "11" * 20
        prior = {"host": address, "recordHash": ZERO, "subjectId": ZERO, "schemaId": ZERO,
            "schemaHash": ZERO, "recordType": ZERO, "recorder": address,
            "authorizationClass": "INDEPENDENT_ATTESTOR", "recordIndex": "0", "recordChainHash": ZERO, "pointer": ""}
        rows = payloads(chain_id=31337, attestor=address, subject_id=ZERO, profile_hash=ZERO,
            prior=prior, source_digest=ZERO, created_at="2026-09-14T00:00:00Z")
        values = [loads(row, canonical=True) for row in rows]
        self.assertTrue(all(0 < len(row) <= 8192 for row in rows))
        self.assertTrue(all(v["assertions"] for v in values))
        entities = [e for v in values for e in v["entities"]]
        claims = [a for v in values for a in v["assertions"]]
        self.assertEqual(len(entities), 5)
        self.assertEqual(len(claims), 25)
        publisher = next(a for a in claims if a["relation"] == PUBLISHER)
        self.assertEqual(publisher["object"], {"entity": PREFIX + "publisher"})
        self.assertNotEqual(publisher["object"]["entity"], publisher["assertingAgent"])
        self.assertTrue(all(a["reviewStatus"] == "unreviewed" for a in claims))
        self.assertEqual({a["assertingAgent"] for a in claims}, {entities[0]["declaringAgent"]})

    def test_selection_rejects_synthetic_or_arbitrary_source(self):
        with self.assertRaises(MuseumError): selected_plans(object())

    def test_declared_library_link_offsets_only(self):
        address = "0x" + "12" * 20
        code = "0x60" + "_" * 40 + "00"
        refs = {"real.sol": {"Real": [{"start": 1, "length": 20}]}}
        calls = []
        raw, links = patch_links(code, refs, lambda source, name: calls.append((source, name)) or address)
        self.assertEqual(raw, bytes.fromhex("60" + "12" * 20 + "00"))
        self.assertEqual(calls, [("real.sol", "Real")])
        self.assertEqual(links, {"real.sol:Real": address})
        for positions in ([{"start": 1, "length": 19}], [{"start": 3, "length": 20}],
                [{"start": 1, "length": 20}, {"start": 1, "length": 20}]):
            with self.subTest(positions=positions), self.assertRaises(MuseumError):
                patch_links(code, {"real.sol": {"Real": positions}}, lambda *_: address)
        with self.assertRaises(MuseumError): patch_links(code, {}, lambda *_: address)
        with self.assertRaises(MuseumError): patch_links("0x1", {}, lambda *_: address)

    def test_compiler_library_selector_keeps_native_nominal_struct_signature(self):
        fixture = object.__new__(CurrentNativeFixture)
        fixture.products = {"Helper": {"abi": [{"type": "function", "name": "hash", "inputs": [
            {"type": "tuple[]", "components": [{"type": "uint64"}]}], "outputs": []}],
            "methodIdentifiers": {"hash(NativeRecord[])": "12345678"}}}
        self.assertEqual(fixture.data("Helper", "hash", ([(7,)],)), "0x12345678" + encode((Array(("uint64",)),), ([(7,)],)).hex())
        with self.assertRaises(MuseumError): fixture.data("Helper", "hash", ([((1 << 64),)],))

    def test_manifest_change_is_rejected_before_rpc_or_deployment(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.json"
            path.write_text("{}", encoding="utf-8")
            with patch.object(CurrentNativeFixture, "rpc") as rpc:
                with self.assertRaisesRegex(MuseumError, "manifest hash changed"):
                    CurrentNativeFixture(path, "http://127.0.0.1:1", expected_manifest_sha256="00" * 32)
                rpc.assert_not_called()

    def test_artifact_source_identity_must_match_the_pinned_manifest(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); artifact = root / "artifact.json"
            artifact.write_text(json.dumps({"abi": [], "metadata": {"settings": {"compilationTarget": {"wrong.sol": "Real"}}}}), encoding="utf-8")
            manifest = {"mode": "current_museum_native_products_v1", "products": {"Real": {
                "source": "right.sol", "artifact": str(artifact), "sha256": hashlib.sha256(artifact.read_bytes()).hexdigest()}}}
            path = root / "manifest.json"; path.write_text(json.dumps(manifest), encoding="utf-8")
            with patch.object(CurrentNativeFixture, "rpc", return_value=["0x" + "11" * 20]):
                with self.assertRaisesRegex(MuseumError, "source/contract identity differs"):
                    CurrentNativeFixture(path, "http://127.0.0.1:1", expected_manifest_sha256=hashlib.sha256(path.read_bytes()).hexdigest())

    def test_main_retains_validated_manifest_and_cleans_owned_process(self):
        from .current_museum_capture import main
        for fail in (False, True):
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary); manifest = root / "manifest.json"; output = root / "output"
                raw = b'{"mode":"current_museum_native_products_v1"}'
                manifest.write_bytes(raw); digest = hashlib.sha256(raw).hexdigest()
                fixture = SimpleNamespace(receipts=[], artifact_rows={})
                process = Mock()
                with patch.object(sys, "argv", ["capture", "--native-manifest", str(manifest),
                        "--native-manifest-sha256", digest, "--output", str(output), "--disclosure", "public"]), \
                        patch("tools.museum.current_museum_capture.socket.socket") as socket, \
                        patch("tools.museum.current_museum_capture.subprocess.Popen", return_value=process) as start, \
                        patch("tools.museum.current_museum_capture.CurrentMuseumFixture", return_value=fixture) as create, \
                        patch("tools.museum.current_museum_capture.capture", return_value="complete",
                            side_effect=RuntimeError("test capture failure") if fail else None) as run, \
                        patch.object(sys, "stdout", io.StringIO()):
                    socket.return_value.__enter__.return_value.getsockname.return_value = ("127.0.0.1", 17321)
                    if fail:
                        with self.assertRaisesRegex(RuntimeError, "test capture failure"): main()
                    else: main()
                    self.assertEqual((output / "native-inputs.json").read_bytes(), raw)
                    create.assert_called_once_with(manifest, "http://127.0.0.1:17321", expected_manifest_sha256=digest)
                    start.assert_called_once()
                    run.assert_called_once_with(fixture, output)
                    process.terminate.assert_called_once()
                    process.wait.assert_called_once_with(timeout=10)
                    self.assertEqual(json.loads((output / "execution-journal.json").read_bytes()), {"transactions": [], "artifacts": {}})

    def test_restricted_classification_rejects_before_start_or_input_read(self):
        from .current_museum_capture import main
        with patch.object(sys, "argv", ["capture", "--native-manifest", "missing", "--native-manifest-sha256", "00",
                "--output", "unused", "--disclosure", "restricted"]), patch("subprocess.Popen") as start:
            with self.assertRaisesRegex(MuseumError, "restricted"): main()
            start.assert_not_called()


if __name__ == "__main__": unittest.main()

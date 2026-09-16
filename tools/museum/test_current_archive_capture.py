import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, call, patch

from .canonical import dumps, keccak256, schema_id, subject_id
from .current_archive_capture import (
    ARCHIVE_CLASS, ARCHIVE_WRITER_SALT, CurrentArchiveFixture,
    POLICY_BYTES, POLICY_NAME, QUALIFICATION, SCHEMA_BYTES, SCHEMA_HASH,
    SCHEMA_PREDECESSOR,
)
from .independent_wire import ZERO
from .semantic_export import MANIFEST_PATH, NAME


A = lambda n: "0x" + f"{n:040x}"
H = lambda n: "0x" + f"{n:064x}"


class ArchiveCaptureTests(unittest.TestCase):
    def test_safe_call_advances_timestamp_before_each_owner_and_execution(self):
        fixture = object.__new__(CurrentArchiveFixture)
        fixture.safe_accounts = {A(6): [A(2), A(3)]}
        fixture.read = Mock(side_effect=[(4,), (H(5),), (5,)])
        fixture.invoke = Mock(side_effect=[{"status": "0x1"}, {"status": "0x1"},
                                           {"status": "0x1", "blockNumber": "0x9"}])
        fixture._advance_next_block_timestamp = Mock()
        result = fixture.safe_call(A(6), A(7), "0x1234")
        self.assertEqual(result["blockNumber"], "0x9")
        self.assertEqual(fixture._advance_next_block_timestamp.call_count, 3)
        self.assertEqual(fixture.invoke.call_count, 3)
        self.assertEqual(fixture.invoke.call_args_list[0].kwargs["sender"], A(2))
        self.assertEqual(fixture.invoke.call_args_list[1].kwargs["sender"], A(3))

    def test_after_hook_uses_authority_source_then_only_rights_metadata_helpers(self):
        fixture = object.__new__(CurrentArchiveFixture)
        fixture.register_document = Mock()
        fixture.safe = Mock(return_value=A(6))
        fixture.addresses = {"StreamCollectionMetadataV1": A(1)}
        order = []
        with patch.object(CurrentArchiveFixture.__mro__[1], "after_media_publications",
                          side_effect=lambda _: order.append("authority")), \
             patch.object(CurrentArchiveFixture.__mro__[2], "deploy_metadata_dependencies",
                          side_effect=lambda _: order.append("deploy")), \
             patch.object(CurrentArchiveFixture.__mro__[2], "select_metadata",
                          side_effect=lambda _: order.append("select")), \
             patch.object(CurrentArchiveFixture.__mro__[2], "extend_actions",
                          side_effect=lambda *_: order.append("extend")), \
             patch("tools.museum.current_archive_capture.configure_archive_lane",
                   return_value={"configured": True}) as configure:
            fixture.after_media_publications()
        self.assertEqual(order, ["authority", "deploy", "select", "extend"])
        self.assertEqual(fixture.register_document.call_args_list, [
            call(NAME, 0, SCHEMA_BYTES, schema_id("RFC8785_JCS"), SCHEMA_PREDECESSOR),
            call(POLICY_NAME, 2, POLICY_BYTES, schema_id("RFC8785_JCS"), ZERO),
        ])
        fixture.safe.assert_called_once_with(ARCHIVE_WRITER_SALT)
        configure.assert_called_once_with(fixture, A(6), ARCHIVE_CLASS, collection_id=1)

    def test_extra_evidence_never_relabels_archive_as_source_or_snapshot(self):
        fixture = object.__new__(CurrentArchiveFixture)
        fixture.archive_writer = A(6)
        fixture.addresses = {"StreamCollectionMetadataV1": A(1)}
        with patch.object(CurrentArchiveFixture.__mro__[1], "extra_capture_evidence",
                          return_value={"authorityCapture": {"kept": True}}):
            value = fixture.extra_capture_evidence()
        self.assertTrue(value["authorityCapture"]["kept"])
        self.assertFalse(value["archivePreparation"]["sourceLaneIncludesArchivePublication"])
        self.assertEqual(value["archivePreparation"]["authorizationClassName"], "PRESERVATION_ADMIN")
        self.assertEqual(value["archivePreparation"]["schemaPredecessor"], SCHEMA_PREDECESSOR)
        self.assertIn("does not transfer authorship", QUALIFICATION)

    def test_capture_lanes_excludes_inherited_preservation_and_archive_outputs(self):
        fixture = object.__new__(CurrentArchiveFixture)
        self.assertEqual(fixture.capture_lanes(), [{"scopeKey": "1",
            "recordType": schema_id("INDEPENDENT_SEMANTIC_ASSERTION")}])

    def test_export_builds_and_verifies_before_archive_publication(self):
        fixture = object.__new__(CurrentArchiveFixture)
        fixture.archive_writer = A(6)
        fixture.archive_configuration = {"configured": True}
        fixture.addresses = {"StreamCollectionMetadataV1": A(1), "StreamCore": A(2)}
        fixture.capture_code_addresses = Mock(return_value=[A(1), A(2)])
        subject = subject_id("collection", "31337", A(2), "1")
        manifest = dumps({"sourceState": {"chainId": "31337", "core": A(2),
            "collectionId": "1", "blockNumber": "100", "blockHash": H(100),
            "anchorSubject": {"kind": "collection", "subjectId": subject}}})
        package = SimpleNamespace(manifest_hash=H(12), manifest=b"envelope",
                                  files=((MANIFEST_PATH, manifest),))
        publication = {"lane": "ARCHIVE_SEMANTIC_EXPORT", "recordHash": H(13),
            "authorizationClass": "6", "authorizationClassName": "PRESERVATION_ADMIN"}
        events = []

        def rpc(method, params):
            if method == "eth_getBlockByNumber":
                return {"number": "0x65", "hash": H(101), "timestamp": "0x65", "stateRoot": H(201)}
            if method == "eth_getCode": return "0x6000"
            raise AssertionError((method, params))
        fixture.rpc = rpc
        verified = SimpleNamespace(manifest_hash=package.manifest_hash)
        with tempfile.TemporaryDirectory() as folder, \
             patch.object(CurrentArchiveFixture.__mro__[1], "export_capture",
                          side_effect=lambda *_: events.append("authority") or H(11)), \
             patch("tools.museum.current_archive_capture.build_export",
                   side_effect=lambda *_a, **_k: events.append("build") or package), \
             patch("tools.museum.current_archive_capture.write_package",
                   side_effect=lambda *_: events.append("write")), \
             patch("tools.museum.current_archive_capture.verify_export",
                   side_effect=lambda *_: events.append("verify") or verified), \
             patch("tools.museum.current_archive_capture.publish_archive_export",
                   side_effect=lambda *_a, **_k: events.append("publish") or publication) as publish:
            result = fixture.export_capture(SimpleNamespace(), Path(folder))
            summary = (Path(folder) / "archive-result.json").read_bytes()
            exact = (Path(folder) / "archive-publication.json").read_bytes()
            grant = (Path(folder) / "archive-grant.json").read_bytes()
        self.assertEqual(events, ["authority", "build", "write", "verify", "publish"])
        self.assertEqual(result, H(13))
        self.assertIn(H(13).encode(), summary)
        self.assertEqual(exact, dumps(publication))
        self.assertEqual(grant, dumps({"configured": True}))
        kwargs = publish.call_args.kwargs
        self.assertEqual(kwargs["source_block_number"], "100")
        self.assertEqual(kwargs["source_block_hash"], H(100))
        self.assertEqual(kwargs["subject_id"], subject)
        self.assertEqual(kwargs["authorization_class"], 6)
        self.assertEqual(kwargs["uri"], "")


if __name__ == "__main__":
    unittest.main()

"""Version-local V6 checks preserve all nineteen groups and native authority boundaries."""
import copy
from pathlib import Path
import unittest
from unittest.mock import patch

from . import acquisition_packet_v5 as v5
from . import acquisition_packet_v6 as v6
from .test_acquisition_packet_v5 import supplied, assembled
from .test_acquisition_native_finality_v1 import fragment, original_events
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from tools.museum.test_native_finality_wire import supplied as wire_supplied, H


def native_packet(assembly=None, *, graph_edit=None, artist_id=None, checkpoint_before_mint=False):
    """Actual existing native fragments plus explicitly synthetic finality originals."""
    assembly = assembly or assembled()
    value = supplied(assembly); state = value["sourceState"]
    files = dict(assembly.files); headers, codes = {}, {}
    for path, raw in files.items():
        if not path.endswith("/source/transcript.json"): continue
        for row in loads(raw, maximum=67108864)["calls"]:
            if row["method"] == "eth_getCode": codes[row["params"][0]] = keccak256(hex_bytes(row["result"]))
            if row["method"] in ("eth_getBlockByHash", "eth_getBlockByNumber") and row.get("result"):
                header = row["result"]; headers[int(header["number"], 16)] = header
    observed = loads(files["captures/selection/source/anchor.json"], maximum=65536)
    observed = {key: observed[key] for key in v6.finality.COMMON}
    for number, delta in ((1, 4), (3, 2), (4, 1)):
        headers.setdefault(number, {"hash": H("supplied-unobserved-block-" + str(number)),
            "timestamp": hex(int(observed["timestamp"]) - delta)})
    graph = wire_supplied(observed)[2]
    ctx, personhood = value["conservation"]["context"], value["attribution"]["personhood"]
    for key, address in (("core", state["core"]), ("metadata", ctx["metadataHost"]), ("schemas", ctx["schemaRegistry"]),
            ("store", ctx["store"]), ("artist", personhood["sourceBindings"]["currentRegistry"])):
        graph[key] = {"address": address, "runtimeHash": codes[address]}
    if graph_edit: graph_edit(graph)
    native = fragment(observed, graph, artist_id=artist_id or personhood["current"]["artistId"],
        root_timestamp=int(headers[3]["timestamp"], 16), finality_timestamp=int(headers[4]["timestamp"], 16))
    native["events"] = original_events(native["bundle"], observed, graph, headers=headers)
    if not checkpoint_before_mint:
        # The target completed mint is in block3. Keep the synthetic checkpoint
        # and its prerequisite publications after that mint, before the root.
        root_event = next(row for row in native["events"] if row["log"]["topics"][0] == v6.finality.wire.EVENTS["root"])
        coordinate = {key: root_event["log"][key] for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex")}
        index = 1000
        for row in native["events"]:
            if int(row["log"]["blockNumber"], 16) not in (1, 3): continue
            row["log"].update(coordinate, logIndex=hex(index)); index += 1
            row["timestamp"] = str(int(headers[3]["timestamp"], 16))
    native["identity"]["collectionSerial"] = state["collectionSerial"]
    native["identity"].update(burned=state["burned"], lifecycle="3" if state["burned"] else "2")
    value.update(schema=v6.PACKET, version=6, metadataMode="ONCHAIN", workClass="script")
    value["finality"] = {"kind": "native_collection_finality", "fragment": native}
    value["contentRootProof"] = v6.finality.token_proof(native)
    digest = native["bundle"]["finality"]["record"][1]
    value["citation"].update(qualified=value["citation"]["work"] + "@fin:" + digest, qualifier={"kind": "fin", "hash": digest})
    value["preservation"]["coverage"] = "onchain_bound"
    cycle = value["preservation"]["fixityCycle"]
    evidence = copy.deepcopy(cycle.get("report", cycle.get("evidence")))
    value["preservation"]["scriptCoverage"] = {"status": "uncovered_within_window", "captureSet": None, "environment": None, "evidence": evidence}
    value["scriptDrill"] = {"status": "never_drilled", "evidence": copy.deepcopy(evidence)}
    return value


class AcquisitionPacketV6Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.assembly = assembled()
        cls.legacy = supplied(cls.assembly)
        cls.legacy.update(schema=v6.PACKET, version=6)
        cls.native = native_packet(cls.assembly)

    def test_existing_variant_preserves_v5_relationships_without_calling_old_packet(self):
        with patch.object(v5, "validate", side_effect=AssertionError("no old-version projection")), \
                patch.object(v5, "_packet", side_effect=AssertionError("version-local packet joins")), \
                patch("socket.socket", side_effect=AssertionError("offline")):
            self.assertEqual(v6.validate(dumps(self.legacy)), self.legacy)

    def test_every_original_field_group_is_still_required(self):
        self.assertEqual(set(v6.definitions()["packet"]["required"]), set(v5.definitions()["packet"]["required"]))
        for key in v5.definitions()["packet"]["required"]:
            with self.subTest(key=key):
                value = copy.deepcopy(self.legacy); del value[key]
                with self.assertRaises(MuseumError): v6.validate(dumps(value))

    def test_old_shape_contradictions_are_not_bypassed(self):
        controls = [lambda v: v["ownershipProvenance"].update(currentOwner=v5.ZERO_ADDRESS),
            lambda v: v["rights"]["effectiveGrants"].update(display="unspecified"),
            lambda v: v["erc721Identity"].update(globalTokenId="999999")]
        for edit in controls:
            value = copy.deepcopy(self.legacy); edit(value)
            with self.assertRaises(MuseumError): v6.validate(dumps(value))

    def test_version_local_body_only_changes_fin_citation_hook(self):
        old = Path(v5.__file__).read_text(encoding="utf-8").split("def _packet(value):", 1)[1].split('if __name__ == "__main__":', 1)[0].strip()
        new = Path(v6.__file__).read_text(encoding="utf-8").split("def _packet(value):", 1)[1].split('if __name__ == "__main__":', 1)[0].strip()
        start, end = '    if citation["qualifier"]["kind"] == "fin":', '    snapshot = value["snapshotCommitment"]'
        def omit_hook(text):
            left, tail = text.split(start, 1)
            return left + end + tail.split(end, 1)[1]
        self.assertEqual(omit_hook(old), omit_hook(new))

    def test_frozen_v5_definition_bytes_remain_exact(self):
        self.assertEqual((v5.ROOT / "schemas/records/STREAM_ACQUISITION_PACKET_V5.json").read_bytes(), v5.PACKET_SCHEMA_BYTES)
        self.assertIn(b'"completeAuthority":false', v6.PACKET_SCHEMA_BYTES)
        self.assertIn(b'"executionTransactionInputCaptured":false', v6.PACKET_SCHEMA_BYTES)

    def test_native_complete_shape_with_explicitly_supplied_remaining_groups(self):
        with patch("socket.socket", side_effect=AssertionError("offline")), \
                patch.object(v5, "validate", side_effect=AssertionError("no old-version projection")), \
                patch.object(v5, "_packet", side_effect=AssertionError("version local")):
            self.assertEqual(v6.validate(dumps(self.native)), self.native)
        self.assertEqual(set(self.native), set(self.legacy))
        self.assertEqual(self.native["finality"]["fragment"]["bundle"]["content"]["rootHistory"][0]["record"][8], "7")
        value = copy.deepcopy(self.native); value.update(schema=v5.PACKET, version=5)
        with self.assertRaises(MuseumError): v5.validate(dumps(value))

    def test_native_requires_exact_fin_citation_and_paired_proof(self):
        for edit in (lambda v: v.update(contentRootProof=copy.deepcopy(self.legacy["contentRootProof"])),
                lambda v: v.update(finality=copy.deepcopy(self.legacy["finality"])),
                lambda v: v.update(citation=copy.deepcopy(self.legacy["citation"]))):
            value = copy.deepcopy(self.native); edit(value)
            with self.assertRaises(MuseumError): v6.validate(dumps(value))

    def test_native_checkpoint_cannot_precede_completed_target_mint(self):
        value = native_packet(self.assembly, checkpoint_before_mint=True)
        # All original native hashes/events are individually consistent. Only
        # the packet supplies the target mint chronology needed for this join.
        v6.finality.validate(dumps(value["finality"]["fragment"]))
        with self.assertRaisesRegex(MuseumError, "target completed mint must precede native checkpoint"):
            v6.validate(dumps(value))
        self.assertEqual(v6.validate(dumps(self.native)), self.native)

    def test_mode_script_and_all_nineteen_semantics_remain_required(self):
        for key, bad in (("metadataMode", "OFFCHAIN_HASH_BOUND"), ("workClass", "non_script")):
            value = copy.deepcopy(self.native); value[key] = bad
            with self.assertRaises(MuseumError): v6.validate(dumps(value))
        value = copy.deepcopy(self.native); value["rights"]["effectiveGrants"]["display"] = "unspecified"
        with self.assertRaises(MuseumError): v6.validate(dumps(value))

    def test_coherent_but_other_native_graph_and_artist_are_not_joinable(self):
        for key in ("metadata", "schemas", "store", "artist"):
            value = native_packet(self.assembly, graph_edit=lambda graph: graph[key].update(address="0x" + "99" * 20))
            v6.finality.validate(dumps(value["finality"]["fragment"]))
            with self.assertRaisesRegex(MuseumError, "shared native graph identities"):
                v6.validate(dumps(value))
        value = native_packet(self.assembly, artist_id=H("different-artist"))
        v6.finality.validate(dumps(value["finality"]["fragment"]))
        with self.assertRaisesRegex(MuseumError, "shared native Artist identity"):
            v6.validate(dumps(value))

    def test_original_token_proof_source_lifecycle_and_legacy_alias_conflicts(self):
        mutations = (lambda v: v["contentRootProof"].update(leafIndex="0"),
            lambda v: v["finality"]["fragment"]["identity"].update(collectionSerial="999"),
            lambda v: v["finality"]["fragment"]["sourceState"].update(blockHash=H("other-source")))
        for mutate in mutations:
            value = copy.deepcopy(self.native); mutate(value)
            with self.assertRaises(MuseumError): v6.validate(dumps(value))
        value = copy.deepcopy(self.native); original = value["finality"]["fragment"]
        value["tombstone"]["record"].update(recordHash=original["bundle"]["finality"]["record"][1],
            host=original["graph"]["finality"]["address"])
        with self.assertRaisesRegex(MuseumError, "cannot be relabeled"):
            v6.validate(dumps(value))


if __name__ == "__main__": unittest.main()

"""Concrete cross-source personhood assembly tests; all chain facts are synthetic."""
from contextlib import redirect_stdout
from copy import deepcopy
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from ..metadata import acquisition_packet_v4 as packet_v4
from ..metadata import acquisition_personhood_v1 as personhood_definition
from . import acquisition_conservation as conservation
from . import acquisition_personhood as assembly
from . import conservation_provider_binding as provider_binding
from . import conservation_rights as rights_binding
from . import public_conservation_floor_source as floor_source
from . import public_conservation_provider_capture as provider_capture
from . import public_conservation_provider_source as provider_source
from . import public_history_capture as rights_capture
from . import public_personhood_capture as personhood_capture
from . import public_personhood_source as personhood_source
from . import public_rights_source as rights_source
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO
from .test_native_conservation_fixture import NativeConservationFixture
from .test_public_conservation_provider_source import (PublicConservationProviderFixture,
    original_preimage)
from .test_public_personhood_source import PublicPersonhoodMixin, K


class NativePersonhoodAssemblyFixture(PublicPersonhoodMixin, NativeConservationFixture):
    """One response map for V4, RIGHTS/provider binding, and personhood readers."""
    set_configuration = PublicConservationProviderFixture.set_configuration
    set_gas = PublicConservationProviderFixture.set_gas

    def __init__(self, *, personhood_mode="resolved", platform_works=False, different_artist=False):
        super().__init__(paid=True)
        for anchor in (self.selection_anchor, self.tier_anchor, self.floor_anchor):
            anchor["environment"] = "public_chain"
        self.a["environment"] = "public_chain"

        # Add one real RIGHTS row using the existing Metadata/selector graph before
        # freezing its public-source anchor.
        conservation_selections = self.selections
        self.selections = {"collection": [], "token": []}
        self.a["rightsSelector"] = self.a["conservationSelector"]
        self.saved_rights = self.append("collection", "granted", block=1)
        self.update_heads()
        self.a.pop("rightsSelector")
        self.rights_selections, self.selections = self.selections, conservation_selections
        rights_anchor = deepcopy(self.selection_anchor)
        rights_anchor.pop("conservationSelector"); rights_anchor.pop("artistRegistry")
        rights_anchor.update(profile=rights_source.PROFILE, rightsSelector=self.a["conservationSelector"])

        # Install exact original provider configuration getters and registrations.
        self.raised = self.optional_reference = self.zero_executor = False
        self.unused_targets = "absent"
        PublicConservationProviderFixture._configure_provider(self)
        targets, hashes = list(self.configuration[0]), list(self.configuration[1])
        targets[8], hashes[8] = self.suite[0], self.pins[self.suite[0]]
        self.configuration = (tuple(targets), tuple(hashes), *self.configuration[2:])
        self.configuration_hash = keccak256(original_preimage(self.configuration))
        self.set_configuration(self.configuration)
        self.admitted_addresses = tuple(targets[index] for index in (0, 1, 2, 3, 4, 7, 8)) + (self.floor_executor,)

        existing_suite, existing_binding = self.suite, self.binding
        if different_artist:
            existing_binding = (K("different current synthetic Artist"), *existing_binding[1:])
        self.setup_personhood(mode=personhood_mode, current_graph={"registry": existing_suite[0],
            "coordinator": self.coordinator, "archive": existing_suite[1], "owners": existing_suite[2],
            "configuration": existing_suite}, current_binding=existing_binding)
        self._rewrite_floor(platform_works)

        # Refresh the three stored anchors after runtime/configuration additions.
        self.selection_anchor["codePins"] = self._pins_for(self.selection_anchor["codePins"])
        self.floor_anchor["codePins"] = self._pins_for([{"address": address, "runtimeHash": self.pins[address]}
            for address in (self.core, self.floor, self.floor_executor, self.floor_recorder)])
        rights_anchor["codePins"] = self._pins_for(rights_anchor["codePins"])
        self.rights_anchor = rights_anchor
        common = {key: self.selection_anchor[key] for key in provider_source.COMMON}
        self.provider_anchor = {"profile": provider_source.PROFILE, **common, "provider": self.floor_provider,
            "configurationHash": self.configuration_hash,
            "runtimeAdmission": {"sourceCommit": provider_source.SOURCE_REVISION, "kind": "synthetic_fixture",
                "artifactHash": K("combined synthetic provider artifact")},
            "codePins": self._pins_for([{"address": address, "runtimeHash": self.pins[address]}
                for address in (self.floor_provider, self.core, *self.admitted_addresses)])}

    def _pins_for(self, rows):
        addresses = dict.fromkeys(row["address"] for row in rows)
        return [{"address": address, "runtimeHash": self.pins[address]} for address in addresses]

    def _rewrite_floor(self, platform_works):
        row = decode((floor_source.SOURCE,), hex_bytes(self.responses[(self.floor,
            calldata("sourceAt(uint64)", ("uint64",), (1,)))]))[0]
        row = (*row[:3], self.pins[self.floor_provider], self.configuration_hash, *row[5:])
        empty = floor_source.empty_head({"chainId": self.a["chainId"], "core": self.core,
            "conservationFloor": self.floor})
        head = floor_source.next_head(empty, 1, row)
        self.add(self.floor, "sourceAt(uint64)", ("uint64",), (1,), (floor_source.SOURCE,), (row,))
        self.add(self.floor, "sourceSetHead()", (), (), ("uint64", "bytes32"), (1, head))
        self.add(self.floor, "sourceSetHashAt(uint64)", ("uint64",), (1,), ("bytes32",), (head,))
        admitted = next(log for receipt in self.receipts.values() for log in receipt["logs"]
            if log["address"] == self.floor and log["topics"][0] == floor_source.ADDED_EVENT)
        admitted["data"] = "0x" + encode(("bytes32", floor_source.SOURCE, "uint16"), (head, row, 1)).hex()

        first = decode((floor_source.FIRST,), hex_bytes(self.responses[(self.floor,
            calldata("firstSale(uint256)", ("uint256",), (1,)))]))[0]
        facts = list(first[8])
        if platform_works:
            facts = [ZERO, ZERO, ZERO, ZERO, ZERO, self.saved_rights["recordHash"], ZERO, True]
        else:
            facts[5] = self.saved_rights["recordHash"]
            facts[6] = self.native_hash if self.personhood_mode == "waiver" else self.summary_hash
            facts[7] = False
        anchor = {"chainId": self.a["chainId"], "core": self.core, "conservationFloor": self.floor}
        first = (ZERO, *first[1:7], head, tuple(facts))
        first = (floor_source.receipt_hash(anchor, floor_source.FIRST_DOMAIN, floor_source.FIRST, first), *first[1:])
        self.add(self.floor, "firstSale(uint256)", ("uint256",), (1,), (floor_source.FIRST,), (first,))
        first_event = next(log for receipt in self.receipts.values() for log in receipt["logs"]
            if log["address"] == self.floor and log["topics"][0] == floor_source.FIRST_EVENT)
        first_event["topics"][2] = first[0]
        first_event["data"] = "0x" + encode((floor_source.FIRST, "uint16"), (first, 1)).hex()

        release_event = next(log for receipt in self.receipts.values() for log in receipt["logs"]
            if log["address"] == self.floor and log["topics"][0] == floor_source.RELEASE_EVENT)
        old_release = decode((floor_source.RELEASE, "uint16"), hex_bytes(release_event["data"]))[0]
        release = (ZERO, *old_release[1:8], head, *old_release[9:])
        release = (floor_source.receipt_hash(anchor, floor_source.RELEASE_DOMAIN, floor_source.RELEASE, release), *release[1:])
        self.add(self.floor, "releaseFloorReceipt(bytes32)", ("bytes32",), (release[1],), (floor_source.RELEASE,), (release,))
        release_event["topics"][2] = release[0]
        release_event["data"] = "0x" + encode((floor_source.RELEASE, "uint16"), (release, 1)).hex()

        settled_event = next(log for receipt in self.receipts.values() for log in receipt["logs"]
            if log["address"] == self.floor and log["topics"][0] == floor_source.SETTLEMENT_EVENT)
        old = decode((floor_source.SETTLEMENT, "uint16"), hex_bytes(settled_event["data"]))[0]
        settled = (ZERO, *old[1:10], first[0], release[0], old[12])
        settled = (floor_source.receipt_hash(anchor, floor_source.SETTLEMENT_DOMAIN,
            floor_source.SETTLEMENT, settled), *settled[1:])
        self.add(self.floor, "settlementReceipt(bytes32)", ("bytes32",), (settled[3],),
            (floor_source.SETTLEMENT,), (settled,))
        settled_event["topics"][2] = settled[0]
        settled_event["data"] = "0x" + encode((floor_source.SETTLEMENT, "uint16"), (settled, 1)).hex()

    def rights_capture(self):
        adapter = rights_source.PublicRightsSource(dumps(self.rights_anchor), self)
        adapter.snapshot(); transcript = adapter.transcript()
        return rights_capture.replay("rights", adapter.anchor_bytes, keccak256(adapter.anchor_bytes),
            rights_source.PROFILE_HASH, transcript, keccak256(transcript),
            provenance="synthetic_fixture", disclosure="public")

    def provider_capture(self):
        adapter = provider_source.PublicConservationProviderSource(dumps(self.provider_anchor), self)
        adapter.snapshot(); transcript = adapter.transcript()
        return provider_capture.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes),
            provider_source.PROFILE_HASH, transcript, keccak256(transcript),
            provenance="synthetic_fixture", disclosure="public")

    def personhood_capture(self):
        adapter = self.source(); adapter.snapshot(); transcript = adapter.transcript()
        return personhood_capture.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes),
            personhood_source.PROFILE_HASH, transcript, keccak256(transcript),
            provenance="synthetic_fixture", disclosure="public")

    def packages(self):
        captures = self.captures()
        conserved = conservation.compose(*sum(([captures[role]["files"], captures[role]["manifestHash"]]
            for role in conservation.CAPTURES), []), disclosure="public",
            packet_schema_hash=packet_v4.PACKET_SCHEMA_HASH,
            conservation_schema_hash=packet_v4.CONSERVATION_SCHEMA_HASH)
        captured_rights = self.rights_capture()
        rights = rights_binding.compose(captures["floor"]["files"], captures["floor"]["manifestHash"],
            dict(captured_rights.files), captured_rights.manifest_hash, disclosure="public")
        provider = self.provider_capture()
        binding = provider_binding.compose(dict(rights.files), rights.manifest_hash,
            dict(provider.files), provider.manifest_hash, disclosure="public")
        personhood = self.personhood_capture()
        return conserved, binding, personhood


class AcquisitionPersonhoodTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = NativePersonhoodAssemblyFixture()
        cls.inputs = cls.fixture.packages()
        cls.result = assembly.compose(dict(cls.inputs[0].files), cls.inputs[0].manifest_hash,
            dict(cls.inputs[1].files), cls.inputs[1].manifest_hash,
            dict(cls.inputs[2].files), cls.inputs[2].manifest_hash, disclosure="public")

    def test_exact_packages_replayed_and_native_personhood_remains_partial(self):
        result = self.result; files = dict(result.files); fragment = result.report["personhood"]
        self.assertEqual(fragment["status"], "current_resolved_summary_matches_saved")
        self.assertEqual(fragment["current"]["artistId"], fragment["firstSale"]["artistId"])
        self.assertEqual(fragment["current"]["evidenceHash"], fragment["firstSale"]["personhoodEvidenceHash"])
        self.assertEqual(fragment["current"]["evidenceHashDomain"], "personhood_proof_summary")
        self.assertFalse(result.report["items"][5]["canonicalPacketCompatible"])
        self.assertFalse(fragment["legalPersonhoodProven"])
        self.assertFalse(fragment["canonicalNotarizationFieldReady"])
        native = personhood_definition.validate(files["packet/native-personhood.json"])
        self.assertEqual(native["schema"], personhood_definition.NAME)
        self.assertEqual(native["sourceRef"], result.report["nativePersonhood"]["sourceRef"])
        self.assertEqual(native["general"]["attestation"][1], "7")
        self.assertNotEqual(native["general"]["attestation"][1], native["sourceState"]["collectionId"])
        self.assertEqual(native["general"]["authority"]["kind"], "native_general_receipt")
        self.assertFalse(result.report["nativePersonhood"]["legacyPacketPersonhoodAdapted"])
        self.assertEqual(files["definitions/native-personhood-schema.json"], personhood_definition.SCHEMA_BYTES)
        for prefix, original in (("conservation-assembly/", self.inputs[0]),
                ("provider-binding/", self.inputs[1]), ("personhood-capture/", self.inputs[2])):
            self.assertEqual({path.removeprefix(prefix): raw for path, raw in files.items()
                if path.startswith(prefix)}, dict(original.files))

    def test_offline_verify_and_rehashed_semantic_tamper_reject(self):
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            self.assertEqual(assembly.verify(dict(self.result.files), self.result.manifest_hash).files,
                self.result.files)
        for path, field in (("packet/personhood.json", "legalPersonhoodProven"),
                ("packet/native-personhood.json", "qualification")):
            files = dict(self.result.files); value = loads(files[path], maximum=1024 * 1024)
            value[field] = True if field == "legalPersonhoodProven" else "caller supplied"
            files[path] = dumps(value)
            manifest = loads(files["manifest.json"], maximum=1024 * 1024)
            manifest["files"] = [assembly.base._ref(name, raw) for name, raw in sorted(files.items())
                if name != "manifest.json"]
            files["manifest.json"] = dumps(manifest)
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, "reconstruction differs|invalid supplied"):
                assembly.verify(files, keccak256(files["manifest.json"]))

    def test_complete_packet_and_private_disclosure_fail_closed(self):
        with self.assertRaisesRegex(MuseumError, "complete canonical packet unavailable"):
            assembly.complete_packet(dict(self.result.files), self.result.manifest_hash)
        class Unreadable:
            def __iter__(self): raise AssertionError("input inspected before disclosure")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            assembly.compose(Unreadable(), K("one"), Unreadable(), K("two"), Unreadable(), K("three"),
                disclosure="restricted")

    def test_native_waiver_uses_record_hash_domain_without_becoming_proof(self):
        fixture = NativePersonhoodAssemblyFixture(personhood_mode="waiver")
        inputs = fixture.packages()
        result = assembly.compose(dict(inputs[0].files), inputs[0].manifest_hash,
            dict(inputs[1].files), inputs[1].manifest_hash,
            dict(inputs[2].files), inputs[2].manifest_hash, disclosure="public")
        fragment = result.report["personhood"]
        self.assertEqual(fragment["status"], "current_waiver_matches_saved")
        self.assertEqual(fragment["current"]["evidenceHashDomain"], "native_op24_record")
        self.assertEqual(fragment["current"]["evidenceHash"], fragment["firstSale"]["personhoodEvidenceHash"])
        self.assertFalse(fragment["legalPersonhoodProven"])

    def test_stale_head_and_changed_artist_do_not_identify_historical_commitment(self):
        fixture = NativePersonhoodAssemblyFixture(personhood_mode="stale_head"); inputs = fixture.packages()
        result = assembly.compose(dict(inputs[0].files), inputs[0].manifest_hash,
            dict(inputs[1].files), inputs[1].manifest_hash,
            dict(inputs[2].files), inputs[2].manifest_hash, disclosure="public")
        self.assertEqual(result.report["personhood"]["status"],
            "saved_commitment_not_currently_identifiable")
        # Isolate the explicit Artist-ID guard on otherwise retained, verified package state.
        personhood_files = dict(self.inputs[2].files)
        snapshot = loads(personhood_files["source/snapshot.json"], maximum=64 * 1024 * 1024)
        snapshot["current"]["artistId"] = K("rotated current Artist")
        personhood_files["source/snapshot.json"] = dumps(snapshot)
        fragment = assembly._join(dict(self.inputs[0].files), dict(self.inputs[1].files), personhood_files)
        self.assertEqual(fragment["status"], "saved_commitment_not_currently_identifiable")

    def test_platform_floor_does_not_promote_current_personhood_to_requirement(self):
        fixture = NativePersonhoodAssemblyFixture(platform_works=True); inputs = fixture.packages()
        result = assembly.compose(dict(inputs[0].files), inputs[0].manifest_hash,
            dict(inputs[1].files), inputs[1].manifest_hash,
            dict(inputs[2].files), inputs[2].manifest_hash, disclosure="public")
        self.assertEqual(result.report["personhood"]["status"], "not_required_platform_floor")
        self.assertFalse(result.report["personhood"]["legalPersonhoodProven"])

    def test_exact_shared_floor_and_provider_personhood_dependency_are_required(self):
        other = NativePersonhoodAssemblyFixture(personhood_mode="waiver").packages()
        with self.assertRaisesRegex(MuseumError, "shared floor capture differs"):
            assembly.compose(dict(self.inputs[0].files), self.inputs[0].manifest_hash,
                dict(other[1].files), other[1].manifest_hash,
                dict(self.inputs[2].files), self.inputs[2].manifest_hash, disclosure="public")
        from .test_public_personhood_source import PublicPersonhoodFixture
        standalone = PublicPersonhoodFixture(); source = standalone.source(); source.snapshot()
        transcript = source.transcript()
        capture = personhood_capture.replay(source.anchor_bytes, keccak256(source.anchor_bytes),
            personhood_source.PROFILE_HASH, transcript, keccak256(transcript),
            provenance="synthetic_fixture", disclosure="public")
        with self.assertRaisesRegex(MuseumError, "shared runtime differs|provider dependency differs"):
            assembly.compose(dict(self.inputs[0].files), self.inputs[0].manifest_hash,
                dict(self.inputs[1].files), self.inputs[1].manifest_hash,
                dict(capture.files), capture.manifest_hash, disclosure="public")

    def test_cli_and_common_dispatch_reconstruct_offline_and_publish_atomically(self):
        from .package_v2 import verify_package
        with TemporaryDirectory() as temp:
            root = Path(temp); paths = []
            for name, value in zip(("conservation", "binding", "personhood"), self.inputs):
                path = root / name; write_tree(dict(value.files), path); paths.append(path)
            output = root / "assembled"; stdout = io.StringIO()
            argv = ["assemble", "--conservation", str(paths[0]), "--conservation-hash", self.inputs[0].manifest_hash,
                "--provider-binding", str(paths[1]), "--provider-binding-hash", self.inputs[1].manifest_hash,
                "--personhood", str(paths[2]), "--personhood-hash", self.inputs[2].manifest_hash,
                "--disclosure", "public", "--output", str(output)]
            with patch("socket.socket", side_effect=AssertionError("offline only")), redirect_stdout(stdout):
                assembly.main(argv)
            message = loads(stdout.getvalue().encode())
            self.assertEqual(message["manifestHash"], self.result.manifest_hash)
            self.assertEqual(read_tree(output), dict(self.result.files))
            with patch("socket.socket", side_effect=AssertionError("offline only")):
                self.assertEqual(verify_package(output, self.result.manifest_hash).files, self.result.files)
            before = read_tree(output)
            with self.assertRaisesRegex(MuseumError, "new directory"):
                assembly.main(argv)
            self.assertEqual(read_tree(output), before)


if __name__ == "__main__": unittest.main()

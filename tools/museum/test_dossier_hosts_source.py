"""Synthetic current-registry roster controls; no actual-chain acceptance."""
from copy import deepcopy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import calldata, decode, encode
from .chain_rpc import ReplayTransport
from . import dossier_hosts_source as hosts
from .independent_wire import RECORD_TYPES, ZERO


def H(label):
    return keccak256(str(label).encode())


def A(number):
    return "0x" + number.to_bytes(20, "big").hex()


class FixtureTransport:
    def __init__(self, fixture):
        self.f = fixture
        self.calls = []

    @staticmethod
    def _args(data, kinds):
        return decode(kinds, hex_bytes(data)[4:])

    @staticmethod
    def _result(kinds, values):
        return "0x" + encode(kinds, values).hex()

    def request(self, method, params):
        self.calls.append((method, deepcopy(params)))
        f = self.f
        if method == "eth_chainId":
            return "0x7a69"
        if method == "eth_getBlockByHash":
            return deepcopy(f.block)
        if method == "eth_getCode":
            target = params[0]
            raw = f.runtimes.get(target, b"")
            if target == f.metadata and f.mode == "metadata_runtime":
                raw = b"changed"
            return "0x" + raw.hex()
        if method != "eth_call":
            raise MuseumError("unexpected dossier host fixture method")
        target, data = params[0]["to"], params[0]["data"]
        if target == f.future_owner:
            raise MuseumError("unsupported version host must not be called")
        if target == f.core:
            if data.startswith(calldata("tokenCollectionIdentity(uint256)")[:10]):
                token, = self._args(data, ("uint256",))
                return self._result(("bool", "uint256", "uint256", "bool"),
                    (token == 7, 1, 3, False))
            if data.startswith(calldata("getSatellitePointer(bytes32)")[:10]):
                pointer_type, = self._args(data, ("bytes32",))
                pointer = f.registry_pointer if pointer_type == hosts.MODULE_REGISTRY else f.metadata_pointer
                return self._result((hosts.POINTER,), (pointer,))
        if target == f.registry:
            if data.startswith(calldata("supportsInterface(bytes4)")[:10]):
                return self._result(("bool",), (True,))
            if data.startswith(calldata("moduleCount()")[:10]):
                count = len(f.records) + (1 if f.mode == "count" else 0)
                return self._result(("uint256",), (count,))
            if data.startswith(calldata("registrationChainHash()")[:10]):
                chain = H("wrong-chain") if f.mode == "chain" else f.registration_chain
                return self._result(("bytes32", "uint64"), (chain, len(f.records)))
            if data.startswith(calldata("moduleAt(uint256)")[:10]):
                index, = self._args(data, ("uint256",))
                address = f.records[index][0]
                if f.mode == "duplicate" and index == 1:
                    address = f.records[0][0]
                return self._result(("address",), (address,))
            if data.startswith(calldata("moduleRecord(address)")[:10]):
                address, = self._args(data, ("address",))
                record = next(row for module, row in f.records if module == address)
                return self._result((hosts.MODULE_RECORD,), (record,))
        identity = f.identities.get(target)
        if identity is not None:
            module_type, version, interface, core = identity
            if data.startswith(calldata("streamModuleType()")[:10]):
                return self._result(("bytes32",), (module_type,))
            if data.startswith(calldata("streamModuleVersion()")[:10]):
                return self._result(("bytes32",), (version,))
            if data.startswith(calldata("streamModuleInterfaceId()")[:10]):
                return self._result(("bytes4",), (interface,))
            if data.startswith(calldata("supportsInterface(bytes4)")[:10]):
                return self._result(("bool",), (True,))
            if data.startswith(calldata("core()")[:10]):
                if target == f.metadata and f.mode == "metadata_core":
                    core = A(99)
                return self._result(("address",), (core,))
            if data.startswith(calldata("isIndependentRecordType(bytes32)")[:10]):
                record_type, = self._args(data, ("bytes32",))
                accepted = record_type in RECORD_TYPES
                if f.mode == "independent_type" and record_type == RECORD_TYPES[-1]:
                    accepted = False
                return self._result(("bool",), (accepted,))
            if data.startswith(calldata("recordTypeCount()")[:10]):
                return self._result(("uint256",), (len(f.metadata_types),))
            if data.startswith(calldata("recordTypeAt(uint256)")[:10]):
                index, = self._args(data, ("uint256",))
                return self._result(("bytes32",), (f.metadata_types[index],))
            if data.startswith(calldata("recordPolicy(bytes32)")[:10]):
                record_type, = self._args(data, ("bytes32",))
                return self._result((hosts.POLICY,), ((H("family-" + record_type), 1 << 8, True),))
            if data.startswith(calldata("recordChainHash(uint256,bytes32)")[:10]):
                scope, record_type = self._args(data, ("uint256", "bytes32"))
                populated = (target == f.independent and scope == 1
                    and record_type == RECORD_TYPES[-1])
                return self._result(("bytes32", "uint64"),
                    (H("lane") if populated else ZERO, 2 if populated else 0))
        raise MuseumError("unexpected dossier host fixture call")


class Fixture:
    def __init__(self, mode=None, *, selected_outside=False):
        self.mode = mode
        self.core, self.registry = A(1), A(2)
        self.owner, self.independent, self.metadata = A(3), A(4), A(5)
        self.future_owner, self.foreign_owner, self.other = A(6), A(7), A(8)
        if selected_outside:
            self.metadata = A(9)
        self.block = {"hash": H("block"), "number": "0x2a", "timestamp": "0x64",
            "stateRoot": H("state"), "transactions": []}
        addresses = (self.core, self.registry, self.owner, self.independent,
            self.metadata, self.future_owner, self.foreign_owner, self.other)
        self.runtimes = {address: b"\x60" + bytes([position + 1])
            for position, address in enumerate(addresses)}
        owner_version = hosts.VERSIONS[hosts.OWNER_RECORDS][1]
        independent_version = hosts.VERSIONS[hosts.COLLECTION_ATTESTATIONS][1]
        metadata_version = hosts.VERSIONS[hosts.COLLECTION_METADATA][1]
        selected_version = H("future-metadata") if selected_outside else metadata_version
        self.interfaces = {address: "0x" + (100 + position).to_bytes(4, "big").hex()
            for position, address in enumerate(addresses)}
        specs = [
            (self.owner, 1, hosts.OWNER_RECORDS, owner_version, self.core),
            (self.independent, 2, hosts.COLLECTION_ATTESTATIONS, independent_version, self.core),
        ]
        if not selected_outside:
            specs.append((self.metadata, 3, hosts.COLLECTION_METADATA, metadata_version, self.core))
        specs.extend(((self.future_owner, 1, hosts.OWNER_RECORDS, H("owner-v2"), self.core),
            (self.foreign_owner, 1, hosts.OWNER_RECORDS, owner_version, A(99)),
            (self.other, 1, H("unrelated-type"), H("unrelated-version"), self.core)))
        self.records = []
        self.identities = {}
        for position, (address, status, module_type, version, core) in enumerate(specs):
            interface = self.interfaces[address]
            record = (status, module_type, version, interface, 200000,
                keccak256(self.runtimes[address]), H("deployment"), H("manifest-" + address),
                "" if address == self.future_owner else "https://example.test/" + str(position),
                10 + position, 20 + position, 1)
            self.records.append((address, record))
            self.identities[address] = (module_type, version, interface, core)
        self.identities[self.metadata] = (hosts.COLLECTION_METADATA, selected_version,
            self.interfaces[self.metadata], self.core)
        self.registration_chain = ZERO
        for index, (address, record) in enumerate(self.records):
            record_hash = keccak256(encode(("bytes32", "address", "bytes32", "bytes4",
                "bytes32", "bytes32", "bytes32", "bytes32"),
                (schema_id("6529STREAM_MODULE_REGISTRATION_RECORD_V1"), address, record[1],
                 record[3], record[2], record[5], record[6], record[7])))
            self.registration_chain = keccak256(encode(("bytes32", "uint256", "address",
                "uint256", "bytes32", "bytes32", "bytes32", "uint64"),
                (schema_id("6529STREAM_RECORD_CHAIN_V1"), 31337, self.registry, 0,
                 schema_id("MODULE_REGISTRATION"), self.registration_chain, record_hash, index)))
        registry_interface = "0x00000091"
        metadata_interface = self.interfaces[self.metadata]
        self.registry_pointer = (self.registry, keccak256(self.runtimes[self.registry]), False,
            hosts.MODULE_REGISTRY, registry_interface, self.registry, 1,
            H("registry-manifest"), H("deployment"), 1)
        selected_registry = A(77) if selected_outside else self.registry
        selected_manifest = (H("metadata-manifest") if selected_outside else
            next(record for address, record in self.records if address == self.metadata)[7])
        self.metadata_pointer = (self.metadata, keccak256(self.runtimes[self.metadata]), False,
            hosts.COLLECTION_METADATA, metadata_interface, selected_registry, 1,
            selected_manifest, H("deployment"), 2)
        self.metadata_types = (H("metadata-type-a"), H("metadata-type-b"))
        self.anchor = {"profile": hosts.PROFILE, "chainId": "31337",
            "blockHash": self.block["hash"], "blockNumber": "42", "timestamp": "100",
            "stateRoot": self.block["stateRoot"], "environment": "local_evm_fixture",
            "deploymentEvidenceHash": H("deployment"), "core": self.core,
            "coreRuntimeHash": keccak256(self.runtimes[self.core]), "tokenId": "7",
            "collectionId": "1"}
        self.transport = FixtureTransport(self)

    def source(self, **kwargs):
        return hosts.DossierHostsSource(dumps(self.anchor), self.transport, **kwargs)


class DossierHostsSourceTests(unittest.TestCase):
    def test_complete_current_registry_roster_preserves_statuses_and_qualification(self):
        f = Fixture(); source = f.source()
        with patch("socket.socket", side_effect=AssertionError("source reader used network")):
            value = loads(source.snapshot(), maximum=1048576, canonical=True)
        self.assertEqual(value["profileHash"], hosts.PROFILE_HASH)
        self.assertEqual(value["sourceState"], {"chainId": "31337", "core": f.core,
            "tokenId": "7", "collectionId": "1", "collectionSerial": "3",
            "burned": False, "blockHash": f.block["hash"], "blockNumber": "42"})
        self.assertEqual(value["registry"]["moduleCount"], "6")
        self.assertEqual([row["status"] for row in value["registry"]["modules"][:3]],
            ["ACTIVE", "DEPRECATED", "INCIDENT_REVOKED"])
        self.assertEqual(value["selectedMetadata"]["host"], f.metadata)
        self.assertEqual(next(row for row in value["hosts"] if row["host"] == f.metadata)["source"],
            "registry_and_selected_metadata")
        self.assertTrue(value["claims"]["currentRegistryEnumerationComplete"])
        self.assertTrue(value["claims"]["currentSelectedMetadataBound"])
        for claim in ("hostInventoryExhaustive", "alternateRegistryHistoryComplete",
                      "unregisteredCompatibleWritersExcluded", "laneHistoriesComplete",
                      "actualChainAcceptance", "cryptographicStateProof",
                      "fullObjectDossierConformance"):
            self.assertFalse(value["claims"][claim])
        self.assertIn("host_inventory_not_exhaustive", value["unresolved"])
        self.assertEqual(source.snapshot(), source.snapshot())

    def test_scope_catalogues_are_native_and_owner_denominator_stays_unresolved(self):
        f = Fixture(); value = loads(f.source().snapshot(), maximum=1048576, canonical=True)
        owner = next(row for row in value["hosts"] if row["host"] == f.owner)
        independent = next(row for row in value["hosts"] if row["host"] == f.independent)
        metadata = next(row for row in value["hosts"] if row["host"] == f.metadata)
        self.assertEqual(owner["scopes"], ["7"])
        self.assertEqual(owner["catalog"]["mode"], "unresolved_no_native_type_enumeration")
        self.assertEqual(independent["scopes"], ["0", "1"])
        self.assertEqual(len(independent["catalog"]["scopeHeads"]), 16)
        self.assertEqual({row["scopeKey"] for row in independent["catalog"]["scopeHeads"]},
            {"0", "1"})
        self.assertEqual(metadata["scopes"], ["1"])
        self.assertEqual(len(metadata["catalog"]["scopeHeads"]), 2)
        type_calls = [row for row in f.transport.calls if row[0] == "eth_call"
            and row[1][0]["data"].startswith(calldata("isIndependentRecordType(bytes32)")[:10])]
        self.assertEqual(len(type_calls), 8)

    def test_unsupported_and_foreign_hosts_are_explicit_and_never_read_as_empty(self):
        f = Fixture(); value = loads(f.source().snapshot(), maximum=1048576, canonical=True)
        future = next(row for row in value["hosts"] if row["host"] == f.future_owner)
        foreign = next(row for row in value["hosts"] if row["host"] == f.foreign_owner)
        self.assertEqual(future["resolution"], "unsupported_registered_version")
        self.assertEqual(future["catalog"]["mode"], "unresolved")
        self.assertEqual(next(row for row in value["registry"]["modules"]
            if row["host"] == f.future_owner)["moduleManifestURI"], "")
        self.assertEqual(foreign["resolution"], "foreign_core")
        self.assertEqual(foreign["catalog"]["scopeHeads"], [])
        lane_targets = [row[1][0]["to"] for row in f.transport.calls if row[0] == "eth_call"
            and row[1][0]["data"].startswith(calldata("recordChainHash(uint256,bytes32)")[:10])]
        self.assertNotIn(f.future_owner, lane_targets)
        self.assertNotIn(f.foreign_owner, lane_targets)

    def test_future_selected_metadata_outside_registry_is_bound_but_catalogue_unresolved(self):
        f = Fixture(selected_outside=True)
        value = loads(f.source().snapshot(), maximum=1048576, canonical=True)
        selected = next(row for row in value["hosts"] if row["host"] == f.metadata)
        self.assertEqual(selected["source"], "selected_metadata")
        self.assertEqual(selected["core"], f.core)
        self.assertFalse(selected["supported"])
        self.assertEqual(selected["resolution"], "selected_metadata_version_unresolved")
        self.assertTrue(value["claims"]["currentSelectedMetadataBound"])
        self.assertIn("selected_metadata_not_in_current_registry", value["unresolved"])

    def test_same_registry_selected_pointer_requires_append_only_registered_row(self):
        f = Fixture(selected_outside=True)
        pointer = list(f.metadata_pointer); pointer[5] = f.registry
        f.metadata_pointer = tuple(pointer)
        with self.assertRaisesRegex(MuseumError, "missing from named current registry"):
            f.source().snapshot()
        # The identical absent target remains an explicit unresolved fallback when the
        # cached pointer names a different registry instance.
        value = loads(Fixture(selected_outside=True).source().snapshot(),
            maximum=1048576, canonical=True)
        self.assertIn("selected_metadata_not_in_current_registry", value["unresolved"])

    def test_same_registry_selected_pointer_immutable_manifest_hashes_are_exact(self):
        for position in (7, 8):
            f = Fixture(); pointer = list(f.metadata_pointer); pointer[position] = H("wrong")
            f.metadata_pointer = tuple(pointer)
            with self.subTest(position=position), self.assertRaisesRegex(MuseumError,
                    "immutable manifests differ"):
                f.source().snapshot()

    def test_chain_counts_pointer_runtime_core_and_fixed_catalogue_are_fail_closed(self):
        cases = ("count", "chain", "duplicate", "metadata_runtime", "metadata_core",
            "independent_type")
        for mode in cases:
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                Fixture(mode).source().snapshot()

    def test_transcript_replay_and_external_pins_are_exact_and_offline(self):
        f = Fixture(); source = f.source(); expected = source.snapshot()
        transcript = source.transcript(); anchor = dumps(f.anchor)
        replayed = hosts.DossierHostsSource(anchor,
            ReplayTransport(transcript, keccak256(transcript)))
        self.assertEqual(replayed.snapshot(), expected)
        with tempfile.TemporaryDirectory() as root:
            root = Path(root); anchor_path = root / "anchor.json"; transcript_path = root / "rpc.json"
            anchor_path.write_bytes(anchor); transcript_path.write_bytes(transcript)
            output = root / "result"
            with patch("socket.socket", side_effect=AssertionError("replay used network")):
                pins = hosts.replay(anchor_path, keccak256(anchor), transcript_path,
                    keccak256(transcript), output)
            self.assertEqual(pins["snapshotHash"], keccak256(expected))
            self.assertEqual((output / "snapshot.json").read_bytes(), expected)
            with self.assertRaises(MuseumError):
                hosts.replay(anchor_path, H("wrong"), transcript_path,
                    keccak256(transcript), root / "wrong")

    def test_profile_generator_is_exact_and_check_mode_rejects_changes(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertEqual(hosts.definitions(root), hosts.PROFILE_HASH)
            path = Path(root) / "dossier-hosts-profile.json"
            self.assertEqual(path.read_bytes(), hosts.PROFILE_BYTES)
            self.assertEqual(hosts.definitions(root, check=True), hosts.PROFILE_HASH)
            path.write_bytes(b"{}")
            with self.assertRaises(MuseumError):
                hosts.definitions(root, check=True)

    def test_anchor_is_closed_and_caller_cannot_declare_hosts_or_scopes(self):
        f = Fixture(); value = deepcopy(f.anchor); value["hosts"] = []
        with self.assertRaisesRegex(MuseumError, "anchor shape"):
            hosts.DossierHostsSource(dumps(value), f.transport)


if __name__ == "__main__":
    unittest.main()

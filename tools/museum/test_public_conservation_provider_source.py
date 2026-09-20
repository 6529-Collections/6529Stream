"""Synthetic native getter/receipt controls; no deployed provider or paid-floor acceptance."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values
from . import public_conservation_provider_source as source
from . import public_conservation_floor_source as floor
from .public_history_rpc import PublicReplayTransport, PublicRpcTransport
from .test_conservation_rights import ConservationRightsFixture, K, A, H


NAMES = tuple("CONSERVATION_PROVIDER_" + part + "_GAS" for part in ("READ", "SOURCE", "REFERENCE"))
IDS = tuple(K("6529STREAM_GGP_" + name) for name in NAMES)
GAS = ("string", "uint256", "uint256", "uint8")
CONFIG = (("address",) * 10, ("bytes32",) * 10, "address", GAS, GAS, GAS)
REGISTERED = K("GasParameterRegistered(uint16,bytes32,string,uint256,uint256,uint8)")
REGISTERED_DATA = ("uint16", "string", "uint256", "uint256", "uint8")
DOMAIN = K("6529STREAM_NATIVE_CONSERVATION_PROVIDER_V1")


def original_preimage(config, chain=31337):
    """Independent fixed-array/dynamic-tuple layout, including the outer Configuration offset."""
    word = lambda value: value.to_bytes(32, "big")
    heads = b"".join(bytes(12) + hex_bytes(address, 20) for address in config[0])
    heads += b"".join(hex_bytes(digest, 32) for digest in config[1])
    heads += bytes(12) + hex_bytes(config[2], 20)
    tails = []
    for name, genesis, minimum, failure in config[3:]:
        raw = name.encode("utf-8")
        tails.append(word(128) + word(genesis) + word(minimum) + word(failure)
            + word(len(raw)) + raw + bytes(-len(raw) % 32))
    offset = 24 * 32
    for tail in tails:
        heads += word(offset)
        offset += len(tail)
    return hex_bytes(DOMAIN, 32) + word(chain) + word(96) + heads + b"".join(tails)


class PublicConservationProviderFixture(ConservationRightsFixture):
    """One exact synthetic response map for original RIGHTS, floor, and provider captures."""
    def __init__(self, *, raised=False, optional_reference=False, unused_targets="absent", zero_executor=False,
            mode="joined", family="universal"):
        self.raised, self.optional_reference = raised, optional_reference
        self.unused_targets, self.zero_executor = unused_targets, zero_executor
        super().__init__(mode=mode, family=family)
        if mode == "empty": self._configure_provider()
        self.provider_anchor = {key: self.a[key] for key in ("chainId", "core", "collectionId", "blockHash",
            "blockNumber", "timestamp", "stateRoot", "environment", "deploymentEvidenceHash")}
        self.provider_anchor.update(profile=source.PROFILE, provider=self.floor_provider,
            configurationHash=self.configuration_hash,
            runtimeAdmission={"sourceCommit": source.SOURCE_REVISION, "kind": "synthetic_fixture",
                "artifactHash": K("synthetic provider artifact for " + source.SOURCE_REVISION)},
            codePins=[{"address": address, "runtimeHash": self.pins[address]}
                for address in dict.fromkeys((self.floor_provider, self.core, *self.admitted_addresses))])
        self.a = self.provider_anchor

    def _paid(self, _old_head):
        self._configure_provider()
        # Replace the original saved configuration commitment before creating any paid receipt.
        # The floor admission event, getters, first/release/settlement hash links all use this head.
        row = decode((floor.SOURCE,), hex_bytes(self.responses[(self.floor, calldata("sourceAt(uint64)", ("uint64",), (1,)))]))[0]
        row = (*row[:3], self.pins[self.floor_provider], self.configuration_hash, *row[5:])
        head = floor.next_head(floor.empty_head(self.hash_anchor), 1, row)
        self.add(self.floor, "sourceAt(uint64)", ("uint64",), (1,), (floor.SOURCE,), (row,))
        self.add(self.floor, "sourceSetHead()", (), (), ("uint64", "bytes32"), (1, head))
        self.add(self.floor, "sourceSetHashAt(uint64)", ("uint64",), (1,), ("bytes32",), (head,))
        event = next(log for log in self.receipts[H(402)]["logs"] if log["topics"][0] == floor.ADDED_EVENT)
        event["data"] = "0x" + encode(("bytes32", floor.SOURCE, "uint16"), (head, row, 1)).hex()
        super()._paid(head)

    def _configure_provider(self):
        self.codes[self.floor_provider] = ("synthetic StreamNativeConservationFloorProvider originalConfiguration "
            + source.SOURCE_REVISION).encode("ascii")
        self.pins[self.floor_provider] = keccak256(self.codes[self.floor_provider])
        targets = [self.core, A(1), A(3), A(4), A(8), A(10005), A(10006), A(5), A(10008), ZERO_ADDRESS]
        for address in (A(10008),) + ((A(10009),) if self.optional_reference else ()):
            self.codes[address] = ("synthetic admitted dependency " + address).encode("ascii")
            self.pins[address] = keccak256(self.codes[address])
        if self.optional_reference: targets[9] = A(10009)
        hashes = [self.pins.get(address, H(index + 100)) for index, address in enumerate(targets)]
        if not self.optional_reference: hashes[9] = ZERO
        if self.unused_targets == "zero":
            targets[5], hashes[6] = ZERO_ADDRESS, ZERO
        elif self.unused_targets != "absent": raise ValueError("unknown synthetic unused target mode")
        executor = ZERO_ADDRESS if self.zero_executor else self.floor_executor
        self.original_gas = ((NAMES[0], 400000, 100000, 2), (NAMES[1], 2000000, 500000, 2),
            (NAMES[2], 3000000, 500000, 2))
        self.configuration = (tuple(targets), tuple(hashes), executor, *self.original_gas)
        self.configuration_hash = keccak256(original_preimage(self.configuration))
        self.admitted_addresses = tuple(targets[index] for index in (0, 1, 2, 3, 4, 7, 8))
        if self.optional_reference: self.admitted_addresses += (targets[9],)
        if executor != ZERO_ADDRESS: self.admitted_addresses += (executor,)
        self.set_configuration(self.configuration)
        for interface, expected in ((source.PROVIDER_INTERFACE, True), ("0x01ffc9a7", True), ("0xffffffff", False)):
            self.add(self.floor_provider, "supportsInterface(bytes4)", ("bytes4",), (interface,), ("bool",), (expected,))
        for getter, kind, value in (("core", "address", self.core), ("coreCodeHash", "bytes32", hashes[0]),
                ("metadata", "address", targets[1]), ("metadataCodeHash", "bytes32", hashes[1]),
                ("deploymentChainId", "uint256", 31337), ("governanceAuthority", "address", executor)):
            self.add(self.floor_provider, getter + "()", (), (), (kind,), (value,))
        self.add(self.floor_provider, "gasParameterIds()", (), (), (Array("bytes32", 3),), (IDS,))
        self.registration_events = []
        self.current_gas = []
        for index, (parameter, config) in enumerate(zip(IDS, self.original_gas)):
            current = (config[1] * 2, config[2], 2, 2) if self.raised and index == 0 else (config[1], config[2], 2, 1)
            self.current_gas.append(current)
            self.set_gas(index, current)
            self.registration_events.append(self.event(0, self.floor_provider, [REGISTERED, parameter],
                REGISTERED_DATA, (2, *config)))

    def set_configuration(self, config, *, digest=None):
        self.add(self.floor_provider, "originalConfiguration()", (), (), (CONFIG,), (config,))
        self.add(self.floor_provider, "configurationHash()", (), (), ("bytes32",),
            (keccak256(original_preimage(config)) if digest is None else digest,))

    def set_gas(self, index, values, *, direct_value=None):
        self.add(self.floor_provider, "gasParameterInfo(bytes32)", ("bytes32",), (IDS[index],),
            ("uint256", "uint256", "uint8", "uint64"), values)
        self.add(self.floor_provider, "gasParameter(bytes32)", ("bytes32",), (IDS[index],), ("uint256",),
            (values[0] if direct_value is None else direct_value,))

    def source(self, **kwargs): return source.PublicConservationProviderSource(dumps(self.a), self, **kwargs)

    def result(self): return loads(self.source().snapshot(), maximum=source.MAX_OUTPUT)


class PublicConservationProviderSourceTests(unittest.TestCase):
    def test_exact_dynamic_configuration_hash_and_native_registration_layout(self):
        fixture = PublicConservationProviderFixture()
        self.assertEqual(source.CONFIG, CONFIG)
        self.assertEqual(source.GAS, GAS)
        self.assertEqual(tuple(source.PARAMETER_NAMES), NAMES)
        self.assertEqual(tuple(source.PARAMETER_IDS), IDS)
        self.assertEqual(source.REGISTERED_EVENT, REGISTERED)
        self.assertEqual(source.REGISTERED_DATA, REGISTERED_DATA)
        raw = original_preimage(fixture.configuration)
        self.assertEqual(raw, encode(("bytes32", "uint256", CONFIG), (DOMAIN, 31337, fixture.configuration)))
        self.assertEqual(int.from_bytes(raw[64:96], "big"), 96)
        self.assertNotEqual(keccak256(raw), keccak256(encode((CONFIG,), (fixture.configuration,))))
        result = fixture.result()
        self.assertEqual(result["configurationHash"], keccak256(raw))
        self.assertEqual(result["configuration"], json_values(fixture.configuration))
        self.assertEqual(len(result["registrationEvents"]), 3)

    def test_original_saved_floor_configuration_and_rights_remain_concrete_replayable(self):
        fixture = PublicConservationProviderFixture()
        provider = fixture.result()
        captures = fixture.captures()
        floor_snapshot = loads(dict(captures["floor"].files)["source/snapshot.json"], maximum=32 * 1024 * 1024)
        self.assertEqual(floor_snapshot["catalogue"]["sources"][0]["source"][4], provider["configurationHash"])
        self.assertEqual(floor_snapshot["floor"]["firstSale"]["receipt"][8][5], fixture.saved["recordHash"])

    def test_original_configuration_does_not_become_current_raised_gas(self):
        plain = PublicConservationProviderFixture(); raised = PublicConservationProviderFixture(raised=True)
        a, b = plain.result(), raised.result()
        self.assertEqual(a["configuration"], b["configuration"])
        self.assertEqual(a["configurationHash"], b["configurationHash"])
        self.assertEqual(a["originalGas"], b["originalGas"])
        self.assertNotEqual(a["currentGas"], b["currentGas"])

    def test_unused_slots_and_optional_zero_retained_without_runtime_probes(self):
        for mode in ("absent", "zero"):
            fixture = PublicConservationProviderFixture(unused_targets=mode, zero_executor=True)
            result = fixture.result()
            self.assertEqual(result["configuration"], json_values(fixture.configuration))
            probed = {params[0] for method, params in fixture.requested if method == "eth_getCode"}
            self.assertFalse({A(10005), A(10006), ZERO_ADDRESS} & probed)
            self.assertEqual(result["configuration"][0][9], ZERO_ADDRESS)
            self.assertEqual(result["configuration"][1][9], ZERO)

    def test_nonzero_optional_reference_is_retained_and_runtime_bound(self):
        fixture = PublicConservationProviderFixture(optional_reference=True)
        result = fixture.result()
        self.assertEqual(result["configuration"][0][9], A(10009))
        self.assertTrue(any(method == "eth_getCode" and params[0] == A(10009) for method, params in fixture.requested))

    def test_unpinned_historical_dependency_replacement_does_not_reauthorize_configuration(self):
        fixture = PublicConservationProviderFixture(optional_reference=True)
        fixture.a["codePins"] = [row for row in fixture.a["codePins"] if row["address"] in (fixture.core, fixture.floor_provider)]
        for address in fixture.admitted_addresses:
            if address != fixture.core: fixture.codes[address] = b""
        result = fixture.result()
        self.assertEqual(result["configuration"], json_values(fixture.configuration))
        self.assertEqual({params[0] for method, params in fixture.requested if method == "eth_getCode"},
            {fixture.core, fixture.floor_provider})
        self.assertFalse(result["claims"]["allDependencyRuntimesCurrentlyChecked"])
        self.assertFalse(result["claims"]["currentFloorEligibilityProven"])

    def test_uint256_original_gas_is_retained_without_claiming_usable_uint64_call_caps(self):
        fixture = PublicConservationProviderFixture()
        gas = tuple((name, (index + 1) * (1 << 80), 1 << 70, 2) for index, name in enumerate(NAMES))
        config = (*fixture.configuration[:3], *gas)
        fixture.set_configuration(config)
        fixture.a["configurationHash"] = keccak256(original_preimage(config))
        for index, (event, row) in enumerate(zip(fixture.registration_events, gas)):
            event["data"] = "0x" + encode(REGISTERED_DATA, (2, *row)).hex()
            fixture.set_gas(index, (row[1], row[2], row[3], 1))
        result = fixture.result()
        self.assertEqual(result["originalGas"][0]["genesisValue"], str(1 << 80))
        self.assertFalse(result["claims"]["currentFloorEligibilityProven"])

    def test_closed_offline_replay_and_explicit_synthetic_provenance(self):
        fixture = PublicConservationProviderFixture(raised=True)
        adapter = fixture.source(); snapshot = adapter.snapshot(); transcript = adapter.transcript()
        with patch("socket.socket", side_effect=AssertionError("no network in synthetic replay")):
            replay = source.PublicConservationProviderSource(adapter.anchor_bytes,
                PublicReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), snapshot)
            self.assertEqual(replay.transcript(), transcript)
        self.assertEqual(loads(snapshot, maximum=source.MAX_OUTPUT)["provenance"], "synthetic_fixture")
        with self.assertRaises(MuseumError): fixture.source(provenance="trusted_rpc")

    def test_explicit_caller_admitted_rpc_mechanics_remain_synthetic_test_not_acceptance(self):
        fixture = PublicConservationProviderFixture()
        anchor = deepcopy(fixture.a)
        anchor["runtimeAdmission"]["kind"] = "externally_admitted_runtime"
        raw_anchor = dumps(anchor)
        with patch("socket.socket", side_effect=AssertionError("no actual RPC in mechanics test")), \
                patch.object(PublicRpcTransport, "request", side_effect=fixture.request):
            adapter = source.PublicConservationProviderSource(raw_anchor, PublicRpcTransport("https://synthetic.invalid"),
                provenance="trusted_rpc")
            snapshot = adapter.snapshot(); transcript = adapter.transcript()
            replay = source.PublicConservationProviderSource(raw_anchor,
                PublicReplayTransport(transcript, keccak256(transcript)), provenance="trusted_rpc")
            self.assertEqual(replay.snapshot(), snapshot)
        result = loads(snapshot, maximum=source.MAX_OUTPUT)
        self.assertEqual(result["provenance"], "trusted_rpc")
        self.assertEqual(result["source"]["runtimeAdmission"], anchor["runtimeAdmission"])
        for claim in ("sourceArtifactAuthenticityProven", "historicalProviderExecutionProven", "personhoodProven",
                "actualChainAcceptance", "sourceConsensusVerified", "completeAcquisitionPacket"):
            self.assertFalse(result["claims"][claim], claim)
        with self.assertRaises(MuseumError):
            source.PublicConservationProviderSource(raw_anchor, PublicReplayTransport(transcript, keccak256(transcript)))

    def test_pinned_runtime_and_original_immutable_getter_contradictions_reject(self):
        for target in (A(86), A(2), A(1), A(10009)):
            with self.subTest(target=target):
                fixture = PublicConservationProviderFixture(optional_reference=True)
                fixture.codes[target] = b"different code at the exact same source block"
                with self.assertRaises(MuseumError): fixture.result()
        for getter, kind, value in (("core", "address", A(999)), ("metadata", "address", A(999)),
                ("coreCodeHash", "bytes32", H(999)), ("metadataCodeHash", "bytes32", H(999)),
                ("deploymentChainId", "uint256", 1), ("governanceAuthority", "address", A(999))):
            with self.subTest(getter=getter):
                fixture = PublicConservationProviderFixture()
                fixture.add(fixture.floor_provider, getter + "()", (), (), (kind,), (value,))
                with self.assertRaises(MuseumError): fixture.result()

    def test_original_configuration_external_hash_and_canonical_abi_reject(self):
        for mode in ("external-pin", "hash-getter", "tuple-preimage", "trailing-abi", "chain-domain"):
            fixture = PublicConservationProviderFixture()
            if mode == "external-pin": fixture.a["configurationHash"] = H(999)
            elif mode == "trailing-abi":
                key = (fixture.floor_provider, calldata("originalConfiguration()", (), ()))
                fixture.responses[key] += "00" * 32
            else:
                digest = H(999) if mode == "hash-getter" else keccak256(encode((CONFIG,), (fixture.configuration,))) \
                    if mode == "tuple-preimage" else keccak256(original_preimage(fixture.configuration, chain=1))
                fixture.set_configuration(fixture.configuration, digest=digest)
                fixture.a["configurationHash"] = digest
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.result()

    def test_coherently_hashed_invalid_original_configs_reject(self):
        for mode in ("optional-address-zero", "optional-hash-zero", "source-not-larger", "reference-not-larger",
                "gas-zero-floor", "gas-floor-above-genesis", "gas-class", "gas-name"):
            fixture = PublicConservationProviderFixture(optional_reference=mode == "optional-hash-zero")
            config = [list(fixture.configuration[0]), list(fixture.configuration[1]), fixture.configuration[2],
                *[list(row) for row in fixture.configuration[3:]]]
            if mode == "optional-address-zero": config[1][9] = H(999)
            elif mode == "optional-hash-zero": config[1][9] = ZERO
            elif mode == "source-not-larger": config[4][1] = config[3][1]
            elif mode == "reference-not-larger": config[5][1] = config[3][1]
            elif mode == "gas-zero-floor": config[3][2] = 0
            elif mode == "gas-floor-above-genesis": config[3][2] = config[3][1] + 1
            elif mode == "gas-class": config[3][3] = 1
            else: config[3][0] = "OTHER_READ_GAS"
            config = (tuple(config[0]), tuple(config[1]), config[2], *map(tuple, config[3:]))
            fixture.set_configuration(config)
            fixture.a["configurationHash"] = keccak256(original_preimage(config))
            for event, gas in zip(fixture.registration_events, config[3:]):
                event["data"] = "0x" + encode(REGISTERED_DATA, (2, *gas)).hex()
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.result()

    def test_current_gas_does_not_contradict_original_registration(self):
        for values, direct_value in (((399999, 100000, 2, 2), None), ((400000, 100001, 2, 1), None),
                ((400000, 100000, 1, 1), None), ((400000, 100000, 2, 0), None),
                ((800000, 100000, 2, 1), None), ((400000, 100000, 2, 1), 400001)):
            fixture = PublicConservationProviderFixture()
            fixture.set_gas(0, values, direct_value=direct_value)
            with self.subTest(values=values, direct_value=direct_value), self.assertRaises(MuseumError): fixture.result()

    def test_revision_counts_require_distinct_integer_raises_and_respect_disabled_executor(self):
        for values in ((400001, 100000, 2, 3), (400000, 100000, 2, 2), (800001, 100000, 2, 2)):
            fixture = PublicConservationProviderFixture()
            fixture.set_gas(0, values)
            with self.subTest(values=values), self.assertRaisesRegex(MuseumError, "current gas differs"):
                fixture.result()
        valid = PublicConservationProviderFixture()
        valid.set_gas(0, (400002, 100000, 2, 3))
        self.assertEqual(valid.result()["currentGas"][0]["revision"], "3")
        with self.assertRaisesRegex(MuseumError, "current gas differs"):
            PublicConservationProviderFixture(raised=True, zero_executor=True).result()

    def test_registration_denominator_order_and_original_event_facts_reject(self):
        for mode in ("missing", "duplicate", "unknown-fourth", "reordered-ids", "unknown-id", "event-value", "event-name", "event-schema"):
            fixture = PublicConservationProviderFixture()
            if mode == "missing":
                logs = fixture.receipts[H(400)]["logs"]
                logs.remove(fixture.registration_events[-1])
            elif mode == "duplicate":
                fixture.event(0, fixture.floor_provider, [REGISTERED, IDS[0]], REGISTERED_DATA, (2, *fixture.original_gas[0]))
            elif mode == "unknown-fourth":
                fixture.event(0, fixture.floor_provider, [REGISTERED, H(999)], REGISTERED_DATA,
                    (2, "UNEXPECTED_PARAMETER", 100000, 10000, 2))
            elif mode in ("reordered-ids", "unknown-id"):
                ids = IDS[::-1] if mode == "reordered-ids" else (*IDS[:2], H(999))
                fixture.add(fixture.floor_provider, "gasParameterIds()", (), (), (Array("bytes32", 3),), (ids,))
            else:
                gas = list(fixture.original_gas[0]); version = 2
                if mode == "event-value": gas[1] += 1
                elif mode == "event-name": gas[0] += "_OTHER"
                else: version = 1
                fixture.registration_events[0]["data"] = "0x" + encode(REGISTERED_DATA, (version, *gas)).hex()
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.result()

    def test_registration_constructor_adjacency_and_fixed_filters(self):
        fixture = PublicConservationProviderFixture(); result = fixture.result()
        queries = [params[0] for method, params in fixture.requested if method == "eth_getLogs"]
        self.assertEqual(queries, [{"address": fixture.floor_provider, "topics": [REGISTERED],
            "fromBlock": "0x0", "toBlock": "0x5"}])
        self.assertTrue(result["historyCoverage"]["providerLogCompletenessTrusted"])
        self.assertFalse(result["historyCoverage"]["allBlockReceipts"])
        changed = PublicConservationProviderFixture()
        logs = changed.receipts[H(400)]["logs"]
        unrelated = deepcopy(logs[-1]); unrelated.update(address=A(999), topics=[H(999)], data="0x")
        logs.insert(logs.index(changed.registration_events[1]), unrelated)
        for index, log in enumerate(logs): log["logIndex"] = hex(index)
        with self.assertRaisesRegex(MuseumError, "constructor registration order"): changed.result()

    def test_original_getter_required_and_no_old_configuration_fallback(self):
        fixture = PublicConservationProviderFixture()
        del fixture.responses[(fixture.floor_provider, calldata("originalConfiguration()", (), ()))]
        with self.assertRaises(MuseumError): fixture.result()

    def test_closed_anchor_and_runtime_admission_fail_before_rpc(self):
        for mode in ("extra", "wrong-profile", "wrong-source", "wrong-admission", "zero-artifact", "zero-config"):
            fixture = PublicConservationProviderFixture()
            if mode == "extra": fixture.a["fromBlock"] = "1"
            elif mode == "wrong-profile": fixture.a["profile"] = "STREAM_MUSEUM_PUBLIC_CONSERVATION_FLOOR_SOURCE_V1"
            elif mode == "wrong-source": fixture.a["runtimeAdmission"]["sourceCommit"] = "0" * 40
            elif mode == "wrong-admission": fixture.a["runtimeAdmission"]["kind"] = "externally_admitted_runtime"
            elif mode == "zero-artifact": fixture.a["runtimeAdmission"]["artifactHash"] = ZERO
            else: fixture.a["configurationHash"] = ZERO
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source()
            self.assertEqual(fixture.requested, [])

    def test_header_changed_after_reads_and_failed_capture_cannot_resume(self):
        fixture = PublicConservationProviderFixture(); adapter = fixture.source()
        original = fixture.request; reads = 0
        def changed(method, params):
            nonlocal reads
            answer = original(method, params)
            if method == "eth_getBlockByHash" and params[0] == fixture.a["blockHash"]:
                reads += 1
                if reads > 1: answer["stateRoot"] = H(999)
            return answer
        with patch.object(fixture, "request", side_effect=changed):
            with self.assertRaises(MuseumError): adapter.snapshot()
        with self.assertRaisesRegex(MuseumError, "cannot resume"): adapter.snapshot()

    def test_rehashed_transcript_gas_tamper_still_rejects_native_correspondence(self):
        fixture = PublicConservationProviderFixture(); adapter = fixture.source(); adapter.snapshot()
        transcript = loads(adapter.transcript(), maximum=32 * 1024 * 1024)
        wanted = calldata("gasParameter(bytes32)", ("bytes32",), (IDS[0],))
        rows = transcript["calls"] if "calls" in transcript else transcript["rows"]
        hits = 0
        for row in rows:
            if row["method"] == "eth_call" and row["params"][0]["data"] == wanted:
                row["result"] = "0x" + encode(("uint256",), (400001,)).hex(); hits += 1
        self.assertGreater(hits, 0)
        raw = dumps(transcript)
        with self.assertRaises(MuseumError):
            source.PublicConservationProviderSource(adapter.anchor_bytes, PublicReplayTransport(raw, keccak256(raw))).snapshot()


if __name__ == "__main__": unittest.main()

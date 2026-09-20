"""Exact original native provider configuration; execution remains separate evidence."""
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .owner_catalog_source import _location, _position
from .public_chain_history import scan_public_history, PROFILE_HASH as HISTORY_PROFILE_HASH
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport

PROFILE = "STREAM_MUSEUM_PUBLIC_CONSERVATION_PROVIDER_SOURCE_V1"
SOURCE_REVISION = "36c871f44636837bdc5504e6aaeafe54e14dcb98"
GAS = ("string", "uint256", "uint256", "uint8")
CONFIG = (("address",) * 10, ("bytes32",) * 10, "address", GAS, GAS, GAS)
GAS_INFO = ("uint256", "uint256", "uint8", "uint64")
CONFIG_DOMAIN = schema_id("6529STREAM_NATIVE_CONSERVATION_PROVIDER_V1")
PARAMETER_NAMES = tuple("CONSERVATION_PROVIDER_" + kind + "_GAS" for kind in ("READ", "SOURCE", "REFERENCE"))
PARAMETER_IDS = tuple(schema_id("6529STREAM_GGP_" + name) for name in PARAMETER_NAMES)
TARGET_NAMES = ("core", "metadata", "schemas", "store", "rightsSelector", "conservationSelector",
    "masterSelector", "router", "artistFacade", "prospectiveReference")
REGISTERED_EVENT = schema_id("GasParameterRegistered(uint16,bytes32,string,uint256,uint256,uint8)")
REGISTERED_DATA = ("uint16", *GAS)
MAX_ANCHOR, MAX_ABI, MAX_OUTPUT = 65536, 4096, 4 * 1024 * 1024
COMMON = ("chainId", "core", "collectionId", "blockHash", "blockNumber", "timestamp",
    "stateRoot", "environment", "deploymentEvidenceHash")


def _interface(signatures):
    value = 0
    for signature in signatures:
        value ^= int(schema_id(signature)[:10], 16)
    return "0x" + f"{value:08x}"


_SALE = "(uint256,uint256,address,bytes32,bytes32,bytes32,bytes32)"
_RELEASE = "(bytes32,bytes32,bytes32,bytes32,bytes32,bool)"
PROVIDER_INTERFACE = _interface(("core()", "coreCodeHash()", "metadata()", "metadataCodeHash()",
    "configurationHash()", "deploymentChainId()", "requireCollectionFloor(uint256,bytes32)",
    "saleRelease(" + _SALE + ")", "requireReleaseFloor(" + _SALE + "," + _RELEASE + ",bytes32)"))
CLAIMS = {"originalConfigurationPreimageChecked": True, "originalGasRegistrationEventsChecked": True,
    "reciprocalProviderGettersChecked": True, "originalAndCurrentGasSeparated": True,
    "providerRuntimeIdentityBound": True, "providerLogCompletenessTrusted": True,
    "canonicalMappingTrusted": True, "allDependencyRuntimesCurrentlyChecked": False,
    "sourceArtifactAuthenticityProven": False, "historicalProviderEligibilityReexecuted": False,
    "historicalProviderExecutionProven": False, "currentFloorEligibilityProven": False,
    "personhoodProven": False, "actualChainAcceptance": False,
    "sourceConsensusVerified": False, "completeAcquisitionPacket": False}
QUALIFICATION = (
    "Exact originalConfiguration preimage for an explicitly admitted provider runtime at the declared block. "
    "All ten target/code pins, executor and three original gas configurations are retained and recompute "
    "the external saved configurationHash. Current governed gas is separately observed. Constructor-skipped "
    "targets 5/6 remain unvalidated, and optional target 9 does not prove reference availability. Dependency "
    "replacement does not rewrite original pins. Source/runtime artifact linkage and provenance remain "
    "externally admitted. No historical or current provider execution, personhood, paid Artist acceptance, "
    "consensus or complete acquisition packet is established. The old 8bb provider without this getter "
    "cannot be captured under this profile.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
    "historyProfileHash": HISTORY_PROFILE_HASH, "bounds": {"anchorBytes": str(MAX_ANCHOR),
        "abiBytes": str(MAX_ABI), "snapshotBytes": str(MAX_OUTPUT), "codePins": "64", "gasRegistrations": "3"},
    "admission": "External anchor pins the original saved configurationHash, provider runtime code pin and source-specific runtimeAdmission artifact commitment. Synthetic and externally admitted runtime identities cannot be relabeled by replay.",
    "configuration": "Canonical dynamic Configuration tuple, exact full ABI preimage with domain and deploymentChainId; original gas values never replaced by current governed values.",
    "registrationDenominator": "All GasParameterRegistered events at the provider from block zero through the anchor; exactly the three constructor names/IDs are accepted. Unknown extra registrations fail rather than being filtered away.",
    "targets": "Constructor validates original code at 0/1/2/3/4/7/8, skips 5/6, and permits absent 9 only with zero hash. This reader checks provider/Core runtime pins and any explicit extra caller pins, without requiring all historical dependencies to remain current.",
    "gas": "Exact original names/order/registration events and immutable floor/failure classes. Current value/revision are observations consistent with monotonic at-most-double raises, not a governance-action history proof. Constructor values above uint64 remain representable, without claiming usable call caps.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def configuration_hash(chain_id, configuration):
    return keccak256(encode(("bytes32", "uint256", CONFIG), (CONFIG_DOMAIN, uint(chain_id), configuration)))


class PublicConservationProviderSource:
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (PublicRpcTransport, PublicReplayTransport)),
            "conservation provider provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == set(COMMON) | {"profile", "provider", "configurationHash", "runtimeAdmission", "codePins"}
            and a["profile"] == PROFILE, "conservation provider anchor shape/profile")
        require(a["environment"] in ("public_chain", "local_evm_fixture"), "conservation provider environment")
        require(uint(a["chainId"]) > 0 and uint(a["collectionId"]) > 0, "conservation provider nonzero identity")
        uint(a["blockNumber"]); uint(a["timestamp"], 64)
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash", "configurationHash"):
            require(any(hex_bytes(a[key], 32)), "conservation provider empty commitment")
        for key in ("core", "provider"):
            require(any(hex_bytes(a[key], 20)), "conservation provider empty address")
        require(a["core"] != a["provider"], "conservation provider distinct Core")
        admission = a["runtimeAdmission"]
        require(type(admission) is dict and set(admission) == {"sourceCommit", "kind", "artifactHash"}
            and admission["sourceCommit"] == SOURCE_REVISION
            and admission["kind"] == ("synthetic_fixture" if provenance == "synthetic_fixture" else "externally_admitted_runtime")
            and any(hex_bytes(admission["artifactHash"], 32)), "conservation provider explicit runtime admission differs")
        require(type(a["codePins"]) is list and 2 <= len(a["codePins"]) <= 64, "conservation provider pin bound")
        pins = {}
        for row in a["codePins"]:
            require(type(row) is dict and set(row) == {"address", "runtimeHash"}
                and any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32))
                and row["address"] not in pins, "conservation provider invalid/duplicate pin")
            pins[row["address"]] = row["runtimeHash"]
        require(all(a[key] in pins for key in ("core", "provider")), "conservation provider required pin missing")
        self.a, self.pins, self.anchor_bytes, self.provenance = a, pins, anchor_bytes, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])
        self._started, self._snapshot = False, None

    def _read(self, signature, outputs, inputs=(), values=()):
        raw = hex_bytes(self.reader.call(self.a["provider"], calldata(signature, inputs, values)))
        return raw, decode(outputs, raw, maximum=MAX_ABI)

    def _one(self, signature, output, inputs=(), values=()):
        return self._read(signature, (output,), inputs, values)[1][0]

    def _configuration(self):
        a = self.a
        for address, digest in sorted(self.pins.items()):
            code = hex_bytes(self.reader.code(address))
            require(0 < len(code) <= 24576 and keccak256(code) == digest, "conservation provider runtime differs")
        for interface, expected in ((PROVIDER_INTERFACE, True), ("0x01ffc9a7", True), ("0xffffffff", False)):
            require(self._one("supportsInterface(bytes4)", "bool", ("bytes4",), (interface,)) == expected,
                "conservation provider native interface differs")
        raw, (configuration,) = self._read("originalConfiguration()", (CONFIG,))
        targets, hashes, executor, *gas = configuration
        for index in (0, 1, 2, 3, 4, 7, 8):
            require(targets[index] != ZERO_ADDRESS and hashes[index] != ZERO, "conservation provider original required pin")
        require((targets[9] == ZERO_ADDRESS) == (hashes[9] == ZERO), "conservation provider optional reference pin")
        require(targets[0] == a["core"] and hashes[0] == self.pins[a["core"]], "conservation provider original Core pin differs")
        for signature, kind, expected in (("core()", "address", targets[0]), ("coreCodeHash()", "bytes32", hashes[0]),
                ("metadata()", "address", targets[1]), ("metadataCodeHash()", "bytes32", hashes[1]),
                ("deploymentChainId()", "uint256", uint(a["chainId"])), ("governanceAuthority()", "address", executor),
                ("configurationHash()", "bytes32", a["configurationHash"])):
            require(self._one(signature, kind) == expected, "conservation provider reciprocal getter differs")
        require(configuration_hash(a["chainId"], configuration) == a["configurationHash"],
            "conservation provider original configuration hash differs")
        for index, row in enumerate(gas):
            require(row[0] == PARAMETER_NAMES[index] and row[2] > 0 and row[1] >= row[2] and row[3] == 2,
                "conservation provider original gas configuration differs")
        require(gas[1][1] > gas[0][1] and gas[2][1] > gas[0][1], "conservation provider original gas ordering differs")
        require(self._one("gasParameterIds()", Array("bytes32", 3)) == PARAMETER_IDS,
            "conservation provider gas parameter inventory differs")
        original, current = [], []
        for parameter, row in zip(PARAMETER_IDS, gas, strict=True):
            _, (value, floor, failure, revision) = self._read("gasParameterInfo(bytes32)", GAS_INFO, ("bytes32",), (parameter,))
            require((floor, failure) == row[2:] and revision > 0 and value >= row[1]
                and (value == row[1] if revision == 1 else value > row[1])
                and value - row[1] >= revision - 1
                and value <= row[1] * (1 << min(revision - 1, 256))
                and (executor != ZERO_ADDRESS or revision == 1), "conservation provider current gas differs")
            require(self._one("gasParameter(bytes32)", "uint256", ("bytes32",), (parameter,)) == value,
                "conservation provider current gas getter differs")
            original.append({"parameterId": parameter, "name": row[0], "genesisValue": str(row[1]), "floor": str(row[2]), "failureClass": str(row[3])})
            current.append({"parameterId": parameter, "value": str(value), "floor": str(floor), "failureClass": str(failure), "revision": str(revision)})
        return raw, configuration, original, current

    def _capture(self):
        a = self.a
        history = scan_public_history(self.reader, a,
            filters=[{"address": a["provider"], "topics": [REGISTERED_EVENT]}])
        raw, configuration, original, current = self._configuration()
        events = history["logs"]
        require(len(events) == 3, "conservation provider exact original gas registrations required")
        previous = None
        for index, event in enumerate(events):
            require(event["address"] == a["provider"] and event["topics"] == [REGISTERED_EVENT, PARAMETER_IDS[index]]
                and decode(REGISTERED_DATA, hex_bytes(event["data"]), maximum=MAX_ABI) == (2, *configuration[3 + index]),
                "conservation provider original gas registration differs")
            position = _position(event)
            require(previous is None or position == (*previous[:2], previous[2] + 1),
                "conservation provider constructor registration order differs")
            previous = position
        require(self._read("originalConfiguration()", (CONFIG,))[0] == raw,
            "conservation provider final original configuration differs")
        self.reader.request("eth_getBlockByHash", [a["blockHash"], False])
        self.reader.request("eth_getBlockByNumber", [hex(uint(a["blockNumber"])), False])
        if type(self.reader.transport) is PublicReplayTransport:
            self.reader.transport.finish()
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "source": a,
            "sourceReviewCommit": SOURCE_REVISION, "sourceState": {key: a[key] for key in COMMON},
            "provenance": self.provenance, "runtimeAdmissionStatus": a["runtimeAdmission"]["kind"],
            "anchorHash": keccak256(self.anchor_bytes),
            "transcriptHash": keccak256(self.reader.transcript()), "configuration": json_values(configuration),
            "configurationRawHex": "0x" + raw.hex(), "configurationHash": a["configurationHash"],
            "dependencies": [{"index": str(i), "name": name, "address": configuration[0][i], "runtimeHash": configuration[1][i],
                "constructorCodeCheck": "skipped" if i in (5, 6) else "optional_absent" if i == 9 and configuration[0][i] == ZERO_ADDRESS else "required"}
                for i, name in enumerate(TARGET_NAMES)], "originalGas": original, "currentGas": current,
            "registrationEvents": [{"log": event, "publication": _location(event)} for event in events],
            "historyCoverage": history["coverage"], "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_OUTPUT, "conservation provider snapshot bound")
        return result

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed conservation provider capture cannot resume")
        self._started = True
        try:
            self._snapshot = self._capture()
        except MuseumError:
            raise
        except (KeyError, TypeError, IndexError, ValueError, OverflowError) as exc:
            raise MuseumError("malformed conservation provider evidence") from exc
        return self._snapshot

    def transcript(self):
        require(self._snapshot is not None, "conservation provider snapshot required before transcript")
        return self.reader.transcript()

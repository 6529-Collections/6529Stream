"""Offline observation join after independent RIGHTS and floor capture verification."""
from . import conservation_capture_join as shared
from .canonical import MuseumError, dumps, keccak256, loads, uint
from .independent_wire import require

PROFILE = "STREAM_MUSEUM_CONSERVATION_RIGHTS_JOIN_V1"
NAMES = ("rights", "floor")
RIGHTS_PROFILE = "STREAM_MUSEUM_PUBLIC_RIGHTS_SOURCE_V1"
FLOOR_FAMILIES = {"STREAM_MUSEUM_PUBLIC_CONSERVATION_FLOOR_SOURCE_V1": "universal_primary_v1",
    "STREAM_MUSEUM_PUBLIC_DIRECT_CONSERVATION_SOURCE_V1": "direct_primary_v1"}
COMMON = shared.COMMON
MAX_INPUT_BYTES, MAX_ANCHOR_BYTES, MAX_ROWS = shared.MAX_INPUT_BYTES, 65536, shared.MAX_ROWS
HOSTS = {"rights": ("core", "host", "router", "originalFinality", "provider", "rightsSelector", "schemas", "store"),
    "floor": ("core", "conservationFloor", "executor")}
CLAIMS = dict(shared.CLAIMS, originalAnchorProfilesPreserved=True, nativeFloorFamilyPreserved=True)
QUALIFICATION = ("Reconciles original observations from independently verified RIGHTS and floor captures. "
    "The accepted floor profile determines universal or DIRECT family without translating native receipts. "
    "Shared anchors and runtime pins, exact RPC outcomes, reciprocal touched headers, full successful receipts "
    "and matching log pages must agree under the unchanged observation checker. Source provenance, native "
    "RIGHTS semantics and documentary applicability remain the caller's separate checks. Provider log "
    "completeness and canonical mappings remain trusted; no unobserved history, consensus, ancestry or "
    "actual-chain acceptance is proved.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "inputs": list(NAMES),
    "sourceProfiles": {"rights": RIGHTS_PROFILE, "floor": FLOOR_FAMILIES},
    "observationSemanticsProfileHash": shared.PROFILE_HASH,
    "historyProfileHash": shared.history.PROFILE_HASH, "rpcProfileHash": shared.rpc.PROFILE_HASH,
    "commonAnchorFields": list(COMMON),
    "bounds": {"inputBytes": str(MAX_INPUT_BYTES), "anchorBytes": str(MAX_ANCHOR_BYTES),
        "rowOccurrences": str(MAX_ROWS), "rightsCodePins": "64", "floorCodePins": "256"},
    "observations": "Uses the unchanged observation checker bounds, exact RPC/limit equality, reciprocal header and receipt/log union checks, and per-input complete binary log splits. No caller-selected lower range or fabricated source input is added.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _inputs(inputs):
    require(type(inputs) is dict and set(inputs) == set(NAMES), "RIGHTS conservation join exact inputs required")
    total = 0
    for value in inputs.values():
        require(type(value) is dict and set(value) == {"anchor", "transcript"}, "RIGHTS conservation join input shape")
        for raw in value.values():
            require(type(raw) is bytes and raw, "RIGHTS conservation join original bytes required")
            total += len(raw)
    require(total <= MAX_INPUT_BYTES, "RIGHTS conservation join aggregate input byte bound")
    common, family, calls, hashes, pins, row_count = None, None, {}, {}, {}, 0
    for name in NAMES:
        value = inputs[name]; a = loads(value["anchor"], maximum=MAX_ANCHOR_BYTES, canonical=True)
        required = set(COMMON) | set(HOSTS[name]) | {"profile", "codePins"}
        if name == "rights": required.add("tokenId")
        require(type(a) is dict and set(a) == required and
            (a["profile"] == RIGHTS_PROFILE if name == "rights" else a["profile"] in FLOOR_FAMILIES),
            "RIGHTS conservation join source anchor shape/profile")
        current = {key: a[key] for key in COMMON}
        require(common is None or common == current, "RIGHTS conservation join common anchor differs")
        common = current
        require(uint(a["chainId"]) > 0 and uint(a["collectionId"]) > 0, "RIGHTS conservation join nonzero identity")
        if name == "rights": require(uint(a["tokenId"]) > 0, "RIGHTS conservation join token identity")
        else: family = FLOOR_FAMILIES[a["profile"]]
        uint(a["blockNumber"]); uint(a["timestamp"], 64)
        require(a["environment"] in ("public_chain", "local_evm_fixture"), "RIGHTS conservation join environment")
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"): shared._nonzero(a[key], 32)
        require(len({a[key] for key in HOSTS[name]}) == len(HOSTS[name]), "RIGHTS conservation join distinct hosts")
        for key in HOSTS[name]: shared._nonzero(a[key], 20)
        rows = a["codePins"]
        require(type(rows) is list and len(HOSTS[name]) <= len(rows) <= (64 if name == "rights" else 256),
            "RIGHTS conservation join pin bound")
        own = {}
        for row in rows:
            require(type(row) is dict and set(row) == {"address", "runtimeHash"} and row["address"] not in own,
                "RIGHTS conservation join duplicate/malformed pin")
            address, digest = row["address"], row["runtimeHash"]
            shared._nonzero(address, 20); shared._nonzero(digest, 32)
            require(address not in pins or pins[address] == digest, "RIGHTS conservation join runtime pin differs")
            own[address] = pins[address] = digest
        require(all(a[key] in own for key in HOSTS[name]), "RIGHTS conservation join missing native pin")
        transcript = loads(value["transcript"], maximum=shared.rpc.MAX_TRANSCRIPT, canonical=True)
        require(type(transcript) is dict and set(transcript) == {"version", "profile", "calls"}
            and type(transcript["version"]) is int and transcript["version"] == shared.rpc.VERSION
            and transcript["profile"] == shared.rpc.PROFILE and type(transcript["calls"]) is list,
            "RIGHTS conservation join transcript profile/shape")
        row_count += len(transcript["calls"])
        require(row_count <= MAX_ROWS, "RIGHTS conservation join aggregate row bound")
        calls[name] = transcript["calls"]
        hashes[name] = {"anchorHash": keccak256(value["anchor"]), "transcriptHash": keccak256(value["transcript"])}
    return common, family, calls, hashes, pins, total, row_count


def reconcile(inputs):
    """Return qualified deterministic coverage; captures must already be verified."""
    try:
        a, family, calls, hashes, pins, total, row_count = _inputs(inputs)
        counts = shared._observations(a, calls, pins)
        return {"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "sourceState": a,
            "floorFamily": family, "coreRuntimeHash": pins[a["core"]], "inputs": hashes,
            "counts": {"inputBytes": str(total), "rowOccurrences": str(row_count), **counts},
            "claims": dict(CLAIMS), "qualification": QUALIFICATION}
    except (KeyError, TypeError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("malformed RIGHTS conservation join evidence") from exc

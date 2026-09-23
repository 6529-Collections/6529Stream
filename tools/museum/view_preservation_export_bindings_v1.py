"""Deterministic correspondence for the local VIEW ceremony binding receipts.

The export contains historical provider getter returns, while the retained
inventory contains independently validated source tuples.  This helper joins
the fields that have an exact counterpart and verifies the receipt hash
chains.  It deliberately does not turn the opaque capability, complete worker
set, or governance action metadata into authority evidence.
"""

from . import view_preservation_inventory_sources_v1 as inventory_sources
from . import view_preservation_inventory_types_v1 as inventory_types
from . import view_preservation_reference_types_v1 as reference_types
from . import view_preservation_snapshot_types_v1 as snapshot_types
from . import view_policy_adoption_types_v2 as adoption_types
from .canonical import MuseumError, hex_bytes, keccak256, schema_id, uint
from .chain_abi import decode, encode
from .independent_wire import json_values, require
from .native_finality_wire import from_json


BASIC_CONFIGURATION = (
    "address", "bytes32", "uint256", "address", "bytes32", "address", "bytes32",
)
VIEW_BINDING = ("address", "bytes32", "address", "bytes32", "uint32", "uint32")
SNAPSHOT_DEPENDENCIES = snapshot_types.DEPENDENCIES
BASIC_RECEIPT = (
    "bytes32", BASIC_CONFIGURATION, VIEW_BINDING, SNAPSHOT_DEPENDENCIES,
    "bytes32", "bytes32", "bytes32", "uint64", "bytes32",
)
COMPLETE_SELECTION = (
    "address", "bytes32", "address", "bytes32", "address", "bytes32",
)
COMPLETE_RECEIPT = (
    COMPLETE_SELECTION, "bytes32", "bytes32", "bytes32", "bytes32",
    "bytes32", "uint64", "bytes32",
)

BASIC_PROPOSAL_DOMAIN = schema_id("6529STREAM_FINALITY_VIEW_PRESERVATION_PROPOSAL_V1")
BASIC_RECEIPT_DOMAIN = schema_id("6529STREAM_FINALITY_VIEW_PRESERVATION_RECEIPT_V1")
COMPLETE_RECEIPT_DOMAIN = schema_id(
    "6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1"
)

# Both native names are the same admitted executor in this source recipe.
GRAPH_ROLES = {
    "CORE": "core",
    "METADATA": "metadata",
    "ROUTER": "router",
    "FINALITY": "finality",
    "PROVIDER": "provider",
    "ARTIST_REGISTRY": "artist",
    "SCHEMAS": "schemas",
    "STORE": "store",
    "DECLARATIONS": "views",
    "VIEW_REGISTRY": "rendererRegistry",
    "VIEW_RENDERER": "renderer",
    "VIEW_SOURCE_SET": "entropySourceSet",
    "PRESERVATION_RENDERER": "preservationRenderer",
    "CHECKPOINT": "checkpoint",
    "OUTPUT_MANIFEST": "outputManifest",
    "SNAPSHOT": "viewSnapshot",
    "REFERENCE": "viewReference",
    "INVENTORY": "inventory",
    "BUNDLE": "bundleCoverage",
    "ARTIFACT_COVERAGE": "coverage",
    "EXTERNAL_COVERAGE": "externalCoverage",
    "SCOPE_MEMBERSHIP": "scopeMembership",
    "GOVERNANCE_EXECUTOR": "authority",
    "ARCHIVE": "artistArchive",
    "SNAPSHOT_AUTHORITY": "authority",
}


def _abi(publication, name, kind, length=None):
    raw = hex_bytes(publication[name])
    if length is not None:
        require(len(raw) == length, "VIEW export binding ABI width differs: " + name)
    value = decode((kind,), raw, maximum=len(raw))[0]
    require(raw == encode((kind,), (value,)), "VIEW export binding ABI is noncanonical: " + name)
    return value, raw


def _hash(kind, value):
    return keccak256(encode((kind,), (value,)))


def _pair(exported, graph, role, name):
    row, retained = exported[role], graph[name]
    require(
        (row["target"], row["runtimeHash"])
        == (retained["address"], retained["runtimeHash"]),
        "VIEW export binding graph differs: " + role,
    )


def _basic_proposal(receipt):
    return keccak256(
        encode(
            (
                "bytes32", "bytes32", BASIC_CONFIGURATION, VIEW_BINDING,
                SNAPSHOT_DEPENDENCIES, "bytes32", "bytes32",
            ),
            (
                BASIC_PROPOSAL_DOMAIN, receipt[0], receipt[1], receipt[2],
                receipt[3], receipt[4], receipt[5],
            ),
        )
    )


def _basic_record(receipt, proposal):
    return keccak256(
        encode(
            ("bytes32", "bytes32", "bytes32", "uint64"),
            (BASIC_RECEIPT_DOMAIN, proposal, receipt[6], receipt[7]),
        )
    )


def _complete_record(chain_id, provider, receipt):
    return keccak256(
        encode(
            (
                "bytes32", "uint256", "address", COMPLETE_SELECTION,
                "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64",
            ),
            (
                COMPLETE_RECEIPT_DOMAIN, chain_id, provider, receipt[0], receipt[1],
                receipt[2], receipt[3], receipt[4], receipt[5], receipt[6],
            ),
        )
    )


def _validate(source, envelope):
    require(type(source) is dict and type(envelope) is dict, "VIEW export binding inputs")
    publication = source["publication"]
    graph = envelope["graph"]
    exported_rows = source["graph"]
    require(type(exported_rows) is list, "VIEW export binding graph")
    exported = {row["role"]: row for row in exported_rows}
    require(len(exported) == len(exported_rows), "VIEW export duplicate graph role")
    for role, name in GRAPH_ROLES.items():
        _pair(exported, graph, role, name)

    basic, _ = _abi(publication, "basicBindingABI", BASIC_RECEIPT, 1376)
    complete, _ = _abi(publication, "completeBindingABI", COMPLETE_RECEIPT, 416)
    reference_dependencies, reference_raw = _abi(
        publication, "referenceDependenciesABI", reference_types.DEPENDENCIES, 608
    )
    inventory_dependencies, inventory_raw = _abi(
        publication, "inventoryDependenciesABI", inventory_types.DEPENDENCIES, 1344
    )
    bundle_dependencies, bundle_raw = _abi(
        publication, "bundleDependenciesABI", inventory_types.BUNDLE_DEPENDENCIES, 480
    )

    value = envelope["inventory"]
    row, bundle, adopted, _ = inventory_sources.selected(value["reference"])
    retained_snapshot_dependencies = from_json(
        SNAPSHOT_DEPENDENCIES, bundle["snapshot"]["dependencies"]
    )
    retained_reference_dependencies = from_json(
        reference_types.DEPENDENCIES, value["reference"]["dependencies"]
    )
    retained_inventory_dependencies = from_json(
        inventory_types.DEPENDENCIES, value["dependencies"]
    )
    original_snapshot_dependencies = basic[3]
    require(
        original_snapshot_dependencies[:3] == retained_snapshot_dependencies[:3]
        and all(
            current >= original
            for original, current in zip(
                original_snapshot_dependencies[3:], retained_snapshot_dependencies[3:]
            )
        ),
        "VIEW export basic snapshot dependency history differs",
    )
    require(
        reference_dependencies == retained_reference_dependencies,
        "VIEW export reference dependencies differ",
    )
    require(
        inventory_dependencies == retained_inventory_dependencies,
        "VIEW export inventory dependencies differ",
    )
    if envelope["bundle"] is not None:
        retained_bundle_dependencies = from_json(
            inventory_types.BUNDLE_DEPENDENCIES, envelope["bundle"]["dependencies"]
        )
        require(
            bundle_dependencies == retained_bundle_dependencies,
            "VIEW export bundle dependencies differ",
        )

    config, declaration = basic[1:3]
    require(
        config[0:2]
        == (graph["viewSnapshot"]["address"], graph["viewSnapshot"]["runtimeHash"])
        and config[3:5]
        == (graph["checkpoint"]["address"], graph["checkpoint"]["runtimeHash"])
        and config[5:7]
        == (graph["outputManifest"]["address"], graph["outputManifest"]["runtimeHash"]),
        "VIEW export basic configuration differs",
    )
    require(
        declaration[0:4]
        == (
            graph["views"]["address"], graph["views"]["runtimeHash"],
            graph["scopeMembership"]["address"], graph["scopeMembership"]["runtimeHash"],
        ),
        "VIEW export declaration binding differs",
    )
    retained_declaration = from_json(
        VIEW_BINDING, from_json(adoption_types.RECORD, adopted["record"])[1][0][16]
    )
    require(
        declaration == retained_declaration,
        "VIEW export complete declaration binding differs",
    )
    expected_dependency_roles = snapshot_types.DEPENDENCY_ROLES
    require(
        original_snapshot_dependencies[0]
        == tuple(graph[name]["address"] for name in expected_dependency_roles)
        and original_snapshot_dependencies[1]
        == tuple(graph[name]["runtimeHash"] for name in expected_dependency_roles),
        "VIEW export snapshot dependency graph differs",
    )
    original_largest_gas = max(original_snapshot_dependencies[3:])
    current_largest_gas = max(retained_snapshot_dependencies[3:])
    require(
        original_snapshot_dependencies[2] == uint(envelope["context"]["chainId"])
        and config[2] <= 16777216
        and all(value <= config[2] for value in original_snapshot_dependencies[3:])
        and all(value <= config[2] for value in retained_snapshot_dependencies[3:])
        and config[2]
        > original_largest_gas + original_largest_gas // 63 + 10000
        and config[2]
        > current_largest_gas + current_largest_gas // 63 + 10000,
        "VIEW export basic dependency chain/gas differs",
    )
    dependency_hash = _hash(SNAPSHOT_DEPENDENCIES, original_snapshot_dependencies)
    require(dependency_hash == basic[4], "VIEW export basic dependencies hash differs")

    proposal_hash = _basic_proposal(basic)
    basic_record = _basic_record(basic, proposal_hash)
    require(
        publication["basicBindingRecord"] == basic[8] == basic_record,
        "VIEW export basic binding record differs",
    )
    require(
        any(hex_bytes(basic[0], 32)) and any(hex_bytes(basic[5], 32))
        and any(hex_bytes(basic[6], 32))
        and uint(source["fixture"]["initialTimestamp"]) <= basic[7]
        and basic[7] <= uint(envelope["context"]["timestamp"]),
        "VIEW export basic binding retained fields",
    )

    selection = complete[0]
    require(
        selection
        == (
            graph["viewReference"]["address"], graph["viewReference"]["runtimeHash"],
            graph["inventory"]["address"], graph["inventory"]["runtimeHash"],
            graph["bundleCoverage"]["address"], graph["bundleCoverage"]["runtimeHash"],
        ),
        "VIEW export complete source selection differs",
    )
    reference_hash = keccak256(reference_raw)
    inventory_hash = keccak256(inventory_raw)
    bundle_hash = keccak256(bundle_raw)
    # Generic provider currentness permits governed reference-gas raises, but
    # this exact source-export recipe calls _viewRequireCompleteBinding before
    # and after export and requires all three current dependency hashes to be
    # the originally admitted hashes.
    require(
        complete[1:5] == (reference_hash, inventory_hash, bundle_hash, basic_record)
        and complete[5:7] == basic[6:8],
        "VIEW export complete binding links differ",
    )
    chain_id = uint(envelope["context"]["chainId"])
    provider = graph["provider"]["address"]
    complete_record = _complete_record(chain_id, provider, complete)
    require(
        publication["completeBindingRecord"] == complete[7] == complete_record,
        "VIEW export complete binding record differs",
    )

    return json_values(
        {
            "basic": {
                "recordHash": basic_record,
                "proposalHash": proposal_hash,
                "configurationTupleHash": _hash(BASIC_CONFIGURATION, config),
                "declarationTupleHash": _hash(VIEW_BINDING, declaration),
                "dependenciesHash": dependency_hash,
                "currentSnapshotDependenciesHash": _hash(
                    SNAPSHOT_DEPENDENCIES, retained_snapshot_dependencies
                ),
                "currentSnapshotGasMonotonic": True,
            },
            "complete": {
                "recordHash": complete_record,
                "selectionTupleHash": _hash(COMPLETE_SELECTION, selection),
                "initialReferenceDependenciesHash": complete[1],
                "currentReferenceDependenciesHash": reference_hash,
                "inventoryDependenciesHash": inventory_hash,
                "bundleDependenciesHash": bundle_hash,
                "basicBindingRecordHash": complete[4],
            },
            "auxiliary": {
                "capabilityHash": basic[0],
                "workersHash": basic[5],
                "actionId": basic[6],
                "boundAt": basic[7],
            },
            "claims": {
                "deterministicReceiptCorrespondenceChecked": True,
                "bundleDependenciesRetained": envelope["bundle"] is not None,
                "initialReferenceDependenciesPreimageVerified": True,
                "currentBindingAuthorityProven": False,
                "capabilityPreimageVerified": False,
                "completeWorkerSetVerified": False,
                "governanceActionVerified": False,
                "historicalExecutionVerified": False,
            },
            "qualification": (
                "The receipt self-hash chains, retained graph identities, complete source selection, "
                "saved snapshot dependency preimage, immutable snapshot prefix and monotonic current "
                "snapshot gas values correspond. Current reference, inventory and bundle dependency "
                "tuples correspond to the retained source; inventory and bundle are immutable and "
                "match their admission hashes. The capability preimage and SnapshotSource worker "
                "identity are absent; workersHash remains an opaque retained commitment. This exact "
                "export recipe additionally proves that its current reference dependency ABI still "
                "hashes to the initial admission value; the more general native provider's later-gas "
                "case is outside this closed export profile. actionId and boundAt are admission "
                "metadata without "
                "governance receipt, event or transaction proof. When the retained packet omits "
                "bundle coverage, bundleDependenciesABI is only an export-side preimage pin. No "
                "current binding authority follows from these historical receipts."
            ),
        }
    )


def validate(source, envelope):
    """Validate deterministic export/retained-source binding correspondence."""
    try:
        return _validate(source, envelope)
    except MuseumError:
        raise
    except (KeyError, IndexError, StopIteration, TypeError, ValueError, OverflowError) as exc:
        raise MuseumError("invalid VIEW export binding correspondence") from exc

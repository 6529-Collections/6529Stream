// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Exact root8b7b5822 helper bodies, with names prefixed for this fixture.
// Direct dependencies avoid compiling the unrelated full source-export test contract.

import "../metadata/StreamContentRootPublication.t.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../helpers/EntropyFinalityEvidenceFixture.sol";
import "../../mocks/MockEntropyRoleRegistry.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import {
    StreamCollectionSnapshots
} from "../../../smart-contracts/domains/metadata/StreamCollectionSnapshots.sol";
import {
    StreamSnapshotTypes
} from "../../../smart-contracts/interfaces/stream/metadata/StreamSnapshotTypes.sol";
import {
    StreamFinalitySnapshotReads
} from "../../../smart-contracts/domains/finality/StreamFinalitySnapshotReads.sol";
import {
    StreamFinalitySnapshotEvidence
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalitySnapshotTypes.sol";
import {
    StreamSnapshotDefinitions
} from "../../../smart-contracts/domains/records/StreamSnapshotDefinitions.sol";
import { StreamRecordJson } from "../../../smart-contracts/domains/records/StreamRecordJson.sol";
import {
    StreamSnapshotManifestJson
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestJson.sol";
import {
    StreamSnapshotManifestBytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import "../../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import "../../../smart-contracts/domains/finality/StreamOnchainContentCheckpoint.sol";
import "../../../smart-contracts/domains/finality/StreamContentLeafManifest.sol";

interface PreservationSourceVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function writeFile(string calldata, string calldata) external;
    function createDir(string calldata, bool) external;
}

contract PreservationSourceSnapshotConsumer {
    StreamFinalitySnapshotReads.Dependencies internal dependencies;

    constructor(StreamFinalitySnapshotReads.Dependencies memory d) {
        dependencies = d;
    }

    function read(StreamFinalityScope memory scope, bytes32 record, uint64 revision)
        external
        view
        returns (StreamFinalitySnapshotEvidence memory)
    {
        return StreamFinalitySnapshotReads.requireCurrent(dependencies, scope, record, revision);
    }

    function locked(StreamFinalityScope memory scope, bytes32 record, uint64 revision)
        external
        view
        returns (StreamFinalitySnapshotEvidence memory)
    {
        return StreamFinalitySnapshotReads.requireLocked(dependencies, scope, record, revision);
    }
}

contract PreservationSourceManifestHarness {
    StreamSnapshotManifestBytes.Manifest internal saved;

    function retain(address store, bytes memory raw) external {
        StreamSnapshotManifestBytes.retain(saved, store, raw);
    }

    function read() external view returns (bytes memory) {
        return StreamSnapshotManifestBytes.read(saved);
    }

    function count() external view returns (uint256) {
        return saved.pointers.length;
    }
}

/// @dev Explicit archival-family receipt boundary. Actual immutable bytes, checkpoint and
///      complete ordered leaf verification are exercised by the actual producers below.
contract PreservationSourceArchiveBoundary {
    address public immutable core;
    address public immutable schemaRegistry;
    F.Coverage internal row;
    address internal pointer;
    bool public current = true;

    constructor(address c, address s) {
        core = c;
        schemaRegistry = s;
    }

    function configure(bytes memory raw, address p) external {
        pointer = p;
        row = F.Coverage(
            keccak256("coverage"),
            keccak256("artifact"),
            keccak256("artist"),
            keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1"),
            keccak256("STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1"),
            keccak256(raw),
            uint64(raw.length),
            1,
            keccak256("family A"),
            keccak256("family B"),
            1,
            keccak256("coverage evidence")
        );
    }

    function setCurrent(bool value) external {
        current = value;
    }

    function requireArtifactCoverage(bytes32 hash, bytes32 artist, bytes32 artifact)
        external
        view
        returns (F.Coverage memory)
    {
        require(
            current && hash == row.completionHash && artist == row.artistId
                && artifact == row.artifactHash,
            "archive boundary"
        );
        return row;
    }

    function artifactChunk(bytes32 artifact, uint32 index)
        external
        view
        returns (address, bytes32)
    {
        require(artifact == row.artifactHash && index == 0);
        return (pointer, pointer.codehash);
    }
}

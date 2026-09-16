// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamRevenueResolverContinuity.sol";
import "./IStreamRoyaltyResolver.sol";
import "./IStreamRoyaltySnapshot.sol";

library StreamRoyaltyContinuityTypes {
    struct Header {
        uint16 schemaVersion;
        address core;
        address factory;
        uint16 maxRoyaltyBps;
        uint256 protectedCount;
        bytes32 protectedRoot;
        uint256 electionCount;
        bytes32 electionRoot;
        bytes32 frozenStateHash;
    }

    struct Route {
        uint8 scope;
        uint256 scopeId;
        uint256 collectionId;
        address hashOrigin;
        IStreamRoyaltyResolver.RoyaltyConfig config;
        bytes32 assignmentHash;
        bytes32 policyHash;
        IStreamRoyaltySnapshot.Snapshot snapshot;
    }

    struct Election {
        uint256 collectionId;
        uint8 mode;
        bytes32 electionHash;
        address hashOrigin;
    }

    struct ManifestRef {
        bytes32 expectedSourceHeaderHash;
        bytes32 contentHash;
        string uri;
        bytes32 uriHash;
        bytes32 schemaId;
        bytes32 canonicalizationId;
    }

    struct ImportState {
        uint8 status; // 0 original/pristine, 1 importing, 2 completed
        address source;
        bytes32 sourceRuntimeHash;
        bytes32 manifestHash;
        bytes32 beginActionId;
        uint256 importedRoutes;
        uint256 importedElections;
        Header expected;
        ManifestRef manifestReference;
    }
    error InvalidEconomicContinuity();
    error EconomicContinuityInProgress();
    error EconomicContinuitySourceChanged();
    error EconomicContinuityIndex();
    error EconomicContinuityReadFailed(address target, bytes4 selector);
}

/// @notice Exact-state royalty handoff. Primary routes and new freeze semantics are separate.
interface IStreamRoyaltyEconomicContinuity is IStreamRevenueResolverContinuity {
    event ProtectedEconomicRouteRecorded(
        uint16 schemaVersion,
        uint256 indexed index,
        bytes32 indexed routeKey,
        bytes32 indexed routeHash,
        bytes canonicalRoute
    );
    event EconomicElectionRecorded(
        uint16 schemaVersion,
        uint256 indexed index,
        uint256 indexed collectionId,
        bytes32 electionHash,
        address hashOrigin,
        uint8 mode
    );
    event EconomicContinuityBegun(
        uint16 schemaVersion,
        address indexed source,
        bytes32 indexed manifestHash,
        bytes32 indexed actionId,
        bytes canonicalManifest
    );
    event EconomicContinuityProgress(
        uint16 schemaVersion,
        bytes32 indexed manifestHash,
        uint256 importedRoutes,
        uint256 importedElections
    );
    event EconomicContinuityCompleted(
        uint16 schemaVersion,
        address indexed source,
        bytes32 indexed manifestHash,
        bytes32 frozenStateHash
    );
    function continuityHeader() external view returns (StreamRoyaltyContinuityTypes.Header memory);
    function protectedEconomicRouteAt(uint256 index)
        external
        view
        returns (StreamRoyaltyContinuityTypes.Route memory);
    function economicElectionAt(uint256 index)
        external
        view
        returns (StreamRoyaltyContinuityTypes.Election memory);
    function economicContinuityState()
        external
        view
        returns (StreamRoyaltyContinuityTypes.ImportState memory);
    function economicContinuityReady() external view returns (bool);
    function continuitySource() external view returns (address);
    function continuityManifestHash() external view returns (bytes32);
    function previewEconomicContinuity(
        address source,
        StreamRoyaltyContinuityTypes.ManifestRef calldata manifestReference
    )
        external
        view
        returns (bytes32 manifestHash, bytes32 scope, bytes32 oldValueHash, bytes32 newValueHash);
    function beginEconomicContinuity(
        address source,
        StreamRoyaltyContinuityTypes.ManifestRef calldata manifestReference
    ) external;
    function importEconomicContinuity(uint256 maxRoutes, uint256 maxElections) external;
    function completeEconomicContinuity() external;
}

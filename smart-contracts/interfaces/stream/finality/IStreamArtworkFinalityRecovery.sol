// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityRecoveryRequest,
    StreamFinalityRecoveryRecord,
    StreamFinalityRecoveryRefreshPlan
} from "./StreamFinalityRecoveryTypes.sol";

/// @notice Canonical executor-only recovery auxiliary interface defined by ADR0020.
/// @dev The sixteen selectors XOR to 0x83685f5c. This interface does not change the
///      permanent original Finality interface or include additive deployment/artist subsets.
interface IStreamArtworkFinalityRecovery {
    function stageFinalityRecoveryManifest(bytes calldata manifestBytes)
        external
        returns (bytes32 contentHash);

    function finalityRecoveryManifestStored(bytes32 contentHash) external view returns (bool stored);

    function finalityRecoveryManifestBytes(bytes32 contentHash)
        external
        view
        returns (bytes memory manifestBytes);

    function finalityRecoveryIntentBytes(StreamFinalityRecoveryRequest calldata request)
        external
        view
        returns (bytes memory intentBytes);

    function executeFinalityRecovery(StreamFinalityRecoveryRequest calldata request) external;

    function finalityRecoveryRecord(bytes32 recoveryId)
        external
        view
        returns (StreamFinalityRecoveryRecord memory record);

    function activeFinalityRecovery(StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32 recoveryId, bytes32 recoveryRouteHash, uint64 generation);

    function resolvedFinalityRoute(bytes32 routeType, StreamFinalityScope calldata scope)
        external
        view
        returns (
            bool pinned,
            address module,
            bytes32 componentRouteHash,
            bytes32 originalFinalityRecordHash,
            bytes32 recoveryId
        );

    function finalityRecoveryRouteStatus(bytes32 routeType, StreamFinalityScope calldata scope)
        external
        view
        returns (
            bool pinned,
            bool currentRouteMatches,
            bytes32 componentRouteHash,
            bytes32 recoveryId
        );

    function finalityRecoveryRefreshPlan(bytes32 recoveryId)
        external
        view
        returns (StreamFinalityRecoveryRefreshPlan memory plan);

    function continueFinalityRecoveryRefresh(StreamFinalityScope calldata scope, bytes32 recoveryId)
        external;

    function incompleteFinalityRecoveryRefreshPlanCount() external view returns (uint256 count);

    function assertNoIncompleteFinalityRecoveryRefreshPlans() external view;

    function finalityRecoveryScopeHash(StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32 scopeHash);

    function finalityRecoveryOldValueHash(StreamFinalityRecoveryRequest calldata request)
        external
        view
        returns (bytes32 oldValueHash);

    function finalityRecoveryNewValueHash(StreamFinalityRecoveryRequest calldata request)
        external
        view
        returns (bytes32 newValueHash);
}

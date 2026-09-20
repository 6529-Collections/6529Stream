// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistGuardianSelectionTypes as S } from "./StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistRecoverySelectionTypesV2 as V2
} from "./StreamArtistRecoverySelectionTypesV2.sol";

interface IStreamArtistRecoverySelectionPreparation {
    event RecoverySelectionPrepared(
        bytes32 indexed key, bytes32 indexed manifestHash, uint64 count
    );
    event RecoverySelectionProgress(bytes32 indexed key, uint64 processed, bool complete);

    function owner() external view returns (address);
    function artistRegistry() external view returns (address);
    function deploymentChainId() external view returns (uint256);
    function beginSelectionV2(bytes32 manifestHash) external returns (bytes32 key);
    function continueSelectionV2(bytes32 key, uint64 maximumRecords)
        external
        returns (S.Progress memory);
    function requireSelectionV2(bytes32 manifestHash) external view returns (S.Result memory);
    function selectionV2(bytes32 key) external view returns (V2.Basis memory, S.Progress memory);
    /// @notice Membership frozen by a completed scan, independent of election eligibility.
    function retainedMemberV2(bytes32 key, address actor) external view returns (bool);
}

/// @notice Immutable preparation binding, exposed by the fixed Identity owner.
interface IStreamArtistRecoverySelectionBinding {
    function recoverySelectionPreparationBinding() external view returns (address, bytes32);
}

/// @notice The owner authenticates the manifest, current cause, ancestry and selection policy.
interface IStreamArtistRecoverySelectionOwnerV2 {
    function recoverySelectionBasisV2(bytes32 manifestHash) external view returns (V2.Basis memory);
}

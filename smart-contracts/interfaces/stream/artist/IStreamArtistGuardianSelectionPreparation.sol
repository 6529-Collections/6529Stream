// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistGuardianSelectionTypes as S } from "./StreamArtistGuardianSelectionTypes.sol";
import { StreamArtistGuardianHistoryTypes as H } from "./StreamArtistGuardianHistoryTypes.sol";
import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";

interface IStreamArtistGuardianSelectionPreparation {
    function owner() external view returns (address);
    function artistRegistry() external view returns (address);
    function deploymentChainId() external view returns (uint256);
    function begin(bytes32 artistId, bytes32 transition, bytes32[] calldata excluded)
        external
        returns (bytes32 key);
    function continueSelection(bytes32 key, uint64 maximumRecords)
        external
        returns (S.Progress memory);
    function selection(bytes32 key) external view returns (S.Basis memory, S.Progress memory);
    function requireSelection(
        bytes32 artistId,
        H.Head calldata history,
        R.TransitionState calldata transition,
        bytes32[] calldata excluded
    ) external view returns (S.Result memory);
}

/// @notice Immutable preparation binding on the fixed third Identity child.
interface IStreamArtistGuardianSelectionBinding {
    function guardianSelectionPreparationBinding() external view returns (address, bytes32);
}

interface IStreamArtistGuardianSelectionOwner {
    function identityRecoveryExtension() external view returns (address);
    function guardianRecoverySelection(bytes32 actionId)
        external
        view
        returns (S.Result memory, R.GuardianRecord memory);
}

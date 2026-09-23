// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryRewindTypes as W } from "./StreamArtistRecoveryRewindTypes.sol";

interface IStreamArtistRecoveryRewindSelection {
    function owner() external view returns (address);
    function payoutOwner() external view returns (address);
    function artistRegistry() external view returns (address);
    function deploymentChainId() external view returns (uint256);
    function coordinator() external view returns (address);
    function beginSelectionV3(bytes32 manifestHash) external returns (bytes32);
    function continueSelectionV3(bytes32 key, uint64 maximumRecords)
        external
        returns (W.ProgressV3 memory);
    function requireSelectionV3(bytes32 manifestHash) external view returns (W.ResultV3 memory);
    function selectionV3(bytes32 key) external view returns (W.BasisV3 memory, W.ProgressV3 memory);
    function selectionResultV3(bytes32 key) external view returns (W.ResultV3 memory);
    function selectionRecordV3(bytes32 key, bytes32 recordHash)
        external
        view
        returns (W.RecordKind, W.SelectedRecordV3 memory, bool retained, bool eligible);
    function retainedMemberV3(bytes32 key, address actor) external view returns (bool);
    function sealPreparationV3(bytes32 manifestHash, bytes32 actionId, bytes32 associationHash)
        external
        returns (bytes32 sealCommitment);
    function preparationSealV3(bytes32 key) external view returns (W.PreparationSealV3 memory);
}

interface IStreamArtistRecoveryRewindSelectionBinding {
    function recoveryRewindSelectionBinding() external view returns (address, bytes32);
}

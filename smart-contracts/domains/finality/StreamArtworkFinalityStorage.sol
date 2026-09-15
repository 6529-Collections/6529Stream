// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Original six physical roots. The retired local action map remains reserved forever.
abstract contract StreamArtworkFinalityStorage {
    mapping(uint256 => StreamCollectionFinalityRecord) internal _collectionRecords;
    mapping(uint256 => StreamFinalityComponentExpectation[]) internal _collectionComponents;
    mapping(bytes32 => StreamScopedFinalityRecord) internal _scopedRecords;
    mapping(bytes32 => StreamFinalityComponentExpectation[]) internal _scopedComponents;
    mapping(bytes32 => StreamTerminalFreezeAction) internal _terminalFreezes;
    mapping(bytes32 => bytes) internal _manifestBytes;
}

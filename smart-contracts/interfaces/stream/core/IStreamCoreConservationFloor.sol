// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice One-time Core anchor retaining original sale-floor receipts across satellite replacement.
interface IStreamCoreConservationFloor {
    error ConservationFloorAlreadyBound();
    error InvalidConservationFloor(address candidate);

    event ConservationFloorBound(
        uint16 schemaVersion,
        address indexed ledger,
        bytes32 runtimeCodeHash,
        bytes32 indexed actionId
    );

    function conservationFloor() external view returns (address ledger, bytes32 runtimeCodeHash);
    function conservationFloorTransition(address candidate)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
    function bindConservationFloor(address candidate) external;
}

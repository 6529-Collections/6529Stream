// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamFinalityRecoveryRequest } from "./StreamFinalityRecoveryTypes.sol";

/// @notice Immutable availability of the complete request behind a staged 704-byte intent.
/// @dev Registration conveys no authority, scheduling evidence, current head or route readiness.
interface IStreamFinalityRecoveryIntentStorage {
    event FinalityRecoveryIntentRegistered(
        uint16 schemaVersion,
        bytes32 indexed manifestContentHash,
        bytes32 indexed requestHash,
        address requestPointer,
        address actor
    );

    function registerFinalityRecoveryIntent(StreamFinalityRecoveryRequest calldata request)
        external
        returns (bytes32 requestHash);

    function finalityRecoveryIntentRequest(bytes32 manifestContentHash)
        external
        view
        returns (StreamFinalityRecoveryRequest memory request);
}

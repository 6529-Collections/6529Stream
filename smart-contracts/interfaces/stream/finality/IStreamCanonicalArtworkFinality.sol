// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtworkFinalityTypes.sol";
import "./StreamFinalityGovernanceTypes.sol";

/// @notice Canonical Executor lifecycle and independently validated execution preparation.
interface IStreamCanonicalArtworkFinality {
    error FinalityLocalLifecycleRetired();
    error FinalityCurrentBindingInvalid(address target);
    error FinalityScopeInputsInvalid();

    event FinalityExecutionWitnessRecorded(
        uint16 schemaVersion,
        bytes32 indexed finalityRecordHash,
        bytes32 indexed actionId,
        address indexed proposer,
        bytes32 reasonHash,
        bytes32 roleMutationHash,
        uint64 roleRevision,
        bytes32 inputsHash
    );

    /// @notice Validates candidate evidence without requiring a currently executing action.
    function finalityExecutionContext(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest
    ) external view returns (StreamFinalityExecutionContext memory);

    function finalityExecutionWitness(bytes32 finalityRecordHash)
        external
        view
        returns (StreamFinalityExecutionWitness memory);
}

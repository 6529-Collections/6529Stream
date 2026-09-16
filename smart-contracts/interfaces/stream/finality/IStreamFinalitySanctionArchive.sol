// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtworkFinalityTypes.sol";
import "./StreamFinalityGovernanceTypes.sol";
import "./StreamFinalitySanctionArchiveTypes.sol";

/// @notice Explicit archive-proof selection for artist-bound canonical finality.
/// @dev Candidate reads validate actual bytes and current coverage outside an executing action.
///      Mutations require the canonical Executor context to bind the exact evidence selection.
interface IStreamFinalitySanctionArchive {
    error FinalitySanctionArchiveRequired();
    error FinalitySanctionArchiveInvalid();
    error FinalitySanctionArchiveReadFailed(address target);

    event FinalitySanctionArchiveWitnessRecorded(
        uint16 schemaVersion,
        bytes32 indexed finalityRecordHash,
        bytes32 indexed evidenceHash,
        bytes32 indexed sanctionRecordHash,
        bytes32 artifactHash,
        bytes32 completionHash
    );

    function artifactCoverage() external view returns (address);

    function finalityExecutionContextWithArchive(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest,
        StreamFinalitySanctionArchiveProof calldata archiveProof
    ) external view returns (StreamFinalityExecutionContext memory);

    function finalizeCollectionArtworkWithArchive(
        uint256 collectionId,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest,
        StreamFinalitySanctionArchiveProof calldata archiveProof
    ) external;

    function finalizeArtworkScopeWithArchive(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest,
        StreamFinalitySanctionArchiveProof calldata archiveProof
    ) external;

    /// @notice Immutable executed evidence; later pointer or family changes do not rewrite history.
    function finalitySanctionArchiveWitness(bytes32 finalityRecordHash)
        external
        view
        returns (StreamFinalitySanctionArchiveWitness memory);
}

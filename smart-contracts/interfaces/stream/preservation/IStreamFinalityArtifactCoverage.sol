// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamFinalityArtifactTypes as F } from "./StreamFinalityArtifactTypes.sol";

interface IStreamFinalityArtifactCoverage {
    error InvalidArtifact();
    error ArtifactExists(bytes32 artifactHash);
    error ArtifactMissing(bytes32 artifactHash);
    error ArtifactComponentChanged(address target);
    error ArtifactReadFailed(address target);
    error ArtifactParentGas(uint256 available, uint256 required);
    error InvalidArtifactCoverage(bytes32 planHash);
    error ArtifactCoverageStale(bytes32 planHash);
    error ArtifactCoverageIndex(uint32 expected, uint32 actual);

    event FinalityArtifactRecorded(
        uint16 schemaVersion, bytes32 indexed artifactHash, F.Artifact artifact
    );
    event FinalityArtifactCoverageStarted(
        uint16 schemaVersion, bytes32 indexed planHash, F.Plan plan
    );
    event FinalityArtifactChunkCovered(
        uint16 schemaVersion,
        bytes32 indexed planHash,
        uint32 indexed index,
        bytes32 coverageRecordHash,
        bytes32 evidenceChainHash
    );
    event FinalityArtifactCoverageCompleted(
        uint16 schemaVersion,
        bytes32 indexed completionHash,
        bytes32 indexed planHash,
        F.Coverage coverage
    );
    event FinalityArtifactValidationAdvanced(
        uint16 schemaVersion,
        bytes32 indexed completionHash,
        bytes32 indexed validationPlanHash,
        uint32 indexed index,
        bytes32 coverageRecordHash,
        bytes32 evidenceChainHash
    );
    event FinalityArtifactValidationCompleted(
        uint16 schemaVersion, bytes32 indexed validationRecordHash, F.Validation validation
    );

    function core() external view returns (address);
    function archivalCoverage() external view returns (address);
    function schemaRegistry() external view returns (address);
    function chunkStore() external view returns (address);
    function finalityRegistry() external view returns (address);
    function recordArtifact(F.Artifact calldata artifact) external returns (bytes32 artifactHash);
    function artifact(bytes32 artifactHash) external view returns (F.Artifact memory);
    function artifactChunk(bytes32 artifactHash, uint32 index)
        external
        view
        returns (address pointer, bytes32 codeHash);
    function beginCoverage(bytes32 artifactHash, bytes32 firstFamily, bytes32 secondFamily)
        external
        returns (bytes32 planHash);
    function coverNextChunk(bytes32 planHash, uint32 index, bytes32 coverageRecordHash)
        external
        returns (bytes32 completionHash);
    function coveragePlan(bytes32 planHash) external view returns (F.Plan memory);
    function coverage(bytes32 completionHash) external view returns (F.Coverage memory);
    function refreshNextChunk(bytes32 completionHash, uint32 index, bytes32 currentCoverageHash)
        external
        returns (bytes32 validationRecordHash);
    /// @notice Latest completed validation cache, which may now be stale after an epoch or pin change.
    /// @dev Only requireArtifactCoverage performs fresh current admission.
    function currentCoverageValidation(bytes32 completionHash)
        external
        view
        returns (F.Validation memory);
    function coverageValidationRecord(bytes32 validationRecordHash)
        external
        view
        returns (F.Validation memory);
    /// @notice Current admission; the returned immutable original metadata excludes the mutable validation head.
    /// @dev Current cache facts are separately exposed by currentCoverageValidation().
    function requireArtifactCoverage(bytes32 completionHash, bytes32 artistId, bytes32 artifactHash)
        external
        view
        returns (F.Coverage memory);
}

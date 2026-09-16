// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamReferenceRenderPublication.sol";
import "./StreamReferenceModeTypes.sol";

/// @notice New mode-aware writes with original typed reference receipt/lock consumer reads.
/// @dev The inherited BYTE_EXACT write/preview selectors deliberately reject on this distinct host.
interface IStreamReferenceModePublication is IStreamReferenceRenderPublication {
    function modeDependencies() external view returns (StreamReferenceModeTypes.Dependencies memory);
    function modeContextHash(StreamReferenceRenderTypes.Publication calldata p)
        external
        view
        returns (bytes32);
    function previewModeReference(
        StreamReferenceRenderTypes.Publication calldata p,
        StreamReferenceModeTypes.Evidence calldata evidence,
        address recorder
    ) external view returns (bytes32 sourceHash, bytes memory canonical);
    function publishModeReference(
        StreamReferenceRenderTypes.Publication calldata p,
        StreamReferenceModeTypes.Evidence calldata evidence
    ) external returns (bytes32);
    function referenceModeEvidence(bytes32 recordHash)
        external
        view
        returns (StreamReferenceModeTypes.Evidence memory, StreamReferenceModeTypes.Facts memory);
    function referenceMode(bytes32 recordHash)
        external
        view
        returns (StreamReferenceModeTypes.Mode mode, bytes32 evidenceHash);
    event ReferenceModePublished(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        StreamReferenceModeTypes.Mode mode,
        bytes32 evidenceHash,
        bytes32 interpretationHash
    );
}

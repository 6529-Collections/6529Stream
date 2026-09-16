// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Explicit collection-context facts for poster and paid-collaborator templates.
/// @dev Existing artist-only template capabilities retain their original grammar.
interface IStreamArtistDynamicPrimaryTemplateFacts {
    function isDynamicPrimaryTemplate(bytes32 templateId) external view returns (bool);
    function dynamicPrimaryTemplateFacts(uint256 collectionId, bytes32 templateId)
        external
        view
        returns (
            bytes32 entriesHash,
            bytes32 metadataURIHash,
            uint32 artistSharePpm,
            bytes32 beneficiaryHash
        );
    function previewArtistDynamicPrimaryTemplateAssignment(
        uint256 collectionId,
        bytes32 templateId,
        bytes32 policyHash,
        bool frozen
    ) external view returns (T.AssignmentFact memory);
}

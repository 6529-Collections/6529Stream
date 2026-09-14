// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistOnboardingTypes.sol";

/// @notice Raw default template identity under an actual collection's Artist consent context.
interface IStreamArtistDefaultPrimaryTemplateFacts {
    function previewArtistDefaultPrimaryTemplateAssignment(
        uint256 collectionId,
        bytes32 templateId,
        bytes32 policyHash,
        bool frozen
    ) external view returns (StreamArtistOnboardingTypes.AssignmentFact memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Raw scoped TEMPLATE reconstruction; it does not require the consent being proposed.
interface IStreamArtistScopedPrimaryTemplateFacts {
    function previewArtistScopedPrimaryTemplateAssignment(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        bytes32 templateId,
        bytes32 policyHash,
        bool frozen
    ) external view returns (T.AssignmentFact memory);
}

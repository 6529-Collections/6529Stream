// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamSaleTemplate } from "./StreamSaleTemplate.sol";
import { IStreamRevenueResolver } from "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import {
    IStreamArtistPrimaryTemplateConsentFacts
} from "../../interfaces/stream/artist/IStreamArtistPrimaryTemplateConsentFacts.sol";

/// @notice Explicit positive-share collection-template projection for consent-qualified consumers.
/// @dev Callers first resolve the actual current assignment through the pinned Resolver, which
///      authenticates consent for low-take rights. This never falls back from the initial capability.
library StreamConsentedSaleTemplate {
    function preview(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory assignment
    ) internal view returns (StreamSaleTemplate.Selection memory selected) {
        if (
            !assignment.exists || assignment.assignmentType != 2 || assignment.scope != 1
                || assignment.scopeId != collectionId || assignment.profileId != 0
                || assignment.templateId == 0 || assignment.assignmentHash == 0
                || assignment.policyHash != 0
        ) {
            revert StreamSaleTemplate.UnsupportedSaleTemplate();
        }
        (,, uint32 artistShare) = IStreamArtistPrimaryTemplateConsentFacts(address(resolver))
            .primaryTemplateConsentFacts(assignment.templateId);
        if (artistShare == 0) revert StreamSaleTemplate.UnsupportedSaleTemplate();
        selected.templateId = assignment.templateId;
        selected.assignmentHash = assignment.assignmentHash;
        (selected.profileId, selected.wallet, selected.entriesHash) =
            resolver.previewCollectionPrimaryProfile(
                assignment.templateId, collectionId, address(0)
            );
        if (selected.profileId == 0 || selected.wallet == address(0) || selected.entriesHash == 0) {
            revert StreamSaleTemplate.UnsupportedSaleTemplate();
        }
    }
}

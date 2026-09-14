// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamSaleTemplate } from "./StreamSaleTemplate.sol";
import { IStreamRevenueResolver } from "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import {
    IStreamDynamicPrimaryTemplates
} from "../../interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";
import {
    IStreamArtistDynamicPrimaryTemplateFacts
} from "../../interfaces/stream/artist/IStreamArtistDynamicPrimaryTemplateFacts.sol";

/// @notice Explicit dynamic projection retaining the authenticated sale poster and exact witnesses.
library StreamDynamicSaleTemplate {
    function preview(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        address poster,
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a
    ) internal view returns (StreamSaleTemplate.Selection memory s, bytes32 witness) {
        if (
            !a.exists || a.assignmentType != 2 || a.scope != 1 || a.scopeId != collectionId
                || a.profileId != 0 || a.templateId == 0 || a.assignmentHash == 0
                || a.policyHash != 0
        ) revert StreamSaleTemplate.UnsupportedSaleTemplate();
        (,, uint32 share, bytes32 facts) = IStreamArtistDynamicPrimaryTemplateFacts(
                address(resolver)
            ).dynamicPrimaryTemplateFacts(collectionId, a.templateId);
        if (share == 0 || facts == 0) revert StreamSaleTemplate.UnsupportedSaleTemplate();
        s.templateId = a.templateId;
        s.assignmentHash = a.assignmentHash;
        (s.profileId, s.wallet, s.entriesHash, witness) = IStreamDynamicPrimaryTemplates(
                address(resolver)
            ).previewDynamicCollectionPrimaryProfile(a.templateId, collectionId, poster);
        if (s.profileId == 0 || s.wallet == address(0) || s.entriesHash == 0 || witness != facts) {
            revert StreamSaleTemplate.UnsupportedSaleTemplate();
        }
    }

    function materialize(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        address poster,
        StreamSaleTemplate.Selection memory s,
        bytes32 witness
    ) internal {
        StreamSaleTemplate.requireCurrent(resolver, collectionId, s);
        (bytes32 profile, address wallet, bytes32 entries, bytes32 actual) = IStreamDynamicPrimaryTemplates(
                address(resolver)
            ).materializeDynamicCollectionPrimaryProfile(s.templateId, collectionId, poster, false);
        if (
            profile != s.profileId || wallet != s.wallet || entries != s.entriesHash
                || actual != witness
        ) revert StreamSaleTemplate.SaleTemplateMaterializationMismatch();
    }
}

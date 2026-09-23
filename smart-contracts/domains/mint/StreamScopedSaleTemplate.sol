// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRevenueResolver } from "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import { StreamSaleTemplate } from "./StreamSaleTemplate.sol";
import "../../interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryTemplateFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryTemplateConsentFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistDynamicPrimaryTemplateFacts.sol";

/// @notice Token TEMPLATE families selected explicitly by the signed custody-rights mode.
library StreamScopedSaleTemplate {
    function preview(
        IStreamRevenueResolver resolver,
        uint256 collection,
        uint256 token,
        uint8 mode,
        address poster,
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a
    ) internal view returns (StreamSaleTemplate.Selection memory s, bytes32 witness) {
        if (
            token == 0 || !a.exists || a.assignmentType != 2 || a.scope != 2 || a.scopeId != token
                || a.profileId != 0 || a.templateId == 0 || a.assignmentHash == 0
                || a.policyHash != 0
        ) revert StreamSaleTemplate.UnsupportedSaleTemplate();
        s.templateId = a.templateId;
        s.assignmentHash = a.assignmentHash;
        if (mode == 4) {
            (,, uint32 share, bytes32 facts) = IStreamArtistDynamicPrimaryTemplateFacts(
                    address(resolver)
                ).dynamicPrimaryTemplateFacts(collection, a.templateId);
            if (share == 0 || facts == 0) revert StreamSaleTemplate.UnsupportedSaleTemplate();
            (s.profileId, s.wallet, s.entriesHash, witness) = IStreamDynamicPrimaryTemplates(
                    address(resolver)
                ).previewDynamicCollectionPrimaryProfile(a.templateId, collection, poster);
            if (witness != facts) revert StreamSaleTemplate.UnsupportedSaleTemplate();
        } else {
            if (mode == 2) {
                IStreamArtistPrimaryTemplateFacts(address(resolver))
                    .primaryTemplateEconomicsFacts(a.templateId);
            } else if (mode == 3) {
                (,, uint32 share) = IStreamArtistPrimaryTemplateConsentFacts(address(resolver))
                    .primaryTemplateConsentFacts(a.templateId);
                if (share == 0) revert StreamSaleTemplate.UnsupportedSaleTemplate();
            } else {
                revert StreamSaleTemplate.UnsupportedSaleTemplate();
            }
            (s.profileId, s.wallet, s.entriesHash) =
                resolver.previewCollectionPrimaryProfile(a.templateId, collection, address(0));
        }
        if (s.profileId == 0 || s.wallet == address(0) || s.entriesHash == 0) {
            revert StreamSaleTemplate.UnsupportedSaleTemplate();
        }
    }

    function materialize(
        IStreamRevenueResolver resolver,
        uint256 collection,
        uint256 token,
        uint8 mode,
        address poster,
        StreamSaleTemplate.Selection memory s,
        bytes32 witness
    ) internal {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory
            a = resolver.resolvePrimaryAssignment(collection, token, keccak256("PRIMARY_SALE"));
        if (
            !a.exists || a.scope != 2 || a.scopeId != token || a.assignmentType != 2
                || a.profileId != 0 || a.templateId != s.templateId
                || a.assignmentHash != s.assignmentHash || a.policyHash != 0
        ) revert StreamSaleTemplate.SaleTemplateAssignmentChanged();
        bytes32 profile;
        address wallet;
        bytes32 entries;
        if (mode == 4) {
            bytes32 actual;
            (profile, wallet, entries, actual) = IStreamDynamicPrimaryTemplates(address(resolver))
                .materializeDynamicCollectionPrimaryProfile(s.templateId, collection, poster, false);
            if (actual != witness) revert StreamSaleTemplate.SaleTemplateMaterializationMismatch();
        } else {
            if (mode != 2 && mode != 3) revert StreamSaleTemplate.UnsupportedSaleTemplate();
            (profile, wallet, entries) = resolver.materializeCollectionPrimaryProfile(
                s.templateId, collection, address(0), false
            );
        }
        if (profile != s.profileId || wallet != s.wallet || entries != s.entriesHash) {
            revert StreamSaleTemplate.SaleTemplateMaterializationMismatch();
        }
    }
}

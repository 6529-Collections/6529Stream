// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistDynamicTemplateReads } from "./StreamArtistDynamicTemplateReads.sol";
import "../../interfaces/stream/artist/IStreamArtistScopedPrimaryTemplateFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryTemplateConsentFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistDynamicPrimaryTemplateFacts.sol";
import "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Canonical previous/result reconstruction, with no current-consent read on the proposal path.
library StreamArtistTemplateMutationReads {
    function freeze(
        T.EconomicsConsent memory p,
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory current
    ) public view returns (bytes memory) {
        if (
            p.collectionId == 0 || p.assignmentHash == 0
                || p.revenueClass != keccak256("PRIMARY_SALE")
                || !((p.scope == 1 && p.scopeId == p.collectionId)
                    || (p.scope == 2 && p.scopeId != 0)) || !current.exists || current.frozen
                || current.scope != p.scope || current.scopeId != p.scopeId
                || current.assignmentType != 2 || current.profileId != 0 || current.templateId == 0
                || current.policyHash != 0
                || !IERC165(p.resolver)
                    .supportsInterface(type(IStreamArtistScopedPrimaryTemplateFacts).interfaceId)
        ) revert T.UnsupportedProfile();
        IStreamArtistScopedPrimaryTemplateFacts provider =
            IStreamArtistScopedPrimaryTemplateFacts(p.resolver);
        T.AssignmentFact memory previous = provider.previewArtistScopedPrimaryTemplateAssignment(
            p.collectionId, p.scope, p.scopeId, current.templateId, 0, false
        );
        T.AssignmentFact memory next = provider.previewArtistScopedPrimaryTemplateAssignment(
            p.collectionId, p.scope, p.scopeId, current.templateId, 0, true
        );
        if (
            previous.resolver != p.resolver || next.resolver != p.resolver
                || previous.revenueClass != p.revenueClass || next.revenueClass != p.revenueClass
                || previous.scope != p.scope || next.scope != p.scope
                || previous.scopeId != p.scopeId || next.scopeId != p.scopeId
                || previous.assignmentHash == 0 || previous.assignmentHash != current.assignmentHash
                || next.assignmentHash != p.assignmentHash
                || previous.assignmentHash == next.assignmentHash
        ) revert T.InvalidRecord();
        bool dynamic_ = StreamArtistDynamicTemplateReads.isDynamic(p.resolver, current.templateId);
        bytes32 entries;
        bytes32 metadata;
        uint32 share;
        bytes32 witness;
        if (dynamic_) {
            (entries, metadata, share, witness) = IStreamArtistDynamicPrimaryTemplateFacts(
                    p.resolver
                ).dynamicPrimaryTemplateFacts(p.collectionId, current.templateId);
            if (witness == 0) revert T.InvalidRecord();
        } else {
            (entries, metadata, share) = IStreamArtistPrimaryTemplateConsentFacts(p.resolver)
                .primaryTemplateConsentFacts(current.templateId);
        }
        if (entries == 0 || share == 0 || share > 1000000) revert T.InvalidRecord();
        return abi.encode(
            keccak256("6529STREAM_PROSPECTIVE_TEMPLATE_FREEZE_EVIDENCE_V1"),
            current,
            previous,
            next,
            dynamic_,
            entries,
            metadata,
            share,
            witness
        );
    }
}

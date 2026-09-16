// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistDynamicTemplateReads } from "./StreamArtistDynamicTemplateReads.sol";
import "../../interfaces/stream/artist/IStreamArtistScopedPrimaryTemplateFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryTemplateConsentFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistDynamicPrimaryTemplateFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Explicit token TEMPLATE evidence under the original exact-scope op15 signature.
library StreamArtistScopedTemplateReads {
    function prospective(T.EconomicsConsent memory p, bytes32 templateId)
        public
        view
        returns (bytes memory)
    {
        return _facts(
            p, templateId, false, keccak256("6529STREAM_PROSPECTIVE_SCOPED_TEMPLATE_EVIDENCE_V1")
        );
    }

    function current(
        uint256 collectionId,
        address resolver,
        bytes32 revenueClass,
        address consentOwner,
        T.Binding memory binding_,
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory selected
    ) public view returns (bytes memory) {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            collectionId,
            resolver,
            revenueClass,
            selected.scope,
            selected.scopeId,
            selected.assignmentHash
        );
        bytes memory evidence = _facts(
            p,
            selected.templateId,
            selected.frozen,
            keccak256("6529STREAM_CURRENT_SCOPED_TEMPLATE_EVIDENCE_V1")
        );
        if (
            IStreamArtistEconomicsEvidence(consentOwner)
                    .economicsRecordForBinding(
                        p, binding_.artistId, binding_.generation, binding_.bindingHash
                    ) == 0
        ) revert T.MissingMintPrerequisite(keccak256("economics"));
        return evidence;
    }

    function _facts(T.EconomicsConsent memory p, bytes32 templateId, bool frozen, bytes32 domain)
        private
        view
        returns (bytes memory)
    {
        if (
            p.scope != 2 || p.scopeId == 0 || p.collectionId == 0 || p.assignmentHash == 0
                || p.revenueClass != keccak256("PRIMARY_SALE")
                || !IERC165(p.resolver)
                    .supportsInterface(type(IStreamArtistScopedPrimaryTemplateFacts).interfaceId)
        ) revert T.UnsupportedProfile();
        bool dynamic_ = StreamArtistDynamicTemplateReads.isDynamic(p.resolver, templateId);
        bytes32 entries;
        bytes32 metadata;
        uint32 share;
        bytes32 beneficiaries;
        if (dynamic_) {
            (entries, metadata, share, beneficiaries) = IStreamArtistDynamicPrimaryTemplateFacts(
                    p.resolver
                ).dynamicPrimaryTemplateFacts(p.collectionId, templateId);
            if (beneficiaries == 0) revert T.InvalidRecord();
        } else {
            (entries, metadata, share) = IStreamArtistPrimaryTemplateConsentFacts(p.resolver)
                .primaryTemplateConsentFacts(templateId);
        }
        T.AssignmentFact memory fact = IStreamArtistScopedPrimaryTemplateFacts(p.resolver)
            .previewArtistScopedPrimaryTemplateAssignment(
                p.collectionId, p.scope, p.scopeId, templateId, 0, frozen
            );
        if (
            entries == 0 || share == 0 || share > 1_000_000 || fact.resolver != p.resolver
                || fact.revenueClass != p.revenueClass || fact.scope != p.scope
                || fact.scopeId != p.scopeId || fact.assignmentHash != p.assignmentHash
        ) revert T.InvalidRecord();
        return
            abi.encode(domain, templateId, dynamic_, entries, metadata, share, beneficiaries, fact);
    }
}

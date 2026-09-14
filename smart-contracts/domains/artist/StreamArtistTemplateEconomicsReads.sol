// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistScopedTemplateReads } from "./StreamArtistScopedTemplateReads.sol";
import { StreamArtistDynamicTemplateReads } from "./StreamArtistDynamicTemplateReads.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryTemplateFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryTemplateConsentFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Fixed linked template facts and evidence reads for the Artist read host.
/// @dev The host first checks its suite, accepted binding and operative payout.
///      Delegatecall preserves that host as the caller of every original provider read.
library StreamArtistTemplateEconomicsReads {
    function prospective(T.EconomicsConsent memory p, bytes32 templateId)
        public
        view
        returns (bytes memory)
    {
        if (p.scope == 2) return StreamArtistScopedTemplateReads.prospective(p, templateId);
        if (StreamArtistDynamicTemplateReads.isDynamic(p.resolver, templateId)) {
            return StreamArtistDynamicTemplateReads.prospective(p, templateId);
        }
        address resolver = p.resolver;
        IStreamArtistPrimaryTemplateConsentFacts provider =
            IStreamArtistPrimaryTemplateConsentFacts(resolver);
        (bytes32 entriesHash, bytes32 metadataURIHash, uint32 share) =
            provider.primaryTemplateConsentFacts(templateId);
        T.AssignmentFact memory fact = provider.previewArtistPrimaryTemplateConsentAssignment(
            p.collectionId, templateId, bytes32(0), false
        );
        if (
            entriesHash == bytes32(0) || share == 0 || share > 1_000_000
                || fact.resolver != p.resolver || fact.revenueClass != p.revenueClass
                || fact.scope != p.scope || fact.scopeId != p.scopeId
                || fact.assignmentHash != p.assignmentHash
        ) revert T.InvalidRecord();
        return abi.encode(
            keccak256("6529STREAM_PROSPECTIVE_PRIMARY_TEMPLATE_ECONOMICS_EVIDENCE_V1"),
            templateId,
            entriesHash,
            metadataURIHash,
            share,
            fact
        );
    }

    function current(
        uint256 collectionId,
        address resolver,
        bytes32 primaryRevenueClass,
        address consentOwner,
        T.Binding memory binding_,
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory current
    ) public view returns (bytes memory) {
        if (current.scope == 2) {
            return StreamArtistScopedTemplateReads.current(
                collectionId, resolver, primaryRevenueClass, consentOwner, binding_, current
            );
        }
        if (StreamArtistDynamicTemplateReads.isDynamic(resolver, current.templateId)) {
            return StreamArtistDynamicTemplateReads.current(
                collectionId, resolver, primaryRevenueClass, consentOwner, binding_, current
            );
        }
        bytes32 entriesHash;
        bytes32 metadataURIHash;
        uint32 artistShare;
        T.AssignmentFact memory preview;
        if (_templateConsentCapability(resolver)) {
            IStreamArtistPrimaryTemplateConsentFacts provider =
                IStreamArtistPrimaryTemplateConsentFacts(resolver);
            (entriesHash, metadataURIHash, artistShare) =
                provider.primaryTemplateConsentFacts(current.templateId);
            preview = provider.previewArtistPrimaryTemplateConsentAssignment(
                collectionId, current.templateId, current.policyHash, current.frozen
            );
            if (artistShare < 500_000) {
                T.EconomicsConsent memory consent = T.EconomicsConsent(
                    collectionId,
                    resolver,
                    primaryRevenueClass,
                    1,
                    collectionId,
                    current.assignmentHash
                );
                if (
                    IStreamArtistEconomicsEvidence(consentOwner)
                            .economicsRecordForBinding(
                                consent,
                                binding_.artistId,
                                binding_.generation,
                                binding_.bindingHash
                            ) == bytes32(0)
                ) {
                    revert T.MissingMintPrerequisite(keccak256("economics"));
                }
            }
        } else {
            IStreamArtistPrimaryTemplateFacts provider = IStreamArtistPrimaryTemplateFacts(resolver);
            (entriesHash, metadataURIHash, artistShare) =
                provider.primaryTemplateEconomicsFacts(current.templateId);
            preview = provider.previewArtistPrimaryTemplateAssignment(
                collectionId, current.templateId, current.policyHash, current.frozen
            );
            if (artistShare < 500_000) revert T.InvalidRecord();
        }
        if (
            entriesHash == bytes32(0) || artistShare == 0 || artistShare > 1_000_000
                || preview.resolver != resolver || preview.revenueClass != primaryRevenueClass
                || preview.scope != 1 || preview.scopeId != collectionId
                || preview.assignmentHash != current.assignmentHash
        ) revert T.InvalidRecord();
        return abi.encode(
            keccak256("6529STREAM_CURRENT_PRIMARY_TEMPLATE_ECONOMICS_EVIDENCE_V1"),
            current.templateId,
            entriesHash,
            metadataURIHash,
            artistShare
        );
    }

    function _templateConsentCapability(address resolver) private view returns (bool) {
        return IERC165(resolver)
            .supportsInterface(type(IStreamArtistPrimaryTemplateConsentFacts).interfaceId);
    }
}

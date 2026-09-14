// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistDynamicPrimaryTemplateFacts
} from "../../interfaces/stream/artist/IStreamArtistDynamicPrimaryTemplateFacts.sol";
import {
    IStreamArtistEconomicsEvidence
} from "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import { IStreamRevenueResolver } from "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Explicit contextual dynamic-template facts within the original Artist op15 transport.
library StreamArtistDynamicTemplateReads {
    function isDynamic(address resolver, bytes32 templateId) public view returns (bool) {
        if (!IERC165(resolver)
                .supportsInterface(type(IStreamArtistDynamicPrimaryTemplateFacts).interfaceId)) return false;
        return
            IStreamArtistDynamicPrimaryTemplateFacts(resolver).isDynamicPrimaryTemplate(templateId);
    }

    function prospective(T.EconomicsConsent memory p, bytes32 templateId)
        public
        view
        returns (bytes memory)
    {
        return _facts(
            p,
            templateId,
            false,
            keccak256("6529STREAM_PROSPECTIVE_DYNAMIC_PRIMARY_TEMPLATE_EVIDENCE_V1")
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
            collectionId, resolver, revenueClass, 1, collectionId, selected.assignmentHash
        );
        bytes memory evidence = _facts(
            p,
            selected.templateId,
            selected.frozen,
            keccak256("6529STREAM_CURRENT_DYNAMIC_PRIMARY_TEMPLATE_EVIDENCE_V1")
        );
        if (
            IStreamArtistEconomicsEvidence(consentOwner)
                    .economicsRecordForBinding(
                        p, binding_.artistId, binding_.generation, binding_.bindingHash
                    ) == 0
        ) {
            revert T.MissingMintPrerequisite(keccak256("economics"));
        }
        return evidence;
    }

    function _facts(T.EconomicsConsent memory p, bytes32 templateId, bool frozen, bytes32 domain)
        private
        view
        returns (bytes memory)
    {
        IStreamArtistDynamicPrimaryTemplateFacts provider =
            IStreamArtistDynamicPrimaryTemplateFacts(p.resolver);
        (bytes32 entries, bytes32 metadata, uint32 share, bytes32 beneficiaries) =
            provider.dynamicPrimaryTemplateFacts(p.collectionId, templateId);
        T.AssignmentFact memory fact = provider.previewArtistDynamicPrimaryTemplateAssignment(
            p.collectionId, templateId, 0, frozen
        );
        if (
            entries == 0 || beneficiaries == 0 || share == 0 || share > 1_000_000
                || fact.resolver != p.resolver || fact.revenueClass != p.revenueClass
                || p.scope != 1 || p.scopeId != p.collectionId || fact.scope != p.scope
                || fact.scopeId != p.scopeId || fact.assignmentHash != p.assignmentHash
                || fact.assignmentHash == 0
        ) revert T.InvalidRecord();
        // Poster is symbolic here. Only the later authenticated sale context selects its account.
        return abi.encode(domain, templateId, entries, metadata, share, beneficiaries, fact);
    }
}

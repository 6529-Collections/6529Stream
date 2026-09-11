// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryTemplateFacts.sol";

/// @dev Concrete template selection is never an alias for assignment identity or artist consent.
library StreamSaleTemplate {
    bytes32 private constant CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant POLICY = keccak256("6529STREAM_PRIMARY_POLICY_V1");

    struct Selection {
        bytes32 profileId;
        address wallet;
        bytes32 templateId;
        bytes32 assignmentHash;
        bytes32 entriesHash;
    }

    error UnsupportedSaleTemplate();
    error SaleTemplateMaterializationMismatch();
    error SaleTemplateAssignmentChanged();

    function preview(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory assignment
    ) internal view returns (Selection memory selected) {
        if (
            !assignment.exists || assignment.assignmentType != 2 || assignment.scope != 1
                || assignment.scopeId != collectionId || assignment.profileId != bytes32(0)
                || assignment.templateId == bytes32(0) || assignment.assignmentHash == bytes32(0)
                || assignment.policyHash != bytes32(0)
        ) revert UnsupportedSaleTemplate();
        // The actual provider validates the bounded artist-only template profile independently
        // of materialization and consent. Collaborator admission belongs to the artist facade.
        IStreamArtistPrimaryTemplateFacts(address(resolver))
            .primaryTemplateEconomicsFacts(assignment.templateId);
        selected.templateId = assignment.templateId;
        selected.assignmentHash = assignment.assignmentHash;
        (selected.profileId, selected.wallet, selected.entriesHash) =
            resolver.previewCollectionPrimaryProfile(
                assignment.templateId, collectionId, address(0)
            );
        if (
            selected.profileId == bytes32(0) || selected.wallet == address(0)
                || selected.entriesHash == bytes32(0)
        ) revert UnsupportedSaleTemplate();
    }

    function policyHash(IStreamRevenueResolver resolver, uint256 collectionId, Selection memory s)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                POLICY,
                block.chainid,
                address(resolver),
                CLASS,
                collectionId,
                uint256(0),
                s.templateId,
                s.profileId,
                s.wallet,
                s.assignmentHash
            )
        );
    }

    function materialize(IStreamRevenueResolver resolver, uint256 collectionId, Selection memory s)
        internal
    {
        if (s.templateId == bytes32(0)) return;
        requireCurrent(resolver, collectionId, s);
        (bytes32 profile, address wallet, bytes32 entries) = resolver.materializeCollectionPrimaryProfile(
            s.templateId, collectionId, address(0), false
        );
        if (profile != s.profileId || wallet != s.wallet || entries != s.entriesHash) {
            revert SaleTemplateMaterializationMismatch();
        }
    }

    /// @dev Keeps this execution's concrete payout moment; never reads another payout designation.
    function requireCurrent(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        Selection memory s
    ) internal view {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory current =
            resolver.resolvePrimaryAssignment(collectionId, 0, CLASS);
        if (
            !current.exists || current.scope != 1 || current.scopeId != collectionId
                || current.assignmentType != 2 || current.profileId != bytes32(0)
                || current.templateId != s.templateId || current.assignmentHash != s.assignmentHash
                || current.policyHash != bytes32(0)
        ) revert SaleTemplateAssignmentChanged();
    }
}

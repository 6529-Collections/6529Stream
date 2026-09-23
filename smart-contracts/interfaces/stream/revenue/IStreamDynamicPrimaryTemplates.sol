// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamRevenueResolver as R } from "./IStreamRevenueResolver.sol";

/// @notice Typed registration of immutable collaborator source identities.
interface IStreamDynamicPrimaryTemplates {
    struct CollaboratorReference {
        address account;
        bytes32 role;
        bytes32 shareLabelId;
    }
    function collaboratorAccountSource(CollaboratorReference calldata reference_)
        external
        pure
        returns (bytes32);
    function createDynamicPrimaryTemplate(
        R.PrimaryTemplateEntry[] calldata entries,
        bytes32 metadataURIHash,
        CollaboratorReference[] calldata references
    ) external returns (bytes32 templateId);
    function previewDynamicCollectionPrimaryProfile(
        bytes32 templateId,
        uint256 collectionId,
        address salePoster
    )
        external
        view
        returns (bytes32 profileId, address wallet, bytes32 entriesHash, bytes32 beneficiaryHash);
    function materializeDynamicCollectionPrimaryProfile(
        bytes32 templateId,
        uint256 collectionId,
        address salePoster,
        bool deployWallet
    )
        external
        returns (bytes32 profileId, address wallet, bytes32 entriesHash, bytes32 beneficiaryHash);
}

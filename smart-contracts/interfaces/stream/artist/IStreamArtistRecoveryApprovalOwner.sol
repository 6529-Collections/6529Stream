// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";
import { StreamArtistRecoveryTypes as Recovery } from "./StreamArtistRecoveryTypes.sol";
import {
    StreamArtistRecoveryApprovalTypes as Approval
} from "./StreamArtistRecoveryApprovalTypes.sol";

interface IStreamArtistRecoveryApprovalEvents {
    event ArtistRecoveryApprovalRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed recoveryManifestHash,
        address indexed signer,
        bytes32 finalityRecordHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 approvalRecordHash
    );
}

/// @notice Fixed Identity callback; its own operation guard and nonce replay remain authoritative.
interface IStreamArtistIdentityRecoveryApprovalOwner {
    function consumeRecoveryApproval(
        T.ActionContext calldata context,
        T.Binding calldata binding_,
        Recovery.ApprovalTerms calldata terms,
        T.Authorization calldata authorization,
        T.SignerApproval calldata approval
    ) external returns (bytes32 recordHash);
}

/// @notice Consent owns immutable records and exact-association lookups, never a global latest head.
interface IStreamArtistRecoveryApprovalOwner is IStreamArtistRecoveryApprovalEvents {
    function recordRecoveryApproval(
        T.ActionContext calldata context,
        T.Binding calldata binding_,
        Recovery.ApprovalRecord calldata record,
        R.AuthorityFact calldata authority,
        Approval.Admission calldata admission
    ) external returns (bytes32 recordHash);

    function recoveryApprovalRecord(bytes32 recordHash)
        external
        view
        returns (Recovery.ApprovalRecord memory, Approval.Admission memory);

    /// @notice Historical lookup only; does not establish current association or recovery eligibility.
    function recoveryApprovalForAssociation(
        bytes32 artistId,
        uint64 generation,
        bytes32 bindingHash,
        Recovery.ApprovalTerms calldata terms
    ) external view returns (bytes32 recordHash);
}

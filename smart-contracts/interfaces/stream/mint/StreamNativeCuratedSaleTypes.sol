// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeSettlementTypes } from "../revenue/StreamNativeSettlementTypes.sol";
import { StreamPreparedNativeContentTypes } from "./StreamPreparedNativeContentTypes.sol";

/// @notice Native selected-work sale records. Configuration and operational clocks are separate.
library StreamNativeCuratedSaleTypes {
    enum SelectionMode {
        COMMIT_REVEAL,
        PUBLIC
    }

    struct Configuration {
        uint256 collectionId;
        bytes32 phaseId;
        uint256 price;
        address poster;
        uint64 startsAt;
        uint64 endsAt;
        bytes32 mintPolicyHash;
        bytes32 expectedPrimaryPolicyHash;
        uint8 primaryPolicyMode;
        bytes32 contentManifestRoot;
    }

    struct SelectionWindows {
        uint64 commitOpen;
        uint64 commitClose;
        uint64 revealOpen;
        uint64 revealClose;
        uint64 absoluteEscape;
    }

    struct FixedConfiguration {
        Configuration sale;
        SelectionMode mode;
        bool differentiatedContent;
        bool publicSelectionDisclosure;
        SelectionWindows windows;
    }

    /// @dev The signer is an explicitly admitted member of the collection's sale-signer set.
    struct PrivateConfiguration {
        Configuration sale;
        address buyer;
        bytes32 contentId;
        bytes32 tokenDataHash;
        address signer;
        uint8 signerKind;
        bytes32 signerEvidenceHash;
        uint64 signerRevision;
        address signerAuthority;
    }

    struct CollectionSigner {
        bytes32 evidenceHash;
        uint64 revision;
        bool enabled;
        address authority;
    }

    struct SaleRecord {
        Configuration config;
        uint256 saleNonce;
        uint8 saleKind;
        bytes32 configHash;
        StreamNativeSettlementTypes.SaleLifecycleBinding lifecycle;
        bytes32 artistId;
        uint64 bindingGeneration;
        bytes32 bindingHash;
        address gate;
        bytes32 gateCodeHash;
        bytes32 gateConfigHash;
        bytes32 manifestHash;
        bytes32 contentCounterId;
        bytes32 contentCounterConfigHash;
        uint8 status; // 0 absent, 1 active, 2 cancelled, 3 expired, 4 private sale completed.
    }

    /// @dev Recipient is the economic beneficiary and final delivery address; Core initially
    /// mints to the adapter while the prepared payment callback executes.
    struct Selection {
        StreamPreparedNativeContentTypes.Selection content;
        bytes tokenData;
        bytes32 mintCommitment;
        address recipient;
        uint256 purchaseNonce;
    }

    struct ExecutionRecord {
        bytes32 saleId;
        address buyer;
        address recipient;
        uint256 purchaseNonce;
        bytes32 authorizationId;
        bytes32 authorizationDigest;
        bytes32 contentLeaf;
        bytes32 tokenDataHash;
        bytes32 mintCommitment;
        uint256 price;
        uint256 tokenId;
        bytes32 settlementKey;
        bytes32 operationRoot;
        bytes32 operationId;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Singleton paid prepared-mint facts, separate from the existing immediate/refund wires.
library StreamPreparedNativeSettlementTypes {
    /// @dev The admitted sale authenticates and locks this complete intent before entering Manager.
    ///      Token identity and operation identity do not exist yet and are not part of its preimage.
    struct Intent {
        uint256 collectionId;
        bytes32 phaseId;
        bytes32 saleId;
        uint256 saleNonce;
        address executor;
        address payer;
        address poster;
        address beneficiary;
        uint256 amount;
        uint8 primaryPolicyMode;
        bytes32 originalPrimaryPolicyHash;
        uint256 executionNonce;
        uint8 authorityMode;
        bytes32 saleAuthorizationDigest;
        bytes32 saleExecutionHash;
        bytes32 contentSelectionHash;
        bytes32 mintCommitment;
        bytes32 boundMintPolicyHash;
    }

    /// @dev These are Manager-derived facts of its one currently executing prepared operation.
    struct Facts {
        address saleAdapter;
        address mintManager;
        address recorder;
        bytes32 recorderCodeHash;
        uint256 collectionId;
        bytes32 phaseId;
        bytes32 intentHash;
        bytes32 operationRoot;
        bytes32 operationId;
        uint256 tokenId;
        uint256 collectionSerial;
        address payer;
        address initialRecipient;
        address beneficiary;
        bytes32 tokenDataHash;
        bytes32 mintCommitment;
        bytes32 currentPolicyHash;
        bytes32 boundPolicyHash;
    }
}

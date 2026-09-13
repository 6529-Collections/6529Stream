// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Permanent MPA-TICKET wire types; verification and execution are separate surfaces.
library StreamMintTicketTypes {
    struct MintTicket {
        uint256 chainId;
        address manager;
        address ledger;
        uint256 collectionId;
        bytes32 phaseId;
        address executor;
        address payer;
        address authorizer;
        uint8 authorizerKind;
        bytes32 initialRecipientsHash;
        bytes32 beneficiariesHash;
        bytes32 tokenDataArrayHash;
        bytes32 mintCommitmentsHash;
        uint256 quantity;
        bytes32 contextHash;
        bytes32 policyHash;
        bytes32 nonce;
        uint64 deadline;
    }
}

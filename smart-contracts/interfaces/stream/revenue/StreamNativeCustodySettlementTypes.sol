// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../auctions/IStreamNativeEnglishAuction.sol";

/// @notice Original unpaid acquisition and the later paid transfer are separate facts.
library StreamNativeCustodySettlementTypes {
    struct Origin {
        address manager;
        bytes32 managerCodeHash;
        bytes32 operationRoot;
        bytes32 operationId;
        bytes32 authorizationId;
        bytes32 tokenDataHash;
        uint256 tokenId;
        uint256 collectionSerial;
        uint256 operationNonce;
        address fundingAccount;
        uint256 revealFeeForwarded;
        bool eligible;
    }

    struct Facts {
        bytes32 auctionId;
        IStreamNativeEnglishAuction.Auction auction;
        Origin origin;
    }

    struct CanonicalHouse {
        address house;
        bytes32 codeHash;
        uint64 boundAt;
        uint64 revision;
        uint64 recorderBoundAt;
        uint64 recorderRevision;
    }
}

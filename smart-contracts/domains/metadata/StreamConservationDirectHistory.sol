// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/StreamDirectPrimaryConservationTypes.sol";

/// @notice Fixed linked storage and reconstruction worker for complete DIRECT floor history.
/// @dev Runs in the ledger's storage context. It does not authenticate a sale or read a former
/// adapter, Manager or provider; the ledger supplies authenticated evidence and immutable links.
library StreamConservationDirectHistory {
    // Member order and types preserve the original ledger's DirectPreparation storage layout.
    struct Preparation {
        bool exists;
        StreamDirectPrimaryConservationTypes.Receipt seed;
        bytes32 collectionEvidence;
        bytes32 releaseEvidence;
    }

    function persist(
        mapping(bytes32 => Preparation) storage preparations,
        Preparation memory p,
        uint256 chainId,
        address core
    ) public returns (bytes32 key) {
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_DIRECT_PREPARED_V1"),
                chainId,
                core,
                address(this),
                p
            )
        );
        preparations[key] = p;
    }

    function receipt(
        Preparation storage p,
        uint64 recordedAt,
        bytes32 firstReceiptHash,
        bytes32 releaseReceiptHash,
        uint256 chainId,
        address core
    ) public view returns (StreamDirectPrimaryConservationTypes.Receipt memory r) {
        r = p.seed;
        r.recordedAt = recordedAt;
        r.firstSaleReceiptHash = firstReceiptHash;
        r.releaseReceiptHash = releaseReceiptHash;
        r.receiptHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1"),
                chainId,
                core,
                address(this),
                r
            )
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Sale terms use the adapter's actual stored identity and complete configuration hash.
library StreamArtistSaleTypes {
    struct Consent {
        uint256 collectionId;
        address saleAdapter;
        bytes32 saleId;
        bytes32 saleConfigHash;
    }

    /// @notice Permanent record plus generation applicability; the latter is outside its frozen preimage.
    struct Record {
        bytes32 recordHash;
        Consent terms;
        bytes32 artistId;
        address signer;
        uint8 authorityClass;
        uint256 nonce;
        uint64 signedAt;
        uint64 bindingGeneration;
        bytes32 bindingHash;
    }

    error SaleConsentUnavailable(uint256 collectionId, bytes32 saleId, bytes32 saleConfigHash);
    error InvalidSaleAdapter(address adapter);
    error SaleFactsReadFailed(address target, bytes4 selector);
    error SaleFactsParentGas(uint256 available, uint256 required);
}

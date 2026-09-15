// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamNativeRefundDelegatedClaims as R
} from "../../interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";
import { StreamNativeAuctionDelegation as D } from "../auctions/StreamNativeAuctionDelegation.sol";

/// @notice Fixed view-only encoder; its host supplies immutable context and returns complete ABI bytes.
library StreamNativeRefundReadEncoding {
    function read(D.Configuration memory c, bytes4 selector) public view returns (bytes memory) {
        if (selector == R.refundDelegationConfiguration.selector) return abi.encode(c);
        if (c.delegateRegistry == address(0)) revert D.DelegationConfigurationInvalid();
        bytes memory manifest = D.manifestBytes(c);
        if (selector == R.refundDelegationManifest.selector) return abi.encode(manifest);
        if (selector == R.refundDelegationManifestHash.selector) {
            return abi.encode(keccak256(manifest));
        }
        revert D.DelegationConfigurationInvalid();
    }

    function domain(uint8 kind) public view returns (bytes memory) {
        return abi.encode(
            bytes1(0x0f),
            kind == 0
                ? "6529StreamNativeFixedPriceSaleAdapter"
                : kind == 1 ? "6529StreamNativePricePrograms" : "6529StreamNativeRefundWindowSale",
            "1",
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }
}

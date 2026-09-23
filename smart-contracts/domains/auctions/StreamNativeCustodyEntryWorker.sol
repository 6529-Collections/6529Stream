// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamTokenProfileCustodyActivation.sol";
import "./StreamCustodyRightsActivation.sol";
import "./StreamPlatformTokenCustodyActivation.sol";
import "./StreamTokenProfileCustodySettlement.sol";
import "./StreamCustodyRightsSettlement.sol";
import "./StreamPlatformTokenCustodySettlement.sol";
import "./StreamNativeEnglishAuctionRegistration.sol";

/// @notice Fixed selector forwarding preserves original host/caller/value and storage roots.
library StreamNativeCustodyEntryWorker {
    function execute(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamTokenProfileCustodyState.State storage tokenProfile,
        StreamCustodyRightsState.State storage rights,
        StreamPlatformTokenCustodyState.State storage platformToken,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes calldata data
    ) public returns (bytes memory) {
        bytes4 selector = bytes4(data[:4]);
        if (selector == IStreamTokenProfileCustodyAuction.activateTokenProfileCustody.selector) {
            (
                StreamTokenProfileCustodyTypes.Authorization memory authorization,
                bytes memory platformSignature,
                bytes memory artistSignature
            ) = abi.decode(data[4:], (StreamTokenProfileCustodyTypes.Authorization, bytes, bytes));

            StreamPlatformTokenCustodyHash.requireLegacy(address(this), authorization.auctionId);
            StreamCustodyRightsHash.requireLegacy(address(this), authorization.auctionId);
            StreamTokenProfileCustodyActivation.activate(
                s, custody, tokenProfile, x, authorization, platformSignature, artistSignature
            );

            return bytes("");
        }
        if (selector == IStreamTokenProfileCustodyAuction.bidTokenProfileCustody.selector) {
            (bytes32 id, address deliverTo) = abi.decode(data[4:], (bytes32, address));

            bytes32 effective = tokenProfileEntry(tokenProfile, id);
            StreamNativeEnglishAuctionRegistration.bidPublicForConfiguration(
                s,
                x,
                0,
                id,
                deliverTo,
                StreamNativeAuctionDelegation.Witness(false, 0),
                false,
                effective,
                true
            );

            return bytes("");
        }
        if (selector == IStreamTokenProfileCustodyAuction.bidSignedTokenProfileCustody.selector) {
            (
                IStreamNativeEnglishAuction.BidAuthorization memory authorization,
                bytes memory signature
            ) = abi.decode(data[4:], (IStreamNativeEnglishAuction.BidAuthorization, bytes));

            bytes32 effective = tokenProfileEntry(tokenProfile, authorization.auctionId);
            StreamNativeEnglishAuctionRegistration.bidSignedForConfiguration(
                s,
                x,
                0,
                authorization,
                signature,
                StreamNativeAuctionDelegation.Witness(false, 0),
                false,
                effective,
                true
            );

            return bytes("");
        }
        if (selector == IStreamTokenProfileCustodyAuction.settleTokenProfileCustody.selector) {
            bytes32 id = abi.decode(data[4:], (bytes32));

            tokenProfileEntry(tokenProfile, id);
            (uint256 token, bytes32 key) =
                StreamTokenProfileCustodySettlement.settle(s, custody, x, id);

            return abi.encode(token, key);
        }
        if (selector == IStreamCustodyRightsAuction.activateCustodyRights.selector) {
            (
                StreamCustodyRightsTypes.Authorization memory authorization,
                bytes memory platformSignature,
                bytes memory artistSignature
            ) = abi.decode(data[4:], (StreamCustodyRightsTypes.Authorization, bytes, bytes));

            StreamPlatformTokenCustodyHash.requireLegacy(address(this), authorization.auctionId);
            StreamCustodyRightsActivation.activate(
                s, custody, rights, x, authorization, platformSignature, artistSignature
            );

            return bytes("");
        }
        if (selector == IStreamCustodyRightsAuction.bidCustodyRights.selector) {
            (bytes32 id, address deliverTo) = abi.decode(data[4:], (bytes32, address));

            bytes32 effective = rightsEntry(rights, id);
            StreamNativeEnglishAuctionRegistration.bidPublicForConfiguration(
                s,
                x,
                0,
                id,
                deliverTo,
                StreamNativeAuctionDelegation.Witness(false, 0),
                false,
                effective,
                true
            );

            return bytes("");
        }
        if (selector == IStreamCustodyRightsAuction.bidSignedCustodyRights.selector) {
            (
                IStreamNativeEnglishAuction.BidAuthorization memory authorization,
                bytes memory signature
            ) = abi.decode(data[4:], (IStreamNativeEnglishAuction.BidAuthorization, bytes));

            bytes32 effective = rightsEntry(rights, authorization.auctionId);
            StreamNativeEnglishAuctionRegistration.bidSignedForConfiguration(
                s,
                x,
                0,
                authorization,
                signature,
                StreamNativeAuctionDelegation.Witness(false, 0),
                false,
                effective,
                true
            );

            return bytes("");
        }
        if (selector == IStreamCustodyRightsAuction.settleCustodyRights.selector) {
            bytes32 id = abi.decode(data[4:], (bytes32));

            rightsEntry(rights, id);
            (uint256 token, bytes32 key) = StreamCustodyRightsSettlement.settle(s, custody, x, id);

            return abi.encode(token, key);
        }
        if (selector == IStreamPlatformTokenCustodyAuction.activatePlatformTokenCustody.selector) {
            StreamPlatformTokenCustodyActivation.fromCalldata(s, custody, platformToken, x, data);

            return bytes("");
        }
        if (selector == IStreamPlatformTokenCustodyAuction.bidPlatformTokenCustody.selector) {
            (bytes32 id, address deliverTo) = abi.decode(data[4:], (bytes32, address));

            (uint8 mode, bytes32 effective) =
                StreamPlatformTokenCustodyActivation.effective(platformToken, id);
            StreamNativeEnglishAuctionRegistration.bidPublicForConfiguration(
                s,
                x,
                mode,
                id,
                deliverTo,
                StreamNativeAuctionDelegation.Witness(false, 0),
                false,
                effective,
                false
            );

            return bytes("");
        }
        if (selector == IStreamPlatformTokenCustodyAuction.bidSignedPlatformTokenCustody.selector) {
            (
                IStreamNativeEnglishAuction.BidAuthorization memory authorization,
                bytes memory signature
            ) = abi.decode(data[4:], (IStreamNativeEnglishAuction.BidAuthorization, bytes));

            (uint8 mode, bytes32 effective) = StreamPlatformTokenCustodyActivation.effective(
                platformToken, authorization.auctionId
            );
            StreamNativeEnglishAuctionRegistration.bidSignedForConfiguration(
                s,
                x,
                mode,
                authorization,
                signature,
                StreamNativeAuctionDelegation.Witness(false, 0),
                false,
                effective,
                false
            );

            return bytes("");
        }
        if (selector == IStreamPlatformTokenCustodyAuction.settlePlatformTokenCustody.selector) {
            bytes32 id = abi.decode(data[4:], (bytes32));

            StreamPlatformTokenCustodyActivation.effective(platformToken, id);
            (uint256 token, bytes32 key) =
                StreamPlatformTokenCustodySettlement.settle(s, custody, x, id);

            return abi.encode(token, key);
        }
        revert IStreamNativeEnglishAuction.InvalidNativeAuction();
    }

    function tokenProfileEntry(StreamTokenProfileCustodyState.State storage s, bytes32 id)
        private
        view
        returns (bytes32)
    {
        if (s.activations[id].authorizationDigest == 0) {
            revert IStreamTokenProfileCustodyAuction.InvalidTokenProfileCustody();
        }
        return s.activations[id].effectiveConfigHash;
    }

    function rightsEntry(StreamCustodyRightsState.State storage s, bytes32 id)
        private
        view
        returns (bytes32)
    {
        if (s.activations[id].authorizationDigest == 0) {
            revert IStreamCustodyRightsAuction.InvalidCustodyRights();
        }
        return s.activations[id].effectiveConfigHash;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeEnglishAuctionRuntime.sol";
import {
    StreamNativeEnglishAuctionCustodyRegistration
} from "./StreamNativeEnglishAuctionCustodyRegistration.sol";
import "./StreamNativeEnglishAuctionCustodyState.sol";
import "../../interfaces/stream/revenue/IStreamNativeCustodyPrimarySettlement.sol";
import "../../vendor/openzeppelin/IERC721Receiver.sol";
import {
    IStreamPreparedNativeCustodyAuction
} from "../../interfaces/stream/auctions/IStreamPreparedNativeCustodyAuction.sol";

/// @notice Unpaid singleton acquisition in the actual house; paid transfer happens later.
library StreamNativeEnglishAuctionCustodyStart {
    error AuctionBidOverflow();
    error AuctionClockConfigurationInvalid();
    error AuctionIncrementInvalid();
    error InvalidNativeAuction();
    error InvalidSettlementContext(address target);
    error NativeAuctionAccountingMismatch();
    error NativeAuctionDeliveryGas(uint256 available, uint256 required);
    error RefundClockOverflow();
    error SettlementBindingInvalid(address target);

    event NativeAuctionCreated(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        IStreamNativeEnglishAuction.Configuration config,
        bytes32 creationDigest
    );
    event NativeAuctionCustodyAcquired(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        IStreamNativeCustodyAuction.Acquisition authorization,
        StreamNativeCustodySettlementTypes.Origin origin
    );
    event NativeAuctionPreparedCustodyBound(
        uint16 schemaVersion,
        bytes32 indexed auctionId,
        uint256 indexed tokenId,
        bytes32 indexed operationRoot,
        bytes32 operationId,
        bytes32 authorizationDigest
    );

    function digest(IStreamNativeCustodyAuction.Acquisition memory a)
        public
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeCustodyAuction"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        return keccak256(
            abi.encodePacked(
                hex"1901",
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "NativeCustodyAcquisition(bytes32 configHash,bytes32 tokenDataHash,uint256 expectedSaleNonce,uint256 expectedTokenId,uint256 expectedCollectionSerial,uint256 expectedOperationNonce,bytes32 contextHash,address executor,uint256 revealFeeDeposit,address artist,bytes32 nonce,uint64 deadline)"
                        ),
                        a
                    )
                )
            )
        );
    }

    function preparedDigest(IStreamNativeCustodyAuction.Acquisition memory a)
        public
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamPreparedNativeCustodyAuction"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        return keccak256(
            abi.encodePacked(
                hex"1901",
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "PreparedNativeCustodyAcquisition(bytes32 configHash,bytes32 tokenDataHash,uint256 expectedSaleNonce,uint256 expectedTokenId,uint256 expectedCollectionSerial,uint256 expectedOperationNonce,bytes32 contextHash,address executor,uint256 revealFeeDeposit,address artist,bytes32 nonce,uint64 deadline)"
                        ),
                        a
                    )
                )
            )
        );
    }

    function registerAuction(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        IStreamNativeEnglishAuction.Configuration calldata c,
        IStreamNativeCustodyAuction.Acquisition calldata auth,
        bytes calldata artwork,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) public returns (bytes32 id) {
        return StreamNativeEnglishAuctionCustodyRegistration.registerAuction(
                s, custody, x, c, auth, artwork, platformSignature, artistSignature, false
            );
    }

    function registerPreparedAuction(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        IStreamNativeEnglishAuction.Configuration calldata c,
        IStreamNativeCustodyAuction.Acquisition calldata auth,
        bytes calldata artwork,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) public returns (bytes32 id) {
        return StreamNativeEnglishAuctionCustodyRegistration.registerAuction(
                s, custody, x, c, auth, artwork, platformSignature, artistSignature, true
            );
    }

    function onReceived(
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        address operator,
        address from,
        uint256 token
    ) public returns (bytes4) {
        if (
            custody.acquiring == 0 || custody.received || msg.sender != x.base.core
                || operator != address(x.base.manager) || from != address(0)
                || token != custody.expectedToken
        ) revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        custody.received = true;
        return IERC721Receiver.onERC721Received.selector;
    }

    function requireToken(
        address core,
        IStreamNativeEnglishAuction.Auction memory a,
        StreamNativeCustodySettlementTypes.Origin memory o
    ) public view {
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            IStreamCore(core).tokenCollectionIdentity(o.tokenId);
        if (
            !exists || burned || !o.eligible || o.tokenId == 0 || a.tokenId != o.tokenId
                || a.config.tokenId != o.tokenId || collection != a.config.collectionId
                || serial != o.collectionSerial
                || IStreamCore(core).ownerOf(o.tokenId) != address(this)
                || IStreamCore(core).tokenLifecycle(o.tokenId) != 2
                || keccak256(IStreamCore(core).tokenData(o.tokenId)) != o.tokenDataHash
        ) {
            revert IStreamNativeCustodyAuction.NativeCustodyOriginUnavailable(a.saleId);
        }
    }
}

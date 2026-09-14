// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeEnglishAuctionRuntime.sol";
import {
    IStreamNativeEnglishAuction as A
} from "../../interfaces/stream/auctions/IStreamNativeEnglishAuction.sol";
import "../../vendor/openzeppelin/IERC721Receiver.sol";

/// @notice Original prepared payment, completion, callback and delivery in the fixed house context.
library StreamNativeEnglishAuctionSettlement {
    event NativeAuctionNoBids(
        bytes32 indexed auctionId, bytes32 indexed saleId, bytes32 reasonHash
    );
    event NativeAuctionSettled(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        bytes32 settlementKey,
        uint256 amount,
        uint256 revealFeeForwarded,
        uint256 revealFeeRefunded
    );
    event NativeAuctionNFTDelivered(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        address recipient
    );
    event NativeAuctionNFTClaimPending(
        bytes32 indexed auctionId, bytes32 indexed saleId, uint256 indexed tokenId, address claimant
    );

    function settle(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionRuntime.Active storage active,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes32 id
    ) public returns (uint256 tokenId, bytes32 settlementKey) {
        A.Auction storage a = StreamNativeEnglishAuctionState.requireAuction(s, id);
        if (a.status == 3) return (a.tokenId, a.settlementKey);
        if (a.status == 5 || a.status == 6) return (0, 0);
        if (a.status != 1) revert A.NativeAuctionTerminal(id);
        if (StreamNativeEnglishAuctionState.paused(s, a.saleId)) revert A.NativeAuctionPaused();
        (uint64 end, uint64 deadline,,) = StreamNativeEnglishAuctionState.deadlines(s, id);
        if (end == 0 || block.timestamp < end) revert A.NativeAuctionUnavailable(id);
        if (a.winner.amount == 0) {
            (,,, a.terminalToll) = StreamNativeEnglishAuctionState.deadlines(s, id);
            a.status = 5;
            emit NativeAuctionNoBids(id, a.saleId, keccak256("NO_BIDS"));
            return (0, 0);
        }
        if (StreamEnglishAuctionClock.expired(deadline, StreamRefundClock.now64())) {
            revert A.NativeAuctionTerminal(id);
        }
        StreamNativeEnglishAuctionRuntime.requireNativeContext(x);
        StreamNativeEnglishAuctionRuntime.requireRetained(x, a);
        StreamNativeEnglishAuctionSupport.requirePhase(
            StreamNativeEnglishAuctionRuntime.support(x), a.config, true
        );
        StreamRefundWindowSupport.preflightReveal(
            StreamNativeEnglishAuctionRuntime.support(x),
            a.config.collectionId,
            StreamNativeEnglishAuctionRuntime.gasParameter(
                StreamNativeEnglishAuctionRuntime.REVEAL_GAS
            )
        );
        StreamNativeEnglishAuctionRuntime.admitDelivery(
            StreamNativeEnglishAuctionRuntime.gasParameter(
                StreamNativeEnglishAuctionRuntime.DELIVERY_GAS
            )
        );
        StreamPreparedNativeSettlementTypes.Intent memory i =
            StreamNativeEnglishAuctionSupport.intent(a);
        (IStreamMintManager.MintBatch memory batch, bytes32 hash) = StreamNativeEnglishAuctionSupport.batch(
            address(x.base.manager), x.recorder, i, s.artwork[id]
        );
        uint256 beforeBalance = address(this).balance;
        StreamNativeEnglishAuctionState.beginSettlement(s, id);
        active.auction = id;
        active.intentHash = hash;
        active.intent = i;
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result;
        bytes32 root;
        bytes32 operation;
        (tokenId, root, operation, result) = IStreamPreparedNativeMint(address(x.base.manager))
            .executePreparedNativeMint(batch, "", hash);
        if (
            !active.callbackConsumed || tokenId != active.token || tokenId == 0 || root == 0
                || operation == 0 || result.settlementKey == 0 || result.amount != a.winner.amount
                || IStreamCore(x.base.core).ownerOf(tokenId) != address(this)
                || IStreamCore(x.base.core).tokenLifecycle(tokenId) != 2
                || IStreamCore(x.base.core).pendingPreparedMintTokenId() != 0
        ) revert A.NativeAuctionAccountingMismatch();
        StreamNativeEnglishAuctionRuntime.requireNativeContext(x);
        StreamNativeEnglishAuctionRuntime.requireRetained(x, a);
        (uint256 forwarded, uint256 remainder) = StreamRefundWindowSupport.fundRevealAndAttempt(
            StreamNativeEnglishAuctionRuntime.support(x),
            a.config.collectionId,
            tokenId,
            a.winner.revealFee,
            StreamNativeEnglishAuctionRuntime.gasParameter(
                StreamNativeEnglishAuctionRuntime.REVEAL_GAS
            )
        );
        if (address(this).balance != beforeBalance - a.winner.amount - forwarded) {
            revert A.NativeAuctionAccountingMismatch();
        }
        settlementKey = result.settlementKey;
        StreamNativeEnglishAuctionState.finishSettlement(s, id, tokenId, settlementKey, remainder);
        delete active.auction;
        delete active.intentHash;
        delete active.intent;
        delete active.token;
        delete active.callbackConsumed;
        emit NativeAuctionSettled(
            id, a.saleId, tokenId, settlementKey, a.winner.amount, forwarded, remainder
        );
        deliver(x, id, a, a.winner.deliverTo, false);
    }

    function onPreparedNativeMint(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionRuntime.Active storage active,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        StreamPreparedNativeSettlementTypes.Facts calldata facts
    ) public returns (bytes4, StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        if (
            msg.sender != address(x.base.manager) || active.auction == 0 || active.intentHash == 0
                || facts.intentHash != active.intentHash || active.callbackConsumed
        ) revert A.InvalidNativeAuction();
        A.Auction storage a = s.auctions[active.auction];
        if (
            a.status != 2
                || keccak256(abi.encode(StreamNativeEnglishAuctionSupport.intent(a)))
                    != keccak256(abi.encode(active.intent))
        ) revert A.InvalidNativeAuction();
        StreamPreparedNativeSettlementValidation.requireActive(
            x.base.core, x.registry, facts, active.intent
        );
        StreamNativeEnglishAuctionRuntime.requireRetained(x, a);
        active.callbackConsumed = true;
        active.token = facts.tokenId;
        result = IStreamPreparedNativePrimarySaleSettlement(x.recorder)
        .settlePreparedNativePrimarySale{ value: a.winner.amount }(
            facts, active.intent
        );
        return (IStreamPreparedNativeSaleBinding.onPreparedNativeMint.selector, result);
    }

    function onERC721Received(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionRuntime.Active storage active,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        address operator,
        address from,
        uint256 tokenId
    ) public view returns (bytes4) {
        if (
            msg.sender != x.base.core || operator != address(x.base.manager) || from != address(0)
                || !active.callbackConsumed || tokenId != active.token || active.auction == 0
                || s.auctions[active.auction].status != 2
        ) revert A.InvalidNativeAuction();
        return IERC721Receiver.onERC721Received.selector;
    }

    function deliver(
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes32 id,
        A.Auction storage a,
        address to,
        bool claim
    ) public {
        uint256 cap = StreamNativeEnglishAuctionRuntime.gasParameter(
            StreamNativeEnglishAuctionRuntime.DELIVERY_GAS
        );
        StreamNativeEnglishAuctionRuntime.admitDelivery(cap);
        a.nftClaimant = address(0);
        address target = x.base.core;
        bytes memory data = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)", address(this), to, a.tokenId
        );
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(cap, target, 0, add(data, 32), mload(data), 0, 0)
            size := returndatasize()
        }
        // The fixed Core's successful void transfer is delivery. A recipient may transfer
        // or burn its received NFT inside the callback; that cannot undo official settlement.
        if (ok && size == 0) {
            emit NativeAuctionNFTDelivered(id, a.saleId, a.tokenId, to);
            return;
        }
        if (claim || IStreamCore(x.base.core).ownerOf(a.tokenId) != address(this)) {
            revert A.NativeAuctionAccountingMismatch();
        }
        a.nftClaimant = a.winner.deliverTo;
        emit NativeAuctionNFTClaimPending(id, a.saleId, a.tokenId, a.nftClaimant);
    }
}

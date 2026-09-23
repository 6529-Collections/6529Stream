// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeEnglishAuctionRuntime.sol";
import "./StreamNativeEnglishAuctionSettlement.sol";
import "../revenue/StreamPreparedNativeRightsValidation.sol";
import {
    IStreamNativeEnglishAuction as A
} from "../../interfaces/stream/auctions/IStreamNativeEnglishAuction.sol";
import "../../vendor/openzeppelin/IERC721Receiver.sol";

/// @notice Original prepared payment, completion, callback and delivery in the fixed house context.
library StreamNativeEnglishAuctionRightsSettlement {
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
        mapping(bytes32 => StreamPreparedNativeRightsTypes.OriginalPolicy) storage policies,
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
        StreamPreparedNativeRightsTypes.Intent memory original =
            StreamPreparedNativeRightsTypes.Intent(i, policies[id]);
        bytes32 hash = StreamPreparedNativeRightsHash.intentHash(
            address(this), x.recorder, original
        );
        (IStreamMintManager.MintBatch memory batch,) = StreamNativeEnglishAuctionSupport.batch(
            address(x.base.manager), x.recorder, i, s.artwork[id]
        );
        batch.authorizationId = hash;
        batch.contextHash =
            StreamPreparedNativeRightsHash.mintContext(address(x.base.manager), address(this), hash);
        uint256 beforeBalance = address(this).balance;
        StreamNativeEnglishAuctionState.beginSettlement(s, id);
        active.auction = id;
        active.intentHash = hash;
        active.intent = i;
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result;
        bytes32 root;
        bytes32 operation;
        (tokenId, root, operation, result) = IStreamPreparedNativeRightsMint(
                address(x.base.manager)
            ).executePreparedNativeRightsMint(batch, "", hash);
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
        StreamNativeEnglishAuctionSettlement.deliver(x, id, a, a.winner.deliverTo, false);
    }

    function onPreparedNativeRightsMint(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionRuntime.Active storage active,
        mapping(bytes32 => StreamPreparedNativeRightsTypes.OriginalPolicy) storage policies,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        StreamPreparedNativeRightsTypes.Facts calldata facts
    ) public returns (bytes4, StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        if (
            msg.sender != address(x.base.manager) || active.auction == 0 || active.intentHash == 0
                || facts.mint.intentHash != active.intentHash || active.callbackConsumed
        ) revert A.InvalidNativeAuction();
        A.Auction storage a = s.auctions[active.auction];
        if (
            a.status != 2
                || keccak256(abi.encode(StreamNativeEnglishAuctionSupport.intent(a)))
                    != keccak256(abi.encode(active.intent))
        ) revert A.InvalidNativeAuction();
        StreamPreparedNativeRightsTypes.Intent memory original =
            StreamPreparedNativeRightsTypes.Intent(active.intent, policies[active.auction]);
        StreamPreparedNativeRightsValidation.requireActive(x.base.core, x.registry, facts, original);
        StreamNativeEnglishAuctionRuntime.requireRetained(x, a);
        active.callbackConsumed = true;
        active.token = facts.mint.tokenId;
        result = IStreamPreparedNativeRightsPrimarySettlement(x.recorder)
        .settlePreparedNativeRightsSale{ value: a.winner.amount }(
            facts, original
        );
        return (IStreamPreparedNativeRightsSaleBinding.onPreparedNativeRightsMint.selector, result);
    }
}

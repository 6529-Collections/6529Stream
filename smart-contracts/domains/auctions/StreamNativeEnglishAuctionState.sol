// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/auctions/IStreamNativeEnglishAuction.sol";
import "../mint/StreamRefundClock.sol";
import "./StreamNativeEnglishAuctionPause.sol";

/// @notice Auction-local escrow and clocks. The host authenticates every entry and owns its guard.
library StreamNativeEnglishAuctionState {
    struct State {
        StreamRefundClock.GlobalClock globalPause;
        StreamNativeEnglishAuctionPause.History pauseHistory;
        mapping(bytes32 => StreamRefundClock.SaleClock) salePause;
        mapping(bytes32 => IStreamNativeEnglishAuction.Auction) auctions;
        mapping(bytes32 => bytes32) auctionBySale;
        mapping(bytes32 => bytes) artwork;
        mapping(bytes32 => mapping(address => address)) delivery;
        mapping(bytes32 => mapping(address => uint256)) credits;
        mapping(address => mapping(bytes32 => bool)) creationUsed;
        mapping(address => mapping(bytes32 => bool)) bidUsed;
        uint256 nextNonce;
        uint256 liabilities;
        uint256 liveDeposits;
    }

    event AuctionExtended(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint64 previousEndTime,
        uint64 endTime,
        uint32 totalExtensionUsed
    );
    event AuctionExtensionBudgetWarning(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint32 usedSeconds,
        uint32 remainingSeconds
    );
    event AuctionBidDeliveryBound(
        bytes32 indexed auctionId, bytes32 indexed saleId, address indexed bidder, address deliverTo
    );
    event NativeAuctionBid(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        address indexed payer,
        IStreamNativeEnglishAuction.WinningBid bid
    );
    event NativeAuctionRefundCredit(
        bytes32 indexed auctionId, bytes32 indexed saleId, address indexed payer, uint256 amount
    );
    event NativeAuctionRefundClaimed(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        address indexed payer,
        address recipient,
        uint256 amount
    );
    event NativeAuctionNoMint(
        bytes32 indexed auctionId, bytes32 indexed saleId, bytes32 reasonHash, uint256 refundAmount
    );
    event NativeAuctionPause(
        bytes32 indexed saleId,
        bool global,
        bool paused,
        address indexed actor,
        bytes32 reasonHash,
        uint64 totalPause
    );

    function requireAuction(State storage s, bytes32 id)
        internal
        view
        returns (IStreamNativeEnglishAuction.Auction storage a)
    {
        a = s.auctions[id];
        if (a.status == 0) revert IStreamNativeEnglishAuction.NativeAuctionUnavailable(id);
    }

    function paused(State storage s, bytes32 saleId) internal view returns (bool) {
        return s.globalPause.paused || s.salePause[saleId].paused;
    }

    function deadlines(State storage s, bytes32 id)
        public
        view
        returns (uint64 end, uint64 deadline, uint64 ceiling, uint64 toll)
    {
        IStreamNativeEnglishAuction.Auction storage a = requireAuction(s, id);
        uint64 total = StreamRefundClock.unionTotal(s.globalPause, s.salePause[a.saleId]);
        uint64 anchor = a.config.clock.startTime > a.lifecycle.saleCreatedAt
            ? a.config.clock.startTime
            : a.lifecycle.saleCreatedAt;
        if (a.status >= 3) {
            toll = a.terminalToll;
        } else if (a.config.clock.startOnFirstBid) {
            if (total < a.pauseBaseline) {
                revert IStreamNativeEnglishAuction.NativeAuctionAccountingMismatch();
            }
            toll = a.clock.nominalEnd == 0 ? 0 : total - a.pauseBaseline;
        } else if (block.timestamp >= anchor) {
            toll = total - StreamNativeEnglishAuctionPause.unionAt(s.pauseHistory, a.saleId, anchor);
        }
        end = StreamEnglishAuctionClock.effectiveEnd(a.clock, toll);
        ceiling = a.winner.signedFinalizeBy;
        deadline = StreamEnglishAuctionClock.effectiveFinalizeBy(
            a.clock, a.config.settlementWindow, toll, ceiling
        );
    }

    function placeBid(
        State storage s,
        bytes32 id,
        IStreamNativeEnglishAuction.WinningBid memory bid
    ) public {
        IStreamNativeEnglishAuction.Auction storage a = requireAuction(s, id);
        if (a.status != 1) revert IStreamNativeEnglishAuction.NativeAuctionTerminal(id);
        if (paused(s, a.saleId)) revert IStreamNativeEnglishAuction.NativeAuctionPaused();
        (, uint64 deadline,, uint64 toll) = deadlines(s, id);
        uint64 now_ = StreamRefundClock.now64();
        if (a.winner.amount != 0 && StreamEnglishAuctionClock.expired(deadline, now_)) {
            revert IStreamNativeEnglishAuction.NativeAuctionTerminal(id);
        }
        if (a.clock.nominalEnd == 0) {
            // No active window existed before the first accepted bid. Its pause baseline starts now.
            a.pauseBaseline = StreamRefundClock.unionTotal(s.globalPause, s.salePause[a.saleId]);
            toll = 0;
        }
        StreamEnglishAuctionClock.Transition memory transition;
        (a.clock, transition) = StreamEnglishAuctionClock.acceptBid(
            a.config.clock,
            a.clock,
            StreamEnglishAuctionClock.Bid(
                bid.amount,
                a.winner.amount,
                a.config.reservePrice,
                a.config.minIncrementBps,
                a.config.incrementFloorWaived
            ),
            now_,
            toll
        );
        uint64 nextDeadline = StreamEnglishAuctionClock.effectiveFinalizeBy(
            a.clock, a.config.settlementWindow, toll, 0
        );
        // Signed bids authorize exactly the published current envelope at their admission.
        if (
            bid.signed
                && (bid.signedFinalizeBy != nextDeadline
                    || bid.signedFinalizeBy <= transition.effectiveEnd)
        ) revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        if (!bid.signed && bid.signedFinalizeBy != 0) {
            revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        }
        address previousDelivery = s.delivery[id][bid.payer];
        if (previousDelivery == address(0)) {
            s.delivery[id][bid.payer] = bid.deliverTo;
            emit AuctionBidDeliveryBound(id, a.saleId, bid.payer, bid.deliverTo);
        } else if (previousDelivery != bid.deliverTo) {
            revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        }
        if (a.winner.amount != 0) {
            uint256 previous = a.winner.amount + a.winner.revealFee;
            s.liveDeposits -= previous;
            credit(s, id, a, a.winner.payer, previous);
        }
        bid.bidIndex = a.winner.bidIndex + 1;
        a.winner = bid;
        uint256 added = bid.amount + bid.revealFee;
        s.liveDeposits += added;
        s.liabilities += added;
        if (transition.extended) {
            emit AuctionExtended(
                id,
                a.saleId,
                transition.previousEnd,
                transition.effectiveEnd,
                transition.usedExtension
            );
        }
        if (transition.budgetWarning) {
            emit AuctionExtensionBudgetWarning(
                id, a.saleId, transition.usedExtension, transition.remainingExtension
            );
        }
        emit NativeAuctionBid(id, a.saleId, bid.payer, bid);
        solvent(s);
    }

    /// @dev Converts an existing deposit; it does not add another total liability.
    function credit(
        State storage s,
        bytes32 id,
        IStreamNativeEnglishAuction.Auction storage a,
        address payer,
        uint256 amount
    ) internal {
        if (amount == 0) return;
        s.credits[a.saleId][payer] += amount;
        emit NativeAuctionRefundCredit(id, a.saleId, payer, amount);
    }

    function noMint(State storage s, bytes32 id, bytes32 reason) public {
        IStreamNativeEnglishAuction.Auction storage a = requireAuction(s, id);
        if (a.status == 6) return;
        if (a.status != 1 || a.winner.amount == 0 || reason == 0) {
            revert IStreamNativeEnglishAuction.NativeAuctionTerminal(id);
        }
        (,,, a.terminalToll) = deadlines(s, id);
        a.status = 6;
        uint256 amount = a.winner.amount + a.winner.revealFee;
        s.liveDeposits -= amount;
        credit(s, id, a, a.winner.payer, amount);
        emit NativeAuctionNoMint(id, a.saleId, reason, amount);
        solvent(s);
    }

    function beginSettlement(State storage s, bytes32 id) public {
        IStreamNativeEnglishAuction.Auction storage a = requireAuction(s, id);
        if (a.status != 1 || a.winner.amount == 0) {
            revert IStreamNativeEnglishAuction.NativeAuctionTerminal(id);
        }
        a.status = 2;
        uint256 deposit = a.winner.amount + a.winner.revealFee;
        s.liveDeposits -= deposit;
        s.liabilities -= deposit;
    }

    function finishSettlement(
        State storage s,
        bytes32 id,
        uint256 tokenId,
        bytes32 key,
        uint256 feeRemainder
    ) public {
        IStreamNativeEnglishAuction.Auction storage a = requireAuction(s, id);
        if (a.status != 2 || tokenId == 0 || key == 0 || feeRemainder > a.winner.revealFee) {
            revert IStreamNativeEnglishAuction.NativeAuctionAccountingMismatch();
        }
        (,,, a.terminalToll) = deadlines(s, id);
        a.status = 3;
        a.tokenId = tokenId;
        a.settlementKey = key;
        if (feeRemainder != 0) {
            s.liabilities += feeRemainder;
            credit(s, id, a, a.winner.payer, feeRemainder);
        }
        solvent(s);
    }

    function claim(State storage s, bytes32 saleId, address payable recipient)
        public
        returns (uint256 amount)
    {
        return claimAccount(s, saleId, msg.sender, recipient);
    }

    /// @dev The fixed host authenticates account before entering this guarded claim worker.
    function claimAccount(
        State storage s,
        bytes32 saleId,
        address account,
        address payable recipient
    ) public returns (uint256 amount) {
        if (account == address(0) || recipient == address(0)) {
            revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        }
        amount = s.credits[saleId][account];
        if (amount == 0) return 0;
        s.credits[saleId][account] = 0;
        s.liabilities -= amount;
        (bool ok,) = recipient.call{ value: amount }("");
        if (!ok) revert IStreamNativeEnglishAuction.NativeAuctionAccountingMismatch();
        emit NativeAuctionRefundClaimed(s.auctionBySale[saleId], saleId, account, recipient, amount);
        solvent(s);
    }

    function setPause(State storage s, bytes32 saleId, bool global, bool value, bytes32 reason)
        public
    {
        if (reason == 0 || (!global && s.auctionBySale[saleId] == 0)) {
            revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        }
        if (global) {
            StreamRefundClock.setGlobal(s.globalPause, value);
            StreamNativeEnglishAuctionPause.recordGlobal(s.pauseHistory, s.globalPause);
        } else {
            StreamRefundClock.setSale(s.globalPause, s.salePause[saleId], value);
            StreamNativeEnglishAuctionPause.recordLocal(
                s.pauseHistory, saleId, s.globalPause, s.salePause[saleId]
            );
        }
        uint64 total = global
            ? StreamRefundClock.globalTotal(s.globalPause)
            : StreamRefundClock.unionTotal(s.globalPause, s.salePause[saleId]);
        emit NativeAuctionPause(saleId, global, value, msg.sender, reason, total);
    }

    function solvent(State storage s) internal view {
        if (address(this).balance < s.liabilities) {
            revert IStreamNativeEnglishAuction.NativeAuctionAccountingMismatch();
        }
    }
}

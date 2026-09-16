// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeEnglishAuctionCustodyReads.sol";
import "./StreamNativeEnglishAuctionUnlock.sol";
import "../revenue/StreamPrimarySettlementHash.sol";

library StreamNativeEnglishAuctionCustodySettlement {
    event NativeAuctionCustodySaleAborted(
        bytes32 indexed auctionId, bytes32 indexed saleId, bytes32 reasonHash, uint256 refundAmount
    );
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
    event NativeAuctionCustodyReleased(
        bytes32 indexed auctionId, bytes32 indexed saleId, uint256 indexed tokenId, address to
    );

    function settle(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes32 id
    ) public returns (uint256 token, bytes32 key) {
        IStreamNativeEnglishAuction.Auction storage a =
            StreamNativeEnglishAuctionState.requireAuction(s, id);
        if (a.status == 3) return (a.tokenId, a.settlementKey);
        if (a.status == 5 || a.status == 6) return (a.tokenId, 0);
        if (a.status != 1) revert IStreamNativeEnglishAuction.NativeAuctionTerminal(id);
        if (StreamNativeEnglishAuctionState.paused(s, a.saleId)) {
            revert IStreamNativeEnglishAuction.NativeAuctionPaused();
        }
        (uint64 end, uint64 deadline,,) = StreamNativeEnglishAuctionState.deadlines(s, id);
        if (end == 0 || block.timestamp < end) {
            revert IStreamNativeEnglishAuction.NativeAuctionUnavailable(id);
        }
        if (a.winner.amount == 0) {
            (,,, a.terminalToll) = StreamNativeEnglishAuctionState.deadlines(s, id);
            a.status = 5;
            deliver(custody, x, id, a, a.config.poster, false);
            emit NativeAuctionNoBids(id, a.saleId, keccak256("NO_BIDS"));
            return (a.tokenId, 0);
        }
        if (block.timestamp > deadline || a.winner.revealFee != 0) {
            revert IStreamNativeEnglishAuction.NativeAuctionTerminal(id);
        }
        StreamNativeEnglishAuctionCustodyReads.requireCurrent(x, a, custody.origins[id]);
        StreamNativeEnglishAuctionRuntime.admitDelivery(
            StreamNativeEnglishAuctionRuntime.gasParameter(
                StreamNativeEnglishAuctionRuntime.DELIVERY_GAS
            )
        );
        uint256 beforeBalance = address(this).balance;
        StreamNativeEnglishAuctionState.beginSettlement(s, id);
        StreamNativeCustodySettlementTypes.Facts memory f =
            StreamNativeCustodySettlementTypes.Facts(id, a, custody.origins[id]);
        (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            StreamSaleTemplate.Selection memory selected
        ) = StreamNativeCustodyPrimaryValidation.derive(
            StreamPrimarySettlementRights.Context(
                x.base.resolver, x.factory, x.factory.splitWalletRuntimeCodeHash()
            ),
            f,
            address(this),
            x.recorder
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r = IStreamNativeCustodyPrimarySettlement(
            x.recorder
        )
        .settleNativeCustodyPrimarySale{ value: a.winner.amount }(
            id
        );
        key = StreamPrimarySettlementHash.settlementKey(
            x.recorder, address(this), c.executionBinding.executionId
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory expected =
            StreamPrimarySettlementTypes.PrimarySettlementResult(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_CUSTODY_TRANSFER_CANDIDATE_V1"),
                        block.chainid,
                        x.recorder,
                        address(this),
                        f,
                        c
                    )
                ),
                key,
                selected.profileId,
                selected.wallet,
                address(0),
                a.winner.amount,
                a.winner.executor,
                c.executionBinding.executionId,
                r.escrowed,
                0,
                0,
                0
            );
        bytes32 factsHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CUSTODY_TRANSFER_FACTS_V1"),
                block.chainid,
                x.recorder,
                address(this),
                f
            )
        );
        if (
            keccak256(abi.encode(r)) != keccak256(abi.encode(expected))
                || keccak256(
                        abi.encode(IStreamPrimarySaleSettlement(x.recorder).settlementResult(key))
                    ) != keccak256(abi.encode(expected))
                || !IStreamPrimarySaleSettlement(x.recorder).settlementConsumed(key)
                || IStreamNativeCustodyPrimarySettlement(x.recorder).nativeCustodyFactsHash(key)
                    != factsHash || address(this).balance != beforeBalance - a.winner.amount
        ) {
            revert IStreamNativeEnglishAuction.NativeAuctionAccountingMismatch();
        }
        StreamNativeEnglishAuctionCustodyReads.requireCurrent(x, a, custody.origins[id]);
        token = a.tokenId;
        StreamNativeEnglishAuctionState.finishSettlement(s, id, token, key, 0);
        emit NativeAuctionSettled(id, a.saleId, token, key, a.winner.amount, 0, 0);
        deliver(custody, x, id, a, a.winner.deliverTo, false);
    }

    function unlock(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes32 id,
        uint8 reason
    ) public {
        IStreamNativeEnglishAuction.Auction storage a =
            StreamNativeEnglishAuctionState.requireAuction(s, id);
        if (a.config.mintAtSettlement) {
            revert IStreamNativeEnglishAuction.UnsupportedNativeAuctionProfile();
        }
        if (a.status == 6) return;
        if (a.status != 1 || a.winner.amount == 0) {
            revert IStreamNativeEnglishAuction.NativeAuctionTerminal(id);
        }
        (uint64 end, uint64 deadline,,) = StreamNativeEnglishAuctionState.deadlines(s, id);
        bytes32 hash;
        if (reason == 0 && block.timestamp > deadline) {
            hash = keccak256("NATIVE_CUSTODY_SALE_AUTHORIZED_DEADLINE");
        } else if ((reason == 4 || reason == 5) && end != 0 && block.timestamp >= end) {
            hash = StreamNativeEnglishAuctionUnlock.reasonHash(
                StreamNativeEnglishAuctionUnlock.Context(
                    StreamNativeEnglishAuctionRuntime.support(x),
                    x.registry,
                    x.registryHash,
                    x.coreHash,
                    x.managerHash,
                    x.recorder
                ),
                a,
                reason
            );
        }
        if (hash == 0) {
            revert IStreamNativeEnglishAuction.NativeAuctionUnlockUnavailable(id, reason);
        }
        (,,, a.terminalToll) = StreamNativeEnglishAuctionState.deadlines(s, id);
        a.status = 6;
        s.liveDeposits -= a.winner.amount;
        StreamNativeEnglishAuctionState.credit(s, id, a, a.winner.payer, a.winner.amount);
        StreamNativeEnglishAuctionState.solvent(s);
        deliver(custody, x, id, a, a.config.poster, false);
        emit NativeAuctionCustodySaleAborted(id, a.saleId, hash, a.winner.amount);
    }

    /// @dev Own terminal claims and poster escapes have no current admission/rights gate.
    function deliver(
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes32 id,
        IStreamNativeEnglishAuction.Auction storage a,
        address to,
        bool claim
    ) public {
        if (to == address(0) || to == address(this) || a.tokenId == 0) {
            revert IStreamNativeCustodyAuction.InvalidNativeCustody();
        }
        uint256 cap = StreamNativeEnglishAuctionRuntime.gasParameter(
            StreamNativeEnglishAuctionRuntime.DELIVERY_GAS
        );
        StreamNativeEnglishAuctionRuntime.admitDelivery(cap);
        bool eligible = custody.origins[id].eligible;
        custody.origins[id].eligible = false;
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
        if (ok && size == 0) {
            emit NativeAuctionNFTDelivered(id, a.saleId, a.tokenId, to);
            emit NativeAuctionCustodyReleased(id, a.saleId, a.tokenId, to);
            return;
        }
        if (claim || IStreamCore(target).ownerOf(a.tokenId) != address(this)) {
            revert IStreamNativeEnglishAuction.NativeAuctionAccountingMismatch();
        }
        custody.origins[id].eligible = eligible;
        a.nftClaimant = a.status == 3 ? a.winner.deliverTo : a.config.poster;
        emit NativeAuctionNFTClaimPending(id, a.saleId, a.tokenId, a.nftClaimant);
    }
}

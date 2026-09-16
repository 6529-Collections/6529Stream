// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeEnglishAuctionCustodySettlement.sol";
import "../revenue/StreamCustodyRightsValidation.sol";
import "../../interfaces/stream/revenue/IStreamCustodyRightsSettlement.sol";
import "./StreamNativeEnglishAuctionUnlock.sol";
import "../revenue/StreamPrimarySettlementHash.sol";

library StreamCustodyRightsSettlement {
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
            StreamNativeEnglishAuctionCustodySettlement.deliver(
                custody, x, id, a, a.config.poster, false
            );
            emit NativeAuctionNoBids(id, a.saleId, keccak256("NO_BIDS"));
            return (a.tokenId, 0);
        }
        if (block.timestamp > deadline || a.winner.revealFee != 0) {
            revert IStreamNativeEnglishAuction.NativeAuctionTerminal(id);
        }
        _requireCurrent(x, a, custody.origins[id], id);
        StreamNativeEnglishAuctionRuntime.admitDelivery(
            StreamNativeEnglishAuctionRuntime.gasParameter(
                StreamNativeEnglishAuctionRuntime.DELIVERY_GAS
            )
        );
        uint256 beforeBalance = address(this).balance;
        StreamNativeEnglishAuctionState.beginSettlement(s, id);
        StreamNativeCustodySettlementTypes.Facts memory f =
            StreamNativeCustodySettlementTypes.Facts(id, a, custody.origins[id]);
        StreamCustodyRightsTypes.Activation memory activation =
            StreamCustodyRightsValidation.activation(address(this), f);
        (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            StreamSaleTemplate.Selection memory selected,
            bytes32 beneficiaryHash
        ) = StreamCustodyRightsValidation.derive(
            StreamPrimarySettlementRights.Context(
                x.base.resolver, x.factory, x.factory.splitWalletRuntimeCodeHash()
            ),
            f,
            activation,
            address(this),
            x.recorder
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r = IStreamCustodyRightsSettlement(
            x.recorder
        )
        .settleCustodyRightsPrimarySale{ value: a.winner.amount }(
            id
        );
        key = StreamPrimarySettlementHash.settlementKey(
            x.recorder, address(this), c.executionBinding.executionId
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory expected =
            StreamPrimarySettlementTypes.PrimarySettlementResult(
                StreamCustodyRightsHash.candidate(
                    x.recorder, address(this), f, activation, c, beneficiaryHash
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
        bytes32 factsHash = StreamCustodyRightsHash.facts(x.recorder, address(this), f, activation);
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
        _requireCurrent(x, a, custody.origins[id], id);
        token = a.tokenId;
        StreamNativeEnglishAuctionState.finishSettlement(s, id, token, key, 0);
        emit NativeAuctionSettled(id, a.saleId, token, key, a.winner.amount, 0, 0);
        StreamNativeEnglishAuctionCustodySettlement.deliver(
            custody, x, id, a, a.winner.deliverTo, false
        );
    }

    function _requireCurrent(
        StreamNativeEnglishAuctionRuntime.Context memory x,
        IStreamNativeEnglishAuction.Auction storage a,
        StreamNativeCustodySettlementTypes.Origin memory o,
        bytes32 id
    ) private view {
        StreamNativeEnglishAuctionCustodyReads.requireCustody(x, a, o);
        StreamNativeCustodySettlementTypes.Facts memory f =
            StreamNativeCustodySettlementTypes.Facts(id, a, o);
        StreamCustodyRightsTypes.Activation memory activation =
            StreamCustodyRightsValidation.activation(address(this), f);
        StreamCustodyRightsValidation.selection(
            StreamPrimarySettlementRights.Context(
                x.base.resolver, x.factory, x.factory.splitWalletRuntimeCodeHash()
            ),
            a.config.collectionId,
            a.tokenId,
            activation.authorization.rightsMode,
            a.config.poster
        );
    }
}

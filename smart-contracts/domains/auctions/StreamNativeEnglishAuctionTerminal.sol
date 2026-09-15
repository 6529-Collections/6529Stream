// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeEnglishAuctionCustodySettlement.sol";
import "./StreamNativeEnglishAuctionSettlement.sol";
import "./StreamNativeEnglishAuctionContentUnlock.sol";
import "../revenue/StreamPreparedNativeRightsHash.sol";
import "../../interfaces/stream/auctions/IStreamNativeAuctionDelegatedDelivery.sol";
import {
    IStreamNativeEnglishAuction as A
} from "../../interfaces/stream/auctions/IStreamNativeEnglishAuction.sol";

/// @notice Terminal mutations and claims in the fixed original house storage context.
/// @dev Own claims and deadline escape never acquire a current dependency gate.
library StreamNativeEnglishAuctionTerminal {
    event NativeAuctionCancelled(
        bytes32 indexed auctionId, bytes32 indexed saleId, bytes32 reasonHash
    );

    function unlockNoMint(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        mapping(bytes32 => StreamPreparedNativeContentTypes.Selection) storage curated,
        mapping(bytes32 => StreamPreparedNativeRightsTypes.OriginalPolicy) storage rights,
        bytes32 id,
        uint8 reason
    ) public {
        A.Auction storage a = StreamNativeEnglishAuctionState.requireAuction(s, id);
        if (!a.config.mintAtSettlement) revert A.UnsupportedNativeAuctionProfile();
        if (a.status == 6) return;
        if (a.status != 1 || a.winner.amount == 0) revert A.NativeAuctionTerminal(id);
        bytes32 hash;
        if (reason == 0) {
            (, uint64 deadline,,) = StreamNativeEnglishAuctionState.deadlines(s, id);
            if (StreamEnglishAuctionClock.expired(deadline, StreamRefundClock.now64())) {
                hash = keccak256("NATIVE_AUCTION_FINALIZATION_DEADLINE");
            }
        } else {
            (uint64 end,,,) = StreamNativeEnglishAuctionState.deadlines(s, id);
            if (end != 0 && block.timestamp >= end) {
                if (a.config.contentManifestRoot != 0) {
                    hash = StreamNativeEnglishAuctionContentUnlock.reasonHash(
                        StreamNativeEnglishAuctionUnlock.Context(
                            StreamNativeEnglishAuctionRuntime.support(x),
                            x.registry,
                            x.registryHash,
                            x.coreHash,
                            x.managerHash,
                            x.recorder
                        ),
                        a,
                        reason,
                        curated[id].contentId
                    );
                } else {
                    bytes32 context;
                    if (rights[id].mode != 0 && reason == 2) {
                        StreamPreparedNativeRightsTypes.Intent memory original =
                            StreamPreparedNativeRightsTypes.Intent(
                                StreamNativeEnglishAuctionSupport.intent(a), rights[id]
                            );
                        context = StreamPreparedNativeRightsHash.mintContext(
                            address(x.base.manager),
                            address(this),
                            StreamPreparedNativeRightsHash.intentHash(
                                address(this), x.recorder, original
                            )
                        );
                    }
                    hash = StreamNativeEnglishAuctionUnlock.reasonHashWithContext(
                        StreamNativeEnglishAuctionUnlock.Context(
                            StreamNativeEnglishAuctionRuntime.support(x),
                            x.registry,
                            x.registryHash,
                            x.coreHash,
                            x.managerHash,
                            x.recorder
                        ),
                        a,
                        reason,
                        context
                    );
                }
            }
        }
        if (hash == 0) revert A.NativeAuctionUnlockUnavailable(id, reason);
        StreamNativeEnglishAuctionState.noMint(s, id, hash);
    }

    function cancel(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes32 id,
        bytes32 reason
    ) public {
        A.Auction storage a = StreamNativeEnglishAuctionState.requireAuction(s, id);
        if (a.status == 4) return;
        (uint64 end,,,) = StreamNativeEnglishAuctionState.deadlines(s, id);
        if (
            msg.sender != a.config.poster || a.status != 1 || a.winner.amount != 0 || reason == 0
                || (end != 0 && block.timestamp >= end)
        ) revert A.NativeAuctionTerminal(id);
        (,,, a.terminalToll) = StreamNativeEnglishAuctionState.deadlines(s, id);
        a.status = 4;
        if (!a.config.mintAtSettlement) _deliver(custody, x, id, a, a.config.poster, false);
        emit NativeAuctionCancelled(id, a.saleId, reason);
    }

    function claimRefundFor(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes32 saleId,
        address account,
        IStreamNativeAuctionDelegatedDelivery.DelegationWitness calldata witness
    ) public returns (uint256) {
        address recipient = _claimRecipient(x, account, witness);
        return StreamNativeEnglishAuctionState.claimAccount(s, saleId, account, payable(recipient));
    }

    function claimNFTFor(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes32 id,
        address account,
        IStreamNativeAuctionDelegatedDelivery.DelegationWitness calldata witness
    ) public {
        A.Auction storage a = StreamNativeEnglishAuctionState.requireAuction(s, id);
        if (!_claimable(a) || account == address(0) || a.nftClaimant != account) {
            revert A.InvalidNativeAuction();
        }
        _deliver(custody, x, id, a, _claimRecipient(x, account, witness), true);
    }

    function claimNFT(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes32 id,
        address to
    ) public {
        A.Auction storage a = StreamNativeEnglishAuctionState.requireAuction(s, id);
        if (
            !_claimable(a) || a.nftClaimant == address(0) || a.nftClaimant != msg.sender
                || to == address(0) || to == address(this)
        ) revert A.InvalidNativeAuction();
        _deliver(custody, x, id, a, to, true);
    }

    function _deliver(
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes32 id,
        A.Auction storage a,
        address to,
        bool claim
    ) private {
        if (!a.config.mintAtSettlement) {
            StreamNativeEnglishAuctionCustodySettlement.deliver(custody, x, id, a, to, claim);
        } else {
            StreamNativeEnglishAuctionSettlement.deliver(x, id, a, to, claim);
        }
    }

    function _claimable(A.Auction storage a) private view returns (bool) {
        return a.status == 3 || (!a.config.mintAtSettlement && a.status >= 4 && a.status <= 6);
    }

    function _claimRecipient(
        StreamNativeEnglishAuctionRuntime.Context memory x,
        address account,
        IStreamNativeAuctionDelegatedDelivery.DelegationWitness calldata witness
    ) private view returns (address) {
        return StreamNativeAuctionDelegation.claimRecipient(
            x.delegation,
            account,
            msg.sender,
            account,
            StreamNativeAuctionDelegation.Witness(witness.walletWide, witness.index),
            msg.sender == account
                ? 0
                : StreamNativeEnglishAuctionRuntime.gasParameter(
                    StreamNativeAuctionDelegation.GAS_PARAMETER
                )
        );
    }
}

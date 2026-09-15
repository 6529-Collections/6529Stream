// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeCustodyPrimaryAdmission.sol";
import "./StreamPrimarySettlementRights.sol";
import "../auctions/StreamNativeEnglishAuctionSupport.sol";

/// @notice Reads actual canonical house state and actual token rights without a second mint.
library StreamNativeCustodyPrimaryValidation {
    function read(
        StreamNativeCustodyPrimaryAdmission.Context memory x,
        StreamNativeCustodySettlementTypes.CanonicalHouse memory pin,
        bytes32 id
    ) public view returns (StreamNativeCustodySettlementTypes.Facts memory f) {
        StreamNativeCustodyPrimaryAdmission.requireCurrent(x, pin, msg.sender);
        f = IStreamNativeCustodyAuction(msg.sender).activeCustodySale(id);
        IStreamNativeEnglishAuction.Auction memory a = f.auction;
        StreamNativeCustodySettlementTypes.Origin memory o = f.origin;
        if (
            f.auctionId != id || id == 0 || a.status != 2 || a.config.mintAtSettlement
                || a.config.artworkCommitment != 0 || a.config.contentManifestRoot != 0
                || a.config.tokenId == 0 || a.config.tokenId != a.tokenId || a.tokenId != o.tokenId
                || a.saleId == 0 || a.saleNonce == 0 || a.creationDigest == 0
                || a.config.primaryPolicyMode != 1 || a.config.expectedPrimaryPolicyHash == 0
                || !o.eligible || o.operationRoot == 0 || o.operationId == 0
                || o.authorizationId != a.creationDigest || o.manager == address(0)
                || o.managerCodeHash == 0 || o.tokenDataHash == 0 || o.collectionSerial == 0
                || o.fundingAccount == address(0) || a.winner.amount == 0 || a.winner.revealFee != 0
                || a.winner.payer == address(0) || a.winner.payer == msg.sender
                || a.winner.payer == address(this) || a.winner.executor == address(0)
                || a.winner.deliverTo == address(0) || a.winner.deliverTo == msg.sender
                || a.winner.authorizationDigest == 0 || a.winner.bidIndex == 0
                || a.nftClaimant != address(0) || a.settlementKey != 0
        ) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            IStreamCore(x.core).tokenCollectionIdentity(o.tokenId);
        if (
            !exists || burned || collection != a.config.collectionId || serial != o.collectionSerial
                || IStreamCore(x.core).tokenLifecycle(o.tokenId) != 2
                || IStreamCore(x.core).ownerOf(o.tokenId) != msg.sender
                || keccak256(IStreamCore(x.core).tokenData(o.tokenId)) != o.tokenDataHash
        ) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamPreparedNativeSettlementAdmission.requireAdmission(
                x.registry, msg.sender, a.saleId
            );
        if (keccak256(abi.encode(lifecycle)) != keccak256(abi.encode(a.lifecycle))) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        (uint64 end, uint64 deadline, uint64 ceiling,) =
            IStreamNativeEnglishAuction(msg.sender).auctionDeadlines(id);
        if (
            end == 0 || block.timestamp < end || block.timestamp > deadline
                || ceiling != a.winner.signedFinalizeBy
                || (a.winner.signed && (ceiling == 0 || block.timestamp > ceiling))
                || (!a.winner.signed && ceiling != 0)
        ) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
    }

    function derive(
        StreamPrimarySettlementRights.Context memory x,
        StreamNativeCustodySettlementTypes.Facts memory f,
        address house,
        address recorder
    )
        public
        view
        returns (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            StreamSaleTemplate.Selection memory selected
        )
    {
        IStreamNativeEnglishAuction.Auction memory a = f.auction;
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory actual =
            x.resolver
                .resolvePrimaryAssignment(
                    a.config.collectionId, a.tokenId, keccak256("PRIMARY_SALE")
                );
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory collection =
            x.resolver.resolvePrimaryAssignment(a.config.collectionId, 0, keccak256("PRIMARY_SALE"));
        if (
            !actual.exists || actual.assignmentType != 1 || actual.scope != 1
                || actual.scopeId != a.config.collectionId || actual.profileId == 0
                || actual.templateId != 0 || actual.assignmentHash == 0 || actual.policyHash != 0
                || keccak256(abi.encode(actual)) != keccak256(abi.encode(collection))
        ) {
            revert IStreamNativeEnglishAuction.UnsupportedNativeAuctionProfile();
        }
        selected = StreamSaleTemplate.Selection(
            actual.profileId,
            x.factory.walletFor(actual.profileId),
            0,
            actual.assignmentHash,
            x.factory.profileEntriesHash(actual.profileId)
        );
        StreamPrimarySettlementRights.requireWallet(x, selected);
        c.saleAdapter = house;
        c.executor = a.winner.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            a.saleId,
            keccak256("PRIMARY_SALE"),
            1,
            a.config.collectionId,
            a.tokenId,
            a.saleNonce,
            a.winner.payer,
            a.config.poster,
            a.winner.deliverTo,
            a.winner.amount,
            StreamSaleTemplate.policyHash(x.resolver, a.config.collectionId, selected)
        );
        c.lifecycleBinding.saleCreatedAt = a.lifecycle.saleCreatedAt;
        c.lifecycleBinding.saleAdapterRegistryRevision = a.lifecycle.saleAdapterRegistryRevision;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_NATIVE_CUSTODY_TRANSFER_EXECUTION_V1"),
                    block.chainid,
                    recorder,
                    house,
                    f
                )
            ),
            a.winner.bidIndex,
            a.winner.signed ? 1 : 2,
            a.winner.authorizationDigest
        );
        c.orchestrationOrder = 3;
        // No current mint operation exists in this paid transfer. Original acquisition is
        // retained separately in f.origin; never alias it into these current-mint fields.
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            selected.profileId, selected.wallet, 0, selected.assignmentHash, selected.entriesHash
        );
        c.saleExecutionHash = keccak256(abi.encode(f));
    }
}

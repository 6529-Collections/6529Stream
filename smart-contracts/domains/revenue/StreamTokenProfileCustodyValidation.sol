// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeCustodyPrimaryValidation.sol";
import "./StreamTokenProfileCustodyHash.sol";

library StreamTokenProfileCustodyValidation {
    function activation(address house, StreamNativeCustodySettlementTypes.Facts memory f)
        public
        view
        returns (StreamTokenProfileCustodyTypes.Activation memory a)
    {
        a = StreamTokenProfileCustodyHash.readOptional(house, f.auctionId);
        StreamTokenProfileCustodyTypes.Authorization memory q = a.authorization;
        if (
            a.authorizationDigest == 0 || q.auctionId != f.auctionId
                || q.baseConfigHash != f.auction.configHash
                || q.originHash != keccak256(abi.encode(f.origin)) || q.tokenId != f.auction.tokenId
                || q.primaryPolicyMode != 1 || q.assignmentHash == 0 || q.primaryPolicyHash == 0
                || q.artist == address(0) || q.nonce == 0
                || a.authorizationDigest != StreamTokenProfileCustodyHash.digest(house, q)
                || a.effectiveConfigHash != StreamTokenProfileCustodyHash.configuration(house, a)
        ) {
            revert IStreamTokenProfileCustodyAuction.InvalidTokenProfileCustody();
        }
    }

    function read(
        StreamNativeCustodyPrimaryAdmission.Context memory x,
        StreamNativeCustodySettlementTypes.CanonicalHouse memory pin,
        bytes32 id
    )
        public
        view
        returns (
            StreamNativeCustodySettlementTypes.Facts memory f,
            StreamTokenProfileCustodyTypes.Activation memory a
        )
    {
        f = StreamNativeCustodyPrimaryValidation.read(x, pin, id);
        a = activation(msg.sender, f);
    }

    function selection(
        StreamPrimarySettlementRights.Context memory x,
        uint256 collection,
        uint256 token
    ) public view returns (StreamSaleTemplate.Selection memory selected, bytes32 policy) {
        if (token == 0) revert IStreamTokenProfileCustodyAuction.InvalidTokenProfileCustody();
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory actual =
            x.resolver.resolvePrimaryAssignment(collection, token, keccak256("PRIMARY_SALE"));
        if (
            !actual.exists || actual.assignmentType != 1 || actual.scope != 2
                || actual.scopeId != token || actual.profileId == 0 || actual.templateId != 0
                || actual.assignmentHash == 0 || actual.policyHash != 0
        ) {
            revert IStreamTokenProfileCustodyAuction.InvalidTokenProfileCustody();
        }
        // The selected Resolver performs the exact scope2 current-binding consent read.
        // Calling Artist directly from the house/recorder would use the wrong resolver identity.
        selected = StreamSaleTemplate.Selection(
            actual.profileId,
            x.factory.walletFor(actual.profileId),
            0,
            actual.assignmentHash,
            x.factory.profileEntriesHash(actual.profileId)
        );
        StreamPrimarySettlementRights.requireWallet(x, selected);
        policy = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(x.resolver),
                keccak256("PRIMARY_SALE"),
                collection,
                token,
                bytes32(0),
                selected.profileId,
                selected.wallet,
                selected.assignmentHash
            )
        );
    }

    function derive(
        StreamPrimarySettlementRights.Context memory x,
        StreamNativeCustodySettlementTypes.Facts memory f,
        StreamTokenProfileCustodyTypes.Activation memory a,
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
        bytes32 policy;
        (selected, policy) = selection(x, f.auction.config.collectionId, f.auction.tokenId);
        IStreamNativeEnglishAuction.Auction memory sale = f.auction;
        c.saleAdapter = house;
        c.executor = sale.winner.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            sale.saleId,
            keccak256("PRIMARY_SALE"),
            1,
            sale.config.collectionId,
            sale.tokenId,
            sale.saleNonce,
            sale.winner.payer,
            sale.config.poster,
            sale.winner.deliverTo,
            sale.winner.amount,
            policy
        );
        c.lifecycleBinding.saleCreatedAt = sale.lifecycle.saleCreatedAt;
        c.lifecycleBinding.saleAdapterRegistryRevision = sale.lifecycle.saleAdapterRegistryRevision;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            StreamTokenProfileCustodyHash.execution(recorder, house, f, a),
            sale.winner.bidIndex,
            sale.winner.signed ? 1 : 2,
            sale.winner.authorizationDigest
        );
        c.orchestrationOrder = 3;
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            selected.profileId, selected.wallet, 0, selected.assignmentHash, selected.entriesHash
        );
        c.saleExecutionHash = StreamTokenProfileCustodyHash.facts(recorder, house, f, a);
    }
}

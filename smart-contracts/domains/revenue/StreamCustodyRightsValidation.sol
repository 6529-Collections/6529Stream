// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeCustodyPrimaryValidation.sol";
import "./StreamCustodyRightsHash.sol";
import "./StreamDefaultPrimaryProfile.sol";
import { StreamScopedSaleTemplate } from "../mint/StreamScopedSaleTemplate.sol";
import { StreamDefaultSaleTemplate } from "../mint/StreamDefaultSaleTemplate.sol";

library StreamCustodyRightsValidation {
    function activation(address house, StreamNativeCustodySettlementTypes.Facts memory f)
        public
        view
        returns (StreamCustodyRightsTypes.Activation memory a)
    {
        a = StreamCustodyRightsHash.readOptional(house, f.auctionId);
        StreamCustodyRightsTypes.Authorization memory q = a.authorization;
        if (
            a.authorizationDigest == 0 || q.auctionId != f.auctionId
                || q.baseConfigHash != f.auction.configHash
                || q.originHash != keccak256(abi.encode(f.origin)) || q.tokenId != f.auction.tokenId
                || q.primaryPolicyMode != 1 || q.rightsMode < 1 || q.rightsMode > 7
                || q.assignmentHash == 0 || q.primaryPolicyHash == 0 || q.artist == address(0)
                || q.nonce == 0 || a.authorizationDigest != StreamCustodyRightsHash.digest(house, q)
                || a.effectiveConfigHash != StreamCustodyRightsHash.configuration(house, a)
        ) {
            revert IStreamCustodyRightsAuction.InvalidCustodyRights();
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
            StreamCustodyRightsTypes.Activation memory a
        )
    {
        f = StreamNativeCustodyPrimaryValidation.read(x, pin, id);
        a = activation(msg.sender, f);
    }

    function selection(
        StreamPrimarySettlementRights.Context memory x,
        uint256 collection,
        uint256 token,
        uint8 mode,
        address poster
    )
        public
        view
        returns (StreamSaleTemplate.Selection memory selected, bytes32 policy, bytes32 witness)
    {
        if (token == 0) {
            revert IStreamCustodyRightsAuction.InvalidCustodyRights();
        }
        if (mode == 1) {
            selected = StreamDefaultPrimaryProfile.resolve(x.resolver, collection, token);
        } else if (mode >= 5 && mode <= 7) {
            (selected, witness) =
                StreamDefaultSaleTemplate.resolve(x.resolver, collection, token, mode, poster);
        } else {
            IStreamRevenueResolver.ResolvedPrimaryAssignment memory actual =
                x.resolver.resolvePrimaryAssignment(collection, token, keccak256("PRIMARY_SALE"));
            (selected, witness) = StreamScopedSaleTemplate.preview(
                x.resolver, collection, token, mode, poster, actual
            );
        }
        policy = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(x.resolver),
                keccak256("PRIMARY_SALE"),
                collection,
                token,
                selected.templateId,
                selected.profileId,
                selected.wallet,
                selected.assignmentHash
            )
        );
    }

    function derive(
        StreamPrimarySettlementRights.Context memory x,
        StreamNativeCustodySettlementTypes.Facts memory f,
        StreamCustodyRightsTypes.Activation memory a,
        address house,
        address recorder
    )
        public
        view
        returns (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            StreamSaleTemplate.Selection memory selected,
            bytes32 beneficiaryHash
        )
    {
        bytes32 policy;
        (selected, policy, beneficiaryHash) = selection(
            x,
            f.auction.config.collectionId,
            f.auction.tokenId,
            a.authorization.rightsMode,
            f.auction.config.poster
        );
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
            StreamCustodyRightsHash.execution(recorder, house, f, a),
            sale.winner.bidIndex,
            sale.winner.signed ? 1 : 2,
            sale.winner.authorizationDigest
        );
        c.orchestrationOrder = 3;
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            selected.profileId,
            selected.wallet,
            selected.templateId,
            selected.assignmentHash,
            selected.entriesHash
        );
        c.saleExecutionHash = StreamCustodyRightsHash.facts(recorder, house, f, a);
    }
}

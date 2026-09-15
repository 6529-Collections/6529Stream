// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeCustodyPrimaryValidation.sol";
import "./StreamPlatformCustodyHash.sol";
import "./StreamPlatformPrimaryProfile.sol";
import "./StreamPreparedNativeRightsProjection.sol";

library StreamPlatformCustodyValidation {
    function read(
        StreamNativeCustodyPrimaryAdmission.Context memory x,
        StreamNativeCustodySettlementTypes.CanonicalHouse memory pin,
        bytes32 id
    ) public view returns (StreamNativeCustodySettlementTypes.Facts memory f) {
        return StreamNativeCustodyPrimaryValidation.read(x, pin, id);
    }

    function binding(
        IStreamRevenueResolver resolver,
        address house,
        StreamNativeCustodySettlementTypes.Facts memory f
    )
        public
        view
        returns (
            bytes32 declaration,
            StreamPreparedNativeRightsTypes.OriginalPolicy memory original
        )
    {
        original = IStreamNativeRightsAuction(house).originalAuctionRights(f.auctionId);
        declaration =
            IStreamPlatformNativeRightsAuction(house).platformAuctionDeclaration(f.auction.saleId);
        if (
            (original.mode != 10 && original.mode != 11) || original.templateId != 0
                || original.assignmentHash == 0 || declaration == 0 || f.auction.artistId != 0
                || f.auction.bindingGeneration != 0 || f.auction.bindingHash != 0
                || StreamPlatformSaleTemplate.declaration(resolver, f.auction.config.collectionId)
                    != declaration
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
            StreamSaleTemplate.Selection memory selected,
            bytes32 beneficiaryHash
        )
    {
        (bytes32 declaration, StreamPreparedNativeRightsTypes.OriginalPolicy memory original) =
            binding(x.resolver, house, f);
        IStreamNativeEnglishAuction.Auction memory a = f.auction;
        (selected, beneficiaryHash) = StreamPlatformPrimaryProfile.resolve(
            x.resolver, a.config.collectionId, a.tokenId, original.mode, a.config.poster
        );
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
            StreamPreparedNativeRightsProjection.policyHash(
                x.resolver, a.config.collectionId, a.tokenId, selected
            )
        );
        c.lifecycleBinding.saleCreatedAt = a.lifecycle.saleCreatedAt;
        c.lifecycleBinding.saleAdapterRegistryRevision = a.lifecycle.saleAdapterRegistryRevision;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_PLATFORM_CUSTODY_EXECUTION_V1"),
                    block.chainid,
                    recorder,
                    house,
                    f,
                    declaration,
                    original,
                    beneficiaryHash
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
        c.saleExecutionHash =
            StreamPlatformCustodyHash.facts(recorder, house, f, declaration, original);
    }
}

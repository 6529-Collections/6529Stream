// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeCustodyPrimaryValidation.sol";
import "./StreamPlatformTokenCustodyHash.sol";
import "./StreamPlatformTokenPrimary.sol";
import "./StreamPlatformCustodyValidation.sol";
import "./StreamPlatformPrimaryProfile.sol";
import "./StreamPreparedNativeRightsProjection.sol";

library StreamPlatformTokenCustodyValidation {
    function read(
        StreamNativeCustodyPrimaryAdmission.Context memory x,
        StreamNativeCustodySettlementTypes.CanonicalHouse memory pin,
        bytes32 id
    ) public view returns (StreamNativeCustodySettlementTypes.Facts memory f) {
        return StreamNativeCustodyPrimaryValidation.read(x, pin, id);
    }

    function activation(
        IStreamRevenueResolver resolver,
        address house,
        StreamNativeCustodySettlementTypes.Facts memory f
    )
        public
        view
        returns (
            StreamPlatformTokenCustodyTypes.Activation memory a,
            StreamPreparedNativeRightsTypes.OriginalPolicy memory original
        )
    {
        bytes32 declaration;
        (declaration, original) = StreamPlatformCustodyValidation.binding(resolver, house, f);
        a = StreamPlatformTokenCustodyHash.readOptional(house, f.auctionId);
        StreamPlatformTokenCustodyTypes.Authorization memory q = a.authorization;
        if (
            a.authorizationDigest == 0 || q.auctionId != f.auctionId
                || q.baseConfigHash != f.auction.configHash
                || q.originHash != keccak256(abi.encode(f.origin)) || q.tokenId != f.auction.tokenId
                || q.tokenId == 0 || q.declarationHash != declaration
                || (q.rightsMode != 12 && q.rightsMode != 13) || q.assignmentHash == 0
                || q.primaryPolicyHash == 0 || q.primaryPolicyMode != 1 || q.nonce == 0
                || a.authorizationDigest != StreamPlatformTokenCustodyHash.digest(house, q)
                || a.effectiveConfigHash != StreamPlatformTokenCustodyHash.configuration(house, a)
        ) revert IStreamPlatformTokenCustodyAuction.InvalidPlatformTokenCustody();
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
        (
            StreamPlatformTokenCustodyTypes.Activation memory appended,
            StreamPreparedNativeRightsTypes.OriginalPolicy memory original
        ) = activation(x.resolver, house, f);
        IStreamNativeEnglishAuction.Auction memory a = f.auction;
        (selected, beneficiaryHash) = StreamPlatformTokenPrimary.resolve(
            x.resolver,
            a.config.collectionId,
            a.tokenId,
            appended.authorization.rightsMode,
            a.config.poster
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
                    keccak256("6529STREAM_PLATFORM_TOKEN_CUSTODY_EXECUTION_V1"),
                    block.chainid,
                    recorder,
                    house,
                    f,
                    appended,
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
            selected.profileId,
            selected.wallet,
            selected.templateId,
            selected.assignmentHash,
            selected.entriesHash
        );
        c.saleExecutionHash =
            StreamPlatformTokenCustodyHash.facts(recorder, house, f, appended, original);
    }
}

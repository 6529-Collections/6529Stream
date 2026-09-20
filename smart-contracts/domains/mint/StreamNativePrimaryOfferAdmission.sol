// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrimaryOfferDelegationManifest.sol";
import "./StreamNativePrimaryOfferSupport.sol";
import "./StreamNativePrimaryOfferAuthorization.sol";
import "./StreamNativePrimaryOfferExecution.sol";
import { StreamNativeAuctionDelegation as D } from "../auctions/StreamNativeAuctionDelegation.sol";

/// @notice Fixed linked offer validation in the guarded carrier's original caller context.
library StreamNativePrimaryOfferAdmission {
    bytes32 private constant SIGNATURE_GAS = keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT");
    error InvalidPrimaryOffer();
    error PrimaryOfferSignerUnavailable();

    function validate(
        StreamNativeCuratedSaleState.State storage state,
        mapping(
            uint256 => mapping(address => mapping(uint8 => Curated.CollectionSigner))
        ) storage signers,
        StreamNativeCuratedSaleRuntime.Context memory x,
        StreamNativePrimaryOfferTypes.Configuration memory c,
        StreamNativePrimaryOfferTypes.Acceptance calldata q,
        bytes32 sellerDigest
    ) public view returns (bytes32 buyerDigest) {
        bytes32 id = q.authorization.saleId;
        requireSigner(signers, c);
        requireDelegations(c.buyer, q);
        StreamNativePrimaryOfferSupport.requireSale(state, x, id);
        if (q.selection.recipient != c.buyer) revert InvalidPrimaryOffer();
        (bytes32 leaf,) =
            StreamNativePrimaryOfferSupport.selection(id, state.sales[id], q.selection);
        if (
            c.sale.contentManifestRoot != 0
                && (q.selection.content.contentId != c.contentId
                    || q.selection.content.tokenDataHash != c.tokenDataHash)
        ) revert InvalidPrimaryOffer();
        buyerDigest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.offerBody(q.offer)
        );
        bytes32 authorizationId = StreamMintTicketHash.authorizationId(buyerDigest);
        IStreamMintManager.MintBatch memory b = StreamNativePrimaryOfferExecution.authorizationBatch(
            state, x, q, buyerDigest, sellerDigest
        );
        (bytes32 validatedSeller, bytes32 validatedBuyer, bytes32 validatedId) = StreamNativePrimaryOfferAuthorization.validate(
            StreamNativePrimaryOfferAuthorization.Context(
                x.base.core,
                address(x.base.manager),
                StreamNativeCuratedSaleRuntime.gasParameter(SIGNATURE_GAS)
            ),
            StreamNativePrimaryOfferAuthorization.Terms(
                    id,
                    c.sale.collectionId,
                    c.sale.phaseId,
                    c.buyer,
                    c.sale.price,
                    c.sale.startsAt,
                    c.sale.endsAt,
                    leaf,
                    c.sale.mintPolicyHash,
                    c.sale.primaryPolicyMode,
                    c.sale.expectedPrimaryPolicyHash,
                    c.signer,
                    c.signerKind,
                    c.offerDigest
                ),
            q.authorization,
            q.sellerProof,
            q.offer,
            q.buyerProof,
            b
        );
        if (
            validatedSeller != sellerDigest || validatedBuyer != buyerDigest
                || validatedId != authorizationId
        ) revert InvalidPrimaryOffer();
    }

    function requireSigner(
        mapping(
            uint256 => mapping(address => mapping(uint8 => Curated.CollectionSigner))
        ) storage signers,
        StreamNativePrimaryOfferTypes.Configuration memory c
    ) public view {
        Curated.CollectionSigner storage s = signers[c.sale.collectionId][c.signer][c.signerKind];
        if (
            c.signer == address(0) || (c.signerKind != 1 && c.signerKind != 2) || !s.enabled
                || s.revision == 0 || s.revision != c.signerRevision
                || s.evidenceHash != c.signerEvidenceHash || s.authority == address(0)
                || s.authority != c.signerAuthority
        ) revert PrimaryOfferSignerUnavailable();
    }

    function requireDelegations(address buyer, StreamNativePrimaryOfferTypes.Acceptance calldata q)
        public
        view
    {
        if (buyer == address(0) || buyer == address(this)) revert InvalidPrimaryOffer();
        if (msg.sender != buyer) {
            _delegate(buyer, msg.sender, q.authorization.saleId, q.executorDelegation);
        }
        if (q.buyerProof.authorizer != buyer) {
            _delegate(buyer, q.buyerProof.authorizer, q.authorization.saleId, q.signerDelegation);
        }
    }

    function _delegate(
        address buyer,
        address signer,
        bytes32 saleId,
        IStreamNativeRefundDelegatedClaims.DelegationWitness calldata witness
    ) private view {
        IStreamNativeRefundDelegatedClaims.DelegationConfiguration memory
            dc = IStreamNativeRefundDelegatedClaims(address(this)).refundDelegationConfiguration();
        D.Configuration memory d = D.Configuration(
            dc.chainId,
            dc.core,
            dc.registry,
            dc.registryCodeHash,
            dc.usecase,
            dc.baseManifestHash,
            dc.moduleRegistry,
            dc.moduleRegistryCodeHash
        );
        uint256 cap = StreamNativeCuratedSaleRuntime.gasParameter(D.GAS_PARAMETER);
        StreamPrimaryOfferDelegationManifest.requireNative(d, address(this), saleId, cap);
        D.requireDelegated(d, buyer, signer, D.Witness(witness.walletWide, witness.index), cap);
    }

    function revoke(
        bool exists,
        address manager,
        StreamNativePrimaryOfferTypes.Configuration memory c,
        StreamPrivateSaleTypes.SaleAuthorization calldata a,
        IStreamPrivateSaleAdapter.Signature calldata proof,
        bytes32 digest
    ) public view {
        // Exact historical binding only; no deadline, admission, current signer or provider read.
        if (
            !exists || a.chainId != block.chainid || a.saleAdapter != address(this)
                || a.mintManager != manager || a.collectionId != c.sale.collectionId
                || a.phaseId != c.sale.phaseId || a.saleKind != 6
                || a.revenueClass != keccak256("PRIMARY_SALE") || a.payer != c.buyer
                || a.asset != address(0) || a.unitPrice != c.sale.price || a.quantity != 1
                || a.primaryPolicyMode != c.sale.primaryPolicyMode
                || a.expectedPrimaryPolicyHash != c.sale.expectedPrimaryPolicyHash
                || a.policyHash != c.sale.mintPolicyHash || a.finalizeBy != 0
                || proof.authorizer != c.signer || proof.kind != c.signerKind
                || c.signer == address(0)
        ) revert InvalidPrimaryOffer();
        StreamPrivateSaleSupport.directOrSignature(
            proof.authorizer,
            proof.kind,
            StreamPrivateSaleHash.digest(
                block.chainid,
                address(this),
                StreamPrivateSaleHash.authorizationRevocationBody(
                    block.chainid, address(this), proof.authorizer, digest
                )
            ),
            proof.signature,
            StreamNativeCuratedSaleRuntime.gasParameter(SIGNATURE_GAS)
        );
    }
}

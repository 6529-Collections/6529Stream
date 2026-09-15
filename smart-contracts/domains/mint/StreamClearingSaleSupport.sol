// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamDutchSaleSupport.sol";
import "./StreamClearingSaleBook.sol";
import "../../interfaces/stream/mint/IStreamNativeClearingSale.sol";
import "../revenue/StreamNativeSupplementalRights.sol";
import "../revenue/StreamNativeSupplementalHash.sol";
import "../revenue/StreamPrimarySettlementHash.sol";

/// @notice Typed preparation and result verification for the clearing consumer's guarded context.
library StreamClearingSaleSupport {
    struct Prepared {
        StreamNativeSettlementTypes.NativeSettlementCandidate floor;
        IStreamMintManager.MintBatch batch;
        StreamDutchSaleSupport.Capture captured;
        uint256 schedulePrice;
        uint256 chargedPrice;
    }

    function authorizationDigest(IStreamNativeClearingSale.ClearingAuthorization memory a)
        public
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeClearingSale"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        bytes32 typeHash = keccak256(
            "ClearingAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 purchaseNonce,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash,uint256 unitPrice,bool hasPriceOverride,uint256 priceOverride,bytes32 windowPolicyHash,uint64 maximumNominalFinalizeBy,uint64 absoluteEscapeDeadline)"
        );
        return keccak256(abi.encodePacked(hex"1901", domain, keccak256(abi.encode(typeHash, a))));
    }

    function windowPolicyHash(IStreamNativeClearingSale.ClearingSaleConfig memory c)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CLEARING_WINDOW_POLICY_V1"),
                c.closesAt,
                c.finalizationWindowSeconds,
                c.absoluteEscapeDeadline,
                keccak256("OBSERVED_GLOBAL_OR_LOCAL_PAUSE_UNION"),
                keccak256("ABSOLUTE_ESCAPE_PAUSED_EQUALITY_UNPAUSED_FINALIZE_EQUALITY")
            )
        );
    }

    function validateConfig(
        StreamDutchSaleSupport.Context memory x,
        IStreamNativeClearingSale.ClearingSaleConfig memory c
    ) public view returns (bytes32 baseline) {
        if (
            c.primaryPolicyMode != 1 || c.finalizationWindowSeconds == 0
                || uint256(c.closesAt) + c.finalizationWindowSeconds > c.absoluteEscapeDeadline
        ) {
            revert IStreamNativeClearingSale.InvalidClearingSale();
        }
        (baseline,) = StreamDutchSaleSupport.validateConfig(
            x,
            IStreamNativeDutchSale.DutchSaleConfig(
                c.collectionId,
                c.phaseId,
                c.schedule,
                c.maxSaleQuantity,
                c.closesAt,
                false,
                c.mintPolicyHash
            )
        );
    }

    function prepare(
        StreamDutchSaleSupport.Context memory x,
        IStreamNativeClearingSale.ClearingSaleRecord memory sale,
        StreamClearingSaleBook.Sale memory financial,
        IStreamNativeClearingSale.ClearingPurchaseData memory d
    ) public view returns (Prepared memory p) {
        IStreamNativeClearingSale.ClearingAuthorization memory a = d.authorization;
        IStreamNativeClearingSale.ClearingSaleConfig memory config = sale.config;
        if (
            sale.saleNonce == 0 || sale.earlyCloseAt != 0 || financial.status != 1
                || financial.purchasedQuantity >= config.maxSaleQuantity
                || block.timestamp < config.schedule.startTime || block.timestamp > config.closesAt
        ) {
            revert IStreamNativeClearingSale.ClearingSaleUnavailable(a.saleId);
        }
        p.captured.consentEvidence = StreamDutchSaleSupport.requireSaleConsent(
            x, config.collectionId, a.saleId, sale.configHash
        );
        if (
            a.saleConfigHash != sale.configHash || a.payer == address(0) || a.payer == address(this)
                || a.executor == address(0) || a.recipient == address(0) || a.artist == address(0)
                || a.purchaseNonce == 0 || a.executionNonce == 0 || a.mintCommitment == 0
                || block.timestamp > a.deadline || a.tokenDataHash != keccak256(d.tokenData)
                || a.windowPolicyHash != sale.windowPolicyHash
                || uint256(config.closesAt) + config.finalizationWindowSeconds
                    > a.maximumNominalFinalizeBy
                || a.absoluteEscapeDeadline != config.absoluteEscapeDeadline
                || (!a.hasPriceOverride && a.priceOverride != 0)
                || (a.hasPriceOverride && a.priceOverride < config.schedule.restingPrice)
        ) {
            revert IStreamNativeClearingSale.InvalidClearingSale();
        }
        p.schedulePrice = StreamDutchPricing.price(config.schedule, block.timestamp);
        p.chargedPrice = a.hasPriceOverride && a.priceOverride < p.schedulePrice
            ? a.priceOverride
            : p.schedulePrice;
        if (a.unitPrice < p.chargedPrice) {
            revert IStreamNativeClearingSale.ClearingPriceAboveMaximum(a.unitPrice, p.chargedPrice);
        }
        p.captured.reveal = StreamDutchSaleSupport.revealPolicy(x, config.collectionId);
        p.captured.association = StreamDutchSaleSupport.artistAssociation(x, config.collectionId);
        StreamDutchSaleSupport.ArtistAssociation memory association = p.captured.association;
        if (
            association.state != 2 || association.authorityStatus != 1 || association.artistId == 0
                || association.generation == 0 || association.bindingHash == 0
                || (sale.artistId != 0
                    && (sale.artistId != association.artistId
                        || sale.bindingGeneration != association.generation
                        || sale.bindingHash != association.bindingHash))
        ) {
            revert IStreamNativeClearingSale.InvalidClearingSale();
        }
        // The selected/code-pinned facade was already admitted by the capped consent read.
        bytes memory signerData =
            abi.encodeCall(IStreamArtistAttribution.acceptedArtist, (config.collectionId));
        uint256 signer = _artistWord(address(x.artists), signerData, x.artistGas);
        if (signer != uint256(uint160(a.artist))) {
            revert IStreamNativeClearingSale.InvalidClearingSale();
        }
        bytes32 digest = authorizationDigest(a);
        if (!StreamNativeSettlementSupport.validSignature(
                x.platform, digest, d.platformSignature, x.signatureGas
            )) {
            revert IStreamNativeClearingSale.ClearingSignatureInvalid(x.platform);
        }
        if (!StreamNativeSettlementSupport.validSignature(
                a.artist, digest, d.artistSignature, x.signatureGas
            )) {
            revert IStreamNativeClearingSale.ClearingSignatureInvalid(a.artist);
        }
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c;
        c.saleAdapter = address(this);
        c.executor = a.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            a.saleId,
            keccak256("PRIMARY_SALE"),
            0,
            config.collectionId,
            0,
            sale.saleNonce,
            a.payer,
            address(0),
            a.recipient,
            config.schedule.restingPrice,
            a.expectedPrimaryPolicyHash
        );
        c.lifecycleBinding = sale.lifecycle;
        c.executionBinding =
            StreamPrimarySettlementTypes.SaleExecutionBinding(0, a.executionNonce, 1, digest);
        c.orchestrationOrder = 1;
        c.mintManager = address(x.manager);
        c.currentPolicyHash = IStreamMintReads(address(x.manager))
            .phasePolicyHash(config.collectionId, config.phaseId);
        c.boundPolicyHash = config.mintPolicyHash;
        if (c.currentPolicyHash != c.boundPolicyHash) {
            revert IStreamNativeClearingSale.InvalidClearingSale();
        }
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(x.resolver, config.collectionId);
        if (
            a.expectedPrimaryPolicyHash == 0
                || StreamSaleTemplate.policyHash(x.resolver, config.collectionId, rights)
                    != a.expectedPrimaryPolicyHash
        ) {
            revert IStreamNativeClearingSale.InvalidClearingSale();
        }
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            rights.profileId,
            rights.wallet,
            rights.templateId,
            rights.assignmentHash,
            rights.entriesHash
        );
        c.saleExecutionHash = keccak256(abi.encode(d));
        p.batch = _batch(a, config, d.tokenData, digest);
        bytes32[] memory ids;
        (c.operationIdentityCommitment, ids) =
            IStreamMintReads(address(x.manager)).previewSingleStepMintOperation(p.batch, "");
        if (c.operationIdentityCommitment == 0 || ids.length != 1 || ids[0] == 0) {
            revert IStreamNativeClearingSale.ClearingMintResultInvalid();
        }
        c.operationId = ids[0];
        c.executionBinding.executionId = StreamNativeSettlementHash.executionId(c);
        p.floor = c;
    }

    function _batch(
        IStreamNativeClearingSale.ClearingAuthorization memory a,
        IStreamNativeClearingSale.ClearingSaleConfig memory config,
        bytes memory tokenData,
        bytes32 digest
    ) private pure returns (IStreamMintManager.MintBatch memory b) {
        b.collectionId = config.collectionId;
        b.phaseId = config.phaseId;
        b.payer = a.payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = a.recipient;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = a.recipient;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = a.mintCommitment;
        b.expectedPolicyHash = config.mintPolicyHash;
        b.authorizationId =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
        b.contextHash = digest;
    }

    function _artistWord(address target, bytes memory data, uint256 cap)
        private
        view
        returns (uint256 word)
    {
        uint256 available = gasleft();
        if (available <= cap + cap / 63 + 20000) {
            revert StreamDutchSaleSupport.InsufficientDutchCallGas(cap, available);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32) revert IStreamNativeClearingSale.InvalidClearingSale();
    }

    function currentSupplementalRights(
        StreamPrimarySettlementRights.Context memory x,
        uint256 collectionId,
        uint256 tokenId
    )
        public
        view
        returns (StreamPrimarySettlementTypes.PrimaryRights memory rights, bytes32 policy)
    {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory
            a = x.resolver
        .resolvePrimaryAssignment(collectionId, tokenId, keccak256("PRIMARY_SALE"));
        StreamSaleTemplate.Selection memory r;
        if (a.assignmentType == 1) {
            r = StreamSaleTemplate.Selection(
                a.profileId,
                x.factory.walletFor(a.profileId),
                0,
                a.assignmentHash,
                x.factory.profileEntriesHash(a.profileId)
            );
        } else if (a.assignmentType == 2) {
            (r.profileId, r.wallet, r.entriesHash) =
                x.resolver.previewCollectionPrimaryProfile(a.templateId, collectionId, address(0));
            r.templateId = a.templateId;
            r.assignmentHash = a.assignmentHash;
        } else {
            revert IStreamNativeClearingSale.InvalidClearingSale();
        }
        rights = StreamPrimarySettlementTypes.PrimaryRights(
            r.profileId, r.wallet, r.templateId, r.assignmentHash, r.entriesHash
        );
        policy = StreamNativeSupplementalRights.policyHash(x.resolver, collectionId, tokenId, r);
        // Independent exact admitted resolver facts, scope, wallet, template profile and hash checks.
        StreamNativeSupplementalRights.resolve(x, collectionId, tokenId, rights, policy);
    }

    function settleSupplement(
        address recorder,
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c
    ) public returns (StreamNativeSupplementalTypes.NativeSupplementalResult memory result) {
        uint256 amount = c.purchase.buyerUniformPrice - c.purchase.floorPrice;
        bytes memory data = abi.encodeCall(
            IStreamNativeSupplementalSettlement.settleNativeSupplementalRevenueFromAdapter, (c)
        );
        bytes memory response = new bytes(512);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(gas(), recorder, amount, add(data, 32), mload(data), add(response, 32), 512)
            size := returndatasize()
        }
        if (!ok || size != 512) revert IStreamNativeClearingSale.ClearingSettlementResultInvalid();
        result = abi.decode(response, (StreamNativeSupplementalTypes.NativeSupplementalResult));
        bytes32 executionId = StreamNativeSupplementalHash.executionId(recorder, c);
        if (
            result.candidateCommitment
                    != StreamNativeSupplementalHash.candidateCommitment(recorder, c)
                || result.settlementKey
                    != StreamPrimarySettlementHash.settlementKey(
                        recorder, address(this), executionId
                    ) || result.purchaseId != c.purchaseId
                || result.originalFloorSettlementKey != c.purchase.floorSettlementKey
                || result.tokenId != c.purchase.tokenId
                || result.profileId != c.currentRights.profileId
                || result.wallet != c.currentRights.wallet || result.amount != amount
                || result.executor != c.executor || result.executionId != executionId
                || result.originalOperationRoot != c.originalFloor.operationIdentityCommitment
                || result.originalOperationId != c.purchase.originalOperationId
                || result.originalExpectedPrimaryPolicyHash
                    != c.originalFloor.sale.expectedPrimaryPolicyHash
                || result.currentPrimaryPolicyHash != c.currentPrimaryPolicyHash
                || result.policyDrift
                    != (c.originalFloor.sale.expectedPrimaryPolicyHash
                        != c.currentPrimaryPolicyHash)
        ) {
            revert IStreamNativeClearingSale.ClearingSettlementResultInvalid();
        }
        data = abi.encodeCall(
            IStreamNativeSupplementalSettlement.nativeSupplementalResult, (result.settlementKey)
        );
        assembly ("memory-safe") {
            ok := staticcall(gas(), recorder, add(data, 32), mload(data), add(response, 32), 512)
            size := returndatasize()
        }
        if (!ok || size != 512 || keccak256(response) != keccak256(abi.encode(result))) {
            revert IStreamNativeClearingSale.ClearingSettlementResultInvalid();
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamNativePricePrograms.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/mint/IStreamNativeFixedPriceSaleAdapter.sol";
import "../revenue/StreamNativeSettlementHash.sol";
import "../revenue/StreamNativeSettlementSupport.sol";
import "./StreamSaleArtist.sol";
import "../revenue/StreamPrimarySettlementHash.sol";
import "../../interfaces/stream/revenue/IStreamNativePrimarySaleSettlement.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";

/// @notice Linked native price preparation, exact recorder call and completion events.
/// @dev No storage or owner. Consumer supplies its immutable recorder; mutable library CALL rejects.
library StreamNativePriceProgram {
    struct Context {
        IStreamMintManager manager;
        IStreamRevenueResolver resolver;
        IStreamSplitFactory factory;
        bytes32 factoryHash;
        IStreamArtistAttribution artists;
        bytes32 artistHash;
        address platform;
    }
    bytes32 internal constant AUTHORIZATION_TYPEHASH = keccak256(
        "NativePriceProgramAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash,uint256 unitPrice)"
    );

    function authorizationDigest(IStreamNativePricePrograms.PriceProgramAuthorization memory a)
        public
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativePricePrograms"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        return keccak256(
            abi.encodePacked(hex"1901", domain, keccak256(abi.encode(AUTHORIZATION_TYPEHASH, a)))
        );
    }

    function validateConfig(
        Context memory x,
        IStreamNativePricePrograms.PriceProgramConfig memory c
    ) public view {
        if (
            c.collectionId == 0 || c.phaseId == 0 || c.mintPolicyHash == 0
                || (c.kind != 0 && c.kind != 1 && c.kind != 12 && c.kind != 13)
                || (c.kind == 1 ? c.maxSaleQuantity != 0 : c.maxSaleQuantity == 0)
                || (c.closeRule != 1 && c.closeRule != 2)
                || (c.closeRule == 1 && (c.endsAt <= c.startsAt || c.endsAt < block.timestamp))
                || (c.closeRule == 2 && c.endsAt != 0)
                || IStreamMintReads(address(x.manager)).phasePolicyHash(c.collectionId, c.phaseId)
                    != c.mintPolicyHash
        ) {
            revert IStreamNativePricePrograms.InvalidNativePriceProgram();
        }
        if (c.kind == 12) {
            if (c.minUnitPrice != 0 || c.maxUnitPrice != 0 || c.primaryAssignmentHash != 0) {
                revert IStreamNativePricePrograms.InvalidNativePriceProgram();
            }
        } else {
            if (
                c.maxUnitPrice == 0 || c.minUnitPrice > c.maxUnitPrice
                    || (c.kind != 13 && (c.minUnitPrice == 0 || c.minUnitPrice != c.maxUnitPrice))
            ) {
                revert IStreamNativePricePrograms.InvalidNativePriceProgram();
            }
            StreamSaleTemplate.Selection memory rights =
                StreamNativeSettlementSupport.rights(x.resolver, c.collectionId);
            if (rights.assignmentHash != c.primaryAssignmentHash) {
                revert IStreamNativePricePrograms.InvalidNativePriceProgram();
            }
        }
    }

    function prepare(
        Context memory x,
        IStreamNativePricePrograms.PriceProgramRecord memory record,
        IStreamNativePricePrograms.PriceProgramExecution memory e,
        bool paused
    )
        public
        view
        returns (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        )
    {
        IStreamNativePricePrograms.PriceProgramAuthorization memory a = e.authorization;
        IStreamNativePricePrograms.PriceProgramConfig memory config = record.config;
        if (
            paused || record.saleNonce == 0 || record.closed || block.timestamp < config.startsAt
                || (config.closeRule == 1 && block.timestamp > config.endsAt)
                || (config.maxSaleQuantity != 0 && record.mintedQuantity >= config.maxSaleQuantity)
        ) {
            revert IStreamNativePricePrograms.NativePriceProgramUnavailable(a.saleId);
        }
        if (
            a.saleConfigHash != record.configHash || a.payer == address(0)
                || a.executor == address(0) || a.recipient == address(0) || a.artist == address(0)
                || a.executionNonce == 0 || a.mintCommitment == 0 || block.timestamp > a.deadline
                || a.tokenDataHash != keccak256(e.tokenData)
        ) {
            revert IStreamNativePricePrograms.InvalidNativePriceProgram();
        }
        uint256 minimum = config.minUnitPrice;
        if (config.kind == 13) {
            if (a.unitPrice > minimum) minimum = a.unitPrice;
        } else if (a.unitPrice != minimum) {
            revert IStreamNativePricePrograms.InvalidNativePriceProgram();
        }
        if (e.chosenUnitPrice < minimum || e.chosenUnitPrice > config.maxUnitPrice) {
            revert IStreamNativePricePrograms.NativePriceOutsideBand(
                e.chosenUnitPrice, minimum, config.maxUnitPrice
            );
        }
        if (config.kind == 12 && a.expectedPrimaryPolicyHash != 0) {
            revert IStreamNativePricePrograms.InvalidNativePriceProgram();
        }
        StreamSaleArtist.requireArtist(x.artists, x.artistHash, config.collectionId, a.artist);
        bytes32 digest = authorizationDigest(a);
        uint256 cap = StreamNativeSettlementSupport.gasParameter(
            x.factory, x.factoryHash, keccak256("6529STREAM_GGP_ERC_1271_GAS_LIMIT")
        );
        if (!StreamNativeSettlementSupport.validSignature(
                x.platform, digest, e.platformSignature, cap
            )) {
            revert IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid(x.platform);
        }
        if (!StreamNativeSettlementSupport.validSignature(a.artist, digest, e.artistSignature, cap))
        {
            revert IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid(a.artist);
        }
        c.saleAdapter = address(this);
        c.executor = a.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            a.saleId,
            keccak256("PRIMARY_SALE"),
            0,
            config.collectionId,
            0,
            record.saleNonce,
            a.payer,
            address(0),
            a.recipient,
            e.chosenUnitPrice,
            a.expectedPrimaryPolicyHash
        );
        c.lifecycleBinding = record.lifecycle;
        c.executionBinding =
            StreamPrimarySettlementTypes.SaleExecutionBinding(0, a.executionNonce, 1, digest);
        c.orchestrationOrder = 1;
        c.mintManager = address(x.manager);
        c.currentPolicyHash = IStreamMintReads(address(x.manager))
            .phasePolicyHash(config.collectionId, config.phaseId);
        c.boundPolicyHash = config.mintPolicyHash;
        if (e.chosenUnitPrice != 0) {
            StreamSaleTemplate.Selection memory rights =
                StreamNativeSettlementSupport.rights(x.resolver, config.collectionId);
            if (
                a.expectedPrimaryPolicyHash == 0
                    || rights.assignmentHash != config.primaryAssignmentHash
                    || StreamSaleTemplate.policyHash(x.resolver, config.collectionId, rights)
                        != a.expectedPrimaryPolicyHash
            ) {
                revert IStreamNativePricePrograms.InvalidNativePriceProgram();
            }
            c.rights = StreamPrimarySettlementTypes.PrimaryRights(
                rights.profileId,
                rights.wallet,
                rights.templateId,
                rights.assignmentHash,
                rights.entriesHash
            );
        }
        c.saleExecutionHash = keccak256(abi.encode(e));
        batch.collectionId = config.collectionId;
        batch.phaseId = config.phaseId;
        batch.payer = a.payer;
        batch.initialRecipients = new address[](1);
        batch.initialRecipients[0] = a.recipient;
        batch.beneficiaries = new address[](1);
        batch.beneficiaries[0] = a.recipient;
        batch.tokenData = new bytes[](1);
        batch.tokenData[0] = e.tokenData;
        batch.mintCommitments = new bytes32[](1);
        batch.mintCommitments[0] = a.mintCommitment;
        batch.expectedPolicyHash = config.mintPolicyHash;
        batch.authorizationId =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
        batch.contextHash = digest;
        bytes32[] memory ids;
        (c.operationIdentityCommitment, ids) =
            IStreamMintReads(address(x.manager)).previewSingleStepMintOperation(batch, "");
        if (c.operationIdentityCommitment == 0 || ids.length != 1 || ids[0] == 0) {
            revert IStreamNativeFixedPriceSaleAdapter.NativeMintResultInvalid();
        }
        c.operationId = ids[0];
        c.executionBinding.executionId = StreamNativeSettlementHash.executionId(c);
    }
    event NativePriceProgramFreeMint(
        bytes32 indexed saleId,
        bytes32 indexed executionId,
        bytes32 indexed operationRoot,
        uint16 schemaVersion,
        bytes32 operationId,
        uint256 tokenId,
        address payer,
        address recipient,
        uint64 mintedQuantity
    );
    event NativePriceProgramPaidMint(
        bytes32 indexed saleId,
        bytes32 indexed executionId,
        bytes32 indexed operationRoot,
        uint16 schemaVersion,
        bytes32 operationId,
        uint256 tokenId,
        address payer,
        address recipient,
        uint256 chargedAmount,
        bytes32 settlementKey,
        bool escrowed,
        uint64 mintedQuantity
    );

    function emitCompletion(
        bytes32 id,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
        IStreamNativePricePrograms.PriceProgramResult memory r,
        uint64 mintedQuantity
    ) public {
        if (c.sale.amount == 0) {
            emit NativePriceProgramFreeMint(
                id,
                r.executionId,
                r.operationRoot,
                1,
                r.operationId,
                r.tokenId,
                c.sale.payer,
                c.sale.beneficiary,
                mintedQuantity
            );
        } else {
            emit NativePriceProgramPaidMint(
                id,
                r.executionId,
                r.operationRoot,
                1,
                r.operationId,
                r.tokenId,
                c.sale.payer,
                c.sale.beneficiary,
                c.sale.amount,
                r.settlementKey,
                r.escrowed,
                mintedQuantity
            );
        }
    }

    function settle(
        address primarySaleSettlement,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        bytes memory data = abi.encodeCall(
            IStreamNativePrimarySaleSettlement.settleNativePrimarySaleFromAdapter, (c)
        );
        bytes memory response = new bytes(384);
        address target = primarySaleSettlement;
        bool ok;
        uint256 size;
        uint256 amount = c.sale.amount;
        assembly ("memory-safe") {
            ok := call(gas(), target, amount, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384) revert IStreamNativeFixedPriceSaleAdapter.NativeSettlementFailed();
        result = abi.decode(response, (StreamPrimarySettlementTypes.PrimarySettlementResult));
        if (
            result.candidateCommitment
                    != StreamNativeSettlementHash.candidateCommitment(primarySaleSettlement, c)
                || result.settlementKey
                    != StreamPrimarySettlementHash.settlementKey(
                        primarySaleSettlement, address(this), c.executionBinding.executionId
                    ) || result.profileId != c.rights.profileId || result.wallet != c.rights.wallet
                || result.asset != address(0) || result.amount != c.sale.amount
                || result.executor != c.executor
                || result.executionId != c.executionBinding.executionId
                || result.operationIdentityCommitment != c.operationIdentityCommitment
                || result.currentPolicyHash != c.currentPolicyHash
                || result.boundPolicyHash != c.boundPolicyHash
        ) revert IStreamNativeFixedPriceSaleAdapter.NativeSettlementFailed();
        data = abi.encodeCall(IStreamPrimarySaleSettlement.settlementResult, (result.settlementKey));
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384 || keccak256(response) != keccak256(abi.encode(result))) {
            revert IStreamNativeFixedPriceSaleAdapter.NativeSettlementFailed();
        }
    }

    function prepareFixed(
        Context memory x,
        IStreamNativeFixedPriceSaleAdapter.SaleRecord memory record,
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
        bool paused,
        bool used,
        bytes32 priorExecution
    )
        public
        view
        returns (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        )
    {
        IStreamNativeFixedPriceSaleAdapter.SaleAuthorization memory a = e.authorization;
        if (
            paused || record.saleNonce == 0 || record.cancelled
                || block.timestamp < record.config.startsAt
                || block.timestamp > record.config.endsAt
        ) revert IStreamNativeFixedPriceSaleAdapter.NativeSaleUnavailable(a.saleId);
        if (
            a.saleConfigHash != record.configHash || a.payer == address(0)
                || a.executor == address(0) || a.recipient == address(0) || a.artist == address(0)
                || a.mintCommitment == 0 || a.executionNonce == 0
                || a.expectedPrimaryPolicyHash == 0 || a.tokenDataHash != keccak256(e.tokenData)
                || block.timestamp > a.deadline
        ) revert IStreamNativeFixedPriceSaleAdapter.InvalidNativeSale();
        if (used) {
            revert IStreamNativeFixedPriceSaleAdapter.NativeAuthorizationUsed(a.artist, a.nonce);
        }
        if (priorExecution != 0) {
            revert IStreamNativeFixedPriceSaleAdapter.NativeExecutionUsed(
                a.saleId, a.executionNonce
            );
        }
        bytes32 digest = _fixedAuthorizationDigest(a);
        StreamSaleArtist.requireArtist(
            x.artists, x.artistHash, record.config.collectionId, a.artist
        );
        if (!_fixedSignature(x, x.platform, digest, e.platformSignature)) {
            revert IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid(x.platform);
        }
        if (!_fixedSignature(x, a.artist, digest, e.artistSignature)) {
            revert IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid(a.artist);
        }
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(x.resolver, record.config.collectionId);
        if (
            StreamSaleTemplate.policyHash(x.resolver, record.config.collectionId, rights)
                    != a.expectedPrimaryPolicyHash
                || rights.assignmentHash != record.config.primaryAssignmentHash
        ) revert IStreamNativeFixedPriceSaleAdapter.InvalidNativeSale();
        c.saleAdapter = address(this);
        c.executor = a.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            a.saleId,
            keccak256("PRIMARY_SALE"),
            0,
            record.config.collectionId,
            0,
            record.saleNonce,
            a.payer,
            address(0),
            a.recipient,
            record.config.price,
            a.expectedPrimaryPolicyHash
        );
        c.lifecycleBinding = record.lifecycle;
        c.executionBinding =
            StreamPrimarySettlementTypes.SaleExecutionBinding(0, a.executionNonce, 1, digest);
        c.orchestrationOrder = 1;
        c.mintManager = address(x.manager);
        c.currentPolicyHash = IStreamMintReads(address(x.manager))
            .phasePolicyHash(record.config.collectionId, record.config.phaseId);
        c.boundPolicyHash = record.config.mintPolicyHash;
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            rights.profileId,
            rights.wallet,
            rights.templateId,
            rights.assignmentHash,
            rights.entriesHash
        );
        c.saleExecutionHash = keccak256(abi.encode(e));
        batch = _fixedBatch(a, record.config, e.tokenData, digest);
        bytes32[] memory ids;
        (c.operationIdentityCommitment, ids) =
            IStreamMintReads(address(x.manager)).previewSingleStepMintOperation(batch, "");
        if (c.operationIdentityCommitment == 0 || ids.length != 1 || ids[0] == 0) {
            revert IStreamNativeFixedPriceSaleAdapter.NativeMintResultInvalid();
        }
        c.operationId = ids[0];
        c.executionBinding.executionId = StreamNativeSettlementHash.executionId(c);
    }

    function _fixedBatch(
        IStreamNativeFixedPriceSaleAdapter.SaleAuthorization memory a,
        IStreamNativeFixedPriceSaleAdapter.SaleConfig memory config,
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

    function _fixedSignature(
        Context memory x,
        address signer,
        bytes32 digest,
        bytes memory signature
    ) private view returns (bool) {
        return StreamNativeSettlementSupport.validSignature(
            signer,
            digest,
            signature,
            StreamNativeSettlementSupport.gasParameter(
                x.factory, x.factoryHash, keccak256("6529STREAM_GGP_ERC_1271_GAS_LIMIT")
            )
        );
    }

    function _fixedAuthorizationDigest(
        IStreamNativeFixedPriceSaleAdapter.SaleAuthorization memory authorization
    ) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeFixedPriceSaleAdapter"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        return keccak256(
            abi.encodePacked(
                hex"1901",
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "NativeSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash)"
                        ),
                        authorization
                    )
                )
            )
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamERC20OfferHash.sol";
import "../../interfaces/stream/mint/StreamERC20OfferMintTypes.sol";
import "../../interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";
import "../../interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import "../../interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import "../../interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";
import "./StreamMintTranscriptTypes.sol";
import "./StreamImmediateSaleReveal.sol";
import "./StreamUniversalSaleRights.sol";
import "../revenue/StreamPreparedNativeSettlementAdmission.sol";
import "../revenue/StreamPrimarySettlementHash.sol";
import "../revenue/StreamPrimarySettlementRights.sol";
import "../../interfaces/stream/mint/IStreamPreparedNativeMint.sol";
import { IStreamERC20OfferSale } from "../../interfaces/stream/mint/IStreamERC20OfferMint.sol";

/// @notice Exact, already-funded order-one receipt required before the offer mint consumes state.
/// @dev Runs in Manager context. Signature/delegation admission and the operation transcript are
/// supplied by the Manager's offer path; this join grants no payment or prepared-mint authority.
library StreamERC20OfferReceipt {
    error InvalidERC20OfferReceipt();
    error ERC20OfferReceiptReadFailed(address target, bytes4 selector);
    error ERC20OfferNativeFeeRequired(uint256 amount);

    // ABI-equivalent to the carrier's Acceptance. Kept local to avoid coupling Manager to a
    // sale implementation. The single dynamic tuple wrapper is part of saleExecutionHash.
    struct SelectionWire {
        StreamPreparedNativeContentTypes.Selection content;
        bytes tokenData;
        bytes32 mintCommitment;
        uint256 executionNonce;
    }

    struct AcceptanceWire {
        StreamPrivateSaleTypes.SaleOffer offer;
        IStreamPrivateSaleAdapter.Signature buyerProof;
        StreamPrivateSaleTypes.SaleAuthorization authorization;
        IStreamPrivateSaleAdapter.Signature sellerProof;
        SelectionWire selection;
        IStreamNativeRefundDelegatedClaims.DelegationWitness signerDelegation;
        IStreamNativeRefundDelegatedClaims.DelegationWitness executorDelegation;
    }

    function requireReceipt(
        address core,
        address registry,
        address recorder,
        bytes32 recorderCodeHash,
        IStreamMintManager.MintBatch calldata batch,
        StreamERC20OfferMintTypes.GateData calldata d,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c,
        StreamMintTranscriptTypes.OperationTranscript memory t
    ) public view {
        _requireReceipt(core, registry, recorder, recorderCodeHash, batch, d, c, t);
    }

    /// @notice Decode only the original candidate's 34 static ABI words inside the linked worker.
    /// @dev The Manager's external typed ABI remains unchanged; no alternate candidate wire exists.
    function requireReceiptEncoded(
        address core,
        address registry,
        address recorder,
        bytes32 recorderCodeHash,
        IStreamMintManager.MintBatch calldata batch,
        StreamERC20OfferMintTypes.GateData calldata d,
        bytes calldata encodedCandidate,
        StreamMintTranscriptTypes.OperationTranscript memory t
    ) public view {
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory
            c = _decodeCandidate(encodedCandidate);
        _requireReceipt(core, registry, recorder, recorderCodeHash, batch, d, c, t);
    }

    /// @notice Decode the frozen execute selector's complete argument buffer in the linked worker.
    /// @dev The first two words point to batch/GateData tails after the 34-word static candidate.
    /// Decoding two dynamic types retains those original offsets; this does not redefine the ABI.
    function requireReceiptArguments(
        address core,
        address registry,
        address recorder,
        bytes32 recorderCodeHash,
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata arguments,
        StreamMintTranscriptTypes.OperationTranscript memory t
    ) public view {
        if (arguments.length < 36 * 32) {
            revert InvalidERC20OfferReceipt();
        }
        (
            IStreamMintManager.MintBatch memory decodedBatch,
            StreamERC20OfferMintTypes.GateData memory d
        ) = abi.decode(
            arguments, (IStreamMintManager.MintBatch, StreamERC20OfferMintTypes.GateData)
        );
        if (keccak256(abi.encode(decodedBatch)) != keccak256(abi.encode(batch))) {
            revert InvalidERC20OfferReceipt();
        }
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c =
            _decodeCandidate(arguments[64:1152]);
        _requireReceipt(core, registry, recorder, recorderCodeHash, batch, d, c, t);
    }

    function _decodeCandidate(bytes calldata encodedCandidate)
        private
        pure
        returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
    {
        if (encodedCandidate.length != 34 * 32) revert InvalidERC20OfferReceipt();
        c = abi.decode(encodedCandidate, (StreamPrimarySettlementTypes.ERC20SettlementCandidate));
        if (keccak256(encodedCandidate) != keccak256(abi.encode(c))) {
            revert InvalidERC20OfferReceipt();
        }
    }

    function _requireReceipt(
        address core,
        address registry,
        address recorder,
        bytes32 recorderCodeHash,
        IStreamMintManager.MintBatch calldata batch,
        StreamERC20OfferMintTypes.GateData memory d,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamMintTranscriptTypes.OperationTranscript memory t
    ) private view {
        _fields(core, batch, d, c, t);
        _saleFacts(batch, c);
        _bindings(core, registry, recorder, recorderCodeHash, c);
        _rights(recorder, c);
        _stored(recorder, c);
        IStreamImmediateSaleReveal.RevealQuote memory q =
            StreamImmediateSaleReveal.quote(core, batch.collectionId);
        if (q.policy.revealFeePerTokenWei != 0) {
            revert ERC20OfferNativeFeeRequired(q.policy.revealFeePerTokenWei);
        }
    }

    function _saleFacts(
        IStreamMintManager.MintBatch calldata batch,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) private view {
        bytes memory raw = _read(
            msg.sender,
            abi.encodeCall(
                IStreamERC20OfferSale.primaryOfferSettlementBinding, (c.sale.settlementId)
            ),
            96
        );
        (uint256 nonce, address poster, bytes32 configHash) =
            abi.decode(raw, (uint256, address, bytes32));
        if (
            keccak256(raw) != keccak256(abi.encode(nonce, poster, configHash))
                || nonce != c.sale.saleNonce || poster != c.sale.poster || configHash == 0
        ) revert InvalidERC20OfferReceipt();
        raw = _read(
            msg.sender,
            abi.encodeCall(
                IStreamERC20OfferSale.primaryOfferAuthorizationBinding, (c.sale.settlementId)
            ),
            160
        );
        (uint256 collection, bytes32 phase, address seller, uint8 kind, bytes32 signerConfig) =
            abi.decode(raw, (uint256, bytes32, address, uint8, bytes32));
        if (
            keccak256(raw) != keccak256(abi.encode(collection, phase, seller, kind, signerConfig))
                || collection != batch.collectionId || phase != batch.phaseId
                || seller == address(0) || (kind != 1 && kind != 2) || signerConfig != configHash
        ) revert InvalidERC20OfferReceipt();
    }

    function _fields(
        address core,
        IStreamMintManager.MintBatch calldata b,
        StreamERC20OfferMintTypes.GateData memory d,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamMintTranscriptTypes.OperationTranscript memory t
    ) private view {
        (bytes32 sellerDigest,) = StreamERC20OfferHash.validate(address(this), msg.sender, b, d);
        if (
            c.saleAdapter != msg.sender || c.mintManager != address(this) || d.offer.core != core
                || c.executor != d.executor || c.sale.settlementId != d.authorization.saleId
                || c.sale.revenueClass != keccak256("PRIMARY_SALE") || c.sale.policyMode != 0
                || c.sale.collectionId != b.collectionId || c.sale.tokenId != 0
                || c.sale.saleNonce == 0 || c.sale.payer != b.payer
                || c.sale.beneficiary != d.offer.buyer || c.sale.amount != d.offer.price
                || c.sale.amount == 0 || c.asset == address(0) || c.asset != d.offer.asset
                || c.sale.expectedPrimaryPolicyHash != d.authorization.expectedPrimaryPolicyHash
                || c.sale.expectedPrimaryPolicyHash == 0 || c.orchestrationOrder != 1
                || c.executionBinding.authorityMode != 1 || c.executionBinding.executionNonce == 0
                || c.executionBinding.saleAuthorizationDigest != sellerDigest
                || c.executionBinding.executionId != StreamPrimarySettlementHash.executionId(c)
                || t.quantity != 1 || t.operationIds.length != 1 || t.operationRoot == 0
                || t.operationIds[0] == 0 || c.operationIdentityCommitment != t.operationRoot
                || c.operationId != t.operationIds[0] || c.currentPolicyHash != t.currentPolicyHash
                || c.boundPolicyHash != t.boundPolicyHash || c.currentPolicyHash == 0
                || c.boundPolicyHash != b.expectedPolicyHash
                || t.authorization.authorizationId != b.authorizationId
                || t.authorization.authorizer != b.authorizer
                || uint8(t.authorization.authorizerKind) != d.buyerSignature.kind
        ) revert InvalidERC20OfferReceipt();
        AcceptanceWire memory a = AcceptanceWire(
            d.offer,
            d.buyerSignature,
            d.authorization,
            d.sellerSignature,
            SelectionWire(
                d.selection, b.tokenData[0], b.mintCommitments[0], c.executionBinding.executionNonce
            ),
            d.buyerDelegation,
            d.executorDelegation
        );
        if (c.saleExecutionHash != keccak256(abi.encode(a))) revert InvalidERC20OfferReceipt();
    }

    function _bindings(
        address core,
        address registry,
        address recorder,
        bytes32 recorderHash,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) private view {
        if (!StreamSettlementAdmission.isContract(recorder) || recorder.codehash != recorderHash) {
            revert InvalidERC20OfferReceipt();
        }
        bytes memory raw = _read(
            address(this), abi.encodeCall(IStreamPreparedNativeMint.preparedNativeRecorder, ()), 128
        );
        (address selected, bytes32 selectedHash, uint64 boundAt, uint64 revision) =
            abi.decode(raw, (address, bytes32, uint64, uint64));
        if (
            selected != recorder || selectedHash != recorderHash
                || keccak256(raw)
                    != keccak256(abi.encode(selected, selectedHash, boundAt, revision))
        ) revert InvalidERC20OfferReceipt();
        StreamPreparedNativeSettlementAdmission.requireRecorder(
            registry, recorder, boundAt, revision
        );
        StreamSettlementAdmission.requireRegistry(
            core,
            bytes32(_word(recorder, "coreCodeHash()")),
            registry,
            bytes32(_word(recorder, "moduleRegistryCodeHash()"))
        );
        address payment = c.lifecycleBinding.paymentAdapter;
        address resolver = _address(recorder, "revenueResolver()");
        if (
            _address(recorder, "core()") != core
                || _address(recorder, "moduleRegistry()") != registry
                || _address(msg.sender, "primarySaleSettlement()") != recorder
                || bytes32(_word(msg.sender, "settlementCodeHash()")) != recorderHash
                || _address(msg.sender, "core()") != core
                || _address(msg.sender, "moduleRegistry()") != registry
                || _address(msg.sender, "mintManager()") != address(this)
                || _address(msg.sender, "revenueResolver()") != resolver
                || _address(payment, "primarySaleSettlement()") != recorder
                || bytes32(_word(payment, "settlementCodeHash()")) != recorderHash
                || _address(payment, "core()") != core
                || _address(payment, "moduleRegistry()") != registry
                || _address(payment, "revenueResolver()") != resolver || c.sale.payer == recorder
                || c.sale.payer == payment || c.sale.payer == c.rights.wallet
                || c.sale.payer == _address(recorder, "revenueEscrow()")
        ) revert InvalidERC20OfferReceipt();
        StreamSettlementAdmission.requireAdmission(registry, payment, c);
    }

    function _rights(
        address recorder,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) private view {
        address resolver = _address(recorder, "revenueResolver()");
        address factory = _address(recorder, "splitFactory()");
        address assets = _address(recorder, "assetPolicyRegistry()");
        if (
            resolver.codehash != bytes32(_word(recorder, "resolverCodeHash()"))
                || factory.codehash != bytes32(_word(recorder, "factoryCodeHash()"))
                || assets.codehash != bytes32(_word(recorder, "assetRegistryCodeHash()"))
                || !StreamSettlementAdmission.isContract(c.asset) || c.rights.templateId != 0
        ) revert InvalidERC20OfferReceipt();
        StreamSaleTemplate.Selection memory rights = StreamUniversalSaleRights.rights(
            IStreamRevenueResolver(resolver), IStreamSplitFactory(factory), c.sale.collectionId
        );
        if (
            keccak256(abi.encode(rights)) != keccak256(abi.encode(c.rights))
                || StreamSaleTemplate.policyHash(
                        IStreamRevenueResolver(resolver), c.sale.collectionId, rights
                    ) != c.sale.expectedPrimaryPolicyHash
        ) revert InvalidERC20OfferReceipt();
        StreamPrimarySettlementRights.requireWallet(
            StreamPrimarySettlementRights.Context(
                IStreamRevenueResolver(resolver),
                IStreamSplitFactory(factory),
                bytes32(_word(recorder, "walletCodeHash()"))
            ),
            rights
        );
        uint256 cap = abi.decode(
            _read(
                factory,
                abi.encodeCall(
                    IStreamGasParameterHost.gasParameter,
                    (keccak256("6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT"))
                ),
                32
            ),
            (uint256)
        );
        if (cap == 0 || cap > type(uint64).max || gasleft() <= cap + cap / 63 + 40_000) {
            revert InvalidERC20OfferReceipt();
        }
        bytes memory data = abi.encodeCall(IStreamAssetPolicyRegistry.assetStatus, (c.asset));
        uint256 value;
        uint256 size;
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(cap, assets, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            value := mload(0)
        }
        if (!ok || size != 32 || value != 1) revert InvalidERC20OfferReceipt();
    }

    function _stored(
        address recorder,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) private view {
        bytes32 key = StreamPrimarySettlementHash.settlementKey(
                recorder, msg.sender, c.executionBinding.executionId
            );
        if (
            abi.decode(
                    _read(
                        recorder,
                        abi.encodeCall(IStreamPrimarySaleSettlement.settlementConsumed, (key)),
                        32
                    ),
                    (uint256)
                ) != 1
        ) {
            revert InvalidERC20OfferReceipt();
        }
        bytes memory raw = _read(
            recorder, abi.encodeCall(IStreamPrimarySaleSettlement.settlementResult, (key)), 384
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
            abi.decode(raw, (StreamPrimarySettlementTypes.PrimarySettlementResult));
        if (
            keccak256(raw) != keccak256(abi.encode(r))
                || r.candidateCommitment
                    != StreamPrimarySettlementHash.candidateCommitment(
                        c.lifecycleBinding.paymentAdapter, recorder, c
                    ) || r.settlementKey != key || r.profileId != c.rights.profileId
                || r.wallet != c.rights.wallet || r.asset != c.asset || r.amount != c.sale.amount
                || r.executor != c.executor || r.executionId != c.executionBinding.executionId
                || r.operationIdentityCommitment != c.operationIdentityCommitment
                || r.currentPolicyHash != c.currentPolicyHash
                || r.boundPolicyHash != c.boundPolicyHash
        ) revert InvalidERC20OfferReceipt();
    }

    function _address(address target, string memory signature) private view returns (address) {
        uint256 value = _word(target, signature);
        if (value == 0 || value > type(uint160).max) revert InvalidERC20OfferReceipt();
        return address(uint160(value));
    }

    function _word(address target, string memory signature) private view returns (uint256) {
        return abi.decode(_read(target, abi.encodeWithSignature(signature), 32), (uint256));
    }

    function _read(address target, bytes memory data, uint256 length)
        private
        view
        returns (bytes memory raw)
    {
        raw = new bytes(length);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(raw, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert ERC20OfferReceiptReadFailed(target, bytes4(data));
    }
}

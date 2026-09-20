// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamPrimaryOfferDelegationManifest } from "./StreamPrimaryOfferDelegationManifest.sol";

import "./StreamERC20PrimaryOfferExecution.sol";
import "./StreamImmediateSaleReveal.sol";
import { StreamNativeAuctionDelegation as D } from "../auctions/StreamNativeAuctionDelegation.sol";

/// @notice Fixed execution flow under the carrier's guard and preconsumed seller digest.
/// @dev Context is constructed only from carrier immutables. There is no arbitrary call surface.
library StreamERC20PrimaryOfferRuntime {
    struct Context {
        StreamERC20PrimaryOfferSupport.Context base;
        address recorder;
        address assets;
        bytes32 coreHash;
        bytes32 registryHash;
        bytes32 resolverHash;
        bytes32 factoryHash;
        bytes32 assetsHash;
        bytes32 managerHash;
        bytes32 recorderHash;
    }
    bytes32 private constant SIGNATURE_GAS = keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT");
    bytes32 private constant REVEAL_GAS = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
    error InvalidERC20PrimaryOffer();
    error InvalidERC20PrimaryOfferDeployment();
    error ERC20PrimaryOfferNativeFeeUnsupported(uint256 requiredWei);
    event OfferAccepted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        bytes32 offerDigest,
        uint256 price,
        address asset
    );
    event PrimaryOfferExecution(bytes32 indexed executionId, Offer.ExecutionRecord execution);
    event PrimaryOfferConfigured(
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        uint256 saleNonce,
        Offer.Configuration configuration
    );

    function register(
        StreamERC20PrimaryOfferState.State storage state,
        Context memory x,
        Offer.Configuration memory c,
        bytes32[] memory proof
    ) public returns (bytes32 id) {
        requireContext(x);
        requireActive(x, c.asset);
        zeroFee(x.base.core, c.collectionId);
        IStreamNativeRefundDelegatedClaims.DelegationConfiguration memory dc =
            IStreamERC20OfferSale(address(this)).offerDelegationConfiguration();
        if (dc.registry != address(0)) {
            D.requireManifest(
                D.Configuration(
                    dc.chainId,
                    dc.core,
                    dc.registry,
                    dc.registryCodeHash,
                    dc.usecase,
                    dc.baseManifestHash,
                    dc.moduleRegistry,
                    dc.moduleRegistryCodeHash
                ),
                _gas(D.GAS_PARAMETER)
            );
        }
        if (
            _word(c.paymentAdapter, "primarySaleSettlement()") != uint256(uint160(x.recorder))
                || _word(c.paymentAdapter, "core()") != uint256(uint160(x.base.core))
                || _word(c.paymentAdapter, "moduleRegistry()") != uint256(uint160(x.base.registry))
                || _word(c.paymentAdapter, "revenueResolver()")
                    != uint256(uint160(address(x.base.resolver)))
        ) revert InvalidERC20PrimaryOffer();
        id = StreamERC20PrimaryOfferSupport.register(state, x.base, c, proof);
        emit PrimaryOfferConfigured(id, state.sales[id].configHash, state.sales[id].saleNonce, c);
    }

    function preview(
        StreamERC20PrimaryOfferState.State storage state,
        Context memory x,
        Offer.Acceptance memory q
    ) public view returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c) {
        (c,,) = candidate(state, x, q);
    }

    function execute(
        StreamERC20PrimaryOfferState.State storage state,
        Context memory x,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata supplied,
        bytes calldata data
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        Offer.Acceptance memory q = abi.decode(data, (Offer.Acceptance));
        if (keccak256(data) != keccak256(abi.encode(q))) revert InvalidERC20PrimaryOffer();
        (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            IStreamMintManager.MintBatch memory b,
            StreamERC20OfferMintTypes.GateData memory d
        ) = candidate(state, x, q);
        if (
            msg.sender != c.lifecycleBinding.paymentAdapter
                || keccak256(abi.encode(c)) != keccak256(abi.encode(supplied))
        ) revert InvalidERC20PrimaryOffer();
        IStreamImmediateSaleReveal.RevealQuote memory quote =
            zeroFee(x.base.core, c.sale.collectionId);
        uint256 revealGas = _gas(REVEAL_GAS);
        StreamImmediateSaleReveal.preflight(quote, 0, revealGas);
        bytes32 id = c.sale.settlementId;
        state.executionNonces[id][c.sale.payer] = q.selection.executionNonce;
        result = StreamERC20PrimaryOfferExecution.settle(x.recorder, c);
        requireLive(state, x, q, c);
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) =
            IStreamERC20OfferMint(address(x.base.manager)).executeERC20OfferMint(b, d, c);
        if (
            tokens.length != 1 || tokens[0] == 0 || root != c.operationIdentityCommitment
                || ids.length != 1 || ids[0] != c.operationId
        ) revert InvalidERC20PrimaryOffer();
        StreamImmediateSaleReveal.fundAndAttempt(
            x.base.core, c.sale.collectionId, tokens[0], quote, revealGas
        );
        requireLive(state, x, q, c);
        Offer.ExecutionRecord memory e = Offer.ExecutionRecord(
            id,
            c.sale.payer,
            c.executor,
            q.selection.executionNonce,
            state.sales[id].config.offerDigest,
            c.executionBinding.saleAuthorizationDigest,
            b.authorizationId,
            q.offer.contentSelectionHash,
            keccak256(q.selection.tokenData),
            tokens[0],
            result.settlementKey,
            root,
            ids[0]
        );
        state.executions[c.executionBinding.executionId] = e;
        state.sales[id].status = 4;
        emit PrimaryOfferExecution(c.executionBinding.executionId, e);
        emit OfferAccepted(1, id, c.sale.payer, e.offerDigest, c.sale.amount, c.asset);
    }

    function candidate(
        StreamERC20PrimaryOfferState.State storage state,
        Context memory x,
        Offer.Acceptance memory q
    )
        private
        view
        returns (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            IStreamMintManager.MintBatch memory b,
            StreamERC20OfferMintTypes.GateData memory d
        )
    {
        requireContext(x);
        Offer.Configuration storage config = state.sales[q.authorization.saleId].config;
        requireActive(x, config.asset);
        zeroFee(x.base.core, config.collectionId);
        requireDelegates(config.buyer, q);
        return StreamERC20PrimaryOfferExecution.candidate(state, x.base, q, _gas(SIGNATURE_GAS));
    }

    function requireLive(
        StreamERC20PrimaryOfferState.State storage state,
        Context memory x,
        Offer.Acceptance memory q,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) private view {
        requireContext(x);
        requireActive(x, c.asset);
        StreamERC20PrimaryOfferSupport.requireSale(state, x.base, c.sale.settlementId);
        requireDelegates(c.sale.payer, q);
        StreamSettlementAdmission.requireAdmission(
            x.base.registry, c.lifecycleBinding.paymentAdapter, c
        );
        if (
            keccak256(
                    abi.encode(
                        StreamERC20PrimaryOfferSupport.rights(
                            x.base, state.sales[c.sale.settlementId].config
                        )
                    )
                ) != keccak256(abi.encode(c.rights))
        ) revert InvalidERC20PrimaryOffer();
    }

    function requireContext(Context memory x) private view {
        StreamSettlementAdmission.requireRegistry(
            x.base.core, x.coreHash, x.base.registry, x.registryHash
        );
        if (
            address(x.base.resolver).codehash != x.resolverHash
                || address(x.base.factory).codehash != x.factoryHash
                || x.assets.codehash != x.assetsHash
                || address(x.base.manager).codehash != x.managerHash
                || x.recorder.codehash != x.recorderHash
                || address(x.base.artists).codehash != x.base.artistsHash
                || x.base.resolver.artistRegistry() != address(x.base.artists)
        ) revert InvalidERC20PrimaryOfferDeployment();
    }

    function requireActive(Context memory x, address asset) private view {
        uint256 cap =
            x.base.factory.gasParameter(keccak256("6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT"));
        if (!StreamSettlementAdmission.isContract(asset) || cap == 0 || cap > type(uint64).max) {
            revert InvalidERC20PrimaryOffer();
        }
        bytes memory data = abi.encodeCall(IStreamAssetPolicyRegistry.assetStatus, (asset));
        uint256 available = gasleft();
        if (cap > available || available - cap < (cap + 62) / 63 + 40_000) {
            revert InvalidERC20PrimaryOffer();
        }
        address target = x.assets;
        uint256 word;
        uint256 size;
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32 || word != 1) revert InvalidERC20PrimaryOffer();
    }

    function requireDelegates(address buyer, Offer.Acceptance memory q) private view {
        if (buyer == address(0) || buyer == address(this)) revert InvalidERC20PrimaryOffer();
        if (q.authorization.executor == buyer && q.buyerProof.authorizer == buyer) return;
        IStreamNativeRefundDelegatedClaims.DelegationConfiguration memory dc =
            IStreamERC20OfferSale(address(this)).offerDelegationConfiguration();
        D.Configuration memory c = D.Configuration(
            dc.chainId,
            dc.core,
            dc.registry,
            dc.registryCodeHash,
            dc.usecase,
            dc.baseManifestHash,
            dc.moduleRegistry,
            dc.moduleRegistryCodeHash
        );
        uint256 cap = _gas(D.GAS_PARAMETER);
        StreamPrimaryOfferDelegationManifest.requireERC20(
            c, address(this), q.authorization.saleId, cap
        );
        if (q.authorization.executor != buyer) {
            D.requireDelegated(
                c,
                buyer,
                q.authorization.executor,
                D.Witness(q.executorDelegation.walletWide, q.executorDelegation.index),
                cap
            );
        }
        if (q.buyerProof.authorizer != buyer) {
            D.requireDelegated(
                c,
                buyer,
                q.buyerProof.authorizer,
                D.Witness(q.signerDelegation.walletWide, q.signerDelegation.index),
                cap
            );
        }
    }

    function zeroFee(address core, uint256 collection)
        public
        view
        returns (IStreamImmediateSaleReveal.RevealQuote memory q)
    {
        q = StreamImmediateSaleReveal.quote(core, collection);
        if (q.policy.revealFeePerTokenWei != 0) {
            revert ERC20PrimaryOfferNativeFeeUnsupported(q.policy.revealFeePerTokenWei);
        }
    }

    function _gas(bytes32 id) private view returns (uint256) {
        return IStreamGasParameterHost(address(this)).gasParameter(id);
    }

    function _word(address target, string memory signature) private view returns (uint256 word) {
        bytes memory data = abi.encodeWithSignature(signature);
        uint256 size;
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32) revert InvalidERC20PrimaryOffer();
    }
}

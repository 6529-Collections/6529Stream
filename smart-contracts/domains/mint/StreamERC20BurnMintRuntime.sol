// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSaleArtist.sol";
import "./StreamERC20BurnMintSupport.sol";
import "./StreamSaleConsent.sol";
import "./StreamUniversalSaleRights.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import "./StreamSaleTemplate.sol";
import "../revenue/StreamSettlementContext.sol";
import "../revenue/StreamPrimarySettlementHash.sol";
import "../../interfaces/stream/mint/IStreamERC20BurnMintSale.sol";
import "../../interfaces/stream/mint/IStreamERC20BurnMintGate.sol";
import "./StreamImmediateSaleReveal.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../interfaces/standards/IERC5267.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

import "./StreamERC20BurnMintState.sol";

/// @notice Fixed linked burn orchestration; the carrier reserves replay before entering this worker.
/// @dev No caller-controlled target or delegate payload. Context contains only carrier immutables.
library StreamERC20BurnMintRuntime {
    struct Context {
        IStreamMintManager mintManager;
        IStreamRevenueResolver revenueResolver;
        IStreamSplitFactory splitFactory;
        IStreamArtistAttribution artistRegistry;
        IStreamAssetPolicyRegistry assetPolicyRegistry;
        address core;
        address moduleRegistry;
        address primarySaleSettlement;
        address platformSigner;
        bytes32 artistRegistryCodeHash;
        bytes32 mintManagerCodeHash;
        bytes32 settlementCodeHash;
        bytes32 coreCodeHash;
        bytes32 moduleRegistryCodeHash;
        bytes32 resolverCodeHash;
        bytes32 factoryCodeHash;
        bytes32 assetRegistryCodeHash;
    }
    error InvalidUniversalSale();
    error UniversalSaleUnavailable(bytes32 saleId);
    error UniversalAuthorizationUsed(address artist, bytes32 nonce);
    error UniversalExecutionUsed(bytes32 saleId, uint256 executionNonce);
    error UniversalSaleSignatureInvalid(address signer);
    error UniversalCandidateMismatch();
    error UniversalSettlementFailed();
    error UniversalMintResultInvalid();
    error BurnMintNativeFeeUnsupported(uint256 requiredWei);
    error BurnMintContinuationUnavailable();

    event UniversalSaleConfigured(
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint16 schemaVersion,
        uint256 saleNonce,
        bytes32 configHash,
        address paymentAdapter
    );
    event UniversalSaleCancelled(bytes32 indexed saleId, uint16 schemaVersion);
    event UniversalSalesPaused(uint16 schemaVersion, bool paused);
    event UniversalAuthorizationCancelled(
        address indexed artist, bytes32 indexed nonce, uint16 schemaVersion
    );
    event UniversalSaleExecution(
        bytes32 indexed saleId,
        bytes32 indexed executionId,
        bytes32 indexed operationRoot,
        uint16 schemaVersion,
        uint8 status,
        bytes32 settlementKey,
        uint256 tokenId
    );
    error InvalidSettlementContext(address target);
    error InsufficientSettlementCallGas(uint256 cap);
    error SettlementReadFailed(address target, bytes4 selector);
    error SettlementAssetNotActive(address asset);
    bytes32 private constant _DEPOSIT_GAS = keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT");
    bytes32 private constant _ASSET_GAS = keccak256("6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT");
    bytes32 private constant _SIGNATURE_GAS = keccak256("6529STREAM_GGP_ERC_1271_GAS_LIMIT");
    bytes32 private constant SALE_AUTHORIZATION_TYPEHASH = keccak256(
        "UniversalSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline)"
    );
    bytes32 private constant _DOMAIN = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant _CONFIG = keccak256("6529STREAM_UNIVERSAL_FIXED_PRICE_CONFIG_V1");
    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant _TICKET_AUTHORIZATION =
        keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1");
    bytes32 private constant REVEAL_GAS = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");

    function registerSale(
        StreamERC20BurnMintState.State storage s,
        Context memory x,
        U.SaleConfig memory config
    ) public returns (bytes32 saleId) {
        _requireSaleContext(x);
        if (
            config.collectionId == 0 || config.phaseId == 0 || config.price == 0
                || config.endsAt <= config.startsAt || config.endsAt < block.timestamp
                || config.mintPolicyHash == 0 || config.expectedPrimaryPolicyHash == 0
                || IStreamMintReads(address(x.mintManager))
                        .phasePolicyHash(config.collectionId, config.phaseId)
                    != config.mintPolicyHash
        ) revert InvalidUniversalSale();
        _requireActive(x, config.asset);
        _zeroFee(x, config.collectionId);
        StreamERC20BurnMintSupport.GateBinding memory gate =
            StreamERC20BurnMintSupport.registrationGate(
                config, x.mintManager, x.core, x.mintManagerCodeHash
            );
        StreamSaleTemplate.Selection memory rights = _rights(x, config.collectionId);
        if (
            StreamSaleTemplate.policyHash(x.revenueResolver, config.collectionId, rights)
                != config.expectedPrimaryPolicyHash
        ) revert InvalidUniversalSale();
        StreamPrimarySettlementTypes.SaleLifecycleBinding memory binding =
            StreamSettlementAdmission.capture(
                x.moduleRegistry, address(this), config.paymentAdapter
            );
        if (
            _read(
                        config.paymentAdapter,
                        abi.encodeWithSignature("primarySaleSettlement()"),
                        gasleft()
                    ) != uint256(uint160(x.primarySaleSettlement))
                || _read(config.paymentAdapter, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(x.core))
        ) revert InvalidUniversalSale();
        uint256 nonce = s.nextSaleNonce++;
        saleId = saleIdFor(config.collectionId, config.phaseId, nonce);
        bytes32 hash = keccak256(abi.encode(_CONFIG, saleId, config));
        s.sales[saleId] = U.SaleRecord(config, nonce, hash, binding, false);
        s.saleBurnGate[saleId] = gate;
        emit UniversalSaleConfigured(
            saleId, config.collectionId, config.phaseId, 1, nonce, hash, config.paymentAdapter
        );
    }

    function previewExecution(
        StreamERC20BurnMintState.State storage s,
        Context memory x,
        E.Execution memory e
    ) public returns (S.ERC20SettlementCandidate memory c) {
        address gate = s.saleBurnGate[e.sale.authorization.saleId].gate;
        s.active = StreamERC20BurnMintState.Continuation(
            gate, keccak256(abi.encode(e)), 0, 0, 0, 1, false
        );
        (, IStreamMintManager.MintBatch memory batch) = _baseCandidate(s, x, e);
        c = IStreamERC20BurnMintGate(gate).previewERC20Burn(batch, e);
        delete s.active;
    }

    function previewBurnExecution(
        StreamERC20BurnMintState.State storage s,
        Context memory x,
        E.Execution memory e
    ) public view returns (S.ERC20SettlementCandidate memory c) {
        (c,) = _candidate(s, x, e);
    }

    function execute(
        StreamERC20BurnMintState.State storage s,
        Context memory x,
        E.Execution memory e
    ) public returns (S.PrimarySettlementResult memory) {
        (, IStreamMintManager.MintBatch memory batch) = _baseCandidate(s, x, e);
        S.ERC20SettlementCandidate memory expected =
            IStreamERC20BurnMintGate(s.active.gate).previewERC20Burn(batch, e);
        if (keccak256(abi.encode(expected)) != s.active.candidateHash) {
            revert UniversalCandidateMismatch();
        }
        emit UniversalSaleExecution(
            e.sale.authorization.saleId,
            expected.executionBinding.executionId,
            expected.operationIdentityCommitment,
            1,
            1,
            0,
            0
        );
        s.active.mode = 2;
        E.Result memory completed =
            IStreamERC20BurnMintGate(s.active.gate).executeERC20Burn(batch, e);
        if (s.active.mode != 4 || keccak256(abi.encode(completed)) != s.active.resultHash) {
            revert UniversalMintResultInvalid();
        }
        _requireLive(s, x, e, expected);
        s.executionStatus[expected.executionBinding.executionId] = 2;
        delete s.active;
        emit UniversalSaleExecution(
            e.sale.authorization.saleId,
            expected.executionBinding.executionId,
            completed.operationRoot,
            1,
            2,
            completed.settlement.settlementKey,
            completed.tokenId
        );
        return completed.settlement;
    }

    function finish(
        StreamERC20BurnMintState.State storage s,
        Context memory x,
        E.Execution memory e
    ) public returns (E.Result memory out) {
        (S.ERC20SettlementCandidate memory c, IStreamMintManager.MintBatch memory batch) =
            _candidate(s, x, e);
        if (!s.active.paidExecution || keccak256(abi.encode(c)) != s.active.candidateHash) {
            revert UniversalCandidateMismatch();
        }
        IStreamImmediateSaleReveal.RevealQuote memory quote = _zeroFee(x, batch.collectionId);
        uint256 cap = IStreamGasParameterHost(address(this)).gasParameter(REVEAL_GAS);
        StreamImmediateSaleReveal.preflight(quote, 0, cap);
        out.settlement = StreamERC20BurnMintSupport.settle(x.primarySaleSettlement, c);
        _requireLive(s, x, e, c);
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) =
            x.mintManager.executeSingleStepMint(batch, "");
        if (
            tokens.length != 1 || tokens[0] == 0 || root != c.operationIdentityCommitment
                || ids.length != 1 || ids[0] != c.operationId
        ) revert UniversalMintResultInvalid();
        out.tokenId = tokens[0];
        out.operationRoot = root;
        out.operationId = ids[0];
        StreamImmediateSaleReveal.fundAndAttempt(x.core, batch.collectionId, tokens[0], quote, cap);
        _requireLive(s, x, e, c);
        s.active.resultHash = keccak256(abi.encode(out));
        s.active.mode = 4;
    }

    function _candidate(
        StreamERC20BurnMintState.State storage s,
        Context memory x,
        E.Execution memory e
    )
        private
        view
        returns (S.ERC20SettlementCandidate memory c, IStreamMintManager.MintBatch memory batch)
    {
        (c, batch) = _baseCandidate(s, x, e);
        bytes32[] memory ids;
        (c.operationIdentityCommitment, ids) =
            IStreamMintReads(address(x.mintManager)).previewSingleStepMintOperation(batch, "");
        if (c.operationIdentityCommitment == 0 || ids.length != 1 || ids[0] == 0) {
            revert UniversalMintResultInvalid();
        }
        c.operationId = ids[0];
        c.executionBinding.executionId = StreamPrimarySettlementHash.executionId(c);
        StreamSettlementAdmission.requireAdmission(
            x.moduleRegistry, c.lifecycleBinding.paymentAdapter, c
        );
    }

    function _baseCandidate(
        StreamERC20BurnMintState.State storage s,
        Context memory x,
        E.Execution memory execution
    )
        private
        view
        returns (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        )
    {
        _requireSaleContext(x);
        U.SaleExecutionData memory e = execution.sale;
        U.SaleAuthorization memory a = e.authorization;
        U.SaleRecord storage record = s.sales[a.saleId];
        if (
            s.paused || record.saleNonce == 0 || record.cancelled
                || block.timestamp < record.config.startsAt
                || block.timestamp > record.config.endsAt
        ) revert UniversalSaleUnavailable(a.saleId);
        _requireConsent(s, x, a.saleId);
        if (
            a.saleConfigHash != record.configHash || a.payer == address(0)
                || a.executor == address(0) || a.recipient == address(0) || a.artist == address(0)
                || a.mintCommitment == 0 || a.executionNonce == 0 || e.tokenData.length > 8192
                || a.tokenDataHash != keccak256(e.tokenData) || block.timestamp > a.deadline
                || a.deadline > record.config.endsAt
        ) revert InvalidUniversalSale();
        if (s.authorizationUsed[a.artist][a.nonce] && !_matchingPaid(s, x, execution)) {
            revert UniversalAuthorizationUsed(a.artist, a.nonce);
        }
        if (
            s.executionIdByNonce[a.saleId][a.executionNonce] != 0 && !_matchingPaid(s, x, execution)
        ) {
            revert UniversalExecutionUsed(a.saleId, a.executionNonce);
        }
        _requireGate(s, x, a.saleId);
        _zeroFee(x, record.config.collectionId);
        bytes32 digest = _authorizationDigest(a);
        _requireActive(x, record.config.asset);
        return StreamERC20BurnMintSupport.candidate(
            StreamERC20BurnMintSupport.Context(
                x.mintManager,
                x.revenueResolver,
                x.splitFactory,
                x.artistRegistry,
                x.artistRegistryCodeHash,
                x.platformSigner,
                _gas(x, _SIGNATURE_GAS)
            ),
            record,
            execution,
            digest
        );
    }

    function _matchingPaid(
        StreamERC20BurnMintState.State storage s,
        Context memory x,
        E.Execution memory e
    ) private view returns (bool) {
        return s.active.paidExecution && s.active.executionHash == keccak256(abi.encode(e))
            && s.executionIdByNonce[
                    e.sale.authorization.saleId
                ][e.sale.authorization.executionNonce] == s.active.executionId;
    }

    function _requireLive(
        StreamERC20BurnMintState.State storage s,
        Context memory x,
        E.Execution memory e,
        S.ERC20SettlementCandidate memory c
    ) private view {
        _requireSaleContext(x);
        U.SaleRecord storage sale = s.sales[e.sale.authorization.saleId];
        if (
            s.paused || sale.cancelled || block.timestamp < sale.config.startsAt
                || block.timestamp > sale.config.endsAt
        ) {
            revert UniversalSaleUnavailable(e.sale.authorization.saleId);
        }
        _requireConsent(s, x, e.sale.authorization.saleId);
        _requireGate(s, x, e.sale.authorization.saleId);
        _zeroFee(x, c.sale.collectionId);
        _requireActive(x, c.asset);
        StreamSettlementAdmission.requireAdmission(
            x.moduleRegistry, c.lifecycleBinding.paymentAdapter, c
        );
        StreamSaleArtist.requireArtist(
            x.artistRegistry,
            x.artistRegistryCodeHash,
            c.sale.collectionId,
            e.sale.authorization.artist
        );
        if (
            keccak256(abi.encode(_rights(x, c.sale.collectionId)))
                != keccak256(abi.encode(c.rights))
        ) revert UniversalCandidateMismatch();
    }

    function _requireGate(
        StreamERC20BurnMintState.State storage s,
        Context memory x,
        bytes32 saleId
    ) private view {
        StreamERC20BurnMintSupport.GateBinding memory current =
            StreamERC20BurnMintSupport.registrationGate(
                s.sales[saleId].config, x.mintManager, x.core, x.mintManagerCodeHash
            );
        if (keccak256(abi.encode(current)) != keccak256(abi.encode(s.saleBurnGate[saleId]))) {
            revert InvalidUniversalSale();
        }
    }

    function _requireConsent(StreamERC20BurnMintState.State storage s, Context memory x, bytes32 id)
        private
        view
    {
        U.SaleRecord storage record = s.sales[id];
        if (record.saleNonce == 0) revert UniversalSaleUnavailable(id);
        StreamSaleConsent.requireConsent(
            x.core,
            address(x.artistRegistry),
            x.artistRegistryCodeHash,
            record.config.collectionId,
            id,
            record.configHash
        );
    }

    function _zeroFee(Context memory x, uint256 collection)
        private
        view
        returns (IStreamImmediateSaleReveal.RevealQuote memory q)
    {
        q = StreamImmediateSaleReveal.quote(x.core, collection);
        if (q.policy.revealFeePerTokenWei != 0) {
            revert BurnMintNativeFeeUnsupported(q.policy.revealFeePerTokenWei);
        }
    }

    function _rights(Context memory x, uint256 collectionId)
        private
        view
        returns (StreamSaleTemplate.Selection memory)
    {
        return StreamUniversalSaleRights.rights(x.revenueResolver, x.splitFactory, collectionId);
    }

    function _requireSaleContext(Context memory x) private view {
        _requireContext(x);
        if (x.primarySaleSettlement.codehash != x.settlementCodeHash) {
            revert InvalidSettlementContext(x.primarySaleSettlement);
        }
        if (address(x.mintManager).codehash != x.mintManagerCodeHash) {
            revert InvalidSettlementContext(address(x.mintManager));
        }
    }

    function _requireContext(Context memory x) private view {
        StreamSettlementAdmission.requireRegistry(
            x.core, x.coreCodeHash, x.moduleRegistry, x.moduleRegistryCodeHash
        );
        if (address(x.revenueResolver).codehash != x.resolverCodeHash) {
            revert InvalidSettlementContext(address(x.revenueResolver));
        }
        _requireAssetBindings(x);
    }

    function _requireAssetBindings(Context memory x) private view {
        if (address(x.splitFactory).codehash != x.factoryCodeHash) {
            revert InvalidSettlementContext(address(x.splitFactory));
        }
        if (address(x.assetPolicyRegistry).codehash != x.assetRegistryCodeHash) {
            revert InvalidSettlementContext(address(x.assetPolicyRegistry));
        }
    }

    function _gas(Context memory x, bytes32 id) private view returns (uint256 cap) {
        _requireAssetBindings(x);
        // Exact-code trusted factory is the canonical repricing host; no cached fallback cap.
        cap = _read(
            address(x.splitFactory),
            abi.encodeCall(IStreamGasParameterHost.gasParameter, (id)),
            gasleft()
        );
        if (cap == 0 || cap > type(uint64).max) {
            revert InvalidSettlementContext(address(x.splitFactory));
        }
    }

    function _requireActive(Context memory x, address asset) private view {
        _requireAssetBindings(x);
        uint256 cap = _gas(x, _ASSET_GAS);
        _admitGas(cap);
        if (
            !StreamSettlementAdmission.isContract(asset)
                || _read(
                        address(x.assetPolicyRegistry),
                        abi.encodeCall(IStreamAssetPolicyRegistry.assetStatus, (asset)),
                        cap
                    ) != 1
        ) {
            revert SettlementAssetNotActive(asset);
        }
    }

    function _admitGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 40_000) {
            revert InsufficientSettlementCallGas(cap);
        }
    }

    function _read(address target, bytes memory data, uint256 cap)
        private
        view
        returns (uint256 word)
    {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32) revert SettlementReadFailed(target, bytes4(data));
    }

    function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 nonce)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                uint8(8),
                collectionId,
                phaseId,
                nonce
            )
        );
    }

    function _authorizationDigest(U.SaleAuthorization memory authorization)
        private
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                _DOMAIN,
                keccak256("6529StreamUniversalFixedPriceSaleAdapter"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        return keccak256(
            abi.encodePacked(
                hex"1901", domain, keccak256(abi.encode(SALE_AUTHORIZATION_TYPEHASH, authorization))
            )
        );
    }
}

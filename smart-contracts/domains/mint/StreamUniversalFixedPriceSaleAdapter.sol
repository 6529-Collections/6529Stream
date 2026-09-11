// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSaleArtist.sol";
import "./StreamSaleTemplate.sol";
import "../revenue/StreamSettlementContext.sol";
import "../revenue/StreamPrimarySettlementHash.sol";
import "../../interfaces/stream/mint/IStreamUniversalFixedPriceSaleAdapter.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Repeatable signed sale programs consumed through the sole universal payer boundary.
/// @dev This consumer accepts only fixed collection PROFILE rights and single-step one-token
///      minting. It never pulls an allowance, holds payment or records official revenue totals.
contract StreamUniversalFixedPriceSaleAdapter is
    IStreamUniversalFixedPriceSaleAdapter,
    IStreamERC20SaleExecution,
    IStreamSaleLifecycleBinding,
    StreamSettlementContext,
    Ownable,
    ReentrancyGuard,
    ERC165
{
    bytes32 public constant SALE_AUTHORIZATION_TYPEHASH = keccak256(
        "UniversalSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline)"
    );
    bytes32 private constant _DOMAIN = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant _CONFIG = keccak256("6529STREAM_UNIVERSAL_FIXED_PRICE_CONFIG_V1");
    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant _NONCE = keccak256("6529STREAM_UNIVERSAL_SALE_NONCE_V1");
    IStreamMintManager public immutable mintManager;
    bytes32 public immutable mintManagerCodeHash;
    address public immutable primarySaleSettlement;
    bytes32 public immutable settlementCodeHash;
    address public immutable platformSigner;
    IStreamArtistAttribution public immutable artistRegistry;
    bytes32 public immutable artistRegistryCodeHash;
    uint256 public nextSaleNonce = 1;
    bool public paused;
    mapping(bytes32 => SaleRecord) private _sales;
    mapping(address => mapping(bytes32 => bool)) public authorizationUsed;
    mapping(bytes32 => mapping(uint256 => bytes32)) public executionIdByNonce;
    mapping(bytes32 => uint8) public executionStatus;

    constructor(
        IStreamMintManager manager,
        IStreamPrimarySaleSettlement recorder,
        address signer,
        IStreamArtistAttribution artists
    ) StreamSettlementContext(recorder.revenueResolver(), recorder.moduleRegistry()) {
        if (
            !StreamSettlementAdmission.isContract(address(manager)) || signer == address(0)
                || !StreamSettlementAdmission.isContract(address(recorder))
                || !recorder.isStreamPrimarySaleSettlement()
                || !StreamSaleArtist.supportsAttribution(artists) || artists.core() != core
                || revenueResolver.artistRegistry() != address(artists)
                || !IStreamMintReads(address(manager)).isStreamMintManager()
                || address(IStreamMintReads(address(manager)).core()) != core
                || address(IStreamMintReads(address(manager)).moduleRegistry()) != moduleRegistry
                || recorder.core() != core
        ) revert InvalidUniversalSale();
        mintManager = manager;
        mintManagerCodeHash = address(manager).codehash;
        primarySaleSettlement = address(recorder);
        settlementCodeHash = address(recorder).codehash;
        platformSigner = signer;
        artistRegistry = artists;
        artistRegistryCodeHash = address(artists).codehash;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamUniversalFixedPriceSaleAdapter).interfaceId
            || id == type(IStreamERC20SaleExecution).interfaceId
            || id == type(IStreamSaleLifecycleBinding).interfaceId || super.supportsInterface(id);
    }

    function registerSale(SaleConfig calldata config)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 saleId)
    {
        _requireSaleContext();
        if (
            config.collectionId == 0 || config.phaseId == 0 || config.price == 0
                || config.endsAt <= config.startsAt || config.endsAt < block.timestamp
                || config.mintPolicyHash == 0 || config.expectedPrimaryPolicyHash == 0
                || IStreamMintReads(address(mintManager))
                        .phasePolicyHash(config.collectionId, config.phaseId)
                    != config.mintPolicyHash
        ) revert InvalidUniversalSale();
        _requireActive(config.asset);
        StreamSaleTemplate.Selection memory rights = _rights(config.collectionId);
        if (
            StreamSaleTemplate.policyHash(revenueResolver, config.collectionId, rights)
                != config.expectedPrimaryPolicyHash
        ) revert InvalidUniversalSale();
        StreamPrimarySettlementTypes.SaleLifecycleBinding memory binding =
            StreamSettlementAdmission.capture(moduleRegistry, address(this), config.paymentAdapter);
        if (
            _read(
                        config.paymentAdapter,
                        abi.encodeWithSignature("primarySaleSettlement()"),
                        gasleft()
                    ) != uint256(uint160(primarySaleSettlement))
                || _read(config.paymentAdapter, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(core))
        ) revert InvalidUniversalSale();
        uint256 nonce = nextSaleNonce++;
        saleId = saleIdFor(config.collectionId, config.phaseId, nonce);
        bytes32 hash = keccak256(abi.encode(_CONFIG, saleId, config));
        _sales[saleId] = SaleRecord(config, nonce, hash, binding, false);
        emit UniversalSaleConfigured(
            saleId, config.collectionId, config.phaseId, 1, nonce, hash, config.paymentAdapter
        );
    }

    function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 nonce)
        public
        view
        override
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                uint8(0),
                collectionId,
                phaseId,
                nonce
            )
        );
    }

    function saleRecord(bytes32 id) external view override returns (SaleRecord memory) {
        return _sales[id];
    }

    function saleLifecycleBinding(bytes32 id)
        external
        view
        override
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory)
    {
        return _sales[id].lifecycle;
    }

    function cancelSale(bytes32 id) external override onlyOwner nonReentrant {
        if (_sales[id].saleNonce == 0 || _sales[id].cancelled) revert UniversalSaleUnavailable(id);
        _sales[id].cancelled = true;
        emit UniversalSaleCancelled(id, 1);
    }

    function setPaused(bool value) external override onlyOwner nonReentrant {
        paused = value;
        emit UniversalSalesPaused(1, value);
    }

    function cancelAuthorization(bytes32 nonce) external override nonReentrant {
        if (authorizationUsed[msg.sender][nonce]) {
            revert UniversalAuthorizationUsed(msg.sender, nonce);
        }
        authorizationUsed[msg.sender][nonce] = true;
        emit UniversalAuthorizationCancelled(msg.sender, nonce, 1);
    }

    function transferOwnership(address newOwner) public override onlyOwner nonReentrant {
        super.transferOwnership(newOwner);
    }

    function renounceOwnership() public override onlyOwner nonReentrant {
        super.renounceOwnership();
    }

    function authorizationDigest(SaleAuthorization calldata authorization)
        external
        view
        override
        returns (bytes32)
    {
        return _authorizationDigest(authorization);
    }

    function _authorizationDigest(SaleAuthorization memory authorization)
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

    function previewExecution(SaleExecutionData calldata execution)
        external
        view
        override
        returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
    {
        (c,) = _candidate(execution);
    }

    function executeERC20PreRevenueSingleStep(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate,
        bytes calldata data
    )
        external
        override
        nonReentrant
        returns (bytes4 magic, StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        SaleExecutionData memory e = abi.decode(data, (SaleExecutionData));
        if (keccak256(data) != keccak256(abi.encode(e))) revert UniversalCandidateMismatch();
        (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        ) = _candidate(e);
        if (
            msg.sender != c.lifecycleBinding.paymentAdapter
                || keccak256(abi.encode(c)) != keccak256(abi.encode(candidate))
        ) revert UniversalCandidateMismatch();
        StreamSettlementAdmission.requireAdmission(moduleRegistry, msg.sender, c);
        authorizationUsed[e.authorization.artist][e.authorization.nonce] = true;
        executionIdByNonce[e.authorization.saleId][e.authorization.executionNonce] =
        c.executionBinding.executionId;
        executionStatus[c.executionBinding.executionId] = 1;
        emit UniversalSaleExecution(
            e.authorization.saleId,
            c.executionBinding.executionId,
            c.operationIdentityCommitment,
            1,
            1,
            0,
            0
        );
        result = _settle(c);
        _requireSaleContext();
        StreamSettlementAdmission.requireAdmission(moduleRegistry, msg.sender, c);
        StreamSaleArtist.requireArtist(
            artistRegistry, artistRegistryCodeHash, c.sale.collectionId, e.authorization.artist
        );
        if (keccak256(abi.encode(_rights(c.sale.collectionId))) != keccak256(abi.encode(c.rights))) revert UniversalCandidateMismatch();
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) =
            mintManager.executeSingleStepMint(batch, "");
        if (
            tokens.length != 1 || tokens[0] == 0 || root != c.operationIdentityCommitment
                || ids.length != 1 || ids[0] != c.operationId
        ) revert UniversalMintResultInvalid();
        executionStatus[c.executionBinding.executionId] = 2;
        emit UniversalSaleExecution(
            e.authorization.saleId,
            c.executionBinding.executionId,
            root,
            1,
            2,
            result.settlementKey,
            tokens[0]
        );
        return (IStreamERC20SaleExecution.executeERC20PreRevenueSingleStep.selector, result);
    }

    function _candidate(SaleExecutionData memory e)
        private
        view
        returns (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        )
    {
        _requireSaleContext();
        SaleAuthorization memory a = e.authorization;
        SaleRecord storage record = _sales[a.saleId];
        if (
            paused || record.saleNonce == 0 || record.cancelled
                || block.timestamp < record.config.startsAt
                || block.timestamp > record.config.endsAt
        ) revert UniversalSaleUnavailable(a.saleId);
        if (
            a.saleConfigHash != record.configHash || a.payer == address(0)
                || a.executor == address(0) || a.recipient == address(0) || a.artist == address(0)
                || a.mintCommitment == 0 || a.executionNonce == 0
                || a.tokenDataHash != keccak256(e.tokenData) || block.timestamp > a.deadline
        ) revert InvalidUniversalSale();
        if (authorizationUsed[a.artist][a.nonce]) {
            revert UniversalAuthorizationUsed(a.artist, a.nonce);
        }
        if (executionIdByNonce[a.saleId][a.executionNonce] != 0) {
            revert UniversalExecutionUsed(a.saleId, a.executionNonce);
        }
        bytes32 digest = _authorizationDigest(a);
        StreamSaleArtist.requireArtist(
            artistRegistry, artistRegistryCodeHash, record.config.collectionId, a.artist
        );
        if (!_validSignature(platformSigner, digest, e.platformSignature)) {
            revert UniversalSaleSignatureInvalid(platformSigner);
        }
        if (!_validSignature(a.artist, digest, e.artistSignature)) {
            revert UniversalSaleSignatureInvalid(a.artist);
        }
        _requireActive(record.config.asset);
        StreamSaleTemplate.Selection memory rights = _rights(record.config.collectionId);
        if (
            StreamSaleTemplate.policyHash(revenueResolver, record.config.collectionId, rights)
                != record.config.expectedPrimaryPolicyHash
        ) revert InvalidUniversalSale();
        c.saleAdapter = address(this);
        c.executor = a.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            a.saleId,
            _CLASS,
            0,
            record.config.collectionId,
            0,
            record.saleNonce,
            a.payer,
            address(0),
            a.recipient,
            record.config.price,
            record.config.expectedPrimaryPolicyHash
        );
        c.lifecycleBinding = record.lifecycle;
        c.executionBinding =
            StreamPrimarySettlementTypes.SaleExecutionBinding(0, a.executionNonce, 1, digest);
        c.asset = record.config.asset;
        c.orchestrationOrder = 1;
        c.mintManager = address(mintManager);
        c.currentPolicyHash = IStreamMintReads(address(mintManager))
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
        batch = _batch(a, record.config, e.tokenData, digest);
        bytes32[] memory ids;
        (c.operationIdentityCommitment, ids) =
            IStreamMintReads(address(mintManager)).previewSingleStepMintOperation(batch, "");
        if (c.operationIdentityCommitment == 0 || ids.length != 1 || ids[0] == 0) {
            revert UniversalMintResultInvalid();
        }
        c.operationId = ids[0];
        c.executionBinding.executionId = StreamPrimarySettlementHash.executionId(c);
    }

    function _batch(
        SaleAuthorization memory a,
        SaleConfig memory config,
        bytes memory tokenData,
        bytes32 digest
    ) private view returns (IStreamMintManager.MintBatch memory b) {
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
            keccak256(abi.encode(_NONCE, block.chainid, address(this), a.artist, a.nonce));
        b.contextHash = digest;
    }

    function _rights(uint256 collectionId)
        private
        view
        returns (StreamSaleTemplate.Selection memory rights)
    {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            revenueResolver.resolvePrimaryAssignment(collectionId, 0, _CLASS);
        if (
            !a.exists || a.assignmentType != 1 || a.scope != 1 || a.scopeId != collectionId
                || a.templateId != 0 || a.profileId == 0 || a.assignmentHash == 0
                || a.policyHash != 0 || !splitFactory.splitWalletExists(a.profileId)
        ) revert InvalidUniversalSale();
        return StreamSaleTemplate.Selection(
            a.profileId,
            splitFactory.walletFor(a.profileId),
            0,
            a.assignmentHash,
            splitFactory.profileEntriesHash(a.profileId)
        );
    }

    function _requireSaleContext() private view {
        _requireContext();
        if (primarySaleSettlement.codehash != settlementCodeHash) {
            revert InvalidSettlementContext(primarySaleSettlement);
        }
        if (address(mintManager).codehash != mintManagerCodeHash) {
            revert InvalidSettlementContext(address(mintManager));
        }
    }

    function _settle(StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
        private
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        bytes memory data = abi.encodeCall(
            IStreamPrimarySaleSettlement.settleERC20PrimarySaleFromAdapter, (msg.sender, c)
        );
        bytes memory response = new bytes(384);
        address target = primarySaleSettlement;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(gas(), target, 0, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384) revert UniversalSettlementFailed();
        result = abi.decode(response, (StreamPrimarySettlementTypes.PrimarySettlementResult));
        if (
            result.candidateCommitment
                    != StreamPrimarySettlementHash.candidateCommitment(
                        msg.sender, primarySaleSettlement, c
                    )
                || result.settlementKey
                    != StreamPrimarySettlementHash.settlementKey(
                        primarySaleSettlement, address(this), c.executionBinding.executionId
                    ) || result.profileId != c.rights.profileId || result.wallet != c.rights.wallet
                || result.asset != c.asset || result.amount != c.sale.amount
                || result.executor != c.executor
                || result.executionId != c.executionBinding.executionId
                || result.operationIdentityCommitment != c.operationIdentityCommitment
                || result.currentPolicyHash != c.currentPolicyHash
                || result.boundPolicyHash != c.boundPolicyHash
        ) revert UniversalSettlementFailed();
    }
}

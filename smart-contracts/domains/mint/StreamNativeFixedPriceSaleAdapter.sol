// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSaleArtist.sol";
import "./StreamSaleTemplate.sol";
import "../revenue/StreamSettlementContext.sol";
import "../revenue/StreamPrimarySettlementHash.sol";
import "../revenue/StreamNativeSettlementHash.sol";
import "../revenue/StreamNativeSettlementAdmission.sol";
import "../revenue/StreamNativeSettlementSupport.sol";
import "../../interfaces/stream/revenue/IStreamNativePrimarySaleSettlement.sol";
import "../../interfaces/stream/mint/IStreamNativeFixedPriceSaleAdapter.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Typed native paid mints through the shared official recorder.
/// @dev PROFILE and current artist-only templates; exact value and no persistent payment custody.
contract StreamNativeFixedPriceSaleAdapter is
    IStreamNativeFixedPriceSaleAdapter,
    StreamSettlementContext,
    Ownable,
    ReentrancyGuard,
    ERC165
{
    bytes32 public constant SALE_AUTHORIZATION_TYPEHASH = keccak256(
        "NativeSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash)"
    );
    bytes32 private constant _DOMAIN = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant _CONFIG = keccak256("6529STREAM_NATIVE_FIXED_PRICE_CONFIG_V1");
    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant _NONCE = keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1");
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
                || !IERC165(address(recorder))
                    .supportsInterface(type(IStreamNativePrimarySaleSettlement).interfaceId)
                || !StreamSaleArtist.supportsAttribution(artists) || artists.core() != core
                || revenueResolver.artistRegistry() != address(artists)
                || !IStreamMintReads(address(manager)).isStreamMintManager()
                || address(IStreamMintReads(address(manager)).core()) != core
                || address(IStreamMintReads(address(manager)).moduleRegistry()) != moduleRegistry
                || recorder.core() != core
        ) revert InvalidNativeSale();
        mintManager = manager;
        mintManagerCodeHash = address(manager).codehash;
        primarySaleSettlement = address(recorder);
        settlementCodeHash = address(recorder).codehash;
        platformSigner = signer;
        artistRegistry = artists;
        artistRegistryCodeHash = address(artists).codehash;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamNativeFixedPriceSaleAdapter).interfaceId
            || id == type(IStreamNativeSaleBinding).interfaceId || super.supportsInterface(id);
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
                || config.mintPolicyHash == 0 || config.primaryAssignmentHash == 0
                || IStreamMintReads(address(mintManager))
                        .phasePolicyHash(config.collectionId, config.phaseId)
                    != config.mintPolicyHash
        ) revert InvalidNativeSale();
        StreamSaleTemplate.Selection memory rights = _rights(config.collectionId);
        if (rights.assignmentHash != config.primaryAssignmentHash) revert InvalidNativeSale();
        StreamNativeSettlementTypes.SaleLifecycleBinding memory binding =
            StreamNativeSettlementAdmission.capture(moduleRegistry, address(this));
        uint256 nonce = nextSaleNonce++;
        saleId = saleIdFor(config.collectionId, config.phaseId, nonce);
        bytes32 hash = keccak256(abi.encode(_CONFIG, saleId, config));
        _sales[saleId] = SaleRecord(config, nonce, hash, binding, false);
        emit NativeSaleConfigured(saleId, config.collectionId, config.phaseId, 1, nonce, hash);
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

    function nativeSaleLifecycleBinding(bytes32 id)
        external
        view
        override
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory)
    {
        return _sales[id].lifecycle;
    }

    function cancelSale(bytes32 id) external override onlyOwner nonReentrant {
        if (_sales[id].saleNonce == 0 || _sales[id].cancelled) revert NativeSaleUnavailable(id);
        _sales[id].cancelled = true;
        emit NativeSaleCancelled(id, 1);
    }

    function setPaused(bool value) external override onlyOwner nonReentrant {
        paused = value;
        emit NativeSalesPaused(1, value);
    }

    function cancelAuthorization(bytes32 nonce) external override nonReentrant {
        if (authorizationUsed[msg.sender][nonce]) {
            revert NativeAuthorizationUsed(msg.sender, nonce);
        }
        authorizationUsed[msg.sender][nonce] = true;
        emit NativeAuthorizationCancelled(msg.sender, nonce, 1);
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
                keccak256("6529StreamNativeFixedPriceSaleAdapter"),
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
        returns (StreamNativeSettlementTypes.NativeSettlementCandidate memory c)
    {
        (c,) = _candidate(execution);
    }

    function purchase(SaleExecutionData calldata execution)
        external
        payable
        override
        nonReentrant
        returns (
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result,
            uint256 tokenId
        )
    {
        (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        ) = _candidate(execution);
        if (msg.sender != c.sale.payer || msg.sender != c.executor || msg.value != c.sale.amount) {
            revert InvalidNativeSale();
        }
        uint256 original = address(this).balance - msg.value;
        StreamNativeSettlementAdmission.requireAdmission(moduleRegistry, c);
        authorizationUsed[execution.authorization.artist][execution.authorization.nonce] = true;
        executionIdByNonce[execution.authorization.saleId][execution.authorization.executionNonce] =
            c.executionBinding.executionId;
        executionStatus[c.executionBinding.executionId] = 1;
        emit NativeSaleExecution(
            execution.authorization.saleId,
            c.executionBinding.executionId,
            c.operationIdentityCommitment,
            1,
            1,
            0,
            0
        );
        result = _settle(c);
        _requireRetained(c, execution.authorization.artist);
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) =
            mintManager.executeSingleStepMint(batch, "");
        if (
            tokens.length != 1 || tokens[0] == 0 || root != c.operationIdentityCommitment
                || ids.length != 1 || ids[0] != c.operationId
        ) revert NativeMintResultInvalid();
        _requireRetained(c, execution.authorization.artist);
        if (address(this).balance != original) revert NativeSettlementFailed();
        tokenId = tokens[0];
        executionStatus[c.executionBinding.executionId] = 2;
        emit NativeSaleExecution(
            execution.authorization.saleId,
            c.executionBinding.executionId,
            root,
            1,
            2,
            result.settlementKey,
            tokenId
        );
    }

    function _requireRetained(
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
        address artist
    ) private view {
        _requireSaleContext();
        StreamNativeSettlementAdmission.requireAdmission(moduleRegistry, c);
        StreamSaleArtist.requireArtist(
            artistRegistry, artistRegistryCodeHash, c.sale.collectionId, artist
        );
        StreamNativeSettlementSupport.requireCurrent(
            revenueResolver,
            c.sale.collectionId,
            StreamSaleTemplate.Selection(
                c.rights.profileId,
                c.rights.wallet,
                c.rights.templateId,
                c.rights.assignmentHash,
                c.rights.entriesHash
            )
        );
    }

    function _candidate(SaleExecutionData memory e)
        private
        view
        returns (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
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
        ) revert NativeSaleUnavailable(a.saleId);
        if (
            a.saleConfigHash != record.configHash || a.payer == address(0)
                || a.executor == address(0) || a.recipient == address(0) || a.artist == address(0)
                || a.mintCommitment == 0 || a.executionNonce == 0
                || a.expectedPrimaryPolicyHash == 0 || a.tokenDataHash != keccak256(e.tokenData)
                || block.timestamp > a.deadline
        ) revert InvalidNativeSale();
        if (authorizationUsed[a.artist][a.nonce]) {
            revert NativeAuthorizationUsed(a.artist, a.nonce);
        }
        if (executionIdByNonce[a.saleId][a.executionNonce] != 0) {
            revert NativeExecutionUsed(a.saleId, a.executionNonce);
        }
        bytes32 digest = _authorizationDigest(a);
        StreamSaleArtist.requireArtist(
            artistRegistry, artistRegistryCodeHash, record.config.collectionId, a.artist
        );
        if (!_validNativeSignature(platformSigner, digest, e.platformSignature)) {
            revert NativeSaleSignatureInvalid(platformSigner);
        }
        if (!_validNativeSignature(a.artist, digest, e.artistSignature)) {
            revert NativeSaleSignatureInvalid(a.artist);
        }
        StreamSaleTemplate.Selection memory rights = _rights(record.config.collectionId);
        if (
            StreamSaleTemplate.policyHash(revenueResolver, record.config.collectionId, rights)
                    != a.expectedPrimaryPolicyHash
                || rights.assignmentHash != record.config.primaryAssignmentHash
        ) revert InvalidNativeSale();
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
            a.expectedPrimaryPolicyHash
        );
        c.lifecycleBinding = record.lifecycle;
        c.executionBinding =
            StreamPrimarySettlementTypes.SaleExecutionBinding(0, a.executionNonce, 1, digest);
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
            revert NativeMintResultInvalid();
        }
        c.operationId = ids[0];
        c.executionBinding.executionId = StreamNativeSettlementHash.executionId(c);
    }

    function _batch(
        SaleAuthorization memory a,
        SaleConfig memory config,
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
        b.authorizationId = keccak256(abi.encode(_NONCE, digest));
        b.contextHash = digest;
    }

    function _rights(uint256 collectionId)
        private
        view
        returns (StreamSaleTemplate.Selection memory)
    {
        return StreamNativeSettlementSupport.rights(revenueResolver, collectionId);
    }

    function _validNativeSignature(address signer, bytes32 digest, bytes memory signature)
        private
        view
        returns (bool)
    {
        return StreamNativeSettlementSupport.validSignature(
            signer,
            digest,
            signature,
            StreamNativeSettlementSupport.gasParameter(
                splitFactory, factoryCodeHash, _SIGNATURE_GAS
            )
        );
    }

    function _requireSaleContext() private view {
        StreamSettlementAdmission.requireRegistry(
            core, coreCodeHash, moduleRegistry, moduleRegistryCodeHash
        );
        if (address(revenueResolver).codehash != resolverCodeHash) {
            revert InvalidSettlementContext(address(revenueResolver));
        }
        if (address(splitFactory).codehash != factoryCodeHash) {
            revert InvalidSettlementContext(address(splitFactory));
        }
        if (primarySaleSettlement.codehash != settlementCodeHash) {
            revert InvalidSettlementContext(primarySaleSettlement);
        }
        if (address(mintManager).codehash != mintManagerCodeHash) {
            revert InvalidSettlementContext(address(mintManager));
        }
    }

    function _settle(StreamNativeSettlementTypes.NativeSettlementCandidate memory c)
        private
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
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
        if (!ok || size != 384) revert NativeSettlementFailed();
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
        ) revert NativeSettlementFailed();
        data = abi.encodeCall(IStreamPrimarySaleSettlement.settlementResult, (result.settlementKey));
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384 || keccak256(response) != keccak256(abi.encode(result))) {
            revert NativeSettlementFailed();
        }
    }
}

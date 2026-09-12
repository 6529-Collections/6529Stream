// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSaleArtist.sol";
import "./StreamNativePriceProgram.sol";
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
    IStreamNativePricePrograms,
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
    mapping(bytes32 => PriceProgramRecord) private _pricePrograms;

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
            || id == type(IStreamNativePricePrograms).interfaceId
            || id == type(IStreamNativeSaleBinding).interfaceId || super.supportsInterface(id);
    }

    function registerPriceProgram(PriceProgramConfig calldata config)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 id)
    {
        _requireSaleContext();
        StreamNativePriceProgram.validateConfig(_priceProgramContext(), config);
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamNativeSettlementAdmission.capture(moduleRegistry, address(this));
        uint256 nonce = nextSaleNonce++;
        id = priceProgramIdFor(config.collectionId, config.phaseId, config.kind, nonce);
        bytes32 hash = keccak256(
            abi.encode(keccak256("6529STREAM_NATIVE_PRICE_PROGRAM_CONFIG_V1"), id, config)
        );
        _pricePrograms[id] = PriceProgramRecord(config, nonce, hash, lifecycle, 0, false);
        emit NativePriceProgramConfigured(
            id,
            1,
            nonce,
            hash,
            config,
            lifecycle.saleCreatedAt,
            lifecycle.saleAdapterRegistryRevision
        );
    }

    function priceProgramIdFor(uint256 collectionId, bytes32 phaseId, uint8 kind, uint256 nonce)
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
                kind,
                collectionId,
                phaseId,
                nonce
            )
        );
    }

    function priceProgramRecord(bytes32 id)
        external
        view
        override
        returns (PriceProgramRecord memory)
    {
        return _pricePrograms[id];
    }

    function closePriceProgram(bytes32 id) external override onlyOwner nonReentrant {
        PriceProgramRecord storage record = _pricePrograms[id];
        if (record.saleNonce == 0 || record.closed) revert NativePriceProgramUnavailable(id);
        record.closed = true;
        emit NativePriceProgramClosed(id, 1, record.mintedQuantity);
    }

    function priceProgramAuthorizationDigest(PriceProgramAuthorization calldata authorization)
        external
        view
        override
        returns (bytes32)
    {
        return StreamNativePriceProgram.authorizationDigest(authorization);
    }

    function previewPriceProgram(PriceProgramExecution calldata e)
        external
        view
        override
        returns (PriceProgramResult memory r)
    {
        (StreamNativeSettlementTypes.NativeSettlementCandidate memory c,) = _preparePriceProgram(e);
        return _priceProgramResult(c);
    }

    function executePriceProgram(PriceProgramExecution calldata e)
        external
        payable
        override
        nonReentrant
        returns (PriceProgramResult memory r)
    {
        (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        ) = _preparePriceProgram(e);
        if (msg.sender != c.sale.payer || msg.sender != c.executor || msg.value != c.sale.amount) {
            revert InvalidNativePriceProgram();
        }
        uint256 original = address(this).balance - msg.value;
        PriceProgramRecord storage record = _pricePrograms[e.authorization.saleId];
        authorizationUsed[e.authorization.artist][e.authorization.nonce] = true;
        executionIdByNonce[e.authorization.saleId][e.authorization.executionNonce] =
        c.executionBinding.executionId;
        executionStatus[c.executionBinding.executionId] = 1;
        ++record.mintedQuantity;
        r = _priceProgramResult(c);
        if (c.sale.amount != 0) {
            StreamPrimarySettlementTypes.PrimarySettlementResult memory settled = _settle(c);
            r.settlementKey = settled.settlementKey;
            r.escrowed = settled.escrowed;
            _requireRetained(c, e.authorization.artist);
        }
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) =
            mintManager.executeSingleStepMint(batch, "");
        if (
            tokens.length != 1 || tokens[0] == 0 || root != c.operationIdentityCommitment
                || ids.length != 1 || ids[0] != c.operationId
        ) revert NativeMintResultInvalid();
        if (c.sale.amount != 0) {
            _requireRetained(c, e.authorization.artist);
        } else {
            _requireSaleContext();
            StreamNativeSettlementAdmission.requireAdmission(moduleRegistry, c);
            StreamSaleArtist.requireArtist(
                artistRegistry, artistRegistryCodeHash, c.sale.collectionId, e.authorization.artist
            );
        }
        if (address(this).balance != original) revert NativeSettlementFailed();
        r.tokenId = tokens[0];
        executionStatus[c.executionBinding.executionId] = 2;
        StreamNativePriceProgram.emitCompletion(e.authorization.saleId, c, r, record.mintedQuantity);
    }

    function _preparePriceProgram(PriceProgramExecution calldata e)
        private
        view
        returns (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        )
    {
        _requireSaleContext();
        if (authorizationUsed[e.authorization.artist][e.authorization.nonce]) {
            revert NativeAuthorizationUsed(e.authorization.artist, e.authorization.nonce);
        }
        if (executionIdByNonce[e.authorization.saleId][e.authorization.executionNonce] != 0) {
            revert NativeExecutionUsed(e.authorization.saleId, e.authorization.executionNonce);
        }
        (c, batch) = StreamNativePriceProgram.prepare(
            _priceProgramContext(), _pricePrograms[e.authorization.saleId], e, paused
        );
        StreamNativeSettlementAdmission.requireAdmission(moduleRegistry, c);
    }

    function _priceProgramResult(StreamNativeSettlementTypes.NativeSettlementCandidate memory c)
        private
        pure
        returns (PriceProgramResult memory r)
    {
        r.revenueOutcome = c.sale.amount == 0 ? 1 : 2;
        r.executionId = c.executionBinding.executionId;
        r.operationRoot = c.operationIdentityCommitment;
        r.operationId = c.operationId;
        r.chargedAmount = c.sale.amount;
    }

    function _priceProgramContext() private view returns (StreamNativePriceProgram.Context memory) {
        return StreamNativePriceProgram.Context(
            mintManager,
            revenueResolver,
            splitFactory,
            factoryCodeHash,
            artistRegistry,
            artistRegistryCodeHash,
            platformSigner
        );
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
        return _sales[id].saleNonce != 0 ? _sales[id].lifecycle : _pricePrograms[id].lifecycle;
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
        return StreamNativePriceProgram.prepareFixed(
            _priceProgramContext(),
            _sales[e.authorization.saleId],
            e,
            paused,
            authorizationUsed[e.authorization.artist][e.authorization.nonce],
            executionIdByNonce[e.authorization.saleId][e.authorization.executionNonce]
        );
    }

    function _rights(uint256 collectionId)
        private
        view
        returns (StreamSaleTemplate.Selection memory)
    {
        return StreamNativeSettlementSupport.rights(revenueResolver, collectionId);
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
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory)
    {
        return StreamNativePriceProgram.settle(primarySaleSettlement, c);
    }
}

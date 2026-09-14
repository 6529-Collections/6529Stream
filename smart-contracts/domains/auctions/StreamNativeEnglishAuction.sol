// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeEnglishAuctionRightsRegistration.sol";
import "./StreamNativeEnglishAuctionTerminal.sol";
import "./StreamNativeEnglishAuctionRightsSettlement.sol";

import "./StreamNativeEnglishAuctionState.sol";
import "./StreamNativeEnglishAuctionCustodySettlement.sol";
import "./StreamTokenProfileCustodyActivation.sol";
import "./StreamTokenProfileCustodySettlement.sol";
import "./StreamNativeEnglishAuctionRegistration.sol";
import "./StreamNativeEnglishAuctionSettlement.sol";
import "./StreamNativeEnglishAuctionContentSettlement.sol";
import "../../interfaces/stream/auctions/IStreamNativeCuratedAuction.sol";
import {
    IStreamPreparedNativeCustodyAuction
} from "../../interfaces/stream/auctions/IStreamPreparedNativeCustodyAuction.sol";
import "./StreamNativeAuctionDelegation.sol";
import "../../interfaces/stream/auctions/IStreamNativeAuctionDelegatedDelivery.sol";
import "./StreamNativeEnglishAuctionSupport.sol";
import "./StreamNativeEnglishAuctionUnlock.sol";
import "./StreamNativeEnglishAuctionContentUnlock.sol";
import "../revenue/StreamSettlementContext.sol";
import "../revenue/StreamPreparedNativeSettlementValidation.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/IERC721Receiver.sol";

/// @notice Deferred native English auction with official payment between Core prepare/complete.
/// @dev Versioned exact-tokenData/collection-PROFILE profile. Own claims and time escape have
/// no current sale or pause gate; delegated claims require the original registry's live grant.
/// Other declared v1 profiles remain separate work.
contract StreamNativeEnglishAuction is
    IStreamNativeEnglishAuction,
    IStreamNativeCuratedAuction,
    IStreamNativeCustodyAuction,
    IStreamPreparedNativeCustodyAuction,
    IStreamTokenProfileCustodyAuction,
    IStreamNativeRightsAuction,
    IStreamNativeAuctionDelegatedDelivery,
    IStreamArtistSaleFacts,
    StreamSettlementContext,
    StreamGasParameterHost,
    ERC165,
    ReentrancyGuard,
    IERC721Receiver
{
    // Retain the original public error ABI after moving their emitting paths to fixed libraries.
    error SettlementBindingInvalid(address target);
    error AuctionClockConfigurationInvalid();
    error RefundClockOverflow();

    struct DeploymentConfig {
        IStreamMintManager manager;
        IStreamPrimarySaleSettlement recorder;
        address platform;
        IStreamArtistAttribution artists;
        IStreamRevealFeeEscrow entropy;
        IStreamRoleRegistry roles;
        address authority;
        GasParameterConfig[4] parameters;
        // All zero keeps the separately supported self-delivery profile. A declared
        // registry requires the complete immutable configuration and named gas parameter.
        address delegateRegistry;
        uint256 delegationUsecase;
        bytes32 baseModuleManifestHash;
        GasParameterConfig delegationGas;
    }

    bytes32 private constant SIGNATURE_GAS = keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT");
    bytes32 private constant ARTIST_GAS =
        keccak256("6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT");
    bytes32 private constant REVEAL_GAS = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
    bytes32 private constant DELIVERY_GAS = keccak256("6529STREAM_GGP_SALE_NFT_DELIVERY_GAS_LIMIT");
    IStreamMintManager public immutable mintManager;
    address public immutable primarySaleSettlement;
    address public immutable platformSigner;
    IStreamArtistAttribution public immutable artistRegistry;
    IStreamRevealFeeEscrow public immutable entropyCoordinator;
    IStreamRoleRegistry public immutable roleRegistry;
    bytes32 public immutable mintManagerCodeHash;
    bytes32 public immutable settlementCodeHash;
    bytes32 public immutable artistRegistryCodeHash;
    bytes32 public immutable entropyCodeHash;
    bytes32 public immutable roleRegistryCodeHash;
    address public immutable override delegateRegistry;
    bytes32 public immutable override delegateRegistryCodeHash;
    uint256 public immutable override delegationUsecase;
    bytes32 public immutable baseModuleManifestHash;
    uint256 private immutable _delegationChainId;
    StreamNativeEnglishAuctionState.State private _state;
    StreamNativeEnglishAuctionRuntime.Active private _active;
    mapping(bytes32 => StreamPreparedNativeContentTypes.Selection) private _curated;
    StreamNativeEnglishAuctionCustodyState.State private _custody;
    mapping(bytes32 => StreamPreparedNativeRightsTypes.OriginalPolicy) private _rights;
    StreamTokenProfileCustodyState.State private _tokenProfileCustody;

    constructor(DeploymentConfig memory d)
        StreamSettlementContext(d.recorder.revenueResolver(), d.recorder.moduleRegistry())
        StreamGasParameterHost(d.authority)
    {
        if (
            d.authority == address(0) || d.authority != splitFactory.governanceAuthority()
                || d.platform == address(0)
                || !StreamSettlementAdmission.isContract(address(d.manager))
                || !StreamSettlementAdmission.isContract(address(d.recorder))
                || !StreamSettlementAdmission.isContract(address(d.artists))
                || !StreamSettlementAdmission.isContract(address(d.entropy))
                || !StreamSettlementAdmission.isContract(address(d.roles))
                || !d.recorder.isStreamPrimarySaleSettlement() || d.recorder.core() != core
                || !IERC165(address(d.recorder))
                    .supportsInterface(type(IStreamPreparedNativePrimarySaleSettlement).interfaceId)
                || address(IStreamMintReads(address(d.manager)).core()) != core
                || address(IStreamMintReads(address(d.manager)).moduleRegistry()) != moduleRegistry
                || !IStreamMintReads(address(d.manager)).isStreamMintManager()
                || d.artists.core() != core
                || revenueResolver.artistRegistry() != address(d.artists)
                || d.entropy.core() != core
                || !IERC165(address(d.entropy))
                    .supportsInterface(type(IStreamRevealFeeEscrow).interfaceId)
                || _read(address(d.roles), abi.encodeWithSignature("owner()"), gasleft())
                    != uint256(uint160(d.authority))
        ) revert InvalidNativeAuction();
        bytes32[4] memory names = [
            keccak256("SALE_ERC1271_GAS_LIMIT"),
            keccak256("SALE_ARTIST_AUTHORITY_GAS_LIMIT"),
            keccak256("REVEAL_ATTEMPT_GAS_LIMIT"),
            keccak256("SALE_NFT_DELIVERY_GAS_LIMIT")
        ];
        for (uint256 j; j < 4; ++j) {
            if (
                keccak256(bytes(d.parameters[j].name)) != names[j]
                    || d.parameters[j].failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
            ) revert InvalidNativeAuction();
            _registerGasParameter(d.parameters[j]);
        }
        if (d.delegateRegistry != address(0)) {
            if (
                keccak256(bytes(d.delegationGas.name)) != keccak256("DELEGATE_REGISTRY_GAS_LIMIT")
                    || d.delegationGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
            ) {
                revert InvalidNativeAuction();
            }
            StreamNativeAuctionDelegation.validateConfiguration(
                StreamNativeAuctionDelegation.Configuration(
                    block.chainid,
                    core,
                    d.delegateRegistry,
                    d.delegateRegistry.codehash,
                    d.delegationUsecase,
                    d.baseModuleManifestHash,
                    moduleRegistry,
                    moduleRegistryCodeHash
                )
            );
            _registerGasParameter(d.delegationGas);
        } else if (
            d.delegationUsecase != 0 || d.baseModuleManifestHash != 0
                || bytes(d.delegationGas.name).length != 0 || d.delegationGas.genesisValue != 0
                || d.delegationGas.floor != 0 || d.delegationGas.failureClass != 0
        ) {
            revert InvalidNativeAuction();
        }
        delegateRegistry = d.delegateRegistry;
        delegateRegistryCodeHash =
            d.delegateRegistry == address(0) ? bytes32(0) : d.delegateRegistry.codehash;
        delegationUsecase = d.delegationUsecase;
        baseModuleManifestHash = d.baseModuleManifestHash;
        _delegationChainId = block.chainid;
        mintManager = d.manager;
        primarySaleSettlement = address(d.recorder);
        platformSigner = d.platform;
        artistRegistry = d.artists;
        entropyCoordinator = d.entropy;
        roleRegistry = d.roles;
        mintManagerCodeHash = address(d.manager).codehash;
        settlementCodeHash = address(d.recorder).codehash;
        artistRegistryCodeHash = address(d.artists).codehash;
        entropyCodeHash = address(d.entropy).codehash;
        roleRegistryCodeHash = address(d.roles).codehash;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return (id == type(IStreamNativeAuctionDelegatedDelivery).interfaceId
                && delegateRegistry != address(0))
            || id == type(IStreamNativeEnglishAuction).interfaceId
            || id == type(IStreamNativeCuratedAuction).interfaceId
            || id == type(IStreamNativeCustodyAuction).interfaceId
            || id == type(IStreamPreparedNativeCustodyAuction).interfaceId
            || id == type(IStreamTokenProfileCustodyAuction).interfaceId
            || id == type(IStreamNativeRightsAuction).interfaceId
            || id == type(IStreamPreparedNativeRightsSaleBinding).interfaceId
            || id == type(IStreamPreparedNativeContentSale).interfaceId
            || id == type(IStreamPreparedNativeSaleBinding).interfaceId
            || id == type(IStreamArtistSaleFacts).interfaceId || super.supportsInterface(id);
    }

    function delegationManifest() external view override returns (bytes memory) {
        if (delegateRegistry == address(0)) revert UnsupportedNativeAuctionProfile();
        return StreamNativeAuctionDelegation.manifestBytes(_delegationConfiguration());
    }

    function bidDelivery(bytes32 id, address bidder) external view override returns (address) {
        return _state.delivery[id][bidder];
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("NATIVE_PREPARED_SALE_ADAPTER");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamPreparedNativeSaleBinding).interfaceId;
    }

    function streamModuleVersion() external pure returns (bytes32) {
        return keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1");
    }

    function auctionConfigurationHash(Configuration calldata c) external view returns (bytes32) {
        return StreamNativeEnglishAuctionSupport.configHash(c);
    }

    function creationAuthorizationDigest(CreationAuthorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamNativeEnglishAuctionSupport.creationDigest(a);
    }

    function bidAuthorizationDigest(BidAuthorization calldata a) external view returns (bytes32) {
        return StreamNativeEnglishAuctionSupport.bidDigest(a);
    }

    function totalBuyerLiabilities() external view returns (uint256) {
        return _state.liabilities;
    }

    function totalLiveBidDeposits() external view returns (uint256) {
        return _state.liveDeposits;
    }

    function auction(bytes32 id) external view override returns (Auction memory) {
        return StreamNativeEnglishAuctionState.requireAuction(_state, id);
    }

    function auctionDeadlines(bytes32 id)
        public
        view
        override
        returns (uint64, uint64, uint64, uint64)
    {
        return StreamNativeEnglishAuctionState.deadlines(_state, id);
    }

    function refundableBalance(bytes32 saleId, address payer)
        external
        view
        override
        returns (uint256)
    {
        return _state.credits[saleId][payer];
    }

    function auctionConfig(bytes32 id)
        external
        view
        override
        returns (uint16, bool, bool, uint32, uint32, uint32, uint32, uint64)
    {
        Auction storage a = StreamNativeEnglishAuctionState.requireAuction(_state, id);
        (uint64 end,,,) = auctionDeadlines(id);
        return (
            a.config.minIncrementBps,
            a.config.incrementFloorWaived,
            a.config.clock.hardClose,
            a.config.clock.antiSnipeWindow,
            a.config.clock.antiSnipeExtension,
            a.config.clock.maxTotalExtension,
            uint32(a.clock.nominalEnd - a.clock.originalEnd),
            end
        );
    }

    function saleConsentFacts(bytes32 saleId) external view override returns (uint256, bytes32) {
        bytes32 id = _state.auctionBySale[saleId];
        if (id == 0) revert SaleConsentFactsUnavailable(saleId);
        Auction storage a = _state.auctions[id];
        return (a.config.collectionId, a.configHash);
    }

    function preparedNativeSaleLifecycle(bytes32 saleId)
        external
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory)
    {
        return StreamNativeEnglishAuctionState.requireAuction(_state, _state.auctionBySale[saleId])
        .lifecycle;
    }

    function activePreparedNativeIntent(bytes32 hash)
        external
        view
        returns (StreamPreparedNativeSettlementTypes.Intent memory)
    {
        if (
            hash == 0 || hash != _active.intentHash || _active.auction == 0
                || _state.auctions[_active.auction].status != 2
        ) revert InvalidNativeAuction();
        return _active.intent;
    }

    function activePreparedNativeContentIntent(bytes32 hash)
        external
        view
        returns (StreamPreparedNativeSettlementTypes.Intent memory)
    {
        if (_state.auctions[_active.auction].config.contentManifestRoot == 0) {
            revert InvalidNativeAuction();
        }
        if (
            hash == 0 || hash != _active.intentHash || _active.auction == 0
                || _state.auctions[_active.auction].status != 2
        ) revert InvalidNativeAuction();
        return _active.intent;
    }

    function registerAuction(
        Configuration calldata c,
        bytes calldata artwork,
        CreationAuthorization calldata authorization,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external override nonReentrant returns (bytes32 id) {
        return StreamNativeEnglishAuctionRegistration.registerAuction(
            _state, _runtime(), c, artwork, authorization, platformSignature, artistSignature
        );
    }

    function bid(bytes32 id, address deliverTo) external payable override nonReentrant {
        _bidPublic(id, deliverTo, StreamNativeAuctionDelegation.Witness(false, 0), false);
    }

    function bidForVault(bytes32 id, address vault, DelegationWitness calldata witness)
        external
        payable
        override
        nonReentrant
    {
        _bidPublic(
            id,
            vault,
            StreamNativeAuctionDelegation.Witness(witness.walletWide, witness.index),
            true
        );
    }

    function _bidPublic(
        bytes32 id,
        address deliverTo,
        StreamNativeAuctionDelegation.Witness memory witness,
        bool allowNew
    ) private {
        _requireLegacyCustodyEntry(id);
        StreamNativeEnglishAuctionRegistration.bidPublic(
            _state, _runtime(), _rights[id].mode, id, deliverTo, witness, allowNew
        );
    }

    function bidSigned(BidAuthorization calldata authorization, bytes calldata signature)
        external
        payable
        override
        nonReentrant
    {
        _bidSigned(authorization, signature, StreamNativeAuctionDelegation.Witness(false, 0), false);
    }

    function bidSignedForVault(
        BidAuthorization calldata authorization,
        bytes calldata signature,
        DelegationWitness calldata witness
    ) external payable override nonReentrant {
        _bidSigned(
            authorization,
            signature,
            StreamNativeAuctionDelegation.Witness(witness.walletWide, witness.index),
            true
        );
    }

    function _bidSigned(
        BidAuthorization calldata authorization,
        bytes calldata signature,
        StreamNativeAuctionDelegation.Witness memory witness,
        bool allowNew
    ) private {
        _requireLegacyCustodyEntry(authorization.auctionId);
        StreamNativeEnglishAuctionRegistration.bidSigned(
            _state,
            _runtime(),
            _rights[authorization.auctionId].mode,
            authorization,
            signature,
            witness,
            allowNew
        );
    }

    function _delegationConfiguration()
        private
        view
        returns (StreamNativeAuctionDelegation.Configuration memory)
    {
        return StreamNativeAuctionDelegation.Configuration(
            _delegationChainId,
            core,
            delegateRegistry,
            delegateRegistryCodeHash,
            delegationUsecase,
            baseModuleManifestHash,
            moduleRegistry,
            moduleRegistryCodeHash
        );
    }

    function settle(bytes32 id)
        external
        override
        nonReentrant
        returns (uint256 tokenId, bytes32 settlementKey)
    {
        if (!_state.auctions[id].config.mintAtSettlement) {
            // Original no-bid poster return remains an ungated escape for either rights family.
            if (_state.auctions[id].winner.amount != 0) _requireLegacyCustodyEntry(id);
            return
                StreamNativeEnglishAuctionCustodySettlement.settle(_state, _custody, _runtime(), id);
        }
        if (_rights[id].mode != 0) {
            return StreamNativeEnglishAuctionRightsSettlement.settle(
                _state, _active, _rights, _runtime(), id
            );
        }
        if (_state.auctions[id].config.contentManifestRoot != 0) {
            return StreamNativeEnglishAuctionContentSettlement.settle(
                _state, _active, _curated, _runtime(), id
            );
        }
        return StreamNativeEnglishAuctionSettlement.settle(_state, _active, _runtime(), id);
    }

    function onPreparedNativeMint(StreamPreparedNativeSettlementTypes.Facts calldata facts)
        external
        returns (bytes4, StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        return StreamNativeEnglishAuctionSettlement.onPreparedNativeMint(
            _state, _active, _runtime(), facts
        );
    }

    function onPreparedNativeContentMint(StreamPreparedNativeSettlementTypes.Facts calldata facts)
        external
        returns (bytes4, StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        return StreamNativeEnglishAuctionContentSettlement.onPreparedNativeContentMint(
            _state, _active, _runtime(), facts
        );
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
        external
        override
        returns (bytes4)
    {
        if (_custody.acquiring != 0) {
            return StreamNativeEnglishAuctionCustodyStart.onReceived(
                _custody, _runtime(), operator, from, tokenId
            );
        }
        return StreamNativeEnglishAuctionSettlement.onERC721Received(
            _state, _active, _runtime(), operator, from, tokenId
        );
    }

    function unlockNoMint(bytes32 id, uint8 reason) external override nonReentrant {
        StreamNativeEnglishAuctionTerminal.unlockNoMint(
            _state, _custody, _runtime(), _curated, _rights, id, reason
        );
    }

    function cancel(bytes32 id, bytes32 reason) external override nonReentrant {
        StreamNativeEnglishAuctionTerminal.cancel(_state, _custody, _runtime(), id, reason);
    }

    function claimRefund(bytes32 saleId, address payable to)
        external
        override
        nonReentrant
        returns (uint256)
    {
        return StreamNativeEnglishAuctionState.claim(_state, saleId, to);
    }

    function claimRefundFor(bytes32 saleId, address account, DelegationWitness calldata witness)
        external
        override
        nonReentrant
        returns (uint256)
    {
        return StreamNativeEnglishAuctionTerminal.claimRefundFor(
            _state, _custody, _runtime(), saleId, account, witness
        );
    }

    function claimNFTFor(bytes32 id, address account, DelegationWitness calldata witness)
        external
        override
        nonReentrant
    {
        StreamNativeEnglishAuctionTerminal.claimNFTFor(
            _state, _custody, _runtime(), id, account, witness
        );
    }

    function claimNFT(bytes32 id, address to) external override nonReentrant {
        StreamNativeEnglishAuctionTerminal.claimNFT(_state, _custody, _runtime(), id, to);
    }

    function custodyAcquisitionDigest(Acquisition calldata authorization)
        external
        view
        override
        returns (bytes32)
    {
        return StreamNativeEnglishAuctionCustodyStart.digest(authorization);
    }

    function registerCustodyAuction(
        Configuration calldata c,
        Acquisition calldata authorization,
        bytes calldata artwork,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external payable override nonReentrant returns (bytes32) {
        return StreamNativeEnglishAuctionCustodyStart.registerAuction(
                _state,
                _custody,
                _runtime(),
                c,
                authorization,
                artwork,
                platformSignature,
                artistSignature
            );
    }

    function preparedCustodyAcquisitionDigest(Acquisition calldata authorization)
        external
        view
        override
        returns (bytes32)
    {
        return StreamNativeEnglishAuctionCustodyStart.preparedDigest(authorization);
    }

    function registerPreparedCustodyAuction(
        Configuration calldata c,
        Acquisition calldata authorization,
        bytes calldata artwork,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external payable override nonReentrant returns (bytes32) {
        return StreamNativeEnglishAuctionCustodyStart.registerPreparedAuction(
                _state,
                _custody,
                _runtime(),
                c,
                authorization,
                artwork,
                platformSignature,
                artistSignature
            );
    }

    function custodyOrigin(bytes32 id)
        external
        view
        override
        returns (StreamNativeCustodySettlementTypes.Origin memory)
    {
        return _custody.origins[id];
    }

    function activeCustodySale(bytes32 id)
        external
        view
        override
        returns (StreamNativeCustodySettlementTypes.Facts memory)
    {
        Auction storage a = StreamNativeEnglishAuctionState.requireAuction(_state, id);
        if (
            a.status != 2 || a.config.mintAtSettlement || _custody.acquiring != 0
                || !_custody.origins[id].eligible || a.winner.amount == 0
        ) revert InvalidNativeCustody();
        return StreamNativeCustodySettlementTypes.Facts(id, a, _custody.origins[id]);
    }

    function unlockCustodySale(bytes32 id, uint8 reason) external override nonReentrant {
        StreamNativeEnglishAuctionCustodySettlement.unlock(_state, _custody, _runtime(), id, reason);
    }

    function pauseAdapter(bytes32 reason) external override nonReentrant {
        _pause(0, true, true, reason);
    }

    function unpauseAdapter(bytes32 reason) external override nonReentrant {
        _pause(0, true, false, reason);
    }

    function pauseSale(bytes32 saleId, bytes32 reason) external override nonReentrant {
        _pause(saleId, false, true, reason);
    }

    function unpauseSale(bytes32 saleId, bytes32 reason) external override nonReentrant {
        _pause(saleId, false, false, reason);
    }

    function _pause(bytes32 id, bool global, bool value, bytes32 reason) private {
        StreamRefundWindowSupport.requireRole(
            address(roleRegistry),
            roleRegistryCodeHash,
            governanceAuthority,
            value ? keccak256("ROLE_PAUSE_GUARDIAN") : keccak256("ROLE_UNPAUSE")
        );
        StreamNativeEnglishAuctionState.setPause(_state, id, global, value, reason);
    }

    function _support() private view returns (StreamRefundWindowSupport.Context memory) {
        return StreamRefundWindowSupport.Context(
            core,
            mintManager,
            revenueResolver,
            platformSigner,
            artistRegistry,
            artistRegistryCodeHash,
            entropyCoordinator,
            entropyCodeHash,
            gasParameter(SIGNATURE_GAS),
            gasParameter(ARTIST_GAS)
        );
    }

    /// @dev Copies immutable pins only; constructing it adds no current dependency gate.
    function _runtime() private view returns (StreamNativeEnglishAuctionRuntime.Context memory x) {
        x.base = StreamRefundWindowSupport.Context(
            core,
            mintManager,
            revenueResolver,
            platformSigner,
            artistRegistry,
            artistRegistryCodeHash,
            entropyCoordinator,
            entropyCodeHash,
            0,
            0
        );
        x.registry = moduleRegistry;
        x.registryHash = moduleRegistryCodeHash;
        x.coreHash = coreCodeHash;
        x.resolverHash = resolverCodeHash;
        x.factory = splitFactory;
        x.factoryHash = factoryCodeHash;
        x.assets = assetPolicyRegistry;
        x.assetsHash = assetRegistryCodeHash;
        x.managerHash = mintManagerCodeHash;
        x.recorder = primarySaleSettlement;
        x.recorderHash = settlementCodeHash;
        x.delegation = _delegationConfiguration();
    }

    function nextCuratedSaleId(uint256 collectionId, bytes32 phaseId)
        external
        view
        override
        returns (uint256 saleNonce, bytes32 saleId)
    {
        saleNonce = _state.nextNonce + 1;
        saleId = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                uint8(2),
                collectionId,
                phaseId,
                saleNonce
            )
        );
    }

    function registerCuratedAuction(
        Configuration calldata config,
        bytes calldata tokenData,
        StreamPreparedNativeContentTypes.Selection calldata selection,
        uint256 expectedSaleNonce,
        CreationAuthorization calldata authorization,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external override nonReentrant returns (bytes32) {
        return StreamNativeEnglishAuctionCurated.registerCuratedAuction(
            _state,
            _curated,
            _runtime(),
            config,
            tokenData,
            selection,
            expectedSaleNonce,
            authorization,
            platformSignature,
            artistSignature
        );
    }

    function curatedSelection(bytes32 id)
        external
        view
        override
        returns (StreamPreparedNativeContentTypes.Selection memory)
    {
        return _curated[id];
    }

    function rightsConfigurationHash(
        Configuration calldata config,
        StreamPreparedNativeRightsTypes.OriginalPolicy calldata original
    ) external view override returns (bytes32) {
        return StreamNativeEnglishAuctionRightsRegistration.configHash(config, original);
    }

    function registerRightsAuction(
        Configuration calldata config,
        StreamPreparedNativeRightsTypes.OriginalPolicy calldata original,
        bytes calldata tokenData,
        CreationAuthorization calldata authorization,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external override nonReentrant returns (bytes32) {
        return StreamNativeEnglishAuctionRightsRegistration.registerRightsAuction(
                _state,
                _rights,
                _runtime(),
                config,
                original,
                tokenData,
                authorization,
                platformSignature,
                artistSignature
            );
    }

    function originalAuctionRights(bytes32 id)
        external
        view
        override
        returns (StreamPreparedNativeRightsTypes.OriginalPolicy memory)
    {
        return _rights[id];
    }

    function activePreparedNativeRightsIntent(bytes32 hash)
        external
        view
        override
        returns (StreamPreparedNativeRightsTypes.Intent memory)
    {
        if (
            hash == 0 || _active.intentHash != hash || _active.auction == 0
                || _rights[_active.auction].mode == 0
        ) revert InvalidNativeAuction();
        return StreamPreparedNativeRightsTypes.Intent(_active.intent, _rights[_active.auction]);
    }

    function onPreparedNativeRightsMint(StreamPreparedNativeRightsTypes.Facts calldata facts)
        external
        override
        returns (bytes4, StreamPrimarySettlementTypes.PrimarySettlementResult memory)
    {
        return StreamNativeEnglishAuctionRightsSettlement.onPreparedNativeRightsMint(
            _state, _active, _rights, _runtime(), facts
        );
    }

    function tokenProfileCustodyDigest(
        StreamTokenProfileCustodyTypes.Authorization calldata authorization
    ) external view override returns (bytes32) {
        return StreamTokenProfileCustodyHash.digest(address(this), authorization);
    }

    function activateTokenProfileCustody(
        StreamTokenProfileCustodyTypes.Authorization calldata authorization,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external override nonReentrant {
        StreamTokenProfileCustodyActivation.activate(
            _state,
            _custody,
            _tokenProfileCustody,
            _runtime(),
            authorization,
            platformSignature,
            artistSignature
        );
    }

    function tokenProfileCustodyActivation(bytes32 id)
        external
        view
        override
        returns (StreamTokenProfileCustodyTypes.Activation memory)
    {
        return _tokenProfileCustody.activations[id];
    }

    function tokenProfileCustodyConfigurationHash(bytes32 id)
        external
        view
        override
        returns (bytes32)
    {
        return _tokenProfileCustody.activations[id].effectiveConfigHash;
    }

    function tokenProfileCustodyNonceUsed(address artist, bytes32 nonce)
        external
        view
        override
        returns (bool)
    {
        return _tokenProfileCustody.nonceUsed[artist][nonce];
    }

    function bidTokenProfileCustody(bytes32 id, address deliverTo)
        external
        payable
        override
        nonReentrant
    {
        bytes32 effective = _requireTokenProfileCustodyEntry(id);
        StreamNativeEnglishAuctionRegistration.bidPublicForConfiguration(
            _state,
            _runtime(),
            0,
            id,
            deliverTo,
            StreamNativeAuctionDelegation.Witness(false, 0),
            false,
            effective,
            true
        );
    }

    function bidSignedTokenProfileCustody(
        BidAuthorization calldata authorization,
        bytes calldata signature
    ) external payable override nonReentrant {
        bytes32 effective = _requireTokenProfileCustodyEntry(authorization.auctionId);
        StreamNativeEnglishAuctionRegistration.bidSignedForConfiguration(
            _state,
            _runtime(),
            0,
            authorization,
            signature,
            StreamNativeAuctionDelegation.Witness(false, 0),
            false,
            effective,
            true
        );
    }

    function settleTokenProfileCustody(bytes32 id)
        external
        override
        nonReentrant
        returns (uint256 tokenId, bytes32 settlementKey)
    {
        _requireTokenProfileCustodyEntry(id);
        return StreamTokenProfileCustodySettlement.settle(_state, _custody, _runtime(), id);
    }

    function _requireLegacyCustodyEntry(bytes32 id) private view {
        if (_tokenProfileCustody.activations[id].authorizationDigest != 0) {
            revert TokenProfileCustodyEntryRequired(id);
        }
    }

    function _requireTokenProfileCustodyEntry(bytes32 id) private view returns (bytes32) {
        StreamTokenProfileCustodyTypes.Activation storage activation =
            _tokenProfileCustody.activations[id];
        if (activation.authorizationDigest == 0) revert InvalidTokenProfileCustody();
        return activation.effectiveConfigHash;
    }
}

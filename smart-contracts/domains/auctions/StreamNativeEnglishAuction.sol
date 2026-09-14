// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeEnglishAuctionState.sol";
import "./StreamNativeEnglishAuctionRegistration.sol";
import "./StreamNativeEnglishAuctionSettlement.sol";
import "./StreamNativeEnglishAuctionContentSettlement.sol";
import "../../interfaces/stream/auctions/IStreamNativeCuratedAuction.sol";
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
        StreamNativeEnglishAuctionRegistration.bidPublic(
            _state, _runtime(), id, deliverTo, witness, allowNew
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
        StreamNativeEnglishAuctionRegistration.bidSigned(
                _state, _runtime(), authorization, signature, witness, allowNew
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

    function _claimRecipient(address account, DelegationWitness calldata witness)
        private
        view
        returns (address)
    {
        return StreamNativeAuctionDelegation.claimRecipient(
            _delegationConfiguration(),
            account,
            msg.sender,
            account,
            StreamNativeAuctionDelegation.Witness(witness.walletWide, witness.index),
            msg.sender == account ? 0 : gasParameter(StreamNativeAuctionDelegation.GAS_PARAMETER)
        );
    }

    function settle(bytes32 id)
        external
        override
        nonReentrant
        returns (uint256 tokenId, bytes32 settlementKey)
    {
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
        view
        override
        returns (bytes4)
    {
        return StreamNativeEnglishAuctionSettlement.onERC721Received(
            _state, _active, _runtime(), operator, from, tokenId
        );
    }

    function unlockNoMint(bytes32 id, uint8 reason) external override nonReentrant {
        Auction storage a = StreamNativeEnglishAuctionState.requireAuction(_state, id);
        if (a.status == 6) return;
        if (a.status != 1 || a.winner.amount == 0) revert NativeAuctionTerminal(id);
        bytes32 hash;
        if (reason == 0) {
            (, uint64 deadline,,) = auctionDeadlines(id);
            if (StreamEnglishAuctionClock.expired(deadline, StreamRefundClock.now64())) {
                hash = keccak256("NATIVE_AUCTION_FINALIZATION_DEADLINE");
            }
        } else {
            (uint64 end,,,) = auctionDeadlines(id);
            if (end != 0 && block.timestamp >= end) {
                if (a.config.contentManifestRoot != 0) {
                    hash = StreamNativeEnglishAuctionContentUnlock.reasonHash(
                        StreamNativeEnglishAuctionUnlock.Context(
                            _support(),
                            moduleRegistry,
                            moduleRegistryCodeHash,
                            coreCodeHash,
                            mintManagerCodeHash,
                            primarySaleSettlement
                        ),
                        a,
                        reason,
                        _curated[id].contentId
                    );
                } else {
                    hash = StreamNativeEnglishAuctionUnlock.reasonHash(
                        StreamNativeEnglishAuctionUnlock.Context(
                            _support(),
                            moduleRegistry,
                            moduleRegistryCodeHash,
                            coreCodeHash,
                            mintManagerCodeHash,
                            primarySaleSettlement
                        ),
                        a,
                        reason
                    );
                }
            }
        }
        if (hash == 0) revert NativeAuctionUnlockUnavailable(id, reason);
        StreamNativeEnglishAuctionState.noMint(_state, id, hash);
    }

    function cancel(bytes32 id, bytes32 reason) external override nonReentrant {
        Auction storage a = StreamNativeEnglishAuctionState.requireAuction(_state, id);
        if (a.status == 4) return;
        (uint64 end,,,) = auctionDeadlines(id);
        if (
            msg.sender != a.config.poster || a.status != 1 || a.winner.amount != 0 || reason == 0
                || (end != 0 && block.timestamp >= end)
        ) revert NativeAuctionTerminal(id);
        (,,, a.terminalToll) = auctionDeadlines(id);
        a.status = 4;
        emit NativeAuctionCancelled(id, a.saleId, reason);
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
        address recipient = _claimRecipient(account, witness);
        return
            StreamNativeEnglishAuctionState.claimAccount(
                _state, saleId, account, payable(recipient)
            );
    }

    function claimNFTFor(bytes32 id, address account, DelegationWitness calldata witness)
        external
        override
        nonReentrant
    {
        Auction storage a = StreamNativeEnglishAuctionState.requireAuction(_state, id);
        if (a.status != 3 || account == address(0) || a.nftClaimant != account) {
            revert InvalidNativeAuction();
        }
        _deliver(id, a, _claimRecipient(account, witness), true);
    }

    function claimNFT(bytes32 id, address to) external override nonReentrant {
        Auction storage a = StreamNativeEnglishAuctionState.requireAuction(_state, id);
        if (
            a.status != 3 || a.nftClaimant == address(0) || a.nftClaimant != msg.sender
                || to == address(0) || to == address(this)
        ) revert InvalidNativeAuction();
        _deliver(id, a, to, true);
    }

    function _deliver(bytes32 id, Auction storage a, address to, bool claim) private {
        StreamNativeEnglishAuctionSettlement.deliver(_runtime(), id, a, to, claim);
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
}

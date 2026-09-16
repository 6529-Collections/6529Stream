// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Ownable } from "../../vendor/openzeppelin/Ownable.sol";
import { ReentrancyGuard } from "../../vendor/openzeppelin/ReentrancyGuard.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { IERC721Receiver } from "../../vendor/openzeppelin/IERC721Receiver.sol";
import { StreamSettlementContext } from "../revenue/StreamSettlementContext.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import { StreamNativeRefundDelegation } from "./StreamNativeRefundDelegation.sol";
import { StreamNativeSurplusHost } from "./StreamNativeSurplusHost.sol";
import { StreamNativeCuratedSaleState } from "./StreamNativeCuratedSaleState.sol";
import { StreamNativeCuratedSaleSupport } from "./StreamNativeCuratedSaleSupport.sol";
import { StreamNativeCuratedSaleHash } from "./StreamNativeCuratedSaleHash.sol";
import { StreamNativeCuratedClock } from "./StreamNativeCuratedClock.sol";
import { StreamRefundWindowSupport } from "./StreamRefundWindowSupport.sol";
import { StreamImmediateSaleReveal } from "./StreamImmediateSaleReveal.sol";
import { IStreamMintManager } from "../../interfaces/stream/mint/IStreamMintManager.sol";
import { IStreamMintReads } from "../../interfaces/stream/mint/IStreamMintReads.sol";
import {
    IStreamPreparedNativeContentSale
} from "../../interfaces/stream/mint/IStreamPreparedNativeContentMint.sol";
import {
    IStreamPreparedNativeContentPurchaseMint,
    IStreamPreparedNativeContentPurchaseSale,
    IStreamPreparedNativeContentPurchaseSettlement
} from "../../interfaces/stream/mint/IStreamPreparedNativeContentPurchaseMint.sol";
import {
    StreamPreparedNativeContentPurchaseTypes as PurchaseTypes
} from "../../interfaces/stream/mint/StreamPreparedNativeContentPurchaseTypes.sol";
import {
    StreamNativeCuratedSaleTypes as Curated
} from "../../interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";
import {
    IStreamImmediateSaleReveal
} from "../../interfaces/stream/mint/IStreamImmediateSaleReveal.sol";
import { IStreamNativeSurplus } from "../../interfaces/stream/mint/IStreamNativeSurplus.sol";
import {
    IStreamPrimarySaleSettlement
} from "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import {
    IStreamPreparedNativeSaleBinding
} from "../../interfaces/stream/revenue/IStreamPreparedNativeSaleBinding.sol";
import {
    IStreamPreparedNativePrimarySaleSettlement
} from "../../interfaces/stream/revenue/IStreamPreparedNativePrimarySaleSettlement.sol";
import {
    StreamPreparedNativeSettlementTypes as Prepared
} from "../../interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol";
import {
    StreamPrimarySettlementTypes as Primary
} from "../../interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";
import {
    StreamNativeSettlementTypes
} from "../../interfaces/stream/revenue/StreamNativeSettlementTypes.sol";
import {
    IStreamArtistAttribution
} from "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import { IStreamArtistSaleFacts } from "../../interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import { IStreamRoleRegistry } from "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

import { StreamNativeCuratedSaleRuntime } from "./StreamNativeCuratedSaleRuntime.sol";
import { StreamNativeCuratedSaleRegistration } from "./StreamNativeCuratedSaleRegistration.sol";
import { StreamNativeCuratedSaleExecution } from "./StreamNativeCuratedSaleExecution.sol";
import { StreamNativeCuratedSaleSettlement } from "./StreamNativeCuratedSaleSettlement.sol";

import { StreamNativeCuratedSaleReadEncoding } from "./StreamNativeCuratedSaleReadEncoding.sol";

import { StreamNativeCuratedSaleControl } from "./StreamNativeCuratedSaleControl.sol";

/// @notice Shared custody, official settlement and pull-credit boundary for selected-work sales.
/// @dev Derived entries own timing and purchase admission. Every mutating entry uses one guard;
/// only the fixed Manager's exact active prepared callback and Core mint receipt enter within it.
abstract contract StreamNativeCuratedSaleBase is
    Ownable,
    ReentrancyGuard,
    StreamSettlementContext,
    StreamGasParameterHost,
    StreamNativeRefundDelegation,
    StreamNativeSurplusHost,
    IERC721Receiver,
    IStreamArtistSaleFacts
{
    struct DeploymentConfig {
        IStreamMintManager manager;
        IStreamPrimarySaleSettlement recorder;
        address platform;
        IStreamArtistAttribution artists;
        IStreamRoleRegistry roles;
        address authority;
        GasParameterConfig[4] parameters;
        DelegationDeployment delegation;
    }

    bytes32 internal constant CURATED_SIGNATURE_GAS =
        keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT");
    bytes32 internal constant CURATED_ARTIST_GAS =
        keccak256("6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT");
    bytes32 internal constant CURATED_REVEAL_GAS =
        keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
    bytes32 internal constant CURATED_DELIVERY_GAS =
        keccak256("6529STREAM_GGP_SALE_NFT_DELIVERY_GAS_LIMIT");
    IStreamMintManager public immutable mintManager;
    IStreamPrimarySaleSettlement public immutable primarySaleSettlement;
    address public immutable platformSigner;
    IStreamArtistAttribution public immutable artistRegistry;
    IStreamRoleRegistry public immutable roleRegistry;
    bytes32 public immutable mintManagerCodeHash;
    bytes32 public immutable settlementCodeHash;
    bytes32 public immutable artistRegistryCodeHash;
    bytes32 public immutable roleRegistryCodeHash;
    StreamNativeCuratedSaleState.State internal _state;

    error InvalidCuratedDeployment();
    error SettlementBindingInvalid(address target);
    error CuratedSaleUnavailable(bytes32 saleId);
    error CuratedSaleStopped(bytes32 saleId);
    error SaleAttributionContested(uint256 collectionId);
    error CuratedPurchaseNonceInvalid(uint256 expected, uint256 actual);
    error CuratedPurchaseInvalid();
    error CuratedAccountingMismatch();
    error CuratedCallbackInvalid();
    error CuratedDeliveryFailed(address recipient);
    error CuratedCreditEmpty();
    error CuratedCreditTransferFailed();
    event CuratedSaleConfigured(
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        uint8 saleKind,
        uint256 saleNonce,
        Curated.Configuration config
    );
    event CuratedPurchaseSettled(
        bytes32 indexed saleId,
        bytes32 indexed purchaseId,
        address indexed buyer,
        Curated.ExecutionRecord execution,
        uint256 revealFee,
        uint256 feeCredit
    );
    event CuratedCreditAdded(bytes32 indexed saleId, address indexed buyer, uint256 amount);
    event CuratedCreditClaimed(
        bytes32 indexed saleId, address indexed buyer, address indexed recipient, uint256 amount
    );
    event AdapterPaused(uint16 schemaVersion, address indexed guardian, bytes32 reasonHash);
    event AdapterUnpaused(uint16 schemaVersion, address indexed unpauser, bytes32 reasonHash);
    event SalePaused(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed guardian, bytes32 reasonHash
    );
    event SaleUnpaused(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed unpauser, bytes32 reasonHash
    );
    event CollectionSaleStopSynced(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed actor,
        uint8 observedContestState,
        bool stopped
    );
    event CuratedSaleCanceled(bytes32 indexed saleId);

    constructor(DeploymentConfig memory d)
        StreamSettlementContext(d.recorder.revenueResolver(), d.recorder.moduleRegistry())
        StreamGasParameterHost(d.authority)
        StreamNativeRefundDelegation(d.recorder.core(), d.recorder.moduleRegistry(), d.delegation)
    {
        if (
            d.authority == address(0) || d.authority != splitFactory.governanceAuthority()
                || d.platform == address(0) || address(d.manager).code.length == 0
                || address(d.recorder).code.length == 0 || address(d.artists).code.length == 0
                || address(d.roles).code.length == 0 || !d.recorder.isStreamPrimarySaleSettlement()
                || d.recorder.core() != core
                || !IStreamMintReads(address(d.manager)).isStreamMintManager()
                || address(IStreamMintReads(address(d.manager)).core()) != core
                || address(IStreamMintReads(address(d.manager)).moduleRegistry()) != moduleRegistry
                || d.artists.core() != core
                || revenueResolver.artistRegistry() != address(d.artists)
                || !IERC165(address(d.recorder))
                    .supportsInterface(type(IStreamPreparedNativePrimarySaleSettlement).interfaceId)
                || _read(address(d.roles), abi.encodeWithSignature("owner()"), gasleft())
                    != uint256(uint160(d.authority))
        ) revert InvalidCuratedDeployment();
        bytes32[4] memory names = [
            keccak256("SALE_ERC1271_GAS_LIMIT"),
            keccak256("SALE_ARTIST_AUTHORITY_GAS_LIMIT"),
            keccak256("REVEAL_ATTEMPT_GAS_LIMIT"),
            keccak256("SALE_NFT_DELIVERY_GAS_LIMIT")
        ];
        for (uint256 n; n < 4; ++n) {
            if (
                keccak256(bytes(d.parameters[n].name)) != names[n]
                    || d.parameters[n].failureClass != 2
            ) revert InvalidCuratedDeployment();
            _registerGasParameter(d.parameters[n]);
        }
        if (d.delegation.registry != address(0)) _registerGasParameter(d.delegation.gas);
        mintManager = d.manager;
        primarySaleSettlement = d.recorder;
        platformSigner = d.platform;
        artistRegistry = d.artists;
        roleRegistry = d.roles;
        mintManagerCodeHash = address(d.manager).codehash;
        settlementCodeHash = address(d.recorder).codehash;
        artistRegistryCodeHash = address(d.artists).codehash;
        roleRegistryCodeHash = address(d.roles).codehash;
        _state.nextSaleNonce = 1;
    }

    function supportsInterface(bytes4 id) public view virtual returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamArtistSaleFacts).interfaceId
            || id == type(IStreamPreparedNativeSaleBinding).interfaceId
            || id == type(IStreamPreparedNativeContentSale).interfaceId
            || id == type(IStreamPreparedNativeContentPurchaseSale).interfaceId
            || id == type(IStreamNativeSurplus).interfaceId || _refundDelegationSupported(id)
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function streamModuleVersion() external pure returns (bytes32) {
        return keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1");
    }

    function nextSaleNonce() external view returns (uint256) {
        return _state.nextSaleNonce;
    }

    function saleIdFor(uint8 kind, uint256 collection, bytes32 phase, uint256 nonce)
        public
        view
        returns (bytes32)
    {
        return StreamNativeCuratedSaleHash.saleId(kind, collection, phase, nonce);
    }

    function purchaseIdFor(bytes32 id, address buyer, uint256 nonce) public view returns (bytes32) {
        return StreamNativeCuratedSaleHash.purchaseId(id, buyer, nonce);
    }

    function nextPurchaseNonce(bytes32 id, address buyer) external view returns (uint256) {
        return _state.purchaseNonces[id][buyer] + 1;
    }

    function saleRecord(bytes32 id) external view returns (Curated.SaleRecord memory) {
        bytes memory out = StreamNativeCuratedSaleReadEncoding.read(_state, 0, id);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function executionRecord(bytes32 id) external view returns (Curated.ExecutionRecord memory) {
        bytes memory out = StreamNativeCuratedSaleReadEncoding.read(_state, 1, id);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function saleConsentFacts(bytes32 id) external view override returns (uint256, bytes32) {
        Curated.SaleRecord storage s = _state.sales[id];
        if (s.configHash == 0) revert SaleConsentFactsUnavailable(id);
        return (s.config.collectionId, s.configHash);
    }

    function preparedNativeSaleLifecycle(bytes32 id)
        external
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory)
    {
        bytes memory out = StreamNativeCuratedSaleReadEncoding.read(_state, 4, id);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function activePreparedNativeIntent(bytes32) external pure returns (Prepared.Intent memory) {
        revert CuratedCallbackInvalid();
    }

    function onPreparedNativeMint(Prepared.Facts calldata)
        external
        pure
        returns (bytes4, Primary.PrimarySettlementResult memory)
    {
        revert CuratedCallbackInvalid();
    }

    function activePreparedNativeContentIntent(bytes32 hash)
        external
        view
        returns (Prepared.Intent memory)
    {
        bytes memory out = StreamNativeCuratedSaleReadEncoding.read(_state, 2, hash);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function activePreparedNativeContentPurchase(bytes32 hash)
        external
        view
        returns (PurchaseTypes.Purchase memory)
    {
        bytes memory out = StreamNativeCuratedSaleReadEncoding.read(_state, 3, hash);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function _registerCommon(Curated.Configuration memory config, uint8 kind, bytes32 configHash)
        internal
        returns (bytes32)
    {
        _requireCuratedContext();
        _requireRefundDelegationManifest();
        return StreamNativeCuratedSaleRegistration.register(
            _state, _support(), config, kind, configHash
        );
    }

    function _requireSale(bytes32 id) internal view returns (Curated.SaleRecord storage s) {
        StreamNativeCuratedSaleRuntime.requireSale(_state, _runtime(), id);
        return _state.sales[id];
    }

    function _reservePurchaseNonce(bytes32 id, address buyer, uint256 nonce) internal {
        uint256 expected = _state.purchaseNonces[id][buyer] + 1;
        if (buyer == address(0) || buyer == address(this) || nonce != expected) {
            revert CuratedPurchaseNonceInvalid(expected, nonce);
        }
        _state.purchaseNonces[id][buyer] = nonce;
    }

    function _batch(
        bytes32 id,
        address buyer,
        Curated.Selection memory chosen,
        bytes32 authorizationId,
        address authorizer
    ) internal view returns (IStreamMintManager.MintBatch memory) {
        return StreamNativeCuratedSaleExecution.batch(
            _state, id, buyer, chosen, authorizationId, authorizer
        );
    }

    function _execute(StreamNativeCuratedSaleState.Request memory r)
        internal
        returns (Curated.ExecutionRecord memory)
    {
        return StreamNativeCuratedSaleExecution.execute(_state, _runtime(), r);
    }

    function onPreparedNativeContentMint(Prepared.Facts calldata facts)
        external
        returns (bytes4, Primary.PrimarySettlementResult memory result)
    {
        bytes memory out = StreamNativeCuratedSaleSettlement.callback(_state, _runtime(), facts);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
        external
        override
        returns (bytes4)
    {
        StreamNativeCuratedSaleState.Active storage a = _state.active;
        if (
            msg.sender != core || operator != address(mintManager) || from != address(0)
                || a.intentHash == 0 || !a.callbackConsumed || a.tokenId != tokenId || a.received
        ) revert CuratedCallbackInvalid();
        a.received = true;
        return IERC721Receiver.onERC721Received.selector;
    }

    function _requireBuyer(address buyer, DelegationWitness calldata witness) internal view {
        if (buyer == address(0) || buyer == address(this)) revert CuratedPurchaseInvalid();
        if (msg.sender != buyer) _requireRefundDelegate(buyer, witness);
    }

    function _credit(bytes32 id, address buyer, uint256 amount) internal {
        StreamNativeCuratedSaleExecution.credit(_state, id, buyer, amount);
    }

    function refundableBalance(bytes32 id, address buyer) external view returns (uint256) {
        return _state.credits[id][buyer];
    }

    function refundLiability() external view returns (uint256) {
        return _state.refundLiability;
    }

    function totalBuyerLiabilities() external view returns (uint256) {
        return _nativeSurplusOwed();
    }

    function saleRevealQuote(bytes32 id)
        external
        view
        returns (IStreamImmediateSaleReveal.RevealQuote memory)
    {
        bytes memory out = StreamNativeCuratedSaleReadEncoding.quote(_state, core, id);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function claimRefund(bytes32 id, address recipient) external nonReentrant returns (uint256) {
        return _claimCredit(id, msg.sender, recipient);
    }

    function claimRefundFor(bytes32 id, address buyer, DelegationWitness calldata witness)
        external
        override
        nonReentrant
        returns (uint256 amount)
    {
        _requireBuyer(buyer, witness);
        amount = _claimCredit(id, buyer, buyer);
        _requireBuyer(buyer, witness);
    }

    function _claimCredit(bytes32 id, address buyer, address recipient)
        private
        returns (uint256 amount)
    {
        return StreamNativeCuratedSaleControl.claimCredit(_state, id, buyer, recipient);
    }

    function sweepNativeSurplus(uint256 amount, bytes32 reason)
        external
        override
        nonReentrant
        returns (uint256)
    {
        return _sweepNativeSurplus(amount, reason);
    }

    function _additionalLiability() internal view virtual returns (uint256) {
        return 0;
    }

    function _nativeSurplusOwed() internal view override returns (uint256) {
        return _state.refundLiability + _additionalLiability();
    }

    function _requireSolvent() internal view {
        if (address(this).balance < _nativeSurplusOwed()) revert CuratedAccountingMismatch();
    }

    function setGlobalPause(bool value, bytes32 reason) external nonReentrant {
        StreamNativeCuratedSaleControl.setGlobalPause(_state, _controlRoles(), value, reason);
    }

    function setSalePause(bytes32 id, bool value, bytes32 reason) external nonReentrant {
        StreamNativeCuratedSaleControl.setSalePause(_state, _controlRoles(), id, value, reason);
    }

    function syncCollectionContest(uint256 collectionId) external nonReentrant {
        StreamNativeCuratedSaleControl.syncCollectionContest(_state, _support(), collectionId);
    }

    function cancelSale(bytes32 id) external onlyOwner nonReentrant {
        if (_state.sales[id].status != 1) revert CuratedSaleUnavailable(id);
        _state.sales[id].status = 2;
        emit CuratedSaleCanceled(id);
    }

    function _requireRole(bytes32 role) internal view {
        StreamRefundWindowSupport.requireRole(
            address(roleRegistry), roleRegistryCodeHash, governanceAuthority, role
        );
    }

    function _requireCuratedContext() internal view {
        StreamNativeCuratedSaleRuntime.requireContext(_runtime());
    }

    function _support() internal view returns (StreamNativeCuratedSaleSupport.Context memory) {
        return StreamNativeCuratedSaleSupport.Context(
            core,
            moduleRegistry,
            mintManager,
            revenueResolver,
            artistRegistry,
            artistRegistryCodeHash,
            gasParameter(CURATED_ARTIST_GAS)
        );
    }

    function _runtime() internal view returns (StreamNativeCuratedSaleRuntime.Context memory x) {
        x.base = StreamNativeCuratedSaleSupport.Context(
            core,
            moduleRegistry,
            mintManager,
            revenueResolver,
            artistRegistry,
            artistRegistryCodeHash,
            0
        );
        x.recorder = primarySaleSettlement;
        x.factory = address(splitFactory);
        x.assets = address(assetPolicyRegistry);
        x.coreHash = coreCodeHash;
        x.registryHash = moduleRegistryCodeHash;
        x.resolverHash = resolverCodeHash;
        x.factoryHash = factoryCodeHash;
        x.assetsHash = assetRegistryCodeHash;
        x.managerHash = mintManagerCodeHash;
        x.recorderHash = settlementCodeHash;
    }

    function _controlRoles() private view returns (StreamNativeCuratedSaleControl.Roles memory) {
        return StreamNativeCuratedSaleControl.Roles(
            address(roleRegistry), roleRegistryCodeHash, governanceAuthority
        );
    }
}

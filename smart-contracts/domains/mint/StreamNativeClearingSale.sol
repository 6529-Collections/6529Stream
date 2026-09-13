// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamClearingSaleExecution.sol";
import "./StreamClearingClock.sol";
import "./StreamClearingUnlock.sol";
import "../../interfaces/stream/revenue/IStreamNativeClearingSaleBinding.sol";
import "./StreamNativePriceProgram.sol";
import "../revenue/StreamSettlementContext.sol";
import "../revenue/StreamNativeSettlementAdmission.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Signed Dutch floor mints with immutable clearing, permanent rebates and typed financial legs.
/// @dev The shared guard covers every consumer mutation; governance gas raises retain their host authority.
contract StreamNativeClearingSale is
    IStreamNativeClearingSale,
    StreamSettlementContext,
    StreamGasParameterHost,
    IStreamArtistSaleFacts,
    IStreamNativeClearingSaleBinding,
    Ownable,
    ReentrancyGuard,
    ERC165
{
    struct DeploymentConfig {
        IStreamMintManager manager;
        IStreamPrimarySaleSettlement recorder;
        address platform;
        IStreamArtistAttribution artists;
        IStreamRevealFeeEscrow entropy;
        IStreamRoleRegistry roles;
        address authority;
        GasParameterConfig[3] parameters;
    }

    bytes32 private constant _SALE_SIGNATURE_GAS =
        keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT");
    bytes32 private constant _SALE_ARTIST_GAS =
        keccak256("6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT");
    bytes32 private constant _REVEAL_GAS = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
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
    uint256 public nextSaleNonce = 1;
    StreamClearingSaleState.State private _state;

    constructor(DeploymentConfig memory deployment)
        StreamSettlementContext(
            deployment.recorder.revenueResolver(), deployment.recorder.moduleRegistry()
        )
        StreamGasParameterHost(deployment.authority)
    {
        if (
            deployment.authority == address(0)
                || deployment.authority != splitFactory.governanceAuthority()
                || deployment.platform == address(0)
                || !StreamSettlementAdmission.isContract(address(deployment.manager))
                || !StreamSettlementAdmission.isContract(address(deployment.recorder))
                || !StreamSettlementAdmission.isContract(address(deployment.artists))
                || !StreamSettlementAdmission.isContract(address(deployment.entropy))
                || !StreamSettlementAdmission.isContract(address(deployment.roles))
                || !deployment.recorder.isStreamPrimarySaleSettlement()
                || deployment.recorder.core() != core
                || !IERC165(address(deployment.recorder))
                    .supportsInterface(type(IStreamNativePrimarySaleSettlement).interfaceId)
                || !IERC165(address(deployment.recorder))
                    .supportsInterface(type(IStreamNativeSupplementalSettlement).interfaceId)
                || address(IStreamMintReads(address(deployment.manager)).core()) != core
                || address(IStreamMintReads(address(deployment.manager)).moduleRegistry())
                    != moduleRegistry
                || !IStreamMintReads(address(deployment.manager)).isStreamMintManager()
                || deployment.artists.core() != core
                || revenueResolver.artistRegistry() != address(deployment.artists)
                || deployment.entropy.core() != core
                || !IERC165(address(deployment.entropy))
                    .supportsInterface(type(IStreamRevealFeeEscrow).interfaceId)
                || _read(address(deployment.roles), abi.encodeWithSignature("owner()"), gasleft())
                    != uint256(uint160(deployment.authority))
        ) {
            revert InvalidClearingSale();
        }
        if (
            keccak256(bytes(deployment.parameters[0].name)) != keccak256("SALE_ERC1271_GAS_LIMIT")
                || deployment.parameters[0].failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || keccak256(bytes(deployment.parameters[1].name))
                    != keccak256("SALE_ARTIST_AUTHORITY_GAS_LIMIT")
                || deployment.parameters[1].failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || keccak256(bytes(deployment.parameters[2].name))
                    != keccak256("REVEAL_ATTEMPT_GAS_LIMIT")
                || deployment.parameters[2].failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
        ) revert InvalidClearingSale();
        for (uint256 i; i < 3; ++i) {
            _registerGasParameter(deployment.parameters[i]);
        }
        mintManager = deployment.manager;
        primarySaleSettlement = address(deployment.recorder);
        platformSigner = deployment.platform;
        artistRegistry = deployment.artists;
        entropyCoordinator = deployment.entropy;
        roleRegistry = deployment.roles;
        mintManagerCodeHash = address(deployment.manager).codehash;
        settlementCodeHash = address(deployment.recorder).codehash;
        artistRegistryCodeHash = address(deployment.artists).codehash;
        entropyCodeHash = address(deployment.entropy).codehash;
        roleRegistryCodeHash = address(deployment.roles).codehash;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamNativeClearingSale).interfaceId
            || id == type(IStreamArtistSaleFacts).interfaceId
            || id == type(IStreamNativeSaleBinding).interfaceId
            || id == type(IStreamNativeClearingSaleBinding).interfaceId
            || super.supportsInterface(id);
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("NATIVE_PRIMARY_SALE_ADAPTER");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamNativeSaleBinding).interfaceId;
    }

    function saleConsentFacts(bytes32 id) external view override returns (uint256, bytes32) {
        ClearingSaleRecord storage record = _state.sales[id];
        if (record.saleNonce == 0) revert SaleConsentFactsUnavailable(id);
        return (record.config.collectionId, record.configHash);
    }

    function nativeSaleLifecycleBinding(bytes32 id)
        external
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory)
    {
        return _state.sales[id].lifecycle;
    }

    function registerClearingSale(ClearingSaleConfig calldata config)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32)
    {
        return StreamClearingSaleExecution.registerClearingSale(
            _state, _executionContext(), config, nextSaleNonce++
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
                uint8(4),
                collectionId,
                phaseId,
                nonce
            )
        );
    }

    function purchaseIdFor(bytes32 id, address buyer, uint256 nonce)
        public
        view
        override
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"),
                block.chainid,
                address(this),
                id,
                buyer,
                nonce
            )
        );
    }

    function saleRecord(bytes32 id) external view override returns (ClearingSaleRecord memory) {
        return _state.sales[id];
    }

    function purchaseRecord(bytes32 id)
        external
        view
        override
        returns (ClearingPurchaseRecord memory)
    {
        return StreamClearingSaleState.purchaseRecord(_state, id, address(mintManager));
    }

    function financialSale(bytes32 id) external view returns (StreamClearingSaleBook.Sale memory) {
        return _state.financial.sales[id];
    }

    function totalBuyerLiabilities() external view returns (uint256) {
        return _state.financial.totalBuyerLiability;
    }

    function currentPrice(bytes32 id) external view override returns (uint256) {
        if (_state.sales[id].saleNonce == 0) revert ClearingSaleUnavailable(id);
        return StreamDutchPricing.price(_state.sales[id].config.schedule, block.timestamp);
    }

    function nextPurchaseNonce(bytes32 id, address buyer) external view override returns (uint256) {
        return _state.financial.buyers[id][buyer].lastPurchaseNonce + 1;
    }

    function authorizationDigest(ClearingAuthorization calldata a)
        external
        view
        override
        returns (bytes32)
    {
        return StreamClearingSaleSupport.authorizationDigest(a);
    }

    function eip712Domain()
        external
        view
        override
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (
            0x0f,
            "6529StreamNativeClearingSale",
            "1",
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    function purchase(ClearingPurchaseData calldata data)
        external
        payable
        override
        nonReentrant
        returns (ClearingPurchaseResult memory)
    {
        return StreamClearingSaleExecution.purchase(_state, _executionContext(), data);
    }

    function fixClearingPrice(bytes32 id) external override nonReentrant {
        ClearingSaleRecord storage sale = _state.sales[id];
        if (sale.saleNonce == 0 || _state.financial.sales[id].status != 1) {
            revert ClearingSaleUnavailable(id);
        }
        if (_isPaused(id)) revert ClearingEntryPaused();
        (uint64 referenceTime,, uint64 deadline,) = saleDeadlines(id);
        if (block.timestamp < referenceTime) revert ClearingSaleUnavailable(id);
        if (block.timestamp > deadline) revert ClearingFinalizeExpired(deadline);
        // Immutable schedule reference, not this keeper's later invocation time.
        uint256 price = StreamDutchPricing.price(sale.config.schedule, referenceTime);
        StreamClearingSaleBook.fixPrice(_state.financial, id, price);
        sale.priceFixedAt = StreamClearingClock.now64();
        if (_state.financial.sales[id].status == 3) _freezeTerminalClock(id);
        emit DutchClearingFinalized(
            1,
            id,
            price,
            _state.financial.sales[id].purchasedQuantity,
            _state.financial.sales[id].scheduledSupplement
        );
        _emitDeadline(id);
    }

    function clearingPurchaseFacts(bytes32 id)
        public
        view
        override
        returns (StreamNativeSupplementalTypes.ClearingPurchaseFacts memory)
    {
        return StreamClearingSaleState.purchaseFacts(_state, id);
    }

    function activeNativeSupplementalSettlement(bytes32 purchaseId)
        external
        view
        override
        returns (bytes32)
    {
        return _state.financial.activePurchase == purchaseId ? _state.activeCandidate : bytes32(0);
    }

    function settlePurchaseSupplement(bytes32 purchaseId)
        external
        override
        nonReentrant
        returns (StreamNativeSupplementalTypes.NativeSupplementalResult memory)
    {
        return StreamClearingSaleExecution.settlePurchaseSupplement(
            _state, _executionContext(), purchaseId
        );
    }

    function refundableBalance(bytes32 id, address payer) external view override returns (uint256) {
        return StreamClearingSaleBook.refundableBalance(_state.financial, id, payer);
    }

    function synchronizeRebate(bytes32 id, address payer)
        external
        override
        nonReentrant
        returns (uint256)
    {
        return StreamClearingSaleExecution.announceRebate(_state, id, payer);
    }

    function claimRefund(bytes32 id, address recipient)
        external
        override
        nonReentrant
        returns (uint256)
    {
        return StreamClearingSaleExecution.claimRefund(_state, id, recipient);
    }

    function saleDeadlines(bytes32 id)
        public
        view
        override
        returns (uint64, uint64, uint64, uint64)
    {
        return StreamClearingSaleState.deadlines(_state, id);
    }

    function synchronizeSaleDeadline(bytes32 id) external override nonReentrant {
        _emitDeadline(id);
    }

    function _emitDeadline(bytes32 id) private {
        (uint64 refTime, uint64 nominal, uint64 effective, uint64 toll) = saleDeadlines(id);
        emit ClearingDeadlineUpdated(1, id, refTime, nominal, effective, toll);
    }

    function _freezeTerminalClock(bytes32 id) private {
        StreamClearingSaleState.freezeTerminalClock(_state, id);
    }

    function unlockRefunds(bytes32 id, uint8 reason) external override nonReentrant {
        ClearingSaleRecord storage sale = _state.sales[id];
        if (sale.saleNonce == 0) revert ClearingSaleUnavailable(id);
        if (_state.financial.sales[id].status == 4) return;
        bytes32 reasonHash;
        // Absolute escape runs before every external pointer/provider/authority read.
        if (
            block.timestamp > sale.config.absoluteEscapeDeadline
                || (block.timestamp == sale.config.absoluteEscapeDeadline && _isPaused(id))
        ) {
            reasonHash = keccak256("CLEARING_ABSOLUTE_ESCAPE");
        } else {
            (,, uint64 deadline,) = saleDeadlines(id);
            if (block.timestamp > deadline) {
                reasonHash = keccak256("CLEARING_FINALIZE_BY_EXPIRED");
            } else {
                reasonHash = StreamClearingUnlock.reasonHash(
                    _support(),
                    moduleRegistry,
                    moduleRegistryCodeHash,
                    primarySaleSettlement,
                    sale,
                    reason
                );
            }
        }
        if (reasonHash == 0) revert ClearingUnlockUnavailable(id, reason);
        StreamClearingSaleBook.unlock(_state.financial, id);
        _freezeTerminalClock(id);
        emit DutchClearingRefundUnlocked(1, id, reasonHash);
        _emitDeadline(id);
    }

    function closeSale(bytes32 id) external override onlyOwner nonReentrant {
        ClearingSaleRecord storage sale = _state.sales[id];
        if (
            sale.saleNonce == 0 || sale.earlyCloseAt != 0 || sale.soldOutAt != 0
                || _state.financial.sales[id].status != 1 || block.timestamp >= sale.config.closesAt
        ) {
            revert ClearingSaleUnavailable(id);
        }
        sale.earlyCloseAt = StreamClearingClock.now64();
        emit ClearingSaleClosed(1, id, sale.earlyCloseAt);
        _emitDeadline(id);
    }

    function paused() external view returns (bool) {
        return StreamClearingClock.globalPaused(_state.clock);
    }

    function salePaused(bytes32 id) external view returns (bool) {
        return StreamClearingClock.localPaused(_state.clock, id);
    }

    function _isPaused(bytes32 id) private view returns (bool) {
        return StreamClearingSaleState.isPaused(_state, id);
    }

    function pauseAdapter(bytes32 reason) external override nonReentrant {
        _requireRole(keccak256("ROLE_PAUSE_GUARDIAN"));
        StreamClearingClock.setGlobal(_state.clock, true);
        emit AdapterPaused(1, msg.sender, reason);
    }

    function unpauseAdapter(bytes32 reason) external override nonReentrant {
        _requireRole(keccak256("ROLE_UNPAUSE"));
        StreamClearingClock.setGlobal(_state.clock, false);
        emit AdapterUnpaused(1, msg.sender, reason);
    }

    function pauseSale(bytes32 id, bytes32 reason) external override nonReentrant {
        _setSalePause(id, reason, true);
    }

    function unpauseSale(bytes32 id, bytes32 reason) external override nonReentrant {
        _setSalePause(id, reason, false);
    }

    function _setSalePause(bytes32 id, bytes32 reason, bool value) private {
        if (_state.sales[id].saleNonce == 0) revert ClearingSaleUnavailable(id);
        _requireRole(value ? keccak256("ROLE_PAUSE_GUARDIAN") : keccak256("ROLE_UNPAUSE"));
        StreamClearingClock.setLocal(_state.clock, id, value);
        if (value) emit SalePaused(1, id, msg.sender, reason);
        else emit SaleUnpaused(1, id, msg.sender, reason);
        _emitDeadline(id);
    }

    function cancelAuthorization(bytes32 nonce) external override nonReentrant {
        if (_state.authorizationUsed[msg.sender][nonce]) {
            revert ClearingAuthorizationUsed(msg.sender, nonce);
        }
        _state.authorizationUsed[msg.sender][nonce] = true;
        emit ClearingAuthorizationCancelled(1, msg.sender, nonce);
    }

    function _requireRole(bytes32 role) private view {
        StreamDutchSaleSupport.requireRole(
            address(roleRegistry), roleRegistryCodeHash, governanceAuthority, role
        );
    }

    function _requireNativeContext() private view {
        StreamSettlementAdmission.requireRegistry(
            core, coreCodeHash, moduleRegistry, moduleRegistryCodeHash
        );
        if (
            address(revenueResolver).codehash != resolverCodeHash
                || address(splitFactory).codehash != factoryCodeHash
                || address(mintManager).codehash != mintManagerCodeHash
                || primarySaleSettlement.codehash != settlementCodeHash
        ) {
            revert InvalidClearingSale();
        }
    }

    function authorizationUsed(address signer, bytes32 nonce) external view returns (bool) {
        return _state.authorizationUsed[signer][nonce];
    }

    function executionIdByNonce(bytes32 id, uint256 nonce) external view returns (bytes32) {
        return _state.executionIdByNonce[id][nonce];
    }

    function executionStatus(bytes32 id) external view returns (uint8) {
        return _state.executionStatus[id];
    }

    function _executionContext() private view returns (StreamClearingSaleState.Context memory) {
        return StreamClearingSaleState.Context(
            _support(),
            splitFactory,
            moduleRegistry,
            primarySaleSettlement,
            coreCodeHash,
            moduleRegistryCodeHash,
            resolverCodeHash,
            factoryCodeHash,
            mintManagerCodeHash,
            settlementCodeHash,
            gasParameter(_REVEAL_GAS)
        );
    }

    function _rightsContext() private view returns (StreamPrimarySettlementRights.Context memory) {
        return StreamPrimarySettlementRights.Context(
            revenueResolver, splitFactory, splitFactory.splitWalletRuntimeCodeHash()
        );
    }

    function _support() private view returns (StreamDutchSaleSupport.Context memory) {
        return StreamDutchSaleSupport.Context(
            core,
            mintManager,
            revenueResolver,
            platformSigner,
            artistRegistry,
            artistRegistryCodeHash,
            entropyCoordinator,
            entropyCodeHash,
            gasParameter(_SALE_SIGNATURE_GAS),
            gasParameter(_SALE_ARTIST_GAS)
        );
    }

    function transferOwnership(address next) public override onlyOwner nonReentrant {
        super.transferOwnership(next);
    }

    function renounceOwnership() public override onlyOwner nonReentrant {
        super.renounceOwnership();
    }
}

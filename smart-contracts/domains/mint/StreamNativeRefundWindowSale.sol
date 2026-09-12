// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamRefundWindowBook.sol";
import "./StreamRefundWindowSupport.sol";
import "./StreamRefundUnlock.sol";
import "./StreamDeferredNativeSettlementCall.sol";
import "./StreamSaleConsent.sol";
import "../revenue/StreamSettlementContext.sol";
import "../revenue/StreamDeferredNativeSettlementAdmission.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Signed native purchases held as buyer liabilities until refund or official mint.
/// @dev New deferred schema only. Refund credit and deadline escape never read mutable providers.
contract StreamNativeRefundWindowSale is
    StreamRefundWindowBook,
    StreamSettlementContext,
    StreamGasParameterHost,
    IStreamArtistSaleFacts,
    Ownable,
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
    mapping(bytes32 => bytes32) private _activeSettlement;

    event RefundAdapterPauseUpdated(
        uint16 schemaVersion,
        bool paused,
        address indexed actor,
        bytes32 reasonHash,
        uint64 globalPauseTotal
    );
    event RefundSalePauseUpdated(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bool paused,
        address indexed actor,
        bytes32 reasonHash,
        uint64 unionPauseTotal
    );

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
                    .supportsInterface(type(IStreamDeferredNativePrimarySaleSettlement).interfaceId)
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
            revert InvalidRefundSale();
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
        ) revert InvalidRefundSale();
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
        return id == type(IStreamNativeRefundWindowSale).interfaceId
            || id == type(IStreamDeferredNativeSaleBinding).interfaceId
            || id == type(IStreamArtistSaleFacts).interfaceId || super.supportsInterface(id);
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("NATIVE_REFUND_WINDOW_SALE_ADAPTER");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamDeferredNativeSaleBinding).interfaceId;
    }

    function saleConsentFacts(bytes32 id)
        external
        view
        override
        returns (uint256 collectionId, bytes32 configHash)
    {
        RefundSaleRecord storage sale = _book._refundSales[id];
        if (sale.saleNonce == 0) revert SaleConsentFactsUnavailable(id);
        return (sale.config.collectionId, sale.configHash);
    }

    function nativeSaleLifecycleBinding(bytes32 id)
        external
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory)
    {
        return _book._refundSales[id].lifecycle;
    }

    function activeDeferredNativeSettlement(bytes32 id) external view returns (bytes32 commitment) {
        commitment = _activeSettlement[id];
        if (commitment == 0 || _book._purchases[id].status != 2) {
            revert RefundPurchaseUnavailable(id);
        }
    }

    function registerRefundSale(RefundSaleConfig calldata c)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 id)
    {
        _requireNativeContext();
        bytes32 baseline = StreamRefundWindowSupport.validateConfig(_support(), c);
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamDeferredNativeSettlementAdmission.capture(moduleRegistry, address(this));
        id = StreamRefundWindowBookStore.configure(
            _book,
            c,
            lifecycle,
            nextSaleNonce++,
            StreamRefundWindowSupport.windowPolicyHash(c),
            baseline
        );
    }

    function refundPurchaseAuthorizationDigest(RefundPurchaseAuthorization calldata a)
        external
        view
        override
        returns (bytes32)
    {
        return StreamRefundWindowSupport.authorizationDigest(a);
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
            hex"0f",
            "6529StreamNativeRefundWindowSale",
            "1",
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    function purchaseRefundWindow(RefundPurchaseData calldata d)
        external
        payable
        override
        nonReentrant
        returns (bytes32 id)
    {
        _requireNativeContext();
        RefundSaleRecord storage sale = _book._refundSales[d.authorization.saleId];
        if (sale.saleNonce == 0) revert RefundSaleUnavailable(d.authorization.saleId);
        if (_isPaused(d.authorization.saleId)) revert SaleEntryPaused();
        _requireConsent(d.authorization.saleId, sale);
        // New purchases require ACTIVE; retained finalization has its distinct grandfathering rule.
        StreamDeferredNativeSettlementAdmission.capture(moduleRegistry, address(this));
        (bytes32 digest, StreamRefundWindowSupport.ArtistAssociation memory a, uint256 fee) =
            StreamRefundWindowSupport.validatePurchase(_support(), sale, d);
        id = _capturePurchase(
            d,
            digest,
            PurchaseCapture(
                fee,
                a.artistId,
                a.generation,
                a.bindingHash,
                IStreamMintReads(address(mintManager))
                .phaseGate(sale.config.collectionId, sale.config.phaseId)
                .gate
            )
        );
    }

    function finalizeRefundWindow(bytes32 id)
        external
        override
        nonReentrant
        returns (RefundFinalizationResult memory r)
    {
        RefundPurchaseRecord storage p = _requirePurchase(id);
        if (p.status == 2) return _book._finalizationResults[id];
        if (p.status != 1) revert RefundWindowPurchaseTerminal(id);
        bytes32 saleId = p.authorization.saleId;
        if (_isPaused(saleId)) revert SaleEntryPaused();
        (uint64 refundDeadline, uint64 finalizeBy, uint64 toll) = purchaseDeadlines(id);
        if (block.timestamp < refundDeadline) revert RefundWindowStillOpen(id, refundDeadline);
        if (block.timestamp > finalizeBy) revert SaleFinalizeByExpired(finalizeBy);
        _requireNativeContext();
        RefundSaleRecord storage sale = _book._refundSales[saleId];
        _requireConsent(saleId, sale);
        (
            StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory d,
            IStreamMintManager.MintBatch memory batch
        ) = StreamRefundWindowSupport.prepareFinalization(
            _support(), id, sale, p, refundDeadline, finalizeBy, toll
        );
        return _completeFinalization(id, p, sale, d, batch);
    }

    function _completeFinalization(
        bytes32 id,
        RefundPurchaseRecord storage p,
        RefundSaleRecord storage sale,
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory d,
        IStreamMintManager.MintBatch memory batch
    ) private returns (RefundFinalizationResult memory r) {
        uint256 attemptGas = gasParameter(_REVEAL_GAS);
        StreamRefundWindowSupport.preflightReveal(_support(), sale.config.collectionId, attemptGas);
        uint256 balanceBefore = address(this).balance;
        _beginFinalization(id, p);
        _activeSettlement[id] =
            StreamDeferredNativeSettlementHash.candidateCommitment(primarySaleSettlement, d);
        {
            StreamPrimarySettlementTypes.PrimarySettlementResult memory settled =
                StreamDeferredNativeSettlementCall.settle(primarySaleSettlement, d);
            r.settlementKey = settled.settlementKey;
            r.escrowed = settled.escrowed;
        }
        _requireRetained(d.execution, sale, p);
        {
            (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) =
                mintManager.executeSingleStepMint(batch, "");
            if (
                tokens.length != 1 || tokens[0] == 0
                    || root != d.execution.operationIdentityCommitment || ids.length != 1
                    || ids[0] != d.execution.operationId
            ) revert RefundAccountingMismatch();
            r.tokenId = tokens[0];
            r.operationRoot = root;
            r.operationId = ids[0];
        }
        _requireRetained(d.execution, sale, p);
        (r.revealFeeForwarded, r.revealFeeRefunded) = StreamRefundWindowSupport.fundRevealAndAttempt(
            _support(), sale.config.collectionId, r.tokenId, p.savedRevealFee, attemptGas
        );
        _creditFeeRemainder(p, r.revealFeeRefunded);
        _requireRetained(d.execution, sale, p);
        r.amount = p.authorization.price;
        if (address(this).balance != balanceBefore - r.amount - r.revealFeeForwarded) {
            revert RefundAccountingMismatch();
        }
        _requireSolvent();
        r.executionId = d.execution.executionBinding.executionId;
        _book._finalizationResults[id] = r;
        delete _activeSettlement[id];
        emit RefundWindowFinalized(1, p.authorization.saleId, id, r.tokenId, 1);
    }

    function unlockRefund(bytes32 id, uint8 reason) external override nonReentrant {
        RefundPurchaseRecord storage p = _requirePurchase(id);
        if (p.status == 4) return;
        if (p.status != 1) revert RefundWindowPurchaseTerminal(id);
        bytes32 hash;
        if (reason == 0) {
            if (_timeUnlockable(id, p)) hash = keccak256("REFUND_FINALIZATION_DEADLINE");
        } else {
            hash = StreamRefundUnlock.reasonHash(
                StreamRefundUnlock.Context(
                    _support(),
                    moduleRegistry,
                    moduleRegistryCodeHash,
                    coreCodeHash,
                    mintManagerCodeHash,
                    primarySaleSettlement
                ),
                _book._refundSales[p.authorization.saleId],
                p,
                reason
            );
        }
        if (hash == 0) revert RefundUnlockNotAvailable(id, reason);
        _closeToRefund(id, p, 4);
        emit RefundWindowRefundUnlocked(1, p.authorization.saleId, id, hash);
    }

    function pauseAdapter(bytes32 reason) external override nonReentrant {
        _requireRole(keccak256("ROLE_PAUSE_GUARDIAN"));
        StreamRefundWindowBookStore.setGlobalPause(_book, true, reason);
    }

    function unpauseAdapter(bytes32 reason) external override nonReentrant {
        _requireRole(keccak256("ROLE_UNPAUSE"));
        StreamRefundWindowBookStore.setGlobalPause(_book, false, reason);
    }

    function pauseRefundSale(bytes32 id, bytes32 reason) external override nonReentrant {
        _setSalePause(id, reason, true);
    }

    function unpauseRefundSale(bytes32 id, bytes32 reason) external override nonReentrant {
        _setSalePause(id, reason, false);
    }

    function _setSalePause(bytes32 id, bytes32 reason, bool paused) private {
        if (_book._refundSales[id].saleNonce == 0) revert RefundSaleUnavailable(id);
        _requireRole(paused ? keccak256("ROLE_PAUSE_GUARDIAN") : keccak256("ROLE_UNPAUSE"));
        StreamRefundWindowBookStore.setSalePause(_book, id, paused, reason);
    }

    function _requireRole(bytes32 role) private view {
        StreamRefundWindowSupport.requireRole(
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
            revert InvalidRefundSale();
        }
    }

    function _requireConsent(bytes32 id, RefundSaleRecord storage sale) private view {
        StreamRefundWindowSupport.requireSaleConsent(
            _support(), sale.config.collectionId, id, sale.configHash
        );
    }

    function _requireRetained(
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
        RefundSaleRecord storage sale,
        RefundPurchaseRecord storage purchase
    ) private view {
        _requireNativeContext();
        _requireConsent(c.sale.settlementId, sale);
        StreamRefundWindowSupport.requireArtistAssociation(
            _support(),
            sale.config.collectionId,
            purchase.artistId,
            purchase.bindingGeneration,
            purchase.bindingHash
        );
        StreamDeferredNativeSettlementAdmission.requireAdmission(moduleRegistry, c);
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamDutchSaleSupport.sol";
import "./StreamNativePriceProgram.sol";
import "../revenue/StreamSettlementContext.sol";
import "../revenue/StreamNativeSettlementAdmission.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Signed standard native Dutch mints with per-sale excess pull credits.
/// @dev Positive price uses the official native recorder; declared zero never settles revenue.
contract StreamNativeDutchSale is
    IStreamNativeDutchSale,
    StreamSettlementContext,
    StreamGasParameterHost,
    IStreamArtistSaleFacts,
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
    bool public paused;
    uint256 public refundLiability;
    mapping(bytes32 => DutchSaleRecord) private _sales;
    mapping(bytes32 => mapping(address => uint256)) private _credits;
    mapping(address => uint256) public refundCredit;
    mapping(address => mapping(bytes32 => bool)) public authorizationUsed;
    mapping(bytes32 => mapping(uint256 => bytes32)) public executionIdByNonce;
    mapping(bytes32 => uint8) public executionStatus;

    event DutchSaleClosed(uint16 schemaVersion, bytes32 indexed saleId);
    event DutchAdapterPauseUpdated(
        uint16 schemaVersion, bool paused, address indexed actor, bytes32 reasonHash
    );
    event DutchSalePauseUpdated(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bool paused,
        address indexed actor,
        bytes32 reasonHash
    );
    event DutchAuthorizationCancelled(
        uint16 schemaVersion, address indexed artist, bytes32 indexed nonce
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
                    .supportsInterface(type(IStreamNativePrimarySaleSettlement).interfaceId)
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
            revert InvalidDutchSale();
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
        ) revert InvalidDutchSale();
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
        return id == type(IStreamNativeDutchSale).interfaceId
            || id == type(IStreamArtistSaleFacts).interfaceId
            || id == type(IStreamNativeSaleBinding).interfaceId || super.supportsInterface(id);
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("NATIVE_PRIMARY_SALE_ADAPTER");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamNativeSaleBinding).interfaceId;
    }

    function saleConsentFacts(bytes32 id) external view override returns (uint256, bytes32) {
        DutchSaleRecord storage record = _sales[id];
        if (record.saleNonce == 0) revert SaleConsentFactsUnavailable(id);
        return (record.config.collectionId, record.configHash);
    }

    function nativeSaleLifecycleBinding(bytes32 id)
        external
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory)
    {
        return _sales[id].lifecycle;
    }

    function registerDutchSale(DutchSaleConfig calldata config)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 id)
    {
        _requireNativeContext();
        (bytes32 baseline, bytes32 assignment) =
            StreamDutchSaleSupport.validateConfig(_support(), config);
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamNativeSettlementAdmission.capture(moduleRegistry, address(this));
        uint256 nonce = nextSaleNonce++;
        id = saleIdFor(config.collectionId, config.phaseId, nonce);
        bytes32 schedule =
            StreamDutchPricing.scheduleHash(config.schedule, block.chainid, address(this), id);
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_DUTCH_CONFIG_V1"),
                id,
                config,
                schedule,
                baseline,
                assignment,
                uint8(0),
                address(0)
            )
        );
        _sales[id] = DutchSaleRecord(
            config, nonce, hash, schedule, baseline, assignment, lifecycle, 0, false, false
        );
        emit SaleConfigured(
            1, id, config.collectionId, config.phaseId, 3, address(0), hash, baseline, 0
        );
        emit DutchSaleConfigured(1, id, nonce, schedule, assignment, config);
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
                uint8(3),
                collectionId,
                phaseId,
                nonce
            )
        );
    }

    function saleRecord(bytes32 id) external view override returns (DutchSaleRecord memory) {
        return _sales[id];
    }

    function currentPrice(bytes32 id) external view override returns (uint256) {
        if (_sales[id].saleNonce == 0) revert DutchSaleUnavailable(id);
        return StreamDutchPricing.price(_sales[id].config.schedule, block.timestamp);
    }

    function authorizationDigest(DutchAuthorization calldata a)
        external
        view
        override
        returns (bytes32)
    {
        return StreamDutchSaleSupport.authorizationDigest(a);
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
            "6529StreamNativeDutchSale",
            "1",
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    function purchase(DutchPurchaseData calldata d)
        external
        payable
        override
        nonReentrant
        returns (DutchPurchaseResult memory r)
    {
        _requireNativeContext();
        if (paused) revert DutchSaleUnavailable(d.authorization.saleId);
        if (authorizationUsed[d.authorization.artist][d.authorization.nonce]) {
            revert DutchAuthorizationUsed(d.authorization.artist, d.authorization.nonce);
        }
        if (executionIdByNonce[d.authorization.saleId][d.authorization.executionNonce] != 0) {
            revert DutchExecutionUsed(d.authorization.saleId, d.authorization.executionNonce);
        }
        (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch,
            StreamDutchSaleSupport.Capture memory captured
        ) = StreamDutchSaleSupport.prepare(_support(), _sales[d.authorization.saleId], d);
        if (msg.sender != c.sale.payer || msg.sender != c.executor) revert InvalidDutchSale();
        uint256 fee = captured.reveal.revealFeePerTokenWei;
        if (msg.value < fee) revert SaleRevealFeeBelowRequired(msg.value, fee);
        uint256 maximum = msg.value - fee;
        if (maximum < c.sale.amount) {
            revert DutchPaymentBelowPrice(maximum, c.sale.amount);
        }
        uint256 original = address(this).balance - msg.value;
        if (original < refundLiability) revert DutchAccountingMismatch();
        StreamNativeSettlementAdmission.requireAdmission(moduleRegistry, c);
        uint256 revealCap = gasParameter(_REVEAL_GAS);
        StreamDutchSaleSupport.preflightReveal(captured.reveal.requestMode, revealCap);
        authorizationUsed[d.authorization.artist][d.authorization.nonce] = true;
        executionIdByNonce[d.authorization.saleId][d.authorization.executionNonce] =
        c.executionBinding.executionId;
        executionStatus[c.executionBinding.executionId] = 1;
        ++_sales[d.authorization.saleId].mintedQuantity;
        r.revenueOutcome = c.sale.amount == 0 ? 1 : 2;
        r.executionId = c.executionBinding.executionId;
        r.operationRoot = c.operationIdentityCommitment;
        r.operationId = c.operationId;
        r.chargedAmount = c.sale.amount;
        r.revealFeeForwarded = fee;
        r.excessCredited = maximum - c.sale.amount;
        if (c.sale.amount != 0) {
            StreamPrimarySettlementTypes.PrimarySettlementResult memory settled =
                StreamNativePriceProgram.settle(primarySaleSettlement, c);
            r.settlementKey = settled.settlementKey;
            r.escrowed = settled.escrowed;
            _requireRetained(c, captured.association);
        }
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) =
            mintManager.executeSingleStepMint(batch, "");
        if (
            tokens.length != 1 || tokens[0] == 0 || root != c.operationIdentityCommitment
                || ids.length != 1 || ids[0] != c.operationId
        ) revert DutchMintResultInvalid();
        r.tokenId = tokens[0];
        _requireRetained(c, captured.association);
        StreamDutchSaleSupport.fundCapturedReveal(
            _support(), c.sale.collectionId, r.tokenId, captured.reveal, revealCap
        );
        _requireRetained(c, captured.association);
        if (address(this).balance != original + r.excessCredited) revert DutchAccountingMismatch();
        if (r.excessCredited != 0) {
            _credits[c.sale.settlementId][c.sale.payer] += r.excessCredited;
            refundCredit[c.sale.payer] += r.excessCredited;
            refundLiability += r.excessCredited;
            emit SalePaymentExcessCredited(1, c.sale.settlementId, c.sale.payer, r.excessCredited);
        }
        executionStatus[r.executionId] = 2;
        if (captured.consentEvidence != 0) {
            emit SaleConsentRecorded(
                1,
                c.sale.settlementId,
                c.sale.collectionId,
                d.authorization.saleConfigHash,
                captured.consentEvidence
            );
        }
        emit DutchPurchaseCompleted(1, c.sale.settlementId, r.executionId, c.sale.payer, r);
    }

    function refundableBalance(bytes32 id, address payer) external view override returns (uint256) {
        return _credits[id][payer];
    }

    function claimRefund(bytes32 id, address recipient) external override nonReentrant {
        uint256 amount = _credits[id][msg.sender];
        if (amount == 0) revert DutchCreditEmpty(id, msg.sender);
        if (recipient == address(0) || recipient == address(this)) {
            revert DutchTransferFailed(recipient);
        }
        uint256 beforeBalance = address(this).balance;
        if (beforeBalance < refundLiability) revert DutchAccountingMismatch();
        _credits[id][msg.sender] = 0;
        refundCredit[msg.sender] -= amount;
        refundLiability -= amount;
        (bool ok,) = recipient.call{ value: amount }("");
        if (!ok) revert DutchTransferFailed(recipient);
        if (address(this).balance != beforeBalance - amount) revert DutchAccountingMismatch();
        emit DutchRefundClaimed(1, id, msg.sender, recipient, amount);
    }

    function closeSale(bytes32 id) external override onlyOwner nonReentrant {
        if (_sales[id].saleNonce == 0 || _sales[id].closed) revert DutchSaleUnavailable(id);
        _sales[id].closed = true;
        emit DutchSaleClosed(1, id);
    }

    function pauseAdapter(bytes32 reason) external override nonReentrant {
        _requireRole(keccak256("ROLE_PAUSE_GUARDIAN"));
        if (paused) revert InvalidDutchSale();
        paused = true;
        emit DutchAdapterPauseUpdated(1, true, msg.sender, reason);
    }

    function unpauseAdapter(bytes32 reason) external override nonReentrant {
        _requireRole(keccak256("ROLE_UNPAUSE"));
        if (!paused) revert InvalidDutchSale();
        paused = false;
        emit DutchAdapterPauseUpdated(1, false, msg.sender, reason);
    }

    function pauseSale(bytes32 id, bytes32 reason) external override nonReentrant {
        _setSalePause(id, reason, true);
    }

    function unpauseSale(bytes32 id, bytes32 reason) external override nonReentrant {
        _setSalePause(id, reason, false);
    }

    function _setSalePause(bytes32 id, bytes32 reason, bool value) private {
        _requireRole(value ? keccak256("ROLE_PAUSE_GUARDIAN") : keccak256("ROLE_UNPAUSE"));
        if (_sales[id].saleNonce == 0 || _sales[id].paused == value) {
            revert DutchSaleUnavailable(id);
        }
        _sales[id].paused = value;
        emit DutchSalePauseUpdated(1, id, value, msg.sender, reason);
    }

    function cancelAuthorization(bytes32 nonce) external override nonReentrant {
        if (authorizationUsed[msg.sender][nonce]) revert DutchAuthorizationUsed(msg.sender, nonce);
        authorizationUsed[msg.sender][nonce] = true;
        emit DutchAuthorizationCancelled(1, msg.sender, nonce);
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
            revert InvalidDutchSale();
        }
    }

    function _requireRetained(
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
        StreamDutchSaleSupport.ArtistAssociation memory association
    ) private view {
        _requireNativeContext();
        StreamNativeSettlementAdmission.requireAdmission(moduleRegistry, c);
        StreamDutchSaleSupport.requireSaleConsent(
            _support(),
            c.sale.collectionId,
            c.sale.settlementId,
            _sales[c.sale.settlementId].configHash
        );
        StreamDutchSaleSupport.requireArtistAssociation(
            _support(),
            c.sale.collectionId,
            association.artistId,
            association.generation,
            association.bindingHash
        );
        if (c.sale.amount != 0) {
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

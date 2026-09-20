// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/mint/IStreamMintLedger.sol";
import "../../interfaces/stream/mint/IStreamMintManager.sol";
import "../../interfaces/stream/mint/IStreamMintPolicyGrace.sol";
import "../../interfaces/stream/mint/compatibility/IStreamMintModuleRegistry.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "./StreamMintCoreExecutor.sol";
import "./StreamMintGateValidator.sol";
import "./StreamMintOperationIdentity.sol";
import "./StreamMintArtistConsent.sol";
import "./StreamMintPhaseState.sol";
import "./StreamMintRevocation.sol";
import "./StreamMintManagerAccounting.sol";
import "./StreamPreparedNativeMintExecution.sol";
import "./StreamPreparedNativeContentExecution.sol";
import "./StreamPreparedNativeContentPurchaseExecution.sol";
import "./StreamPreparedNativeOfferExecution.sol";
import "./StreamMintManagerOfferTranscript.sol";
import { StreamMintManagerERC20OfferTranscript } from "./StreamMintManagerERC20OfferTranscript.sol";
import { StreamERC20OfferReceipt } from "./StreamERC20OfferReceipt.sol";
import { IStreamERC20OfferMint } from "../../interfaces/stream/mint/IStreamERC20OfferMint.sol";
import { StreamERC20OfferMintTypes } from "../../interfaces/stream/mint/StreamERC20OfferMintTypes.sol";
import "../../interfaces/stream/mint/IStreamMintSaleAuthorizationRevocation.sol";
import "../../interfaces/stream/mint/IStreamMintImmediateSaleAuthorizationRevocation.sol";
import "./StreamMintManagerTranscript.sol";
import "./StreamMintManagerExecution.sol";
import "./StreamMintManagerPolicy.sol";
import "./StreamMintPhaseFreezeControl.sol";
import "./StreamMintManagerViews.sol";
import "./StreamMintPreview.sol";
import "./StreamMintCounterReads.sol";
import "./StreamMintImport.sol";
import { StreamMintRoyaltyPolicy } from "./StreamMintRoyaltyPolicy.sol";
import {
    IStreamMintRoyaltyPolicy
} from "../../interfaces/stream/mint/IStreamMintRoyaltyPolicy.sol";
import "../parameters/StreamGasParameterHost.sol";

/// @notice Outside-Core phase policy and prepared mint execution manager.
contract StreamMintManager is
    IStreamMintManager,
    StreamMintTranscriptTypes,
    IStreamPreparedNativeMint,
    IStreamPreparedNativeContentMint,
    IStreamPreparedNativeContentPurchaseMint,
    IStreamPreparedNativeOfferMint,
    IStreamERC20OfferMint,
    IStreamMintSaleAuthorizationRevocation,
    IStreamMintImmediateSaleAuthorizationRevocation,
    IStreamPreparedNativeRightsMint,
    IStreamMintAuthorizationRevocation,
    IStreamMintRoyaltyPolicy,
    IStreamMintManagerImport,
    IStreamMintPolicyGrace,
    IStreamMintPhaseFreeze,
    IStreamMintPreview,
    IStreamMintCounterReads,
    Ownable,
    ReentrancyGuard,
    ERC165,
    StreamGasParameterHost
{
    /// @notice Retains the original public error ABI when the fixed policy worker rejects grace.
    error InvalidPolicyGrace(uint64 graceUntil);

    bytes32 public constant GGP_ARTIST_AUTHORITY_GAS_LIMIT =
        keccak256("6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT");
    bytes32 public constant GGP_MINT_REVOCATION_ERC1271_GAS_LIMIT =
        keccak256("6529STREAM_GGP_MINT_REVOCATION_ERC1271_GAS_LIMIT");
    bytes32 public constant GGP_PREPARED_NATIVE_CALLBACK_GAS_LIMIT =
        keccak256("6529STREAM_GGP_PREPARED_NATIVE_CALLBACK_GAS_LIMIT");
    event MintPhaseConsentRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bytes32 indexed policyHash,
        uint8 consentMode,
        bytes32 consentEvidenceHash
    );
    /// @notice Domain separator for active phase policy hashes.
    bytes32 public constant POLICY_DOMAIN = keccak256("6529STREAM_MINT_MANAGER_POLICY_V1");
    /// @notice Domain separator for phase configuration hashes.
    bytes32 public constant PHASE_CONFIG_DOMAIN =
        keccak256("6529STREAM_MINT_MANAGER_PHASE_CONFIG_V1");
    /// @notice Domain separator for ordered counter configuration hashes.
    bytes32 public constant COUNTER_CONFIG_DOMAIN =
        keccak256("6529STREAM_MINT_MANAGER_COUNTER_CONFIG_V1");
    /// @notice Domain separator for optional gate configuration hashes.
    bytes32 public constant GATE_CONFIG_DOMAIN =
        keccak256("6529STREAM_MINT_MANAGER_GATE_CONFIG_V1");
    /// @notice Domain separator for sorted executor set hashes.
    bytes32 public constant EXECUTOR_SET_DOMAIN =
        keccak256("6529STREAM_MINT_MANAGER_EXECUTOR_SET_V1");
    /// @notice Domain separator for manager-derived counter subjects.
    bytes32 public constant SUBJECT_DOMAIN = keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1");
    /// @notice Domain separator for counter resolution hashes.
    bytes32 public constant RESOLUTION_DOMAIN = keccak256("6529STREAM_MINT_COUNTER_RESOLUTION_V1");
    /// @notice Domain separators for the canonical batch-operation transcript.
    bytes32 public constant MINT_REQUEST_COMMITMENT_DOMAIN =
        keccak256("6529STREAM_MINT_REQUEST_COMMITMENT_V1");
    bytes32 public constant MINT_VALIDATED_RESULT_DOMAIN =
        keccak256("6529STREAM_MINT_VALIDATED_RESULT_V1");
    bytes32 public constant MINT_COUNTER_CONSUMPTIONS_DOMAIN =
        keccak256("6529STREAM_MINT_COUNTER_CONSUMPTIONS_V1");
    bytes32 public constant MINT_NULLIFIERS_DOMAIN = keccak256("6529STREAM_MINT_NULLIFIERS_V1");
    bytes32 public constant MINT_OPERATION_ROOT_DOMAIN =
        keccak256("6529STREAM_MINT_OPERATION_ROOT_V1");
    bytes32 public constant MINT_TOKEN_OPERATION_ID_DOMAIN =
        keccak256("6529STREAM_MINT_TOKEN_OPERATION_ID_V1");
    bytes32 public constant MINT_EXECUTION_PATH_SINGLE_STEP =
        keccak256("6529STREAM_MINT_EXECUTION_PATH_SINGLE_STEP_V1");
    bytes32 public constant MINT_EXECUTION_PATH_PREPARED =
        keccak256("6529STREAM_MINT_EXECUTION_PATH_PREPARED_V1");
    bytes32 public constant BATCH_RECIPIENTS_DOMAIN =
        keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1");
    bytes32 public constant BATCH_BENEFICIARIES_DOMAIN =
        keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1");
    bytes32 public constant BATCH_TOKEN_DATA_DOMAIN =
        keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1");
    bytes32 public constant BATCH_COMMITMENTS_DOMAIN =
        keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1");

    /// @notice Manager policy schema version encoded into policy hashes.
    uint16 public constant SCHEMA_VERSION = 1;
    /// @notice Launch hard cap for one prepared mint batch.
    uint32 public constant MAX_PHASE_BATCH_QUANTITY = 10;
    /// @notice Launch hard cap for enabled counters evaluated by one phase.
    uint16 public constant MAX_PHASE_COUNTERS = 16;
    /// @notice Launch hard cap for enabled executors included in one policy hash.
    uint16 public constant MAX_PHASE_EXECUTORS = 64;
    /// @notice StreamCore dependency that owns prepared mint hooks.
    IStreamCore public immutable core;
    /// @notice StreamMintLedger dependency that enforces phase counter consumption.
    IStreamMintLedger public immutable mintLedger;
    /// @notice Registry dependency that approves optional mint gate modules.
    IERC165 public immutable moduleRegistry;
    /// @notice Next nonce reserved for prepared mint operation IDs.
    uint256 public override nextOperationNonce;

    mapping(uint256 => mapping(bytes32 => StreamMintPhaseState.PhaseState)) private _phases;
    mapping(uint256 => mapping(bytes32 => MintGateConfig)) private _phaseGateConfigs;
    /// @notice Active manager policy hash for each configured phase.
    mapping(uint256 => mapping(bytes32 => bytes32)) public override phasePolicyHash;
    /// @notice Whether an executor may mint for a configured phase.
    mapping(uint256 => mapping(bytes32 => mapping(address => bool))) public override phaseExecutor;
    mapping(uint256 => mapping(bytes32 => bytes32[])) private _phaseCounterIds;
    mapping(uint256 => mapping(bytes32 => mapping(bytes32 => MintCounterConfig))) private
        _counterConfigs;
    mapping(uint256 => mapping(bytes32 => address[])) private _phaseExecutors;
    mapping(uint256 => mapping(bytes32 => mapping(address => uint256))) private _phaseExecutorIndex;
    StreamPreparedNativeMintExecution.State private _preparedNative;
    StreamPreparedNativeContentExecution.State private _preparedContent;
    StreamPreparedNativeRightsExecution.State private _preparedRights;
    mapping(uint256 => mapping(bytes32 => IStreamMintRoyaltyPolicy.Policy)) private _phaseRoyalties;
    mapping(uint256 => bool) public hasRegisteredPhasePolicy;
    StreamPreparedNativeContentExecution.State private _preparedOffer;

    constructor(IStreamCore core_, IStreamMintLedger mintLedger_, IERC165 moduleRegistry_)
        StreamGasParameterHost(StreamMintArtistConsent.governance(
                address(core_), address(moduleRegistry_)
            ))
    {
        if (address(core_).code.length == 0) {
            revert InvalidCoreContract(address(core_));
        }
        try core_.supportsInterface(0x80ac58cd) returns (bool ok) {
            if (!ok) {
                revert InvalidCoreContract(address(core_));
            }
        } catch {
            revert InvalidCoreContract(address(core_));
        }

        if (address(mintLedger_).code.length == 0) {
            revert InvalidMintLedgerContract(address(mintLedger_));
        }
        try mintLedger_.isStreamMintLedger() returns (bool ok) {
            if (!ok) {
                revert InvalidMintLedgerContract(address(mintLedger_));
            }
        } catch {
            revert InvalidMintLedgerContract(address(mintLedger_));
        }

        if (!StreamMintGateValidator.isSupportedRegistry(moduleRegistry_)) {
            revert InvalidMintModuleRegistry(address(moduleRegistry_));
        }

        core = core_;
        mintLedger = mintLedger_;
        moduleRegistry = moduleRegistry_;
        _registerGasParameter(GasParameterConfig("ARTIST_AUTHORITY_GAS_LIMIT", 150_000, 150_000, 2));
        _registerGasParameter(GasParameterConfig("MINT_GATE_GAS_LIMIT", 400_000, 400_000, 2));
        _registerGasParameter(
            GasParameterConfig("MINT_REVOCATION_ERC1271_GAS_LIMIT", 400_000, 350_000, 2)
        );
        _registerGasParameter(
            GasParameterConfig("PREPARED_NATIVE_CALLBACK_GAS_LIMIT", 4_000_000, 500_000, 2)
        );
    }

    /// @notice Returns true for deployment validation.
    function isStreamMintManager() external pure override returns (bool) {
        return true;
    }

    /// @notice Advertises the manager interface required by Core satellite validation.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, ERC165)
        returns (bool)
    {
        return StreamMintManagerViews.supportsMintInterface(interfaceId)
            || super.supportsInterface(interfaceId);
    }

    function importMintState(bytes calldata encodedBatch) external override onlyOwner nonReentrant {
        StreamMintImport.forward(address(mintLedger), encodedBatch);
    }

    function mintTicketAuthorizationId(
        StreamMintTicketTypes.MintTicket calldata ticket,
        address verifyingGate
    ) external view override returns (bytes32) {
        return StreamMintRevocation.ticketId(ticket, verifyingGate);
    }

    function mintOfferAuthorizationId(StreamPrivateSaleTypes.SaleOffer calldata offer)
        external
        view
        override
        returns (bytes32)
    {
        return StreamMintRevocation.offerId(offer);
    }

    function voidMintTicket(
        StreamMintTicketTypes.MintTicket calldata ticket,
        address verifyingGate,
        bytes calldata revocationSignature
    ) external override nonReentrant returns (bytes32) {
        return StreamMintRevocation.voidTicket(
            _revocationContext(), ticket, verifyingGate, revocationSignature
        );
    }

    function voidMintOffer(
        StreamPrivateSaleTypes.SaleOffer calldata offer,
        uint8 buyerKind,
        bytes calldata revocationSignature
    ) external override nonReentrant returns (bytes32) {
        return StreamMintRevocation.voidOffer(
            _revocationContext(), offer, buyerKind, revocationSignature
        );
    }

    function mintSaleAuthorizationId(StreamPrivateSaleTypes.SaleAuthorization calldata authorization)
        external view override returns (bytes32)
    {
        return StreamMintRevocation.saleAuthorizationId(authorization);
    }

    function voidMintSaleAuthorization(
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        bytes calldata revocationSignature
    ) external override nonReentrant returns (bytes32) {
        return StreamMintRevocation.voidSaleAuthorization(_revocationContext(), authorization, revocationSignature);
    }

    function voidMintImmediateSaleAuthorization(
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        address claimedAuthorizer,
        uint8 authorizerKind,
        bytes calldata revocationSignature
    ) external override nonReentrant returns (bytes32) {
        return StreamMintRevocation.voidImmediateSaleAuthorization(
            _revocationContext(), authorization, claimedAuthorizer, authorizerKind, revocationSignature
        );
    }

    function _revocationContext() private view returns (StreamMintRevocation.Context memory) {
        return StreamMintRevocation.Context(
            address(core),
            address(mintLedger),
            _gasParameterValue(GGP_MINT_REVOCATION_ERC1271_GAS_LIMIT)
        );
    }

    /// @notice Configures and registers a launch-static phase policy.
    function configurePhase(
        uint256 collectionId,
        bytes32 phaseId,
        MintPhaseConfig calldata config,
        MintGateConfig calldata gateConfig,
        bytes32[] calldata counterIds,
        MintCounterConfig[] calldata counterConfigs
    ) external override onlyOwner nonReentrant returns (bytes32 policyHash) {
        _requirePhaseIdentity(collectionId, phaseId);
        if (_phases[collectionId][phaseId].exists) {
            revert MintPhaseAlreadyConfigured(collectionId, phaseId);
        }
        StreamMintRoyaltyPolicy.requireCurrent(
            _phaseRoyalties[collectionId][phaseId],
            _royaltyContext(),
            collectionId,
            phaseId,
            config.configHash,
            false
        );
        // Atomic with policy admission: a reverted registration leaves no history.
        hasRegisteredPhasePolicy[collectionId] = true;
        return StreamMintPhaseState.configure(
            _phases[collectionId][phaseId],
            _phaseGateConfigs[collectionId],
            _phaseCounterIds[collectionId][phaseId],
            _counterConfigs[collectionId][phaseId],
            _phaseExecutors[collectionId][phaseId],
            phaseExecutor[collectionId][phaseId],
            _phaseExecutorIndex[collectionId][phaseId],
            phasePolicyHash[collectionId],
            msg.data[4:],
            StreamMintPhaseState.ConfigurationContext(
                _policyContext(collectionId, phaseId),
                address(core),
                _gasParameterValue(GGP_ARTIST_AUTHORITY_GAS_LIMIT),
                MAX_PHASE_BATCH_QUANTITY,
                MAX_PHASE_COUNTERS
            )
        );
    }

    /// @notice Enables or disables a caller for a configured phase.
    function setPhaseExecutor(uint256 collectionId, bytes32 phaseId, address executor, bool allowed)
        external
        override
        onlyOwner
        nonReentrant
    {
        _setPhaseExecutor(collectionId, phaseId, executor, allowed, 0);
    }

    /// @inheritdoc IStreamMintPolicyGrace
    function setPhaseExecutorWithGrace(
        uint256 collectionId,
        bytes32 phaseId,
        address executor,
        bool allowed,
        uint64 graceUntil
    ) external override onlyOwner nonReentrant {
        _setPhaseExecutor(collectionId, phaseId, executor, allowed, graceUntil);
    }

    function _setPhaseExecutor(
        uint256 collectionId,
        bytes32 phaseId,
        address executor,
        bool allowed,
        uint64 graceUntil
    ) private {
        _requireConfiguredPhase(collectionId, phaseId);
        StreamMintManagerPolicy.updateExecutor(
            _phases[collectionId][phaseId],
            _phaseGateConfigs[collectionId][phaseId],
            _phaseCounterIds[collectionId][phaseId],
            _counterConfigs[collectionId][phaseId],
            phaseExecutor[collectionId][phaseId],
            _phaseExecutors[collectionId][phaseId],
            _phaseExecutorIndex[collectionId][phaseId],
            phasePolicyHash[collectionId],
            StreamMintManagerPolicy.ExecutorUpdate(
                StreamMintManagerPolicy.Context(_policyContext(collectionId, phaseId), address(core)),
                executor,
                allowed,
                graceUntil,
                MAX_PHASE_EXECUTORS
            )
        );
    }

    function freezePhase(uint256 collectionId, bytes32 phaseId)
        external override onlyOwner nonReentrant
    {
        _requireConfiguredPhase(collectionId, phaseId);
        StreamMintPhaseFreezeControl.freeze(collectionId, phaseId);
    }

    function phaseFrozen(uint256 collectionId, bytes32 phaseId)
        external view override returns (bool)
    {
        return StreamMintPhaseFreezeControl.frozen(
            address(mintLedger), address(this), collectionId, phaseId
        );
    }

    function phaseExecutors(uint256 collectionId, bytes32 phaseId)
        external view override returns (address[] memory)
    {
        bytes memory encoded = StreamMintManagerViews.executorsEncoded(
            _phaseExecutors[collectionId][phaseId]
        );
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function phaseFreezeTransitionHashes(uint256 collectionId, bytes32 phaseId)
        external view override returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        return StreamMintPhaseFreezeControl.transition(address(this), collectionId, phaseId);
    }

    /// @notice Pauses or unpauses a configured phase.
    function setPhasePaused(uint256 collectionId, bytes32 phaseId, bool paused)
        external
        override
        onlyOwner
        nonReentrant
    {
        StreamMintPhaseState.PhaseState storage phaseState =
            _requireConfiguredPhase(collectionId, phaseId);
        StreamMintManagerPolicy.pause(
            phaseState, collectionId, phaseId, paused, phasePolicyHash[collectionId][phaseId]
        );
    }

    /// @notice Executes the immediate Core manager path atomically.
    function executeSingleStepMint(MintBatch calldata batch, bytes calldata gateData)
        external
        override
        nonReentrant
        returns (uint256[] memory tokenIds, bytes32 operationRoot, bytes32[] memory operationIds)
    {
        OperationTranscript memory transcript =
            _operationTranscript(batch, gateData, MINT_EXECUTION_PATH_SINGLE_STEP);
        _reserveOperationNonces(transcript.firstOperationNonce, transcript.quantity);
        return StreamMintManagerExecution.singleStep(
            _executionContext(),
            _phaseGateConfigs[batch.collectionId][batch.phaseId],
            batch,
            transcript
        );
    }

    /// @notice Previews the independently authenticated original offer transcript.
    function previewERC20OfferMintOperation(
        MintBatch calldata batch,
        StreamERC20OfferMintTypes.GateData calldata
    ) external view override returns (bytes32 operationRoot, bytes32[] memory operationIds) {
        OperationTranscript memory transcript = _erc20OfferOperationTranscript(batch, msg.data[4:]);
        return (transcript.operationRoot, transcript.operationIds);
    }

    /// @notice Mints only after the official recorder has stored this exact ERC20 offer settlement.
    function executeERC20OfferMint(
        MintBatch calldata batch,
        StreamERC20OfferMintTypes.GateData calldata,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata
    ) external override nonReentrant returns (
        uint256[] memory tokenIds, bytes32 operationRoot, bytes32[] memory operationIds
    ) {
        OperationTranscript memory transcript = _erc20OfferOperationTranscript(batch, msg.data[4:]);
        // Strict decoding of the original typed offer/candidate stays in the fixed worker.
        // The public wire ABI and original caller are retained while preserving runtime headroom.
        StreamERC20OfferReceipt.requireReceiptArguments(
            address(core), address(moduleRegistry), _preparedNative.recorder,
            _preparedNative.recorderCodeHash, batch, msg.data[4:], transcript
        );
        _reserveOperationNonces(transcript.firstOperationNonce, transcript.quantity);
        return StreamMintManagerExecution.singleStep(
            _executionContext(), _phaseGateConfigs[batch.collectionId][batch.phaseId], batch, transcript
        );
    }

    /// @notice Executes the prepared Core manager path atomically.
    function executePreparedMint(MintBatch calldata batch, bytes calldata gateData)
        external
        override
        nonReentrant
        returns (uint256[] memory tokenIds, bytes32 operationRoot, bytes32[] memory operationIds)
    {
        OperationTranscript memory transcript =
            _operationTranscript(batch, gateData, MINT_EXECUTION_PATH_PREPARED);
        _reserveOperationNonces(transcript.firstOperationNonce, transcript.quantity);
        return StreamMintManagerExecution.prepared(
            _executionContext(),
            _phaseGateConfigs[batch.collectionId][batch.phaseId],
            batch,
            transcript
        );
    }

    /// @notice Previews the single-step identity transcript for the current manager state.
    /// @dev Matches execution only while the nonce, phase policy/grace, and gate result stay unchanged.
    function previewSingleStepMintOperation(MintBatch calldata batch, bytes calldata gateData)
        external
        view
        override
        returns (bytes32 operationRoot, bytes32[] memory operationIds)
    {
        OperationTranscript memory transcript =
            _operationTranscript(batch, gateData, MINT_EXECUTION_PATH_SINGLE_STEP);
        return (transcript.operationRoot, transcript.operationIds);
    }

    /// @notice Advisory eligibility for an explicit executor; never reserves or authorizes a mint.
    function canMint(MintBatch calldata batch, address executor, bytes calldata gateData)
        external view override returns (IStreamMintPreview.MintPreview memory)
    {
        bytes memory encoded = StreamMintPreview.read(batch, executor, gateData);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function previewPreparedNativeMintOperation(MintBatch calldata batch, bytes calldata gateData)
        external
        view
        override
        returns (bytes32 operationRoot, bytes32[] memory operationIds)
    {
        OperationTranscript memory transcript =
            _operationTranscript(batch, gateData, MINT_EXECUTION_PATH_PREPARED);
        if (transcript.quantity != 1) revert InvalidPreparedNativeMint();
        return (transcript.operationRoot, transcript.operationIds);
    }

    function activePreparedNativeMint()
        external
        view
        override
        returns (StreamPreparedNativeSettlementTypes.Facts memory)
    {
        bytes memory encoded = StreamMintManagerViews.preparedEncoded(_preparedNative.active);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function bindPreparedNativeRecorder(address recorder) external override onlyOwner nonReentrant {
        StreamPreparedNativeMintExecution.bindRecorder(
            _preparedNative, address(core), address(moduleRegistry), recorder
        );
        emit PreparedNativeRecorderBound(
            recorder,
            _preparedNative.recorderCodeHash,
            _preparedNative.boundAt,
            _preparedNative.moduleRevision
        );
    }

    function preparedNativeRecorder()
        external
        view
        override
        returns (address, bytes32, uint64, uint64)
    {
        return (
            _preparedNative.recorder,
            _preparedNative.recorderCodeHash,
            _preparedNative.boundAt,
            _preparedNative.moduleRevision
        );
    }

    function executePreparedNativeMint(
        MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 intentHash
    )
        external
        override
        nonReentrant
        returns (
            uint256 tokenId,
            bytes32 operationRoot,
            bytes32 operationId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        )
    {
        OperationTranscript memory transcript =
            _operationTranscript(batch, gateData, MINT_EXECUTION_PATH_PREPARED);
        if (transcript.quantity != 1) revert InvalidPreparedNativeMint();
        _reserveOperationNonces(transcript.firstOperationNonce, transcript.quantity);
        return StreamMintManagerExecution.paid(
            _executionContext(),
            _phaseGateConfigs[batch.collectionId][batch.phaseId],
            _preparedNative,
            batch,
            intentHash,
            transcript
        );
    }

    function executePreparedNativeRightsMint(
        MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 intentHash
    )
        external
        override
        nonReentrant
        returns (
            uint256 tokenId,
            bytes32 operationRoot,
            bytes32 operationId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        )
    {
        OperationTranscript memory transcript =
            _operationTranscript(batch, gateData, MINT_EXECUTION_PATH_PREPARED);
        if (transcript.quantity != 1) revert InvalidPreparedNativeMint();
        _reserveOperationNonces(transcript.firstOperationNonce, transcript.quantity);
        return StreamMintManagerExecution.rightsPaid(
            _executionContext(),
            _phaseGateConfigs[batch.collectionId][batch.phaseId],
            _preparedNative,
            _preparedRights,
            batch,
            intentHash,
            transcript
        );
    }

    function activePreparedNativeRights()
        external
        view
        override
        returns (StreamPreparedNativeRightsTypes.Facts memory)
    {
        bytes memory encoded = StreamMintManagerViews.rightsEncoded(_preparedRights.active);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function executePreparedNativeContentMint(
        MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 intentHash
    )
        external
        override
        nonReentrant
        returns (
            uint256 tokenId,
            bytes32 operationRoot,
            bytes32 operationId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        )
    {
        StreamPreparedNativeContentExecution.admit(
            _preparedContent, address(moduleRegistry), batch, gateData, intentHash
        );
        OperationTranscript memory transcript =
            _operationTranscript(batch, gateData, MINT_EXECUTION_PATH_PREPARED);
        if (transcript.quantity != 1) revert InvalidPreparedNativeMint();
        _reserveOperationNonces(transcript.firstOperationNonce, transcript.quantity);
        return StreamMintManagerExecution.contentPaid(
            _executionContext(),
            _phaseGateConfigs[batch.collectionId][batch.phaseId],
            _preparedNative,
            _preparedContent,
            batch,
            gateData,
            intentHash,
            transcript
        );
    }

    function executePreparedNativeContentPurchaseMint(
        MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 intentHash
    )
        external
        override
        nonReentrant
        returns (
            uint256 tokenId,
            bytes32 operationRoot,
            bytes32 operationId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        )
    {
        StreamPreparedNativeContentPurchaseExecution.admit(
            _preparedContent, address(moduleRegistry), batch, gateData, intentHash
        );
        OperationTranscript memory transcript =
            _operationTranscript(batch, gateData, MINT_EXECUTION_PATH_PREPARED);
        if (transcript.quantity != 1) revert InvalidPreparedNativeMint();
        _reserveOperationNonces(transcript.firstOperationNonce, transcript.quantity);
        return StreamMintManagerExecution.contentPurchasePaid(
            _executionContext(),
            _phaseGateConfigs[batch.collectionId][batch.phaseId],
            _preparedNative,
            _preparedContent,
            batch,
            gateData,
            intentHash,
            transcript
        );
    }

    function executePreparedNativeOfferMint(
        MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 intentHash
    )
        external
        override
        nonReentrant
        returns (
            uint256 tokenId,
            bytes32 operationRoot,
            bytes32 operationId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        )
    {
        StreamPreparedNativeOfferExecution.admit(
            _preparedOffer, address(moduleRegistry), batch, gateData, intentHash
        );
        OperationTranscript memory transcript =
            _offerOperationTranscript(batch, gateData, MINT_EXECUTION_PATH_PREPARED);
        if (transcript.quantity != 1) revert InvalidPreparedNativeMint();
        _reserveOperationNonces(transcript.firstOperationNonce, transcript.quantity);
        return StreamMintManagerExecution.offerPaid(
            _executionContext(),
            _phaseGateConfigs[batch.collectionId][batch.phaseId],
            _preparedNative,
            _preparedOffer,
            batch,
            gateData,
            intentHash,
            transcript
        );
    }

    function activePreparedNativeOfferContent()
        external view override returns (StreamPreparedNativeContentTypes.Facts memory)
    {
        bytes memory encoded = StreamMintManagerViews.contentEncoded(_preparedOffer.active);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function preparedNativeOfferAdmission() external view override returns (bytes32) {
        return _preparedOffer.admissionHash;
    }

    function activePreparedNativeContent()
        external
        view
        override
        returns (StreamPreparedNativeContentTypes.Facts memory)
    {
        bytes memory encoded = StreamMintManagerViews.contentEncoded(_preparedContent.active);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function preparedNativeContentAdmission() external view override returns (bytes32) {
        return _preparedContent.admissionHash;
    }

    /// @notice Returns immutable phase config plus existence.
    function phase(uint256 collectionId, bytes32 phaseId)
        external
        view
        override
        returns (bool exists, MintPhaseConfig memory config)
    {
        StreamMintPhaseState.PhaseState storage phaseState = _phases[collectionId][phaseId];
        bytes memory encoded = StreamMintManagerViews.phaseEncoded(phaseState);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    /// @notice Returns manager-scoped authorization replay state independent of the caller.
    function isAuthorizationUsed(bytes32 authorizationId) external view override returns (bool) {
        _counterRead();
    }

    function rawCounterValue(bytes32 valueKey) external view override returns (uint64) {
        _counterRead();
    }

    function counterValue(uint256 collectionId, bytes32 phaseId, bytes32 counterId, bytes32 subjectKey)
        external view override returns (uint64)
    {
        _counterRead();
    }

    function remainingForCounter(uint256 collectionId, bytes32 phaseId, bytes32 counterId, bytes32 subjectKey)
        external view override returns (uint64)
    {
        _counterRead();
    }

    function resolveCounter(IStreamMintCounterReads.CounterKeyContext calldata context)
        external view override returns (IStreamMintCounterReads.CounterResolution memory resolution)
    {
        _counterRead();
    }

    function remainingForResolvedCounter(IStreamMintCounterReads.CounterKeyContext calldata context)
        external view override returns (IStreamMintCounterReads.CounterResolution memory, uint64, uint64)
    {
        _counterRead();
    }

    function _counterRead() private view {
        bytes memory encoded = StreamMintCounterReads.read(msg.data);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    /// @notice Returns manager-scoped nullifier replay state independent of the caller.
    function isNullifierUsed(bytes32 nullifier) external view override returns (bool) {
        _counterRead();
    }

    /// @notice Returns manager-scoped operation-root replay state independent of the caller.
    function isOperationRootUsed(bytes32 operationRoot) external view override returns (bool) {
        _counterRead();
    }

    /// @notice Returns the immediate predecessor policy and its grace expiry.
    function phasePolicyGrace(uint256 collectionId, bytes32 phaseId)
        external
        view
        override
        returns (bytes32 previousPolicyHash, uint64 graceUntil)
    {
        _counterRead();
    }

    /// @notice Returns the ordered counter IDs for a phase.
    function phaseCounterIds(uint256 collectionId, bytes32 phaseId)
        external
        view
        override
        returns (bytes32[] memory)
    {
        bytes memory encoded = StreamMintManagerViews.counterIdsEncoded(
            _phaseCounterIds[collectionId][phaseId]
        );
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    /// @notice Returns one manager-side counter config.
    function counterConfig(uint256 collectionId, bytes32 phaseId, bytes32 counterId)
        external
        view
        override
        returns (MintCounterConfig memory)
    {
        bytes memory encoded = StreamMintManagerViews.counterEncoded(_counterConfigs[collectionId][phaseId][counterId]);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    /// @notice Returns one phase's optional gate config.
    function phaseGate(uint256 collectionId, bytes32 phaseId)
        external
        view
        override
        returns (MintGateConfig memory)
    {
        bytes memory encoded = StreamMintManagerViews.gateEncoded(_phaseGateConfigs[collectionId][phaseId]);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    /// @notice Previews the manager-derived subject key for one token/counter context.
    function previewSubjectKey(
        CounterKeyMode keyMode,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        address payer,
        address recipient,
        address executor,
        address authorizer,
        bytes32 contextHash
    ) external view override returns (bytes32) {
        return StreamMintManagerViews.subject(msg.data[4:], address(mintLedger));
    }

    /// @notice Previews the canonical ledger value key for a derived subject.
    function previewCounterValueKey(
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        bytes32 subjectKey
    ) external view override returns (bytes32) {
        return StreamMintManagerAccounting.previewValue(
            address(mintLedger), collectionId, phaseId, counterId, subjectKey
        );
    }

    function _requireConfiguredPhase(uint256 collectionId, bytes32 phaseId)
        private
        view
        returns (StreamMintPhaseState.PhaseState storage phaseState)
    {
        phaseState = _phases[collectionId][phaseId];
        if (!phaseState.exists) {
            revert MintPhaseDoesNotExist(collectionId, phaseId);
        }
    }

    function _requireExecutablePhase(MintBatch calldata request)
        private
        view
        returns (StreamMintPhaseState.PhaseState storage phaseState)
    {
        phaseState = _phases[request.collectionId][request.phaseId];
        StreamMintManagerPolicy.requireExecutable(
            phaseState, request.collectionId, request.phaseId,
            phaseExecutor[request.collectionId][request.phaseId][msg.sender]
        );
    }

    function _operationTranscript(
        MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 executionPath
    ) private view returns (OperationTranscript memory transcript) {
        StreamMintPhaseState.PhaseState storage phaseState = _requireExecutablePhase(batch);
        StreamMintRoyaltyPolicy.requireCurrent(
            _phaseRoyalties[batch.collectionId][batch.phaseId],
            _royaltyContext(),
            batch.collectionId,
            batch.phaseId,
            phaseState.config.configHash,
            executionPath == MINT_EXECUTION_PATH_SINGLE_STEP
        );
        return StreamMintManagerTranscript.build(
            batch,
            gateData,
            executionPath,
            phaseState,
            _phaseGateConfigs[batch.collectionId][batch.phaseId],
            _phaseCounterIds[batch.collectionId][batch.phaseId],
            _counterConfigs[batch.collectionId][batch.phaseId],
            _phaseExecutors[batch.collectionId][batch.phaseId],
            StreamMintManagerTranscript.Context(
                address(core),
                _policyContext(batch.collectionId, batch.phaseId),
                phasePolicyHash[batch.collectionId][batch.phaseId],
                nextOperationNonce,
                _gasParameterValue(GGP_ARTIST_AUTHORITY_GAS_LIMIT)
            )
        );
    }

    function _offerOperationTranscript(
        MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 executionPath
    ) private view returns (OperationTranscript memory transcript) {
        StreamMintPhaseState.PhaseState storage phaseState = _requireExecutablePhase(batch);
        StreamMintRoyaltyPolicy.requireCurrent(
            _phaseRoyalties[batch.collectionId][batch.phaseId],
            _royaltyContext(),
            batch.collectionId,
            batch.phaseId,
            phaseState.config.configHash,
            executionPath == MINT_EXECUTION_PATH_SINGLE_STEP
        );
        return StreamMintManagerOfferTranscript.build(
            batch,
            gateData,
            executionPath,
            phaseState,
            _phaseGateConfigs[batch.collectionId][batch.phaseId],
            _phaseCounterIds[batch.collectionId][batch.phaseId],
            _counterConfigs[batch.collectionId][batch.phaseId],
            _phaseExecutors[batch.collectionId][batch.phaseId],
            StreamMintManagerOfferTranscript.Context(
                address(core),
                _policyContext(batch.collectionId, batch.phaseId),
                phasePolicyHash[batch.collectionId][batch.phaseId],
                nextOperationNonce,
                _gasParameterValue(GGP_ARTIST_AUTHORITY_GAS_LIMIT)
            )
        );
    }

    function _erc20OfferOperationTranscript(
        MintBatch calldata batch,
        bytes calldata arguments
    ) private view returns (OperationTranscript memory transcript) {
        StreamMintPhaseState.PhaseState storage phaseState = _requireExecutablePhase(batch);
        StreamMintRoyaltyPolicy.requireCurrent(
            _phaseRoyalties[batch.collectionId][batch.phaseId], _royaltyContext(),
            batch.collectionId, batch.phaseId, phaseState.config.configHash, true
        );
        return StreamMintManagerERC20OfferTranscript.build(
            batch, arguments, MINT_EXECUTION_PATH_SINGLE_STEP, phaseState,
            _phaseGateConfigs[batch.collectionId][batch.phaseId],
            _phaseCounterIds[batch.collectionId][batch.phaseId],
            _counterConfigs[batch.collectionId][batch.phaseId],
            _phaseExecutors[batch.collectionId][batch.phaseId],
            StreamMintManagerERC20OfferTranscript.Context(
                address(core), _policyContext(batch.collectionId, batch.phaseId),
                phasePolicyHash[batch.collectionId][batch.phaseId], nextOperationNonce,
                _gasParameterValue(GGP_ARTIST_AUTHORITY_GAS_LIMIT)
            )
        );
    }

    function _executionContext() private view returns (StreamMintManagerExecution.Context memory) {
        return StreamMintManagerExecution.Context(core, mintLedger, address(moduleRegistry));
    }

    function _reserveOperationNonces(uint256 firstOperationNonce, uint256 quantity) private {
        nextOperationNonce = firstOperationNonce + quantity;
    }

    /// @notice Computes the exact prospective policy so the artist can consent before registration.
    /// @dev Uses this Manager's chain/dependencies. Pause is excluded; executor order is canonicalized.
    ///      Configuration admission and runtime authorization are independently checked when applied.
    function previewPhasePolicyHash(
        uint256 collectionId,
        bytes32 phaseId,
        MintPhaseConfig calldata config,
        MintGateConfig calldata gateConfig,
        bytes32[] calldata counterIds,
        MintCounterConfig[] calldata counterConfigs,
        address[] calldata executors
    ) external view returns (bytes32) {
        return StreamMintManagerViews.phasePolicy(
            msg.data[4:], address(mintLedger), address(moduleRegistry)
        );
    }

    function _policyContext(uint256 collectionId, bytes32 phaseId)
        private
        view
        returns (StreamMintOperationIdentity.PolicyContext memory)
    {
        return StreamMintOperationIdentity.PolicyContext(
            block.chainid,
            address(this),
            address(mintLedger),
            address(moduleRegistry),
            SCHEMA_VERSION,
            collectionId,
            phaseId
        );
    }

    function _requirePhaseIdentity(uint256 collectionId, bytes32 phaseId) private pure {
        if (collectionId == 0 || phaseId == bytes32(0)) {
            revert InvalidMintPhase(collectionId, phaseId);
        }
    }

    function registerPhaseRoyaltyPolicy(
        uint256 collectionId,
        bytes32 phaseId,
        IStreamMintRoyaltyPolicy.Policy calldata policy
    ) external override onlyOwner nonReentrant returns (bytes32) {
        _requirePhaseIdentity(collectionId, phaseId);
        if (_phases[collectionId][phaseId].exists) {
            revert MintPhaseAlreadyConfigured(collectionId, phaseId);
        }
        return StreamMintRoyaltyPolicy.register(
            _phaseRoyalties[collectionId][phaseId], _royaltyContext(), collectionId, phaseId, policy
        );
    }

    function phaseRoyaltyPolicy(uint256 collectionId, bytes32 phaseId)
        external
        view
        override
        returns (IStreamMintRoyaltyPolicy.Policy memory)
    {
        bytes memory encoded = StreamMintManagerViews.royaltyEncoded(
            _phaseRoyalties[collectionId][phaseId]
        );
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function phaseRoyaltyConfigHash(
        uint256 collectionId,
        bytes32 phaseId,
        IStreamMintRoyaltyPolicy.Policy calldata policy
    ) external view override returns (bytes32) {
        return StreamMintRoyaltyPolicy.configHash(collectionId, phaseId, policy);
    }

    function _royaltyContext() private view returns (StreamMintRoyaltyPolicy.Context memory) {
        return StreamMintRoyaltyPolicy.Context(address(core), address(moduleRegistry));
    }
}

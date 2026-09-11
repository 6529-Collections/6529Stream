// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/mint/IStreamMintLedger.sol";
import "../../interfaces/stream/mint/IStreamMintManager.sol";
import "../../interfaces/stream/mint/compatibility/IStreamMintModuleRegistry.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "./StreamMintCoreExecutor.sol";
import "./StreamMintGateValidator.sol";
import "./StreamMintOperationIdentity.sol";
import "./StreamMintArtistConsent.sol";
import "./StreamMintPhaseState.sol";
import "../parameters/StreamGasParameterHost.sol";

/// @notice Outside-Core phase policy and prepared mint execution manager.
contract StreamMintManager is
    IStreamMintManager,
    Ownable,
    ReentrancyGuard,
    ERC165,
    StreamGasParameterHost
{
    bytes32 public constant GGP_ARTIST_AUTHORITY_GAS_LIMIT =
        keccak256("6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT");
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

    struct OperationTranscript {
        uint256 quantity;
        uint256 firstOperationNonce;
        bytes32 currentPolicyHash;
        bytes32 boundPolicyHash;
        bytes32 operationRoot;
        bytes32[] operationIds;
        IStreamMintLedger.CounterConsumption[] consumptions;
        StreamMintOperationIdentity.MintAuthorization authorization;
    }

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
    }

    /// @notice Returns true for deployment validation.
    function isStreamMintManager() external pure override returns (bool) {
        return true;
    }

    /// @notice Advertises the manager interface required by Core satellite validation.
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return
            interfaceId == type(IStreamMintManager).interfaceId
                || super.supportsInterface(interfaceId);
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
        return StreamMintPhaseState.configure(
            _phases[collectionId][phaseId],
            _phaseGateConfigs[collectionId],
            _phaseCounterIds[collectionId][phaseId],
            _counterConfigs[collectionId][phaseId],
            _phaseExecutors[collectionId][phaseId],
            phasePolicyHash[collectionId],
            config,
            gateConfig,
            counterIds,
            counterConfigs,
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
        _requireConfiguredPhase(collectionId, phaseId);
        if (!StreamMintPhaseState.setExecutor(
                phaseExecutor[collectionId][phaseId],
                _phaseExecutors[collectionId][phaseId],
                _phaseExecutorIndex[collectionId][phaseId],
                executor,
                allowed,
                MAX_PHASE_EXECUTORS
            )) return;

        bytes32 policyHash = _refreshLedgerPolicy(collectionId, phaseId);
        emit MintPhaseExecutorUpdated(
            collectionId, phaseId, executor, allowed, policyHash, msg.sender
        );
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
        if (phaseState.config.paused == paused) {
            return;
        }
        phaseState.config.paused = paused;
        bytes32 policyHash = phasePolicyHash[collectionId][phaseId];
        emit MintPhasePausedEvent(collectionId, phaseId, paused, policyHash, msg.sender);
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
        _consumeOperation(batch, transcript);
        _emitGateValidation(batch, transcript);

        tokenIds = new uint256[](transcript.quantity);
        for (uint256 i = 0; i < transcript.quantity; i++) {
            tokenIds[i] = StreamMintCoreExecutor.executeSingleStep(
                core, batch, i, transcript.operationRoot, transcript.operationIds[i], SCHEMA_VERSION
            );
        }

        _emitOperationCompletion(batch, transcript, tokenIds[0]);
        return (tokenIds, transcript.operationRoot, transcript.operationIds);
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
        _consumeOperation(batch, transcript);
        _emitGateValidation(batch, transcript);

        tokenIds = new uint256[](transcript.quantity);
        for (uint256 i = 0; i < transcript.quantity; i++) {
            tokenIds[i] = StreamMintCoreExecutor.executePrepared(
                core, batch, i, transcript.operationRoot, transcript.operationIds[i], SCHEMA_VERSION
            );
        }

        _emitOperationCompletion(batch, transcript, tokenIds[0]);
        return (tokenIds, transcript.operationRoot, transcript.operationIds);
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

    function _emitOperationCompletion(
        MintBatch calldata batch,
        OperationTranscript memory transcript,
        uint256 firstTokenId
    ) private {
        emit MintAuthorizationConsumed(
            SCHEMA_VERSION,
            batch.collectionId,
            batch.phaseId,
            batch.authorizationId,
            transcript.boundPolicyHash,
            transcript.operationRoot
        );
        emit MintBatchExecuted(
            SCHEMA_VERSION,
            transcript.operationRoot,
            batch.collectionId,
            batch.phaseId,
            msg.sender,
            batch.payer,
            transcript.authorization.authorizer,
            firstTokenId,
            transcript.quantity,
            batch.contextHash,
            transcript.authorization.gateHash,
            transcript.currentPolicyHash,
            transcript.boundPolicyHash
        );
    }

    /// @notice Returns immutable phase config plus existence.
    function phase(uint256 collectionId, bytes32 phaseId)
        external
        view
        override
        returns (bool exists, MintPhaseConfig memory config)
    {
        StreamMintPhaseState.PhaseState storage phaseState = _phases[collectionId][phaseId];
        return (phaseState.exists, phaseState.config);
    }

    /// @notice Returns manager-scoped authorization replay state independent of the caller.
    function isAuthorizationUsed(bytes32 authorizationId) external view override returns (bool) {
        return mintLedger.isManagerAuthorizationUsed(address(this), authorizationId);
    }

    /// @notice Returns manager-scoped nullifier replay state independent of the caller.
    function isNullifierUsed(bytes32 nullifier) external view override returns (bool) {
        return mintLedger.isManagerNullifierUsed(address(this), nullifier);
    }

    /// @notice Returns manager-scoped operation-root replay state independent of the caller.
    function isOperationRootUsed(bytes32 operationRoot) external view override returns (bool) {
        return mintLedger.isManagerOperationRootUsed(address(this), operationRoot);
    }

    /// @notice Returns the immediate predecessor policy and its grace expiry.
    function phasePolicyGrace(uint256 collectionId, bytes32 phaseId)
        external
        view
        override
        returns (bytes32 previousPolicyHash, uint64 graceUntil)
    {
        // Revision adjacency is enforced by the ledger; this view exposes only hash and expiry.
        // slither-disable-next-line unused-return
        (previousPolicyHash,, graceUntil) =
            mintLedger.policyGrace(address(this), collectionId, phaseId);
    }

    /// @notice Returns the ordered counter IDs for a phase.
    function phaseCounterIds(uint256 collectionId, bytes32 phaseId)
        external
        view
        override
        returns (bytes32[] memory)
    {
        return _phaseCounterIds[collectionId][phaseId];
    }

    /// @notice Returns one manager-side counter config.
    function counterConfig(uint256 collectionId, bytes32 phaseId, bytes32 counterId)
        external
        view
        override
        returns (MintCounterConfig memory)
    {
        return _counterConfigs[collectionId][phaseId][counterId];
    }

    /// @notice Returns one phase's optional gate config.
    function phaseGate(uint256 collectionId, bytes32 phaseId)
        external
        view
        override
        returns (MintGateConfig memory)
    {
        return _phaseGateConfigs[collectionId][phaseId];
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
        StreamMintOperationIdentity.SubjectContext memory context =
            StreamMintOperationIdentity.SubjectContext({
                chainId: block.chainid,
                ledger: address(mintLedger),
                collectionId: collectionId,
                phaseId: phaseId,
                counterId: counterId,
                payer: payer,
                recipient: recipient,
                executor: executor,
                authorizer: authorizer,
                contextHash: contextHash
            });
        return StreamMintOperationIdentity.subjectKey(keyMode, context);
    }

    /// @notice Previews the canonical ledger value key for a derived subject.
    function previewCounterValueKey(
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        bytes32 subjectKey
    ) external view override returns (bytes32) {
        return mintLedger.deriveCounterValueKey(
            address(this), collectionId, phaseId, counterId, subjectKey
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
        _requirePhaseIdentity(request.collectionId, request.phaseId);
        phaseState = _requireConfiguredPhase(request.collectionId, request.phaseId);
        if (phaseState.config.paused) {
            revert MintPhasePaused(request.collectionId, request.phaseId);
        }
        if (phaseState.config.startTime != 0 && block.timestamp < phaseState.config.startTime) {
            revert MintPhaseNotStarted(request.collectionId, request.phaseId, block.timestamp);
        }
        if (phaseState.config.endTime != 0 && block.timestamp > phaseState.config.endTime) {
            revert MintPhaseEnded(request.collectionId, request.phaseId, block.timestamp);
        }
        if (!phaseExecutor[request.collectionId][request.phaseId][msg.sender]) {
            revert UnauthorizedMintExecutor(request.collectionId, request.phaseId, msg.sender);
        }
    }

    function _validateMintBatch(MintBatch calldata request, MintPhaseConfig memory config)
        private
        pure
        returns (uint256 quantity)
    {
        quantity = request.initialRecipients.length;
        if (
            quantity == 0 || quantity != request.beneficiaries.length
                || quantity != request.tokenData.length
                || quantity != request.mintCommitments.length
        ) {
            revert MintArrayLengthMismatch();
        }
        if (quantity > config.maxBatchQuantity) {
            revert MintBatchQuantityLimitExceeded(quantity, config.maxBatchQuantity);
        }
        for (uint256 i = 0; i < quantity; i++) {
            if (
                request.initialRecipients[i] == address(0) || request.beneficiaries[i] == address(0)
            ) {
                revert InvalidMintRecipient(
                    i, request.initialRecipients[i], request.beneficiaries[i]
                );
            }
        }
    }

    function _operationTranscript(
        MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 executionPath
    ) private view returns (OperationTranscript memory transcript) {
        StreamMintPhaseState.PhaseState storage phaseState = _requireExecutablePhase(batch);
        transcript.quantity = _validateMintBatch(batch, phaseState.config);
        transcript.currentPolicyHash = _computePolicyHash(batch.collectionId, batch.phaseId);
        bytes32 registeredPolicyHash = phasePolicyHash[batch.collectionId][batch.phaseId];
        if (transcript.currentPolicyHash != registeredPolicyHash) {
            revert MintPolicyHashMismatch(registeredPolicyHash, transcript.currentPolicyHash);
        }
        transcript.boundPolicyHash = _requireBoundPolicyHash(batch, transcript.currentPolicyHash);
        StreamMintArtistConsent.mint(
            address(core),
            batch.collectionId,
            batch.phaseId,
            transcript.currentPolicyHash,
            _gasParameterValue(GGP_ARTIST_AUTHORITY_GAS_LIMIT)
        );
        transcript.authorization = StreamMintGateValidator.validateAuthorization(
            batch,
            gateData,
            transcript.quantity,
            transcript.boundPolicyHash,
            _phaseGateConfigs[batch.collectionId][batch.phaseId],
            moduleRegistry,
            msg.sender
        );
        transcript.consumptions =
            _counterConsumptions(batch, transcript.quantity, transcript.authorization.authorizer);
        transcript.firstOperationNonce = nextOperationNonce;
        if (type(uint256).max - transcript.firstOperationNonce < transcript.quantity) {
            revert MintOperationNonceOverflow(transcript.firstOperationNonce, transcript.quantity);
        }
        StreamMintOperationIdentity.TranscriptContext memory context =
            StreamMintOperationIdentity.TranscriptContext({
                chainId: block.chainid,
                manager: address(this),
                coreAddress: address(core),
                ledgerAddress: address(mintLedger),
                gate: _phaseGateConfigs[batch.collectionId][batch.phaseId].gate,
                executor: msg.sender,
                executionPath: executionPath,
                currentPolicyHash: transcript.currentPolicyHash,
                boundPolicyHash: transcript.boundPolicyHash,
                firstOperationNonce: transcript.firstOperationNonce,
                quantity: transcript.quantity
            });
        (transcript.operationRoot, transcript.operationIds) = StreamMintOperationIdentity.derive(
            batch, transcript.authorization, transcript.consumptions, context
        );
    }

    function _requireBoundPolicyHash(MintBatch calldata batch, bytes32 currentPolicyHash)
        private
        view
        returns (bytes32 boundPolicyHash)
    {
        boundPolicyHash = batch.expectedPolicyHash;
        if (boundPolicyHash == bytes32(0)) {
            revert MintPolicyHashRequired(batch.collectionId, batch.phaseId);
        }
        if (boundPolicyHash == currentPolicyHash) {
            return boundPolicyHash;
        }
        // The ledger independently enforces predecessor revision adjacency during consume.
        // slither-disable-next-line unused-return
        (bytes32 previousPolicyHash,, uint64 graceUntil) =
            mintLedger.policyGrace(address(this), batch.collectionId, batch.phaseId);
        if (boundPolicyHash != previousPolicyHash || block.timestamp > graceUntil) {
            revert MintPolicyHashMismatch(boundPolicyHash, currentPolicyHash);
        }
    }

    function _reserveOperationNonces(uint256 firstOperationNonce, uint256 quantity) private {
        nextOperationNonce = firstOperationNonce + quantity;
    }

    function _consumeOperation(MintBatch calldata batch, OperationTranscript memory transcript)
        private
    {
        mintLedger.consume(
            batch.collectionId,
            batch.phaseId,
            transcript.consumptions,
            batch.authorizationId,
            transcript.authorization.nullifiers,
            transcript.boundPolicyHash,
            transcript.operationRoot
        );
    }

    function _counterConsumptions(MintBatch calldata request, uint256 quantity, address authorizer)
        private
        view
        returns (IStreamMintLedger.CounterConsumption[] memory consumptions)
    {
        bytes32[] storage storedCounterIds = _phaseCounterIds[request.collectionId][request.phaseId];
        bytes32[] memory counterIds = new bytes32[](storedCounterIds.length);
        MintCounterConfig[] memory counterConfigs = new MintCounterConfig[](storedCounterIds.length);
        for (uint256 i = 0; i < storedCounterIds.length; i++) {
            bytes32 counterId = storedCounterIds[i];
            counterIds[i] = counterId;
            counterConfigs[i] = _counterConfigs[request.collectionId][request.phaseId][counterId];
        }
        StreamMintOperationIdentity.CounterContext memory context =
            StreamMintOperationIdentity.CounterContext({
                chainId: block.chainid,
                manager: address(this),
                ledger: address(mintLedger),
                executor: msg.sender,
                authorizer: authorizer
            });
        return StreamMintOperationIdentity.deriveCounterConsumptions(
            request, quantity, counterIds, counterConfigs, context
        );
    }

    function _emitGateValidation(MintBatch calldata batch, OperationTranscript memory transcript)
        private
    {
        address gate = _phaseGateConfigs[batch.collectionId][batch.phaseId].gate;
        if (gate == address(0)) {
            return;
        }
        emit MintGateValidated(
            batch.collectionId,
            batch.phaseId,
            gate,
            batch.authorizationId,
            transcript.authorization.authorizer,
            transcript.quantity,
            batch.contextHash,
            transcript.authorization.gateHash,
            transcript.boundPolicyHash
        );
    }

    function _refreshLedgerPolicy(uint256 collectionId, bytes32 phaseId)
        private
        returns (bytes32 policyHash)
    {
        bytes32[] storage counterIds = _phaseCounterIds[collectionId][phaseId];
        bytes32[] memory ids = new bytes32[](counterIds.length);
        IStreamMintLedger.LedgerCounterPolicy[] memory ledgerPolicies =
            new IStreamMintLedger.LedgerCounterPolicy[](counterIds.length);
        for (uint256 i = 0; i < counterIds.length; i++) {
            bytes32 counterId = counterIds[i];
            ids[i] = counterId;
            ledgerPolicies[i] = _ledgerPolicy(_counterConfigs[collectionId][phaseId][counterId]);
        }
        policyHash = _computePolicyHash(collectionId, phaseId);
        _recordArtistConsent(collectionId, phaseId, policyHash);
        phasePolicyHash[collectionId][phaseId] = policyHash;
        mintLedger.registerPhasePolicy(
            address(this), collectionId, phaseId, policyHash, ids, ledgerPolicies, 0
        );
    }

    function _recordArtistConsent(uint256 collectionId, bytes32 phaseId, bytes32 policyHash)
        private
    {
        (uint8 mode, bytes32 evidence) = StreamMintArtistConsent.registration(
            address(core),
            collectionId,
            phaseId,
            policyHash,
            _gasParameterValue(GGP_ARTIST_AUTHORITY_GAS_LIMIT)
        );
        emit MintPhaseConsentRecorded(
            SCHEMA_VERSION, collectionId, phaseId, policyHash, mode, evidence
        );
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
        if (
            counterIds.length != counterConfigs.length || counterIds.length > MAX_PHASE_COUNTERS
                || executors.length > MAX_PHASE_EXECUTORS
        ) revert MintArrayLengthMismatch();
        return StreamMintOperationIdentity.computePolicyHash(
            config,
            gateConfig,
            counterIds,
            counterConfigs,
            executors,
            StreamMintOperationIdentity.PolicyContext(
                block.chainid,
                address(this),
                address(mintLedger),
                address(moduleRegistry),
                SCHEMA_VERSION,
                collectionId,
                phaseId
            )
        );
    }

    function _computePolicyHash(uint256 collectionId, bytes32 phaseId)
        private
        view
        returns (bytes32)
    {
        return StreamMintPhaseState.computeStoredPolicyHash(
            _phases[collectionId][phaseId],
            _phaseGateConfigs[collectionId][phaseId],
            _phaseCounterIds[collectionId][phaseId],
            _counterConfigs[collectionId][phaseId],
            _phaseExecutors[collectionId][phaseId],
            _policyContext(collectionId, phaseId)
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

    function _ledgerPolicy(MintCounterConfig memory config)
        private
        pure
        returns (IStreamMintLedger.LedgerCounterPolicy memory)
    {
        return IStreamMintLedger.LedgerCounterPolicy({
            enabled: config.enabled,
            capMode: config.capMode,
            deltaMode: config.deltaMode,
            staticCap: config.staticCap,
            staticIncrement: config.staticIncrement,
            counterConfigHash: config.counterConfigHash
        });
    }

    function _requirePhaseIdentity(uint256 collectionId, bytes32 phaseId) private pure {
        if (collectionId == 0 || phaseId == bytes32(0)) {
            revert InvalidMintPhase(collectionId, phaseId);
        }
    }
}

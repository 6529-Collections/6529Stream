// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamEntropyCoordinatorContinuity as EntropyContinuityCapability
} from "../../interfaces/stream/entropy/IStreamEntropyCoordinatorContinuity.sol";
import { StreamEntropyExecution } from "./StreamEntropyExecution.sol";
import { StreamEntropyContinuity } from "./StreamEntropyContinuity.sol";
import {
    IStreamEntropyPolicyContinuity as PolicyContinuity
} from "../../interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyOriginRelay as OriginRelay
} from "../../interfaces/stream/entropy/IStreamEntropyOriginRelay.sol";
import { StreamEntropyPolicyInventory as Inventory } from "./StreamEntropyPolicyInventory.sol";
import {
    StreamEntropyPolicyImportState as PolicyImportState
} from "./StreamEntropyPolicyImportState.sol";
import { StreamEntropyPolicyImport as PolicyImport } from "./StreamEntropyPolicyImport.sol";
import { StreamEntropyPolicyExport as PolicyExports } from "./StreamEntropyPolicyExport.sol";
import {
    StreamEntropyDirectReadEncoding as DirectReadEncoding
} from "./StreamEntropyDirectReadEncoding.sol";
import { StreamEntropyRelayState as RelayState } from "./StreamEntropyRelayState.sol";
import { StreamEntropyOriginRelay as Relay } from "./StreamEntropyOriginRelay.sol";
import { StreamEntropyRelayAdmission as RelayAdmission } from "./StreamEntropyRelayAdmission.sol";
import { StreamEntropyScopeRegistration } from "./StreamEntropyScopeRegistration.sol";
import { StreamEntropyCollectionPolicy } from "./StreamEntropyCollectionPolicy.sol";
import {
    IStreamEntropyCollectionPolicy as CollectionPolicy
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import { StreamEntropyTerminalAdmission } from "./StreamEntropyTerminalAdmission.sol";
import { StreamEntropySubjectReads } from "./StreamEntropySubjectReads.sol";
import {
    IStreamEntropyArtistUnavailability as EntropyU
} from "../../interfaces/stream/entropy/IStreamEntropyArtistUnavailability.sol";

import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import "../../interfaces/stream/entropy/IStreamEntropyProvider.sol";
import "../../interfaces/stream/entropy/IStreamInstantEntropyProviderIdentity.sol";
import "../../interfaces/stream/entropy/IStreamEntropyTerminalFacts.sol";
import "../../interfaces/stream/entropy/IStreamEntropyProviderFeeQuote.sol";
import "../../interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import "../../interfaces/stream/entropy/IStreamRevealPolicyAdmin.sol";
import "../../interfaces/stream/entropy/IStreamEntropyTiming.sol";
import "../../interfaces/stream/entropy/IStreamEntropyFinalityPolicy.sol";
import "../../interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../interfaces/stream/governance/IStreamGovernanceRoleSources.sol";
import "../../interfaces/stream/mint/IStreamMintGovernanceRegistry.sol";
import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../modules/StreamModuleBase.sol";
import "../parameters/StreamTimeParameterHost.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { StreamEntropyIncidentParameters } from "./StreamEntropyIncidentParameters.sol";
import { StreamEntropyIncidentEvidence } from "./StreamEntropyIncidentEvidence.sol";
import { StreamEntropyCoordinatorReads } from "./StreamEntropyCoordinatorReads.sol";
import { StreamEntropyProviderLifecycle } from "./StreamEntropyProviderLifecycle.sol";
import { StreamEntropyIncidentTransition } from "./StreamEntropyIncidentTransition.sol";
import { StreamEntropyFreshRecovery } from "./StreamEntropyFreshRecovery.sol";
import { StreamEntropyFulfillment } from "./StreamEntropyFulfillment.sol";
import { StreamEntropyRequestPlan } from "./StreamEntropyRequestPlan.sol";
import { StreamEntropyRequestSubmission } from "./StreamEntropyRequestSubmission.sol";
import {
    StreamEntropyCollectionPolicyState as PolicyState
} from "./StreamEntropyCollectionPolicyState.sol";
import "../../interfaces/stream/entropy/IStreamEntropyFreshRecovery.sol";
import { StreamEntropyCollectionRecovery } from "./StreamEntropyCollectionRecovery.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCollectionRecovery.sol";
import { StreamEntropyCollectionConfiguration } from "./StreamEntropyCollectionConfiguration.sol";
import { StreamEntropyRecoveryPolicies } from "./StreamEntropyRecoveryPolicies.sol";
import "../../interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import { StreamEntropyAuxiliaryReads } from "./StreamEntropyAuxiliaryReads.sol";
import {
    IStreamEntropyProviderLifecycle,
    EntropyProviderState
} from "../../interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";
import "../../interfaces/stream/entropy/IStreamEntropyIncidents.sol";

/// @notice Core-bound asynchronous entropy with immutable request inputs and no ordinary reroll.
/// @dev Policy locks on first token/scope registration. Fresh requests require a prebound frozen
///      policy, an evidenced incident and exact Artist consent where attribution is bound.
contract StreamEntropyCoordinator is
    StreamModuleBase,
    ReentrancyGuard,
    StreamTimeParameterHost,
    IStreamEntropyCoordinator,
    IStreamEntropyView,
    IStreamRevealPolicyAdmin,
    IStreamEntropyTiming,
    IStreamEntropyFinalityPolicy,
    IStreamEntropyEpochs,
    IStreamEntropyIncidents,
    IStreamEntropyProviderLifecycle,
    IStreamEntropyRecoveryPolicies,
    IStreamEntropyCollectionRecovery,
    IStreamEntropyFreshRecovery,
    CollectionPolicy,
    IStreamEntropyTerminalFacts,
    PolicyContinuity,
    OriginRelay
{
    bytes32 public constant GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS =
        keccak256("6529STREAM_GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS");
    bytes32 public constant GTP_ENTROPY_REVEAL_SLO_BLOCKS =
        keccak256("6529STREAM_GTP_ENTROPY_REVEAL_SLO_BLOCKS");
    bytes32 public constant GTP_ENTROPY_RECOVERY_STEP_DELAY_BLOCKS =
        keccak256("6529STREAM_GTP_ENTROPY_RECOVERY_STEP_DELAY_BLOCKS");
    bytes32 public constant REQUEST_DOMAIN = keccak256("6529STREAM_ENTROPY_REQUEST_V1");
    bytes32 public constant SEED_DOMAIN = keccak256("6529STREAM_ENTROPY_SEED_V1");
    bytes32 public constant SCOPE_DOMAIN = keccak256("6529STREAM_ENTROPY_SCOPE_SUBJECT_V1");
    bytes32 public constant SCOPE_REQUEST_DOMAIN = keccak256("6529STREAM_ENTROPY_SCOPE_REQUEST_V1");
    bytes32 public constant SCOPE_SEED_DOMAIN = keccak256("6529STREAM_ENTROPY_SCOPE_SEED_V1");

    struct CollectionConfig {
        address provider;
        bool publicRequests;
        bool locked;
        uint64 timeoutBlocks;
        bytes32 providerConfigHash;
        bytes32 providerCodeHash;
        bytes32 collectionSalt;
    }

    struct Subject {
        uint256 collectionId;
        bytes32 inputsHash;
        bytes32 requestKey;
        bytes32 seed;
        StreamEntropyStatus status;
    }

    struct Request {
        bytes32 subjectKey;
        uint256 tokenId;
        bytes32 scopeId;
        address provider;
        uint64 requestedAtBlock;
        uint256 providerRequestId;
        bytes32 rawRandomness;
    }

    struct SeedInputs {
        bytes32 domain;
        uint256 chainId;
        address coordinator;
        address streamCore;
        uint256 collectionId;
        bytes32 identity;
        address provider;
        uint32 providerEpoch;
        bytes32 providerConfigHash;
        bytes32 requestKey;
        uint256 providerRequestId;
        bytes32 rawRandomness;
        bytes32 collectionSalt;
        bytes32 inputsHash;
    }

    IStreamCore public immutable core;
    address public immutable authority;
    mapping(uint256 => CollectionConfig) public collectionEntropyConfig;
    mapping(address => bool) public requesters;
    mapping(address => bool) public providerRevoked;
    mapping(bytes32 => Subject) private _subjects;
    mapping(bytes32 => Request) public requests;
    mapping(address => mapping(uint256 => bytes32)) public providerRequestKeys;
    mapping(address => uint256) public entropyFeeCredit;
    uint256 public totalFeeCredits;
    uint256 public pendingRequestCount;
    mapping(uint256 => bool) public metadataNotificationPending;
    mapping(bytes32 => bool) private _registeredScopes;
    IStreamRoleRegistry public immutable roleRegistry;
    bytes32 public immutable roleRegistryCodeHash;
    mapping(uint256 => IStreamRevealFeeEscrow.CollectionRevealPolicy) private _revealPolicies;
    mapping(uint256 => uint256) public revealFeeEscrow;
    uint256 public totalRevealFeeEscrows;
    mapping(uint256 => uint64) public registeredAtBlock;
    mapping(uint256 => uint256) public nonterminalTokenCount;
    // Append new identity data; retain existing config/request getter shapes and storage.
    mapping(uint256 => uint32) public override collectionProviderEpoch;
    mapping(bytes32 => RequestPolicySnapshot) private _requestPolicies;

    bytes32 private constant _REVEAL_OWNER = keccak256("ROLE_ENTROPY_REVEAL_OWNER");
    bytes32 private constant _ENTROPY_ADMIN = keccak256("ROLE_ENTROPY_ADMIN");
    bytes32 private constant _TREASURY = keccak256("ROLE_TREASURY");

    error Unauthorized(address caller);
    error InvalidDependency(address target);
    error InvalidCollection(uint256 collectionId);
    error PolicyLocked(uint256 collectionId);
    error InvalidToken(uint256 tokenId);
    error InvalidSubject(bytes32 subjectKey);
    error InvalidStatus(StreamEntropyStatus actual);
    error ProviderConfigurationChanged(address provider);
    error ProviderRequestCollision(address provider, uint256 providerRequestId);
    error InsufficientEntropyFee(uint256 required, uint256 supplied);
    error InvalidDestination();
    error CreditTransferFailed();
    error RequestNotExpired();
    error ProviderOutputAlreadyReceived();
    error ProviderFailureUnproven();
    error RevealPolicyUndeclared(uint256 collectionId);
    error InvalidRevealPolicy(uint256 collectionId);
    error RevealFeeBelowQuote(uint256 declaredFee, uint256 providerQuote);
    error RevealFeeQuoteUnavailable(address provider);
    error InsufficientRevealFee(uint256 providerQuote, uint256 escrowDraw, uint256 callerSupplied);
    error RevealEscrowUnavailable(uint256 collectionId);
    error EntropyBlockNumberOverflow();
    error InstantEntropyBeforeDelivery(uint256 tokenId);

    event CollectionEntropyConfigured(
        uint256 indexed collectionId,
        address indexed provider,
        bytes32 configHash,
        bytes32 collectionSalt,
        bool publicRequests,
        uint64 timeoutBlocks
    );
    event EntropyRequesterUpdated(address indexed requester, bool allowed);
    event ProviderRevocationUpdated(address indexed provider, bool revoked);
    event EntropyRegistered(
        uint256 indexed collectionId, uint256 indexed tokenId, bytes32 mintCommitment
    );
    event EntropyScopeRegistered(
        uint256 indexed collectionId, bytes32 indexed scopeId, uint8 scopeKind, bytes32 scopeRef
    );
    event EntropyRequested(
        bytes32 indexed requestKey,
        uint256 indexed tokenId,
        bytes32 indexed scopeId,
        address provider,
        uint256 providerRequestId
    );
    event InstantEntropyProduced(
        uint16 schemaVersion,
        bytes32 indexed requestKey,
        uint256 indexed providerRequestId,
        bytes32 rawRandomness,
        bytes32 provenanceHash,
        IStreamInstantEntropyProviderIdentity.InstantMode mode,
        bytes32 assumptionsHash
    );
    event EntropyFinalized(
        bytes32 indexed requestKey,
        uint256 indexed tokenId,
        bytes32 indexed scopeId,
        bytes32 seed,
        bytes32 rawRandomness
    );
    event EntropyRequestTerminal(bytes32 indexed requestKey, StreamEntropyStatus status);
    event EntropyFulfillmentRejected(bytes32 indexed requestKey, uint8 outcome);
    event EntropyFeeCredited(address indexed payer, uint256 amount);
    event EntropyFeeCreditClaimed(
        address indexed payer, address indexed destination, uint256 amount
    );
    event MetadataNotificationFailed(uint256 indexed tokenId, bytes32 indexed requestKey);

    /// @notice Complete constructor configuration for a new coordinator instance.
    struct DeploymentConfig {
        address core;
        address authority;
        address roleRegistry;
        TimeParameterConfig[3] timeParameters;
        bytes32 deploymentManifestHash;
        string manifestURI;
        bytes32 manifestHash;
    }

    constructor(DeploymentConfig memory config)
        StreamModuleBase(
            keccak256("6529stream.entropy-coordinator.schema.v1"),
            address(0),
            config.deploymentManifestHash,
            config.manifestURI,
            config.manifestHash
        )
        StreamTimeParameterHost(config.authority)
    {
        if (config.core.code.length == 0 || !IERC165(config.core).supportsInterface(0x80ac58cd)) {
            revert InvalidDependency(config.core);
        }
        if (
            config.authority == address(0) || config.deploymentManifestHash == 0
                || config.manifestHash == 0
        ) {
            revert InvalidDependency(config.authority);
        }
        if (
            config.roleRegistry.code.length == 0
                || !IStreamRoleRegistry(config.roleRegistry)
                    .supportsInterface(type(IStreamRoleRegistry).interfaceId)
                || IStreamRoleRegistry(config.roleRegistry).supportsInterface(0xffffffff)
                || IStreamRoleRegistryOwnership(config.roleRegistry).owner() != config.authority
        ) revert InvalidDependency(config.roleRegistry);
        core = IStreamCore(config.core);
        authority = config.authority;
        roleRegistry = IStreamRoleRegistry(config.roleRegistry);
        roleRegistryCodeHash = config.roleRegistry.codehash;
        StreamEntropyIncidentParameters.initialize(config.authority);
        StreamEntropyProviderLifecycle.initialize(config.authority);
        StreamEntropyRecoveryPolicies.initialize(config.authority);
        bytes32[3] memory expected = [
            GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS,
            GTP_ENTROPY_REVEAL_SLO_BLOCKS,
            GTP_ENTROPY_RECOVERY_STEP_DELAY_BLOCKS
        ];
        for (uint256 i; i < expected.length; ++i) {
            bytes32 id = _registerTimeParameter(config.timeParameters[i]);
            if (id != expected[i]) revert TimeParameterInvalidConfig(id);
        }
    }

    modifier onlyAuthority() {
        PolicyImportState.requireOperational();
        if (msg.sender != authority) revert Unauthorized(msg.sender);
        _;
    }

    function streamModuleType() public pure override returns (bytes32) {
        return 0xb3b3ef20764c647bdeda70b21ab009ff2783106d6995be14389ec6f42ea6dfbb;
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.entropy-coordinator.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamEntropyCoordinator).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(IStreamEntropyCoordinator).interfaceId
            || id == type(CollectionPolicy).interfaceId
            || id == type(IStreamEntropyTerminalFacts).interfaceId
            || id == type(PolicyContinuity).interfaceId || id == type(OriginRelay).interfaceId
            || id == type(IStreamRevealFeeEscrow).interfaceId
            || id == type(IStreamRevealPolicyAdmin).interfaceId
            || id == type(IStreamTimeParameterHost).interfaceId
            || id == type(IStreamEntropyTiming).interfaceId
            || id == type(IStreamEntropyView).interfaceId
            || id == type(IStreamEntropyFinalityPolicy).interfaceId
            || id == type(IStreamEntropyEpochs).interfaceId
            || id == type(IStreamEntropyIncidents).interfaceId
            || id == type(IStreamEntropyFreshRecovery).interfaceId
            || id == type(EntropyU).interfaceId
            || id == type(IStreamEntropyCollectionRecovery).interfaceId
            || id == type(IStreamEntropyRecoveryPolicies).interfaceId
            || id == type(EntropyContinuityCapability).interfaceId
            || id == type(IStreamEntropyProviderLifecycle).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || super.supportsInterface(id);
    }

    function entropyPolicyInventory() external view override returns (uint256, uint64, bytes32) {
        Inventory.Header memory h = Inventory.header();
        return (h.count, h.serial, h.idDigest);
    }

    function entropyPolicyCollectionAt(uint256 index) external view override returns (uint256) {
        return Inventory.at(index);
    }

    function exportEntropyPolicy(uint256 id)
        external
        view
        override
        returns (PolicyContinuity.PolicyExport memory)
    {
        bytes memory encoded = DirectReadEncoding.policy(
            PolicyExports.policy(
                core,
                id,
                collectionEntropyConfig[id],
                collectionProviderEpoch[id],
                _revealPolicies[id]
            )
        );
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function exportEntropyRecovery(bytes32 id)
        external
        view
        override
        returns (PolicyContinuity.RecoveryExport memory)
    {
        bytes memory encoded = DirectReadEncoding.recovery(PolicyExports.recovery(id));
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function entropyPolicyImport()
        external
        view
        override
        returns (PolicyContinuity.ImportReceipt memory)
    {
        PolicyContinuity.ImportReceipt memory receipt = PolicyImportState.receipt();
        // All seventeen canonical memory words are already the static return tuple.
        assembly ("memory-safe") { return(receipt, 544) }
    }

    function importedEntropyPolicy(uint256 id)
        external
        view
        override
        returns (bytes32, bytes32, address, bytes32, bytes32)
    {
        return PolicyImportState.imported(id);
    }

    function entropyPolicyImportReady(
        address predecessor,
        bytes32 codeHash,
        uint64 pointerRevision,
        uint256 count,
        uint64 serial,
        bytes32 idDigest
    ) external view override returns (bool) {
        return PolicyImportState.ready(
            predecessor, codeHash, pointerRevision, count, serial, idDigest
        );
    }

    function beginEntropyPolicyImport(address, bytes32) external override {
        _policyImportWrite();
    }

    function importNextEntropyPolicy(uint256) external override {
        _policyImportWrite();
    }

    function confirmEntropyRelayRoute(uint256) external override {
        _policyImportWrite();
    }

    function sealEntropyPolicyImport() external override {
        _policyImportWrite();
    }

    function activateEntropyPolicyImport() external override {
        _policyImportWrite();
    }

    function _policyImportWrite() private {
        PolicyImport.write(
            core,
            authority,
            collectionEntropyConfig,
            collectionProviderEpoch,
            _revealPolicies,
            revealFeeEscrow,
            msg.data
        );
    }

    function entropyPolicyImportTransition(address predecessor, bytes32 manifest)
        external
        view
        override
        returns (bytes32, bytes32, bytes32)
    {
        return _policyImportTransition();
    }

    function entropyPolicyImportSealTransition()
        external
        view
        override
        returns (bytes32, bytes32, bytes32)
    {
        return _policyImportTransition();
    }

    function entropyPolicyImportActivationTransition()
        external
        view
        override
        returns (bytes32, bytes32, bytes32)
    {
        return _policyImportTransition();
    }

    function _policyImportTransition() private view returns (bytes32, bytes32, bytes32) {
        return PolicyImport.transitionEncoded(core, authority, msg.data);
    }

    function admitEntropyRelay(uint256 id, address successor, bytes32 importHash)
        external
        override
    {
        PolicyImportState.requireOperational();
        RelayAdmission.admit(core, authority, id, successor, importHash);
    }

    function entropyRelayAdmissionTransition(uint256 id, address successor, bytes32 importHash)
        external
        view
        override
        returns (bytes32, bytes32, bytes32)
    {
        return RelayAdmission.admissionTransition(core, authority, id, successor, importHash);
    }

    function entropyRelayAdmission(uint256 id, address successor)
        external
        view
        override
        returns (bytes32, bytes32, bytes32)
    {
        RelayState.Admission storage a = RelayState.store().admissions[id][successor];
        return (a.successorCodeHash, a.importHash, a.policyHash);
    }

    function relayEntropyRequest(OriginRelay.RelayInput calldata input)
        external
        payable
        override
        nonReentrant
        returns (uint256)
    {
        PolicyImportState.requireOperational();
        return Relay.submitEncoded(core, requests, providerRequestKeys, msg.data[4:]);
    }

    function relayInstantEntropy(OriginRelay.RelayInput calldata input)
        external
        view
        override
        returns (bytes32, bytes32)
    {
        PolicyImportState.requireOperational();
        return Relay.instantEncoded(core, msg.data[4:]);
    }

    function relayRequestWitness(bytes32 key) external view override returns (bytes32) {
        Request storage request = requests[key];
        Subject storage subject = _subjects[request.subjectKey];
        RelayState.LocalRoute storage route = RelayState.store().localRoutes[key];
        RequestPolicySnapshot storage snapshot = _requestPolicies[key];
        if (
            request.provider == address(0) || request.provider != snapshot.provider
                || subject.status != StreamEntropyStatus.REQUESTED || subject.requestKey != key
                || route.origin == address(0)
                || (request.scopeId == 0
                        ? request.tokenId == 0 || request.subjectKey != _tokenKey(request.tokenId)
                        : request.tokenId != 0 || request.subjectKey != request.scopeId
                        || !_registeredScopes[request.scopeId])
        ) revert OriginRelay.EntropyRelayWitnessMismatch(key);
        bool instant = PolicyState.mode(subject.collectionId) == CollectionPolicy.Mode.INSTANT;
        if (snapshot.inputsHash != (instant ? bytes32(0) : subject.inputsHash)) {
            revert OriginRelay.EntropyRelayWitnessMismatch(key);
        }
        OriginRelay.RelayInput memory input = OriginRelay.RelayInput(
            route.importHash, subject.collectionId, request.tokenId, request.scopeId, key, snapshot
        );
        bytes32 witness =
            RelayState.witnessHash(core, address(this), route.origin, route.originCodeHash, input);
        // The sole route writer validates the key and derives relayId before saving this witness.
        // Rehashing the actual immutable request/snapshot authenticates every input again here.
        if (witness != route.witnessHash) {
            revert OriginRelay.EntropyRelayWitnessMismatch(key);
        }
        return witness;
    }

    function retryEntropyRelay(bytes32 relayId)
        external
        override
        nonReentrant
        returns (bool, uint8)
    {
        return Relay.retry(core, requests, providerRequestKeys, relayId);
    }

    function entropyRelayResult(bytes32 relayId)
        external
        view
        override
        returns (OriginRelay.RelayResult memory)
    {
        OriginRelay.RelayResult memory result = RelayState.store().results[relayId];
        // All seventeen canonical memory words are already the static return tuple.
        assembly ("memory-safe") { return(result, 544) }
    }

    function configureFreshRecoveryPolicyV2(
        bytes32,
        uint16,
        bytes32,
        bytes32,
        bytes32,
        FreshRecoveryStep[] calldata,
        address,
        bytes32
    ) external {
        StreamEntropyRecoveryPolicies.configureV2Call(authority, core, msg.data[4:]);
    }

    function freshRecoveryPolicyV2Transition(bytes32, bytes32)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        _auxiliaryRead();
    }

    function coordinatorReplacementTerms(bytes32)
        external
        view
        returns (address, bytes32, bytes32)
    {
        _auxiliaryRead();
    }

    function uncoveredPendingRequestCount(address successor, bytes32 codeHash)
        external
        view
        returns (uint256)
    {
        return StreamEntropyContinuity.uncovered(pendingRequestCount, successor, codeHash);
    }

    function configureFreshRecoveryPolicy(
        bytes32 policyId,
        uint16 maxFreshRecoveryAttempts,
        bytes32 incidentDeclarerRole,
        bytes32 reasonSchemaHash,
        bytes32 policyManifestHash,
        FreshRecoveryStep[] calldata steps
    ) external override {
        StreamEntropyRecoveryPolicies.configureCall(authority, msg.data[4:]);
    }

    function freezeFreshRecoveryPolicy(bytes32 policyId) external override {
        StreamEntropyRecoveryPolicies.freeze(authority, policyId);
    }

    function freshRecoveryPolicy(bytes32)
        external
        view
        override
        returns (FreshRecoveryPolicy memory, bytes32, uint64, bytes32)
    {
        _auxiliaryRead();
    }

    function freshRecoveryPolicyTransition(bytes32, bytes32, bool)
        external
        view
        override
        returns (bytes32, bytes32, bytes32)
    {
        _auxiliaryRead();
    }

    function configureCollectionFreshRecovery(
        uint256 collectionId,
        uint16 maxFreshRecoveryAttempts,
        bytes32 policyId
    ) external override {
        StreamEntropyCollectionRecovery.configure(
            authority,
            core,
            collectionEntropyConfig,
            collectionProviderEpoch,
            collectionId,
            maxFreshRecoveryAttempts,
            policyId
        );
    }

    function collectionFreshRecovery(uint256)
        external
        view
        override
        returns (CollectionRecovery memory)
    {
        _auxiliaryRead();
    }

    function collectionFreshRecoveryTransition(uint256 id, uint16 attempts, bytes32 policyId)
        external
        view
        override
        returns (bytes32, bytes32, bytes32)
    {
        _auxiliaryRead();
    }

    function configureCollection(
        uint256 collectionId,
        address provider,
        bytes32 collectionSalt,
        bool publicRequests,
        uint64 timeoutBlocks
    ) external onlyAuthority {
        _entropyWrite();
    }

    function configureCollectionEntropyPolicy(uint256, CollectionPolicy.PolicyInput calldata)
        external
        override
    {
        _collectionPolicyWrite();
    }

    function collectionEntropyPolicy(uint256)
        external
        view
        override
        returns (CollectionPolicy.PolicyRecord memory)
    {
        _auxiliaryRead();
    }

    function collectionEntropyPolicyTransition(uint256, CollectionPolicy.PolicyInput calldata)
        external
        view
        override
        returns (bytes32, bytes32, bytes32, bytes32)
    {
        _auxiliaryRead();
    }

    function freezeCollectionEntropyPolicy(uint256) external override {
        _collectionPolicyWrite();
    }

    function _collectionPolicyWrite() private {
        PolicyImportState.requireOperationalAndMarkUsed();
        StreamEntropyCollectionPolicy.write(
            core,
            authority,
            collectionEntropyConfig,
            collectionProviderEpoch,
            _revealPolicies,
            revealFeeEscrow,
            msg.data
        );
    }

    function freezeCollectionEntropyPolicyTransition(uint256)
        external
        view
        override
        returns (bytes32, bytes32, bytes32, bytes32)
    {
        _auxiliaryRead();
    }

    /// @notice Explicit declared-zero policies remain distinguishable from absent configuration.
    function collectionRevealPolicy(uint256 collectionId)
        external
        view
        returns (IStreamRevealFeeEscrow.CollectionRevealPolicy memory)
    {
        _subjectRead();
    }

    /// @inheritdoc IStreamEntropyFinalityPolicy
    function entropyPolicyFrozen(uint256 collectionId)
        external
        view
        override
        returns (
            bool frozen,
            bytes32 policyManifestHash,
            address provider,
            uint32 providerEpoch,
            bytes32 collectionSaltCommitment
        )
    {
        bytes memory encoded = StreamEntropyCoordinatorReads.policyEncoded(
            core,
            collectionId,
            collectionEntropyConfig[collectionId],
            _revealPolicies[collectionId],
            collectionProviderEpoch[collectionId]
        );
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function configureCollectionRevealPolicy(
        uint256 collectionId,
        uint8 requestMode,
        bytes32 revealOwnerRole,
        uint64 requestSLOBlocks,
        uint256 revealFeePerTokenWei
    ) external override {
        _entropyWrite();
    }

    /// @notice Retunes funding for future mints without changing frozen reveal promises or escrow.
    function updateRevealFeePerToken(uint256 collectionId, uint256 next) external override {
        _entropyWrite();
    }

    /// @notice Permissionless funding does not query or request the provider, including during outages.
    function fundRevealFeeEscrow(uint256 collectionId) external payable nonReentrant {
        _entropyWrite();
    }

    /// @notice Residual collection funds can only reach the current registry-resolved treasury.
    function withdrawRevealFeeEscrow(uint256 collectionId, uint256 amount)
        external
        override
        nonReentrant
    {
        _entropyWrite();
    }

    function setRequester(address requester, bool allowed) external onlyAuthority {
        _entropyWrite();
    }

    /// @notice Compatibility transition, bound to its original delayed catalog class.
    function setProviderRevoked(address provider, bool revoked) external onlyAuthority {
        _updateProvider();
    }

    function entropyProviderRecord(address provider)
        external
        view
        override
        returns (ProviderRecord memory)
    {
        _auxiliaryRead();
    }

    function entropyProviderCount() external view override returns (uint256) {
        _auxiliaryRead();
    }

    function entropyProviderAt(uint256 index) external view override returns (address) {
        _auxiliaryRead();
    }

    function entropyProviderTransition(
        address provider,
        EntropyProviderState next,
        string calldata reasonURI
    )
        external
        view
        override
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 actionClass)
    {
        _auxiliaryRead();
    }

    function providerRevocationTransition(address provider, bool revoked)
        external
        view
        override
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        _auxiliaryRead();
    }

    function activateEntropyProvider(address provider, string calldata reasonURI)
        external
        override
        onlyAuthority
    {
        _updateProvider();
    }

    function deprecateEntropyProvider(address provider, string calldata reasonURI)
        external
        override
        onlyAuthority
    {
        _updateProvider();
    }

    function revokeEntropyProvider(address provider, string calldata reasonURI)
        external
        override
        onlyAuthority
    {
        _updateProvider();
    }

    function _updateProvider() private {
        PolicyImportState.requireOperational();
        StreamEntropyProviderLifecycle.updateEncoded(authority, providerRevoked, msg.data);
    }

    function onTokenMinted(
        uint256 collectionId,
        uint256 tokenId,
        address recipient,
        bytes32 mintCommitment
    ) external override {
        _entropyWrite();
    }

    /// @inheritdoc IStreamEntropyTiming
    function effectiveRequestTimeoutBlocks(uint256 collectionId)
        public
        view
        override
        returns (uint256)
    {
        CollectionConfig storage config = collectionEntropyConfig[collectionId];
        if (config.provider == address(0)) revert InvalidCollection(collectionId);
        uint256 live = _timeParameterValue(GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS);
        return live > config.timeoutBlocks ? live : config.timeoutBlocks;
    }

    /// @inheritdoc IStreamEntropyTiming
    function effectiveRevealSLOBlocks(uint256 collectionId) public view override returns (uint256) {
        IStreamRevealFeeEscrow.CollectionRevealPolicy storage policy = _revealPolicies[collectionId];
        if (!policy.declared) revert RevealPolicyUndeclared(collectionId);
        uint256 live = _timeParameterValue(GTP_ENTROPY_REVEAL_SLO_BLOCKS);
        return live > policy.requestSLOBlocks ? live : policy.requestSLOBlocks;
    }

    function requestEntropy(uint256 tokenId)
        external
        payable
        override
        nonReentrant
        returns (bytes32 requestKey, uint256 providerRequestId)
    {
        return abi.decode(_entropyWrite(), (bytes32, uint256));
    }

    function registerEntropyScope(uint256 collectionId, uint8 scopeKind, bytes32 scopeRef)
        external
        override
        returns (bytes32 scopeId)
    {
        PolicyImportState.requireOperationalAndMarkUsed();
        return StreamEntropyScopeRegistration.register(
            core,
            authority,
            requesters,
            _subjects,
            _registeredScopes,
            collectionEntropyConfig,
            _revealPolicies,
            collectionId,
            scopeKind,
            scopeRef
        );
    }

    function requestScopeEntropy(bytes32 scopeId, bytes32 scopeInputsHash)
        external
        payable
        override
        nonReentrant
        returns (bytes32 requestKey, uint256 providerRequestId)
    {
        return abi.decode(_entropyWrite(), (bytes32, uint256));
    }

    function _recoveryEnvironment()
        private
        view
        returns (StreamEntropyFreshRecovery.Environment memory)
    {
        return StreamEntropyFreshRecovery.Environment(
            core,
            _timeParameterValue(GTP_ENTROPY_RECOVERY_STEP_DELAY_BLOCKS),
            StreamEntropyIncidentParameters.value(GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT)
        );
    }

    function requestFreshEntropy(RecoveryInput calldata input)
        external
        payable
        override
        nonReentrant
        returns (bytes32 requestKey, uint256 providerRequestId)
    {
        return abi.decode(_entropyWrite(), (bytes32, uint256));
    }

    function requestFreshEntropyWithUnavailability(
        RecoveryInput calldata input,
        bytes32 findingRecordHash
    ) external payable nonReentrant returns (bytes32 requestKey, uint256 providerRequestId) {
        return abi.decode(_entropyWrite(), (bytes32, uint256));
    }

    function artistEntropyRecoveryIntent(RecoveryInput calldata input)
        external
        view
        returns (EntropyU.Intent memory)
    {
        bytes memory encoded = StreamEntropyFreshRecovery.intentEncoded(
            _recoveryEnvironment(), _subjects, requests, _requestPolicies, msg.data[4:]
        );
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function entropyRecoveryIntentTerminal(bytes32 oldRequestKey) external view returns (bool) {
        return StreamEntropyFreshRecovery.terminal(core, _subjects, requests, oldRequestKey);
    }

    function entropyUnavailabilityEvidence(bytes32 requestKey)
        external
        view
        returns (bytes32, bytes32, uint64)
    {
        return StreamEntropyFreshRecovery.findingEvidence(requestKey);
    }

    function freshRecoveryTransition(RecoveryInput calldata input)
        external
        view
        override
        returns (bytes32 requestKey, bytes32 contentStateHash, uint256 providerFee)
    {
        return StreamEntropyFreshRecovery.transition(
            _recoveryEnvironment(), _subjects, requests, _requestPolicies, input
        );
    }

    function freshRecoveryReceipt(bytes32) external view override returns (RecoveryReceipt memory) {
        _auxiliaryRead();
    }

    function artistContentFamilyState(uint256, bytes32)
        external
        view
        override
        returns (bool, bytes32)
    {
        _auxiliaryRead();
    }

    function fulfillEntropy(bytes32 requestKey, bytes32 rawRandomness)
        external
        override
        nonReentrant
        returns (uint8 outcome)
    {
        return abi.decode(_entropyWrite(), (uint8));
    }

    function fulfillRelayedEntropy(bytes32 requestKey, bytes32 relayId, bytes32 rawRandomness)
        external
        override
        nonReentrant
        returns (uint8 outcome)
    {
        return abi.decode(_entropyWrite(), (uint8));
    }

    function retryMetadataNotification(uint256 tokenId) external nonReentrant {
        _entropyWrite();
    }

    bytes32 public constant GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT =
        keccak256("6529STREAM_GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT");
    bytes32 public constant GGP_ENTROPY_INSTANT_READ_GAS_LIMIT =
        keccak256("6529STREAM_GGP_ENTROPY_INSTANT_READ_GAS_LIMIT");
    bytes32 public constant GGP_ENTROPY_RELAY_AUTH_READ_GAS_LIMIT =
        keccak256("6529STREAM_GGP_ENTROPY_RELAY_AUTH_READ_GAS_LIMIT");
    bytes32 public constant GGP_ENTROPY_RELAY_INSTANT_READ_GAS_LIMIT =
        keccak256("6529STREAM_GGP_ENTROPY_RELAY_INSTANT_READ_GAS_LIMIT");
    bytes32 public constant GGP_ENTROPY_RELAY_DELIVERY_GAS_LIMIT =
        keccak256("6529STREAM_GGP_ENTROPY_RELAY_DELIVERY_GAS_LIMIT");

    function gasParameter(bytes32 id) external view returns (uint256) {
        _auxiliaryRead();
    }

    function gasParameterInfo(bytes32 id) external view returns (uint256, uint256, uint8, uint64) {
        _auxiliaryRead();
    }

    function gasParameterIds() external pure returns (bytes32[] memory) {
        return StreamEntropyIncidentParameters.ids();
    }

    function gasParameterTransition(bytes32 id, uint256 next)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        _auxiliaryRead();
    }

    function raiseGasParameter(bytes32 id, uint256 next) external {
        StreamEntropyIncidentParameters.raise(authority, id, next);
    }

    function entropyIncident(bytes32 key) external view override returns (Incident memory) {
        _auxiliaryRead();
    }

    function markEntropyRequestUnrecoverable(
        uint256 tokenId,
        string calldata reasonURI,
        bytes32 evidenceHash
    ) external override nonReentrant {
        _entropyWrite();
    }

    function markEntropyScopeRequestUnrecoverable(
        bytes32 scopeId,
        string calldata reasonURI,
        bytes32 evidenceHash
    ) external override nonReentrant {
        _entropyWrite();
    }

    /// @notice Marks a timed-out request terminal without authorizing a fresh random draw.
    function markRequestStale(bytes32 requestKey) external onlyAuthority nonReentrant {
        _entropyWrite();
    }

    /// @notice Requires adapter evidence of terminal failure before displaying a failed request.
    function markRequestFailed(bytes32 requestKey) external onlyAuthority nonReentrant {
        _entropyWrite();
    }

    function claimEntropyFeeCredit(address payable destination) external nonReentrant {
        _entropyWrite();
    }

    function tokenSeed(uint256 tokenId)
        external
        view
        override
        returns (bytes32 seed, bool finalized)
    {
        _subjectRead();
    }

    function tokenEntropyStatus(uint256 tokenId)
        public
        view
        override
        returns (StreamEntropyStatus)
    {
        return _subjects[_tokenKey(tokenId)].status;
    }

    /// @notice Original token render facts, read directly without external or delegated calls.
    /// @dev Status values match IStreamEntropyView. A saved request pins its original provider;
    ///      before a request, provider follows the original collection configuration lookup.
    function staticTokenRenderFacts(uint256 tokenId)
        external
        view
        returns (uint8 status, bytes32 seed, address provider)
    {
        Subject storage subject = _subjects[_tokenKey(tokenId)];
        status = uint8(subject.status);
        seed = subject.seed;
        provider = subject.requestKey == bytes32(0)
            ? collectionEntropyConfig[subject.collectionId].provider
            : _requestPolicies[subject.requestKey].provider;
    }

    /// @inheritdoc IStreamEntropyTerminalFacts
    function staticTerminalEntropyFacts(uint256 tokenId)
        external
        view
        override
        returns (
            uint256 collectionId,
            CollectionPolicy.PolicyRecord memory policy,
            uint8 status,
            bytes32 seed,
            bytes32 requestKey
        )
    {
        Subject storage subject = _subjects[_tokenKey(tokenId)];
        collectionId = subject.collectionId;
        PolicyState.Entry storage entry = PolicyState.store().entries[collectionId];
        if (entry.revision == 0) {
            revert CollectionPolicy.ExplicitCollectionPolicyRequired(collectionId);
        }
        policy.configured = true;
        policy.explicitPolicy = true;
        policy.frozen = collectionEntropyConfig[collectionId].locked;
        policy.mode = entry.mode;
        policy.securityClass = entry.securityClass;
        policy.renderRequirement = entry.renderRequirement;
        policy.revision = entry.revision;
        policy.providerEpoch = collectionProviderEpoch[collectionId];
        policy.policyHash = entry.policyHash;
        policy.contentStateHash = PolicyState.contentState(entry.policyHash, policy.frozen);
        policy.lastActionId = entry.lastActionId;
        policy.artistConsentRecord = entry.artistConsentRecord;
        status = uint8(subject.status);
        seed = subject.seed;
        requestKey = subject.requestKey;
    }

    function tokenEntropy(uint256 tokenId)
        external
        view
        override
        returns (
            StreamEntropyStatus status,
            bytes32 seed,
            address provider,
            uint32 providerEpoch,
            bytes32 providerConfigHash,
            bytes32 requestKey,
            uint256 providerRequestId,
            uint16 requestAttempt
        )
    {
        _subjectRead();
    }

    /// @inheritdoc IStreamEntropyEpochs
    function requestPolicySnapshot(bytes32 requestKey)
        external
        view
        override
        returns (RequestPolicySnapshot memory)
    {
        _subjectRead();
    }

    function scopeSeed(bytes32 scopeId) external view returns (bytes32 seed, bool finalized) {
        _subjectRead();
    }

    function scopeEntropy(bytes32 scopeId) external view returns (Subject memory) {
        _subjectRead();
    }

    /// @dev Used only by the six external stored-read selectors, preserving their exact ABI.
    function _subjectRead() private view {
        bytes memory encoded = StreamEntropySubjectReads.read(
            collectionEntropyConfig,
            collectionProviderEpoch,
            _subjects,
            requests,
            _requestPolicies,
            _revealPolicies,
            msg.data
        );
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    /// @dev Only terminal read entrypoints use this fixed decoder. No mutation/guard cleanup is bypassed.
    function _auxiliaryRead() private view {
        bytes memory result = StreamEntropyAuxiliaryReads.read(
            core,
            collectionEntropyConfig,
            collectionProviderEpoch,
            _revealPolicies,
            revealFeeEscrow,
            msg.data
        );
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }

    /// @dev Fixed finite worker; return normally so every host modifier performs its cleanup.
    function _entropyWrite() private returns (bytes memory) {
        StreamEntropyExecution.Word storage credits;
        StreamEntropyExecution.Word storage pending;
        StreamEntropyExecution.Word storage escrowTotal;
        assembly ("memory-safe") {
            credits.slot := totalFeeCredits.slot
            pending.slot := pendingRequestCount.slot
            escrowTotal.slot := totalRevealFeeEscrows.slot
        }
        return StreamEntropyExecution.write(
            StreamEntropyExecution.Environment(core, authority, roleRegistry, roleRegistryCodeHash),
            collectionEntropyConfig,
            requesters,
            providerRevoked,
            _subjects,
            requests,
            providerRequestKeys,
            entropyFeeCredit,
            credits,
            pending,
            metadataNotificationPending,
            _registeredScopes,
            _revealPolicies,
            revealFeeEscrow,
            escrowTotal,
            registeredAtBlock,
            nonterminalTokenCount,
            collectionProviderEpoch,
            _requestPolicies,
            _timeParameters,
            msg.data
        );
    }

    function _tokenKey(uint256 tokenId) private pure returns (bytes32) {
        return keccak256(abi.encode("TOKEN", tokenId));
    }
}

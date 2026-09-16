// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamEntropyTerminalAdmission } from "./StreamEntropyTerminalAdmission.sol";
import { StreamEntropySubjectReads } from "./StreamEntropySubjectReads.sol";
import {
    IStreamEntropyArtistUnavailability as EntropyU
} from "../../interfaces/stream/entropy/IStreamEntropyArtistUnavailability.sol";

import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import "../../interfaces/stream/entropy/IStreamEntropyProvider.sol";
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
    IStreamEntropyFreshRecovery
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
            || id == type(IStreamEntropyProviderLifecycle).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || super.supportsInterface(id);
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
        StreamEntropyCollectionConfiguration.configure(
            core,
            collectionEntropyConfig,
            collectionProviderEpoch,
            _revealPolicies,
            collectionId,
            provider,
            collectionSalt,
            publicRequests,
            timeoutBlocks
        );
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
        _requireEntropyAdmin();
        if (
            !core.collectionExists(collectionId)
                || collectionEntropyConfig[collectionId].provider == address(0)
        ) {
            revert InvalidCollection(collectionId);
        }
        if (
            collectionEntropyConfig[collectionId].locked
                || core.collectionFreezeStatus(collectionId)
        ) {
            revert PolicyLocked(collectionId);
        }
        if (requestMode > 1 || revealOwnerRole != _REVEAL_OWNER || requestSLOBlocks == 0) {
            revert InvalidRevealPolicy(collectionId);
        }
        _validateRevealFee(collectionId, revealFeePerTokenWei);
        _revealPolicies[collectionId] = IStreamRevealFeeEscrow.CollectionRevealPolicy(
            true, requestMode, revealOwnerRole, requestSLOBlocks, revealFeePerTokenWei
        );
        emit RevealPolicyConfigured(
            1, collectionId, requestMode, revealOwnerRole, requestSLOBlocks, revealFeePerTokenWei
        );
    }

    /// @notice Retunes funding for future mints without changing frozen reveal promises or escrow.
    function updateRevealFeePerToken(uint256 collectionId, uint256 next) external override {
        _requireEntropyAdmin();
        IStreamRevealFeeEscrow.CollectionRevealPolicy storage policy = _revealPolicies[collectionId];
        if (!policy.declared) revert RevealPolicyUndeclared(collectionId);
        _validateRevealFee(collectionId, next);
        uint256 previous = policy.revealFeePerTokenWei;
        policy.revealFeePerTokenWei = next;
        emit RevealFeePerTokenUpdated(1, collectionId, previous, next);
    }

    /// @notice Permissionless funding does not query or request the provider, including during outages.
    function fundRevealFeeEscrow(uint256 collectionId) external payable nonReentrant {
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        if (!_revealPolicies[collectionId].declared) revert RevealPolicyUndeclared(collectionId);
        revealFeeEscrow[collectionId] += msg.value;
        totalRevealFeeEscrows += msg.value;
        emit RevealFeeEscrowFunded(
            1, collectionId, msg.sender, msg.value, revealFeeEscrow[collectionId]
        );
    }

    /// @notice Residual collection funds can only reach the current registry-resolved treasury.
    function withdrawRevealFeeEscrow(uint256 collectionId, uint256 amount)
        external
        override
        nonReentrant
    {
        _requireEntropyAdmin();
        if (!_revealPolicies[collectionId].declared) revert RevealPolicyUndeclared(collectionId);
        if (
            nonterminalTokenCount[collectionId] != 0 || amount == 0
                || amount > revealFeeEscrow[collectionId]
        ) {
            revert RevealEscrowUnavailable(collectionId);
        }
        address treasury = roleRegistry.resolveRole(_TREASURY);
        if (treasury.code.length == 0) revert InvalidDestination();
        revealFeeEscrow[collectionId] -= amount;
        totalRevealFeeEscrows -= amount;
        (bool success,) = treasury.call{ value: amount }("");
        if (!success) revert CreditTransferFailed();
        emit RevealFeeEscrowWithdrawn(1, collectionId, treasury, amount);
    }

    function _validateRevealFee(uint256 collectionId, uint256 fee) private view {
        StreamEntropyCoordinatorReads.validateRevealFee(collectionEntropyConfig[collectionId], fee);
    }

    function _requireEntropyAdmin() private view {
        if (!_hasRole(_ENTROPY_ADMIN, msg.sender)) revert Unauthorized(msg.sender);
    }

    function _hasRole(bytes32 role, address account) private view returns (bool) {
        return StreamEntropyCoordinatorReads.hasRole(
            core, authority, roleRegistry, roleRegistryCodeHash, role, account
        );
    }

    function setRequester(address requester, bool allowed) external onlyAuthority {
        if (requester == address(0)) revert InvalidDependency(requester);
        requesters[requester] = allowed;
        emit EntropyRequesterUpdated(requester, allowed);
    }

    /// @notice Compatibility transition, bound to its original delayed catalog class.
    function setProviderRevoked(address provider, bool revoked) external onlyAuthority {
        _updateProvider(
            provider,
            revoked ? EntropyProviderState.INCIDENT_REVOKED : EntropyProviderState.ACTIVE,
            StreamEntropyProviderLifecycle.LEGACY_REASON,
            true
        );
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
        _updateProvider(provider, EntropyProviderState.ACTIVE, reasonURI, false);
    }

    function deprecateEntropyProvider(address provider, string calldata reasonURI)
        external
        override
        onlyAuthority
    {
        _updateProvider(provider, EntropyProviderState.DEPRECATED, reasonURI, false);
    }

    function revokeEntropyProvider(address provider, string calldata reasonURI)
        external
        override
        onlyAuthority
    {
        _updateProvider(provider, EntropyProviderState.INCIDENT_REVOKED, reasonURI, false);
    }

    function _updateProvider(
        address provider,
        EntropyProviderState next,
        string memory reasonURI,
        bool legacy
    ) private {
        StreamEntropyProviderLifecycle.update(authority, provider, next, reasonURI, legacy);
        bool revoked = next == EntropyProviderState.INCIDENT_REVOKED;
        providerRevoked[provider] = revoked;
        emit ProviderRevocationUpdated(provider, revoked);
    }

    function onTokenMinted(
        uint256 collectionId,
        uint256 tokenId,
        address recipient,
        bytes32 mintCommitment
    ) external override {
        if (msg.sender != address(core)) revert Unauthorized(msg.sender);
        (bool exists, uint256 actualCollection,, bool burned) =
            core.tokenCollectionIdentity(tokenId);
        if (
            !exists || burned || actualCollection != collectionId || recipient == address(0)
                || core.coordinatorAtMint(tokenId) != address(this)
        ) revert InvalidToken(tokenId);
        bytes32 key = _tokenKey(tokenId);
        if (_subjects[key].status != StreamEntropyStatus.NONE) revert InvalidSubject(key);
        _lockPolicy(collectionId);
        _subjects[key].collectionId = collectionId;
        _subjects[key].inputsHash = mintCommitment;
        _subjects[key].status = StreamEntropyStatus.REGISTERED;
        if (block.number > type(uint64).max) revert EntropyBlockNumberOverflow();
        registeredAtBlock[tokenId] = uint64(block.number);
        ++nonterminalTokenCount[collectionId];
        emit EntropyRegistered(collectionId, tokenId, mintCommitment);
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
        Subject storage subject = _subjects[_tokenKey(tokenId)];
        if (
            core.tokenLifecycle(tokenId) != uint8(StreamTokenLifecycle.MINTED)
                || core.coordinatorAtMint(tokenId) != address(this)
        ) revert InvalidToken(tokenId);
        // A matured public remedy does not depend on availability of optional role reads.
        // Subtraction avoids overflow when a governed window approaches uint256's limit.
        bool lapsed = subject.status == StreamEntropyStatus.REGISTERED
            && block.number > registeredAtBlock[tokenId]
            && block.number - registeredAtBlock[tokenId]
                > effectiveRevealSLOBlocks(subject.collectionId);
        if (
            !lapsed && msg.sender != authority && !requesters[msg.sender]
                && !collectionEntropyConfig[subject.collectionId].publicRequests
                && !_hasRole(_ENTROPY_ADMIN, msg.sender)
                && !_hasRole(_revealPolicies[subject.collectionId].revealOwnerRole, msg.sender)
        ) revert Unauthorized(msg.sender);
        return _request(_tokenKey(tokenId), tokenId, bytes32(0));
    }

    function registerEntropyScope(uint256 collectionId, uint8 scopeKind, bytes32 scopeRef)
        external
        override
        returns (bytes32 scopeId)
    {
        if (msg.sender != authority && !requesters[msg.sender]) {
            revert Unauthorized(msg.sender);
        }
        if (scopeKind > 2 || scopeRef == 0 || !core.collectionExists(collectionId)) {
            revert InvalidCollection(collectionId);
        }
        scopeId = keccak256(
            abi.encode(
                SCOPE_DOMAIN,
                block.chainid,
                address(this),
                address(core),
                collectionId,
                scopeKind,
                scopeRef
            )
        );
        if (_subjects[scopeId].status != StreamEntropyStatus.NONE) revert InvalidSubject(scopeId);
        _lockPolicy(collectionId);
        _registeredScopes[scopeId] = true;
        _subjects[scopeId].collectionId = collectionId;
        _subjects[scopeId].status = StreamEntropyStatus.REGISTERED;
        emit EntropyScopeRegistered(collectionId, scopeId, scopeKind, scopeRef);
    }

    function requestScopeEntropy(bytes32 scopeId, bytes32 scopeInputsHash)
        external
        payable
        override
        nonReentrant
        returns (bytes32 requestKey, uint256 providerRequestId)
    {
        if (msg.sender != authority && !requesters[msg.sender]) {
            revert Unauthorized(msg.sender);
        }
        // Token keys share _subjects storage but must never enter the mutable scope-input path.
        if (!_registeredScopes[scopeId] || scopeInputsHash == 0) revert InvalidSubject(scopeId);
        _subjects[scopeId].inputsHash = scopeInputsHash;
        return _request(scopeId, 0, scopeId);
    }

    function _lockPolicy(uint256 collectionId) private {
        CollectionConfig storage config = collectionEntropyConfig[collectionId];
        if (config.provider == address(0)) revert InvalidCollection(collectionId);
        if (!_revealPolicies[collectionId].declared) revert RevealPolicyUndeclared(collectionId);
        config.locked = true;
    }

    function _request(bytes32 subjectKey, uint256 tokenId, bytes32 scopeId)
        private
        returns (bytes32 requestKey, uint256 providerRequestId)
    {
        Subject storage subject = _subjects[subjectKey];
        StreamEntropyRequestPlan.Plan memory p = StreamEntropyRequestPlan.initial(
            core,
            subject,
            collectionEntropyConfig[subject.collectionId],
            collectionProviderEpoch[subject.collectionId],
            tokenId,
            scopeId
        );
        return _submitRequest(subjectKey, tokenId, scopeId, p);
    }

    function _submitRequest(
        bytes32 subjectKey,
        uint256 tokenId,
        bytes32 scopeId,
        StreamEntropyRequestPlan.Plan memory p
    ) private returns (bytes32 requestKey, uint256 providerRequestId) {
        Subject storage subject = _subjects[subjectKey];
        _fundRequest(subject.collectionId, tokenId, p.fee);
        requestKey = p.key;
        address provider = p.policy.provider;
        subject.requestKey = requestKey;
        subject.status = StreamEntropyStatus.REQUESTED;
        requests[requestKey] =
            Request(subjectKey, tokenId, scopeId, provider, uint64(block.number), 0, 0);
        _requestPolicies[requestKey] = p.policy;
        ++pendingRequestCount;
        providerRequestId =
            IStreamEntropyProvider(provider).requestEntropy{ value: p.fee }(requestKey, p.context);
        if (providerRequestKeys[provider][providerRequestId] != 0) {
            revert ProviderRequestCollision(provider, providerRequestId);
        }
        providerRequestKeys[provider][providerRequestId] = requestKey;
        requests[requestKey].providerRequestId = providerRequestId;
        emit EntropyRequested(requestKey, tokenId, scopeId, provider, providerRequestId);
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
        return _requestFreshWithEvidence(input, bytes32(0));
    }

    function requestFreshEntropyWithUnavailability(
        RecoveryInput calldata input,
        bytes32 findingRecordHash
    ) external payable nonReentrant returns (bytes32 requestKey, uint256 providerRequestId) {
        if (findingRecordHash == 0) revert FreshRecoveryArtistEvidenceUnavailable();
        return _requestFreshWithEvidence(input, findingRecordHash);
    }

    function _requestFreshWithEvidence(RecoveryInput calldata input, bytes32 findingRecordHash)
        private
        returns (bytes32 requestKey, uint256 providerRequestId)
    {
        if (!_hasRole(keccak256("ROLE_ENTROPY_INCIDENT_DECLARER"), msg.sender)) {
            revert Unauthorized(msg.sender);
        }
        StreamEntropyRequestPlan.Plan memory p = StreamEntropyFreshRecovery.admitSelected(
            _recoveryEnvironment(), _subjects, requests, _requestPolicies, input, findingRecordHash
        );
        Request storage old = requests[input.oldRequestKey];
        if (old.tokenId != 0) ++nonterminalTokenCount[_subjects[old.subjectKey].collectionId];
        return _submitRequest(old.subjectKey, old.tokenId, old.scopeId, p);
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

    function _fundRequest(uint256 collectionId, uint256 tokenId, uint256 fee) private {
        uint256 draw;
        if (tokenId != 0) {
            uint256 escrow = revealFeeEscrow[collectionId];
            draw = escrow < fee ? escrow : fee;
        }
        uint256 callerCost = fee - draw;
        if (msg.value < callerCost) {
            if (tokenId == 0) revert InsufficientEntropyFee(fee, msg.value);
            revert InsufficientRevealFee(fee, draw, msg.value);
        }
        if (draw != 0) {
            revealFeeEscrow[collectionId] -= draw;
            totalRevealFeeEscrows -= draw;
            emit RevealFeeEscrowSpent(1, collectionId, tokenId, draw, revealFeeEscrow[collectionId]);
        }
        uint256 excess = msg.value - callerCost;
        if (excess != 0) {
            entropyFeeCredit[msg.sender] += excess;
            totalFeeCredits += excess;
            emit EntropyFeeCredited(msg.sender, excess);
        }
    }

    function fulfillEntropy(bytes32 requestKey, bytes32 rawRandomness)
        external
        override
        nonReentrant
        returns (uint8 outcome)
    {
        Request storage request = requests[requestKey];
        Subject storage subject = _subjects[request.subjectKey];
        outcome = StreamEntropyFulfillment.finalize(
            core, request, subject, _requestPolicies[requestKey], requestKey, rawRandomness
        );
        if (outcome != 0) return _reject(requestKey, outcome);
        --pendingRequestCount;
        if (request.tokenId != 0) --nonterminalTokenCount[subject.collectionId];
        emit EntropyFinalized(
            requestKey, request.tokenId, request.scopeId, subject.seed, rawRandomness
        );
        if (request.tokenId != 0) _notify(request.tokenId, requestKey);
        return 0;
    }

    function _reject(bytes32 requestKey, uint8 outcome) private returns (uint8) {
        emit EntropyFulfillmentRejected(requestKey, outcome);
        return outcome;
    }

    function _notify(uint256 tokenId, bytes32 requestKey) private {
        try core.emitMetadataUpdate(tokenId, requestKey) {
            metadataNotificationPending[tokenId] = false;
        } catch {
            metadataNotificationPending[tokenId] = true;
            emit MetadataNotificationFailed(tokenId, requestKey);
        }
    }

    function retryMetadataNotification(uint256 tokenId) external nonReentrant {
        Subject storage subject = _subjects[_tokenKey(tokenId)];
        if (
            !metadataNotificationPending[tokenId]
                || (subject.status != StreamEntropyStatus.FINALIZED
                    && subject.status != StreamEntropyStatus.STALE
                    && subject.status != StreamEntropyStatus.FAILED)
        ) revert InvalidToken(tokenId);
        _notify(tokenId, subject.requestKey);
    }

    bytes32 public constant GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT =
        keccak256("6529STREAM_GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT");

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
        if (tokenId == 0) revert InvalidToken(tokenId);
        _markUnrecoverable(_tokenKey(tokenId), tokenId, bytes32(0), reasonURI, evidenceHash);
    }

    function markEntropyScopeRequestUnrecoverable(
        bytes32 scopeId,
        string calldata reasonURI,
        bytes32 evidenceHash
    ) external override nonReentrant {
        if (!_registeredScopes[scopeId]) revert InvalidSubject(scopeId);
        _markUnrecoverable(scopeId, 0, scopeId, reasonURI, evidenceHash);
    }

    function _markUnrecoverable(
        bytes32 subjectKey,
        uint256 tokenId,
        bytes32 scopeId,
        string calldata reasonURI,
        bytes32 evidenceHash
    ) private {
        if (!_hasRole(keccak256("ROLE_ENTROPY_INCIDENT_DECLARER"), msg.sender)) {
            revert Unauthorized(msg.sender);
        }
        Subject storage subject = _subjects[subjectKey];
        bytes32 key = subject.requestKey;
        Request storage request = requests[key];
        RequestPolicySnapshot storage policy = _requestPolicies[key];
        StreamEntropyIncidentTransition.record(
            subject,
            request,
            policy,
            subjectKey,
            tokenId,
            scopeId,
            providerRevoked[request.provider],
            collectionEntropyConfig[subject.collectionId],
            _timeParameterValue(GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS),
            StreamEntropyIncidentParameters.value(GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT),
            reasonURI,
            evidenceHash
        );
        _terminal(key, subject, StreamEntropyStatus.FAILED);
        StreamEntropyIncidentTransition.emitFailure(
            subject, request, policy, tokenId, scopeId, reasonURI, evidenceHash
        );
    }

    /// @notice Marks a timed-out request terminal without authorizing a fresh random draw.
    function markRequestStale(bytes32 requestKey) external onlyAuthority nonReentrant {
        Request storage request = requests[requestKey];
        Subject storage subject = _subjects[request.subjectKey];
        StreamEntropyTerminalAdmission.stale(request, subject, requestKey);
        _terminal(requestKey, subject, StreamEntropyStatus.STALE);
    }

    /// @notice Requires adapter evidence of terminal failure before displaying a failed request.
    function markRequestFailed(bytes32 requestKey) external onlyAuthority nonReentrant {
        Request storage request = requests[requestKey];
        Subject storage subject = _subjects[request.subjectKey];
        StreamEntropyTerminalAdmission.failed(request, subject, requestKey);
        _terminal(requestKey, subject, StreamEntropyStatus.FAILED);
    }

    function _terminal(bytes32 requestKey, Subject storage subject, StreamEntropyStatus status)
        private
    {
        subject.status = status;
        --pendingRequestCount;
        emit EntropyRequestTerminal(requestKey, status);
        uint256 tokenId = requests[requestKey].tokenId;
        if (tokenId != 0) {
            --nonterminalTokenCount[subject.collectionId];
            _notify(tokenId, requestKey);
        }
    }

    function claimEntropyFeeCredit(address payable destination) external nonReentrant {
        if (destination == address(0)) revert InvalidDestination();
        uint256 amount = entropyFeeCredit[msg.sender];
        entropyFeeCredit[msg.sender] = 0;
        totalFeeCredits -= amount;
        (bool success,) = destination.call{ value: amount }("");
        if (!success) revert CreditTransferFailed();
        emit EntropyFeeCreditClaimed(msg.sender, destination, amount);
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
            core, collectionEntropyConfig, collectionProviderEpoch, msg.data
        );
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }

    function _tokenKey(uint256 tokenId) private pure returns (bytes32) {
        return keccak256(abi.encode("TOKEN", tokenId));
    }
}

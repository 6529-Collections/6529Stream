// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
import "./StreamEntropyIncidentParameters.sol";
import "./StreamEntropyIncidentEvidence.sol";
import "./StreamEntropyCoordinatorReads.sol";
import "../../interfaces/stream/entropy/IStreamEntropyIncidents.sol";

/// @notice Core-bound asynchronous entropy with immutable request inputs and no ordinary reroll.
/// @dev A collection's initial policy locks on its first token or scope registration. Fresh
///      randomness recovery and provider migration require a separate explicit implementation.
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
    IStreamEntropyIncidents
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
            || id == type(IStreamGasParameterHost).interfaceId || super.supportsInterface(id);
    }

    function configureCollection(
        uint256 collectionId,
        address provider,
        bytes32 collectionSalt,
        bool publicRequests,
        uint64 timeoutBlocks
    ) external onlyAuthority {
        if (!core.collectionExists(collectionId)) {
            revert InvalidCollection(collectionId);
        }
        if (
            collectionEntropyConfig[collectionId].locked
                || core.collectionFreezeStatus(collectionId)
        ) revert PolicyLocked(collectionId);
        bytes32 configHash =
            StreamEntropyCoordinatorReads.providerConfiguration(provider, timeoutBlocks);
        CollectionConfig storage prior = collectionEntropyConfig[collectionId];
        uint32 epoch = collectionProviderEpoch[collectionId];
        if (prior.provider != provider || prior.providerConfigHash != configHash) {
            if (epoch == type(uint32).max) revert ProviderEpochOverflow(collectionId);
            collectionProviderEpoch[collectionId] = ++epoch;
        }
        collectionEntropyConfig[collectionId] = CollectionConfig(
            provider,
            publicRequests,
            false,
            timeoutBlocks,
            configHash,
            provider.codehash,
            collectionSalt
        );
        if (_revealPolicies[collectionId].declared) {
            _validateRevealFee(collectionId, _revealPolicies[collectionId].revealFeePerTokenWei);
        }
        emit CollectionEntropyConfigured(
            collectionId, provider, configHash, collectionSalt, publicRequests, timeoutBlocks
        );
        emit CollectionEntropyEpochConfigured(1, collectionId, provider, epoch, configHash);
    }

    /// @notice Explicit declared-zero policies remain distinguishable from absent configuration.
    function collectionRevealPolicy(uint256 collectionId)
        external
        view
        returns (IStreamRevealFeeEscrow.CollectionRevealPolicy memory)
    {
        return _revealPolicies[collectionId];
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
        return StreamEntropyCoordinatorReads.policy(
            core,
            collectionId,
            collectionEntropyConfig[collectionId],
            _revealPolicies[collectionId],
            collectionProviderEpoch[collectionId]
        );
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
        CollectionConfig storage config = collectionEntropyConfig[collectionId];
        address provider = config.provider;
        if (
            provider.code.length == 0 || provider.codehash != config.providerCodeHash
                || IStreamEntropyProvider(provider).streamEntropyProviderConfigHash()
                    != config.providerConfigHash
        ) {
            revert ProviderConfigurationChanged(provider);
        }
        if (!IERC165(provider).supportsInterface(type(IStreamEntropyProviderFeeQuote).interfaceId))
        {
            revert RevealFeeQuoteUnavailable(provider);
        }
        bytes memory data =
            abi.encodeCall(IStreamEntropyProviderFeeQuote.contextIndependentRequestFee, ());
        bool success;
        uint256 size;
        uint256 quote;
        assembly ("memory-safe") {
            let result := mload(0x40)
            success := staticcall(gas(), provider, add(data, 32), mload(data), result, 32)
            size := returndatasize()
            quote := mload(result)
        }
        if (!success || size != 32) revert RevealFeeQuoteUnavailable(provider);
        if (fee < quote) revert RevealFeeBelowQuote(fee, quote);
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

    function setProviderRevoked(address provider, bool revoked) external onlyAuthority {
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
        if (subject.status != StreamEntropyStatus.REGISTERED) revert InvalidStatus(subject.status);
        if (block.number > type(uint64).max) revert EntropyBlockNumberOverflow();
        CollectionConfig storage config = collectionEntropyConfig[subject.collectionId];
        address provider = config.provider;
        uint32 providerEpoch = collectionProviderEpoch[subject.collectionId];
        if (
            providerRevoked[provider] || provider.codehash != config.providerCodeHash
                || IStreamEntropyProvider(provider).streamEntropyProviderConfigHash()
                    != config.providerConfigHash
        ) revert ProviderConfigurationChanged(provider);
        bytes memory context = abi.encode(
            uint16(scopeId == 0 ? 1 : 2),
            address(core),
            subject.collectionId,
            tokenId,
            scopeId,
            providerEpoch,
            config.providerConfigHash,
            uint16(1),
            subject.inputsHash
        );
        if (scopeId == 0) {
            requestKey = keccak256(
                abi.encode(
                    REQUEST_DOMAIN,
                    block.chainid,
                    address(this),
                    address(core),
                    subject.collectionId,
                    tokenId,
                    provider,
                    providerEpoch,
                    config.providerConfigHash,
                    uint16(1)
                )
            );
        } else {
            requestKey = keccak256(
                abi.encode(
                    SCOPE_REQUEST_DOMAIN,
                    block.chainid,
                    address(this),
                    address(core),
                    subject.collectionId,
                    scopeId,
                    provider,
                    providerEpoch,
                    config.providerConfigHash,
                    subject.inputsHash,
                    uint16(1)
                )
            );
        }
        uint256 fee = IStreamEntropyProvider(provider).quoteRequest(context);
        _fundRequest(subject.collectionId, tokenId, fee);
        subject.requestKey = requestKey;
        subject.status = StreamEntropyStatus.REQUESTED;
        requests[requestKey] =
            Request(subjectKey, tokenId, scopeId, provider, uint64(block.number), 0, 0);
        _requestPolicies[requestKey] = RequestPolicySnapshot({
            provider: provider,
            providerCodeHash: config.providerCodeHash,
            providerEpoch: providerEpoch,
            providerConfigHash: config.providerConfigHash,
            collectionSalt: config.collectionSalt,
            inputsHash: subject.inputsHash,
            requestAttempt: 1
        });
        ++pendingRequestCount;
        providerRequestId =
            IStreamEntropyProvider(provider).requestEntropy{ value: fee }(requestKey, context);
        if (providerRequestKeys[provider][providerRequestId] != 0) {
            revert ProviderRequestCollision(provider, providerRequestId);
        }
        providerRequestKeys[provider][providerRequestId] = requestKey;
        requests[requestKey].providerRequestId = providerRequestId;
        emit EntropyRequested(requestKey, tokenId, scopeId, provider, providerRequestId);
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
        if (request.provider == address(0)) return _reject(requestKey, 4);
        if (msg.sender != request.provider) revert Unauthorized(msg.sender);
        Subject storage subject = _subjects[request.subjectKey];
        if (subject.status == StreamEntropyStatus.FINALIZED) return _reject(requestKey, 3);
        if (providerRevoked[msg.sender]) return _reject(requestKey, 5);
        if (subject.status == StreamEntropyStatus.STALE) return _reject(requestKey, 1);
        if (subject.status != StreamEntropyStatus.REQUESTED || subject.requestKey != requestKey) {
            return _reject(requestKey, 2);
        }
        bytes32 seed = _deriveSeed(requestKey, request, subject, rawRandomness);
        request.rawRandomness = rawRandomness;
        subject.seed = seed;
        subject.status = StreamEntropyStatus.FINALIZED;
        --pendingRequestCount;
        if (request.tokenId != 0) --nonterminalTokenCount[subject.collectionId];
        emit EntropyFinalized(requestKey, request.tokenId, request.scopeId, seed, rawRandomness);
        if (request.tokenId != 0) _notify(request.tokenId, requestKey);
        return 0;
    }

    function _deriveSeed(
        bytes32 requestKey,
        Request storage request,
        Subject storage subject,
        bytes32 rawRandomness
    ) private view returns (bytes32) {
        return StreamEntropyCoordinatorReads.deriveSeed(
            core, requestKey, request, subject, _requestPolicies[requestKey], rawRandomness
        );
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
        return StreamEntropyIncidentParameters.value(id);
    }

    function gasParameterInfo(bytes32 id) external view returns (uint256, uint256, uint8, uint64) {
        return StreamEntropyIncidentParameters.info(id);
    }

    function gasParameterIds() external pure returns (bytes32[] memory) {
        return StreamEntropyIncidentParameters.ids();
    }

    function gasParameterTransition(bytes32 id, uint256 next)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        return StreamEntropyIncidentParameters.transition(id, next);
    }

    function raiseGasParameter(bytes32 id, uint256 next) external {
        StreamEntropyIncidentParameters.raise(authority, id, next);
    }

    function entropyIncident(bytes32 key) external view override returns (Incident memory) {
        return StreamEntropyIncidentEvidence.incident(key);
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
        if (subject.status != StreamEntropyStatus.REQUESTED) revert InvalidStatus(subject.status);
        bytes32 key = subject.requestKey;
        Request storage request = requests[key];
        RequestPolicySnapshot storage policy = _requestPolicies[key];
        if (
            key == 0 || subject.seed != 0 || request.subjectKey != subjectKey
                || request.tokenId != tokenId || request.scopeId != scopeId
                || request.provider != policy.provider || policy.inputsHash != subject.inputsHash
                || request.rawRandomness != 0
        ) revert IncidentRequestMismatch();
        if (
            !providerRevoked[request.provider]
                && (block.number <= request.requestedAtBlock
                    || block.number - request.requestedAtBlock
                        <= effectiveRequestTimeoutBlocks(subject.collectionId))
        ) {
            revert RequestNotExpired();
        }
        StreamEntropyIncidentEvidence.record(
            key,
            request.provider,
            policy.providerCodeHash,
            request.providerRequestId,
            StreamEntropyIncidentParameters.value(GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT),
            reasonURI,
            evidenceHash
        );
        _terminal(key, subject, StreamEntropyStatus.FAILED);
        if (tokenId != 0) {
            emit EntropyRequestFailed(
                1,
                subject.collectionId,
                tokenId,
                request.provider,
                key,
                policy.providerEpoch,
                policy.requestAttempt,
                reasonURI,
                evidenceHash
            );
        } else {
            emit EntropyScopeRequestFailed(
                1,
                subject.collectionId,
                scopeId,
                request.provider,
                key,
                policy.providerEpoch,
                policy.requestAttempt,
                reasonURI,
                evidenceHash
            );
        }
    }

    /// @notice Marks a timed-out request terminal without authorizing a fresh random draw.
    function markRequestStale(bytes32 requestKey) external onlyAuthority nonReentrant {
        Request storage request = requests[requestKey];
        Subject storage subject = _subjects[request.subjectKey];
        if (subject.status != StreamEntropyStatus.REQUESTED) revert InvalidStatus(subject.status);
        if (
            block.number <= request.requestedAtBlock
                || block.number - request.requestedAtBlock
                    <= effectiveRequestTimeoutBlocks(subject.collectionId)
        ) revert RequestNotExpired();
        (, bytes32 boundKey,, bool received,) =
            IStreamEntropyProvider(request.provider).providerResultStatus(request.providerRequestId);
        if (boundKey != requestKey || received) revert ProviderOutputAlreadyReceived();
        _terminal(requestKey, subject, StreamEntropyStatus.STALE);
    }

    /// @notice Requires adapter evidence of terminal failure before displaying a failed request.
    function markRequestFailed(bytes32 requestKey) external onlyAuthority nonReentrant {
        Request storage request = requests[requestKey];
        Subject storage subject = _subjects[request.subjectKey];
        if (subject.status != StreamEntropyStatus.REQUESTED) revert InvalidStatus(subject.status);
        (StreamProviderResultStatus status, bytes32 boundKey,, bool received,) =
            IStreamEntropyProvider(request.provider).providerResultStatus(request.providerRequestId);
        if (
            boundKey != requestKey || received
                || status != StreamProviderResultStatus.TERMINAL_FAILED
        ) revert ProviderFailureUnproven();
        _terminal(requestKey, subject, StreamEntropyStatus.FAILED);
    }

    function _terminal(bytes32 requestKey, Subject storage subject, StreamEntropyStatus status)
        private
    {
        subject.status = status;
        --pendingRequestCount;
        emit EntropyRequestTerminal(requestKey, status);
        uint256 tokenId = requests[requestKey].tokenId;
        if (tokenId != 0) --nonterminalTokenCount[subject.collectionId];
        if (tokenId != 0) _notify(tokenId, requestKey);
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
        Subject storage subject = _subjects[_tokenKey(tokenId)];
        return (subject.seed, subject.status == StreamEntropyStatus.FINALIZED);
    }

    function tokenEntropyStatus(uint256 tokenId)
        public
        view
        override
        returns (StreamEntropyStatus)
    {
        return _subjects[_tokenKey(tokenId)].status;
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
        Subject storage subject = _subjects[_tokenKey(tokenId)];
        if (subject.requestKey != 0) {
            RequestPolicySnapshot storage policy = _requestPolicies[subject.requestKey];
            return (
                subject.status,
                subject.seed,
                policy.provider,
                policy.providerEpoch,
                policy.providerConfigHash,
                subject.requestKey,
                requests[subject.requestKey].providerRequestId,
                policy.requestAttempt
            );
        }
        CollectionConfig storage config = collectionEntropyConfig[subject.collectionId];
        return (
            subject.status,
            subject.seed,
            config.provider,
            collectionProviderEpoch[subject.collectionId],
            config.providerConfigHash,
            bytes32(0),
            0,
            0
        );
    }

    /// @inheritdoc IStreamEntropyEpochs
    function requestPolicySnapshot(bytes32 requestKey)
        external
        view
        override
        returns (RequestPolicySnapshot memory)
    {
        return _requestPolicies[requestKey];
    }

    function scopeSeed(bytes32 scopeId) external view returns (bytes32 seed, bool finalized) {
        Subject storage subject = _subjects[scopeId];
        return (subject.seed, subject.status == StreamEntropyStatus.FINALIZED);
    }

    function scopeEntropy(bytes32 scopeId) external view returns (Subject memory) {
        return _subjects[scopeId];
    }

    function _tokenKey(uint256 tokenId) private pure returns (bytes32) {
        return keccak256(abi.encode("TOKEN", tokenId));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/IStreamCore.sol";
import "../../interfaces/stream/IStreamEntropyCoordinator.sol";
import "../../interfaces/stream/IStreamEntropyView.sol";
import "../../interfaces/stream/IStreamEntropyProvider.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../modules/StreamModuleBase.sol";

/// @notice Core-bound asynchronous entropy with immutable request inputs and no ordinary reroll.
/// @dev A collection's initial policy locks on its first token or scope registration. Fresh
///      randomness recovery and provider migration require a separate explicit implementation.
contract StreamEntropyCoordinator is
    StreamModuleBase,
    ReentrancyGuard,
    IStreamEntropyCoordinator,
    IStreamEntropyView
{
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

    constructor(
        address core_,
        address authority_,
        bytes32 deploymentManifestHash,
        string memory manifestURI,
        bytes32 manifestHash
    )
        StreamModuleBase(
            keccak256("6529stream.entropy-coordinator.schema.v1"),
            address(0),
            deploymentManifestHash,
            manifestURI,
            manifestHash
        )
    {
        if (core_.code.length == 0 || !IERC165(core_).supportsInterface(0x80ac58cd)) revert InvalidDependency(core_);
        if (authority_ == address(0) || deploymentManifestHash == 0 || manifestHash == 0) {
            revert InvalidDependency(authority_);
        }
        core = IStreamCore(core_);
        authority = authority_;
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
            || id == type(IStreamEntropyView).interfaceId || super.supportsInterface(id);
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
        if (
            provider.code.length == 0 || timeoutBlocks == 0
                || !IERC165(provider).supportsInterface(type(IStreamEntropyProvider).interfaceId)
                || IERC165(provider).supportsInterface(0xffffffff)
        ) revert InvalidDependency(provider);
        bytes32 configHash = IStreamEntropyProvider(provider).streamEntropyProviderConfigHash();
        if (configHash == 0 || !IStreamEntropyProvider(provider).isStreamEntropyProvider()) {
            revert InvalidDependency(provider);
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
        emit CollectionEntropyConfigured(
            collectionId, provider, configHash, collectionSalt, publicRequests, timeoutBlocks
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
        emit EntropyRegistered(collectionId, tokenId, mintCommitment);
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
        if (
            msg.sender != authority && !requesters[msg.sender]
                && !collectionEntropyConfig[subject.collectionId].publicRequests
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
        if (scopeInputsHash == 0) revert InvalidSubject(scopeId);
        _subjects[scopeId].inputsHash = scopeInputsHash;
        return _request(scopeId, 0, scopeId);
    }

    function _lockPolicy(uint256 collectionId) private {
        CollectionConfig storage config = collectionEntropyConfig[collectionId];
        if (config.provider == address(0)) revert InvalidCollection(collectionId);
        config.locked = true;
    }

    function _request(bytes32 subjectKey, uint256 tokenId, bytes32 scopeId)
        private
        returns (bytes32 requestKey, uint256 providerRequestId)
    {
        Subject storage subject = _subjects[subjectKey];
        if (subject.status != StreamEntropyStatus.REGISTERED) revert InvalidStatus(subject.status);
        CollectionConfig storage config = collectionEntropyConfig[subject.collectionId];
        address provider = config.provider;
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
            uint32(1),
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
                    uint32(1),
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
                    uint32(1),
                    config.providerConfigHash,
                    subject.inputsHash,
                    uint16(1)
                )
            );
        }
        uint256 fee = IStreamEntropyProvider(provider).quoteRequest(context);
        if (msg.value < fee) revert InsufficientEntropyFee(fee, msg.value);
        subject.requestKey = requestKey;
        subject.status = StreamEntropyStatus.REQUESTED;
        requests[requestKey] =
            Request(subjectKey, tokenId, scopeId, provider, uint64(block.number), 0, 0);
        ++pendingRequestCount;
        if (msg.value > fee) {
            uint256 excess = msg.value - fee;
            entropyFeeCredit[msg.sender] += excess;
            totalFeeCredits += excess;
            emit EntropyFeeCredited(msg.sender, excess);
        }
        providerRequestId =
            IStreamEntropyProvider(provider).requestEntropy{ value: fee }(requestKey, context);
        if (providerRequestKeys[provider][providerRequestId] != 0) {
            revert ProviderRequestCollision(provider, providerRequestId);
        }
        providerRequestKeys[provider][providerRequestId] = requestKey;
        requests[requestKey].providerRequestId = providerRequestId;
        emit EntropyRequested(requestKey, tokenId, scopeId, provider, providerRequestId);
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
        CollectionConfig storage config = collectionEntropyConfig[subject.collectionId];
        bytes32 seed = _deriveSeed(requestKey, request, subject, config, rawRandomness);
        request.rawRandomness = rawRandomness;
        subject.seed = seed;
        subject.status = StreamEntropyStatus.FINALIZED;
        --pendingRequestCount;
        emit EntropyFinalized(requestKey, request.tokenId, request.scopeId, seed, rawRandomness);
        if (request.tokenId != 0) _notify(request.tokenId, requestKey);
        return 0;
    }

    function _deriveSeed(
        bytes32 requestKey,
        Request storage request,
        Subject storage subject,
        CollectionConfig storage config,
        bytes32 rawRandomness
    ) private view returns (bytes32) {
        SeedInputs memory inputs;
        inputs.domain = request.scopeId == 0 ? SEED_DOMAIN : SCOPE_SEED_DOMAIN;
        inputs.chainId = block.chainid;
        inputs.coordinator = address(this);
        inputs.streamCore = address(core);
        inputs.collectionId = subject.collectionId;
        inputs.identity = request.scopeId == 0 ? bytes32(request.tokenId) : request.scopeId;
        inputs.provider = request.provider;
        inputs.providerEpoch = 1;
        inputs.providerConfigHash = config.providerConfigHash;
        inputs.requestKey = requestKey;
        inputs.providerRequestId = request.providerRequestId;
        inputs.rawRandomness = rawRandomness;
        inputs.collectionSalt = config.collectionSalt;
        inputs.inputsHash = subject.inputsHash;
        return keccak256(abi.encode(inputs));
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

    /// @notice Marks a timed-out request terminal without authorizing a fresh random draw.
    function markRequestStale(bytes32 requestKey) external onlyAuthority nonReentrant {
        Request storage request = requests[requestKey];
        Subject storage subject = _subjects[request.subjectKey];
        if (subject.status != StreamEntropyStatus.REQUESTED) revert InvalidStatus(subject.status);
        if (
            block.number
                <= uint256(request.requestedAtBlock)
                    + collectionEntropyConfig[subject.collectionId].timeoutBlocks
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
        CollectionConfig storage config = collectionEntropyConfig[subject.collectionId];
        return (
            subject.status,
            subject.seed,
            config.provider,
            config.provider == address(0) ? 0 : 1,
            config.providerConfigHash,
            subject.requestKey,
            requests[subject.requestKey].providerRequestId,
            subject.requestKey == 0 ? 0 : 1
        );
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

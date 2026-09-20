// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentHostEvidence.sol";
import "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";

interface IEntropyCollectionPolicyReceiverFixture {
    function onPolicyTokenReceived(uint256 collectionId, uint256 tokenId) external;
}

interface EntropyCollectionPolicyVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
}

/// @notice Typed Core boundary for collection-policy units; no actual Core mint or pointer governance.
contract EntropyCollectionPolicyCoreFixture {
    StreamEntropyCoordinator private _coordinator;
    address private _artist;
    address private _moduleRegistry;
    mapping(uint256 => uint256) public collectionMintedEver;
    mapping(uint256 => uint256) private _collections;
    mapping(uint256 => address) public coordinatorAtMint;
    mapping(uint256 => bool) public collectionFreezeStatus;
    uint256 public metadataNotifications;

    function wire(StreamEntropyCoordinator coordinator, address artist, address registry) external {
        _coordinator = coordinator;
        _artist = artist;
        _moduleRegistry = registry;
    }

    function setArtist(address artist) external {
        _artist = artist;
    }

    function setCoordinator(StreamEntropyCoordinator coordinator) external {
        _coordinator = coordinator;
    }

    function setMintedEver(uint256 id, uint256 count) external {
        collectionMintedEver[id] = count;
    }

    function freezeCollection(uint256 id) external {
        collectionFreezeStatus[id] = true;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd || id == 0x01ffc9a7;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1 || id == 2;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address target;
        bytes4 capability;
        if (kind == keccak256("ENTROPY_COORDINATOR")) {
            target = address(_coordinator);
            capability = type(IStreamEntropyCoordinator).interfaceId;
        } else if (kind == keccak256("ARTIST_REGISTRY")) {
            target = _artist;
            capability = type(IStreamArtistContentHostEvidence).interfaceId;
        } else {
            require(kind == keccak256("MODULE_REGISTRY"), "unknown pointer");
            target = _moduleRegistry;
            capability = type(IStreamModuleRegistry).interfaceId;
        }
        return (target, target.codehash, false, kind, capability, _moduleRegistry, 1, 0, 0, 1);
    }

    function registerToken(uint256 id, uint256 tokenId, bytes32 commitment) external {
        _registerToken(id, tokenId, commitment, address(0xbeef));
    }

    /// @notice Explicit unit ordering seam, not an implementation of actual Core safe minting.
    function registerTokenWithCallback(
        uint256 id,
        uint256 tokenId,
        bytes32 commitment,
        address receiver
    ) external {
        _registerToken(id, tokenId, commitment, receiver);
        IEntropyCollectionPolicyReceiverFixture(receiver).onPolicyTokenReceived(id, tokenId);
    }

    function _registerToken(uint256 id, uint256 tokenId, bytes32 commitment, address recipient)
        private
    {
        _collections[tokenId] = id;
        coordinatorAtMint[tokenId] = address(_coordinator);
        ++collectionMintedEver[id];
        _coordinator.onTokenMinted(id, tokenId, recipient, commitment);
    }

    function tokenCollectionIdentity(uint256 tokenId)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (_collections[tokenId] != 0, _collections[tokenId], tokenId, false);
    }

    function tokenLifecycle(uint256 tokenId) external view returns (uint8) {
        return uint8(
            _collections[tokenId] != 0 ? StreamTokenLifecycle.MINTED : StreamTokenLifecycle.UNKNOWN
        );
    }

    function emitMetadataUpdate(uint256 tokenId, bytes32 reason) external {
        require(
            msg.sender == coordinatorAtMint[tokenId] && _collections[tokenId] != 0 && reason != 0
        );
        ++metadataNotifications;
    }
}

/// @notice Executes observation checks inside the typed Core's delivery callback before accepting/rejecting.
contract EntropyCollectionPolicyReceiverFixture is IEntropyCollectionPolicyReceiverFixture {
    EntropyCollectionPolicyCoreFixture public immutable core;
    StreamEntropyCoordinator public immutable coordinator;
    bytes32 public immutable expectedPolicyHash;
    StreamEntropyStatus public immutable expectedStatus;
    bool public reject = true;
    uint256 public deliveries;

    error PolicyReceiverRejected(bytes32 observedPolicyHash, uint8 observedStatus, uint256 tokenId);

    constructor(
        EntropyCollectionPolicyCoreFixture core_,
        StreamEntropyCoordinator coordinator_,
        bytes32 h,
        StreamEntropyStatus status
    ) {
        core = core_;
        coordinator = coordinator_;
        expectedPolicyHash = h;
        expectedStatus = status;
    }

    function setReject(bool next) external {
        reject = next;
    }

    function onPolicyTokenReceived(uint256 id, uint256 tokenId) external override {
        require(msg.sender == address(core), "typed Core delivery only");
        (bool exists, uint256 actualCollection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(tokenId);
        require(
            exists && actualCollection == id && serial == tokenId && !burned,
            "identity precedes delivery"
        );
        require(
            core.tokenLifecycle(tokenId) == uint8(StreamTokenLifecycle.MINTED),
            "mint lifecycle precedes delivery"
        );
        require(
            core.coordinatorAtMint(tokenId) == address(coordinator),
            "original coordinator precedes delivery"
        );
        IStreamEntropyCollectionPolicy.PolicyRecord memory p =
            IStreamEntropyCollectionPolicy(address(coordinator)).collectionEntropyPolicy(id);
        require(
            p.configured && p.explicitPolicy && p.frozen && p.policyHash == expectedPolicyHash,
            "locked explicit H precedes delivery"
        );
        (uint8 status, bytes32 seed,) = coordinator.staticTokenRenderFacts(tokenId);
        require(
            status == uint8(expectedStatus) && seed == 0, "terminal render facts precede delivery"
        );
        require(
            coordinator.tokenEntropyStatus(tokenId) == expectedStatus,
            "terminal record precedes delivery"
        );
        require(
            coordinator.registeredAtBlock(tokenId) == block.number,
            "registration block precedes delivery"
        );
        require(
            coordinator.nonterminalTokenCount(id) == 0 && coordinator.pendingRequestCount() == 0,
            "terminal counters visible in delivery"
        );
        ++deliveries;
        if (reject) revert PolicyReceiverRejected(p.policyHash, status, tokenId);
    }
}

/// @notice Models an already-recorded original op17 receipt, not Artist signatures or lifecycle.
/// @dev Exact collection/host/family/state keys and caller checks expose the Coordinator's join.
contract EntropyCollectionPolicyArtistFixture {
    address public immutable core;
    bool public bound = true;
    uint256 public readCap = 600000;
    uint256 public readFloor = 100000;
    uint8 public readFailure = 2;
    uint64 public readRevision = 1;
    mapping(bytes32 => bytes32) private _records;

    constructor(address core_) {
        core = core_;
    }

    function setBound(bool next) external {
        bound = next;
    }

    function setReadBudget(uint256 cap, uint256 floor, uint8 failure, uint64 revision) external {
        readCap = cap;
        readFloor = floor;
        readFailure = failure;
        readRevision = revision;
    }

    function approve(uint256 id, address host, bytes32 family, bytes32 state, bytes32 record)
        external
    {
        _records[keccak256(abi.encode(id, host, family, state))] = record;
    }

    function gasParameterInfo(bytes32 id) external view returns (uint256, uint256, uint8, uint64) {
        require(id == keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS"), "wrong Artist cap");
        return (readCap, readFloor, readFailure, readRevision);
    }

    function collectionArtistState(uint256 id)
        external
        view
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        if (!bound) return (0, 0, 0, 0, 0);
        return (2, 1, keccak256("policy Artist"), 1, keccak256(abi.encode("accepted binding", id)));
    }

    function contentConsentEvidenceForHost(uint256 id, address host, bytes32 family, bytes32 state)
        external
        view
        returns (bytes32)
    {
        require(msg.sender == host, "only exact content host");
        return _records[keccak256(abi.encode(id, host, family, state))];
    }
}

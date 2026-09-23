// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./EntropyCollectionPolicyFixtures.sol";
import "../../mocks/MockEntropyRoleRegistry.sol";

interface EntropySuccessorVm {
    function mockCallRevert(address target, bytes calldata data, bytes calldata result) external;
    function clearMockedCalls() external;
}

/// @notice Typed registry eligibility boundary; actual ModuleRegistry governance is outside this unit.
contract EntropySuccessorModuleFixture is MockEntropyModuleRegistry {
    mapping(address => bool) public eligible;

    constructor(address authority) MockEntropyModuleRegistry(authority) { }

    function setEligible(address target, bool value) external {
        eligible[target] = value;
    }

    function isModuleEligible(address target, bytes32 moduleType, bytes4 capability)
        external
        view
        returns (bool)
    {
        return eligible[target] && moduleType == keccak256("ENTROPY_COORDINATOR")
            && capability == type(IStreamEntropyCoordinator).interfaceId;
    }
}

/// @notice Typed Core identity/pointer seam, NOT the actual Core replacement or mint implementation.
/// @dev Tests explicitly choose the pointer revision. Each token retains its original Coordinator.
contract EntropyPolicySuccessorCoreFixture {
    StreamEntropyCoordinator public selected;
    address public artist;
    address public modules;
    uint64 public pointerRevision = 1;
    mapping(uint256 => uint256) private _collection;
    mapping(uint256 => address) public coordinatorAtMint;
    mapping(uint256 => uint256) public collectionMintedEver;
    mapping(uint256 => bool) public collectionFreezeStatus;
    uint256 public metadataNotifications;
    bool public rejectNotification;

    function wire(StreamEntropyCoordinator first, address artist_, address modules_) external {
        selected = first;
        artist = artist_;
        modules = modules_;
    }

    function select(StreamEntropyCoordinator next, uint64 revision) external {
        selected = next;
        pointerRevision = revision;
    }

    function setRejectNotification(bool next) external {
        rejectNotification = next;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd || id == 0x01ffc9a7;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id != 0 && id <= 4;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address target;
        bytes4 capability;
        uint64 revision = 1;
        if (kind == keccak256("ENTROPY_COORDINATOR")) {
            target = address(selected);
            capability = type(IStreamEntropyCoordinator).interfaceId;
            revision = pointerRevision;
        } else if (kind == keccak256("ARTIST_REGISTRY")) {
            target = artist;
            capability = type(IStreamArtistContentHostEvidence).interfaceId;
        } else {
            require(kind == keccak256("MODULE_REGISTRY"), "known fixture pointer");
            target = modules;
            capability = type(IStreamModuleRegistry).interfaceId;
        }
        return (target, target.codehash, false, kind, capability, modules, 1, 0, 0, revision);
    }

    function registerToken(uint256 collectionId, uint256 tokenId, bytes32 commitment) external {
        require(_collection[tokenId] == 0 && tokenId != 0, "fresh fixture token");
        _collection[tokenId] = collectionId;
        coordinatorAtMint[tokenId] = address(selected);
        ++collectionMintedEver[collectionId];
        selected.onTokenMinted(collectionId, tokenId, address(0xbeef), commitment);
    }

    function tokenCollectionIdentity(uint256 tokenId)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (_collection[tokenId] != 0, _collection[tokenId], tokenId, false);
    }

    function tokenLifecycle(uint256 tokenId) external view returns (uint8) {
        return uint8(
            _collection[tokenId] == 0 ? StreamTokenLifecycle.UNKNOWN : StreamTokenLifecycle.MINTED
        );
    }

    function emitMetadataUpdate(uint256 tokenId, bytes32 reason) external {
        require(!rejectNotification, "fixture notification unavailable");
        require(msg.sender == coordinatorAtMint[tokenId] && reason != 0, "original token owner");
        ++metadataNotifications;
    }
}

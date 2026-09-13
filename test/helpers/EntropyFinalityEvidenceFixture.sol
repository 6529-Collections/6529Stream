// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../../smart-contracts/domains/finality/StreamFinalityEntropyEvidenceProvider.sol";

/// @dev Explicit Core/metadata/membership/live-module boundaries. No current-stack claim.
contract EntropyFinalityCoreBoundary {
    mapping(bytes32 => StreamMetadataRecoveryRoutes.Pointer) private _pointers;
    mapping(uint256 => bool) private _tokens;
    StreamEntropyCoordinator public coordinator;

    function setCoordinator(StreamEntropyCoordinator c) external {
        coordinator = c;
    }

    function setPointer(bytes32 key, StreamMetadataRecoveryRoutes.Pointer calldata p) external {
        _pointers[key] = p;
    }

    function getSatellitePointer(bytes32 key)
        external
        view
        returns (StreamMetadataRecoveryRoutes.Pointer memory)
    {
        return _pointers[key];
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd || id == 0x01ffc9a7;
    }

    function collectionExists(uint256 cid) external pure returns (bool) {
        return cid == 1 || cid == 2;
    }

    function collectionFreezeStatus(uint256) external pure returns (bool) {
        return false;
    }

    function registerToken(uint256 id) external {
        _tokens[id] = true;
        coordinator.onTokenMinted(1, id, address(0xbeef), keccak256(abi.encode("mint", id)));
    }

    function tokenCollectionIdentity(uint256 id)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (_tokens[id], 1, id, false);
    }

    function coordinatorAtMint(uint256 id) external view returns (address) {
        return _tokens[id] ? address(coordinator) : address(0);
    }

    function tokenLifecycle(uint256 id) external view returns (uint8) {
        return uint8(_tokens[id] ? StreamTokenLifecycle.MINTED : StreamTokenLifecycle.UNKNOWN);
    }

    function emitMetadataUpdate(uint256, bytes32) external view {
        require(msg.sender == address(coordinator));
    }
}

contract EntropyFinalityMetadataBoundary {
    address public immutable core;

    constructor(address c) {
        core = c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamCollectionMetadataV1).interfaceId;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("COLLECTION_METADATA");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamCollectionMetadataV1).interfaceId;
    }
}

contract EntropyFinalityMembershipBoundary {
    address public immutable core;
    address public immutable metadataHost;
    uint8 public fault;

    constructor(address c, address m) {
        core = c;
        metadataHost = m;
    }

    function setFault(uint8 value) external {
        fault = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamFinalityScopeMembership).interfaceId;
    }

    function requireScopeMembership(StreamFinalityScope calldata scope)
        external
        view
        returns (StreamScopeMembershipFacts memory f)
    {
        require(fault != 1, "membership unavailable");
        if (fault == 2) assembly ("memory-safe") { return(0, 255) }
        f.scopeSubject = fault == 3
            ? bytes32(0)
            : StreamMetadataSubjects.scopeSubject(block.chainid, core, scope);
        f.membershipHash = fault == 4 ? bytes32(0) : keccak256(abi.encode(scope));
        f.tokenCount = 1;
    }
}

contract EntropyFinalityModuleBoundary {
    address public immutable governanceExecutor;
    bool public eligible = true;

    constructor(address e) {
        governanceExecutor = e;
    }

    function setEligible(bool value) external {
        eligible = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamModuleRegistry).interfaceId;
    }

    function isModuleEligible(address, bytes32, bytes4) external view returns (bool) {
        return eligible;
    }
}

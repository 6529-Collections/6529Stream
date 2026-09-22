// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamCollectionMetadataV1
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    GovernanceAction,
    GovernanceActionStatus
} from "../../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";

contract MetadataExecutorBoundary {
    bool private active;
    bytes32 private scope;
    bytes32 private oldHash;
    bytes32 private newHash;
    address public root;
    bytes32 private rootCodeHash;
    uint64 private rootRevision = 1;
    address private proposer;
    GovernanceActionStatus private storedStatus = GovernanceActionStatus.EXECUTED;
    string private reasonURI;

    constructor() {
        root = msg.sender;
        rootCodeHash = msg.sender.codehash;
        proposer = msg.sender;
    }

    function setRoot(address account) external {
        root = account;
        rootCodeHash = account.codehash;
        ++rootRevision;
    }

    function setProposer(address account) external {
        proposer = account;
    }

    function setReasonURI(string memory value) external {
        reasonURI = value;
    }

    function setStoredStatus(GovernanceActionStatus value) external {
        storedStatus = value;
    }

    function governanceRootState() external view returns (address, bytes32, uint64) {
        return (root, rootCodeHash, rootRevision);
    }

    function governanceAction(bytes32) external view returns (GovernanceAction memory a) {
        a.status = storedStatus;
        a.actionClass = 1;
        // Deliberately represent another first batch target, not the metadata call.
        a.target = address(0xbeef);
        a.selector = 0x11223344;
        a.proposer = proposer;
        a.reasonURI = reasonURI;
    }

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return active
            ? (true, bytes32(uint256(1)), uint8(1), scope, oldHash, newHash)
            : (false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0));
    }

    function execute(address target, bytes memory data, bytes32 s, bytes32 o, bytes32 n)
        external
        returns (bytes memory result)
    {
        active = true;
        scope = s;
        oldHash = o;
        newHash = n;
        (bool ok, bytes memory output) = target.call(data);
        if (!ok) assembly { revert(add(output, 32), mload(output)) }
        active = false;
        scope = 0;
        oldHash = 0;
        newHash = 0;
        return output;
    }
}

/// @dev Explicit current-Core and governance boundaries. Real Core/Executor composition is separate.
contract MetadataCoreBoundary {
    mapping(bytes32 => address) public selected;
    mapping(uint256 => address) public owners;
    mapping(uint256 => uint8) public lifecycles;
    mapping(uint256 => uint256) private portableSerials;
    mapping(bytes32 => address) private portablePointerTargets;
    mapping(bytes32 => bytes32) private portablePointerCodeHashes;
    mapping(bytes32 => address) private portableModuleRegistries;
    mapping(bytes32 => bytes4) private portableCapabilities;
    mapping(bytes32 => bool) private portablePointers;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd || id == 0x01ffc9a7;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1 || id == 2;
    }

    function setPointer(bytes32 kind, address target) external {
        selected[kind] = target;
    }

    function setPortablePointer(bytes32 kind, address target, bytes4 capability, address modules)
        external
    {
        portablePointerTargets[kind] = target;
        portablePointerCodeHashes[kind] = target.codehash;
        portableCapabilities[kind] = capability;
        portableModuleRegistries[kind] = modules;
        portablePointers[kind] = true;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address target = portablePointers[kind] ? portablePointerTargets[kind] : selected[kind];
        if (portablePointers[kind]) {
            return (
                target,
                portablePointerCodeHashes[kind],
                false,
                kind,
                portableCapabilities[kind],
                portableModuleRegistries[kind],
                1,
                keccak256("typed module manifest"),
                keccak256("typed deployment"),
                1
            );
        }
        return (
            target,
            target.codehash,
            false,
            kind,
            type(IStreamCollectionMetadataV1).interfaceId,
            address(this),
            1,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            1
        );
    }

    function setToken(uint256 id, address owner, uint8 lifecycle) external {
        owners[id] = owner;
        lifecycles[id] = lifecycle;
    }

    function setPortableTokenSerial(uint256 id, uint256 serial) external {
        portableSerials[id] = serial;
    }

    function tokenCollectionIdentity(uint256 id)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        uint256 serial = portableSerials[id];
        return (lifecycles[id] != 0, 1, serial == 0 ? id : serial, lifecycles[id] == 3);
    }

    function tokenLifecycle(uint256 id) external view returns (uint8) {
        return lifecycles[id];
    }

    function ownerOf(uint256 id) external view returns (address) {
        require(lifecycles[id] == 2, "not live");
        return owners[id];
    }
}

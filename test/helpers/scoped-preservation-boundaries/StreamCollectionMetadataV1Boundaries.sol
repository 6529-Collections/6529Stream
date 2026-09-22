// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

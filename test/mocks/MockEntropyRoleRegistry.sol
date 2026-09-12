// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";

/// @notice Explicit role-resolution boundary for isolated entropy tests, not governance evidence.
contract MockEntropyRoleRegistry {
    address public immutable owner;
    mapping(bytes32 => address) private _holders;

    constructor(address administrator) {
        owner = administrator;
        _holders[keccak256("ROLE_ENTROPY_ADMIN")] = administrator;
        _holders[keccak256("ROLE_ENTROPY_REVEAL_OWNER")] = administrator;
        _holders[keccak256("ROLE_TREASURY")] = administrator;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamRoleRegistry).interfaceId || id == 0x01ffc9a7;
    }

    function setHolder(bytes32 role, address holder) external {
        _holders[role] = holder;
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return account != address(0) && _holders[role] == account;
    }

    function resolveRole(bytes32 role) external view returns (address holder) {
        holder = _holders[role];
        if (holder == address(0)) revert IStreamRoleRegistry.RoleUnresolved(role);
    }
}

/// @notice Immutable canonical-governance read boundary for the small subject fixture.
contract MockEntropyModuleRegistry {
    address public immutable governanceExecutor;

    constructor(address executor) {
        governanceExecutor = executor;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamModuleRegistry).interfaceId || id == 0x01ffc9a7;
    }
}

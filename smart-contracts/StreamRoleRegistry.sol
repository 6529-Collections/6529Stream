// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamRoleRegistry.sol";
import "./Ownable.sol";
import "./StreamRoles.sol";

/// @notice Admin registry resolving the ADR 0004 [GOV-ROLES] `ROLE_*`
///         vocabulary to current holders.
/// @dev The owner is `GovernanceRoot`. Root-class roles are granted and
///     revoked only by the owner; operational-class roles are also grantable
///     by registered role managers. The vocabulary is closed-world: grants
///     against constants outside the pinned [GOV-ROLES] table revert. Holder
///     sets are enumerable so redundancy gates and deployment checks can prove
///     the active authority graph from state reads alone.
contract StreamRoleRegistry is Ownable, IStreamRoleRegistry {
    /// @notice Schema version carried by role lifecycle events.
    uint16 public constant SCHEMA_VERSION = 1;

    mapping(address => bool) private _roleManagers;
    mapping(bytes32 => address[]) private _roleHolders;
    // holder => (index + 1) into _roleHolders[role]; zero means not a holder.
    mapping(bytes32 => mapping(address => uint256)) private _roleHolderIndex;

    /// @inheritdoc IStreamRoleRegistry
    function grantRole(bytes32 role, address holder) external override {
        _checkRoleActor(role);
        if (holder == address(0)) {
            revert ZeroRoleHolder(role);
        }
        if (_roleHolderIndex[role][holder] != 0) {
            revert RoleAlreadyGranted(role, holder);
        }
        _checkDisjointness(role, holder);
        _roleHolders[role].push(holder);
        _roleHolderIndex[role][holder] = _roleHolders[role].length;
        emit StreamRoleGranted(SCHEMA_VERSION, role, holder, _grantClass(role), msg.sender);
    }

    /// @inheritdoc IStreamRoleRegistry
    function revokeRole(bytes32 role, address holder) external override {
        _checkRoleActor(role);
        uint256 indexPlusOne = _roleHolderIndex[role][holder];
        if (indexPlusOne == 0) {
            revert RoleNotGranted(role, holder);
        }
        address[] storage holders = _roleHolders[role];
        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = holders.length - 1;
        if (index != lastIndex) {
            address moved = holders[lastIndex];
            holders[index] = moved;
            _roleHolderIndex[role][moved] = indexPlusOne;
        }
        holders.pop();
        delete _roleHolderIndex[role][holder];
        emit StreamRoleRevoked(SCHEMA_VERSION, role, holder, _grantClass(role), msg.sender);
    }

    /// @notice Registers or removes an operational-role manager.
    function registerRoleManager(address account, bool enabled) external onlyOwner {
        if (account == address(0)) {
            revert ZeroRoleHolder(bytes32(0));
        }
        _roleManagers[account] = enabled;
        emit RoleManagerUpdated(account, enabled, msg.sender);
    }

    /// @inheritdoc IStreamRoleRegistry
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roleHolderIndex[role][account] != 0;
    }

    /// @inheritdoc IStreamRoleRegistry
    function roleHolderCount(bytes32 role) public view override returns (uint256) {
        return _roleHolders[role].length;
    }

    /// @inheritdoc IStreamRoleRegistry
    function roleHolderAt(bytes32 role, uint256 index) public view override returns (address) {
        if (index >= _roleHolders[role].length) {
            revert RoleHolderIndexOutOfBounds(role, index);
        }
        return _roleHolders[role][index];
    }

    /// @inheritdoc IStreamRoleRegistry
    function resolveRole(bytes32 role) public view override returns (address holder) {
        uint256 count = _roleHolders[role].length;
        if (count == 0) {
            revert RoleUnresolved(role);
        }
        if (count > 1) {
            revert AmbiguousRoleResolution(role, count);
        }
        return _roleHolders[role][0];
    }

    /// @inheritdoc IStreamRoleRegistry
    function emergencyRecipient() external view override returns (address) {
        return resolveRole(StreamRoles.ROLE_EMERGENCY_RECIPIENT);
    }

    /// @inheritdoc IStreamRoleRegistry
    function roleGrantClass(bytes32 role) public pure override returns (uint8) {
        uint8 grantClass = _grantClassOrZero(role);
        if (grantClass == 0) {
            revert UnknownRole(role);
        }
        return grantClass;
    }

    /// @inheritdoc IStreamRoleRegistry
    function isKnownRole(bytes32 role) public pure override returns (bool) {
        return _grantClassOrZero(role) != 0;
    }

    /// @inheritdoc IStreamRoleRegistry
    function roleRedundancy(bytes32 role)
        public
        view
        override
        returns (uint256 holderCount, uint256 contractHolderCount)
    {
        address[] storage holders = _roleHolders[role];
        holderCount = holders.length;
        for (uint256 i = 0; i < holderCount; i++) {
            if (holders[i].code.length > 0) {
                contractHolderCount++;
            }
        }
    }

    /// @inheritdoc IStreamRoleRegistry
    function isRoleRedundant(bytes32 role) external view override returns (bool) {
        (uint256 holderCount, uint256 contractHolderCount) = roleRedundancy(role);
        return holderCount >= 2 && contractHolderCount == holderCount;
    }

    /// @inheritdoc IStreamRoleRegistry
    function isRoleManager(address account) external view override returns (bool) {
        return _roleManagers[account];
    }

    function _checkRoleActor(bytes32 role) private view {
        uint8 grantClass = roleGrantClass(role);
        if (msg.sender == owner()) {
            return;
        }
        if (grantClass == StreamRoles.GRANT_CLASS_OPERATIONAL && _roleManagers[msg.sender]) {
            return;
        }
        revert RoleActorNotAuthorized(role, msg.sender);
    }

    /// @dev [GOV-WINDOWS] rule 3: pause guardians cannot unpause and unpause
    ///     holders cannot pause; one account may never hold both authorities.
    function _checkDisjointness(bytes32 role, address holder) private view {
        if (role == StreamRoles.ROLE_PAUSE_GUARDIAN && hasRole(StreamRoles.ROLE_UNPAUSE, holder)) {
            revert DisjointRoleConflict(role, StreamRoles.ROLE_UNPAUSE, holder);
        }
        if (role == StreamRoles.ROLE_UNPAUSE && hasRole(StreamRoles.ROLE_PAUSE_GUARDIAN, holder)) {
            revert DisjointRoleConflict(role, StreamRoles.ROLE_PAUSE_GUARDIAN, holder);
        }
    }

    function _grantClass(bytes32 role) private pure returns (uint8) {
        return _grantClassOrZero(role);
    }

    function _grantClassOrZero(bytes32 role) private pure returns (uint8) {
        if (
            role == StreamRoles.ROLE_PAUSE_GUARDIAN || role == StreamRoles.ROLE_UNPAUSE
                || role == StreamRoles.ROLE_COLLECTION_FINALITY_ADMIN
                || role == StreamRoles.ROLE_TERMINAL_FREEZE_VETO
                || role == StreamRoles.ROLE_ATTRIBUTION_ARBITER
                || role == StreamRoles.ROLE_ARTIST_DORMANCY_ADMIN
                || role == StreamRoles.ROLE_ATTRIBUTION_APPEAL
                || role == StreamRoles.ROLE_EMERGENCY_RECIPIENT || role == StreamRoles.ROLE_TREASURY
        ) {
            return StreamRoles.GRANT_CLASS_ROOT;
        }
        if (
            role == StreamRoles.ROLE_ENTROPY_INCIDENT_DECLARER
                || role == StreamRoles.ROLE_ENTROPY_REVEAL_OWNER
                || role == StreamRoles.ROLE_ARTIST_REGISTRY_ADMIN
                || role == StreamRoles.ROLE_FIXITY_OPERATOR
                || role == StreamRoles.ROLE_EXPORT_PUBLISHER
                || role == StreamRoles.ROLE_CLAIM_ROUTER_OPERATOR
                || role == StreamRoles.ROLE_ENTROPY_ADMIN
        ) {
            return StreamRoles.GRANT_CLASS_OPERATIONAL;
        }
        return 0;
    }
}

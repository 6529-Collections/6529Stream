// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Role-resolution registry for the ADR 0004 [GOV-ROLES] vocabulary.
/// @dev Long-lived authorities are `bytes32` role references resolved through
///     this registry at call time, never raw stored addresses (ADR 0013
///     decision U5). Root-class roles are granted and revoked only by
///     `GovernanceRoot` (the registry owner); operational-class roles are also
///     grantable by registered role managers. Role-redundancy semantics for
///     the [GOV-WINDOWS] rule 2 emergency assumption are exposed as views so
///     conformance-matrix gates can verify them onchain.
interface IStreamRoleRegistry {
    /// @notice Reverts when a role constant is outside the pinned [GOV-ROLES] vocabulary.
    error UnknownRole(bytes32 role);
    /// @notice Reverts when the caller may not grant or revoke the role class.
    error RoleActorNotAuthorized(bytes32 role, address actor);
    /// @notice Reverts when granting a role the holder already has.
    error RoleAlreadyGranted(bytes32 role, address holder);
    /// @notice Reverts when revoking a role the holder does not have.
    error RoleNotGranted(bytes32 role, address holder);
    /// @notice Reverts on zero-address holders and role managers.
    error ZeroRoleHolder(bytes32 role);
    /// @notice Reverts when resolving a role with no current holder.
    error RoleUnresolved(bytes32 role);
    /// @notice Reverts when single-address resolution meets multiple holders.
    error AmbiguousRoleResolution(bytes32 role, uint256 holderCount);
    /// @notice Reverts when a grant would violate a pinned role-disjointness rule
    ///         ([GOV-WINDOWS] rule 3: pause guardians cannot unpause and
    ///         unpause holders cannot pause).
    error DisjointRoleConflict(bytes32 role, bytes32 conflictingRole, address holder);
    /// @notice Reverts when a holder enumeration index is out of bounds.
    error RoleHolderIndexOutOfBounds(bytes32 role, uint256 index);

    event StreamRoleGranted(
        uint16 schemaVersion,
        bytes32 indexed role,
        address indexed holder,
        uint8 grantClass,
        address indexed actor
    );

    event StreamRoleRevoked(
        uint16 schemaVersion,
        bytes32 indexed role,
        address indexed holder,
        uint8 grantClass,
        address indexed actor
    );

    event RoleManagerUpdated(address indexed account, bool enabled, address indexed admin);

    /// @notice Grants `role` to `holder` under the role's grant class rules.
    function grantRole(bytes32 role, address holder) external;

    /// @notice Revokes `role` from `holder` under the role's grant class rules.
    function revokeRole(bytes32 role, address holder) external;

    /// @notice Returns true when `account` currently holds `role`.
    function hasRole(bytes32 role, address account) external view returns (bool);

    /// @notice Returns the number of current holders of `role`.
    function roleHolderCount(bytes32 role) external view returns (uint256);

    /// @notice Returns the holder of `role` at `index` (unordered enumeration).
    function roleHolderAt(bytes32 role, uint256 index) external view returns (address);

    /// @notice Resolves `role` to its single current holder; reverts when the
    ///         role has zero or multiple holders.
    function resolveRole(bytes32 role) external view returns (address holder);

    /// @notice Resolves `ROLE_EMERGENCY_RECIPIENT` through the registry.
    /// @dev Never a stored raw address (ADR 0004 [GOV-ROLES]; ADR 0013 decision U5).
    function emergencyRecipient() external view returns (address);

    /// @notice Returns the pinned grant class for `role`
    ///         (1 = root, 2 = operational); reverts for unknown roles.
    function roleGrantClass(bytes32 role) external pure returns (uint8);

    /// @notice Returns true when `role` is in the pinned [GOV-ROLES] vocabulary.
    function isKnownRole(bytes32 role) external pure returns (bool);

    /// @notice Returns the holder count and the count of holders with deployed
    ///         code observed at call time, for [GOV-WINDOWS] rule 2 redundancy gates.
    function roleRedundancy(bytes32 role)
        external
        view
        returns (uint256 holderCount, uint256 contractHolderCount);

    /// @notice Returns true when `role` satisfies the [GOV-WINDOWS] rule 2
    ///         emergency-holder floor: at least two holders, all of which
    ///         expose deployed code at observation time (no single-signer EOA).
    function isRoleRedundant(bytes32 role) external view returns (bool);

    /// @notice Returns true when `account` is a registered role manager.
    function isRoleManager(address account) external view returns (bool);
}

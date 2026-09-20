// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Append-only configured-policy IDs and ultimate origins in the calling Coordinator.
/// @dev The digest commits to ordered IDs, not current policy contents. Host hooks must call
/// recordLocal only for an actual local configuration and touch only for an actual record change.
library StreamEntropyPolicyInventory {
    bytes32 private constant SLOT = keccak256("6529STREAM_ENTROPY_POLICY_INVENTORY_STORAGE_V1");
    bytes32 internal constant INITIAL_ID_DIGEST =
        keccak256("6529STREAM_ENTROPY_POLICY_INVENTORY_IDS_INITIAL_V1");
    bytes32 internal constant APPEND_ID_DOMAIN =
        keccak256("6529STREAM_ENTROPY_POLICY_INVENTORY_IDS_APPEND_V1");

    struct Origin {
        address origin;
        bytes32 codeHash;
    }

    struct Header {
        uint256 count;
        uint64 serial;
        bytes32 idDigest;
    }

    struct Store {
        uint256[] ids;
        mapping(uint256 => bool) inventoried;
        mapping(uint256 => Origin) origins;
        uint64 serial;
        bytes32 idDigest;
    }

    error PolicyInventoryIndexOutOfBounds(uint256 index);
    error UnknownPolicyInventoryCollection(uint256 collectionId);
    error PolicyInventoryAlreadyRegistered(uint256 collectionId);
    error InvalidPolicyInventoryOrigin(address origin, bytes32 codeHash);
    error PolicyInventorySerialOverflow();

    function store() internal pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function header() internal view returns (Header memory h) {
        Store storage s = store();
        h.count = s.ids.length;
        h.serial = s.serial;
        h.idDigest = h.count == 0 ? INITIAL_ID_DIGEST : s.idDigest;
    }

    function count() internal view returns (uint256) {
        return store().ids.length;
    }

    function at(uint256 index) internal view returns (uint256) {
        Store storage s = store();
        if (index >= s.ids.length) revert PolicyInventoryIndexOutOfBounds(index);
        return s.ids[index];
    }

    /// @notice Returns the recorded pin without requiring the original runtime to remain live.
    /// @dev Unknown IDs never infer an origin from the current host or legacy policy state.
    function origin(uint256 collectionId) internal view returns (address, bytes32) {
        Store storage s = store();
        if (!s.inventoried[collectionId]) revert UnknownPolicyInventoryCollection(collectionId);
        Origin storage o = s.origins[collectionId];
        return (o.origin, o.codeHash);
    }

    /// @notice A new local policy is authored here, including replacement of an imported policy.
    function recordLocal(uint256 collectionId) internal {
        Store storage s = store();
        _advance(s);
        if (!s.inventoried[collectionId]) _append(s, collectionId);
        s.origins[collectionId] = Origin(address(this), address(this).codehash);
    }

    /// @notice Freeze, first lock and fee changes invalidate exports while retaining policy origin.
    function touch(uint256 collectionId) internal {
        Store storage s = store();
        if (!s.inventoried[collectionId]) revert UnknownPolicyInventoryCollection(collectionId);
        _advance(s);
    }

    /// @notice Final import application retains the exact ultimate origin, never the relay host.
    /// @dev Validates only account code facts; no provider, Artist or origin function is called.
    function installImported(uint256 collectionId, address policyOrigin, bytes32 codeHash)
        internal
    {
        Store storage s = store();
        if (s.inventoried[collectionId]) revert PolicyInventoryAlreadyRegistered(collectionId);
        if (
            policyOrigin == address(0) || codeHash == 0 || policyOrigin.code.length == 0
                || policyOrigin.codehash != codeHash
        ) {
            revert InvalidPolicyInventoryOrigin(policyOrigin, codeHash);
        }
        _advance(s);
        _append(s, collectionId);
        s.origins[collectionId] = Origin(policyOrigin, codeHash);
    }

    function _advance(Store storage s) private {
        if (s.serial == type(uint64).max) revert PolicyInventorySerialOverflow();
        ++s.serial;
    }

    function _append(Store storage s, uint256 collectionId) private {
        uint256 index = s.ids.length;
        bytes32 previous = index == 0 ? INITIAL_ID_DIGEST : s.idDigest;
        s.idDigest = keccak256(abi.encode(APPEND_ID_DOMAIN, previous, index, collectionId));
        s.ids.push(collectionId);
        s.inventoried[collectionId] = true;
    }
}

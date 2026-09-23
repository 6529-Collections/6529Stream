// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistGuardianAppealTypes as A
} from "../../interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import { IStreamRoleRegistry } from "../../interfaces/stream/governance/IStreamRoleRegistry.sol";

/// @notice Restricted APPEAL authority: the canonical root controls the actual ARBITER role owner.
/// @dev This is root-mediated role administration, not a generic delegated role-admin claim.
library StreamArtistGuardianAppealAuthority {
    function current(address executor, address roles) public view returns (A.Authority memory a) {
        if (executor.code.length == 0 || roles.code.length == 0) {
            revert A.GuardianAppealDependencyChanged(executor);
        }
        a.executor = executor;
        a.roles = roles;
        if (
            _address(executor, abi.encodeWithSignature("roleRegistry()")) != roles
                || _address(roles, abi.encodeWithSignature("owner()")) != executor
        ) {
            revert A.GuardianAppealDependencyChanged(roles);
        }
        (a.root, a.rootCodeHash, a.rootRevision) = abi.decode(
            _fixed(executor, abi.encodeWithSignature("governanceRootState()"), 96),
            (address, bytes32, uint64)
        );
        if (
            a.root == address(0) || a.root.code.length == 0 || a.rootCodeHash == 0
                || a.root.codehash != a.rootCodeHash || a.rootRevision == 0
                || _address(executor, abi.encodeWithSignature("owner()")) != a.root
        ) {
            revert A.GuardianAppealDependencyChanged(a.root);
        }
        if (!abi.decode(
                _fixed(roles, abi.encodeCall(IStreamRoleRegistry.hasRole, (A.APPEAL, a.root)), 32),
                (bool)
            )) {
            revert A.InvalidGuardianAppeal(bytes32(0));
        }
        (a.roleMutationHash, a.roleRevision) = abi.decode(
            _fixed(roles, abi.encodeCall(IStreamRoleRegistry.roleMutationState, (A.APPEAL)), 64),
            (bytes32, uint64)
        );
        if (a.roleMutationHash == 0 || a.roleRevision == 0) {
            revert A.InvalidGuardianAppeal(bytes32(0));
        }
    }

    function requireProposer(address executor, address roles, address proposer)
        public
        view
        returns (bytes32 mutation, uint64 revision)
    {
        A.Authority memory a = current(executor, roles);
        if (proposer != a.root) revert A.InvalidGuardianAppeal(bytes32(0));
        return (a.roleMutationHash, a.roleRevision);
    }

    function _address(address target, bytes memory data) private view returns (address) {
        return abi.decode(_fixed(target, data, 32), (address));
    }

    function _fixed(address target, bytes memory data, uint256 length)
        private
        view
        returns (bytes memory result)
    {
        result = new bytes(length);
        if (gasleft() < 20_000) revert A.GuardianAppealDependencyChanged(target);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(
                sub(gas(), 10000),
                target,
                add(data, 32),
                mload(data),
                add(result, 32),
                length
            )
            size := returndatasize()
        }
        if (!ok || size != length) revert A.GuardianAppealDependencyChanged(target);
    }
}

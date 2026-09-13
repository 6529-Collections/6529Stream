// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import "../../interfaces/stream/governance/IStreamGovernanceReads.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";

/// @notice Bounded canonical Executor/arbiter witness shared by filing and dismissal.
library StreamArtistGovernanceWitness {
    /// @notice AA-ESTATE accelerator is class1 with the same stored evidence hash.
    /// @dev No arbiter role is required by this distinct action. Per-call context supports batches.
    function readEstateAcceleration(
        address authority,
        bytes32 evidenceHash,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) public view returns (Contest.GovernanceWitness memory g) {
        bool executing;
        (executing, g.actionId, g.actionClass, g.scopeHash, g.oldValueHash, g.newValueHash) =
            abi.decode(
                _fixed(authority, abi.encodeCall(IStreamGovernanceReads.currentAction, ()), 192),
                (bool, bytes32, uint8, bytes32, bytes32, bytes32)
            );
        if (
            !executing || g.actionId == bytes32(0) || g.actionClass != 1 || g.scopeHash != scope
                || g.oldValueHash != oldHash || g.newValueHash != newHash
        ) {
            revert Contest.InvalidContestGovernance();
        }
        (bytes memory header, uint256 size) = _read(
            authority, abi.encodeCall(IStreamGovernanceReads.governanceAction, (g.actionId)), 640
        );
        uint256 uriLength = _word(header, 19);
        if (
            size < 640 || _word(header, 0) != 32 || _word(header, 17) != 576
                || uriLength > size - 640 || size % 32 != 0 || size - 640 - uriLength > 31
                || _word(header, 1) != uint256(GovernanceActionStatus.EXECUTED)
                || _word(header, 2) != 1 || _word(header, 3) >> 160 != 0
                || _word(header, 5) << 32 != 0 || _word(header, 10) > type(uint64).max
                || _word(header, 11) > type(uint64).max || _word(header, 12) >> 160 != 0
                || _word(header, 13) >> 160 != 0 || _word(header, 14) >> 160 != 0
                || _word(header, 15) >> 160 != 0 || bytes32(_word(header, 16)) != evidenceHash
                || evidenceHash == bytes32(0)
        ) revert Contest.InvalidContestGovernance();
        g.proposer = address(uint160(_word(header, 12)));
        if (g.proposer == address(0)) revert Contest.InvalidContestGovernance();
    }

    function read(
        D.CoordinatorContext memory x,
        address authority,
        bytes32 reasonHash,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) public view returns (Contest.GovernanceWitness memory g) {
        address roles = abi.decode(
            _fixed(authority, abi.encodeWithSignature("roleRegistry()"), 32), (address)
        );
        if (roles != x.suite.roleRegistry) revert Contest.InvalidContestGovernance();
        bool executing;
        (executing, g.actionId, g.actionClass, g.scopeHash, g.oldValueHash, g.newValueHash) =
            abi.decode(
                _fixed(authority, abi.encodeCall(IStreamGovernanceReads.currentAction, ()), 192),
                (bool, bytes32, uint8, bytes32, bytes32, bytes32)
            );

        if (
            !executing || g.actionId == bytes32(0) || (g.actionClass != 1 && g.actionClass != 2)
                || g.scopeHash != scope || g.oldValueHash != oldHash || g.newValueHash != newHash
        ) {
            revert Contest.InvalidContestGovernance();
        }
        // governanceAction is one dynamic tuple, not a flat fixed-size result.
        (bytes memory header, uint256 size) = _read(
            authority, abi.encodeCall(IStreamGovernanceReads.governanceAction, (g.actionId)), 640
        );
        uint256 uriLength = _word(header, 19);
        if (
            size < 640 || _word(header, 0) != 32 || _word(header, 17) != 576
                || uriLength > size - 640 || size % 32 != 0 || size - 640 - uriLength > 31
                || _word(header, 1) != uint256(GovernanceActionStatus.EXECUTED)
                || _word(header, 2) != g.actionClass || _word(header, 3) >> 160 != 0
                || _word(header, 5) << 32 != 0 || _word(header, 10) > type(uint64).max
                || _word(header, 11) > type(uint64).max || _word(header, 12) >> 160 != 0
                || _word(header, 13) >> 160 != 0 || _word(header, 14) >> 160 != 0
                || _word(header, 15) >> 160 != 0 || bytes32(_word(header, 16)) != reasonHash
        ) {
            revert Contest.InvalidContestGovernance();
        }
        g.proposer = address(uint160(_word(header, 12)));
        bytes32 role = keccak256("ROLE_ATTRIBUTION_ARBITER");
        if (
            g.proposer == address(0)
                || !abi.decode(
                    _fixed(
                        roles, abi.encodeCall(IStreamRoleRegistry.hasRole, (role, g.proposer)), 32
                    ),
                    (bool)
                )
        ) {
            revert T.Unauthorized(g.proposer);
        }
        (g.roleMutationHash, g.roleRevision) = abi.decode(
            _fixed(roles, abi.encodeCall(IStreamRoleRegistry.roleMutationState, (role)), 64),
            (bytes32, uint64)
        );
        if (g.roleMutationHash == bytes32(0) || g.roleRevision == 0) {
            revert Contest.InvalidContestGovernance();
        }
    }

    function _word(bytes memory data, uint256 index) private pure returns (uint256 word) {
        assembly ("memory-safe") { word := mload(add(add(data, 32), mul(index, 32))) }
    }

    function _fixed(address target, bytes memory data, uint256 length)
        private
        view
        returns (bytes memory result)
    {
        uint256 size;
        (result, size) = _read(target, data, length);
        if (size != length) revert Contest.InvalidContestGovernance();
    }

    /// @dev Canonical immutable Executor/RoleRegistry only. Copy bounded headers even for dynamic URI data.
    function _read(address target, bytes memory data, uint256 length)
        private
        view
        returns (bytes memory result, uint256 size)
    {
        result = new bytes(length);
        bool ok;
        if (gasleft() < 20_000) revert Contest.InvalidContestGovernance();
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
        if (!ok || size < length) revert Contest.InvalidContestGovernance();
    }
}

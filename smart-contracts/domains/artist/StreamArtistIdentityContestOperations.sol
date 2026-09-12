// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import "../../interfaces/stream/governance/IStreamGovernanceReads.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";

/// @notice Fixed operation-33 recipe in the authenticated, locked Coordinator context.
library StreamArtistIdentityContestOperations {
    function file(D.CoordinatorContext memory x, address actor, Contest.Request memory p)
        public
        returns (bytes32 record)
    {
        IStreamArtistIdentityContestOwner owner =
            IStreamArtistIdentityContestOwner(x.suite.owners[2]);
        T.Snapshot[7] memory before_;
        before_[2] = IStreamArtistOwner(address(owner)).ownerStateSnapshotV2();
        Contest.GovernanceWitness memory governance;
        if (actor == owner.artistWindowAuthority()) {
            governance = _governance(x, actor, p, owner);
        }
        record = owner.contestIdentity(T.ActionContext(33, actor, before_[2]), p, governance);
        T.Snapshot[7] memory after_;
        after_[2] = IStreamArtistOwner(address(owner)).ownerStateSnapshotV2();
        bytes memory payload = abi.encode(
            p,
            governance,
            owner.identityContestRecord(record),
            IStreamArtistSuccessionOwner(address(owner)).operativeSuccessorRecord(p.artistId)
        );
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(33),
                actor,
                record
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1), x.configurationHash, uint16(33), actor, record, before_, after_, payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }

    function _governance(
        D.CoordinatorContext memory x,
        address authority,
        Contest.Request memory p,
        IStreamArtistIdentityContestOwner owner
    ) private view returns (Contest.GovernanceWitness memory g) {
        address roles =
            abi.decode(_fixed(authority, abi.encodeWithSignature("roleRegistry()"), 32), (address));
        if (roles != x.suite.roleRegistry) revert Contest.InvalidContestGovernance();
        bool executing;
        (executing, g.actionId, g.actionClass, g.scopeHash, g.oldValueHash, g.newValueHash) =
            abi.decode(
                _fixed(authority, abi.encodeCall(IStreamGovernanceReads.currentAction, ()), 192),
                (bool, bytes32, uint8, bytes32, bytes32, bytes32)
            );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = owner.identityContestContext(p);
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
                || _word(header, 15) >> 160 != 0 || bytes32(_word(header, 16)) != p.reasonHash
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

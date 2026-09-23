// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Fixed original Identity source validation stage.
library StreamArtistRecoveredIdentitySourceActions {
    bytes32 private constant PREPARATION =
        keccak256("identity_authority.replay.recovery_preparation");

    function validate(IH.Bundle calldata b, RH.OwnerProvenance calldata p) public pure {
        for (uint256 i; i < b.actions.length; ++i) {
            IH.ActionRow calldata r = b.actions[i];
            bytes32 key = r.association.action.actionId;
            _point(p, r.point);
            if (
                key == 0 || r.association.artistId != b.artistId
                    || r.association.ownerRevision != r.point.ownerRevision
                    || r.excludedMemberships.length != b.memberships.length
            ) revert IH.InvalidRecoveredIdentity(key);
            if (i != 0) _ordered(p, b.actions[i - 1].point, r.point);
            bool found;
            for (uint256 j; j < p.aliases.length; ++j) {
                RH.ReplayAlias memory a = p.aliases[j];
                if (
                    a.surface == PREPARATION && a.scope == key
                        && a.cell.commitment == r.association.associationHash
                        && _samePoint(a.admittedAt, r.point)
                ) found = true;
            }
            if (!found) revert IH.InvalidRecoveredIdentity(key);
            if (r.execution != 0) {
                bool executed;
                for (uint256 j; j < b.recoveries.length; ++j) {
                    if (
                        b.recoveries[j].record.recordHash == r.execution
                            && b.recoveries[j].record.fields.governanceActionId == key
                    ) {
                        _ordered(p, r.point, b.recoveries[j].position.point);
                        executed = true;
                    }
                }
                if (!executed) revert IH.InvalidRecoveredIdentity(key);
            }
        }
        for (uint256 i; i < b.recoveries.length; ++i) {
            bool found;
            for (uint256 j; j < b.actions.length; ++j) {
                if (b.actions[j].execution == b.recoveries[i].record.recordHash) found = true;
            }
            if (!found) revert IH.InvalidRecoveredIdentity(b.recoveries[i].record.recordHash);
        }
        if (b.heads.pendingRecoveryAction != 0) {
            bool found;
            for (uint256 i; i < b.actions.length; ++i) {
                if (b.actions[i].association.action.actionId == b.heads.pendingRecoveryAction) {
                    found = true;
                }
            }
            if (!found) revert IH.InvalidRecoveredIdentity(b.heads.pendingRecoveryAction);
        }
    }

    function _point(RH.OwnerProvenance calldata p, RH.Point memory point) private pure {
        if (point.ownerIndex != 2) revert IH.InvalidRecoveredIdentity(point.environmentHash);
        Chronology.validateOwnerPoint(p, 2, point);
    }

    function _ordered(RH.OwnerProvenance calldata p, RH.Point memory a, RH.Point memory b)
        private
        pure
    {
        if (!Chronology.beforeOwner(p, 2, a, b)) {
            revert IH.InvalidRecoveredIdentity(b.environmentHash);
        }
    }

    function _samePoint(RH.Point memory a, RH.Point memory b) private pure returns (bool) {
        return keccak256(abi.encode(a)) == keccak256(abi.encode(b));
    }
}

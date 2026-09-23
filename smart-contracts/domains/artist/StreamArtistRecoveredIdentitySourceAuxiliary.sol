// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    IStreamArtistRecoveredIdentityHydrationOwner as Raw
} from "../../interfaces/stream/artist/IStreamArtistRecoveredIdentityHydrationOwner.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Source
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";

import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Fixed original Identity source validation stage.
library StreamArtistRecoveredIdentitySourceAuxiliary {
    bytes32 private constant PREPARATION =
        keccak256("identity_authority.replay.recovery_preparation");
    bytes32 private constant VESTING = keccak256("identity_authority.hydration.guardian_vesting");
    bytes32 private constant ORIGINAL_CONTINUATION =
        keccak256("identity_authority.hydration.dismissal_continuation");
    bytes32 private constant REVISION_CONTINUATION =
        keccak256("identity_authority.hydration.revision_continuation_v3");
    bytes32 private constant STANDING_CONTINUATION =
        keccak256("identity_authority.hydration.standing_continuation_v3");
    bytes32 private constant CAPABILITY_CONTINUATION =
        keccak256("identity_authority.hydration.capability_continuation_v3");

    function validate(address source, IH.Bundle calldata b, RH.OwnerProvenance calldata p)
        public
        view
    {
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            if (
                a.surface != PREPARATION
                    || Raw(source).recoveredIdentityHydrationActionArtist(a.scope) != b.artistId
            ) continue;
            bool found;
            for (uint256 j; j < b.actions.length; ++j) {
                if (b.actions[j].association.action.actionId == a.scope) found = true;
            }
            if (!found) revert IH.InvalidRecoveredIdentity(a.scope);
        }
        for (uint256 i; i < b.vestings.length; ++i) {
            _aux(
                source, VESTING, b.vestings[i].snapshot.transitionRecordHash, b.vestings[i].point, p
            );
        }
        for (uint256 i; i < b.actions.length; ++i) {
            _aux(
                source, PREPARATION, b.actions[i].association.action.actionId, b.actions[i].point, p
            );
        }
        for (uint256 i; i < b.originalContinuations.length; ++i) {
            _aux(
                source,
                ORIGINAL_CONTINUATION,
                b.originalContinuations[i].continuation.continuationHash,
                b.originalContinuations[i].point,
                p
            );
        }
        for (uint256 i; i < b.revisionContinuations.length; ++i) {
            _aux(
                source,
                REVISION_CONTINUATION,
                b.revisionContinuations[i].continuation.continuationHash,
                b.revisionContinuations[i].point,
                p
            );
        }
        for (uint256 i; i < b.standingContinuations.length; ++i) {
            _aux(
                source,
                STANDING_CONTINUATION,
                b.standingContinuations[i].continuation.continuationHash,
                b.standingContinuations[i].point,
                p
            );
        }
        for (uint256 i; i < b.capabilityContinuations.length; ++i) {
            _aux(
                source,
                CAPABILITY_CONTINUATION,
                b.capabilityContinuations[i].continuation.recoveryRecordHash,
                b.capabilityContinuations[i].point,
                p
            );
        }
    }

    function _aux(
        address source,
        bytes32 surface,
        bytes32 key,
        RH.Point memory point,
        RH.OwnerProvenance calldata p
    ) private view {
        _point(p, point);
        if (
            key == 0
                || !_samePoint(point, Source(source).recoveredHydrationAuxiliaryPoint(surface, key))
        ) revert IH.InvalidRecoveredIdentity(key);
    }

    function _point(RH.OwnerProvenance calldata p, RH.Point memory point) private pure {
        if (point.ownerIndex != 2) revert IH.InvalidRecoveredIdentity(point.environmentHash);
        Chronology.validateOwnerPoint(p, 2, point);
    }

    function _samePoint(RH.Point memory a, RH.Point memory b) private pure returns (bool) {
        return keccak256(abi.encode(a)) == keccak256(abi.encode(b));
    }
}

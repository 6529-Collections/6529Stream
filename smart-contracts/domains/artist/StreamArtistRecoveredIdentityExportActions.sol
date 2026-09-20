// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";

import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityExportActions {
    bytes32 private constant PREPARATION =
        keccak256("identity_authority.replay.recovery_preparation");

    function collect(uint256[17] memory r, bytes calldata canonical, RH.OwnerProvenance memory p)
        public
        view
        returns (bytes memory)
    {
        IH.Bundle calldata b = Frame.bundle(canonical);
        bytes32[] memory keys = new bytes32[](p.aliases.length);
        uint256 n;
        for (uint256 i; i < p.aliases.length; ++i) {
            if (
                p.aliases[i].surface == PREPARATION
                    && X.recovery(r).actions[p.aliases[i].scope].artistId == b.artistId
            ) {
                bytes32 key = p.aliases[i].scope;
                bool found;
                for (uint256 j; j < n; ++j) {
                    if (keys[j] == key) found = true;
                }
                if (!found) keys[n++] = key;
            }
        }
        IH.ActionRow[] memory rows = new IH.ActionRow[](n);
        for (uint256 i; i < n; ++i) {
            bytes32 key = keys[i];
            IH.ActionRow memory row;
            row.association = X.recovery(r).actions[key];
            row.veto = X.recovery(r).vetoes[key];
            row.execution = X.recovery(r).actionExecutions[key];
            row.guardianSnapshot = X.recovery(r).guardianHistory.snapshots[key];
            row.plan = X.recovery(r).guardianSupersession.plans[key];
            row.election = X.recovery(r).guardianSupersession.elections[key];
            row.restoredGuardian = X.recovery(r).guardianSupersession.restoredGuardians[key];
            row.excludedMemberships = new uint64[](b.memberships.length);
            for (uint256 j; j < b.memberships.length; ++j) {
                row.excludedMemberships[j] = X.recovery(r).guardianSupersession
                    .excludedMemberships[key][b.memberships[j].actor];
            }
            row.evidenceV2 = X.adjudication(r).actions[key];
            row.evidenceV3 = X.rewinds(r).actions[key];
            row.manifestActionV2 = X.adjudication(r).manifestActions[row.evidenceV2.manifestHash];
            row.manifestActionV3 = X.rewinds(r).manifestActions[row.evidenceV3.manifestHash];
            bool point;
            for (uint256 j; j < p.aliases.length; ++j) {
                if (
                    p.aliases[j].surface == PREPARATION && p.aliases[j].scope == key
                        && p.aliases[j].cell.commitment == row.association.associationHash
                ) {
                    if (
                        point
                            && keccak256(abi.encode(row.point))
                                != keccak256(abi.encode(p.aliases[j].admittedAt))
                    ) revert IH.InvalidRecoveredIdentity(key);
                    row.point = p.aliases[j].admittedAt;
                    point = true;
                }
            }
            if (!point) revert IH.InvalidRecoveredIdentity(key);
            rows[i] = row;
        }
        // Prefix enumeration is key-ordered; restore actual chronology without comparing raw cross-owner revisions.
        for (uint256 i = 1; i < rows.length; ++i) {
            IH.ActionRow memory row = rows[i];
            uint256 j = i;
            while (j != 0 && Chronology.beforeOwner(p, 2, row.point, rows[j - 1].point)) {
                rows[j] = rows[j - 1];
                --j;
            }
            rows[j] = row;
        }
        return abi.encode(rows);
    }
}

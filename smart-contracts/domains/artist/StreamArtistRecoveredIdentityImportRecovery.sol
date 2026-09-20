// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";
import {
    StreamArtistIdentityRecoveryReceipts as Receipts
} from "./StreamArtistIdentityRecoveryReceipts.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Fixed recovery phase of the original recovered Identity import.
/// @dev The fixed importer passes the complete canonical Bundle after SourceCodec validation.
/// Linked library calls retain the host's 17 declared roots and storage context.
library StreamArtistRecoveredIdentityImportRecovery {
    function install(uint256[17] memory roots, bytes calldata canonical) public {
        IH.Bundle calldata b = Frame.bundle(canonical);
        _recovery(roots, b);
    }

    function _recovery(uint256[17] memory r, IH.Bundle calldata b) private {
        for (uint256 i; i < b.recoveries.length; ++i) {
            IH.RecoveryRow memory row = b.recoveries[i];
            IH.RecoveryRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(
                    X.recovery(r).records[key],
                    X.recovery(r).transitions[key],
                    X.recovery(r).recoveryGuardians[key]
                ),
                abi.encode(zero.record, zero.transition, bytes32(0)),
                key
            );
            if (
                X.recovery(r).receipts.receipts[Receipts.PRIMARY][key] != 0
                    || X.recovery(r).receipts.secondaryOccurrences[row.secondaryOccurrence] != 0
            ) revert IH.InvalidRecoveredIdentity(key);
            X.recovery(r).records[key] = row.record;
            X.recovery(r).transitions[key] = row.transition;
            X.recovery(r).recoveryGuardians[key] = row.guardian;
            X.recovery(r).receipts.receipts[Receipts.PRIMARY][key] = row.primaryReceipt;
            X.recovery(r).receipts.secondaryOccurrences[row.secondaryOccurrence] =
            row.secondaryReceipt;
        }
        for (uint256 i; i < b.vestings.length; ++i) {
            IH.VestingRow memory row = b.vestings[i];
            IH.VestingRow memory zero;
            bytes32 key = row.snapshot.transitionRecordHash;
            _empty(
                abi.encode(X.recovery(r).vestingHistory.snapshots[key]),
                abi.encode(zero.snapshot),
                key
            );
            X.recovery(r).vestingHistory.snapshots[key] = row.snapshot;
        }
        for (uint256 i; i < b.actions.length; ++i) {
            IH.ActionRow memory row = b.actions[i];
            IH.ActionRow memory zero;
            bytes32 key = row.association.action.actionId;
            _empty(
                abi.encode(
                    X.recovery(r).actions[key],
                    X.recovery(r).vetoes[key],
                    X.recovery(r).actionExecutions[key],
                    X.recovery(r).guardianHistory.snapshots[key]
                ),
                abi.encode(zero.association, zero.veto, bytes32(0), zero.guardianSnapshot),
                key
            );
            _empty(
                abi.encode(
                    X.recovery(r).guardianSupersession.plans[key],
                    X.recovery(r).guardianSupersession.elections[key],
                    X.recovery(r).guardianSupersession.restoredGuardians[key]
                ),
                abi.encode(zero.plan, zero.election, zero.restoredGuardian),
                key
            );
            _empty(
                abi.encode(X.adjudication(r).actions[key], X.rewinds(r).actions[key]),
                abi.encode(zero.evidenceV2, zero.evidenceV3),
                key
            );
            X.recovery(r).actions[key] = row.association;
            X.recovery(r).vetoes[key] = row.veto;
            X.recovery(r).actionExecutions[key] = row.execution;
            X.recovery(r).guardianHistory.snapshots[key] = row.guardianSnapshot;
            X.recovery(r).guardianSupersession.plans[key] = row.plan;
            X.recovery(r).guardianSupersession.elections[key] = row.election;
            X.recovery(r).guardianSupersession.restoredGuardians[key] = row.restoredGuardian;
            for (uint256 j; j < b.memberships.length; ++j) {
                if (
                    X.recovery(r).guardianSupersession
                            .excludedMemberships[key][b.memberships[j].actor] != 0
                ) revert IH.InvalidRecoveredIdentity(key);
                X.recovery(r).guardianSupersession
                    .excludedMemberships[key][b.memberships[j].actor] = row.excludedMemberships[j];
            }
            X.adjudication(r).actions[key] = row.evidenceV2;
            X.rewinds(r).actions[key] = row.evidenceV3;
            if (row.evidenceV2.manifestHash != 0) {
                if (X.adjudication(r).manifestActions[row.evidenceV2.manifestHash] != 0) {
                    revert IH.InvalidRecoveredIdentity(row.evidenceV2.manifestHash);
                }
                X.adjudication(r).manifestActions[row.evidenceV2.manifestHash] =
                row.manifestActionV2;
            }
            if (row.evidenceV3.manifestHash != 0) {
                if (X.rewinds(r).manifestActions[row.evidenceV3.manifestHash] != 0) {
                    revert IH.InvalidRecoveredIdentity(row.evidenceV3.manifestHash);
                }
                X.rewinds(r).manifestActions[row.evidenceV3.manifestHash] = row.manifestActionV3;
            }
        }
    }

    function _empty(bytes memory old, bytes memory zero, bytes32 key) private pure {
        if (keccak256(old) != keccak256(zero)) revert IH.InvalidRecoveredIdentity(key);
    }
}

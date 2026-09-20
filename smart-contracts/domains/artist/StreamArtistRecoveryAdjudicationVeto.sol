// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveryAdjudicationState as Supplemental
} from "./StreamArtistRecoveryAdjudicationState.sol";
import {
    StreamArtistIdentityRecoveryState as Recovery
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistGuardianSelectionTypes as Selection
} from "../../interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistRecoverySelectionTypesV2 as V2
} from "../../interfaces/stream/artist/StreamArtistRecoverySelectionTypesV2.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    IStreamArtistRecoverySelectionPreparation,
    IStreamArtistRecoverySelectionBinding
} from "../../interfaces/stream/artist/IStreamArtistRecoverySelectionPreparation.sol";

/// @notice Frozen lifetime membership excludes both prior permanent and current adjudications.
/// @dev Do not require the live execution anchor here: a scheduled action remains vetoable after
/// another owner revision. The original action/pending/execution/veto checks still gate mutation.
library StreamArtistRecoveryAdjudicationVeto {
    function member(
        Recovery.State storage s,
        Supplemental.State storage supplemental,
        Identity.OwnerContext memory o,
        bytes32 artistId,
        bytes32 actionId,
        address actor
    ) public view returns (bool) {
        A.Association storage a = s.actions[actionId];
        E.EvidenceStateV2 memory e = supplemental.actions[actionId];
        GH.Snapshot storage snapshot = s.guardianHistory.snapshots[actionId];
        Selection.Result memory result = s.guardianSupersession.elections[actionId];
        if (
            a.artistId != artistId || a.action.actionId != actionId || a.associationHash == 0
                || e.manifestHash == 0 || e.associationHash != a.associationHash
                || snapshot.artistId != artistId || snapshot.associationHash != a.associationHash
                || result.sourceKey == 0 || result.commitment == 0
                || result.commitment != e.selectionCommitment
        ) revert A.InvalidRecoveryAction(actionId);
        (address target, bytes32 codeHash) = IStreamArtistRecoverySelectionBinding(address(this))
            .recoverySelectionPreparationBinding();
        if (target.code.length == 0 || codeHash == 0 || target.codehash != codeHash) {
            revert E.RecoveryEvidenceDependencyChanged(target);
        }
        IStreamArtistRecoverySelectionPreparation worker =
            IStreamArtistRecoverySelectionPreparation(target);
        if (
            worker.owner() != address(this) || worker.artistRegistry() != o.environment.registry
                || worker.deploymentChainId() != o.environment.chainId
        ) revert E.RecoveryEvidenceDependencyChanged(target);
        (V2.Basis memory basis, Selection.Progress memory progress) =
            worker.selectionV2(result.sourceKey);
        if (
            basis.artistId != artistId || basis.manifestHash != e.manifestHash
                || basis.ownerCodeHash != address(this).codehash || !progress.complete
                || progress.processed != snapshot.count || basis.history.count != snapshot.count
                || basis.history.commitment != snapshot.historyCommitment
                || result.sourceKey
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_GUARDIAN_SELECTION_SOURCE_V2"),
                            o.environment.chainId,
                            o.environment.registry,
                            address(this),
                            basis
                        )
                    )
                || result.commitment
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_GUARDIAN_SELECTION_RESULT_V2"),
                            result.sourceKey,
                            basis,
                            progress
                        )
                    )
        ) revert A.InvalidRecoveryAction(actionId);
        return worker.retainedMemberV2(result.sourceKey, actor);
    }
}

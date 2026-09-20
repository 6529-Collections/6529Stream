// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveryRewindState as Rewind } from "./StreamArtistRecoveryRewindState.sol";
import {
    StreamArtistIdentityRecoveryState as Recovery
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import {
    StreamArtistRecoveryRewindEvidenceReads as Evidence
} from "./StreamArtistRecoveryRewindEvidenceReads.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    IStreamArtistRecoveryRewindSelection as Worker
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

/// @notice A scheduled action stays vetoable after unrelated revisions; membership uses its frozen scan.
library StreamArtistRecoveryRewindVeto {
    function member(
        Recovery.State storage s,
        Rewind.State storage rewind,
        Identity.OwnerContext memory o,
        bytes32 artistId,
        bytes32 actionId,
        address actor
    ) public view returns (bool) {
        A.Association storage a = s.actions[actionId];
        W.EvidenceStateV3 memory saved = rewind.actions[actionId];
        GH.Snapshot storage snapshot = s.guardianHistory.snapshots[actionId];
        if (
            a.artistId != artistId || a.action.actionId != actionId || a.associationHash == 0
                || saved.manifestHash == 0 || saved.associationHash != a.associationHash
                || snapshot.artistId != artistId || snapshot.associationHash != a.associationHash
        ) {
            revert A.InvalidRecoveryAction(actionId);
        }
        W.EnvironmentV3 memory e = Evidence.environment(o);
        if (Imported.commitment() != 0) {
            Runtime.OriginFact memory source = Recovered.preparation(Runtime.load(e, 2), a);
            e = Runtime.rewindEnvironment(source.environment);
            if (e.identityOwner.codehash != e.identityCodeHash || e.identityOwner.code.length == 0)
            {
                revert W.RecoveryRewindDependencyChanged(e.identityOwner);
            }
        }
        Worker worker = Evidence.worker(e);
        (W.BasisV3 memory basis, W.ProgressV3 memory progress) = worker.selectionV3(saved.sourceKey);
        W.ResultV3 memory result = worker.selectionResultV3(saved.sourceKey);
        if (
            !progress.complete || basis.identity.artistId != artistId
                || basis.identity.manifestHash != saved.manifestHash
                || basis.identity.ownerCodeHash != e.identityCodeHash
                || result.commitment != saved.selectionCommitment
                || result.sourceKey != saved.sourceKey
                || W.selectionKey(e, basis) != saved.sourceKey
                || W.selectionResultHash(e, result) != result.commitment
                || progress.guardiansProcessed != snapshot.count
                || basis.identity.guardianHistory.count != snapshot.count
                || basis.identity.guardianHistory.commitment != snapshot.historyCommitment
                || keccak256(abi.encode(result.guardians))
                    != keccak256(abi.encode(s.guardianSupersession.elections[actionId]))
        ) {
            revert A.InvalidRecoveryAction(actionId);
        }
        return worker.retainedMemberV3(saved.sourceKey, actor);
    }
}

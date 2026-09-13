// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistGuardianSelectionOwner
} from "../../interfaces/stream/artist/IStreamArtistGuardianSelectionPreparation.sol";
import {
    StreamArtistGuardianSelectionTypes as Selection
} from "../../interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistRotationTypes as Rotation
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    IStreamArtistGuardianHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";

import { StreamArtistRecoveryActionReads as Reads } from "./StreamArtistRecoveryActionReads.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as R
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    IStreamArtistRecoveryActionOwner
} from "../../interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import { IStreamArtistArchiveV2 } from "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import { GovernanceCall } from "../../interfaces/stream/governance/StreamGovernanceTypes.sol";

/// @notice Explicit auxiliary and operation34 recipes, invoked inside the pinned Coordinator lock.
library StreamArtistRecoveryActionOperations {
    function prepare(
        D.CoordinatorContext memory x,
        address actor,
        bytes32 actionId,
        GovernanceCall[] memory calls,
        R.Request memory p,
        T.Authorization memory acceptance
    ) public returns (bytes32 association) {
        address identity = x.suite.owners[2];
        T.Snapshot[7] memory before_;
        before_[2] = IStreamArtistOwner(identity).ownerStateSnapshotV2();
        R.Context memory context =
            IStreamArtistIdentityRecoveryOwner(identity).identityRecoveryContext(p, acceptance);
        IStreamArtistRecoveryActionOwner owner = IStreamArtistRecoveryActionOwner(identity);
        (address executor, bytes32 codeHash) = owner.recoveryExecutorBinding();
        A.Witness memory w = Reads.prepare(
            A.Environment(x.suite.registry, executor, codeHash, x.suite.roleRegistry),
            actionId,
            calls,
            p,
            acceptance,
            context
        );
        (A.Association memory previous,,,) =
            owner.identityRecoveryActionState(p.artistId, bytes32(0));
        bool terminal = previous.associationHash == bytes32(0) || Reads.terminal(previous.action);
        association = owner.prepareIdentityRecoveryAction(
            T.ActionContext(A.PREPARE_OPERATION, actor, before_[2]),
            p,
            acceptance,
            w,
            previous.associationHash,
            terminal
        );
        (A.Association memory saved, A.Veto memory veto, bytes32 executed, uint64 count) =
            owner.identityRecoveryActionState(p.artistId, actionId);
        if (
            association == bytes32(0) || saved.associationHash != association
                || veto.vetoer != address(0) || executed != bytes32(0)
                || saved.action.actionId != actionId
        ) revert T.InvalidRecord();
        (GH.Head memory head,, GH.Snapshot memory history,) = IStreamArtistGuardianHistory(
                address(owner)
            ).guardianHistoryState(p.artistId, 0, address(0), actionId);
        if (
            history.associationHash != association || history.artistId != p.artistId
                || history.count != count || head.count != count
                || history.historyCommitment != head.commitment
        ) revert T.InvalidRecord();
        _archive(
            x,
            actor,
            A.PREPARE_OPERATION,
            association,
            before_,
            _preparationPayload(identity, p, acceptance, context, saved, count, history)
        );
    }

    function _preparationPayload(
        address identity,
        R.Request memory p,
        T.Authorization memory acceptance,
        R.Context memory context,
        A.Association memory saved,
        uint64 count,
        GH.Snapshot memory history
    ) private view returns (bytes memory) {
        if (p.supersededRecordHashes.length != 0) {
            (Selection.Result memory result, Rotation.GuardianRecord memory restored) = IStreamArtistGuardianSelectionOwner(
                    identity
                ).guardianRecoverySelection(saved.action.actionId);
            if (result.commitment != 0) {
                return abi.encode(p, acceptance, context, saved, count, history, result, restored);
            }
        }
        return abi.encode(p, acceptance, context, saved, count, history);
    }

    function veto(D.CoordinatorContext memory x, address actor, bytes32 artistId, bytes32 reason)
        public
    {
        address identity = x.suite.owners[2];
        T.Snapshot[7] memory before_;
        before_[2] = IStreamArtistOwner(identity).ownerStateSnapshotV2();
        IStreamArtistRecoveryActionOwner owner = IStreamArtistRecoveryActionOwner(identity);
        (A.Association memory a,,,) = owner.identityRecoveryActionState(artistId, bytes32(0));
        if (a.associationHash == bytes32(0)) revert A.InvalidRecoveryAction(bytes32(0));
        Reads.requireScheduled(a.action);
        owner.vetoPreparedIdentityRecovery(
            T.ActionContext(34, actor, before_[2]), artistId, a.action.actionId, reason, true
        );
        (, A.Veto memory v, bytes32 executed,) =
            owner.identityRecoveryActionState(artistId, a.action.actionId);
        if (v.vetoer != actor || v.reasonHash != reason || executed != bytes32(0)) {
            revert T.InvalidRecord();
        }
        bytes32 id = keccak256(abi.encode(a.associationHash, v));
        _archive(x, actor, 34, id, before_, abi.encode(a, v));
    }

    function requireExecution(address identity, bytes32 artistId, bytes32 actionId) public view {
        IStreamArtistRecoveryActionOwner owner = IStreamArtistRecoveryActionOwner(identity);
        (A.Association memory a,,,) = owner.identityRecoveryActionState(artistId, actionId);
        // The owner independently rejects an unprepared guarded context. The original unguarded profile stays exact.
        if (a.associationHash == bytes32(0)) return;
        (address executor, bytes32 codeHash) = owner.recoveryExecutorBinding();
        if (a.action.executor != executor || a.action.executorCodeHash != codeHash) {
            revert T.InvalidBinding();
        }
        Reads.requireExecuted(a.action);
    }

    function _archive(
        D.CoordinatorContext memory x,
        address actor,
        uint16 operation,
        bytes32 commitment,
        T.Snapshot[7] memory before_,
        bytes memory payload
    ) private {
        T.Snapshot[7] memory after_;
        after_[2] = IStreamArtistOwner(x.suite.owners[2]).ownerStateSnapshotV2();
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                operation,
                actor,
                commitment
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1), x.configurationHash, operation, actor, bytes32(0), before_, after_, payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}

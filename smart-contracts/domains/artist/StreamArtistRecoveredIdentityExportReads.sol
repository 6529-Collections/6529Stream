// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";

import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Source
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";

import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";

import {
    StreamArtistRecoveredTimingInventory as Timing
} from "./StreamArtistRecoveredTimingInventory.sol";

import {
    StreamArtistRecoveredHydrationState as ProvenanceState
} from "./StreamArtistRecoveredHydrationState.sol";
import { StreamArtistNativeReceipts as Native } from "./StreamArtistNativeReceipts.sol";

import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityExportReads {
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

    struct Repudiation {
        uint64 seconds_;
        uint64 revision;
        mapping(bytes32 => bool) actions;
    }

    function actionArtist(uint256[17] memory roots, bytes32 action) public view returns (bytes32) {
        return X.recovery(roots).actions[action].artistId;
    }

    function auxiliaryPoint(
        uint256[17] memory roots,
        bytes32 kind,
        bytes32 key,
        bytes32 currentOriginHash
    ) public view returns (RH.Point memory) {
        uint64 revision;
        RH.Point memory producer;
        if (kind == VESTING) {
            V.Snapshot memory v = X.recovery(roots).vestingHistory.snapshots[key];
            if (v.transitionRecordHash != key) revert IH.InvalidRecoveredIdentity(key);
            revision = v.ownerRevision;
            if (v.operationId == 32 || v.operationId == 40) {
                producer = _replayPoint(
                    roots,
                    v.operationId == 32
                        ? keccak256("identity_authority.replay.rotation_execution_key")
                        : keccak256("identity_authority.replay.activation_execution_key"),
                    key,
                    key,
                    revision
                );
            } else if (v.operationId == 35 || v.operationId == 43) {
                producer = _nativePoint(v.operationId, key, currentOriginHash);
            } else {
                revert IH.InvalidRecoveredIdentity(key);
            }
        } else if (kind == PREPARATION) {
            if (X.recovery(roots).actions[key].action.actionId != key) {
                revert IH.InvalidRecoveredIdentity(key);
            }
            revision = X.recovery(roots).actions[key].ownerRevision;
            producer = _replayPoint(
                roots, PREPARATION, key, X.recovery(roots).actions[key].associationHash, revision
            );
        } else if (kind == REVISION_CONTINUATION) {
            if (X.rewinds(roots).revisionContinuations[key].continuationHash != key) {
                revert IH.InvalidRecoveredIdentity(key);
            }
            revision = X.rewinds(roots).revisionContinuations[key].ownerRevision;
            producer = _nativePoint(
                35,
                X.rewinds(roots).revisionContinuations[key].recoveryRecordHash,
                currentOriginHash
            );
        } else if (kind == STANDING_CONTINUATION) {
            if (X.rewinds(roots).standingContinuations[key].continuationHash != key) {
                revert IH.InvalidRecoveredIdentity(key);
            }
            revision = X.rewinds(roots).standingContinuations[key].ownerRevision;
            producer = _nativePoint(
                35,
                X.rewinds(roots).standingContinuations[key].recoveryRecordHash,
                currentOriginHash
            );
        } else if (kind == ORIGINAL_CONTINUATION) {
            bytes32 dismissal = X.resolutions(roots).continuations[key].dismissalRecordHash;
            if (
                key == 0 || X.resolutions(roots).continuations[key].continuationHash != key
                    || dismissal == 0
                    || X.resolutions(roots).records[dismissal].recordHash != dismissal
            ) revert IH.InvalidRecoveredIdentity(key);
            producer = _nativePoint(58, dismissal, currentOriginHash);
            revision = producer.ownerRevision;
        } else if (kind == CAPABILITY_CONTINUATION) {
            if (
                key == 0 || X.rewinds(roots).capabilityContinuations[key].recoveryRecordHash != key
                    || X.rewinds(roots).capabilityContinuations[key].commitment == 0
                    || X.recovery(roots).records[key].recordHash != key
            ) revert IH.InvalidRecoveredIdentity(key);
            producer = _nativePoint(35, key, currentOriginHash);
            revision = producer.ownerRevision;
        } else {
            revert IH.InvalidRecoveredIdentity(key);
        }
        RH.Point memory retained = ProvenanceState.artifactPoint(
            kind, key, revision, RH.Point(currentOriginHash, 2, revision)
        );
        if (
            producer.environmentHash != retained.environmentHash || producer.ownerIndex != 2
                || producer.ownerRevision != retained.ownerRevision
        ) revert IH.InvalidRecoveredIdentity(key);
        if (kind == VESTING && retained.environmentHash == currentOriginHash) {
            V.Snapshot memory v = X.recovery(roots).vestingHistory.snapshots[key];
            IStreamArtistOwner owner = IStreamArtistOwner(address(this));
            bytes32 currentHash = keccak256(
                bytes.concat(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                        owner.deploymentChainId(),
                        owner.artistRegistry(),
                        address(this)
                    ),
                    abi.encode(
                        v.artistId,
                        v.transitionRecordHash,
                        v.operationId,
                        v.ownerRevision,
                        v.executedAt,
                        v.oldAddress,
                        v.newAddress,
                        v.authorityClass,
                        v.guardians,
                        v.previousTransitionRecordHash,
                        v.previousCommitment
                    )
                )
            );
            if (v.commitment != currentHash) revert IH.InvalidRecoveredIdentity(key);
        }
        return retained;
    }

    function _replayPoint(
        uint256[17] memory roots,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment,
        uint64 revision
    ) private view returns (RH.Point memory) {
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        bytes32 replayKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                owner.deploymentChainId(),
                owner.artistRegistry(),
                owner.operationCoordinator(),
                owner.archiveV2(),
                address(this),
                owner.domainId(),
                surface,
                scope
            )
        );
        if (
            commitment == 0 || X.replay(roots).cells[replayKey].commitment != commitment
                || X.replay(roots).cells[replayKey].kind != 1
                || X.replay(roots).cells[replayKey].status != 2
                || X.replay(roots).cells[replayKey].touchedRevision != revision
        ) {
            revert IH.InvalidRecoveredIdentity(scope);
        }
        return Source(address(this)).recoveredHydrationReplayPoint(replayKey);
    }

    function _nativePoint(uint16 operation, bytes32 key, bytes32 currentOriginHash)
        private
        view
        returns (RH.Point memory point)
    {
        bytes32 kind = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_RECOVERED_NATIVE_RECORD_V1"), operation)
        );
        uint256 count = Native.count();
        for (uint256 i; i < count; ++i) {
            if (Native.at(i).operation != operation || Native.at(i).recordHash != key) continue;
            if (point.ownerRevision != 0) revert IH.InvalidRecoveredIdentity(key);
            uint64 revision = Native.revisionAt(i);
            point = ProvenanceState.artifactPoint(
                kind, key, revision, RH.Point(currentOriginHash, 2, revision)
            );
        }
        // Imported semantic rows are not duplicated in this owner's native receipt array.
        if (point.ownerRevision == 0) point = ProvenanceState.artifact(kind, key);
    }

    function timingCheckpoint(uint256[17] memory roots) public view returns (TM.Checkpoint memory) {
        return Timing.checkpoint(configuration(roots));
    }

    function configuration(uint256[17] memory roots)
        public
        view
        returns (TM.Configuration memory c)
    {
        c.values = [
            X.rotations(roots).rotationContestSeconds,
            X.rotations(roots).priorStandingTailSeconds,
            X.estate(roots).noticeSeconds,
            X.dormancy(roots).inactivitySeconds,
            X.dormancy(roots).noticeSeconds,
            X.findings(roots).noticeSeconds,
            _repudiation().seconds_
        ];
        c.revisions = [
            X.rotations(roots).timingRevision,
            X.estate(roots).noticeRevision,
            X.dormancy(roots).timingRevision,
            X.findings(roots).timingRevision,
            _repudiation().revision
        ];
    }

    function _repudiation() private pure returns (Repudiation storage s) {
        bytes32 slot = keccak256("6529STREAM_ARTIST_REPUDIATION_TIMING_V1");
        assembly ("memory-safe") { s.slot := slot }
    }
}

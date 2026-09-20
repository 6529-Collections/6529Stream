// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistRecoveryDeployment
} from "../../interfaces/stream/artist/IStreamArtistRecoveryDeployment.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import {
    IStreamArtistGuardianVestingHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import { StreamArtistHashes as H } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Fixed-owner admission and original association proofs shared by the V3 record reader.
/// @dev The selector proves complete receipt prefixes and currentness; this leaf never scans history.
library StreamArtistRecoveryRewindAdmission {
    error InvalidRewindRecord(bytes32 recordHash);
    error InvalidRewindEnvironment();

    /// @notice Original key-domain admission with its actual historical mutation point.
    function consumedAt(
        W.EnvironmentV3 memory e,
        bytes32 origin,
        bytes32 surface,
        bytes32 scope,
        bytes32 expected
    ) public view returns (Runtime.ReplayFact memory f) {
        Runtime.Context memory c = Runtime.load(e, 2);
        f = Runtime.replay(c, origin, surface, scope);
        if (
            expected == 0 || f.cell.commitment != expected || f.cell.kind != 1 || f.cell.status != 2
        ) revert InvalidRewindRecord(expected);
    }

    function nonceAt(
        W.EnvironmentV3 memory e,
        bytes32 origin,
        bytes32 artistId,
        uint256 value,
        bytes32 digest
    ) public view returns (Runtime.ReplayFact memory) {
        return consumedAt(
            e,
            origin,
            keccak256("identity_authority.replay.nonce_allocator"),
            keccak256(abi.encode(artistId, value)),
            digest
        );
    }

    function vestingAt(W.EnvironmentV3 memory e, bytes32 artistId, bytes32 record)
        public
        view
        returns (V.Snapshot memory v, R.TransitionState memory t, Runtime.OriginFact memory origin)
    {
        Runtime.Context memory c = Runtime.load(e, 2);
        v = IStreamArtistGuardianVestingHistory(e.identityOwner)
            .guardianVestingSnapshot(artistId, record);
        t = IStreamArtistRotationReads(e.identityOwner).artistTransitionState(record);
        origin = Recovered.vesting(c, v);
        if (
            record == 0 || v.artistId != artistId || v.transitionRecordHash != record
                || v.executedAt > block.timestamp || t.recordHash != record
                || t.artistId != artistId || t.phase != 2 || t.executedAt != v.executedAt
                || t.postWindowEndsAt <= t.executedAt
                || (t.contestedAt != 0
                    && (t.contestedAt < t.executedAt || t.contestedAt > block.timestamp))
                || (v.previousTransitionRecordHash == 0 && v.previousCommitment != 0)
        ) revert InvalidRewindRecord(record);
    }

    function associationAt(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        R.ProvisionalAssociation memory a,
        address signer,
        uint8 authorityClass,
        RH.Point memory admission
    ) public view returns (R.TransitionState memory t, bool eligible, bytes32 proof) {
        Runtime.Context memory c = Runtime.load(e, 2);
        if (a.transitionRecordHash == 0) {
            if (a.windowEndsAt != 0) revert InvalidRewindRecord(bytes32(0));
            // Validate the supplied point even when there is no provisional association.
            Runtime.environment(c, admission.environmentHash);
            Runtime.before(c, admission, admission);
            return (t, true, keccak256(abi.encode(a)));
        }
        (
            V.Snapshot memory v,
            R.TransitionState memory transition,
            Runtime.OriginFact memory origin
        ) = vestingAt(e, artistId, a.transitionRecordHash);
        t = transition;
        if (
            a.windowEndsAt != t.postWindowEndsAt || signer != v.newAddress
                || authorityClass != v.authorityClass || !Runtime.before(c, origin.point, admission)
        ) revert InvalidRewindRecord(a.transitionRecordHash);
        D.Closure memory closed = IStreamArtistIdentityDismissalOwner(e.identityOwner)
            .identityTransitionClosure(artistId, a.transitionRecordHash);
        bytes32 closureProof;
        if (closed.dismissalRecordHash != 0) {
            (D.Record memory d, Runtime.ReplayFact memory resolved) =
                dismissalAt(e, closed.dismissalRecordHash);
            if (
                closed.artistId != artistId || closed.transitionRecordHash != t.recordHash
                    || closed.windowEndsAt != t.postWindowEndsAt
                    || closed.contestedAt != t.contestedAt
                    || closed.abandoned
                        != (t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt)
                    || d.terms.artistId != artistId
                    || !Runtime.before(c, origin.point, resolved.admission.point)
            ) revert InvalidRewindRecord(t.recordHash);
            closureProof = keccak256(abi.encode(d, resolved));
        } else {
            D.Closure memory empty;
            if (keccak256(abi.encode(closed)) != keccak256(abi.encode(empty))) {
                revert InvalidRewindRecord(t.recordHash);
            }
        }
        eligible = R.eligible(artistId, a, t, block.timestamp);
        proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_ASSOCIATION_V1"),
                a,
                v,
                t,
                closed,
                closureProof,
                origin,
                admission
            )
        );
    }

    function dismissalAt(W.EnvironmentV3 memory e, bytes32 record)
        public
        view
        returns (D.Record memory d, Runtime.ReplayFact memory admitted)
    {
        Runtime.Context memory c = Runtime.load(e, 2);
        d = IStreamArtistIdentityDismissalOwner(e.identityOwner)
            .identityContestDismissalRecord(record);
        Runtime.ReceiptFact memory original = Recovered.nativeFact(c, 58, d.terms.artistId, record);
        RH.OriginEnvironment memory origin = original.environment;
        if (
            record == 0 || d.recordHash != record || d.terms.artistId == 0
                || d.terms.expectedCauseHash == 0 || d.executor == address(0)
                || d.proposer == address(0) || d.incumbent == address(0) || d.actionClass != 1
                || d.actionId == 0 || d.dismissedAt == 0 || d.dismissedAt > block.timestamp
                || d.governanceWitnessHash == 0 || d.cohortHash == 0 || d.terms.evidenceHash == 0
                || d.terms.reasonHash == 0 || (d.authorityClass != 1 && d.authorityClass != 3)
                || (d.restoredStatus != d.authorityClass
                    && !(d.authorityClass == 1 && d.restoredStatus == 2))
                || record
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_RECORD_V1"),
                            origin.chainId,
                            origin.registry,
                            origin.owners[2],
                            d.terms,
                            d.executor,
                            d.proposer,
                            d.actionClass,
                            d.actionId,
                            d.incumbent,
                            d.authorityClass,
                            d.restoredStatus,
                            d.dismissedAt,
                            d.cohortHash,
                            d.governanceWitnessHash
                        )
                    )
        ) revert InvalidRewindRecord(record);
        admitted = consumedAt(
            e,
            original.position.point.environmentHash,
            keccak256("identity_authority.replay.contest_resolution"),
            keccak256(abi.encode(d.terms.artistId, d.terms.expectedCauseHash)),
            record
        );
        if (!Recovered.samePoint(original.position.point, admitted.admission.point)) {
            revert InvalidRewindRecord(record);
        }
    }

    function environment(W.EnvironmentV3 memory e) public view {
        if (
            e.chainId != block.chainid || e.registry == address(0) || e.identityOwner == address(0)
                || e.payoutOwner == address(0) || e.identityOwner == e.payoutOwner
                || e.coordinator == address(0) || e.archive == address(0) || e.core == address(0)
                || e.manager == address(0) || e.identityCodeHash == 0 || e.payoutCodeHash == 0
                || e.identityOwner.code.length == 0 || e.payoutOwner.code.length == 0
                || e.identityOwner.codehash != e.identityCodeHash
                || e.payoutOwner.codehash != e.payoutCodeHash
        ) revert InvalidRewindEnvironment();
        T.SuiteConfiguration memory suite =
            IStreamArtistRecoveryDeployment(e.coordinator).suiteConfiguration();
        if (
            suite.owners[2] != e.identityOwner || suite.owners[5] != e.payoutOwner
                || suite.registry != e.registry || suite.archive != e.archive
                || suite.core != e.core || suite.mintManager != e.manager
                || IStreamArtistRecoveryDeployment(e.coordinator).deploymentChainId() != e.chainId
        ) revert InvalidRewindEnvironment();
        _owner(e, e.identityOwner, keccak256("domain:identity_authority"));
        _owner(e, e.payoutOwner, keccak256("domain:payout_lifecycle"));
    }

    function hashes(W.EnvironmentV3 memory e) internal pure returns (H.Environment memory) {
        return H.Environment(e.chainId, e.registry, e.core, e.manager);
    }

    function key(W.EnvironmentV3 memory e, bytes32 surface, bytes32 scope)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                e.chainId,
                e.registry,
                e.coordinator,
                e.archive,
                e.identityOwner,
                keccak256("domain:identity_authority"),
                surface,
                scope
            )
        );
    }

    function consumed(W.EnvironmentV3 memory e, bytes32 surface, bytes32 scope, bytes32 expected)
        public
        view
        returns (T.ReplayCell memory cell)
    {
        cell = IStreamArtistOwner(e.identityOwner).replayCell(key(e, surface, scope));
        if (
            expected == 0 || cell.commitment != expected || cell.status != 2 || cell.kind != 1
                || cell.touchedRevision == 0
                || cell.touchedRevision
                    > IStreamArtistOwner(e.identityOwner).ownerStateSnapshotV2().revision
        ) revert InvalidRewindRecord(expected);
    }

    function nonce(W.EnvironmentV3 memory e, bytes32 artistId, uint256 value, bytes32 digest)
        public
        view
        returns (T.ReplayCell memory)
    {
        return consumed(
            e,
            keccak256("identity_authority.replay.nonce_allocator"),
            keccak256(abi.encode(artistId, value)),
            digest
        );
    }

    function vesting(W.EnvironmentV3 memory e, bytes32 artistId, bytes32 record)
        public
        view
        returns (V.Snapshot memory v, R.TransitionState memory t)
    {
        v = IStreamArtistGuardianVestingHistory(e.identityOwner)
            .guardianVestingSnapshot(artistId, record);
        t = IStreamArtistRotationReads(e.identityOwner).artistTransitionState(record);
        if (
            record == 0 || v.artistId != artistId || v.transitionRecordHash != record
                || v.ownerRevision == 0 || v.ownerRevision <= v.guardians.ownerRevision
                || v.ownerRevision
                    > IStreamArtistOwner(e.identityOwner).ownerStateSnapshotV2().revision
                || v.executedAt == 0 || v.executedAt > block.timestamp || v.oldAddress == address(0)
                || v.newAddress == address(0) || v.oldAddress == v.newAddress
                || (v.authorityClass != 1 && v.authorityClass != 3)
                || (v.operationId != 32
                    && v.operationId != 35
                    && v.operationId != 40
                    && v.operationId != 43) || (v.operationId == 40 && v.authorityClass != 3)
                || v.commitment == 0 || v.commitment != _vestingHash(e, v) || t.recordHash != record
                || t.artistId != artistId || t.phase != 2 || t.executedAt != v.executedAt
                || t.postWindowEndsAt <= t.executedAt
                || (t.contestedAt != 0
                    && (t.contestedAt < t.executedAt || t.contestedAt > block.timestamp))
        ) revert InvalidRewindRecord(record);
        if (v.previousTransitionRecordHash == 0 && v.previousCommitment != 0) {
            revert InvalidRewindRecord(record);
        }
    }

    function association(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        R.ProvisionalAssociation memory a,
        address signer,
        uint8 authorityClass,
        uint64 admissionRevision
    ) public view returns (R.TransitionState memory t, bool eligible, bytes32 proof) {
        if (a.transitionRecordHash == 0) {
            if (a.windowEndsAt != 0) revert InvalidRewindRecord(bytes32(0));
            return (t, true, keccak256(abi.encode(a)));
        }
        V.Snapshot memory v;
        (v, t) = vesting(e, artistId, a.transitionRecordHash);
        if (
            a.windowEndsAt != t.postWindowEndsAt || signer != v.newAddress
                || authorityClass != v.authorityClass || admissionRevision <= v.ownerRevision
        ) revert InvalidRewindRecord(a.transitionRecordHash);
        D.Closure memory c = IStreamArtistIdentityDismissalOwner(e.identityOwner)
            .identityTransitionClosure(artistId, a.transitionRecordHash);
        bytes32 closureProof;
        if (c.dismissalRecordHash != 0) {
            (D.Record memory d, T.ReplayCell memory cell) = dismissal(e, c.dismissalRecordHash);
            if (
                c.artistId != artistId || c.transitionRecordHash != t.recordHash
                    || c.windowEndsAt != t.postWindowEndsAt || c.contestedAt != t.contestedAt
                    || c.abandoned != (t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt)
                    || d.terms.artistId != artistId || cell.touchedRevision <= v.ownerRevision
            ) revert InvalidRewindRecord(t.recordHash);
            closureProof = keccak256(abi.encode(d, cell));
        } else {
            D.Closure memory empty;
            if (keccak256(abi.encode(c)) != keccak256(abi.encode(empty))) {
                revert InvalidRewindRecord(t.recordHash);
            }
        }
        eligible = R.eligible(artistId, a, t, block.timestamp);
        proof = keccak256(abi.encode(a, v, t, c, closureProof));
    }

    function dismissal(W.EnvironmentV3 memory e, bytes32 record)
        public
        view
        returns (D.Record memory d, T.ReplayCell memory cell)
    {
        d = IStreamArtistIdentityDismissalOwner(e.identityOwner)
            .identityContestDismissalRecord(record);
        if (
            record == 0 || d.recordHash != record || d.terms.artistId == 0
                || d.terms.expectedCauseHash == 0 || d.executor == address(0)
                || d.proposer == address(0) || d.incumbent == address(0) || d.actionClass != 1
                || d.actionId == 0 || d.dismissedAt == 0 || d.dismissedAt > block.timestamp
                || d.governanceWitnessHash == 0 || d.cohortHash == 0 || d.terms.evidenceHash == 0
                || d.terms.reasonHash == 0 || (d.authorityClass != 1 && d.authorityClass != 3)
                || (d.restoredStatus != d.authorityClass
                    && !(d.authorityClass == 1 && d.restoredStatus == 2))
                || record
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_RECORD_V1"),
                            e.chainId,
                            e.registry,
                            e.identityOwner,
                            d.terms,
                            d.executor,
                            d.proposer,
                            d.actionClass,
                            d.actionId,
                            d.incumbent,
                            d.authorityClass,
                            d.restoredStatus,
                            d.dismissedAt,
                            d.cohortHash,
                            d.governanceWitnessHash
                        )
                    )
        ) revert InvalidRewindRecord(record);
        cell = consumed(
            e,
            keccak256("identity_authority.replay.contest_resolution"),
            keccak256(abi.encode(d.terms.artistId, d.terms.expectedCauseHash)),
            record
        );
    }

    function _owner(W.EnvironmentV3 memory e, address target, bytes32 domain) private view {
        IStreamArtistOwner o = IStreamArtistOwner(target);
        if (
            o.deploymentChainId() != e.chainId || o.artistRegistry() != e.registry
                || o.operationCoordinator() != e.coordinator || o.archiveV2() != e.archive
                || o.core() != e.core || o.mintManager() != e.manager || o.domainId() != domain
                || o.ownerStateSnapshotV2().domainId != domain
        ) revert InvalidRewindEnvironment();
    }

    function _vestingHash(W.EnvironmentV3 memory e, V.Snapshot memory v)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                e.chainId,
                e.registry,
                e.identityOwner,
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
        );
    }
}

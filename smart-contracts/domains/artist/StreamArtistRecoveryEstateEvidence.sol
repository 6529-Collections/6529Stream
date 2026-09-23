// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredHistoryOrder as Order
} from "./StreamArtistRecoveredHistoryOrder.sol";

import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistEstateState as EstateState } from "./StreamArtistEstateState.sol";
import { StreamArtistEstateHashes } from "./StreamArtistEstateHashes.sol";
import {
    StreamArtistIdentityContestState as ContestState
} from "./StreamArtistIdentityContestState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistRecoveryEstateGuardians as EstateGuardians
} from "./StreamArtistRecoveryEstateGuardians.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveryEstateHistory as EstateHistory
} from "./StreamArtistRecoveryEstateHistory.sol";
import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistSuccessionState } from "./StreamArtistSuccessionState.sol";
import { StreamArtistSuccessionHashes } from "./StreamArtistSuccessionHashes.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Fixed typed recovery read worker; preserves the original host context and checks.
library StreamArtistRecoveryEstateEvidence {
    function _contest(
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Recovery.Request memory p,
        Contest.Record memory c,
        bytes32 head
    ) public view {
        e = _recordEnvironment(e, 33, c.terms.artistId, c.recordHash);
        if (
            cause.facts.kind != 1 || cause.facts.authorityClass != 3 || cause.facts.priorStatus != 3
                || c.recordHash == 0 || c.recordHash != cause.facts.referenceHash
                || c.terms.artistId != p.artistId || c.terms.subjectRecordHash != head
                || c.terms.evidenceHash != p.evidenceHash || c.terms.reasonHash != p.reasonHash
                || cause.facts.evidenceHash != p.evidenceHash
                || cause.facts.reasonHash != p.reasonHash || c.contester != cause.facts.actor
                || c.contestedAt != cause.facts.enteredAt || c.priorStatus != 3
                || c.pendingTransitionRecordHash != 0 || c.executedTransitionRecordHash != head
                || c.recordHash
                    != keccak256(
                        abi.encode(
                            bytes32(
                                0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb
                            ),
                            e.chainId,
                            e.registry,
                            p.artistId,
                            c.contester,
                            head,
                            p.evidenceHash,
                            p.reasonHash,
                            c.contestedAt
                        )
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
    }

    function _vestingHash(StreamArtistHashes.Environment memory e, V.Snapshot memory v)
        public
        view
        returns (bytes32)
    {
        if (Imported.commitment() != 0) return Order.vesting(e, v);
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    e.chainId,
                    e.registry,
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
    }

    function _recordEnvironment(
        StreamArtistHashes.Environment memory e,
        uint16 operation,
        bytes32 artistId,
        bytes32 record
    ) public view returns (StreamArtistHashes.Environment memory) {
        return Imported.commitment() == 0
            ? e
            : Order.nativeEnvironment(e, operation, artistId, record);
    }

    function _causeHash(StreamArtistHashes.Environment memory e, Dismissal.Cause memory cause)
        public
        view
        returns (bytes32)
    {
        address originalOwner = address(this);
        if (Imported.commitment() != 0) {
            Runtime.ReceiptFact memory row = Recovered.nativeFact(
                Recovered.load(address(this), e.registry, e.chainId),
                cause.facts.kind == 1 ? 33 : 31,
                cause.facts.artistId,
                cause.causeHash
            );
            e = Recovered.hashes(row.environment);
            originalOwner = row.environment.owners[2];
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                e.chainId,
                e.registry,
                originalOwner,
                cause.facts
            )
        );
    }

    function _dismissalHash(StreamArtistHashes.Environment memory e, Dismissal.Record memory r)
        public
        view
        returns (bytes32)
    {
        address originalOwner = address(this);
        if (Imported.commitment() != 0) {
            Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
            Runtime.ReceiptFact memory row =
                Recovered.nativeFact(clock, 58, r.terms.artistId, r.recordHash);
            Runtime.ReplayFact memory replay = Runtime.replay(
                clock,
                RH.originHash(clock.current),
                keccak256("identity_authority.replay.contest_resolution"),
                keccak256(abi.encode(r.terms.artistId, r.terms.expectedCauseHash))
            );
            if (
                replay.cell.kind != 1 || replay.cell.status != 2
                    || replay.cell.commitment != r.recordHash
                    || !Recovered.samePoint(replay.admission.point, row.position.point)
            ) {
                revert RH.InvalidRecoveredHydrationProvenance();
            }
            e = Recovered.hashes(row.environment);
            originalOwner = row.environment.owners[2];
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_RECORD_V1"),
                e.chainId,
                e.registry,
                originalOwner,
                r.terms,
                r.executor,
                r.proposer,
                r.actionClass,
                r.actionId,
                r.incumbent,
                r.authorityClass,
                r.restoredStatus,
                r.dismissedAt,
                r.cohortHash,
                r.governanceWitnessHash
            )
        );
    }

    function _before(
        StreamArtistHashes.Environment memory e,
        V.Snapshot memory a,
        V.Snapshot memory b
    ) public view returns (bool) {
        return Imported.commitment() == 0
            ? a.ownerRevision < b.ownerRevision
            : Order.before(e, a, b);
    }
}

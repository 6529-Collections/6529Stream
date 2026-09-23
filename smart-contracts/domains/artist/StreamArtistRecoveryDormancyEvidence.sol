// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistLivingDormancyBoundary as LivingBoundary
} from "./StreamArtistLivingDormancyBoundary.sol";

import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistEstateState as EstateState } from "./StreamArtistEstateState.sol";
import {
    StreamArtistIdentityContestState as ContestState
} from "./StreamArtistIdentityContestState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistSuccessionState } from "./StreamArtistSuccessionState.sol";
import { StreamArtistSuccessionHashes } from "./StreamArtistSuccessionHashes.sol";
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

import "./StreamArtistDormancyState.sol";
import {
    StreamArtistRecoveryDormancyClosure as DormClosure
} from "./StreamArtistRecoveryDormancyClosure.sol";
import {
    StreamArtistRecoveryDormancyGuardians as DormGuardians
} from "./StreamArtistRecoveryDormancyGuardians.sol";

import {
    StreamArtistRecoveryDormancyStanding as DormStanding
} from "./StreamArtistRecoveryDormancyStanding.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

/// @notice Fixed typed recovery read worker; preserves the original host context and checks.
library StreamArtistRecoveryDormancyEvidence {
    function _noticeHash(StreamArtistHashes.Environment memory e, Dorm.Notice memory n)
        public
        view
        returns (bytes32)
    {
        address originalOwner;
        (e, originalOwner) = _original(e, 41, n.terms.artistId, n.recordHash);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_NOTICE_V1"),
                e.chainId,
                e.registry,
                originalOwner,
                n.terms,
                n.incumbent,
                n.initiatedAt,
                n.noticeEndsAt,
                n.inactivitySeconds,
                n.noticeSeconds,
                n.timingRevision,
                n.priorLivenessAt,
                n.priorActivity,
                n.actionId,
                n.witnessHash
            )
        );
    }

    function _contest(
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Recovery.Request memory p,
        Contest.Record memory c,
        bytes32 head
    ) public view {
        e = _recordEnvironment(e, 33, p.artistId, c.recordHash);
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
        if (Imported.commitment() != 0) {
            Recovered.vesting(Recovered.load(address(this), e.registry, e.chainId), v);
            return v.commitment;
        }
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

    function _original(
        StreamArtistHashes.Environment memory e,
        uint16 operation,
        bytes32 artistId,
        bytes32 record
    ) public view returns (StreamArtistHashes.Environment memory, address) {
        if (Imported.commitment() == 0) return (e, address(this));
        Runtime.ReceiptFact memory row = Recovered.nativeFact(
            Recovered.load(address(this), e.registry, e.chainId), operation, artistId, record
        );
        return (Recovered.hashes(row.environment), row.environment.owners[2]);
    }

    function _recordEnvironment(
        StreamArtistHashes.Environment memory e,
        uint16 operation,
        bytes32 artistId,
        bytes32 record
    ) public view returns (StreamArtistHashes.Environment memory original) {
        (original,) = _original(e, operation, artistId, record);
    }

    function _causeHash(StreamArtistHashes.Environment memory e, Dismissal.Cause memory c)
        public
        view
        returns (bytes32)
    {
        address originalOwner;
        (e, originalOwner) =
            _original(e, c.facts.kind == 1 ? 33 : 31, c.facts.artistId, c.causeHash);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                e.chainId,
                e.registry,
                originalOwner,
                c.facts
            )
        );
    }

    function _before(
        StreamArtistHashes.Environment memory e,
        V.Snapshot memory a,
        V.Snapshot memory b
    ) public view returns (bool) {
        if (Imported.commitment() == 0) {
            return a.ownerRevision < b.ownerRevision;
        }
        Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
        return Runtime.before(
            clock, Recovered.vesting(clock, a).point, Recovered.vesting(clock, b).point
        );
    }
}

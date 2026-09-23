// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistEstateHashes } from "./StreamArtistEstateHashes.sol";
import { StreamArtistIdentityRecoveryHashes } from "./StreamArtistIdentityRecoveryHashes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistGuardianVestingHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import {
    IStreamArtistDormancyOwner,
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityContestTypes as C
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";

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
    StreamArtistRecoveryStagingHistory as Original
} from "./StreamArtistRecoveryStagingHistory.sol";

/// @notice Fixed typed worker preserving the original validation and caller context.
library StreamArtistRecoveryStagingEstateHistory {
    function _cancelledEstate(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 requestHash,
        uint64 boundaryRevision,
        RH.Point memory boundary
    ) public view returns (Original.EstateFacts memory f) {
        Original.Environment memory e = _environment(owner, registry, chainId, artistId);
        uint8 phase;
        Estate.ExecutionFacts memory execution;
        (f.request, phase, execution) =
            IStreamArtistEstateOwner(owner).estateActivationRecord(requestHash);
        _request(e, artistId, requestHash, f.request);
        f.transition = IStreamArtistRotationReads(owner).artistTransitionState(requestHash);
        f.requestReplay = _replay(
            e,
            artistId,
            keccak256("identity_authority.replay.activation_request_key"),
            requestHash,
            requestHash
        );
        f.cancellationReplay = _replay(
            e,
            artistId,
            keccak256("identity_authority.replay.activation_cancellation_key"),
            requestHash,
            requestHash
        );
        Estate.ExecutionFacts memory empty;
        R.TransitionState memory t = f.transition;
        if (
            phase != 3 || keccak256(abi.encode(execution)) != keccak256(abi.encode(empty))
                || t.artistId != artistId || t.recordHash != requestHash || t.phase != 3
                || t.stagedAt != f.request.requestedAt || t.contestEndsAt != f.request.noticeEndsAt
                || t.executedAt != 0 || t.postWindowEndsAt != 0
                || (t.contestedAt != 0 && t.contestedAt < t.stagedAt)
                || (!e.imported
                    && (f.requestReplay.touchedRevision >= f.cancellationReplay.touchedRevision
                        || boundaryRevision == 0
                        || boundaryRevision > e.revision
                        || f.cancellationReplay.touchedRevision > boundaryRevision))
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        if (e.imported) {
            Runtime.ReplayFact memory requested = _replayAt(
                e,
                keccak256("identity_authority.replay.activation_request_key"),
                requestHash,
                requestHash
            );
            Runtime.ReplayFact memory cancelled = _replayAt(
                e,
                keccak256("identity_authority.replay.activation_cancellation_key"),
                requestHash,
                requestHash
            );
            f.requestPoint = requested.admission.point;
            f.cancellationPoint = cancelled.admission.point;
            if (
                !Runtime.before(e.clock, f.requestPoint, f.cancellationPoint)
                    || (!Recovered.samePoint(f.cancellationPoint, boundary)
                        && !Runtime.before(e.clock, f.cancellationPoint, boundary))
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        }
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_CANCELLED_ESTATE_STAGE_V1"),
                chainId,
                registry,
                owner,
                f.request,
                t,
                f.requestReplay,
                f.cancellationReplay
            )
        );
    }

    function _request(
        Original.Environment memory e,
        bytes32 artistId,
        bytes32 hash,
        Estate.RequestRecord memory r
    ) private view {
        if (
            hash == 0 || r.recordHash != hash || r.terms.artistId != artistId
                || r.incumbent == address(0) || r.terms.successor == address(0)
                || r.terms.successor == r.incumbent || r.terms.evidenceHash == 0
                || r.requestedAt == 0 || r.noticeRevision == 0 || r.rotationTimingRevision == 0
                || uint256(r.noticeEndsAt) != uint256(r.requestedAt) + r.noticeSeconds
                || r.designationRecordHash == 0
                || r.terms.expectedDesignationRecordHash != r.designationRecordHash
                || r.terms.selectedCoverageHash == 0 || r.envelopeHash == 0
                || hash
                    != StreamArtistEstateHashes.record(
                        _recordEnvironment(e, artistId, 38, hash),
                        r.terms,
                        r.authorization.nonce,
                        r.requestedAt,
                        r.noticeEndsAt
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _environment(address owner, address registry, uint256 chainId, bytes32 artistId)
        private
        view
        returns (Original.Environment memory e)
    {
        if (
            owner.code.length == 0 || registry == address(0) || artistId == 0
                || chainId != block.chainid
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        IStreamArtistOwner source = IStreamArtistOwner(owner);
        e.owner = owner;
        e.registry = registry;
        e.chainId = chainId;
        e.coordinator = source.operationCoordinator();
        e.archive = source.archiveV2();
        e.domain = source.domainId();
        e.revision = source.ownerStateSnapshotV2().revision;
        e.imported = Recovered.active(owner);
        if (e.imported) e.clock = Recovered.load(owner, registry, chainId);
        if (
            source.artistRegistry() != registry || source.deploymentChainId() != chainId
                || e.domain != keccak256("domain:identity_authority") || e.coordinator == address(0)
                || e.archive == address(0)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _replay(
        Original.Environment memory e,
        bytes32 artistId,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment
    ) private view returns (T.ReplayCell memory cell) {
        if (e.imported) return _replayAt(e, surface, scope, commitment).cell;
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                e.chainId,
                e.registry,
                e.coordinator,
                e.archive,
                e.owner,
                e.domain,
                surface,
                scope
            )
        );
        cell = IStreamArtistOwner(e.owner).replayCell(key);
        if (
            cell.commitment != commitment || cell.kind != 1 || cell.status != 2
                || cell.touchedRevision == 0 || cell.touchedRevision > e.revision
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _replayAt(
        Original.Environment memory e,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment
    ) private view returns (Runtime.ReplayFact memory f) {
        f = Runtime.replay(e.clock, RH.originHash(e.clock.current), surface, scope);
        if (
            commitment == 0 || f.cell.commitment != commitment || f.cell.kind != 1
                || f.cell.status != 2
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(commitment);
        }
    }

    function _recordEnvironment(
        Original.Environment memory e,
        bytes32 artistId,
        uint16 operation,
        bytes32 record
    ) private view returns (StreamArtistHashes.Environment memory) {
        if (!e.imported) return _hashEnvironment(e);
        return
            Recovered.hashes(Recovered.nativeFact(e.clock, operation, artistId, record).environment);
    }

    function _hashEnvironment(Original.Environment memory e)
        private
        pure
        returns (StreamArtistHashes.Environment memory)
    {
        return StreamArtistHashes.Environment(e.chainId, e.registry, address(0), address(0));
    }
}

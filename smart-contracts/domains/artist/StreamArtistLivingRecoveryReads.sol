// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistLivingRecoveryAdmission as AdmissionReads
} from "./StreamArtistLivingRecoveryAdmission.sol";

import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistGuardianVestingHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as IdentityRecovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistIdentityRecoveryHashes as Hashes
} from "./StreamArtistIdentityRecoveryHashes.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";

/// @notice Original admitted class-1 operation35 evidence from the fixed Identity owner.
/// @dev Callers supply their fixed owner and decide current-head, epoch and closure eligibility.
/// This reader neither reauthorizes historical governance nor consults mutable retirement state.
library StreamArtistLivingRecoveryReads {
    struct Facts {
        IdentityRecovery.Record record;
        R.TransitionState transition;
        V.Snapshot vesting;
        bytes32 proof;
    }

    struct Environment {
        address owner;
        address registry;
        uint256 chainId;
        bool imported;
        Runtime.Context runtime;
    }

    struct Admission {
        A.Association association;
        GH.Snapshot frozen;
        V.Snapshot parent;
        bytes32 guardian;
        bytes32 primary;
        bytes32 occurrence;
        bytes32 secondary;
    }

    function read(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 recordHash
    ) public view returns (Facts memory f) {
        if (
            chainId != block.chainid || owner.code.length == 0 || registry == address(0)
                || artistId == 0 || recordHash == 0
                || IStreamArtistOwner(owner).deploymentChainId() != chainId
                || IStreamArtistOwner(owner).artistRegistry() != registry
        ) revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
        Environment memory e = _environment(owner, registry, chainId);
        f.record = IStreamArtistIdentityRecoveryOwner(owner).identityRecoveryRecord(recordHash);
        f.transition = IStreamArtistRotationReads(owner).artistTransitionState(recordHash);
        f.vesting = IStreamArtistGuardianVestingHistory(owner)
            .guardianVestingSnapshot(artistId, recordHash);
        _record(e, artistId, recordHash, f, false);
        f.proof = AdmissionReads.read(e, f, false);
        if (e.imported) f.proof = _sourceProof(e, f);
    }

    /// @notice Original admitted class1 or class3 operation35 for complete V2 ancestry.
    /// @dev Current authority and cause/closure eligibility remain caller-owned.
    function readFamily(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 recordHash
    ) public view returns (Facts memory f) {
        if (
            chainId != block.chainid || owner.code.length == 0 || registry == address(0)
                || artistId == 0 || recordHash == 0
                || IStreamArtistOwner(owner).deploymentChainId() != chainId
                || IStreamArtistOwner(owner).artistRegistry() != registry
        ) {
            revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        Environment memory e = _environment(owner, registry, chainId);
        f.record = IStreamArtistIdentityRecoveryOwner(owner).identityRecoveryRecord(recordHash);
        f.transition = IStreamArtistRotationReads(owner).artistTransitionState(recordHash);
        f.vesting = IStreamArtistGuardianVestingHistory(owner)
            .guardianVestingSnapshot(artistId, recordHash);
        _record(e, artistId, recordHash, f, true);
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ADMITTED_RECOVERY_FAMILY_V2"),
                AdmissionReads.read(e, f, true)
            )
        );
        if (e.imported) f.proof = _sourceProof(e, f);
    }

    function _environment(address owner, address registry, uint256 chainId)
        private
        view
        returns (Environment memory e)
    {
        e.owner = owner;
        e.registry = registry;
        e.chainId = chainId;
        e.imported = Recovered.active(owner);
        if (e.imported) e.runtime = Recovered.load(owner, registry, chainId);
    }

    function _sourceProof(Environment memory e, Facts memory f) private view returns (bytes32) {
        Runtime.ReceiptFact memory original =
            Recovered.nativeFact(e.runtime, 35, f.record.fields.artistId, f.record.recordHash);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_ADMITTED_RECOVERY_SOURCE_V1"),
                f.proof,
                e.runtime.importCommitment,
                original
            )
        );
    }

    function _record(
        Environment memory e,
        bytes32 artistId,
        bytes32 recordHash,
        Facts memory f,
        bool family
    ) private view {
        IdentityRecovery.Record memory r = f.record;
        R.TransitionState memory t = f.transition;
        V.Snapshot memory v = f.vesting;
        address registry = e.registry;
        if (e.imported) {
            Runtime.ReceiptFact memory original =
                Recovered.nativeFact(e.runtime, 35, artistId, recordHash);
            Runtime.OriginFact memory vested = Recovered.vesting(e.runtime, v);
            if (!Recovered.samePoint(original.position.point, vested.point)) {
                revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
            registry = original.environment.registry;
        }
        if (
            r.recordHash != recordHash || Hashes.record(e.chainId, registry, r.fields) != recordHash
                || r.fields.artistId != artistId || r.fields.oldAddress == address(0)
                || r.fields.newAddress == address(0) || r.fields.oldAddress == r.fields.newAddress
                || (r.fields.vestedAuthorityClass != 1
                    && (!family || r.fields.vestedAuthorityClass != 3)) || r.fields.recoveredAt == 0
                || r.fields.governanceActionId == 0 || r.fields.evidenceHash == 0
                || r.fields.reasonHash == 0 || r.terms.artistId != artistId
                || r.terms.newAddress != r.fields.newAddress
                || r.terms.vestedAuthorityClass != r.fields.vestedAuthorityClass
                || r.terms.expectedCauseHash == 0 || r.terms.evidenceHash != r.fields.evidenceHash
                || r.terms.reasonHash != r.fields.reasonHash
                || Hashes.supersession(r.terms.supersededRecordHashes)
                    != r.fields.supersededRecordsHash || r.executor == address(0)
                || r.proposer == address(0) || r.governanceWitnessHash == 0 || r.contextHash == 0
                || r.acceptanceDigest == 0 || r.acceptanceDeadline < r.fields.recoveredAt
                || r.postContestSeconds < 72 hours || r.standingTailSeconds < 30 days
                || r.timingRevision == 0 || r.delegationEpoch == 0 || t.artistId != artistId
                || t.recordHash != recordHash || t.phase != 2
                || t.executedAt != r.fields.recoveredAt || t.stagedAt != t.executedAt
                || t.contestEndsAt != t.executedAt
                || uint256(t.postWindowEndsAt) != uint256(t.executedAt) + r.postContestSeconds
                || (t.contestedAt != 0 && t.contestedAt < t.executedAt) || v.artistId != artistId
                || v.transitionRecordHash != recordHash || v.operationId != 35
                || v.authorityClass != r.fields.vestedAuthorityClass
                || v.oldAddress != r.fields.oldAddress || v.newAddress != r.fields.newAddress
                || v.executedAt != t.executedAt || v.ownerRevision == 0
                || (!e.imported && v.ownerRevision <= v.guardians.ownerRevision)
                || v.commitment == 0 || v.commitment != _vestingHash(e, v)
        ) revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _vestingHash(Environment memory e, V.Snapshot memory v)
        private
        view
        returns (bytes32)
    {
        if (e.imported) {
            Runtime.OriginFact memory origin = Recovered.vesting(e.runtime, v);
            return Recovered.vestingHash(origin.environment, v);
        }
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    e.chainId,
                    e.registry,
                    e.owner
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
}

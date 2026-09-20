// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistDormancyOwner,
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
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
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistEstateTypes as E
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistGuardianSupersessionTypes as S
} from "../../interfaces/stream/artist/StreamArtistGuardianSupersessionTypes.sol";

/// @notice Canonical designated operation43 for a fixed owner's current election cutoff.
/// @dev This authenticates admitted records, not historical governance. Recovery separately
/// proves the current epoch, operative plan, full guardian history, cause and original closures.
/// The owner is address(this) in Identity or the immutable owner of its selection preparation.
library StreamArtistDormancyVestingReads {
    function current(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        R.TransitionState memory transition
    ) public view returns (V.Snapshot memory v) {
        bytes32 record = transition.recordHash;
        if (
            chainId != block.chainid || owner.code.length == 0 || artistId == 0 || record == 0
                || IStreamArtistOwner(owner).deploymentChainId() != chainId
                || IStreamArtistOwner(owner).artistRegistry() != registry
                || IStreamArtistIdentityRecoveryOwner(owner).latestIdentityRecovery(artistId) != 0
        ) revert S.InvalidGuardianSupersession(record);
        (bytes32 noticeHash, uint8 phase, bytes32 terminalHash) =
            IStreamArtistDormancyOwner(owner).dormancyNotice(artistId);
        (Dorm.Notice memory n, uint8 savedPhase, Dorm.Terminal memory t) =
            IStreamArtistDormancyOwner(owner).dormancyRecord(noticeHash);
        E.AuthorityCapabilities memory caps =
            IStreamArtistEstateOwner(owner).currentAuthorityCapabilities(artistId);
        if (
            noticeHash == 0 || phase != 3 || savedPhase != 3 || terminalHash != record
                || n.recordHash != noticeHash || n.terms.artistId != artistId
                || n.incumbent == address(0) || n.incumbent == t.plan.authority
                || n.terms.evidenceHash == 0 || n.initiatedAt == 0 || n.actionId == 0
                || n.witnessHash == 0 || n.inactivitySeconds < 365 days
                || n.noticeSeconds < 180 days || n.timingRevision == 0
                || uint256(n.noticeEndsAt) != uint256(n.initiatedAt) + n.noticeSeconds
                || uint256(n.initiatedAt) < uint256(n.priorLivenessAt) + n.inactivitySeconds
                || n.recordHash != _noticeHash(owner, registry, chainId, n)
                || t.recordHash != record || t.noticeHash != noticeHash || t.authorityClass != 3
                || t.plan.authorityClass != 3 || t.plan.authority == address(0)
                || t.appointmentBlock != 0 || t.actor == address(0) || t.evidenceHash == 0
                || t.actionId == 0 || t.witnessHash == 0 || t.observedAt < n.noticeEndsAt
                || t.delegationEpoch == 0 || t.plan.designation == 0
                || t.plan.stewardGrantRecordHash != 0 || t.plan.postSeconds < 72 hours
                || t.plan.standingTail < 30 days || t.plan.capabilities & ~uint32(4095) != 0
                || caps.authorityClass != 3 || (caps.status != 3 && caps.status != 4)
                || caps.authorityAddress != t.plan.authority || caps.activationRecordHash != record
                || caps.effectiveCapabilities != t.plan.capabilities
                || transition.artistId != artistId || transition.phase != 2
                || transition.stagedAt != n.initiatedAt
                || transition.contestEndsAt != n.noticeEndsAt
                || transition.executedAt != t.observedAt
                || uint256(transition.postWindowEndsAt)
                    != uint256(t.observedAt) + t.plan.postSeconds
                || keccak256(abi.encode(transition))
                    != keccak256(
                        abi.encode(IStreamArtistRotationReads(owner).artistTransitionState(record))
                    )
        ) revert S.InvalidGuardianSupersession(record);
        t.recordHash = 0;
        if (
            record
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_V1"),
                        chainId,
                        registry,
                        owner,
                        t
                    )
                )
        ) revert S.InvalidGuardianSupersession(record);
        v = IStreamArtistGuardianVestingHistory(owner).guardianVestingSnapshot(artistId, record);
        if (
            v.artistId != artistId || v.transitionRecordHash != record || v.operationId != 43
                || v.authorityClass != 3 || v.oldAddress != n.incumbent
                || v.newAddress != t.plan.authority || v.executedAt != t.observedAt
                || v.ownerRevision == 0 || v.ownerRevision <= v.guardians.ownerRevision
                || v.commitment == 0 || v.commitment != _vestingHash(owner, registry, chainId, v)
        ) revert S.InvalidGuardianSupersession(record);
    }

    function _noticeHash(address owner, address registry, uint256 chainId, Dorm.Notice memory n)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_NOTICE_V1"),
                chainId,
                registry,
                owner,
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

    function _vestingHash(address owner, address registry, uint256 chainId, V.Snapshot memory v)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"), chainId, registry, owner
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

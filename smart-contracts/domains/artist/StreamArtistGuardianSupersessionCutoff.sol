// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistGuardianVestingHistory as Vesting
} from "./StreamArtistGuardianVestingHistory.sol";
import { StreamArtistGuardianHistory as History } from "./StreamArtistGuardianHistory.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistEstateHashes } from "./StreamArtistEstateHashes.sol";
import { StreamArtistDormancyVestingReads } from "./StreamArtistDormancyVestingReads.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistGuardianSupersessionTypes as S
} from "../../interfaces/stream/artist/StreamArtistGuardianSupersessionTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistEstateTypes as E
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";

import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityRecoveryHashes as RecoveryHashes
} from "./StreamArtistIdentityRecoveryHashes.sol";

/// @notice Original admitted vesting prefix for the current contested execution.
/// @dev Fixed owner state and canonical writer-chain records, never a caller-selected cutoff.
library StreamArtistGuardianSupersessionCutoff {
    function current(
        Vesting.State storage vesting,
        History.State storage history,
        Rotations.State storage rotations,
        bytes32 artistId,
        GH.Head memory head
    ) public view returns (V.Snapshot memory v) {
        bytes32 terminal = rotations.latestExecution[artistId];
        v = vesting.snapshots[terminal];
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        StreamArtistHashes.Environment memory e = StreamArtistHashes.Environment(
            owner.deploymentChainId(), owner.artistRegistry(), owner.core(), owner.mintManager()
        );
        if (
            e.chainId != block.chainid || terminal == 0 || vesting.latest[artistId] != terminal
                || v.artistId != artistId || v.transitionRecordHash != terminal || v.commitment == 0
                || v.commitment != _hash(e, v) || v.ownerRevision == 0 || v.executedAt == 0
                || v.oldAddress == address(0) || v.newAddress == address(0)
                || v.oldAddress == v.newAddress || v.guardians.count > head.count
                || v.guardians.ownerRevision >= v.ownerRevision
        ) {
            revert S.InvalidGuardianSupersession(terminal);
        }
        if (v.guardians.count == 0) {
            if (v.guardians.commitment != 0 || v.guardians.ownerRevision != 0) {
                revert S.InvalidGuardianSupersession(terminal);
            }
        } else {
            GH.Entry storage last = history.entries[history.records[artistId][v.guardians.count]];
            if (
                last.artistId != artistId || last.index != v.guardians.count
                    || last.commitment != v.guardians.commitment
                    || last.ownerRevision != v.guardians.ownerRevision
            ) {
                revert S.InvalidGuardianSupersession(terminal);
            }
        }
        R.TransitionState memory t = Rotations.transitionState(rotations, terminal);
        if (t.artistId != artistId || t.phase != 2 || t.executedAt != v.executedAt) {
            revert S.InvalidGuardianSupersession(terminal);
        }
        if (v.operationId == 32 && (v.authorityClass == 1 || v.authorityClass == 3)) {
            R.RotationRecord memory r = rotations.rotations[terminal];
            if (
                r.recordHash != terminal || r.terms.artistId != artistId
                    || r.terms.oldAddress != v.oldAddress || r.terms.newAddress != v.newAddress
                    || StreamArtistRotationHashes.rotationRecord(
                            e,
                            r.terms,
                            r.oldNonce,
                            r.transition.stagedAt,
                            r.transition.contestEndsAt
                        ) != terminal
            ) {
                revert S.InvalidGuardianSupersession(terminal);
            }
        } else if (v.operationId == 40 && v.authorityClass == 3) {
            (E.RequestRecord memory r, uint8 phase, E.ExecutionFacts memory x) =
                IStreamArtistEstateOwner(address(this)).estateActivationRecord(terminal);
            if (
                r.recordHash != terminal || r.terms.artistId != artistId || phase != 2
                    || r.incumbent != v.oldAddress || r.terms.successor != v.newAddress
                    || x.activationRecordHash != terminal || x.executedAt != v.executedAt
                    || StreamArtistEstateHashes.record(
                            e, r.terms, r.authorization.nonce, r.requestedAt, r.noticeEndsAt
                        ) != terminal
            ) {
                revert S.InvalidGuardianSupersession(terminal);
            }
        } else if (v.operationId == 35 && (v.authorityClass == 1 || v.authorityClass == 3)) {
            I.Record memory r =
                IStreamArtistIdentityRecoveryOwner(address(this)).identityRecoveryRecord(terminal);
            if (
                r.recordHash != terminal || r.fields.artistId != artistId
                    || r.fields.oldAddress != v.oldAddress || r.fields.newAddress != v.newAddress
                    || r.fields.vestedAuthorityClass != v.authorityClass
                    || r.fields.recoveredAt != v.executedAt
                    || RecoveryHashes.record(e.chainId, e.registry, r.fields) != terminal
                    || IStreamArtistIdentityRecoveryOwner(address(this))
                            .latestIdentityRecovery(artistId) != terminal
            ) {
                revert S.InvalidGuardianSupersession(terminal);
            }
        } else if (v.operationId == 43 && v.authorityClass == 3) {
            V.Snapshot memory original = StreamArtistDormancyVestingReads.current(
                address(this), e.registry, e.chainId, artistId, t
            );
            if (keccak256(abi.encode(original)) != keccak256(abi.encode(v))) {
                revert S.InvalidGuardianSupersession(terminal);
            }
        } else {
            revert S.InvalidGuardianSupersession(terminal);
        }
        if (v.previousTransitionRecordHash == 0) {
            if (v.previousCommitment != 0) revert S.InvalidGuardianSupersession(terminal);
        } else {
            V.Snapshot memory prior = vesting.snapshots[v.previousTransitionRecordHash];
            if (
                prior.artistId != artistId
                    || prior.transitionRecordHash != v.previousTransitionRecordHash
                    || prior.commitment == 0 || prior.commitment != v.previousCommitment
                    || prior.commitment != _hash(e, prior) || prior.ownerRevision >= v.ownerRevision
                    || prior.executedAt > v.executedAt || prior.newAddress != v.oldAddress
                    || prior.guardians.count > v.guardians.count
                    || (v.operationId == 40 || v.operationId == 43
                            ? prior.authorityClass != 1
                            : prior.authorityClass != v.authorityClass)
            ) {
                revert S.InvalidGuardianSupersession(terminal);
            }
        }
    }

    function _hash(StreamArtistHashes.Environment memory e, V.Snapshot memory v)
        private
        view
        returns (bytes32)
    {
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
}

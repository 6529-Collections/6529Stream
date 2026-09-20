// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryState as State
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistDormancyOwner
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Select added staging profiles without changing the encoding of previously admitted histories.
/// @dev Classification grants no authority. The selected original or full-family reader authenticates
/// its records. In particular, a cancelled request absorbed before an original40/43 is not by itself
/// a new profile: older origin readers intentionally used their actual vesting producer's admission.
library StreamArtistRecoveryFamilyProfile {
    struct Staging {
        bool cancelled;
        bool referenced;
    }

    struct Episodes {
        bool living;
        bool estate;
        bool cancelledNotice;
    }

    function required(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        D.Cause memory current
    ) public view returns (bool) {
        bytes32 artistId = current.facts.artistId;
        bytes32 root = recovery.latest[artistId];
        if (
            current.facts.kind == 2
                || (current.facts.pendingTransitionHash != 0
                    && (root == 0 || current.facts.authorityClass == 3))
                || _cancelled(current.facts.pendingTransitionHash, artistId)
                || _cancelled(rotations.latestTransition[artistId], artistId)
        ) return true;

        if (current.facts.authorityClass == 1) {
            if (root == 0) {
                // Both original first-living readers require the staging head to equal E.
                // A dismissed aborted P can retain an earlier cancelled S behind that head.
                if (rotations.latestTransition[artistId] != rotations.latestExecution[artistId]) {
                    return true;
                }
                // The original first-living reader inspected only terminal32's immediate saved
                // predecessor. Earlier cancelled stages inside its admitted parent stay legacy.
                return _cancelled(
                    rotations.rotations[rotations.latestExecution[artistId]].terms
                    .expectedPreviousTransitionRecordHash,
                    artistId
                );
            }
            // The repeated-living reader checks the complete staged suffix after latest35.
            return _stages(rotations, artistId, root, 0).cancelled;
        }
        if (current.facts.authorityClass != 3) return false;
        if (root != 0 && recovery.records[root].fields.vestedAuthorityClass == 3) return false;

        Estate.AuthorityCapabilities memory capabilities =
            IStreamArtistEstateOwner(address(this)).currentAuthorityCapabilities(artistId);
        bytes32 origin = capabilities.activationRecordHash;
        uint16 operation = recovery.vestingHistory.snapshots[origin].operationId;
        if (operation == 40) {
            // First-estate readers already absorbed their pre40 staging and cause history.
            // A preceding living35 was not an admitted first-estate origin profile.
            return root != 0;
        }
        if (operation != 43) return false;
        Staging memory stages = _stages(rotations, artistId, root, origin);
        if (!stages.cancelled) return false;
        Episodes memory episodes = _episodes(
            resolutions,
            e,
            artistId,
            current.facts.previousCauseHash,
            recovery.records[root].terms.expectedCauseHash
        );
        // The living35 and old-cancelled-notice boundary readers inspect every intervening
        // saved32 predecessor and selected episode. A pending estate in an episode was rejected.
        if (episodes.estate) return true;
        if (root != 0 || episodes.cancelledNotice) return stages.referenced;
        // The original zero/32-only dormancy boundary has no saved cause/resolution pair.
        // Plain cancelled requests (even before a prior32) leave that old encoding intact.
        return episodes.living;
    }

    function _stages(
        Rotations.State storage rotations,
        bytes32 artistId,
        bytes32 root,
        bytes32 stop
    ) private view returns (Staging memory f) {
        IStreamArtistNativeReceipts source = IStreamArtistNativeReceipts(address(this));
        bool selected = root == 0;
        uint256 count = source.artistNativeReceiptCount();
        for (uint256 i; i < count; ++i) {
            H.Receipt memory row = source.artistNativeReceiptAt(i);
            if (row.artistId != artistId) continue;
            if (row.operation == 35 && row.recordHash == root) selected = true;
            if (!selected) continue;
            if (stop != 0 && row.operation == 43 && row.recordHash == stop) return f;
            if (row.operation == 38 && _cancelled(row.recordHash, artistId)) f.cancelled = true;
            if (
                row.operation == 29
                    && _cancelled(
                        rotations.rotations[row.recordHash].terms
                        .expectedPreviousTransitionRecordHash,
                        artistId
                    )
            ) f.referenced = true;
        }
    }

    function _episodes(
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        bytes32 artistId,
        bytes32 cursor,
        bytes32 baseline
    ) private view returns (Episodes memory f) {
        while (cursor != baseline) {
            D.Cause memory cause = resolutions.causes[cursor];
            if (
                cursor == 0 || cause.causeHash != cursor || cause.facts.artistId != artistId
                    || cursor
                        != keccak256(
                            abi.encode(
                                keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                                e.chainId,
                                e.registry,
                                address(this),
                                cause.facts
                            )
                        )
            ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
            if (cause.facts.authorityClass == 1) {
                // A phase3 notice's own priorStatus2 episodes were already admitted by the
                // zero-baseline notice reader. Only an earlier ACTIVE pair changes that case.
                if (cause.facts.priorStatus == 1) f.living = true;
                if (_cancelled(cause.facts.pendingTransitionHash, artistId)) f.estate = true;
                if (cause.facts.priorStatus == 2) {
                    (, uint8 phase,) = IStreamArtistDormancyOwner(address(this))
                        .dormancyResolutionState(artistId, cursor);
                    if (phase == 2) f.cancelledNotice = true;
                }
            }
            cursor = cause.facts.previousCauseHash;
        }
    }

    function _cancelled(bytes32 hash, bytes32 artistId) private view returns (bool) {
        if (hash == 0) return false;
        (Estate.RequestRecord memory request, uint8 phase,) =
            IStreamArtistEstateOwner(address(this)).estateActivationRecord(hash);
        return request.recordHash == hash && request.terms.artistId == artistId && phase == 3;
    }
}

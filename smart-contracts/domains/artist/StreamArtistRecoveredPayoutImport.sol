// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredPayoutTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecoveredPayoutTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import { StreamArtistPayoutRecoveryState as S } from "./StreamArtistPayoutRecoveryState.sol";
import {
    StreamArtistRecoveredPayoutHydration as Codec
} from "./StreamArtistRecoveredPayoutHydration.sol";

/// @notice Exact empty-destination Payout installation for the separately authenticated profile.
/// @dev Called only by the fixed owner after operation60 source/provenance/lane authorization.
/// Replay keys, provenance and owner commits remain the common profile's responsibility.
library StreamArtistRecoveredPayoutImport {
    function importState(
        mapping(bytes32 => T.Payout) storage stable,
        mapping(bytes32 => T.PayoutDesignation) storage records,
        mapping(bytes32 => T.Payout) storage pending,
        mapping(bytes32 => R.ProvisionalAssociation) storage associations,
        mapping(bytes32 => bytes32) storage abandoned,
        S.State storage recovery,
        bytes32 artistId,
        bytes memory raw,
        RH.OwnerProvenance memory provenance
    ) public returns (bytes32 commitment) {
        P.Bundle memory b = Codec.decodeLocal(raw, provenance);
        if (
            artistId == 0 || b.artistId != artistId || stable[artistId].recordHash != 0
                || stable[artistId].account != address(0) || pending[artistId].recordHash != 0
                || pending[artistId].account != address(0)
                || recovery.statusCommitments[artistId] != 0
                || recovery.continuationHeads[artistId] != 0
        ) {
            revert P.InvalidRecoveredPayout(artistId);
        }
        T.PayoutDesignation memory emptyRecord;
        R.ProvisionalAssociation memory emptyAssociation;
        W.StatusV3 memory emptyStatus;
        for (uint256 i; i < b.records.length; ++i) {
            bytes32 hash = b.records[i].original.recordHash;
            if (
                keccak256(abi.encode(records[hash])) != keccak256(abi.encode(emptyRecord))
                    || keccak256(abi.encode(associations[hash]))
                        != keccak256(abi.encode(emptyAssociation)) || abandoned[hash] != 0
                    || keccak256(abi.encode(recovery.statuses[hash]))
                        != keccak256(abi.encode(emptyStatus))
                    || recovery.recordContinuations[hash] != 0
            ) revert P.InvalidRecoveredPayout(hash);
        }
        W.PayoutContinuationV3 memory emptyContinuation;
        for (uint256 i; i < b.continuations.length; ++i) {
            W.PayoutContinuationV3 memory c = b.continuations[i].continuation;
            if (
                keccak256(abi.encode(recovery.continuations[c.continuationHash]))
                        != keccak256(abi.encode(emptyContinuation))
                    || recovery.appliedRecoveries[c.recoveryRecordHash] != 0
            ) {
                revert P.InvalidRecoveredPayout(c.continuationHash);
            }
        }
        for (uint256 i; i < b.records.length; ++i) {
            P.RecordRow memory row = b.records[i];
            bytes32 hash = row.original.recordHash;
            records[hash] = row.original.terms;
            associations[hash] = row.association;
            abandoned[hash] = row.abandonedUnder;
            recovery.statuses[hash] = row.status;
            recovery.recordContinuations[hash] = row.continuationHash;
        }
        for (uint256 i; i < b.continuations.length; ++i) {
            P.ContinuationRow memory row = b.continuations[i];
            recovery.continuations[row.continuation.continuationHash] = row.continuation;
            recovery.appliedRecoveries[row.continuation.recoveryRecordHash] = row.appliedCommitment;
        }
        stable[artistId] = b.inventory.stable;
        pending[artistId] = b.inventory.candidate;
        recovery.statusCommitments[artistId] = b.inventory.supersessionStateCommitment;
        recovery.continuationHeads[artistId] = b.inventory.continuationCommitment;
        return keccak256(abi.encode(P.SCHEMA, b));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistCompleteHistoryPlatformTypes as Types
} from "./StreamArtistCompleteHistoryPlatformTypes.sol";
import {
    StreamArtistUnboundPlatformNativeRows as Rows
} from "./StreamArtistUnboundPlatformNativeRows.sol";
import {
    StreamArtistRecoveredPlatformNativeProof as Native
} from "./StreamArtistRecoveredPlatformNativeProof.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";

/// @notice Platform family proof used by the single complete Archive chronology.
/// @dev These helpers neither select a partial source nor authorize a binding. Proposal,
/// correction, collaborator and completion proofs use the same evolving collection cursor.
library StreamArtistCompleteHistoryPlatformProof {
    function nativeRows(P.Platform memory p, RH.OwnerProvenance memory owner4)
        public
        pure
        returns (D.Guard[] memory guards)
    {
        Types.requireRow(p, owner4);
        RH.Point memory point;
        if (
            (p.state.declaration.recordHash == 0
                    && keccak256(abi.encode(p.declarationPoint)) != keccak256(abi.encode(point)))
                || (p.state.correction.recordHash == 0
                    && keccak256(abi.encode(p.correctionPoint)) != keccak256(abi.encode(point)))
        ) _invalid();
        if (P.nativeCount(p) != 0) return Rows.validate(p, owner4);
        PW.State memory empty;
        PL.Status memory status;
        if (
            keccak256(abi.encode(p.state)) != keccak256(abi.encode(empty))
                || keccak256(abi.encode(p.status)) != keccak256(abi.encode(status))
                || keccak256(abi.encode(p.declarationPoint)) != keccak256(abi.encode(point))
                || keccak256(abi.encode(p.correctionPoint)) != keccak256(abi.encode(point))
                || p.allegationCount != 0 || p.latestAllegation != 0 || p.latestDisplayClaim != 0
                || p.continuations.length != 0
        ) _invalid();
        for (uint256 i; i < owner4.journal.length; ++i) {
            if (
                owner4.journal[i].receipt.collectionId == p.collectionId
                    && P.nativeOperation(owner4.journal[i].receipt.operation)
            ) _invalid();
        }
        guards = new D.Guard[](0);
    }

    function native(
        P.Platform memory p,
        P.Cursor memory cursor,
        RH.OwnerProvenance memory owner4,
        uint256 era,
        H.Envelope memory envelope
    ) public pure returns (P.Cursor memory) {
        Types.requireRow(p, owner4);
        if (
            !P.nativeOperation(envelope.operation)
                || abi.decode(envelope.payload, (uint256)) != p.collectionId
                || (envelope.operation == 8 && cursor.generation != 0)
        ) _invalid();
        cursor.state = Native.advanceWithRecords(p, cursor.state, owner4, era, envelope);
        cursor.status.originalCorrectionRecord = cursor.state.correction.recordHash;
        return cursor;
    }

    /// @notice Advance only when the original complete binding acceptance actually occurred.
    /// @dev For an op7 completion, completionRecord is its collaborator receipt. The primary
    /// acceptance can predate this write. The original stored lineage time is authenticated by
    /// the resulting hash in the exact owner4 transition, not substituted from the primary map.
    function complete(
        P.Platform memory p,
        P.Cursor memory cursor,
        T.Binding memory binding,
        bytes32 completionRecord,
        RH.OriginEnvironment memory origin
    ) public pure returns (P.Cursor memory, bytes32 continuation) {
        if (
            binding.generation == 0 || binding.generation != cursor.generation
                || completionRecord == 0 || cursor.completed
        ) _invalid();
        if (
            cursor.status.latestLineageRecord != 0 && cursor.status.generation == binding.generation
        ) {
            if (cursor.continuations == 0 || cursor.continuations > p.continuations.length) {
                _invalid();
            }
            P.ContinuationRow memory row = p.continuations[cursor.continuations - 1];
            if (
                row.record.recordHash != cursor.status.latestLineageRecord
                    || row.record.collectionId != p.collectionId
                    || row.record.generation != binding.generation
                    || row.record.bindingHash != binding.bindingHash
                    || row.record.artistId != binding.artistId
                    || row.record.artist != binding.artistAddress || row.acceptance.acceptedAt == 0
            ) _invalid();
            PL.Acceptance memory expected = PL.Acceptance(
                0, row.record.recordHash, completionRecord, row.acceptance.acceptedAt
            );
            expected.recordHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_PLATFORM_BINDING_CONTINUATION_ACCEPTANCE_V1"),
                    origin.chainId,
                    origin.owners[4],
                    p.collectionId,
                    binding.generation,
                    expected
                )
            );
            if (keccak256(abi.encode(expected)) != keccak256(abi.encode(row.acceptance))) {
                _invalid();
            }
            continuation = expected.recordHash;
            cursor.status.latestAcceptanceRecord = continuation;
            cursor.status.effectiveAccepted = true;
        } else if (cursor.state.declaration.recordHash != 0) {
            if (
                cursor.state.correction.correctiveGeneration != binding.generation
                    || cursor.state.correction.accepted
                    || cursor.state.correction.proposedArtist != binding.artistAddress
            ) _invalid();
            cursor.state.correction.accepted = true;
            cursor.status.effectiveAccepted = true;
        }
        return (cursor, continuation);
    }

    function finish(P.Platform memory p, P.Cursor memory cursor, CB.Bundle memory bindings)
        public
        pure
    {
        uint256 count = bindings.bindings.rows.length;
        if (
            p.collectionId == 0 || p.catalogues.length != 0 || p.operations.length != 0
                || bindings.bindings.collectionId != p.collectionId || cursor.generation != count
                || cursor.continuations != p.continuations.length
                || keccak256(abi.encode(cursor.state)) != keccak256(abi.encode(p.state))
                || keccak256(abi.encode(cursor.status)) != keccak256(abi.encode(p.status))
        ) _invalid();
        if (p.state.declaration.recordHash != 0) {
            uint64 generation = p.state.correction.correctiveGeneration;
            if (count == 0) {
                if (generation != 0 || p.state.correction.accepted || p.continuations.length != 0) {
                    _invalid();
                }
            } else {
                if (generation == 0 || generation > count) _invalid();
                T.Binding memory bound = bindings.bindings.rows[generation - 1].item;
                if (
                    p.state.correction.recordHash == 0 || bound.artistId == 0
                        || bound.generation != generation
                        || bound.artistAddress != p.state.correction.proposedArtist
                        || bound.accepted != p.state.correction.accepted
                ) _invalid();
            }
        } else if (p.continuations.length != 0 || p.state.correction.correctiveGeneration != 0) {
            _invalid();
        }
        PL.Acceptance memory empty;
        for (uint256 i; i < p.continuations.length; ++i) {
            P.ContinuationRow memory row = p.continuations[i];
            uint64 generation = row.record.generation;
            if (generation == 0 || generation > count) _invalid();
            T.Binding memory bound = bindings.bindings.rows[generation - 1].item;
            if (
                row.record.collectionId != p.collectionId
                    || row.record.bindingHash != bound.bindingHash
                    || row.record.artistId != bound.artistId
                    || row.record.artist != bound.artistAddress
                    || (bound.accepted && row.acceptance.recordHash == 0)
                    || (!bound.accepted
                        && keccak256(abi.encode(row.acceptance)) != keccak256(abi.encode(empty)))
            ) _invalid();
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

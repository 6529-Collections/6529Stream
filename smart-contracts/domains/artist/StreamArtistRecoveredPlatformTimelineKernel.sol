// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformCatalogue as Catalogue
} from "./StreamArtistRecoveredPlatformCatalogue.sol";
import {
    StreamArtistRecoveredPlatformNativeProof as Native
} from "./StreamArtistRecoveredPlatformNativeProof.sol";
import {
    StreamArtistRecoveredPlatformProposalProof as Proposal
} from "./StreamArtistRecoveredPlatformProposalProof.sol";
import {
    StreamArtistRecoveredPlatformCompletionProof as Completion
} from "./StreamArtistRecoveredPlatformCompletionProof.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Fixed shared original/record-history validation body; all full typed inputs are retained.
library StreamArtistRecoveredPlatformTimelineKernel {
    function validate(
        P.Platform memory b,
        CB.Bundle memory bindings,
        A.Generation[] memory generations,
        RH.OwnerProvenance memory p,
        bool includeRecords
    ) public view returns (RH.Point[] memory proposals, RH.Point[] memory completions) {
        Catalogue.requireLocal(p, 4, b.catalogues, b.operations);
        proposals = new RH.Point[](generations.length);
        completions = new RH.Point[](generations.length);
        P.Cursor memory c;
        uint256 nativeCount;
        uint256 previousEra;
        uint64 previousRevision;
        for (uint256 i; i < b.operations.length; ++i) {
            H.OperationEvidence memory row = b.operations[i];
            uint256 era = A.era(p, row.originHash);
            H.Envelope memory e = Catalogue.read(p.origins[era], b.catalogues[era], row.evidence);
            if (
                row.operation != e.operation || era < previousEra
                    || (i != 0 && era == previousEra && e.after_[4].revision <= previousRevision)
            ) _invalid();
            previousEra = era;
            previousRevision = e.after_[4].revision;
            RH.Point memory point = RH.Point(row.originHash, 4, previousRevision);
            if (P.nativeOperation(e.operation)) {
                if (e.operation == 8 && c.generation != 0) _invalid();
                c.state = includeRecords
                    ? Native.advanceWithRecords(b, c.state, p, era, e)
                    : Native.advance(b, c.state, p, era, e);
                c.status.originalCorrectionRecord = c.state.correction.recordHash;
                ++nativeCount;
            } else {
                _snapshots(b.catalogues[era], e);
                if (e.operation == 1) {
                    c = includeRecords
                        ? Proposal.advanceWithRecords(b, bindings, generations, c, p, era, e)
                        : Proposal.advance(b, bindings, generations, c, p, era, e);
                    proposals[c.generation - 1] = point;
                } else {
                    c = includeRecords
                        ? Completion.advanceWithRecords(b, bindings, generations, c, p, era, e)
                        : Completion.advance(b, bindings, generations, c, p, era, e);
                    completions[c.generation - 1] = point;
                }
            }
        }
        if (
            nativeCount != P.nativeCount(b) || c.generation != generations.length || !c.completed
                || c.continuations != b.continuations.length
                || keccak256(abi.encode(c.state)) != keccak256(abi.encode(b.state))
                || keccak256(abi.encode(c.status)) != keccak256(abi.encode(b.status))
        ) _invalid();
        PL.Acceptance memory empty;
        for (uint256 i; i < b.continuations.length; ++i) {
            uint64 g = b.continuations[i].record.generation;
            if (g == 0 || g > generations.length) _invalid();
            if (
                !generations[g - 1].accepted
                    && keccak256(abi.encode(b.continuations[i].acceptance))
                        != keccak256(abi.encode(empty))
            ) {
                _invalid();
            }
        }
    }

    function _snapshots(P.Catalogue memory c, H.Envelope memory e) private pure {
        uint256 mask = e.operation == 2 ? 0x1f : e.operation == 4 ? 0x11 : 0x15;
        T.Snapshot memory zero;
        for (uint8 i; i < 7; ++i) {
            T.Snapshot memory before_ = e.before_[i];
            T.Snapshot memory after_ = e.after_[i];
            if ((mask & (1 << i)) == 0) {
                if (
                    keccak256(abi.encode(before_)) != keccak256(abi.encode(zero))
                        || keccak256(abi.encode(after_)) != keccak256(abi.encode(zero))
                ) _invalid();
            } else {
                if (
                    before_.domainId != RH.ownerDomain(i) || after_.domainId != RH.ownerDomain(i)
                        || before_.stateRoot == 0 || before_.recordChainTip == 0
                        || after_.stateRoot == 0 || after_.recordChainTip == 0
                        || before_.revision < c.lower[i] || after_.revision > c.upper[i]
                        || after_.revision < before_.revision
                        || after_.revision > before_.revision + 1
                ) {
                    _invalid();
                }
                if (i == 1 || (i == 2 && e.operation == 1 && after_.revision == before_.revision)) {
                    if (keccak256(abi.encode(before_)) != keccak256(abi.encode(after_))) {
                        _invalid();
                    }
                } else if (after_.revision != before_.revision + 1) {
                    _invalid();
                }
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

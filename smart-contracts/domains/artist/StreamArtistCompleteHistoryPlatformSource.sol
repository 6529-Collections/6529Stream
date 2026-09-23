// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistCompleteHistoryCatalogue as Catalogue
} from "./StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistCompleteHistoryPlatformProof as Proof
} from "./StreamArtistCompleteHistoryPlatformProof.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    IStreamArtistPlatformOwner as Platform
} from "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import {
    IStreamArtistPlatformCorrectionLineage as Lineage,
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    IStreamArtistAttributionClaimsOwner as Claims
} from "../../interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import {
    IStreamUnboundPlatformClaimHead as Head
} from "../../interfaces/stream/artist/IStreamUnboundPlatformClaimHead.sol";

/// @notice Complete Platform collection projections over one authentic whole-owner journal.
/// @dev Bound siblings retain arbitrary admitted binding/dispute/collaborator histories.
/// Shared clocks prove the declaration's consumption and every continuation after collection.
library StreamArtistCompleteHistoryPlatformSource {
    function collect(
        address source,
        M.State memory scope,
        RH.OwnerProvenance memory owner4,
        P.Catalogue[] memory catalogues,
        H.OperationEvidence[] memory operations
    ) public view returns (P.Platform[] memory rows) {
        Provenance.validateOwnerSource(owner4, 4, source);
        Catalogue.requireLocal(owner4, 4, catalogues, operations);
        _partition(scope, owner4);
        rows = new P.Platform[](scope.collections.length);
        for (uint256 k; k < rows.length; ++k) {
            rows[k] = _collection(source, scope.collections[k].collectionId, owner4);
            // Reproduce the original records and native replay coordinates before any
            // lifecycle fields are trusted by the shared Archive chronology.
            Proof.nativeRows(rows[k], owner4);
        }
    }

    function requireCurrent(
        address source,
        M.State memory scope,
        RH.OwnerProvenance memory owner4,
        P.Catalogue[] memory catalogues,
        H.OperationEvidence[] memory operations,
        P.Platform[] memory expected
    ) public view {
        P.Platform[] memory current = collect(source, scope, owner4, catalogues, operations);
        if (keccak256(abi.encode(current)) != keccak256(abi.encode(expected))) _invalid();
    }

    function _partition(M.State memory scope, RH.OwnerProvenance memory owner4) private pure {
        for (uint256 k; k < scope.collections.length; ++k) {
            if (scope.collections[k].collectionId == 0) _invalid();
            for (uint256 j; j < k; ++j) {
                if (scope.collections[k].collectionId == scope.collections[j].collectionId) {
                    _invalid();
                }
            }
        }
        for (uint256 i; i < owner4.journal.length; ++i) {
            RH.JournalEntry memory entry = owner4.journal[i];
            if (!P.nativeOperation(entry.receipt.operation)) continue;
            if (entry.receipt.artistId != 0) _invalid();
            uint256 matches;
            for (uint256 k; k < scope.collections.length; ++k) {
                if (scope.collections[k].collectionId == entry.receipt.collectionId) ++matches;
            }
            if (matches != 1) _invalid();
        }
    }

    function _collection(address source, uint256 id, RH.OwnerProvenance memory owner4)
        private
        view
        returns (P.Platform memory p)
    {
        p.provenance = RH.ownerProvenanceHash(owner4, 4);
        p.collectionId = id;
        p.state = Platform(source).platformWorksState(id);
        uint256 claims;
        uint256 contests;
        uint256 allegations;
        for (uint256 i; i < owner4.journal.length; ++i) {
            RH.JournalEntry memory j = owner4.journal[i];
            if (j.receipt.collectionId != id) continue;
            if (j.receipt.operation == 9) ++claims;
            else if (j.receipt.operation == 10) ++allegations;
            else if (j.receipt.operation == 11) ++contests;
        }
        if (claims + contests + allegations > RH.MAX_JOURNAL_ENTRIES) _invalid();
        p.claims = new P.ClaimRow[](claims);
        p.contests = new P.ContestRow[](contests);
        p.allegations = new P.AttributionClaimRow[](allegations);
        claims = 0;
        contests = 0;
        allegations = 0;
        for (uint256 i; i < owner4.journal.length; ++i) {
            RH.JournalEntry memory j = owner4.journal[i];
            uint16 op = j.receipt.operation;
            if (j.receipt.collectionId != id || !P.nativeOperation(op)) continue;
            if (op == 8) {
                if (
                    p.declarationPoint.ownerRevision != 0
                        || j.receipt.recordHash != p.state.declaration.recordHash
                ) _invalid();
                p.declarationPoint = j.position.point;
            } else if (op == 9) {
                p.claims[claims++] = P.ClaimRow(
                    j.position.point,
                    Platform(source).platformWorksClaimRecord(j.receipt.recordHash)
                );
            } else if (op == 10) {
                p.allegations[allegations++] = P.AttributionClaimRow(
                    j.position.point, Claims(source).attributionClaimRecord(j.receipt.recordHash)
                );
            } else if (op == 11) {
                p.contests[contests++] = P.ContestRow(
                    j.position.point,
                    Platform(source).platformWorksContestRecord(j.receipt.recordHash)
                );
            } else {
                if (
                    p.correctionPoint.ownerRevision != 0
                        || j.receipt.recordHash != p.state.correction.recordHash
                ) _invalid();
                p.correctionPoint = j.position.point;
            }
        }
        p.allegationCount = allegations;
        p.latestAllegation =
            allegations == 0 ? bytes32(0) : p.allegations[allegations - 1].record.recordHash;
        (uint256 total, bytes32 latest) = Head(source).attributionClaims(id);
        if (total != claims + allegations || p.state.claimCount != claims) _invalid();
        p.latestDisplayClaim = latest;
        p.status = Lineage(source).platformCorrectionStatus(id);
        if (p.status.count > P.MAX_ROWS) _invalid();
        p.continuations = new P.ContinuationRow[](p.status.count);
        bytes32 cursor = p.status.latestLineageRecord;
        for (uint256 i = p.continuations.length; i != 0; --i) {
            PL.Record memory r = Lineage(source).platformCorrectionLineage(cursor);
            if (cursor == 0 || r.recordHash != cursor || r.collectionId != id) _invalid();
            p.continuations[i - 1] =
                P.ContinuationRow(r, Lineage(source).platformCorrectionAcceptance(cursor));
            cursor = r.previousLineageRecord;
        }
        if (cursor != 0) _invalid();
        // The enclosing complete inventory owns these arrays exactly once.
        p.catalogues = new P.Catalogue[](0);
        p.operations = new H.OperationEvidence[](0);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

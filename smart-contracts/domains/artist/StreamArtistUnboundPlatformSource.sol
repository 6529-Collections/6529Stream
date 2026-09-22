// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformCatalogue as Catalogue
} from "./StreamArtistRecoveredPlatformCatalogue.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
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
    IStreamUnboundPlatformClaimHead
} from "../../interfaces/stream/artist/IStreamUnboundPlatformClaimHead.sol";

/// @notice Complete original Platform keys come only from the authenticated native journal/head.
library StreamArtistUnboundPlatformSource {
    function collect(address source, AH.Query memory q, RH.Provenance memory full)
        public
        view
        returns (P.Platform memory p)
    {
        RH.OwnerProvenance memory local = RH.ownerProvenance(full, 4);
        Provenance.validateOwnerSource(local, 4, source);
        p.provenance = RH.ownerProvenanceHash(local, 4);
        p.collectionId = q.collectionId;
        p.state = Platform(source).platformWorksState(q.collectionId);
        if (
            q.artistId != 0 || q.bindingHash != 0 || q.policies.length != 0
                || p.state.declaration.recordHash == 0
                || p.state.correction.correctiveGeneration != 0 || p.state.correction.accepted
        ) _invalid();
        uint256 claims;
        uint256 contests;
        uint256 allegations;
        for (uint256 i; i < local.journal.length; ++i) {
            if (local.journal[i].receipt.collectionId != q.collectionId) continue;
            uint16 op = local.journal[i].receipt.operation;
            if (op == 9) ++claims;
            else if (op == 11) ++contests;
            else if (op == 10) ++allegations;
        }
        if (claims + contests + allegations > RH.MAX_JOURNAL_ENTRIES) _invalid();
        p.claims = new P.ClaimRow[](claims);
        p.contests = new P.ContestRow[](contests);
        p.allegations = new P.AttributionClaimRow[](allegations);
        claims = 0;
        contests = 0;
        allegations = 0;
        for (uint256 i; i < local.journal.length; ++i) {
            RH.JournalEntry memory j = local.journal[i];
            uint16 op = j.receipt.operation;
            if (!P.nativeOperation(op) || j.receipt.collectionId != q.collectionId) continue;
            if (j.receipt.artistId != 0 || j.receipt.collectionId != q.collectionId) _invalid();
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
        (uint256 total, bytes32 latest) =
            IStreamUnboundPlatformClaimHead(source).attributionClaims(q.collectionId);
        if (total != claims + allegations || p.state.claimCount != claims) _invalid();
        p.latestDisplayClaim = latest;
        p.status = Lineage(source).platformCorrectionStatus(q.collectionId);
        PL.Status memory expected;
        expected.originalCorrectionRecord = p.state.correction.recordHash;
        if (keccak256(abi.encode(p.status)) != keccak256(abi.encode(expected))) _invalid();
        p.continuations = new P.ContinuationRow[](p.status.count);
        bytes32 cursor = p.status.latestLineageRecord;
        for (uint256 i = p.continuations.length; i != 0; --i) {
            PL.Record memory r = Lineage(source).platformCorrectionLineage(cursor);
            if (cursor == 0 || r.recordHash != cursor) _invalid();
            p.continuations[i - 1] =
                P.ContinuationRow(r, Lineage(source).platformCorrectionAcceptance(cursor));
            cursor = r.previousLineageRecord;
        }
        if (cursor != 0) _invalid();
        (p.catalogues, p.operations) = Catalogue.collect(full);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

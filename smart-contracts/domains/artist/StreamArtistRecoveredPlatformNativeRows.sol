// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistAttributionClaimTypes as AC
} from "../../interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Original collection-only native records, exact source domains and all replay subjects.
/// @dev The separate Archive timeline proves fields outside record hashes and op1/op2 mutations.
library StreamArtistRecoveredPlatformNativeRows {
    struct Cursor {
        PW.State state;
        uint256 claims;
        uint256 contests;
        uint256 allegations;
        bytes32 allegation;
        bytes32 display;
    }

    function validate(P.Platform memory b, RH.OwnerProvenance memory p)
        public
        pure
        returns (D.Guard[] memory guards)
    {
        if (
            b.collectionId == 0 || b.provenance != RH.ownerProvenanceHash(p, 4)
                || P.nativeCount(b) == 0 || P.nativeCount(b) > RH.MAX_JOURNAL_ENTRIES
        ) _invalid();
        guards = new D.Guard[](P.nativeCount(b));
        uint256 n;
        Cursor memory c;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            uint16 op = j.receipt.operation;
            if (!P.nativeOperation(op)) continue;
            if (
                j.receipt.artistId != 0 || j.receipt.collectionId != b.collectionId
                    || n == guards.length
            ) _invalid();
            Clock.validateOwnerPoint(p, 4, j.position.point);
            RH.OriginEnvironment memory o = p.origins[A.era(p, j.position.point.environmentHash)];
            bytes32 scope;
            if (op == 8) scope = _declare(b, j, o, c);
            else if (op == 9) scope = _claim(b, j, o, c);
            else if (op == 10) scope = _allegation(b, j, o, c);
            else if (op == 11) scope = _contest(b, j, o, c);
            else scope = _correction(b, j, o, c);
            bytes32 surface = op == 10
                ? keccak256("attribution_lifecycle.replay.claim_record_hash_uniqueness")
                : keccak256(abi.encode("PLATFORM_WORKS", op));
            guards[n++] = D.Guard(surface, scope, j.receipt.recordHash, j.position.point);
        }
        // Copy before clearing the two lifecycle fields: no mutation of the retained Bundle.
        PW.State memory expected = abi.decode(abi.encode(b.state), (PW.State));
        expected.correction.correctiveGeneration = 0;
        expected.correction.accepted = false;
        if (
            n != guards.length || c.claims != b.claims.length || c.contests != b.contests.length
                || c.allegations != b.allegations.length || c.allegations != b.allegationCount
                || c.allegation != b.latestAllegation || c.display != b.latestDisplayClaim
                || keccak256(abi.encode(c.state)) != keccak256(abi.encode(expected))
        ) _invalid();
        for (uint256 i; i < guards.length; ++i) {
            for (uint256 k; k < i; ++k) {
                if (guards[i].surface == guards[k].surface && guards[i].scope == guards[k].scope) {
                    _invalid();
                }
            }
        }
        // Contest and correction use one shared original governance-action cell.
        for (uint256 i; i < b.contests.length; ++i) {
            bytes32 action = b.contests[i].record.actionId;
            if (action == b.state.correction.approvalActionId) _invalid();
            for (uint256 k; k < i; ++k) {
                if (b.contests[k].record.actionId == action) _invalid();
            }
        }
    }

    function _declare(
        P.Platform memory b,
        RH.JournalEntry memory j,
        RH.OriginEnvironment memory o,
        Cursor memory c
    ) private pure returns (bytes32) {
        PW.Declaration memory r = b.state.declaration;
        if (
            c.state.declaration.recordHash != 0 || r.recordHash == 0 || r.statementHash == 0
                || r.actor == address(0) || !D.samePoint(b.declarationPoint, j.position.point)
                || j.receipt.recordHash != r.recordHash
                || r.recordHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PLATFORM_WORKS_DECLARATION_V1"),
                            o.chainId,
                            o.registry,
                            o.core,
                            b.collectionId,
                            r.statementHash,
                            r.declaredAt
                        )
                    )
        ) _invalid();
        c.state.declaration = r;
        return bytes32(b.collectionId);
    }

    function _claim(
        P.Platform memory b,
        RH.JournalEntry memory j,
        RH.OriginEnvironment memory o,
        Cursor memory c
    ) private pure returns (bytes32 scope) {
        if (c.claims == b.claims.length) _invalid();
        P.ClaimRow memory row = b.claims[c.claims++];
        PW.Claim memory r = row.record;
        if (
            c.state.declaration.recordHash == 0 || r.collectionId != b.collectionId
                || r.claimant == address(0) || r.evidenceHash == 0 || r.reasonHash == 0
                || !D.samePoint(row.point, j.position.point) || r.recordHash != j.receipt.recordHash
                || r.recordHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PLATFORM_WORKS_CLAIM_RECORD_V1"),
                            o.chainId,
                            o.registry,
                            o.core,
                            b.collectionId,
                            r.claimant,
                            r.evidenceHash,
                            r.reasonHash,
                            r.filedAt
                        )
                    )
        ) _invalid();
        ++c.state.claimCount;
        c.state.latestClaim = r.recordHash;
        c.display = r.recordHash;
        return keccak256(abi.encode(b.collectionId, r.claimant, r.evidenceHash, r.reasonHash));
    }

    function _allegation(
        P.Platform memory b,
        RH.JournalEntry memory j,
        RH.OriginEnvironment memory o,
        Cursor memory c
    ) private pure returns (bytes32 scope) {
        if (c.allegations == b.allegations.length) _invalid();
        P.AttributionClaimRow memory row = b.allegations[c.allegations++];
        AC.Claim memory r = row.record;
        if (
            r.collectionId != b.collectionId || r.claimant == address(0) || r.evidenceHash == 0
                || r.reasonHash == 0 || r.filedAt == 0 || bytes(r.reasonURI).length > 4096
                || r.index != c.allegations || r.previousRecordHash != c.allegation
                || !D.samePoint(row.point, j.position.point) || r.recordHash != j.receipt.recordHash
                || r.recordHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_ATTRIBUTION_CLAIM_RECORD_V1"),
                            o.chainId,
                            o.registry,
                            o.core,
                            b.collectionId,
                            r.claimant,
                            r.evidenceHash,
                            r.reasonHash,
                            r.filedAt
                        )
                    )
        ) _invalid();
        c.allegation = r.recordHash;
        c.display = r.recordHash;
        return keccak256(abi.encode(b.collectionId, r.claimant, r.evidenceHash, r.reasonHash));
    }

    function _contest(
        P.Platform memory b,
        RH.JournalEntry memory j,
        RH.OriginEnvironment memory o,
        Cursor memory c
    ) private pure returns (bytes32 scope) {
        if (c.contests == b.contests.length) _invalid();
        P.ContestRow memory row = b.contests[c.contests++];
        PW.Contest memory r = row.record;
        if (
            c.state.declaration.recordHash == 0 || r.collectionId != b.collectionId
                || r.evidenceHash == 0 || r.reasonHash == 0 || r.actionId == 0
                || r.previousRecordHash != c.state.contestRecord
                || !D.samePoint(row.point, j.position.point) || r.recordHash != j.receipt.recordHash
                || (r.state == 1
                        ? (c.state.contestState != 0 && c.state.contestState != 2)
                        : ((r.state != 2 && r.state != 3)
                            || c.state.contestState != 1
                            || c.state.contestClaim != r.claimRecordHash))
        ) _invalid();
        bool found;
        for (uint256 k; k < c.claims; ++k) {
            if (b.claims[k].record.recordHash == r.claimRecordHash) found = true;
        }
        if (
            !found
                || r.recordHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PLATFORM_WORKS_CONTEST_TRANSITION_V1"),
                            o.chainId,
                            o.owners[4],
                            PW.Contest(
                                r.collectionId,
                                r.adjudicatedArtist,
                                r.state,
                                r.claimRecordHash,
                                r.evidenceHash,
                                r.reasonHash,
                                r.actionId,
                                r.previousRecordHash,
                                r.changedAt,
                                0
                            )
                        )
                    )
        ) {
            _invalid();
        }
        c.state.contestState = r.state;
        c.state.contestClaim = r.claimRecordHash;
        c.state.contestRecord = r.recordHash;
        return keccak256(abi.encode(b.collectionId, r.actionId));
    }

    function _correction(
        P.Platform memory b,
        RH.JournalEntry memory j,
        RH.OriginEnvironment memory o,
        Cursor memory c
    ) private pure returns (bytes32 scope) {
        PW.Correction memory r = b.state.correction;
        if (
            c.state.correction.recordHash != 0 || c.state.contestState != 3 || c.contests == 0
                || r.collectionId != b.collectionId || r.claimRecordHash != c.state.contestClaim
                || r.sustainedContestRecordHash != c.state.contestRecord
                || r.proposedArtist == address(0)
                || r.proposedArtist != b.contests[c.contests - 1].record.adjudicatedArtist
                || r.evidenceHash == 0 || r.reasonHash == 0 || r.approvalActionId == 0
                || !D.samePoint(b.correctionPoint, j.position.point)
                || r.recordHash != j.receipt.recordHash
                || r.recordHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PLATFORM_WORKS_CORRECTION_RECORD_V1"),
                            o.chainId,
                            o.registry,
                            o.core,
                            b.collectionId,
                            r.sustainedContestRecordHash,
                            r.claimRecordHash,
                            r.evidenceHash,
                            r.reasonHash,
                            r.approvalActionId,
                            r.approvedAt
                        )
                    )
        ) {
            _invalid();
        }
        c.state.correction = PW.Correction(
            r.collectionId,
            r.proposedArtist,
            r.claimRecordHash,
            r.sustainedContestRecordHash,
            r.evidenceHash,
            r.reasonHash,
            r.approvalActionId,
            r.approvedAt,
            0,
            false,
            r.recordHash
        );
        return keccak256(abi.encode(b.collectionId, r.approvalActionId));
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

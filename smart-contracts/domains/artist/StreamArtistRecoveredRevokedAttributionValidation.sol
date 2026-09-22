// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as P
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import { StreamArtistDisputeHashes as H } from "./StreamArtistDisputeHashes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";

/// @notice Closed original governed opening/revocation history, without projecting any source rows.
library StreamArtistRecoveredRevokedAttributionValidation {
    bytes32 private constant OPEN = keccak256("attribution_lifecycle.replay.dispute_key");
    bytes32 private constant RESOLVE =
        keccak256("attribution_lifecycle.replay.dispute_resolution_key");
    bytes32 private constant GOVERNANCE =
        keccak256("attribution_lifecycle.replay.governance_action");

    function validate(A.AttributionBundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
    {
        if (
            P.validateOwner(p, 4) != b.provenance || b.artistId != q.artistId
                || b.collectionId != q.collectionId || b.bindingHash != q.bindingHash
                || q.artistId == 0 || q.collectionId == 0 || q.bindingHash == 0
                || b.current.state != 2 || b.current.generation != b.generations.length
                || b.generations.length < 2 || b.generations.length > 128
                || b.revocations.length == 0 || b.revocations.length != p.journal.length
        ) _invalid();
        uint256[] memory claims = new uint256[](p.eras.length);
        uint256[] memory revokes = new uint256[](p.eras.length);
        uint256 previousEra;
        for (uint256 i; i < b.generations.length; ++i) {
            A.Generation memory g = b.generations[i];
            uint256 e = A.era(p, g.proposal.environmentHash);
            if (
                g.generation != i + 1 || g.bindingHash == 0 || g.proposal.ownerIndex != 0
                    || g.proposal.ownerRevision == 0 || e < previousEra
            ) _invalid();
            previousEra = e;
            ++claims[e];
            if (i + 1 == b.generations.length && (!g.accepted || g.bindingHash != q.bindingHash)) _invalid();
        }
        uint256 cursor;
        for (uint256 i; i + 1 < b.generations.length; ++i) {
            if (!b.generations[i].accepted) continue;
            if (cursor >= b.revocations.length) _invalid();
            A.Revocation memory r = b.revocations[cursor];
            RH.JournalEntry memory j = p.journal[cursor++];
            uint256 e = A.era(p, j.position.point.environmentHash);
            // No import can commit a disputed/revoked collection. Its terminating resolution
            // and next corrective proposal belong to the same original owner era.
            if (e != A.era(p, b.generations[i + 1].proposal.environmentHash)) _invalid();
            uint256 priorClaims;
            for (uint256 k; k <= i; ++k) {
                if (b.generations[k].proposal.environmentHash == p.eras[e].originHash) ++priorClaims;
            }
            uint64 revision = uint64((e == 0 ? 0 : 1) + 2 * priorClaims + 2 * revokes[e] + 1);
            if (
                j.receipt.operation != 44 || j.receipt.recordHash != r.opening.recordHash
                    || j.receipt.artistId != q.artistId || j.receipt.collectionId != q.collectionId
                    || j.position.point.ownerRevision != revision
            ) _invalid();
            _row(r, b.generations[i], q, p.origins[e]);
            ++revokes[e];
        }
        if (cursor != b.revocations.length) _invalid();
        uint256 total;
        for (uint256 e; e < p.eras.length; ++e) {
            total += revokes[e];
            RH.OwnerEra memory era_ = p.eras[e];
            if (
                era_.lowerRevision != (e == 0 ? 0 : 1) || era_.nativeCount != revokes[e]
                    || era_.checkpoint.ownerState.revision
                        != era_.lowerRevision + 2 * claims[e] + 2 * revokes[e]
                    || era_.checkpoint.replayCount != 4 * total
                    || era_.checkpoint.nonceIndexCount != 0 || era_.checkpoint.nonceRoot != 0
            ) _invalid();
        }
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            bool found;
            for (uint256 j; j < b.revocations.length; ++j) {
                A.Revocation memory r = b.revocations[j];
                bytes32 expected;
                bool resolution;
                if (
                    a.surface == OPEN
                        && a.scope
                            == keccak256(
                                abi.encode(
                                    q.collectionId,
                                    r.opening.terms.bindingGeneration,
                                    bytes32(0),
                                    r.opening.signer,
                                    r.opening.terms.evidenceHash,
                                    r.opening.terms.reasonHash
                                )
                            )
                ) {
                    expected = r.opening.recordHash;
                } else if (a.surface == RESOLVE && a.scope == r.opening.recordHash) {
                    expected = r.resolution.actionId;
                    resolution = true;
                } else if (a.surface == GOVERNANCE && a.scope == r.opening.governanceActionId) {
                    expected = r.opening.recordHash;
                } else if (a.surface == GOVERNANCE && a.scope == r.resolution.actionId) {
                    expected = r.opening.recordHash;
                    resolution = true;
                } else {
                    continue;
                }
                // Both resolution aliases refer to opening + 1. Copy its original point:
                // a memory reference would advance the journal again for the next alias.
                RH.Point memory recorded = p.journal[j].position.point;
                RH.Point memory point = RH.Point(
                    recorded.environmentHash, recorded.ownerIndex, recorded.ownerRevision
                );
                if (resolution) ++point.ownerRevision;
                if (
                    a.cell.kind != 1 || a.cell.status != 2 || a.cell.commitment != expected
                        || keccak256(abi.encode(a.admittedAt)) != keccak256(abi.encode(point))
                ) _invalid();
                found = true;
                break;
            }
            if (!found) _invalid();
        }
    }

    function _row(
        A.Revocation memory r,
        A.Generation memory g,
        AH.Query memory q,
        RH.OriginEnvironment memory o
    ) private pure {
        AD.Record memory a = r.opening;
        AD.Resolution memory d = r.resolution;
        AD.Head memory h = r.head;
        AD.Standing memory empty;
        if (
            a.recordHash == 0 || a.terms.collectionId != q.collectionId
                || a.terms.bindingGeneration != g.generation || a.terms.disputeAction != 1
                || a.terms.evidenceHash == 0 || a.terms.reasonHash == 0 || a.signer == address(0)
                || a.authorityClass != 0 || a.nonce != 0 || a.recordedAt == 0
                || a.artistId != q.artistId || a.bindingHash != g.bindingHash
                || a.disputeRecordHash != a.recordHash || a.previousRecordHash != 0
                || keccak256(abi.encode(a.standing)) != keccak256(abi.encode(empty))
                || a.governanceActionId == 0
                || a.recordHash
                    != H.record(
                        Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                        a.terms,
                        a.signer,
                        0,
                        0,
                        a.recordedAt
                    )
        ) _invalid();
        if (
            h.disputeRecordHash != a.recordHash || h.counterStatementRecordHash != 0
                || h.resolutionActionId != d.actionId || h.restoreState != 2
                || h.revocationReason != 4 || h.open || h.reopened || d.actionId == 0
                || d.actionId == a.governanceActionId || d.actor == address(0)
                || d.proposer == address(0) || d.actionClass != 2 || d.restoredState != 5
                || d.resolvedAt < a.recordedAt || d.previousResolutionActionId != 0
                || d.witnessHash == 0 || d.terms.collectionId != q.collectionId
                || d.terms.bindingGeneration != g.generation
                || d.terms.disputeRecordHash != a.recordHash || d.terms.resolution != 2
                || d.terms.evidenceHash == 0 || d.terms.reasonHash == 0
                || d.terms.counterStatementRecordHash != 0
        ) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

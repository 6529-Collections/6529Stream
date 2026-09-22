// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistDisputeWithdrawalTypes as W
} from "../../interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import { StreamArtistDisputeHashes as H } from "./StreamArtistDisputeHashes.sol";
import { StreamArtistRepudiationHashes as RHash } from "./StreamArtistRepudiationHashes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";

/// @notice Original dispute and repudiation predicates shared by singleton and aggregate proofs.
library StreamArtistRecoveredDisputeHistoryRowFacts {
    function dispute(D.Bundle memory b, D.DisputeRow memory r, RH.OwnerProvenance memory p)
        public
        pure
    {
        AD.Record memory a = r.record;
        uint64 g = a.terms.bindingGeneration;
        if (
            g == 0 || g > b.generations.length || a.recordHash == 0 || a.recordedAt == 0
                || a.artistId != b.artistId || a.bindingHash != b.generations[g - 1].bindingHash
                || a.terms.collectionId != b.collectionId || a.terms.evidenceHash == 0
                || a.terms.reasonHash == 0 || a.signer == address(0) || a.authorityClass > 4
        ) _invalid();
        RH.OriginEnvironment memory o = p.origins[A.era(p, r.point.environmentHash)];
        if (
            a.recordHash
                != H.record(
                    Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                    a.terms,
                    a.signer,
                    a.authorityClass,
                    a.nonce,
                    a.recordedAt
                )
        ) _invalid();
        if (a.governanceActionId != 0) {
            AD.Standing memory empty;
            if (
                a.terms.disputeAction != 1 || a.authorityClass != 0 || a.nonce != 0
                    || keccak256(abi.encode(a.standing)) != keccak256(abi.encode(empty))
            ) _invalid();
        } else {
            if (
                a.authorityClass == 0 || a.standing.artistId != b.artistId
                    || a.standing.bindingGeneration == 0 || a.standing.bindingGeneration > g
                    || a.standing.collaboratorIndex != 0
                    || !b.generations[a.standing.bindingGeneration - 1].accepted
                    || (a.standing.delegation != 0
                        && (a.authorityClass != 2 || a.standing.bindingGeneration != g))
                    || (a.standing.delegation == 0 && a.authorityClass == 2)
                    || (a.terms.disputeAction == 3 && a.standing.bindingGeneration != g)
            ) _invalid();
        }
        if (a.terms.disputeAction == 1) {
            if (a.disputeRecordHash != a.recordHash) _invalid();
        } else {
            W.Outcome memory empty;
            if (
                keccak256(abi.encode(r.withdrawal)) != keccak256(abi.encode(empty))
                    || a.disputeRecordHash == 0 || a.disputeRecordHash == a.recordHash
            ) _invalid();
        }
        for (uint256 i; i < b.disputes.length; ++i) {
            AD.Record memory other = b.disputes[i].record;
            if (other.recordHash == a.recordHash && !D.samePoint(b.disputes[i].point, r.point)) {
                _invalid();
            }
            if (
                a.terms.disputeAction == 1 && other.terms.disputeAction == 1
                    && other.recordHash != a.recordHash && other.terms.bindingGeneration == g
                    && other.terms.evidenceHash == a.terms.evidenceHash
            ) _invalid();
        }
    }

    function repudiation(
        D.Bundle memory b,
        D.RepudiationRow memory row,
        RH.OwnerProvenance memory p
    ) public pure {
        RP.Record memory r = row.record;
        RP.Terminal memory t = row.terminal;
        uint64 g = r.terms.bindingGeneration;
        if (
            g == 0 || g > b.generations.length || !b.generations[g - 1].accepted
                || r.recordHash == 0 || r.artistId != b.artistId
                || r.bindingHash != b.generations[g - 1].bindingHash
                || r.terms.collectionId != b.collectionId || r.terms.disputeAction != 4
                || r.terms.reasonHash == 0 || r.signer == address(0)
                || (r.authorityClass != 1 && r.authorityClass != 3 && r.authorityClass != 4)
                || r.authorityHead.principal != r.signer
                || r.authorityHead.authorityClass != r.authorityClass || r.stagedAt == 0
                || r.executableAt <= r.stagedAt || r.windowRevision == 0 || t.phase == 0
                || t.phase > 5
        ) _invalid();
        RH.OriginEnvironment memory o = p.origins[A.era(p, row.point.environmentHash)];
        if (
            r.recordHash
                != RHash.recordHash(Hashes.Environment(o.chainId, o.registry, o.core, o.manager), r)
        ) _invalid();
        RH.Point memory zero;
        if (t.phase == 1) {
            if (
                t.actor != address(0) || t.reasonHash != 0 || t.recordedAt != 0
                    || !D.samePoint(row.terminalPoint, zero)
            ) _invalid();
        } else {
            if (t.recordedAt < r.stagedAt) _invalid();
            if (t.phase == 5) {
                if (t.actor != address(0) || !D.samePoint(row.terminalPoint, zero)) _invalid();
                _invalidation(b, row, p);
            } else {
                if (t.actor == address(0) || !Clock.beforeOwner(p, 4, row.point, row.terminalPoint))
                {
                    _invalid();
                }
                if (
                    (t.phase == 2 && (t.reasonHash == 0))
                        || (t.phase == 3 && (t.actor != r.signer || t.reasonHash != 0))
                        || (t.phase == 4
                            && (t.reasonHash != r.terms.reasonHash
                                || t.recordedAt < r.executableAt))
                ) _invalid();
            }
        }
    }

    function _invalidation(
        D.Bundle memory b,
        D.RepudiationRow memory row,
        RH.OwnerProvenance memory p
    ) private pure {
        bool found;
        if (row.terminal.reasonHash != 0) {
            for (uint256 i; i < b.disputes.length; ++i) {
                D.DisputeRow memory d = b.disputes[i];
                if (
                    d.record.recordHash == row.terminal.reasonHash
                        && d.record.terms.disputeAction == 1
                        && d.record.recordedAt == row.terminal.recordedAt
                        && Clock.beforeOwner(p, 4, row.point, d.point)
                ) found = true;
            }
        } else {
            for (uint256 i; i < b.repudiations.length; ++i) {
                D.RepudiationRow memory next = b.repudiations[i];
                if (
                    Clock.beforeOwner(p, 4, row.point, next.point)
                        && next.record.stagedAt == row.terminal.recordedAt
                        && (next.record.bindingHash != row.record.bindingHash
                            || keccak256(abi.encode(next.record.authorityHead))
                                != keccak256(abi.encode(row.record.authorityHead)))
                ) found = true;
            }
        }
        if (!found) _invalid();
    }

    function pending(D.Bundle memory b) public pure {
        bytes32 pending;
        for (uint256 i; i < b.repudiations.length; ++i) {
            if (b.repudiations[i].terminal.phase != 1) continue;
            if (pending != 0) _invalid();
            pending = b.repudiations[i].record.recordHash;
        }
        if (pending != b.pending) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

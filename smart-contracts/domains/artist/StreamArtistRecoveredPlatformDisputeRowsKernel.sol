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
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
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
    StreamArtistRecoveredHydrationProvenance as P
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import { StreamArtistDisputeHashes as H } from "./StreamArtistDisputeHashes.sol";
import { StreamArtistRepudiationHashes as RHash } from "./StreamArtistRepudiationHashes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";

import {
    StreamArtistRecoveredPlatformTypes as Platform
} from "./StreamArtistRecoveredPlatformTypes.sol";

import { StreamArtistRecoveredDisputeHistoryRowFacts as Facts } from "./StreamArtistRecoveredDisputeHistoryRowFacts.sol";

/// @notice Fixed shared original/record-history validation body; all full typed inputs are retained.
library StreamArtistRecoveredPlatformDisputeRowsKernel {
    function validate(
        D.Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        bool sanctioned,
        uint256 platformCount,
        uint256 recordCount
    ) public pure {
        if (
            P.validateOwner(p, 4) != b.provenance || b.artistId != q.artistId
                || b.collectionId != q.collectionId || b.bindingHash != q.bindingHash
                || q.artistId == 0 || q.collectionId == 0 || q.bindingHash == 0
                || b.generations.length == 0 || b.generations.length > 128
                || b.heads.length != b.generations.length
                || b.current.generation != b.generations.length || b.current.state < 2
                || b.current.state > 5 || (!sanctioned && b.current.state == 3)
                || !b.generations[b.generations.length - 1].accepted
                || b.generations[b.generations.length - 1].bindingHash != q.bindingHash
                || b.disputes.length + b.repudiations.length + platformCount + recordCount
                    != p.journal.length
        ) _invalid();
        for (uint256 i; i < b.generations.length; ++i) {
            A.Generation memory g = b.generations[i];
            if (
                g.generation != i + 1 || g.bindingHash == 0 || g.proposal.ownerIndex != 0
                    || g.proposal.ownerRevision == 0
            ) _invalid();
            A.era(p, g.proposal.environmentHash);
        }
        uint256 disputes;
        uint256 repudiations;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (
                Platform.nativeOperation(j.receipt.operation)
                    || (recordCount != 0 && j.receipt.operation == 24)
            ) continue;
            if (
                j.receipt.artistId != q.artistId || j.receipt.collectionId != q.collectionId
                    || j.position.point.ownerIndex != 4
            ) _invalid();
            Clock.validateOwnerPoint(p, 4, j.position.point);
            if (
                i != 0
                    && !Clock.beforeOwner(p, 4, p.journal[i - 1].position.point, j.position.point)
            ) _invalid();
            if (j.receipt.operation == 47) {
                if (repudiations >= b.repudiations.length) _invalid();
                D.RepudiationRow memory r = b.repudiations[repudiations++];
                if (
                    j.receipt.recordHash != r.record.recordHash
                        || !D.samePoint(j.position.point, r.point)
                ) _invalid();
                Facts.repudiation(b, r, p);
            } else {
                if (disputes >= b.disputes.length) _invalid();
                D.DisputeRow memory r = b.disputes[disputes++];
                uint8 action = r.record.terms.disputeAction;
                if (
                    j.receipt.operation
                            != (action == 1 ? 44 : action == 2 ? 61 : action == 3 ? 45 : 0)
                        || j.receipt.recordHash != r.record.recordHash
                        || !D.samePoint(j.position.point, r.point)
                ) _invalid();
                Facts.dispute(b, r, p);
            }
        }
        if (disputes != b.disputes.length || repudiations != b.repudiations.length) _invalid();
        for (uint256 i; i < b.resolutions.length; ++i) {
            D.ResolutionRow memory r = b.resolutions[i];
            AD.Resolution memory a = r.record;
            Clock.validateOwnerPoint(p, 4, r.point);
            if (i != 0 && !Clock.beforeOwner(p, 4, b.resolutions[i - 1].point, r.point)) {
                _invalid();
            }
            if (
                a.actionId == 0 || a.actor == address(0) || a.proposer == address(0)
                    || a.actionClass < 1 || a.actionClass > 2 || a.resolvedAt == 0
                    || a.witnessHash == 0 || a.terms.collectionId != b.collectionId
                    || a.terms.bindingGeneration == 0
                    || a.terms.bindingGeneration > b.generations.length || a.terms.evidenceHash == 0
                    || a.terms.reasonHash == 0
                    || (a.terms.resolution != 1 && a.terms.resolution != 2)
                    || (a.terms.resolution == 2 && (a.actionClass != 2 || a.restoredState != 5))
                    || (a.terms.resolution == 1 && (a.restoredState < 1 || a.restoredState > 3))
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    b.resolutions[j].record.actionId == a.actionId
                        || b.resolutions[j].record.terms.disputeRecordHash
                            == a.terms.disputeRecordHash
                ) _invalid();
            }
        }
        Facts.pending(b);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

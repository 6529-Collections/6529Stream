// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";

import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAttributionDisputesOwner as Disputes,
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistPlatformOwner as Platform
} from "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationGuards as Guards
} from "./StreamArtistRecoveredMultipleGenerationGuards.sol";
import {
    StreamArtistRecoveredMultipleGenerationRevocationLeaf as Leaf
} from "./StreamArtistRecoveredMultipleGenerationRevocationLeaf.sol";
import {
    StreamArtistRecoveredMultipleCollectionRows as Native
} from "./StreamArtistRecoveredMultipleCollectionRows.sol";
import {
    StreamArtistRecoveredMultipleCodec as Scope
} from "./StreamArtistRecoveredMultipleCodec.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";

import {
    StreamArtistRecoveredAggregateSanctionAttributionFacts as Sanctions
} from "./StreamArtistRecoveredAggregateSanctionAttributionFacts.sol";

/// @notice Complete governed44/class2-revoke46 history with original interleaved resolution coordinates.
library StreamArtistRecoveredMultipleGenerationRevocations {
    bytes32 private constant OPEN = keccak256("attribution_lifecycle.replay.dispute_key");
    bytes32 private constant RESOLVE =
        keccak256("attribution_lifecycle.replay.dispute_resolution_key");
    bytes32 private constant GOVERNANCE =
        keccak256("attribution_lifecycle.replay.governance_action");

    struct Context {
        bool[] aliases;
        uint256[] revokes;
        RH.Point[] resolutions;
        uint256 cursor;
    }

    function collect(
        address source,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory,
        Clocks.Result memory clocks
    ) public view returns (A.AttributionBundle[] memory rows) {
        return collect(source, scope, p, inventory, clocks, new H.ConfirmationRow[](0));
    }

    function collect(
        address source,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory,
        Clocks.Result memory clocks,
        H.ConfirmationRow[] memory confirmations
    ) public view returns (A.AttributionBundle[] memory rows) {
        Provenance.validateOwnerSource(p, 4, source);
        rows = new A.AttributionBundle[](scope.collections.length);
        for (uint256 k; k < rows.length; ++k) {
            AH.Query memory q = scope.collections[k];
            A.AttributionBundle memory b;
            b.provenance = RH.ownerProvenanceHash(p, 4);
            b.artistId = q.artistId;
            b.collectionId = q.collectionId;
            b.bindingHash = q.bindingHash;
            (b.current.state, b.current.generation) =
                Attribution(source).attributionState(q.collectionId);
            b.generations = inventory.generations[k];
            PW.State memory emptyPlatform;
            if (
                keccak256(abi.encode(Platform(source).platformWorksState(q.collectionId)))
                    != keccak256(abi.encode(emptyPlatform))
            ) _invalid();
            uint256 count;
            for (uint256 g; g + 1 < b.generations.length; ++g) {
                if (b.generations[g].accepted) ++count;
            }
            b.revocations = new A.Revocation[](count);
            count = 0;
            for (uint256 g; g < b.generations.length; ++g) {
                AD.Head memory head =
                    Disputes(source).attributionDispute(q.collectionId, uint64(g + 1));
                if (g + 1 == b.generations.length || !b.generations[g].accepted) {
                    AD.Head memory empty;
                    if (keccak256(abi.encode(head)) != keccak256(abi.encode(empty))) _invalid();
                    continue;
                }
                AD.Record memory opening =
                    Disputes(source).attributionDisputeRecord(head.disputeRecordHash);
                AD.Resolution memory resolution =
                    Disputes(source).attributionDisputeResolution(head.resolutionActionId);
                b.revocations[count++] = A.Revocation(head, opening, resolution);
                if (
                    keccak256(inventory.bindings[k].corrections[g + 1].approval.causeData)
                        != keccak256(
                            abi.encode(
                                inventory.bindings[k].bindings.rows[g].terminal,
                                head,
                                opening,
                                resolution
                            )
                        )
                ) _invalid();
            }
            rows[k] = b;
        }
        validate(rows, scope, p, inventory, clocks, confirmations);
    }

    function validate(
        A.AttributionBundle[] memory rows,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory,
        Clocks.Result memory clocks
    ) public pure {
        validate(rows, scope, p, inventory, clocks, new H.ConfirmationRow[](0));
    }

    function validate(
        A.AttributionBundle[] memory rows,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory,
        Clocks.Result memory clocks,
        H.ConfirmationRow[] memory confirmations
    ) public pure {
        bytes32 provenance = Provenance.validateOwner(p, 4);
        if (
            rows.length != scope.collections.length || clocks.collections.length != rows.length
                || clocks.counts.length != p.eras.length
                || inventory.generations.length != rows.length
        ) _invalid();
        Context memory c;
        c.aliases = new bool[](p.aliases.length);
        c.revokes = new uint256[](p.eras.length);
        c.resolutions = new RH.Point[](p.journal.length + confirmations.length);
        uint256 openings;
        for (uint256 k; k < rows.length; ++k) {
            A.AttributionBundle memory b = rows[k];
            AH.Query memory q = scope.collections[k];
            if (
                b.provenance != provenance || b.artistId != q.artistId
                    || b.collectionId != q.collectionId || b.bindingHash != q.bindingHash
                    || (b.current.state != 2 && (confirmations.length == 0 || b.current.state != 3))
                    || b.current.generation != b.generations.length
                    || keccak256(abi.encode(b.generations))
                        != keccak256(abi.encode(inventory.generations[k]))
            ) _invalid();
            uint256 cursor;
            for (uint256 g; g + 1 < b.generations.length; ++g) {
                if (!b.generations[g].accepted) continue;
                if (cursor >= b.revocations.length) _invalid();
                A.Revocation memory r = b.revocations[cursor++];
                RH.JournalEntry memory native_ = Native.occurrence(p, q, 44, r.opening.recordHash);
                RH.Point memory opened = native_.position.point;
                RH.Point memory resolved =
                    Guards.resolved(p, RESOLVE, r.opening.recordHash, r.resolution.actionId);
                uint256 era = A.era(p, opened.environmentHash);
                Leaf.row(r, b.generations[g], q, p.origins[era], confirmations.length != 0);
                if (
                    resolved.ownerIndex != 4 || resolved.environmentHash != opened.environmentHash
                        || resolved.environmentHash
                            != clocks.collections[k].attributionProposals[g + 1].environmentHash
                        || !Clock.beforeOwner(
                            p, 4, clocks.collections[k].attributionCompletions[g], opened
                        ) || !Clock.beforeOwner(p, 4, opened, resolved)
                        || !Clock.beforeOwner(
                            p, 4, resolved, clocks.collections[k].attributionProposals[g + 1]
                        )
                ) _invalid();
                Guards.mark(
                    p,
                    c.aliases,
                    OPEN,
                    keccak256(
                        abi.encode(
                            q.collectionId,
                            r.opening.terms.bindingGeneration,
                            bytes32(0),
                            r.opening.signer,
                            r.opening.terms.evidenceHash,
                            r.opening.terms.reasonHash
                        )
                    ),
                    r.opening.recordHash,
                    opened
                );
                Guards.mark(
                    p,
                    c.aliases,
                    GOVERNANCE,
                    r.opening.governanceActionId,
                    r.opening.recordHash,
                    opened
                );
                Guards.mark(
                    p, c.aliases, RESOLVE, r.opening.recordHash, r.resolution.actionId, resolved
                );
                Guards.mark(
                    p, c.aliases, GOVERNANCE, r.resolution.actionId, r.opening.recordHash, resolved
                );
                _distinct(p, clocks, c, resolved);
                c.resolutions[c.cursor++] = resolved;
                ++c.revokes[era];
                ++openings;
            }
            if (cursor != b.revocations.length) _invalid();
        }
        Guards.complete(c.aliases);
        uint256 nativeOpenings;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            uint256 k = Scope.collection(scope, j.receipt.collectionId);
            if (
                j.receipt.artistId != scope.collections[k].artistId
                    || (j.receipt.operation != 24 && j.receipt.operation != 44)
            ) _invalid();
            if (j.receipt.operation == 44) ++nativeOpenings;
        }
        if (nativeOpenings != openings) _invalid();
        uint256[] memory confirmed = new uint256[](p.eras.length);
        for (uint256 i; i < confirmations.length; ++i) {
            RH.Point memory point = confirmations[i].attributionPoint;
            Clock.validateOwnerPoint(p, 4, point);
            uint256 eraIndex = A.era(p, point.environmentHash);
            if (point.ownerRevision <= p.eras[eraIndex].lowerRevision) _invalid();
            _distinct(p, clocks, c, point);
            c.resolutions[c.cursor++] = point;
            ++confirmed[eraIndex];
        }
        uint256 total;
        for (uint256 e; e < p.eras.length; ++e) {
            total += c.revokes[e];
            RH.OwnerEra memory era = p.eras[e];
            if (
                era.lowerRevision != (e == 0 ? 0 : 1)
                    || era.checkpoint.ownerState.revision
                        != era.lowerRevision + clocks.counts[e] + era.nativeCount + c.revokes[e]
                            + confirmed[e] || era.checkpoint.replayCount != 4 * total
                    || (total == 0 && era.checkpoint.replayRoot != 0)
                    || era.checkpoint.nonceIndexCount != 0 || era.checkpoint.nonceRoot != 0
            ) _invalid();
        }
        if (confirmations.length != 0) Sanctions.generations(rows, p, clocks, confirmations);
    }

    function _distinct(
        RH.OwnerProvenance memory p,
        Clocks.Result memory clocks,
        Context memory c,
        RH.Point memory point
    ) private pure {
        for (uint256 i; i < p.journal.length; ++i) {
            if (_same(point, p.journal[i].position.point)) _invalid();
        }
        for (uint256 i; i < c.cursor; ++i) {
            if (_same(point, c.resolutions[i])) _invalid();
        }
        for (uint256 k; k < clocks.collections.length; ++k) {
            for (uint256 g; g < clocks.collections[k].attributionProposals.length; ++g) {
                if (
                    _same(point, clocks.collections[k].attributionProposals[g])
                        || _same(point, clocks.collections[k].attributionCompletions[g])
                ) _invalid();
            }
        }
    }

    function _same(RH.Point memory a, RH.Point memory b) private pure returns (bool) {
        return a.environmentHash == b.environmentHash && a.ownerIndex == b.ownerIndex
            && a.ownerRevision == b.ownerRevision;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

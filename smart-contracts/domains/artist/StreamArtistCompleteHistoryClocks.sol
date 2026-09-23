// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistCompleteHistoryCatalogue as Catalogue
} from "./StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistPrimaryCollaboratorLeaves as Leaves
} from "./StreamArtistPrimaryCollaboratorLeaves.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Exhaustive original proposal, partial acceptance and completion chronology.
/// @dev All original Archive rows and owner journals are retained. An op2 can overwrite
/// its binding's primary map while still pending; every native occurrence survives here.
import {
    StreamArtistCompleteHistoryClockBindingProof as BindingProof
} from "./StreamArtistCompleteHistoryClockBindingProof.sol";

import {
    StreamArtistPrimaryCollaboratorClocks as Original
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistCompleteHistoryPlatformProof as Platform
} from "./StreamArtistCompleteHistoryPlatformProof.sol";

library StreamArtistCompleteHistoryClocks {
    struct Context {
        P.Cursor[] cursors;
        RH.OwnerProvenance owner0;
        RH.OwnerProvenance owner3;
        P.Platform[] platforms;
        RH.OwnerProvenance owner4;
        uint256 primaryCount;
        uint256 previousEra;
        uint256 previousIndex;
        uint256 attributionEra;
        uint64 attributionRevision;
        bool hasAttribution;
    }

    function validate(
        M.State memory scope,
        RH.Provenance memory p,
        PC.BindingInventory memory bindings,
        PC.Inventory memory inventory,
        P.Platform[] memory platforms
    ) public view returns (Original.Result memory r) {
        Catalogue.requireCurrent(p, inventory.catalogues, inventory.operations);
        Context memory c;
        c.owner0 = RH.ownerProvenance(p, 0);
        c.platforms = platforms;
        if (platforms.length != scope.collections.length) _invalid();
        c.owner3 = RH.ownerProvenance(p, 3);
        c.owner4 = RH.ownerProvenance(p, 4);
        c.cursors = new P.Cursor[](scope.collections.length);
        _initialize(scope, bindings, r, p.eras.length, inventory.operations.length);
        for (uint256 i; i < inventory.operations.length; ++i) {
            H.OperationEvidence memory row = inventory.operations[i];
            uint256 era = A.era(c.owner4, row.originHash);
            H.Envelope memory e =
                Catalogue.read(p.origins[era], inventory.catalogues[era], row.evidence);
            if (
                row.operation != e.operation || era < c.previousEra
                    || (i != 0
                        && era == c.previousEra
                        && row.evidence.catalogueIndex <= c.previousIndex)
            ) _invalid();
            c.previousEra = era;
            c.previousIndex = row.evidence.catalogueIndex;
            BindingProof.bounds(inventory.catalogues[era].lower, inventory.catalogues[era].upper, e);
            if (P.nativeOperation(e.operation)) {
                uint256 k = _platform(scope, e);
                c.cursors[k] = Platform.native(c.platforms[k], c.cursors[k], c.owner4, era, e);
                continue;
            }
            // Other families retain the same full catalogue and are proved by their
            // fixed family workers. This loop does not assert owner4 completeness.
            if (e.operation > 7) continue;
            if (e.operation == 5) {
                Leaves.proposal(p.origins[era], e);
                continue;
            }
            if (e.operation == 6) {
                Leaves.identity(p.origins[era], e);
                continue;
            }
            (uint256 k, uint256 g) = _scope(scope, bindings, c, e);
            if (e.operation == 1) {
                _proposal(scope, bindings, r, c, era, e, k, g);
            } else {
                if (c.cursors[k].generation != g + 1 || c.cursors[k].completed) _invalid();
                if (e.operation == 2) {
                    _primary(scope, bindings, r, c, era, e, k, g, i);
                } else if (e.operation == 7) {
                    _collaborator(scope, bindings, r, c, era, e, k, g);
                } else {
                    _terminal(scope, bindings, r, c, era, e, k, g);
                }
            }
        }
        for (uint256 k; k < scope.collections.length; ++k) {
            uint256 n = bindings.generations[k].length;
            if (c.cursors[k].generation != n) _invalid();
            if (n != 0) {
                bool terminal = bindings.bindings[k].bindings.rows[n - 1].terminal.kind != 0;
                if (c.cursors[k].completed != (bindings.generations[k][n - 1].accepted || terminal))
                {
                    _invalid();
                }
            }
            Platform.finish(c.platforms[k], c.cursors[k], bindings.bindings[k]);
        }
        PC.PrimaryReceipt[] memory primary = r.primary;
        uint256 count = c.primaryCount;
        assembly ("memory-safe") { mstore(primary, count) }
    }

    function _initialize(
        M.State memory scope,
        PC.BindingInventory memory b,
        Original.Result memory r,
        uint256 eras,
        uint256 operations
    ) private pure {
        uint256 n = scope.collections.length;
        if (
            n == 0 || b.bindings.length != n || b.generations.length != n
                || b.collaborators.length != n
        ) _invalid();
        r.clocks.collections = new G.Timeline[](n);
        r.clocks.counts = new uint256[](eras);
        r.primary = new PC.PrimaryReceipt[](operations);
        r.finalPrimary = new bytes32[][](n);
        r.accepted = new uint32[][](n);
        for (uint256 k; k < n; ++k) {
            uint256 m = b.generations[k].length;
            if (
                m > 128 || b.bindings[k].bindings.rows.length != m
                    || b.bindings[k].corrections.length != m || b.collaborators[k].length != m
                    || b.bindings[k].bindings.artistId != scope.collections[k].artistId
                    || b.bindings[k].bindings.collectionId != scope.collections[k].collectionId
                    || b.bindings[k].bindings.bindingHash != scope.collections[k].bindingHash
                    || b.bindings[k].bindings.current.bindingHash
                        != scope.collections[k].bindingHash
                    || b.bindings[k].bindings.current.artistId != scope.collections[k].artistId
            ) _invalid();
            if (m == 0) {
                T.Binding memory empty;
                if (
                    scope.collections[k].artistId != 0 || scope.collections[k].bindingHash != 0
                        || keccak256(abi.encode(b.bindings[k].bindings.current))
                            != keccak256(abi.encode(empty))
                ) _invalid();
            } else if (
                keccak256(abi.encode(b.bindings[k].bindings.current))
                    != keccak256(abi.encode(b.bindings[k].bindings.rows[m - 1].item))
            ) {
                _invalid();
            }
            r.clocks.collections[k].proposals = new RH.Point[](m);
            r.clocks.collections[k].completions = new RH.Point[](m);
            r.clocks.collections[k].attributionProposals = new RH.Point[](m);
            r.clocks.collections[k].attributionCompletions = new RH.Point[](m);
            r.finalPrimary[k] = new bytes32[](m);
            r.accepted[k] = new uint32[](m);
        }
    }

    function _proposal(
        M.State memory scope,
        PC.BindingInventory memory b,
        Original.Result memory r,
        Context memory c,
        uint256 era,
        H.Envelope memory e,
        uint256 k,
        uint256 g
    ) private pure {
        c.cursors[k] = BindingProof.proposal(_bindingContext(scope, b, c, era, e, k, g));
        r.clocks.collections[k].proposals[g] =
            RH.Point(c.owner4.eras[era].originHash, 0, e.after_[0].revision);
        r.clocks.collections[k].attributionProposals[g] = _attributionPoint(r, c, era, e);
    }

    function _primary(
        M.State memory scope,
        PC.BindingInventory memory b,
        Original.Result memory r,
        Context memory c,
        uint256 era,
        H.Envelope memory e,
        uint256 k,
        uint256 g,
        uint256 operationIndex
    ) private pure {
        PC.PrimaryAcceptance memory a = Leaves.primary(
            c.owner4.origins[era], e, b.bindings[k].bindings.rows[g].terms.count
        );
        if (
            a.acceptance.id != scope.collections[k].collectionId
                || !_pendingEqual(a.acceptance.binding_, b.bindings[k].bindings.rows[g].item)
                || a.accepted != r.accepted[k][g]
        ) _invalid();
        RH.JournalEntry memory native_ = _native(c.owner3, 2, e.value);
        if (
            native_.receipt.artistId != b.bindings[k].bindings.rows[g].item.artistId
                || native_.receipt.collectionId != scope.collections[k].collectionId
                || native_.position.point.environmentHash != c.owner4.eras[era].originHash
                || native_.position.point.ownerRevision != e.after_[3].revision
        ) _invalid();
        r.primary[c.primaryCount++] = PC.PrimaryReceipt(
            scope.collections[k].collectionId,
            uint64(g + 1),
            a.acceptance.binding_.bindingHash,
            e.value,
            native_.position.point,
            operationIndex
        );
        r.finalPrimary[k][g] = e.value;
        if (a.complete) _complete(scope, b, r, c, era, e, k, g);
    }

    function _collaborator(
        M.State memory scope,
        PC.BindingInventory memory b,
        Original.Result memory r,
        Context memory c,
        uint256 era,
        H.Envelope memory e,
        uint256 k,
        uint256 g
    ) private pure {
        PC.BindingAcceptance memory a = Leaves.acceptance(c.owner4.origins[era], e);
        if (
            !_pendingEqual(a.binding_, b.bindings[k].bindings.rows[g].item)
                || a.acceptance.collectionId != scope.collections[k].collectionId
                || a.acceptance.generation != g + 1
                || a.acceptance.bindingHash != a.binding_.bindingHash
                || keccak256(abi.encode(a.terms))
                    != keccak256(abi.encode(b.bindings[k].bindings.rows[g].terms))
                || a.priorCount != r.accepted[k][g] || a.primaryRecord != r.finalPrimary[k][g]
        ) _invalid();
        uint256 matches;
        for (uint256 j; j < b.collaborators[k][g].length; ++j) {
            T.CollaboratorRecord memory term = b.collaborators[k][g][j];
            if (
                term.account == a.acceptance.account && term.role == a.acceptance.role
                    && term.shareLabelId == a.acceptance.shareLabelId
            ) ++matches;
        }
        if (matches != 1) _invalid();
        RH.JournalEntry memory native_ = _native(c.owner3, 7, e.value);
        if (
            native_.receipt.artistId != a.artistId
                || native_.receipt.collectionId != scope.collections[k].collectionId
                || native_.position.point.environmentHash != c.owner4.eras[era].originHash
                || native_.position.point.ownerRevision != e.after_[3].revision
        ) _invalid();
        r.accepted[k][g] = a.count;
        if (a.complete) _complete(scope, b, r, c, era, e, k, g);
    }

    function _complete(
        M.State memory scope,
        PC.BindingInventory memory b,
        Original.Result memory r,
        Context memory c,
        uint256 era,
        H.Envelope memory e,
        uint256 k,
        uint256 g
    ) private pure {
        if (
            !b.generations[k][g].accepted || !b.bindings[k].bindings.rows[g].item.accepted
                || r.finalPrimary[k][g] == 0
                || r.accepted[k][g] != b.bindings[k].bindings.rows[g].terms.count
        ) _invalid();
        c.cursors[k] = BindingProof.complete(
            BindingProof.Completion({
                platform: c.platforms[k],
                cursor: c.cursors[k],
                collectionId: scope.collections[k].collectionId,
                binding: b.bindings[k].bindings.rows[g].item,
                owner4: c.owner4,
                era: era,
                envelope: e,
                generation: g,
                proposal: r.clocks.collections[k].attributionProposals[g]
            })
        );
        r.clocks.collections[k].completions[g] =
            RH.Point(c.owner4.eras[era].originHash, 0, e.after_[0].revision);
        r.clocks.collections[k].attributionCompletions[g] = _attributionPoint(r, c, era, e);
        c.cursors[k].completed = true;
    }

    function _terminal(
        M.State memory scope,
        PC.BindingInventory memory b,
        Original.Result memory r,
        Context memory c,
        uint256 era,
        H.Envelope memory e,
        uint256 k,
        uint256 g
    ) private view {
        c.cursors[k] = BindingProof.terminal(_bindingContext(scope, b, c, era, e, k, g));
        r.clocks.collections[k].completions[g] =
            RH.Point(c.owner4.eras[era].originHash, 0, e.after_[0].revision);
        r.clocks.collections[k].attributionCompletions[g] = _attributionPoint(r, c, era, e);
    }

    function _attributionPoint(
        Original.Result memory r,
        Context memory c,
        uint256 era,
        H.Envelope memory e
    ) private pure returns (RH.Point memory point) {
        point = RH.Point(c.owner4.eras[era].originHash, 4, e.after_[4].revision);
        if (
            c.hasAttribution
                && (era < c.attributionEra
                    || (era == c.attributionEra && point.ownerRevision <= c.attributionRevision))
        ) _invalid();
        c.hasAttribution = true;
        c.attributionEra = era;
        c.attributionRevision = point.ownerRevision;
        for (uint256 j; j < c.owner4.journal.length; ++j) {
            RH.Point memory other = c.owner4.journal[j].position.point;
            if (
                point.environmentHash == other.environmentHash
                    && point.ownerRevision == other.ownerRevision
            ) _invalid();
        }
        ++r.clocks.counts[era];
    }

    function _platform(M.State memory scope, H.Envelope memory e) private pure returns (uint256 k) {
        // Every original Platform payload starts with its uint256 collection id.
        if (e.payload.length < 32) _invalid();
        uint256 id = abi.decode(e.payload, (uint256));
        bool found;
        for (uint256 i; i < scope.collections.length; ++i) {
            if (scope.collections[i].collectionId != id) continue;
            if (found) _invalid();
            found = true;
            k = i;
        }
        if (!found) _invalid();
    }

    function _scope(
        M.State memory scope,
        PC.BindingInventory memory b,
        Context memory c,
        H.Envelope memory e
    ) private pure returns (uint256 k, uint256 g) {
        if (e.operation == 2 || e.operation == 7) {
            RH.JournalEntry memory row = _native(c.owner3, e.operation, e.value);
            bool found;
            for (uint256 i; i < scope.collections.length; ++i) {
                if (scope.collections[i].collectionId == row.receipt.collectionId) {
                    if (found || c.cursors[i].generation == 0) _invalid();
                    found = true;
                    k = i;
                    g = c.cursors[i].generation - 1;
                }
            }
            if (!found) _invalid();
            return (k, g);
        }
        bool found;
        for (uint256 i; i < b.bindings.length; ++i) {
            for (uint256 j; j < b.bindings[i].bindings.rows.length; ++j) {
                bytes32 h = e.operation == 3
                    ? b.bindings[i].bindings.rows[j].terminal.recordHash
                    : b.bindings[i].bindings.rows[j].item.bindingHash;
                if (h == 0 || h != e.value) continue;
                if (found) _invalid();
                found = true;
                k = i;
                g = j;
            }
        }
        if (!found) _invalid();
    }

    function _native(RH.OwnerProvenance memory p, uint16 operation, bytes32 record)
        private
        pure
        returns (RH.JournalEntry memory result)
    {
        bool found;
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.recordHash == record) {
                if (found || p.journal[i].receipt.operation != operation) _invalid();
                found = true;
                result = p.journal[i];
                Clock.validateOwnerPoint(p, 3, result.position.point);
            }
        }
        if (!found) _invalid();
    }

    function _pendingEqual(T.Binding memory observed, T.Binding memory accepted)
        private
        pure
        returns (bool)
    {
        T.Binding memory pending = abi.decode(abi.encode(accepted), (T.Binding));
        pending.accepted = false;
        return keccak256(abi.encode(observed)) == keccak256(abi.encode(pending));
    }

    function _bindingContext(
        M.State memory scope,
        PC.BindingInventory memory b,
        Context memory c,
        uint256 era,
        H.Envelope memory e,
        uint256 k,
        uint256 g
    ) private pure returns (BindingProof.Context memory x) {
        x.query = scope.collections[k];
        x.platform = c.platforms[k];
        x.owner0 = c.owner0;
        x.binding = b.bindings[k];
        x.generations = b.generations[k];
        x.collaborators = b.collaborators[k][g];
        x.cursor = c.cursors[k];
        x.owner4 = c.owner4;
        x.era = era;
        x.envelope = e;
        x.generation = g;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

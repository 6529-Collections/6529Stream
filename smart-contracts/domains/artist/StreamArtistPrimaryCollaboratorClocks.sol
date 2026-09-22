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
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorCatalogue as Catalogue
} from "./StreamArtistPrimaryCollaboratorCatalogue.sol";
import {
    StreamArtistPrimaryCollaboratorLeaves as Leaves
} from "./StreamArtistPrimaryCollaboratorLeaves.sol";
import {
    StreamArtistPrimaryCollaboratorBindingLeaves as BindingLeaves
} from "./StreamArtistPrimaryCollaboratorBindingLeaves.sol";
import {
    StreamArtistPrimaryCollaboratorProposalProof as Proposal
} from "./StreamArtistPrimaryCollaboratorProposalProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationCompletionProof as Terminal
} from "./StreamArtistRecoveredMultipleGenerationCompletionProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as OriginalClocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
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
    StreamArtistRecoveredPlatformTransitionProof as Transition
} from "./StreamArtistRecoveredPlatformTransitionProof.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";

/// @notice Exhaustive original proposal, partial acceptance and completion chronology.
/// @dev All original Archive rows and owner journals are retained. An op2 can overwrite
/// its binding's primary map while still pending; every native occurrence survives here.
library StreamArtistPrimaryCollaboratorClocks {
    struct Result {
        OriginalClocks.Result clocks;
        PC.PrimaryReceipt[] primary;
        bytes32[][] finalPrimary;
        uint32[][] accepted;
    }

    struct Context {
        P.Cursor[] cursors;
        RH.OwnerProvenance owner3;
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
        PC.Inventory memory inventory
    ) public view returns (Result memory r) {
        Catalogue.requireCurrent(p, inventory.catalogues, inventory.operations);
        Context memory c;
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
            _bounds(inventory.catalogues[era], e);
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
            if (
                c.cursors[k].generation != bindings.generations[k].length || !c.cursors[k].completed
            ) _invalid();
        }
        PC.PrimaryReceipt[] memory primary = r.primary;
        uint256 count = c.primaryCount;
        assembly ("memory-safe") { mstore(primary, count) }
    }

    function _initialize(
        M.State memory scope,
        PC.BindingInventory memory b,
        Result memory r,
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
                m == 0 || m > 128 || b.bindings[k].bindings.rows.length != m
                    || b.bindings[k].corrections.length != m || b.collaborators[k].length != m
                    || b.bindings[k].bindings.artistId != scope.collections[k].artistId
                    || b.bindings[k].bindings.collectionId != scope.collections[k].collectionId
                    || b.bindings[k].bindings.bindingHash != scope.collections[k].bindingHash
                    || !b.bindings[k].bindings.current.accepted
                    || b.bindings[k].bindings.current.bindingHash
                        != scope.collections[k].bindingHash
                    || keccak256(abi.encode(b.bindings[k].bindings.current))
                        != keccak256(abi.encode(b.bindings[k].bindings.rows[m - 1].item))
            ) _invalid();
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
        Result memory r,
        Context memory c,
        uint256 era,
        H.Envelope memory e,
        uint256 k,
        uint256 g
    ) private pure {
        A.Generation memory generation = b.generations[k][g];
        if (
            g != c.cursors[k].generation || (g != 0 && !c.cursors[k].completed)
                || generation.generation != g + 1
                || generation.bindingHash != b.bindings[k].bindings.rows[g].item.bindingHash
                || generation.accepted != b.bindings[k].bindings.rows[g].item.accepted
                || generation.proposal.ownerIndex != 0
        ) _invalid();
        BindingLeaves.row(
            b.bindings[k].bindings.rows[g],
            scope.collections[k],
            uint64(g + 1),
            c.owner4.origins[era],
            b.collaborators[k][g]
        );
        BindingLeaves.correction(b.bindings[k], scope.collections[k], g, c.owner4.origins[era]);
        _fixedFrames(e, 0x15, e.after_[2].revision == e.before_[2].revision ? 0x11 : 0x15);
        P.Platform memory platform;
        platform.collectionId = scope.collections[k].collectionId;
        c.cursors[k] = Proposal.advance(
            platform, b.bindings[k], b.generations[k], c.cursors[k], c.owner4, era, e, true
        );
        r.clocks.collections[k].proposals[g] =
            RH.Point(c.owner4.eras[era].originHash, 0, e.after_[0].revision);
        r.clocks.collections[k].attributionProposals[g] = _attributionPoint(r, c, era, e);
    }

    function _primary(
        M.State memory scope,
        PC.BindingInventory memory b,
        Result memory r,
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
            native_.receipt.artistId != scope.collections[k].artistId
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
        Result memory r,
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
        Result memory r,
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
        RH.Point memory point = RH.Point(c.owner4.eras[era].originHash, 4, e.after_[4].revision);
        // The shared _attributionPoint below advances the global cursor once, after
        // the complete original transition preimage is authenticated.
        if (!Clock.beforeOwner(c.owner4, 4, r.clocks.collections[k].attributionProposals[g], point))
        {
            _invalid();
        }
        T.Binding memory pending =
            abi.decode(abi.encode(b.bindings[k].bindings.rows[g].item), (T.Binding));
        pending.accepted = false;
        Transition.validateWithRecords(
            c.owner4.origins[era],
            c.owner4,
            era,
            e,
            keccak256(abi.encode(scope.collections[k].collectionId, pending, e.value)),
            keccak256(
                abi.encode(scope.collections[k].collectionId, AS.Attribution(2, uint64(g + 1)))
            ),
            0,
            0
        );
        r.clocks.collections[k].completions[g] =
            RH.Point(c.owner4.eras[era].originHash, 0, e.after_[0].revision);
        r.clocks.collections[k].attributionCompletions[g] = _attributionPoint(r, c, era, e);
        c.cursors[k].completed = true;
    }

    function _terminal(
        M.State memory scope,
        PC.BindingInventory memory b,
        Result memory r,
        Context memory c,
        uint256 era,
        H.Envelope memory e,
        uint256 k,
        uint256 g
    ) private view {
        if (e.operation != 3 && e.operation != 4) _invalid();
        _fixedFrames(e, e.operation == 3 ? 0x15 : 0x11, e.operation == 3 ? 0x15 : 0x11);
        P.Platform memory platform;
        platform.collectionId = scope.collections[k].collectionId;
        c.cursors[k] = Terminal.advance(
            platform, b.bindings[k], b.generations[k], c.cursors[k], c.owner4, era, e, true
        );
        r.clocks.collections[k].completions[g] =
            RH.Point(c.owner4.eras[era].originHash, 0, e.after_[0].revision);
        r.clocks.collections[k].attributionCompletions[g] = _attributionPoint(r, c, era, e);
    }

    function _attributionPoint(Result memory r, Context memory c, uint256 era, H.Envelope memory e)
        private
        pure
        returns (RH.Point memory point)
    {
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

    function _bounds(P.Catalogue memory catalogue, H.Envelope memory e) private pure {
        for (uint8 i; i < 7; ++i) {
            T.Snapshot memory a = e.before_[i];
            T.Snapshot memory b = e.after_[i];
            if (a.domainId == 0 && b.domainId == 0) continue;
            if (
                a.domainId != RH.ownerDomain(i) || b.domainId != a.domainId || a.stateRoot == 0
                    || b.stateRoot == 0 || a.recordChainTip == 0 || b.recordChainTip == 0
                    || a.revision < catalogue.lower[i] || b.revision > catalogue.upper[i]
                    || b.revision < a.revision || b.revision > a.revision + 1
            ) _invalid();
        }
    }

    function _fixedFrames(H.Envelope memory e, uint256 observed, uint256 changed) private pure {
        T.Snapshot memory zero;
        for (uint8 i; i < 7; ++i) {
            if ((observed & (1 << i)) == 0) {
                if (
                    keccak256(abi.encode(e.before_[i])) != keccak256(abi.encode(zero))
                        || keccak256(abi.encode(e.after_[i])) != keccak256(abi.encode(zero))
                ) _invalid();
            } else if ((changed & (1 << i)) != 0) {
                if (e.after_[i].revision != e.before_[i].revision + 1) _invalid();
            } else if (keccak256(abi.encode(e.before_[i])) != keccak256(abi.encode(e.after_[i]))) {
                _invalid();
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

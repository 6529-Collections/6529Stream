// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    IStreamArtistBindingLifecycle as Lifecycle
} from "../../interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import {
    IStreamArtistBindingCorrectionOwner as Corrections
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import { StreamArtistBindingCorrectionState as CS } from "./StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistRecoveredHydrationProvenance as P
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistCompleteHistoryBindingLeaves as Leaves
} from "./StreamArtistCompleteHistoryBindingLeaves.sol";

import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";

import {
    StreamArtistCompleteHistoryBindingTypes as Types
} from "./StreamArtistCompleteHistoryBindingTypes.sol";

/// @notice Every original binding row and native occurrence, including latest pending and terminal heads.
/// @dev Complete counters, aliases and non-native completion clocks are joined by the aggregate
/// timeline before import. This collector never substitutes a filtered owner provenance.
library StreamArtistCompleteHistoryBindingSource {
    function collect(address source, M.State memory scope, RH.OwnerProvenance memory p)
        public
        view
        returns (PC.BindingInventory memory result)
    {
        P.validateOwnerSource(p, 0, source);
        result.bindings = new CB.Bundle[](scope.collections.length);
        result.generations = new A.Generation[][](scope.collections.length);
        bool[] memory covered = new bool[](p.journal.length);
        bytes32 provenance = RH.ownerProvenanceHash(p, 0);
        result.collaborators = new T.CollaboratorRecord[][][](scope.collections.length);
        for (uint256 k; k < scope.collections.length; ++k) {
            AH.Query memory q = scope.collections[k];
            CB.Bundle memory b;
            b.bindings.artistId = q.artistId;
            b.bindings.collectionId = q.collectionId;
            b.bindings.bindingHash = q.bindingHash;
            b.bindings.provenanceCommitment = provenance;
            b.bindings.current = Binding(source).binding(q.collectionId);
            uint256 n = b.bindings.current.generation;
            if (
                n > 128 || b.bindings.current.artistId != q.artistId
                    || b.bindings.current.bindingHash != q.bindingHash
            ) _invalid();
            result.collaborators[k] = new T.CollaboratorRecord[][](n);
            b.bindings.rows = new G.Row[](n);
            b.corrections = new CS.Correction[](n);
            A.Generation[] memory generations = new A.Generation[](n);
            for (uint256 i; i < n; ++i) {
                uint64 generation = uint64(i + 1);
                G.Row memory row = G.Row(
                    Binding(source).bindingAt(q.collectionId, generation),
                    Terms(source).bindingTerms(q.collectionId, generation),
                    Lifecycle(source).bindingTermination(q.collectionId, generation)
                );
                AH.Query memory historical = Types.rowQuery(q, row);
                Types.principalIndex(scope, historical.artistId);
                RH.Point memory proposal = _native(p, covered, historical, 1, row.item.bindingHash);
                if (i != 0 && !Clock.beforeOwner(p, 0, generations[i - 1].proposal, proposal)) {
                    _invalid();
                }
                if (row.terms.count > 32) _invalid();
                T.CollaboratorRecord[] memory terms = new T.CollaboratorRecord[](row.terms.count);
                for (uint256 j; j < terms.length; ++j) {
                    terms[j] = Terms(source).collaboratorTerm(q.collectionId, generation, j);
                }
                Leaves.row(row, q, generation, p.origins[A.era(p, proposal.environmentHash)], terms);
                result.collaborators[k][i] = terms;
                b.bindings.rows[i] = row;
                (b.corrections[i].approval, b.corrections[i].recordHash) =
                    Corrections(source).bindingCorrection(row.item.bindingHash);
                generations[i] =
                    A.Generation(row.item.bindingHash, generation, row.item.accepted, proposal);
                if (row.terminal.kind == 1) {
                    RH.Point memory refusal =
                        _native(p, covered, historical, 3, row.terminal.recordHash);
                    if (!Clock.beforeOwner(p, 0, proposal, refusal)) _invalid();
                }
            }
            for (uint256 i; i < n; ++i) {
                Leaves.correction(
                    b, q, i, p.origins[A.era(p, generations[i].proposal.environmentHash)]
                );
                // A prior pending row can be superseded only by its genuine owner4
                // arbiter revocation. It does not acquire a fabricated owner0 completion.
                if (
                    i + 1 < n && !generations[i].accepted && b.bindings.rows[i].terminal.kind == 0
                        && (b.corrections[i + 1].recordHash == 0
                            || b.corrections[i + 1].approval.cause != 4)
                ) _invalid();
            }
            result.bindings[k] = b;
            result.generations[k] = generations;
        }
        Types.validate(scope, result, provenance);
        for (uint256 i; i < covered.length; ++i) {
            if (!covered[i]) _invalid();
        }
    }

    function _native(
        RH.OwnerProvenance memory p,
        bool[] memory covered,
        AH.Query memory q,
        uint16 operation,
        bytes32 record
    ) private pure returns (RH.Point memory point) {
        if (record == 0) _invalid();
        bool found;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory row = p.journal[i];
            if (row.receipt.recordHash != record) continue;
            if (
                found || covered[i] || row.receipt.operation != operation
                    || row.receipt.artistId != q.artistId
                    || row.receipt.collectionId != q.collectionId
            ) _invalid();
            Clock.validateOwnerPoint(p, 0, row.position.point);
            point = row.position.point;
            covered[i] = true;
            found = true;
        }
        if (!found) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

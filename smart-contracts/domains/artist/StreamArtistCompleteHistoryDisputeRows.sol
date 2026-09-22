// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredPlatformTypes as Platform
} from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryRowFacts as Original
} from "./StreamArtistRecoveredDisputeHistoryRowFacts.sol";
import {
    StreamArtistCompleteHistoryDisputeFacts as Facts
} from "./StreamArtistCompleteHistoryDisputeFacts.sol";
import {
    StreamArtistCompleteHistoryCatalogue as Catalogue
} from "./StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredDisputeHistoryChains as Chains
} from "./StreamArtistRecoveredDisputeHistoryChains.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import { StreamArtistCompleteHistoryScope as Scope } from "./StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";

/// @notice Exact dispute-family partition of the original full native journal and generation chains.
/// @dev Provenance retains global occurrence indices and clocks. No filtered owner is manufactured.
library StreamArtistCompleteHistoryDisputeRows {
    function validate(
        D.Bundle[] memory rows,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        PC.BindingInventory memory bindings,
        PC.Inventory memory archive,
        Clocks.Result memory clocks
    ) public view {
        bytes32 provenance = Provenance.validateOwner(p, 4);
        if (
            rows.length != scope.collections.length || bindings.generations.length != rows.length
                || bindings.bindings.length != rows.length
                || bindings.collaborators.length != rows.length
                || clocks.clocks.collections.length != rows.length
        ) _invalid();
        Catalogue.requireLocal(p, 4, archive.catalogues, archive.operations);
        uint256[] memory disputes = new uint256[](rows.length);
        uint256[] memory repudiations = new uint256[](rows.length);
        for (uint256 k; k < rows.length; ++k) {
            D.Bundle memory b = rows[k];
            AH.Query memory q = scope.collections[k];
            if (
                b.provenance != provenance || b.artistId != q.artistId
                    || b.collectionId != q.collectionId || b.bindingHash != q.bindingHash
                    || b.generations.length > 128 || b.heads.length != b.generations.length
                    || b.current.generation != b.generations.length
                    || bindings.bindings[k].bindings.rows.length != b.generations.length
                    || bindings.bindings[k].corrections.length != b.generations.length
                    || bindings.collaborators[k].length != b.generations.length
                    || clocks.clocks.collections[k].attributionProposals.length
                        != b.generations.length
                    || clocks.clocks.collections[k].attributionCompletions.length
                        != b.generations.length
                    || keccak256(abi.encode(b.generations))
                        != keccak256(abi.encode(bindings.generations[k]))
            ) _invalid();
            if (b.generations.length == 0) {
                if (
                    q.artistId != 0 || q.bindingHash != 0 || b.disputes.length != 0
                        || b.repudiations.length != 0 || b.resolutions.length != 0
                ) _invalid();
            } else if (b.generations[b.generations.length - 1].bindingHash != q.bindingHash) {
                _invalid();
            }
        }
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            uint256 k = Scope.collection(scope, j.receipt.collectionId);
            // The enclosing proof accounts for these original native families using this same p.
            if (j.receipt.operation == 24 || Platform.nativeOperation(j.receipt.operation)) {
                continue;
            }
            if (
                j.receipt.operation != 44 && j.receipt.operation != 45 && j.receipt.operation != 47
                    && j.receipt.operation != 61
            ) _invalid();
            Clock.validateOwnerPoint(p, 4, j.position.point);
            D.Bundle memory b = rows[k];
            if (j.receipt.operation == 47) {
                if (repudiations[k] >= b.repudiations.length) _invalid();
                D.RepudiationRow memory r = b.repudiations[repudiations[k]++];
                if (
                    j.receipt.recordHash != r.record.recordHash
                        || j.receipt.artistId != r.record.artistId
                        || !D.samePoint(j.position.point, r.point)
                ) _invalid();
                Scope.artist(scope, r.record.artistId);
                Facts.repudiation(b, r, p, bindings.bindings[k], clocks.clocks.collections[k]);
            } else {
                if (disputes[k] >= b.disputes.length) _invalid();
                D.DisputeRow memory r = b.disputes[disputes[k]++];
                uint8 action = r.record.terms.disputeAction;
                if (
                    j.receipt.operation
                            != (action == 1 ? 44 : action == 2 ? 61 : action == 3 ? 45 : 0)
                        || j.receipt.recordHash != r.record.recordHash
                        || j.receipt.artistId != r.record.artistId
                        || !D.samePoint(j.position.point, r.point)
                ) _invalid();
                Scope.artist(scope, r.record.artistId);
                if (r.record.governanceActionId == 0) {
                    Scope.artist(scope, r.record.standing.artistId);
                }
                Facts.dispute(
                    b,
                    r,
                    p,
                    bindings,
                    archive,
                    clocks.clocks.collections[k],
                    k,
                    _operationIndex(p, archive, j.receipt.operation, r.record.recordHash, r.point)
                );
            }
        }
        for (uint256 k; k < rows.length; ++k) {
            D.Bundle memory b = rows[k];
            if (disputes[k] != b.disputes.length || repudiations[k] != b.repudiations.length) {
                _invalid();
            }
            _resolutions(b, p, clocks.clocks.collections[k]);
            Original.pending(b);
            Chains.validateGenerationChains(b, p);
            Facts.current(b, bindings.bindings[k]);
            Facts.causes(b, bindings.bindings[k]);
        }
    }

    function _resolutions(
        D.Bundle memory b,
        RH.OwnerProvenance memory p,
        G.Timeline memory timeline
    ) private pure {
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
            Facts.interval(p, timeline, r.point, a.terms.bindingGeneration, false);
            for (uint256 j; j < i; ++j) {
                if (
                    b.resolutions[j].record.actionId == a.actionId
                        || b.resolutions[j].record.terms.disputeRecordHash
                            == a.terms.disputeRecordHash
                ) _invalid();
            }
        }
    }

    function _operationIndex(
        RH.OwnerProvenance memory p,
        PC.Inventory memory archive,
        uint16 operation,
        bytes32 record,
        RH.Point memory point
    ) private view returns (uint256 index) {
        uint256 era = A.era(p, point.environmentHash);
        uint256 matches;
        for (uint256 i; i < archive.operations.length; ++i) {
            H.OperationEvidence memory row = archive.operations[i];
            if (row.operation != operation || row.originHash != point.environmentHash) continue;
            H.Envelope memory e =
                Catalogue.read(p.origins[era], archive.catalogues[era], row.evidence);
            if (e.operation != operation) _invalid();
            if (e.value != record) continue;
            if (e.after_[4].revision != point.ownerRevision) _invalid();
            index = i;
            ++matches;
        }
        if (matches != 1) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

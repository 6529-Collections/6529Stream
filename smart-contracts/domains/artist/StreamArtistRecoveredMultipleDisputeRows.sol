// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "./StreamArtistRecoveredMultipleDisputeTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryRowFacts as Facts
} from "./StreamArtistRecoveredDisputeHistoryRowFacts.sol";
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
import {
    StreamArtistRecoveredMultipleCodec as Scope
} from "./StreamArtistRecoveredMultipleCodec.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";

/// @notice One bijection over the full native journal, then the original per-collection chains.
/// @dev Provenance retains global occurrence indices and clocks. No filtered owner is manufactured.
library StreamArtistRecoveredMultipleDisputeRows {
    function validate(
        D.Bundle[] memory rows,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory
    ) public pure {
        validate(rows, scope, p, inventory, false);
    }

    /// @dev State3 is admitted only with the caller's paired original confirmation proof.
    function validate(
        D.Bundle[] memory rows,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory,
        bool sanctioned
    ) public pure {
        bytes32 provenance = Provenance.validateOwner(p, 4);
        if (rows.length != scope.collections.length || inventory.generations.length != rows.length) _invalid();
        uint256[] memory disputes = new uint256[](rows.length);
        uint256[] memory repudiations = new uint256[](rows.length);
        for (uint256 k; k < rows.length; ++k) {
            D.Bundle memory b = rows[k];
            AH.Query memory q = scope.collections[k];
            if (
                b.provenance != provenance || b.artistId != q.artistId
                    || b.collectionId != q.collectionId || b.bindingHash != q.bindingHash
                    || b.generations.length == 0 || b.generations.length > 128
                    || b.heads.length != b.generations.length
                    || b.current.generation != b.generations.length
                    || (b.current.state != 2
                        && b.current.state != 4
                        && b.current.state != 5
                        && (!sanctioned || b.current.state != 3))
                    || !b.generations[b.generations.length - 1].accepted
                    || b.generations[b.generations.length - 1].bindingHash != q.bindingHash
                    || keccak256(abi.encode(b.generations))
                        != keccak256(abi.encode(inventory.generations[k]))
            ) _invalid();
        }
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            uint256 k = Scope.collection(scope, j.receipt.collectionId);
            if (j.receipt.artistId != scope.collections[k].artistId) _invalid();
            if (j.receipt.operation == 24) continue; // Independently complete original op24 proof.
            if (!MD.nativeDispute(j.receipt.operation)) _invalid();
            Clock.validateOwnerPoint(p, 4, j.position.point);
            D.Bundle memory b = rows[k];
            if (j.receipt.operation == 47) {
                if (repudiations[k] >= b.repudiations.length) _invalid();
                D.RepudiationRow memory r = b.repudiations[repudiations[k]++];
                if (
                    j.receipt.recordHash != r.record.recordHash
                        || !D.samePoint(j.position.point, r.point)
                ) _invalid();
                Facts.repudiation(b, r, p);
            } else {
                if (disputes[k] >= b.disputes.length) _invalid();
                D.DisputeRow memory r = b.disputes[disputes[k]++];
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
        for (uint256 k; k < rows.length; ++k) {
            D.Bundle memory b = rows[k];
            if (disputes[k] != b.disputes.length || repudiations[k] != b.repudiations.length) {
                _invalid();
            }
            _resolutions(b, p, sanctioned);
            Facts.pending(b);
            if (sanctioned) Chains.validateSanctioned(b, p);
            else Chains.validate(b, p);
        }
    }

    function _resolutions(D.Bundle memory b, RH.OwnerProvenance memory p, bool sanctioned)
        private
        pure
    {
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
                    || (a.terms.resolution == 1
                        && (a.restoredState < 1 || a.restoredState > (sanctioned ? 3 : 2)))
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    b.resolutions[j].record.actionId == a.actionId
                        || b.resolutions[j].record.terms.disputeRecordHash
                            == a.terms.disputeRecordHash
                ) _invalid();
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistAttributionDisputesOwner as Disputes,
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    IStreamArtistDisputeWithdrawalOwner as Withdrawal
} from "../../interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";
import {
    IStreamArtistRepudiationOwner as Repudiation
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRecoveredHydrationProvenance as P
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredPlatformTypes as Platform
} from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistCompleteHistoryDisputeRows as Rows
} from "./StreamArtistCompleteHistoryDisputeRows.sol";

/// @notice Complete bound dispute maps from the full owner source and original provenance.
/// @dev Only this family's rows are collected. Platform, attestation, Archive, Identity and
/// whole-owner replay/mutation bijections remain mandatory in the enclosing complete proof.

library StreamArtistCompleteHistoryDisputeSource {
    function collect(
        address source,
        M.State memory scope,
        RH.Provenance memory p,
        PC.BindingInventory memory bindings,
        PC.Inventory memory archive,
        Clocks.Result memory clocks
    ) public view returns (D.Bundle[] memory all) {
        P.validateOwnerSource(RH.ownerProvenance(p, 4), 4, source);
        if (
            bindings.bindings.length != scope.collections.length
                || bindings.generations.length != scope.collections.length
        ) _invalid();
        all = new D.Bundle[](scope.collections.length);
        for (uint256 k; k < all.length; ++k) {
            all[k] = _collect(source, scope.collections[k], p, bindings.generations[k]);
        }
        // A captured authority head may have pending records in several collections.
        for (uint256 k; k < all.length; ++k) {
            for (uint256 i; i < all[k].repudiations.length; ++i) {
                bytes32 cohort = keccak256(abi.encode(all[k].repudiations[i].record.authorityHead));
                uint256 count;
                for (uint256 c; c < all.length; ++c) {
                    for (uint256 j; j < all[c].repudiations.length; ++j) {
                        if (
                            all[c].repudiations[j].record.artistId
                                    == all[k].repudiations[i].record.artistId
                                && all[c].repudiations[j].terminal.phase == 1
                                && keccak256(
                                        abi.encode(all[c].repudiations[j].record.authorityHead)
                                    ) == cohort
                        ) ++count;
                    }
                }
                if (
                    Repudiation(source)
                            .repudiationCount(all[k].repudiations[i].record.artistId, cohort)
                        != count
                ) {
                    _invalid();
                }
            }
        }
        Rows.validate(all, scope, RH.ownerProvenance(p, 4), bindings, archive, clocks);
    }

    function _collect(
        address source,
        AH.Query memory q,
        RH.Provenance memory p,
        A.Generation[] memory generations
    ) private view returns (D.Bundle memory b) {
        RH.OwnerProvenance memory local = RH.ownerProvenance(p, 4);
        b.provenance = RH.ownerProvenanceHash(local, 4);
        b.artistId = q.artistId;
        b.collectionId = q.collectionId;
        b.bindingHash = q.bindingHash;
        (b.current.state, b.current.generation) =
            Attribution(source).attributionState(q.collectionId);
        b.generations = generations;
        b.heads = new AD.Head[](b.generations.length);
        for (uint256 i; i < b.heads.length; ++i) {
            b.heads[i] = Disputes(source).attributionDispute(q.collectionId, uint64(i + 1));
        }
        uint256 disputes;
        uint256 repudiations;
        for (uint256 i; i < local.journal.length; ++i) {
            if (local.journal[i].receipt.collectionId != q.collectionId) continue;
            uint16 op = local.journal[i].receipt.operation;
            if (op == 47) ++repudiations;
            else if (op == 44 || op == 45 || op == 61) ++disputes;
            else if (op != 24 && !Platform.nativeOperation(op)) _invalid();
        }
        b.disputes = new D.DisputeRow[](disputes);
        b.repudiations = new D.RepudiationRow[](repudiations);
        disputes = 0;
        repudiations = 0;
        for (uint256 i; i < local.journal.length; ++i) {
            RH.JournalEntry memory j = local.journal[i];
            if (j.receipt.collectionId != q.collectionId) continue;
            if (j.receipt.operation == 24 || Platform.nativeOperation(j.receipt.operation)) {
                continue;
            }
            if (j.receipt.operation == 47) {
                D.RepudiationRow memory r;
                r.point = j.position.point;
                r.record = Repudiation(source).attributionRepudiationRecord(j.receipt.recordHash);
                r.terminal =
                    Repudiation(source).attributionRepudiationTerminal(j.receipt.recordHash);
                if (r.terminal.phase >= 2 && r.terminal.phase <= 4) {
                    r.terminalPoint = _point(
                        local,
                        D.terminalSurface(r.terminal.phase),
                        j.receipt.recordHash,
                        keccak256(
                            abi.encode(
                                j.receipt.recordHash, r.terminal.phase, r.terminal.reasonHash
                            )
                        )
                    );
                }
                b.repudiations[repudiations++] = r;
            } else {
                D.DisputeRow memory r;
                r.point = j.position.point;
                r.record = Disputes(source).attributionDisputeRecord(j.receipt.recordHash);
                if (j.receipt.operation == 44) {
                    r.withdrawal =
                        Withdrawal(source).attributionDisputeWithdrawal(j.receipt.recordHash);
                }
                b.disputes[disputes++] = r;
            }
        }
        _resolutions(b, source, local);
        b.pending = Repudiation(source).rawPendingRepudiation(q.collectionId);
    }

    function _resolutions(D.Bundle memory b, address source, RH.OwnerProvenance memory p)
        private
        view
    {
        D.ResolutionRow[] memory rows = new D.ResolutionRow[](p.aliases.length);
        uint256 n;
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            if (a.surface != D.RESOLVE) continue;
            bool seen;
            for (uint256 j; j < n; ++j) {
                if (rows[j].record.actionId == a.cell.commitment) seen = true;
            }
            if (seen) continue;
            AD.Resolution memory record =
                Disputes(source).attributionDisputeResolution(a.cell.commitment);
            if (record.terms.collectionId != b.collectionId) continue;
            rows[n++] = D.ResolutionRow(a.admittedAt, record);
        }
        assembly ("memory-safe") { mstore(rows, n) }
        for (uint256 i = 1; i < n; ++i) {
            D.ResolutionRow memory row = rows[i];
            uint256 j = i;
            while (j != 0 && Clock.beforeOwner(p, 4, row.point, rows[j - 1].point)) {
                rows[j] = rows[j - 1];
                --j;
            }
            rows[j] = row;
        }
        b.resolutions = rows;
    }

    function _point(RH.OwnerProvenance memory p, bytes32 surface, bytes32 scope, bytes32 commitment)
        private
        pure
        returns (RH.Point memory point)
    {
        bool found;
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            if (a.surface != surface || a.scope != scope) continue;
            if (
                a.cell.kind != 1 || a.cell.status != 2 || a.cell.commitment != commitment
                    || (found && !D.samePoint(point, a.admittedAt))
            ) _invalid();
            point = a.admittedAt;
            found = true;
        }
        if (!found) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredPlatformTypes as PLH
} from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryValidation as Validation
} from "./StreamArtistRecoveredDisputeHistoryValidation.sol";
import {
    StreamArtistRecoveredPlatformBindingValidation as Binding
} from "./StreamArtistRecoveredPlatformBindingValidation.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
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
    IStreamArtistPlatformOwner as Platform
} from "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as P
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Fixed shared original/record-history validation body; all full typed inputs are retained.
library StreamArtistRecoveredPlatformDisputeSourceKernel {
    function collect(
        address source,
        AH.Query memory q,
        RH.Provenance memory p,
        CB.Bundle memory bindings,
        bool includeRecords
    ) public view returns (D.Bundle memory b) {
        RH.OwnerProvenance memory local = RH.ownerProvenance(p, 4);
        P.validateOwnerSource(local, 4, source);
        b.provenance = RH.ownerProvenanceHash(local, 4);
        b.artistId = q.artistId;
        b.collectionId = q.collectionId;
        b.bindingHash = q.bindingHash;
        (b.current.state, b.current.generation) =
            Attribution(source).attributionState(q.collectionId);
        b.generations = Binding.validate(bindings, q, RH.ownerProvenance(p, 0));
        b.heads = new AD.Head[](b.generations.length);
        for (uint256 i; i < b.heads.length; ++i) {
            b.heads[i] = Disputes(source).attributionDispute(q.collectionId, uint64(i + 1));
        }
        uint256 disputes;
        uint256 repudiations;
        for (uint256 i; i < local.journal.length; ++i) {
            uint16 op = local.journal[i].receipt.operation;
            if (op == 47) ++repudiations;
            else if (op == 44 || op == 45 || op == 61) ++disputes;
            else if (!PLH.nativeOperation(op) && !(includeRecords && op == 24)) _invalid();
        }
        b.disputes = new D.DisputeRow[](disputes);
        b.repudiations = new D.RepudiationRow[](repudiations);
        disputes = 0;
        repudiations = 0;
        for (uint256 i; i < local.journal.length; ++i) {
            RH.JournalEntry memory j = local.journal[i];
            if (
                PLH.nativeOperation(j.receipt.operation)
                    || (includeRecords && j.receipt.operation == 24)
            ) continue;
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
        for (uint256 i; i < b.repudiations.length; ++i) {
            bytes32 cohort = keccak256(abi.encode(b.repudiations[i].record.authorityHead));
            uint256 count;
            for (uint256 j; j < b.repudiations.length; ++j) {
                if (
                    b.repudiations[j].terminal.phase == 1
                        && keccak256(abi.encode(b.repudiations[j].record.authorityHead)) == cohort
                ) ++count;
            }
            if (Repudiation(source).repudiationCount(q.artistId, cohort) != count) _invalid();
        }
        // The complete Platform codec validates the full journal, guards and state timeline.
        _causes(b, bindings);
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
            rows[n++] = D.ResolutionRow(
                a.admittedAt, Disputes(source).attributionDisputeResolution(a.cell.commitment)
            );
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

    function _causes(D.Bundle memory b, CB.Bundle memory bindings) private pure {
        for (uint256 i; i + 1 < b.generations.length; ++i) {
            if (!b.generations[i].accepted && b.heads[i].revocationReason != 4) continue;
            bytes memory expected;
            if (bindings.corrections[i + 1].approval.cause == 4) {
                AD.Record memory opening;
                AD.Resolution memory resolution;
                for (uint256 j; j < b.disputes.length; ++j) {
                    if (b.disputes[j].record.recordHash == b.heads[i].disputeRecordHash) {
                        opening = b.disputes[j].record;
                    }
                }
                for (uint256 j; j < b.resolutions.length; ++j) {
                    if (b.resolutions[j].record.actionId == b.heads[i].resolutionActionId) {
                        resolution = b.resolutions[j].record;
                    }
                }
                expected =
                    abi.encode(bindings.bindings.rows[i].terminal, b.heads[i], opening, resolution);
            } else if (bindings.corrections[i + 1].approval.cause == 3) {
                bool found;
                for (uint256 j; j < b.repudiations.length; ++j) {
                    if (
                        b.repudiations[j].record.recordHash
                            == bindings.corrections[i + 1].approval.causeRecord
                    ) {
                        expected = abi.encode(
                            bindings.bindings.rows[i].terminal,
                            b.heads[i],
                            b.repudiations[j].record,
                            b.repudiations[j].terminal
                        );
                        found = true;
                    }
                }
                if (!found) _invalid();
            } else {
                _invalid();
            }
            if (
                keccak256(expected)
                    != keccak256(Binding.causeData(bindings.corrections[i + 1].approval.causeData))
            ) {
                _invalid();
            }
        }
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

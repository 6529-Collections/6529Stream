// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionAttributionCodec as Validation
} from "./StreamArtistRecoveredSanctionAttributionCodec.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import { StreamArtistDisputeState as Disputes } from "./StreamArtistDisputeState.sol";
import {
    StreamArtistDisputeWithdrawalState as Withdrawals
} from "./StreamArtistDisputeWithdrawalState.sol";
import { StreamArtistRepudiationState as Repudiations } from "./StreamArtistRepudiationState.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistDisputeWithdrawalTypes as W
} from "../../interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";

/// @notice Original fixed Attribution maps, called only inside its unchanged guarded op60 path.
/// @dev Every empty-state and canonical inventory check precedes the first semantic write.
library StreamArtistRecoveredSanctionAttributionImport {
    function importIfSelected(AS.State storage s, AH.Query memory q, bytes memory outer)
        public
        returns (bool)
    {
        (RH.ExportHeader memory h, Payload.Payload memory p) = Payload.decode(outer, 4);
        if ((h.requiredFeatures & RH.SANCTION_HISTORY) == 0) return false;
        if (p.nonces.length != 0) _invalid();
        H.AttributionBundle memory complete = Validation.decode(q, p.provenance, p.semanticState);
        D.Bundle memory b = complete.original;
        if (
            s.attributions[q.collectionId].state != 0
                || s.attributions[q.collectionId].generation != 0
        ) _invalid();
        _empty(b);
        Disputes.Store storage ds = Disputes.store();
        Withdrawals.Store storage ws = Withdrawals.store();
        Repudiations.State storage rs = Repudiations.state();
        s.attributions[q.collectionId] = b.current;
        for (uint256 i; i < b.heads.length; ++i) {
            ds.heads[Disputes.key(q.collectionId, uint64(i + 1))] = b.heads[i];
        }
        for (uint256 i; i < b.disputes.length; ++i) {
            D.DisputeRow memory row = b.disputes[i];
            ds.records[row.record.recordHash] = row.record;
            if (row.record.terms.disputeAction == 1) {
                ds.evidenceSeen[
                    keccak256(
                        abi.encode(
                            q.collectionId,
                            row.record.terms.bindingGeneration,
                            row.record.terms.evidenceHash
                        )
                    )
                ] = true;
                if (row.withdrawal.recordHash != 0) {
                    ws.outcomes[row.record.recordHash] = row.withdrawal;
                }
            }
        }
        for (uint256 i; i < b.resolutions.length; ++i) {
            ds.resolutions[b.resolutions[i].record.actionId] = b.resolutions[i].record;
        }
        for (uint256 i; i < b.repudiations.length; ++i) {
            D.RepudiationRow memory row = b.repudiations[i];
            rs.records[row.record.recordHash] = row.record;
            rs.terminal[row.record.recordHash] = row.terminal;
            if (row.terminal.phase == 1) {
                ++rs.counts[q.artistId][keccak256(abi.encode(row.record.authorityHead))];
            }
        }
        rs.pending[q.collectionId] = b.pending;
        return true;
    }

    function _empty(D.Bundle memory b) private view {
        Disputes.Store storage ds = Disputes.store();
        Withdrawals.Store storage ws = Withdrawals.store();
        Repudiations.State storage rs = Repudiations.state();
        AD.Head memory head;
        AD.Record memory record;
        AD.Resolution memory resolution;
        W.Outcome memory outcome;
        RP.Record memory repudiation;
        RP.Terminal memory terminal;
        if (rs.pending[b.collectionId] != 0) _invalid();
        for (uint256 i; i < b.heads.length; ++i) {
            if (
                keccak256(abi.encode(ds.heads[Disputes.key(b.collectionId, uint64(i + 1))]))
                    != keccak256(abi.encode(head))
            ) _invalid();
        }
        for (uint256 i; i < b.disputes.length; ++i) {
            AD.Record memory row = b.disputes[i].record;
            if (keccak256(abi.encode(ds.records[row.recordHash])) != keccak256(abi.encode(record))) _invalid();
            if (
                row.terms.disputeAction == 1
                    && (ds.evidenceSeen[
                            keccak256(
                                abi.encode(
                                    b.collectionId,
                                    row.terms.bindingGeneration,
                                    row.terms.evidenceHash
                                )
                            )
                        ]
                        || keccak256(abi.encode(ws.outcomes[row.recordHash]))
                            != keccak256(abi.encode(outcome)))
            ) _invalid();
        }
        for (uint256 i; i < b.resolutions.length; ++i) {
            if (
                keccak256(abi.encode(ds.resolutions[b.resolutions[i].record.actionId]))
                    != keccak256(abi.encode(resolution))
            ) _invalid();
        }
        for (uint256 i; i < b.repudiations.length; ++i) {
            RP.Record memory row = b.repudiations[i].record;
            if (
                keccak256(abi.encode(rs.records[row.recordHash]))
                        != keccak256(abi.encode(repudiation))
                    || keccak256(abi.encode(rs.terminal[row.recordHash]))
                        != keccak256(abi.encode(terminal))
                    || rs.counts[b.artistId][keccak256(abi.encode(row.authorityHead))] != 0
            ) _invalid();
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

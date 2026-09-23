// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionCatalogue as Catalogue
} from "./StreamArtistRecoveredSanctionCatalogue.sol";
import {
    StreamArtistRecoveredSanctionEvidenceCodec as Codec
} from "./StreamArtistRecoveredSanctionEvidenceCodec.sol";
import {
    StreamArtistRecoveredSanctionConfirmationProof as Confirmation
} from "./StreamArtistRecoveredSanctionConfirmationProof.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import { StreamArtistSanctionHashes as Hashes } from "./StreamArtistSanctionHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    IStreamArtistSanctionArchiveFacts as Facts
} from "../../interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";

/// @notice Each destination owner checks its own complete clock and exact immutable evidence.
/// @dev Complete seven-owner source provenance authenticates the other owner's cutoff in the
/// Coordinator before any writer and again after all writers. No cross-owner clock is inferred.
library StreamArtistRecoveredSanctionLocalProof {
    function validate(
        RH.OwnerProvenance memory p,
        uint8 owner,
        AH.Query memory q,
        H.Inventory memory x
    ) public view {
        Catalogue.requireLocal(p, owner, x.catalogues, x.operations);
        uint256 ns;
        uint256 nc;
        for (uint256 i; i < x.operations.length; ++i) {
            H.OperationEvidence memory op = x.operations[i];
            uint256 era = _era(p, op.originHash);
            RH.OriginEnvironment memory o = p.origins[era];
            H.Catalogue memory c = x.catalogues[era];
            H.Envelope memory e = Catalogue.read(o, c, op.evidence);
            if (op.operation == 12) {
                if (ns >= x.sanctions.length) _invalid();
                H.SanctionRow memory row = x.sanctions[ns++];
                H.SanctionPayload memory s = Codec.sanction(e.payload);
                bytes memory expected = Hashes.archiveBytes(
                    StreamArtistHashes.Environment(o.chainId, o.registry, o.core, o.manager),
                    s.prepared.subject.finalityRegistry,
                    s.record,
                    s.prepared.ceremony,
                    s.authorization.signature
                );
                Facts.Facts memory f = Facts.Facts(
                    s.record.recordHash,
                    q.artistId,
                    Hashes.ARCHIVE_SCHEMA,
                    Hashes.ARCHIVE_CANONICALIZATION,
                    keccak256(expected),
                    uint64(expected.length)
                );
                if (
                    row.record.artistId != q.artistId
                        || row.record.terms.collectionId != q.collectionId
                        || row.record.recordHash != e.value
                        || !D.samePoint(row.point, RH.Point(op.originHash, 6, e.after_[6].revision))
                        || keccak256(abi.encode(row.record)) != keccak256(abi.encode(s.record))
                        || keccak256(abi.encode(row.evidence)) != keccak256(abi.encode(op.evidence))
                        || keccak256(row.archiveBytes) != keccak256(expected)
                        || keccak256(abi.encode(row.archiveFacts)) != keccak256(abi.encode(f))
                ) _invalid();
            } else {
                if (nc >= x.confirmations.length) _invalid();
                H.ConfirmationRow memory row = x.confirmations[nc++];
                RH.Era memory bounds;
                bounds.originHash = op.originHash;
                bounds.lowerRevisions[4] = c.attributionLower;
                bounds.checkpoints[4].ownerState.revision = c.attributionUpper;
                bounds.lowerRevisions[6] = c.consentLower;
                bounds.checkpoints[6].ownerState.revision = c.consentUpper;
                // Owner0 does not mutate in op13. Its exact original snapshot is retained;
                // only the global Coordinator proof compares it to owner0's own checkpoint.
                bounds.checkpoints[0].ownerState.revision = e.after_[0].revision;
                (H.ConfirmationPayload memory proof, RH.Point memory ap, RH.Point memory cp) =
                    Confirmation.validate(o, bounds, e);
                if (
                    proof.transition.artistId != q.artistId
                        || proof.transition.collectionId != q.collectionId
                        || !D.samePoint(row.attributionPoint, ap)
                        || !D.samePoint(row.consentPoint, cp)
                        || keccak256(abi.encode(row.transition))
                            != keccak256(abi.encode(proof.transition))
                        || keccak256(abi.encode(row.evidence)) != keccak256(abi.encode(op.evidence))
                ) _invalid();
            }
        }
        if (
            ns != x.sanctions.length || nc != x.confirmations.length || ns == 0
                || nc > H.MAX_CONFIRMATIONS
        ) _invalid();
    }

    function _era(RH.OwnerProvenance memory p, bytes32 origin) private pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == origin) return i;
        }
        _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}

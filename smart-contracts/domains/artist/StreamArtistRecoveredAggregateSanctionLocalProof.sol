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
    StreamArtistSanctionTypes as S
} from "../../interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    IStreamArtistSanctionArchiveFacts as Facts
} from "../../interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";

/// @notice Exact original sanction evidence at an aggregate owner4 or owner6 import boundary.
/// @dev The global composition separately proves every original binding and all seven cutoffs.
/// No collection projection replaces the complete catalogue or the original owner certificate.
library StreamArtistRecoveredAggregateSanctionLocalProof {
    function validate(
        RH.OwnerProvenance memory p,
        uint8 owner,
        AH.Query[] memory collections,
        H.Inventory memory x
    ) public view {
        if (owner != 4 && owner != 6) _invalid();
        _collections(collections);
        Catalogue.requireLocal(p, owner, x.catalogues, x.operations);
        uint256 ns;
        uint256 nc;
        for (uint256 i; i < x.operations.length; ++i) {
            H.OperationEvidence memory op = x.operations[i];
            uint256 era = _era(p, op.originHash);
            H.Envelope memory e = Catalogue.read(p.origins[era], x.catalogues[era], op.evidence);
            if (e.operation != op.operation) _invalid();
            if (op.operation == 12) {
                if (ns >= x.sanctions.length) _invalid();
                H.SanctionRow memory row = x.sanctions[ns++];
                _collection(collections, row.record.terms.collectionId);
                _sanction(p.origins[era], op, e, row);
            } else if (op.operation == 13) {
                if (nc >= x.confirmations.length) _invalid();
                _collection(collections, x.confirmations[nc].transition.collectionId);
                _confirmation(p, x, era, op, e, ns, nc++);
            } else {
                _invalid();
            }
        }
        if (
            ns != x.sanctions.length || nc != x.confirmations.length || ns == 0
                || ns > RH.MAX_JOURNAL_ENTRIES || nc > H.MAX_CONFIRMATIONS
        ) _invalid();
    }

    function _sanction(
        RH.OriginEnvironment memory o,
        H.OperationEvidence memory op,
        H.Envelope memory e,
        H.SanctionRow memory row
    ) private pure {
        H.SanctionPayload memory s = Codec.sanction(e.payload);
        bytes memory expected = Hashes.archiveBytes(
            StreamArtistHashes.Environment(o.chainId, o.registry, o.core, o.manager),
            s.prepared.subject.finalityRegistry,
            s.record,
            s.prepared.ceremony,
            s.authorization.signature
        );
        // A later primary change must not replace the original record's Artist with the head query.
        Facts.Facts memory f = Facts.Facts(
            s.record.recordHash,
            s.record.artistId,
            Hashes.ARCHIVE_SCHEMA,
            Hashes.ARCHIVE_CANONICALIZATION,
            keccak256(expected),
            uint64(expected.length)
        );
        if (
            row.record.recordHash == 0 || row.record.artistId == 0
                || row.record.recordHash != e.value
                || !D.samePoint(row.point, RH.Point(op.originHash, 6, e.after_[6].revision))
                || keccak256(abi.encode(row.record)) != keccak256(abi.encode(s.record))
                || keccak256(abi.encode(row.evidence)) != keccak256(abi.encode(op.evidence))
                || keccak256(row.archiveBytes) != keccak256(expected)
                || keccak256(abi.encode(row.archiveFacts)) != keccak256(abi.encode(f))
        ) _invalid();
    }

    function _confirmation(
        RH.OwnerProvenance memory p,
        H.Inventory memory x,
        uint256 era,
        H.OperationEvidence memory op,
        H.Envelope memory e,
        uint256 priorSanctions,
        uint256 index
    ) private pure {
        H.Catalogue memory c = x.catalogues[era];
        RH.Era memory bounds;
        bounds.originHash = op.originHash;
        bounds.lowerRevisions[4] = c.attributionLower;
        bounds.checkpoints[4].ownerState.revision = c.attributionUpper;
        bounds.lowerRevisions[6] = c.consentLower;
        bounds.checkpoints[6].ownerState.revision = c.consentUpper;
        // Original op13 reads owner0 without mutating it. The global proof checks its own cutoff.
        bounds.checkpoints[0].ownerState.revision = e.after_[0].revision;
        (H.ConfirmationPayload memory proof, RH.Point memory ap, RH.Point memory cp) =
            Confirmation.validate(p.origins[era], bounds, e);
        H.ConfirmationRow memory row = x.confirmations[index];
        if (
            !D.samePoint(row.attributionPoint, ap) || !D.samePoint(row.consentPoint, cp)
                || keccak256(abi.encode(row.transition)) != keccak256(abi.encode(proof.transition))
                || keccak256(abi.encode(row.evidence)) != keccak256(abi.encode(op.evidence))
        ) _invalid();
        _priorSanction(p, x.sanctions, priorSanctions, proof.sanction, row.consentPoint);
        for (uint256 i; i < index; ++i) {
            H.ConfirmationRow memory earlier = x.confirmations[i];
            if (
                earlier.transition.collectionId == row.transition.collectionId
                    && earlier.transition.artistId == row.transition.artistId
                    && earlier.transition.bindingGeneration == row.transition.bindingGeneration
            ) _invalid();
        }
    }

    function _priorSanction(
        RH.OwnerProvenance memory p,
        H.SanctionRow[] memory rows,
        uint256 count,
        S.Record memory record,
        RH.Point memory confirmation
    ) private pure {
        uint256 matched;
        for (uint256 i; i < rows.length; ++i) {
            if (rows[i].record.recordHash != record.recordHash) continue;
            if (
                i >= count || keccak256(abi.encode(rows[i].record)) != keccak256(abi.encode(record))
                    || !_beforeConsent(p, rows[i].point, confirmation)
            ) _invalid();
            ++matched;
        }
        if (matched != 1) _invalid();
    }

    function _beforeConsent(RH.OwnerProvenance memory p, RH.Point memory a, RH.Point memory b)
        private
        pure
        returns (bool)
    {
        if (a.ownerIndex != 6 || b.ownerIndex != 6) _invalid();
        uint256 left = _era(p, a.environmentHash);
        uint256 right = _era(p, b.environmentHash);
        return left < right || (left == right && a.ownerRevision < b.ownerRevision);
    }

    function _collections(AH.Query[] memory collections) private pure {
        if (collections.length == 0 || collections.length > 128) _invalid();
        for (uint256 i; i < collections.length; ++i) {
            if (collections[i].collectionId == 0) _invalid();
            for (uint256 j; j < i; ++j) {
                if (collections[i].collectionId == collections[j].collectionId) _invalid();
            }
        }
    }

    function _collection(AH.Query[] memory collections, uint256 id) private pure {
        for (uint256 i; i < collections.length; ++i) {
            if (collections[i].collectionId == id) return;
        }
        _invalid();
    }

    function _era(RH.OwnerProvenance memory p, bytes32 origin) private pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == origin) return i;
        }
        _invalid();
        return 0;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
